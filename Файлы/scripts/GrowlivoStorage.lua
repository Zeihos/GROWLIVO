-- GROWLIVO / DataStore bootstrap / Alpha 0.9.17
-- Unpublished Studio places get an IN-MEMORY implementation for playtests only.
-- Published places NEVER silently fall back to temporary storage.
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local Storage = {}

local unpublishedStudio = RunService:IsStudio() and (game.GameId == 0 or game.PlaceId == 0)
Storage.Mode = unpublishedStudio and "StudioTemporary" or "Persistent"
Storage.IsTemporary = unpublishedStudio

local buckets = {}
local function deepCopy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[deepCopy(k)] = deepCopy(v) end
    return result
end

local function memoryStore(name, isOrdered)
    local key = (isOrdered and "ordered:" or "profile:") .. name
    if buckets[key] then return buckets[key] end
    local data = {}
    local instance = {}
    function instance:UpdateAsync(entryKey, transform)
        -- Emulates only the UpdateAsync subset used by GROWLIVO.
        local previous = deepCopy(data[tostring(entryKey)])
        local updated = transform(previous)
        if updated == nil then return nil end -- cancellation leaves data untouched
        data[tostring(entryKey)] = deepCopy(updated)
        return deepCopy(updated)
    end
    if isOrdered then
        function instance:GetSortedAsync(ascending, pageSize)
            local rows = {}
            for entryKey, value in pairs(data) do
                table.insert(rows, {key = entryKey, value = value})
            end
            table.sort(rows, function(a, b)
                if a.value == b.value then return a.key < b.key end
                if ascending then return a.value < b.value end
                return a.value > b.value
            end)
            local page = {}
            for i = 1, math.min(#rows, pageSize) do
                table.insert(page, rows[i])
            end
            return {GetCurrentPage = function() return deepCopy(page) end}
        end
    end
    buckets[key] = instance
    return instance
end

local function unavailableStore(name, reason)
    local instance = {}
    local function fail()
        error("[GROWLIVO] Roblox DataStore unavailable for '" .. name .. "': " .. tostring(reason), 2)
    end
    instance.UpdateAsync = fail
    instance.GetSortedAsync = fail
    return instance
end

local function acquire(name, ordered)
    if unpublishedStudio then
        return memoryStore(name, ordered)
    end
    local method = ordered and "GetOrderedDataStore" or "GetDataStore"
    local ok, value = pcall(function()
        if ordered then
            return DataStoreService:GetOrderedDataStore(name)
        end
        return DataStoreService:GetDataStore(name)
    end)
    if ok then return value end
    warn("[GROWLIVO] " .. method .. " failed: " .. tostring(value))
    -- Never use ephemeral progression for published games, even inside Studio.
    -- Server profile loader retries and then denies access; ranks remain unavailable.
    return unavailableStore(name, value)
end

function Storage.GetDataStore(name) return acquire(name, false) end
function Storage.GetOrderedDataStore(name) return acquire(name, true) end

if unpublishedStudio then
    warn("[GROWLIVO] UNPUBLISHED STUDIO TEST: temporary memory only. " ..
        "Progress and rankings disappear after Stop. Publish a separate test game " ..
        "and enable Studio API Services to test real persistence.")
else
    print("[GROWLIVO] Persistent Roblox DataStore mode (no temporary fallback)")
end
return Storage
