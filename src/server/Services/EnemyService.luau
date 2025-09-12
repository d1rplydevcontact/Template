--!native
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SignalPlus = require(ServerScriptService.ServerPackages.SignalPlus)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Jecs = require(ReplicatedStorage.Packages.Jecs)
local EnemyTypes = require(ReplicatedStorage.Shared.Types.EnemyTypes)
local Utils = require(ReplicatedStorage.Shared.Utils)

local enemiesFolder = ReplicatedStorage.Assets.Enemies

local EnemyService = {}
EnemyService.__index = EnemyService

type self = {
	world: typeof(Jecs.World.new()),
	janitor: Janitor.Janitor,
	enemyAdded: SignalPlus.Signal<Model, Jecs.Entity>,
	enemyRemoved: SignalPlus.Signal<Model, Jecs.Entity>,

	traits: {
		Position: number,
		Health: number,
		Speed: number,
		Model: number,
		Animations: number,
	},
} & typeof(setmetatable({}, EnemyService))

--- @brief Creates a new EnemyService instance
--- @return self EnemyService instance
function EnemyService.new()
	local self = setmetatable({}, EnemyService)

	self.world = Jecs.World.new()
	self.janitor = Janitor.new()
	self.enemyAdded = SignalPlus()
	self.enemyRemoved = SignalPlus()

	-- Define shared components across all enemies
	self.traits = {
		Position = self.world:component(),
		Health = self.world:component(),
		Speed = self.world:component(),
		Animations = self.world:component(),
		Model = self.world:component(),
	}

	return self
end

--- @brief Initializes enemy service events and cleanup logic
--- @param self self
function EnemyService.init(self: self)
	self.enemyAdded:Connect(function(model, enemy)
		local animations = self.world:get(enemy, self.traits.Animations)
		if animations then
			for _, animId: string in pairs(animations) do
				Utils.loadAnimation(model, animId)
			end
		end

		model.Parent = workspace.Temp.Enemies
		print(model.Name, "was added")
	end)

	self.enemyRemoved:Connect(function(model, enemy)
		self.world:delete(enemy)
		self.janitor:Remove(model)
		print(model.Name, "was removed")
	end)
end

--- @brief Adds an enemy entity to the world
--- @param self self
--- @param metadata EnemyTypes.Metadata Enemy configuration (name, position, health, speed, etc.)
function EnemyService.addEnemy(self: self, metadata: EnemyTypes.Metadata)
	local enemy = self.world:entity()
	local enemyModel = enemiesFolder[metadata.name]:Clone()

	self.world:set(enemy, self.traits.Model, enemyModel)
	self.world:set(enemy, self.traits.Position, metadata.position)
	self.world:set(enemy, self.traits.Health, metadata.health)
	self.world:set(enemy, self.traits.Speed, metadata.speed)
	self.world:set(enemy, self.traits.Animations, metadata.animations)

	self.janitor:Add(enemyModel, "Destroy", enemyModel)
	self.enemyAdded:Fire(enemyModel, enemy)
end

--- @brief Removes an enemy from both ECS and workspace
--- @param self self
--- @param model Model Roblox model of the enemy to remove
function EnemyService.removeEnemy(self: self, model: Model)
	for enemy in self.world:query(self.traits.Model) do
		local m = self.world:get(enemy, self.traits.Model)
		if m == model then
			self.enemyRemoved:Fire(m, enemy)
			return
		end
	end
	warn("Enemy not found")
end

--- @brief Updates all enemies each frame (movement, AI, etc.)
--- @param self self
--- @param dt number Delta time since last frame
function EnemyService.update(self: self, dt: number)
	-- Implementation later (movement logic, etc.)
end

--- @brief Cleans up the ECS world and Janitor
--- @param self self
function EnemyService.clear(self: self)
	self.world:cleanup()
	self.janitor:Cleanup()
end

return EnemyService
