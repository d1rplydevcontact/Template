--!strict
--!native
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Packages = ReplicatedStorage.Packages
local Promise = require(Packages.Promise)
local ControllerTypes = require(ReplicatedStorage.Shared.Types.ControllerTypes)

local ControllerManager = {}
ControllerManager.__index = ControllerManager

type self = {
	controllers: { [string]: ControllerTypes.Controller },
}

export type ControllerManager = typeof(setmetatable({} :: self, ControllerManager))

local BLACKLISTED_CONTROLLERS = {}

local controllersFolder = script.Parent.Parent.Controllers

--- @brief Create a singleton ControllerManager instance
--- @return ControllerManager
function ControllerManager.new(): ControllerManager
	local self = setmetatable({}, ControllerManager)
	self.controllers = {}
	return self
end

--- @brief Call the update method of a controller every PreRender
--- @param controllerInstance ControllerTypes.Controller
--- @param controllerName string
local function updateControllerAsync(controllerInstance, controllerName: string)
	return Promise.try(function()
		local cb = controllerInstance.update
		if cb then
			RunService.PreRender:Connect(function(dt)
				cb(controllerInstance, dt)
			end)
		else
			warn(controllerName .. " does not have an 'update' method")
		end
	end):catch(function(err)
		error("Failed to setup update for controller " .. controllerName .. ": " .. tostring(err))
	end)
end

--- @brief Initialize all controllers in the ControllerManager
--- @param self ControllerManager
function ControllerManager:init()
	for _, controllerModule in ipairs(controllersFolder:GetChildren()) do
		if controllerModule:IsA("ModuleScript") then
			if table.find(BLACKLISTED_CONTROLLERS, controllerModule.Name) then
				return warn(controllerModule.Name, "is blacklisted")
			end
			local success, result = pcall(function()
				local controller = require(controllerModule) :: ControllerTypes.Controller
				local controllerInstance = controller.new()
				controllerInstance:init()

				self.controllers[controllerModule.Name] = controllerInstance

				updateControllerAsync(controllerInstance, controllerModule.Name)

				return controllerInstance
			end)

			if not success then
				error("Failed to initialize controller " .. controllerModule.Name .. ": " .. tostring(result))
			end
		end
	end
	print("Initialized the ControllerManager controllers")
end

--- @brief Get a controller instance by name
--- @param self ControllerManager
--- @param name string
function ControllerManager:getController(name: string): ControllerTypes.Controller?
	local controller = self.controllers[name]
	if not controller then
		warn("Controller not found: " .. name)
		return nil
	end
	return controller
end

--- @brief Clear all controllers
--- @param self ControllerManager
function ControllerManager:clearAllControllers()
	for _, controller in pairs(self.controllers) do
		if controller.clear then
			controller.clear()
		end
	end
	print("Cleared all the controllers")
end

return ControllerManager
