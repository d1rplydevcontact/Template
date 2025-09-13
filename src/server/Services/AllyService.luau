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

local alliesInstancesFolder = ReplicatedStorage.Assets.Allies
local alliesConfigFolder = ReplicatedStorage.Shared.Allies

local AllyService = {}
AllyService.__index = AllyService

local HEALTH_THRESHOLD = 0

type Components = {
	Health: Jecs.Entity<number>,
	Radius: Jecs.Entity<number>,
	TargetMode: Jecs.Entity<string>,
	Cooldown: Jecs.Entity<number>,
	RangeDamage: Jecs.Entity<number>,
	Character: Jecs.Entity<Model>,
}

type CachedTargets = { [number]: Model }

type self = {
	world: typeof(Jecs.World.new()),
	janitor: Janitor.Janitor,
	allyAdded: SignalPlus.Signal<Model, Jecs.Entity>,
	allyRemoved: SignalPlus.Signal<Model, Jecs.Entity>,
	serviceManager: any,
	components: Components,
	enemyService: any,
	cachedTargets: CachedTargets,
	alliesQuery: Jecs.Query<number, Model>?,
} & typeof(AllyService)

function AllyService.new(serviceManager): self
	local self = setmetatable({}, AllyService)
	self.world = Jecs.World.new()
	self.janitor = Janitor.new()
	self.allyAdded = SignalPlus()
	self.allyRemoved = SignalPlus()
	self.serviceManager = serviceManager

	self.components = {
		Health = self.world:component(),
		Radius = self.world:component(),
		TargetMode = self.world:component(),
		Cooldown = self.world:component(),
		RangeDamage = self.world:component(),
		Character = self.world:component(),
	}

	self.cachedTargets = {}
	self.alliesQuery = nil

	return self
end

function AllyService.init(self: self)
	self.enemyService = self.serviceManager:getService("EnemyService")
	self:_updateTargetCache()
	self:_setupSignalConnections()
	self:_createQueries()
end

function AllyService._createQueries(self: self)
	self.alliesQuery = self.world:query(self.components.Character):cached()
end

function AllyService._setupSignalConnections(self: self)
	self.allyAdded:Connect(function(character, ally)
		self:_onAllyAdded(character, ally)
	end)

	self.allyRemoved:Connect(function(character, ally)
		self:_onAllyRemoved(character, ally)
	end)

	if self.enemyService then
		self.enemyService.enemyAdded:Connect(function()
			self:_updateTargetCache()
		end)

		self.enemyService.enemyRemoved:Connect(function()
			self:_updateTargetCache()
		end)
	end
end

--- @brief Add an ally
function AllyService._onAllyAdded(self: self, character: Model, ally: Jecs.Entity)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn(`No humanoid found for ally {ally}`)
		return
	end

	local health = self.world:get(ally, self.components.Health)
	humanoid.MaxHealth = health
	humanoid.Health = health

	humanoid.Died:Once(function()
		Utils.deathEffect(character)
		self:removeAlly(character, ally)
	end)

	character.Parent = workspace.Temp
	print(`{character.Name} ally was added`)
end

function AllyService._onAllyRemoved(self: self, character: Model, ally: Jecs.Entity)
	if self.world:contains(ally) then
		self.world:delete(ally)
	end
	self.janitor:Remove(character)
	print(`{character.Name} ally was removed`)
end

function AllyService._updateTargetCache(self: self)
	self.cachedTargets = {}
	if self.enemyService then
		local enemies = self.enemyService:getEnemies()
		if enemies then
			for _, character in enemies do
				table.insert(self.cachedTargets, character)
			end
		end
	end
end

function AllyService._isValidAlly(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > HEALTH_THRESHOLD
end

function AllyService.addAlly(self: self, name: string): (Jecs.Entity, Model)
	local metadata: CharacterTypes.AllyMetadata = require(alliesConfigFolder[name])

	local ally = self.world:entity()
	local character = alliesInstancesFolder[metadata.name]:Clone()

	if not character then
		error(`Ally template '{metadata.name}' not found in allies folder`)
	end

	character:PivotTo(metadata.position)

	self.world:set(ally, self.components.Character, character)
	self.world:set(ally, self.components.Health, metadata.health)
	self.world:set(ally, self.components.TargetMode, metadata.targetMode)
	self.world:set(ally, self.components.Cooldown, metadata.cooldown or 0)

	if metadata.radius then
		self.world:set(ally, self.components.Radius, metadata.radius)
	end
	if metadata.rangeDamage then
		self.world:set(ally, self.components.RangeDamage, metadata.rangeDamage)
	end

	self.janitor:Add(character, "Destroy", character)
	self.allyAdded:Fire(character, ally)
end

function AllyService.removeAlly(self: self, character: Model, ally: Jecs.Entity)
	if character and self.world:contains(ally) then
		self.allyRemoved:Fire(character, ally)
	else
		warn("Attempted to remove non-existent ally")
	end
end

function AllyService.getAllies(self: self): Jecs.Query<number, Model>?
	return self.alliesQuery
end

function AllyService.update(self: self, dt: number)
	-- Query allies with relevant components
	for ally, character, radius, targetMode, cooldown in
		self.world:query(
			self.components.Character,
			self.components.Radius,
			self.components.TargetMode,
			self.components.Cooldown
		)
	do
		-- Skip dead or invalid allies
		if not self._isValidAlly(character) then
			continue
		end

		-- Update cooldown
		if cooldown > 0 then
			cooldown -= dt
			self.world:set(ally, self.components.Cooldown, math.max(0, cooldown))
		end

		-- Process ECS-based combat against cached targets
		if CombatManager then
			local position = CombatManager.getHumanoidRootPart(character)
			if position then
				CombatManager.processCharacterCombatComponents(
					self.world,
					ally,
					position.Position,
					self.world:get(ally, self.components.Radius) or 0,
					self.world:get(ally, self.components.TargetMode) or "Nearest",
					self.world:get(ally, self.components.Cooldown) or 0,
					dt,
					self.cachedTargets,
					self.components
				)
			end
		end
	end
end

--- Clears all allies and cleans up resources
function AllyService.clear(self: self)
	if self.alliesQuery then
		for _, character in self.alliesQuery do
			if character and character.Parent then
				character:Destroy()
			end
		end
	end

	self.world:cleanup()
	self.janitor:Cleanup()

	self.cachedTargets = {}
	self.alliesQuery = nil
end

return AllyService
