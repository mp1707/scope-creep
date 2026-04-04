local HotReload = require("src.core.hot_reload")
local Scaling = require("src.core.scaling")
local Theme = require("src.ui.theme")
local Card = require("src.ui.card")
local BoosterPack = require("src.ui.booster_pack")

local APP_WIDTH = 1920
local APP_HEIGHT = 1080
local WORLD_WIDTH = APP_WIDTH * 2
local WORLD_HEIGHT = APP_HEIGHT * 2

local state = {
    time = 0,
    day = 1,
    nextCardId = 1,
    cards = nil,
    camera = nil,
}

local GRID_SIZE = 30
local GRID_COLOR = Theme.colors.gridLine

local CARD_BODY_ASPECT_WIDTH = 300
local CARD_BODY_ASPECT_HEIGHT = 350
local CARD_WIDTH = 150
local CARD_BODY_HEIGHT = math.floor((CARD_WIDTH * CARD_BODY_ASPECT_HEIGHT / CARD_BODY_ASPECT_WIDTH) + 0.5)
local CARD_HEIGHT = (Card.HEADER_HEIGHT or 34) + CARD_BODY_HEIGHT
local BOOSTER_PACK_IMAGE_ASPECT = 400 / 500
local BOOSTER_PACK_HEIGHT = math.floor(CARD_HEIGHT * 1.089 + 0.5)
local BOOSTER_PACK_WIDTH = math.floor(BOOSTER_PACK_HEIGHT * BOOSTER_PACK_IMAGE_ASPECT + 0.5)

local STACK_OFFSET_Y = (Card.HEADER_HEIGHT or 34) - 3
local STACK_SNAP_DISTANCE = 80
local CLICK_ATTACH_THRESHOLD = 6
local STEVE_ICON_PATH = "assets/icons/characters/stressed.png"
local CONSULTING_ICON_PATH = "assets/icons/characters/consulting.png"
local MONEY_ICON_PATH = "assets/icons/Green Cash 1st Outline 256px.png"

local WORK_CYCLE_SECONDS = 3
local WORK_BAR_HEIGHT = 14
local WORK_BAR_RADIUS = 8
local OPPORTUNITY_CLICK_LIMIT = 3
local OPPORTUNITY_WOBBLE_DURATION = 0.18
local OPPORTUNITY_WOBBLE_AMPLITUDE = 0.05
local OPPORTUNITY_WOBBLE_CYCLES = 2.4
local PERSON_HOVER_MIN_HEIGHT = 32
local PERSON_HOVER_GAP = 14
local PERSON_HOVER_RADIUS = 8
local PERSON_HOVER_PADDING_X = 10
local PERSON_HOVER_PADDING_Y = 8
local CONSULTING_HOVER_HEIGHT = 58
local CONSULTING_HOVER_GAP = 14

local NEW_DAY_BUTTON = {
    width = 220,
    height = 52,
    marginRight = 26,
    marginBottom = 20,
}

local CONSULTING_ZONE = {
    width = 210,
    height = 237,
    marginLeft = 34,
    visibleHeight = 214,
    hoverLift = 11,
    cost = 1,
}

local camera = {
    x = 0,
    y = 0,
    zoom = 1,
    minZoom = 0.65,
    maxZoom = 1.9,
    zoomStep = 1.12,
}

local consultingHover = 0
local consultingZoneImage = nil
local consultingZoneLoadAttempted = false
local moneyIconImage = nil
local moneyIconLoadAttempted = false
local coverQuadCache = setmetatable({}, { __mode = "k" })

local cards = {}
local draggingCards = {}
local dragRootCard = nil
local stickyDragMode = false
local dragPressStartScreenX = nil
local dragPressStartScreenY = nil
local panningWorld = false

local consumeMoneyAtConsulting
local spawnMoneyForFeature
local createSideBounceMotion
local clampCamera
local gameToWorld
local worldToGame
local getNewDayButtonRect
local getConsultingRect

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function damp(current, target, speed, dt)
    local t = 1 - math.exp(-speed * dt)
    return current + (target - current) * t
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function easeOutQuad(t)
    local inv = 1 - t
    return 1 - (inv * inv)
end

local function getConsultingZoneImage()
    if consultingZoneImage or consultingZoneLoadAttempted then
        return consultingZoneImage
    end

    consultingZoneLoadAttempted = true

    local ok, loadedImage = pcall(love.graphics.newImage, CONSULTING_ICON_PATH)
    if not ok then
        return nil
    end

    loadedImage:setFilter("linear", "linear")
    consultingZoneImage = loadedImage
    return consultingZoneImage
end

local function getMoneyIconImage()
    if moneyIconImage or moneyIconLoadAttempted then
        return moneyIconImage
    end

    moneyIconLoadAttempted = true

    local ok, loadedImage = pcall(love.graphics.newImage, MONEY_ICON_PATH)
    if not ok then
        return nil
    end

    loadedImage:setFilter("linear", "linear")
    moneyIconImage = loadedImage
    return moneyIconImage
end

