local HotReload   = require("src.core.hot_reload")
local Scaling     = require("src.core.scaling")
local Theme       = require("src.ui.theme")
local Card        = require("src.ui.card")

local APP_WIDTH   = 1920
local APP_HEIGHT  = 1080

local state       = {
    time = 0,
    cards = nil,
}

local GRID_SIZE   = 30
local GRID_COLOR  = { 0.84, 0.86, 0.8, 0.32 }
local CARD_WIDTH  = 150
local CARD_HEIGHT = 190
local STACK_OFFSET_Y = Card.HEADER_HEIGHT or 34
local STACK_SNAP_DISTANCE = 80
local STACK_LINK_X_TOLERANCE = 24
local STACK_LINK_Y_TOLERANCE = 24
local CLICK_ATTACH_THRESHOLD = 6

local steveCard   = nil
local quickWinCard = nil
local cards = {}
local draggingCards = {}
local dragRootCard = nil
local stickyDragMode = false
local dragPressStartScreenX = nil
local dragPressStartScreenY = nil

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function getCardIndex(cardToFind)
    for i, card in ipairs(cards) do
        if card == cardToFind then
            return i
        end
    end
    return nil
end

local function isCardDragging(cardToFind)
    for _, card in ipairs(draggingCards) do
        if card == cardToFind then
            return true
        end
    end
    return false
end

local function bringCardsToFront(cardsToRaise)
    local selected = {}
    for _, card in ipairs(cardsToRaise) do
        selected[card] = true
    end

    local reordered = {}
    for _, card in ipairs(cards) do
        if not selected[card] then
            table.insert(reordered, card)
        end
    end
    for _, card in ipairs(cards) do
        if selected[card] then
            table.insert(reordered, card)
        end
    end

    cards = reordered
end

local function findStackedCardAbove(baseCard, baseIndex)
    local bestCard = nil
    local bestIndex = nil
    local bestScore = nil

    for i = baseIndex + 1, #cards do
        local candidate = cards[i]
        local dx = math.abs(candidate.targetX - baseCard.targetX)
        local dy = math.abs(candidate.targetY - (baseCard.targetY + STACK_OFFSET_Y))

        if dx <= STACK_LINK_X_TOLERANCE and dy <= STACK_LINK_Y_TOLERANCE then
            local score = dx + dy
            if not bestScore or score < bestScore then
                bestScore = score
                bestCard = candidate
                bestIndex = i
            end
        end
    end

    return bestCard, bestIndex
end

local function collectStackFrom(card)
    local baseIndex = getCardIndex(card)
    if not baseIndex then
        return { card }
    end

    local selected = { card }
    local currentCard = card
    local currentIndex = baseIndex

    while true do
        local aboveCard, aboveIndex = findStackedCardAbove(currentCard, currentIndex)
        if not aboveCard then
            break
        end

        table.insert(selected, aboveCard)
        currentCard = aboveCard
        currentIndex = aboveIndex
    end

    return selected
end

local function findBestStackTarget(cardToSnap, excludedCards)
    local best = nil
    local bestDistanceSquared = STACK_SNAP_DISTANCE * STACK_SNAP_DISTANCE

    for _, other in ipairs(cards) do
        local isExcluded = excludedCards and excludedCards[other]
        if other ~= cardToSnap and not isExcluded then
            local snapX = other.x
            local snapY = other.y + STACK_OFFSET_Y
            local dx = cardToSnap.targetX - snapX
            local dy = cardToSnap.targetY - snapY
            local distanceSquared = dx * dx + dy * dy

            if distanceSquared <= bestDistanceSquared then
                bestDistanceSquared = distanceSquared
                best = {
                    x = snapX,
                    y = snapY,
                }
            end
        end
    end

    return best
end

local function applyStackSnap(cardToSnap, excludedCards)
    local target = findBestStackTarget(cardToSnap, excludedCards)
    if not target then
        return
    end

    cardToSnap.targetX = clamp(target.x, 0, APP_WIDTH - CARD_WIDTH)
    cardToSnap.targetY = clamp(target.y, 0, APP_HEIGHT - CARD_HEIGHT)
