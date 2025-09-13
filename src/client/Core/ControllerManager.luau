--!native
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Jecs = require(ReplicatedStorage.Packages.Jecs)
local ControllerTypes = require(ReplicatedStorage.Shared.Types.ControllerTypes)

local ControllerManager = {}
ControllerManager.__index = ControllerManager

type self = {
	controllers: { [string]: ControllerTypes.Controller },
	world: typeof(Jecs.World.new()),
} & typeof(ControllerManager)

export type ControllerManager = typeof(setmetatable({}, ControllerManager))

local BLACKLISTED_CONTROLLERS = {}
local controllersFolder = StarterPlayer.StarterPlayerScripts.Client.Controllers

function ControllerManager.new(): ControllerManager
	local self = setmetatable({}, ControllerManager)
	self.world = Jecs.World.new()
	self.controllers = {}
	return self
end

--- Initialize all controllers
function ControllerManager.init(self: self)
	for _, moduleScript in ipairs(controllersFolder:GetChildren()) do
		if moduleScript:IsA("ModuleScript") then
			if table.find(BLACKLISTED_CONTROLLERS, moduleScript.Name) then
				warn(moduleScript.Name, "is blacklisted")
				continue
			end
			local success, result = pcall(function()
				local controllerModule = require(moduleScript) :: ControllerTypes.Controller
				local controllerInstance = controllerModule.new(self)
				return controllerInstance
			end)
			if success then
				self.controllers[moduleScript.Name] = result
			else
				warn(`Failed to load controller {moduleScript.Name}:`, result)
			end
		end
	end

	for name, controller in pairs(self.controllers) do
		if controller.init then
			local success, err = pcall(controller.init, controller)
			if not success then
				warn(`Failed to initialize controller {name}:`, err)
			end
		end
	end

	RunService.PostSimulation:Connect(function(dt)
		for name, controller in pairs(self.controllers) do
			if controller.update then
				local success, err = pcall(controller.update, controller, dt)
				if not success then
					warn("Failed to update controller", name, err)
				end
			end
		end
	end)
end

function ControllerManager.getController(self: self, name: string): ControllerTypes.Controller?
	local controller = self.controllers[name]
	if not controller then
		warn(`Controller not found: {name}. Available controllers:`, table.concat(self:getControllerNames(), ", "))
		return nil
	end
	return controller
end

function ControllerManager.getControllerNames(self: self): { string }
	local names = {}
	for name in pairs(self.controllers) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function ControllerManager.hasController(self: self, name: string): boolean
	return self.controllers[name] ~= nil
end

function ControllerManager.clearAllControllers(self: self)
	for name, controller in pairs(self.controllers) do
		if controller.clear then
			local success, err = pcall(controller.clear, controller)
			if not success then
				warn(`Failed to clear controller {name}:`, err)
			end
		end
	end
end

return ControllerManager
