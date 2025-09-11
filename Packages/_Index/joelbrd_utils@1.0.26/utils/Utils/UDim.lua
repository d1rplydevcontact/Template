local UDimUtil = {}

UDimUtil.UDim = {}

function UDimUtil.UDim.multiply(udim: UDim, multiplier: number)
    return UDim.new(udim.Scale * multiplier, udim.Offset * multiplier)
end

function UDimUtil.UDim.serialize(udim: UDim)
    return {
        Scale = udim.Scale,
        Offset = udim.Offset,
    }
end

function UDimUtil.UDim.deserialize(serializedUDim: { Scale: number, Offset: number })
    return UDim.new(serializedUDim.Scale, serializedUDim.Offset)
end

function UDimUtil.UDim.update(udim: UDim, updater: (serializedUDim: { Scale: number, Offset: number }) -> ())
    local serializedUDim = UDimUtil.UDim.serialize(udim)
    updater(serializedUDim)
    return UDimUtil.UDim.deserialize(serializedUDim)
end

UDimUtil.UDim2 = {}

function UDimUtil.UDim2.multiply(udim: UDim2, multiplier: number)
    return UDim2.new(udim.X.Scale * multiplier, udim.X.Offset * multiplier, udim.Y.Scale * multiplier, udim.Y.Offset * multiplier)
end

function UDimUtil.UDim2.serialize(udim: UDim2)
    return {
        X = UDimUtil.UDim.serialize(udim.X),
        Y = UDimUtil.UDim.serialize(udim.Y),
    }
end

function UDimUtil.UDim2.deserialize(serializedUDim: { X: { Scale: number, Offset: number }, Y: { Scale: number, Offset: number } })
    return UDim2.new(UDimUtil.UDim.deserialize(serializedUDim.X), UDimUtil.UDim.deserialize(serializedUDim.Y))
end

function UDimUtil.UDim2.update(
    udim: UDim2,
    updater: (serializedUDim: { X: { Scale: number, Offset: number }, Y: { Scale: number, Offset: number } }) -> ()
)
    local serializedUDim = UDimUtil.UDim2.serialize(udim)
    updater(serializedUDim)
    return UDimUtil.UDim2.deserialize(serializedUDim)
end

return UDimUtil
