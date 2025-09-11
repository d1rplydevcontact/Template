--[=[
    DeltaTable
    Version: 2.0
    By: SocialSimulator
    Date: 2021-07-01

    This module is for getting the difference between a table and then 
    being able to merge it back in. 
    -- Specifically great for networking as it allows us only to send what has changed

    This is an independant Module because it has enough parts to it, that it should be 
    seperated from ADTs and or some sort of "Table" lib.  This is abstractly a table differ.
]=]
local DeltaTable = {
    _VERSION = 2.0,
    --> Enhanced with better detection of tables, nils, nested tables, and protections
    -- so that new tables can be added after the fact
}
------------------------------------------------------------------------------------------------
-- Helpers
local function recursiveCall(old, new, var, count, res)
    --its a table, recurse
    -- predicate
    if type(old[var]) ~= "table" then
        count = count + 1
        res[var] = new[var]

        return res, count
    end

    local newtable, num = DeltaTable.DiffTable(old[var], new[var])
    if num > 0 then
        count = count + 1
        res[var] = newtable
    end
    return res, count
end

local function ifChangedSetCall(old, new, var, count, res)
    local a = new[var]
    local b = old[var]

    if a ~= b then
        count = count + 1
        res[var] = a
    end
    return res, count
end

local function DeepCopy(original)
    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            v = DeepCopy(v)
        end
        copy[k] = v
    end
    return copy
end

local function nilSanatize(old, new)
    for var, data in pairs(old) do
        -- "_" is our signal to delete
        if new[var] == nil then
            new[var] = "_"
            continue
        end
    end
end

------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
--[[
This will return the:
Result, and count tuple
]]
DeltaTable.DiffTable = function(old, _new)
    local res = {}
    local count = 0

    local new = DeepCopy(_new)
    nilSanatize(old, new)

    for var, data in pairs(new) do
        -- Sanatize
        if old[var] == nil then
            res[var] = "nil"
        end

        if type(new[var]) == "table" then
            res, count = recursiveCall(old, new, var, count, res)
        else
            res, count = ifChangedSetCall(old, new, var, count, res)
        end
    end

    return res, count
end
--[[
Merge Table will then take the an old table and overwrite it with the new table
]]
DeltaTable.MergeTable = function(old, diffTable)
    local newTable = DeepCopy(old)

    for var, data in pairs(diffTable) do
        -- If we signal a deletion then here we go
        if diffTable[var] == "_" then
            newTable[var] = nil
            continue
        end

        if type(diffTable[var]) == "table" then
            if type(old[var]) ~= "table" then
                newTable[var] = diffTable[var]
            else
                newTable[var] = DeltaTable.MergeTable(old[var], diffTable[var])
            end
        else
            newTable[var] = diffTable[var]
        end
    end

    return newTable
end

return DeltaTable
