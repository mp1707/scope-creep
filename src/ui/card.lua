local Scaling = require("src.core.scaling")
local Theme = require("src.ui.theme")
local CardBackground = require("src.ui.card_background")
local UiPanel = require("src.ui.ui_panel")
local UiShadow = require("src.ui.ui_shadow")

local Card = {}
Card.__index = Card
Card.HEADER_HEIGHT = 48

local CARD_PADDING = 11
local FOOTER_HEIGHT = 26
local FEATURE_PIP_SIZE = 15
local FEATURE_PIP_GAP = -3

local CARD_BODY_ASPECT_WIDTH = 300
local CARD_BODY_ASPECT_HEIGHT = 350

local MONEY_ICON_PATH = "assets/handdrawn/cardIcons/money.png"
local MONEY_SMALL_ICON_PATH = "assets/handdrawn/smallIcons/moneySmall.png"
local FEATURE_ICON_PATH = "assets/handdrawn/cardIcons/star.png"
local DOT_SMALL_ICON_PATH = "assets/handdrawn/smallIcons/dotSmall.png"
local DEFAULT_ICON_PATH = FEATURE_ICON_PATH
local CIRCLE_BG_ICON_PATH = "assets/handdrawn/ui/circleBig.png"

local cardIconImageCache = {}
local cardIconLoadAttempted = {}

local DEFAULT_STYLES = Theme.cardStyles

local function damp(current, target, speed, dt)
    local t = 1 - math.exp(-speed * dt)
    return current + (target - current) * t
end

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function applyAlpha(color, alphaMultiplier)
    return color[1], color[2], color[3], (color[4] or 1) * alphaMultiplier
end

local function getCardIconImage(iconPath)
    if not iconPath or iconPath == "" then
        return nil
    end

    if cardIconImageCache[iconPath] or cardIconLoadAttempted[iconPath] then
        return cardIconImageCache[iconPath]
    end

    cardIconLoadAttempted[iconPath] = true

    local ok, loadedImage = pcall(love.graphics.newImage, iconPath)
    if not ok then
        return nil
    end

    loadedImage:setFilter("linear", "linear")
    cardIconImageCache[iconPath] = loadedImage
    return loadedImage
end

local function getFeatureIconImage()
    return getCardIconImage(FEATURE_ICON_PATH)
end

local function fitTextToWidth(text, maxWidth, font, scale)
    local value = tostring(text or "")
    if value == "" or not font then
        return value
    end

    local textScale = scale or 1
    if maxWidth <= 0 then
        return ""
    end

    if (font:getWidth(value) * textScale) <= maxWidth then
        return value
    end

    local ellipsis = "..."
    local result = value
    while #result > 0 and (font:getWidth(result .. ellipsis) * textScale) > maxWidth do
        result = result:sub(1, -2)
    end

    if result == "" then
        return ellipsis
    end

    return result .. ellipsis
end

