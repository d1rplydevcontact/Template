local Logger = require(script.Parent.Logger)
local Table = require(script.Parent.Table)

type Methods = {
    isValid: (value: any) -> boolean,
    areValid: (values: { any }) -> boolean,
    getValues: () -> { any },
    getRandomValue: () -> any,
    assert: (valueOrValues: any | { any }) -> (),
}

--[=[
    Wraps a constMap-like table like so:

    ```lua
    local SomeEnum = {
        A = "A",
        B = "B",
        C = "C",
        ...
    }
    ```

    - Verifies keys are equal to values
    - Protects the table from being modified
    - Ensures non-existent keys are caught at runtime
]=]
return function<T>(_constMap: T)
    local _constMapAny = _constMap :: any
    local constMap = _constMapAny :: table

    for key, value in pairs(constMap) do
        if key ~= value then
            Logger.error(`Enum key {key} does not match value {value}`)
        end
    end

    local validKeys = Table.Sift.Dictionary.map(constMap, function(value, key)
        return true, key
    end)

    local methods: Methods = {
        assert = function(valueOrValues)
            local values = type(valueOrValues) == "table" and valueOrValues or { valueOrValues }
            for _, value in pairs(values) do
                if validKeys[value] == nil then
                    Logger.error(
                        `Invalid constMap value {value}. Valid values are: {Table.ToStringList(
                            constMap,
                            Table.ToStringListMiddleware.DoubleQuotes
                        )}`
                    )
                end
            end
        end,
        isValid = function(value)
            if validKeys[value] == nil then
                return false
            end

            return true
        end,
        areValid = function(values)
            for _, value in pairs(values) do
                if validKeys[value] == nil then
                    return false
                end
            end

            return true
        end,
        getValues = function()
            local values = {}
            for key, value in pairs(constMap) do
                table.insert(values, value)
            end

            return values
        end,
        getRandomValue = function()
            local values = {}
            for key, value in pairs(constMap) do
                table.insert(values, value)
            end

            return values[math.random(1, #values)]
        end,
    }

    setmetatable(constMap, {
        __index = function(self, key)
            if methods[key] then
                return methods[key]
            end

            Logger.error(
                `Invalid constMap key {key}. Valid keys are: {Table.ToStringList(constMap, Table.ToStringListMiddleware.DoubleQuotes)}`
            )

            return
        end,
    })
    table.freeze(constMap)

    return constMap :: T & Methods
end
