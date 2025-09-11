--[=[
    Hacky workarounds for interacting with Roblox Seats..
]=]
local Seat = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Future = require(script.Parent.Parent.Parent.Future)
local Functions = require(script.Parent.Parent.Parent.Functions)
local isInstanceDestroyed = Functions.isInstanceDestroyed

local FORCE_TIMEOUT_SECONDS = 5
local DEFAULT_JUMP_POWER = 50

function Seat.simpleSit(seat: Seat, humanoid: Humanoid)
    seat:Sit(humanoid)
end

function Seat.forceSit(seat: Seat, humanoid: Humanoid, timeoutSeconds: number?)
    return Future.new(function()
        if seat.Occupant then
            seat.Disabled = true
            task.wait()
            seat.Disabled = false
        end

        local timeoutTick = tick() + (timeoutSeconds or FORCE_TIMEOUT_SECONDS)

        while not isInstanceDestroyed(humanoid) and humanoid.Health > 0 and tick() < timeoutTick do
            seat:Sit(humanoid)
            if seat.Occupant == humanoid then
                break
            end

            task.wait()
        end

        return seat.Occupant == humanoid
    end)
end

function Seat.forceStand(humanoid: Humanoid)
    humanoid.Sit = false
end

function Seat.lockToSeats(humanoid: Humanoid)
    humanoid.JumpPower = 0
end

function Seat.unlockFromSeats(humanoid: Humanoid)
    humanoid.JumpPower = DEFAULT_JUMP_POWER
end

local function humanoid(player: Player)
    local character = player.Character
    if not character then
        return nil
    end

    return character:FindFirstChildOfClass("Humanoid")
end

function Seat.isOccupying(seat: Seat, player: Player)
    return seat.Occupant == humanoid(player)
end

return Seat
