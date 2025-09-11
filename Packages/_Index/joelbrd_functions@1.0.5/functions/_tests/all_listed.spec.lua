local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local Functions = require(script.Parent.Parent)
local FunctionModuleScripts = script.Parent.Parent.Functions

local describe = JestGlobals.describe
local test = JestGlobals.test
local expect = JestGlobals.expect

-- describe(`describe`, function()
--     test(`test`, function()
--         expect(true).toBe(true)
--     end)
-- end)

describe(`Functions`, function()
    test(`all modules are listed`, function()
        local allModules: { [string]: table } = {}
        for _, moduleScript in pairs(FunctionModuleScripts:GetChildren()) do
            if moduleScript:IsA("ModuleScript") then
                allModules[moduleScript.Name] = require(moduleScript)
            end
        end

        expect(Functions).toEqual(allModules)
    end)
end)
