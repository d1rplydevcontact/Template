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
} & typeof(ServiceManager)

export type ServiceManager = typeof(setmetatable({}, ServiceManager))

local BLACKLISTED_SERVICES = {}
local servicesFolder = ServerScriptService.Server.Services

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
			local success, result = pcall(function()
				local serviceModule = require(moduleScript) :: ServiceTypes.Service
				local serviceInstance = serviceModule.new(self)
				return serviceInstance
			end)
			if success then
				self.services[moduleScript.Name] = result
			else
				warn(`Failed to load service {moduleScript.Name}:`, result)
			end
		end
	end

	for name, service in pairs(self.services) do
		if service.init then
			local success, err = pcall(service.init, service)
			if not success then
				warn(`Failed to initialize service {name}:`, err)
			end
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

function ServiceManager.getService(self: self, name: string): ServiceTypes.Service?
	local service = self.services[name]
	if not service then
		warn(`Service not found: {name}. Available services:`, table.concat(self:getServiceNames(), ", "))
		return nil
	end
	return service
end

function ServiceManager.getServiceNames(self: self): { string }
	local names = {}
	for name in pairs(self.services) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function ServiceManager.hasService(self: self, name: string): boolean
	return self.services[name] ~= nil
end

function ServiceManager.clearAllServices(self: self)
	for name, service in pairs(self.services) do
		if service.clear then
			local success, err = pcall(service.clear, service)
			if not success then
				warn(`Failed to clear service {name}:`, err)
			end
		end
	end
end

return ServiceManager
