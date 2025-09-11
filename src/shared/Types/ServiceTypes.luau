local Packages = game:GetService("Packages")
local Janitor = require(Packages.Janitor)


local Service = {}
Service.__index = Service

export type self = {
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
}

return Service
