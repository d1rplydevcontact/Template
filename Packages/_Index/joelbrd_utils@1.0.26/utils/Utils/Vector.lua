local Vector = {}

local Math = require(script.Parent.Parent.Parent.Math)

type Vector = Vector2 | Vector3

Vector.Vector2 = {}

Vector.Vector2.huge = Vector2.new(math.huge, math.huge)

function Vector.Vector2.serialize(vector2: Vector2)
    return {
        x = vector2.X,
        y = vector2.Y,
    }
end

function Vector.Vector2.serializeArray(vector2Array: { Vector2 })
    local serializedArray = {}
    for _, vector2 in ipairs(vector2Array) do
        table.insert(serializedArray, Vector.Vector2.serialize(vector2))
    end
    return serializedArray
end

function Vector.Vector2.deserialize(serializedVector2: { x: number, y: number })
    return Vector2.new(serializedVector2.x, serializedVector2.y)
end

function Vector.Vector2.deserializeArray(serializedVector2Array: { { x: number, y: number } })
    local vector2Array = {}
    for _, serializedVector2 in ipairs(serializedVector2Array) do
        table.insert(vector2Array, Vector.Vector2.deserialize(serializedVector2))
    end
    return vector2Array
end

function Vector.Vector2.iterateRange(vector0: Vector2, vector1: Vector2, callback: (vector: Vector2) -> ())
    local minX = math.min(vector0.X, vector1.X)
    local maxX = math.max(vector0.X, vector1.X)
    local minY = math.min(vector0.Y, vector1.Y)
    local maxY = math.max(vector0.Y, vector1.Y)

    for x = minX, maxX do
        for y = minY, maxY do
            callback(Vector2.new(x, y))
        end
    end
end

--[=[
    Note: Assume this will create floating point errors so round the result if you need integers.
]=]
function Vector.Vector2.rotate(vector: { x: number, y: number }, pivot: { x: number, y: number }, angleDegrees: number)
    -- Convert the angle from degrees to radians
    local angleRadians = math.rad(angleDegrees)

    -- Calculate the cosine and sine of the angle
    local cosTheta = math.cos(angleRadians)
    local sinTheta = math.sin(angleRadians)

    -- Translate point to the origin
    local translatedX = vector.x - pivot.x
    local translatedY = vector.y - pivot.y

    -- Apply the rotation matrix
    local rotatedX = translatedX * cosTheta - translatedY * sinTheta
    local rotatedY = translatedX * sinTheta + translatedY * cosTheta

    -- Translate the point back to the pivot
    local resultX = rotatedX + pivot.x
    local resultY = rotatedY + pivot.y

    -- Return the rotated vector
    return { x = resultX, y = resultY }
end

function Vector.Vector2.max(...: Vector2)
    local maxVector = {
        x = -math.huge,
        y = -math.huge,
    }

    for _, vector in pairs({ ... }) do
        maxVector.x = math.max(maxVector.x, vector.X)
        maxVector.y = math.max(maxVector.y, vector.Y)
    end

    return Vector2.new(maxVector.x, maxVector.y)
end

function Vector.Vector2.min(...: Vector2)
    local minVector = {
        x = math.huge,
        y = math.huge,
    }

    for _, vector in pairs({ ... }) do
        minVector.x = math.min(minVector.x, vector.X)
        minVector.y = math.min(minVector.y, vector.Y)
    end

    return Vector2.new(minVector.x, minVector.y)
end

function Vector.Vector2.abs(vector: Vector2)
    return Vector2.new(math.abs(vector.X), math.abs(vector.Y))
end

function Vector.Vector2.sign(vector: Vector2)
    return Vector2.new(math.sign(vector.X), math.sign(vector.Y))
end

function Vector.Vector2.round(vector2: Vector2, decimalPlaces: number?)
    return Vector2.new(Math.round(vector2.X, decimalPlaces), Math.round(vector2.Y, decimalPlaces))
end

function Vector.Vector2.toString(vector2: Vector2, decimalPlaces: number?)
    local _, x = Math.round(vector2.X, decimalPlaces)
    local _, y = Math.round(vector2.Y, decimalPlaces)
    local str = string.format("(%s, %s)", x, y)
    str = string.gsub(str, "-0", "0")
    return str
end

function Vector.Vector2.fromString(str: string)
    local x, y = str:match("%((.-), (.-)%)")
    return Vector2.new(tonumber(x), tonumber(y))
end

function Vector.Vector2.isNeighbouring(index: Vector2, possibleNeighbours: { Vector2 })
    for _, neighbour in pairs(possibleNeighbours) do
        if (index - neighbour).Magnitude <= 1 then
            return true
        end
    end

    return false
end

function Vector.Vector2.isInRange(index: Vector2, corner0: Vector2, corner1: Vector2)
    local minX = math.min(corner0.X, corner1.X)
    local maxX = math.max(corner0.X, corner1.X)
    local minY = math.min(corner0.Y, corner1.Y)
    local maxY = math.max(corner0.Y, corner1.Y)

    return index.X >= minX and index.X <= maxX and index.Y >= minY and index.Y <= maxY
end

Vector.Vector3 = {}

function Vector.Vector3.serialize(vector3: Vector3)
    return {
        x = vector3.X,
        y = vector3.Y,
        z = vector3.Z,
    }
end

function Vector.Vector3.serializeArray(vector3Array: { Vector3 })
    local serializedArray = {}
    for _, vector3 in ipairs(vector3Array) do
        table.insert(serializedArray, Vector.Vector3.serialize(vector3))
    end
    return serializedArray
end

function Vector.Vector3.deserialize(serializedVector3: { x: number, y: number, z: number })
    return Vector3.new(serializedVector3.x, serializedVector3.y, serializedVector3.z)
end

function Vector.Vector3.deserializeArray(serializedVector3Array: { { x: number, y: number, z: number } })
    local vector3Array = {}
    for _, serializedVector3 in ipairs(serializedVector3Array) do
        table.insert(vector3Array, Vector.Vector3.deserialize(serializedVector3))
    end
    return vector3Array
end

function Vector.Vector3.max(...: Vector3)
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

function Vector.Vector3.abs(vector: Vector3)
    return Vector3.new(math.abs(vector.X), math.abs(vector.Y), math.abs(vector.Z))
end

function Vector.Vector3.sign(vector: Vector3)
    return Vector3.new(math.sign(vector.X), math.sign(vector.Y), math.sign(vector.Z))
end

function Vector.Vector3.round(vector3: Vector3, decimalPlaces: number?)
    return Vector3.new(Math.round(vector3.X, decimalPlaces), Math.round(vector3.Y, decimalPlaces), Math.round(vector3.Z, decimalPlaces))
end

function Vector.Vector3.toString(vector3: Vector3, decimalPlaces: number?)
    local _, x = Math.round(vector3.X, decimalPlaces)
    local _, y = Math.round(vector3.Y, decimalPlaces)
    local _, z = Math.round(vector3.Z, decimalPlaces)
    local str = string.format("(%s, %s, %s)", x, y, z)
    str = string.gsub(str, "-0", "0")
    return str
end

function Vector.Vector3.fromString(str: string)
    local x, y, z = str:match("%((.-), (.-), (.-)%)")
    return Vector3.new(tonumber(x), tonumber(y), tonumber(z))
end

function Vector.Vector3.nanToZero(vector3: Vector3)
    return Vector3.new(
        Math.isNan(vector3.X) and 0 or vector3.X,
        Math.isNan(vector3.Y) and 0 or vector3.Y,
        Math.isNan(vector3.Z) and 0 or vector3.Z
    )
end

return Vector
