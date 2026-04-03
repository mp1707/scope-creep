local HotReload = require("src.core.hot_reload")
local Scaling = require("src.core.scaling")
local Theme = require("src.ui.theme")
local Card = require("src.ui.card")

local APP_WIDTH = 1920
local APP_HEIGHT = 1080

local state = {
    time = 0,
    day = 1,
    nextCardId = 1,
    cards = nil,
}

local GRID_SIZE = 30
local GRID_COLOR = { 0.84, 0.86, 0.8, 0.32 }

local CARD_WIDTH = 150
local CARD_HEIGHT = 190

local STACK_OFFSET_Y = Card.HEADER_HEIGHT or 34
local STACK_SNAP_DISTANCE = 80
local CLICK_ATTACH_THRESHOLD = 6

local WORK_CYCLE_SECONDS = 3
local WORK_BAR_HEIGHT = 14

local NEW_DAY_BUTTON = {
    x = APP_WIDTH - 250,
    y = 24,
    width = 220,
    height = 52,
}

local cards = {}
local draggingCards = {}
local dragRootCard = nil
local stickyDragMode = false
local dragPressStartScreenX = nil
local dragPressStartScreenY = nil

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
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

local function allocateCardId()
    local nextId = state.nextCardId or 1
    state.nextCardId = nextId + 1
    return nextId
end

local function getCardById(cardId)
    if cardId == nil then
        return nil
    end

    for _, card in ipairs(cards) do
        if card.id == cardId then
            return card
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

local function removeCardInstance(cardToRemove)
    if not cardToRemove then
        return
    end

    for i = #cards, 1, -1 do
        if cards[i] == cardToRemove then
            table.remove(cards, i)
            break
        end
    end

    for i = #draggingCards, 1, -1 do
        if draggingCards[i] == cardToRemove then
            table.remove(draggingCards, i)
        end
    end

    if dragRootCard == cardToRemove then
        dragRootCard = nil
    end

    for _, other in ipairs(cards) do
        if other.stackParentId == cardToRemove.id then
            other.stackParentId = nil
        end
    end
end

local function getDirectChild(parentCard, excludedCards)
    for _, candidate in ipairs(cards) do
        if candidate.stackParentId == parentCard.id and not (excludedCards and excludedCards[candidate]) then
            return candidate
        end
    end
    return nil
end

local function getDirectChildOfType(parentCard, cardType)
    for _, candidate in ipairs(cards) do
        if candidate.stackParentId == parentCard.id and candidate.cardType == cardType then
            return candidate
        end
    end
    return nil
end

local function isDescendant(card, potentialAncestor)
    local current = card
    while current and current.stackParentId do
        local parent = getCardById(current.stackParentId)
        if not parent then
            return false
        end
        if parent == potentialAncestor then
            return true
        end
        current = parent
    end
    return false
end

local function collectStackFrom(card)
    local selected = {}

    local function collectFrom(root)
        table.insert(selected, root)
        for _, candidate in ipairs(cards) do
            if candidate.stackParentId == root.id then
                collectFrom(candidate)
            end
        end
    end

    collectFrom(card)
    return selected
end

local function canAttachCard(cardToSnap, targetCard, excludedCards)
    if not cardToSnap or not targetCard then
        return false
    end

    if cardToSnap == targetCard then
        return false
    end

    if cardToSnap.shipState or targetCard.shipState then
        return false
    end

    if isDescendant(targetCard, cardToSnap) then
        return false
    end

    if cardToSnap.cardType == "person" then
        return false
    end

    if cardToSnap.cardType == "feature" then
        if cardToSnap:isFeatureComplete() then
            return false
        end
        if targetCard.cardType ~= "person" then
            return false
        end

        local existingChild = getDirectChild(targetCard, excludedCards)
        if existingChild and existingChild ~= cardToSnap then
            return false
        end

        return true
    end

    if cardToSnap.cardType == "money" then
        if targetCard.cardType ~= "money" then
            return false
        end

        local existingChild = getDirectChild(targetCard, excludedCards)
        if existingChild and existingChild ~= cardToSnap then
            return false
        end

        return true
    end

    return false
