local Packages = game:GetService("Packages")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Jecs = require(Packages.Jecs)
local Promise = require(Packages.Promise)
local ServiceTypes = require(ReplicatedStorage.Shared.Types.ServiceTypes)
local Utils = require(ReplicatedStorage.Shared.Utils)

local logger = Utils.logger

local world = Jecs.World.new()

local ServiceComponent = world:component({
	name = "string",
	instance = "any",
})

local ServiceManager = {}
ServiceManager.__index = ServiceManager

type self = {
	services: { [string]: Jecs.Entity<ServiceTypes.Service> },
}
export type ServiceManager = typeof(setmetatable({} :: self, ServiceManager))

local servicesFolder = ServerScriptService.Server.Services

--- @brief Create a singleton ServiceManager instance
--- @return ServiceManager
function ServiceManager.new()
	local self = setmetatable({}, ServiceManager)
	self.services = {}
	return self
end

--- @brief Call the update method of a service every heartbeat
--- @param serviceInstance ServiceTypes.Service
--- @param serviceName string
local function updateServiceAsync(serviceInstance, serviceName)
	Promise.try(function()
		local cb = serviceInstance.update
		if cb then
			RunService.Heartbeat:Connect(function(dt)
				cb(dt)
			end)
		else
			logger:error(serviceName .. " does not have an 'update' method")
		end
	end)
end

--- @brief Initialize all services in the ServiceManager
--- @param self ServiceManager
function ServiceManager.init(self)
	for _, serviceModule in ipairs(servicesFolder:GetChildren()) do
		local service = require(serviceModule) :: ServiceTypes.Service
		local serviceInstance = service.new()

		local entity = world:entity()
		entity:add(ServiceComponent, {
			name = serviceModule.Name,
			instance = serviceInstance,
		})
		self.services[serviceModule.Name] = entity

		updateServiceAsync(serviceInstance, serviceModule.Name)
	end
end

--- @brief Get a service instance by name
--- @param self ServiceManager
--- @param name string
function ServiceManager.getService(self, name)
	local entity = self.services[name]
	if not entity then
		logger:warn("Service not found: " .. name)
		return nil
	end
	return entity:get(ServiceComponent).instance
end

--- @brief Clear all services
--- @param self ServiceManager
function ServiceManager.clearAllServices(self)
	for _, entity in pairs(self.services) do
		local service = entity:get(ServiceComponent).instance
		if service.clear then
			service.clear()
		end
	end
	logger:info("Cleared all the services")
end
