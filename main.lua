-- Entrypoint: wires LÖVE callbacks to the modular app layer.
-- All gameplay, rendering, and input logic lives under `src/app/` and `src/game/`.

local HotReload = require("src.core.hot_reload")
local Scaling = require("src.core.scaling")
local Theme = require("src.ui.theme")

local Constants = require("src.app.constants")
local State = require("src.app.state")
local Systems = require("src.app.systems")
local Camera = require("src.app.camera")
local GameFlow = require("src.app.game_flow")
local Simulation = require("src.app.simulation")
local Input = require("src.app.input")
local HotReloadSetup = require("src.app.hot_reload_setup")
local WorldRenderer = require("src.app.render.world")
local Hud = require("src.app.render.hud")

function love.load(isReload)
    Scaling.init({
        width = Constants.APP_WIDTH,
        height = Constants.APP_HEIGHT,
        clearColor = Theme.colors.background,
        barColor = Theme.colors.letterbox,
    })

    Theme.load(Scaling.getScale())

    if isReload ~= true then
        GameFlow.bootstrapNewGame()
    end

    HotReloadSetup.configure()
end

function love.update(dt)
    if not Systems.time or not Systems.gameState then
        GameFlow.bootstrapNewGame()
    end

    State.time = State.time + dt

    local mouseX, mouseY = love.mouse.getPosition()
    local gameX, gameY = screenToGame(mouseX, mouseY)
    local worldX, worldY = Camera.gameToWorld(gameX, gameY)

    Simulation.update(dt)
    Simulation.updateCards(dt, worldX, worldY)

    HotReload:update(dt)
end

function love.draw()
    Scaling.draw(function()
        local mouseX, mouseY = love.mouse.getPosition()
        local gameX, gameY = screenToGame(mouseX, mouseY)

        WorldRenderer.draw()
        Hud.draw(gameX, gameY)

        love.graphics.setFont(Theme.fonts.default)
        HotReload:draw(Constants.APP_HEIGHT, Scaling.getScale())
    end)
end

function love.resize(w, h)
    Scaling.resize(w, h)
    Theme.load(Scaling.getScale())
end

function love.keypressed(key)
    Input.keypressed(key)
end

function love.mousepressed(x, y, button)
    Input.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    Input.mousereleased(x, y, button)
end

function love.mousemoved(x, y, dx, dy)
    Input.mousemoved(x, y, dx, dy)
end

function love.wheelmoved(x, y)
    Input.wheelmoved(x, y)
end
