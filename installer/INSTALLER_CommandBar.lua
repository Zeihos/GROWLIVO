-- GROWLIVO Alpha 0.9.27 / Command Bar Installer (EDIT mode only)
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "[GROWLIVO] Stop Play before installation")
local targets = {
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    ServerScriptService = game:GetService("ServerScriptService"),
    StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"),
}
local packages = {
    {name="GrowlivoConfig", className="ModuleScript", target="ReplicatedStorage", source=[==[-- GROWLIVO / Shared economy and progression config / Alpha 0.9.27
local Config = {}
Config.Version = "Alpha 0.9.27"
Config.ProfileVersion = 7
Config.MaxSerializedProfileBytes = 3000000 -- under the DataStore value limit; conservative safety margin
Config.TutorialClickGoal = 20
Config.DataStoreName = "GROWLIVO_Profiles_v1" -- migration from 0.1/0.2; do not rename
Config.AutosaveSeconds = 90
Config.DirtySaveDelaySeconds = 8 -- post-UpdateAsync changes should not wait 90 s
Config.SaveRetrySeconds = 12 -- fast retry for transient storage failures
Config.SaveWaitTimeoutSeconds = 20 -- bounded wait for in-flight write
Config.SessionLockSeconds = 240
Config.MaxClicksPerSecond = 8
-- Free progression feature: 2 rebirths unlocks 1 server-owned tap every 2 sec.
-- Session toggle only: no purchases, no client-supplied tap counts, no new save fields.
Config.AutoTap = {UnlockRebirths = 2, IntervalSeconds = 2}
-- Server-only streaks from accepted manual taps; no new persistent fields.
Config.TapCombo = {WindowSeconds = 2.5, MaxStreak = 50,
    Tiers = {{Taps = 10, Multiplier = 1.10}, {Taps = 25, Multiplier = 1.25},
        {Taps = 50, Multiplier = 1.50}}}
function Config.TapComboMultiplier(taps)
    local count = math.max(0, math.floor(tonumber(taps) or 0))
    local factor = 1
    for _, tier in ipairs(Config.TapCombo.Tiers) do
        if count >= tier.Taps then factor = tier.Multiplier end
    end
    return factor
end
-- Per-player Action RemoteEvent capacity and refill rate. On top of action-specific cooldowns.
Config.RemoteBurstCapacity = 30
Config.RemoteTokensPerSecond = 20
Config.SaveRetryMaxSeconds = 60 -- bounded backoff after repeated DataStore failures
Config.MaxClickBalance = 1000000000000
Config.MaxTotalClicks = 9000000000000000
Config.MaxGems = 1000000000
Config.MaxTapLevel = 50
Config.BulkUpgradeCount = 5 -- fixed server-owned batch size; clients never choose arbitrary counts
Config.MaxRebirths = 1000
Config.MaxPetInventory = 60
Config.MaxHatchBatch = 3
Config.MaxEquippedPets = 3
Config.EggPrice = 150 -- compatibility with old UI/tests
-- Non-persistent rune expedition: three unique runes per world unlock a temporary
-- ×2 tap boost. No new DataStore fields, no premium purchases, no client reward call.
Config.RuneTrial = {
    Required = 3, BoostMultiplier = 2, BoostSeconds = 75,
    CooldownSeconds = 240, CollectRadius = 16,
}
-- One world chest per world and UTC day. Claims are persistent to prevent
-- rejoining another server to claim the same currency multiple times.
Config.WorldChests = {
    SkyCrown = {Clicks = 450, Gems = 3},
    CrystalVale = {Clicks = 4000, Gems = 8},
    AuroraGrove = {Clicks = 18000, Gems = 15},
}
Config.ChestCollectRadius = 16
Config.DefaultSettings = {ShowPets = true, Effects = true, ReducedMotion = false, Sounds = true}

-- Deterministic UTC schedule shared across servers. Active first 10 minutes of every hour.
-- Nothing in the payload from a client can change the clock, reward, multiplier or progress.
Config.Starfall = {
    Name = "Звёздный дождь", CycleSeconds = 3600, ActiveSeconds = 600,
    Multiplier = 2, Goal = 60, RewardClicks = 500, RewardGems = 20,
}
function Config.StarfallAt(now)
    local clock = math.max(0, math.floor(now))
    local offset = clock % Config.Starfall.CycleSeconds
    local active = offset < Config.Starfall.ActiveSeconds
    local remaining = active and (Config.Starfall.ActiveSeconds - offset)
        or (Config.Starfall.CycleSeconds - offset)
    return active, remaining, active and Config.Starfall.Multiplier or 1
end

-- Add your own numeric Roblox UserId to enable the admin panel. Never trust client checks.
Config.AdminUserIds = {} -- Example: {123456789}; intentionally empty on release
Config.Leaderboards = {
    TotalClicksStore = "GROWLIVO_TopTotalClicks_v1",
    RebirthsStore = "GROWLIVO_TopRebirths_v1",
    PageSize = 10,
    RefreshSeconds = 120,
}


Config.Worlds = {
    {Id = "SkyCrown", Name = "Небесная корона", Multiplier = 1, UnlockRebirths = 0, UnlockGems = 0, EggId = "SkyEgg"},
    {Id = "CrystalVale", Name = "Кристальная долина", Multiplier = 2, UnlockRebirths = 1, UnlockGems = 25, EggId = "CrystalEgg"},
    {Id = "AuroraGrove", Name = "Роща сияния", Multiplier = 4, UnlockRebirths = 3, UnlockGems = 100, EggId = "AuroraEgg"},
}
local worldById = {}
for _, world in ipairs(Config.Worlds) do worldById[world.Id] = world end
function Config.FindWorld(id) return typeof(id) == "string" and worldById[id] or nil end

Config.Pets = {
    {Id = "CloudBunny", Name = "Облачный зайчик", Rarity = "Обычный", Bonus = 10, Color = Color3.fromRGB(237, 245, 255)},
    {Id = "SunFox", Name = "Солнечный лис", Rarity = "Необычный", Bonus = 20, Color = Color3.fromRGB(255, 189, 84)},
    {Id = "SkyOwl", Name = "Небесная сова", Rarity = "Редкий", Bonus = 35, Color = Color3.fromRGB(105, 209, 255)},
    {Id = "CrystalCat", Name = "Кристальный кот", Rarity = "Эпический", Bonus = 65, Color = Color3.fromRGB(152, 108, 255)},
    {Id = "CrownDragon", Name = "Коронованный дракон", Rarity = "Легендарный", Bonus = 120, Color = Color3.fromRGB(255, 207, 51)},
    {Id = "GemSlime", Name = "Самоцветный слайм", Rarity = "Обычный", Bonus = 45, Color = Color3.fromRGB(60, 234, 216)},
    {Id = "PrismDeer", Name = "Призматический олень", Rarity = "Редкий", Bonus = 80, Color = Color3.fromRGB(186, 151, 255)},
    {Id = "AzurePhoenix", Name = "Лазурный феникс", Rarity = "Эпический", Bonus = 155, Color = Color3.fromRGB(46, 181, 255)},
    {Id = "DiamondWyrm", Name = "Алмазный змей", Rarity = "Мифический", Bonus = 260, Color = Color3.fromRGB(255, 242, 168)},
    {Id = "AuroraMoth", Name = "Сияющий мотылёк", Rarity = "Обычный", Bonus = 110, Color = Color3.fromRGB(131, 255, 196)},
    {Id = "DuskWolf", Name = "Сумеречный волк", Rarity = "Редкий", Bonus = 185, Color = Color3.fromRGB(121, 155, 255)},
    {Id = "RuneStag", Name = "Рунный олень", Rarity = "Эпический", Bonus = 340, Color = Color3.fromRGB(255, 162, 226)},
    {Id = "DawnGriffin", Name = "Грифон рассвета", Rarity = "Мифический", Bonus = 600, Color = Color3.fromRGB(255, 220, 125)},
}
local petById = {}
for _, pet in ipairs(Config.Pets) do petById[pet.Id] = pet end
function Config.FindPet(id) return typeof(id) == "string" and petById[id] or nil end

-- Pet fusion never creates new persistent fields. Three UNEQUIPPED duplicates
-- become one pet from the same egg family. The final tier cannot be fused.
Config.FusionRequired = 3
Config.FusionNext = {
    CloudBunny = "SunFox", SunFox = "SkyOwl", SkyOwl = "CrystalCat",
    CrystalCat = "CrownDragon",
    GemSlime = "PrismDeer", PrismDeer = "AzurePhoenix",
    AzurePhoenix = "DiamondWyrm",
    AuroraMoth = "DuskWolf", DuskWolf = "RuneStag",
    RuneStag = "DawnGriffin",
}
function Config.FusionResult(species)
    if typeof(species) ~= "string" then return nil end
    local nextSpecies = Config.FusionNext[species]
    return nextSpecies and petById[nextSpecies] or nil
end

-- Only the server chooses the egg and rolls the odds.
Config.Eggs = {
    SkyEgg = {Name = "Небесное яйцо", Price = 150, World = "SkyCrown", Drops = {
        {Species = "CloudBunny", Chance = 45}, {Species = "SunFox", Chance = 28},
        {Species = "SkyOwl", Chance = 17}, {Species = "CrystalCat", Chance = 8},
        {Species = "CrownDragon", Chance = 2},
    }},
    CrystalEgg = {Name = "Кристальное яйцо", Price = 2500, World = "CrystalVale", Drops = {
        {Species = "GemSlime", Chance = 50}, {Species = "PrismDeer", Chance = 30},
        {Species = "AzurePhoenix", Chance = 15}, {Species = "DiamondWyrm", Chance = 5},
    }},
    AuroraEgg = {Name = "Яйцо сияния", Price = 15000, World = "AuroraGrove", Drops = {
        {Species = "AuroraMoth", Chance = 50}, {Species = "DuskWolf", Chance = 30},
        {Species = "RuneStag", Chance = 15}, {Species = "DawnGriffin", Chance = 5},
    }},
}
function Config.EggForWorld(worldId)
    local world = Config.FindWorld(worldId)
    return world and Config.Eggs[world.EggId] or nil
end

-- All goals are repeatable after UTC midnight; progress tracks actions, not purchased rewards.
Config.Quests = {
    {Id = "Tap80", Name = "80 нажатий", Event = "Tap", Goal = 80, Gems = 8},
    {Id = "Egg2", Name = "Открыть 2 яйца", Event = "Hatch", Goal = 2, Gems = 7},
    {Id = "Upgrade3", Name = "Купить 3 улучшения", Event = "Upgrade", Goal = 3, Gems = 5},
    {Id = "Rebirth1", Name = "Сделать перерождение", Event = "Rebirth", Goal = 1, Gems = 10},
}
-- Weekly quests use a single UTC Monday key, not the player's local clock.
-- A manual tap increments by one even when a world/Starfall multiplies its value.
Config.WeeklyQuests = {
    {Id = "WeekTap750", Name = "750 нажатий за неделю", Event = "Tap", Goal = 750, Gems = 35},
    {Id = "WeekHatch10", Name = "Открыть 10 яиц", Event = "Hatch", Goal = 10, Gems = 40},
    {Id = "WeekUpgrade10", Name = "Купить 10 улучшений", Event = "Upgrade", Goal = 10, Gems = 30},
    {Id = "WeekRebirth2", Name = "Сделать 2 перерождения", Event = "Rebirth", Goal = 2, Gems = 55},
}
local weeklyQuestById = {}
for _, quest in ipairs(Config.WeeklyQuests) do weeklyQuestById[quest.Id] = quest end
function Config.FindWeeklyQuest(id)
    return typeof(id) == "string" and weeklyQuestById[id] or nil
end
local questById = {}
for _, quest in ipairs(Config.Quests) do questById[quest.Id] = quest end
function Config.FindQuest(id) return typeof(id) == "string" and questById[id] or nil end
Config.DailyReward = {Clicks = 300, Gems = 10}

Config.Achievements = {
    {Id = "FirstSteps", Name = "Первые 500 кликов", Stat = "TotalClicks", Goal = 500, Gems = 10},
    {Id = "PetCollector", Name = "Открыть 10 яиц", Stat = "HatchedTotal", Goal = 10, Gems = 15},
    {Id = "RebirthMaster", Name = "Сделать 5 перерождений", Stat = "Rebirths", Goal = 5, Gems = 25},
}
local achievementById = {}
for _, achievement in ipairs(Config.Achievements) do achievementById[achievement.Id] = achievement end
function Config.FindAchievement(id) return typeof(id) == "string" and achievementById[id] or nil end

function Config.PetBonus(inventory, equipped)
    if typeof(inventory) ~= "table" or typeof(equipped) ~= "table" then return 0 end
    local owned = {}
    for _, item in ipairs(inventory) do owned[item.Id] = item.Species end
    local bonus = 0
    for _, id in ipairs(equipped) do
        local pet = Config.FindPet(owned[id])
        if pet then bonus += pet.Bonus end
    end
    return bonus
end
function Config.ClickPower(tapLevel, rebirths, petBonus, worldMultiplier)
    local level = math.max(1, math.floor(tapLevel))
    local rebirth = 1 + math.max(0, math.floor(rebirths))
    local bonus = math.max(0, math.floor(petBonus or 0))
    local world = math.clamp(math.floor(worldMultiplier or 1), 1, 100)
    return math.max(1, math.floor(level * rebirth * (100 + bonus) / 100 * world))
end
function Config.UpgradeCost(level)
    if level >= Config.MaxTapLevel then return nil end
    return math.floor(25 * (1.55 ^ (level - 1)))
end
-- Quote from the SAME per-level price function used by ordinary upgrades.
-- Near the cap, a x5 purchase buys only the remaining levels.
-- Returns nil,0 when no upgrades remain or an invalid batch is requested.
function Config.UpgradeBundleCost(level, requested)
    if typeof(level) ~= "number" or level ~= level then return nil, 0 end
    if requested ~= 1 and requested ~= Config.BulkUpgradeCount then return nil, 0 end
    local first = math.max(1, math.floor(level))
    local levels = math.min(requested, Config.MaxTapLevel - first)
    if levels <= 0 then return nil, 0 end
    local total = 0
    for index = 0, levels - 1 do
        local price = Config.UpgradeCost(first + index)
        if not price then return nil, 0 end
        total += price
    end
    return total, levels
end
function Config.RebirthCost(rebirths)
    if rebirths >= Config.MaxRebirths then return nil end
    return 500 * ((rebirths + 1) ^ 2)
end
function Config.RebirthGemReward(rebirths)
    return 5 + 2 * math.max(0, rebirths)
end
return Config
]==]},
    {name="GrowlivoCalendar", className="ModuleScript", target="ServerScriptService", source=[==[-- GROWLIVO / UTC calendar periods / Alpha 0.9.15
-- ServerScriptService > GrowlivoCalendar [ModuleScript]
-- Pure UTC helpers: no DataStore access or mutations.
local Calendar = {}

function Calendar.DayKey(now)
    local timestamp = now or os.time()
    assert(typeof(timestamp) == "number" and timestamp == timestamp
        and timestamp ~= math.huge and timestamp ~= -math.huge,
        "Expected a finite UTC timestamp")
    return os.date("!%Y-%m-%d", math.floor(timestamp))
end

function Calendar.WeekKey(now)
    local timestamp = now or os.time()
    assert(typeof(timestamp) == "number" and timestamp == timestamp
        and timestamp ~= math.huge and timestamp ~= -math.huge,
        "Expected a finite UTC timestamp")
    timestamp = math.floor(timestamp)
    local weekday = os.date("!*t", timestamp).wday -- Sunday=1, Monday=2
    local daysSinceMonday = (weekday + 5) % 7
    return Calendar.DayKey(timestamp - daysSinceMonday * 86400)
end

-- Reject impossible calendar keys before a profile can be loaded or written.
-- A lexical comparison is meaningful only for validated YYYY-MM-DD keys.
local function leapYear(year)
    return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
end
function Calendar.IsValidKey(key)
    if typeof(key) ~= "string" then return false end
    local y, m, d = key:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    if not y then return false end
    local year, month, day = tonumber(y), tonumber(m), tonumber(d)
    if year < 1970 or month < 1 or month > 12 or day < 1 then return false end
    local days = {31, leapYear(year) and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
    return day <= days[month]
end

-- ISO-style weekly reward keys must refer to Monday. Gregorian arithmetic is
-- used rather than local os.time(), so timezone/DST cannot change the result.
function Calendar.IsWeekKey(key)
    if not Calendar.IsValidKey(key) then return false end
    local y, m, d = key:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    local year, month, day = tonumber(y), tonumber(m), tonumber(d)
    -- Sakamoto: weekday 0 = Sunday, 1 = Monday, ..., 6 = Saturday.
    local offsets = {0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4}
    if month < 3 then year -= 1 end
    local weekday = (year + math.floor(year / 4) - math.floor(year / 100)
        + math.floor(year / 400) + offsets[month] + day) % 7
    return weekday == 1
end

-- Never run a recurring reward period backwards on clock skew / rollback.
-- The next genuine later UTC day or Monday advances the period normally.
function Calendar.ShouldAdvance(stored, current)
    return Calendar.IsValidKey(stored) and Calendar.IsValidKey(current)
        and current > stored
end

return Calendar
]==]},
    {name="GrowlivoProfileGuard", className="ModuleScript", target="ServerScriptService", source=[==[-- GROWLIVO / Strict persistent-profile guard / Alpha 0.9.15
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
]==]},
    {name="GrowlivoPersistenceAudit", className="ModuleScript", target="ServerScriptService", source=[==[-- GROWLIVO / Outgoing profile-snapshot audit / Alpha 0.9.14
-- ServerScriptService > GrowlivoPersistenceAudit [ModuleScript]
-- No DataStore calls, no mutations. Safe to use in Studio on synthetic tables.
local HttpService = game:GetService("HttpService")
local ProfileGuard = require(script.Parent:WaitForChild("GrowlivoProfileGuard"))
local Audit = {}
local requiredNumbers = {"Version", "Clicks", "TotalClicks", "Gems", "TapLevel", "Rebirths",
    "HatchedTotal", "NextPetId", "TutorialStep", "TutorialClicks", "StarfallProgress"}
local requiredTables = {"Pets", "Equipped", "UnlockedWorlds", "QuestProgress", "QuestClaimed",
    "AchievementClaimed", "WeeklyProgress", "WeeklyClaimed", "Settings", "ChestClaimed"}
local requiredBooleans = {"DailyClaimed", "StarfallClaimed"}
local requiredDates = {"DailyDay", "WeeklyWeek", "ChestDay"}

function Audit.Validate(snapshot, config)
    if typeof(snapshot) ~= "table" then return false, "MissingSnapshot" end
    if snapshot.Version ~= config.ProfileVersion then return false, "UnexpectedSnapshotVersion" end
    -- Saved records are complete, unlike legacy records loaded by ProfileGuard.
    for _, key in ipairs(requiredNumbers) do
        if typeof(snapshot[key]) ~= "number" then return false, "MissingNumber:" .. key end
    end
    for _, key in ipairs(requiredTables) do
        if typeof(snapshot[key]) ~= "table" then return false, "MissingTable:" .. key end
    end
    for _, key in ipairs(requiredBooleans) do
        if typeof(snapshot[key]) ~= "boolean" then return false, "MissingFlag:" .. key end
    end
    for _, key in ipairs(requiredDates) do
        if typeof(snapshot[key]) ~= "string" then return false, "MissingDate:" .. key end
    end
    local valid, reason = ProfileGuard.Validate(snapshot, config)
    if not valid then return false, "InvalidData:" .. tostring(reason) end
    if snapshot.UnlockedWorlds.SkyCrown ~= true then
        return false, "MissingStarterWorld"
    end
    -- Prevent creating a duplicate pet ID after a reload.
    for _, pet in ipairs(snapshot.Pets) do
        if pet.Id >= snapshot.NextPetId then return false, "NextPetIdCollision" end
    end
    local ok, encoded = pcall(function() return HttpService:JSONEncode(snapshot) end)
    if not ok or typeof(encoded) ~= "string" then return false, "JSONEncodeFailed" end
    if #encoded > config.MaxSerializedProfileBytes then
        return false, "SnapshotTooLarge"
    end
    return true, #encoded
end
return Audit
]==]},
    {name="GrowlivoSaveReceipt", className="ModuleScript", target="ServerScriptService", source=[==[-- GROWLIVO / Pure save receipt accounting / Alpha 0.9.14
-- ServerScriptService > GrowlivoSaveReceipt [ModuleScript]
-- No DataStore calls, Roblox Players or I/O. Testable with synthetic profiles.
local Receipt = {}

function Receipt.HasPending(profile)
    return (profile.MutationSerial or 0) > (profile.LastSavedSerial or 0)
end

function Receipt.MarkChanged(profile)
    profile.MutationSerial = (profile.MutationSerial or 0) + 1
    return Receipt.HasPending(profile)
end

function Receipt.BeginSnapshot(profile)
    return profile.MutationSerial or 0
end

function Receipt.Commit(profile, writtenSerial)
    -- A successful UpdateAsync only confirms the serial captured BEFORE it
    -- started. Clicks arriving during the yielding call still need saving.
    assert(typeof(writtenSerial) == "number" and writtenSerial >= 0
        and writtenSerial == math.floor(writtenSerial), "Invalid written serial")
    local currentSerial = profile.MutationSerial or 0
    local currentReceipt = profile.LastSavedSerial or 0
    profile.LastSavedSerial = math.max(currentReceipt, math.min(writtenSerial, currentSerial))
    return Receipt.HasPending(profile)
end

return Receipt
]==]},
    {name="GrowlivoStorage", className="ModuleScript", target="ServerScriptService", source=[==[-- GROWLIVO / DataStore bootstrap / Alpha 0.9.17
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
]==]},
    {name="GrowlivoServer", className="Script", target="ServerScriptService", source=[==[-- GROWLIVO / Economy, pets, worlds, daily goals, persistence / Alpha 0.9.27
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
    setPlayerAttribute(player, "ClickPower", Config.ClickPower(p.TapLevel, p.Rebirths, bonus, world.Multiplier) * eventMultiplier * runeBoostFor(player, p.World))
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
local function fusePets(player, p, requestedSpecies)
    if typeof(requestedSpecies) ~= "string" or #requestedSpecies > 40 then return false end
    local result = Config.FusionResult(requestedSpecies)
    if not result then
        notify(player, "Этот питомец достиг высшей ступени слияния")
        return false
    end
    if p.NextPetId > MAX_PET_ID then
        notify(player, "Достигнут лимит ID питомцев")
        return false
    end
    local protected = {}
    for _, id in ipairs(p.Equipped) do protected[id] = true end
    local indexes = {}
    for index, item in ipairs(p.Pets) do
        if item.Species == requestedSpecies and not protected[item.Id] then
            table.insert(indexes, index)
            if #indexes == Config.FusionRequired then break end
        end
    end
    if #indexes ~= Config.FusionRequired then
        notify(player, "Нужно 3 одинаковых СНЯТЫХ питомца для слияния")
        return false
    end
    -- Remove from the end so earlier indices cannot shift under us.
    for i = #indexes, 1, -1 do
        table.remove(p.Pets, indexes[i])
    end
    local newId = p.NextPetId
    p.NextPetId += 1
    table.insert(p.Pets, {Id = newId, Species = result.Id})
    if #p.Equipped < Config.MaxEquippedPets then
        table.insert(p.Equipped, newId)
    end
    countError("PetsFused")
    VisualEvent:FireClient(player, {Type = "Fusion", Species = result.Id})
    notify(player, "Слияние успешно! Получен: " .. result.Name)
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
        Config.PetBonus(p.Pets, p.Equipped), world.Multiplier)
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
    elseif actionName == "Upgrade" or actionName == "Upgrade5" then
        -- Never accept a client-supplied number or price. Determine the entire
        -- batch cost here, then charge and award it as one atomic transaction.
        local requested = actionName == "Upgrade5" and Config.BulkUpgradeCount or 1
        local cost, levels = Config.UpgradeBundleCost(p.TapLevel, requested)
        if not cost then
            notify(player, "Сила клика максимальная")
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
    elseif actionName == "FusePets" then
        changed = fusePets(player, p, argument)
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
]==]},
    {name="GrowlivoWorld", className="Script", target="ServerScriptService", source=[==[-- GROWLIVO / Three styled floating worlds, rune expeditions and daily chests / Alpha 0.9.24
-- ServerScriptService > GrowlivoWorld [Script]
-- Only replaces a model that is explicitly called GROWLIVO_World.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("GrowlivoConfig"))

local previous = workspace:FindFirstChild("GROWLIVO_World")
if previous then previous:Destroy() end
local world = Instance.new("Model")
world.Name = "GROWLIVO_World"
world.Parent = workspace

local GOLD = Color3.fromRGB(255, 196, 58)
local CYAN = Color3.fromRGB(34, 202, 255)
local DEEP = Color3.fromRGB(24, 42, 72)
local STONE = Color3.fromRGB(105, 128, 156)
local LEAVES = Color3.fromRGB(55, 183, 113)
local GRASS = Color3.fromRGB(84, 200, 100)
local WHITE = Color3.fromRGB(240, 250, 255)

local function part(name, size, position, color, material, parent)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.Size = size
    p.Position = position
    p.Material = material or Enum.Material.SmoothPlastic
    p.Color = color
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent or world
    return p
end

local function ball(name, radius, position, color, parent)
    local p = part(name, Vector3.new(radius, radius, radius), position, color, Enum.Material.SmoothPlastic, parent)
    p.Shape = Enum.PartType.Ball
    return p
end

local function billboard(object, caption, color, height, width)
    local gui = Instance.new("BillboardGui")
    gui.Name = "WorldCaption"
    gui.Adornee = object
    gui.AlwaysOnTop = true
    gui.MaxDistance = 150
    gui.Size = UDim2.fromOffset(width or 240, 56)
    gui.StudsOffsetWorldSpace = Vector3.new(0, height or 8, 0)
    gui.Parent = object
    local text = Instance.new("TextLabel")
    text.BackgroundTransparency = 1
    text.Size = UDim2.fromScale(1, 1)
    text.Font = Enum.Font.GothamBlack
    text.Text = caption
    text.TextScaled = true
    text.TextColor3 = color
    text.TextStrokeTransparency = 0.18
    text.Parent = gui
end

local function island(name, x, z, width, depth)
    local m = Instance.new("Model")
    m.Name = name
    m.Parent = world
    part("FloatingStone", Vector3.new(width + 4, 11, depth + 4), Vector3.new(x, -7, z), STONE, Enum.Material.Slate, m)
    part("Grass", Vector3.new(width, 2, depth), Vector3.new(x, 0, z), GRASS, Enum.Material.Grass, m)
    local lip = part("GoldRim", Vector3.new(width + 1, 0.7, depth + 1), Vector3.new(x, -1.3, z), GOLD, Enum.Material.Metal, m)
    lip.CanCollide = false
    for i = 1, 4 do
        local sx = i % 2 == 0 and 1 or -1
        local sz = i <= 2 and 1 or -1
        local c = part("CornerCrystal", Vector3.new(3, 10, 3), Vector3.new(x + sx * (width/2 - 6), 6, z + sz * (depth/2 - 6)), CYAN, Enum.Material.Neon, m)
        c.CanCollide = false
    end
    return m
end

local function tree(x, z)
    part("TreeTrunk", Vector3.new(3, 12, 3), Vector3.new(x, 7, z), Color3.fromRGB(110, 75, 46), Enum.Material.Wood)
    ball("TreeLeaves", 15, Vector3.new(x, 15, z), LEAVES)
    ball("TreeLeaves", 10, Vector3.new(x - 5, 13, z + 2), LEAVES)
end

local function column(x, z, title, color)
    local base = part("Pedestal", Vector3.new(12, 4, 9), Vector3.new(x, 3, z), DEEP, Enum.Material.Metal)
    part("Trim", Vector3.new(13, 1, 10), Vector3.new(x, 5.3, z), GOLD, Enum.Material.Neon)
    billboard(base, title, color or WHITE, 9, 310)
    return base
end

island("01_SKY_CROWN", 0, 0, 120, 120)
island("02_EGGS", -102, 0, 42, 44)
island("03_UPGRADES", 102, 0, 42, 44)
island("04_PORTALS", 0, -102, 44, 42)

local function bridge(name, size, pos)
    local b = part(name, size, pos, Color3.fromRGB(161, 113, 61), Enum.Material.WoodPlanks)
    part(name .. "_Stripe", Vector3.new(size.X, 0.2, math.min(1, size.Z)), pos + Vector3.new(0, 1.12, 0), GOLD, Enum.Material.Metal)
    return b
end
bridge("BridgeEggs", Vector3.new(26, 2, 13), Vector3.new(-74, 0, 0))
bridge("BridgeUpgrades", Vector3.new(26, 2, 13), Vector3.new(74, 0, 0))
bridge("BridgePortals", Vector3.new(13, 2, 26), Vector3.new(0, 0, -74))

local spawn = Instance.new("SpawnLocation")
spawn.Name = "GROWLIVO_Spawn"
spawn.Size = Vector3.new(11, 1, 11)
spawn.Position = Vector3.new(0, 2.5, 29)
spawn.Anchored = true
spawn.Neutral = true
spawn.Material = Enum.Material.Neon
spawn.Color = CYAN
spawn.Transparency = 0.2
spawn.Parent = world

-- Monogram G built from separate physical beams, with an illuminated crown.
part("MonumentPillar", Vector3.new(19, 12, 15), Vector3.new(0, 7, -25), DEEP, Enum.Material.Metal)
part("MonumentTop", Vector3.new(23, 2, 19), Vector3.new(0, 14, -25), GOLD, Enum.Material.Metal)
local center = Vector3.new(0, 22, -25)
part("G_Left", Vector3.new(3, 13, 2), center + Vector3.new(-5, 0, 0), GOLD, Enum.Material.Neon)
part("G_Top", Vector3.new(13, 3, 2), center + Vector3.new(0, 5, 0), GOLD, Enum.Material.Neon)
part("G_Bottom", Vector3.new(13, 3, 2), center + Vector3.new(0, -5, 0), GOLD, Enum.Material.Neon)
part("G_Right", Vector3.new(3, 7, 2), center + Vector3.new(5, -3, 0), GOLD, Enum.Material.Neon)
part("G_Middle", Vector3.new(7, 3, 2), center + Vector3.new(3, 0, 0), GOLD, Enum.Material.Neon)
local crown = part("Crown", Vector3.new(16, 3, 2.5), Vector3.new(0, 32, -25), GOLD, Enum.Material.Metal)
for _, x in ipairs({-6, 0, 6}) do
    ball("CrownJewel", 3.7, Vector3.new(x, 35, -25), CYAN)
end
billboard(crown, "GROWLIVO  •  SKY CROWN", GOLD, 9, 420)

for i = 1, 12 do
    local a = i * math.pi / 6
    local x, z = math.cos(a) * 48, math.sin(a) * 48
    local crystal = part("Crystal_" .. i, Vector3.new(3, 5 + i % 4 * 2, 3), Vector3.new(x, 5, z), CYAN, Enum.Material.Neon)
    crystal.CanCollide = false
end
for _, position in ipairs({Vector2.new(-40, 37), Vector2.new(43, 37), Vector2.new(-43, -38), Vector2.new(43, -38)}) do
    tree(position.X, position.Y)
end
column(-30, 29, "КЛИКАЙ • УЛУЧШАЙСЯ", CYAN)
column(30, 29, "ПЕРЕРОЖДЕНИЯ В МЕНЮ", GOLD)

local eggStand = column(-102, 0, "НЕБЕСНОЕ ЯЙЦО  •  150", GOLD)
local egg = ball("SkyEgg", 10, Vector3.new(-102, 13, -4), CYAN)
egg.Shape = Enum.PartType.Ball
part("EggHalo", Vector3.new(14, 0.5, 14), Vector3.new(-102, 7, -4), GOLD, Enum.Material.Neon)
local prompt = Instance.new("ProximityPrompt")
prompt.Name = "OpenEggShop"
prompt.ActionText = "Открыть яйца"
prompt.ObjectText = "Небесное яйцо"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 14
prompt.RequiresLineOfSight = false
prompt.Parent = eggStand

task.spawn(function()
    local folder = ReplicatedStorage:WaitForChild("GROWLIVO_Remotes", 30)
    if not folder then return end
    local openShop = folder:WaitForChild("OpenEggShop", 30)
    if not openShop then return end
    prompt.Triggered:Connect(function(player)
        openShop:FireClient(player)
    end)
end)

column(102, 0, "УЛУЧШЕНИЯ • В МЕНЮ", CYAN)
local left = part("PortalLeft", Vector3.new(4, 15, 4), Vector3.new(-10, 8, -103), CYAN, Enum.Material.Neon)
part("PortalRight", Vector3.new(4, 15, 4), Vector3.new(10, 8, -103), CYAN, Enum.Material.Neon)
part("PortalTop", Vector3.new(24, 4, 4), Vector3.new(0, 17, -103), GOLD, Enum.Material.Neon)
billboard(left, "ПОРТАЛ В НОВЫЕ МИРЫ", GOLD, 18, 315)


-- Second world: separate island to the east, reachable via the worlds panel.
local VIOLET = Color3.fromRGB(150, 105, 255)
local ICE = Color3.fromRGB(99, 221, 255)
local CRYSTAL_STONE = Color3.fromRGB(53, 62, 113)
local W2_X = 355
local crystalWorld = island("05_CRYSTAL_VALE", W2_X, 0, 112, 108)
local crystalFloor = part("CrystalFloor", Vector3.new(90, 1.2, 91), Vector3.new(W2_X, 1.6, 0), CRYSTAL_STONE, Enum.Material.Metal, crystalWorld)
crystalFloor.CanCollide = true
local crystalSpawn = part("CrystalArrival", Vector3.new(13, 1, 13), Vector3.new(W2_X, 2.5, 22), ICE, Enum.Material.Neon, crystalWorld)
crystalSpawn.Transparency = 0.25
local function obelisk(x, z, height, tint)
    local base = part("CrystalBase", Vector3.new(8, 3, 8), Vector3.new(x, 3, z), CRYSTAL_STONE, Enum.Material.Metal, crystalWorld)
    local column = part("CrystalObelisk", Vector3.new(5, height, 5), Vector3.new(x, 4 + height / 2, z), tint, Enum.Material.Neon, crystalWorld)
    column.Orientation = Vector3.new(0, 45, 0)
    column.CanCollide = false
    base.CanCollide = true
    local tip = ball("CrystalTip", 5, Vector3.new(x, 5 + height, z), tint, crystalWorld)
    tip.CanCollide = false
end
for i = 1, 12 do
    local theta = i * math.pi / 6
    local radius = (i % 2 == 0) and 44 or 36
    obelisk(W2_X + math.cos(theta) * radius, math.sin(theta) * radius, 9 + (i % 4) * 4, i % 2 == 0 and ICE or VIOLET)
end
local w2Crown = column(W2_X, -26, "CRYSTAL VALE  •  КЛИКИ x2", ICE)
part("CrystalGateLeft", Vector3.new(4, 16, 5), Vector3.new(W2_X - 11, 10, -30), VIOLET, Enum.Material.Neon, crystalWorld)
part("CrystalGateRight", Vector3.new(4, 16, 5), Vector3.new(W2_X + 11, 10, -30), VIOLET, Enum.Material.Neon, crystalWorld)
part("CrystalGateTop", Vector3.new(26, 3, 5), Vector3.new(W2_X, 19, -30), GOLD, Enum.Material.Neon, crystalWorld)
local crystalEggBase = part("CrystalEggStand", Vector3.new(16, 5, 12), Vector3.new(W2_X - 25, 5, 3), DEEP, Enum.Material.Metal, crystalWorld)
local crystalEggModel = ball("CrystalEgg", 10, Vector3.new(W2_X - 25, 14, 3), VIOLET, crystalWorld)
crystalEggModel.CanCollide = false
billboard(crystalEggBase, "КРИСТАЛЬНОЕ ЯЙЦО  •  2500", ICE, 10, 300)
local crystalEggPrompt = Instance.new("ProximityPrompt")
crystalEggPrompt.ActionText = "Открыть яйца"
crystalEggPrompt.ObjectText = "Кристальное яйцо"
crystalEggPrompt.HoldDuration = 0
crystalEggPrompt.MaxActivationDistance = 13
crystalEggPrompt.RequiresLineOfSight = false
crystalEggPrompt.Parent = crystalEggBase
local worldPromptBase = part("WorldPortalConsole", Vector3.new(10, 4, 10), Vector3.new(0, 5, -107), DEEP, Enum.Material.Metal, world)
local worldPrompt = Instance.new("ProximityPrompt")
worldPrompt.ActionText = "Открыть миры"
worldPrompt.ObjectText = "Межмировой портал"
worldPrompt.HoldDuration = 0
worldPrompt.MaxActivationDistance = 13
worldPrompt.RequiresLineOfSight = false
worldPrompt.Parent = worldPromptBase
local returnPortal = part("ReturnPortal", Vector3.new(11, 4, 10), Vector3.new(W2_X + 28, 5, 3), DEEP, Enum.Material.Metal, crystalWorld)
billboard(returnPortal, "ПОРТАЛ • ВЫБОР МИРА", GOLD, 9, 240)
local returnPrompt = Instance.new("ProximityPrompt")
returnPrompt.ActionText = "Выбрать мир"
returnPrompt.ObjectText = "Обратный портал"
returnPrompt.HoldDuration = 0
returnPrompt.MaxActivationDistance = 13
returnPrompt.RequiresLineOfSight = false
returnPrompt.Parent = returnPortal
-- World scripts only open UI. Teleport, unlock and egg payments are validated on the server.
task.spawn(function()
    local folder = ReplicatedStorage:WaitForChild("GROWLIVO_Remotes", 30)
    if not folder then return end
    local eggRemote = folder:WaitForChild("OpenEggShop", 30)
    local worldRemote = folder:WaitForChild("OpenWorldMenu", 30)
    if eggRemote then
        crystalEggPrompt.Triggered:Connect(function(player)
            -- Avoid offering the second-world egg to players who are elsewhere.
            if player:GetAttribute("World") == "CrystalVale" then eggRemote:FireClient(player) end
        end)
    end
    if worldRemote then
        worldPrompt.Triggered:Connect(function(player) worldRemote:FireClient(player) end)
        returnPrompt.Triggered:Connect(function(player) worldRemote:FireClient(player) end)
    end
end)


-- Alpha 0.9.20: AURORA GROVE. Independent third island, green aurora beams,
-- giant luminous tree, an egg sanctuary and a return portal.
-- Gameplay unlocks and hatch costs are still decided by GrowlivoServer.
local W3_X = -355
local MINT = Color3.fromRGB(109, 255, 190)
local PINK = Color3.fromRGB(255, 152, 231)
local GROVE_STONE = Color3.fromRGB(52, 84, 91)
local GROVE_GRASS = Color3.fromRGB(45, 133, 110)
local grove = Instance.new("Model")
grove.Name = "08_AURORA_GROVE"
grove.Parent = world
part("GroveFloatingRock", Vector3.new(120, 12, 115), Vector3.new(W3_X, -7, 0), GROVE_STONE, Enum.Material.Slate, grove)
part("GroveMoss", Vector3.new(116, 2, 111), Vector3.new(W3_X, 0, 0), GROVE_GRASS, Enum.Material.Grass, grove)
local groveRim = part("GroveRim", Vector3.new(119, 0.65, 114), Vector3.new(W3_X, -1.3, 0), MINT, Enum.Material.Neon, grove)
groveRim.CanCollide = false
local arrival = part("AuroraArrival", Vector3.new(13, 1, 13), Vector3.new(W3_X, 2.5, 25), MINT, Enum.Material.Neon, grove)
arrival.Transparency = 0.28
for i = 1, 12 do
    local theta = i * math.pi / 6
    local x, z = W3_X + math.cos(theta) * 44, math.sin(theta) * 42
    local stump = part("AuroraTrunk", Vector3.new(3.5, 12, 3.5), Vector3.new(x, 7, z), GROVE_STONE, Enum.Material.Wood, grove)
    local canopy = ball("AuroraCanopy", i % 3 == 0 and 13 or 10, Vector3.new(x, 15, z), i % 2 == 0 and MINT or PINK, grove)
    canopy.Material = Enum.Material.Neon
    canopy.Transparency = 0.34
    stump.CanCollide = false
    canopy.CanCollide = false
end
-- Central landmark tree; trunk is intentionally away from the arrival pad.
local ancientTrunk = part("AncientAuroraTree", Vector3.new(11, 34, 11), Vector3.new(W3_X, 19, -25), GROVE_STONE, Enum.Material.Wood, grove)
local ancientCrown = ball("AuroraTreeCrown", 28, Vector3.new(W3_X, 40, -25), MINT, grove)
ancientCrown.Material = Enum.Material.Glass
ancientCrown.Transparency = 0.18
ancientCrown.CanCollide = false
billboard(ancientTrunk, "AURORA GROVE  •  КЛИКИ x4", MINT, 27, 330)
local glowTree = Instance.new("PointLight")
glowTree.Name = "AuroraTreeLight"
glowTree.Color = MINT
glowTree.Brightness = 1.5
glowTree.Range = 40
glowTree.Shadows = false
glowTree.Parent = ancientCrown
for i = 1, 10 do
    local theta = 2 * math.pi * i / 10
    local shard = part("AuroraRune", Vector3.new(2.8, 9 + (i % 3) * 3, 2.8),
        Vector3.new(W3_X + math.cos(theta) * 31, 5.6, -15 + math.sin(theta) * 28),
        i % 2 == 0 and MINT or PINK, Enum.Material.Neon, grove)
    shard.Orientation = Vector3.new(0, 45, 18)
    shard.CanCollide = false
end
local groveEggBase = part("AuroraEggStand", Vector3.new(15, 5, 12), Vector3.new(W3_X - 25, 5, 6), GROVE_STONE, Enum.Material.Metal, grove)
local groveEgg = ball("AuroraEgg", 10, Vector3.new(W3_X - 25, 14, 6), PINK, grove)
groveEgg.Material = Enum.Material.Neon
groveEgg.CanCollide = false
billboard(groveEggBase, "ЯЙЦО СИЯНИЯ  •  15000", MINT, 10, 320)
local groveEggPrompt = Instance.new("ProximityPrompt")
groveEggPrompt.Name = "OpenAuroraEgg"
groveEggPrompt.ActionText = "Открыть яйца"
groveEggPrompt.ObjectText = "Яйцо сияния"
groveEggPrompt.KeyboardKeyCode = Enum.KeyCode.E
groveEggPrompt.MaxActivationDistance = 13
groveEggPrompt.HoldDuration = 0
groveEggPrompt.RequiresLineOfSight = false
groveEggPrompt.Parent = groveEggBase
local grovePortal = part("AuroraReturnPortal", Vector3.new(11, 4, 10), Vector3.new(W3_X + 29, 5, 6), GROVE_STONE, Enum.Material.Metal, grove)
billboard(grovePortal, "ПОРТАЛ • ВЫБОР МИРА", MINT, 9, 260)
local grovePrompt = Instance.new("ProximityPrompt")
grovePrompt.Name = "OpenWorlds"
grovePrompt.ActionText = "Выбрать мир"
grovePrompt.ObjectText = "Портал Рощи сияния"
grovePrompt.MaxActivationDistance = 13
grovePrompt.HoldDuration = 0
grovePrompt.RequiresLineOfSight = false
grovePrompt.Parent = grovePortal
for z = 0, 23, 6 do
    local tile = part("AuroraPath", Vector3.new(9, 0.2, 5.4), Vector3.new(W3_X, 1.16, z), PINK, Enum.Material.Glass, grove)
    tile.CanCollide = false
    tile.Transparency = 0.25
end
-- Prompts open an existing UI; they never grant worlds, currencies or pets.
task.spawn(function()
    local folder = ReplicatedStorage:WaitForChild("GROWLIVO_Remotes", 30)
    if not folder then return end
    local eggsEvent = folder:WaitForChild("OpenEggShop", 30)
    local worldsEvent = folder:WaitForChild("OpenWorldMenu", 30)
    if eggsEvent then
        groveEggPrompt.Triggered:Connect(function(player)
            if player:GetAttribute("World") == "AuroraGrove" then
                eggsEvent:FireClient(player)
            end
        end)
    end
    if worldsEvent then
        grovePrompt.Triggered:Connect(function(player)
            if player:GetAttribute("World") == "AuroraGrove" then
                worldsEvent:FireClient(player)
            end
        end)
    end
end)

-- Alpha 0.9.14: polished landmarks and low-cost, asset-free visual dressing.
-- All props stay inside GROWLIVO_World and disappear when the world regenerates.
local function decoration(name, size, where, tint, material, parent)
    local result = part(name, size, where, tint, material, parent)
    result.CanCollide = false
    result.CanTouch = false
    result.CanQuery = false
    return result
end
local function glow(object, tint, range, brightness)
    local light = Instance.new("PointLight")
    light.Name = "RoyalGlow"
    light.Color = tint
    light.Range = range or 15
    light.Brightness = brightness or 0.75
    light.Shadows = false
    light.Parent = object
end
local function shimmer(object, tint, rate)
    local emit = Instance.new("ParticleEmitter")
    emit.Name = "CrystalShimmer"
    emit.Rate = rate or 2
    emit.Lifetime = NumberRange.new(0.6, 1.5)
    emit.Speed = NumberRange.new(0.5, 1.6)
    emit.SpreadAngle = Vector2.new(35, 35)
    emit.LightEmission = 0.7
    emit.Color = ColorSequence.new(tint, WHITE)
    emit.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0)})
    emit.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1)})
    emit.Parent = object
