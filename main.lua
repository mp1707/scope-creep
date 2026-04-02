local HotReload  = require("src.core.hot_reload")
local Scaling    = require("src.core.scaling")
local Theme      = require("src.ui.theme")
local Board      = require("src.ui.board")
local InfoPanel  = require("src.ui.info_panel")

local APP_WIDTH   = 1920
local APP_HEIGHT  = 1080

local state = {
    time = 0,
}

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
    InfoPanel.load()

    if not isReload then
        state.time = 0
    end

    configureHotReload()
end

function love.update(dt)
    state.time = state.time + dt
    InfoPanel.update()
    HotReload:update(dt)
end

function love.draw()
    Scaling.draw(function()
        Board.draw()
        InfoPanel.draw()
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
