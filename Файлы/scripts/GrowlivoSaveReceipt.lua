-- GROWLIVO / Pure save receipt accounting / Alpha 0.9.14
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
