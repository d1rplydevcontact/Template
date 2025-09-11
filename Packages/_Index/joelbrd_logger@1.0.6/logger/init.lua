local Logger = {}

local TRACEBACK_PATTERN_WITH_FUNCTION = ".*%.([_%w]+:%d+)%s*function%s*([_%w]+)" -- https://www.lua.org/manual/5.3/manual.html#6.4.1
local TRACEBACK_PATTERN = "([_%w]+:%d+)" -- https://www.lua.org/manual/5.3/manual.html#6.4.1
local SCRUB_LINE_NUMBER_PATTERN = ":(%d+)"
local TRACEBACK_SOURCE_LINE = 3 -- Line where the source can be found in tracebacks.
local LEVELS = {
    [1] = {
        Name = "Debug",
        Emoji = "🐛",
    },
    [2] = {
        Name = "Trace",
        Emoji = "🔍",
    },
    [3] = {
        Name = "Info",
        Emoji = "ℹ️",
    },
    [4] = {
        Name = "Warn",
        Emoji = "⚠️",
    },
    [5] = {
        Name = "Error",
        Emoji = "❌",
    },
}
local DEFAULT_LEVEL = 3

Logger.Levels = {
    Debug = 1,
    Trace = 2,
    Info = 3,
    Warn = 4,
    Error = 5,
}

local levelsBySourceName: { [string]: number } = {}

-------------------------------------------------------------------------------
-- Private
-------------------------------------------------------------------------------

-- Returns the name of the source being executed and its line of code as well.
local function getSourceName(sourceOffset: number?, grabJustSource: boolean?)
    sourceOffset = (sourceOffset or 0) + TRACEBACK_SOURCE_LINE

    local tracebackLines = debug.traceback():split("\n")
    if tracebackLines and #tracebackLines >= sourceOffset then
        local sourceLine = tracebackLines[sourceOffset]
        if sourceLine then
            if not grabJustSource then
                -- Try get source, linenumber and functionname
                local sourceLineFunction, repl = sourceLine:gsub(TRACEBACK_PATTERN_WITH_FUNCTION, "%1 %2")
                if repl > 0 then
                    return sourceLineFunction
                end
            end

            -- Just source and linenumber
            for trace in sourceLine:gmatch(TRACEBACK_PATTERN) do
                return grabJustSource and trace:gsub(SCRUB_LINE_NUMBER_PATTERN, "") or trace
            end
        end
    end
    return "Unknown Source"
end

local function assertLevel(level: number)
    assert(level >= 1 and level <= 5, "Invalid level")
end

-- Gets the level of logging for the source this is called from.
local function getLevel(sourceOffset: number?)
    return levelsBySourceName[getSourceName((sourceOffset or 0) + 1, true)] or DEFAULT_LEVEL
end

local function output(method: (...any) -> (), level: number, ...)
    -- RETURN: Level out of bounds
    if getLevel(1) > level then
        return
    end

    -- EDGE CASE: Error
    if method == error then
        local stringArgs = { "\n\n", LEVELS[level].Emoji, getSourceName(1), LEVELS[level].Emoji, "=>" }
        for _, arg in pairs({ ... }) do
            table.insert(stringArgs, tostring(arg))
        end
        table.insert(stringArgs, "\n\n")
        table.insert(stringArgs, debug.traceback())

        error(table.concat(stringArgs, " "))
    end

    method(("%s %s %s =>"):format(LEVELS[level].Emoji, getSourceName(1), LEVELS[level].Emoji), ...)
end

-------------------------------------------------------------------------------
-- API
-------------------------------------------------------------------------------

-- Sets the level of logging for the source this is called from.
function Logger.setLevel(level: number)
    assertLevel(level)
    levelsBySourceName[getSourceName(0, true)] = level
end

-- Granular flow information useful when developing systems.
function Logger.trace(...)
    output(print, Logger.Levels.Trace, ...)
end

-- Low-level information on the flow through the system, mostly for developers.
function Logger.debug(...)
    output(print, Logger.Levels.Debug, ...)
end

-- Generic and useful information about system operation.
function Logger.info(...)
    output(print, Logger.Levels.Info, ...)
end

-- Warnings, poor usage of the API, or 'almost' errors.
function Logger.warn(...)
    local args = { ... }
    table.insert(args, `\n\n{debug.traceback()}`) --todo option for traceback that is controlled via Commands/DebugMenu
    output(warn, Logger.Levels.Warn, table.unpack(args))
end

-- Severe runtime errors or unexpected conditions.
function Logger.error(...)
    output(warn, Logger.Levels.Warn, "❌ ERROR ❌\n\n", ..., `\n\n`, debug.traceback()) -- Sometimes things error silently (???). This ensures we see necessary messages.
    output(error, Logger.Levels.Error, ...)
end

return Logger
