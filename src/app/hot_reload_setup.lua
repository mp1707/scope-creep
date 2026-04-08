local HotReload = require("src.core.hot_reload")

local State = require("src.app.state")
local Systems = require("src.app.systems")
local Camera = require("src.app.camera")
local Utils = require("src.app.utils")
local Serialization = require("src.app.serialization")

local HotReloadSetup = {}

function HotReloadSetup.configure()
    HotReload.getState = function()
        return {
            state = {
                time = State.time,
                nextUid = State.nextUid,
                cards = Serialization.serializeCards(),
                camera = {
                    x = Camera.x,
                    y = Camera.y,
                    zoom = Camera.zoom,
                },
                dragState = {
                    draggingCards = {},
                    dragRootCard = nil,
                    dragPressStartScreenX = nil,
                    dragPressStartScreenY = nil,
                    panningWorld = false,
                },
                uiState = Utils.copyState(State.uiState),
            },
            systems = {
                gameState = Systems.gameState:serialize(),
                time = Systems.time:serialize(),
                work = Systems.work:serialize(),
                sprint = Systems.sprint:serialize(),
                firedLabels = Utils.copyState(Systems.payday:getFiredLabels()),
            },
        }
    end

    HotReload.setState = function(saved)
        if type(saved) ~= "table" then
            return
        end

        Systems.setup()

        local savedState = saved.state or {}
        State.time = savedState.time or 0
        State.nextUid = savedState.nextUid or 1
        State.uiState = savedState.uiState or { nextButtonPressed = false }
        if savedState.dragState then
            State.dragState = savedState.dragState
        end
        State.dragState.draggingCards = {}
        State.dragState.dragRootCard = nil

        Serialization.restoreCards(savedState.cards)

        if savedState.camera then
            Camera.x = tonumber(savedState.camera.x) or Camera.x
            Camera.y = tonumber(savedState.camera.y) or Camera.y
            Camera.zoom = Utils.clamp(
                tonumber(savedState.camera.zoom) or Camera.zoom,
                Camera.minZoom,
                Camera.maxZoom
            )
        end

        Camera.clamp()

        local savedSystems = saved.systems or {}
        Systems.gameState:deserialize(savedSystems.gameState)
        Systems.time:deserialize(savedSystems.time)
        Systems.work:deserialize(savedSystems.work)
        Systems.sprint:deserialize(savedSystems.sprint)

        if type(savedSystems.firedLabels) == "table" then
            Systems.payday.firedLabels = savedSystems.firedLabels
        end

        Systems.evaluateStacks()
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

return HotReloadSetup
