local Time = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Logger = require(script.Parent.Parent.Parent.Logger)
local ConstMap = require(script.Parent.Parent.Parent.ConstMap)

Time.TimeType = ConstMap({
    Milliseconds = "Milliseconds",
    Seconds = "Seconds",
    Minutes = "Minutes",
    Hours = "Hours",
    Days = "Days",
    Weeks = "Weeks",
    Months = "Months",
    Years = "Years",
})

Time.TimeTypeOrderDescending = {
    Time.TimeType.Years,
    Time.TimeType.Months,
    Time.TimeType.Weeks,
    Time.TimeType.Days,
    Time.TimeType.Hours,
    Time.TimeType.Minutes,
    Time.TimeType.Seconds,
    Time.TimeType.Milliseconds,
}

Time.TimeTypeSecondsRatio = {
    [Time.TimeType.Milliseconds] = 0.001,
    [Time.TimeType.Seconds] = 1,
    [Time.TimeType.Minutes] = 60,
    [Time.TimeType.Hours] = 60 * 60,
    [Time.TimeType.Days] = 60 * 60 * 24,
    [Time.TimeType.Weeks] = 60 * 60 * 24 * 7,
    [Time.TimeType.Months] = 60 * 60 * 24 * 30.44,
    [Time.TimeType.Years] = 60 * 60 * 24 * 365.25,
}

--- includes milliseconds
function Time.getServerTimeNow()
    return Workspace:GetServerTimeNow()
end

local _replicationLag: number? = nil

--[=[
    Useful for when you set Replication Lag in Roblox Studio settings - this does not get picked up by player:GetNetworkPing().

    This will override logic in Time.getPing().
]=]
function Time._setReplicationLag(lag: number?)
    _replicationLag = lag
end

--- time for request and response. divide by 2 to get 1-way latency.
function Time.getPing(player: Player)
    return _replicationLag or player:GetNetworkPing()
end

--- Sugar for `Time.getPing(Players.LocalPlayer)`
function Time.getLocalPing()
    return Time.getPing(Players.LocalPlayer)
end

function Time.getTimeTypeSecondsRatio(timeType: string): number
    return Time.TimeTypeSecondsRatio[timeType] or Logger.error(`Invalid timeType: {timeType}`)
end

--[=[
    Where `osTime` is the time in seconds since the epoch, a "time type numeric" is the number of `timeType` units that have passed since the epoch.

    Example:
    ```lua
        local yearsSinceEpoch = Time.getTimeTypeNumericFromOSTime(Time.TimeType.Years, os.time())
    ```
]=]
function Time.getTimeTypeNumericFromOSTime(timeType: string, osTime: number)
    return math.floor(osTime / Time.getTimeTypeSecondsRatio(timeType))
end

function Time.getSecondsFromTimeTypeNumeric(timeType: string, timeTypeNumeric: number)
    return timeTypeNumeric * Time.getTimeTypeSecondsRatio(timeType)
end

-------------------------------------------------------------------------------
-- Time Formatter
-------------------------------------------------------------------------------

local TimeFormatter = {}
Time.TimeFormatter = TimeFormatter

TimeFormatter.TimeType = Time.TimeType

TimeFormatter.LengthType = ConstMap({
    Short = "Short",
    Long = "Long",
})

local TIME_TYPE_ORDER_DESCENDING = Time.TimeTypeOrderDescending

local TIME_TYPE_DATA: { [string]: { SecondsRatio: number, LengthTypeDisplay: { Plural: { [string]: string }, Singular: { [string]: string } } } } =
    {
        [TimeFormatter.TimeType.Milliseconds] = {
            SecondsRatio = Time.TimeTypeSecondsRatio[TimeFormatter.TimeType.Milliseconds],
            LengthTypeDisplay = {
                Plural = {
                    [TimeFormatter.LengthType.Short] = "ms",
                    [TimeFormatter.LengthType.Long] = "milliseconds",
                },
                Singular = {
                    [TimeFormatter.LengthType.Short] = "ms",
                    [TimeFormatter.LengthType.Long] = "millisecond",
                },
            },
        },
        [TimeFormatter.TimeType.Seconds] = {
            SecondsRatio = Time.TimeTypeSecondsRatio[TimeFormatter.TimeType.Seconds],
            LengthTypeDisplay = {
                Plural = {
                    [TimeFormatter.LengthType.Short] = "s",
                    [TimeFormatter.LengthType.Long] = "seconds",
                },
                Singular = {
                    [TimeFormatter.LengthType.Short] = "s",
                    [TimeFormatter.LengthType.Long] = "second",
                },
            },
        },
        [TimeFormatter.TimeType.Minutes] = {
            SecondsRatio = Time.TimeTypeSecondsRatio[TimeFormatter.TimeType.Minutes],
            LengthTypeDisplay = {
                Plural = {
                    [TimeFormatter.LengthType.Short] = "m",
                    [TimeFormatter.LengthType.Long] = "minutes",
                },
                Singular = {
                    [TimeFormatter.LengthType.Short] = "m",
                    [TimeFormatter.LengthType.Long] = "minute",
                },
            },
        },
        [TimeFormatter.TimeType.Hours] = {
            SecondsRatio = Time.TimeTypeSecondsRatio[TimeFormatter.TimeType.Hours],
            LengthTypeDisplay = {
                Plural = {
                    [TimeFormatter.LengthType.Short] = "h",
                    [TimeFormatter.LengthType.Long] = "hours",
                },
                Singular = {
                    [TimeFormatter.LengthType.Short] = "h",
                    [TimeFormatter.LengthType.Long] = "hour",
                },
            },
        },
        [TimeFormatter.TimeType.Days] = {
            SecondsRatio = Time.TimeTypeSecondsRatio[TimeFormatter.TimeType.Days],
            LengthTypeDisplay = {
                Plural = {
                    [TimeFormatter.LengthType.Short] = "d",
                    [TimeFormatter.LengthType.Long] = "days",
                },
                Singular = {
                    [TimeFormatter.LengthType.Short] = "d",
                    [TimeFormatter.LengthType.Long] = "day",
                },
            },
        },
        [TimeFormatter.TimeType.Weeks] = {
            SecondsRatio = Time.TimeTypeSecondsRatio[TimeFormatter.TimeType.Weeks],
            LengthTypeDisplay = {
                Plural = {
                    [TimeFormatter.LengthType.Short] = "w",
                    [TimeFormatter.LengthType.Long] = "weeks",
                },
                Singular = {
                    [TimeFormatter.LengthType.Short] = "w",
                    [TimeFormatter.LengthType.Long] = "week",
                },
            },
        },
        [TimeFormatter.TimeType.Months] = {
            SecondsRatio = Time.TimeTypeSecondsRatio[TimeFormatter.TimeType.Months],
            LengthTypeDisplay = {
                Plural = {
                    [TimeFormatter.LengthType.Short] = "mo",
                    [TimeFormatter.LengthType.Long] = "months",
                },
                Singular = {
                    [TimeFormatter.LengthType.Short] = "mo",
                    [TimeFormatter.LengthType.Long] = "month",
                },
            },
        },
        [TimeFormatter.TimeType.Years] = {
            SecondsRatio = Time.TimeTypeSecondsRatio[TimeFormatter.TimeType.Years],
            LengthTypeDisplay = {
                Plural = {
                    [TimeFormatter.LengthType.Short] = "y",
                    [TimeFormatter.LengthType.Long] = "years",
                },
                Singular = {
                    [TimeFormatter.LengthType.Short] = "y",
                    [TimeFormatter.LengthType.Long] = "year",
                },
            },
        },
    }

