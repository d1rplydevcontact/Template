--!nocheck
--!native
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Jecs = require(ReplicatedStorage.Packages.Jecs)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local SignalPlus = require(ServerScriptService.ServerPackages.SignalPlus)
local CharacterTypes = require(ReplicatedStorage.Shared.Types.CharacterTypes)
local Utils = require(ReplicatedStorage.Shared.Utils)

local CharacterManager = {}
CharacterManager.__index = CharacterManager

local HEALTH_THRESHOLD = 0

export type Components = {
	Health: Jecs.Entity<number>,
	Speed: Jecs.Entity<number>,
	Radius: Jecs.Entity<number>,
	Damage: Jecs.Entity<number>,
	Cooldown: Jecs.Entity<number>,
	RangeDamage: Jecs.Entity<number>,
	Character: Jecs.Entity<Model>,
}

export type CharacterManager = {
	world: typeof(Jecs.World.new()),
	janitor: Janitor.Janitor,
	characterAdded: SignalPlus.Signal<Model, Jecs.Entity>,
	characterRemoved: SignalPlus.Signal<Model, Jecs.Entity>,
	components: Components,
	charactersQuery: Jecs.Query<number, Model>?,
	assetsFolder: Folder,
	characterType: string,
} & typeof(CharacterManager)

--- Creates a new CharacterManager instance
function CharacterManager.new(assetsFolder: Folder, characterType: string): CharacterManager
	local self = setmetatable({}, CharacterManager)
	self.world = Jecs.World.new()
	self.janitor = Janitor.new()
	self.characterAdded = SignalPlus()
	self.characterRemoved = SignalPlus()
	self.assetsFolder = assetsFolder
	self.characterType = characterType

	self.components = {
		Health = self.world:component(),
		Speed = self.world:component(),
		Radius = self.world:component(),
		Damage = self.world:component(),
		Cooldown = self.world:component(),
		RangeDamage = self.world:component(),
		Character = self.world:component(),
	}

	self.charactersQuery = nil

	return self
end

--- Initializes the CharacterManager
function CharacterManager.init(self: CharacterManager)
	self:_createQueries()
	self:_setupSignalConnections()
end

function CharacterManager._createQueries(self: CharacterManager)
	self.charactersQuery = self.world:query(self.components.Character):cached()
end

function CharacterManager._setupSignalConnections(self: CharacterManager)
	self.characterAdded:Connect(function(character, entity)
		self:_onCharacterAdded(character, entity)
	end)

	self.characterRemoved:Connect(function(character, entity)
		self:_onCharacterRemoved(character, entity)
	end)
end

function CharacterManager._onCharacterAdded(self: CharacterManager, character: Model, entity: Jecs.Entity)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn(`No humanoid found for {self.characterType} {entity}`)
		return
	end

	local health = self.world:get(entity, self.components.Health)
	local speed = self.world:get(entity, self.components.Speed)

	humanoid.MaxHealth = health
	humanoid.Health = health

	if speed then
		humanoid.WalkSpeed = speed
	end

	humanoid.Died:Once(function()
		Utils.fadeoutCharacter(character)
		self:removeCharacter(character, entity)
	end)

	character.Parent = workspace.Temp
	print(`{character.Name} {self.characterType} was added`)
end

function CharacterManager._onCharacterRemoved(self: CharacterManager, character: Model, entity: Jecs.Entity)
	if self.world:contains(entity) then
		self.world:delete(entity)
	end
	self.janitor:Remove(character)
	print(`{character.Name} {self.characterType} was removed`)
end

--- @brief Adds a new character
function CharacterManager.addCharacter(self: CharacterManager, metadata: CharacterTypes.Metadata): (Jecs.Entity, Model)
	local entity = self.world:entity()
	local character = self.assetsFolder[metadata.name]:Clone()

	if not character then
		error(`{self.characterType} template '{metadata.name}' not found in assets folder`)
	end

	character:PivotTo(metadata.cframe)

	self.world:set(entity, self.components.Character, character)
	self.world:set(entity, self.components.Health, metadata.health)
	self.world:set(entity, self.components.Cooldown, metadata.cooldown or 0)

	if metadata.speed then
		self.world:set(entity, self.components.Speed, metadata.speed)
	end
	if metadata.damage then
		self.world:set(entity, self.components.Damage, metadata.damage)
	end
	if metadata.radius then
		self.world:set(entity, self.components.Radius, metadata.radius)
	end
	if metadata.rangeDamage then
		self.world:set(entity, self.components.RangeDamage, metadata.rangeDamage)
	end

	self.janitor:Add(character, "Destroy", character)
	self.characterAdded:Fire(character, entity)

	return entity, character
end

function CharacterManager.removeCharacter(self: CharacterManager, character: Model, entity: Jecs.Entity)
	if character and self.world:contains(entity) then
		self.characterRemoved:Fire(character, entity)
	else
		warn(`Attempted to remove non-existent {self.characterType}`)
	end
end

function CharacterManager.getCharacters(self: CharacterManager): Jecs.Query<number, Model>?
	return self.charactersQuery
end

function CharacterManager.getCharacterRoot(character: Model): BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid.RootPart
	end
	return character:FindFirstChild("HumanoidRootPart")
end

function CharacterManager.isValidCharacter(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > HEALTH_THRESHOLD
end

function CharacterManager.updateCooldowns(self: CharacterManager, deltaTime: number)
	for entity, _, cooldown in self.world:query(self.components.Character, self.components.Cooldown) do
		if cooldown > 0 then
			cooldown -= deltaTime
			self.world:set(entity, self.components.Cooldown, math.max(0, cooldown))
		end
	end
end

--- Gets characters ready for combat (with radius and not on cooldown)
function CharacterManager.getCombatReadyCharacters(self: CharacterManager)
	return self.world:query(self.components.Character, self.components.Radius, self.components.Cooldown)
end

--- Clears all characters and cleans up resources
function CharacterManager.clear(self: CharacterManager)
	if self.charactersQuery then
		for _, character in self.charactersQuery do
			if character and character.Parent then
				character:Destroy()
			end
		end
	end

	self.world:cleanup()
	self.janitor:Cleanup()

	self.charactersQuery = nil
end

return CharacterManager
