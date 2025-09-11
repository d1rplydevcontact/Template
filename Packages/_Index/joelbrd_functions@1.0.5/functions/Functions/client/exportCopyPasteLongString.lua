local Players = game:GetService("Players")

local TEXT_BOX_CHARACTER_LIMIT = 16384

local function splitStringIntoChunks(str: string, chunkSize: number)
    local chunks: { string } = {}
    for i = 1, #str, chunkSize do
        table.insert(chunks, str:sub(i, i + chunkSize - 1))
    end
    return chunks
end

-- Allows a player to copy a string to their clipboard from in-game
return function(logString: string)
    -- Create UI
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LongString"
    screenGui.Parent = Players.LocalPlayer.PlayerGui

    local textBox = Instance.new("TextBox")
    textBox.Name = "LogString"
    textBox.AnchorPoint = Vector2.new(0.5, 0.5)
    textBox.Position = UDim2.new(0.5, 0, 0.5, 0)
    textBox.Size = UDim2.new(0.3, 0, 0.3, 0)
    textBox.Parent = screenGui

    -- Split up log string into its counterparts (character limit on textbox)
    local chunks = splitStringIntoChunks(logString, TEXT_BOX_CHARACTER_LIMIT)
    for i, chunk in pairs(chunks) do
        textBox.Text = ("Click to copy log chunk %d/%d"):format(i, #chunks)

        textBox.Focused:Wait()

        task.wait()
        textBox.Text = chunk

        textBox.FocusLost:Wait()
    end

    screenGui:Destroy()
end
