local Scaling = require("src.core.scaling")
local Theme = require("src.ui.theme")
local CardBackground = require("src.ui.card_background")
local UiPanel = require("src.ui.ui_panel")

local BoosterPack = {}
BoosterPack.__index = BoosterPack

local BADGE_SIZE = 34
local BADGE_INSET = 6
local FEATURE_ICON_PATH = "assets/handdrawn/cardIcons/star.png"
local DEFAULT_TEXT_COLOR = Theme.colors.textPrimary

local featureIconImage = nil
local featureIconLoadAttempted = false

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function damp(current, target, speed, dt)
    local t = 1 - math.exp(-speed * dt)
    return current + (target - current) * t
end

local function applyAlpha(color, alphaMultiplier)
    return color[1], color[2], color[3], (color[4] or 1) * alphaMultiplier
end

local function getFeatureIconImage()
    if featureIconImage or featureIconLoadAttempted then
        return featureIconImage
    end

    featureIconLoadAttempted = true
    local ok, loadedImage = pcall(love.graphics.newImage, FEATURE_ICON_PATH)
    if not ok then
        return nil
    end

    loadedImage:setFilter("linear", "linear")
    featureIconImage = loadedImage
    return featureIconImage
end

local function getFeatureCardIconSize()
    local iconTheme = (Theme.card and Theme.card.icon) or {}
    local size = tonumber(iconTheme.featureSize) or tonumber(iconTheme.bodySize) or 74
    return math.max(32, size)
end

local function drawOpportunityBadge(self, alpha, viewportScale)
    local remaining = math.max(0, math.floor(self.insightsRemaining or 0))
    local badgeX = self.x + self.width - BADGE_SIZE - BADGE_INSET + 1.5
    local badgeY = self.y + BADGE_INSET
    UiPanel.drawPanel(badgeX, badgeY, BADGE_SIZE, BADGE_SIZE, {
        bodyColor = Theme.palette.featureBody,
        borderColor = Theme.colors.borderStrong,
        alpha = alpha,
    })

    local label = tostring(remaining)
    love.graphics.setFont(Theme.fonts.cardBody)
    local font = love.graphics.getFont()
    local textScale = 1 / viewportScale
    local textWidth = font:getWidth(label) * textScale
    local textHeight = font:getHeight() * textScale
    love.graphics.setColor(applyAlpha(DEFAULT_TEXT_COLOR, alpha))
    love.graphics.print(
        label,
        badgeX + (BADGE_SIZE - textWidth) * 0.5,
        badgeY + (BADGE_SIZE - textHeight) * 0.5,
        0,
        textScale,
        textScale
    )
end

function BoosterPack.new(config)
    local self = setmetatable({}, BoosterPack)

    self.id = config.id
    self.objectType = "booster_pack"
    self.cardType = "opportunity"
    self.title = config.title or "Actionable Insights"
    self.effect = config.effect
    self.insightsRemaining = config.insightsRemaining
    if self.insightsRemaining == nil then
        self.insightsRemaining = 3
    end

    self.width = config.width or 189
    self.height = config.height or 236
    self.worldWidth = config.worldWidth or 1920
    self.worldHeight = config.worldHeight or 1080

    self.x = config.x or 0
    self.y = config.y or 0
    self.targetX = config.targetX or self.x
    self.targetY = config.targetY or self.y

    self.dragging = false
    self.dragOffsetX = 0
    self.dragOffsetY = 0

    self.scale = 1
    self.targetScale = 1

    self.shadowOffsetX = 2
    self.shadowOffsetY = 2
    self.shadowAlpha = 0.08
    self.shadowExpand = 0

    self.targetShadowOffsetX = self.shadowOffsetX
    self.targetShadowOffsetY = self.shadowOffsetY
    self.targetShadowAlpha = self.shadowAlpha
    self.targetShadowExpand = self.shadowExpand

    self.dragFollowSpeed = 34
    self.settleSpeed = 22
    self.scaleSpeed = 20
    self.shadowSpeed = 18

    self.stackParentId = nil
    self.shipState = nil
    self.motionState = nil
    self.rotation = 0
    self.renderAlpha = 1

    return self
end

function BoosterPack:containsPoint(px, py)
    local centerX = self.x + self.width * 0.5
    local centerY = self.y + self.height * 0.5

    local halfW = self.width * self.scale * 0.5
    local halfH = self.height * self.scale * 0.5

    return px >= centerX - halfW and px <= centerX + halfW
        and py >= centerY - halfH and py <= centerY + halfH
end

function BoosterPack:containsHeaderPoint()
    return false
end

function BoosterPack:beginDrag(px, py, force)
    if not force and not self:containsPoint(px, py) then
        return false
    end

    self.dragging = true
    self.dragOffsetX = px - self.x
    self.dragOffsetY = py - self.y
    self.targetScale = 1.03
    self.targetShadowOffsetX = 8
    self.targetShadowOffsetY = 10
    self.targetShadowAlpha = 0.17
    self.targetShadowExpand = 8
    return true
end

function BoosterPack:endDrag()
    self.dragging = false
    self.targetScale = 1
    self.targetShadowOffsetX = 2
    self.targetShadowOffsetY = 2
    self.targetShadowAlpha = 0.08
    self.targetShadowExpand = 0
