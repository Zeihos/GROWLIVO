-- GROWLIVO / Economy, pets, worlds, daily goals, persistence / Alpha 0.9.32
-- ServerScriptService > GrowlivoServer [Script]
-- Only server mutates player balances, ownership, unlocks, quests and achievements.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Storage = require(game:GetService("ServerScriptService"):WaitForChild("GrowlivoStorage"))
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage:WaitForChild("GrowlivoConfig"))
local ProfileGuard = require(ServerScriptService:WaitForChild("GrowlivoProfileGuard"))
local PersistenceAudit = require(ServerScriptService:WaitForChild("GrowlivoPersistenceAudit"))
local SaveReceipt = require(ServerScriptService:WaitForChild("GrowlivoSaveReceipt"))
local Calendar = require(ServerScriptService:WaitForChild("GrowlivoCalendar"))
local store = Storage.GetDataStore(Config.DataStoreName)
local rng = Random.new()

-- Internal server signal: only records from successful profile loads/saves are ranked.
local confirmedSave = ServerScriptService:FindFirstChild("GROWLIVO_ConfirmedSave")
if not confirmedSave then
    confirmedSave = Instance.new("BindableEvent")
    confirmedSave.Name = "GROWLIVO_ConfirmedSave"
    confirmedSave.Parent = ServerScriptService
end
assert(confirmedSave:IsA("BindableEvent"), "GROWLIVO_ConfirmedSave must be BindableEvent")


local remotes = ReplicatedStorage:FindFirstChild("GROWLIVO_Remotes")
if not remotes then
    remotes = Instance.new("Folder")
    remotes.Name = "GROWLIVO_Remotes"
    remotes.Parent = ReplicatedStorage
end
local function remote(name)
    local found = remotes:FindFirstChild(name)
    assert(not found or found:IsA("RemoteEvent"), "Remote name collision: " .. name)
    if not found then
        found = Instance.new("RemoteEvent")
        found.Name = name
        found.Parent = remotes
    end
    return found
end
local Action = remote("Action")
local Feedback = remote("Feedback")
local PetState = remote("PetState")
remote("OpenEggShop")
local ProgressState = remote("ProgressState")
local EventState = remote("EventState")
local VisualEvent = remote("VisualEvent")
remote("OpenWorldMenu")

local profiles, saveBusy, lastClick, lastAction, lastPets, lastProgress = {}, {}, {}, {}, {}, {}
local nextAutosave = {} -- per-player jitter, avoids burst writes
local recoveringSave = {} -- a failed write is only recovered after UpdateAsync succeeds
local retryAttempts = {} -- consecutive failed save batches, per player
local remoteBuckets = {} -- per-player token bucket; never trust UI-side throttles
-- Weak player keys avoid retaining departed Player instances. Keep the completion
-- marker until the key is collected: BindToClose must not perform a second
-- release when PlayerRemoving already completed its final save.
local finalizing = setmetatable({}, {__mode = "k"}) -- serialize PlayerRemoving / BindToClose
local progressQueued, eventQueued, lastEvent = {}, {}, {}
local pendingTeleport = {} -- one build-wait per player; prevents many queued teleports
-- Transient rune expedition state; no persistence schema changes.
local runeSessions = {}
-- Auto tap state is session-only and keyed by player. Server controls all awards.
local autoTapEnabled = {}
local nextAutoTap = {}
-- Per-session combo: the client cannot submit streak counts or reward amounts.
local tapCombos = {}
local function recordManualCombo(player)
    local now = os.clock()
    local state = tapCombos[player]
    if not state or now - state.LastTap >= Config.TapCombo.WindowSeconds then
        state = {Count = 0, LastTap = now}
        tapCombos[player] = state
    end
    state.Count = math.min(Config.TapCombo.MaxStreak, state.Count + 1)
    state.LastTap = now
    local factor = Config.TapComboMultiplier(state.Count)
    player:SetAttribute("TapComboCount", state.Count)
    player:SetAttribute("TapComboMultiplier", factor)
    player:SetAttribute("TapComboExpiresAt", workspace:GetServerTimeNow() + Config.TapCombo.WindowSeconds)
    return factor
end
local function runeSession(player)
    local state = runeSessions[player]
    if not state then
        state = {WorldId = nil, Used = {}, Count = 0, Cooldowns = {}, BoostWorld = nil, BoostUntil = 0}
        runeSessions[player] = state
    end
    return state
end
local function runeBoostFor(player, worldId)
    local state = runeSessions[player]
    if state and state.BoostWorld == worldId and workspace:GetServerTimeNow() < state.BoostUntil then
        return Config.RuneTrial.BoostMultiplier
    end
    return 1
end
local function publishRune(player, worldId)
    local state = runeSession(player)
    local now = workspace:GetServerTimeNow()
    if state.WorldId ~= worldId then
        state.WorldId, state.Used, state.Count = worldId, {}, 0
    end
    player:SetAttribute("RuneCount", state.Count)
    -- The authoritative per-world activation mask is replicated only for UI guidance.
    -- 1 = first rune, 2 = second, 4 = third. The client never submits this value.
    local runeMask = 0
    for runeIndex = 1, Config.RuneTrial.Required do
        if state.Used[runeIndex] then
            runeMask += 2 ^ (runeIndex - 1)
        end
    end
    player:SetAttribute("RuneMask", runeMask)
    player:SetAttribute("RuneBoostUntil", state.BoostWorld == worldId and state.BoostUntil or 0)
    player:SetAttribute("RuneCooldownUntil", state.Cooldowns[worldId] or 0)
    player:SetAttribute("RuneBoostMultiplier", runeBoostFor(player, worldId))
end
local metrics = ServerScriptService:FindFirstChild("GROWLIVO_Diagnostics")
if not metrics then
    metrics = Instance.new("Folder")
    metrics.Name = "GROWLIVO_Diagnostics"
    metrics.Parent = ServerScriptService
end
for _, name in ipairs({"LoadFailures", "SaveFailures", "LostLocks", "SaveTimeouts",
    "AcceptedTaps", "UpgradesBought", "EggsOpened", "PetsFused", "RebirthsMade", "DailyClaims", "WeeklyClaims", "ConfirmedSaves",
    "ExitSaveFailures", "SaveRecoveries", "RemoteDrops", "SaveRetryBatches",
    "LastSaveMs", "MaxSaveMs", "ActiveSaves", "LateSaveCompletions", "ShutdownWaitTimeouts",
    "RejectedProfileLoads", "FutureProfileVersions", "RejectedProfileWrites",
    "AutosaveBusySkips", "RejectedSnapshotWrites", "WorldBuildWaitTimeouts", "RuneTrialsCompleted"}) do
    if metrics:GetAttribute(name) == nil then metrics:SetAttribute(name, 0) end
end
local function countError(name)
    metrics:SetAttribute(name, (metrics:GetAttribute(name) or 0) + 1)
end
-- Max 30 calls in a burst, refilling at 20 per second by default. In addition to
-- explicit click/purchase cooldowns, this bounds expensive GetPets/GetProgress spam.
local function allowRemote(player)
    local now = os.clock()
    local bucket = remoteBuckets[player]
    if not bucket then
        bucket = {Tokens = Config.RemoteBurstCapacity, At = now}
        remoteBuckets[player] = bucket
    end
    bucket.Tokens = math.min(Config.RemoteBurstCapacity,
        bucket.Tokens + math.max(0, now - bucket.At) * Config.RemoteTokensPerSecond)
    bucket.At = now
    if bucket.Tokens < 1 then
        countError("RemoteDrops")
        return false
    end
    bucket.Tokens -= 1
    return true
end
local MAX_PET_ID = 2000000000
local function int(value, default, minimum, maximum)
    if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
        return default
    end
    return math.clamp(math.floor(value), minimum, maximum)
end
local function dayUTC()
    return Calendar.DayKey()
end
local function weekUTC(now)
    return Calendar.WeekKey(now)
end
local function profileDefault()
    return {
        Version = Config.ProfileVersion,
        Clicks = 0, TotalClicks = 0, Gems = 0, TapLevel = 1, Rebirths = 0,
        Pets = {}, Equipped = {}, NextPetId = 1,
        HatchedTotal = 0, UnlockedWorlds = {SkyCrown = true}, World = "SkyCrown",
        DailyDay = dayUTC(), DailyClaimed = false, QuestProgress = {}, QuestClaimed = {},
        AchievementClaimed = {}, TutorialStep = 1, TutorialClicks = 0,
        Settings = table.clone(Config.DefaultSettings),
        WeeklyWeek = weekUTC(), WeeklyProgress = {}, WeeklyClaimed = {},
        StarfallProgress = 0, StarfallClaimed = false,
        ChestDay = dayUTC(), ChestClaimed = {},
    }
