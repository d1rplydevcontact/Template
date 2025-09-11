local Tree = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger = require(script.Parent.Parent.Parent.Logger)
local Promise = require(script.Parent.Parent.Parent.Promise)

local DELIM = "/"

local function fullNameToPath(instance: Instance): string
    return instance:GetFullName():gsub("%.", DELIM)
end

--[=[
    Similar to FindFirstChild, with a few key differences:
    - A path to the instance can be provided, delimited by forward slashes (e.g. `Path/To/Child`)
    - Optionally, the instance's type can be asserted using `IsA`

    ```lua
    -- Find "Child" directly under parent:
    local instance = Tree.Find(parent, "Child")

    -- Find "Child" descendant:
    local instance = Tree.Find(parent, "Path/To/Child")

    -- Find "Child" descendant and assert that it's a BasePart:
    local instance = Tree.Find(parent, "Path/To/Child", "BasePart") :: BasePart?
    ```

]=]
function Tree.find(parent: Instance, path: string, assertIsA: string?): Instance?
    local instance = parent
    local paths = path:split(DELIM)

    for _, path in paths do
        -- Error for empty path parts:
        if path == "" then
            Logger.error(`Invalid path: {path}`)
        end

        instance = instance:FindFirstChild(path)

        if instance == nil then
            return nil
        end
    end

    if assertIsA and not instance:IsA(assertIsA) then
        return nil
    end

    return instance
end

--[=[
	Returns `true` if the instance is found. Similar to `Tree.Find`, except this returns `true|false`. No error is thrown unless the path is invalid.

	```lua
	-- Check if "Child" exists directly in `parent`:
	if Tree.Exists(parent, "Child") then ... end
	
	-- Check if "Child" descendant exists at `parent.Path.To.Child`:
	if Tree.Exists(parent, "Path/To/Child") then ... end
	
	-- Check if "Child" descendant exists at `parent.Path.To.Child` and is a BasePart:
	if Tree.Exists(parent, "Path/To/Child", "BasePart") then ... end
	```
]=]
function Tree.exists(parent: Instance, path: string, assertIsA: string?): boolean
    local instance = parent
    local paths = path:split(DELIM)

    for _, path in paths do
        -- Error for empty path parts:
        if path == "" then
            Logger.error(`Invalid path: {path}`)
        end

        instance = instance:FindFirstChild(path)

        if instance == nil then
            return false
        end
    end

    if assertIsA and not instance:IsA(assertIsA) then
        return false
    end

    return true
end

--[=[
	Waits for the path to exist within the parent instance. Similar to `Tree.find`, except `WaitForChild`
	is used internally. An optional `timeout` can be supplied, which is passed along to each call to
	`WaitForChild`.

    This is all wrapped in a Promsie - so you can use `:andThen` or `:catch` to handle the result.

	```lua
	local child = Tree.Await(parent, "Path/To/Child", 30)
	```
]=]
function Tree.promise(parent: Instance, path: string, timeout: number?, assertIsA: string?)
    local instance = parent
    local paths = path:split(DELIM)

    local promise = Promise.new(function(resolve, reject)
        for _, path in paths do
            -- Error for empty path parts:
            if path == "" then
                reject(`Invalid path: {path}`)
            end

            instance = instance:WaitForChild(path, timeout)

            -- Error if instance is not found:
            if instance == nil then
                reject(`Failed to wait for {path} in {fullNameToPath(parent)} (timeout reached)`)
            end
        end

        -- Assert class type if argument is supplied:
        if assertIsA and not instance:IsA(assertIsA) then
            reject(`Got class {instance.ClassName}; expected to be of type {assertIsA}`)
        end

        resolve(instance)
    end)

    return promise
end

return Tree
