local NumberSequenceUtil = {}

local TweenService = game:GetService("TweenService")
local Math = require(script.Parent.Parent.Parent.Math)

local DEFAULT_SEGMENTS = 18
local MAX_SEGMENTS = 20

function NumberSequenceUtil.keypointsFromEasing(
    startTime: number,
    startValue: number,
    endTime: number,
    endValue: number,
    style: Enum.EasingStyle,
    direction: Enum.EasingDirection,
    segments: number?
)
    local _segments = math.min(segments or DEFAULT_SEGMENTS, MAX_SEGMENTS)

    local keypoints: { NumberSequenceKeypoint } = {}

    -- use TweenService:GetValue(alpha, style, direction)

    local startKeypoint = NumberSequenceKeypoint.new(startTime, startValue)
    table.insert(keypoints, startKeypoint)

    for i = 1, _segments do
        local alpha = i / (_segments + 1)
        local value = TweenService:GetValue(alpha, style, direction)
        local time = Math.map(alpha, 0, 1, startTime, endTime)
        local keypoint = NumberSequenceKeypoint.new(time, value)
        table.insert(keypoints, keypoint)
    end

    local endKeypoint = NumberSequenceKeypoint.new(endTime, endValue)
    table.insert(keypoints, endKeypoint)

    return keypoints
end

function NumberSequenceUtil.fromEasing(
    startTime: number,
    startValue: number,
    endTime: number,
    endValue: number,
    style: Enum.EasingStyle,
    direction: Enum.EasingDirection,
    segments: number?
)
    return NumberSequence.new(NumberSequenceUtil.keypointsFromEasing(startTime, startValue, endTime, endValue, style, direction, segments))
end

return NumberSequenceUtil
