local Players = game:GetService("Players")
-- https://devforum.roblox.com/t/your-name-color-in-chat-%E2%80%94-history-and-how-it-works/2702247

local NAME_COLORS = {
    Color3.new(253 / 255, 41 / 255, 67 / 255), -- BrickColor.new("Bright red").Color,
    Color3.new(1 / 255, 162 / 255, 255 / 255), -- BrickColor.new("Bright blue").Color,
    Color3.new(2 / 255, 184 / 255, 87 / 255), -- BrickColor.new("Earth green").Color,
    BrickColor.new("Bright violet").Color,
    BrickColor.new("Bright orange").Color,
    BrickColor.new("Bright yellow").Color,
    BrickColor.new("Light reddish violet").Color,
    BrickColor.new("Brick yellow").Color,
}

local function GetNameValue(pName)
    local value = 0
    for index = 1, #pName do
        local cValue = string.byte(string.sub(pName, index, index))
        local reverseIndex = #pName - index + 1
        if #pName % 2 == 1 then
            reverseIndex = reverseIndex - 1
        end
        if reverseIndex % 4 >= 2 then
            cValue = -cValue
        end
        value = value + cValue
    end
    return value
end

local color_offset = 0

local function player(playerOrUserId: Player | number): Player?
    if typeof(playerOrUserId) == "number" then
        return Players:GetPlayerByUserId(playerOrUserId)
    end

    return playerOrUserId
end

return function(playerOrNameOrUserId: Player | string | number)
    local playerName: string
    if typeof(playerOrNameOrUserId) == "string" then
        playerName = playerOrNameOrUserId
    else
        local _player = player(playerOrNameOrUserId)
        playerName = _player and _player.Name or "not_found"
    end

    return NAME_COLORS[((GetNameValue(playerName) + color_offset) % #NAME_COLORS) + 1]
end
