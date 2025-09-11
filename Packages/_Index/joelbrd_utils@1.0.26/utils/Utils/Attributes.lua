local Attributes = {}

export type AttributeExists = table
export type AttributeNone = table

export type AttributeValidationData = {
    [string]: any & AttributeExists & (value: any) -> boolean,
}

Attributes.Exists = { "attribute_exists" } :: AttributeExists
Attributes.None = { "attribute_none" } :: AttributeNone

function Attributes.doesInstancePassAttributeValidation(instance: Instance, attributeValidation: AttributeValidationData)
    for attribute, check in pairs(attributeValidation) do
        local attributeValue = instance:GetAttribute(attribute)
        if attributeValue == nil then
            return false
        end

        if check == Attributes.Exists then
            continue
        end

        if type(check) == "function" then
            if not check(attributeValue) then
                return false
            end
        end

        if check == attributeValue then
            continue
        else
            return false
        end
    end

    return true
end

--[=[
    Tracks the attributes of an instance and calls the callback when they change - as well as an initial first call.
]=]
function Attributes.observeAttributes(
    instance: Instance,
    attributeCallbacks: { [string]: (value: any?) -> () },
    ignoreInitialCall: boolean?
)
    local connection = instance.AttributeChanged:Connect(function(attributeName: string)
        if attributeCallbacks[attributeName] then
            attributeCallbacks[attributeName](instance:GetAttribute(attributeName))
        end
    end)

    if not ignoreInitialCall then
        for attribute, callback in pairs(attributeCallbacks) do
            -- Call the callback immediately with the current value of the attribute
            callback(instance:GetAttribute(attribute))
        end
    end

    return function()
        connection:Disconnect()
    end
end

function Attributes.setAttributes(instance: Instance, attributes: { [string]: any | AttributeNone })
    for attribute, value in pairs(attributes) do
        if value == Attributes.None then
            instance:SetAttribute(attribute, nil)
        else
            instance:SetAttribute(attribute, value)
        end
    end
end

return Attributes
