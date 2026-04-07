local HotReload = require("src.core.hot_reload")
local Scaling = require("src.core.scaling")
local Theme = require("src.ui.theme")
local Card = require("src.ui.card")
local BoosterPack = require("src.ui.booster_pack")
local UiPanel = require("src.ui.ui_panel")
local UiShadow = require("src.ui.ui_shadow")
local CardDefs = require("src.core.card_defs")
local Recipes = require("src.core.recipes")
local Sprint = require("src.core.sprint")
local Hud = require("src.ui.hud")

local APP_WIDTH = 1920
local APP_HEIGHT = 1080
local WORLD_WIDTH = APP_WIDTH * 2
local WORLD_HEIGHT = APP_HEIGHT * 2

local CARD_BODY_ASPECT_WIDTH = 300
local CARD_BODY_ASPECT_HEIGHT = 280
local CARD_WIDTH = 150
local CARD_BODY_HEIGHT = math.floor((CARD_WIDTH * CARD_BODY_ASPECT_HEIGHT / CARD_BODY_ASPECT_WIDTH) + 0.5)
local CARD_HEIGHT = (Card.HEADER_HEIGHT or 34) + CARD_BODY_HEIGHT
local BOOSTER_PACK_WIDTH_SCALE = 1.265
local BOOSTER_PACK_ASPECT = 1280 / 1024

local STACK_OFFSET_Y = (Card.HEADER_HEIGHT or 34) - 14
local STACK_SNAP_DISTANCE = 80
local CLICK_ATTACH_THRESHOLD = 6

-- Grid layout for starting cards
local GRID_ORIGIN_X = WORLD_WIDTH * 0.28
local GRID_ORIGIN_Y = WORLD_HEIGHT * 0.34
local GRID_COL_SPACING = CARD_WIDTH + 70
local GRID_ROW_SPACING = CARD_HEIGHT + 28

-- Coffee Machine passive
local COFFEE_MACHINE_INTERVAL = 20
local COFFEE_MAX_ON_BOARD = 2

-- Hire Market / Business Opportunity
local HIRE_MARKET_COST = 3
local BUSINESS_OPP_COST = 2

-- Asset paths
local OFFICE_BACKGROUND_PATH = "assets/handdrawn/officebg.png"
local MONEY_SMALL_ICON_PATH = "assets/handdrawn/smallIcons/moneySmall.png"
local CIRCLE_BG_ICON_PATH = "assets/handdrawn/ui/circleBig.png"
local BOOSTER_ICON_PATH = "assets/handdrawn/cardIcons/star.png"
local BOOSTER_ICON_CIRCLE_PATH = "assets/handdrawn/ui/circleBig.png"

local WORK_BAR_HEIGHT    = 28
local WORK_BAR_FILL_MARGIN_X = 6
local WORK_BAR_FILL_MARGIN_Y = 7
local WORK_BAR_FILL_RADIUS = 8
local WORK_BAR_FILL_RIGHT_TRIM = 4
local CARD_ADDON_GAP     = 3   -- gap: card→bar, bar→tooltip
local TOOLTIP_MIN_HEIGHT = 36
local TOOLTIP_PADDING_X  = 14
local TOOLTIP_PADDING_Y  = 12
local DRAG_FOCUS_PULSE_SPEED = 3.2
local DRAG_FOCUS_DIM_PULSE_SPEED = 2.1

-- ── Module-level state ────────────────────────────────────────────────────────

local state = {
    time = 0,
    nextCardId = 1,
    cards = nil,
    camera = nil,
    sprint = nil,
    gameState = nil,
}

local gameState = {
    money = 3, -- starts with 3 money cards
    bugCount = 0,
    burnoutCount = 0,
    hireCount = 0, -- number of hires from Hire Market so far
}

local camera = {
    x = 0,
    y = 0,
    zoom = 1,
    minZoom = 0.65,
    maxZoom = 1.9,
    zoomStep = 1.12,
}

local cards = {}
local draggingCards = {}
local dragRootCard = nil
local stickyDragMode = false
local dragPressStartScreenX = nil
local dragPressStartScreenY = nil
local panningWorld = false

local coffeeMachineTimer = 0

local officeBackgroundImage = nil
local officeBackgroundLoadAttempted = false
local moneyIconImage = nil
local moneyIconLoadAttempted = false
local coverQuadCache = setmetatable({}, { __mode = "k" })

-- Forward declarations
local createSideBounceMotion
local clampCamera
local gameToWorld
local worldToGame
local spawnCard
local removeCardInstance
local countCardsByType
local spawnBurnoutForWorker
local addMoney
local spendMoney
local spawnMoneyCards
local removeMoneyCards
local createBoosterPackUiTest

-- ── Helper functions ──────────────────────────────────────────────────────────

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

local function setColorWithAlpha(color, alphaMultiplier)
    local alpha = (color[4] or 1) * (alphaMultiplier or 1)
    love.graphics.setColor(color[1], color[2], color[3], alpha)
end

local function getOfficeBackgroundImage()
    if officeBackgroundImage or officeBackgroundLoadAttempted then
        return officeBackgroundImage
    end
    officeBackgroundLoadAttempted = true
    local ok, img = pcall(love.graphics.newImage, OFFICE_BACKGROUND_PATH)
    if not ok then return nil end
    img:setFilter("linear", "linear")
    officeBackgroundImage = img
    return officeBackgroundImage
end

local function getMoneyIconImage()
    if moneyIconImage or moneyIconLoadAttempted then
        return moneyIconImage
    end
    moneyIconLoadAttempted = true
    local ok, img = pcall(love.graphics.newImage, MONEY_SMALL_ICON_PATH)
    if not ok then return nil end
    img:setFilter("linear", "linear")
    moneyIconImage = img
    return moneyIconImage
end

local function drawImageCover(image, x, y, width, height)
    local imageWidth = image:getWidth()
    local imageHeight = image:getHeight()
    if imageWidth <= 0 or imageHeight <= 0 or width <= 0 or height <= 0 then return end
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
    love.graphics.draw(image, quad, x, y, 0, width / sourceWidth, height / sourceHeight)
end

local function getCameraViewSize()
    local zoom = camera.zoom
    if zoom <= 0 then zoom = 1 end
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
    if gameX == nil or gameY == nil then return nil, nil end
    local zoom = camera.zoom
    if zoom <= 0 then zoom = 1 end
    return camera.x + (gameX / zoom), camera.y + (gameY / zoom)