end
local function restore(raw)
    local p = profileDefault()
    if typeof(raw) ~= "table" then return p end
    p.Clicks = int(raw.Clicks, 0, 0, Config.MaxClickBalance)
    p.TotalClicks = int(raw.TotalClicks, 0, 0, Config.MaxTotalClicks)
    p.Gems = int(raw.Gems, 0, 0, Config.MaxGems)
    p.TapLevel = int(raw.TapLevel, 1, 1, Config.MaxTapLevel)
    p.Rebirths = int(raw.Rebirths, 0, 0, Config.MaxRebirths)
    p.HatchedTotal = int(raw.HatchedTotal, 0, 0, Config.MaxTotalClicks)
    local ids, largest = {}, 0
    if typeof(raw.Pets) == "table" then
        for _, entry in ipairs(raw.Pets) do
            if #p.Pets >= Config.MaxPetInventory then break end
            if typeof(entry) == "table" then
                local id = int(entry.Id, 0, 0, MAX_PET_ID)
                if id > 0 and not ids[id] and Config.FindPet(entry.Species) then
                    table.insert(p.Pets, {Id = id, Species = entry.Species})
                    ids[id] = true
                    largest = math.max(largest, id)
                end
            end
        end
    end
    local equipped = {}
    if typeof(raw.Equipped) == "table" then
        for _, idValue in ipairs(raw.Equipped) do
            if #p.Equipped >= Config.MaxEquippedPets then break end
            local id = int(idValue, 0, 0, MAX_PET_ID)
            if ids[id] and not equipped[id] then
                table.insert(p.Equipped, id)
                equipped[id] = true
            end
        end
    end
    p.NextPetId = math.max(largest + 1, int(raw.NextPetId, 1, 1, MAX_PET_ID + 1))
    -- Restore all known unlocked worlds, including new future additions.
    -- Preserve old saves (which only contain SkyCrown or CrystalVale).
    if typeof(raw.UnlockedWorlds) == "table" then
        for _, definition in ipairs(Config.Worlds) do
            if definition.Id ~= "SkyCrown" and raw.UnlockedWorlds[definition.Id] == true then
                p.UnlockedWorlds[definition.Id] = true
            end
        end
    end
    if typeof(raw.DailyDay) == "string" and string.match(raw.DailyDay, "^%d%d%d%d%-%d%d%-%d%d$") then
        p.DailyDay = raw.DailyDay
    end
    p.DailyClaimed = raw.DailyClaimed == true
    p.StarfallProgress = int(raw.StarfallProgress, 0, 0, Config.Starfall.Goal)
    p.StarfallClaimed = raw.StarfallClaimed == true
    if typeof(raw.ChestDay) == "string" and Calendar.IsValidKey(raw.ChestDay) then
        p.ChestDay = raw.ChestDay
    end
    if typeof(raw.ChestClaimed) == "table" then
        for worldId in pairs(Config.WorldChests) do
            if raw.ChestClaimed[worldId] == true then
                p.ChestClaimed[worldId] = true
            end
        end
    end
    if typeof(raw.QuestProgress) == "table" then
        for _, quest in ipairs(Config.Quests) do
            p.QuestProgress[quest.Id] = int(raw.QuestProgress[quest.Id], 0, 0, quest.Goal)
        end
    end
    if typeof(raw.QuestClaimed) == "table" then
        for _, quest in ipairs(Config.Quests) do
            if raw.QuestClaimed[quest.Id] == true then p.QuestClaimed[quest.Id] = true end
        end
    end
    if typeof(raw.WeeklyWeek) == "string" and string.match(raw.WeeklyWeek, "^%d%d%d%d%-%d%d%-%d%d$") then
        p.WeeklyWeek = raw.WeeklyWeek
    end
    if typeof(raw.WeeklyProgress) == "table" then
        for _, quest in ipairs(Config.WeeklyQuests) do
            p.WeeklyProgress[quest.Id] = int(raw.WeeklyProgress[quest.Id], 0, 0, quest.Goal)
        end
    end
    if typeof(raw.WeeklyClaimed) == "table" then
        for _, quest in ipairs(Config.WeeklyQuests) do
            if raw.WeeklyClaimed[quest.Id] == true then p.WeeklyClaimed[quest.Id] = true end
        end
    end
    if typeof(raw.AchievementClaimed) == "table" then
        for _, achievement in ipairs(Config.Achievements) do
            if raw.AchievementClaimed[achievement.Id] == true then
                p.AchievementClaimed[achievement.Id] = true
            end
        end
    end
    -- Tutorial migration: existing 0.3 players resume from their achieved milestone.
    if raw.TutorialStep ~= nil then
        p.TutorialStep = int(raw.TutorialStep, 1, 1, 4)
        p.TutorialClicks = int(raw.TutorialClicks, 0, 0, Config.TutorialClickGoal)
    else
        p.TutorialClicks = math.min(Config.TutorialClickGoal, p.TotalClicks)
        if p.HatchedTotal > 0 then
            p.TutorialStep = 4
        elseif p.TapLevel > 1 then
            p.TutorialStep = 3
        elseif p.TotalClicks >= Config.TutorialClickGoal then
            p.TutorialStep = 2
        end
    end
    if typeof(raw.Settings) == "table" then
        for key, defaultValue in pairs(Config.DefaultSettings) do
            if typeof(raw.Settings[key]) == "boolean" then
                p.Settings[key] = raw.Settings[key]
            else
                p.Settings[key] = defaultValue
            end
        end
    end
    -- World is intentionally session-only: every login starts at Sky Crown.
    return p
end
local function snapshot(p)
    local pets, equipped = {}, {}
    for _, pet in ipairs(p.Pets) do table.insert(pets, {Id = pet.Id, Species = pet.Species}) end
    for _, id in ipairs(p.Equipped) do table.insert(equipped, id) end
    return {
        Version = Config.ProfileVersion,
        Clicks = p.Clicks, TotalClicks = p.TotalClicks, Gems = p.Gems,
        TapLevel = p.TapLevel, Rebirths = p.Rebirths,
        Pets = pets, Equipped = equipped, NextPetId = p.NextPetId,
        HatchedTotal = p.HatchedTotal, UnlockedWorlds = table.clone(p.UnlockedWorlds),
        DailyDay = p.DailyDay, DailyClaimed = p.DailyClaimed,
        QuestProgress = table.clone(p.QuestProgress), QuestClaimed = table.clone(p.QuestClaimed),
        WeeklyWeek = p.WeeklyWeek, WeeklyProgress = table.clone(p.WeeklyProgress),
        WeeklyClaimed = table.clone(p.WeeklyClaimed),
        AchievementClaimed = table.clone(p.AchievementClaimed),
        TutorialStep = p.TutorialStep, TutorialClicks = p.TutorialClicks,
        Settings = table.clone(p.Settings),
        StarfallProgress = p.StarfallProgress, StarfallClaimed = p.StarfallClaimed,
        ChestDay = p.ChestDay, ChestClaimed = table.clone(p.ChestClaimed),
    }
end
local function notify(player, message) Feedback:FireClient(player, message) end
local function isReady(player)
    -- Pause all mutations while a save is in trouble. Never promise a player
    -- permanent progress when the backend cannot confirm writes.
    -- While PlayerRemoving / BindToClose releases the session lock, no more
    -- client economic actions may mutate the snapshot being committed.
    return finalizing[player] == nil and profiles[player] ~= nil
        and player:GetAttribute("DataReady") == true
        and player:GetAttribute("DataStatus") == "Ready"
        and profiles[player].CanSave == true
end
local function setDataStatus(player, status)
    -- An autosave may finish after finalSave() has begun waiting for it.
    -- Never show Ready/SaveRetry again during logout (or open a new action window).
    if finalizing[player] ~= nil and status ~= "Closing" and status ~= "Conflict" then
        countError("LateSaveCompletions")
        return
    end
    if player.Parent then
        player:SetAttribute("DataStatus", status)
        player:SetAttribute("SavingEnabled", status == "Ready")
    end
end
-- Exponential, jittered retries. A failed write never re-enables gameplay.
local function scheduleRetry(player)
    -- A finalSave() is already queued; it will handle the closing write.
    -- Do not schedule an autosave that may never run on a departing Player.
    if finalizing[player] ~= nil then return end
    recoveringSave[player] = true
    retryAttempts[player] = math.min(6, (retryAttempts[player] or 0) + 1)
    local multiplier = 2 ^ (retryAttempts[player] - 1)
    local delaySeconds = math.min(Config.SaveRetryMaxSeconds,
        Config.SaveRetrySeconds * multiplier) + rng:NextInteger(0, 3)
    nextAutosave[player] = os.clock() + delaySeconds
    countError("SaveRetryBatches")
    setDataStatus(player, "SaveRetry")
