--[=[
    A wrapper around the Players service.
]=]
local PlayersWrap = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Logger = require(script.Parent.Logger)
local Table = require(script.Parent.Table)
local Signal = require(script.Parent.Signal)
local Trove = require(script.Parent.Trove)
local MockPlayer = require(script.MockPlayer)
local Timer = require(script.Parent.Timer)
local Concur = require(script.Parent.Concur)
local Charm = require(script.Parent.Charm)
local Future = require(script.Parent.Future)
local CharmHub = require(script.Parent.CharmHub)
local Observers = require(script.Parent.Observers)
local Utils = require(script.Parent.Utils)

export type PlayerDataType = number | { number } | Player | { Player } | { Player | number }

local CLEAN_DUMMY_TROVE_EVERY_SECONDS = 1
local DESTROY_PLAYER_AFTER_SECONDS = 60 --for preventing roblox memory leaks.
local TAG_MOCK_PLAYER_CHARACTER = "MockCharacter"
local ATTRIBUTE_MOCK_PLAYER_CHARACTER_USER_ID = "MockCharacterUserId"
local DESTROY_CHARACTER_AFTER_DEATH_SECONDS = 5
local WAIT_FOR_PLAYER_TIMEOUT_SECONDS = 10

local dummyTrove = Trove.new()
local troves: { [Player]: Trove.Trove | false } = {} -- false indicates we have cleaned up this player's trove, but are waiting on `DESTROY_PLAYER_AFTER_SECONDS`. This was a clean way to handle trove creation/get/destruction.
local mockPlayersByUserId: { [number]: Player } = {}

--- Using CharmHub, this state will automatically be synced across clients.
local mockUserIds: Charm.Atom<{ [string]: string }> = CharmHub.Public.atom(`PlayersWrap/MockUserIds`, {})

local createMockPlayerCharacter: ((player: Player) -> Model?)?

local function addMockUserId(userId: number)
    mockUserIds(function(state)
        if state[tostring(userId)] then
            return state
        end

        local newState = table.clone(state)
        newState[tostring(userId)] = tostring(userId)
        return newState
    end)
end

local function removeMockUserId(userId: number)
    mockUserIds(function(state)
        if not state[tostring(userId)] then
            return state
        end

        local newState = table.clone(state)
        newState[tostring(userId)] = nil
        return newState
    end)
end

PlayersWrap.LocalUserId = Players.LocalPlayer and Players.LocalPlayer.UserId or nil

function PlayersWrap:OnPlayerAdded(inclusive: boolean, callback: (player: Player, isMockPlayer: boolean) -> (), ignoreMockPlayers: boolean?)
    -- Annoying bulky logic, but ensures we run callback exactly once for each player.
    -- We were having it run twice in Studio environments on startup.
    local runForPlayers: { [Player]: true }? = {}
    local connection = PlayersWrap.PlayerAdded:Connect(function(player, isMockPlayer)
        if isMockPlayer and ignoreMockPlayers then
            return
        end

        if runForPlayers then
            runForPlayers[player] = true
        end

        callback(player, isMockPlayer)
    end)

    if inclusive then
        for _, player in pairs(PlayersWrap:GetPlayers(ignoreMockPlayers)) do
            if runForPlayers and runForPlayers[player] then
                continue
            end

            task.spawn(callback, player, PlayersWrap:IsMockPlayer(player))
        end

        runForPlayers = nil
    end

    return connection
end

--[=[
    Run a callback when a player joins. This can return a function that will be called when the player leaves.
]=]
function PlayersWrap:OnPlayer(
    inclusive: boolean,
    added: (player: Player, isMockPlayer: boolean) -> (() -> ())?,
    ignoreMockPlayers: boolean?
)
    local removeDatas: { [Player]: { leaveConnection: RBXScriptConnection, removeCallback: () -> () } } = {}

    local connection = PlayersWrap:OnPlayerAdded(inclusive, function(player, _isMockPlayer)
        local removed = added(player, _isMockPlayer)
        if not removed then
            return
        end

        local removeData = { removeCallback = removed }

        removeData.leaveConnection = PlayersWrap.PlayerRemoving:Connect(function(removingPlayer)
            if removingPlayer == player then
                removeData.leaveConnection:Disconnect()
                removed()

                removeDatas[player] = nil
            end
        end)
    end, ignoreMockPlayers)

    return function()
        connection:Disconnect()

        for _, removeData in pairs(removeDatas) do
            removeData.leaveConnection:Disconnect()
            removeData.removeCallback()
        end

        removeDatas = {}
    end
