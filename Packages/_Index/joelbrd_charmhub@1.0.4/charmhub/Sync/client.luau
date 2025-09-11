local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(script.Parent.Parent.Parent.Charm)
local Logger = require(script.Parent.Parent.Parent.Logger)
local patch = require(script.Parent.patch)
local types = require(script.Parent.Parent.types)

type AtomMap = types.AtomMap
type DataSyncPayload = types.DataSyncPayload
type DataRequestPayload = types.DataRequestPayload
type ClientSyncer = types.ClientSyncer

--[=[
	Creates a `ClientSyncer` object that receives patches from the server and
	applies them to the local state.
	
	@param options The atoms to synchronize with the server.
	@return A `ClientSyncer` object.
]=]
local function client(): ClientSyncer
    local self = {} :: ClientSyncer

    local atoms: { [string]: types.AtomMap } = {} -- registryId: { key: Atom<any> }
    local registries: { [string]: types.Registry } = {}

    local stateRequestCallback: (data: types.DataRequestPayload) -> () = function()
        Logger.error(`No state request callback set. Please set one using setDataRequestCallback.`)
    end

    local function getAtom(registryId: string, key: string): Charm.Atom<any>?
        local registryAtoms = atoms[registryId]
        if not registryAtoms then
            return nil
        end

        return registryAtoms[key]
    end

    local function hydrate(payload: DataSyncPayload)
        for key, value in next, payload.data.data do
            local atom = getAtom(payload.registryId, key)
            if not atom then
                Logger.warn(`No atom registered with the key "{key}". Skipping hydration for this key.`)
                continue
            end

            atom(value)
        end
    end

    local function applyPatch(payload: DataSyncPayload)
        local registryAtoms = atoms[payload.registryId] or {}

        local target = {}

        for key, _ in next, payload.data.data do
            local atom = getAtom(payload.registryId, key)
            if not atom then
                Logger.warn(`No atom registered with the key "{key}". Skipping patch application for this key.`)
                continue
            end

            target[key] = atom()
        end

        target = patch.apply(target, payload.data.data)

        for key, value in next, target do
            registryAtoms[key](value)
        end
    end

    local function addAtoms(registryId: string, newAtoms: AtomMap)
        atoms[registryId] = atoms[registryId] or {}

        for key, atom in next, newAtoms do
            atoms[registryId][key] = atom
            stateRequestCallback({
                registryId = registryId,
                key = key,
            })
        end
    end

    local function removeAtoms(registryId: string, oldAtoms: AtomMap)
        atoms[registryId] = atoms[registryId] or {} -- failsafe, shouldn't be needed.

        for key, atom in next, oldAtoms do
            atoms[registryId][key] = nil
            stateRequestCallback({
                registryId = registryId,
                key = key,
                isRemoving = true,
            })
        end
    end

    function self:linkRegistry(registry: types.Registry)
        registries[registry.Id] = registry

        registry.AtomRegistered:Connect(function(key, atom)
            addAtoms(registry.Id, { [key] = atom })
        end)
        registry.AtomDeregistered:Connect(function(key)
            removeAtoms(registry.Id, { [key] = registry.Registry[key] })
        end)

        addAtoms(registry.Id, registry.Registry)
    end

    function self:sync(payload: DataSyncPayload)
        if payload.data.type == "init" then
            hydrate(payload)
        else
            applyPatch(payload)
        end
    end

    function self:setDataRequestCallback(callback: (data: types.DataRequestPayload) -> ())
        stateRequestCallback = callback
    end

    return self
end

return client
