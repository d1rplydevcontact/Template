local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Functions = require(script.Parent.Functions)
local Registry = require(script.Registry)

local types = require(script.types)

export type PeekData = types.PeekData
export type Registry = types.Registry

local function privateId()
    if RunService:IsServer() then
        return `Private-Server-{Functions.uuid({ small = true })}`
    end

    return `Private-Client-{Players.LocalPlayer.UserId}`
end

return {
    Public = Registry.new(`Public`),
    Private = Registry.new(privateId()),
    Sync = require(script.Sync),
    Debug = require(script.Debug),
}