end
local decor = Instance.new("Model")
decor.Name = "06_ROYAL_DECOR"
decor.Parent = world

-- Crown-ring silhouette: luminous ring behind the central G landmark.
local radius = 18
for i = 1, 28 do
    local angleA = (i - 1) * 2 * math.pi / 28
    local angleB = i * 2 * math.pi / 28
    local from = Vector3.new(math.cos(angleA) * radius, 24 + math.sin(angleA) * radius, -32)
    local to = Vector3.new(math.cos(angleB) * radius, 24 + math.sin(angleB) * radius, -32)
    local beam = decoration("MonumentHaloSegment", Vector3.new(1.25, 1.25, (to - from).Magnitude + 0.2), (from + to) / 2, i % 5 == 0 and CYAN or GOLD, Enum.Material.Neon, decor)
    beam.CFrame = CFrame.lookAt((from + to) / 2, to)
end

-- Landmark arch deliberately leaves the middle of the walking path clear.
for _, x in ipairs({-19, 19}) do
    decoration("ArrivalArchColumn", Vector3.new(3.5, 18, 3.5), Vector3.new(x, 10, 12), DEEP, Enum.Material.Metal, decor)
    local cap = decoration("ArrivalArchGem", Vector3.new(5, 5, 5), Vector3.new(x, 20.5, 12), CYAN, Enum.Material.Neon, decor)
    cap.Shape = Enum.PartType.Ball
    glow(cap, CYAN, 16, 0.6)
end
decoration("ArrivalArchLintel", Vector3.new(42, 2.8, 4), Vector3.new(0, 21.5, 12), GOLD, Enum.Material.Metal, decor)
decoration("ArrivalArchInlay", Vector3.new(40, 0.7, 4.2), Vector3.new(0, 23.2, 12), CYAN, Enum.Material.Neon, decor)

-- Four compact fountain plinths, with shimmering magical cores.
for _, position in ipairs({Vector2.new(-35, 4), Vector2.new(35, 4), Vector2.new(-35, -20), Vector2.new(35, -20)}) do
    local x, z = position.X, position.Y
    decoration("FountainBase", Vector3.new(10, 2, 10), Vector3.new(x, 2, z), DEEP, Enum.Material.Marble, decor)
    local bowl = decoration("FountainWater", Vector3.new(8, 0.5, 8), Vector3.new(x, 3.25, z), CYAN, Enum.Material.Neon, decor)
    bowl.Transparency = 0.22
    local gem = decoration("FountainCrystal", Vector3.new(3, 7, 3), Vector3.new(x, 8, z), GOLD, Enum.Material.Neon, decor)
    gem.Orientation = Vector3.new(0, 45, 23)
    shimmer(gem, GOLD, 3)
end

-- Sky waterfalls dropping past the edge: decorative, zero collision.
for _, x in ipairs({-31, 31}) do
    local waterfall = decoration("SkyWaterfall", Vector3.new(9, 30, 0.8), Vector3.new(x, -13, 60.9), CYAN, Enum.Material.Neon, decor)
    waterfall.Transparency = 0.4
    shimmer(waterfall, CYAN, 4)
end

-- Soft suspended clouds under and between islands (purely atmospheric).
for i = 1, 18 do
    local theta = i * 2.399963229728653
    local distance = 78 + (i % 5) * 24
    local x, z = math.cos(theta) * distance, math.sin(theta) * distance
    local cloud = decoration("CloudBank", Vector3.new(20 + i % 4 * 6, 6 + i % 3 * 2, 14 + i % 4 * 4), Vector3.new(x, -18 - i % 3 * 5, z), WHITE, Enum.Material.SmoothPlastic, decor)
    cloud.Shape = Enum.PartType.Ball
    cloud.Transparency = 0.45
end

-- Egg islands receive larger glowing egg pedestals and navigational beacons.
for _, spec in ipairs({
    {Pos = Vector3.new(-102, 12, -4), Color = GOLD},
    {Pos = Vector3.new(W2_X - 25, 14, 3), Color = VIOLET},
}) do
    local shell = decoration("EggGlaze", Vector3.new(7, 9, 7), spec.Pos + Vector3.new(0, 0.5, 0), spec.Color, Enum.Material.Glass, decor)
    shell.Shape = Enum.PartType.Ball
    shell.Transparency = 0.45
    shimmer(shell, spec.Color, 2)
    glow(shell, spec.Color, 18, 0.9)
end

-- A dedicated quest and trophy spot helps players orient without duplicating game UI.
local questsSign = decoration("QuestMonolith", Vector3.new(11, 13, 4), Vector3.new(-27, 7.5, 47), DEEP, Enum.Material.Metal, decor)
decoration("QuestMonolithInlay", Vector3.new(9, 8, 0.4), Vector3.new(-27, 9.5, 44.8), GOLD, Enum.Material.Neon, decor)
billboard(questsSign, "ЗАДАНИЯ • ОТКРОЙ МЕНЮ", WHITE, 12, 270)
local trophySign = decoration("TrophyMonolith", Vector3.new(11, 13, 4), Vector3.new(27, 7.5, 47), DEEP, Enum.Material.Metal, decor)
decoration("TrophyMonolithInlay", Vector3.new(9, 8, 0.4), Vector3.new(27, 9.5, 44.8), CYAN, Enum.Material.Neon, decor)
billboard(trophySign, "ДОСТИЖЕНИЯ • МЕНЮ", WHITE, 12, 270)

-- Decorative spires in Crystal Vale, spaced away from its main paths.
for i = 1, 8 do
    local a = i * math.pi / 4
    local x, z = W2_X + math.cos(a) * 40, math.sin(a) * 40
    local shard = decoration("ValleyShard", Vector3.new(3.5, 11 + (i % 3) * 4, 3.5), Vector3.new(x, 8, z), i % 2 == 0 and ICE or VIOLET, Enum.Material.Glass, decor)
    shard.Orientation = Vector3.new(0, 45, i % 3 * 8)
    shimmer(shard, i % 2 == 0 and ICE or VIOLET, 2)
end

-- Alpha 0.9.14: navigable royal cobblestones and signature lanterns.
-- Decorative pieces deliberately have no collision and don't block avatars.
local royalPath = Instance.new("Model")
royalPath.Name = "07_ROYAL_PATHS"
royalPath.Parent = world
for z = -12, 39, 6 do
    local tile = decoration("CrownWalkway", Vector3.new(12, 0.15, 5.6), Vector3.new(0, 1.13, z), DEEP, Enum.Material.Slate, royalPath)
    tile.Transparency = 0.06
    for _, x in ipairs({-5.4, 5.4}) do
        local stripe = decoration("GoldenWalkwayEdge", Vector3.new(0.5, 0.18, 5.3), Vector3.new(x, 1.22, z), GOLD, Enum.Material.Metal, royalPath)
        stripe.Reflectance = 0.08
    end
