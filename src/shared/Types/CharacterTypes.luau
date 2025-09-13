local Character = {}

type CharacterMetadata = {
	name: string,
	health: number,
	radius: number?,
	targetMode: "Nearest" | "Farthest" | "Middle" | "Random" | "Weakest" | "Strongest",
	cooldown: number,
	rangeDamage: number?,
}

export type AllyMetadata = CharacterMetadata & {
	position: CFrame,
}

export type EnemyMetadata = CharacterMetadata & {
	startPosition: CFrame,
	speed: number,
	damage: number,
}

return Character
