local Card = require("src.ui.card")
local BoosterPack = require("src.ui.booster_pack")

local CardDefs = require("src.game.defs.card_defs")
local PackDefs = require("src.game.defs.pack_defs")

local Constants = require("src.app.constants")
local State = require("src.app.state")
local Systems = require("src.app.systems")
local Utils = require("src.app.utils")
local Motion = require("src.app.cards.motion")

local Factory = {}

local clamp = Utils.clamp

function Factory.applyCardRuntimeDefaults(card, defId, createdAt)
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

local function createCardInstance(defId, worldX, worldY)
    local config = CardDefs.toCardConfig(defId)
    if not config then
        return nil
    end

    local x = clamp(worldX or 0, 0, Constants.WORLD_WIDTH - Constants.CARD_WIDTH)
    local y = clamp(worldY or 0, 0, Constants.WORLD_HEIGHT - Constants.CARD_HEIGHT)

    local card = Card.new({
        id = State.allocateUid(),
        cardType = config.cardType,
        role = config.role,
        title = config.title,
        effect = config.effect,
        iconPath = config.iconPath,
        style = config.style,
        value = config.value,
        moneyAmount = config.moneyAmount,
        width = Constants.CARD_WIDTH,
        height = Constants.CARD_HEIGHT,
        worldWidth = Constants.WORLD_WIDTH,
        worldHeight = Constants.WORLD_HEIGHT,
        x = x,
        y = y,
        targetX = x,
        targetY = y,
    })

    Factory.applyCardRuntimeDefaults(card, defId, Systems.time:getSimTime())
    return card
end

local function boosterDimensions()
    local w = math.floor((Constants.CARD_WIDTH * Constants.BOOSTER_PACK_WIDTH_SCALE) + 0.5)
    local h = math.floor((w * Constants.BOOSTER_PACK_ASPECT) + 0.5)
    return w, h
end

local function createPackInstance(packDefId, worldX, worldY)
    local packDef = PackDefs.get(packDefId)
    if not packDef then
        return nil
    end

    local boosterW, boosterH = boosterDimensions()
    local x = clamp(worldX or 0, 0, Constants.WORLD_WIDTH - boosterW)
    local y = clamp(worldY or 0, 0, Constants.WORLD_HEIGHT - boosterH)

    local pack = BoosterPack.new({
        id = State.allocateUid(),
        objectType = "booster_pack",
        cardType = "booster_pack",
        x = x,
        y = y,
        targetX = x,
        targetY = y,
        width = boosterW,
        height = boosterH,
        worldWidth = Constants.WORLD_WIDTH,
        worldHeight = Constants.WORLD_HEIGHT,
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
    pack.createdAt = Systems.time:getSimTime()
    pack.effectTimers = {}
    pack.markedForRemoval = false
    pack.dimmed = false
    pack.locked = false
    pack.packRuntime = Systems.packs:createPackRuntime(packDefId)

    return pack
end

function Factory.spawnCard(defId, worldX, worldY, options)
    local card = createCardInstance(defId, worldX, worldY)
    if not card then
        return nil
    end

    table.insert(State.cards, card)

    local spawnOptions = options or {}
    if spawnOptions.withBounce then
        local fromX = spawnOptions.fromX or (card.x - 20)
        local fromY = spawnOptions.fromY or card.y
        card.motionState = Motion.createSideBounce(fromX, fromY, card.x, card.y)
    end

    return card
end

function Factory.spawnPack(defId, worldX, worldY)
    local pack = createPackInstance(defId, worldX, worldY)
    if not pack then
        return nil
    end
    table.insert(State.cards, pack)
    return pack
end

function Factory.removeCard(cardToRemove)
    if not cardToRemove then
        return
    end

    cardToRemove.markedForRemoval = true

    for i = #State.cards, 1, -1 do
        if State.cards[i] == cardToRemove then
            table.remove(State.cards, i)
            break
        end
    end

    local dragging = State.dragState.draggingCards
    for i = #dragging, 1, -1 do
        if dragging[i] == cardToRemove then
            table.remove(dragging, i)
        end
    end

    if State.dragState.dragRootCard == cardToRemove then
        State.dragState.dragRootCard = nil
    end

    for _, other in ipairs(State.cards) do
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

function Factory.createStartBoard()
    State.cards = {}
    local boosterW, boosterH = boosterDimensions()
    local centerX = (Constants.WORLD_WIDTH - boosterW) * 0.5
    local centerY = (Constants.WORLD_HEIGHT - boosterH) * 0.5
    Factory.spawnPack("startup", centerX, centerY)
end

return Factory
