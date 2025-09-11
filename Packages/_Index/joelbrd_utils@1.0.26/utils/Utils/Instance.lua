local InstanceUtil = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(script.Parent.Parent.Parent.Trove)
local Functions = require(script.Parent.Parent.Parent.Functions)
local isInstanceDestroyed = Functions.isInstanceDestroyed
local noYield = Functions.noYield
local Logger = require(script.Parent.Parent.Parent.Logger)
local Attributes = require(script.Parent.Attributes)
local Table = require(script.Parent.Parent.Parent.Table)
local t = require(script.Parent.Parent.Parent.t)

-- `setProps`, setting these last can increase performance
local SET_PROPS_LAST = { "Visible", "Enabled", "Parent" }
local SET_PROPS_LAST_SET = Table.Sift.Array.toSet(SET_PROPS_LAST)

--[=[
    `callback` can return a cleanup function, that is called when
    - the descendant is removed
    - the cleanup function (return by this call) is called

    Note a cleanup function from `instance` (when IncludeSelf=true) is only called when the cleanup function is called.
]=]
function InstanceUtil.descendantAdded(
    instance: Instance,
    callback: (instance: Instance) -> (() -> ())?,
    props: {
        Inclusive: boolean?,
        IncludeSelf: boolean?,
    }?
)
    local onDescendantRemovedsByInstance: { [Instance]: (() -> ())? } = {}

    local addedConnection = instance.DescendantAdded:Connect(function(instance)
        onDescendantRemovedsByInstance[instance] = noYield(callback, instance)
    end)

    local removingConnection = instance.DescendantRemoving:Connect(function(instance)
        local onDescendantRemoved = onDescendantRemovedsByInstance[instance]
        if onDescendantRemoved then
            onDescendantRemovedsByInstance[instance] = nil
            onDescendantRemoved()
        end
    end)

    if props then
        if props.Inclusive then
            for _, descendant in pairs(instance:GetDescendants()) do
                onDescendantRemovedsByInstance[descendant] = noYield(callback, descendant)
            end
        end
        if props.IncludeSelf then
            onDescendantRemovedsByInstance[instance] = noYield(callback, instance)
        end
    end

    return function()
        addedConnection:Disconnect()
        removingConnection:Disconnect()

        for instance, onDescendantRemoved in pairs(onDescendantRemovedsByInstance) do
            if onDescendantRemoved then
                onDescendantRemoved()
            end
        end
    end
end

--[=[
    Sets properties on an instance.

    returns the instance and the old properties.
]=]
function InstanceUtil.setProps<T>(
    instance: T,
    props: {
        [string]: any,
    }
)
    local _instance = instance :: any -- type trick

    local oldProps: { [string]: any } = {}

    for key, value in pairs(props) do
        if SET_PROPS_LAST_SET[key] then
            continue
        end

        oldProps[key] = _instance[key]
        _instance[key] = value
    end

    --[[
        If we update properties on an Instance in the workspace, this can trigger a lot of updates. We parent it last incase
        it is not in the workspace yet, and is more performant. Also may support Components better.
    ]]
    for _, key in pairs(SET_PROPS_LAST) do
        local value = props[key]
        if value ~= nil then
            oldProps[key] = _instance[key]
            _instance[key] = value
        end
    end

    return instance, oldProps
end

--[=[
    Sets tags on an instance.

    `tags` is a table of tags to set on the instance. The value is true to add the tag, and false to remove the tag.
]=]
function InstanceUtil.setTags(instance: Instance, tags: { [string]: boolean })
    for tag, add in pairs(tags) do
        if add then
            instance:AddTag(tag)
        else
            instance:RemoveTag(tag)
        end
    end
end

InstanceUtil.Attributes = Attributes

function InstanceUtil.doesInstancePassPropsValidation(instance: Instance, propsValidation: { [string]: any | (value: any) -> boolean })
    for propertyName, valueOrCheck in pairs(propsValidation) do
        -- assert the property exists..
        if not pcall(function()
            return instance[propertyName]
        end) then
            return false
        end

        local propertyValue = instance[propertyName]

        if typeof(valueOrCheck) == "function" then
            if not valueOrCheck(propertyValue) then
                return false
            end
        end

        if propertyValue ~= valueOrCheck then
            return false
        end
    end

    return true
