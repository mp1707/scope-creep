local Theme = {
    colors = {
        bg = { 0.09, 0.10, 0.16, 1 },
        bgGlowA = { 0.12, 0.21, 0.36, 0.28 },
        bgGlowB = { 0.27, 0.16, 0.33, 0.18 },

        ink = { 0.09, 0.08, 0.14, 1 },
        inkSoft = { 0.16, 0.15, 0.24, 0.45 },

        text = { 0.14, 0.11, 0.09, 1 },
        textDim = { 0.34, 0.29, 0.25, 1 },
        textDanger = { 0.76, 0.26, 0.24, 1 },
        textShadow = { 0, 0, 0, 0 },

        success = { 0.42, 0.74, 0.49, 1 },

        surface = { 0.96, 0.92, 0.84, 1 },
        surface2 = { 0.92, 0.88, 0.80, 1 },
        surface3 = { 0.17, 0.18, 0.27, 0.96 },
        surfaceMuted = { 0.28, 0.30, 0.44, 0.96 },
        surfaceShadow = { 0.02, 0.03, 0.06, 0.44 },

        boardBackdrop = { 0.12, 0.14, 0.23, 0.90 },
        boardLane = { 0.19, 0.20, 0.31, 0.94 },
        boardDivider = { 0.82, 0.82, 0.92, 0.18 },

        laneInProgress = { 0.97, 0.76, 0.34, 1 },
        laneTesting = { 0.74, 0.60, 0.86, 1 },
        laneRollout = { 0.91, 0.44, 0.35, 1 },
        laneDone = { 0.42, 0.74, 0.49, 1 },

        chipA = { 0.97, 0.92, 0.82, 1 },
        chipB = { 0.97, 0.92, 0.82, 1 },
        goalSurface = { 0.96, 0.89, 0.70, 1 },

        meterRevenueFill = { 0.97, 0.63, 0.37, 1 },
        meterRevenueBg = { 0.33, 0.34, 0.46, 1 },
        meterBurnoutFill = { 0.78, 0.41, 0.26, 1 },
        meterBurnoutBg = { 0.33, 0.34, 0.46, 1 },
        meterDebtFill = { 0.86, 0.35, 0.30, 1 },
        meterDebtBg = { 0.33, 0.34, 0.46, 1 },
        meterDaysFill = { 0.44, 0.72, 0.54, 1 },

        cardBorder = { 0.18, 0.13, 0.10, 1 },
        cardSelected = { 0.26, 0.60, 0.93, 1 },
        cardTarget = { 0.22, 0.76, 0.48, 1 },
        highlight = { 0.23, 0.76, 0.48, 1 },

        buttonPlay = { 0.97, 0.79, 0.39, 1 },
        buttonEnd = { 0.89, 0.56, 0.42, 1 },
        buttonDisabled = { 0.45, 0.45, 0.49, 0.84 },
    },

    screen = {
        width = 1920,
        height = 1080,
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

    backdropImage = nil,
}

local function resolveFirstExistingPath(paths, fallback)
    for _, path in ipairs(paths) do
        if love.filesystem.getInfo(path) then
            return path
        end
    end
    return fallback
end

function Theme:load()
    local fallbackFont = "assets/fonts/m6x11plus.ttf"

    local balooRegular = resolveFirstExistingPath({
        "assets/fonts/Baloo2/Baloo2-Regular.ttf",
        "assets/fonts/Baloo2/Baloo2-VariableFont_wght.ttf",
        "assets/fonts/Baloo2/static/Baloo2-Regular.ttf",
    }, fallbackFont)

    local balooBold = resolveFirstExistingPath({
        "assets/fonts/Baloo2/Baloo2-Bold.ttf",
        "assets/fonts/Baloo2/static/Baloo2-Bold.ttf",
        "assets/fonts/Baloo2/Baloo2-SemiBold.ttf",
        "assets/fonts/Baloo2/static/Baloo2-SemiBold.ttf",
        balooRegular,
    }, balooRegular)

    if balooRegular == fallbackFont then
        print("[Theme] Baloo2 font files not found in assets/fonts/Baloo2. Falling back to m6x11plus.ttf")
    end

    self.fonts.tiny = love.graphics.newFont(balooRegular, 20)
    self.fonts.small = love.graphics.newFont(balooRegular, 28)
    self.fonts.normal = love.graphics.newFont(balooRegular, 36)
    self.fonts.large = love.graphics.newFont(balooBold, 44)
    self.fonts.display = love.graphics.newFont(balooBold, 58)
    self.fonts.huge = love.graphics.newFont(balooBold, 72)
    self.fonts.giant = love.graphics.newFont(balooBold, 76)

    for _, font in pairs(self.fonts) do
        font:setFilter("linear", "linear")
    end

    if love.filesystem.getInfo("assets/images/office_bg.png") then
        self.backdropImage = love.graphics.newImage("assets/images/office_bg.png")
        self.backdropImage:setFilter("linear", "linear")
    else
        self.backdropImage = nil
    end
end

function Theme:drawBackdrop(layout, time)
    local w = (layout and layout.w) or self.screen.width
    local h = (layout and layout.h) or self.screen.height
    local _ = time

    love.graphics.setColor(self.colors.bg)
    love.graphics.rectangle("fill", 0, 0, w, h)

    if self.backdropImage then
        local iw, ih = self.backdropImage:getDimensions()
        local scale = math.max(w / iw, h / ih)
        local drawW = iw * scale
        local drawH = ih * scale
        local drawX = (w - drawW) * 0.5
        local drawY = (h - drawH) * 0.5

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.backdropImage, drawX, drawY, 0, scale, scale)
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function Theme:drawTextWithShadow(text, x, y, font, color, shadowOffset)
    font = font or self.fonts.normal
    color = color or self.colors.text

    love.graphics.setFont(font)

    love.graphics.setColor(color)
    love.graphics.print(text, math.floor(x), math.floor(y))
end

function Theme:drawTextCenteredWithShadow(text, x, y, width, font, color, shadowOffset)
    font = font or self.fonts.normal
    color = color or self.colors.text

    love.graphics.setFont(font)

    local textWidth = font:getWidth(text)
    local tx = x + (width - textWidth) * 0.5

    love.graphics.setColor(color)
    love.graphics.print(text, math.floor(tx), math.floor(y))
end

function Theme:drawTextRightWithShadow(text, x, y, width, font, color, shadowOffset)
    font = font or self.fonts.normal
    color = color or self.colors.text

    love.graphics.setFont(font)

    local textWidth = font:getWidth(text)
    local tx = x + width - textWidth

    love.graphics.setColor(color)
    love.graphics.print(text, math.floor(tx), math.floor(y))
end

function Theme:drawTextWrappedWithShadow(text, x, y, width, align, font, color, shadowOffset)
    font = font or self.fonts.normal
    color = color or self.colors.text
    align = align or "left"

    love.graphics.setFont(font)

    love.graphics.setColor(color)
    love.graphics.printf(text, math.floor(x), math.floor(y), width, align)
end

return Theme
