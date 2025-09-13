--!native
local ServiceManager = require(script.Core.ServiceManager)
local serviceManager = ServiceManager.new()
serviceManager:init()

local enemyService = serviceManager:getService("EnemyService")
local allyService = serviceManager:getService("AllyService")

enemyService:addEnemy("StarterEnemy")
allyService:addAlly("StarterAlly")
