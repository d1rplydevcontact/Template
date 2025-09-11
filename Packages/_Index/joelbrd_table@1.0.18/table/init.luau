local Table = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Validate = require(script.Validate)
local DeltaTable = require(script.DeltaTable)
local tableToString = require(script.TableToString)
local SleitnickTableUtil = require(script.SleitnickTableUtil)
local Sift = require(script.Parent.Sift)
local Logger = require(script.Parent.Logger)
local CyclicRefsToString = require(script.CyclicRefsToString)

local DELIMITER = "/"

-- Sleitnick TableUtil
Table.Copy = SleitnickTableUtil.Copy
Table.Sync = SleitnickTableUtil.Sync
Table.Reconcile = SleitnickTableUtil.Reconcile
Table.SwapRemove = SleitnickTableUtil.SwapRemove
Table.SwapRemoveFirstValue = SleitnickTableUtil.SwapRemoveFirstValue
Table.Map = SleitnickTableUtil.Map
Table.Filter = SleitnickTableUtil.Filter
Table.Reduce = SleitnickTableUtil.Reduce
Table.Assign = SleitnickTableUtil.Assign
Table.Extend = SleitnickTableUtil.Extend
Table.Reverse = SleitnickTableUtil.Reverse
Table.Shuffle = SleitnickTableUtil.Shuffle
Table.Sample = SleitnickTableUtil.Sample
Table.Flat = SleitnickTableUtil.Flat
Table.FlatMap = SleitnickTableUtil.FlatMap
Table.Keys = SleitnickTableUtil.Keys
Table.Values = SleitnickTableUtil.Values
Table.Find = SleitnickTableUtil.Find
Table.Every = SleitnickTableUtil.Every
Table.Some = SleitnickTableUtil.Some
Table.Truncate = SleitnickTableUtil.Truncate
Table.Zip = SleitnickTableUtil.Zip
Table.Lock = SleitnickTableUtil.Lock
Table.EncodeJSON = SleitnickTableUtil.EncodeJSON
Table.DecodeJSON = SleitnickTableUtil.DecodeJSON

-- Sift
Table.Sift = Sift -- https://cxmeel.github.io/sift/api/Sift

-- Our Own
Table.ToString = tableToString
Table.DeltaTable = DeltaTable
Table.CyclicRefsToString = CyclicRefsToString

function Table.IsEmpty(tbl: table)
    for key, value in pairs(tbl) do
        return false
    end

    return true
end

local function getKeysFromPath(path: string)
    local keys = string.split(path, DELIMITER)

    if path:sub(1, 1) == DELIMITER then
        table.remove(keys, 1)
    end

    for i, key in pairs(keys) do
        keys[i] = tonumber(key) or key
    end

    return keys
end

Table.GetKeysFromPath = getKeysFromPath

--[=[
    this/is/a/path
]=]
function Table.PathGet(tbl: table, path: string)
    local keys = getKeysFromPath(path)
    local current = tbl
    for _, key in pairs(keys) do
        current = current[key]
        if not current then
            return nil
        end
    end
    return current :: any
end