end
for _, x in ipairs({-8, 8}) do
    for _, z in ipairs({-18, 2, 22, 42}) do
        local column = decoration("RoyalLanternPost", Vector3.new(0.7, 5, 0.7), Vector3.new(x, 3.7, z), DEEP, Enum.Material.Metal, royalPath)
        column.CanCollide = false
        local orb = decoration("RoyalLanternOrb", Vector3.new(2.1, 2.1, 2.1), Vector3.new(x, 6.4, z), CYAN, Enum.Material.Neon, royalPath)
        orb.Shape = Enum.PartType.Ball
        glow(orb, CYAN, 9, 0.35)
        decoration("RoyalLanternCrown", Vector3.new(2.5, 0.35, 2.5), Vector3.new(x, 7.6, z), GOLD, Enum.Material.Metal, royalPath)
    end
end
-- Crystal Vale has its own welcoming pathway and a glowing landmark.
for z = -12, 28, 8 do
    decoration("CrystalPath", Vector3.new(9, 0.18, 7), Vector3.new(W2_X, 2.35, z), VIOLET, Enum.Material.Glass, royalPath).Transparency = 0.4
end
local valeOrb = decoration("ValeBeacon", Vector3.new(8, 8, 8), Vector3.new(W2_X, 15, -26), ICE, Enum.Material.Glass, royalPath)
valeOrb.Shape = Enum.PartType.Ball
valeOrb.Transparency = 0.18
glow(valeOrb, ICE, 23, 1.1)
shimmer(valeOrb, ICE, 5)

-- Alpha 0.9.21: three rune shrines in each world (server-handled Prompts).
-- All runes are cosmetic and non-collidable; the core platform remains walkable.
local runeModel = Instance.new("Model")
runeModel.Name = "09_RUNE_EXPEDITIONS"
runeModel.Parent = world

local function buildRune(worldId, runeIndex, x, z, groundY, tint)
    local y = groundY + 1.8
    local base = decoration("RunePedestal", Vector3.new(6, 2, 6), Vector3.new(x, y, z), DEEP, Enum.Material.Metal, runeModel)
    base.CanCollide = false
    local ornament = decoration("RuneCore", Vector3.new(3.2, 5.2, 2.0), Vector3.new(x, y + 3.8, z), tint, Enum.Material.Neon, runeModel)
    ornament.Orientation = Vector3.new(0, 45, 25)
    ornament.CanCollide = false
    ornament.Transparency = 0.13
    local halo = decoration("RuneHalo", Vector3.new(7.2, 0.25, 7.2), Vector3.new(x, groundY + 0.65, z), tint, Enum.Material.Neon, runeModel)
    halo.Transparency = 0.28
    halo.CanCollide = false
    glow(ornament, tint, 12, 0.65)
    billboard(ornament, "РУНА " .. runeIndex .. "/3  •  E", tint, 6.5, 178)
    -- Attributes are set by the world builder, never supplied by the client.
    base:SetAttribute("RuneWorld", worldId)
    base:SetAttribute("RuneIndex", runeIndex)
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "GrowlivoRunePrompt"
    prompt.ActionText = "Активировать руну"
    prompt.ObjectText = "Руна " .. runeIndex .. "/3"
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.MaxActivationDistance = 12
    prompt.HoldDuration = 0.35
    prompt.RequiresLineOfSight = false
    prompt.Parent = base
end

for _, row in ipairs({
    {"SkyCrown", 1, -36, -6, 1, GOLD},
    {"SkyCrown", 2, 36, 8, 1, CYAN},
    {"SkyCrown", 3, 0, 48, 1, GOLD},
    {"CrystalVale", 1, W2_X - 29, -20, 2.2, ICE},
    {"CrystalVale", 2, W2_X + 30, -5, 2.2, VIOLET},
    {"CrystalVale", 3, W2_X + 6, 33, 2.2, ICE},
    {"AuroraGrove", 1, W3_X - 34, -13, 1, MINT},
    {"AuroraGrove", 2, W3_X + 34, -13, 1, PINK},
    {"AuroraGrove", 3, W3_X + 4, 38, 1, MINT},
}) do
    buildRune(row[1], row[2], row[3], row[4], row[5], row[6])
end

-- Each world receives restrained landmark accents and an accessible path.
local accentModel = Instance.new("Model")
accentModel.Name = "10_WORLD_ACCENTS"
accentModel.Parent = world
for _, x in ipairs({-12, 12}) do
    for _, z in ipairs({-48, -32, -15}) do
        local pennant = decoration("SkyBanner", Vector3.new(1.6, 8, 0.35), Vector3.new(x, 7, z), GOLD, Enum.Material.Metal, accentModel)
        pennant.CanCollide = false
        local jewel = decoration("BannerGem", Vector3.new(1, 1, 1), Vector3.new(x, 10, z - 0.25), CYAN, Enum.Material.Neon, accentModel)
        jewel.Shape = Enum.PartType.Ball
        jewel.CanCollide = false
    end
end
for _, dx in ipairs({-23, 23}) do
    for _, z in ipairs({-36, 12, 36}) do
        local crystalAccent = decoration("ValePrism", Vector3.new(2, 6.5, 2), Vector3.new(W2_X + dx, 5.4, z), VIOLET, Enum.Material.Glass, accentModel)
        crystalAccent.Orientation = Vector3.new(0, 45, 17)
        crystalAccent.CanCollide = false
    end
end
for z = -10, 35, 5 do
    local tile = decoration("GroveTrail", Vector3.new(9.2, 0.18, 4.3), Vector3.new(W3_X, 1.18, z), PINK, Enum.Material.Glass, accentModel)
    tile.Transparency = 0.58
    tile.CanCollide = false
end


-- Alpha 0.9.24: three daily treasure chests, one for each world.
-- Visual-only map objects. Rewards and per-player claims are server-validated.
local chestGroup = Instance.new("Model")
chestGroup.Name = "11_WORLD_CHESTS"
chestGroup.Parent = world
local function makeChest(worldId, x, z, groundY, accent)
    local p = Vector3.new(x, groundY + 2.2, z)
    local body = part("WorldTreasureChest", Vector3.new(7, 4.4, 5), p, DEEP, Enum.Material.WoodPlanks, chestGroup)
    body:SetAttribute("ChestWorld", worldId)
    part("TreasureLid", Vector3.new(7.8, 1.1, 5.5), p + Vector3.new(0, 2.6, 0), GOLD, Enum.Material.Metal, chestGroup)
    local lock = part("TreasureLock", Vector3.new(1.7, 1.7, 0.45), p + Vector3.new(0, 0.5, -2.7), accent, Enum.Material.Neon, chestGroup)
    lock.CanCollide = false
    local highlight = Instance.new("PointLight")
    highlight.Brightness = 0.7
    highlight.Range = 14
    highlight.Color = accent
    highlight.Parent = lock
    billboard(body, "СУНДУК ДНЯ  •  E", accent, 7, 240)
    local prompt = Instance.new("ProximityPrompt")
    prompt.Name = "GrowlivoChestPrompt"
    prompt.ActionText = "Забрать награду"
    prompt.ObjectText = "Ежедневный сундук"
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.HoldDuration = 0.5
    prompt.MaxActivationDistance = 12
    prompt.RequiresLineOfSight = false
    prompt.Parent = body
end
makeChest("SkyCrown", 32, 32, 1, CYAN)
makeChest("CrystalVale", W2_X + 30, 30, 2.2, ICE)
makeChest("AuroraGrove", W3_X + 28, 31, 1, PINK)

for _, name in ipairs({"GROWLIVO_Bloom", "GROWLIVO_Atmosphere", "GROWLIVO_SunRays"}) do
    local effect = Lighting:FindFirstChild(name)
    if effect then effect:Destroy() end
end
local bloom = Instance.new("BloomEffect")
bloom.Name = "GROWLIVO_Bloom"
bloom.Intensity = 0.38
bloom.Size = 24
bloom.Threshold = 1.25
bloom.Parent = Lighting
local atmosphere = Instance.new("Atmosphere")
atmosphere.Name = "GROWLIVO_Atmosphere"
atmosphere.Density = 0.26
atmosphere.Offset = 0.1
atmosphere.Color = Color3.fromRGB(173, 221, 255)
atmosphere.Decay = Color3.fromRGB(74, 119, 174)
atmosphere.Parent = Lighting
local rays = Instance.new("SunRaysEffect")
rays.Name = "GROWLIVO_SunRays"
rays.Intensity = 0.055
rays.Spread = 0.8
rays.Parent = Lighting

Lighting.ClockTime = 13.5
Lighting.Brightness = 2.5
Lighting.Ambient = Color3.fromRGB(116, 143, 196)
Lighting.OutdoorAmbient = Color3.fromRGB(135, 176, 215)
world:SetAttribute("WorldReady", true)
print("[GROWLIVO] World built: Sky Crown + Crystal Vale + Aurora Grove + Royal Decor / " .. Config.Version)
]==]},
    {name="GrowlivoClient", className="LocalScript", target="StarterPlayerScripts", source=[==[-- GROWLIVO / Mobile-friendly clicker and pet inventory UI / Alpha 0.9.27
-- StarterPlayer > StarterPlayerScripts > GrowlivoClient [LocalScript]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("GrowlivoConfig"))
local remotes = ReplicatedStorage:WaitForChild("GROWLIVO_Remotes")
local Action = remotes:WaitForChild("Action")
local Feedback = remotes:WaitForChild("Feedback")
local PetState = remotes:WaitForChild("PetState")
local OpenEggShop = remotes:WaitForChild("OpenEggShop")

local GOLD = Color3.fromRGB(255, 200, 67)
local BLUE = Color3.fromRGB(34, 202, 255)
local PANEL = Color3.fromRGB(22, 35, 60)
local DARK = Color3.fromRGB(13, 24, 44)
local WHITE = Color3.fromRGB(238, 248, 255)
local MUTED = Color3.fromRGB(172, 200, 224)

local gui = Instance.new("ScreenGui")
gui.Name = "GROWLIVO_HUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function rounded(object, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 14)
    corner.Parent = object
    return object
end
local function outlined(object, color, width)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = width or 2
    stroke.Transparency = 0.25
    stroke.Color = color
    stroke.Parent = object
end
local function frame(name, parent, color)
    local f = Instance.new("Frame")
    f.Name = name
    f.BorderSizePixel = 0
    f.BackgroundColor3 = color or PANEL
    f.Parent = parent
    rounded(f)
    return f
end
local function text(name, parent, value, fontSize, color)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.BorderSizePixel = 0
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.Text = value
    label.TextColor3 = color or WHITE
    label.TextSize = fontSize or 16
    label.TextWrapped = true
    label.Parent = parent
    return label
end
local function button(name, parent, value, color)
    local b = Instance.new("TextButton")
    b.Name = name
    b.Text = value
    b.TextColor3 = DARK
    b.TextSize = 17
    b.TextWrapped = true
    b.Font = Enum.Font.GothamBold
    b.BackgroundColor3 = color or GOLD
    b.BorderSizePixel = 0
    b.AutoButtonColor = true
    b.Parent = parent
    rounded(b, 12)
    return b
end
local function pretty(value)
    value = tonumber(value) or 0
    if value >= 1e12 then return string.format("%.2fT", value / 1e12) end
    if value >= 1e9 then return string.format("%.2fB", value / 1e9) end
    if value >= 1e6 then return string.format("%.2fM", value / 1e6) end
    if value >= 1e3 then return string.format("%.1fK", value / 1e3) end
    return tostring(math.floor(value))
end
local function attr(key)
    return player:GetAttribute(key) or 0
end

local title = text("Title", gui, "👑 GROWLIVO  •  " .. string.upper(Config.Version), 22, GOLD)
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.new(0.5, 0, 0, 7)
title.Size = UDim2.fromOffset(330, 40)
title.TextStrokeTransparency = 0.55
local tapFlash = Instance.new("BindableEvent")
tapFlash.Name = "TapFlash"
tapFlash.Parent = gui

local stats = frame("Stats", gui, PANEL)
outlined(stats, BLUE)
local statPadding = Instance.new("UIPadding")
statPadding.PaddingLeft = UDim.new(0, 12)
statPadding.PaddingRight = UDim.new(0, 6)
statPadding.PaddingTop = UDim.new(0, 8)
statPadding.Parent = stats
local statLayout = Instance.new("UIListLayout")
statLayout.SortOrder = Enum.SortOrder.LayoutOrder
statLayout.Parent = stats
local statFields = {}
for i, name in ipairs({"Clicks", "Gems", "Rebirths", "Power", "Pets"}) do
    local label = text(name, stats, "—", 15, WHITE)
    label.Size = UDim2.new(1, 0, 0, 25)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.LayoutOrder = i
    statFields[name] = label
end
local actions = frame("ActionPanel", gui, PANEL)
outlined(actions, GOLD)
local upgrade = button("Upgrade", actions, "УЛУЧШИТЬ", BLUE)
local bulkUpgrade = button("Upgrade5", actions, "⚡ ×5", BLUE)
local rebirth = button("Rebirth", actions, "ПЕРЕРОЖДЕНИЕ", GOLD)
local petsButton = button("Pets", gui, "🐾 ПИТОМЦЫ", BLUE)
local autoTapButton = button("AutoTap", gui, "🤖 АВТОКЛИК", GOLD)
autoTapButton.TextSize = 12
local menuToggle = button("CompactMenu", gui, "☰ МЕНЮ", BLUE)
menuToggle.TextSize = 13
menuToggle.Visible = false
player:SetAttribute("CompactMenuOpen", false) -- client HUD state, never trusted by the server
local clickButton = button("Click", gui, "+1 КЛИК", GOLD)
clickButton.TextSize = 29
outlined(clickButton, WHITE)

local toast = text("Toast", gui, "", 16, WHITE)
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.TextStrokeTransparency = 0.2
local toastNonce = 0
local function message(value)
    toastNonce += 1
    local nonce = toastNonce
    toast.Text = tostring(value)
    task.delay(3, function()
        if nonce == toastNonce then
            toast.Text = ""
        end
    end)
end

local shade = frame("ModalBackdrop", gui, Color3.fromRGB(0, 0, 0))
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundTransparency = 0.25
shade.Visible = false
shade.ZIndex = 10
shade.Active = true
shade.ClipsDescendants = true
local modal = frame("PetsPanel", shade, PANEL)
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.fromScale(0.5, 0.5)
modal.ZIndex = 11
outlined(modal, GOLD)
local heading = text("Heading", modal, "🐾  ПИТОМЦЫ И ЯЙЦА", 22, GOLD)
heading.Position = UDim2.fromOffset(12, 7)
heading.Size = UDim2.new(1, -72, 0, 46)
heading.ZIndex = 12
local close = button("Close", modal, "✕", GOLD)
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -12, 0, 10)
close.Size = UDim2.fromOffset(43, 38)
close.ZIndex = 12
local hatch = button("Hatch", modal, "🥚 ОТКРЫТЬ ЯЙЦО", BLUE)
hatch.Position = UDim2.new(0, 12, 0, 60)
hatch.Size = UDim2.new(0.64, -14, 0, 53)
hatch.TextSize = 15
hatch.ZIndex = 12
local hatch3 = button("Hatch3", modal, "🥚 ×3", GOLD)
hatch3.Position = UDim2.new(0.64, 4, 0, 60)
hatch3.Size = UDim2.new(0.36, -16, 0, 53)
hatch3.TextSize = 14
hatch3.ZIndex = 12
local odds = text("Odds", modal, "Шансы выпадения", 12, MUTED)
odds.Position = UDim2.new(0, 12, 0, 118)
odds.Size = UDim2.new(1, -24, 0, 37)
odds.ZIndex = 12
local inventoryTitle = text("InventoryTitle", modal, "ИНВЕНТАРЬ: 0/60   |   НАДЕТО: 0/3", 14, WHITE)
inventoryTitle.Position = UDim2.new(0, 12, 0, 160)
inventoryTitle.Size = UDim2.new(1, -24, 0, 28)
inventoryTitle.TextXAlignment = Enum.TextXAlignment.Left
inventoryTitle.ZIndex = 12

-- Client-side inventory tools: these never alter saved pets or the server economy.
local search = Instance.new("TextBox")
search.Name = "PetSearch"
search.Position = UDim2.new(0, 12, 0, 190)
search.Size = UDim2.new(0.49, -12, 0, 34)
search.BackgroundColor3 = DARK
search.TextColor3 = WHITE
search.PlaceholderColor3 = MUTED
search.PlaceholderText = "Поиск питомца"
search.Text = ""
search.TextSize = 12
search.Font = Enum.Font.Gotham
search.ClearTextOnFocus = false
search.BorderSizePixel = 0
search.ZIndex = 12
search.Parent = modal
rounded(search, 9)
local sortButton = button("PetSort", modal, "СИЛА ↓", BLUE)
sortButton.Position = UDim2.new(0.49, 6, 0, 190)
sortButton.Size = UDim2.new(0.255, -10, 0, 34)
sortButton.TextSize = 11
sortButton.ZIndex = 12
local equippedFilter = button("EquippedFilter", modal, "ВСЕ", GOLD)
equippedFilter.Position = UDim2.new(0.745, 2, 0, 190)
equippedFilter.Size = UDim2.new(0.255, -14, 0, 34)
equippedFilter.TextSize = 11
equippedFilter.ZIndex = 12

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Inventory"
scroll.Position = UDim2.new(0, 12, 0, 231)
scroll.Size = UDim2.new(1, -24, 1, -298)
scroll.BackgroundColor3 = DARK
scroll.BackgroundTransparency = 0.2
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 5
scroll.ScrollBarImageColor3 = BLUE
scroll.CanvasSize = UDim2.fromOffset(0, 0)
scroll.ZIndex = 12
scroll.Parent = modal
rounded(scroll, 8)
local scrollPad = Instance.new("UIPadding")
scrollPad.PaddingTop = UDim.new(0, 7)
scrollPad.PaddingLeft = UDim.new(0, 8)
scrollPad.PaddingRight = UDim.new(0, 8)
scrollPad.Parent = scroll
local list = Instance.new("UIListLayout")
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Padding = UDim.new(0, 6)
list.Parent = scroll
list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scroll.CanvasSize = UDim2.fromOffset(0, list.AbsoluteContentSize.Y + 18)
end)
local best = button("EquipBest", modal, "⚡ НАДЕТЬ ЛУЧШИХ", GOLD)
best.AnchorPoint = Vector2.new(0, 1)
best.Position = UDim2.new(0, 12, 1, -12)
best.Size = UDim2.new(0.64, -16, 0, 47)
best.ZIndex = 12
local unequip = button("UnequipAll", modal, "СНЯТЬ ВСЕХ", BLUE)
unequip.AnchorPoint = Vector2.new(0, 1)
unequip.Position = UDim2.new(0.64, 4, 1, -12)
unequip.Size = UDim2.new(0.36, -16, 0, 47)
unequip.TextSize = 12
unequip.ZIndex = 12

local currentPets = {}
local currentEquipped = {}
local petsDirty = true
local pendingReleaseId = nil
local pendingReleaseButton = nil
local pendingReleaseNonce = 0
local pendingFuseSpecies = nil
local pendingFuseButton = nil
local pendingFuseNonce = 0
local sortMode = "Power" -- Power / New / Old
local equippedOnly = false
local sortNames = {Power = "СИЛА ↓", New = "НОВЫЕ", Old = "СТАРЫЕ"}
-- Lua string.lower handles ASCII but not Cyrillic. Small explicit mapping keeps
-- Russian-name searches case-insensitive without any external dependencies.
local uppercase = {"А","Б","В","Г","Д","Е","Ё","Ж","З","И","Й","К","Л","М","Н","О","П","Р","С","Т","У","Ф","Х","Ц","Ч","Ш","Щ","Ъ","Ы","Ь","Э","Ю","Я"}
local lowercase = {"а","б","в","г","д","е","ё","ж","з","и","й","к","л","м","н","о","п","р","с","т","у","ф","х","ц","ч","ш","щ","ъ","ы","ь","э","ю","я"}
local function normalizeSearch(value)
    value = string.lower(tostring(value or ""))
    for i, letter in ipairs(uppercase) do
        value = string.gsub(value, letter, lowercase[i])
    end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end
local function clearReleaseConfirmation()
    if pendingReleaseButton and pendingReleaseButton.Parent and pendingReleaseButton.Active then
        pendingReleaseButton.Text = "ОТПУСТИТЬ"
    end
    pendingReleaseId = nil
    pendingReleaseButton = nil
    pendingReleaseNonce += 1
end
local function clearFuseConfirmation()
    if pendingFuseButton and pendingFuseButton.Parent then
        pendingFuseButton.Text = "✨ СЛИТЬ"
    end
    pendingFuseSpecies = nil
    pendingFuseButton = nil
    pendingFuseNonce += 1