end

local function findBestStackTarget(cardToSnap, excludedCards)
    local best = nil
    local bestDistanceSquared = STACK_SNAP_DISTANCE * STACK_SNAP_DISTANCE

    for _, other in ipairs(cards) do
        if other ~= cardToSnap and not (excludedCards and excludedCards[other]) then
            if canAttachCard(cardToSnap, other, excludedCards) then
                local snapX = other.targetX
                local snapY = other.targetY + STACK_OFFSET_Y
                local dx = cardToSnap.targetX - snapX
                local dy = cardToSnap.targetY - snapY
                local distanceSquared = dx * dx + dy * dy

                if distanceSquared <= bestDistanceSquared then
                    bestDistanceSquared = distanceSquared
                    best = {
                        parent = other,
                        x = snapX,
                        y = snapY,
                    }
                end
            end
        end
    end

    return best
end

local function applyStackSnap(cardToSnap, excludedCards)
    local target = findBestStackTarget(cardToSnap, excludedCards)
    if not target then
        cardToSnap.stackParentId = nil
        return false
    end

    cardToSnap.stackParentId = target.parent.id
    cardToSnap.targetX = clamp(target.x, 0, APP_WIDTH - CARD_WIDTH)
    cardToSnap.targetY = clamp(target.y, 0, APP_HEIGHT - CARD_HEIGHT)
    return true
end

local function beginDragSelection(selection, pointerX, pointerY)
    draggingCards = selection
    dragRootCard = selection[1]

    local selectedById = {}
    for _, card in ipairs(selection) do
        selectedById[card.id] = true
    end

    for _, card in ipairs(selection) do
        if card.stackParentId and not selectedById[card.stackParentId] then
            card.stackParentId = nil
        end
    end

    for _, card in ipairs(cards) do
        if card.stackParentId and selectedById[card.stackParentId] and not selectedById[card.id] then
            card.stackParentId = nil
        end
    end

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

local function createCard(config)
    return Card.new({
        id = config.id or allocateCardId(),
        cardType = config.cardType,
        title = config.title,
        effect = config.effect,
        maxCapacity = config.maxCapacity,
        capacity = config.capacity,
        costTotal = config.costTotal,
        costRemaining = config.costRemaining,
        value = config.value,
        moneyAmount = config.moneyAmount,
        stackParentId = config.stackParentId,
        workProgress = config.workProgress,
        width = CARD_WIDTH,
        height = CARD_HEIGHT,
        worldWidth = APP_WIDTH,
        worldHeight = APP_HEIGHT,
        x = config.x,
        y = config.y,
        targetX = config.targetX,
        targetY = config.targetY,
    })
end

local function createDefaultCards()
    local centeredX = (APP_WIDTH - CARD_WIDTH) * 0.5
    local centeredY = (APP_HEIGHT - CARD_HEIGHT) * 0.5

    local steveCard = createCard({
        cardType = "person",
        title = "Steve",
        effect = "no special talents...",
        maxCapacity = 2,
        capacity = 2,
        x = centeredX,
        y = centeredY,
        targetX = centeredX,
        targetY = centeredY,
        workProgress = 0,
    })

    local quickWinX = centeredX + CARD_WIDTH + 120
    local quickWinY = centeredY - 20

    local quickWinCard = createCard({
        cardType = "feature",
        title = "Quick Win",
        costTotal = 4,
        costRemaining = 4,
        value = 1,
        x = quickWinX,
        y = quickWinY,
        targetX = quickWinX,
        targetY = quickWinY,
    })

    return { quickWinCard, steveCard }
end

