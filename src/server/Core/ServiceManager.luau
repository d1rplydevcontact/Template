--!strict
--!native
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Packages = ReplicatedStorage.Packages
local Promise = require(Packages.Promise)
local ServiceTypes = require(ReplicatedStorage.Shared.Types.ServiceTypes)

local ServiceManager = {}
ServiceManager.__index = ServiceManager

export type ServiceManager = typeof(setmetatable({}, ServiceManager))

-- Exclude service from executing
local BLACKLISTED_SERVICES = {
	"WaveService",
}

local servicesFolder = ServerScriptService.Server.Services

--- @brief Create a singleton ServiceManager instance
--- @return ServiceManager
function ServiceManager.new(): ServiceManager
	local self = setmetatable({}, ServiceManager)
	self.services = {}
	return self
end

--- @brief Call the update method of a service every PostSimulation
--- @param serviceInstance ServiceTypes.Service
--- @param serviceName string
local function updateServiceAsync(serviceInstance, serviceName: string)
	Promise.try(function()
		local cb = serviceInstance.update
		if cb then
			RunService.PostSimulation:Connect(function(dt)
				cb(serviceInstance, dt)
			end)
		else
			warn(serviceName .. " does not have an 'update' method")
		end
	end):catch(function(err)
		error("Failed to setup update for service " .. serviceName .. ": " .. tostring(err))
	end)
end

--- @brief Initialize all services in the ServiceManager
--- @param self ServiceManager
function ServiceManager:init()
	for _, serviceModule in ipairs(servicesFolder:GetChildren()) do
		if serviceModule:IsA("ModuleScript") then
			if table.find(BLACKLISTED_SERVICES, serviceModule.Name) then
				return warn(serviceModule.Name, "is blacklisted")
			end

			local success, result = pcall(function()
				local service = require(serviceModule) :: ServiceTypes.Service
				local serviceInstance = service.new()
				serviceInstance:init()

				self.services[serviceModule.Name] = serviceInstance

				updateServiceAsync(serviceInstance, serviceModule.Name)

				return serviceInstance
			end)

			if not success then
				error("Failed to initialize service " .. serviceModule.Name .. ": " .. tostring(result))
			end
		end
	end
	print("Initialized the ServiceManager services")
end

--- @brief Get a service instance by name
--- @param self ServiceManager
--- @param name string
function ServiceManager:getService(name: string): ServiceTypes.Service?
	local service = self.services[name]
	if not service then
		warn("Service not found: " .. name)
		return nil
	end
	return service
end

--- @brief Clear all services
--- @param self ServiceManager
function ServiceManager:clearAllServices()
	for _, service in pairs(self.services) do
		if service.clear then
			service.clear()
		end
	end
	print("Cleared all the services")
end

return ServiceManager
