local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(script.Parent.Parent.Charm)
local Signal = require(script.Parent.Parent.Signal)

export type Atom<T> = Charm.Atom<T>

export type AtomOptions<T> = {
    --[=[
		A function that determines whether the state has changed. By default,
		a strict equality check (`===`) is used.
	]=]
    equals: (prev: T, next: T) -> boolean,
}

--[=[
	A payload that can be sent from the server to the client to synchronize
	state between the two.

    Data keys should match the keys of the atoms being synchronized under the CharmRegistry.
]=]
export type DataSyncPayload = {
    registryId: string,
    data: {
        type: "init" | "patch",
        data: { [string]: any }, -- atomKey: atomPatchDiff
    },
}

--[=[
    A payload that can be sent from the client to the server to inform the server what
    atoms the client is interested in, or no longer interested in.
]=]
export type DataRequestPayload = {
    registryId: string,
    key: string,
    isRemoving: boolean?,
}

export type AtomMap = {
    [string]: Atom<any>,
}

export type SelectorsMap = {
    [string]: (state: any) -> any,
}

export type Registry = {
    Id: string,

    --- key: string, atom: Atom<any>
    AtomRegistered: Signal.Signal<string, Atom<any>>,

    --- key: string
    AtomDeregistered: Signal.Signal<string, Atom<any>>,

    Registry: AtomMap,

    --[=[
        Registers an atom directly under the given key. If an atom is already registered under that key, it will throw an error.

        - If there is an atom on the server/client registered under the same `key`, they will be synced.

        Then as a 2nd return value, it returns a deregister function that can be called to remove the atom from the registry. This is very important to call when the atom is no longer needed, to prevent memory leaks.

        @param key The key to register the atom under.
        @param state The initial state of the atom.
        @param options The options for the atom.
        @return The atom registered under the given key, and a function to deregister it.
    ]=]
    register: <T>(key: string, atom: Atom<T>) -> (Atom<T>, () -> ()),

    --[=[
        Deregisters the atom registered under the given key. If no atom is registered under that key, it will do nothing.

        @param key The key to deregister the atom from.
    ]=]
    deregister: (key: string) -> (),

    --[=[
        Friend of `Charm.atom`, but registers it internally under the given key.

        - If `key` is already registered to an atom, it will return the existing atom and a deregister function.
        - If there is an atom on the server/client registered under the same `key`, they will be synced.

        Then as a 2nd return value, it returns a deregister function that can be called to remove the atom from the registry. This is very important to call when the atom is no longer needed, to prevent memory leaks.

        @param key The key to register the atom under.
        @param state The initial state of the atom.
        @param options The options for the atom.
        @return The atom registered under the given key, and a function to deregister it.
    ]=]
    atom: <T>(key: string, state: T, options: AtomOptions<T>?) -> (Atom<T>, () -> ()),

    --[=[
        Returns the atom registered under the given key, or `nil` if no atom is registered under that key.
    ]=]
    get: (key: string) -> Atom<any>?,

    --[=[
        Returns a snapshot of all atoms registered in the self.Registry, at the time of the call.
    ]=]
    snapshot: () -> { [string]: Atom<any> },
}

export type PeekData = {
    success: boolean,
    err: string?,
    data: {
        [string]: string, -- registryId: atomKey (atomKey is in the `public` registry, and is an atom that contains the keys of all atoms in the given registryId)
    }?,
}

export type ServerOptions = {
    --[=[
		The interval at which to send patches to the client, in seconds.
		Defaults to `0` (patches are sent up to once per frame). Set to a
		negative value to disable automatic syncing.
	]=]
    interval: number?,
    --[=[
		When `true`, Charm will apply validation and serialize unsafe arrays
		to address remote event argument limitations. Defaults to `true`.

		This option should be disabled if your network library uses a custom
		serialization method (i.e. Zap, ByteNet) to prevent interference.
	]=]
    autoSerialize: boolean?,
}

export type ServerSyncer = {
    --[=[
		Sets up a subscription to each atom that schedules a patch to be sent to
		the client whenever the state changes. When a change occurs, the `callback`
		is called with the player and the payload to send.

		Note that the `payload` object should not be mutated. If you need to
		modify the payload, apply the changes to a copy of the object.

		@param callback The function to call when the state changes.
		@return A cleanup function that unsubscribes all listeners.
	]=]
    connect: (self: ServerSyncer, callback: (player: Player, payload: DataSyncPayload) -> ()) -> () -> (),

    --[=[
        Links the syncer to a registry, allowing it to automatically
        synchronize atoms registered in the registry.

        Optionally, you can provide a `selectorGenerator` function that, when given an atom key, can
        return a selector function that will be used to transform the state of the atom before sending it to the client.
        This was originally implemented to clean up cyclic tables for CharmHub debug functionality, but can be used for any purpose.
        
        @param registry The registry to link to.
        @param selectorGenerator? A function that takes an atom key and returns a selector function that transforms the state of the atom.
    ]=]
    linkRegistry: (self: ServerSyncer, registry: Registry, selectorGenerator: ((key: string) -> ((state: any) -> any)?)?) -> (),

    --[=[
        Informs the ServerSyncer that the client is either interested in or no longer interested in the atom.
        Implement your own networking solution to handle this.

        This is used to request synchronization of an atom, or to remove it from synchronization.
    ]=]
    onClientStateRequest: (self: ServerSyncer, player: Player, data: DataRequestPayload) -> (),
}

export type ClientSyncer = {
    --[=[
		Applies a patch or initializes the state of the atoms with the given payload from the server.

        Implement your own networking solution to handle this.
		
		@param ...payloads The patches or hydration payloads to apply.
	]=]
    sync: (self: ClientSyncer, data: DataSyncPayload) -> (),

    --[=[
        Links the client syncer to a registry, allowing it to automatically
        synchronize atoms registered in the registry.
        
        @param registry The registry to link to.
    ]=]
    linkRegistry: (self: ClientSyncer, registry: Registry) -> (),

    --[=[
        Sets a callback that is called when an atom is either added or removed. The logic of the callback is
        to inform the ServerSyncer that the client is either interested in or no longer interested in the atom. 
        
        Implement your own networking solution to handle this.
    ]=]
    setDataRequestCallback: (self: ClientSyncer, callback: (data: DataRequestPayload) -> ()) -> (),
}

export type ServerDebugger = {
    --[=[
        Sets a callback for indicating whether a player has permission to request and receive 
        debug data of all atoms.
    ]=]
    setHasPermission: (self: ServerDebugger, callback: (Player) -> boolean) -> (),

    --[=[
        Call and return this function for when any player requests peek data. Returns a
        correct response given their permission status.
    ]=]
    requestPeekData: (self: ServerDebugger, player: Player) -> PeekData,

    --[=[
        This registry will be debug synced!
    ]=]
    linkRegistry: (self: ServerDebugger, registry: Registry) -> (),

    --[=[
        This registry will be debug synced, but it will have extra processing run on it
        to ensure it is safe.

        In this instance, "Unsafe" means data that isn't automatically safe to be sent
        over the network e.g., cyclic tables.

        Implemented for CharmHub debug functionality.
    ]=]
    linkUnsafeRegistry: (self: ServerDebugger, registry: Registry) -> (),
}

export type ClientDebugger = {
    getDebugRegistries: (self: ClientDebugger) -> { Registry },
}

return nil