local function drawMoneyAmountWithIcon(amount, x, y, width, options)
    options = options or {}

    local numericAmount = tonumber(amount) or 0
    local amountLabel = string.format("%d x", math.max(0, math.floor(numericAmount)))

    local fontScale = options.fontScale or 1
    if fontScale <= 0 then
        fontScale = 1
    end

    local align = options.align or "left"
    local iconVerticalAlign = options.iconVerticalAlign or "center"
    local iconHeightFactor = options.iconHeightFactor or 0.9

    local font = love.graphics.getFont()
    local textWidth = font:getWidth(amountLabel) * fontScale
    local textHeight = font:getHeight() * fontScale

    local moneyIcon = getCardIconImage(MONEY_SMALL_ICON_PATH)
    local iconWidth = 0
    local iconHeight = 0
    local gap = 0

    if moneyIcon then
        local rawWidth = moneyIcon:getWidth()
        local rawHeight = moneyIcon:getHeight()
        iconHeight = textHeight * iconHeightFactor
        local iconScale = iconHeight / rawHeight
        iconWidth = rawWidth * iconScale
        gap = math.max(4, math.floor(textHeight * 0.3))
    end

    local contentWidth = textWidth + gap + iconWidth
    local availableWidth = width or contentWidth
    local drawX = x

    if align == "center" then
        drawX = x + (availableWidth - contentWidth) * 0.5
    elseif align == "right" then
        drawX = x + (availableWidth - contentWidth)
    end

    local textR, textG, textB, textA = love.graphics.getColor()
    love.graphics.print(amountLabel, drawX, y, 0, fontScale, fontScale)

    if moneyIcon then
        local rawHeight = moneyIcon:getHeight()
        local drawScale = iconHeight / rawHeight
        local iconX = drawX + textWidth + gap
        local iconY = y + (textHeight - iconHeight) * 0.5
        if iconVerticalAlign == "bottom" then
            iconY = y + textHeight - iconHeight
        end
        local tint = Theme.colors.icon
        love.graphics.setColor(tint[1], tint[2], tint[3], textA or 1)
        love.graphics.draw(moneyIcon, iconX, iconY, 0, drawScale, drawScale)
        love.graphics.setColor(textR, textG, textB, textA)
    end
end

function Card.drawMoneyAmount(amount, x, y, width, options)
    drawMoneyAmountWithIcon(amount, x, y, width, options)
end

local function getDefaultHeroIconPath(cardType)
    if cardType == "feature" then
        return FEATURE_ICON_PATH
    end
    if cardType == "money" or cardType == "resource" then
        return MONEY_ICON_PATH
    end
    return DEFAULT_ICON_PATH
end

local function getBodyIconTargetSize(cardType, cardHeight)
    local iconTheme = (Theme.card and Theme.card.icon) or {}
    local themeValue = iconTheme.bodySize

    if cardType == "person" or cardType == "developer" then
        themeValue = iconTheme.personSize or themeValue
    elseif cardType == "feature" then
        themeValue = iconTheme.featureSize or themeValue
    elseif cardType == "money" or cardType == "resource" then
        themeValue = iconTheme.resourceSize or themeValue
    elseif cardType == "support" or cardType == "tooling" then
        themeValue = iconTheme.supportSize or themeValue
    elseif cardType == "problem" or cardType == "bug" then
        themeValue = iconTheme.problemSize or themeValue
    else
        themeValue = iconTheme.eventSize or themeValue
    end

    local size = tonumber(themeValue)
    if not size then
        if cardType == "person" or cardType == "developer" then
            size = math.floor(cardHeight * 0.6 + 0.5)
        elseif cardType == "money" or cardType == "resource" then
            size = math.floor(cardHeight * 0.44 + 0.5)
        elseif cardType == "feature" then
            size = math.floor(cardHeight * 0.36 + 0.5)
        else
            size = math.floor(cardHeight * 0.38 + 0.5)
        end
    end

    return math.max(32, size)
end

local function drawIconInArea(image, areaX, areaY, areaWidth, areaHeight, targetSize, options)
    if not image then
        return
    end
    if areaWidth <= 0 or areaHeight <= 0 then
        return
    end

    options = options or {}
    local flipHorizontal = options.flipHorizontal == true
    local verticalBias = tonumber(options.verticalBias) or 0
    local alpha = options.alpha or 1

    local iconWidth = image:getWidth()
    local iconHeight = image:getHeight()
    if iconWidth <= 0 or iconHeight <= 0 then
        return
    end

    local fittedTargetSize = math.max(1, math.min(targetSize, areaWidth, areaHeight))
    local iconScale = math.min(fittedTargetSize / iconWidth, fittedTargetSize / iconHeight)
    local drawWidth = iconWidth * iconScale
    local drawHeight = iconHeight * iconScale
    local freeY = areaHeight - drawHeight
    local drawX = areaX + (areaWidth - drawWidth) * 0.5
    local drawY = areaY + (freeY * 0.5) + (freeY * verticalBias)

    local tint = options.tint or Theme.colors.icon
    love.graphics.setColor(tint[1], tint[2], tint[3], alpha)
    if flipHorizontal then
        love.graphics.draw(image, drawX + drawWidth, drawY, 0, -iconScale, iconScale)
    else
        love.graphics.draw(image, drawX, drawY, 0, iconScale, iconScale)
    end
