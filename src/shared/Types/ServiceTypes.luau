local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Packages = ReplicatedStorage.Packages
local EnemyService = require(ServerScriptService.Server.Services.EnemyService)
local Jecs = require(Packages.Jecs)
local Janitor = require(Packages.Janitor)

local Service = {}

export type self = {
	world: typeof(Jecs.World.new()),
	janitor: Janitor.Janitor,
	--- @brief Updates the service instance every heartbeat
	--- @param self The service instance
	update: self,
	--- @brief Frees up memory from the service instance
	--- @param self The service instance
	clear: self,
} & {
	[string]: any,
}

export type Service = {
	--- @returns self The service instance
	new: () -> self,
	init: (self) -> (),
}

-- Individual services
export type EnemyService = typeof(setmetatable({}, EnemyService)) & Service

return Service
