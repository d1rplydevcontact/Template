local RichText = {}

function RichText.add(
    str: string,
    tags: {
        Bold: boolean?,
        Color: Color3?,
        Italic: boolean?,
        Underline: boolean?,
        Stroke: {
            Color: Color3?,
            Width: number?,
            Transparency: number?,
        }?,
    }
)
    local result = str

    if tags.Bold then
        result = "<b>" .. result .. "</b>"
    end

    if tags.Color then
        result = '<font color="rgb('
            .. math.round(tags.Color.R * 255)
            .. ","
            .. math.round(tags.Color.G * 255)
            .. ","
            .. math.round(tags.Color.B * 255)
            .. ')">'
            .. result
            .. "</font>"
    end

    if tags.Italic then
        result = "<i>" .. result .. "</i>"
    end

    if tags.Underline then
        result = "<u>" .. result .. "</u>"
    end

    if tags.Stroke then
        local tag = "<stroke"
        if tags.Stroke.Color then
            tag ..= ` color="rgb({math.round(tags.Stroke.Color.R * 255)},{math.round(tags.Stroke.Color.G * 255)},{math.round(
                tags.Stroke.Color.B * 255
            )})"`
        end

        if tags.Stroke.Width then
            tag ..= ` thickness="{tags.Stroke.Width}"`
        end

        if tags.Stroke.Transparency then
            tag ..= ` transparency="{tags.Stroke.Transparency}"`
        end

        tag ..= ">"

        result = tag .. result .. "</stroke>"
    end

    return result
end

function RichText.getTags(str: string): {
    Bold: { Vector2 }?,
    Color: { Vector2 }?,
    Italic: { Vector2 }?,
    Underline: { Vector2 }?,
    Stroke: { Vector2 }?,
}
    local result = {}

    if string.match(str, "<b>") then
        local vectors: { Vector2 } = {}
        local searchIndex = 0
        while true do
            local start, finish = string.find(str, "<b>", searchIndex)
            if not start then
                break
            end

            table.insert(vectors, Vector2.new(start, finish))
            searchIndex = finish
        end
    end

    if string.match(str, "<font[^>]+>") then
        local vectors: { Vector2 } = {}
        local searchIndex = 0
        while true do
            local start, finish = string.find(str, "<font[^>]+>", searchIndex)
            if not start then
                break
            end

            table.insert(vectors, Vector2.new(start, finish))
            searchIndex = finish
        end
    end

    if string.match(str, "<i>") then
        local vectors: { Vector2 } = {}
        local searchIndex = 0
        while true do
            local start, finish = string.find(str, "<i>", searchIndex)
            if not start then
                break
            end

            table.insert(vectors, Vector2.new(start, finish))
            searchIndex = finish
        end
    end

    if string.match(str, "<u>") then
        local vectors: { Vector2 } = {}
        local searchIndex = 0
        while true do
            local start, finish = string.find(str, "<u>", searchIndex)
            if not start then
                break
            end

            table.insert(vectors, Vector2.new(start, finish))
            searchIndex = finish
        end
    end

    if string.match(str, "<stroke[^>]+>") then
        local vectors: { Vector2 } = {}
        local searchIndex = 0
        while true do
            local start, finish = string.find(str, "<stroke[^>]+>", searchIndex)
            if not start then
                break
            end

            table.insert(vectors, Vector2.new(start, finish))
            searchIndex = finish
        end
    end

    return result
end

function RichText.hasTags(
    str: string,
    options: {
        Bold: boolean?,
        Color: boolean?,
        Italic: boolean?,
        Underline: boolean?,
        Stroke: boolean?,
    }?
)
    if not options then
        return string.match(str, "<[^>]+>") ~= nil
    end

    local result = true

    if options.Bold then
        result = result and string.match(str, "<b>") ~= nil
    end

    if options.Color then
        result = result and string.match(str, "<font[^>]+>") ~= nil
    end

    if options.Italic then
        result = result and string.match(str, "<i>") ~= nil
    end

    if options.Underline then
        result = result and string.match(str, "<u>") ~= nil
    end

    if options.Stroke then
        result = result and string.match(str, "<stroke[^>]+>") ~= nil
    end

    return result
end

function RichText.removeTags(
    str: string,
    options: {
        Bold: boolean?,
        Color: boolean?,
        Italic: boolean?,
        Underline: boolean?,
        Stroke: boolean?,
    }?
)
    if not options then
        return string.gsub(str, "<[^>]+>", "")
    end

    local result = str

    if options.Bold then
        result = string.gsub(result, "<b>", "")
        result = string.gsub(result, "</b>", "")
    end

    if options.Italic then
        result = string.gsub(result, "<i>", "")
        result = string.gsub(result, "</i>", "")
    end

    if options.Underline then
        result = string.gsub(result, "<u>", "")
        result = string.gsub(result, "</u>", "")
    end

    if options.Stroke then
        result = string.gsub(result, "<stroke[^>]+>", "")
        result = string.gsub(result, "</stroke>", "")
    end

    if options.Color then
        result = string.gsub(result, "<font[^>]+>", "")
        result = string.gsub(result, "</font>", "")
    end

    return result
end

return RichText