end

worldToGame = function(worldX, worldY)
    if worldX == nil or worldY == nil then return nil, nil end
    local zoom = camera.zoom
    if zoom <= 0 then zoom = 1 end
    return (worldX - camera.x) * zoom, (worldY - camera.y) * zoom
end

local function copyState(value)
    if type(value) ~= "table" then return value end
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
    if cardId == nil then return nil end
    for _, card in ipairs(cards) do
        if card.id == cardId then return card end
    end
    return nil
end

local function isCardDragging(cardToFind)
    for _, card in ipairs(draggingCards) do
        if card == cardToFind then return true end
    end
    return false
end

local function isCardLocked(card)
    return card ~= nil and (card.shipState ~= nil or card.motionState ~= nil)
end

local function bringCardsToFront(cardsToRaise)
    local selected = {}
    for _, card in ipairs(cardsToRaise) do selected[card] = true end
    local reordered = {}
    for _, card in ipairs(cards) do
        if not selected[card] then table.insert(reordered, card) end
    end
    for _, card in ipairs(cards) do
        if selected[card] then table.insert(reordered, card) end
    end
    cards = reordered
end

removeCardInstance = function(cardToRemove)
    if not cardToRemove then return end
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
    if dragRootCard == cardToRemove then dragRootCard = nil end
    for _, other in ipairs(cards) do
        if other.stackParentId == cardToRemove.id then
            other.stackParentId = nil
        end
        if other.recipePartnerId == cardToRemove.id then
            other.recipePartnerId = nil
            other.recipeActive = false
            other.recipeElapsed = 0
        end
    end
end

local function getDirectChild(parentCard, excludedCards)
    for _, candidate in ipairs(cards) do
        if candidate.stackParentId == parentCard.id
            and not (excludedCards and excludedCards[candidate]) then
            return candidate
        end
    end
    return nil
end

local function isDescendant(card, potentialAncestor)
    local current = card
    while current and current.stackParentId do
        local parent = getCardById(current.stackParentId)
        if not parent then return false end
        if parent == potentialAncestor then return true end
        current = parent
    end
    return false
end

local function collectStackFrom(card)
    local selected = {}
    local function collectFrom(root)
        table.insert(selected, root)
        for _, candidate in ipairs(cards) do
            if candidate.stackParentId == root.id then collectFrom(candidate) end
        end
    end
    collectFrom(card)
    return selected
end

countCardsByType = function(cardType, subType)
    local count = 0
    for _, card in ipairs(cards) do
        if card.cardType == cardType then
            if subType == nil or card.subType == subType then
                count = count + 1
            end
        end
    end
    return count
end

-- Count how many money cards are in a chain starting at this card's child
local function countMoneyChainOnCard(parentCard)
    local count = 0
    local current = parentCard
    while current do
        local child = getDirectChild(current, nil)
        if child and child.cardType == "money" then
            count = count + 1
            current = child
        else
            break
        end
    end
    return count
end

-- Collect money chain starting from direct child
local function collectMoneyChainOnCard(parentCard)
    local result = {}
    local current = parentCard
    while current do
        local child = getDirectChild(current, nil)
        if child and child.cardType == "money" then
            table.insert(result, child)
            current = child
        else
            break
        end
    end
    return result
end

-- Spawn money cards near a position (used by sprint cashout)
spawnMoneyCards = function(amount, worldX, worldY)
    for i = 1, math.max(0, amount) do
        local mx = clamp((worldX or WORLD_WIDTH * 0.5) + (i - 1) * 22, 0, WORLD_WIDTH - CARD_WIDTH)
        local my = clamp((worldY or WORLD_HEIGHT * 0.4), 0, WORLD_HEIGHT - CARD_HEIGHT)
        local mc = spawnCard("money", mx, my, { moneyAmount = 1 })
        mc.motionState = createSideBounceMotion(mx, my, clamp(mx + 70, 0, WORLD_WIDTH - CARD_WIDTH), my)
    end
end

-- Remove money cards from board, consuming up to `amount` money units.
-- Returns true if fully paid, false if bankrupt.
removeMoneyCards = function(amount)
    local moneyCards = {}
    for _, card in ipairs(cards) do
        if card.cardType == "money" then
            table.insert(moneyCards, card)
        end
    end
    -- Check if we have enough
    local total = 0
    for _, mc in ipairs(moneyCards) do total = total + (mc.moneyAmount or 1) end
    if total < amount then
        -- Remove all money (bankrupt)
        for _, mc in ipairs(moneyCards) do removeCardInstance(mc) end
        return false
    end
    -- Remove cards until we've covered the amount
    local removed = 0
    for _, mc in ipairs(moneyCards) do
        if removed >= amount then break end
        removed = removed + (mc.moneyAmount or 1)
        removeCardInstance(mc)
    end
    return true
end

addMoney = function(amount)
    spawnMoneyCards(amount, WORLD_WIDTH * 0.5, WORLD_HEIGHT * 0.4)
end

spendMoney = function(amount)
    return removeMoneyCards(amount)
end

-- ── Card creation ─────────────────────────────────────────────────────────────

