local Math = {}
local Logger = require(script.Parent.Logger)
local Table = require(script.Parent.Table)

function Math.round(num: number, decimalPlaces: number?)
    local mult = 10 ^ (decimalPlaces or 0)
    local rounded = math.floor(num * mult + 0.5) / mult
    local formatString = "%." .. (decimalPlaces or 0) .. "f"
    local formattedString = string.format(formatString, rounded)
    return rounded, formattedString
end

function Math.roundToNearestIncrement(num: number, range: NumberRange, increment: number)
    local min = range.Min
    local max = range.Max
    local clamped = math.clamp(num, min, max)
    local rounded = min + math.floor(((clamped - min) / increment) + 0.5) * increment
    return Math.round(rounded, Math.countDecimalPlaces(increment))
end

--[=[
    Will call `callback` for each point in a 2D spiral pattern, until `callback` returns false.

    - Starts at (0, 0) and spirals outwards.
    - `counter` starts at 1, and goes up by 1 for each point.
]=]
function Math.spiral2D(callback: (x: number, y: number, counter: number) -> boolean)
    local x, y = 0, 0
    local directions = { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } } -- right, up, left, down
    local dirIndex = 1
    local steps = 1
    local changeStep = 0

    local counter = 1
    while true do
        for i = 1, steps do
            if not callback(x, y, counter) then
                return
            end
            x = x + directions[dirIndex][1]
            y = y + directions[dirIndex][2]
            counter = counter + 1
        end

        dirIndex = dirIndex % 4 + 1
        changeStep = changeStep + 1

        if changeStep == 2 then
            steps = steps + 1
            changeStep = 0
        end
    end
end

function Math.countDecimalPlaces(num: number)
    local numString = tostring(num)
    local decimalIndex = string.find(numString, "%.")
    if decimalIndex == nil then
        return 0
    end

    return #numString - decimalIndex
end

--[=[
    Applies a modulo operation to a number, in the context of Lua arrays starting at index 1 and not 0.

    Examples
    ```lua
    Math.arrayModulo(1, 3) -- 1
    Math.arrayModulo(2, 3) -- 2
    Math.arrayModulo(3, 3) -- 3
    Math.arrayModulo(4, 3) -- 1
    Math.arrayModulo(0, 3) -- 3
    ```
]=]
function Math.arrayModulo(num: number, modulo: number)
    return ((num - 1) % modulo) + 1
end

-------------------------------------------------------------------------------
-- Weighted Probability
-------------------------------------------------------------------------------

local weightedProbability = {}
Math.WeightedProbability = weightedProbability

function weightedProbability.pick<T>(tbl: { [T]: number })
    local total = 0
    for item, weight in pairs(tbl) do
        if weight < 0 then
            Logger.warn(`Negative weight`, item, weight)
        end

        total += weight
    end

    local random = math.random() * total
    local backupItem: T = nil
    for item, weight in pairs(tbl) do
        random -= weight
        if random <= 0 then
            return item
        end
    end

    if backupItem == nil then
        Logger.error(`No item`)
    end

    return backupItem
end

function Math.map(value: number, inRangeStart: number, inRangeEnd: number, outRangeStart: number, outRangeEnd: number, clamp: boolean?)
    local newValue = (value - inRangeStart) / (inRangeEnd - inRangeStart) * (outRangeEnd - outRangeStart) + outRangeStart
    if clamp then
        return math.clamp(newValue, math.min(outRangeStart, outRangeEnd), math.max(outRangeStart, outRangeEnd))
    end
    return newValue
end

--[=[
    Returns an array of Vector2 points that form a circle of radius `radius`, where the points
    lay out in a checkerboard pattern.

    A radius of 1 will return a single point at (0, 0)...
]=]
function Math.checkerboardCirclePoints(radius: number)
    local points: { Vector2 } = {}

    local function addPoint(x: number, y: number)
        table.insert(points, Vector2.new(x, y))
    end

    local useRadius = radius - 1

    for x = -useRadius, useRadius do
        for y = -useRadius, useRadius do
            if math.sqrt(x * x + y * y) <= useRadius and (x + y) % 2 == 0 then
                addPoint(x, y)
            end
        end
    end

    return points
end

function Math.circlePoints(radius: number)
    local points: { Vector2 } = {}

    local function addPoint(x: number, y: number)
        table.insert(points, Vector2.new(x, y))
    end

    local useRadius = radius - 1

    for x = -useRadius, useRadius do
        for y = -useRadius, useRadius do
            if math.sqrt(x * x + y * y) <= useRadius then
                addPoint(x, y)
            end
        end
    end

    return points
end

--[=[
    Returns `desiredPoints` number of points from `points` that have the lowest magnitude.
]=]
function Math.filterLowestMagnitudePoints(points: { Vector2 }, desiredPoints: number)
    local filteredPoints: { Vector2 } = table.clone(points)

    table.sort(filteredPoints, function(a, b)
        return a.Magnitude < b.Magnitude
    end)

    return Table.Sift.Array.slice(filteredPoints, 1, desiredPoints)
end

function Math.isNan(num: number)
    return tostring(num) == "inf"
end

function Math.toString(num: number, decimalPlaces: number?)
    local _, rounded = Math.round(num, decimalPlaces)
    return rounded
end

