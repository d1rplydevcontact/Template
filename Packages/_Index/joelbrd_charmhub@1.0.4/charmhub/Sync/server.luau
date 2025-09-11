local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(script.Parent.Parent.Parent.Charm)
local Logger = require(script.Parent.Parent.Parent.Logger)
local interval = require(script.Parent.interval)
local patch = require(script.Parent.patch)
local types = require(script.Parent.Parent.types)

type AtomMap = types.AtomMap
type SelectorsMap = types.SelectorsMap
type DataSyncPayload = types.DataSyncPayload
type DataRequestPayload = types.DataRequestPayload
type ServerOptions = types.ServerOptions
type ServerSyncer = types.ServerSyncer

--[=[
	Creates a `ServerSyncer` object that sends patches to the client and
	hydrates the client's state.
	
	@param options The atoms to synchronize with the client.
	@return A `ServerSyncer` object.
]=]
local function server(options: ServerOptions): ServerSyncer
    local self = {} :: ServerSyncer

    local autoSerialize = options.autoSerialize ~= false
    local syncRate = options.interval or 0

    local registries: { [string]: types.Registry } = {}
    local atoms: { [string]: types.AtomMap } = {} -- registryId: { key: Atom<any> }
    local atomSelectors: { [string]: types.SelectorsMap } = {} -- registryId: { key: (state: any) -> any }
    local unsubscribers: { [string]: { [string]: () -> () } } = {} -- registryId: key: unsubscribe function
    local clientInterest: { [Player]: { [string]: { [string]: true } } } = {} -- userId: registryId: atomKey: true

    local function getAtom(registryId: string, key: string): Charm.Atom<any>?
        local registryAtoms = atoms[registryId]
        if not registryAtoms then
            return nil
        end

        return registryAtoms[key]
    end

    local function getSelector(registryId: string, key: string): ((state: any) -> any)?
        local registrySelectors = atomSelectors[registryId]
        if not registrySelectors then
            return nil
        end

        return registrySelectors[key]
    end

    local sync: (player: Player, payload: DataSyncPayload) -> ()

    local previousSnapshot = {}
    local currentSnapshot = {}
    local changed = false

    local function readState(registryId: string, key: string): any
        local atom = getAtom(registryId, key)
        if not atom then
            Logger.warn(`No atom registered with the key "{key}" in registry "{registryId}".`)
            return nil
        end

        local selector = getSelector(registryId, key)
        if selector then
            return selector(atom())
        end

        return atom()
    end

    local function hydrate(player: Player, registryId: string, key: string)
        assert(sync, "connect() must be called before hydrate()")

        local atom = getAtom(registryId, key)
        if not atom then
            Logger.warn(`No atom registered with the key "{key}". Skipping hydration for this key.`)
            return
        end

        sync(player, {
            registryId = registryId,
            data = {
                type = "init",
                data = {
                    [key] = readState(registryId, key),
                },
            },
        })
    end

    local function addAtoms(registryId: string, newAtoms: AtomMap, selectorsMap: SelectorsMap?)
        atoms[registryId] = atoms[registryId] or {}
        atomSelectors[registryId] = atomSelectors[registryId] or {}

        for key, atom in next, newAtoms do
            atoms[registryId][key] = atom
            atomSelectors[registryId][key] = selectorsMap and selectorsMap[key]

            local unsubscribe = Charm.subscribe(atom, function(state)
                currentSnapshot[registryId] = currentSnapshot[registryId] or {}
                currentSnapshot[registryId][key] = readState(registryId, key)
                changed = true
            end)
            unsubscribers[key] = unsubscribe

            -- If any players have already expressed interest in this atom, send it over baby!
            for player, interest in next, clientInterest do
                if not interest[registryId] then
                    continue
                end

                if not interest[registryId][key] then
                    continue
                end

                hydrate(player, registryId, key)
            end
        end
    end

    local function removeAtoms(registryId: string, oldAtoms: AtomMap)
        atoms[registryId] = atoms[registryId] or {} -- failsafe, shouldn't be needed.
        atomSelectors[registryId] = atomSelectors[registryId] or {}

        -- for key, atom in next, oldAtoms do
        --     atoms[registryId][key] = nil
        --     stateRequestCallback(key, true)
        -- end

        for key, atom in next, oldAtoms do
            if not atoms[registryId][key] then
                continue
            end

            local unsubscriber = unsubscribers[registryId][key] and unsubscribers[registryId]
            if unsubscriber then -- should always exist, but failsafe.
                unsubscriber()
                unsubscribers[registryId][key] = nil
            else
                Logger.warn(`No unsubscribe function found for atom "{key}" in registry "{registryId}".`)
            end

            atoms[registryId][key] = nil
            atomSelectors[registryId][key] = nil
        end
    end

    function self:linkRegistry(registry: types.Registry, selectorGenerator: ((key: string) -> ((state: any) -> any)?)?)
        if registries[registry.Id] then
            return
        end

        registries[registry.Id] = registry

        registry.AtomRegistered:Connect(function(key, atom)
            local selector = selectorGenerator and selectorGenerator(key)

            addAtoms(registry.Id, { [key] = atom }, { [key] = selector })
        end)
        registry.AtomDeregistered:Connect(function(key)
            removeAtoms(registry.Id, { [key] = registry.Registry[key] })
        end)

        local selectorsMap: SelectorsMap = {}
        if selectorGenerator then
            for key, _ in pairs(registry.Registry) do
                local selector = selectorGenerator(key)
                if selector then
                    selectorsMap[key] = selector
                end
            end
        end

        addAtoms(registry.Id, registry.Registry, selectorsMap)
    end

    function self:onClientStateRequest(player: Player, data: DataRequestPayload)
        clientInterest[player] = clientInterest[player] or {}
        clientInterest[player][data.registryId] = clientInterest[player][data.registryId] or {}

        local interest = clientInterest[player][data.registryId]

        if data.isRemoving then
            interest[data.key] = nil
            return
        end

        -- Player is interested in this atom...
        interest[data.key] = true

        if getAtom(data.registryId, data.key) then
            hydrate(player, data.registryId, data.key)
        end
    end

    function self:connect(callback: (player: Player, payload: DataSyncPayload) -> ())
        local subscriptions = {}

        sync = callback

        local disconnect = interval(function()
            if not changed then
                return
            end

            local patchDiffByRegistryId: { [string]: table } = {}
            for registryId, snapshot in next, currentSnapshot do
                patchDiffByRegistryId[registryId] = patch.diff(previousSnapshot[registryId] or {}, snapshot, autoSerialize)

                previousSnapshot[registryId] = table.clone(snapshot)
            end

            changed = false

            for player, interests in next, clientInterest do
                for registryId, interest in next, interests do
                    local payload: DataSyncPayload = {
                        registryId = registryId,
                        data = {
                            type = "patch",
                            data = {},
                        },
                    }

                    for atomKey, _ in pairs(interest) do
                        local atomDiff = patchDiffByRegistryId[registryId] and patchDiffByRegistryId[registryId][atomKey]
                        if not atomDiff then
                            continue
                        end

                        payload.data.data[atomKey] = atomDiff
                    end

                    callback(player, payload)
                end
            end
        end, syncRate)

        return function()
            disconnect()

            for _, unsubscribe in next, subscriptions do
                unsubscribe()
            end
        end
    end

    local function main()
        Players.PlayerRemoving:Connect(function(player)
            clientInterest[player] = nil
        end)
    end

    main()

    return self
end

return server