end
local function repaintPets()
    petsDirty = false
    clearReleaseConfirmation() -- destroyed row buttons must not retain confirmations
    clearFuseConfirmation()
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    local marked = {}
    for _, id in ipairs(currentEquipped) do marked[id] = true end
    local availableBySpecies = {}
    for _, item in ipairs(currentPets) do
        if not marked[item.Id] then
            availableBySpecies[item.Species] = (availableBySpecies[item.Species] or 0) + 1
        end
    end
    local query = normalizeSearch(search.Text)
    local visiblePets = {}
    for _, item in ipairs(currentPets) do
        local definition = Config.FindPet(item.Species)
        if definition and (not equippedOnly or marked[item.Id]) then
            local words = normalizeSearch(definition.Name .. " " .. definition.Rarity .. " " .. item.Species .. " " .. tostring(item.Id))
            if query == "" or string.find(words, query, 1, true) then
                table.insert(visiblePets, item)
            end
        end
    end
    table.sort(visiblePets, function(a, b)
        if sortMode == "New" then return a.Id > b.Id end
        if sortMode == "Old" then return a.Id < b.Id end
        local petA, petB = Config.FindPet(a.Species), Config.FindPet(b.Species)
        local powerA, powerB = petA and petA.Bonus or 0, petB and petB.Bonus or 0
        if powerA == powerB then return a.Id < b.Id end
        return powerA > powerB
    end)
    inventoryTitle.Text = string.format("ИНВЕНТАРЬ: %d/%d | НАДЕТО: %d/%d | ПОКАЗАНО: %d",
        #currentPets, Config.MaxPetInventory, #currentEquipped, Config.MaxEquippedPets, #visiblePets)
    if #visiblePets == 0 then
        local empty = frame("Empty", scroll, DARK)
        empty.Size = UDim2.new(1, -4, 0, 55)
        empty.ZIndex = 13
        local info = text("Info", empty, #currentPets == 0 and "Пока нет питомцев. Открой яйцо!" or "По запросу питомцев не найдено", 13, MUTED)
        info.ZIndex = 14
        return
    end
    for index, item in ipairs(visiblePets) do
        local definition = Config.FindPet(item.Species)
        if definition then
            local row = frame("Pet_" .. tostring(item.Id), scroll, PANEL)
            row.Size = UDim2.new(1, -4, 0, 115)
            row.LayoutOrder = index
            row.ZIndex = 13
            local name = text("PetName", row, definition.Name .. "  •  +" .. tostring(definition.Bonus) .. "%", 14, definition.Color)
            name.Position = UDim2.fromOffset(9, 4)
            name.Size = UDim2.new(1, -18, 0, 25)
            name.TextXAlignment = Enum.TextXAlignment.Left
            name.ZIndex = 14
            local target = Config.FusionResult(item.Species)
            local count = availableBySpecies[item.Species] or 0
            local detail = definition.Rarity .. "  |  #" .. tostring(item.Id)
            if target then
                detail ..= "  |  Слияние " .. count .. "/" .. Config.FusionRequired .. " → " .. target.Name
            end
            local rarity = text("Rarity", row, detail, 11, MUTED)
            rarity.Position = UDim2.fromOffset(9, 30)
            rarity.Size = UDim2.new(1, -18, 0, 41)
            rarity.TextXAlignment = Enum.TextXAlignment.Left
            rarity.ZIndex = 14
            local toggle = button("Toggle", row, marked[item.Id] and "СНЯТЬ" or "НАДЕТЬ", marked[item.Id] and GOLD or BLUE)
            toggle.Position = UDim2.new(0, 8, 1, -42)
            toggle.Size = UDim2.new(0.31, -6, 0, 35)
            toggle.TextSize = 10
            toggle.ZIndex = 14
            toggle.Activated:Connect(function()
                clearReleaseConfirmation()
                clearFuseConfirmation()
                Action:FireServer("ToggleEquip", item.Id)
            end)
            local canFuse = target ~= nil and count >= Config.FusionRequired
            local fuse = button("Fuse", row, target and "✨ СЛИТЬ" or "МАКС.", GOLD)
            fuse.Position = UDim2.new(0.32, 0, 1, -42)
            fuse.Size = UDim2.new(0.35, -4, 0, 35)
            fuse.TextSize = 10
            fuse.ZIndex = 14
            fuse.Active = canFuse
            fuse.AutoButtonColor = canFuse
            fuse.BackgroundTransparency = canFuse and 0 or 0.6
            fuse.Activated:Connect(function()
                if not canFuse or not fuse.Active or player:GetAttribute("DataReady") ~= true
                    or player:GetAttribute("DataStatus") ~= "Ready" then return end
                if pendingFuseButton == fuse and pendingFuseSpecies == item.Species then
                    clearFuseConfirmation()
                    Action:FireServer("FusePets", item.Species)
                    fuse.Text = "..."
                    fuse.Active = false
                else
                    clearReleaseConfirmation()
                    clearFuseConfirmation()
                    pendingFuseButton = fuse
                    pendingFuseSpecies = item.Species
                    fuse.Text = "ТОЧНО?"
                    local nonce = pendingFuseNonce
                    task.delay(4, function()
                        if pendingFuseNonce == nonce and pendingFuseButton == fuse then
                            clearFuseConfirmation()
                        end
                    end)
                end
            end)
            local release = button("Release", row,
                marked[item.Id] and "НАДЕТ" or "ОТПУСТИТЬ", Color3.fromRGB(232, 124, 115))
            release.Position = UDim2.new(0.67, 0, 1, -42)
            release.Size = UDim2.new(0.33, -8, 0, 35)
            release.TextSize = 9
            release.ZIndex = 14
            release.Active = not marked[item.Id]
            release.AutoButtonColor = not marked[item.Id]
            release.BackgroundTransparency = marked[item.Id] and 0.5 or 0
            release.Activated:Connect(function()
                if player:GetAttribute("DataReady") ~= true or player:GetAttribute("DataStatus") ~= "Ready"
                    or marked[item.Id] or not release.Active then return end
                if pendingReleaseId == item.Id and pendingReleaseButton == release then
                    clearReleaseConfirmation()
                    Action:FireServer("ReleasePet", item.Id)
                    release.Text = "..."
                    release.Active = false
                else
                    clearFuseConfirmation()
                    clearReleaseConfirmation()
                    pendingReleaseId = item.Id
                    pendingReleaseButton = release
                    release.Text = "ТОЧНО?"
                    local nonce = pendingReleaseNonce
                    task.delay(4, function()
                        if pendingReleaseNonce == nonce and pendingReleaseId == item.Id then
                            clearReleaseConfirmation()
                            if release.Parent then release.Text = "ОТПУСТИТЬ" end
                        end
                    end)
                end
            end)
        end
    end
end

local function refreshEgg()
    local egg = Config.EggForWorld(player:GetAttribute("World") or "SkyCrown")
    if not egg then return end
    hatch.Text = "🥚 " .. egg.Name .. "\n" .. pretty(egg.Price)
    hatch3.Text = "🥚 ×3\n" .. pretty(egg.Price * Config.MaxHatchBatch)
    local pieces = {}
    for _, drop in ipairs(egg.Drops) do
        local pet = Config.FindPet(drop.Species)
        if pet then table.insert(pieces, pet.Name .. " " .. drop.Chance .. "%") end
    end
    odds.Text = table.concat(pieces, "  ·  ")
end

local function update()
    refreshEgg()
    statFields.Clicks.Text = "👆 Клики: " .. pretty(attr("Clicks"))
    statFields.Gems.Text = "💎 Кристаллы: " .. pretty(attr("Gems"))
    statFields.Rebirths.Text = "🔄 Перерождения: " .. pretty(attr("Rebirths"))
    statFields.Power.Text = "⚡ Сила клика: +" .. pretty(attr("ClickPower"))
    statFields.Pets.Text = "🐾 Питомцы: " .. pretty(attr("PetCount")) .. "  |  бонус +" .. pretty(attr("PetBonus")) .. "%"
    local cost = Config.UpgradeCost(attr("TapLevel"))
    upgrade.Text = cost and ("⚡ УЛУЧШИТЬ\n" .. pretty(cost) .. " кликов") or "МАКС. УРОВЕНЬ"
    local total, levels = Config.UpgradeBundleCost(attr("TapLevel"), Config.BulkUpgradeCount)
    bulkUpgrade.Text = total and ("⚡ ×" .. levels .. "\n" .. pretty(total)) or "МАКС."
    bulkUpgrade.BackgroundColor3 = total and attr("Clicks") >= total and BLUE or MUTED
    local costR = Config.RebirthCost(attr("Rebirths"))
    rebirth.Text = costR and ("🔄 ПЕРЕРОДИТЬСЯ\n" .. pretty(costR) .. " кликов") or "МАКС. ПЕРЕРОЖДЕНИЯ"
    clickButton.Text = "+" .. pretty(attr("ClickPower")) .. " КЛИК"
    local unlocked = player:GetAttribute("AutoTapUnlocked") == true
    local enabled = player:GetAttribute("AutoTapEnabled") == true
    if not unlocked then
        autoTapButton.Text = "🔒 АВТОКЛИК • " .. Config.AutoTap.UnlockRebirths .. " 🔄"
        autoTapButton.BackgroundColor3 = MUTED
    elseif enabled and player:GetAttribute("DataStatus") ~= "Ready" then
        autoTapButton.Text = "🤖 АВТОКЛИК • ПАУЗА"
        autoTapButton.BackgroundColor3 = MUTED
    else
        autoTapButton.Text = enabled and "🤖 АВТОКЛИК • ВКЛ" or "🤖 АВТОКЛИК • ВЫКЛ"
        autoTapButton.BackgroundColor3 = enabled and BLUE or GOLD
    end
    if player:GetAttribute("DataStatus") == "SaveRetry" then
        toast.Text = "Сохранение недоступно: действия приостановлены"
    elseif player:GetAttribute("DataStatus") == "Ready"
        and toast.Text == "Сохранение недоступно: действия приостановлены" then
        toast.Text = ""
    end
end

local function resize()
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1024, 768)
    local w, h = viewport.X, viewport.Y
    local mobile = w < 700
    local landscapeMenu = mobile and h < 500
    local menuOpen = player:GetAttribute("CompactMenuOpen") == true
    menuToggle.Visible = landscapeMenu
    if landscapeMenu then
        menuToggle.Position = UDim2.new(1, -106, 0, 5)
        menuToggle.Size = UDim2.fromOffset(96, 36)
        menuToggle.Text = menuOpen and "✕ ЗАКРЫТЬ" or "☰ МЕНЮ"
    end
    petsButton.Visible = not landscapeMenu or menuOpen
    autoTapButton.Visible = petsButton.Visible
    clickButton.Visible = not landscapeMenu or not menuOpen
    actions.Visible = not landscapeMenu or not menuOpen
    if mobile then
        title.TextSize = 19
        if landscapeMenu then
            title.AnchorPoint = Vector2.new(0, 0)
            title.Position = UDim2.fromOffset(10, 7)
            title.Size = UDim2.new(1, -120, 0, 36)
            title.TextXAlignment = Enum.TextXAlignment.Left
        else
            title.AnchorPoint = Vector2.new(0.5, 0)
            title.Position = UDim2.new(0.5, 0, 0, 7)
            title.Size = UDim2.new(1, -20, 0, 36)
            title.TextXAlignment = Enum.TextXAlignment.Center
        end
        local compact = h < 650
        stats.Position = UDim2.fromOffset(12, 48)
        stats.Size = UDim2.new(1, -24, 0, compact and 110 or 134)
        for _, field in pairs(statFields) do field.Size = UDim2.new(1, 0, 0, compact and 20 or 25) end
        actions.AnchorPoint = Vector2.new(0, 1)
        actions.Position = UDim2.new(0, 12, 1, -10)
        actions.Size = UDim2.new(1, -24, 0, 66)
        upgrade.Position = UDim2.new(0, 7, 0, 7)
        upgrade.Size = UDim2.new(0.30, -5, 1, -14)
        bulkUpgrade.Position = UDim2.new(0.30, 2, 0, 7)
        bulkUpgrade.Size = UDim2.new(0.20, -5, 1, -14)
        rebirth.Position = UDim2.new(0.5, 3, 0, 7)
        rebirth.Size = UDim2.new(0.5, -10, 1, -14)
        upgrade.TextSize, bulkUpgrade.TextSize, rebirth.TextSize = 10, 10, 12
        petsButton.Position = UDim2.new(1, -12, 0, compact and 163 or 187)
        petsButton.AnchorPoint = Vector2.new(1, 0)
        petsButton.Size = UDim2.fromOffset(math.min(w - 24, 162), 43)
        autoTapButton.AnchorPoint = Vector2.new(1, 0)
        autoTapButton.Position = UDim2.new(1, -12, 0, compact and 211 or 235)
        autoTapButton.Size = UDim2.fromOffset(math.min(w - 24, 162), 36)
        autoTapButton.TextSize = 11
        clickButton.AnchorPoint = Vector2.new(0.5, 1)
        clickButton.Position = UDim2.new(0.5, 0, 1, -94)
        clickButton.Size = UDim2.fromOffset(math.min(w - 32, 238), 73)
        toast.Position = UDim2.new(0.5, 0, 1, -171)
        toast.Size = UDim2.new(1, -20, 0, 42)
        modal.Size = UDim2.new(1, -24, 0, math.min(h - 28, 570))
        heading.TextSize = 18
        hatch.TextSize = 13
        search.TextSize = 11
        sortButton.TextSize = 10
        equippedFilter.TextSize = 10
        inventoryTitle.TextSize = 12
        best.TextSize = 12
        unequip.TextSize = 10
    else
        title.AnchorPoint = Vector2.new(0.5, 0)
        title.Position = UDim2.new(0.5, 0, 0, 7)
        title.TextXAlignment = Enum.TextXAlignment.Center
        title.TextSize = 22
        title.Size = UDim2.fromOffset(330, 40)
        stats.Position = UDim2.fromOffset(18, 58)
        stats.Size = UDim2.fromOffset(275, 137)
        for _, field in pairs(statFields) do field.Size = UDim2.new(1, 0, 0, 25) end
        actions.AnchorPoint = Vector2.new(1, 0)
        actions.Position = UDim2.new(1, -18, 0, 58)
        actions.Size = UDim2.fromOffset(245, 171)
        upgrade.Position = UDim2.fromOffset(9, 9)
        upgrade.Size = UDim2.new(0.62, -11, 0, 72)
        bulkUpgrade.Position = UDim2.new(0.62, 0, 0, 9)
        bulkUpgrade.Size = UDim2.new(0.38, -9, 0, 72)
        rebirth.Position = UDim2.fromOffset(9, 90)
        rebirth.Size = UDim2.new(1, -18, 0, 72)
        upgrade.TextSize, bulkUpgrade.TextSize, rebirth.TextSize = 13, 12, 15
        petsButton.AnchorPoint = Vector2.new(1, 0)
        petsButton.Position = UDim2.new(1, -18, 0, 239)
        petsButton.Size = UDim2.fromOffset(245, 50)
        autoTapButton.AnchorPoint = Vector2.new(1, 0)
        autoTapButton.Position = UDim2.new(1, -18, 0, 297)
        autoTapButton.Size = UDim2.fromOffset(245, 45)
        autoTapButton.TextSize = 13
        clickButton.AnchorPoint = Vector2.new(0.5, 1)
        clickButton.Position = UDim2.new(0.5, 0, 1, -20)
        clickButton.Size = UDim2.fromOffset(285, 85)
        toast.Position = UDim2.new(0.5, 0, 1, -115)
        toast.Size = UDim2.fromOffset(440, 42)
        modal.Size = UDim2.fromOffset(math.min(w - 90, 560), math.min(h - 80, 590))
        heading.TextSize = 22
        hatch.TextSize = 16
        search.TextSize = 12
        sortButton.TextSize = 11
        equippedFilter.TextSize = 11
        inventoryTitle.TextSize = 14
        best.TextSize = 16
        unequip.TextSize = 12
    end
    local compactPets = modal.Size.Y.Offset < 450
    if compactPets then
        odds.Visible = false
        inventoryTitle.Position = UDim2.fromOffset(12, 113)
        search.Position = UDim2.new(0, 12, 0, 145)
        sortButton.Position = UDim2.new(0.49, 6, 0, 145)
        equippedFilter.Position = UDim2.new(0.745, 2, 0, 145)
        scroll.Position = UDim2.new(0, 12, 0, 185)
        scroll.Size = UDim2.new(1, -24, 1, -252)
    else
        odds.Visible = true
        inventoryTitle.Position = UDim2.fromOffset(12, 160)
        search.Position = UDim2.new(0, 12, 0, 190)
        sortButton.Position = UDim2.new(0.49, 6, 0, 190)
        equippedFilter.Position = UDim2.new(0.745, 2, 0, 190)
        scroll.Position = UDim2.new(0, 12, 0, 231)
        scroll.Size = UDim2.new(1, -24, 1, -298)
    end
end

local function ready()
    return player:GetAttribute("DataReady") == true
        and player:GetAttribute("DataStatus") == "Ready"
end
local lastTap = -100
local function click()
    if not ready() or shade.Visible or player:GetAttribute("SettingsOpen") == true
        or player:GetAttribute("CompactMenuOpen") == true then return end
    local now = os.clock()
    if now - lastTap < (1 / Config.MaxClicksPerSecond) then return end
    lastTap = now
    Action:FireServer("Click")
    tapFlash:Fire(attr("ClickPower"))
end
clickButton.Activated:Connect(click)
autoTapButton.Activated:Connect(function()
    if ready() then
        Action:FireServer("ToggleAutoTap")
    end
end)
menuToggle.Activated:Connect(function()
    player:SetAttribute("CompactMenuOpen", player:GetAttribute("CompactMenuOpen") ~= true)
end)
player:GetAttributeChangedSignal("CompactMenuOpen"):Connect(resize)
UserInputService.InputBegan:Connect(function(input, handled)
    if not handled and not UserInputService:GetFocusedTextBox()
        and input.KeyCode == Enum.KeyCode.Space then click() end
end)
upgrade.Activated:Connect(function()
    if ready() then Action:FireServer("Upgrade") end
end)
bulkUpgrade.Activated:Connect(function()
    if ready() then Action:FireServer("Upgrade5") end
end)
rebirth.Activated:Connect(function()
    if ready() then Action:FireServer("Rebirth") end
end)
local function openPets()
    player:SetAttribute("CompactMenuOpen", false)
    shade.Visible = true
    if petsDirty then repaintPets() end
    if ready() then Action:FireServer("GetPets") end
end
petsButton.Activated:Connect(openPets)
OpenEggShop.OnClientEvent:Connect(openPets)
close.Activated:Connect(function()
    clearReleaseConfirmation()
    clearFuseConfirmation()
    shade.Visible = false
end)
hatch.Activated:Connect(function()
    if ready() then Action:FireServer("Hatch") end
end)
hatch3.Activated:Connect(function()
    if ready() then Action:FireServer("Hatch3") end
end)
best.Activated:Connect(function()
    if ready() then Action:FireServer("EquipBest") end
end)
unequip.Activated:Connect(function()
    clearReleaseConfirmation()
    clearFuseConfirmation()
    if ready() and #currentEquipped > 0 then Action:FireServer("UnequipAll") end
end)
local function updateFilter()
    clearReleaseConfirmation()
    clearFuseConfirmation()
    scroll.CanvasPosition = Vector2.new(0, 0)
    petsDirty = true
    if shade.Visible then repaintPets() end
end
search:GetPropertyChangedSignal("Text"):Connect(updateFilter)
sortButton.Activated:Connect(function()
    sortMode = sortMode == "Power" and "New" or (sortMode == "New" and "Old" or "Power")
    sortButton.Text = sortNames[sortMode]
    updateFilter()
end)
equippedFilter.Activated:Connect(function()
    equippedOnly = not equippedOnly
    equippedFilter.Text = equippedOnly and "НАДЕТЫ" or "ВСЕ"
    equippedFilter.BackgroundColor3 = equippedOnly and BLUE or GOLD
    updateFilter()
end)
Feedback.OnClientEvent:Connect(function(info)
    if typeof(info) == "string" then message(info) end
end)
PetState.OnClientEvent:Connect(function(inventory, equipped)
    if typeof(inventory) ~= "table" or typeof(equipped) ~= "table" then return end
    clearReleaseConfirmation()
    currentPets = inventory
    currentEquipped = equipped
    petsDirty = true
    if shade.Visible then repaintPets() end
end)

-- Several attributes change during one server sync. Redraw HUD only once
-- in the next scheduler slice instead of rebuilding labels for every field.
local updateQueued = false
local function scheduleUpdate()
    if updateQueued then return end
    updateQueued = true
    task.defer(function()
        updateQueued = false
        if gui.Parent then update() end
    end)
end
for _, key in ipairs({"Clicks", "Gems", "Rebirths", "TapLevel", "ClickPower", "PetBonus", "PetCount", "DataReady", "SavingEnabled", "DataStatus", "World", "AutoTapEnabled", "AutoTapUnlocked"}) do
    player:GetAttributeChangedSignal(key):Connect(scheduleUpdate)
end
player:GetAttributeChangedSignal("DataReady"):Connect(function()
    if ready() then Action:FireServer("GetPets") end
end)
resize()
update()
if ready() then Action:FireServer("GetPets") end
local viewportConnection
local function cameraChanged()
    if viewportConnection then viewportConnection:Disconnect() end
    viewportConnection = nil
    resize()
    local camera = workspace.CurrentCamera
    if camera then
        viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
    end
end
cameraChanged()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(cameraChanged)

-- Alpha 0.9.26: display server-confirmed manual tap streak without client rewards.
local comboHud = Instance.new("TextLabel")
comboHud.Name = "TapCombo"
comboHud.AnchorPoint = Vector2.new(0.5, 0)
comboHud.Position = UDim2.new(0.5, 0, 0, 160)
comboHud.Size = UDim2.fromOffset(280, 32)
comboHud.BackgroundColor3 = PANEL
comboHud.BackgroundTransparency = 0.12
comboHud.BorderSizePixel = 0
comboHud.Font = Enum.Font.GothamBold
comboHud.TextColor3 = GOLD
comboHud.TextSize = 13
comboHud.TextWrapped = true
comboHud.Visible = false
comboHud.Parent = gui
rounded(comboHud, 10)
outlined(comboHud, GOLD, 1)
local function refreshCombo()
    local count = tonumber(player:GetAttribute("TapComboCount")) or 0
    local multiplier = tonumber(player:GetAttribute("TapComboMultiplier")) or 1
    local expiry = tonumber(player:GetAttribute("TapComboExpiresAt")) or 0
    local remain = math.max(0, expiry - workspace:GetServerTimeNow())
    comboHud.Visible = player:GetAttribute("DataReady") == true and count > 0 and remain > 0
    if not comboHud.Visible then return end
    local camera = workspace.CurrentCamera
    local w = camera and camera.ViewportSize.X or 900
    comboHud.Size = UDim2.fromOffset(math.min(280, math.max(180, w - 24)), 32)
    comboHud.Text = "⚡ КОМБО " .. count .. " ×" .. string.format("%.2f", multiplier)
        .. " • " .. string.format("%.1f", remain) .. " с"
end
for _, field in ipairs({"TapComboCount", "TapComboMultiplier", "TapComboExpiresAt", "DataReady"}) do
    player:GetAttributeChangedSignal(field):Connect(refreshCombo)
end
task.spawn(function()
    while gui.Parent do
        refreshCombo()
        task.wait(comboHud.Visible and 0.15 or 0.5)
    end
end)
refreshCombo()
]==]},
    {name="GrowlivoPetsVisual", className="LocalScript", target="StarterPlayerScripts", source=[==[-- GROWLIVO / Nine distinctive low-poly pet follower silhouettes / Alpha 0.9.14
-- StarterPlayer > StarterPlayerScripts > GrowlivoPetsVisual [LocalScript]
-- All pets are cosmetic client-only models. The server calculates game bonuses.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("GrowlivoConfig"))
local remotes = ReplicatedStorage:WaitForChild("GROWLIVO_Remotes")
local petState = remotes:WaitForChild("PetState")
local action = remotes:WaitForChild("Action")
local models = {}
local folder = Instance.new("Folder")
folder.Name = "GROWLIVO_LocalPets"
folder.Parent = workspace
local function setVisibility()
    local show = player:GetAttribute("SettingShowPets") ~= false
    folder.Parent = show and workspace or nil
end
player:GetAttributeChangedSignal("SettingShowPets"):Connect(setVisibility)
setVisibility()

local INK = Color3.fromRGB(14, 28, 47)
local PALE = Color3.fromRGB(249, 250, 255)
local GOLD = Color3.fromRGB(255, 208, 83)
local function piece(parent, name, size, offset, color, shape, material)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = CFrame.new(offset)
    p.Shape = shape or Enum.PartType.Ball
    p.Material = material or Enum.Material.SmoothPlastic
    p.Color = color
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = false
    p.Parent = parent
    return p
end
local function ornament(model, species, primary)
    local c = primary
    local function shape(name, size, pos, color, typ)
        return piece(model, name, size, pos, color or c, typ)
    end
    if species == "CloudBunny" then
        shape("LongEarL", Vector3.new(0.85, 2.6, 0.8), Vector3.new(-0.88, 2.25, -0.15))
        shape("LongEarR", Vector3.new(0.85, 2.6, 0.8), Vector3.new(0.88, 2.25, -0.15))
        shape("CloudTail", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, -0.3, 1.5), PALE)
    elseif species == "SunFox" then
        shape("FoxEarL", Vector3.new(1.05, 1.4, 1.05), Vector3.new(-1.1, 1.55, -0.1))
        shape("FoxEarR", Vector3.new(1.05, 1.4, 1.05), Vector3.new(1.1, 1.55, -0.1))
        shape("FoxMuzzle", Vector3.new(1.3, 0.7, 0.8), Vector3.new(0, -0.25, -1.52), PALE)
        shape("FoxTail", Vector3.new(2.7, 1.2, 1.2), Vector3.new(1.35, -0.8, 1.6))
        shape("FoxTailTip", Vector3.new(1, 1, 1), Vector3.new(2.5, -0.8, 1.8), PALE)
    elseif species == "SkyOwl" then
        shape("OwlWingL", Vector3.new(1.8, 2.3, 0.75), Vector3.new(-2.1, -0.25, 0.3))
        shape("OwlWingR", Vector3.new(1.8, 2.3, 0.75), Vector3.new(2.1, -0.25, 0.3))
        shape("OwlBeak", Vector3.new(0.65, 0.7, 0.75), Vector3.new(0, -0.2, -1.8), GOLD)
        shape("OwlBrowL", Vector3.new(1.0, 0.35, 0.4), Vector3.new(-0.8, 0.95, -1.55), PALE)
        shape("OwlBrowR", Vector3.new(1.0, 0.35, 0.4), Vector3.new(0.8, 0.95, -1.55), PALE)
    elseif species == "CrystalCat" then
        shape("CatEarL", Vector3.new(0.8, 1.7, 0.9), Vector3.new(-1, 1.85, 0))
        shape("CatEarR", Vector3.new(0.8, 1.7, 0.9), Vector3.new(1, 1.85, 0))
        shape("CatGem", Vector3.new(0.75, 0.85, 0.6), Vector3.new(0, 0.92, -1.6), GOLD)
        shape("CatTail", Vector3.new(0.9, 2.6, 0.9), Vector3.new(1.5, -0.1, 1.2))
    elseif species == "CrownDragon" then
        shape("DragonWingL", Vector3.new(2.3, 2.4, 0.45), Vector3.new(-2.2, 0.15, 0.5))
        shape("DragonWingR", Vector3.new(2.3, 2.4, 0.45), Vector3.new(2.2, 0.15, 0.5))
        for _, x in ipairs({-1, 0, 1}) do
            shape("CrownSpike", Vector3.new(0.7, x == 0 and 1.7 or 1.2, 0.7), Vector3.new(x, 1.85, -0.2), GOLD)
        end
        shape("DragonNose", Vector3.new(1.3, 0.8, 1.1), Vector3.new(0, -0.25, -1.65))
    elseif species == "GemSlime" then
        local halo = shape("SlimeHalo", Vector3.new(4.1, 4.1, 4.1), Vector3.new(0, 0, 0), PALE)
        halo.Transparency = 0.86
        shape("SlimeCrownGem", Vector3.new(1.1, 1.7, 1.1), Vector3.new(0, 1.9, 0), GOLD)
    elseif species == "PrismDeer" then
        shape("DeerNose", Vector3.new(0.95, 0.7, 0.85), Vector3.new(0, -0.1, -1.67), PALE)
        for _, x in ipairs({-1, 1}) do
            shape("AntlerStem", Vector3.new(0.5, 2.7, 0.6), Vector3.new(x * 0.95, 2.25, 0.2), GOLD)
            shape("AntlerBranch", Vector3.new(1.25, 0.4, 0.55), Vector3.new(x * 1.52, 2.8, 0), GOLD)
        end
    elseif species == "AzurePhoenix" then
        shape("PhoenixWingL", Vector3.new(3.0, 2.1, 0.6), Vector3.new(-2.25, 0.25, 0))
        shape("PhoenixWingR", Vector3.new(3.0, 2.1, 0.6), Vector3.new(2.25, 0.25, 0))
        shape("PhoenixPlume", Vector3.new(0.9, 2.4, 0.9), Vector3.new(0, 2.2, 0), GOLD)
        shape("PhoenixTailL", Vector3.new(0.7, 2.2, 0.7), Vector3.new(-0.75, -1.65, 1.0))
        shape("PhoenixTailR", Vector3.new(0.7, 2.2, 0.7), Vector3.new(0.75, -1.65, 1.0))
    elseif species == "DiamondWyrm" then
        for i = 1, 3 do
            shape("WyrmTail_" .. i, Vector3.new(1.65 - i * 0.25, 1.65 - i * 0.25, 1.65 - i * 0.25), Vector3.new(0, -i * 0.37, 1.2 + i * 0.95))
        end
        shape("WyrmHornL", Vector3.new(0.7, 1.8, 0.7), Vector3.new(-0.95, 1.8, 0), GOLD)
        shape("WyrmHornR", Vector3.new(0.7, 1.8, 0.7), Vector3.new(0.95, 1.8, 0), GOLD)
    elseif species == "AuroraMoth" then
        shape("MothWingL", Vector3.new(2.5, 3.1, 0.35), Vector3.new(-2.05, 0.4, 0.6), PALE)
        shape("MothWingR", Vector3.new(2.5, 3.1, 0.35), Vector3.new(2.05, 0.4, 0.6), PALE)
        shape("MothAntennaL", Vector3.new(0.25, 1.7, 0.25), Vector3.new(-0.65, 2.05, -0.6), GOLD)
        shape("MothAntennaR", Vector3.new(0.25, 1.7, 0.25), Vector3.new(0.65, 2.05, -0.6), GOLD)
    elseif species == "DuskWolf" then
        shape("WolfEarL", Vector3.new(0.85, 1.65, 0.75), Vector3.new(-1.1, 1.9, 0))
        shape("WolfEarR", Vector3.new(0.85, 1.65, 0.75), Vector3.new(1.1, 1.9, 0))
        shape("WolfSnout", Vector3.new(1.4, 0.8, 1.2), Vector3.new(0, -0.4, -1.65), PALE)
        shape("WolfTail", Vector3.new(1.25, 1.5, 1.65), Vector3.new(1.35, -0.65, 1.65))
    elseif species == "RuneStag" then
        for _, direction in ipairs({-1, 1}) do
            shape("RuneAntlerStem", Vector3.new(0.48, 3.0, 0.5), Vector3.new(direction * 0.85, 2.4, 0), GOLD)
            shape("RuneAntlerTip", Vector3.new(1.1, 0.45, 0.6), Vector3.new(direction * 1.42, 3.1, -0.15), PALE)
        end
        shape("RuneForehead", Vector3.new(0.85, 1, 0.4), Vector3.new(0, 0.95, -1.55), GOLD)
    elseif species == "DawnGriffin" then
        shape("GriffinWingL", Vector3.new(3, 2.6, 0.65), Vector3.new(-2.3, 0.25, 0.7), GOLD)
        shape("GriffinWingR", Vector3.new(3, 2.6, 0.65), Vector3.new(2.3, 0.25, 0.7), GOLD)
        shape("GriffinBeak", Vector3.new(1.05, 0.85, 1.2), Vector3.new(0, -0.15, -1.9), PALE)
        shape("GriffinCrest", Vector3.new(1, 1.75, 0.85), Vector3.new(0, 1.95, -0.45), GOLD)
        shape("GriffinTail", Vector3.new(0.85, 2.2, 0.85), Vector3.new(0.85, -1.4, 1.5))
    end
end
local function makePet(item)
    local def = Config.FindPet(item.Species)
    if not def then return nil end
    local m = Instance.new("Model")
    m.Name = "Pet_" .. tostring(item.Id)
    m.Parent = folder
    local body = piece(m, "Body", Vector3.new(3.25, 3, 3.25), Vector3.zero, def.Color)
    m.PrimaryPart = body
    m:SetAttribute("PetId", item.Id)
    m:SetAttribute("Species", item.Species)
    ornament(m, def.Id, def.Color)
    for _, x in ipairs({-0.69, 0.69}) do
        piece(m, "Eye", Vector3.new(0.42, 0.52, 0.34), Vector3.new(x, 0.25, -1.56), INK)
        piece(m, "EyeShine", Vector3.new(0.16, 0.16, 0.14), Vector3.new(x - 0.08, 0.39, -1.78), PALE)
    end
    local nameGui = Instance.new("BillboardGui")
    nameGui.Name = "NameTag"
    nameGui.Adornee = body
    nameGui.Size = UDim2.fromOffset(160, 28)
    nameGui.StudsOffsetWorldSpace = Vector3.new(0, 3.8, 0)
    nameGui.MaxDistance = 70
    nameGui.Parent = body
    local text = Instance.new("TextLabel")
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.Font = Enum.Font.GothamBold
    text.Text = def.Name
    text.TextScaled = true
    text.TextColor3 = def.Color
    text.TextStrokeTransparency = 0.14
    text.Parent = nameGui
    return m
end

local function refresh(inventory, equipped)
    if typeof(inventory) ~= "table" or typeof(equipped) ~= "table" then return end
    local lookup = {}
    for _, item in ipairs(inventory) do
        if typeof(item) == "table" and typeof(item.Id) == "number" then lookup[item.Id] = item end
    end
    -- Reuse unchanged 3D followers rather than destroy/recreate all their Parts.
    -- PetState can be broadcast after many independent profile actions.
    local byId = {}
    for _, model in ipairs(models) do
        local id = model:GetAttribute("PetId")
        if typeof(id) == "number" then byId[id] = model else model:Destroy() end
    end
    local updated = {}
    for i = 1, math.min(#equipped, Config.MaxEquippedPets) do
        local item = lookup[equipped[i]]
        if item then
            local pet = byId[item.Id]
            if pet and pet:GetAttribute("Species") ~= item.Species then
                pet:Destroy()
                pet = nil
            end
            if not pet then pet = makePet(item) end
            byId[item.Id] = nil
            if pet then table.insert(updated, pet) end
        end
    end
    for _, obsolete in pairs(byId) do obsolete:Destroy() end
    models = updated
end
petState.OnClientEvent:Connect(refresh)
local function request()
    if player:GetAttribute("DataReady") == true then action:FireServer("GetPets") end
end
player:GetAttributeChangedSignal("DataReady"):Connect(request)
task.delay(1, request)

-- Low-overhead follower tick: avoids rebuilding transforms at display refresh rate.
local UserInputService = game:GetService("UserInputService")
local elapsed = 0
RunService.Heartbeat:Connect(function(delta)
    if player:GetAttribute("SettingShowPets") == false or #models == 0 then
        elapsed = 0
        return
    end
    elapsed += math.min(delta, 0.2)
    -- Mobile/low-motion get a smaller animation budget; the game economy is unaffected.
    local interval = UserInputService.TouchEnabled and (1 / 15) or (1 / 30)
    if player:GetAttribute("SettingReducedMotion") == true then interval = 1 / 12 end
    if elapsed < interval then return end
    local step = elapsed
    elapsed = 0
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local camera = workspace.CurrentCamera
    -- Avoid 3D transforms while viewing a distant world from a cinematic camera.
    if camera and (camera.CFrame.Position - root.Position).Magnitude > 140 then return end
    local reduced = player:GetAttribute("SettingReducedMotion") == true
    local t = os.clock()
    for i, pet in ipairs(models) do
        if pet.Parent and pet.PrimaryPart then
            local x = (i - 2) * 4.2
            local z = 4.8 + math.abs(i - 2) * 1.5
            local bob = reduced and 0 or math.sin(t * 2.8 + i) * 0.3
            local target = root.CFrame * CFrame.new(x, 0.5 + bob, z)
            local current = pet:GetPivot()
            local distance = (current.Position - target.Position).Magnitude
            if distance > 30 then
                pet:PivotTo(target)
            elseif distance > 0.04 or current.LookVector:Dot(target.LookVector) < 0.999 then
                pet:PivotTo(current:Lerp(target, math.clamp(step * 8, 0, 1)))
            end
        end
    end
end)
]==]},
    {name="GrowlivoProgressUI", className="LocalScript", target="StarterPlayerScripts", source=[==[-- GROWLIVO / Worlds, quests, daily rewards, achievements / Alpha 0.9.14
-- StarterPlayer > StarterPlayerScripts > GrowlivoProgressUI [LocalScript]
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Config = require(RS:WaitForChild("GrowlivoConfig"))
local remotes = RS:WaitForChild("GROWLIVO_Remotes")
local Action = remotes:WaitForChild("Action")
local ProgressState = remotes:WaitForChild("ProgressState")
local OpenWorldMenu = remotes:WaitForChild("OpenWorldMenu")

local GOLD, BLUE = Color3.fromRGB(255, 201, 68), Color3.fromRGB(48, 211, 253)
local DARK, PANEL = Color3.fromRGB(11, 25, 46), Color3.fromRGB(25, 41, 70)
local WHITE, MUTED = Color3.fromRGB(238, 249, 255), Color3.fromRGB(169, 199, 221)
local gui = Instance.new("ScreenGui")
gui.Name = "GROWLIVO_ProgressUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 0
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(element, amount)
    local child = Instance.new("UICorner")
    child.CornerRadius = UDim.new(0, amount or 12)
    child.Parent = element
end
local function makeFrame(name, parent, background, z)
    local element = Instance.new("Frame")
    element.Name = name
    element.BackgroundColor3 = background or PANEL
    element.BorderSizePixel = 0
    element.ZIndex = z or 1
    element.Parent = parent
    corner(element)
    return element
end
local function makeText(name, parent, caption, size, color, z)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.BackgroundTransparency = 1
    label.Text = caption
    label.Font = Enum.Font.GothamBold
    label.TextSize = size or 14
    label.TextWrapped = true
    label.TextColor3 = color or WHITE
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = z or 1
    label.Parent = parent
    return label
end
local function makeButton(name, parent, caption, color, z)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Text = caption
    button.Font = Enum.Font.GothamBold
    button.TextSize = 14
    button.TextWrapped = true
    button.TextColor3 = DARK
    button.BackgroundColor3 = color or BLUE
    button.BorderSizePixel = 0
    button.ZIndex = z or 1
    button.Parent = parent
    corner(button, 10)
    return button
end
local function nice(n)
    n = tonumber(n) or 0
    if n >= 1000000 then return string.format("%.1fM", n / 1000000) end
    if n >= 1000 then return string.format("%.1fK", n / 1000) end
    return tostring(math.floor(n))
end
local function send(name, arg)
    if player:GetAttribute("DataReady") then Action:FireServer(name, arg) end
end

local worldButton = makeButton("Worlds", gui, "🌍 МИРЫ", BLUE)
local questButton = makeButton("Quests", gui, "📜 ЗАДАНИЯ", GOLD)
local badgesButton = makeButton("Achievements", gui, "🏆 НАГРАДЫ", BLUE)

local shade = makeFrame("Shade", gui, Color3.new(0, 0, 0), 20)
shade.BackgroundTransparency = 0.25
shade.Size = UDim2.fromScale(1, 1)
shade.Visible = false
shade.Active = true
local modal = makeFrame("Panel", shade, PANEL, 21)
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.fromScale(0.5, 0.5)
local rim = Instance.new("UIStroke")
rim.Color = GOLD
rim.Thickness = 2
rim.Parent = modal
local heading = makeText("Heading", modal, "", 22, GOLD, 22)
heading.Position = UDim2.fromOffset(16, 8)
heading.Size = UDim2.new(1, -86, 0, 45)
local close = makeButton("Close", modal, "✕", GOLD, 22)
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -10, 0, 10)
close.Size = UDim2.fromOffset(43, 37)

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Entries"
scroll.Position = UDim2.new(0, 12, 0, 62)
scroll.Size = UDim2.new(1, -24, 1, -75)
scroll.CanvasSize = UDim2.fromOffset(0, 0)
scroll.ScrollBarThickness = 5
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ZIndex = 22
scroll.Parent = modal
local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 4)
padding.PaddingBottom = UDim.new(0, 6)
padding.PaddingRight = UDim.new(0, 6)
padding.Parent = scroll
local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 9)
layout.Parent = scroll
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scroll.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 20)
end)

