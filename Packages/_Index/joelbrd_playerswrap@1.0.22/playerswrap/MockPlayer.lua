local MockPlayer = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(script.Parent.Parent.Signal)

local EMPTY_FUNCTION = function() end

local function getName(userId: number): string
    local success, response = pcall(function()
        return Players:GetNameFromUserIdAsync(math.abs(userId))
    end)
    if success then
        return response
    end

    return `Player{string.sub(tostring(math.abs(userId)), 1, 4)}`
end

function MockPlayer.new(userId: number)
    local mockPlayer = {
        IsMockPlayer = true,
    }

    -- Player Props
    mockPlayer.AccountAge = 1 :: number
    mockPlayer.AutoJumpEnabled = true :: boolean
    mockPlayer.CameraMaxZoomDistance = 400 :: number
    mockPlayer.CameraMinZoomDistance = 0.5 :: number
    mockPlayer.CameraMode = Enum.CameraMode.Classic :: Enum.CameraMode
    mockPlayer.CanLoadCharacterAppearance = true :: boolean
    mockPlayer.Character = nil :: Model?
    mockPlayer.CharacterAppearanceId = userId :: number
    mockPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom :: Enum.DevCameraOcclusionMode
    mockPlayer.DevComputerCameraMode = Enum.DevComputerCameraMovementMode.UserChoice :: Enum.DevComputerCameraMovementMode
    mockPlayer.DevComputerMovementMode = Enum.DevComputerMovementMode.UserChoice :: Enum.DevComputerMovementMode
    mockPlayer.DevEnableMouseLock = true :: boolean
    mockPlayer.DevTouchCameraMode = Enum.DevTouchCameraMovementMode.UserChoice :: Enum.DevTouchCameraMovementMode
    mockPlayer.DevTouchMovementMode = Enum.DevTouchMovementMode.UserChoice :: Enum.DevTouchMovementMode
    mockPlayer.FollowUserId = 0 :: number
    mockPlayer.GameplayPaused = false :: boolean
    mockPlayer.HasVerifiedBadge = false :: boolean
    mockPlayer.HealthDisplayDistance = 100 :: number
    mockPlayer.LocaleId = "en-us" :: string
    mockPlayer.MembershipType = Enum.MembershipType.Premium :: Enum.MembershipType
    mockPlayer.NameDisplayDistance = 100 :: number
    mockPlayer.Neutral = true :: boolean
    mockPlayer.ReplicationFocus = nil :: Instance?
    mockPlayer.RespawnLocation = nil :: SpawnLocation?
    mockPlayer.Team = nil :: Team?
    mockPlayer.TeamColor = BrickColor.new("White") :: BrickColor

    mockPlayer.UserId = userId :: number
    mockPlayer.Name = getName(userId) :: string
    mockPlayer.DisplayName = mockPlayer.Name :: string
    mockPlayer.Parent = Players

    -- Instance Props
    mockPlayer.Archivable = true
    mockPlayer.ClassName = "Player"

    -- Player Methods
    mockPlayer.ClearCharacterAppearance = EMPTY_FUNCTION
    mockPlayer.DistanceFromCharacter = function(self, position: Vector3)
        if not mockPlayer.Character then
            return 0
        end

        local head = mockPlayer.Character:FindFirstChild("Head") :: BasePart?
        if not head then
            return 0
        end

        return (head:GetPivot().Position - position).Magnitude
    end
    mockPlayer.GetJoinData = function()
        return {}
    end
    mockPlayer.GetMouse = EMPTY_FUNCTION
    mockPlayer.GetNetworkPing = function()
        return 0
    end
    mockPlayer.HasAppearanceLoaded = function()
        return true
    end
    mockPlayer.IsVerified = function()
        return false
    end
    mockPlayer.Kick = EMPTY_FUNCTION
    mockPlayer.Move = EMPTY_FUNCTION
    mockPlayer.SetAccountAge = EMPTY_FUNCTION
    mockPlayer.SetSuperSafeChat = EMPTY_FUNCTION
    mockPlayer.GetFriendsOnline = function()
        return {}
    end
    mockPlayer.GetRankInGroup = function()
        return 0
    end
    mockPlayer.GetRoleInGroup = function()
        return "Guest"
    end
    mockPlayer.IsFriendsWith = function()
        return false
    end
    mockPlayer.IsInGroup = function()
        return false
    end
    mockPlayer.LoadCharacter = EMPTY_FUNCTION
    mockPlayer.LoadCharacterWithHumanoidDescription = EMPTY_FUNCTION
    mockPlayer.RequestStreamAroundAsync = EMPTY_FUNCTION

    -- Player Events
    mockPlayer.CharacterAdded = Signal.new()
    mockPlayer.CharacterAppearanceLoaded = Signal.new()
    mockPlayer.CharacterRemoving = Signal.new()
    mockPlayer.Chatted = Signal.new()
    mockPlayer.Idled = Signal.new()
    mockPlayer.OnTeleport = Signal.new()

    -- Instance Events
    mockPlayer.Destroying = Signal.new()

    -- Instance Methods
    mockPlayer.GetFullName = function()
        return `MockPlayers.{mockPlayer.Name}`
    end
    mockPlayer.IsA = function(self, className: string)
        return className == "Player"
    end

    -- Destroy
    local _isDestroyed = false
    function mockPlayer:Destroy()
        if _isDestroyed then
            return
        end
        _isDestroyed = true

        if mockPlayer.Character then
            mockPlayer.Character:Destroy()
            mockPlayer.Character = nil
        end

        mockPlayer.Parent = nil
        mockPlayer.Destroying:Fire()

        task.wait()

        for key, value in pairs(mockPlayer) do
            if typeof(value) == "Instance" then
                value:Destroy()
            end
        end
    end

    return mockPlayer
end

return MockPlayer