local function restoreCardsFromSnapshot(cardSnapshots)
    local restoredCards = {}
    local maxId = 0

    for _, snapshot in ipairs(cardSnapshots) do
        local restored = createCard(snapshot)
        table.insert(restoredCards, restored)
        if restored.id and restored.id > maxId then
            maxId = restored.id
        end
    end

    if maxId >= (state.nextCardId or 1) then
        state.nextCardId = maxId + 1
    end

    return restoredCards
end

local function bootstrapCards()
    if type(state.cards) == "table" and #state.cards > 0 then
        cards = restoreCardsFromSnapshot(state.cards)
        return
    end

    cards = createDefaultCards()
end

local function serializeCards()
    local snapshots = {}
    for _, card in ipairs(cards) do
        if not card.shipState then
            table.insert(snapshots, card:getSnapshot())
        end
    end
    state.cards = snapshots
end

local function startNewDay()
    state.day = (state.day or 1) + 1

    for _, card in ipairs(cards) do
        if card.cardType == "person" then
            card.capacity = card.maxCapacity or card.capacity
        end
    end
end

local function releaseCompletedFeature(featureCard, workerCard)
    if not featureCard or not workerCard then
        return
    end

    featureCard.stackParentId = nil
    featureCard.costRemaining = 0

    local targetX = clamp(workerCard.targetX + CARD_WIDTH + 30, 0, APP_WIDTH - CARD_WIDTH)
    local targetY = clamp(workerCard.targetY + 8, 0, APP_HEIGHT - CARD_HEIGHT)

    featureCard.targetX = targetX
    featureCard.targetY = targetY

    bringCardsToFront({ featureCard })
end

local function updateWorkerProgress(dt)
    for _, workerCard in ipairs(cards) do
        if workerCard.cardType == "person" then
            local activeFeature = getDirectChildOfType(workerCard, "feature")

            if not activeFeature or activeFeature:isFeatureComplete() then
                workerCard.workProgress = 0
            elseif workerCard.capacity and workerCard.capacity > 0 then
                workerCard.workProgress = (workerCard.workProgress or 0) + dt

                while workerCard.workProgress >= WORK_CYCLE_SECONDS and workerCard.capacity > 0 and activeFeature.costRemaining > 0 do
                    workerCard.workProgress = workerCard.workProgress - WORK_CYCLE_SECONDS
                    workerCard.capacity = workerCard.capacity - 1
                    activeFeature.costRemaining = activeFeature.costRemaining - 1

                    if activeFeature.costRemaining <= 0 then
                        activeFeature.costRemaining = 0
                        workerCard.workProgress = 0
                        releaseCompletedFeature(activeFeature, workerCard)
                        break
                    end
                end
            end
        end
    end
end

local function startShipAnimation(featureCard)
    featureCard.shipState = {
        elapsed = 0,
        duration = 0.34,
    }
end

local function spawnMoneyForFeature(featureCard)
    local moneyCard = createCard({
        cardType = "money",
        title = "Money",
        moneyAmount = featureCard.value or 1,
        x = clamp(featureCard.x + 20, 0, APP_WIDTH - CARD_WIDTH),
        y = clamp(featureCard.y + 10, 0, APP_HEIGHT - CARD_HEIGHT),
        targetX = clamp(featureCard.targetX + 20, 0, APP_WIDTH - CARD_WIDTH),
        targetY = clamp(featureCard.targetY + 10, 0, APP_HEIGHT - CARD_HEIGHT),
    })

    table.insert(cards, moneyCard)
end

local function updateShipAnimations(dt)
    local cardsToFinish = {}

    for _, card in ipairs(cards) do
        if card.shipState then
            card.shipState.elapsed = card.shipState.elapsed + dt
            if card.shipState.elapsed >= card.shipState.duration then
                table.insert(cardsToFinish, card)
            end
        end
    end

    for _, card in ipairs(cardsToFinish) do
        spawnMoneyForFeature(card)
        removeCardInstance(card)
    end