end

--[=[
    If inclusive is true, the callback will be called on all existing characters also
]=]
function PlayersWrap:OnCharacterAdded(
    inclusive: boolean,
    callback: (player: Player, character: Model) -> (() -> ())?,
    ignoreMockPlayers: boolean?
)
    local function onPlayerAdded(player: Player)
        local cleanup: (() -> ())? = nil

        local function runCallback()
            if cleanup then
                Concur.spawn(cleanup)
                cleanup = nil
            end

            if not player.Character then
                Logger.warn(`wat`)
                return
            end

            cleanup = callback(player, player.Character)
        end

        if player.Character and inclusive then
            runCallback()
            task.wait()
        end

        local connection = player.CharacterAdded:Connect(runCallback)

        return function()
            connection:Disconnect()
            if cleanup then
                cleanup()
            end
        end
    end

    return PlayersWrap:OnPlayerAdded(true, onPlayerAdded, ignoreMockPlayers)
end

--[=[
    Returns the Trove instance for the given player - this trove gets destroyed as soon as the player leaves the game.

    @param player Player The player to get the Trove for.
    @return Trove The Trove instance.
]=]
function PlayersWrap:GetTrove(player: Player)
    if troves[player] then
        return troves[player] :: Trove.Trove
    end

    if troves[player] == false then
        Logger.warn(`Trove for {player.Name} was cleaned up, but we are waiting on DESTROY_PLAYER_AFTER_SECONDS to destroy it.`)
        return dummyTrove
    end

    if player.Parent == nil then
        Logger.warn(`Player {player.Name} has no parent, returning dummy trove.`)
        return dummyTrove
    end

    local trove = Trove.new()
    troves[player] = trove

    return trove
end

local function buildMockPlayerCharacter(player: Player)
    if not createMockPlayerCharacter then
        return
    end

    local character = createMockPlayerCharacter(player)
    if not character then
        return
    end

    character:SetAttribute(ATTRIBUTE_MOCK_PLAYER_CHARACTER_USER_ID, player.UserId)
    character:AddTag(TAG_MOCK_PLAYER_CHARACTER)
end

--[=[
    All mock player userIds are negative to avoid collisions with real players.

    If `userId` is already a mock player, it will return the existing mock player.

    Will yield as we run some Async functions e.g., `GetNameFromUserIdAsync`.
]=]
function PlayersWrap:CreateMockPlayer(_userId: number?)
    local userId = _userId or math.random(100, 2 ^ 31 - 1) -- === 2147483647, which is a valid userId
    userId = -math.abs(userId)

    local existingMockPlayer = mockPlayersByUserId[userId]
    if existingMockPlayer then
        return existingMockPlayer
    end

    local mockPlayer = MockPlayer.new(userId) :: Player
    mockPlayersByUserId[userId] = mockPlayer
    addMockUserId(userId)

    PlayersWrap.PlayerAdded:Fire(mockPlayer, true)

    mockPlayer.Destroying:Once(function()
        removeMockUserId(userId)
    end)

    return mockPlayer
end

function PlayersWrap:IsMockPlayer(player: Player)
    return typeof(player) == "table" and player.IsMockPlayer and true or false
end

function PlayersWrap:IsRealPlayer(player: Player)
    if not PlayersWrap:IsPlayer(player) then
        Logger.warn(`Passed argument is not a player: {Table.ToString(player)}`)
        return false
    end

    return not PlayersWrap:IsMockPlayer(player)
end

--[=[
    Returns true if the player is active in the game (i.e., has a parent).
    This is useful to check if the player is currently in the game or has left (or in the case of mock players, destroyed.)
]=]
function PlayersWrap:IsActive(player: Player)
    if not PlayersWrap:IsPlayer(player) then
        Logger.warn(`Passed argument is not a player: {Table.ToString(player)}`)
        return false
    end

    return player.Parent ~= nil
end

