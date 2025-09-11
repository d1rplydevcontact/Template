local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local Utils = require(script.Parent.Parent)
local UtilModuleScripts = script.Parent.Parent.Utils

local describe = JestGlobals.describe
local test = JestGlobals.test
local expect = JestGlobals.expect

-- describe(`describe`, function()
--     test(`test`, function()
--         expect(true).toBe(true)
--     end)
-- end)

describe(`Utils`, function()
    test(`all modules are listed`, function()
        local allModules: { [string]: table } = {}
        for _, moduleScript in pairs(UtilModuleScripts:GetChildren()) do
            if moduleScript:IsA("ModuleScript") then
                allModules[moduleScript.Name] = require(moduleScript)
            end
        end

        expect(Utils).toEqual(allModules)
    end)
end)
