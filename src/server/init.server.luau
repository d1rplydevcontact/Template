--!native
local ServiceManager = require(script.Core.ServiceManager)
local serviceManager = ServiceManager.new()
serviceManager:init()

local enemyService = serviceManager:getService("EnemyService")
local allyService = serviceManager:getService("AllyService")

-- Add ally in the center
allyService:addAlly({
	name = "Starter Ally",
	cframe = CFrame.new(Vector3.new(0, 5, 0)), -- Center position
	health = 80,
	speed = 12,
	damage = 15,
	targetMode = "Nearest",
	cooldown = 0.2,
	radius = 12,
	rangeDamage = 5,
})

-- Add enemies in a circle around the ally
local enemyPositions = {
	Vector3.new(10, 5, 0), -- East
	Vector3.new(-10, 5, 0), -- West
	Vector3.new(0, 5, 10), -- South
	Vector3.new(0, 5, -10), -- North
}

for _, position in ipairs(enemyPositions) do
	enemyService:addEnemy({
		name = "Starter Enemy",
		cframe = CFrame.new(position),
		health = 50,
		speed = 16,
		damage = 10,
		targetMode = "Nearest",
		cooldown = 1,
		radius = 10,
		rangeDamage = 2,
	})
end

task.wait(5) -- Wait 5 seconds, then add reinforcements
allyService:addAlly({
	name = "Starter Ally",
	cframe = CFrame.new(Vector3.new(3, 5, 3)),
	health = 80,
	speed = 12,
	damage = 15,
	targetMode = "Nearest",
	cooldown = 0.2,
	radius = 12,
	rangeDamage = 5,
})

task.wait(30)
serviceManager.clearAllServices(serviceManager)
