local Scaling = require("src.core.scaling")

local Card = {}
Card.__index = Card

local function damp(current, target, speed, dt)
    local t = 1 - math.exp(-speed * dt)
    return current + (target - current) * t
end

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

function Card.new(config)
    local self = setmetatable({}, Card)

    self.name = config.name or "Card"
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

    return self
end

function Card:containsPoint(px, py)
    local centerX = self.x + self.width * 0.5
    local centerY = self.y + self.height * 0.5

    local halfW = self.width * self.scale * 0.5
    local halfH = self.height * self.scale * 0.5

    return px >= centerX - halfW and px <= centerX + halfW
        and py >= centerY - halfH and py <= centerY + halfH
end

function Card:beginDrag(px, py)
    if not self:containsPoint(px, py) then
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
        x = self.x,
        y = self.y,
        targetX = self.targetX,
        targetY = self.targetY,
    }
end

function Card:draw(font)
    local centerX = self.x + self.width * 0.5
    local centerY = self.y + self.height * 0.5

    love.graphics.push()
    love.graphics.translate(centerX, centerY)
    love.graphics.scale(self.scale, self.scale)
    love.graphics.translate(-centerX, -centerY)

    love.graphics.setColor(0, 0, 0, self.shadowAlpha)
    love.graphics.rectangle(
        "fill",
        self.x - self.shadowExpand * 0.5 + self.shadowOffsetX,
        self.y - self.shadowExpand * 0.5 + self.shadowOffsetY,
        self.width + self.shadowExpand,
        self.height + self.shadowExpand
    )

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)

    if font then
        love.graphics.setFont(font)
    end

    local viewportScale = Scaling.getScale()
    if viewportScale <= 0 then
        viewportScale = 1
    end

    local headerHeight = 34
    local fontHeight = love.graphics.getFont():getHeight()
    local effectiveFontHeight = fontHeight / viewportScale
    local titleY = self.y + (headerHeight - effectiveFontHeight) * 0.5
    love.graphics.printf(
        self.name,
        self.x + 12,
        titleY,
        (self.width - 24) * viewportScale,
        "center",
        0,
        1 / viewportScale,
        1 / viewportScale
    )
    love.graphics.setLineWidth(2)
    love.graphics.line(self.x, self.y + headerHeight, self.x + self.width, self.y + headerHeight)

    love.graphics.pop()
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return Card