local state = nil
local page = "worlds"
local function row(name, label, details, buttonCaption, action, index)
    local card = makeFrame(name, scroll, DARK, 23)
    card.Size = UDim2.new(1, -4, 0, 103)
    card.LayoutOrder = index
    local top = makeText("Name", card, label, 15, GOLD, 24)
    top.Position = UDim2.fromOffset(12, 7)
    top.Size = UDim2.new(1, -24, 0, 32)
    local bottom = makeText("Details", card, details, 12, MUTED, 24)
    bottom.Position = UDim2.fromOffset(12, 42)
    bottom.Size = UDim2.new(0.61, -12, 0, 53)
    if buttonCaption then
        local execute = makeButton("Action", card, buttonCaption, BLUE, 24)
        execute.AnchorPoint = Vector2.new(1, 0.5)
        execute.Position = UDim2.new(1, -9, 0.66, 0)
        execute.Size = UDim2.new(0.34, 0, 0, 43)
        execute.TextSize = 12
        execute.Activated:Connect(action)
    end
    return card
end
local function repaint()
    if not shade.Visible then return end
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    if not state then
        heading.Text = "ЗАГРУЗКА..."
        row("Wait", "Ожидаем профиль", "Если нет сохранений, игра запустится во временном режиме.", nil, nil, 1)
        return
    end
    if page == "worlds" then
        heading.Text = "🌍 МИРЫ GROWLIVO"
        for i, world in ipairs(Config.Worlds) do
            local unlocked = world.Id == "SkyCrown" or state.UnlockedWorlds[world.Id] == true
            local current = state.World == world.Id
            local details
            if not unlocked then
                details = "Требуется: " .. world.UnlockRebirths .. " перерожд. и " .. world.UnlockGems .. " 💎"
            else
                details = current and "Ты находишься в этом мире" or "Открыт • Можно переместиться"
            end
            local actionLabel = nil
            if not current then actionLabel = unlocked and "ПЕРЕЙТИ" or "ОТКРЫТЬ" end
            row(world.Id, world.Name .. "  •  клики x" .. world.Multiplier, details, actionLabel, function()
                send(unlocked and "Travel" or "UnlockWorld", world.Id)
            end, i)
        end
    elseif page == "quests" then
        heading.Text = "📜 ЗАДАНИЯ / " .. state.Day
        row("Daily", "🎁 Подарок за вход", "+" .. nice(Config.DailyReward.Clicks) .. " кликов и +" .. Config.DailyReward.Gems .. " 💎\nРаз в сутки (UTC)",
            not state.DailyClaimed and "ПОЛУЧИТЬ" or nil, function() send("ClaimDaily") end, 0)
        for i, quest in ipairs(Config.Quests) do
            local entry = state.Quests[quest.Id] or {Progress = 0, Claimed = false}
            row(quest.Id, quest.Name, nice(entry.Progress) .. "/" .. nice(quest.Goal) .. "  •  +" .. quest.Gems .. " 💎" .. (entry.Claimed and "\nВыполнено" or ""),
                (entry.Progress >= quest.Goal and not entry.Claimed) and "ЗАБРАТЬ" or nil,
                function() send("ClaimQuest", quest.Id) end, i)
        end
        row("WeekHeader", "📅 НЕДЕЛЯ / с " .. tostring(state.WeeklyWeek or "—"),
            "Новый набор с понедельника, 00:00 UTC", nil, nil, #Config.Quests + 1)
        for i, quest in ipairs(Config.WeeklyQuests) do
            local entry = (state.WeeklyQuests or {})[quest.Id] or {Progress = 0, Claimed = false}
            row(quest.Id, quest.Name,
                nice(entry.Progress) .. "/" .. nice(quest.Goal) .. "  •  +" .. quest.Gems .. " 💎"
                    .. (entry.Claimed and "\nПолучено" or ""),
                (entry.Progress >= quest.Goal and not entry.Claimed) and "ЗАБРАТЬ" or nil,
                function() send("ClaimWeeklyQuest", quest.Id) end, #Config.Quests + i + 1)
        end
    else
        heading.Text = "🏆 ДОСТИЖЕНИЯ"
        for i, item in ipairs(Config.Achievements) do
            local current = math.floor(tonumber(state[item.Stat]) or 0)
            local collected = state.Achievements[item.Id] == true
            row(item.Id, item.Name, nice(math.min(item.Goal, current)) .. "/" .. nice(item.Goal) .. "  •  +" .. item.Gems .. " 💎" .. (collected and "\nПолучено" or ""),
                (current >= item.Goal and not collected) and "ЗАБРАТЬ" or nil,
                function() send("ClaimAchievement", item.Id) end, i)
        end
    end
end
local function open(which)
    player:SetAttribute("CompactMenuOpen", false)
    page = which
    shade.Visible = true
    gui.DisplayOrder = 10
    send("GetProgress")
    repaint()
end
local function compactNavigationVisible(w, h)
    return w >= 700 or h >= 500 or player:GetAttribute("CompactMenuOpen") == true
end
local function petInventoryOpen()
    local hud = player:FindFirstChild("PlayerGui")
    local main = hud and hud:FindFirstChild("GROWLIVO_HUD")
    local backdrop = main and main:FindFirstChild("ModalBackdrop")
    return backdrop ~= nil and backdrop.Visible == true
end
local function resize()
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1024, 768)
    local w, h = viewport.X, viewport.Y
    local visible = compactNavigationVisible(w, h) and not petInventoryOpen()
    worldButton.Visible = visible
    questButton.Visible = visible
    badgesButton.Visible = visible
    if w < 700 then
        local half = (w - 36) / 2
        local navY = h < 650 and 163 or 187
        worldButton.Position = UDim2.fromOffset(12, navY)
        worldButton.Size = UDim2.fromOffset(math.min(half, w - 24 - math.min(w - 24, 162)), 43)
        questButton.Position = UDim2.fromOffset(12, navY + 49)
        questButton.Size = UDim2.fromOffset(half, 43)
        badgesButton.Position = UDim2.fromOffset(24 + half, navY + 49)
        badgesButton.Size = UDim2.fromOffset(half, 43)
        modal.Size = UDim2.new(1, -24, 0, math.min(h - 24, 590))
        heading.TextSize = 17
    else
        for i, button in ipairs({worldButton, questButton, badgesButton}) do
            button.Position = UDim2.fromOffset(18, 204 + (i - 1) * 58)
            button.Size = UDim2.fromOffset(245, 49)
        end
        modal.Size = UDim2.fromOffset(math.min(w - 90, 550), math.min(h - 80, 610))
        heading.TextSize = 22
    end
end
worldButton.Activated:Connect(function() open("worlds") end)
questButton.Activated:Connect(function() open("quests") end)
badgesButton.Activated:Connect(function() open("badges") end)
OpenWorldMenu.OnClientEvent:Connect(function() open("worlds") end)
close.Activated:Connect(function()
    shade.Visible = false
    gui.DisplayOrder = 0
end)
ProgressState.OnClientEvent:Connect(function(payload)
    if typeof(payload) ~= "table" then return end
    if typeof(payload.Quests) ~= "table" or typeof(payload.UnlockedWorlds) ~= "table" then return end
    state = payload
    repaint()
end)
player:GetAttributeChangedSignal("DataReady"):Connect(function()
    if player:GetAttribute("DataReady") then send("GetProgress") end
end)
resize()
if player:GetAttribute("DataReady") then send("GetProgress") end
local viewportConnection
local function attachCamera()
    if viewportConnection then viewportConnection:Disconnect() end
    viewportConnection = nil
    resize()
    local camera = workspace.CurrentCamera
    if camera then
        viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
    end
end
attachCamera()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(attachCamera)
-- Avoid blocking the pet inventory GUI when the separate HUD's modal is open.
task.spawn(function()
    local hud = player:WaitForChild("PlayerGui"):WaitForChild("GROWLIVO_HUD", 30)
    if not hud then return end
    local petsBackdrop = hud:WaitForChild("ModalBackdrop", 30)
    if not petsBackdrop then return end
    local function checkPetModal()
        if petsBackdrop.Visible then
            shade.Visible = false
            gui.DisplayOrder = 0
        end
        -- Respect both the compact-menu state and the pet inventory overlay.
        resize()
    end
    petsBackdrop:GetPropertyChangedSignal("Visible"):Connect(checkPetModal)
    checkPetModal()
end)

player:GetAttributeChangedSignal("CompactMenuOpen"):Connect(resize)
]==]},
    {name="GrowlivoVisualFX", className="LocalScript", target="StarterPlayerScripts", source=[==[-- GROWLIVO / Local visual-only tap & reward effects / Alpha 0.9.14
-- StarterPlayer > StarterPlayerScripts > GrowlivoVisualFX [LocalScript]
-- Never grants currency: only reacts to a local tap signal and server-authored rewards.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("GrowlivoConfig"))
local remotes = ReplicatedStorage:WaitForChild("GROWLIVO_Remotes")
local visuals = remotes:WaitForChild("VisualEvent")
local hud = player:WaitForChild("PlayerGui"):WaitForChild("GROWLIVO_HUD")
local tap = hud:WaitForChild("Click")
local tapFlash = hud:WaitForChild("TapFlash")
local GOLD = Color3.fromRGB(255, 209, 66)
local SKY = Color3.fromRGB(38, 203, 255)
local NAVY = Color3.fromRGB(13, 28, 51)
local WHITE = Color3.fromRGB(245, 249, 255)

local gui = Instance.new("ScreenGui")
gui.Name = "GROWLIVO_VisualFX"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 50
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local scale = Instance.new("UIScale")
scale.Name = "ClickPulse"
scale.Scale = 1
scale.Parent = tap
local pulses, floating = 0, 0
local function effectsEnabled()
    return player:GetAttribute("SettingEffects") ~= false
end
local function reducedMotion()
    return player:GetAttribute("SettingReducedMotion") == true or GuiService.ReducedMotionEnabled
end
local function floatTap(amount)
    if floating >= 12 or not effectsEnabled() or reducedMotion() then return end
    floating += 1
    local center = tap.AbsolutePosition + tap.AbsoluteSize / 2
    local label = Instance.new("TextLabel")
    label.Name = "FloatingTap"
    label.BackgroundTransparency = 1
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Position = UDim2.fromOffset(center.X + math.random(-24, 24), center.Y - 42)
    label.Size = UDim2.fromOffset(190, 48)
    label.Text = "+" .. tostring(math.floor(tonumber(amount) or 1))
    label.Font = Enum.Font.GothamBlack
    label.TextColor3 = GOLD
    label.TextStrokeTransparency = 0.25
    label.TextSize = 29
    label.ZIndex = 4
    label.Parent = gui
    local tween = TweenService:Create(label, TweenInfo.new(0.65, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Position = label.Position - UDim2.fromOffset(0, 65),
        TextTransparency = 1,
        TextStrokeTransparency = 1,
    })
    tween:Play()
    task.delay(0.7, function()
        label:Destroy()
        floating -= 1
    end)
end
local function pulse()
    if not effectsEnabled() or reducedMotion() then return end
    pulses += 1
    local stamp = pulses
    TweenService:Create(scale, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0.93}):Play()
    task.delay(0.07, function()
        if stamp ~= pulses then return end
        TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
    end)
end
tapFlash.Event:Connect(function(amount)
    pulse()
    floatTap(amount)
end)

local activeCard = nil
local pendingCards = {}
local activeSerial = 0
local function rewardCard(title, caption, tint)
    if activeCard then
        if #pendingCards < 3 then table.insert(pendingCards, {title, caption, tint}) end
        return
    end
    activeSerial += 1
    local serial = activeSerial
    if activeCard then activeCard:Destroy() end
    local size = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1000, 700)
    local width = math.max(240, math.min(410, size.X - 38))
    local card = Instance.new("Frame")
    card.Name = "RewardCard"
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.39)
    card.Size = UDim2.fromOffset(width, 190)
    card.BackgroundColor3 = NAVY
    card.BorderSizePixel = 0
    card.ZIndex = 20
    card.Parent = gui
    activeCard = card
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 24)
    corner.Parent = card
    local outline = Instance.new("UIStroke")
    outline.Thickness = 3
    outline.Color = tint
    outline.Parent = card
    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 28
    gradient.Color = ColorSequence.new(NAVY, Color3.fromRGB(27, 66, 105))
    gradient.Parent = card
    local cardScale = Instance.new("UIScale")
    cardScale.Scale = 0.65
    cardScale.Parent = card
    local heading = Instance.new("TextLabel")
    heading.BackgroundTransparency = 1
    heading.Position = UDim2.new(0, 15, 0, 24)
    heading.Size = UDim2.new(1, -30, 0, 62)
    heading.Text = title
    heading.TextColor3 = tint
    heading.TextWrapped = true
    heading.TextSize = 25
    heading.Font = Enum.Font.GothamBlack
    heading.ZIndex = 21
    heading.Parent = card
    local detail = Instance.new("TextLabel")
    detail.BackgroundTransparency = 1
    detail.Position = UDim2.new(0, 16, 0, 96)
    detail.Size = UDim2.new(1, -32, 0, 67)
    detail.Text = caption
    detail.TextColor3 = WHITE
    detail.TextWrapped = true
    detail.TextSize = 16
    detail.Font = Enum.Font.GothamBold
    detail.ZIndex = 21
    detail.Parent = card
    if effectsEnabled() and not reducedMotion() then
        TweenService:Create(cardScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
    else
        cardScale.Scale = 1
    end
    for i = 1, (effectsEnabled() and not reducedMotion()) and 14 or 0 do
        local confetti = Instance.new("Frame")
        confetti.Name = "Confetti"
        confetti.AnchorPoint = Vector2.new(0.5, 0.5)
        confetti.Size = UDim2.fromOffset(math.random(5, 12), math.random(7, 17))
        confetti.Position = UDim2.fromScale(0.5, 0.39)
        confetti.Rotation = math.random(0, 180)
        confetti.BorderSizePixel = 0
        confetti.BackgroundColor3 = i % 2 == 0 and tint or SKY
        confetti.ZIndex = 22
        confetti.Parent = gui
        local mx = math.random(-190, 190)
        local my = math.random(-170, 125)
        TweenService:Create(confetti, TweenInfo.new(0.95, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, mx, 0.39, my),
            Rotation = confetti.Rotation + math.random(100, 330),
            BackgroundTransparency = 1,
        }):Play()
        task.delay(1.05, function() confetti:Destroy() end)
    end
    task.delay(2.4, function()
        if serial ~= activeSerial or activeCard ~= card then return end
        TweenService:Create(cardScale, TweenInfo.new(0.23, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.78}):Play()
        TweenService:Create(card, TweenInfo.new(0.23), {BackgroundTransparency = 1}):Play()
        task.delay(0.25, function()
            if activeCard == card then activeCard = nil end
            card:Destroy()
            local nextCard = table.remove(pendingCards, 1)
            if nextCard then rewardCard(nextCard[1], nextCard[2], nextCard[3]) end
        end)
    end)
end

