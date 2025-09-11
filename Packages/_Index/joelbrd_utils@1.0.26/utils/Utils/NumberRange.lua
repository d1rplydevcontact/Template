local NumberRangeUtil = {}

function NumberRangeUtil.contains(range: NumberRange, value: number): boolean
    return value >= range.Min and value <= range.Max
end

function NumberRangeUtil.midpoint(range: NumberRange): number
    return (range.Min + range.Max) / 2
end

function NumberRangeUtil.randomInt(range: NumberRange): number
    return math.round(math.random(range.Min, range.Max))
end

function NumberRangeUtil.randomFloat(range: NumberRange): number
    return math.random() * (range.Max - range.Min) + range.Min
end

return NumberRangeUtil