function PlayersWrap:IsPlayer(possiblePlayer: any)
    if typeof(possiblePlayer) == "Instance" then
        return possiblePlayer:IsA("Player")
    end

    if typeof(possiblePlayer) == "table" then
        return PlayersWrap:IsMockPlayer(possiblePlayer)
    end

    return false
end

function PlayersWrap:GetPlayerByUserId(userId: number, ignoreMockPlayers: boolean?)
    if ignoreMockPlayers == true then
        return Players:GetPlayerByUserId(userId)
    end

    return mockPlayersByUserId[userId] or Players:GetPlayerByUserId(userId)
end

--- Default timeout is 10 seconds.
function PlayersWrap:WaitForPlayerWithUserId(userId: number, timeoutSeconds: number?): Future.Future<Player?>
    local player = PlayersWrap:GetPlayerByUserId(userId)
    if player then
        return Future.new(function()
            return player
        end)
    end

    return Future.new(function()
        local _timeoutSeconds = timeoutSeconds or WAIT_FOR_PLAYER_TIMEOUT_SECONDS

        local trove = Trove.new()
        local player: Player? = nil

        trove:Add(PlayersWrap.PlayerAdded:Connect(function(_player)
            if _player.UserId == userId then
                player = _player
            end
        end))

        player = PlayersWrap:GetPlayerByUserId(userId)

        local start = tick()
        while true do
            if player then
                trove:Destroy()
                return player
            end

            if tick() - start >= _timeoutSeconds then
                trove:Destroy()
                Logger.warn(`Timed out waiting for player with userId {userId}.`)
                return nil
            end

            task.wait()
        end
    end)
end

function PlayersWrap:GetPlayers(ignoreMockPlayers: boolean?)
    local players: { Player } = {}

    for _, player in pairs(Players:GetPlayers()) do
        table.insert(players, player)
    end

    if ignoreMockPlayers ~= true then
        for _, mockPlayer in pairs(mockPlayersByUserId) do
            table.insert(players, mockPlayer)
        end
    end

    return players
end

function PlayersWrap:GetMockPlayers()
    return Table.Values(mockPlayersByUserId)
end

function PlayersWrap:GetPlayersFromDataType(data: PlayerDataType, ignoreMockPlayers: boolean?): { Player }
    if typeof(data) == "number" then
        return { PlayersWrap:GetPlayerByUserId(data, ignoreMockPlayers) }
    end

    if PlayersWrap:IsPlayer(data) then
        if ignoreMockPlayers and PlayersWrap:IsMockPlayer(data :: Player) then
            return {}
        end

        return { data :: Player }
    end

    if typeof(data) == "table" then
        local players: { Player } = {}
        for _, playerOrUserId in pairs(data) do
            table.insert(players, PlayersWrap:GetPlayersFromDataType(playerOrUserId, ignoreMockPlayers)[1])
        end
        return players
    end

    return {}
end

function PlayersWrap:GetNameFromUserIdAsync(userId: number): string?
    local player = PlayersWrap:GetPlayerByUserId(userId)
    if player then
        return player.Name
    end

    local success, response = pcall(function()
        return Players:GetNameFromUserIdAsync(userId)
    end)
    if success then
        return response
    end

    Logger.warn(`Failed to GetNameFromUserIdAsync for userId {userId}. Error: {response}`)

    return nil
end

function PlayersWrap:GetPlayerFromCharacter(character: Model, ignoreMockPlayers: boolean?): Player?
    for _, player in pairs(PlayersWrap:GetPlayers(ignoreMockPlayers)) do
        if player.Character == character then
            return player
        end
    end

    return nil
end

function PlayersWrap:SetMockPlayerCharacterHook(createCharacterHook: (player: Player) -> Model?)
    if RunService:IsClient() then
        Logger.error(`SetMockPlayerCharacterHook must be called on the server.`)
    end

    createMockPlayerCharacter = createCharacterHook

    for _, mockPlayer in pairs(PlayersWrap:GetMockPlayers()) do
        if mockPlayer.Character then
            mockPlayer.Character:Destroy()
        end

        buildMockPlayerCharacter(mockPlayer)
    end
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

PlayersWrap.PlayerAdded = Signal.new() :: Signal.Signal<Player, boolean> -- (player: Player, isMockPlayer: boolean)
Players.PlayerAdded:Connect(function(player)
    PlayersWrap.PlayerAdded:Fire(player, false)
end)

