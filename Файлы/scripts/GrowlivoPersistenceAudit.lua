-- GROWLIVO / Outgoing profile-snapshot audit / Alpha 0.9.14
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
