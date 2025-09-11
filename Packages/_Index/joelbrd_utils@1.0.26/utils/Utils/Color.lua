local Color = {}

local LIGHTEN_DARKEN_DEFAULT_SCALAR = 2

--- [0, 255]
function Color.mutateRGB(color: Color3, mutator: (rgb: { R: number, G: number, B: number }) -> ())
    local rgb = {
        R = color.R,
        G = color.G,
        B = color.B,
    }
    mutator(rgb)
    return Color3.new(rgb.R, rgb.G, rgb.B)
end

--- [0, 255]
function Color.mutateHSV(color: Color3, mutator: (hsv: { H: number, S: number, V: number }) -> ())
    local h, s, v = Color3.toHSV(color)
    local hsv = {
        H = h * 255,
        S = s * 255,
        V = v * 255,
    }
    mutator(hsv)
    return Color3.fromHSV(hsv.H / 255, hsv.S / 255, hsv.V / 255)
end

--- Scalar > 1 to lighten. Default scalar is 2, making it 2x lighter.
function Color.lighten(color: Color3, scalar: number?)
    return Color.mutateHSV(color, function(hsv)
        hsv.S = math.max(0, hsv.S / (scalar or LIGHTEN_DARKEN_DEFAULT_SCALAR))
        hsv.V = math.min(255, hsv.V * (scalar or LIGHTEN_DARKEN_DEFAULT_SCALAR))
    end)
end

--- Scalar > 1 to darken. Default scalar is 2, making it 2x darker.
function Color.darken(color: Color3, scalar: number?)
    return Color.mutateHSV(color, function(hsv)
        hsv.S = math.min(255, hsv.S * (scalar or LIGHTEN_DARKEN_DEFAULT_SCALAR))
        hsv.V = math.max(0, hsv.V / (scalar or LIGHTEN_DARKEN_DEFAULT_SCALAR))
    end)
end

function Color.isLight(color: Color3)
    --[=[
        The values: 299 for red, 587 for green, 114 for blue

        Come from a perceptual luminance formula used in digital image processing and accessibility standards (like WCAG).
    ]=]

    local r, g, b = color.R * 255, color.G * 255, color.B * 255
    return (r * 299 + g * 587 + b * 114) / 1000 > 128
end

function Color.isDark(color: Color3)
    return not Color.isLight(color)
end

--[=[
    Sugar for

    ```lua
    if Color.isLight(color) then
        return Color.darken(color, scalar)
    else
        return Color.lighten(color, scalar)
    end
    ```
]=]
function Color.contrast(color: Color3, scalar: number?)
    if Color.isLight(color) then
        return Color.darken(color, scalar)
    else
        return Color.lighten(color, scalar)
    end
end

function Color.merge(...: Color3)
    local colors = { ... }

    local r = 0
    local g = 0
    local b = 0

    for _, color in ipairs(colors) do
        r += color.R
        g += color.G
        b += color.B
    end

    return Color3.new(r / #colors, g / #colors, b / #colors)
end

return Color
