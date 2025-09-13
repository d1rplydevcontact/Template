--!strict
--!native
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Jecs = require(ReplicatedStorage.Packages.Jecs)
local ServiceTypes = require(ReplicatedStorage.Shared.Types.ServiceTypes)

local ServiceManager = {}
ServiceManager.__index = ServiceManager

type self = {
	services: { [string]: ServiceTypes.Service },
	world: typeof(Jecs.World.new()),
} & ServiceManager
export type ServiceManager = typeof(setmetatable({}, ServiceManager))

local BLACKLISTED_SERVICES = { "WaveService" }
local servicesFolder = ServerScriptService.Server.Services

--- Create a new ServiceManager instance
function ServiceManager.new(): ServiceManager
	local self = setmetatable({}, ServiceManager)
	self.world = Jecs.World.new()
	self.services = {}
	return self
end

--- Initialize all services
function ServiceManager.init(self: self)
	for _, moduleScript in ipairs(servicesFolder:GetChildren()) do
		if moduleScript:IsA("ModuleScript") then
			if table.find(BLACKLISTED_SERVICES, moduleScript.Name) then
				warn(moduleScript.Name, "is blacklisted")
				continue
			end

			local serviceModule = require(moduleScript) :: ServiceTypes.Service
			local serviceInstance = serviceModule.new(self)
			self.services[moduleScript.Name] = serviceInstance
		end
	end

	for name, service in pairs(self.services) do
		if service.init then
			service:init()
		end
	end

	RunService.PostSimulation:Connect(function(dt)
		for name, service in pairs(self.services) do
			if service.update then
				local success, err = pcall(service.update, service, dt)
				if not success then
					warn("Failed to update service", name, err)
				end
			end
		end
	end)
end

--- Retrieve a service by name
function ServiceManager.getService(self: self, name: string): ServiceTypes.Service?
	local service = self.services[name]
	if not service then
		warn("Service not found:", name)
		return nil
	end
	return service
end

--- Clear all services by calling their `clear` method
function ServiceManager.clearAllServices(self: self)
	for _, service in pairs(self.services) do
		if service.clear then
			service:clear()
		end
	end
	print("Cleared all services")
end

return ServiceManager
