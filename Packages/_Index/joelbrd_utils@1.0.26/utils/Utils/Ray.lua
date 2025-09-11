local RayUtil = {}

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local EPSILON = 1e-6

export type Plane = {
    Normal: Vector3,
    Point: Vector3,
}

local camera = Workspace.CurrentCamera

function RayUtil.plane(normal: Vector3, point: Vector3): Plane
    return {
        Normal = normal,
        Point = point,
    }
end

function RayUtil.raycastPlane(origin: Vector3, direction: Vector3, plane: Plane): Vector3?
    if direction.Magnitude == 0 then
        return nil
    end

    local dot = plane.Normal:Dot(direction)

    -- Check if the direction vector is parallel to the plane
    if math.abs(dot) < EPSILON then
        return nil
    end

    local t = (plane.Normal:Dot(plane.Point - origin)) / dot

    -- If t is negative, the intersection point is behind the ray's origin
    if t < 0 then
        return nil
    end

    return origin + direction * t
end

--[=[
    Assures no issues with GuiInset.
]=]
function RayUtil.viewportPointToRay()
    local screenPosition = UserInputService:GetMouseLocation()
    local ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
    return ray
end

return RayUtil