end

local function updateAttachedCardTargets()
    for _, card in ipairs(cards) do
        if card.stackParentId and not card:isDragging() then
            local parent = getCardById(card.stackParentId)
            if parent then
                card.targetX = clamp(parent.targetX, 0, APP_WIDTH - CARD_WIDTH)
                card.targetY = clamp(parent.targetY + STACK_OFFSET_Y, 0, APP_HEIGHT - CARD_HEIGHT)
            else
                card.stackParentId = nil
            end
        end
    end
end

local function drawWorkBars()
    for _, workerCard in ipairs(cards) do
        if workerCard.cardType == "person" then
            local activeFeature = getDirectChildOfType(workerCard, "feature")
            if activeFeature and not activeFeature:isFeatureComplete() then
                local barX = workerCard.x
                local stackTopY = math.min(workerCard.y, activeFeature.y)
                local barY = stackTopY - WORK_BAR_HEIGHT - 14

                local progress = clamp((workerCard.workProgress or 0) / WORK_CYCLE_SECONDS, 0, 1)
                local innerPadding = 3

                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.rectangle("fill", barX, barY, CARD_WIDTH, WORK_BAR_HEIGHT)

                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", barX, barY, CARD_WIDTH, WORK_BAR_HEIGHT)

                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.rectangle(
                    "fill",
                    barX + innerPadding,
                    barY + innerPadding,
                    (CARD_WIDTH - innerPadding * 2) * progress,
                    WORK_BAR_HEIGHT - innerPadding * 2
                )
            end
        end
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

local function getShipButtonRect(featureCard)
    return {
        x = featureCard.x + 8,
        y = featureCard.y + featureCard.height - 38,
        width = featureCard.width - 16,
        height = 30,
    }
end

local function isShipButtonVisible(card)
    return card.cardType == "feature"
        and card:isFeatureComplete()
        and not card.shipState
        and not card.stackParentId
end

local function drawShipButtons()
    love.graphics.setFont(Theme.fonts.uiButton)

    for _, card in ipairs(cards) do
        if isShipButtonVisible(card) then
            local button = getShipButtonRect(card)

            love.graphics.setColor(0.44, 0.84, 0.48, 1)
            love.graphics.rectangle("fill", button.x, button.y, button.width, button.height)

            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", button.x, button.y, button.width, button.height)

            love.graphics.printf("Ship it!", button.x, button.y + 2, button.width, "center")
        end
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawShipPuff(card)
    if not card.shipState then
        return
    end

    local progress = clamp(card.shipState.elapsed / card.shipState.duration, 0, 1)
    local centerX = card.x + card.width * 0.5
    local centerY = card.y + card.height * 0.45
    local radiusBase = 12 + 28 * progress
    local alpha = 0.45 * (1 - progress)

    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.circle("fill", centerX - 20, centerY - 4, radiusBase)
    love.graphics.circle("fill", centerX + 16, centerY + 5, radiusBase * 0.9)
    love.graphics.circle("fill", centerX, centerY - 16, radiusBase * 0.75)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawCardWithEffects(card, options)
    options = options or {}

    local drawOptions = {
        skipShadow = options.skipShadow,
        bodyFont = Theme.fonts.cardBody,
        valueFont = Theme.fonts.default,
    }

    if card.shipState then
        local progress = clamp(card.shipState.elapsed / card.shipState.duration, 0, 1)
        drawOptions.alpha = 1 - progress
        drawOptions.extraScale = 1 + 0.18 * progress
    end

    card:draw(Theme.fonts.cardHeader, drawOptions)

    if card.shipState then
        drawShipPuff(card)
    end
end