end

function InstanceUtil.doesInstancePassTagsValidation(instance: Instance, tags: { string } | { [string]: boolean })
    local tagsSet: { [string]: boolean } = Table.Sift.Array.is(tags) and Table.Sift.Array.toSet(tags) or tags

    for tag, shouldHave in pairs(tagsSet) do
        local hasTag = instance:HasTag(tag)
        if hasTag ~= shouldHave then
            return false
        end
    end

    return true
end

function InstanceUtil.doesInstancePassIsAValidation(instance: Instance, isA: string | { string })
    if typeof(isA) == "string" then
        return instance:IsA(isA)
    end

    for _, className in pairs(isA) do
        if instance:IsA(className) then
            return true
        end
    end

    return false
end

function InstanceUtil.getInstancesInDirectory(
    directory: Instance,
    validation: {
        props: { [string]: any | (value: any) -> boolean }?,
        validator: ((instance: Instance) -> boolean)?,
        attributes: Attributes.AttributeValidationData?,
        tags: ({ string } | { [string]: boolean })?,
        includeSelf: boolean?,
        isA: (string | { string })?,
    }
)
    local instances: { Instance } = {}

    local instancesToCheck = directory:GetDescendants()
    if validation and validation.includeSelf then
        table.insert(instancesToCheck, directory)
    end

    for _, instance in pairs(instancesToCheck) do
        if validation.isA and not InstanceUtil.doesInstancePassIsAValidation(instance, validation.isA) then
            continue
        end

        if validation.props and not InstanceUtil.doesInstancePassPropsValidation(instance, validation.props) then
            continue
        end

        if validation.attributes and not Attributes.doesInstancePassAttributeValidation(instance, validation.attributes) then
            continue
        end

        if validation.tags and not InstanceUtil.doesInstancePassTagsValidation(instance, validation.tags) then
            continue
        end

        if validation.validator and not validation.validator(instance) then
            continue
        end

        table.insert(instances, instance)
    end

    return instances
end

function InstanceUtil.observeInstancesInDirectory(
    directory: Instance,
    observer: (instance: any) -> (() -> ())?,
    validation: {
        props: { [string]: any | (value: any) -> boolean }?,
        validator: ((instance: Instance) -> boolean)?,
        attributes: Attributes.AttributeValidationData?,
        tags: ({ string } | { [string]: boolean })?,
        eventTriggers: { string }?,
        includeSelf: boolean?,
        isA: (string | { string })?,
    }?
)
    local isCleaningUp = false
    local trovesByInstance: { [Instance]: Trove.Trove } = {}
    local unobserveDescendantAdded = InstanceUtil.descendantAdded(directory, function(instance)
        local trove = Trove.new()
        trovesByInstance[instance] = trove

        local isObserving = false
        local unobserve: (() -> ())? = nil
        local function update()
            local shouldObserve = instance:IsDescendantOf(directory)

            if shouldObserve and validation and validation.isA then
                shouldObserve = InstanceUtil.doesInstancePassIsAValidation(instance, validation.isA)
            end

            if shouldObserve and validation and validation.props then
                shouldObserve = InstanceUtil.doesInstancePassPropsValidation(instance, validation.props)
            end

            if shouldObserve and validation and validation.attributes then
                shouldObserve = Attributes.doesInstancePassAttributeValidation(instance, validation.attributes)
            end

            if shouldObserve and validation and validation.tags then
                shouldObserve = InstanceUtil.doesInstancePassTagsValidation(instance, validation.tags)
            end

            if shouldObserve and validation and validation.validator then
                shouldObserve = validation.validator(instance)
            end

            if shouldObserve == isObserving then
                return
            end
            isObserving = shouldObserve

            if shouldObserve then
                unobserve = observer(instance)
                if unobserve then
                    trove:Add(unobserve)
                end
            else
                if unobserve then
                    if not isCleaningUp then
                        trove:Remove(unobserve)
                    end

                    unobserve = nil
                end
            end
        end

        update()

        -- Update Triggers
        trove:Add(instance.AncestryChanged:Connect(update))

        if validation then
            if validation.eventTriggers then
                for _, event in pairs(validation.eventTriggers) do
                    if event == "AncestryChanged" then
                        continue
                    end

                    trove:Add(instance[event]:Connect(update))
                end
            end

            if validation.attributes then
                for attribute, _ in pairs(validation.attributes) do
                    trove:Add(instance:GetAttributeChangedSignal(attribute):Connect(update))
                end
            end

            if validation.props then
                for propertyName, _ in pairs(validation.props) do
                    trove:Add(instance:GetPropertyChangedSignal(propertyName):Connect(update))
                end
            end
        end

        return function()
            isCleaningUp = true
            trove:Destroy()
            trovesByInstance[instance] = nil
        end
    end, {
        Inclusive = true,
        IncludeSelf = validation and validation.includeSelf,
    })

    return unobserveDescendantAdded
