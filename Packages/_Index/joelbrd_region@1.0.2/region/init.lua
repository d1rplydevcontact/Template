local Region = {}

export type Region = {
    CFrame: CFrame,
    Size: Vector3,
}

local CORNERS = {
    Vector3.new(0.5, 0.5, 0.5),
    Vector3.new(0.5, -0.5, 0.5),
    Vector3.new(-0.5, 0.5, 0.5),
    Vector3.new(-0.5, -0.5, 0.5),
    Vector3.new(0.5, 0.5, -0.5),
    Vector3.new(0.5, -0.5, -0.5),
    Vector3.new(-0.5, 0.5, -0.5),
    Vector3.new(-0.5, -0.5, -0.5),
}

local function vector3max(...: Vector3)
    local maxVector = {
        x = -math.huge,
        y = -math.huge,
        z = -math.huge,
    }

    for _, vector in pairs({ ... }) do
        maxVector.x = math.max(maxVector.x, vector.X)
        maxVector.y = math.max(maxVector.y, vector.Y)
        maxVector.z = math.max(maxVector.z, vector.Z)
    end

    return Vector3.new(maxVector.x, maxVector.y, maxVector.z)
end

local function vector3abs(vector: Vector3)
    return Vector3.new(math.abs(vector.X), math.abs(vector.Y), math.abs(vector.Z))
end

local function vector3sign(vector: Vector3)
    return Vector3.new(math.sign(vector.X), math.sign(vector.Y), math.sign(vector.Z))
end

local function cframeSetPosition(cframe: CFrame, position: Vector3)
    return cframe - cframe.Position + position
end

function Region.new(cframe: CFrame, size: Vector3): Region
    return {
        CFrame = cframe,
        Size = size,
    }
end

Region.identity = Region.new(CFrame.identity, Vector3.zero)

function Region.fromPart(part: BasePart)
    return Region.new(part.CFrame, part.Size)
end

function Region.fromModel(model: Model)
    return Region.new(model:GetPivot(), model:GetExtentsSize())
end

function Region.getCorners(region: Region)
    local corners = {}

    -- helper cframes for intermediate steps
    -- before finding the corners cframes.
    -- With corners I only need cframe.Position of corner cframes.

    -- face centers - 2 of 6 faces referenced
    local frontFaceCenter = (region.CFrame + region.CFrame.LookVector * region.Size.Z / 2)
    local backFaceCenter = (region.CFrame - region.CFrame.LookVector * region.Size.Z / 2)

    -- edge centers - 4 of 12 edges referenced
    local topFrontEdgeCenter = frontFaceCenter + frontFaceCenter.UpVector * region.Size.Y / 2
    local bottomFrontEdgeCenter = frontFaceCenter - frontFaceCenter.UpVector * region.Size.Y / 2
    local topBackEdgeCenter = backFaceCenter + backFaceCenter.UpVector * region.Size.Y / 2
    local bottomBackEdgeCenter = backFaceCenter - backFaceCenter.UpVector * region.Size.Y / 2

    -- corners
    corners.topFrontRight = (topFrontEdgeCenter + topFrontEdgeCenter.RightVector * region.Size.X / 2).Position
    corners.topFrontLeft = (topFrontEdgeCenter - topFrontEdgeCenter.RightVector * region.Size.X / 2).Position

    corners.bottomFrontRight = (bottomFrontEdgeCenter + bottomFrontEdgeCenter.RightVector * region.Size.X / 2).Position
    corners.bottomFrontLeft = (bottomFrontEdgeCenter - bottomFrontEdgeCenter.RightVector * region.Size.X / 2).Position

    corners.topBackRight = (topBackEdgeCenter + topBackEdgeCenter.RightVector * region.Size.X / 2).Position
    corners.topBackLeft = (topBackEdgeCenter - topBackEdgeCenter.RightVector * region.Size.X / 2).Position

    corners.bottomBackRight = (bottomBackEdgeCenter + bottomBackEdgeCenter.RightVector * region.Size.X / 2).Position
    corners.bottomBackLeft = (bottomBackEdgeCenter - bottomBackEdgeCenter.RightVector * region.Size.X / 2).Position

    return corners
end

