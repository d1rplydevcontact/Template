local DebugMenu = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Iris = require(script.Parent.Parent.Parent.Iris)
local Table = require(script.Parent.Parent.Parent.Table)
local types = require(script.Parent.Parent.types)

local function buildCharmData(registry: { [string]: () -> any }): { [string]: any }
    local charmData = {}
    for key, atom in pairs(registry) do
        local parts = {}
        for part in string.gmatch(key, "[^/]+") do
            table.insert(parts, part)
        end
        local node = charmData
        for i = 1, #parts - 1 do
            node[parts[i]] = node[parts[i]] or {}
            node = node[parts[i]]
        end
        node[parts[#parts]] = atom
    end
    return charmData
end

local function renderNode(node: { [string]: any } | (() -> any), path: string)
    -- If node is a function (atom), render its value
    if type(node) ~= "table" then
        local value = node()
        if type(value) == "table" then
            -- Put table values in a collapsible toggle
            local tree = Iris.Tree({ "Table Value" })
            if tree.state.isUncollapsed.value then
                Iris.Text({ Table.ToString(value) })
            end
            Iris.End()
        else
            Iris.Text({ tostring(value) })
        end
        return
    end

    -- Render table structure
    for k, v in pairs(node) do
        if type(v) == "table" then
            local tree = Iris.Tree({ tostring(k) })
            if tree.state.isUncollapsed.value then
                renderNode(v, `{path}/{tostring(k)}`)
            end
            Iris.End()
        else
            -- This is an atom function
            local value = v()
            if type(value) == "table" then
                -- Put table values in a collapsible toggle
                local tree = Iris.Tree({ `{tostring(k)}: Table` })
                if tree.state.isUncollapsed.value then
                    Iris.Text({ Table.ToString(value) })
                end
                Iris.End()
            else
                Iris.Text({ `{tostring(k)}: {tostring(value)}` })
            end
        end
    end
end

local function registryTab(registry: types.Registry)
    Iris.Tab({ registry.Id })
    do
        local totalAtoms = Table.Sift.Dictionary.count(registry.Registry)

        Iris.Text({ `{totalAtoms} Atoms` })
        Iris.Separator()

        if totalAtoms > 0 then
            renderNode(buildCharmData(registry.Registry), registry.Id)
        else
            Iris.Text({ "No atoms registered." })
        end
    end
    Iris.End()
end

local function irisWindow(registries: { types.Registry })
    Iris.Window({ "Debug Menu" })
    do
        Iris.TabBar()
        for _, registry in pairs(registries) do
            registryTab(registry)
        end
        Iris.End()
    end
    Iris.End()
end

return {
    irisWindow = irisWindow,
}