local function drawImageCover(image, x, y, width, height)
    local imageWidth = image:getWidth()
    local imageHeight = image:getHeight()
    if imageWidth <= 0 or imageHeight <= 0 or width <= 0 or height <= 0 then
        return
    end

    local scale = math.max(width / imageWidth, height / imageHeight)
    local sourceWidth = width / scale
    local sourceHeight = height / scale
    local sourceX = (imageWidth - sourceWidth) * 0.5
    local sourceY = (imageHeight - sourceHeight) * 0.5

    local quad = coverQuadCache[image]
    if not quad then
        quad = love.graphics.newQuad(0, 0, 1, 1, imageWidth, imageHeight)
        coverQuadCache[image] = quad
    end
    quad:setViewport(sourceX, sourceY, sourceWidth, sourceHeight, imageWidth, imageHeight)

    love.graphics.draw(
        image,
        quad,
        x,
        y,
        0,
        width / sourceWidth,
        height / sourceHeight
    )
end

local function drawConsultingPriceLine(x, y, width, price, viewportScale)
    local fontScale = 1 / viewportScale
    local numericPrice = math.max(0, math.floor(tonumber(price) or 0))
    local labelText = "Preis:"
    local amountText = string.format("%d x", numericPrice)
    local iconHeightFactor = 0.9

    local font = love.graphics.getFont()
    local textHeight = font:getHeight() * fontScale
    local labelWidth = font:getWidth(labelText) * fontScale
    local amountWidth = font:getWidth(amountText) * fontScale

    local iconWidth = 0
    local iconHeight = 0
    local iconGap = 0
    local moneyIcon = getMoneyIconImage()
    if moneyIcon then
        iconHeight = textHeight * iconHeightFactor
        iconWidth = moneyIcon:getWidth() * (iconHeight / moneyIcon:getHeight())
        iconGap = math.max(4, math.floor(textHeight * 0.3))
    end

    local sectionGap = math.max(8, math.floor(textHeight * 0.45))
    local contentWidth = labelWidth + sectionGap + amountWidth + iconGap + iconWidth
    local startX = x + (width - contentWidth) * 0.5
    local textY = y

    local textR, textG, textB, textA = love.graphics.getColor()

    love.graphics.print(labelText, startX, textY, 0, fontScale, fontScale)

    local amountX = startX + labelWidth + sectionGap
    love.graphics.print(amountText, amountX, textY, 0, fontScale, fontScale)

    if moneyIcon then
        local iconX = amountX + amountWidth + iconGap
        local iconY = textY + (textHeight - iconHeight) * 0.5
        love.graphics.setColor(1, 1, 1, textA or 1)
        love.graphics.draw(moneyIcon, iconX, iconY, 0, iconHeight / moneyIcon:getHeight(), iconHeight / moneyIcon:getHeight())
        love.graphics.setColor(textR, textG, textB, textA)
    end
end

local function getCameraViewSize()
    local zoom = camera.zoom
    if zoom <= 0 then
        zoom = 1
    end
    return APP_WIDTH / zoom, APP_HEIGHT / zoom
end

clampCamera = function()
    local viewWidth, viewHeight = getCameraViewSize()
    camera.x = clamp(camera.x, 0, math.max(0, WORLD_WIDTH - viewWidth))
    camera.y = clamp(camera.y, 0, math.max(0, WORLD_HEIGHT - viewHeight))
end

local function setCameraCenteredOn(worldX, worldY)
    local viewWidth, viewHeight = getCameraViewSize()
    camera.x = (worldX or 0) - viewWidth * 0.5
    camera.y = (worldY or 0) - viewHeight * 0.5
    clampCamera()
end

gameToWorld = function(gameX, gameY)
    if gameX == nil or gameY == nil then
        return nil, nil
    end
    local zoom = camera.zoom
    if zoom <= 0 then
        zoom = 1
    end
    return camera.x + (gameX / zoom), camera.y + (gameY / zoom)
end

worldToGame = function(worldX, worldY)
    if worldX == nil or worldY == nil then
        return nil, nil
    end
    local zoom = camera.zoom
    if zoom <= 0 then
        zoom = 1
    end
    return (worldX - camera.x) * zoom, (worldY - camera.y) * zoom
end

getNewDayButtonRect = function()
    return {
        x = APP_WIDTH - NEW_DAY_BUTTON.width - NEW_DAY_BUTTON.marginRight,
        y = APP_HEIGHT - NEW_DAY_BUTTON.height - NEW_DAY_BUTTON.marginBottom,
        width = NEW_DAY_BUTTON.width,
        height = NEW_DAY_BUTTON.height,
    }
end

getConsultingRect = function()
    local baseY = APP_HEIGHT - CONSULTING_ZONE.visibleHeight
    local lift = CONSULTING_ZONE.hoverLift * consultingHover
    return {
        x = CONSULTING_ZONE.marginLeft,
        y = baseY - lift,
        width = CONSULTING_ZONE.width,
        height = CONSULTING_ZONE.height,
    }
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