end

local function beginDragSelection(selection, pointerX, pointerY)
    draggingCards = selection
    dragRootCard = selection[1]

    for _, card in ipairs(selection) do
        card:beginDrag(pointerX, pointerY, true)
    end
end

local function endDragSelection()
    if #draggingCards == 0 then
        return
    end

    local rootCard = dragRootCard or draggingCards[1]
    local beforeSnapX = rootCard.targetX
    local beforeSnapY = rootCard.targetY

    for _, card in ipairs(draggingCards) do
        card:endDrag()
    end

    local excludedCards = {}
    for _, card in ipairs(draggingCards) do
        excludedCards[card] = true
    end

    applyStackSnap(rootCard, excludedCards)

    local snapDeltaX = rootCard.targetX - beforeSnapX
    local snapDeltaY = rootCard.targetY - beforeSnapY
    if snapDeltaX ~= 0 or snapDeltaY ~= 0 then
        for _, card in ipairs(draggingCards) do
            if card ~= rootCard then
                card.targetX = clamp(card.targetX + snapDeltaX, 0, APP_WIDTH - CARD_WIDTH)
                card.targetY = clamp(card.targetY + snapDeltaY, 0, APP_HEIGHT - CARD_HEIGHT)
            end
        end
    end

    draggingCards = {}
    dragRootCard = nil
end

local function drawDragStackShadow()
    if #draggingCards == 0 then
        return
    end

    local root = dragRootCard or draggingCards[1]
    if not root then
        return
    end

    local minX = math.huge
    local minY = math.huge
    local maxX = -math.huge
    local maxY = -math.huge

    for _, card in ipairs(draggingCards) do
        local centerX = card.x + card.width * 0.5
        local centerY = card.y + card.height * 0.5
        local halfW = card.width * card.scale * 0.5
        local halfH = card.height * card.scale * 0.5
        local left = centerX - halfW
        local top = centerY - halfH
        local right = centerX + halfW
        local bottom = centerY + halfH

        if left < minX then minX = left end
        if top < minY then minY = top end
        if right > maxX then maxX = right end
        if bottom > maxY then maxY = bottom end
    end

    local shadowExpand = root.shadowExpand or 0
    local shadowOffsetX = root.shadowOffsetX or 0
    local shadowOffsetY = root.shadowOffsetY or 0
    local shadowAlpha = root.shadowAlpha or 0.12

    love.graphics.setColor(0, 0, 0, shadowAlpha)
    love.graphics.rectangle(
        "fill",
        minX - shadowExpand * 0.5 + shadowOffsetX,
        minY - shadowExpand * 0.5 + shadowOffsetY,
        (maxX - minX) + shadowExpand,
        (maxY - minY) + shadowExpand
    )
end

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
        state.cards = saved.cards or state.cards
        if not state.cards and saved.card then
            state.cards = {
                steve = saved.card,
            }
        end
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

    Theme.load(Scaling.getScale())

    if not isReload then
        state.time = 0
        state.cards = nil
    end

    if not state.cards then
        state.cards = {}
    end

    if not state.cards.steve then
        local centeredX = (APP_WIDTH - CARD_WIDTH) * 0.5
        local centeredY = (APP_HEIGHT - CARD_HEIGHT) * 0.5
        state.cards.steve = {
            x = centeredX,
            y = centeredY,
            targetX = centeredX,
            targetY = centeredY,
        }
    end

    if not state.cards.quickWin then
        local centeredX = (APP_WIDTH - CARD_WIDTH) * 0.5
        local centeredY = (APP_HEIGHT - CARD_HEIGHT) * 0.5
        local quickWinX = centeredX + CARD_WIDTH + 120
        local quickWinY = centeredY - 20
        state.cards.quickWin = {
            x = quickWinX,
            y = quickWinY,
            targetX = quickWinX,
            targetY = quickWinY,
        }
    end

    local steveState = state.cards.steve
    steveCard = Card.new({
        name = "Steve",
        capacity = 2,
        width = CARD_WIDTH,
        height = CARD_HEIGHT,
        worldWidth = APP_WIDTH,
        worldHeight = APP_HEIGHT,
        x = steveState.x,
        y = steveState.y,
        targetX = steveState.targetX,
        targetY = steveState.targetY,
    })

    local quickWinState = state.cards.quickWin
    quickWinCard = Card.new({
        name = "Quick Win",
        capacity = 2,
        width = CARD_WIDTH,
        height = CARD_HEIGHT,
        worldWidth = APP_WIDTH,
        worldHeight = APP_HEIGHT,
        x = quickWinState.x,
        y = quickWinState.y,
        targetX = quickWinState.targetX,
        targetY = quickWinState.targetY,
    })
    cards = { quickWinCard, steveCard }
    draggingCards = {}
    dragRootCard = nil
    stickyDragMode = false
    dragPressStartScreenX = nil
    dragPressStartScreenY = nil

    configureHotReload()
