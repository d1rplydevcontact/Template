local tUtil = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(script.Parent.Parent.Parent.Signal)

function tUtil.signal(obj: any)
    if Signal.Is(obj) then
        return true
    end

    return false, `Expected Signal, got {typeof(obj)} {tostring(obj)}`
end

return tUtil
