local Scaling = {
    scale = 1,
    offsetX = 0,
    offsetY = 0,
    scaledWidth = 1920,
    scaledHeight = 1080,
    viewportWidth = 1920,
    viewportHeight = 1080,
    baseWidth = 1920,
    baseHeight = 1080,
    clearColor = { 1, 1, 1, 1 },
    barColor = { 0, 0, 0, 1 },
    initialized = false,
}

local function setColor(color)
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
end

local function clearWithColor(color)
    love.graphics.clear(color[1], color[2], color[3], color[4] or 1)
end

function Scaling.calculateScale()
    local windowWidth, windowHeight = love.graphics.getDimensions()
    local baseWidth = Scaling.baseWidth
    local baseHeight = Scaling.baseHeight

    local scaleX = windowWidth / baseWidth
    local scaleY = windowHeight / baseHeight
    Scaling.scale = math.min(scaleX, scaleY)

    if Scaling.scale <= 0 then
        Scaling.scale = 1
    end

    Scaling.scaledWidth = baseWidth * Scaling.scale
    Scaling.scaledHeight = baseHeight * Scaling.scale
    Scaling.offsetX = math.floor((windowWidth - Scaling.scaledWidth) * 0.5 + 0.5)
    Scaling.offsetY = math.floor((windowHeight - Scaling.scaledHeight) * 0.5 + 0.5)
    Scaling.viewportWidth = math.floor(Scaling.scaledWidth + 0.5)
    Scaling.viewportHeight = math.floor(Scaling.scaledHeight + 0.5)
end

function Scaling.screenToGame(screenX, screenY)
    if not Scaling.initialized then
        return screenX or 0, screenY or 0
    end

    if screenX == nil or screenY == nil then
        return nil, nil
    end

    if screenX < Scaling.offsetX
        or screenX >= Scaling.offsetX + Scaling.viewportWidth
        or screenY < Scaling.offsetY
        or screenY >= Scaling.offsetY + Scaling.viewportHeight
    then
        return nil, nil
    end

    local gameX = ((screenX or 0) - Scaling.offsetX) / Scaling.scale
    local gameY = ((screenY or 0) - Scaling.offsetY) / Scaling.scale

    local baseWidth = Scaling.baseWidth
    local baseHeight = Scaling.baseHeight
    if gameX < 0 or gameX >= baseWidth or gameY < 0 or gameY >= baseHeight then
        return nil, nil
    end

    return gameX, gameY
end

function Scaling.init(config)
    if config then
        if config.width then
            Scaling.baseWidth = config.width
        end
        if config.height then
            Scaling.baseHeight = config.height
        end
        if config.clearColor then
            Scaling.clearColor = config.clearColor
        end
        if config.barColor then
            Scaling.barColor = config.barColor
        else
            Scaling.barColor = { 0, 0, 0, 1 }
        end
    end

    Scaling.calculateScale()
    Scaling.initialized = true

    _G.screenToGame = Scaling.screenToGame
    _G.gameToScreen = Scaling.gameToScreen
end

function Scaling.resize(_, _)
    Scaling.calculateScale()
end

function Scaling.getScale()
    return Scaling.scale
end

function Scaling.getViewport()
    return Scaling.offsetX, Scaling.offsetY, Scaling.viewportWidth, Scaling.viewportHeight
end

function Scaling.gameToScreen(gameX, gameY)
    if not Scaling.initialized then
        return gameX or 0, gameY or 0
    end

    return Scaling.offsetX + (gameX or 0) * Scaling.scale,
        Scaling.offsetY + (gameY or 0) * Scaling.scale
end

function Scaling.draw(drawCallback)
    love.graphics.push("all")
    clearWithColor(Scaling.barColor)

    love.graphics.setScissor(Scaling.offsetX, Scaling.offsetY, Scaling.viewportWidth, Scaling.viewportHeight)
    love.graphics.translate(Scaling.offsetX, Scaling.offsetY)
    love.graphics.scale(Scaling.scale, Scaling.scale)

    setColor(Scaling.clearColor)
    love.graphics.rectangle("fill", 0, 0, Scaling.baseWidth, Scaling.baseHeight)
    love.graphics.setColor(1, 1, 1, 1)

    if drawCallback then
        drawCallback()
    end

    love.graphics.pop()
end

return Scaling