end

function love.update(dt)
    state.time = state.time + dt

    if #cards > 0 then
        local mouseX, mouseY = love.mouse.getPosition()
        local gameX, gameY = screenToGame(mouseX, mouseY)

        for _, card in ipairs(cards) do
            local pointerX = nil
            local pointerY = nil
            if card:isDragging() then
                pointerX = gameX
                pointerY = gameY
            end
            card:update(dt, pointerX, pointerY)
        end

        if steveCard and quickWinCard then
            state.cards = {
                steve = steveCard:getSnapshot(),
                quickWin = quickWinCard:getSnapshot(),
            }
        end
    end

    HotReload:update(dt)
end

function love.draw()
    Scaling.draw(function()
        drawPaperGrid()
        for _, card in ipairs(cards) do
            if not isCardDragging(card) then
                card:draw(Theme.fonts.cardHeader)
            end
        end
        drawDragStackShadow()
        for _, card in ipairs(cards) do
            if isCardDragging(card) then
                card:draw(Theme.fonts.cardHeader, { skipShadow = true })
            end
        end

        love.graphics.setFont(Theme.fonts.default)
        HotReload:draw(APP_HEIGHT, Scaling.getScale())
    end)
end

function love.resize(w, h)
    Scaling.resize(w, h)
    Theme.load(Scaling.getScale())
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
    if button ~= 1 then
        return
    end

    if #draggingCards > 0 and stickyDragMode then
        endDragSelection()
        stickyDragMode = false
        dragPressStartScreenX = nil
        dragPressStartScreenY = nil
        return
    end

    local gameX, gameY = screenToGame(x, y)
    if not gameX or not gameY then
        return
    end

    local selectedCard = nil
    for i = #cards, 1, -1 do
        local card = cards[i]
        if card:containsPoint(gameX, gameY) then
            selectedCard = card
            break
        end
    end

    if not selectedCard then
        return
    end

    local selection = { selectedCard }
    if selectedCard:containsHeaderPoint(gameX, gameY) then
        selection = collectStackFrom(selectedCard)
    end

    bringCardsToFront(selection)
    beginDragSelection(selection, gameX, gameY)
    stickyDragMode = false
    dragPressStartScreenX = x
    dragPressStartScreenY = y
end

function love.mousereleased(x, y, button)
    if button ~= 1 then
        return
    end

    if #draggingCards == 0 then
        return
    end

    if stickyDragMode then
        return
    end

    local dx = x - (dragPressStartScreenX or x)
    local dy = y - (dragPressStartScreenY or y)
    local movedEnough = (dx * dx + dy * dy) > (CLICK_ATTACH_THRESHOLD * CLICK_ATTACH_THRESHOLD)

    if movedEnough then
        endDragSelection()
        stickyDragMode = false
    else
        stickyDragMode = true
    end

    dragPressStartScreenX = nil
    dragPressStartScreenY = nil
end
