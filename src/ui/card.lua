local Scaling = require("src.core.scaling")

local Card = {}
Card.__index = Card
Card.HEADER_HEIGHT = 34

local INDICATOR_SIZE = 16
local INDICATOR_GAP = 5
local MONEY_ICON_PATH = "assets/icons/Green Cash 1st Outline 256px.png"
local OPPORTUNITY_ICON_PATH = "assets/icons/Golden Star 1st Outline 256px.png"

local moneyIconImage = nil
local moneyIconLoadAttempted = false
local opportunityIconImage = nil
local opportunityIconLoadAttempted = false
local cardIconImageCache = {}
local cardIconLoadAttempted = {}

local DEFAULT_STYLES = {
    person = {
        bodyColor = { 1, 1, 1, 1 },
        headerColor = { 0.7, 0.86, 1, 1 },
        borderColor = { 0, 0, 0, 1 },
        textColor = { 0, 0, 0, 1 },
        indicatorFill = { 0.53, 0.79, 0.98, 1 },
        indicatorEmpty = { 0.79, 0.82, 0.86, 1 },
    },
    feature = {
        bodyColor = { 1, 1, 1, 1 },
        headerColor = { 0.93, 0.82, 0.33, 1 },
        borderColor = { 0, 0, 0, 1 },
        textColor = { 0, 0, 0, 1 },
        indicatorFill = { 0.93, 0.82, 0.33, 1 },
        indicatorEmpty = { 0.86, 0.84, 0.71, 1 },
    },
    money = {
        bodyColor = { 0.88, 0.95, 0.87, 1 },
        headerColor = { 0.56, 0.84, 0.55, 1 },
        borderColor = { 0, 0, 0, 1 },
        textColor = { 0, 0, 0, 1 },
        indicatorFill = { 0.82, 0.86, 0.82, 1 },
        indicatorEmpty = { 0.82, 0.86, 0.82, 1 },
    },
    opportunity = {
        bodyColor = { 0.98, 0.94, 0.84, 1 },
        headerColor = { 0.96, 0.89, 0.42, 1 },
        borderColor = { 0, 0, 0, 1 },
        textColor = { 0, 0, 0, 1 },
        indicatorFill = { 0.82, 0.86, 0.82, 1 },
        indicatorEmpty = { 0.82, 0.86, 0.82, 1 },
    },
    default = {
        bodyColor = { 1, 1, 1, 1 },
        headerColor = { 1, 1, 1, 1 },
        borderColor = { 0, 0, 0, 1 },
        textColor = { 0, 0, 0, 1 },
        indicatorFill = { 0.8, 0.8, 0.8, 1 },
        indicatorEmpty = { 0.8, 0.8, 0.8, 1 },
    },
}

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

local function getMoneyIconImage()
    if moneyIconImage or moneyIconLoadAttempted then
        return moneyIconImage
    end

    moneyIconLoadAttempted = true

    local ok, loadedImage = pcall(love.graphics.newImage, MONEY_ICON_PATH)
    if not ok then
        return nil
    end

    loadedImage:setFilter("linear", "linear")
    moneyIconImage = loadedImage
    return moneyIconImage
end

local function getOpportunityIconImage()
    if opportunityIconImage or opportunityIconLoadAttempted then
        return opportunityIconImage
    end

    opportunityIconLoadAttempted = true

    local ok, loadedImage = pcall(love.graphics.newImage, OPPORTUNITY_ICON_PATH)
    if not ok then
        return nil
    end

    loadedImage:setFilter("linear", "linear")
    opportunityIconImage = loadedImage
    return opportunityIconImage
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

