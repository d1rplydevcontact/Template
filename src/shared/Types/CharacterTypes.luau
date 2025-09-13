local Character = {}

export type AllyMetadata = {
	name: string,
	position: CFrame,
	health: number,
	radius: number?,
	targetMode: string,
	cooldown: number,
	rangeDamage: number?,
}

export type EnemyMetadata = {
	name: string,
	startPosition: CFrame,
	health: number,
	speed: number,
	radius: number?,
	targetMode: string,
	cooldown: number,
	rangeDamage: number?,
	damage: number,
}

return Character