end

local function drawOpportunityBadge(card, alpha)
    if card.cardType ~= "opportunity" then
        return
    end

    local remaining = math.max(0, math.floor(card.insightsRemaining or 0))
    local badgeSize = 28
    local badgeX = card.x + card.width - (badgeSize * 0.35)
    local badgeY = card.y - (badgeSize * 0.45)

    local viewportScale = Scaling.getScale()
    if viewportScale <= 0 then
        viewportScale = 1
    end

    UiPanel.drawPanel(badgeX, badgeY, badgeSize, badgeSize, {
        bodyColor = Theme.palette.featureBody,
        borderColor = Theme.colors.borderStrong,
        alpha = alpha,
    })

    local label = tostring(remaining)
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(label) / viewportScale
    local textHeight = font:getHeight() / viewportScale
    local textColor = Theme.colors.textPrimary
    love.graphics.setColor(applyAlpha(textColor, alpha))
    love.graphics.print(
        label,
        badgeX + (badgeSize - textWidth) * 0.5,
        badgeY + (badgeSize - textHeight) * 0.5,
        0,
        1 / viewportScale,
        1 / viewportScale
    )
end

local function getCardHeroImage(card)
    if card.iconPath and card.iconPath ~= "" then
        return getCardIconImage(card.iconPath)
    end
    return getCardIconImage(getDefaultHeroIconPath(card.cardType))
end

function Card.new(config)
    local self = setmetatable({}, Card)

    self.id = config.id
    self.cardType = config.cardType or "default"
    self.role = config.role
    self.subType = config.subType
    self.title = config.title or config.name or "Card"
    self.effect = config.effect
    self.iconPath = config.iconPath

    self.maxCapacity = config.maxCapacity
    self.capacity = config.capacity

    self.costTotal = config.costTotal
    self.costRemaining = config.costRemaining
    self.value = config.value
    self.moneyAmount = config.moneyAmount or config.coinAmount or 1
    self.insightsRemaining = config.insightsRemaining
    if self.cardType == "opportunity" and self.insightsRemaining == nil then
        self.insightsRemaining = 3
    end

    -- Focus system (worker cards)
    self.maxFocus = config.maxFocus
    self.focus = config.focus

    -- Recipe tracking
    self.recipeActive = config.recipeActive or false
    self.recipeElapsed = config.recipeElapsed or 0
    self.recipeDuration = config.recipeDuration
    self.recipePartnerId = config.recipePartnerId

    -- Deadline badge
    self.hasDeadline = config.hasDeadline or false

    -- Burnout link
    self.ownerWorkerId = config.ownerWorkerId

    self.stackParentId = config.stackParentId

    self.width = config.width or 160
    local defaultBodyHeight = math.floor((self.width * CARD_BODY_ASPECT_HEIGHT / CARD_BODY_ASPECT_WIDTH) + 0.5)
    self.height = config.height or (Card.HEADER_HEIGHT + defaultBodyHeight)

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

    self.dragFollowSpeed = 34
    self.settleSpeed = 22
    self.scaleSpeed = 20
    self.shadowSpeed = 18

    self.style = config.style or {}
    self.shipState = nil
    self.rotation = 0
    self.renderAlpha = 1
    self:setShadowRole("cardRest", true)

    return self
end

function Card:getStyleColor(key)
    if self.style[key] then
        return self.style[key]
    end

    local typedDefaults = DEFAULT_STYLES[self.cardType] or DEFAULT_STYLES.default
    if typedDefaults[key] then
        return typedDefaults[key]
    end

    return DEFAULT_STYLES.default[key]
end

