local Theme = {
    colors = {
        bg = { 0.90, 0.90, 0.91, 1 },

        text = { 0.10, 0.12, 0.16, 1 },
        textDim = { 0.48, 0.52, 0.58, 1 },
        textDanger = { 0.96, 0.46, 0.16, 1 },
        textShadow = { 0, 0, 0, 0.28 },

        success = { 0.22, 0.78, 0.47, 1 },

        surface = { 0.93, 0.94, 0.95, 1 },
        surface2 = { 0.87, 0.89, 0.92, 1 },
        surface3 = { 0.79, 0.83, 0.89, 1 },
        surfaceMuted = { 0.75, 0.78, 0.82, 1 },
        surfaceShadow = { 0, 0, 0, 0.4 },

        chipA = { 0.55, 0.88, 0.91, 1 },
        chipB = { 0.62, 0.82, 0.98, 1 },
        goalSurface = { 0.72, 0.66, 0.92, 1 },

        meterRevenueFill = { 0.96, 0.80, 0.22, 1 },
        meterRevenueBg = { 0.95, 0.88, 0.64, 1 },
        meterBurnoutFill = { 0.96, 0.50, 0.50, 1 },
        meterBurnoutBg = { 0.94, 0.77, 0.77, 1 },
        meterDebtFill = { 0.99, 0.54, 0.05, 1 },
        meterDebtBg = { 0.95, 0.82, 0.64, 1 },
        meterDaysFill = { 0.61, 0.84, 0.67, 1 },

        cardBorder = { 0.20, 0.20, 0.22, 1 },
        cardSelected = { 0.15, 0.45, 0.85, 1 },
        cardTarget = { 0.17, 0.76, 0.44, 1 },
        highlight = { 0.18, 0.78, 0.45, 1 },

        buttonPlay = { 0.61, 0.88, 0.68, 1 },
        buttonEnd = { 0.55, 0.86, 0.95, 1 },
        buttonDisabled = { 0.70, 0.72, 0.75, 0.7 },
    },

    screen = {
        width = 1920,
        height = 1080,
    },

    nineSlice = {
        cornerSize = 24,
        borderScale = 0.5,
        image = nil,
    },

    fonts = {
        tiny = nil,
        small = nil,
        normal = nil,
        large = nil,
        huge = nil,
        display = nil,
        giant = nil,
    },
}

function Theme:load()
    self.nineSlice.image = love.graphics.newImage("assets/ui/pixelSurface.png")
    self.nineSlice.image:setFilter("nearest", "nearest")

    local fontPath = "assets/fonts/m6x11plus.ttf"
    -- Keep Scope Creep legibility while preserving the Space Eels style family.
    self.fonts.tiny = love.graphics.newFont(fontPath, 20)
    self.fonts.small = love.graphics.newFont(fontPath, 28)
    self.fonts.normal = love.graphics.newFont(fontPath, 36)
    self.fonts.large = love.graphics.newFont(fontPath, 46)
    self.fonts.display = love.graphics.newFont(fontPath, 62)
    self.fonts.huge = love.graphics.newFont(fontPath, 74)
    self.fonts.giant = love.graphics.newFont(fontPath, 74)

    for _, font in pairs(self.fonts) do
        font:setFilter("nearest", "nearest")
    end
end

function Theme:drawTextWithShadow(text, x, y, font, color, shadowOffset)
    font = font or self.fonts.normal
    color = color or self.colors.text
    shadowOffset = shadowOffset or 1

    love.graphics.setFont(font)

    local shadow = self.colors.textShadow
    local alpha = (color[4] or 1) * (shadow[4] or 0.28)
    love.graphics.setColor(shadow[1], shadow[2], shadow[3], alpha)
    love.graphics.print(text, math.floor(x + shadowOffset), math.floor(y + shadowOffset))

    love.graphics.setColor(color)
    love.graphics.print(text, math.floor(x), math.floor(y))
end

function Theme:drawTextCenteredWithShadow(text, x, y, width, font, color, shadowOffset)
    font = font or self.fonts.normal
    color = color or self.colors.text
    shadowOffset = shadowOffset or 1

    love.graphics.setFont(font)

    local textWidth = font:getWidth(text)
    local tx = x + (width - textWidth) * 0.5

    local shadow = self.colors.textShadow
    local alpha = (color[4] or 1) * (shadow[4] or 0.28)
    love.graphics.setColor(shadow[1], shadow[2], shadow[3], alpha)
    love.graphics.print(text, math.floor(tx + shadowOffset), math.floor(y + shadowOffset))

    love.graphics.setColor(color)
    love.graphics.print(text, math.floor(tx), math.floor(y))
end

function Theme:drawTextRightWithShadow(text, x, y, width, font, color, shadowOffset)
    font = font or self.fonts.normal
    color = color or self.colors.text
    shadowOffset = shadowOffset or 1

    love.graphics.setFont(font)

    local textWidth = font:getWidth(text)
    local tx = x + width - textWidth

    local shadow = self.colors.textShadow
    local alpha = (color[4] or 1) * (shadow[4] or 0.28)
    love.graphics.setColor(shadow[1], shadow[2], shadow[3], alpha)
    love.graphics.print(text, math.floor(tx + shadowOffset), math.floor(y + shadowOffset))

    love.graphics.setColor(color)
    love.graphics.print(text, math.floor(tx), math.floor(y))
end

function Theme:drawTextWrappedWithShadow(text, x, y, width, align, font, color, shadowOffset)
    font = font or self.fonts.normal
    color = color or self.colors.text
    align = align or "left"
    shadowOffset = shadowOffset or 1

    love.graphics.setFont(font)

    local shadow = self.colors.textShadow
    local alpha = (color[4] or 1) * (shadow[4] or 0.28)
    love.graphics.setColor(shadow[1], shadow[2], shadow[3], alpha)
    love.graphics.printf(text, math.floor(x + shadowOffset), math.floor(y + shadowOffset), width, align)

    love.graphics.setColor(color)
    love.graphics.printf(text, math.floor(x), math.floor(y), width, align)
end

return Theme
