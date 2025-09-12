local Directory = {}

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Trove = require(script.Parent.Parent.Parent.Trove)
local Attributes = require(script.Parent.Attributes)
local InstanceUtil = require(script.Parent.Instance)

local ATTRIBUTE_SETUP = "DirectorySetup"

local HIDDEN_PARENT = Lighting:FindFirstChild("_unusedDirectories")
    or InstanceUtil.setProps(Instance.new("Folder"), {
        Name = "_unusedDirectories",
        Parent = Lighting,
    })

--[=[
    Gets a Directory (creates it if it doesn't exist) with the given name and parent.

    - We can call this on Client and Server; the Client will pickup on the Server version of the Directory
    - The directory will only exist under `parent` if it has children; useful for a less cluttered Explorer during development
]=]
function Directory.get(name: string, parent: Instance)
    name ..= `({RunService:IsServer() and "Server" or "Client"})`

    local directory = InstanceUtil.findFirstChild(parent, {
        props = {
            Name = name,
            ClassName = "Folder",
        },
        attributes = {
            [ATTRIBUTE_SETUP] = Attributes.Exists,
        },
    }) or InstanceUtil.findFirstChild(HIDDEN_PARENT, {
        props = {
            Name = name,
            ClassName = "Folder",
        },
        attributes = {
            [ATTRIBUTE_SETUP] = Attributes.Exists,
        },
    }) or InstanceUtil.setProps(Instance.new("Folder"), {
        Name = name,
        Parent = HIDDEN_PARENT,
    })

    if directory:GetAttribute(ATTRIBUTE_SETUP) then
        return directory
    end

    local trove = Trove.new()

    local function updateParent()
        if #directory:GetChildren() > 0 then
            directory.Parent = parent
        else
            directory.Parent = HIDDEN_PARENT
        end
    end

    trove:Add(directory.ChildAdded:Connect(updateParent))
    trove:Add(directory.ChildRemoved:Connect(updateParent))

    InstanceUtil.onDestroyed(directory, function()
        trove:Destroy()
    end)

    directory:SetAttribute(ATTRIBUTE_SETUP, true)

    return directory
end

return Directory
