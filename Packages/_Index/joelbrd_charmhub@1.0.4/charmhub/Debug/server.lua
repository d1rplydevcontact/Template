local server = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Functions = require(script.Parent.Parent.Parent.Functions)
local Logger = require(script.Parent.Parent.Parent.Logger)
local Sift = require(script.Parent.Parent.Parent.Sift)
local Registry = require(script.Parent.Parent.Registry)
local types = require(script.Parent.Parent.types)
local Table = require(script.Parent.Parent.Parent.Table)

type ServerDebugger = types.ServerDebugger

--todo use Charm.computed or Charm.mapped (requires adding API to Registry..)
local function setupAtomsList(registry: types.Registry, atomsList: types.Atom<{ [string]: true }>)
    -- Init state
    atomsList(Sift.Dictionary.map(registry.Registry, function(value, key)
        return true, key
    end))

    -- Add atom to the list
    registry.AtomRegistered:Connect(function(key, atom)
        atomsList(function(currentState)
            local newState = table.clone(currentState)
            newState[key] = true
            return newState
        end)
    end)

    -- Remove atom from the list
    registry.AtomDeregistered:Connect(function(key)
        atomsList(function(currentState)
            local newState = table.clone(currentState)
            newState[key] = nil
            return newState
        end)
    end)
end

local function cleanCyclicState(state: table)
    return Table.CyclicRefsToString(state)
end

return function(publicRegistry: types.Registry, syncer: types.ServerSyncer)
    local self = {} :: ServerDebugger

    local registries: { [string]: string } = {} -- registryId: atomsListKey

    local hasPermissionCallback: (Player) -> boolean

    function self:setHasPermission(callback: (Player) -> boolean)
        hasPermissionCallback = callback
    end

    function self:requestPeekData(player: Player): types.PeekData
        if not hasPermissionCallback then
            Logger.error(`Please set a permission callback before requesting peek data via setHasPermission`)
        end

        local hasPermission = hasPermissionCallback(player)
        if not hasPermission then
            return {
                success = false,
                err = "You do not have permission to access the debug data.",
            }
        end

        return {
            success = true,
            data = registries,
        }
    end

    function self:linkRegistry(registry: types.Registry)
        local debugRegistry = Registry.mirror(registry, function(id)
            return `Debug-{id}`
        end)

        syncer:linkRegistry(debugRegistry)

        local atomsListKey = `{debugRegistry.Id}-AtomsList-{Functions.uuid({ small = true })}` -- uuid for security.
        local atomsList = publicRegistry.atom(atomsListKey, {} :: { [string]: true })

        setupAtomsList(debugRegistry, atomsList)

        registries[debugRegistry.Id] = atomsListKey
    end

    function self:linkUnsafeRegistry(registry: types.Registry)
        local debugRegistry = Registry.mirror(registry, function(id)
            return `Debug-{id}`
        end)

        syncer:linkRegistry(debugRegistry, function(key_)
            return cleanCyclicState
        end)

        local atomsListKey = `{debugRegistry.Id}-AtomsList-{Functions.uuid({ small = true })}` -- uuid for security.
        local atomsList = publicRegistry.atom(atomsListKey, {} :: { [string]: true })

        setupAtomsList(debugRegistry, atomsList)

        registries[debugRegistry.Id] = atomsListKey
    end

    return self
end
