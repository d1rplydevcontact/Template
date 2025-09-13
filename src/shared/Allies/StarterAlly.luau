local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterTypes = require(ReplicatedStorage.Shared.Types.CharacterTypes)

return {
	name = "StarterAlly",
	position = CFrame.new(Vector3.one),
	health = 15,
	speed = 16,
	radius = 10,
	targetMode = "Nearest",
	cooldown = 0.25,
	rangeDamage = 1,
	damage = 16,
} :: CharacterTypes.AllyMetadata