visuals.OnClientEvent:Connect(function(event)
    if typeof(event) ~= "table" or typeof(event.Type) ~= "string" then return end
    if event.Type == "EventReward" then
        rewardCard("✦ ЗВЁЗДНЫЙ ДОЖДЬ!", "+500 кликов и +20 кристаллов. Награда получена!", SKY)
    elseif event.Type == "WeeklyReward" then
        rewardCard("📅 НЕДЕЛЬНОЕ ЗАДАНИЕ!", "Кристаллы за недельный прогресс получены!", GOLD)
    elseif event.Type == "WorldChest" then
        local reward = Config.WorldChests[event.World]
        if reward then
            rewardCard("🎁 СУНДУК МИРА!", "+" .. reward.Clicks .. " кликов и +" .. reward.Gems .. " кристаллов!", GOLD)
        end
    elseif event.Type == "RuneComplete" then
        rewardCard("🔮 ИСПЫТАНИЕ РУН!", "Сила кликов ×2 на 75 секунд!", SKY)
    elseif event.Type == "Fusion" then
        local pet = Config.FindPet(event.Species)
        if pet then
            rewardCard("✨ СЛИЯНИЕ ПИТОМЦЕВ!", "Получен: " .. pet.Name .. " • бонус +" .. pet.Bonus .. "%", pet.Color)
        end
    elseif event.Type == "Rebirth" then
        rewardCard("🔄 ПЕРЕРОЖДЕНИЕ!", "Новая ступень силы. Получены кристаллы!", GOLD)
    elseif event.Type == "WorldUnlock" then
        local world = Config.FindWorld(event.World)
        if world then rewardCard("🌍 МИР ОТКРЫТ!", world.Name .. " • Клики x" .. world.Multiplier, SKY) end
    elseif event.Type == "TutorialStep" and event.Step == 4 then
        rewardCard("👑 ОБУЧЕНИЕ ПРОЙДЕНО!", "+200 кликов и +5 кристаллов. Добро пожаловать в GROWLIVO!", GOLD)
    end
end)
]==]},
    {name="GrowlivoTutorial", className="LocalScript", target="StarterPlayerScripts", source=[==[-- GROWLIVO / Persistent three-step beginner guide / Alpha 0.9.14
-- StarterPlayer > StarterPlayerScripts > GrowlivoTutorial [LocalScript]
-- Read-only UI. Tutorial progress and completion rewards belong to the server.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "GROWLIVO_Tutorial"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 2
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
local DARK = Color3.fromRGB(12, 29, 52)
local PANEL = Color3.fromRGB(22, 44, 76)
local GOLD = Color3.fromRGB(255, 202, 73)
local CYAN = Color3.fromRGB(45, 208, 255)
local WHITE = Color3.fromRGB(239, 249, 255)
local MUTED = Color3.fromRGB(180, 205, 226)

local panel = Instance.new("Frame")
panel.Name = "TutorialCard"
panel.BackgroundColor3 = PANEL
panel.BorderSizePixel = 0
panel.Parent = gui
local round = Instance.new("UICorner")
round.CornerRadius = UDim.new(0, 14)
round.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = GOLD
stroke.Thickness = 1.8
stroke.Transparency = 0.15
stroke.Parent = panel
local function label(name, caption, font, size, color)
    local obj = Instance.new("TextLabel")
    obj.Name = name
    obj.BackgroundTransparency = 1
    obj.Text = caption
    obj.Font = font
    obj.TextSize = size
    obj.TextColor3 = color
    obj.TextXAlignment = Enum.TextXAlignment.Left
    obj.TextWrapped = true
    obj.Parent = panel
    return obj
end
local heading = label("Heading", "👑 ОБУЧЕНИЕ", Enum.Font.GothamBlack, 15, GOLD)
local hint = label("Hint", "", Enum.Font.Gotham, 13, WHITE)
local progress = label("Progress", "", Enum.Font.GothamBold, 12, MUTED)
local bar = Instance.new("Frame")
bar.Name = "ProgressTrack"
bar.BackgroundColor3 = DARK
bar.BorderSizePixel = 0
bar.Parent = panel
local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(1, 0)
barCorner.Parent = bar
local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = CYAN
fill.BorderSizePixel = 0
fill.Parent = bar
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = fill
local toggle = Instance.new("TextButton")
toggle.Name = "Toggle"
toggle.BackgroundColor3 = DARK
local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 8)
toggleCorner.Parent = toggle
toggle.Text = "−"
toggle.TextColor3 = GOLD
toggle.TextSize = 22
toggle.Font = Enum.Font.GothamBold
toggle.BorderSizePixel = 0
toggle.Parent = panel
-- Mobile guide starts as a button so it cannot hide quests/settings.
local collapsed = false
local firstLayout = true
local viewportCompact = false
local viewportTooShort = false

local function currentStage()
    return tonumber(player:GetAttribute("TutorialStep")) or 1
end
local function layout()
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1000, 700)
    local w, h = viewport.X, viewport.Y
    local mobile = w < 700
    if firstLayout then
        collapsed = mobile
        firstLayout = false
    end
    viewportCompact = mobile and h < 440
    viewportTooShort = mobile and h < 390
    local small = collapsed or viewportCompact
    if mobile then
        if small then
            local navY = h < 650 and 163 or 187
            panel.AnchorPoint = Vector2.new(0, 0)
            panel.Position = UDim2.fromOffset(math.floor(w / 2) + 5, navY + 147)
            panel.Size = UDim2.fromOffset(math.floor(w / 2) - 17, 43)
            panel.ZIndex = 2
            gui.DisplayOrder = 2
        else
            -- Expanded on demand, above other HUD elements, closes via the + button.
            panel.AnchorPoint = Vector2.new(0.5, 0.5)
            panel.Position = UDim2.fromScale(0.5, 0.5)
            panel.Size = UDim2.new(1, -24, 0, 135)
            panel.ZIndex = 20
            gui.DisplayOrder = 40
        end
    else
        panel.AnchorPoint = Vector2.new(0, 0)
        panel.Position = UDim2.new(1, -328, 0, 304)
        panel.Size = UDim2.fromOffset(308, small and 43 or 136)
        panel.ZIndex = 2
        gui.DisplayOrder = 2
    end
    heading.Position = UDim2.fromOffset(12, 5)
    heading.TextSize = small and 12 or 15
    heading.Size = UDim2.new(1, -58, 0, 30)
    hint.Position = UDim2.fromOffset(13, 37)
    hint.Size = UDim2.new(1, -26, 0, mobile and 38 or 49)
    progress.Position = UDim2.fromOffset(13, mobile and 76 or 88)
    progress.Size = UDim2.new(1, -26, 0, 20)
    bar.Position = UDim2.new(0, 13, 1, -13)
    bar.Size = UDim2.new(1, -26, 0, 6)
    toggle.Position = UDim2.new(1, -37, 0, 6)
    toggle.Size = UDim2.fromOffset(29, 28)
    toggle.Text = small and "+" or "−"
    hint.Visible = not small
    progress.Visible = not small
    bar.Visible = not small
    -- The compact menu controls collapsed visibility on short screens.
end
local function update()
    local ready = player:GetAttribute("DataReady") == true
    local step = currentStage()
    local camera = workspace.CurrentCamera
    local size = camera and camera.ViewportSize or Vector2.new(1000, 700)
    local compactNav = size.X < 700 and size.Y < 500
    panel.Visible = ready and step < 4
        and (not compactNav or player:GetAttribute("CompactMenuOpen") == true)
    if not panel.Visible then return end
    local taps = math.min(20, math.floor(tonumber(player:GetAttribute("TutorialClicks")) or 0))
    if step == 1 then
        heading.Text = "👆 1/3 • ПЕРВЫЕ КЛИКИ"
        hint.Text = "Нажми большую золотую кнопку 20 раз. На ПК также можно нажимать пробел."
        progress.Text = string.format("Нажатия: %d / 20", taps)
    elseif step == 2 then
        heading.Text = "⚡ 2/3 • УЛУЧШЕНИЕ"
        hint.Text = "Накопи клики и купи улучшение силы клика в игровом меню."
        progress.Text = "Действие: купить одно улучшение"
    else
        heading.Text = "🥚 3/3 • ПЕРВОЕ ЯЙЦО"
        hint.Text = "Открой ПИТОМЦЫ, накопи 150 кликов и купи яйцо. Питомец усилит каждый клик."
        progress.Text = "Награда: +200 кликов и +5 💎"
    end
    local percentage = step == 1 and (taps / 20) or step == 2 and (1 / 3) or (2 / 3)
    if GuiService.ReducedMotionEnabled or player:GetAttribute("SettingReducedMotion") == true then
        fill.Size = UDim2.fromScale(percentage, 1)
    else
        TweenService:Create(fill, TweenInfo.new(0.22), {Size = UDim2.fromScale(percentage, 1)}):Play()
    end
end
toggle.Activated:Connect(function()
    collapsed = not collapsed
    layout()
    update()
end)
for _, attribute in ipairs({"DataReady", "TutorialStep", "TutorialClicks"}) do
    player:GetAttributeChangedSignal(attribute):Connect(update)
end
local function cameraChanged()
    layout()
    update()
    local camera = workspace.CurrentCamera
    if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        layout()
        update()
    end) end
end
cameraChanged()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(cameraChanged)
update()

player:GetAttributeChangedSignal("CompactMenuOpen"):Connect(function()
    layout()
    update()
end)

player:GetAttributeChangedSignal("CompactMenuOpen"):Connect(function()
    layout()
    update()
end)
]==]},
    {name="GrowlivoHatchFX", className="LocalScript", target="StarterPlayerScripts", source=[==[-- GROWLIVO / Cinematic egg opening in ViewportFrame / Alpha 0.9.14
-- Local-only presentation. No rewards or currency changes happen here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("GrowlivoConfig"))
local visual = ReplicatedStorage:WaitForChild("GROWLIVO_Remotes"):WaitForChild("VisualEvent")

local GOLD = Color3.fromRGB(255, 207, 70)
local CYAN = Color3.fromRGB(45, 207, 255)
local NAVY = Color3.fromRGB(16, 30, 57)
local WHITE = Color3.fromRGB(241, 249, 255)
local gui = Instance.new("ScreenGui")
gui.Name = "GROWLIVO_HatchFX"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 45
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local overlay = Instance.new("Frame")
overlay.Name = "HatchingOverlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(4, 11, 23)
overlay.BackgroundTransparency = 0.18
overlay.BorderSizePixel = 0
overlay.Visible = false
overlay.Active = true
overlay.Parent = gui

local card = Instance.new("Frame")
card.Name = "HatchingCard"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.BackgroundColor3 = NAVY
card.BorderSizePixel = 0
card.Parent = overlay
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 22)
corner.Parent = card
local rim = Instance.new("UIStroke")
rim.Thickness = 3
rim.Color = GOLD
rim.Parent = card
local scale = Instance.new("UIScale")
scale.Parent = card

local title = Instance.new("TextLabel")
title.Name = "Heading"
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 12, 0, 12)
title.Size = UDim2.new(1, -24, 0, 40)
title.Font = Enum.Font.GothamBlack
title.TextSize = 23
title.TextColor3 = GOLD
title.Parent = card

-- One egg rendered entirely from primitive Roblox Parts, without external assets.
local viewport = Instance.new("ViewportFrame")
viewport.Name = "EggViewport"
viewport.Position = UDim2.new(0, 15, 0, 55)
viewport.Size = UDim2.new(1, -30, 0, 195)
viewport.BackgroundColor3 = Color3.fromRGB(22, 46, 82)
viewport.BackgroundTransparency = 0.1
viewport.BorderSizePixel = 0
viewport.Ambient = Color3.fromRGB(168, 197, 255)
viewport.LightColor = WHITE
viewport.LightDirection = Vector3.new(-1, -2, -1)
viewport.Parent = card
local viewportCorner = Instance.new("UICorner")
viewportCorner.CornerRadius = UDim.new(0, 15)
viewportCorner.Parent = viewport
local modelWorld = Instance.new("WorldModel")
modelWorld.Parent = viewport
local camera = Instance.new("Camera")
camera.CFrame = CFrame.new(Vector3.new(0, 1, 12), Vector3.new(0, 0, 0))
camera.FieldOfView = 45
camera.Parent = viewport
viewport.CurrentCamera = camera
local egg = Instance.new("Model")
egg.Name = "RoyalEgg"
egg.Parent = modelWorld
local function piece(name, size, cf, tint, shape)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.CFrame = cf
    part.Color = tint
    part.Material = Enum.Material.SmoothPlastic
    part.Shape = shape or Enum.PartType.Ball
    part.Anchored = true
    part.CanCollide = false
    part.Parent = egg
    return part
end
local shell = piece("EggShell", Vector3.new(4.2, 5.2, 4.1), CFrame.new(), CYAN)
egg.PrimaryPart = shell
piece("GoldBand", Vector3.new(4.35, 0.55, 4.25), CFrame.new(0, -0.65, 0), GOLD)
piece("CrystalTop", Vector3.new(2.2, 0.9, 2.2), CFrame.new(0, 2.4, 0), GOLD)
for _, x in ipairs({-1, 0, 1}) do
    piece("CrownGem", Vector3.new(0.65, 0.65, 0.6), CFrame.new(x, 2.55 + (x == 0 and 0.5 or 0), -0.2), WHITE)
end

local result = Instance.new("TextLabel")
result.Name = "PetResult"
result.BackgroundTransparency = 1
result.Position = UDim2.new(0, 12, 0, 255)
result.Size = UDim2.new(1, -24, 0, 60)
result.Font = Enum.Font.GothamBlack
result.TextWrapped = true
result.TextSize = 23
result.TextColor3 = GOLD
result.Text = ""
result.Parent = card
local detail = Instance.new("TextLabel")
detail.Name = "PetDetails"
detail.BackgroundTransparency = 1
detail.Position = UDim2.new(0, 12, 0, 312)
detail.Size = UDim2.new(1, -24, 0, 33)
detail.Font = Enum.Font.GothamBold
detail.TextWrapped = true
detail.TextSize = 15
detail.TextColor3 = WHITE
detail.Text = ""
detail.Parent = card
local skip = Instance.new("TextButton")
skip.Name = "Skip"
skip.AnchorPoint = Vector2.new(0.5, 0)
skip.Position = UDim2.new(0.5, 0, 1, -49)
skip.Size = UDim2.fromOffset(180, 36)
skip.Text = "ПРОПУСТИТЬ"
skip.TextColor3 = NAVY
skip.Font = Enum.Font.GothamBold
skip.TextSize = 14
skip.BackgroundColor3 = GOLD
skip.BorderSizePixel = 0
skip.Parent = card
local skipCorner = Instance.new("UICorner")
skipCorner.CornerRadius = UDim.new(0, 10)
skipCorner.Parent = skip

local queue, playing, serial = {}, false, 0
local forceReveal = false
local function shortAnimation()
    return GuiService.ReducedMotionEnabled or player:GetAttribute("SettingReducedMotion") == true
        or player:GetAttribute("SettingEffects") == false
end
local function layout()
    local v = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(900, 700)
    local width = math.max(248, math.min(440, v.X - 28))
    local height = math.max(294, math.min(420, v.Y - 30))
    card.Size = UDim2.fromOffset(width, height)
    local previewHeight = math.max(95, height - 222)
    viewport.Size = UDim2.new(1, -30, 0, previewHeight)
    result.Position = UDim2.new(0, 12, 0, 60 + previewHeight)
    detail.Position = UDim2.new(0, 12, 0, 118 + previewHeight)
end
local cameraConnection
local function cameraChanged()
    if cameraConnection then cameraConnection:Disconnect() end
    layout()
    if workspace.CurrentCamera then
        cameraConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
    end
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(cameraChanged)
cameraChanged()
skip.Activated:Connect(function() forceReveal = true end)

local function playHatch(pet)
    serial += 1
    local ticket = serial
    overlay.Visible = true
    result.Text = ""
    detail.Text = ""
    title.Text = "🥚 ОТКРЫТИЕ ЯЙЦА"
    rim.Color = pet.Color
    shell.Color = pet.Color
    egg:PivotTo(CFrame.new())
    scale.Scale = 1
    forceReveal = false
    skip.Text = "ПРОПУСТИТЬ"
    if not shortAnimation() then
        for i = 1, 5 do
            if forceReveal or ticket ~= serial then break end
            local angle = (i % 2 == 0 and 1 or -1) * math.rad(9 + i * 3)
            egg:PivotTo(CFrame.Angles(0, angle, angle / 2))
            task.wait(0.13)
        end
        if not forceReveal then
            local flicker = TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back), {Scale = 1.07})
            flicker:Play()
            task.wait(0.16)
        end
    end
    egg:PivotTo(CFrame.new())
    scale.Scale = 1
    -- A first tap skips the egg shake; a second tap closes the result.
    forceReveal = false
    title.Text = "✨ НОВЫЙ ПИТОМЕЦ!"
    result.Text = pet.Name
    result.TextColor3 = pet.Color
    detail.Text = pet.Rarity .. "  •  Бонус к кликам +" .. pet.Bonus .. "%"
    skip.Text = "ЗАКРЫТЬ"
    -- An explicit close remains available, while each reward still auto-dismisses.
    local waited = 0
    while waited < (shortAnimation() and 0.65 or 1.5) do
        if forceReveal then break end
        task.wait(0.05)
        waited += 0.05
    end
    overlay.Visible = false
end

local function drain()
    if playing then return end
    playing = true
    while #queue > 0 do
        local nextPet = table.remove(queue, 1)
        if nextPet then playHatch(nextPet) end
    end
    playing = false