function Card:containsPoint(px, py)
    local centerX = self.x + self.width * 0.5
    local centerY = self.y + self.height * 0.5

    local halfW = self.width * self.scale * 0.5
    local halfH = self.height * self.scale * 0.5

    return px >= centerX - halfW and px <= centerX + halfW
        and py >= centerY - halfH and py <= centerY + halfH
end

function Card:containsHeaderPoint(px, py)
    if self.cardType == "opportunity" then
        return false
    end

    local centerX = self.x + self.width * 0.5
    local centerY = self.y + self.height * 0.5
    local halfW = self.width * self.scale * 0.5
    local halfH = self.height * self.scale * 0.5

    local left = centerX - halfW
    local right = centerX + halfW
    local top = centerY - halfH
    local headerBottom = top + Card.HEADER_HEIGHT * self.scale

    return px >= left and px <= right
        and py >= top and py <= headerBottom
end

function Card:beginDrag(px, py, force)
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

function Card:endDrag()
    self.dragging = false
    self.targetScale = 1
    self:setShadowRole("cardRest")
end

function Card:isDragging()
    return self.dragging
end

function Card:isFeatureComplete()
    return self.cardType == "feature" and (self.costRemaining or 0) <= 0
end

function Card:setShadowRole(role, immediate)
    UiShadow.applyRole(self, role, { immediate = immediate == true })
end

function Card:update(dt, pointerX, pointerY)
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

function Card:getSnapshot()
    return {
        id = self.id,
        cardType = self.cardType,
        role = self.role,
        subType = self.subType,
        title = self.title,
        effect = self.effect,
        iconPath = self.iconPath,
        maxCapacity = self.maxCapacity,
        capacity = self.capacity,
        costTotal = self.costTotal,
        costRemaining = self.costRemaining,
        value = self.value,
        moneyAmount = self.moneyAmount,
        insightsRemaining = self.insightsRemaining,
        -- Focus
        maxFocus = self.maxFocus,
        focus = self.focus,
        -- Recipe
        recipeActive = self.recipeActive,
        recipeElapsed = self.recipeElapsed,
        recipeDuration = self.recipeDuration,
        recipePartnerId = self.recipePartnerId,
        -- Misc
        hasDeadline = self.hasDeadline,
        ownerWorkerId = self.ownerWorkerId,
        stackParentId = self.stackParentId,
        x = self.x,
        y = self.y,
        targetX = self.targetX,
        targetY = self.targetY,
    }
end

