local Players = game:GetService("Players")
--[[
	https://devforum.roblox.com/t/notched-screen-support-full-release/2074324#advanced-how-can-i-get-the-devices-safe-area-inset-sizes-25
]]

type inset4 = { left: number, top: number, right: number, bottom: number }

return function()
    local playerGui = Players.LocalPlayer.PlayerGui
    assert(playerGui)

    local fullscreenGui = playerGui:FindFirstChild("_FullscreenTestGui")
    if not fullscreenGui then
        fullscreenGui = Instance.new("ScreenGui")
        fullscreenGui.Name = "_FullscreenTestGui"
        fullscreenGui.Parent = playerGui
        fullscreenGui.ScreenInsets = Enum.ScreenInsets.None
    end

    local deviceGui = playerGui:FindFirstChild("_DeviceTestGui")
    if not deviceGui then
        deviceGui = Instance.new("ScreenGui")
        deviceGui.Name = "_DeviceTestGui"
        deviceGui.Parent = playerGui
        deviceGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
    end

    local tlInset = deviceGui.AbsolutePosition - fullscreenGui.AbsolutePosition
    local brInset = fullscreenGui.AbsolutePosition + fullscreenGui.AbsoluteSize - (deviceGui.AbsolutePosition + deviceGui.AbsoluteSize)
    local result: inset4 = { left = tlInset.X, top = tlInset.Y, right = brInset.X, bottom = brInset.Y }

    return result
end