local function drawMoneyAmountWithIcon(amount, x, y, width, options)
    options = options or {}

    local numericAmount = tonumber(amount) or 0
    local amountLabel = string.format("%d x", math.max(0, math.floor(numericAmount)))

    local fontScale = options.fontScale or 1
    if fontScale <= 0 then
        fontScale = 1
    end

    local align = options.align or "left"
    local iconHeightFactor = options.iconHeightFactor or 0.9

    local font = love.graphics.getFont()
    local textWidth = font:getWidth(amountLabel) * fontScale
    local textHeight = font:getHeight() * fontScale

    local moneyIcon = getMoneyIconImage()
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
        local rawWidth = moneyIcon:getWidth()
        local rawHeight = moneyIcon:getHeight()
        local drawScale = iconHeight / rawHeight
        local iconX = drawX + textWidth + gap
        local iconY = y + (textHeight - iconHeight) * 0.5
        love.graphics.setColor(1, 1, 1, textA or 1)
        love.graphics.draw(moneyIcon, iconX, iconY, 0, drawScale, drawScale)
        love.graphics.setColor(textR, textG, textB, textA)
    end
end

function Card.drawMoneyAmount(amount, x, y, width, options)
    drawMoneyAmountWithIcon(amount, x, y, width, options)
end

local function drawOpportunityBadge(card, alpha, viewportScale, badgeFont)
    if card.cardType ~= "opportunity" then
        return
    end

    local remaining = math.max(0, math.floor(card.insightsRemaining or 0))
    local centerX = card.x + card.width
    local centerY = card.y
    local radius = 12

    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.circle("fill", centerX, centerY, radius)

    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", centerX, centerY, radius)

    if badgeFont then
        love.graphics.setFont(badgeFont)
    end

    local label = tostring(remaining)
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(label) / viewportScale
    local textHeight = font:getHeight() / viewportScale
    love.graphics.print(label, centerX - textWidth * 0.5, centerY - textHeight * 0.5, 0, 1 / viewportScale, 1 / viewportScale)
end

function Card.new(config)
    local self = setmetatable({}, Card)

    self.id = config.id
    self.cardType = config.cardType or "default"
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

    self.stackParentId = config.stackParentId
    self.workProgress = config.workProgress or 0

    self.width = config.width or 160
    self.height = config.height or math.floor(self.width * (7 / 5))

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
    self.shadowAlpha = 0.12
    self.shadowExpand = 0

    self.targetShadowOffsetX = self.shadowOffsetX
    self.targetShadowOffsetY = self.shadowOffsetY
    self.targetShadowAlpha = self.shadowAlpha
    self.targetShadowExpand = self.shadowExpand

    self.dragFollowSpeed = 34
    self.settleSpeed = 22
    self.scaleSpeed = 20
    self.shadowSpeed = 18

    self.style = config.style or {}
    self.shipState = nil
    self.rotation = 0
    self.renderAlpha = 1

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
    self.targetShadowOffsetX = 8
    self.targetShadowOffsetY = 12
    self.targetShadowAlpha = 0.2
    self.targetShadowExpand = 6
    return true
end

function Card:endDrag()
    self.dragging = false
    self.targetScale = 1
    self.targetShadowOffsetX = 4
    self.targetShadowOffsetY = 4
    self.targetShadowAlpha = 0.12
    self.targetShadowExpand = 0
end

function Card:isDragging()
    return self.dragging
end

function Card:isFeatureComplete()
    return self.cardType == "feature" and (self.costRemaining or 0) <= 0
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
        stackParentId = self.stackParentId,
        workProgress = self.workProgress,
        x = self.x,
        y = self.y,
        targetX = self.targetX,
        targetY = self.targetY,
    }
end