--[=[
    this/is/a/path
]=]
function Table.PathSet(tbl: table, path: string, value: any)
    local keys = getKeysFromPath(path)
    local current = tbl
    for i = 1, #keys - 1 do
        local key = keys[i]
        if current[key] == nil then
            current[key] = {}
        end
        current = current[key]
    end
    current[keys[#keys]] = value
end

--[=[
    this/is/a/path

    Will remove all empty tables on this path.
]=]
function Table.PathRemove(tbl: table, path: string)
    -- get keys, go through whole path, keep a record of keys and tables, go down to the lowest table.
    -- then go through this record bottom to top. if a table is empty, remove it. if a table is non-empty, we can assume
    -- that the table above it is non-empty as well so we can stop.

    local keys = getKeysFromPath(path)
    local current = tbl
    local record = {}
    for i = 1, #keys - 1 do
        local key = keys[i]
        if current[key] == nil then
            break
        end
        table.insert(record, { key = key, table = current })
        current = current[key]
    end

    for i = #record, 1, -1 do
        local entry = record[i]
        local key = entry.key
        local table = entry.table
        if Table.IsEmpty(table[key]) then
            table[key] = nil
        else
            break
        end
    end
end

local function is_cyclic(tbl, seen)
    if type(tbl) ~= "table" then
        return false
    end

    seen = seen or {}

    if seen[tbl] then
        return true
    end

    seen[tbl] = true

    for k, v in pairs(tbl) do
        -- Check key
        if type(k) == "table" and is_cyclic(k, seen) then
            return true
        end
        -- Check value
        if type(v) == "table" and is_cyclic(v, seen) then
            return true
        end
    end

    seen[tbl] = nil -- Optional: cleanup for reuse
    return false
end

function Table.IsCyclic(tbl: table)
    return is_cyclic(tbl)
end

--[=[
    Will list all array elements in a list
]=]
function Table.ToStringList<K, V>(tbl: { [K]: V }, middleware: ((V, K) -> string)?)
    local strings = {}
    for key, value in pairs(tbl) do
        if middleware then
            value = middleware(value, key)
        end

        table.insert(strings, tostring(value))
    end

    local listString = ""
    for i, str in pairs(strings) do
        if i == 1 then
            listString = str
        elseif i == #strings then
            listString = listString .. " and " .. str
        else
            listString = listString .. ", " .. str
        end
    end

    return listString
end

Table.ToStringListMiddleware = {
    DoubleQuotes = function(value: any)
        return `"{tostring(value)}"`
    end,
}

--[=[
    Iterates deeply through all `tbl`, starting at the deepest leaf nodes and working its way up to the root.
]=]
function Table.Iterate(tbl: table, callback: (key: any, value: any, path: string) -> ())
    local function iterate(_tbl: table, path: string)
        for key, value in pairs(table.clone(_tbl)) do
            if type(value) == "table" then
                iterate(value, path .. DELIMITER .. key)
            end
            callback(key, value, path)
        end
    end
    iterate(tbl, "")
end

--[=[
    Utility built for use for immutable state management. Will return a new table, with the tables at each key along
    each path having `table.clone` ran on it to generate fresh references.

    ```
    example/path
    ```
]=]
function Table.NewReferences<T>(tbl: T, paths: { string })
    local cache: { [table]: true } = {}

    local newTbl = table.clone(tbl :: any) :: table
    cache[newTbl] = true

    for _, path in pairs(paths) do
        local keys = getKeysFromPath(path)
        local current = newTbl
        for i, key in pairs(keys) do
            local keyTbl = current[key]
            if not keyTbl then
                Logger.warn(`Path {path} does not exist in table (key {key} does not exist)`)
                break
            end

            if cache[keyTbl] then
                current = keyTbl
                continue
            end

            if typeof(keyTbl) ~= "table" then
                Logger.warn(`Bad path {path} (key {key} is not a table)`)
                break
            end

            local newKeyTbl = table.clone(keyTbl)
            current[key] = newKeyTbl
            cache[newKeyTbl] = true

            current = newKeyTbl
        end
    end

    return newTbl :: T
end

--[=[
    Inserts an item into a table in order, based on the comparator function.
    If no comparator is provided, it will insert the item in ascending order.
    Returns the index at which the item was inserted.
]=]
function Table.InsertInOrder(tbl: table, item: any, comparator: ((a: any, b: any) -> boolean)?)
    if #tbl == 0 then
        table.insert(tbl, item)
        return 1
    end

    local index = #tbl + 1
    for i, value in ipairs(tbl) do
        if comparator then
            if comparator(item, value) then
                index = i
                break
            end
        else
            if item < value then
                index = i
                break
            end
        end
    end

    table.insert(tbl, index, item)

    return index
end

--[=[
    Validates a table to ensure it can be synced over a remote event.
]=]
Table.ValidateNetwork = Validate

--[=[
    Validates a table to ensure it can be used for a data store.
]=]
Table.ValidateDataStore = Validate

Table.Set = {}

function Table.Set.equals(...: any)
    local sets = { ... }

    for i = 1, #sets - 1 do
        local set1 = sets[i]
        local set2 = sets[i + 1]

        for key, _ in pairs(set1) do
            if not set2[key] then
                return false
            end
        end

        for key, _ in pairs(set2) do
            if not set1[key] then
                return false
            end
        end
    end

    return true
end

return Table
