local function tableCopy(originalTable, visitedTables, depthData, path)
    visitedTables = visitedTables or {}
    path = path or "ROOT"
    depthData = depthData or { 0, path }

    -- Check if we've already visited this table (cyclic reference)
    local cyclicData = visitedTables[originalTable]
    if cyclicData then
        -- Return a string representation instead of the cyclic reference
        return (cyclicData[1] == depthData[1] - 1 and "[Cyclic Parent " or "[Cyclic ")
            .. tostring(originalTable)
            .. ", path: "
            .. cyclicData[2]
            .. "]"
    end

    -- Mark this table as visited
    local currentDepth = depthData[1] + 1
    local currentDepthData = { currentDepth, path }
    visitedTables[originalTable] = currentDepthData

    -- Create new table
    local newTable = {}

    for key, value in pairs(originalTable) do
        local newKey = key
        local newValue = value

        -- Handle cyclic references in keys
        if type(key) == "table" then
            local keyPath = path .. "[key]"
            newKey = tableCopy(key, visitedTables, { currentDepth, path }, keyPath)
        end

        -- Handle cyclic references in values
        if type(value) == "table" then
            local valuePath = path .. (type(key) == "string" and ("." .. key) or "[" .. tostring(key) .. "]")
            newValue = tableCopy(value, visitedTables, { currentDepth, path }, valuePath)
        end

        newTable[newKey] = newValue
    end

    return newTable
end

return function(tbl: table): table
    local result = tableCopy(tbl)
    return result
end
