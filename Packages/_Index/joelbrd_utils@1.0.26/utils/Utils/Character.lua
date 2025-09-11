local Character = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Table = require(script.Parent.Parent.Parent.Table)
local BasePart = require(script.Parent.BasePart)
local Concur = require(script.Parent.Parent.Parent.Concur)
local Future = require(script.Parent.Parent.Parent.Future)
local Trove = require(script.Parent.Parent.Parent.Trove)
local CFrameUtil = require(script.Parent.CFrame)

type CharacterOrPlayer = Model | Player

local DEFAULT_TIMEOUT = 10

local function character(characterOrPlayer: CharacterOrPlayer): Model?
    if characterOrPlayer:IsA("Model") then
        return characterOrPlayer
    elseif characterOrPlayer:IsA("Player") then
        return characterOrPlayer.Character
    end
    return nil
end

--[=[
    Get the character of a player or a Model representing a character.

    If found, and `callback` is provided, it will be called with the character as an argument on a separate thread.
]=]
function Character.character(characterOrPlayer: CharacterOrPlayer, callback: (character: Model) -> ()?): Model?
    local char = character(characterOrPlayer)
    if char and callback then
        Concur.spawn(callback, char)
    end
    return char
end

function Character.futureCharacter(characterOrPlayer: CharacterOrPlayer, timeout: number?): Future.Future<Model?>
    local char = Character.character(characterOrPlayer)
    if char then
        return Future.new(function()
            return char
        end)
    end

    local _timeout = timeout or DEFAULT_TIMEOUT
    return Future.new(function()
        local player = characterOrPlayer:IsA("Player") and characterOrPlayer or nil
        if not player then
            return nil
        end

        local trove = Trove.new()

        trove:Add(player.CharacterAdded:Connect(function(character)
            char = character
        end))

        char = player.Character

        local start = tick()
        while true do
            if char then
                trove:Destroy()
                return char
            end

            if tick() - start > _timeout then
                trove:Destroy()
                return nil
            end

            task.wait()
        end
    end)
end

--[=[
    We verify if the provided instance is a character by checking for both a Humanoid and a HumanoidRootPart.
]=]
function Character.isCharacter(characterOrPlayer: CharacterOrPlayer | any)
    if Character.humanoid(characterOrPlayer) and Character.humanoidRootPart(characterOrPlayer) then
        return true
    end

    return false
end

--[=[
    Get the Humanoid of a character or player.

    If found, and `callback` is provided, it will be called with the Humanoid as an argument on a separate thread.
]=]
function Character.humanoid(characterOrPlayer: CharacterOrPlayer, callback: (humanoid: Humanoid) -> ()?): Humanoid?
    local char = character(characterOrPlayer)
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid and callback then
            Concur.spawn(callback, humanoid)
        end
        return humanoid
    end
    return nil
end

function Character.futureHumanoid(characterOrPlayer: CharacterOrPlayer, timeout: number?): Future.Future<Humanoid?>
    local humanoid = Character.humanoid(characterOrPlayer)
    if humanoid then
        return Future.new(function()
            return humanoid
        end)
    end

    local _timeout = timeout or DEFAULT_TIMEOUT
    return Future.new(function()
        local start = tick()
        local character = Character.futureCharacter(characterOrPlayer, _timeout):Await()

        if not character then
            return nil
        end

        local humanoid = Character.humanoid(characterOrPlayer)
        if humanoid then
            return humanoid
        end

        local trove = Trove.new()

        trove:Add(character.ChildAdded:Connect(function(child)
            humanoid = Character.humanoid(characterOrPlayer) -- Check if the new child was a Humanoid
        end))

        humanoid = Character.humanoid(characterOrPlayer) -- for safety after making the connection

        while true do
            if humanoid then
                trove:Destroy()
                return humanoid
            end

            if tick() - start > _timeout then
                trove:Destroy()
                return nil
            end

            task.wait()
        end
    end)
end

--[=[
    Get the HumanoidRootPart of a character or player.

    If found, and `callback` is provided, it will be called with the HumanoidRootPart as an argument on a separate thread.
]=]
function Character.humanoidRootPart(characterOrPlayer: CharacterOrPlayer, callback: (humanoidRootPart: BasePart) -> ()?): BasePart?
    local char = character(characterOrPlayer)
    if char then
        local humanoidRootPart = char:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart and callback then
            Concur.spawn(callback, humanoidRootPart)
        end
        return humanoidRootPart
    end
    return nil
end

