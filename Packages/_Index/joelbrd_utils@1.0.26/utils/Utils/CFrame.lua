local CFrameUtil = {}

function CFrameUtil.setRightVector(cframe: CFrame, rightVector: Vector3)
    local newRight = rightVector.Unit
    local look = cframe.LookVector
    -- compute up using cross product in the correct order
    local newUp = newRight:Cross(look).Unit
    local newLook = newUp:Cross(newRight).Unit -- recompute look to enforce orthogonality
    return CFrame.fromMatrix(cframe.Position, newRight, newUp, -newLook)
end

function CFrameUtil.setLookVector(cframe: CFrame, lookVector: Vector3)
    local newLook = lookVector.Unit
    local right = cframe.RightVector
    local newUp = newLook:Cross(right).Unit
    local newRight = newUp:Cross(newLook).Unit
    return CFrame.fromMatrix(cframe.Position, newRight, newUp, -newLook)
end

function CFrameUtil.setUpVector(cframe: CFrame, upVector: Vector3)
    local newUp = upVector.Unit
    local look = cframe.LookVector
    local newRight = look:Cross(newUp).Unit
    local newLook = newRight:Cross(newUp).Unit
    return CFrame.fromMatrix(cframe.Position, newRight, newUp, -newLook)
end

function CFrameUtil.setPosition(cframe: CFrame, position: Vector3)
    return cframe - cframe.Position + position
end

function CFrameUtil.equalToPrecision(epsilon: number, ...: CFrame)
    local cframes: { CFrame } = { ... }

    local firstCFrame = table.remove(cframes, 1)

    for _, cframe in ipairs(cframes) do
        if (firstCFrame.Position - cframe.Position).Magnitude > epsilon then
            return false
        end

        if (firstCFrame.LookVector - cframe.LookVector).Magnitude > epsilon then
            return false
        end

        if (firstCFrame.UpVector - cframe.UpVector).Magnitude > epsilon then
            return false
        end

        if (firstCFrame.RightVector - cframe.RightVector).Magnitude > epsilon then
            return false
        end
    end

    return true
end

function CFrameUtil.equal(...: CFrame)
    return CFrameUtil.equalToPrecision(0.0001, ...)
end

return CFrameUtil
