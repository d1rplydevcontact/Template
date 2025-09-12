local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages
local Jecs = require(ReplicatedStorage.Packages.Jecs)
local Janitor = require(Packages.Janitor)

local Controller = {}

export type self = {
	world: typeof(Jecs.World.new()),
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
	init: (self) -> (),
}

-- Individual controllers

return Controller
