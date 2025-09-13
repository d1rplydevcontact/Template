--!strict
--!native
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServiceManager = require(ServerScriptService.Server.Core.ServiceManager)
local SignalPlus = require(ServerScriptService.ServerPackages.SignalPlus)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Jecs = require(ReplicatedStorage.Packages.Jecs)
local CharacterTypes = require(ReplicatedStorage.Shared.Types.CharacterTypes)
local Utils = require(ReplicatedStorage.Shared.Utils)

local alliesFolder = ReplicatedStorage.Assets.Allies

local AllyService = {}
AllyService.__index = AllyService

type Traits = {
	Health: Jecs.Entity<number>,
	Radius: Jecs.Entity<number>,
	Cooldown: Jecs.Entity<number>,
	RangeDamage: Jecs.Entity<number>,
	Character: Jecs.Entity<Model>,
}

type self = {
	world: typeof(Jecs.World.new()),
	janitor: Janitor.Janitor,
	allyAdded: SignalPlus.Signal<Model, Jecs.Entity>,
	allyRemoved: SignalPlus.Signal<Model, Jecs.Entity>,
	serviceManager: ServiceManager.ServiceManager,
	traits: Traits,
	targets: { [number]: Model },
} & typeof(AllyService)

--- @brief Creates a new AllyService instance
--- @return self The AllyService instance
function AllyService.new(serviceManager): self
	local self = setmetatable({}, AllyService)
	self.world = Jecs.World.new()
	self.janitor = Janitor.new()
	self.allyAdded = SignalPlus()
	self.allyRemoved = SignalPlus()
	self.serviceManager = serviceManager

	self.traits = {
		Health = self.world:component(),
		Radius = self.world:component(),
		Cooldown = self.world:component(),
		RangeDamage = self.world:component(),
		Character = self.world:component(),
	}

	self.targets = {}
	return self
end

--- @brief Initializes AllyService, connects signals, and sets up target cache
function AllyService.init(self: self)
	self.enemyService = self.serviceManager:getService("EnemyService")
	self.targets = self.enemyService:getEnemies()

	self.allyAdded:Connect(function(character, ally)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			warn("No humanoid found for", ally)
			return
		end

		humanoid.MaxHealth = self.world:get(ally, self.traits.Health)
		humanoid.Health = humanoid.MaxHealth

		humanoid.Died:Once(function()
			Utils.smoothDeath(character)
				:andThen(function()
					self:_removeAlly(character, ally)
				end)
				:catch(warn)
		end)

		character.Parent = workspace.Temp
		print(character.Name, "was added")
	end)

	self.allyRemoved:Connect(function(character, ally)
		self.world:delete(ally)
		self.janitor:Remove(character)
		print(character.Name, "was removed")
	end)

	self.enemyService.enemyAdded:Connect(function()
		self.targets = self.enemyService:getEnemies()
	end)
	self.enemyService.enemyRemoved:Connect(function()
		self.targets = self.enemyService:getEnemies()
	end)
end

--- @brief Removes an ally safely
--- @param character Model The ally character model
--- @param ally Jecs.Entity The ECS entity associated with the ally
function AllyService._removeAlly(self: self, character: Model, ally: Jecs.Entity)
	if character and self.world:contains(ally) then
		self.allyRemoved:Fire(character, ally)
	else
		warn("Ally not found")
	end
end

--- @brief Adds a new ally to the ECS world
--- @param metadata CharacterTypes.Metadata The metadata for the ally
--- @return Jecs.Entity The created ECS entity
--- @return Model The cloned ally character model
function AllyService.addAlly(self: self, metadata: CharacterTypes.Metadata): (Jecs.Entity, Model)
	local ally = self.world:entity()
	local character = alliesFolder[metadata.name]:Clone()
	character:PivotTo(metadata.cframe)

	self.world:set(ally, self.traits.Character, character)
	self.world:set(ally, self.traits.Health, metadata.health)
	self.world:set(ally, self.traits.Cooldown, metadata.cooldown)
	if metadata.radius then
		self.world:set(ally, self.traits.Radius, metadata.radius)
	end
	if metadata.rangeDamage then
		self.world:set(ally, self.traits.RangeDamage, metadata.rangeDamage)
	end

	self.janitor:Add(character, "Destroy", character)
	self.allyAdded:Fire(character, ally)
end

--- @brief Returns all ally entities in the ECS world
--- @return { [number]: Jecs.Entity } The cached ally entities
function AllyService.getAllies(self: self): Jecs.Query<number, Model>?
	local allies = self.world:query(self.traits.Character)
	if allies then
		return self.world:query(self.traits.Character):cached()
	end
	return nil
end

--- @brief Updates all allies each frame
--- @param dt number Delta time from the frame
function AllyService.update(self: self, dt: number)
	-- TEST
	-- ADD TARGET MODES (Nearest, middle, last, random, strongest)
	-- Make it better, lol, it sucks, get good
	for ally, character, radius, cooldown in
		self.world:query(self.traits.Character, self.traits.Radius, self.traits.Cooldown)
	do
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			continue
		end

		if cooldown > 0 then
			cooldown -= dt
			self.world:set(ally, self.traits.Cooldown, cooldown)
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
				local damage = self.world:get(ally, self.traits.RangeDamage)
				local targetHumanoid = nearestTarget:FindFirstChildOfClass("Humanoid")
				if targetHumanoid and targetHumanoid.Health > 0 then
					targetHumanoid:TakeDamage(damage)
				end
				self.world:set(ally, self.traits.Cooldown, 1)
			end
		end
	end
end

--- @brief Clears all allies and cleans up resources
function AllyService.clear(self: self)
	for _, character in self.world:query(self.traits.Character) do
		character:Destroy()
	end
	self.world:cleanup()
	self.janitor:Cleanup()
end

return AllyService
