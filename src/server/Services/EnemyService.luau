local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SignalPlus = require(ServerScriptService.ServerPackages.SignalPlus)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Jecs = require(ReplicatedStorage.Packages.Jecs)
local EnemyTypes = require(ReplicatedStorage.Shared.Types.EnemyTypes)

local enemiesFolder = ReplicatedStorage.Assets.Enemies

local EnemyService = {}
EnemyService.__index = EnemyService

type self = {
	world: typeof(Jecs.World.new()),
	janitor: Janitor.Janitor,
	enemyAdded: SignalPlus.Signal<Model, Jecs.Entity>,
	enemyRemoved: SignalPlus.Signal<Model, Jecs.Entity>,

	-- Shared traits among enemies
	traits: {
		Position: number,
		Health: number,
		Speed: number,
		Character: number,
	},
} & typeof(setmetatable({}, EnemyService))

function EnemyService.new()
	local self = setmetatable({}, EnemyService)
	self.world = Jecs.World.new()
	self.janitor = Janitor.new()
	self.enemyAdded = SignalPlus()
	self.enemyRemoved = SignalPlus()

	-- Shared traits accross all enemies
	self.traits = {
		Position = self.world:component(),
		Health = self.world:component(),
		Speed = self.world:component(),
		Character = self.world:component(),
	}

	return self
end

function EnemyService.init(self: self)
	self.enemyAdded:Connect(function(character, _)
		character.Parent = workspace.Temp.Enemies
		print(character.Name, "was added")
	end)

	-- Cleanup
	self.enemyRemoved:Connect(function(character, enemy)
		self.world:delete(enemy)
		self.janitor:Remove(character)
		print(character.Name, "was removed")
	end)
end

function EnemyService.addEnemy(self: self, metadata: EnemyTypes.Metadata)
	local enemy = self.world:entity()
	local enemyCharacter = enemiesFolder[metadata.name]:Clone()

	self.world:set(enemy, self.traits.Character, enemyCharacter)
	self.world:set(enemy, self.traits.Position, metadata.position)
	self.world:set(enemy, self.traits.Health, metadata.health)
	self.world:set(enemy, self.traits.Speed, metadata.speed)

	self.janitor:Add(enemyCharacter, "Destroy", enemyCharacter)
	self.enemyAdded:Fire(enemyCharacter, enemy)
end

function EnemyService.removeEnemy(self: self, character: Model)
	for enemy in self.world:query(self.traits.Character) do
		local char = self.world:get(enemy, self.traits.Character)
		if char == character then
			self.enemyRemoved:Fire(char, enemy)
			return
		end
	end
	warn("Enemy not found")
end

function EnemyService.update(self: self, dt: number)
	
end

function EnemyService.clear(self: self)
	self.world:cleanup() -- Cleanup empty archetypes
	self.janitor:Cleanup()
end

return EnemyService
