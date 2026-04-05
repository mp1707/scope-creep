local UiShadow = {}

UiShadow.roles = {
    cardRest = {
        offsetX = 2,
        offsetY = 2,
        alpha = 0.08,
        expand = 0,
        destLeft = 10,
        destRight = 10,
        destTop = 10,
        destBottom = 10,
    },
    cardMotion = {
        offsetX = 4,
        offsetY = 4,
        alpha = 0.11,
        expand = 0,
        destLeft = 10,
        destRight = 10,
        destTop = 10,
        destBottom = 10,
    },
    cardDrag = {
        offsetX = 8,
        offsetY = 10,
        alpha = 0.17,
        expand = 8,
        destLeft = 10,
        destRight = 10,
        destTop = 10,
        destBottom = 10,
    },
    panel = {
        offsetX = 2,
        offsetY = 2,
        alpha = 0.14,
        expand = 0,
    },
    tooltip = {
        offsetX = 2,
        offsetY = 2,
        alpha = 0.08,
        expand = 0,
        destLeft = 8,
        destRight = 8,
        destTop = 8,
        destBottom = 8,
    },
    buttonRaised = {
        offsetX = 2,
        offsetY = 2,
        alpha = 0.16,
        expand = 0,
    },
    buttonInset = {
        offsetX = 1,
        offsetY = 1,
        alpha = 0.06,
        expand = 0,
    },
}

local SHADOW_KEYS = {
    "offsetX",
    "offsetY",
    "alpha",
    "expand",
    "destLeft",
    "destRight",
    "destTop",
    "destBottom",
}

local function copyShadow(definition)
    local shadow = {}
    for _, key in ipairs(SHADOW_KEYS) do
        local value = definition[key]
        if value ~= nil then
            shadow[key] = value
        end
    end
    return shadow
end

function UiShadow.get(role, overrides)
    local base = UiShadow.roles[role] or UiShadow.roles.cardRest
    local shadow = copyShadow(base)

    if type(overrides) == "table" then
        for _, key in ipairs(SHADOW_KEYS) do
            if overrides[key] ~= nil then
                shadow[key] = tonumber(overrides[key]) or overrides[key]
            end
        end
    end

    return shadow
end

function UiShadow.capture(target, role, options)
    options = options or {}
    local shadow = UiShadow.get(role, options)

    if type(target) == "table" then
        if target.shadowOffsetX ~= nil then
            shadow.offsetX = tonumber(target.shadowOffsetX) or shadow.offsetX
        end
        if target.shadowOffsetY ~= nil then
            shadow.offsetY = tonumber(target.shadowOffsetY) or shadow.offsetY
        end
        if target.shadowAlpha ~= nil then
            shadow.alpha = tonumber(target.shadowAlpha) or shadow.alpha
        end
        if target.shadowExpand ~= nil then
            shadow.expand = tonumber(target.shadowExpand) or shadow.expand
        end
    end

    local alphaMultiplier = tonumber(options.alphaMultiplier) or 1
    shadow.alpha = (tonumber(shadow.alpha) or 0) * alphaMultiplier
    return shadow
end

function UiShadow.applyRole(target, role, options)
    if type(target) ~= "table" then
        return UiShadow.get(role, options)
    end

    options = options or {}
    local shadow = UiShadow.get(role, options)

    target.targetShadowOffsetX = shadow.offsetX or 0
    target.targetShadowOffsetY = shadow.offsetY or 0
    target.targetShadowAlpha = shadow.alpha or 0
    target.targetShadowExpand = shadow.expand or 0
    target.shadowRole = role

    if options.immediate or target.shadowOffsetX == nil or target.shadowOffsetY == nil
        or target.shadowAlpha == nil or target.shadowExpand == nil then
        target.shadowOffsetX = target.targetShadowOffsetX
        target.shadowOffsetY = target.targetShadowOffsetY
        target.shadowAlpha = target.targetShadowAlpha
        target.shadowExpand = target.targetShadowExpand
    end

    return shadow
end

return UiShadow