local function drawNewDayButton()
    love.graphics.setFont(Theme.fonts.uiButton)

    love.graphics.setColor(0, 0, 0, 0.15)
    love.graphics.rectangle("fill", NEW_DAY_BUTTON.x + 2, NEW_DAY_BUTTON.y + 2, NEW_DAY_BUTTON.width, NEW_DAY_BUTTON.height, 10, 10)

    love.graphics.setColor(0.94, 0.97, 1, 1)
    love.graphics.rectangle("fill", NEW_DAY_BUTTON.x, NEW_DAY_BUTTON.y, NEW_DAY_BUTTON.width, NEW_DAY_BUTTON.height, 10, 10)

    love.graphics.setColor(0.1, 0.2, 0.33, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", NEW_DAY_BUTTON.x, NEW_DAY_BUTTON.y, NEW_DAY_BUTTON.width, NEW_DAY_BUTTON.height, 10, 10)
    love.graphics.printf("Start New Day", NEW_DAY_BUTTON.x, NEW_DAY_BUTTON.y + 10, NEW_DAY_BUTTON.width, "center")

    love.graphics.setFont(Theme.fonts.cardBody)
    love.graphics.setColor(0.05, 0.08, 0.1, 0.75)
    love.graphics.printf("Day " .. tostring(state.day or 1), NEW_DAY_BUTTON.x, NEW_DAY_BUTTON.y + NEW_DAY_BUTTON.height + 4, NEW_DAY_BUTTON.width, "center")

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

local function pointInRect(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.width
        and y >= rect.y and y <= rect.y + rect.height
end

local function configureHotReload()
    HotReload.getState = function()
        serializeCards()
        return copyState(state)
    end

    HotReload.setState = function(saved)
        if not saved then
            return
        end

        state.time = saved.time or 0
        state.day = saved.day or 1
        state.nextCardId = saved.nextCardId or 1

        if type(saved.cards) == "table" and #saved.cards > 0 then
            state.cards = saved.cards
        else
            state.cards = nil
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
        width = APP_WIDTH,
        height = APP_HEIGHT,
        clearColor = Theme.colors.background,
        barColor = { 0, 0, 0, 1 },
    })

    Theme.load(Scaling.getScale())

    if not isReload then
        state.time = 0
        state.day = 1
        state.nextCardId = 1
        state.cards = nil
    end

    bootstrapCards()

    draggingCards = {}
    dragRootCard = nil
    stickyDragMode = false
    dragPressStartScreenX = nil
    dragPressStartScreenY = nil

    configureHotReload()
end

function love.update(dt)
    state.time = state.time + dt

    local mouseX, mouseY = love.mouse.getPosition()
    local gameX, gameY = screenToGame(mouseX, mouseY)

    updateAttachedCardTargets()

    for _, card in ipairs(cards) do
        local pointerX = nil
        local pointerY = nil
        if card:isDragging() then
            pointerX = gameX
            pointerY = gameY
        end
        card:update(dt, pointerX, pointerY)
    end

    updateWorkerProgress(dt)
    updateShipAnimations(dt)

    serializeCards()
    HotReload:update(dt)
end

function love.draw()
    Scaling.draw(function()
        drawPaperGrid()

        for _, card in ipairs(cards) do
            if not isCardDragging(card) then
                drawCardWithEffects(card)
            end
        end

        drawDragStackShadow()

        for _, card in ipairs(cards) do
            if isCardDragging(card) then
                drawCardWithEffects(card, { skipShadow = true })
            end
        end

        drawWorkBars()
        drawShipButtons()
        drawNewDayButton()

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

    if pointInRect(gameX, gameY, NEW_DAY_BUTTON) then
        startNewDay()
        return
    end

    for i = #cards, 1, -1 do
        local card = cards[i]
        if isShipButtonVisible(card) then
            local shipButton = getShipButtonRect(card)
            if pointInRect(gameX, gameY, shipButton) then
                startShipAnimation(card)
                return
            end
        end
    end

    local selectedCard = nil
    for i = #cards, 1, -1 do
        local card = cards[i]
        if not card.shipState and card:containsPoint(gameX, gameY) then
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