end

function BoosterPack:isDragging()
    return self.dragging
end

function BoosterPack:update(dt, pointerX, pointerY)
    if self.dragging and pointerX and pointerY then
        self.targetX = clamp(pointerX - self.dragOffsetX, 0, self.worldWidth - self.width)
        self.targetY = clamp(pointerY - self.dragOffsetY, 0, self.worldHeight - self.height)
    end

    local moveSpeed = self.dragging and self.dragFollowSpeed or self.settleSpeed
    self.x = damp(self.x, self.targetX, moveSpeed, dt)
    self.y = damp(self.y, self.targetY, moveSpeed, dt)
    self.scale = damp(self.scale, self.targetScale, self.scaleSpeed, dt)
    self.shadowOffsetX = damp(self.shadowOffsetX, self.targetShadowOffsetX, self.shadowSpeed, dt)
    self.shadowOffsetY = damp(self.shadowOffsetY, self.targetShadowOffsetY, self.shadowSpeed, dt)
    self.shadowAlpha = damp(self.shadowAlpha, self.targetShadowAlpha, self.shadowSpeed, dt)
    self.shadowExpand = damp(self.shadowExpand, self.targetShadowExpand, self.shadowSpeed, dt)
end

function BoosterPack:getSnapshot()
    return {
        id = self.id,
        objectType = self.objectType,
        cardType = self.cardType,
        title = self.title,
        effect = self.effect,
        insightsRemaining = self.insightsRemaining,
        x = self.x,
        y = self.y,
        targetX = self.targetX,
        targetY = self.targetY,
        width = self.width,
        height = self.height,
    }
end

function BoosterPack:drawShadow()
    return
end

function BoosterPack:draw(_, options)
    options = options or {}

    local alpha = options.alpha or 1
    local extraScale = options.extraScale or 1
    local skipShadow = options.skipShadow == true
    local centerX = self.x + self.width * 0.5
    local centerY = self.y + self.height * 0.5
    local drawScale = self.scale * extraScale
    local drawRotation = self.rotation or 0

    love.graphics.push()
    love.graphics.translate(centerX, centerY)
    love.graphics.rotate(drawRotation)
    love.graphics.scale(drawScale, drawScale)
    love.graphics.translate(-centerX, -centerY)

    local viewportScale = Scaling.getScale()
    if viewportScale <= 0 then
        viewportScale = 1
    end

    local style = Theme.cardStyles and Theme.cardStyles.opportunity
    local textColor = style and style.textColor or DEFAULT_TEXT_COLOR

    if not skipShadow then
        UiPanel.drawShadow(self.x, self.y, self.width, self.height, {
            alpha = (self.shadowAlpha or 0.08) * alpha,
            offsetX = self.shadowOffsetX or 0,
            offsetY = self.shadowOffsetY or 0,
            expand = self.shadowExpand or 0,
            destLeft = 10,
            destRight = 10,
            destTop = 10,
            destBottom = 10,
        })
    end

    CardBackground.draw(self.x, self.y, self.width, self.height, alpha, {
        bodyColor = Theme.cardStyles.opportunity.bodyColor,
        headerColor = Theme.cardStyles.opportunity.headerColor,
        headerHeight = 0,
        borderColor = Theme.cardStyles.opportunity.borderColor,
    })

    local font = love.graphics.getFont()
    local lineHeight = font:getHeight() / viewportScale
    local verticalGap = math.max(4, lineHeight * 0.22)
    local iconSize = getFeatureCardIconSize()
    local totalHeight = lineHeight + verticalGap + iconSize + verticalGap + lineHeight
    local startY = self.y + (self.height - totalHeight) * 0.5
    local featureTextY = startY
    local iconY = featureTextY + lineHeight + verticalGap
    local ideasTextY = iconY + iconSize + verticalGap

    love.graphics.setColor(applyAlpha(textColor, alpha))
    love.graphics.printf(
        "Feature",
        self.x + 12,
        featureTextY,
        (self.width - 24) * viewportScale,
        "center",
        0,
        1 / viewportScale,
        1 / viewportScale
    )

    local featureIcon = getFeatureIconImage()
    if featureIcon then
        local iconScale = math.min(iconSize / featureIcon:getWidth(), iconSize / featureIcon:getHeight())
        local drawWidth = featureIcon:getWidth() * iconScale
        local drawHeight = featureIcon:getHeight() * iconScale
        local drawX = self.x + (self.width - drawWidth) * 0.5
        local drawY = iconY + (iconSize - drawHeight) * 0.5
        local iconColor = Theme.colors.icon
        love.graphics.setColor(iconColor[1], iconColor[2], iconColor[3], alpha)
        love.graphics.draw(featureIcon, drawX, drawY, 0, iconScale, iconScale)
    end

    love.graphics.setColor(applyAlpha(textColor, alpha))
    love.graphics.printf(
        "Ideas",
        self.x + 12,
        ideasTextY,
        (self.width - 24) * viewportScale,
        "center",
        0,
        1 / viewportScale,
        1 / viewportScale
    )

    drawOpportunityBadge(self, alpha, viewportScale)

    love.graphics.pop()
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return BoosterPack