end
local function resetDaily(p)
    local today = dayUTC()
    if p.DailyDay ~= today and Calendar.ShouldAdvance(p.DailyDay, today) then
        p.DailyDay = today
        p.DailyClaimed = false
        p.QuestProgress = {}
        p.QuestClaimed = {}
        p.StarfallProgress = 0
        p.StarfallClaimed = false
        -- Even a passive UTC rollover can race an in-flight snapshot.
        SaveReceipt.MarkChanged(p)
        return true
    end
    return false
end
local function resetChests(p)
    local today = dayUTC()
    -- Never roll a claim back because of an incorrect server clock.
    if p.ChestDay ~= today and Calendar.ShouldAdvance(p.ChestDay, today) then
        p.ChestDay = today
        p.ChestClaimed = {}
        SaveReceipt.MarkChanged(p)
        return true
    end
    return false
end
local function resetWeekly(p)
    local currentWeek = weekUTC()
    if p.WeeklyWeek ~= currentWeek and Calendar.ShouldAdvance(p.WeeklyWeek, currentWeek) then
        p.WeeklyWeek = currentWeek
        p.WeeklyProgress = {}
        p.WeeklyClaimed = {}
        SaveReceipt.MarkChanged(p)
        return true
    end
    return false
end
local function progressPayload(p)
    local questData = {}
    for _, quest in ipairs(Config.Quests) do
        questData[quest.Id] = {
            Progress = math.min(quest.Goal, p.QuestProgress[quest.Id] or 0),
            Claimed = p.QuestClaimed[quest.Id] == true,
        }
    end
    local weeklyQuestData = {}
    for _, quest in ipairs(Config.WeeklyQuests) do
        weeklyQuestData[quest.Id] = {
            Progress = math.min(quest.Goal, p.WeeklyProgress[quest.Id] or 0),
            Claimed = p.WeeklyClaimed[quest.Id] == true,
        }
    end
    return {
        WeeklyWeek = p.WeeklyWeek, WeeklyQuests = weeklyQuestData,
        World = p.World,
        UnlockedWorlds = table.clone(p.UnlockedWorlds),
        Day = p.DailyDay, DailyClaimed = p.DailyClaimed,
        Quests = questData, Achievements = table.clone(p.AchievementClaimed),
        TotalClicks = p.TotalClicks, HatchedTotal = p.HatchedTotal, Rebirths = p.Rebirths,
    }
end
local function eventPayload(p)
    local active, remaining, multiplier = Config.StarfallAt(os.time())
    return {
        Name = Config.Starfall.Name, Active = active, SecondsLeft = remaining,
        Multiplier = multiplier, Goal = Config.Starfall.Goal,
        Progress = p.StarfallProgress, Claimed = p.StarfallClaimed,
        RewardClicks = Config.Starfall.RewardClicks,
        RewardGems = Config.Starfall.RewardGems, Day = p.DailyDay,
    }
end
local function pushEvent(player)
    local p = profiles[player]
    if p then EventState:FireClient(player, eventPayload(p)) end
end
local function queueEvent(player)
    if eventQueued[player] then return end
    eventQueued[player] = true
    task.delay(0.55, function()
        eventQueued[player] = nil
        if profiles[player] then pushEvent(player) end
    end)
end
local function pushProgress(player)
    local p = profiles[player]
    if not p then return end
    ProgressState:FireClient(player, progressPayload(p))
end
local function queueProgress(player)
    if progressQueued[player] then return end
    progressQueued[player] = true
    task.delay(0.5, function()
        progressQueued[player] = nil
        if profiles[player] then pushProgress(player) end
    end)
end
local function pushPets(player)
    local p = profiles[player]
    if not p then return end
    local pets, equipped = {}, {}
    for _, pet in ipairs(p.Pets) do table.insert(pets, {Id = pet.Id, Species = pet.Species}) end
    for _, id in ipairs(p.Equipped) do table.insert(equipped, id) end
    PetState:FireClient(player, pets, equipped)
