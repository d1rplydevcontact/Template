local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(script.Parent.Parent.Parent.Charm)
local Logger = require(script.Parent.Parent.Parent.Logger)
local Registry = require(script.Parent.Parent.Registry)
local types = require(script.Parent.Parent.types)

local function setupRegistry(registryId: string, atomslistKey: string, publicRegistry: types.Registry, syncer: types.ServerSyncer)
    local atomsList = publicRegistry.atom(atomslistKey, {} :: { [string]: true })
    local debugRegistry = Registry.new(registryId)

    -- when we get a new atom key, create it in our respective debug registry.
    Charm.observe(atomsList, function(_true, key)
        local _atom, deregister = debugRegistry.atom(key, {})

        return function()
            deregister()
        end
    end)

    syncer:linkRegistry(debugRegistry)

    return debugRegistry
end

return function(publicRegistry: types.Registry, syncer: types.ServerSyncer, peekData: types.PeekData)
    local self = {} :: types.ClientDebugger

    if not peekData.data then
        Logger.error(`No registry data found in peekData. Please ensure the server has sent the data.`, peekData)
        return self
    end

    local registries: { types.Registry } = {}

    for registryId, atomsListKey in pairs(peekData.data) do
        local registry = setupRegistry(registryId, atomsListKey, publicRegistry, syncer)
        table.insert(registries, registry)
    end

    function self:getDebugRegistries()
        return registries
    end

    return self
end
