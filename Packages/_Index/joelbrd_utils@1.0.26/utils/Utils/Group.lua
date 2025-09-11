local Group = {}

local Players = game:GetService("Players")

local function player(playerOrUserId: Player | number): Player?
    if typeof(playerOrUserId) == "number" then
        return Players:GetPlayerByUserId(playerOrUserId)
    end

    return playerOrUserId
end

function Group.rank(groupId: number, playerOrUserId: Player | number)
    local player = player(playerOrUserId)
    if not player then
        return 0
    end

    return player:GetRankInGroup(groupId)
end

function Group.isInGroup(groupId: number, playerOrUserId: Player | number)
    local player = player(playerOrUserId)
    if not player then
        return false
    end

    return player:IsInGroup(groupId)
end

return Group
