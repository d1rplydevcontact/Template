local Enemy = {}

export type Metadata = {
	name: string,
	position: Vector3,
	health: number,
	speed: number,
	animations: {
		[string]: number,
	},
}

return Enemy
