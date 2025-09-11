--[=[
    Wrapper for the Roblox RunService.

    - Provides methods to connect to RunService events with optional profiling.
]=]
local RunServiceWrap = {}

local RunService = game:GetService("RunService")
local Logger = require(script.Parent.Logger)

--[=[
    Toggle for profiling any callbacks run through RunServiceWrap
]=]
RunServiceWrap.ProfilingActive = true

--[=[
    If `name` is provided, the callback will be profiled with that name. Callback must not yield in these cases.
]=]
function RunServiceWrap:OnHeartbeat(callback: (dt: number) -> (), name: string?)
    if name then
        return RunService.Heartbeat:Connect(function(dt: number)
            if not RunServiceWrap.ProfilingActive then
                callback(dt)
                return
            end

            debug.profilebegin(name)
            callback(dt)
            debug.profileend()
        end)
    end

    return RunService.Heartbeat:Connect(callback)
end

--[=[
    If `name` is provided, the callback will be profiled with that name. Callback must not yield in these cases.
]=]
function RunServiceWrap:OnStepped(callback: (dt: number, renderStep: Enum.RenderPriority) -> (), name: string?)
    if name then
        return RunService.Stepped:Connect(function(dt: number, renderStep: Enum.RenderPriority)
            if not RunServiceWrap.ProfilingActive then
                callback(dt, renderStep)
                return
            end

            debug.profilebegin(name)
            callback(dt, renderStep)
            debug.profileend()
        end)
    end

    return RunService.Stepped:Connect(callback)
end

--[=[
    If `name` is provided, the callback will be profiled with that name. Callback must not yield in these cases.
]=]
function RunServiceWrap:OnRenderStepped(callback: (dt: number) -> (), name: string?)
    if name then
        return RunService.RenderStepped:Connect(function(dt: number)
            if not RunServiceWrap.ProfilingActive then
                callback(dt)
                return
            end

            debug.profilebegin(name)
            callback(dt)
            debug.profileend()
        end)
    end

    return RunService.RenderStepped:Connect(callback)
end

--[=[
    If `name` is provided, the callback will be profiled with that name. Callback must not yield in these cases.

    - Runs the callback every `props.Seconds` seconds, starting immediately if `props.Inclusive` is true.
    - If `props.Yield` is true, it will wait for the previous callback to finish before starting the timer again.
    - If `props.Method` is provided, it will use that method to run the callback. Defaults to "Heartbeat".
    - If `props.Method` is not provided, it will use "Heartbeat" by default.
]=]
function RunServiceWrap:Every(
    props: {
        Seconds: number, -- how often to run the callback
        Method: ("Heartbeat" | "Stepped" | "RenderStepped")?, -- which method to use. Defaults to Heartbeat
        Inclusive: boolean?, -- if true, will run the callback ASAP. Else, will wait the first `seconds`
        Yield: boolean?, -- if true, it will start the internal timer of `Seconds` after the previous callback has finished
    },
    callback: () -> (),
    name: string?
)
    local method = props.Method or "Heartbeat"
    local func = method == "Heartbeat" and RunServiceWrap.OnHeartbeat
        or method == "Stepped" and RunServiceWrap.OnStepped
        or method == "RenderStepped" and RunServiceWrap.OnRenderStepped
        or Logger.error(`Invalid Method: {method}`)

    local isExecuting = false
    local lastCall = props.Inclusive and -1 or tick()
    return func(RunServiceWrap, function(dt: number)
        if isExecuting and props.Yield then
            return
        end

        if tick() - lastCall < props.Seconds then
            return
        end
        lastCall = tick()

        isExecuting = true

        callback()

        if props.Yield then
            lastCall = tick()
        end

        isExecuting = false
    end, name) :: RBXScriptConnection
end

--[=[
    Sugar wrapper around `RunServiceWrap:Every`, that then disconnects after `callback` has been run exactly once.
]=]
function RunServiceWrap:After(seconds: number, callback: () -> (), method: ("Heartbeat" | "Stepped" | "RenderStepped")?)
    local connection: RBXScriptConnection
    connection = RunServiceWrap:Every({
        Seconds = seconds,
        Method = method,
        Inclusive = false,
        Yield = true,
    }, function()
        callback()
        connection:Disconnect()
    end)

    return connection
end

--[=[
    Runs BindToRenderStep with profiling.
]=]
function RunServiceWrap:WrapBindToRenderStep(name: string, priority: Enum.RenderPriority, callback: (dt: number) -> ())
    if not RunService:IsClient() then
        Logger.error("WrapBindToRenderStep can only be used on the client")
        return
    end

    return RunService:BindToRenderStep(name, priority, function(dt: number)
        if not RunServiceWrap.ProfilingActive then
            callback(dt)
            return
        end

        debug.profilebegin(name)
        callback(dt)
        debug.profileend()
    end)
end

function RunServiceWrap:GetEnvironment()
    return (RunService:IsServer() and "Server" or "Client") :: "Server" | "Client"
end

-------------------------------------------------------------------------------
-- Export
-------------------------------------------------------------------------------

local function wrapRobloxService(fakeService, realService)
    setmetatable(fakeService, {
        __index = function(_, key: string)
            -- Functions use : notation, when indexing is via . notation. We need to simulate this.
            local value = realService[key]
            if typeof(value) == "function" then
                return function(_, ...) -- _ is fakeService
                    return value(realService, ...)
                end
            end

            return value
        end,
    })
end

type RunServiceWrapper = typeof(RunServiceWrap)
wrapRobloxService(RunServiceWrap, RunService)

return RunServiceWrap :: RunServiceWrapper & RunService
