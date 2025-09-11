local WorldDebug = {}

local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Directory = require(script.Parent.Directory)

WorldDebug.CollisionGroup = "joelbrd/utils.WorldDebug"

local DEFAULT_COLOR = Color3.fromRGB(255, 105, 105)
local DEFAULT_LIFETIME = 5
local DEFAULT_SIZE = Vector3.new(0.1, 0.1, 0.1)

local function getDebugPart() --todo object pool
    local part = Instance.new("Part")
    part.Name = "DebugPart"
    part.Anchored = true
    part.CanCollide = false
    part.Size = Vector3.new(0.1, 0.1, 0.1)
    part.Transparency = 0.5
    part.Parent = Directory.get("WorldDebug", Workspace)

    part.CollisionGroup = WorldDebug.CollisionGroup

    return part
end

function WorldDebug.ray(origin: Vector3, direction: Vector3, color: Color3, lifetime: number, raycastResult: RaycastResult?)
    local part = getDebugPart()
    part.Size = Vector3.new(0.1, 0.1, direction.Magnitude)
    part.CFrame = CFrame.lookAt(origin + direction / 2, origin + direction)
    part.Color = color

    local hitPart: Part
    if raycastResult then
        hitPart = getDebugPart()
        hitPart.Size *= 5
        hitPart.Shape = Enum.PartType.Ball
        hitPart.Position = raycastResult.Position
        hitPart.Color = color
    end

    task.delay(lifetime, function()
        part:Destroy()

        if hitPart then
            hitPart:Destroy()
        end
    end)
end

function WorldDebug.point(
    cframe: CFrame,
    options: {
        Color: Color3?,
        Lifetime: number?,
        Size: (Vector3 | number)?,
    }?
)
    local _options = options or {}
    local optionsSize = _options.Size
            and (typeof(_options.Size) == "number" and Vector3.new(_options.Size, _options.Size, _options.Size) or _options.Size)
        or nil

    local part = getDebugPart()
    part.CFrame = cframe
    part.Size = optionsSize or DEFAULT_SIZE
    part.Color = _options.Color or DEFAULT_COLOR

    task.delay(_options.Lifetime or DEFAULT_LIFETIME, function()
        part:Destroy()
    end)
end

function WorldDebug.cube(
    cube: {
        Bounds: {
            CornerMin: Vector3,
            CornerMax: Vector3,
        },
        Midpoint: Vector3,
    },
    color: Color3,
    lifetime: number
)
    local part = getDebugPart()

    local size = cube.Bounds.CornerMax - cube.Bounds.CornerMin

    part.Size = size
    part.Position = cube.Midpoint
    part.Color = color

    task.delay(lifetime, function()
        part:Destroy()
    end)
end

local function main()
    if RunService:IsServer() then
        PhysicsService:RegisterCollisionGroup(WorldDebug.CollisionGroup)
    end
end

main()

return WorldDebug