end
visual.OnClientEvent:Connect(function(event)
    if typeof(event) ~= "table" or event.Type ~= "Hatch" then return end
    local pet = Config.FindPet(event.Species)
    if not pet then return end
    -- Bounded queue; a triple hatch cannot flood the screen with unbounded GUIs.
    if #queue < 6 then
        table.insert(queue, pet)
        task.spawn(drain)
    end
end)
]==]},
    {name="GrowlivoSettingsUI", className="LocalScript", target="StarterPlayerScripts", source=[==[-- GROWLIVO / Player preferences / Alpha 0.9.14
-- StarterPlayer > StarterPlayerScripts > GrowlivoSettingsUI [LocalScript]
-- Toggles persist on the server; only known boolean options are accepted.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local action = RS:WaitForChild("GROWLIVO_Remotes"):WaitForChild("Action")
local gui = Instance.new("ScreenGui")
gui.Name = "GROWLIVO_SettingsUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 30
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local NAVY = Color3.fromRGB(18, 34, 60)
local DARK = Color3.fromRGB(9, 19, 36)
local GOLD = Color3.fromRGB(255, 202, 68)
local CYAN = Color3.fromRGB(60, 209, 255)
local WHITE = Color3.fromRGB(242, 250, 255)
local function round(target, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 12)
    corner.Parent = target
end
local function makeFrame(name, parent, tint, z)
    local obj = Instance.new("Frame")
    obj.Name = name
    obj.BackgroundColor3 = tint
    obj.BorderSizePixel = 0
    obj.ZIndex = z or 1
    obj.Parent = parent
    round(obj)
    return obj
end
local function makeButton(name, parent, label, tint, z)
    local obj = Instance.new("TextButton")
    obj.Name = name
    obj.Text = label
    obj.Font = Enum.Font.GothamBold
    obj.TextSize = 15
    obj.TextColor3 = DARK
    obj.TextWrapped = true
    obj.AutoButtonColor = true
    obj.BackgroundColor3 = tint
    obj.BorderSizePixel = 0
    obj.ZIndex = z or 1
    obj.Parent = parent
    round(obj, 10)
    return obj
end
local function makeText(name, parent, label, fontSize, tint, z)
    local obj = Instance.new("TextLabel")
    obj.Name = name
    obj.Text = label
    obj.Font = Enum.Font.GothamBold
    obj.TextSize = fontSize
    obj.TextWrapped = true
    obj.TextColor3 = tint
    obj.BackgroundTransparency = 1
    obj.TextXAlignment = Enum.TextXAlignment.Left
    obj.ZIndex = z or 1
    obj.Parent = parent
    return obj
end

local open = makeButton("SettingsButton", gui, "⚙ НАСТРОЙКИ", CYAN)
local overlay = makeFrame("Overlay", gui, Color3.fromRGB(0, 0, 0), 10)
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundTransparency = 0.25
overlay.Active = true
overlay.Visible = false
local modal = makeFrame("SettingsPanel", overlay, NAVY, 11)
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.fromScale(0.5, 0.5)
local modalScale = Instance.new("UIScale")
modalScale.Scale = 1
modalScale.Parent = modal
local rim = Instance.new("UIStroke")
rim.Color = GOLD
rim.Thickness = 2
rim.Parent = modal
local heading = makeText("Heading", modal, "⚙ НАСТРОЙКИ GROWLIVO", 20, GOLD, 12)
heading.Position = UDim2.fromOffset(16, 12)
heading.Size = UDim2.new(1, -78, 0, 42)
local close = makeButton("Close", modal, "✕", GOLD, 12)
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -13, 0, 14)
close.Size = UDim2.fromOffset(42, 38)
local subtitle = makeText("Subtitle", modal, "Настройки сохраняются в профиле", 13, WHITE, 12)
subtitle.Position = UDim2.fromOffset(18, 58)
subtitle.Size = UDim2.new(1, -36, 0, 25)

local entries = {
    {Key = "ShowPets", Name = "Показывать питомцев", Info = "Скрыть 3D-модели рядом с героем"},
    {Key = "Effects", Name = "Эффекты и частицы", Info = "Анимации кликов и конфетти"},
    {Key = "ReducedMotion", Name = "Уменьшить движение", Info = "Без тряски и вспышек при яйцах"},
    {Key = "Sounds", Name = "Звуковые эффекты", Info = "Звук кликов и игровых наград"},
}
local toggles = {}
for i, item in ipairs(entries) do
    local row = makeFrame(item.Key .. "Row", modal, DARK, 12)
    row.Position = UDim2.fromOffset(16, 96 + (i - 1) * 86)
    row.Size = UDim2.new(1, -32, 0, 76)
    local title = makeText("Name", row, item.Name, 14, WHITE, 13)
    title.Position = UDim2.fromOffset(12, 9)
    title.Size = UDim2.new(1, -125, 0, 31)
    local desc = makeText("Info", row, item.Info, 11, Color3.fromRGB(174, 200, 220), 13)
    desc.Position = UDim2.fromOffset(12, 39)
    desc.Size = UDim2.new(1, -128, 0, 29)
    local toggle = makeButton("Toggle", row, "", CYAN, 13)
    toggle.AnchorPoint = Vector2.new(1, 0.5)
    toggle.Position = UDim2.new(1, -9, 0.5, 0)
    toggle.Size = UDim2.fromOffset(91, 43)
    toggles[item.Key] = toggle
    toggle.Activated:Connect(function()
        if player:GetAttribute("DataReady") ~= true then return end
        local current = player:GetAttribute("Setting" .. item.Key)
        if typeof(current) ~= "boolean" then return end
        action:FireServer("SetSetting", {Key = item.Key, Value = not current})
    end)
end
local status = makeText("Status", modal, "", 12, WHITE, 12)
status.Position = UDim2.fromOffset(18, 439)
status.Size = UDim2.new(1, -36, 0, 27)

local function refresh()
    for _, item in ipairs(entries) do
        local value = player:GetAttribute("Setting" .. item.Key)
        local control = toggles[item.Key]
        control.Text = value == true and "ВКЛ" or "ВЫКЛ"
        control.BackgroundColor3 = value == true and GOLD or CYAN
    end
    status.Text = player:GetAttribute("SavingEnabled") == false
        and "⚠ Сейчас сохранение недоступно" or "Изменения сохраняются вместе с прогрессом"
end
local function setOpen(value)
    overlay.Visible = value
    -- Client-side attribute for HUD input suppression only; never trusted by server.
    player:SetAttribute("SettingsOpen", value)
    if value then refresh() end
end
open.Activated:Connect(function() setOpen(true) end)
close.Activated:Connect(function() setOpen(false) end)
UserInputService.InputBegan:Connect(function(input, handled)
    if not handled and input.KeyCode == Enum.KeyCode.Escape and overlay.Visible then
        setOpen(false)
    end
end)
for _, entry in ipairs(entries) do
    player:GetAttributeChangedSignal("Setting" .. entry.Key):Connect(refresh)
end
player:GetAttributeChangedSignal("SavingEnabled"):Connect(refresh)
local function compactNavigationVisible(w, h)
    return w >= 700 or h >= 500 or player:GetAttribute("CompactMenuOpen") == true
end
local function resize()
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1000, 700)
    open.Visible = compactNavigationVisible(viewport.X, viewport.Y)
    modalScale.Scale = math.min(1, math.max(0.68, (viewport.Y - 22) / 490))
    if viewport.X < 700 then
        local navY = viewport.Y < 650 and 163 or 187
        open.Position = UDim2.fromOffset(math.floor(viewport.X / 2) + 5, navY + 98)
        open.Size = UDim2.fromOffset(math.floor(viewport.X / 2) - 17, 43)
        modal.Size = UDim2.fromOffset(math.max(270, math.min(430, (viewport.X - 22) / modalScale.Scale)), 490)
        heading.TextSize = 17
    else
        open.Position = UDim2.fromOffset(18, 378)
        open.Size = UDim2.fromOffset(175, 45)
        modal.Size = UDim2.fromOffset(460, 490)
        heading.TextSize = 20
    end
end
local cameraConnection
local function cameraChanged()
    if cameraConnection then cameraConnection:Disconnect() end
    resize()
    if workspace.CurrentCamera then
        cameraConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
    end
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(cameraChanged)
cameraChanged()
refresh()

player:GetAttributeChangedSignal("CompactMenuOpen"):Connect(resize)
]==]},
    {name="GrowlivoLeaderboards", className="Script", target="ServerScriptService", source=[==[-- GROWLIVO / Persistent global rankings / Alpha 0.9.17
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
]==]},
    {name="GrowlivoLeaderboardUI", className="LocalScript", target="StarterPlayerScripts", source=[==[-- GROWLIVO / Global top-10 panel / Alpha 0.9.14
-- StarterPlayer > StarterPlayerScripts > GrowlivoLeaderboardUI [LocalScript]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("GROWLIVO_Remotes")
local request = remotes:WaitForChild("RequestBoards")
local boardState = remotes:WaitForChild("BoardState")
local GOLD, BLUE, WHITE = Color3.fromRGB(255, 207, 73), Color3.fromRGB(56, 207, 255), Color3.fromRGB(237, 247, 255)
local PANEL = Color3.fromRGB(18, 31, 58)
local gui = Instance.new("ScreenGui")
gui.Name = "GROWLIVO_LeaderboardUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local function round(target)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 12)
    c.Parent = target
end
local function label(parent, content, size, color)
    local t = Instance.new("TextLabel")
    t.Size = UDim2.fromScale(1, 1)
    t.BackgroundTransparency = 1
    t.TextColor3 = color or WHITE
    t.Font = Enum.Font.GothamBold
    t.TextSize = size or 16
    t.TextWrapped = true
    t.Text = content
    t.Parent = parent
    return t
end
local function button(parent, name, value, color)
    local b = Instance.new("TextButton")
    b.Name = name
    b.Text = value
    b.TextSize = 15
    b.TextColor3 = PANEL
    b.Font = Enum.Font.GothamBold
    b.BackgroundColor3 = color or GOLD
    b.Parent = parent
    round(b)
    return b
end
local opener = button(gui, "OpenGlobalTop", "🏆 ТОП", GOLD)
opener.Position = UDim2.fromOffset(12, 292)
opener.Size = UDim2.fromOffset(110, 42)
local function compactNavigationVisible(w, h)
    return w >= 700 or h >= 500 or player:GetAttribute("CompactMenuOpen") == true
end
local function positionOpener()
    local camera = workspace.CurrentCamera
    local w = camera and camera.ViewportSize.X or 900
    local h = camera and camera.ViewportSize.Y or 700
    opener.Visible = compactNavigationVisible(w, h)
    if w < 700 then
        local navY = h < 650 and 163 or 187
        opener.Position = UDim2.fromOffset(12, navY + 98)
        opener.Size = UDim2.fromOffset(math.floor(w / 2) - 19, 43)
    else
        opener.Position = UDim2.fromOffset(18, 436)
        opener.Size = UDim2.fromOffset(245, 45)
    end
end
local viewportConnection
local function attachCamera()
    if viewportConnection then viewportConnection:Disconnect() end
    positionOpener()
    local camera = workspace.CurrentCamera
    if camera then
        viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(positionOpener)
    end
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(attachCamera)
attachCamera()
local panel = Instance.new("Frame")
panel.Name = "GlobalTopPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.9, 0, 0.78, 0)
panel.BackgroundColor3 = PANEL
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
round(panel)
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(520, 540)
limit.MinSize = Vector2.new(270, 300)
limit.Parent = panel
local heading = label(panel, "🏆 РЕКОРДЫ GROWLIVO", 21, GOLD)
heading.Position = UDim2.fromOffset(12, 10)
heading.Size = UDim2.new(1, -66, 0, 36)
local close = button(panel, "Close", "✕", BLUE)
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -12, 0, 12)
close.Size = UDim2.fromOffset(38, 33)
local totalTab = button(panel, "TotalClicks", "ВСЕ КЛИКИ", GOLD)
totalTab.Position = UDim2.new(0, 12, 0, 55)
totalTab.Size = UDim2.new(0.5, -18, 0, 40)
local rebirthTab = button(panel, "Rebirths", "ПЕРЕРОЖДЕНИЯ", BLUE)
rebirthTab.Position = UDim2.new(0.5, 6, 0, 55)
rebirthTab.Size = UDim2.new(0.5, -18, 0, 40)
local scroll = Instance.new("ScrollingFrame")
scroll.Name = "TopEntries"
scroll.Position = UDim2.fromOffset(12, 106)
scroll.Size = UDim2.new(1, -24, 1, -149)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 5
scroll.BorderSizePixel = 0
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.fromOffset(0, 0)
scroll.Parent = panel
local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 5)
layout.Parent = scroll
local status = label(panel, "Загрузка результатов…", 12, BLUE)
status.Position = UDim2.new(0, 12, 1, -38)
status.Size = UDim2.new(1, -24, 0, 28)
local currentTab = "TotalClicks"
local data = nil
local function pretty(v)
    if v >= 1e12 then return string.format("%.2fT", v / 1e12) end
    if v >= 1e9 then return string.format("%.2fB", v / 1e9) end
    if v >= 1e6 then return string.format("%.2fM", v / 1e6) end
    return tostring(math.floor(v))
end
local function redraw()
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    local entries = data and data[currentTab]
    if typeof(entries) ~= "table" or #entries == 0 then
        local empty = label(scroll, "Пока нет сохранённых рекордов", 15, WHITE)
        empty.Size = UDim2.new(1, -6, 0, 48)
        empty.LayoutOrder = 1
    else
        for i, entry in ipairs(entries) do
            local row = label(scroll, string.format("%d. %s   •   %s", i, tostring(entry.Name), pretty(tonumber(entry.Value) or 0)), 14, i <= 3 and GOLD or WHITE)
            row.Size = UDim2.new(1, -7, 0, 32)
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.LayoutOrder = i
        end
    end
    local stamp = data and tonumber(data.UpdatedAt) or 0
    if data and data.Available == false then
        status.Text = "Данные временно недоступны · показан последний снимок"
    elseif stamp > 0 then
        status.Text = "Обновлено: " .. os.date("!%H:%M UTC", stamp)
    else
        status.Text = "Рейтинг обновится после первого сохранения"
    end
    totalTab.BackgroundColor3 = currentTab == "TotalClicks" and GOLD or BLUE
    rebirthTab.BackgroundColor3 = currentTab == "Rebirths" and GOLD or BLUE
end
boardState.OnClientEvent:Connect(function(payload)
    if typeof(payload) ~= "table" then return end
    data = payload
    redraw()
end)
totalTab.Activated:Connect(function() currentTab = "TotalClicks"; redraw() end)
rebirthTab.Activated:Connect(function() currentTab = "Rebirths"; redraw() end)
close.Activated:Connect(function() panel.Visible = false end)
opener.Activated:Connect(function()
    panel.Visible = not panel.Visible
    if panel.Visible then request:FireServer(); redraw() end
end)
request:FireServer()

player:GetAttributeChangedSignal("CompactMenuOpen"):Connect(positionOpener)
]==]},
    {name="GrowlivoAdminServer", className="Script", target="ServerScriptService", source=[==[-- GROWLIVO / Minimal server-authoritative moderation / Alpha 0.9.14
-- ServerScriptService > GrowlivoAdminServer [Script]
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("GrowlivoConfig"))
local remotes = ReplicatedStorage:WaitForChild("GROWLIVO_Remotes")
local function remote(name)
    local r = remotes:FindFirstChild(name)
    assert(not r or r:IsA("RemoteEvent"), "Unexpected remote: " .. name)
    if not r then
        r = Instance.new("RemoteEvent")
        r.Name = name
        r.Parent = remotes
    end
    return r
end
local adminAction = remote("AdminAction")
local adminReply = remote("AdminReply")
local notice = remote("ServerNotice")

local allowed = {}
for _, userId in ipairs(Config.AdminUserIds) do
    if typeof(userId) == "number" and userId >= 1 and userId == math.floor(userId) then
        allowed[userId] = true
    end
end
local function isAdmin(player)
    return player and allowed[player.UserId] == true
end
local function setAdminFlag(player)
    player:SetAttribute("GrowlivoAdmin", isAdmin(player))
end
Players.PlayerAdded:Connect(setAdminFlag)
for _, player in ipairs(Players:GetPlayers()) do setAdminFlag(player) end
local lastRequest = {}
local function respond(player, text)
    adminReply:FireClient(player, tostring(text))
end
local function audit(player, action, target)
    warn(string.format("[GROWLIVO ADMIN] user=%d action=%s target=%s", player.UserId, action, tostring(target or "none")))
end
adminAction.OnServerEvent:Connect(function(player, command, raw)
    -- The attribute and interface are cosmetic; this check is the actual permission boundary.
    if not isAdmin(player) then
        warn("[GROWLIVO ADMIN] unauthorized call user=" .. tostring(player.UserId))
        return
    end
    if typeof(command) ~= "string" or #command > 20 then return end
    local now = os.clock()
    if now - (lastRequest[player] or -100) < 2 then return end
    lastRequest[player] = now
    if command == "ServerInfo" then
        respond(player, "Игроков в сервере: " .. tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers))
    elseif command == "Diagnostics" then
        local data = ServerScriptService:FindFirstChild("GROWLIVO_Diagnostics")
        local ready, saving = 0, 0
        for _, current in ipairs(Players:GetPlayers()) do
            if current:GetAttribute("DataReady") == true then ready += 1 end
            if current:GetAttribute("SavingEnabled") == true then saving += 1 end
        end
        local function metric(key)
            return data and tonumber(data:GetAttribute(key)) or 0
        end
        audit(player, "diagnostics", "server")
        respond(player, string.format("Профили: %d готовы / %d запись разрешена | Load: %d | Save: %d | Lock: %d | Timeout: %d | Exit: %d | Recovery: %d | Retry: %d | Drops: %d | ms: %d/%d | в записи: %d | поздних: %d | профили отклонены: %d | новые версии: %d | запись отклонена: %d | пропуск автосохр.: %d | опасных снимков: %d",
            ready, saving, metric("LoadFailures"), metric("SaveFailures"),
            metric("LostLocks"), metric("SaveTimeouts"),
            metric("ExitSaveFailures"), metric("SaveRecoveries"),
            metric("SaveRetryBatches"), metric("RemoteDrops"),
            metric("LastSaveMs"), metric("MaxSaveMs"), metric("ActiveSaves"),
            metric("LateSaveCompletions"), metric("RejectedProfileLoads"),
            metric("FutureProfileVersions"), metric("RejectedProfileWrites"),
            metric("AutosaveBusySkips"), metric("RejectedSnapshotWrites")))
    elseif command == "Telemetry" then
        local data = ServerScriptService:FindFirstChild("GROWLIVO_Diagnostics")
        local function metric(key)
            return data and tonumber(data:GetAttribute(key)) or 0
        end
        audit(player, "telemetry", "server")
        respond(player, string.format(
            "Клики: %d | Улучшения: %d | Яйца: %d | Перерожд.: %d | Дни: %d | Недели: %d | Сохран.: %d",
            metric("AcceptedTaps"), metric("UpgradesBought"), metric("EggsOpened"),
            metric("RebirthsMade"), metric("DailyClaims"), metric("WeeklyClaims"), metric("ConfirmedSaves")))
    elseif command == "Inspect" or command == "Kick" then
        if typeof(raw) ~= "number" or raw ~= math.floor(raw) or raw < 1 then
            respond(player, "Укажите корректный числовой UserId")
            return
        end
        local target = Players:GetPlayerByUserId(raw)
        if not target then respond(player, "Игрок не найден в текущем сервере") return end
        if command == "Inspect" then
            audit(player, "inspect", raw)
            respond(player, string.format("%s | ID %d | Клики: %s | Перерождения: %s | Сохранение: %s",
                target.Name, target.UserId, tostring(target:GetAttribute("Clicks") or 0),
                tostring(target:GetAttribute("Rebirths") or 0),
                tostring(target:GetAttribute("SavingEnabled") == true)))
        else
            if target == player or isAdmin(target) then
                respond(player, "Нельзя исключить себя или другого администратора")
                return
            end
            audit(player, "kick", raw)
            respond(player, "Игрок исключён из текущего сервера")
            target:Kick("GROWLIVO: исключён администратором сервера")
        end
    elseif command == "Announce" then
        if typeof(raw) ~= "string" or #raw < 1 or #raw > 160 then
            respond(player, "Объявление: от 1 до 160 байт UTF-8")
            return
        end
        -- Roblox requires filtering even for privileged player-authored text.
        local ok, safe = pcall(function()
            local result = TextService:FilterStringAsync(raw, player.UserId)
            return result:GetNonChatStringForBroadcastAsync()
        end)
        if not ok or typeof(safe) ~= "string" or safe == "" then
            respond(player, "Объявление не отправлено: ошибка фильтрации")
            return
        end
        audit(player, "announce", "server")
        notice:FireAllClients(safe)
        respond(player, "Объявление отправлено игрокам этого сервера")
    end
end)
Players.PlayerRemoving:Connect(function(player)
    lastRequest[player] = nil
end)
print("[GROWLIVO] Admin commands loaded (configured admins: " .. tostring(#Config.AdminUserIds) .. ")")
]==]},
    {name="GrowlivoAdminUI", className="LocalScript", target="StarterPlayerScripts", source=[==[-- GROWLIVO / Admin utilities + filtered server notices / Alpha 0.9.14
-- StarterPlayer > StarterPlayerScripts > GrowlivoAdminUI [LocalScript]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("GROWLIVO_Remotes")
local action = remotes:WaitForChild("AdminAction")
local reply = remotes:WaitForChild("AdminReply")
local notice = remotes:WaitForChild("ServerNotice")
local gui = Instance.new("ScreenGui")
gui.Name = "GROWLIVO_AdminUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local GOLD = Color3.fromRGB(255, 204, 73)
local WHITE = Color3.fromRGB(235, 247, 255)
local BLUE = Color3.fromRGB(56, 206, 255)
local PANEL = Color3.fromRGB(16, 31, 54)
local function style(ui)
    ui.BorderSizePixel = 0
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = ui
end
local function text(parent, message, size)
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Text = message
    t.TextWrapped = true
    t.TextColor3 = WHITE
    t.Font = Enum.Font.GothamBold
    t.TextSize = size or 15
    t.Parent = parent
    return t
end
local function button(parent, caption)
    local b = Instance.new("TextButton")
    b.Text = caption
    b.Font = Enum.Font.GothamBold
    b.TextSize = 15
    b.TextColor3 = PANEL
    b.BackgroundColor3 = GOLD
    b.Parent = parent
    style(b)
    return b
end
local opener = button(gui, "🛡 АДМИН")
opener.AnchorPoint = Vector2.new(1, 1)
opener.Position = UDim2.new(1, -12, 1, -140)
opener.Size = UDim2.fromOffset(123, 42)
opener.Visible = false
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.86, 0, 0, 470)
panel.BackgroundColor3 = PANEL
panel.Visible = false
panel.Parent = gui
style(panel)
local constraint = Instance.new("UISizeConstraint")
constraint.MaxSize = Vector2.new(440, 510)
constraint.MinSize = Vector2.new(270, 320)
constraint.Parent = panel
local head = text(panel, "🛡 ПАНЕЛЬ АДМИНИСТРАТОРА", 18)
head.Position = UDim2.fromOffset(12, 10)
head.Size = UDim2.new(1, -60, 0, 33)
local close = button(panel, "✕")
close.Position = UDim2.new(1, -50, 0, 9)
close.Size = UDim2.fromOffset(37, 36)
local field = Instance.new("TextBox")
field.Name = "TargetUserId"
field.PlaceholderText = "UserId игрока в этом сервере"
field.Text = ""
field.ClearTextOnFocus = false
field.TextSize = 15
field.Font = Enum.Font.Gotham
field.BackgroundColor3 = Color3.fromRGB(37, 62, 91)
field.TextColor3 = WHITE
field.PlaceholderColor3 = Color3.fromRGB(172, 192, 206)
field.Position = UDim2.fromOffset(12, 55)
field.Size = UDim2.new(1, -24, 0, 38)
field.Parent = panel
style(field)
local inspect = button(panel, "ПРОВЕРИТЬ")
inspect.Position = UDim2.fromOffset(12, 102)
inspect.Size = UDim2.new(0.5, -18, 0, 37)
local kick = button(panel, "ИСКЛЮЧИТЬ")
kick.BackgroundColor3 = BLUE
kick.Position = UDim2.new(0.5, 6, 0, 102)
kick.Size = UDim2.new(0.5, -18, 0, 37)
local announcement = Instance.new("TextBox")
announcement.Name = "Announcement"
announcement.PlaceholderText = "Текст объявления (до 160 байт)"
announcement.Text = ""
announcement.ClearTextOnFocus = false
announcement.MultiLine = true
announcement.TextWrapped = true
announcement.TextSize = 14
announcement.Font = Enum.Font.Gotham
announcement.TextColor3 = WHITE
announcement.BackgroundColor3 = Color3.fromRGB(37, 62, 91)
announcement.Position = UDim2.fromOffset(12, 151)
announcement.Size = UDim2.new(1, -24, 0, 64)
announcement.Parent = panel
style(announcement)
local announce = button(panel, "ОТПРАВИТЬ ОБЪЯВЛЕНИЕ")
announce.Position = UDim2.fromOffset(12, 223)
announce.Size = UDim2.new(1, -24, 0, 39)
local server = button(panel, "ДАННЫЕ О СЕРВЕРЕ")
server.BackgroundColor3 = BLUE
server.Position = UDim2.fromOffset(12, 270)
server.Size = UDim2.new(1, -24, 0, 34)
local diagnostics = button(panel, "ДИАГНОСТИКА СОХРАНЕНИЙ")
diagnostics.BackgroundColor3 = BLUE
diagnostics.Position = UDim2.fromOffset(12, 311)
diagnostics.Size = UDim2.new(1, -24, 0, 34)
local telemetry = button(panel, "ИГРОВАЯ СТАТИСТИКА")
telemetry.BackgroundColor3 = BLUE
telemetry.Position = UDim2.fromOffset(12, 352)
telemetry.Size = UDim2.new(1, -24, 0, 34)
local result = text(panel, "Команды доступны только указанным UserId", 12)
result.Position = UDim2.fromOffset(12, 396)
result.Size = UDim2.new(1, -24, 0, 67)
local function updateAdmin()
    local allowed = player:GetAttribute("GrowlivoAdmin") == true
    opener.Visible = allowed
    if not allowed then panel.Visible = false end
end
player:GetAttributeChangedSignal("GrowlivoAdmin"):Connect(updateAdmin)
updateAdmin()
local function targetNumber()
    local id = tonumber(field.Text)
    if not id or id < 1 or id ~= math.floor(id) then
        result.Text = "Введите числовой UserId"
        return nil
    end
    return id
end
opener.Activated:Connect(function() panel.Visible = not panel.Visible end)
close.Activated:Connect(function() panel.Visible = false end)
inspect.Activated:Connect(function()
    local target = targetNumber()
    if target then action:FireServer("Inspect", target) end
end)
kick.Activated:Connect(function()
    local target = targetNumber()
    if target then action:FireServer("Kick", target) end
end)
announce.Activated:Connect(function() action:FireServer("Announce", announcement.Text) end)
server.Activated:Connect(function() action:FireServer("ServerInfo") end)
diagnostics.Activated:Connect(function() action:FireServer("Diagnostics") end)
telemetry.Activated:Connect(function() action:FireServer("Telemetry") end)
reply.OnClientEvent:Connect(function(message) result.Text = tostring(message) end)
local notification = Instance.new("Frame")
notification.Name = "AnnouncementBanner"
notification.AnchorPoint = Vector2.new(0.5, 0)
notification.Position = UDim2.new(0.5, 0, 0, 48)
notification.Size = UDim2.new(0.9, 0, 0, 74)
notification.BackgroundColor3 = PANEL
notification.Visible = false
notification.Parent = gui
style(notification)
local limitNotice = Instance.new("UISizeConstraint")
limitNotice.MaxSize = Vector2.new(520, 120)
limitNotice.Parent = notification
local caption = text(notification, "", 16)
caption.Size = UDim2.new(1, -16, 1, -12)
caption.Position = UDim2.fromOffset(8, 6)
local noticeNonce = 0
notice.OnClientEvent:Connect(function(filtered)
    if typeof(filtered) ~= "string" then return end
    noticeNonce += 1
    local nonce = noticeNonce
    caption.Text = "📢 GROWLIVO: " .. filtered
    notification.Visible = true
    task.delay(8, function()
        if nonce == noticeNonce then notification.Visible = false end
    end)
end)
]==]},
    {name="GrowlivoEventUI", className="LocalScript", target="StarterPlayerScripts", source=[==[-- GROWLIVO / UTC Starfall event HUD / Alpha 0.9.14
-- StarterPlayer > StarterPlayerScripts > GrowlivoEventUI [LocalScript]
-- Displays only state supplied by the server. Does not grant rewards or modify currency.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("GROWLIVO_Remotes")
local action = remotes:WaitForChild("Action")
local eventState = remotes:WaitForChild("EventState")
local GOLD = Color3.fromRGB(255, 207, 77)
local SKY = Color3.fromRGB(73, 206, 255)
local NAVY = Color3.fromRGB(17, 32, 57)
local DARK = Color3.fromRGB(9, 19, 37)
local WHITE = Color3.fromRGB(242, 248, 255)
local MUTED = Color3.fromRGB(170, 193, 216)
local gui = Instance.new("ScreenGui")
gui.Name = "GROWLIVO_Starfall"
gui.ResetOnSpawn = false
gui.DisplayOrder = 11
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
local function round(frame, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 12)
    corner.Parent = frame
end
local function label(parent, caption, size, color)
    local result = Instance.new("TextLabel")
    result.Text = caption
    result.BackgroundTransparency = 1
    result.Font = Enum.Font.GothamBold
    result.TextSize = size
    result.TextWrapped = true
    result.TextColor3 = color or WHITE
    result.Parent = parent
    return result
end
local function button(parent, text, background)
    local result = Instance.new("TextButton")
    result.Text = text
    result.TextWrapped = true
    result.Font = Enum.Font.GothamBold
    result.TextColor3 = DARK
    result.TextSize = 14
    result.BackgroundColor3 = background or GOLD
    result.BorderSizePixel = 0
    result.Parent = parent
    round(result, 12)
    return result
end
local opener = button(gui, "✦ СОБЫТИЕ", SKY)
opener.Name = "StarfallButton"
opener.Size = UDim2.fromOffset(155, 43)
opener.Visible = false

local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 0.36
backdrop.Active = true
backdrop.Visible = false
backdrop.Parent = gui
local panel = Instance.new("Frame")
panel.Name = "StarfallPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(1, -24, 0, 345)
panel.BackgroundColor3 = NAVY
panel.BorderSizePixel = 0
panel.Parent = backdrop
round(panel, 18)
local constraint = Instance.new("UISizeConstraint")
constraint.MaxSize = Vector2.new(465, 365)
constraint.MinSize = Vector2.new(255, 265)
constraint.Parent = panel
local panelScale = Instance.new("UIScale")
panelScale.Scale = 1
panelScale.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = GOLD
stroke.Thickness = 2
stroke.Parent = panel
local title = label(panel, "✦ ЗВЁЗДНЫЙ ДОЖДЬ", 21, GOLD)
title.Position = UDim2.fromOffset(15, 13)
title.Size = UDim2.new(1, -70, 0, 40)
local close = button(panel, "✕", GOLD)
close.Position = UDim2.new(1, -52, 0, 12)
close.Size = UDim2.fromOffset(38, 36)
local description = label(panel, "", 14, WHITE)
description.Position = UDim2.fromOffset(17, 63)
description.Size = UDim2.new(1, -34, 0, 66)
local timerLabel = label(panel, "", 18, SKY)
timerLabel.Position = UDim2.fromOffset(17, 133)
timerLabel.Size = UDim2.new(1, -34, 0, 38)
local barBack = Instance.new("Frame")
barBack.Position = UDim2.fromOffset(17, 185)
barBack.Size = UDim2.new(1, -34, 0, 19)
barBack.BackgroundColor3 = Color3.fromRGB(39, 58, 80)
barBack.BorderSizePixel = 0
barBack.Parent = panel
round(barBack, 8)
local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = GOLD
barFill.BorderSizePixel = 0
barFill.Parent = barBack
round(barFill, 8)
local progressLabel = label(panel, "", 15, WHITE)
progressLabel.Position = UDim2.fromOffset(17, 214)
progressLabel.Size = UDim2.new(1, -34, 0, 32)
local claim = button(panel, "ЗАБРАТЬ НАГРАДУ", GOLD)
claim.Position = UDim2.fromOffset(17, 261)
claim.Size = UDim2.new(1, -34, 0, 48)
local foot = label(panel, "Прогресс события сбрасывается в 00:00 UTC", 11, MUTED)
foot.Position = UDim2.fromOffset(17, 317)
foot.Size = UDim2.new(1, -34, 0, 19)

local latest = nil
local receivedAt = 0
local function clock(seconds)
    local left = math.max(0, math.floor(seconds))
    return string.format("%02d:%02d", math.floor(left / 60), left % 60)
end
local function draw()
    if not latest then return end
    local secondsLeft = math.max(0, latest.SecondsLeft - (os.clock() - receivedAt))
    -- Server is authoritative; ask for fresh state when the local estimate expires.
    local active = latest.Active and secondsLeft > 0
    local progress = math.clamp(latest.Progress or 0, 0, latest.Goal or 60)
    local goal = math.max(1, latest.Goal or 60)
    local ready = progress >= goal and not latest.Claimed
    opener.Text = ready and "✦ ЗАБРАТЬ ПРИЗ" or (active and ("✦ БОНУС x" .. tostring(latest.Multiplier)) or "✦ СОБЫТИЕ")
    if active then
        description.Text = "Пока идёт событие, каждый принятый сервером клик приносит в "
            .. tostring(latest.Multiplier) .. " раза больше очков!"
        timerLabel.Text = "До окончания: " .. clock(secondsLeft)
    else
        description.Text = "Во время события сделай " .. tostring(goal) .. " кликов и получи награду."
        timerLabel.Text = "До начала: " .. clock(secondsLeft)
    end
    progressLabel.Text = string.format("Прогресс: %d / %d  •  +%d кликов и +%d 💎",
        progress, goal, latest.RewardClicks or 0, latest.RewardGems or 0)
    barFill.Size = UDim2.fromScale(progress / goal, 1)
    claim.Visible = true
    claim.Active = ready
    claim.AutoButtonColor = ready
    claim.BackgroundColor3 = ready and GOLD or Color3.fromRGB(90, 108, 126)
    claim.Text = latest.Claimed and "НАГРАДА ПОЛУЧЕНА" or (ready and "ЗАБРАТЬ НАГРАДУ" or "ПРОДОЛЖАЙ ИГРАТЬ")
end
local function request()
    if player:GetAttribute("DataReady") == true then
        action:FireServer("GetEvent")
    end
end
eventState.OnClientEvent:Connect(function(payload)
    if typeof(payload) ~= "table" then return end
    if typeof(payload.Active) ~= "boolean" or typeof(payload.SecondsLeft) ~= "number"
        or typeof(payload.Goal) ~= "number" or typeof(payload.Progress) ~= "number"
        or typeof(payload.Claimed) ~= "boolean" then return end
    if payload.Goal < 1 or payload.Goal > 100000 or payload.SecondsLeft < 0 then return end
    latest = payload
    receivedAt = os.clock()
    -- The layout owns opener visibility: don't resurrect it while the
    -- compact landscape navigation menu is closed.
    draw()
end)
opener.Activated:Connect(function()
    backdrop.Visible = not backdrop.Visible
    if backdrop.Visible then request() end
    draw()
end)
close.Activated:Connect(function() backdrop.Visible = false end)
claim.Activated:Connect(function()
    if latest and latest.Progress >= latest.Goal and not latest.Claimed then
        claim.Active = false
        action:FireServer("ClaimEvent")
        task.delay(0.8, request)
    end
end)
local function compactNavigationVisible(w, h)
    return w >= 700 or h >= 500 or player:GetAttribute("CompactMenuOpen") == true
end
local function layout()
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1100, 720)
    local w, h = viewport.X, viewport.Y
    opener.Visible = compactNavigationVisible(w, h)
    panelScale.Scale = h < 395 and math.clamp((h - 25) / 345, 0.67, 1) or 1
    if w < 700 then
        local navY = h < 650 and 163 or 187
        opener.Position = UDim2.fromOffset(12, navY + 147)
        opener.Size = UDim2.fromOffset(math.min(155, math.max(115, w / 2 - 24)), 40)
        panel.Size = UDim2.new(1, -24, 0, 345)
        title.TextSize = 17
    else
        opener.Position = UDim2.fromOffset(18, 494)
        opener.Size = UDim2.fromOffset(185, 45)
        panel.Size = UDim2.fromOffset(465, 345)
        title.TextSize = 21
    end
end
layout()
local viewportConnection
local function attachCamera()
    if viewportConnection then viewportConnection:Disconnect() end
    viewportConnection = nil
    layout()
    local camera = workspace.CurrentCamera
    if camera then
        viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
    end
end
attachCamera()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(attachCamera)
player:GetAttributeChangedSignal("DataReady"):Connect(request)
if player:GetAttribute("DataReady") == true then request() end
-- Render locally at one Hz and resync after clock boundary/server packet loss.
task.spawn(function()
    local tickCount = 0
    while gui.Parent do
        task.wait(1)
        tickCount += 1
        if latest then draw() end
        if tickCount % 25 == 0 or (latest and os.clock() - receivedAt > latest.SecondsLeft) then
            request()
        end
    end
end)

player:GetAttributeChangedSignal("CompactMenuOpen"):Connect(layout)
]==]},
    {name="GrowlivoSoundFX", className="LocalScript", target="StarterPlayerScripts", source=[==[-- GROWLIVO / Optional local UI sounds / Alpha 0.9.14
-- StarterPlayer > StarterPlayerScripts > GrowlivoSoundFX [LocalScript]
-- Uses bundled Roblox UI cues. Failed/unavailable assets only produce silence.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local player = Players.LocalPlayer
local remotes = RS:WaitForChild("GROWLIVO_Remotes")
local visuals = remotes:WaitForChild("VisualEvent")
local feedback = remotes:WaitForChild("Feedback")
local playerGui = player:WaitForChild("PlayerGui")
local hud = playerGui:WaitForChild("GROWLIVO_HUD")
local tapFlash = hud:WaitForChild("TapFlash")

-- Short cues only. No copyrighted music, autoplay ambience or external audio IDs.
local cues = {
    Tap = {Id = "rbxasset://sounds/button.wav", Volume = 0.14, Speed = 1.3},
    Reward = {Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.32, Speed = 1},
    Hatch = {Id = "rbxasset://sounds/switch.wav", Volume = 0.24, Speed = 1.05},
    Error = {Id = "rbxasset://sounds/snap.wav", Volume = 0.12, Speed = 0.9},
}
local folder = Instance.new("Folder")
folder.Name = "GROWLIVO_LocalSounds"
folder.Parent = SoundService
local sounds = {}
for name, info in pairs(cues) do
    local cue = Instance.new("Sound")
    cue.Name = name
    cue.SoundId = info.Id
    cue.Volume = info.Volume
    cue.PlaybackSpeed = info.Speed
    cue.Looped = false
    cue.Parent = folder
    sounds[name] = cue
end
local lastPlayed = {}
local function play(name, cooldown)
    if player:GetAttribute("SettingSounds") == false then return end
    local now = os.clock()
    if now - (lastPlayed[name] or -100) < (cooldown or 0.1) then return end
    lastPlayed[name] = now
    local cue = sounds[name]
    if cue then
        cue.TimePosition = 0
        cue:Play()
    end
end
-- The main HUD already rate-limits manual taps before firing TapFlash.
tapFlash.Event:Connect(function()
    play("Tap", 0.12)
end)
visuals.OnClientEvent:Connect(function(data)
    if typeof(data) ~= "table" then return end
    if data.Type == "Hatch" then
        play("Hatch", 0.25)
    elseif data.Type == "Fusion" or data.Type == "Rebirth" or data.Type == "EventReward"
        or data.Type == "WorldUnlock" or data.Type == "WeeklyReward"
        or data.Type == "TutorialStep" then
        play("Reward", 0.3)
    end
end)
feedback.OnClientEvent:Connect(function(message)
    if typeof(message) ~= "string" then return end
    if string.find(message, "Не хватает", 1, true) or string.find(message, "Недостаточно", 1, true) then
        play("Error", 0.6)
    elseif string.find(message, "Задание выполнено", 1, true)
        or string.find(message, "Достижение!", 1, true) then
        play("Reward", 0.3)
    end
end)
]==]},
    {name="GrowlivoSessionUI", className="LocalScript", target="StarterPlayerScripts", source=[==[-- GROWLIVO / Persistent save-state indicator / Alpha 0.9.17
-- StarterPlayerScripts / LocalScript. Visual only; no currency operations.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "GROWLIVO_SessionUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 80
-- A recoverable save failure blocks input until a confirmed retry.
gui.Parent = player:WaitForChild("PlayerGui")
local backdrop = Instance.new("Frame")
backdrop.Name = "SaveStatusBackdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.fromRGB(8, 16, 33)
backdrop.BackgroundTransparency = 0.25
backdrop.BorderSizePixel = 0
backdrop.Active = true
backdrop.Parent = gui
local panel = Instance.new("Frame")
panel.Name = "StatusPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(1, -28, 0, 164)
panel.BackgroundColor3 = Color3.fromRGB(18, 34, 64)
panel.BorderSizePixel = 0
panel.Parent = backdrop
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(440, 164)
limit.MinSize = Vector2.new(230, 140)
limit.Parent = panel
local round = Instance.new("UICorner")
round.CornerRadius = UDim.new(0, 16)
round.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 205, 83)
stroke.Thickness = 2
stroke.Parent = panel
local heading = Instance.new("TextLabel")
heading.Name = "Heading"
heading.Position = UDim2.fromOffset(14, 14)
heading.Size = UDim2.new(1, -28, 0, 49)
heading.TextColor3 = Color3.fromRGB(255, 209, 84)
heading.BackgroundTransparency = 1
heading.Font = Enum.Font.GothamBold
heading.TextSize = 21
heading.TextWrapped = true
heading.Parent = panel
local details = Instance.new("TextLabel")
details.Name = "Details"
details.Position = UDim2.fromOffset(18, 66)
details.Size = UDim2.new(1, -36, 0, 80)
details.TextColor3 = Color3.fromRGB(232, 244, 255)
details.BackgroundTransparency = 1
details.Font = Enum.Font.Gotham
details.TextSize = 15
details.TextWrapped = true
details.Parent = panel
-- Compact persistence acknowledgement, shown only when the profile is
-- usable. Status Ready is not the same as "latest actions were saved".
local saveBadge = Instance.new("TextLabel")
saveBadge.Name = "PersistenceBadge"
saveBadge.AnchorPoint = Vector2.new(1, 0)
saveBadge.Position = UDim2.new(1, -10, 0, 46)
saveBadge.Size = UDim2.fromOffset(188, 31)
saveBadge.BackgroundColor3 = Color3.fromRGB(18, 34, 64)
saveBadge.BackgroundTransparency = 0.12
saveBadge.TextColor3 = Color3.fromRGB(232, 244, 255)
saveBadge.Font = Enum.Font.GothamBold
saveBadge.TextSize = 12
saveBadge.ZIndex = 5
saveBadge.Visible = false
saveBadge.Parent = gui
local badgeCorner = Instance.new("UICorner")
badgeCorner.CornerRadius = UDim.new(0, 9)
badgeCorner.Parent = saveBadge
local function refresh()
    local status = player:GetAttribute("DataStatus") or "Loading"
    local ready = player:GetAttribute("DataReady") == true
    backdrop.Visible = status ~= "Ready" or not ready
    saveBadge.Visible = status == "Ready" and ready
    if saveBadge.Visible then
        if player:GetAttribute("DataMode") == "StudioTemporary" then
            saveBadge.Text = "⚠ ТЕСТ · без сохранения"
            saveBadge.TextColor3 = Color3.fromRGB(255, 207, 95)
        elseif player:GetAttribute("UnsavedChanges") == true then
            saveBadge.Text = "◷ Ожидает сохранения"
            saveBadge.TextColor3 = Color3.fromRGB(255, 207, 95)
        elseif (player:GetAttribute("LastConfirmedSaveAt") or 0) > 0 then
            saveBadge.Text = "✓ Сохранено сервером"
            saveBadge.TextColor3 = Color3.fromRGB(135, 239, 191)
        else
            -- Successfully read from DataStore; there was no write this session.
            saveBadge.Text = "✓ Профиль загружен"
            saveBadge.TextColor3 = Color3.fromRGB(135, 239, 191)
        end
    end
    if status == "Closing" then
        heading.Text = "👑 ЗАВЕРШЕНИЕ СЕССИИ"
        details.Text = "Игра завершает сохранение и освобождает профиль. Новые действия временно недоступны."
    elseif status == "SaveRetry" then
        heading.Text = "⚠ ПРОБЛЕМА СОХРАНЕНИЯ"
        details.Text = "Действия приостановлены для защиты прогресса. Повторные попытки выполняются с увеличением интервала (до примерно минуты). Выход до восстановления может привести к потере последних действий."
    elseif status == "Conflict" then
        heading.Text = "⚠ КОНФЛИКТ ПРОФИЛЯ"
        details.Text = "Данные открыты другим сервером. Подключитесь повторно позже."
    elseif status == "Unavailable" then
        heading.Text = "⚠ ПРОГРЕСС НЕДОСТУПЕН"
        details.Text = "Загрузка не удалась. Вход отменён, чтобы не потерять достижения."
    else
        heading.Text = "👑 GROWLIVO"
        details.Text = "Безопасная загрузка игрового прогресса…"
    end
end
player:GetAttributeChangedSignal("DataMode"):Connect(refresh)
player:GetAttributeChangedSignal("DataStatus"):Connect(refresh)
player:GetAttributeChangedSignal("DataReady"):Connect(refresh)
player:GetAttributeChangedSignal("UnsavedChanges"):Connect(refresh)
player:GetAttributeChangedSignal("LastConfirmedSaveAt"):Connect(refresh)
refresh()
]==]},
    {name="GrowlivoRuneUI", className="LocalScript", target="StarterPlayerScripts", source=[==[-- GROWLIVO / Rune compass & expedition HUD / Alpha 0.9.22
-- Passive client UI; all eligibility, world selection, and rune rewards remain server-authoritative.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("GrowlivoConfig"))
local trial = Config.RuneTrial
local gui = Instance.new("ScreenGui")
gui.Name = "GROWLIVO_RuneUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 3
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local NAVY = Color3.fromRGB(15, 31, 54)
local TEAL = Color3.fromRGB(108, 237, 206)
local PALE = Color3.fromRGB(236, 250, 255)
local MUTED = Color3.fromRGB(166, 190, 207)
local panel = Instance.new("Frame")
panel.Name = "RuneStatus"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.BackgroundColor3 = NAVY
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel
local rim = Instance.new("UIStroke")
rim.Color = TEAL
rim.Thickness = 1
rim.Parent = panel

local heading = Instance.new("TextLabel")
heading.Name = "Heading"
heading.BackgroundTransparency = 1
heading.Font = Enum.Font.GothamBold
heading.TextSize = 14
heading.TextColor3 = PALE
heading.TextXAlignment = Enum.TextXAlignment.Left
heading.Position = UDim2.fromOffset(11, 5)
heading.Size = UDim2.new(1, -42, 0, 20)
heading.Parent = panel

local toggle = Instance.new("TextButton")
toggle.Name = "ToggleCompass"
toggle.AnchorPoint = Vector2.new(1, 0)
toggle.Position = UDim2.new(1, -5, 0, 5)
toggle.Size = UDim2.fromOffset(31, 25)
toggle.BackgroundTransparency = 1
toggle.TextColor3 = TEAL
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 19
toggle.Parent = panel

local details = Instance.new("TextLabel")
details.Name = "RuneProgress"
details.BackgroundTransparency = 1
details.Font = Enum.Font.GothamMedium
details.TextSize = 13
details.TextColor3 = MUTED
details.TextXAlignment = Enum.TextXAlignment.Left
details.TextWrapped = true
details.Position = UDim2.fromOffset(11, 28)
details.Size = UDim2.new(1, -22, 0, 41)
details.Parent = panel

-- World-space marker is a client-only BillboardGui; it never modifies the shrine.
local marker = Instance.new("BillboardGui")
marker.Name = "RuneWaypoint"
marker.Size = UDim2.fromOffset(148, 41)
marker.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
marker.AlwaysOnTop = true
marker.MaxDistance = 120
marker.Enabled = false
marker.Parent = gui
local markerLabel = Instance.new("TextLabel")
markerLabel.Size = UDim2.fromScale(1, 1)
markerLabel.BackgroundColor3 = NAVY
markerLabel.BackgroundTransparency = 0.1
markerLabel.Font = Enum.Font.GothamBold
markerLabel.TextSize = 13
markerLabel.TextColor3 = TEAL
markerLabel.TextStrokeTransparency = 0.65
markerLabel.Parent = marker
local markerCorner = Instance.new("UICorner")
markerCorner.CornerRadius = UDim.new(0, 9)
markerCorner.Parent = markerLabel

local expanded = true
local viewHeight = 600
local viewWidth = 900
local function resize()
    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(900, 600)
    viewWidth, viewHeight = viewport.X, viewport.Y
    local narrow = viewWidth < 500
    local width = math.min(narrow and 246 or 295, math.max(175, viewWidth - 20))
    panel.Size = UDim2.fromOffset(width, expanded and 73 or 34)
    -- Keep clear of the bottom-center click button, including on shorter screens.
    panel.Position = UDim2.new(0.5, 0, 1, viewHeight < 550 and -191 or -235)
    details.Visible = expanded
    toggle.Text = expanded and "⌃" or "⌄"
end

toggle.Activated:Connect(function()
    expanded = not expanded
    resize()
end)

local function wasCollected(mask, index)
    return math.floor(mask / (2 ^ (index - 1))) % 2 == 1
end

local shrineGroup = nil
local shrineMap = {}
local function findShrines()
    local model = workspace:FindFirstChild("GROWLIVO_World")
    local group = model and model:FindFirstChild("09_RUNE_EXPEDITIONS")
    if group == shrineGroup then return end
    shrineGroup = group
    table.clear(shrineMap)
    if not group then return end
    for _, pedestal in ipairs(group:GetChildren()) do
        if pedestal:IsA("BasePart") and pedestal.Name == "RunePedestal" then
            local id, index = pedestal:GetAttribute("RuneWorld"), pedestal:GetAttribute("RuneIndex")
            if type(id) == "string" and type(index) == "number" and index >= 1 and index <= trial.Required then
                shrineMap[id] = shrineMap[id] or {}
                shrineMap[id][index] = pedestal
            end
        end
    end
end

local function update()
    if player:GetAttribute("DataReady") ~= true then
        panel.Visible = false
        marker.Enabled = false
        marker.Adornee = nil
        return
    end
    local worldId = player:GetAttribute("World")
    local worldConfig = Config.FindWorld(worldId)
    if not worldConfig then
        panel.Visible = false
        marker.Enabled = false
        marker.Adornee = nil
        return
    end
    panel.Visible = true
    local now = workspace:GetServerTimeNow()
    local boostUntil = tonumber(player:GetAttribute("RuneBoostUntil")) or 0
    local cooldownUntil = tonumber(player:GetAttribute("RuneCooldownUntil")) or 0
    local boostMultiplier = tonumber(player:GetAttribute("RuneBoostMultiplier")) or 1
    local count = math.clamp(tonumber(player:GetAttribute("RuneCount")) or 0, 0, trial.Required)
    local mask = math.clamp(math.floor(tonumber(player:GetAttribute("RuneMask")) or 0), 0, 2 ^ trial.Required - 1)
    local boostActive = boostUntil > now and boostMultiplier > 1
    local cooling = cooldownUntil > now
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    findShrines()
    local target, nearestDistance, nearestIndex
    if not cooling and root then
        for index = 1, trial.Required do
            local pedestal = shrineMap[worldId] and shrineMap[worldId][index]
            if pedestal and pedestal.Parent and not wasCollected(mask, index) then
                local distance = (root.Position - pedestal.Position).Magnitude
                if not nearestDistance or distance < nearestDistance then
                    target, nearestIndex, nearestDistance = pedestal, index, distance
                end
            end
        end
    end
    marker.Enabled = target ~= nil and expanded and player:GetAttribute("SettingEffects") ~= false
    marker.Adornee = marker.Enabled and target or nil
    if marker.Enabled then
        markerLabel.Text = string.format("◆ РУНА %d • %d м", nearestIndex, math.floor(nearestDistance + 0.5))
    end
    if boostActive then
        heading.Text = string.format("✦ РУНЫ ×%d • %d сек.", boostMultiplier, math.ceil(boostUntil - now))
    elseif cooling then
        heading.Text = "◆ Руны • отдых " .. math.ceil(cooldownUntil - now) .. " сек."
    else
        heading.Text = "◆ Руны • " .. worldConfig.Name
    end
    local icons = {}
    for index = 1, trial.Required do
        table.insert(icons, wasCollected(mask, index) and "✓" or "◇")
    end
    local indicator = table.concat(icons, "   ")
    if boostActive then
        details.Text = indicator .. "  •  бонус активен\nМир: " .. worldConfig.Name
    elseif cooling then
        details.Text = indicator .. "  •  испытание завершено\nСледующая попытка после восстановления"
    elseif nearestDistance then
        details.Text = string.format("%s  •  собрано %d/%d\nК руне %d: %d м (клавиша E)", indicator, count, trial.Required, nearestIndex, math.floor(nearestDistance + 0.5))
    else
        details.Text = indicator .. "  •  исследуй остров\nАктивируй три разные руны"
    end
end

for _, name in ipairs({"RuneMask", "RuneCount", "RuneBoostUntil", "RuneBoostMultiplier", "RuneCooldownUntil", "DataReady", "World", "SettingEffects"}) do
    player:GetAttributeChangedSignal(name):Connect(update)
end
resize()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(resize)
-- Low-cost refresh: no RenderStepped loop and only nine possible shrines.
task.spawn(function()
    local lastSizeCheck = 0
    while gui.Parent do
        update()
        if os.clock() - lastSizeCheck > 2 then
            resize()
            lastSizeCheck = os.clock()
        end
        task.wait(0.5)
    end
end)
]==]},
    {name="GrowlivoChestUI", className="LocalScript", target="StarterPlayerScripts", source=[==[-- GROWLIVO / Daily chest compass / Alpha 0.9.25
-- StarterPlayerScripts > GrowlivoChestUI [LocalScript]
-- Client-only navigation. All rewards, distances and claims are verified by the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("GrowlivoConfig"))
local playerGui = player:WaitForChild("PlayerGui")

local previous = playerGui:FindFirstChild("GROWLIVO_ChestUI")
if previous then previous:Destroy() end
local oldWaypoint = playerGui:FindFirstChild("GROWLIVO_ChestWaypoint")
if oldWaypoint then oldWaypoint:Destroy() end

local GOLD = Color3.fromRGB(255, 219, 114)
local MUTED = Color3.fromRGB(185, 204, 220)
local NAVY = Color3.fromRGB(16, 32, 57)
local gui = Instance.new("ScreenGui")
gui.Name = "GROWLIVO_ChestUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 2
gui.IgnoreGuiInset = false
gui.Parent = playerGui

local function label(name, y, height, color)
    local item = Instance.new("TextLabel")
    item.Name = name
    item.AnchorPoint = Vector2.new(0.5, 0)
    item.Position = UDim2.new(0.5, 0, 0, y)
    item.Size = UDim2.fromOffset(315, height)
    item.BackgroundColor3 = NAVY
    item.BackgroundTransparency = 0.15
    item.BorderSizePixel = 0
    item.TextColor3 = color
    item.TextSize = 13
    item.TextWrapped = true
    item.Font = Enum.Font.GothamBold
    item.Visible = false
    item.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = item
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = 1
    stroke.Transparency = 0.45
    stroke.Parent = item
    return item
end

local panel = label("DailyChestStatus", 84, 37, GOLD)
local navigation = label("ChestDirection", 124, 29, MUTED)

-- The marker is parented to PlayerGui, not Workspace: no shared objects are
-- changed and another player cannot see our personal navigation.
local marker = Instance.new("BillboardGui")
marker.Name = "GROWLIVO_ChestWaypoint"
marker.Size = UDim2.fromOffset(180, 42)
marker.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
marker.AlwaysOnTop = true
marker.MaxDistance = 600
marker.Enabled = false
marker.Parent = playerGui
local markerText = Instance.new("TextLabel")
markerText.Size = UDim2.fromScale(1, 1)
markerText.BackgroundColor3 = NAVY
markerText.BackgroundTransparency = 0.16
markerText.BorderSizePixel = 0
markerText.TextColor3 = GOLD
markerText.TextSize = 13
markerText.Font = Enum.Font.GothamBold
markerText.TextWrapped = true
markerText.Parent = marker
local markerCorner = Instance.new("UICorner")
markerCorner.CornerRadius = UDim.new(0, 10)
markerCorner.Parent = markerText

local function claimedToday()
    if player:GetAttribute("ChestClaimed") ~= true then return false end
    local day = player:GetAttribute("ChestDay")
    return typeof(day) == "string" and day >= os.date("!%Y-%m-%d")
end

local function findChest(worldId)
    local world = workspace:FindFirstChild("GROWLIVO_World")
    local group = world and world:FindFirstChild("11_WORLD_CHESTS")
    if not group then return nil end
    for _, item in ipairs(group:GetChildren()) do
        if item:IsA("BasePart") and item.Name == "WorldTreasureChest"
            and item:GetAttribute("ChestWorld") == worldId then
            return item
        end
    end
    return nil
end

local function update()
    local worldId = player:GetAttribute("World")
    local reward = Config.WorldChests[worldId]
    local ready = player:GetAttribute("DataReady") == true and reward ~= nil
    panel.Visible = ready
    navigation.Visible = false
    marker.Enabled = false
    marker.Adornee = nil
    if not ready then return end

    local camera = workspace.CurrentCamera
    local width = camera and camera.ViewportSize.X or 900
    width = math.min(315, math.max(205, width - 24))
    panel.Size = UDim2.fromOffset(width, 37)
    navigation.Size = UDim2.fromOffset(width, 29)

    if claimedToday() then
        panel.Text = "🎁 Сундук дня получен • обновление в 00:00 UTC"
        panel.TextColor3 = MUTED
        return
    end

    panel.Text = "🎁 Сундук: +" .. reward.Clicks .. " кликов, +" .. reward.Gems .. " 💎"
    panel.TextColor3 = GOLD
    navigation.Visible = true

    local chest = findChest(worldId)
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not chest or not root then
        navigation.Text = "📍 Сундук загружается • проверь локацию"
        return
    end

    local distance = (root.Position - chest.Position).Magnitude
    local studs = math.floor(distance + 0.5)
    if distance <= 12 then
        navigation.Text = "✨ Ты у сундука • взаимодействуй с ним"
    else
        navigation.Text = "📍 До сундука: " .. studs .. " студ. • следуй за меткой"
        marker.Adornee = chest
        marker.Enabled = true
        markerText.Text = "🎁 СУНДУК ДНЯ\n" .. studs .. " студ."
    end
end

for _, attribute in ipairs({"DataReady", "World", "ChestDay", "ChestClaimed"}) do
    player:GetAttributeChangedSignal(attribute):Connect(update)
end
player.CharacterAdded:Connect(update)
task.spawn(function()
    while gui.Parent do
        update()
        task.wait(0.75)
    end
    marker:Destroy()
end)
update()
]==]},
}
-- Preflight: validate all names/classes before changing existing scripts.
for _, pack in ipairs(packages) do
    local existing = targets[pack.target]:FindFirstChild(pack.name)
    if existing then
        assert(existing:IsA(pack.className), "[GROWLIVO] Wrong class: " .. pack.name)
    end
