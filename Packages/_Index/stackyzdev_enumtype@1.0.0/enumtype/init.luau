--[[
    EnumType.lua
    Defines a strongly-typed, immutable enum system similar to Roblox's native Enum,
    but fully customizable. Useful for cases where custom enums with predictable
    name/value mappings are required.

    Author: Stackyz
    Date: July 9th, 2025
]]

local Packages = script.Parent

local Assert = require(Packages.Assert)
local UniqueTag = require(Packages.UniqueTag)

-- Unique keys for internal data to prevent external access
local NAME_KEY = UniqueTag("EnumType::Name")
local ITEMS_KEY = UniqueTag("EnumType::Items")

-- Represents a single enum value (e.g. Enum.Status.Idle)
local EnumItem = {}

-- Creates a new EnumItem bound to a parent EnumType
function EnumItem.new(enumType, name: string, value: number)
    Assert.string(name, "EnumItem name")
    Assert.number(value, "EnumItem value")

    return setmetatable({
        Name = name,
        Value = value,
        EnumType = enumType, -- Reference to parent EnumType
    }, EnumItem)
end

-- Prevents access to undefined properties on EnumItem
function EnumItem:__index(key)
    error(string.format("%s is not a valid member of \"%s\"", key, tostring(self)), 2)
end

-- Prevents setting any property on EnumItem
function EnumItem:__newindex(key)
    error(string.format("%s is not a valid member of EnumItem", key), 2)
end

-- Provides a string representation (e.g. Status.Idle)
function EnumItem:__tostring()
    return string.format("%s.%s", tostring(self.EnumType), self.Name)
end

-- A custom, immutable set of named EnumItems
local EnumType = {}

-- Creates a new EnumType with a name and list of enum names
-- Example: EnumType.new("Status", {"Idle", "Running", "Stopped"})
function EnumType.new(name: string, enumNames: {string})
    Assert.string(name, "Enum name")
    Assert.table(enumNames, "Enum list")

    local self = {
        [NAME_KEY] = name,
        [ITEMS_KEY] = {}, -- Ordered list of EnumItems
    }

    for value, enumName in enumNames do
        local enumItem = EnumItem.new(self, enumName, value)
        self[enumName] = enumItem
        table.insert(self[ITEMS_KEY], enumItem)
    end

    return setmetatable(self, EnumType)
end

-- Blocks invalid access
function EnumType:__index(key)
    error(string.format("%s is not a valid member of \"%s\"", key, tostring(self)), 2)
end

-- Blocks any modification after creation
function EnumType:__newindex(key)
    error(string.format("%s is not a valid member of Enum", key), 2)
end

-- String representation returns the enum type name
function EnumType:__tostring()
    return self[NAME_KEY]
end

-- Returns EnumItem from its string name
function EnumType:FromName(name: string)
    return rawget(self, name)
end

-- Returns EnumItem from its position in original list
function EnumType:FromValue(index: number)
    return self[ITEMS_KEY][index]
end

-- Returns all EnumItems in definition order
function EnumType:GetEnumItems()
    return self[ITEMS_KEY]
end

return EnumType
