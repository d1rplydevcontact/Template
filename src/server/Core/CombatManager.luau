--!nocheck
--!native
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Jecs = require(ReplicatedStorage.Packages.Jecs)

local CombatService = {}

-- Constants
local DEFAULT_COOLDOWN = 1
local HEALTH_THRESHOLD = 0

export type CachedTargets = { [number]: Model }

--- Updates the cached targets from a query or table
function CombatService.updateTargetCache(query: any): CachedTargets
	local cache = {}
	if query then
		if typeof(query) == "table" then
			-- Handle direct table of targets
			return query
		else
			-- Handle Jecs query
			for _, character in query do
				table.insert(cache, character)
			end
		end
	end
	return cache
end

--- Finds the nearest target within range
function CombatService.findNearestTarget(position: Vector3, range: number, targets: CachedTargets): (Model?, number?)
	local nearestTarget, nearestDistance = nil, nil

	for _, target in targets do
		if not CombatService.isValidTarget(target) then
			continue
		end

		local targetRoot = CombatService.getHumanoidRootPart(target)
		if not targetRoot then
			continue
		end

		local distance = (targetRoot.Position - position).Magnitude
		if distance <= range and (not nearestDistance or distance < nearestDistance) then
			nearestTarget = target
			nearestDistance = distance
		end
	end

	return nearestTarget, nearestDistance
end

--- Gets HumanoidRootPart safely
function CombatService.getHumanoidRootPart(character: Model): BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid.RootPart
	end
	return character:FindFirstChild("HumanoidRootPart")
end

--- Validates if a target is valid for attacking
function CombatService.isValidTarget(target: Model): boolean
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > HEALTH_THRESHOLD
end

--- Handles combat logic between attacker and target
function CombatService.processCombat(
	world: typeof(Jecs.World.new()),
	attacker: Jecs.Entity,
	target: Model,
	cooldown: number,
	rangeDamageComponent: Jecs.Entity<number>,
	cooldownComponent: Jecs.Entity<number>
): boolean
	if cooldown > 0 then
		return false -- Still on cooldown
	end

	local damage = world:get(attacker, rangeDamageComponent)
	if not damage then
		return false
	end

	local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
	if CombatService.isValidTarget(target) and targetHumanoid then
		targetHumanoid:TakeDamage(damage)
		world:set(attacker, cooldownComponent, DEFAULT_COOLDOWN)
		return true
	end

	return false
end

--- Smoothly orients character to face target over time
--- @param characterRoot BasePart The character's root part
--- @param targetRoot BasePart The target's root part
--- @param speed number rotation speed multiplier
function CombatService.orientToTarget(characterRoot: BasePart, targetRoot: BasePart, dt: number)
	local speed = 8

	local lookDirection = (targetRoot.Position - characterRoot.Position)
	lookDirection = Vector3.new(lookDirection.X, 0, lookDirection.Z)

	if lookDirection.Magnitude > 0.01 then
		local unitDirection = lookDirection.Unit
		local targetCFrame = CFrame.lookAt(characterRoot.Position, characterRoot.Position + unitDirection)

		local alpha = math.clamp(speed * dt, 0, 1)
		characterRoot.CFrame = characterRoot.CFrame:Lerp(targetCFrame, alpha)
	end
end

--- Processes combat for a single character entity
function CombatService.processCharacterCombat(
	world: typeof(Jecs.World.new()),
	entity: Jecs.Entity,
	character: Model,
	radius: number,
	targetMode: string,
	cooldown: number,
	dt: number,
	targets: CachedTargets,
	rangeDamageComponent: Jecs.Entity<number>,
	cooldownComponent: Jecs.Entity<number>
): boolean
	local root = CombatService.getHumanoidRootPart(character)
	if not root then
		return false
	end

  local target = nil
	if targetMode == "Nearest" then
		 target = CombatService.findNearestTarget(root.Position, radius, targets)
	end

	if target then
		local targetRoot = CombatService.getHumanoidRootPart(target)
		if targetRoot then
			CombatService.orientToTarget(root, targetRoot, dt)
			return CombatService.processCombat(
				world,
				entity,
				target,
				cooldown,
				rangeDamageComponent,
				cooldownComponent
			)
		end
	end

	return false
end

return CombatService
