local Tween = {}

local TweenService = game:GetService("TweenService")
local RunServiceWrap = require(script.Parent.Parent.Parent.RunServiceWrap)

--[=[
    Creates a tween, and automatically plays it.

    We return a custom Object that links directly to the tween, but when Destroy() is called it cancels the tween
    then destroys it... how it should be!
]=]
function Tween.tween(instance: Instance, tweenInfo: TweenInfo, propertyTable: { [string]: any }): Tween
    local tween = TweenService:Create(instance, tweenInfo, propertyTable)
    tween:Play()

    local fakeTween = {
        Destroy = function()
            if tween then
                tween:Cancel()
                tween:Destroy()
                tween = nil
            end
        end,
    }

    setmetatable(fakeTween, {
        __index = function(_, key: string)
            -- Functions use : notation, when indexing is via . notation. We need to simulate this.
            local value = tween[key]
            if typeof(value) == "function" then
                return function(_, ...) -- _ is fakeService
                    return value(tween, ...)
                end
            end

            return value
        end,
    })

    return (fakeTween :: any) :: Tween
end

--[[
    Every frame, will call `callback` with an alpha value which is calculated from the tweenInfo.

    Returns an RBXScriptConnection that:
    - Will automatically disconnect when the tween is completed
    - You can disconnect at any time yourself!
]]
function Tween.run(callback: (alpha: number, dt: number, prevAlpha: number?) -> nil, tweenInfo: TweenInfo)
    local startTick = tick() + tweenInfo.DelayTime
    local repeatsLeft = tweenInfo.RepeatCount

    local prevAlpha: number?
    local isReversing = false

    local connection: RBXScriptConnection = nil
    local function onTick(dt: number)
        -- RETURN: Delay time stops us from starting yet
        local thisTick = tick()
        if thisTick < startTick then
            return
        end

        -- Calculate time
        local timeElapsed = thisTick - startTick
        local timeAlpha = math.clamp(timeElapsed / tweenInfo.Time, 0, 1)
        if isReversing then
            timeAlpha = 1 - timeAlpha
        end

        -- Times up! What do?
        if isReversing and timeAlpha == 0 or timeAlpha == 1 then
            local doReverse = isReversing == false and tweenInfo.Reverses
            if doReverse then
                isReversing = true
                startTick += tweenInfo.Time
            else
                isReversing = false

                repeatsLeft -= 1
                if repeatsLeft == -1 then
                    -- Exit
                    connection:Disconnect()
                else
                    -- Loop back
                    startTick += tweenInfo.Time
                end

                callback(timeAlpha, dt, prevAlpha)
                return
            end
        end

        -- Tween
        local tweenAlpha = TweenService:GetValue(timeAlpha, tweenInfo.EasingStyle, tweenInfo.EasingDirection)
        callback(tweenAlpha, dt, prevAlpha)

        prevAlpha = tweenAlpha
    end

    connection = RunServiceWrap:OnRenderStepped(onTick, "Tween.run")

    return connection
end

return Tween
