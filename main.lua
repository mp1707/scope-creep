local HotReload = require("src.core.hot_reload")
local Scaling = require("src.core.scaling")
local Theme = require("src.ui.theme")
local Card = require("src.ui.card")
local BoosterPack = require("src.ui.booster_pack")
local UiPanel = require("src.ui.ui_panel")
local UiShadow = require("src.ui.ui_shadow")

local CardDefs = require("src.game.defs.card_defs")
local PackDefs = require("src.game.defs.pack_defs")
local RecipeDefs = require("src.game.defs.recipe_defs")

local GameStateSystem = require("src.game.systems.game_state_system")
local TimeSystem = require("src.game.systems.time_system")
local StackEvalSystem = require("src.game.systems.stack_eval_system")
local WorkSystem = require("src.game.systems.work_system")
local EffectSystem = require("src.game.systems.effect_system")
local SprintSystem = require("src.game.systems.sprint_system")
local PaydaySystem = require("src.game.systems.payday_system")
local PackSystem = require("src.game.systems.pack_system")
local GameOverSystem = require("src.game.systems.gameover_system")

local PaydayOverlay = require("src.game.ui.payday_overlay")
local GameOverOverlay = require("src.game.ui.gameover_overlay")

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
local STACK_SNAP_DISTANCE = 88
local CLICK_ATTACH_THRESHOLD = 6

local WORK_BAR_HEIGHT = 24
local WORK_BAR_FILL_MARGIN_X = 6
local WORK_BAR_FILL_MARGIN_Y = 6
local WORK_BAR_FILL_RADIUS = 8
local WORK_BAR_FILL_RIGHT_TRIM = 4

local OFFICE_BACKGROUND_PATH = "assets/handdrawn/officebg.png"

local state = {
    time = 0,
    nextUid = 1,
    cards = {},
    lastStackEval = nil,
    dragState = {
        draggingCards = {},
        dragRootCard = nil,
        dragPressStartScreenX = nil,
        dragPressStartScreenY = nil,
        panningWorld = false,
    },
    uiState = {
        nextButtonPressed = false,
    },
}

local camera = {
    x = 0,
    y = 0,
    zoom = 1,
    minZoom = 0.65,
    maxZoom = 1.9,
    zoomStep = 1.12,
}

local systems = {
    gameState = nil,
    time = nil,
    stackEval = nil,
    work = nil,
    effects = nil,
    sprint = nil,
    payday = nil,
    packs = nil,
    gameover = nil,
    recipeById = {},
}

local officeBackgroundImage = nil
local officeBackgroundLoadAttempted = false
local coverQuadCache = setmetatable({}, { __mode = "k" })

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

local function copyState(value)
    if type(value) ~= "table" then
        return value
    end

    local out = {}
    for key, nestedValue in pairs(value) do
        out[copyState(key)] = copyState(nestedValue)
    end
    return out
end

local function getOfficeBackgroundImage()
    if officeBackgroundImage or officeBackgroundLoadAttempted then
        return officeBackgroundImage
    end
    officeBackgroundLoadAttempted = true
    local ok, img = pcall(love.graphics.newImage, OFFICE_BACKGROUND_PATH)
    if not ok then
        return nil
    end
    img:setFilter("linear", "linear")
    officeBackgroundImage = img
    return officeBackgroundImage
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
    love.graphics.draw(image, quad, x, y, 0, width / sourceWidth, height / sourceHeight)
end

local function drawOfficeBackground()
    local image = getOfficeBackgroundImage()
    if image then
        setColorWithAlpha(Theme.colors.background or { 1, 1, 1, 1 }, 1)
        drawImageCover(image, 0, 0, WORLD_WIDTH, WORLD_HEIGHT)
        if Theme.colors.backgroundWash then
            setColorWithAlpha(Theme.colors.backgroundWash, 1)
            love.graphics.rectangle("fill", 0, 0, WORLD_WIDTH, WORLD_HEIGHT)
        end
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    local fallback = Theme.colors.background or { 1, 1, 1, 1 }
    setColorWithAlpha(fallback, 1)
    love.graphics.rectangle("fill", 0, 0, WORLD_WIDTH, WORLD_HEIGHT)
    love.graphics.setColor(1, 1, 1, 1)
end

local function getCameraViewSize()
    local zoom = camera.zoom
    if zoom <= 0 then
        zoom = 1
    end
    return APP_WIDTH / zoom, APP_HEIGHT / zoom
end

local function clampCamera()
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

local function gameToWorld(gameX, gameY)
    if gameX == nil or gameY == nil then
        return nil, nil
    end
    local zoom = camera.zoom
    if zoom <= 0 then
        zoom = 1
    end
    return camera.x + (gameX / zoom), camera.y + (gameY / zoom)
end

local function allocateUid()
    local uid = state.nextUid
    state.nextUid = uid + 1
    return uid
end

local function getCardByUid(uid)
    if uid == nil then
        return nil
    end
    for _, card in ipairs(state.cards) do
        if card.uid == uid then
            return card
        end
    end
    return nil
end

local function getDirectChild(parentCard, excludedCards)
    for _, candidate in ipairs(state.cards) do
        if candidate.stackParentId == parentCard.uid
            and not (excludedCards and excludedCards[candidate])
        then
            return candidate
        end
    end
    return nil
end