function Character.futureHumanoidRootPart(characterOrPlayer: CharacterOrPlayer, timeout: number?): Future.Future<BasePart?>
    local humanoidRootPart = Character.humanoidRootPart(characterOrPlayer)
    if humanoidRootPart then
        return Future.new(function()
            return humanoidRootPart
        end)
    end

    local _timeout = timeout or DEFAULT_TIMEOUT
    return Future.new(function()
        local start = tick()
        local character = Character.futureCharacter(characterOrPlayer, _timeout):Await()

        if not character then
            return nil
        end

        humanoidRootPart = Character.humanoidRootPart(characterOrPlayer)

        if humanoidRootPart then
            return humanoidRootPart
        end

        local trove = Trove.new()

        trove:Add(character.ChildAdded:Connect(function()
            humanoidRootPart = Character.humanoidRootPart(characterOrPlayer) -- Check if the new child was a HumanoidRootPart
        end))

        while true do
            if humanoidRootPart then
                trove:Destroy()
                return humanoidRootPart
            end

            if tick() - start > _timeout then
                trove:Destroy()
                return nil
            end

            task.wait()
        end
    end)
end

function Character.isAlive(characterOrPlayer: CharacterOrPlayer)
    local character = Character.character(characterOrPlayer)
    local humanoid = Character.humanoid(characterOrPlayer)

    return (
        character
        and character.Parent
        and humanoid
        and humanoid.Parent
        and humanoid.Health > 0
        and Character.humanoidRootPart(characterOrPlayer)
        and characterOrPlayer.Parent
    )
end

function Character.parts(characterOrPlayer: CharacterOrPlayer): { BasePart }
    local char = character(characterOrPlayer)
    if not char then
        return {}
    end

    return Table.Sift.Array.filter(char:GetChildren(), function(child)
        return child:IsA("BasePart") or child:IsA("MeshPart")
    end)
end

function Character.mass(characterOrPlayer: CharacterOrPlayer): number
    local humanoidRootPart = Character.humanoidRootPart(characterOrPlayer)
    if not humanoidRootPart then
        return 1 -- not zero to avoid division by zero in some calculations
    end

    local parts = BasePart.connectedPartsSystem(humanoidRootPart)
    local totalMass = 0

    for _, part in ipairs(parts) do
        if part:IsA("BasePart") then
            totalMass += part:GetMass()
        end
    end

    return totalMass
end

function Character.resetVelocity(characterOrPlayer: CharacterOrPlayer)
    local parts = Character.parts(characterOrPlayer)
    for _, part in pairs(parts) do
        part.AssemblyLinearVelocity = Vector3.zero
        part.AssemblyAngularVelocity = Vector3.zero
    end
end

function Character.pivotTo(characterOrPlayer: CharacterOrPlayer, cframe: CFrame): boolean
    local character = Character.character(characterOrPlayer)
    if not character then
        return false
    end

    character:PivotTo(cframe)
    return true
end

function Character.pivotToPosition(characterOrPlayer: CharacterOrPlayer, position: Vector3): boolean
    local character = Character.character(characterOrPlayer)
    if not character then
        return false
    end

    character:PivotTo(CFrameUtil.setPosition(character:GetPivot(), position))
    return true
end

local function getRandomPointOnTopSurface(part: BasePart): Vector3
    local size = part.Size
    local cframe = part.CFrame

    -- Get local offsets for X and Z
    local xOffset = (math.random() - 0.5) * size.X
    local zOffset = (math.random() - 0.5) * size.Z
    local yOffset = size.Y / 2

    -- Local point on top surface
    local localPoint = Vector3.new(xOffset, yOffset, zOffset)
    -- Convert to world position
    return cframe:PointToWorldSpace(localPoint)
end

function Character.pivotOntoPart(
    characterOrPlayer: CharacterOrPlayer,
    part: BasePart,
    options: {
        RandomisePositionOnPart: boolean?,
        Offset: Vector3?,
    }?
)
    local character = Character.character(characterOrPlayer)
    if not character then
        return false
    end

    local position: Vector3 = nil
    if options and options.RandomisePositionOnPart then
        position = getRandomPointOnTopSurface(part)
    else
        position = part.Position
    end

    local characterExtents = character:GetExtentsSize()
    position += Vector3.new(0, characterExtents.Y / 2, 0)

    local offset = options and options.Offset or Vector3.zero
    position += offset

    return Character.pivotToPosition(character, position)
end

--[=[
    Given any instance, will traverse up the hierarchy until it finds a Model that is a character, or nil if none found.

    `instance` can also be the character itself, in which case it will be returned if valid.
]=]
function Character.characterFromInstance(instance: Instance): Model?
    local check: Instance? = instance

    while true do
        if check == nil then
            return nil
        end

        if check:IsA("Model") then
            if Character.isCharacter(check) then
                return check :: Model
            end
        end

        -- too far up the hierarchy
        if check == game or check == Workspace then
            return nil
        end

        check = check.Parent
    end

    return nil
end

return Character