function Region.getClosestPointInRegionToPoint(region: Region, position: Vector3): Vector3
    local cframe = region.CFrame
    local offset = cframe:PointToObjectSpace(position)
    local size = region.Size / 2

    local positionDistanceFromClosestPoint = vector3max(vector3abs(offset) - size, Vector3.new())
    return cframe:PointToWorldSpace(offset - (positionDistanceFromClosestPoint * vector3sign(offset)))
end

-- Will return a random point that lies in/on the boundary of the given part
function Region.getRandomPointInRegion(region: Region)
    return (region.CFrame * CFrame.new(
        math.random(-region.Size.X / 2, region.Size.X / 2),
        math.random(region.Size.Y / 2, region.Size.Y / 2),
        math.random(-region.Size.Z / 2, region.Size.Z / 2)
    )).Position
end

-- Get's the closest point on (region1) relative to (region2)
function Region.closestPoint(region1: Region, region2: Region): Vector3
    local closestPoint: Vector3
    local minDistance: number = math.huge

    local origin = region1.CFrame.Position

    for _, corner in pairs(CORNERS) do
        local closestPointToCorner = Region.getClosestPointInRegionToPoint(region1, region2.CFrame:PointToWorldSpace(region2.Size * corner))

        local distanceToCorner = (closestPointToCorner - origin).Magnitude
        if distanceToCorner < minDistance then
            minDistance = distanceToCorner
            closestPoint = closestPointToCorner
        end
    end

    return closestPoint
end

-- Return's the center point of a basepart's face
function Region.getSurfacePosition(region: Region, surfaceDirection: Vector3)
    local size = region.Size
    return region.CFrame:PointToWorldSpace((size / 2 * surfaceDirection * Vector3.new(1, 1, -1)))
end

--! untested.
function Region.isPointInRegion(region: Region, point: Vector3)
    local offset = region.CFrame:PointToObjectSpace(point)
    local size = region.Size / 2

    return math.abs(offset.X) <= size.X and math.abs(offset.Y) <= size.Y and math.abs(offset.Z) <= size.Z
end

function Region.isRegionContainedWithinRegion(parentRegion: Region, childRegion: Region)
    local corners = Region.getCorners(parentRegion)

    for _, corner in pairs(corners) do
        if not Region.isPointInRegion(childRegion, corner) then
            return false
        end
    end

    return true
end

function Region.isRegionIntersectingRegion(region1: Region, region2: Region)
    local corners = Region.getCorners(region1)

    for _, corner in pairs(corners) do
        if Region.isPointInRegion(region2, corner) then
            return true
        end
    end

    return false
end

function Region.shortestDistanceBetweenRegions(region1: Region, region2: Region)
    if Region.isRegionIntersectingRegion(region1, region2) then
        return 0
    end

    local closestPointRegion1 = Region.closestPoint(region1, region2)
    local closestPointRegion2 = Region.closestPoint(region2, region1)

    return (closestPointRegion1 - closestPointRegion2).Magnitude
end

--[=[
    Tries to fit the child region into the parent region by translating it's position.

    `options`:
    - `filter`: Check the proposed result against some criteria. Default `nil`
    - `contained`: If true, the child region must be fully contained within the parent region. Default `false`
    - `attempts`: The number of attempts to try fitting the child region. Default `20`

    Returns a boolean indicating if the child region was successfully fit into the parent region and the proposed region.
]=]
function Region.tryFitRegionInRegion(
    parentRegion: Region,
    childRegion: Region,
    options: {
        filter: ((proposedRegion: Region) -> boolean)?,
        contained: boolean?,
        attempts: number?,
    }
): (boolean, Region?)
    local _filter = options.filter or function()
        return true
    end

    if options.contained then
        local prevFilter = _filter
        _filter = function(proposedRegion: Region)
            return Region.isRegionContainedWithinRegion(parentRegion, proposedRegion) and prevFilter(proposedRegion)
        end
    end

    for _ = 1, (options.attempts or 20) do
        local randomPoint = Region.getRandomPointInRegion(parentRegion)
        local proposedRegion = Region.new(cframeSetPosition(childRegion.CFrame, randomPoint), childRegion.Size)
        if _filter(proposedRegion) then
            return true, proposedRegion
        end
    end

    return false
end

return Region