local function isDescendant(card, potentialAncestor)
    local current = card
    while current and current.stackParentId do
        local parent = getCardByUid(current.stackParentId)
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

local function isCardDragging(cardToFind)
    for _, card in ipairs(state.dragState.draggingCards) do
        if card == cardToFind then
            return true
        end
    end
    return false
end

local function isCardLocked(card)
    if not card then
        return false
    end
    return card.locked or card.markedForRemoval or card.shipState ~= nil or card.motionState ~= nil
end

local function bringCardsToFront(cardsToRaise)
    local selected = {}
    for _, card in ipairs(cardsToRaise) do
        selected[card] = true
    end

    local reordered = {}
    for _, card in ipairs(state.cards) do
        if not selected[card] then
            table.insert(reordered, card)
        end
    end
    for _, card in ipairs(state.cards) do
        if selected[card] then
            table.insert(reordered, card)
        end
    end

    state.cards = reordered
end

local function applyCardRuntimeDefaults(card, defId, createdAt)
    local def = CardDefs.get(defId)
    if not def then
        return
    end

    card.uid = card.id
    card.defId = defId
    card.kind = def.kind
    card.role = def.role
    card.workRate = def.workRate
    card.baseDuration = def.baseDuration
    card.processRole = def.processRole

    card.dimmed = card.dimmed == true
    card.locked = card.locked == true
    card.activeProgress = card.activeProgress or 0
    card.assignedToPayroll = card.assignedToPayroll == true
    card.payrollAssigned = card.payrollAssigned == true
    card.createdAt = card.createdAt or (createdAt or 0)
    card.effectTimers = card.effectTimers or {}
    card.markedForRemoval = card.markedForRemoval == true
end

local function createSideBounceMotion(startX, startY, endX, endY, config)
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

local function createCardInstance(defId, worldX, worldY)
    local config = CardDefs.toCardConfig(defId)
    if not config then
        return nil
    end

    local x = clamp(worldX or 0, 0, WORLD_WIDTH - CARD_WIDTH)
    local y = clamp(worldY or 0, 0, WORLD_HEIGHT - CARD_HEIGHT)

    local card = Card.new({
        id = allocateUid(),
        cardType = config.cardType,
        role = config.role,
        title = config.title,
        effect = config.effect,
        iconPath = config.iconPath,
        style = config.style,
        value = config.value,
        moneyAmount = config.moneyAmount,
        width = CARD_WIDTH,
        height = CARD_HEIGHT,
        worldWidth = WORLD_WIDTH,
        worldHeight = WORLD_HEIGHT,
        x = x,
        y = y,
        targetX = x,
        targetY = y,
    })

    applyCardRuntimeDefaults(card, defId, systems.time:getSimTime())
    return card
end

local function createPackInstance(packDefId, worldX, worldY)
    local packDef = PackDefs.get(packDefId)
    if not packDef then
        return nil
    end

    local boosterWidth = math.floor((CARD_WIDTH * BOOSTER_PACK_WIDTH_SCALE) + 0.5)
    local boosterHeight = math.floor((boosterWidth * BOOSTER_PACK_ASPECT) + 0.5)

    local x = clamp(worldX or 0, 0, WORLD_WIDTH - boosterWidth)
    local y = clamp(worldY or 0, 0, WORLD_HEIGHT - boosterHeight)

    local pack = BoosterPack.new({
        id = allocateUid(),
        objectType = "booster_pack",
        cardType = "booster_pack",
        x = x,
        y = y,
        targetX = x,
        targetY = y,
        width = boosterWidth,
        height = boosterHeight,
        worldWidth = WORLD_WIDTH,
        worldHeight = WORLD_HEIGHT,
        topText = packDef.topText,
        bottomText = packDef.bottomText,
        iconPath = packDef.iconPath,
        iconCirclePath = packDef.iconCirclePath,
        backgroundColor = packDef.backgroundColor,
        borderColor = packDef.borderColor,
        textColor = packDef.textColor,
        iconColor = packDef.iconColor,
        iconCircleColor = packDef.iconCircleColor,
    })

    pack.uid = pack.id
    pack.defId = packDefId
    pack.kind = "pack"
    pack.createdAt = systems.time:getSimTime()
    pack.effectTimers = {}
    pack.markedForRemoval = false
    pack.dimmed = false
    pack.locked = false
    pack.packRuntime = systems.packs:createPackRuntime(packDefId)

    return pack
end

local function spawnCard(defId, worldX, worldY, options)
    local card = createCardInstance(defId, worldX, worldY)
    if not card then
        return nil
    end

    table.insert(state.cards, card)

    local spawnOptions = options or {}
    if spawnOptions.withBounce then
        local fromX = spawnOptions.fromX or (card.x - 20)
        local fromY = spawnOptions.fromY or card.y
        card.motionState = createSideBounceMotion(fromX, fromY, card.x, card.y)
    end

    return card
end

local function spawnPack(defId, worldX, worldY)
    local pack = createPackInstance(defId, worldX, worldY)
    if not pack then
        return nil
    end

    table.insert(state.cards, pack)
    return pack
end