-- credit http://richard.warburton.it
function Math.toCommasString(num: number, decimalPlaces: number?)
    local formatted = Math.toString(num, decimalPlaces)
    local left, _num, right = string.match(formatted, "^([^%d]*%d)(%d*)(.-)$")
    return left .. (_num:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
end

-------------------------------------------------------------------------------
-- FORMAT NUMBER
-------------------------------------------------------------------------------

local LARGE_NUMBER_MAP = {}

-- Populate large number map, assigning names to numbers from 0 to 1e303 (1 Centillion)
table.insert(LARGE_NUMBER_MAP, { Exponent = 00, Name = "", Suffix = "" })
table.insert(LARGE_NUMBER_MAP, { Exponent = 03, Name = "Thousand", Suffix = "K" })
table.insert(LARGE_NUMBER_MAP, { Exponent = 06, Name = "Million", Suffix = "M" })
table.insert(LARGE_NUMBER_MAP, { Exponent = 09, Name = "Billion", Suffix = "B" })
table.insert(LARGE_NUMBER_MAP, { Exponent = 12, Name = "Trillion", Suffix = "T" })
table.insert(LARGE_NUMBER_MAP, { Exponent = 15, Name = "Quadrillion", Suffix = "Q" })
table.insert(LARGE_NUMBER_MAP, { Exponent = 18, Name = "Quintillion", Suffix = "QQ" })
table.insert(LARGE_NUMBER_MAP, { Exponent = 21, Name = "Sextillion", Suffix = "S" })
table.insert(LARGE_NUMBER_MAP, { Exponent = 24, Name = "Septillion", Suffix = "SS" })
table.insert(LARGE_NUMBER_MAP, { Exponent = 27, Name = "Octillion", Suffix = "O" })
table.insert(LARGE_NUMBER_MAP, { Exponent = 30, Name = "Nonillion", Suffix = "N" })
local largeNumberPrefixes = { "", "un", "duo", "tres", "quattuor", "quin", "ses", "septen", "octo", "noven" }
local largeNumberSuffixes = {
    "dec",
    "vigint",
    "trigint",
    "quadragint",
    "quinquagint",
    "sexagint",
    "septuagint",
    "octogint",
    "nonagint",
}
local fixedSuffix = "illion"
for suffixIndex, suffix in pairs(largeNumberSuffixes) do
    for prefixIndex, prefix in pairs(largeNumberPrefixes) do
        -- Handle exceptions
        if suffix == "dec" then
            if prefix == "tres" then
                prefix = "tre"
            elseif prefix == "ses" then
                prefix = "se"
            end
        elseif suffix == "vigint" then
            if prefix == "septen" then
                prefix = "septem"
            elseif prefix == "noven" then
                prefix = "novem"
            end
        end

        -- Register next values
        local nextNotation = LARGE_NUMBER_MAP[#LARGE_NUMBER_MAP].Exponent + 3
        local nextName = ("%s%s%s"):format(prefix, suffix, fixedSuffix):gsub("^%l", string.upper)
        table.insert(LARGE_NUMBER_MAP, { Exponent = nextNotation, Name = nextName })
    end
end
table.insert(LARGE_NUMBER_MAP, { Exponent = LARGE_NUMBER_MAP[#LARGE_NUMBER_MAP].Exponent + 3, Name = "Centillion" })

-------------------------------------------------------------------------------
-- function
-------------------------------------------------------------------------------

local function formatNumber(number: number, formatType: "Scientific" | "Long" | "Short" | "Shortest" | nil)
    if formatType == nil then
        if number >= 0 and number < 1000 then
            return formatNumber(number, "Long")
        end

        return formatNumber(number, "Shortest")
    end

    if formatType == "Scientific" then
        return ("%.3g"):format(number):gsub("+", ""):gsub("e0+", "e")
    end

    -- Obtain indexes
    local valueExponent = math.max(0, math.floor(math.log10(number)))
    local dataIndex = math.floor(valueExponent / 3) + 1
    dataIndex = math.clamp(dataIndex, 1, #LARGE_NUMBER_MAP)
    local mapEntry = LARGE_NUMBER_MAP[dataIndex]

    -- Define decimals
    local baseValue = math.max(1, 10 ^ mapEntry.Exponent)
    local valueByBase = number / baseValue
    local decimals = (valueByBase ~= 0 and valueByBase < 1) and 2 or 0
    local hasDecimals = decimals > 0

    -- Format value
    local _decimalHelper = 10 ^ decimals
    local rounded = math.floor(valueByBase * _decimalHelper) / _decimalHelper

    local formattedValue: string = nil
    if hasDecimals then
        local integerString = Math.toCommasString(math.floor(rounded)) --StringUtil:CommaValue(math.floor(rounded))
        local digitsAsInteger = math.floor((rounded % 1) * 10 ^ decimals)
        local stringFormat = ("%%s.%%0%dd"):format(decimals)
        formattedValue = stringFormat:format(integerString, digitsAsInteger)
    elseif valueByBase < 10 then
        formattedValue = tostring(math.round(valueByBase * 10) / 10)
    else
        formattedValue = Math.toCommasString(rounded)
    end

    if formatType == "Short" then
        return ("%s %s"):format(formattedValue, mapEntry.Name)
    end

    if formatType == "Shortest" then
        return ("%s%s"):format(formattedValue, mapEntry.Suffix)
    end

    if formatType == "Long" then
        return formattedValue
    end

    Logger.warn(`Invalid formatType: ${formatType}`)
    return "?"
end

Math.formatNumber = formatNumber

-- Rounds a number to a specified number of significant figures
local function roundToSigFig(num: number, sig: number)
    if num == 0 then
        return 0
    end

    -- Calculate order of magnitude
    local order = math.floor(math.log10(math.abs(num)))
    local scale = 10 ^ (sig - order - 1)

    -- Round using scale, then rescale
    local rounded = math.floor(num * scale + 0.5) / scale
    return rounded
end

Math.roundToSigFig = roundToSigFig

return Math