local function isCardLocked(card)
    return card ~= nil and (card.shipState ~= nil or card.motionState ~= nil)
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

    if isCardLocked(cardToSnap) or isCardLocked(targetCard) then
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
    cardToSnap.targetX = clamp(target.x, 0, WORLD_WIDTH - (cardToSnap.width or CARD_WIDTH))
    cardToSnap.targetY = clamp(target.y, 0, WORLD_HEIGHT - (cardToSnap.height or CARD_HEIGHT))
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
    if consumeMoneyAtConsulting(rootCard) then
        for _, card in ipairs(draggingCards) do
            card:endDrag()
        end
        draggingCards = {}
        dragRootCard = nil
        return
    end

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
                card.targetX = clamp(card.targetX + snapDeltaX, 0, WORLD_WIDTH - (card.width or CARD_WIDTH))
                card.targetY = clamp(card.targetY + snapDeltaY, 0, WORLD_HEIGHT - (card.height or CARD_HEIGHT))
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

    local minX = math.huge
    local minY = math.huge
    local maxX = -math.huge
    local maxY = -math.huge
    local shadowSource = nil

    for _, card in ipairs(draggingCards) do
        if card.cardType ~= "opportunity" then
            if not shadowSource then
                shadowSource = card
            end

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
    end

    if not shadowSource then
        return
    end

    local shadowExpand = shadowSource.shadowExpand or 0
    local shadowOffsetX = shadowSource.shadowOffsetX or 0
    local shadowOffsetY = shadowSource.shadowOffsetY or 0
    local shadowAlpha = shadowSource.shadowAlpha or 0.11

    local shadowColor = Theme.colors.cardShadow
    love.graphics.setColor(shadowColor[1], shadowColor[2], shadowColor[3], shadowAlpha)
    love.graphics.rectangle(
        "fill",
        minX - shadowExpand * 0.5 + shadowOffsetX,
        minY - shadowExpand * 0.5 + shadowOffsetY,
        (maxX - minX) + shadowExpand,
        (maxY - minY) + shadowExpand
    )
end

local function drawPaperGrid()
    for x = 0, WORLD_WIDTH, GRID_SIZE do
        love.graphics.setColor(GRID_COLOR)
        love.graphics.line(x, 0, x, WORLD_HEIGHT)
    end

    for y = 0, WORLD_HEIGHT, GRID_SIZE do
        love.graphics.setColor(GRID_COLOR)
        love.graphics.line(0, y, WORLD_WIDTH, y)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

local function createCard(config)
    return Card.new({
        id = config.id or allocateCardId(),
        cardType = config.cardType,
        title = config.title,
        effect = config.effect,
        iconPath = config.iconPath,
        maxCapacity = config.maxCapacity,
        capacity = config.capacity,
        costTotal = config.costTotal,
        costRemaining = config.costRemaining,
        value = config.value,
        moneyAmount = config.moneyAmount,
        insightsRemaining = config.insightsRemaining,
        stackParentId = config.stackParentId,
        workProgress = config.workProgress,
        width = config.width or CARD_WIDTH,
        height = config.height or CARD_HEIGHT,
        style = config.style,
        worldWidth = WORLD_WIDTH,
        worldHeight = WORLD_HEIGHT,
        x = config.x,
        y = config.y,
        targetX = config.targetX,
        targetY = config.targetY,
    })
end

local function createBoosterPack(config)
    return BoosterPack.new({
        id = config.id or allocateCardId(),
        title = config.title,
        effect = config.effect,
        insightsRemaining = config.insightsRemaining,
        width = BOOSTER_PACK_WIDTH,
        height = BOOSTER_PACK_HEIGHT,
        worldWidth = WORLD_WIDTH,
        worldHeight = WORLD_HEIGHT,
        x = config.x,
        y = config.y,
        targetX = config.targetX,
        targetY = config.targetY,
    })
end

local function createBoardObject(config)
    if config.objectType == "booster_pack" or config.cardType == "opportunity" then
        return createBoosterPack(config)
    end
    return createCard(config)
end