PlayersWrap.PlayerRemoving = Signal.new() :: Signal.Signal<Player, boolean> -- (player: Player, isMockPlayer: boolean)
Players.PlayerRemoving:Connect(function(player)
    PlayersWrap.PlayerRemoving:Fire(player, false)
end)

-------------------------------------------------------------------------------
-- Logic
-------------------------------------------------------------------------------

Concur.spawn(function()
    -- Trove Cleanup on player removing..
    PlayersWrap:OnPlayer(true, function(player)
        return function()
            local trove = PlayersWrap:GetTrove(player)
            if trove then
                trove:Destroy()
                troves[player] = false
            end

            -- possible memory leak from a Roblox bug a while back, not sure if it still exists but just to play it safe..
            task.delay(DESTROY_PLAYER_AFTER_SECONDS, function()
                Logger.trace(`Destroying {player.Name} Player object.`)
                player:Destroy()
                troves[player] = nil
            end)
        end
    end)

    Timer.Simple(CLEAN_DUMMY_TROVE_EVERY_SECONDS, function()
        dummyTrove:Clean()
    end)

    -- Using `mockUserIds` as a source of truth, create/destroy mock players as needed.
    Charm.observe(mockUserIds, function(stringUserId)
        local userId = tonumber(stringUserId)
        if not userId then
            Logger.warn(`Invalid userId {stringUserId} in mockUserIds.`)
            return
        end

        local isRemoved = false
        local function remove()
            local mockPlayer = mockPlayersByUserId[userId]
            if not mockPlayer then
                Logger.warn(`Mock player with userId {userId} not found.`)
                return
            end

            mockPlayersByUserId[userId] = nil

            PlayersWrap.PlayerRemoving:Fire(mockPlayer, true)
        end

        Concur.spawn(function()
            PlayersWrap:CreateMockPlayer(userId) -- yields.. cannot yield in a Charm.observe callback.
            if isRemoved then
                remove()
                return
            end
        end)

        return function()
            isRemoved = true
            remove()
        end
    end)

    -- Build mock player characters
    PlayersWrap.PlayerAdded:Connect(function(player, isMockPlayer)
        if not isMockPlayer then
            return
        end

        buildMockPlayerCharacter(player)
    end)

    --- Lifecycles of mock player characters.
    Observers.observeTag(TAG_MOCK_PLAYER_CHARACTER, function(mockCharacter: Model)
        local userId = mockCharacter:GetAttribute(ATTRIBUTE_MOCK_PLAYER_CHARACTER_USER_ID)
        if not userId then
            Logger.warn(`Mock character {mockCharacter.Name} does not have the attribute {ATTRIBUTE_MOCK_PLAYER_CHARACTER_USER_ID}.`)
            return
        end

        --- Wait incase the character was synced to the client before the mock player was created.
        --- Yielding is allowed in `Observers`.
        local player = PlayersWrap:WaitForPlayerWithUserId(userId):Await()
        if not (player and PlayersWrap:IsMockPlayer(player)) then
            Logger.warn(`Mock character {mockCharacter:GetFullName()} has no mock player with userId {userId}.`)
            return
        end

        if player.Character then
            player.Character:Destroy()
        end

        player.Character = mockCharacter
        player.CharacterAdded:Fire(mockCharacter)

        local trove = Trove.new()

        trove:Add(mockCharacter.AncestryChanged:Connect(function()
            local isDestroyed = mockCharacter.Parent == nil
            if not isDestroyed then
                return
            end

            player.Character = nil
            player.CharacterRemoving:Fire(mockCharacter)
        end))

        local humanoid = Utils.Character.humanoid(mockCharacter)
        if humanoid then
            trove:Add(humanoid.Died:Connect(function()
                Concur.delay(DESTROY_CHARACTER_AFTER_DEATH_SECONDS, function()
                    if mockCharacter.Parent then
                        mockCharacter:Destroy()
                    end
                end)
            end))
        end

        return function()
            trove:Destroy()
        end
    end, { Workspace })
end)

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

type PlayersWrapper = typeof(PlayersWrap)
wrapRobloxService(PlayersWrap, Players)

return PlayersWrap :: PlayersWrapper & Players
