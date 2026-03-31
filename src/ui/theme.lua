local Theme = {
    colors = {
        bg = { 0.90, 0.90, 0.91, 1 },
        text = { 0.10, 0.12, 0.16, 1 },
        textDim = { 0.48, 0.52, 0.58, 1 },
        textDanger = { 0.96, 0.46, 0.16, 1 },
        textShadow = { 0, 0, 0, 0.38 },
        success = { 0.22, 0.78, 0.47, 1 },
    },
    fonts = {
        tiny = nil,
        small = nil,
        normal = nil,
        large = nil,
        display = nil,
        huge = nil,
    },
}

function Theme:load()
    local fontPath = "assets/fonts/m6x11plus.ttf"
    self.fonts.tiny = love.graphics.newFont(fontPath, 20)
    self.fonts.small = love.graphics.newFont(fontPath, 28)
    self.fonts.normal = love.graphics.newFont(fontPath, 36)
    self.fonts.large = love.graphics.newFont(fontPath, 46)
    self.fonts.display = love.graphics.newFont(fontPath, 62)
    self.fonts.huge = love.graphics.newFont(fontPath, 74)

    for _, font in pairs(self.fonts) do
        font:setFilter("nearest", "nearest")
    end
end

function Theme:drawTextWithShadow(text, x, y, font, color, shadowOffset)
    font = font or self.fonts.normal
    color = color or self.colors.text
    shadowOffset = shadowOffset or 2

    love.graphics.setFont(font)

    local shadow = self.colors.textShadow
    local alpha = (color[4] or 1) * (shadow[4] or 0.38)
    love.graphics.setColor(shadow[1], shadow[2], shadow[3], alpha)
    love.graphics.print(text, math.floor(x + shadowOffset), math.floor(y + shadowOffset))

    love.graphics.setColor(color)
    love.graphics.print(text, math.floor(x), math.floor(y))
end

function Theme:drawTextCenteredWithShadow(text, x, y, width, font, color, shadowOffset)
    font = font or self.fonts.normal
    color = color or self.colors.text
    shadowOffset = shadowOffset or 2

    love.graphics.setFont(font)
    local textWidth = font:getWidth(text)
    local tx = x + (width - textWidth) * 0.5

    local shadow = self.colors.textShadow
    local alpha = (color[4] or 1) * (shadow[4] or 0.38)
    love.graphics.setColor(shadow[1], shadow[2], shadow[3], alpha)
    love.graphics.print(text, math.floor(tx + shadowOffset), math.floor(y + shadowOffset))

    love.graphics.setColor(color)
    love.graphics.print(text, math.floor(tx), math.floor(y))
end

function Theme:drawTextRightWithShadow(text, x, y, width, font, color, shadowOffset)
    font = font or self.fonts.normal
    color = color or self.colors.text
    shadowOffset = shadowOffset or 2

    love.graphics.setFont(font)
    local textWidth = font:getWidth(text)
    local tx = x + width - textWidth

    local shadow = self.colors.textShadow
    local alpha = (color[4] or 1) * (shadow[4] or 0.38)
    love.graphics.setColor(shadow[1], shadow[2], shadow[3], alpha)
    love.graphics.print(text, math.floor(tx + shadowOffset), math.floor(y + shadowOffset))

    love.graphics.setColor(color)
    love.graphics.print(text, math.floor(tx), math.floor(y))
end

function Theme:drawTextWrappedWithShadow(text, x, y, width, align, font, color, shadowOffset)
    font = font or self.fonts.normal
    color = color or self.colors.text
    align = align or "left"
    shadowOffset = shadowOffset or 2

    love.graphics.setFont(font)

    local shadow = self.colors.textShadow
    local alpha = (color[4] or 1) * (shadow[4] or 0.38)
    love.graphics.setColor(shadow[1], shadow[2], shadow[3], alpha)
    love.graphics.printf(text, math.floor(x + shadowOffset), math.floor(y + shadowOffset), width, align)

    love.graphics.setColor(color)
    love.graphics.printf(text, math.floor(x), math.floor(y), width, align)
end

return Theme