function Card:drawBodyContent(alpha)
    local headerHeight = Card.HEADER_HEIGHT
    local bodyTop = self.y + headerHeight
    local bodyBottom = self.y + self.height
    local footerTop = bodyBottom - FOOTER_HEIGHT

    local iconAreaX = self.x + CARD_PADDING
    local iconAreaY = bodyTop + CARD_PADDING
    local iconAreaWidth = self.width - CARD_PADDING * 2
    local iconAreaHeight = math.max(1, footerTop - iconAreaY - CARD_PADDING)

    local cardType = self.cardType
    if cardType == "feature" and (self.costTotal or 0) > 0 and not self:isFeatureComplete() then
        iconAreaY = iconAreaY + FEATURE_PIP_SIZE + FEATURE_PIP_GAP + 4
        iconAreaHeight = math.max(1, footerTop - iconAreaY - CARD_PADDING)
    elseif (cardType == "person" or cardType == "developer")
        and ((tonumber(self.maxFocus) or 0) > 0 or (tonumber(self.maxCapacity) or 0) > 0) then
        iconAreaY = iconAreaY + FEATURE_PIP_SIZE + FEATURE_PIP_GAP + 4
        iconAreaHeight = math.max(1, footerTop - iconAreaY - CARD_PADDING)
    end

    if cardType == "opportunity" then
        local textColor = self:getStyleColor("textColor")
        local viewportScale = Scaling.getScale()
        if viewportScale <= 0 then
            viewportScale = 1
        end

        local font = love.graphics.getFont()
        local lineHeight = font:getHeight() / viewportScale
        local verticalGap = math.max(4, lineHeight * 0.22)
        local iconSize = getBodyIconTargetSize("feature", self.height)
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
            drawIconInArea(
                featureIcon,
                self.x + (self.width - iconSize) * 0.5,
                iconY,
                iconSize,
                iconSize,
                iconSize,
                { alpha = alpha }
            )
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
        return
    end

    local icon = getCardHeroImage(self)
    if not icon then
        -- Letter fallback: draw first letter of title centered in icon area
        local headerColor = self:getStyleColor("headerColor")
        local circleImage = getCardIconImage(CIRCLE_BG_ICON_PATH)
        local fallbackSize = math.min(getBodyIconTargetSize(cardType, self.height), iconAreaWidth, iconAreaHeight)
        if circleImage then
            local circleTint = { headerColor[1], headerColor[2], headerColor[3], 1 }
            drawIconInArea(circleImage, iconAreaX, iconAreaY, iconAreaWidth, iconAreaHeight,
                fallbackSize * 0.9, { verticalBias = -0.06, alpha = alpha, tint = circleTint })
        end
        local viewportScale = Scaling.getScale()
        if viewportScale <= 0 then viewportScale = 1 end
        local firstLetter = (self.title or "?"):sub(1, 1):upper()
        local letterFont = Theme.fonts.cardHeader or love.graphics.getFont()
        local prevFont = love.graphics.getFont()
        love.graphics.setFont(letterFont)
        local letterScale = (fallbackSize * 0.55) / math.max(1, letterFont:getHeight() / viewportScale)
        local letterW = letterFont:getWidth(firstLetter) * (letterScale / viewportScale)
        local letterH = letterFont:getHeight() * (letterScale / viewportScale)
        local lx = iconAreaX + (iconAreaWidth - letterW) * 0.5
        local ly = iconAreaY + (iconAreaHeight - letterH) * 0.5 - iconAreaHeight * 0.06
        love.graphics.setColor(applyAlpha(self:getStyleColor("textColor"), alpha))
        love.graphics.print(firstLetter, lx, ly, 0, letterScale / viewportScale, letterScale / viewportScale)
        love.graphics.setFont(prevFont)
        return
    end

    if cardType == "person" or cardType == "developer" then
        local targetSize = math.min(getBodyIconTargetSize(cardType, self.height), iconAreaWidth, iconAreaHeight)

        local circleImage = getCardIconImage(CIRCLE_BG_ICON_PATH)
        if circleImage then
            local headerColor = self:getStyleColor("headerColor")
            local circleTint = { headerColor[1], headerColor[2], headerColor[3], 1 }
            drawIconInArea(
                circleImage,
                iconAreaX,
                iconAreaY,
                iconAreaWidth,
                iconAreaHeight,
                targetSize * 0.9,
                {
                    verticalBias = -0.06,
                    alpha = alpha,
                    tint = circleTint
                }
            )
        end

        drawIconInArea(
            icon,
            iconAreaX,
            iconAreaY,
            iconAreaWidth,
            iconAreaHeight,
            targetSize,
            {
                verticalBias = -0.06,
                alpha = alpha,
            }
        )
        return
    end

    local iconTarget = math.min(getBodyIconTargetSize(cardType, self.height), iconAreaWidth, iconAreaHeight)
    local verticalBias = -0.08
    if cardType == "money" or cardType == "resource" then
        verticalBias = -0.05
    elseif cardType == "feature" then
        verticalBias = -0.1
    end

    local circleImage = getCardIconImage(CIRCLE_BG_ICON_PATH)
    if circleImage then
        local headerColor = self:getStyleColor("headerColor")
        local circleTint = { headerColor[1], headerColor[2], headerColor[3], 1 }
        drawIconInArea(
            circleImage,
            iconAreaX,
            iconAreaY,
            iconAreaWidth,
            iconAreaHeight,
            iconTarget * 0.9,
            {
                verticalBias = verticalBias,
                alpha = alpha,
                tint = circleTint
            }
        )
    end

    drawIconInArea(
        icon,
        iconAreaX,
        iconAreaY,
        iconAreaWidth,
        iconAreaHeight,
        iconTarget,
        {
            alpha = alpha,
            verticalBias = verticalBias,
        }
    )
