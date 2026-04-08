local Utils = {}

function Utils.clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

function Utils.damp(current, target, speed, dt)
    local t = 1 - math.exp(-speed * dt)
    return current + (target - current) * t
end

function Utils.lerp(a, b, t)
    return a + (b - a) * t
end

function Utils.easeOutQuad(t)
    local inv = 1 - t
    return 1 - (inv * inv)
end

function Utils.setColorWithAlpha(color, alphaMultiplier)
    local alpha = (color[4] or 1) * (alphaMultiplier or 1)
    love.graphics.setColor(color[1], color[2], color[3], alpha)
end

function Utils.copyState(value)
    if type(value) ~= "table" then
        return value
    end
    local out = {}
    for key, nestedValue in pairs(value) do
        out[Utils.copyState(key)] = Utils.copyState(nestedValue)
    end
    return out
end

function Utils.formatTime(seconds)
    local s = math.max(0, math.floor(seconds))
    return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

return Utils