end
-- Preserve the owner's existing numeric AdminUserIds, not arbitrary old Lua.
-- This setting was previously reset to {} on each version upgrade.
-- A strict digit/comma/whitespace whitelist prevents code injection from Source.
local oldConfig = targets.ReplicatedStorage:FindFirstChild("GrowlivoConfig")
local preservedAdminIds = nil
if oldConfig and oldConfig:IsA("ModuleScript") then
    local oldList = oldConfig.Source:match("Config%.AdminUserIds%s*=%s*(%b{})")
    if oldList then
        local contents = oldList:sub(2, -2)
        if contents:match("^[%d,%s]*$") then
            local cleaned, seen = {}, {}
            for digits in contents:gmatch("%d+") do
                local numeric = tonumber(digits)
                if numeric and numeric >= 1 and numeric <= 9007199254740991
                    and numeric == math.floor(numeric) and not seen[numeric] then
                    seen[numeric] = true
                    table.insert(cleaned, tostring(numeric))
                end
            end
            if #cleaned <= 20 then
                preservedAdminIds = "{" .. table.concat(cleaned, ", ") .. "}"
            else
                error("[GROWLIVO] Too many admin IDs. Review the existing configuration.")
            end
        else
            error("[GROWLIVO] Cannot safely parse previous AdminUserIds; back up and correct the numeric list before updating.")
        end
    end
end
-- Back up sources in memory and roll back earlier changes on a failed write.
-- This protects Edit mode if a Source assignment fails unexpectedly.
local backups = {}
for _, pack in ipairs(packages) do
    local target = targets[pack.target]
    local existing = target:FindFirstChild(pack.name)
    local object = existing or Instance.new(pack.className)
    object.Name = pack.name
    local backup = {object = object, created = existing == nil,
        source = existing and existing.Source or nil}
    table.insert(backups, backup)
    local ok, err = pcall(function()
        local nextSource = pack.source
        if pack.name == "GrowlivoConfig" and preservedAdminIds ~= nil then
            local replaced, matches = nextSource:gsub("Config%.AdminUserIds%s*=%s*%b{}", function()
                return "Config.AdminUserIds = " .. preservedAdminIds
            end, 1)
            assert(matches == 1, "AdminUserIds setting missing from new config")
            nextSource = replaced
        end
        object.Source = nextSource
        if not existing then object.Parent = target end
    end)
    if not ok then
        for i = #backups, 1, -1 do
            local previous = backups[i]
            if previous.created then
                previous.object:Destroy()
            else
                pcall(function() previous.object.Source = previous.source end)
            end
        end
        error("[GROWLIVO] Installation rolled back at " .. pack.name .. ": " .. tostring(err))
    end
    print("[GROWLIVO] Installed: " .. pack.name)
end

-- Clean legacy GROWLIVO Studio-only diagnostics installed by older Alpha builds.
local obsoleteDiagnostics = {
    {name="GrowlivoStudioChecks", className="Script", target="ServerScriptService"},
    {name="GrowlivoMultiClientChecks", className="Script", target="ServerScriptService"},
    {name="GrowlivoPerformanceHUD", className="LocalScript", target="StarterPlayerScripts"},
    {name="GrowlivoProfileGuardChecks", className="Script", target="ServerScriptService"},
    {name="GrowlivoPersistenceAuditChecks", className="Script", target="ServerScriptService"},
    {name="GrowlivoGameplayChecks", className="Script", target="ServerScriptService"},
    {name="GrowlivoSaveReceiptChecks", className="Script", target="ServerScriptService"},
    {name="GrowlivoSaveReceiptUnitChecks", className="Script", target="ServerScriptService"},
    {name="GrowlivoCalendarChecks", className="Script", target="ServerScriptService"},
    {name="GrowlivoCalendarSafetyChecks", className="Script", target="ServerScriptService"},
    {name="GrowlivoProfileIntegrityChecks", className="Script", target="ServerScriptService"},
}
for _, item in ipairs(obsoleteDiagnostics) do
    local candidate = targets[item.target]:FindFirstChild(item.name)
    if candidate and candidate:IsA(item.className) then
        candidate:Destroy()
        print("[GROWLIVO] Removed old diagnostic: " .. item.name)
    end
end
print("[GROWLIVO] Alpha 0.9.27 CLEAN installed: 24 game scripts. Unpublished Studio = temporary data.")
