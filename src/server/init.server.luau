--!native
local ServiceManager = require(script.Core.ServiceManager)

local serviceManager = ServiceManager.new()
serviceManager:init()

local enemyService = serviceManager:getService("EnemyService")
local allyService = serviceManager:getService("AllyService")

enemyService:addEnemy({
	name = "Starter Enemy",
	cframe = CFrame.new(Vector3.new(0, 5, 0)),
	health = 50,
	speed = 16,
	damage = 10,
	cooldown = 1,
	radius = 10,
	rangeDamage = 5,
})

allyService:addAlly({
	name = "Starter Ally",
	cframe = CFrame.new(Vector3.new(5, 5, 0)),
	health = 80,
	speed = 12,
	damage = 15,
	cooldown = 0.5,
	radius = 12,
	rangeDamage = 8,
})