function Card:drawBodyContent(viewportScale, bodyFont, valueFont)
    local textColor = self:getStyleColor("textColor")
    love.graphics.setColor(textColor)

    if self.cardType == "person" then
        if bodyFont then
            love.graphics.setFont(bodyFont)
        end

        local effectText = self.effect
        if not effectText or effectText == "" then
            effectText = "no special talents..."
        end

        local portraitImage = getCardIconImage(self.iconPath)
        if portraitImage then
            local headerHeight = Card.HEADER_HEIGHT
            local bodyTop = self.y + headerHeight
            local bodyHeight = self.height - headerHeight
            local maxIconWidth = self.width - 48
            local maxIconHeight = bodyHeight * 0.4

            local iconWidth = portraitImage:getWidth()
            local iconHeight = portraitImage:getHeight()
            local iconScale = math.min(maxIconWidth / iconWidth, maxIconHeight / iconHeight)

            local drawWidth = iconWidth * iconScale
            local drawHeight = iconHeight * iconScale
            local drawX = self.x + (self.width - drawWidth) * 0.5
            local drawY = bodyTop + 12

            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(portraitImage, drawX, drawY, 0, iconScale, iconScale)

            love.graphics.setColor(textColor)
            love.graphics.printf(
                effectText,
                self.x + 10,
                drawY + drawHeight + 10,
                (self.width - 20) * viewportScale,
                "center",
                0,
                1 / viewportScale,
                1 / viewportScale
            )
        else
            love.graphics.printf(
                effectText,
                self.x + 10,
                self.y + Card.HEADER_HEIGHT + 14,
                (self.width - 20) * viewportScale,
                "left",
                0,
                1 / viewportScale,
                1 / viewportScale
            )
        end
        return
    end

    if self.cardType == "opportunity" then
        local opportunityIcon = getOpportunityIconImage()
        if not opportunityIcon then
            return
        end

        if bodyFont then
            love.graphics.setFont(bodyFont)
        end

        love.graphics.printf(
            "Business\nInsights",
            self.x + 12,
            self.y + 20,
            (self.width - 24) * viewportScale,
            "center",
            0,
            1 / viewportScale,
            1 / viewportScale
        )

        local maxIconWidth = self.width - 52
        local maxIconHeight = self.height * 0.34

        local iconWidth = opportunityIcon:getWidth()
        local iconHeight = opportunityIcon:getHeight()
        local iconScale = math.min(maxIconWidth / iconWidth, maxIconHeight / iconHeight)
        local drawWidth = iconWidth * iconScale
        local drawHeight = iconHeight * iconScale
        local drawX = self.x + (self.width - drawWidth) * 0.5
        local drawY = self.y + self.height * 0.55 - drawHeight * 0.5

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(opportunityIcon, drawX, drawY, 0, iconScale, iconScale)

        love.graphics.setColor(textColor)
        love.graphics.printf(
            "Booster Pack",
            self.x + 12,
            self.y + self.height - 44,
            (self.width - 24) * viewportScale,
            "center",
            0,
            1 / viewportScale,
            1 / viewportScale
        )
        return
    end

    if self.cardType == "feature" then
        if valueFont then
            love.graphics.setFont(valueFont)
        elseif bodyFont then
            love.graphics.setFont(bodyFont)
        end

        local font = love.graphics.getFont()
        local textHeight = font:getHeight() / viewportScale
        local textY = self.y + (self.height - textHeight) * 0.52

        drawMoneyAmountWithIcon(
            self.value or 0,
            self.x + 8,
            textY,
            self.width - 16,
            {
                align = "center",
                fontScale = 1 / viewportScale,
                iconHeightFactor = 0.9,
            }
        )
        return
    end

    if self.cardType == "money" then
        local moneyIcon = getMoneyIconImage()
        if not moneyIcon then
            return
        end

        local headerHeight = Card.HEADER_HEIGHT
        local bodyTop = self.y + headerHeight
        local bodyHeight = self.height - headerHeight
        local maxIconWidth = self.width - 36
        local maxIconHeight = bodyHeight - 28

        local iconWidth = moneyIcon:getWidth()
        local iconHeight = moneyIcon:getHeight()
        local iconScale = math.min(maxIconWidth / iconWidth, maxIconHeight / iconHeight) * 0.6
        local drawWidth = iconWidth * iconScale
        local drawHeight = iconHeight * iconScale

        local drawX = self.x + (self.width - drawWidth) * 0.5
        local drawY = bodyTop + (bodyHeight - drawHeight) * 0.5

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(moneyIcon, drawX, drawY, 0, iconScale, iconScale)
    end
end