end

InstanceUtil.observeAttributes = Attributes.observeAttributes

function InstanceUtil.findFirstChild(
    instance: Instance,
    validation: {
        recursive: boolean?,
        props: { [string]: any | (value: any) -> boolean }?,
        validator: ((instance: Instance) -> boolean)?,
        attributes: Attributes.AttributeValidationData?,
        tags: ({ string } | { [string]: boolean })?,
        includeSelf: boolean?,
        errorIfNotFound: boolean?,
        isA: (string | { string })?,
    }
): Instance?
    local instancesToCheck = instance:GetChildren()
    if validation and validation.includeSelf then
        table.insert(instancesToCheck, instance)
    end

    for _, child in pairs(instancesToCheck) do
        if validation.isA and not InstanceUtil.doesInstancePassIsAValidation(child, validation.isA) then
            continue
        end

        if validation.props and not InstanceUtil.doesInstancePassPropsValidation(child, validation.props) then
            continue
        end

        if validation.attributes and not Attributes.doesInstancePassAttributeValidation(child, validation.attributes) then
            continue
        end

        if validation.tags and not InstanceUtil.doesInstancePassTagsValidation(child, validation.tags) then
            continue
        end

        if validation.validator and not validation.validator(child) then
            continue
        end

        return child
    end

    local errorIfNotFound = validation.errorIfNotFound
    if errorIfNotFound then
        validation = table.clone(validation) -- incase we recurse further down the tree ..
        validation.errorIfNotFound = nil
    end

    if validation.recursive then
        for _, child in pairs(instance:GetChildren()) do
            local foundChild = InstanceUtil.findFirstChild(child, validation)
            if foundChild then
                return foundChild
            end
        end
    end

    if errorIfNotFound then
        Logger.error(`Could not find child in {instance:GetFullName()}`)
    end

    return nil
end

InstanceUtil.isInstanceDestroyed = isInstanceDestroyed

function InstanceUtil.onDestroyed(instance: Instance, onDestroyed: () -> ())
    local connection: RBXScriptConnection
    connection = instance.AncestryChanged:Connect(function()
        if not isInstanceDestroyed(instance) then
            return
        end

        connection:Disconnect()
        onDestroyed()
    end)

    return connection
end

export type HydrateOptions = {
    ClassName: string?, -- required in all non-root Options. Ignored in root-level Options.
    Props: { [string]: any }?,
    Tags: { [string]: boolean }?, -- true to add, false to remove, nil to ignore
    Attributes: { [string]: any | typeof(Attributes.None) }?, -- any to set, Attributes.None to remove, nil to ignore
    Children: {
        [string]: HydrateOptions, -- keys are reference
    }?,
}

local HYDRATE_CHILD_ID_ATTRIBUTE = "_HydrateChildId"

local _typecheckHydrateOptions = t.interface({
    ClassName = t.optional(t.string),
    Props = t.optional(t.map(t.string, t.any)),
    Tags = t.optional(t.map(t.string, t.boolean)),
    Attributes = t.optional(t.map(t.string, t.any)),
})

