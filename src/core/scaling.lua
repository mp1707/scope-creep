local Scaling = {
    canvas = nil,
    scale = 1,
    offsetX = 0,
    offsetY = 0,
    baseWidth = 1920,
    baseHeight = 1080,
    clearColor = { 1, 1, 1, 1 },
    barColor = { 0, 0, 0, 1 },
    initialized = false,
}

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

    local scaledWidth = baseWidth * Scaling.scale
    local scaledHeight = baseHeight * Scaling.scale
    Scaling.offsetX = (windowWidth - scaledWidth) * 0.5
    Scaling.offsetY = (windowHeight - scaledHeight) * 0.5
end

function Scaling.screenToGame(screenX, screenY)
    if not Scaling.initialized then
        return screenX or 0, screenY or 0
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

    Scaling.canvas = love.graphics.newCanvas(Scaling.baseWidth, Scaling.baseHeight)
    Scaling.canvas:setFilter("linear", "linear")

    Scaling.calculateScale()
    Scaling.initialized = true

    _G.screenToGame = Scaling.screenToGame
end

function Scaling.resize(_, _)
    Scaling.calculateScale()
end

function Scaling.draw(drawCallback)
    love.graphics.setCanvas(Scaling.canvas)
    love.graphics.clear(Scaling.clearColor)

    if drawCallback then
        drawCallback()
    end

    love.graphics.setCanvas()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(Scaling.canvas, Scaling.offsetX, Scaling.offsetY, 0, Scaling.scale, Scaling.scale)

    love.graphics.setColor(Scaling.barColor)
    if Scaling.offsetX > 0 then
        love.graphics.rectangle("fill", 0, 0, Scaling.offsetX, love.graphics.getHeight())
        love.graphics.rectangle("fill", love.graphics.getWidth() - Scaling.offsetX, 0, Scaling.offsetX, love.graphics.getHeight())
    end
    if Scaling.offsetY > 0 then
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), Scaling.offsetY)
        love.graphics.rectangle("fill", 0, love.graphics.getHeight() - Scaling.offsetY, love.graphics.getWidth(), Scaling.offsetY)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return Scaling