function Card:drawIndicators(alpha)
    local total = 0
    local filled = 0

    if self.cardType == "person" then
        total = self.maxCapacity or 0
        filled = self.capacity or 0
    elseif self.cardType == "feature" then
        if self:isFeatureComplete() then
            return
        end
        total = self.costTotal or 0
        filled = self.costRemaining or 0
    else
        return
    end

    if total <= 0 then
        return
    end

    local drawTotal = math.min(total, 8)
    local startX = self.x + 10
    local startY = self.y + self.height - INDICATOR_SIZE - 8

    local fillColor = self:getStyleColor("indicatorFill")
    local emptyColor = self:getStyleColor("indicatorEmpty")

    for i = 1, drawTotal do
        local x = startX + (i - 1) * (INDICATOR_SIZE + INDICATOR_GAP)
        local isFilled = i <= filled

        if isFilled then
            love.graphics.setColor(applyAlpha(fillColor, alpha))
        else
            love.graphics.setColor(applyAlpha(emptyColor, alpha))
        end

        love.graphics.rectangle("fill", x, startY, INDICATOR_SIZE, INDICATOR_SIZE, 4, 4)
    end
end

function Card:draw(headerFont, options)
    options = options or {}

    local alpha = options.alpha or 1
    local extraScale = options.extraScale or 1
    local bodyFont = options.bodyFont
    local valueFont = options.valueFont

    local centerX = self.x + self.width * 0.5
    local centerY = self.y + self.height * 0.5
    local drawScale = self.scale * extraScale
    local drawRotation = self.rotation or 0

    love.graphics.push()
    love.graphics.translate(centerX, centerY)
    love.graphics.rotate(drawRotation)
    love.graphics.scale(drawScale, drawScale)
    love.graphics.translate(-centerX, -centerY)

    if not options.skipShadow then
        love.graphics.setColor(0, 0, 0, self.shadowAlpha * alpha)
        love.graphics.rectangle(
            "fill",
            self.x - self.shadowExpand * 0.5 + self.shadowOffsetX,
            self.y - self.shadowExpand * 0.5 + self.shadowOffsetY,
            self.width + self.shadowExpand,
            self.height + self.shadowExpand
        )
    end

    local bodyColor = self:getStyleColor("bodyColor")
    local headerColor = self:getStyleColor("headerColor")
    local borderColor = self:getStyleColor("borderColor")
    local textColor = self:getStyleColor("textColor")

    love.graphics.setColor(applyAlpha(bodyColor, alpha))
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)

    local showHeader = self.cardType ~= "opportunity"
    local headerHeight = showHeader and Card.HEADER_HEIGHT or 0
    if showHeader then
        love.graphics.setColor(applyAlpha(headerColor, alpha))
        love.graphics.rectangle("fill", self.x, self.y, self.width, headerHeight)
    end

    love.graphics.setColor(applyAlpha(borderColor, alpha))
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)

    if headerFont then
        love.graphics.setFont(headerFont)
    end

    local viewportScale = Scaling.getScale()
    if viewportScale <= 0 then
        viewportScale = 1
    end

    if showHeader then
        local fontHeight = love.graphics.getFont():getHeight()
        local effectiveFontHeight = fontHeight / viewportScale
        local titleY = self.y + (headerHeight - effectiveFontHeight) * 0.5

        love.graphics.setColor(applyAlpha(textColor, alpha))
        love.graphics.print(
            self.title,
            self.x + 10,
            titleY,
            0,
            1 / viewportScale,
            1 / viewportScale
        )

        love.graphics.setLineWidth(2)
        love.graphics.setColor(applyAlpha(borderColor, alpha))
        love.graphics.line(self.x, self.y + headerHeight, self.x + self.width, self.y + headerHeight)
    end

    love.graphics.setColor(applyAlpha(textColor, alpha))
    self:drawBodyContent(viewportScale, bodyFont, valueFont)
    self:drawIndicators(alpha)
    drawOpportunityBadge(self, alpha, viewportScale, bodyFont)

    love.graphics.pop()
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return Card