end
-- Avoid rewriting identical replicated attributes on every accepted click.
-- Economy still changes exclusively on the server and updated numbers are
-- published immediately (no artificial delay in the clicker's HUD).
local function setPlayerAttribute(player, name, value)
    if player:GetAttribute(name) ~= value then
        player:SetAttribute(name, value)
    end
end
local function sync(player, trackMutation)
    local p = profiles[player]
    if not p then return end
    -- Pure UI refreshes (initial sync, changing Starfall display) do not
    -- create artificial dirty snapshots. Actual economy changes increment
    -- the serial; UTC daily/weekly rollovers increment it in reset functions.
    if trackMutation ~= false then
        SaveReceipt.MarkChanged(p)
    end
    -- A client-side Ready status only means that the profile is usable;
    -- it is not an acknowledgement that recent mutations reached DataStore.
    setPlayerAttribute(player, "UnsavedChanges",
        SaveReceipt.HasPending(p))
    local world = Config.FindWorld(p.World) or Config.Worlds[1]
    local bonus = Config.PetBonus(p.Pets, p.Equipped)
    local collectionBonus, speciesCount = Config.CollectionBonus(p.Pets)
    setPlayerAttribute(player, "CollectionBonus", collectionBonus)
    setPlayerAttribute(player, "CollectionSpecies", speciesCount)
    setPlayerAttribute(player, "Clicks", p.Clicks)
    setPlayerAttribute(player, "TotalClicks", p.TotalClicks)
    setPlayerAttribute(player, "Gems", p.Gems)
    setPlayerAttribute(player, "TapLevel", p.TapLevel)
    setPlayerAttribute(player, "Rebirths", p.Rebirths)
    setPlayerAttribute(player, "AutoTapUnlocked", p.Rebirths >= Config.AutoTap.UnlockRebirths)
    setPlayerAttribute(player, "PetBonus", bonus)
    setPlayerAttribute(player, "PetCount", #p.Pets)
    setPlayerAttribute(player, "EquippedCount", #p.Equipped)
    setPlayerAttribute(player, "World", p.World)
    setPlayerAttribute(player, "ChestDay", p.ChestDay)
    setPlayerAttribute(player, "ChestClaimed", p.ChestClaimed[p.World] == true)
    setPlayerAttribute(player, "WorldMultiplier", world.Multiplier)
    publishRune(player, p.World)
    local _, _, eventMultiplier = Config.StarfallAt(os.time())
    setPlayerAttribute(player, "EventMultiplier", eventMultiplier)
    setPlayerAttribute(player, "ClickPower", Config.ClickPower(p.TapLevel, p.Rebirths, bonus + collectionBonus, world.Multiplier) * eventMultiplier * runeBoostFor(player, p.World))
    setPlayerAttribute(player, "TutorialStep", p.TutorialStep)
    setPlayerAttribute(player, "TutorialClicks", p.TutorialClicks)
    for key, enabled in pairs(p.Settings) do
        setPlayerAttribute(player, "Setting" .. key, enabled)
    end
    local board = player:FindFirstChild("leaderstats")
    if board then
        local clicks, rebirths = board:FindFirstChild("Clicks"), board:FindFirstChild("Rebirths")
        if clicks then clicks.Value = p.Clicks end
        if rebirths then rebirths.Value = p.Rebirths end
    end
end

-- Session lock is stored directly in the existing v1 value to preserve 0.1/0.2 profiles.
-- Do NOT run old server versions against the same live store: they ignore this lock.
local function acquireProfile(player)
    local key = "player_" .. tostring(player.UserId)
    local token = HttpService:GenerateGUID(false)
    local loaded, locked, rejected = nil, false, nil
    local latestError = "unknown"
    for attempt = 1, 3 do
        local denialReason = nil
        local ok, value = pcall(function()
            return store:UpdateAsync(key, function(raw)
                local valid, reason = ProfileGuard.Validate(raw, Config)
                if not valid then
                    denialReason = reason
                    return nil -- leave existing bytes untouched
                end
                local current = raw or {}
                local lock = current.__Session
                local now = os.time()
                if typeof(lock) == "table" and typeof(lock.Id) == "string"
                    and lock.Id ~= token and int(lock.Expires, 0, 0, 4102444800) > now then
                    denialReason = "Locked"
                    return nil
                end
                local output = table.clone(current)
                output.__Session = {Id = token, Expires = now + Config.SessionLockSeconds}
                return output
            end)
        end)
        if ok then
            if value == nil then
                if denialReason == "Locked" then
                    locked = true
                else
                    rejected = denialReason or "CancelledWrite"
                end
                break
            end
            loaded = restore(value)
            loaded.CanSave = true
            loaded.LockToken = token
            break
        end
        latestError = tostring(value)
        if attempt < 3 then task.wait(attempt * 1.5) end
    end
    if locked then return nil, "locked" end
    if rejected then
        countError("RejectedProfileLoads")
        if rejected == "FutureVersion" then countError("FutureProfileVersions") end
        warn("[GROWLIVO] Unsafe stored profile rejected without modification: "
            .. player.UserId .. " / " .. rejected)
        return nil, rejected == "FutureVersion" and "future" or "invalid"
    end
    if loaded then return loaded, nil end
    countError("LoadFailures")
    warn("[GROWLIVO] Load failed / entry denied: " .. player.UserId .. " / " .. latestError)
    -- Fail closed: allowing gameplay on a temporary account can result in lost
    -- purchases, pets and rewards. Do not create a fake saveable profile.
    return nil, "offline"
end

local function save(player, release)
    local p = profiles[player]
    if not p or not p.CanSave then return end
    -- Per-key serialization prevents an older retry overwriting a newer snapshot.
    local waitedFrom = os.clock()
    while saveBusy[player] do
        if os.clock() - waitedFrom > Config.SaveWaitTimeoutSeconds then
            countError("SaveTimeouts")
            warn("[GROWLIVO] Save wait exceeded for " .. player.UserId)
            if release then
                countError("ExitSaveFailures")
            else
                scheduleRetry(player)
            end
            return
        end
        task.wait(0.12)
    end
    -- Validate the NEW snapshot before the first DataStore API call. Checking only
    -- the old value inside UpdateAsync is not sufficient: a future bug in economy
    -- code could otherwise persist malformed numbers, pets or oversized JSON.
    -- Even constructing the snapshot may fail if a future bug corrupts an
    -- in-memory table. Never let that crash silently during PlayerRemoving.
    local madeSnapshot, value = pcall(snapshot, p)
    local validSnapshot, rejectReason = false, "SnapshotBuildFailed"
    if madeSnapshot then
        local auditOk, accepted, detail = pcall(PersistenceAudit.Validate, value, Config)
        if auditOk then
            validSnapshot, rejectReason = accepted, detail
        else
            rejectReason = "AuditException:" .. tostring(accepted)
        end
    else
        rejectReason = "SnapshotBuildFailed:" .. tostring(value)
    end
    if not validSnapshot then
        p.CanSave = false
        countError("RejectedSnapshotWrites")
        if release then countError("ExitSaveFailures") end
        warn("[GROWLIVO] INVALID OUTGOING SNAPSHOT (not written): "
            .. tostring(player.UserId) .. " / " .. tostring(rejectReason))
        setDataStatus(player, "Conflict")
        if player.Parent then
            player:Kick("GROWLIVO: ошибка проверки прогресса. Данные не перезаписаны; обратитесь к разработчику.")
        end
        return
    end
    saveBusy[player] = true
    local saveStarted = os.clock()
    metrics:SetAttribute("ActiveSaves", (metrics:GetAttribute("ActiveSaves") or 0) + 1)
    local writtenSerial = SaveReceipt.BeginSnapshot(p)
    local token, key = p.LockToken, "player_" .. tostring(player.UserId)
    local success, response
    local guardRejected = nil
    for attempt = 1, 3 do
        guardRejected = nil
        success, response = pcall(function()
            return store:UpdateAsync(key, function(raw)
                local valid, reason = ProfileGuard.Validate(raw, Config)
                if not valid then
                    guardRejected = reason
                    return nil
                end
                local current = raw or {}
                local lock = current.__Session
                if typeof(lock) ~= "table" or lock.Id ~= token then return nil end
                local updated = table.clone(value)
                if not release then
                    updated.__Session = {Id = token, Expires = os.time() + Config.SessionLockSeconds}
                end
                return updated
            end)
        end)
        if success then break end
        if attempt < 3 then task.wait(attempt * 1.5) end
    end
    if not success then
        countError("SaveFailures")
        if release then
            countError("ExitSaveFailures")
            warn("[GROWLIVO] EXIT SAVE FAILED: " .. player.UserId ..
                " / progress from this session may not have been written")
        else
            scheduleRetry(player)
        end
        warn("[GROWLIVO] Save failed: " .. player.UserId .. " / " .. tostring(response))
    elseif response == nil then
        if guardRejected then
            countError("RejectedProfileWrites")
            warn("[GROWLIVO] Save rejected without modifying unsafe stored profile: "
                .. player.UserId .. " / " .. guardRejected)
        end
        p.CanSave = false
        setDataStatus(player, "Conflict")
        countError("LostLocks")
        if release then
            countError("ExitSaveFailures")
            warn("[GROWLIVO] EXIT SAVE CONFLICT: " .. player.UserId ..
                " / another session owns this profile; latest progress may be lost")
        end
        warn("[GROWLIVO] Session lock lost: " .. player.UserId)
        -- The lock may belong to another server. Do not permit further writes.
        if player.Parent then
            player:Kick("GROWLIVO: конфликт сохранения. Войдите повторно позже.")
        end
    else
        countError("ConfirmedSaves")
        retryAttempts[player] = nil
        if recoveringSave[player] then
            recoveringSave[player] = nil
            countError("SaveRecoveries")
            warn("[GROWLIVO] Save recovered for " .. player.UserId)
        end
        -- Server acknowledgement: mark only the snapshot that actually made
        -- it to DataStore as committed. A click during UpdateAsync remains dirty.
        local pendingChanges = SaveReceipt.Commit(p, writtenSerial)
        setPlayerAttribute(player, "LastConfirmedSaveAt", os.time())
        setPlayerAttribute(player, "UnsavedChanges", pendingChanges)
        if not release then
            setDataStatus(player, "Ready")
            if pendingChanges then
                -- A player may have clicked during UpdateAsync's yield.
                -- Keep the successful snapshot, but flush the newer state soon.
                nextAutosave[player] = math.min(nextAutosave[player] or math.huge,
                    os.clock() + Config.DirtySaveDelaySeconds)
            end
        end
        confirmedSave:Fire(player.UserId, value.TotalClicks, value.Rebirths)
    end
    -- Studio-visible write duration counters; no extra DataStore requests.
    local elapsedMs = math.floor(math.max(0, os.clock() - saveStarted) * 1000)
    metrics:SetAttribute("LastSaveMs", elapsedMs)
    metrics:SetAttribute("MaxSaveMs", math.max(elapsedMs, metrics:GetAttribute("MaxSaveMs") or 0))
    metrics:SetAttribute("ActiveSaves", math.max(0, (metrics:GetAttribute("ActiveSaves") or 0) - 1))
    saveBusy[player] = nil
end
local function initBoard(player)
    local existing = player:FindFirstChild("leaderstats")
    if existing then existing:Destroy() end
    local folder = Instance.new("Folder")
    folder.Name = "leaderstats"
    folder.Parent = player
    for _, name in ipairs({"Clicks", "Rebirths"}) do
        local n = Instance.new("NumberValue")
        n.Name = name
        n.Parent = folder
    end
end
-- Startup order is not guaranteed: the world builder can still be generating
-- islands when the first profile finishes loading. Never teleport players into
-- unbuilt terrain. Coalesce startup requests and resolve the latest world.
local function teleport(player, worldId)
    local destinations = {
        SkyCrown = CFrame.new(0, 7, 29),
        CrystalVale = CFrame.new(355, 7, 22),
        AuroraGrove = CFrame.new(-355, 7, 25),
    }
    local destination = destinations[worldId]
    if not destination then return end
    local built = workspace:FindFirstChild("GROWLIVO_World")
    if built and built:GetAttribute("WorldReady") == true then
        local character = player.Character
        if character then character:PivotTo(destination) end
        return
    end
    if pendingTeleport[player] then return end
    pendingTeleport[player] = true
    task.spawn(function()
        local deadline = os.clock() + 30
        while player.Parent and os.clock() < deadline do
            local world = workspace:FindFirstChild("GROWLIVO_World")
            if world and world:GetAttribute("WorldReady") == true then break end
            task.wait(0.25)
        end
        pendingTeleport[player] = nil
        if not player.Parent or not isReady(player) then return end
        local world = workspace:FindFirstChild("GROWLIVO_World")
        if not world or world:GetAttribute("WorldReady") ~= true then
            countError("WorldBuildWaitTimeouts")
            warn("[GROWLIVO] World not ready: teleport skipped for " .. player.UserId)
            return
        end
        -- The player may have chosen another world while we waited.
        local profile = profiles[player]
        local latest = profile and destinations[profile.World]
        if latest and player.Character then player.Character:PivotTo(latest) end
    end)
end
local function addQuest(p, kind)
    resetDaily(p)
    resetWeekly(p)
    for _, quest in ipairs(Config.Quests) do
        if quest.Event == kind and not p.QuestClaimed[quest.Id] then
            p.QuestProgress[quest.Id] = math.min(quest.Goal, (p.QuestProgress[quest.Id] or 0) + 1)
        end
    end
    for _, quest in ipairs(Config.WeeklyQuests) do
        if quest.Event == kind and not p.WeeklyClaimed[quest.Id] then
            p.WeeklyProgress[quest.Id] = math.min(quest.Goal, (p.WeeklyProgress[quest.Id] or 0) + 1)
        end
    end
end
local function addGems(p, amount)
    p.Gems = math.min(Config.MaxGems, p.Gems + amount)
end
-- Server-owned onboarding state, persisted with the existing profile.
-- 1 = 20 manual taps; 2 = first upgrade; 3 = first hatch; 4 = complete.
local function tutorialAdvance(player, p, kind)
    local previous = p.TutorialStep
    if previous == 1 and kind == "Tap" then
        p.TutorialClicks = math.min(Config.TutorialClickGoal, p.TutorialClicks + 1)
        if p.TutorialClicks >= Config.TutorialClickGoal then p.TutorialStep = 2 end
    elseif previous == 2 and kind == "Upgrade" then
        p.TutorialStep = 3
    elseif previous == 3 and kind == "Hatch" then
        p.TutorialStep = 4
        p.Clicks = math.min(Config.MaxClickBalance, p.Clicks + 200)
        addGems(p, 5)
        notify(player, "Обучение пройдено! +200 кликов и +5 кристаллов")
    end
    if p.TutorialStep ~= previous then
        VisualEvent:FireClient(player, {Type = "TutorialStep", Step = p.TutorialStep})
    end
end
-- Server-authoritative single and triple hatch. All costs/capacity are checked
-- before spending; no client-selected species, chance or price are accepted.
local function hatch(player, p, quantity)
    if quantity ~= 1 and quantity ~= Config.MaxHatchBatch then return false end
    local egg = Config.EggForWorld(p.World)
    if not egg then return false end
    local totalCost = egg.Price * quantity
    if #p.Pets + quantity > Config.MaxPetInventory then
        notify(player, "Недостаточно места для " .. quantity .. " питомцев")
        return false
    end
    if p.NextPetId + quantity - 1 > MAX_PET_ID then
        notify(player, "Достигнут лимит ID питомцев")
        return false
    end
    if p.Clicks < totalCost then
        notify(player, "Не хватает кликов: нужно " .. totalCost)
        return false
    end
    local results = {}
    for i = 1, quantity do
        local roll, cumulative, selected = rng:NextInteger(1, 100), 0, nil
        for _, drop in ipairs(egg.Drops) do
            cumulative += drop.Chance
            if roll <= cumulative then selected = Config.FindPet(drop.Species) break end
        end
        if not selected then return false end
        table.insert(results, selected)
    end
    p.Clicks -= totalCost
    for _, selected in ipairs(results) do
        local petId = p.NextPetId
        table.insert(p.Pets, {Id = petId, Species = selected.Id})
        if #p.Equipped < Config.MaxEquippedPets then
            table.insert(p.Equipped, petId)
        end
        p.NextPetId += 1
        p.HatchedTotal = math.min(Config.MaxTotalClicks, p.HatchedTotal + 1)
        addQuest(p, "Hatch")
        countError("EggsOpened")
        VisualEvent:FireClient(player, {Type = "Hatch", Species = selected.Id})
    end
    tutorialAdvance(player, p, "Hatch")
    notify(player, quantity == 1 and ("Новый питомец: " .. results[1].Name)
        or ("Открыто яиц: " .. quantity .. "! Инвентарь обновлён"))
    return true
end
local function equip(player, p, requestedId)
    if typeof(requestedId) ~= "number" or requestedId ~= math.floor(requestedId) then return false end
    local id = int(requestedId, 0, 1, MAX_PET_ID)
    local owned = false
    for _, pet in ipairs(p.Pets) do if pet.Id == id then owned = true break end end
    if not owned then return false end
    for index, equippedId in ipairs(p.Equipped) do
        if equippedId == id then
            table.remove(p.Equipped, index)
            notify(player, "Питомец снят")
            return true
        end
    end
    if #p.Equipped >= Config.MaxEquippedPets then notify(player, "Можно надеть не более 3 питомцев") return false end
    table.insert(p.Equipped, id)
    notify(player, "Питомец экипирован")
    return true
end
local function equipBest(player, p)
    local sorted = table.clone(p.Pets)
    table.sort(sorted, function(a, b)
        local x, y = Config.FindPet(a.Species), Config.FindPet(b.Species)
        local bonusA, bonusB = x and x.Bonus or 0, y and y.Bonus or 0
        if bonusA == bonusB then return a.Id < b.Id end
        return bonusA > bonusB
    end)
    table.clear(p.Equipped)
    for i = 1, math.min(#sorted, Config.MaxEquippedPets) do table.insert(p.Equipped, sorted[i].Id) end
    notify(player, "Экипированы лучшие питомцы")
    return true
end
-- Bulk unequip only changes the player's equipped IDs. No client-provided IDs
-- or inventory data are trusted, and the existing pet ownership remains intact.
local function unequipAll(player, p)
    if #p.Equipped == 0 then
        notify(player, "Нет надетых питомцев")
        return false
    end
    table.clear(p.Equipped)
    notify(player, "Все питомцы сняты")
    return true
end
-- Inventory maintenance: without releasing pets a player who reaches the
-- inventory cap can never hatch an egg again. Never trust a client-supplied
-- species or position; the server resolves a pet by its owned numeric ID.
-- Equipped pets must be taken off first, preventing accidental loss of bonuses.
local function releasePet(player, p, requestedId)
    if typeof(requestedId) ~= "number" or requestedId ~= requestedId
        or requestedId == math.huge or requestedId == -math.huge
        or requestedId ~= math.floor(requestedId)
        or requestedId < 1 or requestedId > MAX_PET_ID then
        return false
    end
    for _, equippedId in ipairs(p.Equipped) do
        if equippedId == requestedId then
            notify(player, "Сначала сними питомца, прежде чем отпускать его")
            return false
        end
    end
    for index, pet in ipairs(p.Pets) do
        if pet.Id == requestedId then
            table.remove(p.Pets, index)
            -- Do not decrement NextPetId or HatchedTotal: old IDs must never
            -- be recycled and achievements count lifetime hatches.
            notify(player, "Питомец отпущен. Освобождено место в инвентаре")
            return true
        end
    end
    return false
end


-- Fusion is an atomic server-side inventory exchange, with no client-provided
-- pet IDs or target rarity. Equipped pets are protected, and no reward counter
-- is incremented: fusion is not a hatch and gives no quest progress.
-- Both actions use a single transactional mutation. Safe MAX preserves one
-- copy of the source species across equipped and unequipped pets, protecting
-- collection bonuses. Ordinary fusion remains available for intentional use.
-- Neither action trusts a client-selected count or target species.
local function fusePets(player, p, requestedSpecies, fuseMax)
    if typeof(requestedSpecies) ~= "string" or #requestedSpecies > 40 then return false end
    local result = Config.FusionResult(requestedSpecies)
    if not result then
        notify(player, "Этот питомец достиг высшей ступени слияния")
        return false
    end
    local protected = {}
    for _, id in ipairs(p.Equipped) do protected[id] = true end
    local indexes = {}
    for index, item in ipairs(p.Pets) do
        if item.Species == requestedSpecies and not protected[item.Id] then
            table.insert(indexes, index)
            if not fuseMax and #indexes == Config.FusionRequired then break end
        end
    end
    local batches = fuseMax
        and Config.SafeFusionBatches(p.Pets, p.Equipped, requestedSpecies)
        or math.floor(#indexes / Config.FusionRequired)
    if batches < 1 then
        notify(player, fuseMax
            and "Нет безопасных групп для ×MAX: последний питомец вида защищён"
            or "Нужно 3 одинаковых СНЯТЫХ питомца для слияния")
        return false
    end
    -- Existing inventory cap bounds MAX batches (60 pets -> at most 20).
    -- Refuse the whole operation if new unique pet IDs would overflow.
    if p.NextPetId + batches - 1 > MAX_PET_ID then
        notify(player, "Недостаточно свободных ID питомцев для слияния")
        return false
    end
    -- Remove exactly the required source pets, descending by array index.
    -- MAX reserves one un-equipped source pet if no equipped copy exists.
    -- All equipped pets and other species remain untouched.
    for i = batches * Config.FusionRequired, 1, -1 do
        table.remove(p.Pets, indexes[i])
    end
    for _ = 1, batches do
        local newId = p.NextPetId
        p.NextPetId += 1
        table.insert(p.Pets, {Id = newId, Species = result.Id})
        if #p.Equipped < Config.MaxEquippedPets then
            table.insert(p.Equipped, newId)
        end
        countError("PetsFused")
    end
    -- A single visual event prevents a burst of hatch/fusion effects.
    VisualEvent:FireClient(player, {Type = "Fusion", Species = result.Id})
    notify(player, "Слияние ×" .. batches .. " — получен: " .. result.Name
        .. " (" .. batches .. " шт.)")
    return true
end

-- Shared award path for manual and automatic taps. Neither accepts client amounts.
-- Update all quests, events, tutorial progress, and persistence through this path.
local function awardTap(player, p, manual)
    -- Auto taps use base power and never add to a manual streak.
    local comboMultiplier = manual and recordManualCombo(player) or 1
    local dayChanged = resetDaily(p)
    local weekChanged = resetWeekly(p)
    local world = Config.FindWorld(p.World) or Config.Worlds[1]
    local active, _, eventMultiplier = Config.StarfallAt(os.time())
    local power = Config.ClickPower(p.TapLevel, p.Rebirths,
        Config.PetBonus(p.Pets, p.Equipped) + Config.CollectionBonus(p.Pets), world.Multiplier)
        * eventMultiplier * runeBoostFor(player, p.World)
    power = math.max(1, math.floor(power * comboMultiplier))
    if active and not p.StarfallClaimed then
        p.StarfallProgress = math.min(Config.Starfall.Goal, p.StarfallProgress + 1)
        if p.StarfallProgress % 10 == 0 or p.StarfallProgress == Config.Starfall.Goal then
            queueEvent(player)
        end
    end
    if dayChanged then queueEvent(player) end
    if weekChanged then queueProgress(player) end
    countError("AcceptedTaps")
    p.Clicks = math.min(Config.MaxClickBalance, p.Clicks + power)
    p.TotalClicks = math.min(Config.MaxTotalClicks, p.TotalClicks + power)
    addQuest(p, "Tap")
    tutorialAdvance(player, p, "Tap")
    sync(player)
    queueProgress(player)
end

local function handleAction(player, actionName, argument)
    if typeof(actionName) ~= "string" or #actionName > 32 then return end
    if not allowRemote(player) then return end
    local p = profiles[player]
    if not p or not isReady(player) then return end
    if actionName == "ToggleAutoTap" then
        if p.Rebirths < Config.AutoTap.UnlockRebirths then
            notify(player, "Автокликер откроется после " .. Config.AutoTap.UnlockRebirths .. " перерождений")
            return
        end
        local enabled = autoTapEnabled[player] ~= true
        autoTapEnabled[player] = enabled
        nextAutoTap[player] = enabled and (os.clock() + Config.AutoTap.IntervalSeconds) or nil
        player:SetAttribute("AutoTapEnabled", enabled)
        notify(player, enabled and "Автокликер включён" or "Автокликер выключен")
        return
    end
    if actionName == "GetPets" then
        local now = os.clock()
        if now - (lastPets[player] or -100) < 0.3 then return end
        lastPets[player] = now
        pushPets(player)
        return
    end
    if actionName == "GetProgress" then
        local now = os.clock()
        if now - (lastProgress[player] or -100) < 0.3 then return end
        lastProgress[player] = now
        local dailyChanged = resetDaily(p)
        local weeklyChanged = resetWeekly(p)
        if dailyChanged or weeklyChanged then sync(player, false) end
        pushProgress(player)
        return
    end
    if actionName == "GetEvent" then
        local now = os.clock()
        if now - (lastEvent[player] or -100) < 1 then return end
        lastEvent[player] = now
        if resetDaily(p) then
            sync(player, false)
            pushProgress(player)
        end
        pushEvent(player)
        return
    end
    if actionName == "Click" then
        local now = os.clock()
        if now - (lastClick[player] or -100) < 1 / Config.MaxClicksPerSecond then return end
        lastClick[player] = now
        awardTap(player, p, true)
        return
    end
    local now = os.clock()
    if now - (lastAction[player] or -100) < 0.18 then return end
    lastAction[player] = now
    local dayChanged = resetDaily(p)
    local weekChanged = resetWeekly(p)
    if dayChanged or weekChanged then
        sync(player, false)
        queueProgress(player)
        if dayChanged then queueEvent(player) end
    end
    local changed, petsChanged, progressChanged, uiChanged = false, false, false, false
    if actionName == "SetSetting" then
        -- Only named boolean preferences may be written by clients.
        if typeof(argument) ~= "table" or typeof(argument.Key) ~= "string"
            or typeof(argument.Value) ~= "boolean" then return end
        if Config.DefaultSettings[argument.Key] == nil then return end
        if p.Settings[argument.Key] ~= argument.Value then
            p.Settings[argument.Key] = argument.Value
            changed = true
        end
    elseif actionName == "Upgrade" or actionName == "Upgrade5"
        or actionName == "UpgradeMax" then
        -- Never accept a client-supplied number or price. Determine the entire
        -- batch cost here, then charge and award it as one atomic transaction.
        local cost, levels
        if actionName == "UpgradeMax" then
            cost, levels = Config.UpgradeAffordableCost(p.TapLevel, p.Clicks)
        else
            local requested = actionName == "Upgrade5" and Config.BulkUpgradeCount or 1
            cost, levels = Config.UpgradeBundleCost(p.TapLevel, requested)
        end
        if not cost then
            notify(player, p.TapLevel >= Config.MaxTapLevel
                and "Сила клика максимальная" or "Не хватает кликов")
        elseif p.Clicks < cost then
            notify(player, "Не хватает кликов для " .. levels .. " улучшений")
        else
            p.Clicks -= cost
            p.TapLevel += levels
            -- Each purchased level counts for quests and telemetry, even when
            -- the whole batch is persisted with a single dirty snapshot.
            for _ = 1, levels do
                countError("UpgradesBought")
                addQuest(p, "Upgrade")
            end
            tutorialAdvance(player, p, "Upgrade")
            changed, progressChanged = true, true
            notify(player, "Приобретено улучшений: " .. levels)
        end
    elseif actionName == "Rebirth" then
        local cost = Config.RebirthCost(p.Rebirths)
        if not cost then notify(player, "Лимит перерождений достигнут")
        elseif p.Clicks < cost then notify(player, "Не хватает кликов")
        else
            p.Clicks = 0
            p.TapLevel = 1
            addGems(p, Config.RebirthGemReward(p.Rebirths))
            p.Rebirths += 1
            countError("RebirthsMade")
            addQuest(p, "Rebirth")
            changed, progressChanged = true, true
            notify(player, "Перерождение! Получены кристаллы")
            VisualEvent:FireClient(player, {Type = "Rebirth"})
        end
    elseif actionName == "Hatch" or actionName == "Hatch3" then
        changed = hatch(player, p, actionName == "Hatch3" and Config.MaxHatchBatch or 1)
        petsChanged, progressChanged = changed, changed
    elseif actionName == "ToggleEquip" then
        changed = equip(player, p, argument)
        petsChanged = changed
    elseif actionName == "EquipBest" then
        changed = equipBest(player, p)
        petsChanged = changed
    elseif actionName == "UnequipAll" then
        changed = unequipAll(player, p)
        petsChanged = changed
    elseif actionName == "ReleasePet" then
        changed = releasePet(player, p, argument)
        petsChanged = changed
    elseif actionName == "FusePets" or actionName == "FusePetsMax" then
        changed = fusePets(player, p, argument, actionName == "FusePetsMax")
        petsChanged = changed
    elseif actionName == "ClaimEvent" then
        -- Claim is possible after the active window, but only before UTC midnight.
        if p.StarfallClaimed then
            notify(player, "Награда события уже получена")
        elseif p.StarfallProgress < Config.Starfall.Goal then
            notify(player, "Сначала выполни цель события")
        else
            p.StarfallClaimed = true
            p.Clicks = math.min(Config.MaxClickBalance, p.Clicks + Config.Starfall.RewardClicks)
            addGems(p, Config.Starfall.RewardGems)
            changed = true
            queueEvent(player)
            VisualEvent:FireClient(player, {Type = "EventReward"})
            notify(player, "Звёздный дождь: награда получена!")
        end
    elseif actionName == "ClaimDaily" then
        if p.DailyClaimed then notify(player, "Награда за сегодня уже получена")
        else
            p.DailyClaimed = true
            countError("DailyClaims")
            p.Clicks = math.min(Config.MaxClickBalance, p.Clicks + Config.DailyReward.Clicks)
            addGems(p, Config.DailyReward.Gems)
            changed, progressChanged = true, true
            notify(player, "Ежедневная награда: +300 кликов, +10 кристаллов")
        end
    elseif actionName == "ClaimQuest" then
        local quest = Config.FindQuest(argument)
        if quest and not p.QuestClaimed[quest.Id] and (p.QuestProgress[quest.Id] or 0) >= quest.Goal then
            p.QuestClaimed[quest.Id] = true
            addGems(p, quest.Gems)
            changed, progressChanged = true, true
            notify(player, "Задание выполнено! +" .. quest.Gems .. " кристаллов")
        end
    elseif actionName == "ClaimWeeklyQuest" then
        local quest = Config.FindWeeklyQuest(argument)
        if quest and not p.WeeklyClaimed[quest.Id]
            and (p.WeeklyProgress[quest.Id] or 0) >= quest.Goal then
            p.WeeklyClaimed[quest.Id] = true
            addGems(p, quest.Gems)
            countError("WeeklyClaims")
            changed, progressChanged = true, true
            VisualEvent:FireClient(player, {Type = "WeeklyReward"})
            notify(player, "Недельное задание! +" .. quest.Gems .. " кристаллов")
        end
    elseif actionName == "ClaimAchievement" then
        local achievement = Config.FindAchievement(argument)
        if achievement and not p.AchievementClaimed[achievement.Id]
            and (p[achievement.Stat] or 0) >= achievement.Goal then
            p.AchievementClaimed[achievement.Id] = true
            addGems(p, achievement.Gems)
            changed, progressChanged = true, true
            notify(player, "Достижение! +" .. achievement.Gems .. " кристаллов")
        end
    elseif actionName == "UnlockWorld" then
        local world = Config.FindWorld(argument)
        if world and world.Id ~= "SkyCrown" then
            if p.UnlockedWorlds[world.Id] then notify(player, "Мир уже открыт")
            elseif p.Rebirths < world.UnlockRebirths then notify(player, "Нужно перерождений: " .. world.UnlockRebirths)
            elseif p.Gems < world.UnlockGems then notify(player, "Не хватает кристаллов")
            else
                p.Gems -= world.UnlockGems
                p.UnlockedWorlds[world.Id] = true
                changed, progressChanged = true, true
                notify(player, "Открыт мир: " .. world.Name)
                VisualEvent:FireClient(player, {Type = "WorldUnlock", World = world.Id})
            end
        end
    elseif actionName == "Travel" then
        local world = Config.FindWorld(argument)
        if world and (world.Id == "SkyCrown" or p.UnlockedWorlds[world.Id]) then
            if p.World ~= world.Id then
                p.World = world.Id
                uiChanged, progressChanged = true, true
            end
            teleport(player, p.World)
            -- World is session-only, so travelling must NOT mark DataStore dirty.
            notify(player, world.Name .. "  •  клики x" .. tostring(world.Multiplier))
        else
            notify(player, "Сначала открой этот мир")
        end
    else
        return
    end
    if changed then
        sync(player)
    elseif uiChanged then
        sync(player, false)
    end
    if petsChanged then pushPets(player) end
    if progressChanged then pushProgress(player) end
end
Action.OnServerEvent:Connect(handleAction)

-- Per-world daily chests. Server owns proximity, world eligibility, payouts
-- and the UTC claim flag. No RemoteEvent accepts a client-supplied reward.
local function openWorldChest(player, chest)
    if not isReady(player) or player.Parent ~= Players then return end
    local p = profiles[player]
    local worldId = chest:GetAttribute("ChestWorld")
    local rewards = Config.WorldChests[worldId]
    if not rewards or p.World ~= worldId or p.UnlockedWorlds[worldId] ~= true then return end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then return end
    if (root.Position - chest.Position).Magnitude > Config.ChestCollectRadius then return end
    resetChests(p)
    if p.ChestClaimed[worldId] then
        notify(player, "Сундук этого мира уже получен сегодня. Возвращайся завтра (UTC)!")
        sync(player, false)
        return
    end
    p.ChestClaimed[worldId] = true -- mark before grant; no yields in this transaction
    p.Clicks = math.min(Config.MaxClickBalance, p.Clicks + rewards.Clicks)
    addGems(p, rewards.Gems)
    sync(player) -- one dirty update for claimed flag and both balances
    notify(player, "Сундук открыт! +" .. rewards.Clicks .. " кликов, +" .. rewards.Gems .. " кристаллов")
    VisualEvent:FireClient(player, {Type = "WorldChest", World = worldId})
end

task.spawn(function()
    local map = workspace:WaitForChild("GROWLIVO_World", 40)
    if not map then warn("[GROWLIVO] Chest connection: world missing"); return end
    -- The world builder creates its container before all chests are inserted.
    -- Wait for the final ready marker, otherwise some Prompts can be missed.
    local deadline = os.clock() + 40
    while map:GetAttribute("WorldReady") ~= true and os.clock() < deadline do
        task.wait(0.1)
    end
    if map:GetAttribute("WorldReady") ~= true then
        warn("[GROWLIVO] Chest connection: world build timed out")
        return
    end
    local group = map:WaitForChild("11_WORLD_CHESTS", 5)
    if not group then warn("[GROWLIVO] Chest connection: chest models missing"); return end
    local connected = 0
    for _, item in ipairs(group:GetDescendants()) do
        if item:IsA("ProximityPrompt") and item.Name == "GrowlivoChestPrompt"
            and item.Parent and item.Parent:IsA("BasePart") then
            local chest = item.Parent
            if Config.WorldChests[chest:GetAttribute("ChestWorld")] then
                item.Triggered:Connect(function(player)
                    openWorldChest(player, chest)
                end)
                connected += 1
            end
        end
    end
    print("[GROWLIVO] Daily world chests connected: " .. connected)
end)

-- Server-authoritative rune expeditions. A player must physically visit
-- THREE distinct pedestals in their current unlocked world to earn a brief boost.
-- Client scripts never request or grant the boost through a RemoteEvent.
local function activateRune(player, pedestal, prompt)
    if not isReady(player) or not player.Parent then return end
    local p = profiles[player]
    local worldId = pedestal:GetAttribute("RuneWorld")
    local runeIndex = pedestal:GetAttribute("RuneIndex")
    if not Config.FindWorld(worldId) or p.World ~= worldId then return end
    if typeof(runeIndex) ~= "number" or runeIndex % 1 ~= 0
        or runeIndex < 1 or runeIndex > Config.RuneTrial.Required then return end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local human = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not root or not human or human.Health <= 0 then return end
    if (root.Position - pedestal.Position).Magnitude > Config.RuneTrial.CollectRadius then return end
    local state = runeSession(player)
    local now = workspace:GetServerTimeNow()
    local cooldown = state.Cooldowns[worldId] or 0
    if cooldown > now then
        notify(player, "Руны восстанавливаются: " .. math.ceil(cooldown - now) .. " сек.")
        return
    end
    -- Expired cooldown must not leave the player with old partial runes.
    if state.WorldId ~= worldId then
        state.WorldId, state.Count, state.Used = worldId, 0, {}
    end
    if state.Used[runeIndex] then
        notify(player, "Эта руна уже активирована. Найди другую!")
        return
    end
    state.Used[runeIndex] = true
    state.Count += 1
    if state.Count >= Config.RuneTrial.Required then
        state.Used, state.Count = {}, 0
        state.Cooldowns[worldId] = now + Config.RuneTrial.CooldownSeconds
        state.BoostWorld = worldId
        state.BoostUntil = now + Config.RuneTrial.BoostSeconds
        countError("RuneTrialsCompleted")
        notify(player, "Испытание рун пройдено! ×" .. Config.RuneTrial.BoostMultiplier
            .. " клики на " .. Config.RuneTrial.BoostSeconds .. " сек.")
        VisualEvent:FireClient(player, {Type = "RuneComplete"})
        local expected = state.BoostUntil
        task.delay(Config.RuneTrial.BoostSeconds + 0.2, function()
            if runeSessions[player] == state and state.BoostUntil == expected and profiles[player]
                and player:GetAttribute("DataStatus") == "Ready" then
                sync(player, false)
            end
        end)
    else
        notify(player, "Руна активирована: " .. state.Count .. "/" .. Config.RuneTrial.Required)
        VisualEvent:FireClient(player, {Type = "RuneCollect"})
    end
    -- A rune trial never dirties DataStore; it only modifies temporary tap power.
    sync(player, false)
end

task.spawn(function()
    local worldModel = workspace:WaitForChild("GROWLIVO_World", 40)
    if not worldModel then warn("[GROWLIVO] Rune expedition: world missing"); return end
    local runeGroup = worldModel:WaitForChild("09_RUNE_EXPEDITIONS", 40)
    if not runeGroup then warn("[GROWLIVO] Rune expedition: shrines missing"); return end
    local total = 0
    for _, item in ipairs(runeGroup:GetDescendants()) do
        if item:IsA("ProximityPrompt") and item.Name == "GrowlivoRunePrompt"
            and item.Parent and item.Parent:IsA("BasePart") then
            local pedestal = item.Parent
            if Config.FindWorld(pedestal:GetAttribute("RuneWorld")) then
                item.Triggered:Connect(function(player) activateRune(player, pedestal, item) end)
                total += 1
            end
        end
    end
    print("[GROWLIVO] Rune shrines connected: " .. total)
end)

local function onJoin(player)
    player:SetAttribute("DataReady", false)
    player:SetAttribute("SavingEnabled", false)
    player:SetAttribute("DataStatus", "Loading")
    player:SetAttribute("UnsavedChanges", false)
    player:SetAttribute("LastConfirmedSaveAt", 0)
    player:SetAttribute("DataMode", Storage.Mode)
    player:SetAttribute("AutoTapEnabled", false)
    player:SetAttribute("AutoTapUnlocked", false)
    player:SetAttribute("TapComboCount", 0)
    player:SetAttribute("TapComboMultiplier", 1)
    player:SetAttribute("TapComboExpiresAt", 0)
    player:SetAttribute("ChestDay", dayUTC())
    player:SetAttribute("ChestClaimed", false)
    player:SetAttribute("RuneCount", 0)
    player:SetAttribute("RuneMask", 0)
    player:SetAttribute("RuneBoostUntil", 0)
    player:SetAttribute("RuneCooldownUntil", 0)
    player:SetAttribute("RuneBoostMultiplier", 1)
    initBoard(player)
    local p, state = acquireProfile(player)
    if not player.Parent then
        if p and p.CanSave then
            profiles[player] = p
            save(player, true)
            profiles[player] = nil
        end
        return
    end
    if state == "locked" then
        setDataStatus(player, "Conflict")
        player:Kick("GROWLIVO: профиль открыт на другом сервере. Повторите вход через несколько минут.")
        return
    end
    if state == "future" then
        setDataStatus(player, "Unavailable")
        player:Kick("GROWLIVO: данные созданы более новой версией игры. Прогресс не изменён.")
        return
    end
    if state == "invalid" then
        setDataStatus(player, "Unavailable")
        player:Kick("GROWLIVO: обнаружены повреждённые данные профиля. Прогресс не перезаписан.")
        return
    end
    if state == "offline" or not p then
        setDataStatus(player, "Unavailable")
        player:Kick("GROWLIVO: не удалось безопасно загрузить прогресс. Повторите вход позже.")
        return
    end
    profiles[player] = p
    nextAutosave[player] = os.clock() + rng:NextInteger(10, 40)
    resetDaily(p)
    resetWeekly(p)
    resetChests(p)
    if SaveReceipt.HasPending(p) then
        nextAutosave[player] = os.clock() + Config.DirtySaveDelaySeconds
    end
    player.CharacterAdded:Connect(function()
        task.delay(0.15, function()
            if isReady(player) then teleport(player, p.World) end
        end)
    end)
    sync(player, false)
    setDataStatus(player, "Ready")
    player:SetAttribute("DataReady", true)
    if p.CanSave then
        -- A successfully restored profile is also a confirmed persistent score.
        confirmedSave:Fire(player.UserId, p.TotalClicks, p.Rebirths)
    end
    if player.Character then teleport(player, p.World) end
    pushPets(player)
    pushProgress(player)
    pushEvent(player)
end
Players.PlayerAdded:Connect(onJoin)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(onJoin, player) end
-- Both PlayerRemoving and BindToClose may fire for the same player on shutdown.
-- Exactly one final release is attempted; the second caller waits for it to finish.
local function finalSave(player)
    if finalizing[player] then
        local waitUntil = os.clock() + 23
        while finalizing[player] == "Writing" and os.clock() < waitUntil do
            task.wait(0.1)
        end
        if finalizing[player] == "Writing" then
            countError("ShutdownWaitTimeouts")
            warn("[GROWLIVO] Final save still in progress at shutdown deadline: " .. player.UserId)
        end
        -- Do not attempt a second concurrent write/release even after timeout.
        return
    end
    finalizing[player] = "Writing"
    setDataStatus(player, "Closing")
    -- Never strand a second shutdown waiter if an unexpected Luau exception
    -- occurs outside the UpdateAsync pcall inside save().
    local ok, err = pcall(save, player, true)
    if not ok then
        countError("ExitSaveFailures")
        warn("[GROWLIVO] Final save crashed: " .. tostring(player.UserId) .. ": " .. tostring(err))
    end
    finalizing[player] = "Done"
end
Players.PlayerRemoving:Connect(function(player)
    finalSave(player)
    profiles[player], saveBusy[player], lastClick[player], lastAction[player] = nil, nil, nil, nil
    lastPets[player], lastProgress[player], progressQueued[player] = nil, nil, nil
    eventQueued[player], lastEvent[player] = nil, nil
    nextAutosave[player], recoveringSave[player], retryAttempts[player] = nil, nil, nil
    remoteBuckets[player], pendingTeleport[player], runeSessions[player] = nil, nil, nil
    autoTapEnabled[player], nextAutoTap[player], tapCombos[player] = nil, nil, nil
    -- Preserve finalizing[player] == "Done" for a concurrently running BindToClose.
    -- Weak player keys release this marker automatically after the Player is GC'd.
end)
-- One server-side automatic tap every IntervalSeconds. Delayed scheduler iterations
-- never generate catch-up rewards; this cannot be accelerated by client requests.
-- Autosaving and save failures use the same checks as regular manual taps.
task.spawn(function()
    while task.wait(0.25) do
        local now = os.clock()
        for player, state in pairs(tapCombos) do
            if state.Count > 0 and now - state.LastTap >= Config.TapCombo.WindowSeconds then
                state.Count = 0
                if player.Parent == Players then
                    player:SetAttribute("TapComboCount", 0)
                    player:SetAttribute("TapComboMultiplier", 1)
                    player:SetAttribute("TapComboExpiresAt", 0)
                end
            end
        end
        for player, enabled in pairs(autoTapEnabled) do
            if enabled and now >= (nextAutoTap[player] or math.huge) then
                nextAutoTap[player] = now + Config.AutoTap.IntervalSeconds
                local p = profiles[player]
                if p and p.Rebirths >= Config.AutoTap.UnlockRebirths
                    and isReady(player) and player.Parent == Players then
                    local character = player.Character
                    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                    if humanoid and humanoid.Health > 0 then
                        awardTap(player, p, false)
                    end
                end
            end
        end
    end
end)

-- Clock-driven refresh: event is UTC-scheduled across all servers without a global hot key.
-- Periodic HUD refresh corrects displayed ClickPower at the beginning/end of event windows.
task.spawn(function()
    task.wait(2)
    while true do
        for _, player in ipairs(Players:GetPlayers()) do
            if isReady(player) then
                local p = profiles[player]
                local dailyChanged = resetDaily(p)
                local weeklyChanged = resetWeekly(p)
                local chestChanged = resetChests(p)
                if dailyChanged or weeklyChanged or chestChanged then
                    sync(player, false)
                    pushProgress(player)
                end
                local _, _, multiplier = Config.StarfallAt(os.time())
                if player:GetAttribute("EventMultiplier") ~= multiplier then sync(player, false) end
                pushEvent(player)
            end
        end
        task.wait(20)
    end
end)
-- Stagger saves across players and servers. SaveRetry profiles stay in the
-- retry queue even though gameplay is paused; success restores Ready.
task.spawn(function()
    while task.wait(5) do
        local now = os.clock()
        for _, player in ipairs(Players:GetPlayers()) do
            local status = player:GetAttribute("DataStatus")
            if profiles[player] and (status == "Ready" or status == "SaveRetry")
                and now >= (nextAutosave[player] or math.huge) then
                if saveBusy[player] then
                    -- Let an in-flight UpdateAsync finish. Do not build an
                    -- unbounded queue of waiting coroutines during outages.
                    countError("AutosaveBusySkips")
                    nextAutosave[player] = now + 5
                else
                    nextAutosave[player] = now + Config.AutosaveSeconds + rng:NextInteger(-15, 15)
                    task.spawn(save, player, false)
                end
            end
        end
    end
end)
game:BindToClose(function()
    local pending = 0
    for _, player in ipairs(Players:GetPlayers()) do
        pending += 1
        task.spawn(function()
            finalSave(player)
            pending -= 1
        end)
    end
    local deadline = os.clock() + 25
    while pending > 0 and os.clock() < deadline do task.wait(0.1) end
end)
print("[GROWLIVO] Server ready / " .. Config.Version)
