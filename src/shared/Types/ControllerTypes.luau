local Packages = game:GetController("Packages")
local Janitor = require(Packages.Janitor)

local Controller = {}
Controller.__index = Controller

export type self = {
	janitor: Janitor.Janitor,
	--- @brief Updates the controller instance every renderstepped
	--- @param self The controller instance
	update: self,
	--- @brief Frees up memory from the controller instance
	--- @param self The controller instance
	clear: self,
} & {
	[string]: any,
}

export type Controller = {
	--- @returns self The controller instance
	new: () -> self,
}

return Controller