end

function Card:drawIndicators(alpha)
    local total = 0
    local filled = 0

    if self.cardType == "feature" then
        if self:isFeatureComplete() then
            return
        end
        total = tonumber(self.costTotal) or 0
        filled = math.max(0, math.floor(tonumber(self.costRemaining) or 0))
    elseif self.cardType == "person" or self.cardType == "developer" then
        -- Use focus pips if available, fall back to capacity
        if self.maxFocus ~= nil then
            total = tonumber(self.maxFocus) or 0
            filled = math.max(0, math.floor(tonumber(self.focus) or 0))
        else
            total = tonumber(self.maxCapacity) or 0
            filled = math.max(0, math.floor(tonumber(self.capacity) or 0))
        end
    else
        return
    end

    if total <= 0 then
        return
    end

    local drawTotal = math.min(math.max(0, math.floor(total)), 8)
    if drawTotal <= 0 then
        return
    end

    local dotIcon = getCardIconImage(DOT_SMALL_ICON_PATH)
    local startX = self.x + CARD_PADDING + (FEATURE_PIP_SIZE * 0.5)
    local centerY = self.y + Card.HEADER_HEIGHT + CARD_PADDING + (FEATURE_PIP_SIZE * 0.5) - 5

    for i = 1, drawTotal do
        local centerX = startX + (i - 1) * (FEATURE_PIP_SIZE + FEATURE_PIP_GAP)
        local isFilled = i <= filled
        local dotAlpha = isFilled and alpha or (alpha * 0.24)
        local tint = Theme.colors.icon

        if dotIcon then
            local dotScale = FEATURE_PIP_SIZE / math.max(dotIcon:getWidth(), dotIcon:getHeight())
            local drawWidth = dotIcon:getWidth() * dotScale
            local drawHeight = dotIcon:getHeight() * dotScale
            love.graphics.setColor(tint[1], tint[2], tint[3], dotAlpha)
            love.graphics.draw(
                dotIcon,
                centerX - drawWidth * 0.5,
                centerY - drawHeight * 0.5,
                0,
                dotScale,
                dotScale
            )
        else
            love.graphics.setColor(tint[1], tint[2], tint[3], dotAlpha)
            love.graphics.points(centerX, centerY)
        end
    end
end

function Card:drawFooterInfo(viewportScale, bodyFont, valueFont, alpha)
    local textColor = self:getStyleColor("textColor")
    if valueFont then
        love.graphics.setFont(valueFont)
    elseif bodyFont then
        love.graphics.setFont(bodyFont)
    end

    local font = love.graphics.getFont()
    local fontScale = (1 / viewportScale) * 0.85
    local lineHeight = font:getHeight() * fontScale
    local footerY = self.y + self.height - CARD_PADDING - lineHeight
    local rightZoneWidth = math.floor(self.width * 0.44)
    local rightX = self.x + self.width - CARD_PADDING - rightZoneWidth

    -- Effect text is shown only in hover tooltips (not on the card itself).
    -- Footer only shows numeric values where relevant.
    love.graphics.setColor(applyAlpha(textColor, alpha))

    -- Money and resource cards: show amount
    if self.cardType == "money" or self.cardType == "resource" then
        drawMoneyAmountWithIcon(
            self.moneyAmount or self.value or 1,
            rightX, footerY, rightZoneWidth,
            { align = "right", fontScale = fontScale, iconHeightFactor = 0.9, iconVerticalAlign = "bottom" }
        )
        return
    end

    -- Shipped work: show payout amount
    if self.cardType == "shipped" then
        drawMoneyAmountWithIcon(
            self.moneyAmount or 2,
            rightX, footerY, rightZoneWidth,
            { align = "right", fontScale = fontScale, iconHeightFactor = 0.9, iconVerticalAlign = "bottom" }
        )
        return
    end

    -- Legacy feature cards: show value
    if self.cardType == "feature" then
        drawMoneyAmountWithIcon(
            self.value or 0,
            rightX, footerY, rightZoneWidth,
            { align = "right", fontScale = fontScale, iconHeightFactor = 0.9, iconVerticalAlign = "bottom" }
        )
        return
    end

    -- All other card types: nothing in the footer (effect shown in tooltip)