local typecheckHydrateOptions = function(topLevel: HydrateOptions)
    local topSuccess, topErr = _typecheckHydrateOptions(topLevel)
    if not topSuccess then
        return false, topErr
    end

    -- Now typecheck `Children` down the tree, also asserting that ClassName exists.
    local function recurse(options: HydrateOptions, path: string)
        local classNameSuccess, classNameErr = t.string(options.ClassName)
        if not classNameSuccess then
            return false, `{path}: {classNameErr}`
        end

        local success, err = _typecheckHydrateOptions(options)
        if not success then
            return false, `{path}: {err}`
        end

        if options.Children then
            for childName, childOptions in pairs(options.Children) do
                local childPath = `{path}.Children.{childName}`
                local childSuccess, childErr = recurse(childOptions, childPath)
                if not childSuccess then
                    return false, `{childPath}: {childErr}`
                end
            end
        end

        return true
    end

    if topLevel.Children then
        for childName, childOptions in pairs(topLevel.Children) do
            local success, err = recurse(childOptions, `Children.{childName}`)
            if not success then
                return false, err
            end
        end
    end

    return true
end

local function hydrate(instance: Instance, options: HydrateOptions, hydrateAttributeId: string)
    if options.Props then
        InstanceUtil.setProps(instance, options.Props)
    end
    if options.Tags then
        InstanceUtil.setTags(instance, options.Tags)
    end
    if options.Attributes then
        Attributes.setAttributes(instance, options.Attributes)
    end

    local keepChildren: { [Instance]: true } = {}
    if options.Children then
        for childId, childHydrateOptions in pairs(options.Children) do
            local childInstance: Instance
            do
                local existingChildInstance = InstanceUtil.findFirstChild(instance, {
                    attributes = {
                        [hydrateAttributeId] = childId,
                    },
                })

                if existingChildInstance and existingChildInstance.ClassName == childHydrateOptions.ClassName then
                    childInstance = existingChildInstance
                else
                    childInstance = Instance.new(childHydrateOptions.ClassName)
                    childInstance:SetAttribute(hydrateAttributeId, childId)
                end
            end

            keepChildren[childInstance] = true

            -- send hydration down the tree, appending parent on the way
            hydrate(
                childInstance,
                Table.Sift.Dictionary.mergeDeep(childHydrateOptions, {
                    Props = {
                        Parent = instance,
                    },
                }),
                hydrateAttributeId
            )
        end
    end

    for _, child in pairs(instance:GetChildren()) do
        if keepChildren[child] then
            continue
        end

        if not child:GetAttribute(hydrateAttributeId) then
            continue
        end

        child:Destroy()
    end
end

--[=[
    Hydrates an instance with props and children.

    `options.Props` is a table of properties to set on the instance.
    `options.Children` is a table of children to set on the instance.

    Children are identified by a unique string id, and are created if they do not exist, or updated if they do exist.
    Children are destroyed if they are not in the `options.Children` table.

    If you have multiple pieces of code that are hydrating the same instance(s), you can pass a `hydrateId` to differentiate between them.

    Example:
    ```lua
    local frame = Instance.new("Frame")
    InstanceHydrate.hydrate(frame, {
        Props = {
            Size = UDim2.new(1, 0, 1, 0),
        },
        Children = {
            Child1 = {
                ClassName = "Frame",
                Options = {
                    Props = {
                        Size = UDim2.new(1, 0, 1, 0),
                    },
                },
            },
        },
    })
    ```

    --!! GetAttribute is expensive, we may need to optimise this. We'll see.
]=]
function InstanceUtil.hydrate(instance: Instance, options: HydrateOptions, hydrateId: string?)
    local success, err = typecheckHydrateOptions(options)
    if not success then
        Logger.error(err)
    end

    local hydrateParentId = hydrateId or "_global"

    -- We generate a unique hydrate Id for this parent, incase we have multiple hydrate calls in the same tree but on different parents.
    -- This lets different parts of the codebase not interfere with each other.
    hydrate(instance, options, `{HYDRATE_CHILD_ID_ATTRIBUTE}_{hydrateParentId}`)
end

return InstanceUtil
