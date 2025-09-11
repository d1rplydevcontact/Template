local Workspace = game:GetService("Workspace")
local BasePartUtil = {}

local Region = require(script.Parent.Parent.Parent.Region)
local Table = require(script.Parent.Parent.Parent.Table)

type Region = Region.Region

local DEFAULT_DRAW_PART_BETWEEN_POINTS_THICKNESS = 0.5

function BasePartUtil.drawPartBetweenPoints(p0: Vector3, p1: Vector3, thickness: number?)
    thickness = thickness or DEFAULT_DRAW_PART_BETWEEN_POINTS_THICKNESS

    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false

    local vector01 = p1 - p0
    part.CFrame = CFrame.new(p0, p1) -- Easy way to get the orientation we need
    part.Position = p0 + vector01 / 2
    part.Size = Vector3.new(0.5, 0.5, vector01.Magnitude)

    return part
end

function BasePartUtil.weld(part0: BasePart, part1: BasePart, parent: BasePart?, constraintType: string?)
    local constraint = Instance.new(constraintType or "WeldConstraint")
    constraint.Name = `{part1.Name} - {part0.Name}`
    constraint.Part0 = part0
    constraint.Part1 = part1
    constraint.Parent = parent or part0

    return constraint
end

function BasePartUtil.weldModel(model: Model, part: BasePart, constraintType: string?)
    for _, descendant in pairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            BasePartUtil.weld(part, descendant, part, constraintType)
        end
    end
end

---https://devforum.roblox.com/t/checking-if-a-part-is-in-a-cylinder-but-rotatable/1134952
local function isPointInCylinder(point: Vector3, cylinder: BasePart)
    local radius = math.min(cylinder.Size.Z, cylinder.Size.Y) * 0.5
    local height = cylinder.Size.X
    local relative = (point - cylinder.Position)

    local sProj = cylinder.CFrame.RightVector:Dot(relative)
    local vProj = cylinder.CFrame.RightVector * sProj
    local len = (relative - vProj).Magnitude

    return len <= radius and math.abs(sProj) <= (height * 0.5)
end

function BasePartUtil.isPointInPart(part: BasePart, point: Vector3)
    local shape: Enum.PartType = part:IsA("Part") and part.Shape or Enum.PartType.Block

    local vec = part.CFrame:PointToObjectSpace(point) -- point now in context of part
    local size = part.Size

    if shape == Enum.PartType.Block then
        return Region.isPointInRegion(Region.fromPart(part), point) --! untested
    elseif shape == Enum.PartType.Ball then
        local radius = math.min(size.X / 2, math.min(size.Y / 2, size.Z / 2))
        return vec.Magnitude <= radius
    elseif shape == Enum.PartType.Cylinder then
        return isPointInCylinder(point, part)
    else
        error(("Lacking API; no check for Part of shape %q (%s)"):format(shape.Name, debug.traceback()))
    end
end

local function isParentedToAWorldModel(instance: Instance): boolean
    if not instance.Parent then
        return false
    end

    if instance.Parent == game then
        return false
    end

    if instance.Parent:IsA("WorldModel") then
        return true
    end

    if instance:IsDescendantOf(Workspace) then
        return true
    end

    -- recurse
    return isParentedToAWorldModel(instance.Parent)
end

--[=[
    Where `part:GetConnectedParts()` will return all parts connected directly to `part`, this function
    will then recursively search all of those parts, return all parts of the same system (even if not connected directly).
]=]
function BasePartUtil.connectedPartsSystem(part: BasePart): { BasePart }
    local partsSet: { [BasePart]: boolean } = {}

    local function searchConnectedParts(currentPart: BasePart)
        if partsSet[currentPart] then
            return
        end

        partsSet[currentPart] = true

        --[=[
            Potential Error:

            Part is not parented to the Workspace or a WorldModel. GetConnectedParts will not include any other parts.
        ]=]
        if not isParentedToAWorldModel(currentPart) then
            return
        end

        for _, connectedPart in pairs(currentPart:GetConnectedParts()) do
            searchConnectedParts(connectedPart)
        end
    end

    searchConnectedParts(part)

    return Table.Sift.Dictionary.keys(partsSet)
end

return BasePartUtil