--[=[
    TimeFormatter is a utility for formatting time durations into human-readable strings.
    It supports various time types (e.g., seconds, minutes, hours) and can display them in short or long formats.
    The formatter can be customized to display a maximum number of time types.

    By default, it will display all time types except milliseconds in a short format.
]=]
function TimeFormatter.new(options: {
    timeTypes: { string },
    lengthType: string,
}?)
    local timeTypes = options and options.timeTypes or TimeFormatter.selectTimeTypes.allButMilliseconds()
    local lengthType = options and options.lengthType or TimeFormatter.LengthType.Short

    TimeFormatter.TimeType.assert(timeTypes)
    TimeFormatter.LengthType.assert(lengthType)

    local timeTypesDescending = table.clone(timeTypes)
    table.sort(timeTypesDescending, function(a, b)
        return table.find(TIME_TYPE_ORDER_DESCENDING, a) < table.find(TIME_TYPE_ORDER_DESCENDING, b)
    end)

    local self = {}

    function self:FromSeconds(seconds: number, _displayMaxTimeTypes: number?)
        local displayMaxTimeTypes = _displayMaxTimeTypes or #timeTypes

        local str = ``
        local gap = lengthType == TimeFormatter.LengthType.Short and `` or ` `
        local totalDisplayedTimeTypes = 0
        for i, timeType in pairs(timeTypesDescending) do
            local timeTypeData = TIME_TYPE_DATA[timeType]
            local timeTypeSeconds = math.floor(seconds / timeTypeData.SecondsRatio)

            if timeTypeSeconds == 0 then
                continue
            end

            if totalDisplayedTimeTypes >= displayMaxTimeTypes then
                break
            end

            seconds -= timeTypeSeconds * timeTypeData.SecondsRatio
            local suffix = timeTypeSeconds > 1 and timeTypeData.LengthTypeDisplay.Plural[lengthType]
                or timeTypeData.LengthTypeDisplay.Singular[lengthType]

            totalDisplayedTimeTypes += 1

            if str == `` then
                str = `{timeTypeSeconds}{gap}{suffix}`
                continue
            end

            if i == #timeTypesDescending then
                if lengthType == TimeFormatter.LengthType.Short then
                    str ..= `{timeTypeSeconds}{gap}{suffix}`
                else
                    str ..= ` and {timeTypeSeconds}{gap}{suffix}`
                end
                continue
            end

            if lengthType == TimeFormatter.LengthType.Short then
                str ..= `{timeTypeSeconds}{gap}{suffix}`
            else
                str ..= `, {timeTypeSeconds}{gap}{suffix}`
            end
        end

        -- if `str` is empty, display the lowest time type
        if str == `` then
            local timeType = timeTypesDescending[#timeTypesDescending]
            local timeTypeData = TIME_TYPE_DATA[timeType]
            local timeTypeSeconds = math.floor(seconds / timeTypeData.SecondsRatio)
            local suffix = timeTypeSeconds > 1 and timeTypeData.LengthTypeDisplay.Plural[lengthType]
                or timeTypeData.LengthTypeDisplay.Singular[lengthType]

            str = `{timeTypeSeconds}{gap}{suffix}`
        end

        return str
    end

    return self
end

TimeFormatter.selectTimeTypes = {}

function TimeFormatter.selectTimeTypes.allButMilliseconds()
    local timeTypes: { string } = {}
    for timeType, _ in pairs(TimeFormatter.TimeType) do
        if timeType ~= TimeFormatter.TimeType.Milliseconds then
            table.insert(timeTypes, timeType)
        end
    end

    return timeTypes
end

return Time
