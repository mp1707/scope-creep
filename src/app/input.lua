local HotReload = require("src.core.hot_reload")
local Scaling = require("src.core.scaling")
local PaydayOverlay = require("src.game.ui.payday_overlay")

local Constants = require("src.app.constants")
local State = require("src.app.state")
local Systems = require("src.app.systems")
local Camera = require("src.app.camera")
local Utils = require("src.app.utils")
local Queries = require("src.app.cards.queries")
local Drag = require("src.app.drag")
local GameFlow = require("src.app.game_flow")

local Input = {}

local clamp = Utils.clamp

function Input.keypressed(key)
    if key == "r" or key == "f5" then
        HotReload:reload()
        return
    end

    if key == "escape" then
        love.event.quit()
        return
    end

    local phase = Systems.gameState:getPhase()

    if key == "space" then
        if phase == "running" or phase == "paused" then
            Systems.gameState:togglePause()
        end
        return
    end

    if key == "return" or key == "kpenter" then
        if phase == "running" or phase == "paused" or phase == "payday" then
            Systems.gameState:toggleSpeed()
        end
    end
end

local function pickCardAt(worldX, worldY)
    for i = #State.cards, 1, -1 do
        local card = State.cards[i]
        if Queries.isCardInteractive(card) and not Queries.isCardLocked(card)
            and card:containsPoint(worldX, worldY)
        then
            return card
        end
    end
    return nil
end

function Input.mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    local gameX, gameY = screenToGame(x, y)
    if not gameX or not gameY then
        return
    end

    local phase = Systems.gameState:getPhase()
    if phase == "gameover" then
        return
    end

    if phase == "payday" and PaydayOverlay.isNextButtonHovered(gameX, gameY) then
        State.uiState.nextButtonPressed = true
        return
    end

    local worldX, worldY = Camera.gameToWorld(gameX, gameY)
    local selectedCard = pickCardAt(worldX, worldY)

    if not selectedCard then
        State.dragState.panningWorld = true
        return
    end

    local selection = { selectedCard }
    if selectedCard:containsHeaderPoint(worldX, worldY) then
        selection = Queries.collectStackFrom(selectedCard)
    end

    State.bringCardsToFront(selection)
    Drag.beginSelection(selection, worldX, worldY)

    State.dragState.dragPressStartScreenX = x
    State.dragState.dragPressStartScreenY = y
    State.dragState.panningWorld = false
end

function Input.mousereleased(x, y, button)
    if button ~= 1 then
        return
    end

    local gameX, gameY = screenToGame(x, y)
    local phase = Systems.gameState:getPhase()

    if phase == "payday" and State.uiState.nextButtonPressed then
        State.uiState.nextButtonPressed = false
        if gameX and gameY and PaydayOverlay.isNextButtonHovered(gameX, gameY) then
            GameFlow.startNextSprintFromPayday()
        end
        return
    end

    if State.dragState.panningWorld then
        State.dragState.panningWorld = false
        return
    end

    if #State.dragState.draggingCards == 0 then
        return
    end

    local rootCard = State.dragState.dragRootCard or State.dragState.draggingCards[1]
    local dx = x - (State.dragState.dragPressStartScreenX or x)
    local dy = y - (State.dragState.dragPressStartScreenY or y)
    local threshold = Constants.CLICK_ATTACH_THRESHOLD
    local movedEnough = (dx * dx + dy * dy) > (threshold * threshold)

    Drag.endSelection()

    if not movedEnough and rootCard
        and rootCard.objectType == "booster_pack"
        and Queries.isCardInteractive(rootCard)
    then
        Systems.packs:openPack(rootCard, {
            spawnCard = function(defId, spawnX, spawnY, options)
                local opts = options or {}
                opts.fromX = rootCard.x + (rootCard.width * 0.5)
                opts.fromY = rootCard.y + (rootCard.height * 0.5)
                return GameFlow.systemCallbacks.spawnCard(defId, spawnX, spawnY, opts)
            end,
            random = math.random,
        })
    end

    State.dragState.dragPressStartScreenX = nil
    State.dragState.dragPressStartScreenY = nil
end

function Input.mousemoved(_, _, dx, dy)
    if not State.dragState.panningWorld then
        return
    end

    if not love.mouse.isDown(1) then
        State.dragState.panningWorld = false
        return
    end

    local viewportScale = Scaling.getScale()
    if viewportScale <= 0 then
        viewportScale = 1
    end

    Camera.x = Camera.x - (dx / viewportScale) / Camera.zoom
    Camera.y = Camera.y - (dy / viewportScale) / Camera.zoom
    Camera.clamp()
end

function Input.wheelmoved(_, y)
    if y == 0 then
        return
    end

    local mouseX, mouseY = love.mouse.getPosition()
    local gameX, gameY = screenToGame(mouseX, mouseY)
    local anchorGameX = gameX or (Constants.APP_WIDTH * 0.5)
    local anchorGameY = gameY or (Constants.APP_HEIGHT * 0.5)
    local anchorWorldX, anchorWorldY = Camera.gameToWorld(anchorGameX, anchorGameY)

    local targetZoom = clamp(Camera.zoom * (Camera.zoomStep ^ y), Camera.minZoom, Camera.maxZoom)
    if targetZoom == Camera.zoom then
        return
    end

    Camera.zoom = targetZoom
    Camera.x = anchorWorldX - (anchorGameX / Camera.zoom)
    Camera.y = anchorWorldY - (anchorGameY / Camera.zoom)
    Camera.clamp()
end

return Input
