local CharmRegistry = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(script.Parent.Parent.Charm)
local Signal = require(script.Parent.Parent.Signal)
local Logger = require(script.Parent.Parent.Logger)
local types = require(script.Parent.types)

function CharmRegistry.mirror(registry: types.Registry, id: string | (id: string) -> string): types.Registry
    local newId = typeof(id) == "function" and id(registry.Id) or id
    local mirroredRegistry = CharmRegistry.new(newId)

    for key, atom in pairs(registry.Registry) do
        mirroredRegistry.register(key, atom)
    end

    registry.AtomRegistered:Connect(function(key, atom)
        mirroredRegistry.register(key, atom)
    end)

    registry.AtomDeregistered:Connect(function(key)
        mirroredRegistry.deregister(key)
    end)

    return mirroredRegistry
end

function CharmRegistry.new(id: string): types.Registry
    local self = {}

    local deregistersByKey: { [string]: () -> () } = {}

    self.Id = id
    self.Registry = {} :: types.AtomMap
    self.AtomRegistered = Signal.new() :: Signal.Signal<string, types.Atom<any>>
    self.AtomDeregistered = Signal.new() :: Signal.Signal<string, types.Atom<any>>

    local function deregister(key: string)
        if not self.Registry[key] then
            return
        end

        self.Registry[key] = nil
        self.AtomDeregistered:Fire(key)
    end

    --[=[
        Registers an atom under the given key. Key must be unique, otherwise it will throw an error.
    ]=]
    local function register<T>(key: string, atom: types.Atom<T>)
        local existingAtom = self.Registry[key]
        if existingAtom and existingAtom ~= atom then
            Logger.error(`An atom with the key "{key}" is already registered.`)
        end

        self.Registry[key] = atom

        self.AtomRegistered:Fire(key, atom)

        local function deregisterThisAtom()
            deregister(key)
        end

        return atom, deregisterThisAtom
    end

    --[=[
        Creates a new atom and registers it under the given key. If the key is already registered, it will return the existing atom and a deregister function.
    ]=]
    local function atom<T>(key: string, state: T, options: types.AtomOptions<T>?)
        if self.Registry[key] then
            return self.Registry[key], deregistersByKey[key]
        end

        local atom = Charm.atom(state, options)

        return register(key, atom)
    end

    local function get(key: string): types.Atom<any>?
        return self.Registry[key]
    end

    local function snapshot(): { [string]: types.Atom<any> }
        return table.clone(self.Registry)
    end

    self.register = register
    self.deregister = deregister
    self.atom = atom
    self.get = get
    self.snapshot = snapshot

    return self
end

return CharmRegistry
