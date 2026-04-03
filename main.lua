local HotReload   = require("src.core.hot_reload")
local Scaling     = require("src.core.scaling")
local Theme       = require("src.ui.theme")
local Card        = require("src.ui.card")

local APP_WIDTH   = 1920
local APP_HEIGHT  = 1080

local state       = {
    time = 0,
    card = nil,
}

local GRID_SIZE   = 30
local GRID_COLOR  = { 0.84, 0.86, 0.8, 0.32 }
local CARD_WIDTH  = 150
local CARD_HEIGHT = 190

local steveCard   = nil

local function drawPaperGrid()
    for x = 0, APP_WIDTH, GRID_SIZE do
        love.graphics.setColor(GRID_COLOR)
        love.graphics.line(x, 0, x, APP_HEIGHT)
    end

    for y = 0, APP_HEIGHT, GRID_SIZE do
        love.graphics.setColor(GRID_COLOR)
        love.graphics.line(0, y, APP_WIDTH, y)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

local function copyState(value)
    if type(value) ~= "table" then
        return value
    end
    local out = {}
    for k, v in pairs(value) do
        out[copyState(k)] = copyState(v)
    end
    return out
end

local function configureHotReload()
    HotReload.getState = function()
        return copyState(state)
    end

    HotReload.setState = function(saved)
        if not saved then return end
        state.time = saved.time or 0
        state.card = saved.card or state.card
    end

    HotReload.onReload = function()
        local okChunk, chunkOrErr = pcall(love.filesystem.load, "main.lua")
        if not okChunk or not chunkOrErr then
            print("Hot reload failed while loading main.lua")
            return
        end

        local okRun, runErr = pcall(chunkOrErr)
        if not okRun then
            print("Hot reload failed while executing main.lua: " .. tostring(runErr))
            return
        end

        if love.load then
            love.load(true)
        end
    end
end

function love.load(isReload)
    Scaling.init({
        width      = APP_WIDTH,
        height     = APP_HEIGHT,
        clearColor = Theme.colors.background,
        barColor   = { 0, 0, 0, 1 },
    })

    Theme.load()

    if not isReload then
        state.time = 0
        state.card = nil
    end

    if not state.card then
        local centeredX = (APP_WIDTH - CARD_WIDTH) * 0.5
        local centeredY = (APP_HEIGHT - CARD_HEIGHT) * 0.5
        state.card = {
            x = centeredX,
            y = centeredY,
            targetX = centeredX,
            targetY = centeredY,
        }
    end

    steveCard = Card.new({
        name = "Steve",
        width = CARD_WIDTH,
        height = CARD_HEIGHT,
        worldWidth = APP_WIDTH,
        worldHeight = APP_HEIGHT,
        x = state.card.x,
        y = state.card.y,
        targetX = state.card.targetX,
        targetY = state.card.targetY,
    })

    configureHotReload()
end

function love.update(dt)
    state.time = state.time + dt

    if steveCard then
        local mouseX, mouseY = love.mouse.getPosition()
        local gameX, gameY = screenToGame(mouseX, mouseY)
        steveCard:update(dt, gameX, gameY)
        state.card = steveCard:getSnapshot()
    end

    HotReload:update(dt)
end

function love.draw()
    Scaling.draw(function()
        drawPaperGrid()
        if steveCard then
            steveCard:draw(Theme.fonts.cardHeader)
        end

        love.graphics.setFont(Theme.fonts.default)
        HotReload:draw()
    end)
end

function love.resize(w, h)
    Scaling.resize(w, h)
end

function love.keypressed(key)
    if key == "r" or key == "f5" then
        HotReload:reload()
        return
    end

    if key == "escape" then
        love.event.quit()
    end
end

function love.mousepressed(x, y, button)
    if button ~= 1 or not steveCard then
        return
    end

    local gameX, gameY = screenToGame(x, y)
    if not gameX or not gameY then
        return
    end

    steveCard:beginDrag(gameX, gameY)
end

function love.mousereleased(_, _, button)
    if button ~= 1 or not steveCard then
        return
    end

    steveCard:endDrag()
end
