--!strict
--!native
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Jecs = require(ReplicatedStorage.Packages.Jecs)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local SignalPlus = require(ServerScriptService.ServerPackages.SignalPlus)
local CharacterTypes = require(ReplicatedStorage.Shared.Types.CharacterTypes)
local Utils = require(ReplicatedStorage.Shared.Utils)

local enemiesFolder = ReplicatedStorage.Assets.Enemies

local EnemyService = {}
EnemyService.__index = EnemyService

type Traits = {
	Health: Jecs.Entity<number>,
	Speed: Jecs.Entity<number>,
	Radius: Jecs.Entity<number>,
	Damage: Jecs.Entity<number>,
	Cooldown: Jecs.Entity<number>,
	RangeDamage: Jecs.Entity<number>,
	Character: Jecs.Entity<Model>,
}

type self = {
	world: typeof(Jecs.World.new()),
	janitor: Janitor.Janitor,
	enemyAdded: SignalPlus.Signal<Model, Jecs.Entity>,
	enemyRemoved: SignalPlus.Signal<Model, Jecs.Entity>,
	serviceManager: any,
	traits: Traits,
	allyService: any,
	targets: { [number]: Model },
} & typeof(EnemyService)

--- @brief Creates a new EnemyService instance
--- @param serviceManager any The ServiceManager instance
--- @return self The EnemyService instance
function EnemyService.new(serviceManager): self
	local self = setmetatable({}, EnemyService)
	self.world = Jecs.World.new()
	self.janitor = Janitor.new()
	self.enemyAdded = SignalPlus()
	self.enemyRemoved = SignalPlus()
	self.serviceManager = serviceManager

	self.traits = {
		Health = self.world:component(),
		Speed = self.world:component(),
		Radius = self.world:component(),
		Damage = self.world:component(),
		Cooldown = self.world:component(),
		RangeDamage = self.world:component(),
		Character = self.world:component(),
	}

	self.targets = {}
	return self
end

--- @brief Initializes the EnemyService, connects signals, and caches allies
function EnemyService.init(self: self)
	self.allyService = self.serviceManager:getService("AllyService")
	self.targets = self.allyService:getAllies()

	self.enemyAdded:Connect(function(character, enemy)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			warn("No humanoid found for", enemy)
			return
		end

		humanoid.MaxHealth = self.world:get(enemy, self.traits.Health)
		humanoid.Health = humanoid.MaxHealth
		humanoid.WalkSpeed = self.world:get(enemy, self.traits.Speed)

		humanoid.Died:Once(function()
			Utils.smoothDeath(character)
				:andThen(function()
					self:_removeEnemy(character, enemy)
				end)
				:catch(warn)
		end)

		character.Parent = workspace.Temp
		print(character.Name, "was added")
	end)

	self.enemyRemoved:Connect(function(character, enemy)
		self.world:delete(enemy)
		self.janitor:Remove(character)
	end)

	self.allyService.allyAdded:Connect(function()
		self.targets = self.allyService:getAllies()
	end)
	self.allyService.allyRemoved:Connect(function()
		self.targets = self.allyService:getAllies()
	end)
end

--- @brief Removes an enemy safely
--- @param character Model The enemy character
--- @param enemy Jecs.Entity The corresponding ECS entity
function EnemyService._removeEnemy(self: self, character: Model, enemy: Jecs.Entity)
	if character and self.world:contains(enemy) then
		self.enemyRemoved:Fire(character, enemy)
	else
		warn("Enemy not found")
	end
end

--- @brief Adds a new enemy to the ECS world
--- @param metadata CharacterTypes.Metadata The enemy metadata
--- @return Jecs.Entity The created ECS entity
--- @return Model The cloned character
function EnemyService.addEnemy(self: self, metadata: CharacterTypes.Metadata)
	local enemy = self.world:entity()
	local character = enemiesFolder[metadata.name]:Clone()
	character:PivotTo(metadata.cframe)

	self.world:set(enemy, self.traits.Character, character)
	self.world:set(enemy, self.traits.Health, metadata.health)
	self.world:set(enemy, self.traits.Speed, metadata.speed)
	self.world:set(enemy, self.traits.Damage, metadata.damage)
	self.world:set(enemy, self.traits.Cooldown, metadata.cooldown)
	if metadata.radius then
		self.world:set(enemy, self.traits.Radius, metadata.radius)
	end
	if metadata.rangeDamage then
		self.world:set(enemy, self.traits.RangeDamage, metadata.rangeDamage)
	end

	self.janitor:Add(character, "Destroy", character)
	self.enemyAdded:Fire(character, enemy)
end

--- @brief Returns all enemy entities in the ECS world
--- @return { [number]: Jecs.Entity } The cached enemy entities
function EnemyService.getEnemies(self: self): Jecs.Query<number, Model>?
	local enemies = self.world:query(self.traits.Character)
	if enemies then
		return self.world:query(self.traits.Character):cached()
	end
	return nil
end

--- @brief Updates all enemies each frame
--- @param dt number Delta time from the frame
function EnemyService.update(self: self, dt: number)
	-- TEST
	-- ADD TARGET MODES (Nearest, middle, last, random, strongest)
	-- Make it better, lol, it sucks, get good
	for enemy, character, radius, cooldown in
		self.world:query(self.traits.Character, self.traits.Radius, self.traits.Cooldown)
	do
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			continue
		end

		if cooldown > 0 then
			cooldown -= dt
			self.world:set(enemy, self.traits.Cooldown, cooldown)
		end

		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			continue
		end

		local nearestTarget, nearestDist
		for _, target in self.targets do
			local targetRoot = target:FindFirstChild("HumanoidRootPart")
			if not targetRoot then
				continue
			end
			local dist = (targetRoot.Position - root.Position).Magnitude
			if dist <= radius and (not nearestDist or dist < nearestDist) then
				nearestTarget = target
				nearestDist = dist
			end
		end

		if nearestTarget then
			local targetRoot = nearestTarget:FindFirstChild("HumanoidRootPart")
			if targetRoot then
				root.CFrame = CFrame.lookAt(root.Position, targetRoot.Position)
			end

			if cooldown <= 0 then
				local damage = self.world:get(enemy, self.traits.RangeDamage)
				local targetHumanoid = nearestTarget:FindFirstChildOfClass("Humanoid")
				if targetHumanoid and targetHumanoid.Health > 0 then
					targetHumanoid:TakeDamage(damage)
				end
				self.world:set(enemy, self.traits.Cooldown, 1)
			end
		end
	end
end

--- @brief Clears all enemies and cleans up resources
function EnemyService.clear(self: self)
	for enemy, character in self.world:query(self.traits.Character) do
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		character:Destroy()
	end
	self.world:cleanup()
	self.janitor:Cleanup()
end

return EnemyService
