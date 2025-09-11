local Packages = game:GetService("Packages")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Promise = require(Packages.Promise)
local Jecs = require(Packages.Jecs)
local ControllerTypes = require(ReplicatedStorage.Shared.Types.ControllerTypes)
local Utils = require(ReplicatedStorage.Shared.Utils)

local logger = Utils.logger

local world = Jecs.World.new()

local ControllerComponent = world:component({
	name = "string",
	instance = "any",
})

local ControllerManager = {}
ControllerManager.__index = ControllerManager

--- @type self
--- @field controllers table<string, Jecs.Entity>
type self = {
	controllers: { [string]: Jecs.Entity<ControllerTypes.Controller> }
}
export type ControllerManager = typeof(setmetatable({} :: self, ControllerManager))

local controllersFolder = script.Parent.Parent.Controllers

--- @brief Create a singleton ControllerManager instance
--- @return ControllerManager
function ControllerManager.new()
	local self = setmetatable({}, ControllerManager)
	self.controllers = {}
	return self
end

--- @brief Call the update method of a controller every RenderStepped
--- @param controllerInstance ControllerTypes.Controller
--- @param controllerName string
local function updateControllerAsync(controllerInstance, controllerName)
	Promise.try(function()
		local cb = controllerInstance.update
		if cb then
			RunService.RenderStepped:Connect(function(dt)
				cb(dt)
			end)
		else
			logger:error(controllerName .. " does not have an 'update' method")
		end
	end)
end

--- @brief Initialize all controllers in the ControllerManager
--- @param self ControllerManager
function ControllerManager.init(self: self)
	for _, controllerModule in ipairs(controllersFolder:GetChildren()) do
		local controller = require(controllerModule) :: ControllerTypes.Controller
		local controllerInstance = controller.new()

		local entity = world:entity()
		entity:add(ControllerComponent, {
			name = controllerModule.Name,
			instance = controllerInstance,
		})
		self.controllers[controllerModule.Name] = entity

		updateControllerAsync(controllerInstance, controllerModule.Name)
	end
end

--- @brief Get a controller instance by name
--- @param self ControllerManager
--- @param name string
--- @return ControllerTypes.Controller?
function ControllerManager.getController(self: self, name)
	local entity = self.controllers[name]
	if not entity then
		logger:warn("Controller not found: " .. name)
		return nil
	end
	return entity:get(ControllerComponent).instance
end

--- @brief Clear all controllers
--- @param self ControllerManager
function ControllerManager.clearAllControllers(self: self)
	for _, entity in pairs(self.controllers) do
		local controller = entity:get(ControllerComponent).instance
		if controller.clear then
			controller.clear()
		end
	end
	logger:info("Cleared all the controllers")
end
