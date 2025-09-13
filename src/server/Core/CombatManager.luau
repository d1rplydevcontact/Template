--!nocheck
--!native
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Jecs = require(ReplicatedStorage.Packages.Jecs)

local CombatManager = {}

-- Constants
local DEFAULT_COOLDOWN = 1
local HEALTH_THRESHOLD = 0

export type CachedTargets = { [number]: Model }

--- Updates the cached targets from a query or table
function CombatManager.updateTargetCache(query: any): CachedTargets
	local cache = {}
	if query then
		if typeof(query) == "table" then
			return query
		else
			for _, character in query do
				table.insert(cache, character)
			end
		end
	end
	return cache
end

--- Gets HumanoidRootPart safely
function CombatManager.getHumanoidRootPart(character: Model): BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid.RootPart
	end
	return character:FindFirstChild("HumanoidRootPart")
end

--- Validates if a target is valid for attacking
function CombatManager.isValidTarget(target: Model): boolean
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > HEALTH_THRESHOLD
end

--- General target selection function
function CombatManager.findTarget(
	position: Vector3,
	range: number,
	targets: CachedTargets,
	mode: string
): (Model?, number?)
	local validTargets = {}
	for _, target in targets do
		if CombatManager.isValidTarget(target) then
			local root = CombatManager.getHumanoidRootPart(target)
			local distance = (root.Position - position).Magnitude
			if root then
				if distance > range then
					continue
				end
				table.insert(validTargets, { target = target, distance = distance })
			end
		end
	end

	if #validTargets == 0 then
		return nil, nil
	end

	if mode == "Nearest" then
		table.sort(validTargets, function(a, b)
			return a.distance < b.distance
		end)
		return validTargets[1].target, validTargets[1].distance
	elseif mode == "Farthest" then
		table.sort(validTargets, function(a, b)
			return a.distance > b.distance
		end)
		return validTargets[1].target, validTargets[1].distance
	elseif mode == "Middle" then
		table.sort(validTargets, function(a, b)
			return a.distance < b.distance
		end)
		local middleIndex = math.ceil(#validTargets / 2)
		return validTargets[middleIndex].target, validTargets[middleIndex].distance
	elseif mode == "Random" then
		local randomIndex = math.random(1, #validTargets)
		return validTargets[randomIndex].target, validTargets[randomIndex].distance
	elseif mode == "Weakest" then
		table.sort(validTargets, function(a, b)
			local hA = a.target:FindFirstChildOfClass("Humanoid").Health
			local hB = b.target:FindFirstChildOfClass("Humanoid").Health
			return hA < hB
		end)
		return validTargets[1].target, validTargets[1].distance
	elseif mode == "Strongest" then
		table.sort(validTargets, function(a, b)
			local hA = a.target:FindFirstChildOfClass("Humanoid").Health
			local hB = b.target:FindFirstChildOfClass("Humanoid").Health
			return hA > hB
		end)
		return validTargets[1].target, validTargets[1].distance
	end

	return nil, nil
end

--- Handles combat logic between attacker and target
function CombatManager.processCombat(
	world: typeof(Jecs.World.new()),
	attacker: Jecs.Entity,
	target: Model,
	cooldown: number,
	rangeDamageComponent: Jecs.Entity<number>,
	cooldownComponent: Jecs.Entity<number>
): boolean
	if cooldown > 0 then
		return false
	end

	local damage = world:get(attacker, rangeDamageComponent)
	if not damage then
		return false
	end

	local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
	if CombatManager.isValidTarget(target) and targetHumanoid then
		targetHumanoid:TakeDamage(damage)
		world:set(attacker, cooldownComponent, DEFAULT_COOLDOWN)
		return true
	end

	return false
end

--- Smoothly orients character to face target over time
function CombatManager.orientToTarget(characterRoot: BasePart, targetRoot: BasePart, dt: number)
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
function CombatManager.processCharacterCombat(
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
	local root = CombatManager.getHumanoidRootPart(character)
	if not root then
		return false
	end

	local target, _ = CombatManager.findTarget(root.Position, radius, targets, targetMode)
	if target then
		local targetRoot = CombatManager.getHumanoidRootPart(target)
		if targetRoot then
			CombatManager.orientToTarget(root, targetRoot, dt)
			return CombatManager.processCombat(world, entity, target, cooldown, rangeDamageComponent, cooldownComponent)
		end
	end

	return false
end

return CombatManager
