--[[
    UniqueTag.lua
    Represents an opaque, strictly protected tag object with an internal UID.
    Used solely for value-based tag comparison and debugging via tostring().

    Author: Stackyz
    Date: July 8th, 2025
]]

local function UniqueTag(uid: any)
    return setmetatable({}, {
        -- Blocks reading of undefined members
        __index = function(_, key)
            error(("Attempt to get UniqueTag::%s (not a valid member)"):format(tostring(key)), 2)
        end,

        -- Blocks writing of any member
        __newindex = function(_, key)
            error(("Attempt to set UniqueTag::%s (not a valid member)"):format(tostring(key)), 2)
        end,

        -- String representation shows the UID (for debugging or logs)
        __tostring = function()
            return tostring(uid)
        end,

        -- Compares tags by UID value (not by object identity)
        __eq = function(a, b)
            return tostring(a) == tostring(b)
        end,
    })
end

return UniqueTag
