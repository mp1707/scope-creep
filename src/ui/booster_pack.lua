local Scaling = require("src.core.scaling")
local Theme = require("src.ui.theme")
local UiShadow = require("src.ui.ui_shadow")

local BoosterPack = {}
BoosterPack.__index = BoosterPack

local BORDER_SPRITE_PATH = "assets/handdrawn/ui/boosterBorder.png"
local BACKGROUND_SPRITE_PATH = "assets/handdrawn/ui/boosterBG.png"
local DEFAULT_ICON_PATH = "assets/handdrawn/cardIcons/star.png"
local DEFAULT_ICON_CIRCLE_PATH = "assets/handdrawn/ui/circleBig.png"
local SOURCE_ASPECT = 1280 / 1024
local HEADER_HEIGHT = 48
local BACKGROUND_INSET_SCALE = 1.01

local borderImage = nil
local borderLoadAttempted = false
local backgroundImage = nil
local backgroundLoadAttempted = false
local iconImageCache = {}
local iconLoadAttempted = {}

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

local function loadImage(path)
    local ok, image = pcall(love.graphics.newImage, path)
    if not ok then return nil end
    image:setFilter("linear", "linear")
    return image
end

local function getBorderImage()
    if borderImage or borderLoadAttempted then return borderImage end
    borderLoadAttempted = true
    borderImage = loadImage(BORDER_SPRITE_PATH)
    return borderImage
end

local function getBackgroundImage()
    if backgroundImage or backgroundLoadAttempted then return backgroundImage end
    backgroundLoadAttempted = true
    backgroundImage = loadImage(BACKGROUND_SPRITE_PATH)
    return backgroundImage
end

local function getIconImage(path)
    if not path or path == "" then return nil end
    if iconImageCache[path] or iconLoadAttempted[path] then
        return iconImageCache[path]
    end
    iconLoadAttempted[path] = true
    iconImageCache[path] = loadImage(path)
    return iconImageCache[path]
end

local function drawCenteredImage(image, x, y, width, height, tint, alpha)
    if not image then return end
    if width <= 0 or height <= 0 then return end
    local iw = image:getWidth()
    local ih = image:getHeight()
    if iw <= 0 or ih <= 0 then return end

    local scale = math.min(width / iw, height / ih)
    local drawW = iw * scale
    local drawH = ih * scale
    local drawX = x + (width - drawW) * 0.5
    local drawY = y + (height - drawH) * 0.5

    love.graphics.setColor(applyAlpha(tint, alpha))
    love.graphics.draw(image, drawX, drawY, 0, scale, scale)
end

local function drawIconInSquare(image, areaX, areaY, areaSize, targetSize, tint, alpha)
    if not image then return end
    if areaSize <= 0 or targetSize <= 0 then return end
    local iw = image:getWidth()
    local ih = image:getHeight()
    if iw <= 0 or ih <= 0 then return end

    local fittedTargetSize = math.max(1, math.min(targetSize, areaSize))
    local scale = math.min(fittedTargetSize / iw, fittedTargetSize / ih)
    local drawW = iw * scale
    local drawH = ih * scale
    local drawX = areaX + (areaSize - drawW) * 0.5
    local drawY = areaY + (areaSize - drawH) * 0.5
    love.graphics.setColor(applyAlpha(tint, alpha))
    love.graphics.draw(image, drawX, drawY, 0, scale, scale)
end

local function getFeatureIconTargetSize(cardHeight)
    local iconTheme = (Theme.card and Theme.card.icon) or {}
    local size = tonumber(iconTheme.featureSize) or tonumber(iconTheme.bodySize)
    if not size then
        size = math.floor(cardHeight * 0.36 + 0.5)
    end
    return math.max(32, size)
end

local function drawSpriteShadow(self, alpha)
    local bg = getBackgroundImage()
    if not bg then return end

    local shadow = UiShadow.capture(self, self.shadowRole or "cardRest", { alphaMultiplier = alpha })
    local expand = math.max(0, tonumber(shadow.expand) or 0)
    local offsetX = tonumber(shadow.offsetX) or 0
    local offsetY = tonumber(shadow.offsetY) or 0
    local shadowAlpha = tonumber(shadow.alpha) or 0
    if shadowAlpha <= 0 then return end

    local shadowX = self.x + offsetX - expand
    local shadowY = self.y + offsetY - expand
    local shadowW = self.width + (expand * 2)
    local shadowH = self.height + (expand * 2)
    local shadowTint = Theme.colors.cardShadow or Theme.palette.ink or { 0, 0, 0, 1 }

    drawCenteredImage(bg, shadowX, shadowY, shadowW, shadowH, shadowTint, shadowAlpha)
end

