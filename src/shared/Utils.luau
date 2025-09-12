--!nocheck
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
	-- Return loaded track (useful if you want to :Play())
	return animator:LoadAnimation(animation)
end

return Utils
