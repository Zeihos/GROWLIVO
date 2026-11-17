-- GROWLIVO / Persistent global rankings / Alpha 0.9.17
-- ServerScriptService > GrowlivoLeaderboards [Script]
-- Only committed, monotonic values reach ordered data stores. Client never writes ranks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Storage = require(ServerScriptService:WaitForChild("GrowlivoStorage"))
local Config = require(ReplicatedStorage:WaitForChild("GrowlivoConfig"))
local settings = Config.Leaderboards
local clicksStore = Storage.GetOrderedDataStore(settings.TotalClicksStore)
local rebirthStore = Storage.GetOrderedDataStore(settings.RebirthsStore)
local savedEvent = ServerScriptService:WaitForChild("GROWLIVO_ConfirmedSave")
assert(savedEvent:IsA("BindableEvent"), "Expected confirmed-save BindableEvent")
local remotes = ReplicatedStorage:WaitForChild("GROWLIVO_Remotes")

local function remote(name)
    local existing = remotes:FindFirstChild(name)
    assert(not existing or existing:IsA("RemoteEvent"), "Unexpected remote: " .. name)
    if not existing then
        existing = Instance.new("RemoteEvent")
        existing.Name = name
        existing.Parent = remotes
    end
    return existing
end
local request = remote("RequestBoards")
local stateEvent = remote("BoardState")
local MAX_SCORE = 9000000000000000
local function score(value)
    if typeof(value) ~= "number" or value ~= value or value < 0 or value > MAX_SCORE then return nil end
    if value ~= math.floor(value) then return nil end
    return value
end
local pending = {} -- userId => newest committed values, including failed writes
local writing = {} -- single writer per user (serializes all retries)
local published = {} -- last successfully written scores on this server
local retryDelays = {10, 20, 40, 60} -- seconds; bounded, never spin on API errors
-- Under heavy joins each committed profile can queue two OrderedDataStore writes.
-- Bound API concurrency so simultaneous joins do not stampede the same budget.
local MAX_PARALLEL_RANK_WRITES = 2
local rankWritesInFlight = 0
local function updateOne(store, key, value)
    for attempt = 1, 3 do
        -- A queued worker does not hold a permit during backoff.
        while rankWritesInFlight >= MAX_PARALLEL_RANK_WRITES do
            task.wait(0.15)
        end
        rankWritesInFlight += 1
        local ok, result = pcall(function()
            return store:UpdateAsync(key, function(previous)
                local old = score(previous) or 0
                return math.max(old, value)
            end)
        end)
        rankWritesInFlight -= 1
        if ok and result ~= nil then return true end
        if attempt < 3 then task.wait(attempt * 1.2) end
    end
    return false
end
local function flush(userId)
    local consecutiveFailures = 0
    while pending[userId] do
        local item = pending[userId]
        pending[userId] = nil
        local key = tostring(userId)
        local previous = published[userId] or {Total = -1, Rebirths = -1}
        local totalDone = item.Total <= previous.Total
        local rebirthDone = item.Rebirths <= previous.Rebirths
        if not totalDone then totalDone = updateOne(clicksStore, key, item.Total) end
        if not rebirthDone then rebirthDone = updateOne(rebirthStore, key, item.Rebirths) end
        -- Partial success matters: on retry do not rewrite a completed dimension.
        published[userId] = {
            Total = totalDone and math.max(item.Total, previous.Total) or previous.Total,
            Rebirths = rebirthDone and math.max(item.Rebirths, previous.Rebirths) or previous.Rebirths,
        }
        if not (totalDone and rebirthDone) then
            -- Merge any newer confirmed save that arrived while UpdateAsync yielded.
            local latest = pending[userId]
            pending[userId] = {
                Total = math.max(item.Total, latest and latest.Total or 0),
                Rebirths = math.max(item.Rebirths, latest and latest.Rebirths or 0),
            }
            consecutiveFailures = math.min(consecutiveFailures + 1, #retryDelays)
            local delaySeconds = retryDelays[consecutiveFailures]
            warn(string.format("[GROWLIVO] Rank retry queued: user=%d in %ds", userId, delaySeconds))
            task.wait(delaySeconds)
        else
            consecutiveFailures = 0
            task.wait(0.25)
        end
    end
    writing[userId] = nil
end
savedEvent.Event:Connect(function(userId, totalClicks, rebirths)
    if typeof(userId) ~= "number" or userId < 1 or userId ~= math.floor(userId) then return end
    local total, rebirth = score(totalClicks), score(rebirths)
    if not total or not rebirth or rebirth > Config.MaxRebirths then return end
    local existing = pending[userId]
    if existing then
        total = math.max(total, existing.Total)
        rebirth = math.max(rebirth, existing.Rebirths)
    end
    pending[userId] = {Total = total, Rebirths = rebirth}
    if not writing[userId] then
        writing[userId] = true
        task.spawn(flush, userId)
    end
end)

local nameCache = {}
local function displayName(userId)
    if nameCache[userId] then return nameCache[userId] end
    local ok, name = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
    local safe = ok and typeof(name) == "string" and name or ("Игрок #" .. tostring(userId))
    nameCache[userId] = safe
    return safe
end
local function fetchTop(store)
    local ok, pages = pcall(function() return store:GetSortedAsync(false, settings.PageSize) end)
    if not ok or not pages then return nil end
    local readOk, items = pcall(function() return pages:GetCurrentPage() end)
    if not readOk or typeof(items) ~= "table" then return nil end
    local result = {}
    for _, item in ipairs(items) do
        local uid = tonumber(item.key)
        local value = score(item.value)
        if uid and uid >= 1 and uid == math.floor(uid) and value then
            table.insert(result, {UserId = uid, Name = displayName(uid), Value = value})
        end
    end
    return result
end
local cache = {TotalClicks = {}, Rebirths = {}, UpdatedAt = 0, Available = false}
local refreshing = false
local function refresh()
    if refreshing then return end
    refreshing = true
    local total = fetchTop(clicksStore)
    local rebirth = fetchTop(rebirthStore)
    if total then cache.TotalClicks = total end
    if rebirth then cache.Rebirths = rebirth end
    if total and rebirth then cache.UpdatedAt = os.time() end
    cache.Available = total ~= nil and rebirth ~= nil
    stateEvent:FireAllClients(cache)
    refreshing = false
end
local askedAt = {}
request.OnServerEvent:Connect(function(player)
    local now = os.clock()
    if now - (askedAt[player] or -100) < 5 then return end
    askedAt[player] = now
    stateEvent:FireClient(player, cache)
end)
Players.PlayerRemoving:Connect(function(player) askedAt[player] = nil end)
task.spawn(function()
    task.wait(12)
    while true do
        refresh()
        task.wait(settings.RefreshSeconds)
    end
end)
print("[GROWLIVO] Global leaderboards initialized (ordered stores)")