local function removeCardInstance(cardToRemove)
    if not cardToRemove then
        return
    end

    cardToRemove.markedForRemoval = true

    for i = #state.cards, 1, -1 do
        if state.cards[i] == cardToRemove then
            table.remove(state.cards, i)
            break
        end
    end

    for i = #state.dragState.draggingCards, 1, -1 do
        if state.dragState.draggingCards[i] == cardToRemove then
            table.remove(state.dragState.draggingCards, i)
        end
    end

    if state.dragState.dragRootCard == cardToRemove then
        state.dragState.dragRootCard = nil
    end

    for _, other in ipairs(state.cards) do
        if other.stackParentId == cardToRemove.uid then
            other.stackParentId = nil
        end
        if other.recipePartnerId == cardToRemove.uid then
            other.recipePartnerId = nil
            other.recipeActive = false
            other.recipeElapsed = 0
            other.recipeDuration = nil
            other.activeProgress = 0
        end
    end
end

local function createStartBoard()
    state.cards = {}
    local boosterWidth = math.floor((CARD_WIDTH * BOOSTER_PACK_WIDTH_SCALE) + 0.5)
    local boosterHeight = math.floor((boosterWidth * BOOSTER_PACK_ASPECT) + 0.5)
    local centerX = (WORLD_WIDTH - boosterWidth) * 0.5
    local centerY = (WORLD_HEIGHT - boosterHeight) * 0.5
    spawnPack("startup", centerX, centerY)
end

local function isPayrollCard(card)
    return card and (card.kind == "employee" or card.defId == "money")
end

local function isCardInteractive(card)
    if not card or card.markedForRemoval then
        return false
    end
    if systems.gameState:isGameOver() then
        return false
    end
    if card.locked then
        return false
    end

    if systems.gameState:isPayday() then
        return isPayrollCard(card)
    end

    return true
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
    if cardToSnap.objectType == "booster_pack" or targetCard.objectType == "booster_pack" then
        return false
    end

    if systems.gameState:isPayday() then
        if not isPayrollCard(cardToSnap) or not isPayrollCard(targetCard) then
            return false
        end
    end

    local existingChild = getDirectChild(targetCard, excludedCards)
    if existingChild and existingChild ~= cardToSnap then
        return false
    end

    return true
end

local function findBestStackTarget(cardToSnap, excludedCards)
    local best = nil
    local bestDistanceSquared = STACK_SNAP_DISTANCE * STACK_SNAP_DISTANCE

    for _, other in ipairs(state.cards) do
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

    cardToSnap.stackParentId = target.parent.uid
    cardToSnap.targetX = clamp(target.x, 0, WORLD_WIDTH - (cardToSnap.width or CARD_WIDTH))
    cardToSnap.targetY = clamp(target.y, 0, WORLD_HEIGHT - (cardToSnap.height or CARD_HEIGHT))
    return true
end

local function collectStackFrom(card)
    local selected = {}

    local function collectFrom(root)
        table.insert(selected, root)
        for _, candidate in ipairs(state.cards) do
            if candidate.stackParentId == root.uid then
                collectFrom(candidate)
            end
        end
    end

    collectFrom(card)
    return selected
end

local function beginDragSelection(selection, pointerX, pointerY)
    state.dragState.draggingCards = selection
    state.dragState.dragRootCard = selection[1]

    local selectedByUid = {}
    for _, card in ipairs(selection) do
        selectedByUid[card.uid] = true
    end

    for _, card in ipairs(selection) do
        if card.stackParentId and not selectedByUid[card.stackParentId] then
            card.stackParentId = nil
        end
    end

    for _, card in ipairs(state.cards) do
        if card.stackParentId and selectedByUid[card.stackParentId] and not selectedByUid[card.uid] then
            card.stackParentId = nil
        end
    end

    for _, card in ipairs(selection) do
        card:beginDrag(pointerX, pointerY, true)
    end
end

local function endDragSelection()
    if #state.dragState.draggingCards == 0 then
        return
    end

    local rootCard = state.dragState.dragRootCard or state.dragState.draggingCards[1]

    for _, card in ipairs(state.dragState.draggingCards) do
        card:endDrag()
    end

    local excludedCards = {}
    for _, card in ipairs(state.dragState.draggingCards) do
        excludedCards[card] = true
    end

    local beforeSnapX = rootCard.targetX
    local beforeSnapY = rootCard.targetY

    applyStackSnap(rootCard, excludedCards)

    local snapDeltaX = rootCard.targetX - beforeSnapX
    local snapDeltaY = rootCard.targetY - beforeSnapY

    if snapDeltaX ~= 0 or snapDeltaY ~= 0 then
        for _, card in ipairs(state.dragState.draggingCards) do
            if card ~= rootCard then
                card.targetX = clamp(card.targetX + snapDeltaX, 0, WORLD_WIDTH - (card.width or CARD_WIDTH))
                card.targetY = clamp(card.targetY + snapDeltaY, 0, WORLD_HEIGHT - (card.height or CARD_HEIGHT))
            end
        end
    end

    state.dragState.draggingCards = {}
    state.dragState.dragRootCard = nil
end

local function updateAttachedCardTargets()
    for _, card in ipairs(state.cards) do
        if card.stackParentId and not card:isDragging() and not card.motionState then
            local parent = getCardByUid(card.stackParentId)
            if parent then
                card.targetX = clamp(parent.targetX, 0, WORLD_WIDTH - (card.width or CARD_WIDTH))
                card.targetY = clamp(parent.targetY + STACK_OFFSET_Y, 0, WORLD_HEIGHT - (card.height or CARD_HEIGHT))
            else
                card.stackParentId = nil
            end
        end
    end
