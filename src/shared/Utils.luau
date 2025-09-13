--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local Utils = {}

--- @brief Loads an animation for a model or instance
--- @param parent Instance The model or instance that should own the animation
--- @param animationId string The Roblox animation asset ID
--- @return AnimationTrack? The loaded animation track, or nil if failed
function Utils.loadAnimation(parent: Instance, animationId: string): AnimationTrack?
	-- Validate inputs
	if not parent or not animationId or animationId == "" then
		warn("Utils.loadAnimation: Invalid parent or animationId")
		return nil
	end

	-- Ensure animationId has proper format
	if not string.match(animationId, "^rbxassetid://") then
		animationId = "rbxassetid://" .. animationId
	end

	-- Find existing AnimationController or Humanoid
	local animator: Animator? = nil
	local humanoid = parent:FindFirstChildOfClass("Humanoid")
	local controller = parent:FindFirstChildOfClass("AnimationController")

	if humanoid then
		animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
	elseif controller then
		animator = controller:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = controller
		end
	else
		-- If neither exist, create an AnimationController and attach
		controller = Instance.new("AnimationController")
		controller.Name = "AnimationController"
		controller.Parent = parent
		animator = Instance.new("Animator")
		animator.Parent = controller
	end

	-- Create animation
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	animation.Parent = animator

	-- Load and return the animation track
	local success, result = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if success then
		return result
	else
		warn("Utils.loadAnimation: Failed to load animation " .. animationId .. " - " .. tostring(result))
		animation:Destroy()
		return nil
	end
end

--- @brief Ragdolls a character and fades out a ragdolled clone
--- @param character Model The character to ragdoll and fade
--- @param duration number? Optional fade duration in seconds (default: 1)
--- @param delay number? Optional delay before fade starts (default: 2)
--- @return () -> () Cleanup function to stop fade early
function Utils.deathEffect(character: Model, duration: number?, delay: number?): () -> ()
	duration = duration or 1
	delay = delay or 2

	if not character or not character.Parent then
		warn("Utils.ragdollAndFade: Invalid character")
		return function() end
	end

	local janitor = Janitor.new()
	local clone = janitor:Add(character:Clone(), "Destroy")
	clone.Parent = character.Parent

	local tweens = {}
	local cancelled = false

	-- Helper: Ragdoll a character (Motor6D → BallSocket / Weld)
	local function ragdollChar(char: Model)
		for _, Part in ipairs(char:GetChildren()) do
			if Part:IsA("BasePart") then
				local Motor6D = Part:FindFirstChildWhichIsA("Motor6D")
				if Motor6D then
					if Part.Name ~= "Head" then
						local BallSocket = Instance.new("BallSocketConstraint")
						local Attachment1 = Instance.new("Attachment")
						local Attachment2 = Instance.new("Attachment")
						Attachment1.CFrame = Motor6D.C0
						Attachment2.CFrame = Motor6D.C1
						Attachment1.Parent = Motor6D.Part0
						Attachment2.Parent = Motor6D.Part1
						BallSocket.Attachment0 = Attachment1
						BallSocket.Attachment1 = Attachment2
						BallSocket.Parent = Motor6D.Parent
						Motor6D:Destroy()
					else
						local WeldConstraint = Instance.new("WeldConstraint")
						WeldConstraint.Part0 = Motor6D.Part0
						WeldConstraint.Part1 = Motor6D.Part1
						WeldConstraint.Parent = Motor6D.Parent
					end
				end
			end
		end
	end

	-- Ragdoll both the original and the clone
	ragdollChar(character)
	ragdollChar(clone)

	-- Helper: Fade a single object
	local function fadeObject(obj)
		if obj:IsA("BasePart") then
			local tween = TweenService:Create(
				obj,
				TweenInfo.new(duration, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out, 0, false, delay),
				{ Transparency = 1 }
			)
			table.insert(tweens, tween)
			return tween
		elseif obj:IsA("Decal") or obj:IsA("Texture") then
			local tween = TweenService:Create(
				obj,
				TweenInfo.new(duration, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out, 0, false, delay),
				{ Transparency = 1 }
			)
			table.insert(tweens, tween)
			return tween
		end
		return nil
	end

	-- Fade all descendants in the clone
	for _, obj in ipairs(clone:GetDescendants()) do
		fadeObject(obj)
	end
	fadeObject(clone)

	-- Start all tweens
	for _, tween in ipairs(tweens) do
		if not cancelled then
			tween:Play()
		end
	end

	-- Cleanup after completion
	task.spawn(function()
		if #tweens > 0 then
			local longestTween = tweens[1]
			for _, tween in ipairs(tweens) do
				if
					tween.TweenInfo.Time + tween.TweenInfo.DelayTime
					> longestTween.TweenInfo.Time + longestTween.TweenInfo.DelayTime
				then
					longestTween = tween
				end
			end
			if not cancelled then
				longestTween.Completed:Wait()
			end
		end
		janitor:Destroy()
	end)

	-- Return cleanup function
	return function()
		cancelled = true
		for _, tween in ipairs(tweens) do
			if tween.PlaybackState ~= Enum.PlaybackState.Completed then
				tween:Cancel()
			end
		end
		janitor:Destroy()
	end
end

--- @brief Creates a smooth camera shake effect
--- @param camera Camera The camera to shake
--- @param intensity number Shake intensity (recommended: 0.1 to 2.0)
--- @param duration number Duration in seconds
--- @return () -> () Cleanup function to stop shake early
function Utils.cameraShake(camera: Camera, intensity: number, duration: number): () -> ()
	intensity = intensity or 1
	duration = duration or 0.5

	local originalCFrame = camera.CFrame
	local startTime = tick()
	local cancelled = false

	local connection
	connection = game:GetService("RunService").Heartbeat:Connect(function()
		if cancelled or tick() - startTime >= duration then
			camera.CFrame = originalCFrame
			connection:Disconnect()
			return
		end

		local elapsed = tick() - startTime
		local fade = 1 - (elapsed / duration) -- Fade out over time
		local shake = intensity * fade

		local randomX = (math.random() - 0.5) * shake
		local randomY = (math.random() - 0.5) * shake
		local randomZ = (math.random() - 0.5) * shake

		camera.CFrame = originalCFrame * CFrame.new(randomX, randomY, randomZ)
	end)

	return function()
		cancelled = true
		if connection then
			connection:Disconnect()
			camera.CFrame = originalCFrame
		end
	end
end

return Utils
