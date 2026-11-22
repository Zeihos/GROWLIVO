-- GROWLIVO / Shared economy and progression config / Alpha 0.9.36
local Config = {}
Config.Version = "Alpha 0.9.36"
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
-- Unlockable, session-only automation. One server-priced egg every 12 seconds.
-- Not a persistent setting: the player must opt in again each session.
Config.AutoHatch = {UnlockRebirths = 5, IntervalSeconds = 12}
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
Config.MaxPetId = 2000000000 -- shared client preview / server validation limit
Config.MaxHatchBatch = 3
Config.MaxHatchMaxBatch = 10 -- never accept a client-selected amount
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
-- Safe MAX fusion keeps at least one copy of the SOURCE species across the
-- equipped + unequipped inventory. Protects completed world collections while
-- allowing ordinary FusePets to consume the last copy if explicitly chosen.
-- Shared with the client for a preview; the server always recalculates.
function Config.SafeFusionBatches(inventory, equipped, species)
    if not Config.FusionResult(species) then return 0 end
    if typeof(inventory) ~= "table" or typeof(equipped) ~= "table" then return 0 end
    local equippedIds = {}
    for _, id in ipairs(equipped) do equippedIds[id] = true end
    local available, protectedCopy = 0, false
    for _, pet in ipairs(inventory) do
        if typeof(pet) == "table" and pet.Species == species then
            if equippedIds[pet.Id] then
                protectedCopy = true
            else
                available += 1
            end
        end
    end
    local reserve = protectedCopy and 0 or 1
    return math.floor(math.max(0, available - reserve) / Config.FusionRequired)
end

-- Safe duplicate cleanup protects all equipped pets and one copy of every
-- species still owned. The oldest free instance is kept if none is equipped.
-- A pure preview for the UI; the server always recomputes it from the profile.
function Config.DuplicateReleaseIds(inventory, equipped)
    if typeof(inventory) ~= "table" or typeof(equipped) ~= "table" then return {} end
    local equippedIds, keptSpecies, releaseIds = {}, {}, {}
    for _, id in ipairs(equipped) do equippedIds[id] = true end
    for _, pet in ipairs(inventory) do
        if typeof(pet) == "table" and equippedIds[pet.Id] and Config.FindPet(pet.Species) then
            keptSpecies[pet.Species] = true
        end
    end
    for _, pet in ipairs(inventory) do
        if typeof(pet) == "table" and not equippedIds[pet.Id] and Config.FindPet(pet.Species) then
            if keptSpecies[pet.Species] then
                table.insert(releaseIds, pet.Id)
            else
                keptSpecies[pet.Species] = true
            end
        end
    end
    return releaseIds
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

-- Server-authoritative quote for the maximum affordable hatch batch.
-- The server supplies its own profile balance, pet count and NextPetId.
-- Clients use replicated attributes for a preview only.
function Config.HatchMaxQuote(price, clicks, petCount, nextPetId)
    if typeof(price) ~= "number" or typeof(clicks) ~= "number"
        or typeof(petCount) ~= "number" or typeof(nextPetId) ~= "number"
        or price ~= price or clicks ~= clicks
        or petCount ~= petCount or nextPetId ~= nextPetId
        or price == math.huge or clicks == math.huge
        or petCount == math.huge or nextPetId == math.huge
        or price <= 0 or clicks < 0 or petCount < 0
        or nextPetId < 1 then
        return nil, 0
    end
    local costPerEgg = math.floor(price)
    if costPerEgg < 1 then return nil, 0 end
    local freeInventory = math.max(0, Config.MaxPetInventory - math.floor(petCount))
    local freeIds = math.max(0, Config.MaxPetId - math.floor(nextPetId) + 1)
    local affordable = math.floor(clicks / costPerEgg)
    local count = math.min(Config.MaxHatchMaxBatch, freeInventory, freeIds, affordable)
    if count < 1 then return nil, 0 end
    return costPerEgg * count, count
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
-- A completed world's collection grants a bonus only while every species
-- from that world's egg is CURRENTLY present in the player's inventory.
-- No additional persistent fields are needed: the server owns the inventory.
Config.CollectionRewards = {SkyCrown = 5, CrystalVale = 10, AuroraGrove = 20}
function Config.CollectionBonus(inventory)
    local ownedSpecies = {}
    if typeof(inventory) == "table" then
        for _, entry in ipairs(inventory) do
            if typeof(entry) == "table" and Config.FindPet(entry.Species) then
                ownedSpecies[entry.Species] = true
            end
        end
    end
    local uniqueCount = 0
    for _ in pairs(ownedSpecies) do uniqueCount += 1 end
    local bonus, byWorld = 0, {}
    for _, world in ipairs(Config.Worlds) do
        local egg = Config.Eggs[world.EggId]
        local count = 0
        for _, drop in ipairs(egg.Drops) do
            if ownedSpecies[drop.Species] then count += 1 end
        end
        local complete = count == #egg.Drops
        byWorld[world.Id] = {Count = count, Total = #egg.Drops, Complete = complete}
        if complete then bonus += Config.CollectionRewards[world.Id] or 0 end
    end
    return bonus, uniqueCount, byWorld
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
-- Purchase the maximum affordable number of levels at the usual per-level
-- prices. Server passes its own balance; the client can only display a quote.
function Config.UpgradeAffordableCost(level, balance)
    if typeof(level) ~= "number" or level ~= level
        or typeof(balance) ~= "number" or balance ~= balance
        or balance == math.huge or balance == -math.huge then
        return nil, 0
    end
    local first = math.clamp(math.floor(level), 1, Config.MaxTapLevel)
    local funds = math.max(0, math.floor(balance))
    local total, levels = 0, 0
    for current = first, Config.MaxTapLevel - 1 do
        local price = Config.UpgradeCost(current)
        if not price or price > funds - total then break end
        total += price
        levels += 1
    end
    if levels == 0 then return nil, 0 end
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
