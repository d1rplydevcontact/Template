local HttpService = game:GetService("HttpService")

--[=[
    Generates a UUID (Universally Unique Identifier) of 36 characters.

    @param options: An optional table with a boolean `small` key to determine if a short UUID should be generated (8 characters).
    @return A string representing the UUID.
]=]
return function(options: {
    small: boolean?,
}?)
    local doSmall = options and options.small or false

    if doSmall then
        return HttpService:GenerateGUID(false):sub(1, 8)
    end

    return HttpService:GenerateGUID(false)
end