end

function Card:drawDeadlineBadge(alpha, viewportScale)
    if not self.hasDeadline then
        return
    end

    local badgeH = 14
    local badgeX = self.x + 2
    local badgeY = self.y + Card.HEADER_HEIGHT + 2
    local badgeW = self.width - 4
    local orange = Theme.palette.deadlineOrange or { 0.91, 0.48, 0.19, 1 }

    love.graphics.setColor(orange[1], orange[2], orange[3], (orange[4] or 1) * alpha)
    love.graphics.rectangle("fill", badgeX, badgeY, badgeW, badgeH, 2, 2)

    local font = Theme.fonts.cardBody or love.graphics.getFont()
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(font)
    local scale = (1 / (viewportScale or 1)) * 0.72
    local label = "DEADLINE"
    local labelW = font:getWidth(label) * scale
    local labelH = font:getHeight() * scale
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.print(
        label,
        badgeX + (badgeW - labelW) * 0.5,
        badgeY + (badgeH - labelH) * 0.5,
        0, scale, scale
    )
    love.graphics.setFont(prevFont)
end

function Card:draw(headerFont, options)
    options = options or {}

    local alpha = options.alpha or 1
    local extraScale = options.extraScale or 1
    local skipShadow = options.skipShadow == true
    local bodyFont = options.bodyFont
    local valueFont = options.valueFont

    local centerX = self.x + self.width * 0.5
    local centerY = self.y + self.height * 0.5
    local drawScale = self.scale * extraScale
    local drawRotation = self.rotation or 0
    local isOpportunity = self.cardType == "opportunity"

    love.graphics.push()
    love.graphics.translate(centerX, centerY)
    love.graphics.rotate(drawRotation)
    love.graphics.scale(drawScale, drawScale)
    love.graphics.translate(-centerX, -centerY)

    local textColor = self:getStyleColor("textColor")
    local headerHeight = Card.HEADER_HEIGHT

    local viewportScale = Scaling.getScale()
    if viewportScale <= 0 then
        viewportScale = 1
    end

    if headerFont then
        love.graphics.setFont(headerFont)
    end

    if not skipShadow then
        UiPanel.drawShadow(
            self.x,
            self.y,
            self.width,
            self.height,
            UiShadow.capture(self, "cardRest", { alphaMultiplier = alpha })
        )
    end

    CardBackground.draw(self.x, self.y, self.width, self.height, alpha, {
        bodyColor = self:getStyleColor("bodyColor"),
        headerColor = isOpportunity and nil or self:getStyleColor("headerColor"),
        headerHeight = isOpportunity and 0 or headerHeight,
        borderColor = self:getStyleColor("borderColor"),
    })

    if not isOpportunity then
        local headerFontRef = love.graphics.getFont()
        local headerScale = 1 / viewportScale
        local headerPaddingX = CARD_PADDING + 5
        local titleY = self.y + (headerHeight - (headerFontRef:getHeight() * headerScale)) * 0.2 + (10 * headerScale)
        local titleMaxWidth = self.width - headerPaddingX * 2
        local titleText = fitTextToWidth(self.title, titleMaxWidth, headerFontRef, headerScale)

        love.graphics.setColor(applyAlpha(textColor, alpha))
        love.graphics.print(titleText, self.x + headerPaddingX, titleY, 0, headerScale, headerScale)
    end

    self:drawIndicators(alpha)
    self:drawBodyContent(alpha)
    drawOpportunityBadge(self, alpha)
    self:drawDeadlineBadge(alpha, viewportScale)
    self:drawFooterInfo(viewportScale, bodyFont, valueFont, alpha)

    love.graphics.pop()
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return Card
