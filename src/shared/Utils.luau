--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Promise = require(ReplicatedStorage.Packages.Promise)
local Utils = {}

--- @brief Loads an animation for a model or instance
--- @param parent Instance The model or instance that should own the animation
--- @param animationId string The Roblox animation asset ID
function Utils.loadAnimation(parent: Instance, animationId: string)
	-- Find existing AnimationController or Humanoid
	local animator: Animator? = nil
	local humanoid = parent:FindFirstChildOfClass("Humanoid")
	local controller = parent:FindFirstChildOfClass("AnimationController")

	if humanoid then
		animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
		animator.Parent = humanoid
	elseif controller then
		animator = controller:FindFirstChildOfClass("Animator") or Instance.new("Animator")
		animator.Parent = controller
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
	return animator:LoadAnimation(animation)
end

function Utils.smoothDeath(character)
	return Promise.new(function(resolve, _reject)
		local tweens = {}
		for _, part in ipairs(character:GetChildren()) do
			if part:IsA("BasePart") then
				local tween = TweenService:Create(
					part,
					TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out, 0, false, 1),
					{ Transparency = 1 }
				)
				table.insert(tweens, tween)
				tween:Play()
			end
		end

		if #tweens == 0 then
			resolve()
			return
		end

		local finished = 0
		for _, tween in ipairs(tweens) do
			tween.Completed:Once(function()
				finished += 1
				if finished == #tweens then
					resolve()
				end
			end)
		end
	end)
end

return Utils
