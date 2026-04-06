local Theme = require("src.ui.theme")
local NineSlice = require("src.ui.nine_slice")
local UiShadow = require("src.ui.ui_shadow")

local UiPanel = {}

local function resolveSurfaceConfig(options)
    local formFactor = options and options.formFactor
    local formFactors = Theme.ui.surface9sliceFormFactors
    if type(formFactor) == "string" and type(formFactors) == "table" then
        local variant = formFactors[formFactor]
        if variant then
            return variant
        end
    end
    return Theme.ui.surface9slice
end

local function pickInsets(options, defaultConfig)
    local sourceLeft = tonumber(options.sourceLeft) or tonumber(defaultConfig.sourceLeft) or 48
    local sourceRight = tonumber(options.sourceRight) or tonumber(defaultConfig.sourceRight) or 48
    local sourceTop = tonumber(options.sourceTop) or tonumber(defaultConfig.sourceTop) or 48
    local sourceBottom = tonumber(options.sourceBottom) or tonumber(defaultConfig.sourceBottom) or 48

    local destLeft = tonumber(options.destLeft) or tonumber(defaultConfig.destLeft) or 12
    local destRight = tonumber(options.destRight) or tonumber(defaultConfig.destRight) or 12
    local destTop = tonumber(options.destTop) or tonumber(defaultConfig.destTop) or 12
    local destBottom = tonumber(options.destBottom) or tonumber(defaultConfig.destBottom) or 12

    return {
        sourceLeft = sourceLeft,
        sourceRight = sourceRight,
        sourceTop = sourceTop,
        sourceBottom = sourceBottom,
        destLeft = destLeft,
        destRight = destRight,
        destTop = destTop,
        destBottom = destBottom,
    }
end

local function drawNineSlice(config, x, y, width, height, color, options)
    options = options or {}
    if width <= 0 or height <= 0 then
        return false
    end

    local insets = pickInsets(options, config)
    local tint = color or Theme.palette.white
    return NineSlice.draw(
        config.path,
        x,
        y,
        width,
        height,
        {
            sourceX = tonumber(config.sourceX) or 0,
            sourceY = tonumber(config.sourceY) or 0,
            sourceWidth = tonumber(config.sourceWidth) or 256,
            sourceHeight = tonumber(config.sourceHeight) or 256,
            left = insets.sourceLeft,
            right = insets.sourceRight,
            top = insets.sourceTop,
            bottom = insets.sourceBottom,
            destLeft = insets.destLeft,
            destRight = insets.destRight,
            destTop = insets.destTop,
            destBottom = insets.destBottom,
            tint = tint,
            alpha = tonumber(options.alpha) or 1,
            drawCenter = options.drawCenter,
        }
    )
end

function UiPanel.drawSurface(x, y, width, height, color, options)
    local config = resolveSurfaceConfig(options)
    return drawNineSlice(config, x, y, width, height, color, options)
end

function UiPanel.drawBorder(x, y, width, height, color, options)
    local config = Theme.ui.border9slice
    return drawNineSlice(config, x, y, width, height, color, options)
end

function UiPanel.drawTopSurfaceOverlay(x, y, width, height, topHeight, color, options)
    if topHeight <= 0 then
        return
    end

    options = options or {}
    local bleedBottom = tonumber(options.bleBottom) or tonumber(options.bleedBottom) or 0
    local overlayHeight = math.max(1, topHeight + bleedBottom)

    UiPanel.drawSurface(x, y, width, overlayHeight, color, options)
end

function UiPanel.drawShadow(x, y, width, height, options)
    options = options or {}
    local expand = tonumber(options.expand) or 0
    local offsetX = tonumber(options.offsetX) or 0
    local offsetY = tonumber(options.offsetY) or 0
    local alpha = tonumber(options.alpha) or 0.2

    local shadowX = x - expand * 0.5 + offsetX
    local shadowY = y - expand * 0.5 + offsetY
    local shadowWidth = width + expand
    local shadowHeight = height + expand

    local insets = {
        destLeft = tonumber(options.destLeft),
        destRight = tonumber(options.destRight),
        destTop = tonumber(options.destTop),
        destBottom = tonumber(options.destBottom),
    }

    local tint = Theme.colors.shadowTint
    UiPanel.drawSurface(shadowX, shadowY, shadowWidth, shadowHeight, tint, {
        alpha = alpha,
        destLeft = insets.destLeft,
        destRight = insets.destRight,
        destTop = insets.destTop,
        destBottom = insets.destBottom,
        formFactor = options.formFactor,
    })
    love.graphics.setColor(1, 1, 1, 1)
end

function UiPanel.drawPanel(x, y, width, height, options)
    options = options or {}

    local alpha = tonumber(options.alpha) or 1
    local bodyColor = options.bodyColor or Theme.palette.white
    local headerColor = options.headerColor
    local headerHeight = tonumber(options.headerHeight) or 0
    local borderColor = options.borderColor or Theme.colors.borderStrong
    local surfaceFormFactor = options.surfaceFormFactor
    local headerSurfaceFormFactor = options.headerSurfaceFormFactor or surfaceFormFactor

    if options.drawShadow then
        local shadowOptions = UiShadow.get(options.shadowRole or "panel", {
            alpha = tonumber(options.shadowAlpha),
            offsetX = tonumber(options.shadowOffsetX),
            offsetY = tonumber(options.shadowOffsetY),
            expand = tonumber(options.shadowExpand),
            destLeft = tonumber(options.shadowDestLeft),
            destRight = tonumber(options.shadowDestRight),
            destTop = tonumber(options.shadowDestTop),
            destBottom = tonumber(options.shadowDestBottom),
        })
        shadowOptions.formFactor = surfaceFormFactor
        UiPanel.drawShadow(x, y, width, height, shadowOptions)
    end

    UiPanel.drawSurface(x, y, width, height, bodyColor, {
        alpha = alpha,
        formFactor = surfaceFormFactor,
    })
    if headerColor and headerHeight > 0 then
        UiPanel.drawTopSurfaceOverlay(x, y, width, height, headerHeight, headerColor, {
            alpha = alpha,
            formFactor = headerSurfaceFormFactor,
        })
    end
    UiPanel.drawBorder(x, y, width, height, borderColor, { alpha = alpha })
end

return UiPanel
