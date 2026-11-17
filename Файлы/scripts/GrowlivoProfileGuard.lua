-- GROWLIVO / Strict persistent-profile guard / Alpha 0.9.15
-- ServerScriptService > GrowlivoProfileGuard [ModuleScript]
-- Pure/read-only module. Used INSIDE UpdateAsync before acquiring or releasing locks.
-- nil means a new player; missing fields in legacy tables remain migratable.
local Calendar = require(script.Parent:WaitForChild("GrowlivoCalendar"))
local Guard = {}
local MAX_PET_ID = 2000000000
local function isIntegerInRange(value, low, high)
    return typeof(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
        and value == math.floor(value) and value >= low and value <= high
end

function Guard.Validate(raw, config)
    if raw == nil then return true, nil end
    if typeof(raw) ~= "table" then return false, "NonTableProfile" end
    if raw.Version ~= nil then
        if not isIntegerInRange(raw.Version, 0, 100000) then
            return false, "InvalidVersion"
        end
        if raw.Version > config.ProfileVersion then
            return false, "FutureVersion"
        end
    end
    local numericFields = {
        Clicks = {0, config.MaxClickBalance},
        TotalClicks = {0, config.MaxTotalClicks},
        Gems = {0, config.MaxGems},
        TapLevel = {1, config.MaxTapLevel},
        Rebirths = {0, config.MaxRebirths},
        HatchedTotal = {0, config.MaxTotalClicks},
        NextPetId = {1, MAX_PET_ID + 1},
        TutorialStep = {1, 4},
        TutorialClicks = {0, config.TutorialClickGoal},
        StarfallProgress = {0, config.Starfall.Goal},
    }
    for key, limits in pairs(numericFields) do
        local value = raw[key]
        if value ~= nil and not isIntegerInRange(value, limits[1], limits[2]) then
            return false, "InvalidNumeric:" .. key
        end
    end
    for _, key in ipairs({"Pets", "Equipped", "UnlockedWorlds", "Settings", "QuestProgress",
        "QuestClaimed", "AchievementClaimed", "WeeklyProgress", "WeeklyClaimed", "ChestClaimed"}) do
        if raw[key] ~= nil and typeof(raw[key]) ~= "table" then
            return false, "InvalidTable:" .. key
        end
    end
    for _, key in ipairs({"DailyClaimed", "StarfallClaimed"}) do
        if raw[key] ~= nil and typeof(raw[key]) ~= "boolean" then
            return false, "InvalidBoolean:" .. key
        end
    end
    for _, key in ipairs({"DailyDay", "WeeklyWeek", "ChestDay"}) do
        if raw[key] ~= nil and not Calendar.IsValidKey(raw[key]) then
            return false, "InvalidDate:" .. key
        end
    end
    -- Never silently erase unrecognised saved unlocks, quest claims or settings.
    -- Unknown IDs can be legitimate future/retired features; refusing to load
    -- is safer than restoring a reduced profile and overwriting the original.
    local function knownKeysOnly(field, definitions)
        local data = raw[field]
        if data == nil then return true end
        for key in pairs(data) do
            if typeof(key) ~= "string" or not definitions[key] then
                return false, "UnknownSavedKey:" .. field
            end
        end
        return true
    end
    local worldIds, questIds, weeklyIds, achievementIds, settingIds = {}, {}, {}, {}, {}
    for _, item in ipairs(config.Worlds) do worldIds[item.Id] = true end
    for _, item in ipairs(config.Quests) do questIds[item.Id] = true end
    for _, item in ipairs(config.WeeklyQuests) do weeklyIds[item.Id] = true end
    for _, item in ipairs(config.Achievements) do achievementIds[item.Id] = true end
    for key in pairs(config.DefaultSettings) do settingIds[key] = true end
    for _, spec in ipairs({
        {"ChestClaimed", worldIds},
        {"UnlockedWorlds", worldIds}, {"QuestProgress", questIds},
        {"QuestClaimed", questIds}, {"WeeklyProgress", weeklyIds},
        {"WeeklyClaimed", weeklyIds}, {"AchievementClaimed", achievementIds},
        {"Settings", settingIds},
    }) do
        local valid, reason = knownKeysOnly(spec[1], spec[2])
        if not valid then return false, reason end
    end
    if raw.ChestClaimed then
        for worldId, claimed in pairs(raw.ChestClaimed) do
            if config.WorldChests[worldId] == nil or typeof(claimed) ~= "boolean" then
                return false, "InvalidChestClaim:" .. tostring(worldId)
            end
        end
    end
    if raw.WeeklyWeek ~= nil and not Calendar.IsWeekKey(raw.WeeklyWeek) then
        return false, "InvalidWeeklyPeriod"
    end
    -- Reject malformed entries rather than silently discarding valuable pets.
    if raw.Pets then
        if #raw.Pets > config.MaxPetInventory then return false, "TooManyPets" end
        for index in pairs(raw.Pets) do
            if not isIntegerInRange(index, 1, #raw.Pets) then return false, "SparseOrMappedPets" end
        end
        local seen = {}
        for _, pet in ipairs(raw.Pets) do
            if typeof(pet) ~= "table" or not isIntegerInRange(pet.Id, 1, MAX_PET_ID)
                or not config.FindPet(pet.Species) or seen[pet.Id] then
                return false, "InvalidPet"
            end
            seen[pet.Id] = true
        end
        if raw.Equipped then
            if #raw.Equipped > config.MaxEquippedPets then return false, "TooManyEquipped" end
            for index in pairs(raw.Equipped) do
                if not isIntegerInRange(index, 1, #raw.Equipped) then
                    return false, "SparseOrMappedEquipped"
                end
            end
            local equippedIds = {}
            for _, id in ipairs(raw.Equipped) do
                if not isIntegerInRange(id, 1, MAX_PET_ID) or not seen[id] or equippedIds[id] then
                    return false, "InvalidEquipped"
                end
                equippedIds[id] = true
            end
        end
    elseif raw.Equipped then
        if #raw.Equipped > 0 then return false, "EquippedWithoutPets" end
        for _ in pairs(raw.Equipped) do
            return false, "SparseOrMappedEquipped"
        end
    end
    if raw.UnlockedWorlds then
        for _, world in ipairs(config.Worlds) do
            local value = raw.UnlockedWorlds[world.Id]
            if value ~= nil and typeof(value) ~= "boolean" then
                return false, "InvalidUnlockedWorld:" .. world.Id
            end
        end
    end
    for _, definition in ipairs({
        {config.Quests, raw.QuestProgress, raw.QuestClaimed},
        {config.WeeklyQuests, raw.WeeklyProgress, raw.WeeklyClaimed},
    }) do
        local quests, progress, claims = definition[1], definition[2], definition[3]
        for _, quest in ipairs(quests) do
            if progress and progress[quest.Id] ~= nil
                and not isIntegerInRange(progress[quest.Id], 0, quest.Goal) then
                return false, "InvalidQuestProgress:" .. quest.Id
            end
            if claims and claims[quest.Id] ~= nil and typeof(claims[quest.Id]) ~= "boolean" then
                return false, "InvalidQuestClaim:" .. quest.Id
            end
        end
    end
    if raw.AchievementClaimed then
        for _, achievement in ipairs(config.Achievements) do
            local value = raw.AchievementClaimed[achievement.Id]
            if value ~= nil and typeof(value) ~= "boolean" then
                return false, "InvalidAchievement:" .. achievement.Id
            end
        end
    end
    if raw.Settings then
        for key, _ in pairs(config.DefaultSettings) do
            if raw.Settings[key] ~= nil and typeof(raw.Settings[key]) ~= "boolean" then
                return false, "InvalidSetting:" .. key
            end
        end
    end
    -- A damaged lock must never be ignored as if it had expired.
    if raw.__Session ~= nil then
        local lock = raw.__Session
        if typeof(lock) ~= "table" or typeof(lock.Id) ~= "string" or #lock.Id == 0
            or not isIntegerInRange(lock.Expires, 1, 4102444800) then
            return false, "InvalidSessionLock"
        end
    end
    return true, nil
end
return Guard
