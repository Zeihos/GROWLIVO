-- GROWLIVO / UTC calendar periods / Alpha 0.9.15
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
