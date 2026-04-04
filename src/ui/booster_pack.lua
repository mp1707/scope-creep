local Scaling = require("src.core.scaling")
local Theme = require("src.ui.theme")

local BoosterPack = {}
BoosterPack.__index = BoosterPack

local PACK_IMAGE_PATH = "assets/icons/characters/featur_booster_pack.png"
local PACK_SPRITE_SCALE = 1.15
local BADGE_SCALE = 1.5
local BADGE_OFFSET_X = -10
local BADGE_OFFSET_Y = -10
local FEATURE_ICON_PATH = "assets/icons/Golden Star 1st Outline 256px.png"
local DEFAULT_TEXT_COLOR = { 0, 0, 0, 1 }

local packImage = nil
local packImageLoadAttempted = false
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

local function getPackImage()
    if packImage or packImageLoadAttempted then
        return packImage
    end

    packImageLoadAttempted = true
    local ok, loadedImage = pcall(love.graphics.newImage, PACK_IMAGE_PATH)
    if not ok then
        return nil
    end

    loadedImage:setFilter("linear", "linear")
    packImage = loadedImage
    return packImage
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

local function getPackSpriteRect(self, expand, offsetX, offsetY)
    local grownWidth = self.width * PACK_SPRITE_SCALE
    local grownHeight = self.height * PACK_SPRITE_SCALE
    local drawWidth = grownWidth + (expand or 0)
    local drawHeight = grownHeight + (expand or 0)
    local drawX = self.x - (grownWidth - self.width) * 0.5 - ((expand or 0) * 0.5) + (offsetX or 0)
    local drawY = self.y - (grownHeight - self.height) * 0.5 - ((expand or 0) * 0.5) + (offsetY or 0)
    return drawX, drawY, drawWidth, drawHeight
end

local function drawOpportunityBadge(self, alpha, viewportScale)
    local remaining = math.max(0, math.floor(self.insightsRemaining or 0))
    local centerX = self.x + self.width + BADGE_OFFSET_X
    local centerY = self.y + BADGE_OFFSET_Y
    local radius = 12 * BADGE_SCALE

    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.circle("fill", centerX, centerY, radius)

    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.setLineWidth(2 * BADGE_SCALE)
    love.graphics.circle("line", centerX, centerY, radius)

    local label = tostring(remaining)
    local font = love.graphics.getFont()
    local textScale = BADGE_SCALE / viewportScale
    local textWidth = font:getWidth(label) * textScale
    local textHeight = font:getHeight() * textScale
    love.graphics.print(
        label,
        centerX - textWidth * 0.5,
        centerY - textHeight * 0.5,
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

    self.shadowOffsetX = 4
    self.shadowOffsetY = 4
    self.shadowAlpha = 0.11
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
    self.targetShadowOffsetX = 4
    self.targetShadowOffsetY = 4
    self.targetShadowAlpha = 0.14
    self.targetShadowExpand = 0
    return true
end

function BoosterPack:endDrag()
    self.dragging = false
    self.targetScale = 1
    self.targetShadowOffsetX = 4
    self.targetShadowOffsetY = 4
    self.targetShadowAlpha = 0.11
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

function BoosterPack:drawShadow(alpha)
    local effectiveAlpha = (self.shadowAlpha or 0.11) * (alpha or 1)
    if effectiveAlpha <= 0 then
        return
    end

    local image = getPackImage()
    local shadowExpand = self.shadowExpand or 0
    local shadowOffsetX = self.shadowOffsetX or 4
    local shadowOffsetY = self.shadowOffsetY or 4

    if image then
        local drawX, drawY, drawWidth, drawHeight = getPackSpriteRect(self, shadowExpand, shadowOffsetX, shadowOffsetY)
        local scaleX = drawWidth / image:getWidth()
        local scaleY = drawHeight / image:getHeight()
        love.graphics.setColor(0, 0, 0, effectiveAlpha)
        love.graphics.draw(image, drawX, drawY, 0, scaleX, scaleY)
        return
    end

    local shadowColor = Theme.colors.cardShadow or DEFAULT_TEXT_COLOR
    love.graphics.setColor(shadowColor[1], shadowColor[2], shadowColor[3], effectiveAlpha)
    love.graphics.rectangle(
        "fill",
        self.x - shadowExpand * 0.5 + shadowOffsetX,
        self.y - shadowExpand * 0.5 + shadowOffsetY,
        self.width + shadowExpand,
        self.height + shadowExpand
    )
end

function BoosterPack:draw(_, options)
    options = options or {}

    local alpha = options.alpha or 1
    local extraScale = options.extraScale or 1
    local centerX = self.x + self.width * 0.5
    local centerY = self.y + self.height * 0.5
    local drawScale = self.scale * extraScale
    local drawRotation = self.rotation or 0
    local image = getPackImage()

    love.graphics.push()
    love.graphics.translate(centerX, centerY)
    love.graphics.rotate(drawRotation)
    love.graphics.scale(drawScale, drawScale)
    love.graphics.translate(-centerX, -centerY)

    if not options.skipShadow then
        self:drawShadow(alpha)
    end

    if image then
        local drawX, drawY, drawWidth, drawHeight = getPackSpriteRect(self)
        local scaleX = drawWidth / image:getWidth()
        local scaleY = drawHeight / image:getHeight()
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(image, drawX, drawY, 0, scaleX, scaleY)
    end

    local viewportScale = Scaling.getScale()
    if viewportScale <= 0 then
        viewportScale = 1
    end

    local style = Theme.cardStyles and Theme.cardStyles.opportunity
    local textColor = style and style.textColor or DEFAULT_TEXT_COLOR
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
        love.graphics.setColor(1, 1, 1, alpha)
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
