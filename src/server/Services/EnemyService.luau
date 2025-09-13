--!nocheck
--!native
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CombatManager = require(ServerScriptService.Server.Core.CombatManager)
local Jecs = require(ReplicatedStorage.Packages.Jecs)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local SignalPlus = require(ServerScriptService.ServerPackages.SignalPlus)
local CharacterTypes = require(ReplicatedStorage.Shared.Types.CharacterTypes)
local Utils = require(ReplicatedStorage.Shared.Utils)

local enemiesFolder = ReplicatedStorage.Assets.Enemies

local EnemyService = {}
EnemyService.__index = EnemyService

local HEALTH_THRESHOLD = 0

type Components = {
	Health: Jecs.Entity<number>,
	Radius: Jecs.Entity<number>,
	Speed: Jecs.Entity<number>,
	TargetMode: Jecs.Entity<string>,
	Cooldown: Jecs.Entity<number>,
	RangeDamage: Jecs.Entity<number>,
	Character: Jecs.Entity<Model>,
}

type CachedTargets = { [number]: Model }

type self = {
	world: typeof(Jecs.World.new()),
	janitor: Janitor.Janitor,
	enemyAdded: SignalPlus.Signal<Model, Jecs.Entity>,
	enemyRemoved: SignalPlus.Signal<Model, Jecs.Entity>,
	serviceManager: any,
	components: Components,
	allyService: any,
	cachedTargets: CachedTargets,
	enemiesQuery: Jecs.Query<number, Model>?,
} & typeof(EnemyService)

--- Creates a new EnemyService instance
function EnemyService.new(serviceManager): self
	local self = setmetatable({}, EnemyService)
	self.world = Jecs.World.new()
	self.janitor = Janitor.new()
	self.enemyAdded = SignalPlus()
	self.enemyRemoved = SignalPlus()
	self.serviceManager = serviceManager

	self.components = {
		Health = self.world:component(),
		Radius = self.world:component(),
		Speed = self.world:component(),
		TargetMode = self.world:component(),
		Cooldown = self.world:component(),
		RangeDamage = self.world:component(),
		Character = self.world:component(),
	}

	self.cachedTargets = {}
	self.enemiesQuery = nil

	return self
end

function EnemyService.init(self: self)
	self.allyService = self.serviceManager:getService("AllyService")
	self:_updateTargetCache()
	self:_setupSignalConnections()
	self:_createQueries()
end

function EnemyService._createQueries(self: self)
	self.enemiesQuery = self.world:query(self.components.Character):cached()
end

function EnemyService._setupSignalConnections(self: self)
	self.enemyAdded:Connect(function(character, enemy)
		self:_onEnemyAdded(character, enemy)
	end)

	self.enemyRemoved:Connect(function(character, enemy)
		self:_onEnemyRemoved(character, enemy)
	end)

	if self.allyService then
		self.allyService.allyAdded:Connect(function()
			self:_updateTargetCache()
		end)

		self.allyService.allyRemoved:Connect(function()
			self:_updateTargetCache()
		end)
	end
end

function EnemyService._onEnemyAdded(self: self, character: Model, enemy: Jecs.Entity)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn(`No humanoid found for enemy {enemy}`)
		return
	end

	local health = self.world:get(enemy, self.components.Health)
	humanoid.MaxHealth = health
	humanoid.Health = health
	local speed = self.world:get(enemy, self.components.Speed)
	humanoid.WalkSpeed = speed

	humanoid.Died:Once(function()
		Utils.fadeoutCharacter(character)
		self:removeEnemy(character, enemy)
	end)

	character.Parent = workspace.Temp
	print(`{character.Name} enemy was added`)
end

function EnemyService._onEnemyRemoved(self: self, character: Model, enemy: Jecs.Entity)
	if self.world:contains(enemy) then
		self.world:delete(enemy)
	end
	self.janitor:Remove(character)
	print(`{character.Name} enemy was removed`)
end

function EnemyService._updateTargetCache(self: self)
	self.cachedTargets = {}
	if self.allyService then
		local allies = self.allyService:getAllies()
		if allies then
			for _, character in allies do
				table.insert(self.cachedTargets, character)
			end
		end
	end
end

function EnemyService._isValidEnemy(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > HEALTH_THRESHOLD
end

--- @brief Adds a new enemy
function EnemyService.addEnemy(self: self, metadata: CharacterTypes.EnemyMetadata): (Jecs.Entity, Model)
	local enemy = self.world:entity()
	local character = enemiesFolder[metadata.name]:Clone()

	if not character then
		error(`Enemy template '{metadata.name}' not found in enemies folder`)
	end

	character:PivotTo(metadata.cframe)

	self.world:set(enemy, self.components.Character, character)
	self.world:set(enemy, self.components.Health, metadata.health)
	self.world:set(enemy, self.components.Speed, metadata.speed)
	self.world:set(enemy, self.components.TargetMode, metadata.targetMode)
	self.world:set(enemy, self.components.Cooldown, metadata.cooldown or 0)

	if metadata.radius then
		self.world:set(enemy, self.components.Radius, metadata.radius)
	end
	if metadata.rangeDamage then
		self.world:set(enemy, self.components.RangeDamage, metadata.rangeDamage)
	end

	self.janitor:Add(character, "Destroy", character)
	self.enemyAdded:Fire(character, enemy)

	return enemy, character
end

function EnemyService.removeEnemy(self: self, character: Model, enemy: Jecs.Entity)
	if character and self.world:contains(enemy) then
		self.enemyRemoved:Fire(character, enemy)
	else
		warn("Attempted to remove non-existent enemy")
	end
end

function EnemyService.getEnemies(self: self): Jecs.Query<number, Model>?
	return self.enemiesQuery
end

function EnemyService.update(self: self, dt: number)
	for enemy, character, radius, targetMode, cooldown in
		self.world:query(
			self.components.Character,
			self.components.Radius,
			self.components.TargetMode,
			self.components.Cooldown
		)
	do
		if not self._isValidEnemy(character) then
			continue
		end

		if cooldown > 0 then
			cooldown -= dt
			self.world:set(enemy, self.components.Cooldown, math.max(0, cooldown))
		end

		if CombatManager then
			CombatManager.processCharacterCombat(
				self.world,
				enemy,
				character,
				radius,
				targetMode,
				cooldown,
				dt,
				self.cachedTargets,
				self.components.RangeDamage,
				self.components.Cooldown
			)
		end
	end
end

--- Clears all enemies and cleans up resources
function EnemyService.clear(self: self)
	if self.enemiesQuery then
		for _, character in self.enemiesQuery do
			if character and character.Parent then
				character:Destroy()
			end
		end
	end

	self.world:cleanup()
	self.janitor:Cleanup()

	self.cachedTargets = {}
	self.enemiesQuery = nil
end

return EnemyService