local function createCard(config)
    return Card.new({
        id = config.id or allocateCardId(),
        cardType = config.cardType,
        role = config.role,
        subType = config.subType,
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
        maxFocus = config.maxFocus,
        focus = config.focus,
        recipeActive = config.recipeActive,
        recipeElapsed = config.recipeElapsed,
        recipeDuration = config.recipeDuration,
        recipePartnerId = config.recipePartnerId,
        hasDeadline = config.hasDeadline,
        ownerWorkerId = config.ownerWorkerId,
        stackParentId = config.stackParentId,
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

local function createBoardObject(config)
    if type(config) == "table" and config.objectType == "booster_pack" then
        return BoosterPack.new({
            id = config.id or allocateCardId(),
            objectType = config.objectType,
            cardType = config.cardType,
            role = config.role,
            subType = config.subType,
            effect = config.effect,
            x = config.x,
            y = config.y,
            targetX = config.targetX,
            targetY = config.targetY,
            width = config.width,
            height = config.height,
            worldWidth = WORLD_WIDTH,
            worldHeight = WORLD_HEIGHT,
            topText = config.topText,
            bottomText = config.bottomText,
            iconPath = config.iconPath,
            iconCirclePath = config.iconCirclePath,
            backgroundColor = config.backgroundColor,
            borderColor = config.borderColor,
            textColor = config.textColor,
            iconColor = config.iconColor,
            iconCircleColor = config.iconCircleColor,
        })
    end
    return createCard(config)
end

-- Spawn a card by def key at world position, with optional overrides
spawnCard = function(defKey, worldX, worldY, overrides)
    local config = CardDefs.createConfig(defKey, overrides or {})
    config.x = clamp(worldX or 0, 0, WORLD_WIDTH - CARD_WIDTH)
    config.y = clamp(worldY or 0, 0, WORLD_HEIGHT - CARD_HEIGHT)
    config.targetX = config.x
    config.targetY = config.y
    local card = createCard(config)
    table.insert(cards, card)
    return card
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
        for key, value in pairs(config) do motion[key] = value end
    end
    return motion
end

-- Spawn a Burnout card near the burned-out worker
spawnBurnoutForWorker = function(workerCard)
    if not workerCard then return end
    workerCard.isBurnedOut = true
    local bx = clamp(workerCard.x - 30, 0, WORLD_WIDTH - CARD_WIDTH)
    local by = clamp(workerCard.y - CARD_HEIGHT - 20, 0, WORLD_HEIGHT - CARD_HEIGHT)
    local burnoutCard = spawnCard("burnout", bx, by, {
        ownerWorkerId = workerCard.id,
        title = "Burnout",
        effect = workerCard.title .. " is burned out",
    })
    burnoutCard.motionState = createSideBounceMotion(
        workerCard.x, workerCard.y,
        clamp(bx, 0, WORLD_WIDTH - CARD_WIDTH),
        clamp(by, 0, WORLD_HEIGHT - CARD_HEIGHT)
    )
    bringCardsToFront({ burnoutCard })
end

-- ── Starting board ────────────────────────────────────────────────────────────

local function createStartingCards()
    local result = {}
    for _, entry in ipairs(CardDefs.STARTING_LAYOUT) do
        local wx = GRID_ORIGIN_X + entry.col * GRID_COL_SPACING
        local wy = GRID_ORIGIN_Y + entry.row * GRID_ROW_SPACING
        wx = clamp(wx, 0, WORLD_WIDTH - CARD_WIDTH)
        wy = clamp(wy, 0, WORLD_HEIGHT - CARD_HEIGHT)
        local config = CardDefs.createConfig(entry.defKey, { x = wx, y = wy, targetX = wx, targetY = wy })
        local card = createCard(config)
        table.insert(result, card)
    end

    table.insert(result, createBoardObject(createBoosterPackUiTest()))
    return result
end

local function restoreCardsFromSnapshot(cardSnapshots)
    local restoredCards = {}
    local maxId = 0
    for _, snapshot in ipairs(cardSnapshots) do
        local restored = createBoardObject(snapshot)
        table.insert(restoredCards, restored)
        if restored.id and restored.id > maxId then maxId = restored.id end
    end
    if maxId >= (state.nextCardId or 1) then
        state.nextCardId = maxId + 1
    end
    return restoredCards
end

local function bootstrapCards()
    if type(state.cards) == "table" then
        cards = restoreCardsFromSnapshot(state.cards)
    else
        cards = createStartingCards()
    end

    local hasBoosterPack = false
    for _, card in ipairs(cards) do
        if card.objectType == "booster_pack" then
            hasBoosterPack = true
            break
        end
    end
    if not hasBoosterPack then
        table.insert(cards, createBoardObject(createBoosterPackUiTest()))
    end
end

createBoosterPackUiTest = function()
    local boosterWidth = math.floor((CARD_WIDTH * BOOSTER_PACK_WIDTH_SCALE) + 0.5)
    local boosterHeight = math.floor((boosterWidth * BOOSTER_PACK_ASPECT) + 0.5)
    local x = clamp(GRID_ORIGIN_X + (GRID_COL_SPACING * 4.1), 0, WORLD_WIDTH - boosterWidth)
    local y = clamp(GRID_ORIGIN_Y + (GRID_ROW_SPACING * 0.1), 0, WORLD_HEIGHT - boosterHeight)
    local borderColor = Theme.cardStyles and Theme.cardStyles.default and Theme.cardStyles.default.borderColor

    return {
        objectType = "booster_pack",
        cardType = "booster_pack",
        x = x,
        y = y,
        targetX = x,
        targetY = y,
        width = boosterWidth,
        height = boosterHeight,
        topText = "Feature",
        bottomText = "Ideas",
        iconPath = BOOSTER_ICON_PATH,
        iconCirclePath = BOOSTER_ICON_CIRCLE_PATH,
        backgroundColor = { 0.78, 0.91, 1.0, 1.0 },
        borderColor = borderColor or Theme.colors.borderStrong,
        textColor = Theme.colors.textPrimary,
        iconColor = Theme.colors.icon,
        iconCircleColor = { 0.58, 0.76, 0.95, 1.0 },
    }
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

-- ── Stacking / snap rules ─────────────────────────────────────────────────────

local function canAttachCard(cardToSnap, targetCard, excludedCards)
    if not cardToSnap or not targetCard then return false end
    if cardToSnap == targetCard then return false end
    if isCardLocked(cardToSnap) or isCardLocked(targetCard) then return false end
    if isDescendant(targetCard, cardToSnap) then return false end
    if cardToSnap.objectType == "booster_pack" or targetCard.objectType == "booster_pack" then return false end

    -- Person cards can never stack on anything
    if cardToSnap.cardType == "person" then return false end

    -- Money stacks on money (keep existing)
    if cardToSnap.cardType == "money" and targetCard.cardType == "money" then
        local existingChild = getDirectChild(targetCard, excludedCards)
        if existingChild and existingChild ~= cardToSnap then return false end
        return true
    end

    -- Money stacks on hire_market and business_opportunity only
    if cardToSnap.cardType == "money" and targetCard.cardType == "infrastructure" then
        if targetCard.role ~= "hire_market" and targetCard.role ~= "business_opportunity" then
            return false
        end
        local existingChild = getDirectChild(targetCard, excludedCards)
        if existingChild and existingChild ~= cardToSnap then return false end
        return true
    end

    -- Coffee can stack on a person (to restore focus) — bypasses the one-child rule
    if cardToSnap.cardType == "coffee" and targetCard.cardType == "person" then
        if targetCard.recipeActive then return false end
        return true
    end

    -- Burnout can stack on a coffee card (player drops burnout on coffee to clear it)
    if cardToSnap.cardType == "burnout" and targetCard.cardType == "coffee" then
        local existingChild = getDirectChild(targetCard, excludedCards)
        if existingChild and existingChild ~= cardToSnap then return false end
        return true
    end

    -- Burnout cannot stack on anything else
    if cardToSnap.cardType == "burnout" then return false end
    -- Deadline cannot be manually stacked (attached by sprint logic only)
    if cardToSnap.cardType == "deadline" then return false end
    -- Infrastructure cannot stack on anything
    if cardToSnap.cardType == "infrastructure" then return false end

    -- Reject if either card is already mid-recipe
    if cardToSnap.recipeActive then return false end
    if targetCard.recipeActive then return false end

    -- Check if a recipe exists for this pair
    local recipe = Recipes.findMatch(targetCard, cardToSnap, cards)
    if recipe then
        -- Don't allow a second work item on a person who already has one
        if targetCard.cardType == "person" then
            local existingChild = getDirectChild(targetCard, excludedCards)
            if existingChild and existingChild ~= cardToSnap then return false end
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
                    best = { parent = other, x = snapX, y = snapY }
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
    for _, card in ipairs(selection) do selectedById[card.id] = true end

    for _, card in ipairs(selection) do
        if card.stackParentId and not selectedById[card.stackParentId] then
            -- Cancel recipe if this card is in an active recipe
            if card.recipeActive or card.recipePartnerId then
                Recipes.cancelRecipe(card, cards)
            end
            card.stackParentId = nil
        end
    end

    for _, card in ipairs(cards) do
        if card.stackParentId and selectedById[card.stackParentId] and not selectedById[card.id] then
            if card.recipeActive or card.recipePartnerId then
                Recipes.cancelRecipe(card, cards)
            end
            card.stackParentId = nil
        end
    end

    for _, card in ipairs(selection) do
        card:beginDrag(pointerX, pointerY, true)
    end
end

local function endDragSelection()
    if #draggingCards == 0 then return end

    local rootCard = dragRootCard or draggingCards[1]

    for _, card in ipairs(draggingCards) do
        card:endDrag()
    end

    local excludedCards = {}
    for _, card in ipairs(draggingCards) do excludedCards[card] = true end

    local beforeSnapX = rootCard.targetX
    local beforeSnapY = rootCard.targetY

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

-- ── Recipe system update ──────────────────────────────────────────────────────

-- Build the sprint callbacks table (used by Sprint and Recipes)
local function makeCallbacks()
    return {
        spawnCard = function(defKey, x, y, overrides)
            return spawnCard(defKey, x, y, overrides)
        end,
        removeCard = function(card)
            removeCardInstance(card)
        end,
        getCardById = function(id)
            return getCardById(id)
        end,
        getAllCards = function()
            return cards
        end,
        countCardsByType = function(cardType, subType)
            return countCardsByType(cardType, subType)
        end,
        getSalaryCost = function(card)
            return CardDefs.getSalaryCost(card)
        end,
        addMoney = function(amount, x, y)
            spawnMoneyCards(amount, x, y)
        end,
        spendMoney = function(amount)
            return removeMoneyCards(amount)
        end,
        spawnBurnoutForWorker = function(workerCard)
            spawnBurnoutForWorker(workerCard)
        end,
        onMajorFeatureShipped = function()
            Sprint.recordMajorFeatureShipped()
        end,
    }
end

local function updateRecipes(dt)
    -- Check for newly stacked pairs that should start a recipe
    for _, childCard in ipairs(cards) do
        if childCard.stackParentId and not childCard.recipeActive then
            -- Skip types that can never be recipe children
            if childCard.cardType ~= "money" and childCard.cardType ~= "person"
                and childCard.cardType ~= "infrastructure" and childCard.cardType ~= "deadline"
                and childCard.cardType ~= "shipped" then
                -- Note: coffee and burnout CAN be recipe children (dropped on workers/coffee)
                local parentCard = getCardById(childCard.stackParentId)
                if parentCard and not parentCard.recipeActive and not isCardLocked(childCard) and not isCardLocked(parentCard) then
                    local recipe = Recipes.findMatch(parentCard, childCard, cards)
                    if recipe then
                        Recipes.startRecipe(parentCard, childCard, recipe, cards)
                        if recipe.instantComplete then
                            -- Instant recipe: complete immediately
                            local callbacks = makeCallbacks()
                            Recipes.complete(parentCard, childCard, recipe, cards, callbacks)
                        end
                    end
                end
            end
        end
    end

    -- Advance active recipes
    local toComplete = {}
    for _, childCard in ipairs(cards) do
        if childCard.recipeActive then
            childCard.recipeElapsed = (childCard.recipeElapsed or 0) + dt

            if childCard.recipeElapsed >= (childCard.recipeDuration or 0) then
                local parentCard = getCardById(childCard.recipePartnerId)
                if parentCard then
                    table.insert(toComplete, { parent = parentCard, child = childCard })
                else
                    -- Parent gone (removed) — cancel
                    Recipes.cancelRecipe(childCard, cards)
                end
            end
        end
    end

    -- Complete recipes outside the iteration loop
    local callbacks = makeCallbacks()
    for _, pair in ipairs(toComplete) do
        -- Find the recipe again (need it for outputs)
        local recipe = Recipes.findMatch(pair.parent, pair.child, cards)
        if recipe then
            local result = Recipes.complete(pair.parent, pair.child, recipe, cards, callbacks)
            if result then
                -- Animate the output card with a bounce
                local settleX = clamp(pair.child.x + 90, 0, WORLD_WIDTH - CARD_WIDTH)
                local settleY = clamp(pair.child.y, 0, WORLD_HEIGHT - CARD_HEIGHT)
                result.motionState = createSideBounceMotion(
                    pair.child.x, pair.child.y, settleX, settleY
                )
                bringCardsToFront({ result })
            end
        end
    end
end

-- ── Coffee Machine passive ────────────────────────────────────────────────────

local function updateCoffeeMachine(dt)
    -- Find coffee machine card
    local machine = nil
    for _, card in ipairs(cards) do
        if card.role == "coffee_machine" then
            machine = card
            break
        end
    end
    if not machine then return end

    coffeeMachineTimer = coffeeMachineTimer + dt
    if coffeeMachineTimer >= COFFEE_MACHINE_INTERVAL then
        local coffeeOnBoard = countCardsByType("coffee")
        if coffeeOnBoard < COFFEE_MAX_ON_BOARD then
            coffeeMachineTimer = 0
            local cx = clamp(machine.x + CARD_WIDTH + 30, 0, WORLD_WIDTH - CARD_WIDTH)
            local cy = clamp(machine.y, 0, WORLD_HEIGHT - CARD_HEIGHT)
            local coffeeCard = spawnCard("coffee", machine.x, machine.y, {})
            coffeeCard.motionState = createSideBounceMotion(machine.x, machine.y, cx, cy)
            bringCardsToFront({ coffeeCard })
        end
    end
end

-- ── Hire Market and Business Opportunity ─────────────────────────────────────

local HIRE_SEQUENCE = { "backend_dev", "fullstack_dev" }
local HIRE_RANDOM_POOL = { "frontend_dev", "backend_dev", "qa_tester" }

local function triggerHireMarket(hireMarketCard)
    -- Consume 3 money cards from the chain on hire market
    local chain = collectMoneyChainOnCard(hireMarketCard)
    if #chain < HIRE_MARKET_COST then return end

    for i = 1, HIRE_MARKET_COST do
        removeCardInstance(chain[i])
    end
    spendMoney(HIRE_MARKET_COST)

    -- Determine which dev to hire
    local hireCount = gameState.hireCount or 0
    local defKey
    if hireCount < #HIRE_SEQUENCE then
        defKey = HIRE_SEQUENCE[hireCount + 1]
    else
        defKey = HIRE_RANDOM_POOL[math.random(#HIRE_RANDOM_POOL)]
    end
    gameState.hireCount = hireCount + 1

    local tx = clamp(hireMarketCard.x + CARD_WIDTH + 50, 0, WORLD_WIDTH - CARD_WIDTH)
    local ty = clamp(hireMarketCard.y, 0, WORLD_HEIGHT - CARD_HEIGHT)
    local newDev = spawnCard(defKey, hireMarketCard.x, hireMarketCard.y, {})
    newDev.motionState = createSideBounceMotion(hireMarketCard.x, hireMarketCard.y, tx, ty)
    bringCardsToFront({ newDev })

    if defKey == "backend_dev" then
        Sprint.recordBackendDevHired()
    end
end

local function triggerBusinessOpportunity(bizOppCard)
    -- Consume 2 money cards from chain
    local chain = collectMoneyChainOnCard(bizOppCard)
    if #chain < BUSINESS_OPP_COST then return end

    for i = 1, BUSINESS_OPP_COST do
        removeCardInstance(chain[i])
    end
    spendMoney(BUSINESS_OPP_COST)

    -- Spawn 2 client requests
    for i = 1, 2 do
        local cx = clamp(bizOppCard.x + (i - 1) * (CARD_WIDTH + 20) - CARD_WIDTH, 0, WORLD_WIDTH - CARD_WIDTH)
        local cy = clamp(bizOppCard.y - CARD_HEIGHT - 30, 0, WORLD_HEIGHT - CARD_HEIGHT)
        local req = spawnCard("client_request", bizOppCard.x, bizOppCard.y, {})
        req.motionState = createSideBounceMotion(bizOppCard.x, bizOppCard.y, cx, cy)
        bringCardsToFront({ req })
    end
end

local function checkInfrastructureTriggers()
    for _, card in ipairs(cards) do
        if card.cardType == "infrastructure" then
            local chain = collectMoneyChainOnCard(card)
            if card.role == "hire_market" and #chain >= HIRE_MARKET_COST then
                triggerHireMarket(card)
            elseif card.role == "business_opportunity" and #chain >= BUSINESS_OPP_COST then
                triggerBusinessOpportunity(card)
            end
        end
    end
end

-- ── Rendering helpers ─────────────────────────────────────────────────────────

local function drawOfficeBackground()
    local backgroundImage = getOfficeBackgroundImage()
    if backgroundImage then
        local bgTint = Theme.colors.background or { 1, 1, 1, 1 }
        local bgTintAlpha = 1
        setColorWithAlpha(bgTint, bgTintAlpha)
        drawImageCover(backgroundImage, 0, 0, WORLD_WIDTH, WORLD_HEIGHT)
        local washColor = Theme.colors.backgroundWash
        if washColor then
            setColorWithAlpha(washColor, 1)
            love.graphics.rectangle("fill", 0, 0, WORLD_WIDTH, WORLD_HEIGHT)
        end
        love.graphics.setColor(1, 1, 1, 1)
        return
    end
    local fallbackColor = Theme.colors.background
    love.graphics.setColor(fallbackColor[1], fallbackColor[2], fallbackColor[3], fallbackColor[4] or 1)
    love.graphics.rectangle("fill", 0, 0, WORLD_WIDTH, WORLD_HEIGHT)
    local washColor = Theme.colors.backgroundWash
    if washColor then
        setColorWithAlpha(washColor, 0.6)
        love.graphics.rectangle("fill", 0, 0, WORLD_WIDTH, WORLD_HEIGHT)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

local function collectDragInteractableTargets()
    if #draggingCards == 0 then return nil end

    local rootCard = dragRootCard or draggingCards[1]
    if not rootCard then return nil end
    if rootCard.objectType == "booster_pack" then return nil end

    local excludedCards = {}
    for _, card in ipairs(draggingCards) do
        excludedCards[card] = true
    end

    local targetSet = {}
    local targetList = {}
    for _, candidate in ipairs(cards) do
        if not excludedCards[candidate] and canAttachCard(rootCard, candidate, excludedCards) then
            targetSet[candidate] = true
            table.insert(targetList, candidate)
        end
    end

    if #targetList == 0 then
        return nil
    end

    return {
        root = rootCard,
        targets = targetSet,
        list = targetList,
    }
end

local function drawDragFocusBackdrop(strength)
    local focusColors = Theme.colors.dragFocus or {}
    local backdropColor = focusColors.backdrop or { 0.08, 0.1, 0.12, 0.18 }
    setColorWithAlpha(backdropColor, strength or 1)
    love.graphics.rectangle("fill", 0, 0, WORLD_WIDTH, WORLD_HEIGHT)
    love.graphics.setColor(1, 1, 1, 1)
end

local function drawDragTargetGlow(targetCards, glowStrength)
    if not targetCards or #targetCards == 0 then return end
    local strength = clamp(glowStrength or 1, 0, 1.25)
    local focusColors = Theme.colors.dragFocus or {}
    local pulse = 0.5 + (0.5 * math.sin((state.time or 0) * DRAG_FOCUS_PULSE_SPEED))
    local glowPrimary = focusColors.glowPrimary or Theme.palette.featureHeader
    local glowSecondary = focusColors.glowSecondary or Theme.palette.featureBody

    for _, card in ipairs(targetCards) do
        local outerPad = 40 + (pulse * 7)
        local midPad = 24 + (pulse * 5)
        local innerPad = 12 + (pulse * 3)

        UiPanel.drawSurface(
            card.x - outerPad,
            card.y - outerPad,
            card.width + (outerPad * 2),
            card.height + (outerPad * 2),
            glowPrimary,
            { alpha = (0.12 + (pulse * 0.05)) * strength }
        )

        UiPanel.drawSurface(
            card.x - midPad,
            card.y - midPad,
            card.width + (midPad * 2),
            card.height + (midPad * 2),
            glowSecondary,
            { alpha = (0.17 + (pulse * 0.08)) * strength }
        )

        UiPanel.drawSurface(
            card.x - innerPad,
            card.y - innerPad,
            card.width + (innerPad * 2),
            card.height + (innerPad * 2),
            glowPrimary,
            { alpha = (0.22 + (pulse * 0.1)) * strength }
        )

        UiPanel.drawBorder(
            card.x - 4,
            card.y - 4,
            card.width + 8,
            card.height + 8,
            glowSecondary,
            { alpha = (0.32 + (pulse * 0.11)) * strength }
        )
    end

    love.graphics.setColor(1, 1, 1, 1)
end

local function drawCardWithEffects(card, options)
    options = options or {}
    local drawOptions = {
        skipShadow = options.skipShadow,
        bodyFont = Theme.fonts.cardBody,
        valueFont = Theme.fonts.cardBody,
        alpha = (card.renderAlpha or 1) * (options.alphaMultiplier or 1),
    }
    card:draw(Theme.fonts.cardHeader, drawOptions)
end

local function drawDragStackShadow()
    if #draggingCards == 0 then return end
    if #draggingCards == 1 and draggingCards[1].objectType == "booster_pack" then
        return
    end
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local shadowSource = nil
    for _, card in ipairs(draggingCards) do
        if not shadowSource then shadowSource = card end
        local centerX = card.x + card.width * 0.5
        local centerY = card.y + card.height * 0.5
        local halfW = card.width * card.scale * 0.5
        local halfH = card.height * card.scale * 0.5
        if centerX - halfW < minX then minX = centerX - halfW end
        if centerY - halfH < minY then minY = centerY - halfH end
        if centerX + halfW > maxX then maxX = centerX + halfW end
        if centerY + halfH > maxY then maxY = centerY + halfH end
    end
    if not shadowSource then return end
    UiPanel.drawShadow(minX, minY, (maxX - minX), (maxY - minY), UiShadow.capture(shadowSource, "cardDrag"))
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

local function computeCapsuleFillRight(fillX, fillWidth, radius, progress)
    local p = clamp(progress or 0, 0, 1)
    if p <= 0 then return fillX end
    if p >= 1 then
        return fillX + fillWidth
    end

    local cap = math.min(math.max(0, radius), fillWidth * 0.5)
    return fillX + cap + (fillWidth - cap) * p
end

local function drawWorkBars(alphaMultiplier)
    local alpha = clamp(alphaMultiplier or 1, 0, 1)
    local workBarColors = Theme.colors.workBar
    for _, childCard in ipairs(cards) do
        if childCard.recipeActive and childCard.stackParentId then
            local parentCard = getCardById(childCard.stackParentId)
            if parentCard and not parentCard.motionState then
                local duration = math.max(0.001, childCard.recipeDuration or 1)
                local progress = clamp((childCard.recipeElapsed or 0) / duration, 0, 1)

                local barX = parentCard.x
                local stackTopY = math.min(parentCard.y, childCard.y)
                local barY = stackTopY - CARD_ADDON_GAP - WORK_BAR_HEIGHT
                UiPanel.drawSurface(barX, barY, CARD_WIDTH, WORK_BAR_HEIGHT, workBarColors.track, { alpha = alpha })

                -- Simple fill: plain rounded rect inside the static border.
                local fillX = barX + WORK_BAR_FILL_MARGIN_X
                local fillY = barY + WORK_BAR_FILL_MARGIN_Y
                local fillMaxWidth = math.max(0,
                    CARD_WIDTH - WORK_BAR_FILL_MARGIN_X * 2 - WORK_BAR_FILL_RIGHT_TRIM)
                local fillHeight = math.max(0, WORK_BAR_HEIGHT - WORK_BAR_FILL_MARGIN_Y * 2)
                if fillMaxWidth > 0 and fillHeight > 0 then
                    local radius = math.min(WORK_BAR_FILL_RADIUS, fillHeight * 0.5)
                    local fillColor = workBarColors.fill or workBarColors.border
                    local fillRight = computeCapsuleFillRight(fillX, fillMaxWidth, radius, progress)
                    local visibleWidth = fillRight - fillX
                    if visibleWidth > 0 then
                        local cap = math.min(radius, visibleWidth * 0.5)
                        local centerY = fillY + fillHeight * 0.5
                        local leftCenterX = fillX + cap
                        local rightCenterX = fillRight - cap
                        local bodyX = leftCenterX
                        local bodyWidth = rightCenterX - leftCenterX

                        setColorWithAlpha(fillColor, alpha)
                        love.graphics.circle("fill", leftCenterX, centerY, cap, 20)
                        if bodyWidth > 0 then
                            love.graphics.rectangle("fill", bodyX, fillY, bodyWidth, fillHeight)
                        end
                        love.graphics.circle("fill", rightCenterX, centerY, cap, 20)
                    end
                end

                UiPanel.drawBorder(barX, barY, CARD_WIDTH, WORK_BAR_HEIGHT, workBarColors.border, { alpha = alpha })
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Returns the top Y of the work bar for the given card's stack, or nil if none active
local function getActiveWorkBarY(card)
    if not card then return nil end
    -- Case A: card is the parent with an active child
    for _, c in ipairs(cards) do
        if c.recipeActive and c.stackParentId == card.id then
            local stackTopY = math.min(card.y, c.y)
            return stackTopY - CARD_ADDON_GAP - WORK_BAR_HEIGHT
        end
    end
    -- Case B: card is the active child
    if card.recipeActive and card.stackParentId then
        local parentCard = getCardById(card.stackParentId)
        if parentCard and not parentCard.motionState then
            local stackTopY = math.min(parentCard.y, card.y)
            return stackTopY - CARD_ADDON_GAP - WORK_BAR_HEIGHT
        end
    end
    return nil
end

-- Returns the topmost hovered card that has effect text (any type)
local function getTopHoveredCardWithEffect(worldX, worldY)
    if not worldX or not worldY then return nil end
    for i = #cards, 1, -1 do
        local card = cards[i]
        if card:containsPoint(worldX, worldY) then
            local effect = card.effect
            if effect and effect ~= "" then return card end
            return nil
        end
    end
    return nil
end

local function drawCardHoverOverlay(card)
    if not card then return end
    local effectText = card.effect
    if not effectText or effectText == "" then return end

    local viewportScale = Scaling.getScale()
    if viewportScale <= 0 then viewportScale = 1 end
    love.graphics.setFont(Theme.fonts.cardBody)
    local font = love.graphics.getFont()
    local textScale = 1 / viewportScale
    local textMaxWidth = math.max(1, card.width - TOOLTIP_PADDING_X * 2)
    local textWrapWidth = textMaxWidth * viewportScale
    local _, wrappedLines = font:getWrap(effectText, textWrapWidth)
    local lineCount = math.max(1, #wrappedLines)
    local textHeight = lineCount * font:getHeight() * textScale
    local overlayHeight = math.max(TOOLTIP_MIN_HEIGHT, TOOLTIP_PADDING_Y * 2 + textHeight)

    -- Anchor above work bar if present, otherwise above card top
    local workBarY = getActiveWorkBarY(card)
    local referenceY = workBarY ~= nil and workBarY or card.y
    local overlayY = math.max(8, referenceY - overlayHeight - CARD_ADDON_GAP)

    local hoverColors = Theme.colors.personHover
    local overlayX = card.x
    local textY = overlayY + math.max(TOOLTIP_PADDING_Y, (overlayHeight - textHeight) * 0.5)
    UiPanel.drawShadow(overlayX, overlayY, card.width, overlayHeight, UiShadow.get("tooltip"))
    UiPanel.drawPanel(overlayX, overlayY, card.width, overlayHeight, {
        bodyColor = hoverColors.fill,
        borderColor = hoverColors.border,
    })
    love.graphics.setColor(hoverColors.text)
    love.graphics.printf(effectText, overlayX + TOOLTIP_PADDING_X, textY,
        textWrapWidth, "center", 0, textScale, textScale)
    love.graphics.setColor(1, 1, 1, 1)
end

local function updatePhysicalCardMotions(dt)
    for _, card in ipairs(cards) do
        local motion = card.motionState
        if motion then
            card.dragging = false
            card.targetScale = 1
            UiShadow.applyRole(card, "cardMotion")

            if motion.kind ~= "sideBounce" then
                motion.kind = "sideBounce"
                motion.elapsed = motion.elapsed or 0
                motion.duration = motion.duration or 0.62
                motion.restHold = motion.restHold or 0.06
                motion.startX = motion.startX or card.x
                motion.startY = motion.startY or card.y
                motion.endX = motion.endX or card.x
                motion.endY = motion.endY or card.y
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
                lift = math.sin((progress / splitA) * math.pi) * (motion.arcHeights[1] or 38)
            elseif progress < splitB then
                lift = math.sin(((progress - splitA) / (splitB - splitA)) * math.pi) * (motion.arcHeights[2] or 24)
            elseif progress < 1 then
                lift = math.sin(((progress - splitB) / (1 - splitB)) * math.pi) * (motion.arcHeights[3] or 14)
            end
            card.y = lerp(motion.startY, motion.endY, moveT) - lift

            if progress >= 1 then
                card.x = motion.endX
                card.y = motion.endY
                motion.restElapsed = (motion.restElapsed or 0) + dt
                if motion.restElapsed >= (motion.restHold or 0.06) then
                    UiShadow.applyRole(card, "cardRest")
                    card.motionState = nil
                    card.rotation = 0
                    card.renderAlpha = 1
                end
            end

            local direction = (motion.endX >= motion.startX) and 1 or -1
            card.rotation = damp(card.rotation or 0, math.sin(progress * math.pi) * (motion.tilt or 0.11) * direction, 10,
                dt)
            card.x = clamp(card.x, 0, WORLD_WIDTH - (card.width or CARD_WIDTH))
            card.y = clamp(card.y, 0, WORLD_HEIGHT - (card.height or CARD_HEIGHT))
            card.targetX = card.x
            card.targetY = card.y
            card.renderAlpha = 1
        else
            card.rotation = damp(card.rotation or 0, 0, 18, dt)
            card.renderAlpha = 1
        end
    end
end

-- ── Sync game-state counters from card board ──────────────────────────────────

local function syncGameStateCounters()
    gameState.bugCount = countCardsByType("bug")
    gameState.burnoutCount = countCardsByType("burnout")
    -- Money is always the sum of money cards on the board
    local total = 0
    for _, card in ipairs(cards) do
        if card.cardType == "money" then
            total = total + (card.moneyAmount or 1)
        end
    end
    gameState.money = total
end

-- ── Hot reload ────────────────────────────────────────────────────────────────

local function configureHotReload()
    HotReload.getState = function()
        serializeCards()
        state.camera = { x = camera.x, y = camera.y, zoom = camera.zoom }
        state.sprint = Sprint.serialize()
        state.gameState = copyState(gameState)
        return copyState(state)
    end

    HotReload.setState = function(saved)
        if type(saved) ~= "table" then return end
        local restored = copyState(saved)

        state.time = restored.time or 0
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

        if type(restored.sprint) == "table" then
            Sprint.deserialize(restored.sprint)
        end

        if type(restored.gameState) == "table" then
            for k, v in pairs(restored.gameState) do
                gameState[k] = v
            end
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
        if love.load then love.load(true) end
    end
end

-- ── love callbacks ────────────────────────────────────────────────────────────

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
        state.nextCardId = 1
        state.cards = nil
        state.camera = nil
        state.sprint = nil
        state.gameState = nil
        Sprint.reset()
        gameState.money = 0 -- will be synced from card counts each frame
        gameState.bugCount = 0
        gameState.burnoutCount = 0
        gameState.hireCount = 0
        coffeeMachineTimer = 0
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

    configureHotReload()
end

function love.update(dt)
    state.time = state.time + dt

    local mouseX, mouseY = love.mouse.getPosition()
    local gameX, gameY = screenToGame(mouseX, mouseY)
    local worldX, worldY = gameToWorld(gameX, gameY)

    local sprintPhase = Sprint.getState().phase

    -- Only update game logic when playing or resolving (not on win/lose screens)
    if sprintPhase ~= "won" and sprintPhase ~= "lost" then
        updateAttachedCardTargets()
        updateRecipes(dt)
        updateCoffeeMachine(dt)
        checkInfrastructureTriggers()
        syncGameStateCounters()

        -- Update sprint
        Sprint.update(dt, makeCallbacks())
    end

    for _, card in ipairs(cards) do
        if not card.motionState then
            local pointerX, pointerY = nil, nil
            if card:isDragging() then
                pointerX = worldX
                pointerY = worldY
            end
            card:update(dt, pointerX, pointerY)
        end
    end

    updatePhysicalCardMotions(dt)

    -- HUD replay button hover
    local sprintState = Sprint.getState()
    if sprintState.phase == "won" or sprintState.phase == "lost" then
        Hud.updateReplayButton(gameX, gameY, love.mouse.isDown(1))
    end

    state.camera = { x = camera.x, y = camera.y, zoom = camera.zoom }
    serializeCards()
    HotReload:update(dt)
end

function love.draw()
    Scaling.draw(function()
        local mouseX, mouseY = love.mouse.getPosition()
        local gameX, gameY = screenToGame(mouseX, mouseY)
        local worldX, worldY = gameToWorld(gameX, gameY)
        local dragFocus = collectDragInteractableTargets()
        local dragFocusActive = dragFocus ~= nil
        local dimPulse = 0.9 + (0.1 * math.sin((state.time or 0) * DRAG_FOCUS_DIM_PULSE_SPEED))
        local backdropStrength = 0.95 + (0.18 * dimPulse)
        local glowStrength = 0.9 + (0.2 * dimPulse)

        love.graphics.push()
        love.graphics.scale(camera.zoom, camera.zoom)
        love.graphics.translate(-camera.x, -camera.y)

        drawOfficeBackground()

        if dragFocusActive then
            for _, card in ipairs(cards) do
                if not isCardDragging(card) then
                    drawCardWithEffects(card)
                end
            end

            drawWorkBars(1)
            drawDragFocusBackdrop(backdropStrength)
            drawDragTargetGlow(dragFocus.list, glowStrength)

            for _, card in ipairs(cards) do
                if not isCardDragging(card) and dragFocus.targets[card] then
                    drawCardWithEffects(card)
                end
            end
        else
            local hoveredPersonCard = getTopHoveredCardWithEffect(worldX, worldY)
            for _, card in ipairs(cards) do
                if not isCardDragging(card) then
                    drawCardWithEffects(card)
                end
            end
            drawWorkBars(1)
            drawCardHoverOverlay(hoveredPersonCard)
        end

        drawDragStackShadow()

        for _, card in ipairs(cards) do
            if isCardDragging(card) then
                drawCardWithEffects(card, { skipShadow = false })
            end
        end

        love.graphics.pop()

        -- HUD (screen space)
        local viewportScale = Scaling.getScale()
        Hud.draw(gameState, Sprint.getState(), viewportScale)

        love.graphics.setFont(Theme.fonts.default)
        HotReload:draw(APP_HEIGHT, viewportScale)
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
    if button ~= 1 then return end

    local gameX, gameY = screenToGame(x, y)
    if not gameX or not gameY then return end

    local sprintPhase = Sprint.getState().phase

    -- Win/lose screen: only handle replay button
    if sprintPhase == "won" or sprintPhase == "lost" then
        if Hud.isReplayButtonClicked(gameX, gameY) then
            love.load(false)
        end
        return
    end

    -- During sprint resolving/summary: block card interaction
    if sprintPhase == "resolving" or sprintPhase == "summary" then
        return
    end

    if #draggingCards > 0 and stickyDragMode then
        endDragSelection()
        stickyDragMode = false
        dragPressStartScreenX = nil
        dragPressStartScreenY = nil
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
    if button ~= 1 then return end

    if panningWorld then
        panningWorld = false
        return
    end

    if #draggingCards == 0 then return end

    if stickyDragMode then return end

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

function love.mousemoved(_, _, dx, dy)
    if not panningWorld then return end
    if not love.mouse.isDown(1) then
        panningWorld = false
        return
    end
    local viewportScale = Scaling.getScale()
    if viewportScale <= 0 then viewportScale = 1 end
    camera.x = camera.x - (dx / viewportScale) / camera.zoom
    camera.y = camera.y - (dy / viewportScale) / camera.zoom
    clampCamera()
end

function love.wheelmoved(_, y)
    if y == 0 then return end
    local mouseX, mouseY = love.mouse.getPosition()
    local gameX, gameY = screenToGame(mouseX, mouseY)
    local anchorGameX = gameX or (APP_WIDTH * 0.5)
    local anchorGameY = gameY or (APP_HEIGHT * 0.5)
    local anchorWorldX, anchorWorldY = gameToWorld(anchorGameX, anchorGameY)
    local targetZoom = camera.zoom * (camera.zoomStep ^ y)
    targetZoom = clamp(targetZoom, camera.minZoom, camera.maxZoom)
    if targetZoom == camera.zoom then return end
    camera.zoom = targetZoom
    camera.x = anchorWorldX - (anchorGameX / camera.zoom)
    camera.y = anchorWorldY - (anchorGameY / camera.zoom)
    clampCamera()
end