local function createDefaultCards()
    local centeredX = (WORLD_WIDTH - CARD_WIDTH) * 0.5
    local centeredY = (WORLD_HEIGHT - CARD_HEIGHT) * 0.5

    local steveCard = createCard({
        cardType = "person",
        title = "Steve",
        effect = "No special talents",
        iconPath = STEVE_ICON_PATH,
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
        costTotal = 2,
        costRemaining = 2,
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
        local restored = createBoardObject(snapshot)
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
    if type(state.cards) == "table" then
        cards = restoreCardsFromSnapshot(state.cards)
        return
    end

    cards = createDefaultCards()
end

local function serializeCards()
    local snapshots = {}
    for _, card in ipairs(cards) do
        if not card.shipState and not (card.motionState and card.motionState.skipSerialize) then
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

    if featureCard.motionState or featureCard.shipState then
        return
    end

    featureCard.stackParentId = nil
    featureCard.costRemaining = 0

    local moneyCard = spawnMoneyForFeature(featureCard)
    local moneySettleX = clamp(featureCard.x + 92, 0, WORLD_WIDTH - CARD_WIDTH)

    removeCardInstance(featureCard)

    moneyCard.motionState = createSideBounceMotion(
        moneyCard.x,
        moneyCard.y,
        moneySettleX,
        clamp(moneyCard.y, 0, WORLD_HEIGHT - CARD_HEIGHT)
    )
    moneyCard.targetX = moneyCard.x
    moneyCard.targetY = moneyCard.y
    moneyCard.rotation = 0
    moneyCard.renderAlpha = 1

    bringCardsToFront({ moneyCard })
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

spawnMoneyForFeature = function(featureCard)
    local moneyCard = createCard({
        cardType = "money",
        title = "Money",
        moneyAmount = featureCard.value or 1,
        x = clamp(featureCard.x + 20, 0, WORLD_WIDTH - CARD_WIDTH),
        y = clamp(featureCard.y + 10, 0, WORLD_HEIGHT - CARD_HEIGHT),
        targetX = clamp(featureCard.targetX + 20, 0, WORLD_WIDTH - CARD_WIDTH),
        targetY = clamp(featureCard.targetY + 10, 0, WORLD_HEIGHT - CARD_HEIGHT),
    })

    table.insert(cards, moneyCard)
    return moneyCard
end

createSideBounceMotion = function(startX, startY, endX, endY, config)
    local motion = {
        kind = "sideBounce",
        elapsed = 0,
        duration = 0.62,
        restHold = 0.06,
        startX = startX,
        startY = startY,
        endX = endX,
        endY = endY,
        arcHeights = { 36, 22, 0 },
        arcSplits = { 0.46, 0.76 },
        xSplits = { 0.58, 0.86 },
        tilt = 0.11,
    }

    if type(config) == "table" then
        for key, value in pairs(config) do
            motion[key] = value
        end
    end

    return motion
end

local function triggerOpportunityWobble(opportunityCard)
    if not opportunityCard then
        return
    end

    opportunityCard.clickWobble = {
        elapsed = 0,
        duration = OPPORTUNITY_WOBBLE_DURATION,
        amplitude = OPPORTUNITY_WOBBLE_AMPLITUDE,
        cycles = OPPORTUNITY_WOBBLE_CYCLES,
    }
end

local function updatePhysicalCardMotions(dt)
    for _, card in ipairs(cards) do
        local motion = card.motionState
        if motion then
            card.dragging = false
            card.targetScale = 1
            card.targetShadowOffsetX = 4
            card.targetShadowOffsetY = 4
            card.targetShadowAlpha = 0.11
            card.targetShadowExpand = 0

            if motion.kind ~= "sideBounce" then
                motion.kind = "sideBounce"
                motion.elapsed = motion.elapsed or 0
                motion.duration = motion.duration or 0.62
                motion.restHold = motion.restHold or 0.06
                motion.startX = motion.startX or card.x
                motion.startY = motion.startY or card.y
                motion.endX = motion.endX or motion.settleX or card.x
                motion.endY = motion.endY or motion.floorY or card.y
                motion.arcHeights = motion.arcHeights or { 38, 24, 0 }
                motion.arcSplits = motion.arcSplits or { 0.46, 0.76 }
                motion.tilt = motion.tilt or 0.11
                motion.xSplits = motion.xSplits or { 0.58, 0.86 }
            end

            motion.elapsed = (motion.elapsed or 0) + dt
            local progress = clamp((motion.elapsed or 0) / (motion.duration or 0.62), 0, 1)
            local splitA = motion.arcSplits[1] or 0.46
            local splitB = motion.arcSplits[2] or 0.76
            local xSplitA = motion.xSplits[1] or 0.58
            local xSplitB = motion.xSplits[2] or 0.86

            local moveT = 0
            if progress < splitA then
                local u = progress / splitA
                moveT = lerp(0, xSplitA, easeOutQuad(u))
            elseif progress < splitB then
                local u = (progress - splitA) / (splitB - splitA)
                moveT = lerp(xSplitA, xSplitB, easeOutQuad(u))
            else
                local u = (progress - splitB) / (1 - splitB)
                moveT = lerp(xSplitB, 1, easeOutQuad(u))
            end

            card.x = lerp(motion.startX, motion.endX, moveT)

            local lift = 0
            if progress < splitA then
                local u = progress / splitA
                lift = math.sin(u * math.pi) * (motion.arcHeights[1] or 38)
            elseif progress < splitB then
                local u = (progress - splitA) / (splitB - splitA)
                lift = math.sin(u * math.pi) * (motion.arcHeights[2] or 24)
            elseif progress < 1 then
                local u = (progress - splitB) / (1 - splitB)
                lift = math.sin(u * math.pi) * (motion.arcHeights[3] or 14)
            end

            card.y = lerp(motion.startY, motion.endY, moveT) - lift

            if progress >= 1 then
                card.x = motion.endX
                card.y = motion.endY
                motion.restElapsed = (motion.restElapsed or 0) + dt
                if motion.restElapsed >= (motion.restHold or 0.06) then
                    card.motionState = nil
                    card.rotation = 0
                    card.renderAlpha = 1
                end
            end

            local direction = (motion.endX >= motion.startX) and 1 or -1
            local tiltWave = math.sin(progress * math.pi) * (motion.tilt or 0.11) * direction
            card.rotation = damp(card.rotation or 0, tiltWave, 10, dt)

            card.x = clamp(card.x, 0, WORLD_WIDTH - (card.width or CARD_WIDTH))
            card.y = clamp(card.y, 0, WORLD_HEIGHT - (card.height or CARD_HEIGHT))
            card.targetX = card.x
            card.targetY = card.y
            card.renderAlpha = 1
        else
            local targetRotation = 0
            local wobble = card.clickWobble
            if wobble then
                wobble.elapsed = (wobble.elapsed or 0) + dt
                local duration = math.max(0.001, wobble.duration or OPPORTUNITY_WOBBLE_DURATION)
                local t = clamp((wobble.elapsed or 0) / duration, 0, 1)
                local fade = (1 - t) * (1 - t)
                local cycles = wobble.cycles or OPPORTUNITY_WOBBLE_CYCLES
                local wave = math.sin(t * math.pi * 2 * cycles)
                targetRotation = wave * (wobble.amplitude or OPPORTUNITY_WOBBLE_AMPLITUDE) * fade

                if t >= 1 then
                    card.clickWobble = nil
                    targetRotation = 0
                end
            end

            card.rotation = damp(card.rotation or 0, targetRotation, 18, dt)
            card.renderAlpha = 1
        end
    end
end

local function updateAttachedCardTargets()
    for _, card in ipairs(cards) do
        if card.stackParentId and not card:isDragging() and not card.motionState then
            local parent = getCardById(card.stackParentId)
            if parent then
                card.targetX = clamp(parent.targetX, 0, WORLD_WIDTH - (card.width or CARD_WIDTH))
                card.targetY = clamp(parent.targetY + STACK_OFFSET_Y, 0, WORLD_HEIGHT - (card.height or CARD_HEIGHT))
            else
                card.stackParentId = nil
            end
        end
    end
end

local function drawWorkBars()
    local workBarColors = Theme.colors.workBar
    local barRadius = math.min(WORK_BAR_RADIUS, WORK_BAR_HEIGHT * 0.5)
    for _, workerCard in ipairs(cards) do
        if workerCard.cardType == "person" then
            local activeFeature = getDirectChildOfType(workerCard, "feature")
            if activeFeature and not activeFeature:isFeatureComplete() then
                local barX = workerCard.x
                local stackTopY = math.min(workerCard.y, activeFeature.y)
                local barY = stackTopY - WORK_BAR_HEIGHT - 14

                local progress = clamp((workerCard.workProgress or 0) / WORK_CYCLE_SECONDS, 0, 1)
                local innerPadding = 3

                love.graphics.setColor(workBarColors.track)
                love.graphics.rectangle("fill", barX, barY, CARD_WIDTH, WORK_BAR_HEIGHT, barRadius, barRadius)

                love.graphics.setColor(workBarColors.border)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", barX, barY, CARD_WIDTH, WORK_BAR_HEIGHT, barRadius, barRadius)

                local progressWidth = (CARD_WIDTH - innerPadding * 2) * progress
                if progressWidth > 0 then
                    local innerHeight = WORK_BAR_HEIGHT - innerPadding * 2
                    local innerRadius = math.max(0, math.min(barRadius - innerPadding, innerHeight * 0.5, progressWidth * 0.5))
                    love.graphics.setColor(workBarColors.fill)
                    love.graphics.rectangle(
                        "fill",
                        barX + innerPadding,
                        barY + innerPadding,
                        progressWidth,
                        innerHeight,
                        innerRadius,
                        innerRadius
                    )
                end
            end
        end
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

local function getPersonEffectText(card)
    local effectText = card and card.effect
    if not effectText or effectText == "" then
        return "No special talents"
    end
    return effectText
end

local function getTopHoveredPersonCard(worldX, worldY)
    if not worldX or not worldY then
        return nil
    end

    for i = #cards, 1, -1 do
        local card = cards[i]
        if card:containsPoint(worldX, worldY) then
            if card.cardType == "person" then
                return card
            end
            return nil
        end
    end

    return nil
end

local function drawPersonHoverOverlay(card)
    if not card then
        return
    end

    local viewportScale = Scaling.getScale()
    if viewportScale <= 0 then
        viewportScale = 1
    end

    love.graphics.setFont(Theme.fonts.cardBody)
    local effectText = getPersonEffectText(card)
    local font = love.graphics.getFont()
    local textScale = 1 / viewportScale
    local textMaxWidth = math.max(1, card.width - PERSON_HOVER_PADDING_X * 2)
    local textWrapWidth = textMaxWidth * viewportScale
    local _, wrappedLines = font:getWrap(effectText, textWrapWidth)
    local lineCount = math.max(1, #wrappedLines)
    local textHeight = lineCount * font:getHeight() * textScale
    local overlayHeight = math.max(PERSON_HOVER_MIN_HEIGHT, PERSON_HOVER_PADDING_Y * 2 + textHeight)

    local hoverColors = Theme.colors.personHover
    local overlayX = card.x
    local overlayY = math.max(8, card.y - overlayHeight - PERSON_HOVER_GAP)
    local textY = overlayY + math.max(PERSON_HOVER_PADDING_Y, (overlayHeight - textHeight) * 0.5)

    love.graphics.setColor(hoverColors.fill)
    love.graphics.rectangle("fill", overlayX, overlayY, card.width, overlayHeight, PERSON_HOVER_RADIUS,
        PERSON_HOVER_RADIUS)

    love.graphics.setColor(hoverColors.border)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", overlayX, overlayY, card.width, overlayHeight, PERSON_HOVER_RADIUS,
        PERSON_HOVER_RADIUS)

    love.graphics.setColor(hoverColors.text)
    love.graphics.printf(
        effectText,
        overlayX + PERSON_HOVER_PADDING_X,
        textY,
        textWrapWidth,
        "center",
        0,
        textScale,
        textScale
    )

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawConsultingHoverOverlay(consultingRect)
    if not consultingRect then
        return
    end

    local viewportScale = Scaling.getScale()
    if viewportScale <= 0 then
        viewportScale = 1
    end

    local hoverColors = Theme.colors.consultingHover
    local overlayX = consultingRect.x
    local overlayY = math.max(8, consultingRect.y - CONSULTING_HOVER_HEIGHT - CONSULTING_HOVER_GAP)

    love.graphics.setColor(hoverColors.fill)
    love.graphics.rectangle("fill", overlayX, overlayY, consultingRect.width, CONSULTING_HOVER_HEIGHT)

    love.graphics.setColor(hoverColors.border)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", overlayX, overlayY, consultingRect.width, CONSULTING_HOVER_HEIGHT)

    love.graphics.setFont(Theme.fonts.cardBody)
    love.graphics.setColor(hoverColors.text)
    drawConsultingPriceLine(
        overlayX,
        overlayY + 18,
        consultingRect.width,
        CONSULTING_ZONE.cost,
        viewportScale
    )

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawCardWithEffects(card, options)
    options = options or {}

    local drawOptions = {
        skipShadow = options.skipShadow,
        bodyFont = Theme.fonts.cardBody,
        valueFont = Theme.fonts.cardBody,
    }

    drawOptions.alpha = card.renderAlpha or 1

    card:draw(Theme.fonts.cardHeader, drawOptions)
end

local function drawNewDayButton()
    local button = getNewDayButtonRect()
    local viewportScale = Scaling.getScale()
    if viewportScale <= 0 then
        viewportScale = 1
    end

    local buttonColors = Theme.colors.newDayButton
    love.graphics.setFont(Theme.fonts.uiButton)

    love.graphics.setColor(buttonColors.shadow)
    love.graphics.rectangle("fill", button.x + 2, button.y + 2, button.width, button.height, 10, 10)

    love.graphics.setColor(buttonColors.fill)
    love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, 10, 10)

    love.graphics.setColor(buttonColors.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", button.x, button.y, button.width, button.height, 10, 10)
    love.graphics.setColor(buttonColors.text)
    love.graphics.printf(
        "Start New Day",
        button.x,
        button.y + 10,
        button.width * viewportScale,
        "center",
        0,
        1 / viewportScale,
        1 / viewportScale
    )

    love.graphics.setFont(Theme.fonts.cardBody)
    local labelColor = buttonColors.label
    love.graphics.setColor(labelColor[1], labelColor[2], labelColor[3], 0.75)
    love.graphics.printf(
        "Day " .. tostring(state.day or 1),
        button.x,
        button.y - 30,
        button.width * viewportScale,
        "center",
        0,
        1 / viewportScale,
        1 / viewportScale
    )

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

local function pointInRect(x, y, rect)
    return x >= rect.x and x <= rect.x + rect.width
        and y >= rect.y and y <= rect.y + rect.height
end

local function isCardCenterInsideRect(card, rect)
    if not card or not rect then
        return false
    end

    local centerX = (card.targetX or card.x) + card.width * 0.5
    local centerY = (card.targetY or card.y) + card.height * 0.5
    local centerGameX, centerGameY = worldToGame(centerX, centerY)
    return pointInRect(centerGameX, centerGameY, rect)
end

local function isConsultingDropCandidate(card)
    return card ~= nil
        and card.cardType == "money"
        and not card.motionState
        and not card.shipState
end

local function isConsultingDropActive()
    local rootCard = dragRootCard or draggingCards[1]
    return isConsultingDropCandidate(rootCard) and isCardCenterInsideRect(rootCard, getConsultingRect())
end

local function drawConsultingZone(gameX, gameY)
    local zone = getConsultingRect()
    local activeDrop = isConsultingDropActive()
    local hovered = gameX and gameY and pointInRect(gameX, gameY, zone) or false
    local raised = activeDrop or hovered
    local viewportScale = Scaling.getScale()
    if viewportScale <= 0 then
        viewportScale = 1
    end

    local zoneColors = Theme.colors.consultingZone
    local bodyColor = raised and zoneColors.bodyRaised or zoneColors.body
    local headerColor = raised and zoneColors.headerRaised or zoneColors.header

    love.graphics.setColor(zoneColors.shadow)
    love.graphics.rectangle("fill", zone.x + 2, zone.y + 2, zone.width, zone.height)

    love.graphics.setColor(bodyColor)
    love.graphics.rectangle("fill", zone.x, zone.y, zone.width, zone.height)

    local borderInset = 2
    local imageX = zone.x + borderInset
    local imageY = zone.y + Card.HEADER_HEIGHT + borderInset
    local imageWidth = zone.width - borderInset * 2
    local imageHeight = zone.height - Card.HEADER_HEIGHT - borderInset * 2

    if imageHeight > 0 then
        love.graphics.setColor(bodyColor)
        love.graphics.rectangle("fill", imageX, imageY, imageWidth, imageHeight)

        local consultingImage = getConsultingZoneImage()
        if consultingImage then
            love.graphics.setColor(1, 1, 1, 1)
            drawImageCover(consultingImage, imageX, imageY, imageWidth, imageHeight)
        end
    end

    love.graphics.setColor(headerColor)
    love.graphics.rectangle("fill", zone.x, zone.y, zone.width, Card.HEADER_HEIGHT)

    love.graphics.setColor(zoneColors.border)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", zone.x, zone.y, zone.width, zone.height)
    love.graphics.setLineWidth(2)
    love.graphics.line(zone.x, zone.y + Card.HEADER_HEIGHT, zone.x + zone.width, zone.y + Card.HEADER_HEIGHT)

    love.graphics.setFont(Theme.fonts.cardHeader)
    love.graphics.setColor(zoneColors.text)
    love.graphics.printf(
        "Business Consulting",
        zone.x,
        zone.y + 5,
        zone.width * viewportScale,
        "center",
        0,
        1 / viewportScale,
        1 / viewportScale
    )

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

local function spawnHighValueOpportunityCard()
    local zone = getConsultingRect()
    local targetGameX = zone.x + zone.width + 56
    local targetGameY = zone.y - BOOSTER_PACK_HEIGHT - 22
    local startGameX = zone.x + (zone.width - BOOSTER_PACK_WIDTH) * 0.5
    local startGameY = zone.y + (zone.height - BOOSTER_PACK_HEIGHT) * 0.5

    local worldTargetX, worldTargetY = gameToWorld(targetGameX, targetGameY)
    local worldStartX, worldStartY = gameToWorld(startGameX, startGameY)
    local targetX = clamp(worldTargetX, 0, WORLD_WIDTH - BOOSTER_PACK_WIDTH)
    local targetY = clamp(worldTargetY, 0, WORLD_HEIGHT - BOOSTER_PACK_HEIGHT)

    local startX = clamp(worldStartX, 0, WORLD_WIDTH - BOOSTER_PACK_WIDTH)
    local startY = clamp(worldStartY, 0, WORLD_HEIGHT - BOOSTER_PACK_HEIGHT)

    local opportunityCard = createBoosterPack({
        cardType = "opportunity",
        title = "Actionable Insights",
        insightsRemaining = OPPORTUNITY_CLICK_LIMIT,
        x = startX,
        y = startY,
        targetX = startX,
        targetY = startY,
    })

    opportunityCard.motionState = createSideBounceMotion(
        startX,
        startY,
        targetX,
        targetY,
        {
            duration = 0.52,
            restHold = 0.04,
            arcHeights = { 30, 18, 0 },
            arcSplits = { 0.45, 0.78 },
            xSplits = { 0.62, 0.86 },
            tilt = 0.09,
        }
    )

    table.insert(cards, opportunityCard)
    bringCardsToFront({ opportunityCard })
    return opportunityCard
end

consumeMoneyAtConsulting = function(card)
    if not isConsultingDropCandidate(card) then
        return false
    end

    if not isCardCenterInsideRect(card, getConsultingRect()) then
        return false
    end

    removeCardInstance(card)
    spawnHighValueOpportunityCard()
    return true
end

local function isOpportunityClickable(card)
    return card ~= nil
        and card.cardType == "opportunity"
        and not card.motionState
        and not card.shipState
        and not card.stackParentId
        and (card.insightsRemaining or 0) > 0
end

local function triggerOpportunityClick(opportunityCard)
    if not opportunityCard or not isOpportunityClickable(opportunityCard) then
        return
    end

    triggerOpportunityWobble(opportunityCard)

    local sourceWidth = opportunityCard.width or CARD_WIDTH
    local sourceHeight = opportunityCard.height or CARD_HEIGHT
    local originX = clamp(opportunityCard.x, 0, WORLD_WIDTH - sourceWidth)
    local originY = clamp(opportunityCard.y, 0, WORLD_HEIGHT - sourceHeight)

    local burstTargets = {
        { dx = -220, dy = -110 },
        { dx = 0,    dy = -185 },
        { dx = 220,  dy = -110 },
    }

    local remaining = math.max(0, math.floor(opportunityCard.insightsRemaining or 0))
    local clickIndex = OPPORTUNITY_CLICK_LIMIT - remaining + 1
    local burst = burstTargets[math.min(math.max(clickIndex, 1), #burstTargets)]
    local targetX = clamp(originX + burst.dx, 0, WORLD_WIDTH - CARD_WIDTH)
    local targetY = clamp(originY + burst.dy, 0, WORLD_HEIGHT - CARD_HEIGHT)

    local quickWinCard = createCard({
        cardType = "feature",
        title = "Quick Win",
        costTotal = 2,
        costRemaining = 2,
        value = 1,
        x = originX,
        y = originY,
        targetX = originX,
        targetY = originY,
    })

    quickWinCard.motionState = createSideBounceMotion(originX, originY, targetX, targetY)
    table.insert(cards, quickWinCard)

    opportunityCard.insightsRemaining = remaining - 1
    if opportunityCard.insightsRemaining <= 0 then
        removeCardInstance(opportunityCard)
        bringCardsToFront({ quickWinCard })
    else
        bringCardsToFront({ opportunityCard, quickWinCard })
    end
end

local function configureHotReload()
    HotReload.getState = function()
        serializeCards()
        state.camera = {
            x = camera.x,
            y = camera.y,
            zoom = camera.zoom,
        }
        return copyState(state)
    end

    HotReload.setState = function(saved)
        if type(saved) ~= "table" then
            return
        end

        local restored = copyState(saved)

        state.time = restored.time or 0
        state.day = restored.day or 1
        state.nextCardId = restored.nextCardId or 1
        state.camera = restored.camera

        if type(restored.cards) == "table" then
            state.cards = restored.cards
        else
            state.cards = nil
        end

        if type(state.camera) == "table" then
            camera.x = tonumber(state.camera.x) or camera.x
            camera.y = tonumber(state.camera.y) or camera.y
            camera.zoom = clamp(tonumber(state.camera.zoom) or camera.zoom, camera.minZoom, camera.maxZoom)
            clampCamera()
        end

        bootstrapCards()
        draggingCards = {}
        dragRootCard = nil
        stickyDragMode = false
        dragPressStartScreenX = nil
        dragPressStartScreenY = nil
        panningWorld = false
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
        barColor = Theme.colors.letterbox,
    })

    Theme.load(Scaling.getScale())

    if not isReload then
        state.time = 0
        state.day = 1
        state.nextCardId = 1
        state.cards = nil
        state.camera = nil
    end

    bootstrapCards()

    if type(state.camera) == "table" then
        camera.x = tonumber(state.camera.x) or camera.x
        camera.y = tonumber(state.camera.y) or camera.y
        camera.zoom = clamp(tonumber(state.camera.zoom) or camera.zoom, camera.minZoom, camera.maxZoom)
    else
        camera.zoom = 1
        setCameraCenteredOn(WORLD_WIDTH * 0.5, WORLD_HEIGHT * 0.5)
    end
    clampCamera()

    draggingCards = {}
    dragRootCard = nil
    stickyDragMode = false
    dragPressStartScreenX = nil
    dragPressStartScreenY = nil
    panningWorld = false
    consultingHover = 0

    configureHotReload()
end

function love.update(dt)
    state.time = state.time + dt

    local mouseX, mouseY = love.mouse.getPosition()
    local gameX, gameY = screenToGame(mouseX, mouseY)
    local worldX, worldY = gameToWorld(gameX, gameY)

    local consultingRect = getConsultingRect()
    local consultingHovered = gameX and gameY and pointInRect(gameX, gameY, consultingRect) or false
    local consultingRaised = consultingHovered or isConsultingDropActive()
    consultingHover = damp(consultingHover, consultingRaised and 1 or 0, 18, dt)

    updateAttachedCardTargets()
    updateWorkerProgress(dt)

    for _, card in ipairs(cards) do
        if not card.motionState then
            local pointerX = nil
            local pointerY = nil
            if card:isDragging() then
                pointerX = worldX
                pointerY = worldY
            end
            card:update(dt, pointerX, pointerY)
        end
    end

    updatePhysicalCardMotions(dt)

    state.camera = {
        x = camera.x,
        y = camera.y,
        zoom = camera.zoom,
    }
    serializeCards()
    HotReload:update(dt)
end

function love.draw()
    Scaling.draw(function()
        local mouseX, mouseY = love.mouse.getPosition()
        local gameX, gameY = screenToGame(mouseX, mouseY)
        local worldX, worldY = gameToWorld(gameX, gameY)
        local hoveredPersonCard = getTopHoveredPersonCard(worldX, worldY)
        local consultingRect = getConsultingRect()
        local consultingHovered = gameX and gameY and pointInRect(gameX, gameY, consultingRect) or false

        love.graphics.push()
        love.graphics.scale(camera.zoom, camera.zoom)
        love.graphics.translate(-camera.x, -camera.y)

        drawPaperGrid()

        for _, card in ipairs(cards) do
            if not isCardDragging(card) then
                drawCardWithEffects(card)
            end
        end

        drawWorkBars()
        drawPersonHoverOverlay(hoveredPersonCard)
        drawDragStackShadow()

        for _, card in ipairs(cards) do
            if isCardDragging(card) then
                drawCardWithEffects(card, { skipShadow = card.cardType ~= "opportunity" })
            end
        end

        love.graphics.pop()

        drawConsultingZone(gameX, gameY)
        if consultingHovered then
            drawConsultingHoverOverlay(consultingRect)
        end
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

    if pointInRect(gameX, gameY, getNewDayButtonRect()) then
        startNewDay()
        return
    end

    if pointInRect(gameX, gameY, getConsultingRect()) then
        return
    end

    local worldX, worldY = gameToWorld(gameX, gameY)
    local selectedCard = nil
    for i = #cards, 1, -1 do
        local card = cards[i]
        if not isCardLocked(card) and card:containsPoint(worldX, worldY) then
            selectedCard = card
            break
        end
    end

    if not selectedCard then
        panningWorld = true
        return
    end

    local selection = { selectedCard }
    if selectedCard:containsHeaderPoint(worldX, worldY) then
        selection = collectStackFrom(selectedCard)
    end

    bringCardsToFront(selection)
    beginDragSelection(selection, worldX, worldY)
    stickyDragMode = false
    dragPressStartScreenX = x
    dragPressStartScreenY = y
    panningWorld = false
end

function love.mousereleased(x, y, button)
    if button ~= 1 then
        return
    end

    if panningWorld then
        panningWorld = false
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
        local rootCard = dragRootCard or draggingCards[1]
        if isOpportunityClickable(rootCard) then
            for _, card in ipairs(draggingCards) do
                card:endDrag()
            end
            draggingCards = {}
            dragRootCard = nil
            stickyDragMode = false
            triggerOpportunityClick(rootCard)
        else
            stickyDragMode = true
        end
    end

    dragPressStartScreenX = nil
    dragPressStartScreenY = nil
end

function love.mousemoved(_, _, dx, dy)
    if not panningWorld then
        return
    end

    if not love.mouse.isDown(1) then
        panningWorld = false
        return
    end

    local viewportScale = Scaling.getScale()
    if viewportScale <= 0 then
        viewportScale = 1
    end

    local gameDx = dx / viewportScale
    local gameDy = dy / viewportScale
    camera.x = camera.x - (gameDx / camera.zoom)
    camera.y = camera.y - (gameDy / camera.zoom)
    clampCamera()
end

function love.wheelmoved(_, y)
    if y == 0 then
        return
    end

    local mouseX, mouseY = love.mouse.getPosition()
    local gameX, gameY = screenToGame(mouseX, mouseY)
    local anchorGameX = gameX or (APP_WIDTH * 0.5)
    local anchorGameY = gameY or (APP_HEIGHT * 0.5)
    local anchorWorldX, anchorWorldY = gameToWorld(anchorGameX, anchorGameY)

    local targetZoom = camera.zoom * (camera.zoomStep ^ y)
    targetZoom = clamp(targetZoom, camera.minZoom, camera.maxZoom)
    if targetZoom == camera.zoom then
        return
    end

    camera.zoom = targetZoom
    camera.x = anchorWorldX - (anchorGameX / camera.zoom)
    camera.y = anchorWorldY - (anchorGameY / camera.zoom)
    clampCamera()
end
