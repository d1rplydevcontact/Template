local Attributes = require(script.Utils.Attributes)
local InstanceUtil = require(script.Utils.Instance)

export type AttributeExists = Attributes.AttributeExists
export type AttributeNone = Attributes.AttributeNone
export type AttributeValidationData = Attributes.AttributeValidationData

export type InstanceHydrateOptions = InstanceUtil.HydrateOptions

local utils = {
    Attributes = Attributes,
    BasePart = require(script.Utils.BasePart),
    CFrame = require(script.Utils.CFrame),
    Color = require(script.Utils.Color),
    Directory = require(script.Utils.Directory),
    Group = require(script.Utils.Group),
    Instance = require(script.Utils.Instance),
    NumberRange = require(script.Utils.NumberRange),
    NumberSequence = require(script.Utils.NumberSequence),
    Pages = require(script.Utils.Pages),
    Ray = require(script.Utils.Ray),
    RichText = require(script.Utils.RichText),
    Seat = require(script.Utils.Seat),
    t = require(script.Utils.t),
    Time = require(script.Utils.Time),
    Tree = require(script.Utils.Tree),
    Tween = require(script.Utils.Tween),
    UDim = require(script.Utils.UDim),
    Vector = require(script.Utils.Vector),
    WorldDebug = require(script.Utils.WorldDebug),
    Character = require(script.Utils.Character),
}

return utils