function BoosterPack.new(config)
    config = config or {}
    local self = setmetatable({}, BoosterPack)

    self.id = config.id
    self.objectType = config.objectType or "booster_pack"
    self.cardType = config.cardType or "booster_pack"
    self.role = config.role
    self.subType = config.subType
    self.effect = config.effect

    self.x = config.x or 0
    self.y = config.y or 0
    self.targetX = config.targetX or self.x
    self.targetY = config.targetY or self.y

    if config.width and not config.height then
        self.width = config.width
        self.height = math.floor((self.width * SOURCE_ASPECT) + 0.5)
    elseif config.height and not config.width then
        self.height = config.height
        self.width = math.floor((self.height / SOURCE_ASPECT) + 0.5)
    else
        self.width = config.width or 172
        self.height = config.height or 215
    end

    self.worldWidth = config.worldWidth or 1920
    self.worldHeight = config.worldHeight or 1080

    self.topText = config.topText or "Feature"
    self.bottomText = config.bottomText or "Ideas"
    self.iconPath = config.iconPath or DEFAULT_ICON_PATH
    self.iconCirclePath = config.iconCirclePath or DEFAULT_ICON_CIRCLE_PATH

    self.backgroundColor = config.backgroundColor or { 0.78, 0.91, 1.0, 1.0 }
    self.borderColor = config.borderColor
        or (Theme.cardStyles and Theme.cardStyles.default and Theme.cardStyles.default.borderColor)
        or Theme.colors.borderStrong
    self.textColor = config.textColor or Theme.colors.textPrimary
    self.iconColor = config.iconColor or Theme.colors.icon
    self.iconCircleColor = config.iconCircleColor or { 0.58, 0.76, 0.95, 1.0 }

    self.dragging = false
    self.dragOffsetX = 0
    self.dragOffsetY = 0
    self.scale = 1
    self.targetScale = 1
    self.dragFollowSpeed = 34
    self.settleSpeed = 22
    self.scaleSpeed = 20
    self.shadowSpeed = 18
    self.stackParentId = nil
    self.shipState = nil
    self.motionState = nil
    self.rotation = 0
    self.renderAlpha = 1
    self:setShadowRole("cardRest", true)

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

function BoosterPack:containsHeaderPoint(px, py)
    local centerX = self.x + self.width * 0.5
    local centerY = self.y + self.height * 0.5
    local halfW = self.width * self.scale * 0.5
    local halfH = self.height * self.scale * 0.5

    local left = centerX - halfW
    local right = centerX + halfW
    local top = centerY - halfH
    local headerBottom = top + HEADER_HEIGHT * self.scale

    return px >= left and px <= right
        and py >= top and py <= headerBottom
end

function BoosterPack:beginDrag(px, py, force)
    if not force and not self:containsPoint(px, py) then
        return false
    end
    self.dragging = true
    self.dragOffsetX = px - self.x
    self.dragOffsetY = py - self.y
    self.targetScale = 1.03
    self:setShadowRole("cardDrag")
    return true
end

function BoosterPack:endDrag()
    self.dragging = false
    self.targetScale = 1
    self:setShadowRole("cardRest")
end

function BoosterPack:isDragging()
    return self.dragging
end

function BoosterPack:setShadowRole(role, immediate)
    UiShadow.applyRole(self, role, { immediate = immediate == true })
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
        role = self.role,
        subType = self.subType,
        effect = self.effect,
        x = self.x,
        y = self.y,
        targetX = self.targetX,
        targetY = self.targetY,
        width = self.width,
        height = self.height,
        topText = self.topText,
        bottomText = self.bottomText,
        iconPath = self.iconPath,
        iconCirclePath = self.iconCirclePath,
        backgroundColor = self.backgroundColor,
        borderColor = self.borderColor,
        textColor = self.textColor,
        iconColor = self.iconColor,
        iconCircleColor = self.iconCircleColor,
    }
end

function BoosterPack:draw(headerFont, options)
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

    if not skipShadow then
        drawSpriteShadow(self, alpha)
    end

    local bg = getBackgroundImage()
    if bg then
        local bgWidth = self.width * BACKGROUND_INSET_SCALE
        local bgHeight = self.height * BACKGROUND_INSET_SCALE
        local bgX = self.x + (self.width - bgWidth) * 0.5 - 1
        local bgY = self.y + (self.height - bgHeight) * 0.5 - 1
        love.graphics.setColor(applyAlpha(self.backgroundColor, alpha))
        love.graphics.draw(bg, bgX, bgY, 0, bgWidth / bg:getWidth(), bgHeight / bg:getHeight())
    end

    local viewportScale = Scaling.getScale()
    if viewportScale <= 0 then viewportScale = 1 end
    if headerFont then love.graphics.setFont(headerFont) end

    local headerScale = 1 / viewportScale
    local headerFontRef = love.graphics.getFont()
    local lineHeight = headerFontRef:getHeight() / viewportScale
    local verticalGap = math.max(4, lineHeight * 0.22)
    local iconSize = math.min(getFeatureIconTargetSize(self.height), self.width * 0.72)
    local totalHeight = lineHeight + verticalGap + iconSize + verticalGap + lineHeight
    local startY = self.y + (self.height - totalHeight) * 0.5
    local topY = startY
    local iconY = topY + lineHeight + verticalGap
    local bottomY = iconY + iconSize + verticalGap

    love.graphics.setColor(applyAlpha(self.textColor, alpha))
    love.graphics.printf(
        tostring(self.topText or ""),
        self.x + 12,
        topY,
        (self.width - 24) * viewportScale,
        "center",
        0,
        headerScale,
        headerScale
    )

    local circleImage = getIconImage(self.iconCirclePath)
    local iconImage = getIconImage(self.iconPath)
    local iconAreaX = self.x + (self.width - iconSize) * 0.5
    local iconAreaY = iconY

    drawIconInSquare(circleImage, iconAreaX, iconAreaY, iconSize, iconSize * 0.9, self.iconCircleColor, alpha)
    drawIconInSquare(iconImage, iconAreaX, iconAreaY, iconSize, iconSize, self.iconColor, alpha)

    love.graphics.setColor(applyAlpha(self.textColor, alpha))
    love.graphics.printf(
        tostring(self.bottomText or ""),
        self.x + 12,
        bottomY,
        (self.width - 24) * viewportScale,
        "center",
        0,
        headerScale,
        headerScale
    )

    local border = getBorderImage()
    if border then
        love.graphics.setColor(applyAlpha(self.borderColor, alpha))
        love.graphics.draw(border, self.x, self.y, 0, self.width / border:getWidth(), self.height / border:getHeight())
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

return BoosterPack