end

local function resolveCompletion(completion, cardsByUid)
    local workerCard = cardsByUid[completion.workerUid]
    local targetCard = cardsByUid[completion.targetUid]
    local recipe = systems.recipeById[completion.recipeId]

    if not workerCard or not targetCard or not recipe then
        return false
    end

    local resolution = RecipeDefs.resolveCompletion(recipe, {
        worker = workerCard,
        target = targetCard,
        rand = math.random,
    })

    if not resolution then
        return false
    end

    local spawnDefIds = resolution.spawnDefIds or {}
    local consumeTarget = resolution.consumeTarget == true

    local parentId = targetCard.stackParentId
    local childCard = getDirectChild(targetCard)
    local targetX, targetY = targetCard.x, targetCard.y

    if consumeTarget then
        if not parentId and completion.softwareUids and #completion.softwareUids > 0 then
            local softwareCard = cardsByUid[completion.softwareUids[1]]
            if softwareCard and not getDirectChild(softwareCard) then
                parentId = softwareCard.uid
            end
        end

        removeCardInstance(targetCard)
    end

    local spawned = {}
    for index, defId in ipairs(spawnDefIds) do
        local offsetX = (index - 1) * 16
        local offsetY = (index - 1) * 10
        local spawnedCard = spawnCard(defId, targetX + offsetX, targetY + offsetY, {
            withBounce = true,
            fromX = targetX,
            fromY = targetY,
        })
        if spawnedCard then
            table.insert(spawned, spawnedCard)
        end
    end

    local firstSpawn = spawned[1]
    if consumeTarget then
        if firstSpawn then
            firstSpawn.stackParentId = parentId
            if childCard then
                childCard.stackParentId = firstSpawn.uid
            end
        elseif childCard then
            childCard.stackParentId = parentId
        end
    end

    if #spawned > 0 then
        bringCardsToFront(spawned)
    end

    return consumeTarget or (#spawned > 0)
end

local function updatePhysicalCardMotions(dt)
    for _, card in ipairs(state.cards) do
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
            card.renderAlpha = card.renderAlpha or 1
        else
            card.rotation = damp(card.rotation or 0, 0, 18, dt)
            if card.renderAlpha == nil then
                card.renderAlpha = 1
            end
        end
    end
end

local function collectDragInteractableTargets()
    if #state.dragState.draggingCards == 0 then
        return nil
    end

    local rootCard = state.dragState.dragRootCard or state.dragState.draggingCards[1]
    if not rootCard then
        return nil
    end

    if rootCard.objectType == "booster_pack" then
        return nil
    end

    local excludedCards = {}
    for _, card in ipairs(state.dragState.draggingCards) do
        excludedCards[card] = true
    end

    local targetSet = {}
    local targetList = {}

    for _, candidate in ipairs(state.cards) do
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
    if not targetCards or #targetCards == 0 then
        return
    end

    local strength = clamp(glowStrength or 1, 0, 1.25)
    local focusColors = Theme.colors.dragFocus or {}
    local pulse = 0.5 + (0.5 * math.sin((state.time or 0) * 3.2))
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
    end

    love.graphics.setColor(1, 1, 1, 1)
end

local function computeCapsuleFillRight(fillX, fillWidth, radius, progress)
    local p = clamp(progress or 0, 0, 1)
    if p <= 0 then
        return fillX
    end
    if p >= 1 then
        return fillX + fillWidth
    end

    local cap = math.min(math.max(0, radius), fillWidth * 0.5)
    return fillX + cap + (fillWidth - cap) * p
end

local function drawWorkBars(activeJobs)
    local workBarColors = Theme.colors.workBar

    for _, job in ipairs(activeJobs) do
        local worker = getCardByUid(job.workerUid)
        local target = getCardByUid(job.targetUid)
        if worker and target then
            local topY = math.min(worker.y, target.y)
            local anchorX = worker.x

            local barX = anchorX
            local barY = topY - 8 - WORK_BAR_HEIGHT

            UiPanel.drawSurface(barX, barY, CARD_WIDTH, WORK_BAR_HEIGHT, workBarColors.track, { alpha = 1 })

            local progress = clamp((job.elapsed or 0) / math.max(0.0001, job.duration or 1), 0, 1)
            local fillX = barX + WORK_BAR_FILL_MARGIN_X
            local fillY = barY + WORK_BAR_FILL_MARGIN_Y
            local fillMaxWidth = math.max(0, CARD_WIDTH - WORK_BAR_FILL_MARGIN_X * 2 - WORK_BAR_FILL_RIGHT_TRIM)
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

                    setColorWithAlpha(fillColor, 1)
                    love.graphics.circle("fill", leftCenterX, centerY, cap, 20)
                    if bodyWidth > 0 then
                        love.graphics.rectangle("fill", bodyX, fillY, bodyWidth, fillHeight)
                    end
                    love.graphics.circle("fill", rightCenterX, centerY, cap, 20)
                end
            end

            UiPanel.drawBorder(barX, barY, CARD_WIDTH, WORK_BAR_HEIGHT, workBarColors.border, { alpha = 1 })
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

local function drawPackBadge(packCard)
    if not packCard or not packCard.packRuntime then
        return
    end

    local remaining = packCard.packRuntime.usesRemaining or 0
    local badgeRadius = 19
    local badgeX = packCard.x + packCard.width - 8
    local badgeY = packCard.y + 12

    love.graphics.setColor(0.98, 0.95, 0.82, (packCard.renderAlpha or 1))
    love.graphics.circle("fill", badgeX, badgeY, badgeRadius)
    love.graphics.setColor(0.1, 0.16, 0.23, (packCard.renderAlpha or 1))
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", badgeX, badgeY, badgeRadius)

    local viewportScale = Scaling.getScale()
    if viewportScale <= 0 then
        viewportScale = 1
    end

    local font = Theme.fonts.cardHeader or love.graphics.getFont()
    love.graphics.setFont(font)

    local label = tostring(remaining)
    local scale = 1 / viewportScale
    local textW = font:getWidth(label) * scale
    local textH = font:getHeight() * scale
    love.graphics.print(label, badgeX - (textW * 0.5), badgeY - (textH * 0.5), 0, scale, scale)

    love.graphics.setColor(1, 1, 1, 1)
end

local function drawFiredLabels()
    local labels = systems.payday:getFiredLabels()
    if not labels then
        return
    end

    local viewportScale = Scaling.getScale()
    if viewportScale <= 0 then
        viewportScale = 1
    end

    local font = Theme.fonts.cardHeader or love.graphics.getFont()
    love.graphics.setFont(font)

    for _, label in ipairs(labels) do
        local progress = clamp(label.elapsed / label.duration, 0, 1)
        local alpha = 1 - progress
        local yOffset = progress * 28
        local drawX = label.x
        local drawY = label.y - yOffset

        love.graphics.push()
        love.graphics.translate(drawX, drawY)
        love.graphics.rotate(-0.32)
        love.graphics.setColor(0.8, 0.08, 0.08, alpha)
        local scale = 1 / viewportScale
        local text = label.text or "gekündigt"
        local textW = font:getWidth(text) * scale
        local textH = font:getHeight() * scale
        love.graphics.print(text, -(textW * 0.5), -(textH * 0.5), 0, scale, scale)
        love.graphics.pop()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

local function drawCardWithEffects(card)
    local alpha = card.renderAlpha or 1

    if systems.gameState:isPayday() then
        if not isPayrollCard(card) then
            alpha = alpha * 0.28
        end
    end

    if card.dimmed then
        alpha = alpha * 0.55
    end

    if card.objectType == "booster_pack" then
        card:draw(Theme.fonts.cardHeader, {
            alpha = alpha,
            bodyFont = Theme.fonts.cardBody,
            valueFont = Theme.fonts.cardBody,
        })
        drawPackBadge(card)
    else
        card:draw(Theme.fonts.cardHeader, {
            alpha = alpha,
            bodyFont = Theme.fonts.cardBody,
            valueFont = Theme.fonts.cardBody,
        })
    end
end

local function formatTime(seconds)
    local s = math.max(0, math.floor(seconds))
    return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local function drawHud(gameX, gameY)
    local viewportScale = Scaling.getScale()
    if viewportScale <= 0 then
        viewportScale = 1
    end

    local scale = 1 / viewportScale
    local headerFont = Theme.fonts.cardHeader or love.graphics.getFont()
    local bodyFont = Theme.fonts.cardBody or headerFont

    local phase = systems.gameState:getPhase()
    local sprintNumber = systems.sprint:getSprintNumber()
    local remaining = systems.sprint:getRemainingTime()
    local speed = systems.gameState:getSpeedFactor()

    UiPanel.drawPanel(20, 20, 280, 110, {
        bodyColor = { 0.97, 0.94, 0.86, 0.96 },
        borderColor = Theme.palette.ink,
    })

    love.graphics.setFont(headerFont)
    love.graphics.setColor(Theme.palette.ink)
    love.graphics.print(string.format("Sprint %d", sprintNumber), 36, 34, 0, scale, scale)

    love.graphics.setFont(bodyFont)
    love.graphics.print(string.format("Zeit: %s", formatTime(remaining)), 36, 66, 0, scale, scale)
    love.graphics.print(string.format("State: %s", phase), 36, 88, 0, scale, scale)

    UiPanel.drawPanel(APP_WIDTH - 260, 20, 240, 88, {
        bodyColor = { 0.97, 0.94, 0.86, 0.96 },
        borderColor = Theme.palette.ink,
    })

    love.graphics.print(string.format("Speed: %dx", speed), APP_WIDTH - 244, 40, 0, scale, scale)
    love.graphics.print("Space: Pause", APP_WIDTH - 244, 62, 0, scale, scale)
    love.graphics.print("Enter: Speed", APP_WIDTH - 244, 84, 0, scale, scale)

    if systems.gameState:isPayday() then
        local paid = 0
        local unpaid = 0
        for _, card in ipairs(state.cards) do
            if card.kind == "employee" then
                if card.assignedToPayroll then
                    paid = paid + 1
                else
                    unpaid = unpaid + 1
                end
            end
        end

        PaydayOverlay.draw({
            viewportScale = viewportScale,
            sprintNumber = sprintNumber,
            paidEmployees = paid,
            unpaidEmployees = unpaid,
            nextButtonHovered = PaydayOverlay.isNextButtonHovered(gameX, gameY),
            nextButtonPressed = state.uiState.nextButtonPressed,
        })
    end

    if systems.gameState:isGameOver() then
        GameOverOverlay.draw(systems.gameState:getGameOverReason(), viewportScale)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

local function serializeCards()
    local snapshots = {}

    for _, card in ipairs(state.cards) do
        if not card.shipState then
            local snapshot
            if card.objectType == "booster_pack" then
                snapshot = card:getSnapshot()
            else
                snapshot = card:getSnapshot()
            end

            snapshot.uid = card.uid
            snapshot.defId = card.defId
            snapshot.kind = card.kind
            snapshot.role = card.role
            snapshot.workRate = card.workRate
            snapshot.baseDuration = card.baseDuration
            snapshot.processRole = card.processRole
            snapshot.dimmed = card.dimmed
            snapshot.locked = card.locked
            snapshot.activeProgress = card.activeProgress
            snapshot.assignedToPayroll = card.assignedToPayroll
            snapshot.payrollAssigned = card.payrollAssigned
            snapshot.createdAt = card.createdAt
            snapshot.effectTimers = copyState(card.effectTimers)
            snapshot.markedForRemoval = card.markedForRemoval
            snapshot.renderAlpha = card.renderAlpha
            snapshot.packRuntime = copyState(card.packRuntime)

            table.insert(snapshots, snapshot)
        end
    end

    return snapshots
end

local function restoreCards(cardSnapshots)
    state.cards = {}
    local maxUid = 0

    for _, snapshot in ipairs(cardSnapshots or {}) do
        local restored
        if snapshot.objectType == "booster_pack" then
            restored = BoosterPack.new(snapshot)
            restored.packRuntime = copyState(snapshot.packRuntime)
            restored.kind = snapshot.kind or "pack"
            restored.defId = snapshot.defId
        else
            restored = Card.new(snapshot)
            restored.defId = snapshot.defId
            if restored.defId then
                applyCardRuntimeDefaults(restored, restored.defId, snapshot.createdAt)
            end
        end

        restored.uid = snapshot.uid or restored.id
        restored.id = restored.uid
        restored.createdAt = snapshot.createdAt or restored.createdAt or 0
        restored.dimmed = snapshot.dimmed == true
        restored.locked = snapshot.locked == true
        restored.activeProgress = snapshot.activeProgress or 0
        restored.assignedToPayroll = snapshot.assignedToPayroll == true
        restored.payrollAssigned = snapshot.payrollAssigned == true
        restored.effectTimers = snapshot.effectTimers or {}
        restored.markedForRemoval = snapshot.markedForRemoval == true
        restored.workRate = snapshot.workRate
        restored.baseDuration = snapshot.baseDuration
        restored.processRole = snapshot.processRole
        restored.renderAlpha = snapshot.renderAlpha or 1

        if not restored.kind then
            if restored.objectType == "booster_pack" then
                restored.kind = "pack"
            elseif restored.defId then
                local def = CardDefs.get(restored.defId)
                restored.kind = def and def.kind or restored.kind
                restored.role = def and def.role or restored.role
            end
        end

        if restored.uid > maxUid then
            maxUid = restored.uid
        end

        table.insert(state.cards, restored)
    end

    if maxUid >= state.nextUid then
        state.nextUid = maxUid + 1
    end
end

local function setupSystems()
    systems.gameState = GameStateSystem.new()
    systems.time = TimeSystem.new(systems.gameState)
    systems.stackEval = StackEvalSystem.new()
    systems.work = WorkSystem.new()
    systems.effects = EffectSystem.new(math.random)
    systems.sprint = SprintSystem.new(60)
    systems.payday = PaydaySystem.new()
    systems.packs = PackSystem.new(PackDefs)
    systems.gameover = GameOverSystem.new()

    systems.recipeById = {}
    for _, recipe in ipairs(RecipeDefs.all()) do
        systems.recipeById[recipe.id] = recipe
    end
end

local function evaluateStacks()
    state.lastStackEval = systems.stackEval:evaluate(state.cards, RecipeDefs)
    return state.lastStackEval
end

local function runSecurityGameOverCheck()
    local lost, reason = systems.gameover:checkSecurityIssueLoss(state.cards)
    if lost then
        systems.gameState:setGameOver(reason)
        evaluateStacks()
        systems.work:clear(state.lastStackEval.cardsByUid)
        return true
    end
    return false
end

local systemCallbacks

local function enterPayday()
    if systems.gameState:getPhase() == "gameover" then
        return
    end

    systems.gameState:setPhase("payday")

    local preEval = evaluateStacks()
    systems.payday:enter(state.cards, preEval, {
        spawnCard = function(defId, x, y, options)
            return spawnCard(defId, x, y, options)
        end,
        removeCard = function(card)
            removeCardInstance(card)
        end,
        mergeBugs = function()
            systems.effects:mergeBugsIfNeeded(state.cards, systemCallbacks)
        end,
    })

    local postEval = evaluateStacks()
    systems.payday:applyPayrollAssignments(state.cards, postEval)
    systems.work:clear(postEval.cardsByUid)

    runSecurityGameOverCheck()
end

local function startNextSprintFromPayday()
    local eval = evaluateStacks()

    local result = systems.payday:startNextSprint(state.cards, eval, {
        spawnCard = function(defId, x, y, options)
            return spawnCard(defId, x, y, options)
        end,
        removeCard = function(card)
            removeCardInstance(card)
        end,
    })

    systems.effects:mergeBugsIfNeeded(state.cards, systemCallbacks)

    local noTeam, reason = systems.gameover:checkNoEmployeeLoss(state.cards)
    if noTeam then
        systems.gameState:setGameOver(reason)
        local refreshed = evaluateStacks()
        systems.work:clear(refreshed.cardsByUid)
        return
    end

    systems.sprint:resetForNextSprint()
    systems.gameState:setPhase("running")

    local refreshed = evaluateStacks()
    systems.payday:clearPayrollFlags(state.cards)
    systems.work:clear(refreshed.cardsByUid)

    if result and result.employeeCount <= 0 then
        systems.gameState:setGameOver("no_team_left")
    end
end

local function bootstrapNewGame()
    state.time = 0
    state.nextUid = 1
    state.cards = {}
    state.lastStackEval = nil

    state.dragState.draggingCards = {}
    state.dragState.dragRootCard = nil
    state.dragState.dragPressStartScreenX = nil
    state.dragState.dragPressStartScreenY = nil
    state.dragState.panningWorld = false
    state.uiState.nextButtonPressed = false

    setupSystems()
    createStartBoard()
    evaluateStacks()

    systems.gameState:setPhase("running")

    camera.zoom = 1
    setCameraCenteredOn(WORLD_WIDTH * 0.5, WORLD_HEIGHT * 0.5)
end

local function configureHotReload()
    HotReload.getState = function()
        return {
            state = {
                time = state.time,
                nextUid = state.nextUid,
                cards = serializeCards(),
                camera = {
                    x = camera.x,
                    y = camera.y,
                    zoom = camera.zoom,
                },
                dragState = {
                    draggingCards = {},
                    dragRootCard = nil,
                    dragPressStartScreenX = nil,
                    dragPressStartScreenY = nil,
                    panningWorld = false,
                },
                uiState = copyState(state.uiState),
            },
            systems = {
                gameState = systems.gameState:serialize(),
                time = systems.time:serialize(),
                work = systems.work:serialize(),
                sprint = systems.sprint:serialize(),
                firedLabels = copyState(systems.payday:getFiredLabels()),
            },
        }
    end

    HotReload.setState = function(saved)
        if type(saved) ~= "table" then
            return
        end

        setupSystems()

        local savedState = saved.state or {}
        state.time = savedState.time or 0
        state.nextUid = savedState.nextUid or 1
        state.uiState = savedState.uiState or { nextButtonPressed = false }
        state.dragState = savedState.dragState or state.dragState
        state.dragState.draggingCards = {}
        state.dragState.dragRootCard = nil

        restoreCards(savedState.cards)

        if savedState.camera then
            camera.x = tonumber(savedState.camera.x) or camera.x
            camera.y = tonumber(savedState.camera.y) or camera.y
            camera.zoom = clamp(tonumber(savedState.camera.zoom) or camera.zoom, camera.minZoom, camera.maxZoom)
        end

        clampCamera()

        local savedSystems = saved.systems or {}
        systems.gameState:deserialize(savedSystems.gameState)
        systems.time:deserialize(savedSystems.time)
        systems.work:deserialize(savedSystems.work)
        systems.sprint:deserialize(savedSystems.sprint)

        if type(savedSystems.firedLabels) == "table" then
            systems.payday.firedLabels = savedSystems.firedLabels
        end

        evaluateStacks()
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

    if isReload ~= true then
        bootstrapNewGame()
    end

    configureHotReload()
end

local function updateSimulation(dt)
    local timing = systems.time:step(dt)
    local realDt = timing.realDt
    local simDt = timing.simDt

    updateAttachedCardTargets()

    local evalBefore = evaluateStacks()

    if systems.gameState:getPhase() == "running" or systems.gameState:getPhase() == "paused" then
        local techDebtCount = systems.effects:getTechDebtCount(state.cards)
        systems.work:sync(evalBefore.workCandidates, evalBefore.cardsByUid, systems.recipeById, techDebtCount)
    else
        systems.work:clear(evalBefore.cardsByUid)
    end

    local boardChanged = false

    if systems.gameState:getPhase() == "running" then
        local completions = systems.work:update(simDt, evalBefore.cardsByUid)
        for _, completion in ipairs(completions) do
            local evalNow = evaluateStacks()
            if resolveCompletion(completion, evalNow.cardsByUid) then
                boardChanged = true
            end
        end

        if boardChanged then
            evaluateStacks()
        end

        if systems.effects:updateSecurityTimers(simDt, state.cards, systemCallbacks) then
            boardChanged = true
            evaluateStacks()
        end

        if systems.effects:mergeBugsIfNeeded(state.cards, systemCallbacks) then
            boardChanged = true
            evaluateStacks()
        end

        if runSecurityGameOverCheck() then
            return
        end

        if systems.sprint:update(simDt) then
            enterPayday()
            return
        end
    elseif systems.gameState:isPayday() then
        local evalPayday = evaluateStacks()
        systems.payday:applyPayrollAssignments(state.cards, evalPayday)
    end

    systems.packs:update(realDt, state.cards, {
        removeCard = function(card)
            removeCardInstance(card)
        end,
    })

    systems.payday:updateFiredLabels(realDt)

    local phase = systems.gameState:getPhase()
    if phase == "running" or phase == "paused" then
        local lost, reason = systems.gameover:checkSecurityIssueLoss(state.cards)
        if lost then
            systems.gameState:setGameOver(reason)
        end
    end
end

function love.update(dt)
    if not systems.time or not systems.gameState then
        bootstrapNewGame()
    end

    state.time = state.time + dt

    local mouseX, mouseY = love.mouse.getPosition()
    local gameX, gameY = screenToGame(mouseX, mouseY)
    local worldX, worldY = gameToWorld(gameX, gameY)

    updateSimulation(dt)

    for _, card in ipairs(state.cards) do
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

    HotReload:update(dt)
end

function love.draw()
    Scaling.draw(function()
        local mouseX, mouseY = love.mouse.getPosition()
        local gameX, gameY = screenToGame(mouseX, mouseY)

        local dragFocus = collectDragInteractableTargets()

        love.graphics.push()
        love.graphics.scale(camera.zoom, camera.zoom)
        love.graphics.translate(-camera.x, -camera.y)

        drawOfficeBackground()

        if dragFocus then
            for _, card in ipairs(state.cards) do
                if not isCardDragging(card) then
                    drawCardWithEffects(card)
                end
            end
            drawWorkBars(systems.work:getActiveJobs())
            drawDragFocusBackdrop(1)
            drawDragTargetGlow(dragFocus.list, 1)
        else
            for _, card in ipairs(state.cards) do
                if not isCardDragging(card) then
                    drawCardWithEffects(card)
                end
            end
            drawWorkBars(systems.work:getActiveJobs())
        end

        for _, card in ipairs(state.cards) do
            if isCardDragging(card) then
                drawCardWithEffects(card)
            end
        end

        drawFiredLabels()

        love.graphics.pop()

        drawHud(gameX, gameY)

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
        return
    end

    local phase = systems.gameState:getPhase()

    if key == "space" then
        if phase == "running" or phase == "paused" then
            systems.gameState:togglePause()
        end
        return
    end

    if key == "return" or key == "kpenter" then
        if phase == "running" or phase == "paused" or phase == "payday" then
            systems.gameState:toggleSpeed()
        end
        return
    end
end

function love.mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    local gameX, gameY = screenToGame(x, y)
    if not gameX or not gameY then
        return
    end

    local phase = systems.gameState:getPhase()
    if phase == "gameover" then
        return
    end

    if phase == "payday" and PaydayOverlay.isNextButtonHovered(gameX, gameY) then
        state.uiState.nextButtonPressed = true
        return
    end

    local worldX, worldY = gameToWorld(gameX, gameY)
    local selectedCard = nil

    for i = #state.cards, 1, -1 do
        local card = state.cards[i]
        if isCardInteractive(card) and not isCardLocked(card) and card:containsPoint(worldX, worldY) then
            selectedCard = card
            break
        end
    end

    if not selectedCard then
        state.dragState.panningWorld = true
        return
    end

    local selection = { selectedCard }
    if selectedCard:containsHeaderPoint(worldX, worldY) then
        selection = collectStackFrom(selectedCard)
    end

    bringCardsToFront(selection)
    beginDragSelection(selection, worldX, worldY)

    state.dragState.dragPressStartScreenX = x
    state.dragState.dragPressStartScreenY = y
    state.dragState.panningWorld = false
end

function love.mousereleased(x, y, button)
    if button ~= 1 then
        return
    end

    local gameX, gameY = screenToGame(x, y)
    local phase = systems.gameState:getPhase()

    if phase == "payday" and state.uiState.nextButtonPressed then
        state.uiState.nextButtonPressed = false
        if gameX and gameY and PaydayOverlay.isNextButtonHovered(gameX, gameY) then
            startNextSprintFromPayday()
        end
        return
    end

    if state.dragState.panningWorld then
        state.dragState.panningWorld = false
        return
    end

    if #state.dragState.draggingCards == 0 then
        return
    end

    local rootCard = state.dragState.dragRootCard or state.dragState.draggingCards[1]
    local dx = x - (state.dragState.dragPressStartScreenX or x)
    local dy = y - (state.dragState.dragPressStartScreenY or y)
    local movedEnough = (dx * dx + dy * dy) > (CLICK_ATTACH_THRESHOLD * CLICK_ATTACH_THRESHOLD)

    endDragSelection()

    if not movedEnough and rootCard and rootCard.objectType == "booster_pack" and isCardInteractive(rootCard) then
        systems.packs:openPack(rootCard, {
            spawnCard = function(defId, spawnX, spawnY, options)
                local opts = options or {}
                opts.fromX = rootCard.x + (rootCard.width * 0.5)
                opts.fromY = rootCard.y + (rootCard.height * 0.5)
                return spawnCard(defId, spawnX, spawnY, opts)
            end,
            random = math.random,
        })
    end

    state.dragState.dragPressStartScreenX = nil
    state.dragState.dragPressStartScreenY = nil
end

function love.mousemoved(_, _, dx, dy)
    if not state.dragState.panningWorld then
        return
    end

    if not love.mouse.isDown(1) then
        state.dragState.panningWorld = false
        return
    end

    local viewportScale = Scaling.getScale()
    if viewportScale <= 0 then
        viewportScale = 1
    end

    camera.x = camera.x - (dx / viewportScale) / camera.zoom
    camera.y = camera.y - (dy / viewportScale) / camera.zoom
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

systemCallbacks = {
    spawnCard = function(defId, x, y, options)
        return spawnCard(defId, x, y, options)
    end,
    removeCard = function(card)
        removeCardInstance(card)
    end,
}
