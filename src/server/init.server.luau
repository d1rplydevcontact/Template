--!strict
--!native
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServiceTypes = require(ReplicatedStorage.Shared.Types.ServiceTypes)
local ServiceManager = require(script.Core.ServiceManager)

local serviceManager = ServiceManager.new()
serviceManager:init()

local enemyService = serviceManager:getService("EnemyService") :: ServiceTypes.EnemyService
--[=[
	Test
	```luau
		type Metadata = {
			name: string,
			position: Vector3,
			health: number,
			speed: number,
		}
	```
]=]
enemyService:addEnemy({
	name = "Enemy",
	position = workspace["Winter Map"]:FindFirstChild("Path"):FindFirstChildOfClass("Part").Position,
	health = 50,
	speed = 100,
})
