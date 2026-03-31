local Sound = require("src.core.sound")
local HotReload = require("src.core.hot_reload")
local Theme = require("src.ui.theme")
local Layout = require("src.ui.layout")
local BoardView = require("src.ui.components.board")
local SidebarView = require("src.ui.components.sidebar")
local HandView = require("src.ui.components.hand")
local ButtonsView = require("src.ui.components.buttons")
local RetrospectiveView = require("src.ui.components.retrospective")

local FEATURE_DEFS = {
    {
        key = "regular_feature",
        name = "Regular Feature",
        kind = "feature",
        baseWork = 3,
        baseValue = 1000,
        color = { 0.92, 0.86, 0.54, 1 },
        count = 5,
    },
    {
        key = "small_feature",
        name = "Small Feature",
        kind = "feature",
        baseWork = 1,
        baseValue = 300,
        color = { 0.95, 0.90, 0.62, 1 },
        count = 5,
    },
    {
        key = "major_feature",
        name = "Major Feature",
        kind = "feature",
        baseWork = 8,
        baseValue = 3000,
        color = { 0.90, 0.82, 0.45, 1 },
        count = 5,
    },
}

local SUPPORT_DEFS = {
    {
        key = "quick_and_dirty",
        name = "Quick and Dirty",
        kind = "support",
        effect = "target_minus_work",
        amount = 2,
        techDebtGain = 20,
        description = "One feature requires -2 Work",
        header = "+20% Tech Debt",
        color = { 0.55, 0.77, 0.93, 1 },
        count = 5,
    },
    {
        key = "weekend_session",
        name = "Weekend Session",
        kind = "support",
        effect = "all_devs_plus_work",
        amount = 1,
        burnoutGain = 30,
        description = "All devs get +1 Work today",
        header = "+30% Burnout",
        color = { 0.50, 0.72, 0.90, 1 },
        count = 5,
    },
}

local APPLICANT_POOL = {
    "Bob",
    "Jim",
    "Alice",
    "Nina",
    "Max",
    "Tina",
    "Sam",
    "Lara",
    "Noah",
    "Jules",
}

local game = {
    phase = "sprint",
    sprint = 1,
    release = 1,
    businessGoal = 4000,
    revenue = 0,
    burnout = 0,
    techDebt = 0,
    day = 1,
    maxDays = 5,

    developers = {},
    rows = {},
    deck = {},
    hand = {},
    applicants = {},

    selectedCardId = nil,
    pendingSupport = nil,

    drag = nil,
    pressedButtonId = nil,

    nextCardId = 1,
    nextDeveloperId = 1,

    layout = nil,
    time = 0,
    rng = nil,

}

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for k, v in pairs(value) do
        copy[deepCopy(k)] = deepCopy(v)
    end
    return copy
end

local function pointInRect(px, py, rect)
    if not rect then
        return false
    end
    return px >= rect.x and px <= rect.x + rect.w and py >= rect.y and py <= rect.y + rect.h
end

local function thousandSep(n)
    local s = tostring(math.floor(n + 0.5))
    local out = s
    while true do
        local replaced, count = string.gsub(out, "^(%-?%d+)(%d%d%d)", "%1.%2")
        out = replaced
        if count == 0 then
            break
        end
    end
    return out
end

local function formatMoney(v)
    return thousandSep(v) .. "$"
end

local function getTechDebtWorkPenalty()
    if game.techDebt >= 100 then
        return 2
    end
    if game.techDebt >= 50 then
        return 1
    end
    return 0
end

local function getDaysRemaining()
    return math.max(0, game.maxDays - game.day + 1)
end

local function shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = game.rng:random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
end

local function getCardById(cardId)
    for _, card in ipairs(game.hand) do
        if card.id == cardId then
            return card
        end
    end
    return nil
end

local function removeCardFromHand(cardId)
    for i, card in ipairs(game.hand) do
        if card.id == cardId then
            table.remove(game.hand, i)
            if game.selectedCardId == cardId then
                game.selectedCardId = nil
            end
            return card
        end
    end
    return nil
end

local function getRowByIndex(index)
    return game.rows[index]
end

local function makeDeveloper(name, baseWork)
    local dev = {
        id = game.nextDeveloperId,
        name = name,
        baseWork = baseWork,
        availableWork = baseWork,
    }
    game.nextDeveloperId = game.nextDeveloperId + 1
    return dev
end

local function resetDeveloperWork()
    for _, dev in ipairs(game.developers) do
        dev.availableWork = dev.baseWork
    end
end

local function buildRows(resetState)
    local newRows = {}
    for i, dev in ipairs(game.developers) do
        local old = game.rows[i]
        if not resetState and old and old.developer.id == dev.id then
            table.insert(newRows, old)
        else
            table.insert(newRows, {
                developer = dev,
                inProgress = nil,
                testing = nil,
                rollout = nil,
                done = nil,
                doneFlash = 0,
            })
        end
    end
    game.rows = newRows
end

local function makeCardFromDef(def)
    local card = {
        id = game.nextCardId,
        key = def.key,
        name = def.name,
        kind = def.kind,
        color = { def.color[1], def.color[2], def.color[3], def.color[4] },

        x = 0,
        y = 0,
        targetX = 0,
        targetY = 0,
        rotation = 0,
        targetRotation = 0,
        tiltX = 0,
        tiltY = 0,
        scale = 1,
        targetScale = 1,
        isDragging = false,
        isPendingTarget = false,
    }

    game.nextCardId = game.nextCardId + 1

    if card.kind == "feature" then
        card.baseWork = def.baseWork
        card.baseValue = def.baseValue
    else
        card.effect = def.effect
        card.amount = def.amount
        card.burnoutGain = def.burnoutGain or 0
        card.techDebtGain = def.techDebtGain or 0
        card.description = def.description
        card.header = def.header
    end

    return card
end

local function buildSprintDeck()
    game.deck = {}

    for _, def in ipairs(FEATURE_DEFS) do
        for _ = 1, def.count do
            table.insert(game.deck, makeCardFromDef(def))
        end
    end

    for _, def in ipairs(SUPPORT_DEFS) do
        for _ = 1, def.count do
            table.insert(game.deck, makeCardFromDef(def))
        end
    end

    shuffle(game.deck)
end

local function computeLayout()
    return Layout.compute(game)
end

local function drawToHandUntil(limit)
    local layout = game.layout
    while #game.hand < limit and #game.deck > 0 do
        local card = table.remove(game.deck)
        local backlog = layout.sidebar.backlogRect

        card.x = backlog.x + backlog.w * 0.5
        card.y = backlog.y + backlog.h * 0.5
        card.targetX = card.x
        card.targetY = card.y
        card.rotation = 0
        card.targetRotation = 0
        card.scale = 1
        card.targetScale = 1
        card.tiltX = 0
        card.tiltY = 0
        card.isPendingTarget = false

        table.insert(game.hand, card)
    end
end

local function getHandTarget(index, count)
    local hand = game.layout.hand
    local areaW = hand.right - hand.left
    local cardW = hand.cardW

    local spacing
    if count <= 1 then
        spacing = 0
    else
        spacing = math.min(cardW * 0.55, (areaW - cardW) / (count - 1))
    end

    local totalW = cardW + spacing * (count - 1)
    local startX = hand.left + (areaW - totalW) * 0.5

    local x = startX + (index - 1) * spacing
    local y = hand.y
    local fanOffset = index - (count + 1) * 0.5
    local rotation = fanOffset * 0.06

    return x, y, rotation
end

local function getTopHandCardAtPoint(x, y)
    local hand = game.layout.hand

    for i = #game.hand, 1, -1 do
        local card = game.hand[i]
        local rect = {
            x = card.x,
            y = card.y,
            w = hand.cardW,
            h = hand.cardH,
        }
        if pointInRect(x, y, rect) then
            return card, i
        end
    end

    return nil, nil
end

local function canPlaySupportCard(card)
    if card.effect == "all_devs_plus_work" and game.burnout >= 100 then
        return false
    end

    if card.effect == "target_minus_work" then
        for _, row in ipairs(game.rows) do
            if row.inProgress then
                return true
            end
        end
        return false
    end

    return true
end

local function findRowIndexByInProgressHit(x, y)
    for i, lrow in ipairs(game.layout.rows) do
        if pointInRect(x, y, lrow.inProgressRect) then
            return i
        end
    end
    return nil
end

local function findTargetableFeatureByPoint(x, y)
    for i, lrow in ipairs(game.layout.rows) do
        if lrow.inProgressCardRect and pointInRect(x, y, lrow.inProgressCardRect) then
            local row = getRowByIndex(i)
            if row and row.inProgress then
                return row
            end
        end
    end
    return nil
end

local function moveCompletedInProgressToTesting(row)
    if row.inProgress and row.inProgress.remainingWork <= 0 and row.testing == nil then
        row.inProgress.remainingWork = 0
        row.testing = row.inProgress
        row.inProgress = nil
        Sound:play("notification", { volume = 0.3 })
    end
end

local function applyWorkToRow(row)
    if not row.inProgress then
        return
    end

    if row.inProgress.remainingWork <= 0 then
        moveCompletedInProgressToTesting(row)
        return
    end

    local dev = row.developer
    if dev.availableWork <= 0 then
        return
    end

    local spend = math.min(dev.availableWork, row.inProgress.remainingWork)
    row.inProgress.remainingWork = row.inProgress.remainingWork - spend
    dev.availableWork = dev.availableWork - spend

    if row.inProgress.remainingWork <= 0 then
        moveCompletedInProgressToTesting(row)
    end
end

local function removePendingSupportCard()
    if not game.pendingSupport then
        return
    end

    local pendingCardId = game.pendingSupport.cardId
    removeCardFromHand(pendingCardId)
    game.pendingSupport = nil
    game.selectedCardId = nil
end

local function applyPendingSupportToRow(row)
    if not game.pendingSupport then
        return false
    end

    if not row or not row.inProgress then
        return false
    end

    local pending = game.pendingSupport
    if pending.effect == "target_minus_work" then
        row.inProgress.remainingWork = math.max(0, row.inProgress.remainingWork - pending.amount)
        moveCompletedInProgressToTesting(row)
        removePendingSupportCard()
        Sound:play("short_light_tap", { volume = 0.4 })
        return true
    end

    return false
end

local function enterRetrospective()
    game.phase = "retrospective"
    game.drag = nil
    game.selectedCardId = nil
    game.pendingSupport = nil

    game.applicants = {}
    if #game.developers >= 5 then
        return
    end

    local usedNames = {}
    for _, dev in ipairs(game.developers) do
        usedNames[dev.name] = true
    end

    local candidates = {}
    for _, name in ipairs(APPLICANT_POOL) do
        if not usedNames[name] then
            table.insert(candidates, name)
        end
    end

    shuffle(candidates)

    local count = math.min(2, #candidates)
    for i = 1, count do
        table.insert(game.applicants, {
            name = candidates[i],
            work = game.rng:random(1, 3),
        })
    end
end

local function startSprintBoard()
    game.phase = "sprint"
    game.revenue = 0
    game.businessGoal = 4000 + (game.sprint - 1) * 2000
    game.day = 1
    game.selectedCardId = nil
    game.pendingSupport = nil
    game.drag = nil

    buildRows(true)
    resetDeveloperWork()

    buildSprintDeck()
    game.hand = {}
    drawToHandUntil(5)
end

local function gotoNextSprint()
    local oldRelease = game.release

    game.sprint = game.sprint + 1
    game.release = math.floor((game.sprint - 1) / 3) + 1

    if game.release ~= oldRelease then
        game.burnout = 0
        game.techDebt = 0
    end

    startSprintBoard()
end

local function checkSprintTransition()
    if game.revenue >= game.businessGoal then
        enterRetrospective()
        return true
    end
    return false
end

local function shipRollout(row)
    if not row.rollout then
        return false
    end

    game.revenue = game.revenue + row.rollout.value
    row.done = row.rollout
    row.doneFlash = 0.6
    row.rollout = nil

    Sound:play("notification", { volume = 0.45 })
    checkSprintTransition()
    return true
end

local function playFeatureCard(card, row)
    if row.inProgress then
        return false
    end

    local workPenalty = getTechDebtWorkPenalty()
    local totalWork = card.baseWork + workPenalty

    row.inProgress = {
        name = card.name,
        color = { card.color[1], card.color[2], card.color[3], card.color[4] },
        totalWork = totalWork,
        remainingWork = totalWork,
        value = card.baseValue,
        status = "in_progress",
    }

    removeCardFromHand(card.id)
    applyWorkToRow(row)
    Sound:play("ultra_light_tap", { volume = 0.4 })

    return true
end

local function playSupportCard(card)
    if game.pendingSupport then
        return false
    end

    if not canPlaySupportCard(card) then
        Sound:play("error", { volume = 0.55 })
        return false
    end

    if card.effect == "all_devs_plus_work" then
        if game.burnout >= 100 then
            Sound:play("error", { volume = 0.55 })
            return false
        end

        game.burnout = clamp(game.burnout + card.burnoutGain, 0, 100)

        for _, row in ipairs(game.rows) do
            row.developer.availableWork = row.developer.availableWork + card.amount
            applyWorkToRow(row)
        end

        removeCardFromHand(card.id)
        Sound:play("short_light_tap", { volume = 0.42 })
        return true
    end

    if card.effect == "target_minus_work" then
        game.techDebt = clamp(game.techDebt + card.techDebtGain, 0, 100)
        game.pendingSupport = {
            cardId = card.id,
            effect = card.effect,
            amount = card.amount,
        }
        game.selectedCardId = card.id
        card.isPendingTarget = true
        Sound:play("short_light_tap", { volume = 0.42 })
        return true
    end

    return false
end

local function endDay()
    if game.phase ~= "sprint" then
        return
    end

    if game.pendingSupport then
        return
    end

    for _, row in ipairs(game.rows) do
        applyWorkToRow(row)
    end

    for _, row in ipairs(game.rows) do
        moveCompletedInProgressToTesting(row)
    end

    for _, row in ipairs(game.rows) do
        if row.testing and row.rollout == nil then
            row.rollout = row.testing
            row.testing = nil
        end
    end

    if checkSprintTransition() then
        return
    end

    if game.day >= game.maxDays then
        enterRetrospective()
        return
    end

    game.day = game.day + 1
    resetDeveloperWork()
    drawToHandUntil(5)

    Sound:play("tick", { volume = 0.35 })
end

local function buttonEnabled(buttonId)
    if game.phase == "retrospective" then
        return buttonId == "next_sprint"
    end

    if buttonId == "play_card" then
        if game.pendingSupport then
            return false
        end
        if not game.selectedCardId then
            return false
        end
        local card = getCardById(game.selectedCardId)
        if not card or card.kind ~= "support" then
            return false
        end
        return canPlaySupportCard(card)
    end

    if buttonId == "end_day" then
        return game.pendingSupport == nil
    end

    return false
end

local function triggerButton(buttonId)
    if buttonId == "play_card" then
        local card = getCardById(game.selectedCardId)
        if card and card.kind == "support" then
            playSupportCard(card)
        end
        return
    end

    if buttonId == "end_day" then
        endDay()
        return
    end

    if buttonId == "next_sprint" then
        gotoNextSprint()
        return
    end
end

local function updateHandAnimations(dt)
    local mx, my = love.mouse.getPosition()
    local hoveredCard, hoveredIndex = getTopHandCardAtPoint(mx, my)

    local handCount = #game.hand
    local hand = game.layout.hand

    for i, card in ipairs(game.hand) do
        local tx, ty, tr = getHandTarget(i, handCount)
        card.targetX = tx
        card.targetY = ty
        card.targetRotation = tr

        local selected = (game.selectedCardId == card.id)
        if selected then
            card.targetY = card.targetY - 36
            card.targetRotation = 0
        end

        if card.isPendingTarget then
            card.targetY = card.targetY - 36
            card.targetRotation = 0
        end

        local hovered = hoveredCard and hoveredCard.id == card.id
        if hovered and not card.isDragging and not game.pendingSupport then
            card.targetY = card.targetY - 14
        end

        local targetScale = 1
        if hovered and not card.isDragging then
            targetScale = 1.02
        end
        card.targetScale = targetScale

        if card.isDragging then
            card.rotation = lerp(card.rotation, 0, math.min(1, dt * 14))
            card.scale = lerp(card.scale, 1.03, math.min(1, dt * 12))
            card.tiltX = lerp(card.tiltX, 0, math.min(1, dt * 10))
            card.tiltY = lerp(card.tiltY, 0, math.min(1, dt * 10))
        else
            local smooth = math.min(1, dt * 12)
            card.x = lerp(card.x, card.targetX, smooth)
            card.y = lerp(card.y, card.targetY, smooth)
            card.rotation = lerp(card.rotation, card.targetRotation, smooth)
            card.scale = lerp(card.scale, card.targetScale, math.min(1, dt * 10))

            if hovered and not game.pendingSupport then
                local cx = card.x + hand.cardW * 0.5
                local cy = card.y + hand.cardH * 0.5
                local nx = clamp((mx - cx) / (hand.cardW * 0.5), -1, 1)
                local ny = clamp((my - cy) / (hand.cardH * 0.5), -1, 1)
                card.tiltX = lerp(card.tiltX, -ny * 0.05, math.min(1, dt * 14))
                card.tiltY = lerp(card.tiltY, -nx * 0.05, math.min(1, dt * 14))
            else
                card.tiltX = lerp(card.tiltX, 0, math.min(1, dt * 12))
                card.tiltY = lerp(card.tiltY, 0, math.min(1, dt * 12))
            end
        end
    end

    if game.drag and game.drag.card then
        local drag = game.drag
        if not drag.isDragging then
            local dx = mx - drag.startX
            local dy = my - drag.startY
            if dx * dx + dy * dy > 64 then
                drag.isDragging = true
                drag.card.isDragging = true
            end
        end

        if drag.isDragging then
            drag.card.x = mx - drag.offsetX
            drag.card.y = my - drag.offsetY
        end
    end

    if hoveredCard and hoveredIndex then
        if not game._lastHoverCardId or game._lastHoverCardId ~= hoveredCard.id then
            Sound:play("ultra_light_tap", { volume = 0.10, pitch = 1.08 })
        end
        game._lastHoverCardId = hoveredCard.id
    else
        game._lastHoverCardId = nil
    end
end

local function getApplicantRect(index)
    local rp = game.layout.retrospective
    local x = rp.applicantStartX + (index - 1) * (rp.applicantW + rp.applicantGap)
    return {
        x = x,
        y = rp.applicantY,
        w = rp.applicantW,
        h = rp.applicantH,
    }
end

local function playCardByDrop(card, x, y)
    if card.kind == "feature" then
        local rowIndex = findRowIndexByInProgressHit(x, y)
        if not rowIndex then
            Sound:play("error", { volume = 0.45 })
            return false
        end

        local row = getRowByIndex(rowIndex)
        if not row or row.inProgress then
            Sound:play("error", { volume = 0.45 })
            return false
        end

        return playFeatureCard(card, row)
    end

    if card.kind == "support" then
        if not pointInRect(x, y, game.layout.boardDropRect) then
            Sound:play("error", { volume = 0.45 })
            return false
        end

        return playSupportCard(card)
    end

    return false
end

local function getSprintButtonAtPoint(x, y)
    local buttons = game.layout.buttons

    if pointInRect(x, y, buttons.playCard) then
        return buttons.playCard.id
    end

    if pointInRect(x, y, buttons.endDay) then
        return buttons.endDay.id
    end

    return nil
end

local function getShipRowAtPoint(x, y)
    for i, lrow in ipairs(game.layout.rows) do
        if lrow.shipButtonRect and pointInRect(x, y, lrow.shipButtonRect) then
            return i
        end
    end
    return nil
end

local function tryRetrospectiveClick(x, y)
    for i = 1, #game.applicants do
        local rect = getApplicantRect(i)
        if pointInRect(x, y, rect) and #game.developers < 5 then
            local applicant = game.applicants[i]
            table.insert(game.developers, makeDeveloper(applicant.name, applicant.work))
            table.remove(game.applicants, i)
            Sound:play("short_light_tap", { volume = 0.4 })
            return true
        end
    end

    if pointInRect(x, y, game.layout.buttons.nextSprint) then
        triggerButton("next_sprint")
        return true
    end

    return false
end

local function initializeGame()
    game.rng = love.math.newRandomGenerator(os.time())

    game.phase = "sprint"
    game.sprint = 1
    game.release = 1
    game.businessGoal = 4000
    game.revenue = 0
    game.burnout = 0
    game.techDebt = 0
    game.day = 1
    game.maxDays = 5

    game.developers = {
        makeDeveloper("Steve", 2),
    }

    game.rows = {}
    buildRows(true)
end

local function configureHotReload()
    HotReload.getState = function()
        return deepCopy({
            phase = game.phase,
            sprint = game.sprint,
            release = game.release,
            businessGoal = game.businessGoal,
            revenue = game.revenue,
            burnout = game.burnout,
            techDebt = game.techDebt,
            day = game.day,
            maxDays = game.maxDays,

            developers = game.developers,
            rows = game.rows,
            deck = game.deck,
            hand = game.hand,
            applicants = game.applicants,

            selectedCardId = game.selectedCardId,
            pendingSupport = game.pendingSupport,

            nextCardId = game.nextCardId,
            nextDeveloperId = game.nextDeveloperId,
            time = game.time,
            _lastHoverCardId = game._lastHoverCardId,
        })
    end

    HotReload.setState = function(state)
        if not state then
            return
        end

        for k, v in pairs(state) do
            game[k] = deepCopy(v)
        end

        game.drag = nil
        game.pressedButtonId = nil
        game.layout = computeLayout()
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
    love.graphics.setDefaultFilter("nearest", "nearest")

    Theme:load()

    Sound:init()

    initializeGame()
    game.layout = computeLayout()
    startSprintBoard()
    configureHotReload()
end

function love.update(dt)
    game.time = game.time + dt

    game.layout = computeLayout()
    HotReload:update(dt)

    for _, row in ipairs(game.rows) do
        if row.doneFlash and row.doneFlash > 0 then
            row.doneFlash = math.max(0, row.doneFlash - dt * 1.6)
        end
    end

    if game.phase == "sprint" then
        updateHandAnimations(dt)
    end
end

function love.draw()
    love.graphics.clear(Theme.colors.bg)

    if game.phase == "sprint" then
        BoardView.draw(Theme, game, game.layout, formatMoney)
        ButtonsView.drawSprint(Theme, game.layout, buttonEnabled)
    else
        RetrospectiveView.draw(
            Theme,
            game,
            game.layout,
            getApplicantRect,
            function(rect, label, enabled, color)
                ButtonsView.drawButton(Theme, rect, label, enabled, color)
            end
        )
    end

    SidebarView.draw(Theme, game, game.layout, formatMoney, getDaysRemaining)

    if game.phase == "sprint" then
        HandView.draw(Theme, game, game.layout, getTechDebtWorkPenalty, formatMoney)

        if game.pendingSupport then
            Theme:drawTextCenteredWithShadow(
                "Select a feature in progress",
                game.layout.boardX,
                18,
                game.layout.boardRight - game.layout.boardX,
                Theme.fonts.normal,
                { 0.17, 0.75, 0.44, 1 }
            )
        end

        if game.techDebt >= 50 then
            local penalty = "+1 Work on all Features"
            if game.techDebt >= 100 then
                penalty = "+2 Work on all Features"
            end
            Theme:drawTextWithShadow(
                penalty,
                game.layout.boardX,
                game.layout.boardTop - 54,
                Theme.fonts.small,
                Theme.colors.textDanger
            )
        end
    end

    love.graphics.setFont(Theme.fonts.small)
    HotReload:draw()
end

function love.mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    if game.phase == "retrospective" then
        tryRetrospectiveClick(x, y)
        return
    end

    if game.pendingSupport then
        local targetRow = findTargetableFeatureByPoint(x, y)
        if targetRow then
            applyPendingSupportToRow(targetRow)
        else
            Sound:play("error", { volume = 0.32 })
        end
        return
    end

    local shipRowIndex = getShipRowAtPoint(x, y)
    if shipRowIndex then
        local row = getRowByIndex(shipRowIndex)
        if row then
            shipRollout(row)
        end
        return
    end

    local buttonId = getSprintButtonAtPoint(x, y)
    if buttonId and buttonEnabled(buttonId) then
        game.pressedButtonId = buttonId
        return
    end

    local card, index = getTopHandCardAtPoint(x, y)
    if card then
        game.drag = {
            card = card,
            cardIndex = index,
            startX = x,
            startY = y,
            offsetX = x - card.x,
            offsetY = y - card.y,
            isDragging = false,
        }
    end
end

function love.mousereleased(x, y, button)
    if button ~= 1 then
        return
    end

    if game.phase ~= "sprint" then
        return
    end

    if game.pressedButtonId then
        local bid = game.pressedButtonId
        game.pressedButtonId = nil
        local buttonRect = nil
        if bid == "play_card" then
            buttonRect = game.layout.buttons.playCard
        elseif bid == "end_day" then
            buttonRect = game.layout.buttons.endDay
        end

        if buttonRect and pointInRect(x, y, buttonRect) and buttonEnabled(bid) then
            triggerButton(bid)
        end
        return
    end

    if not game.drag then
        return
    end

    local drag = game.drag
    local card = drag.card
    game.drag = nil

    card.isDragging = false

    if drag.isDragging then
        playCardByDrop(card, x, y)
        return
    end

    if card.kind == "support" then
        if game.selectedCardId == card.id then
            game.selectedCardId = nil
        else
            game.selectedCardId = card.id
            Sound:play("ultra_light_tap", { volume = 0.28 })
        end
    else
        game.selectedCardId = nil
    end
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

    if game.phase == "sprint" then
        if key == "space" then
            endDay()
            return
        end

        if key == "return" then
            if buttonEnabled("play_card") then
                triggerButton("play_card")
            end
            return
        end
    else
        if key == "return" then
            triggerButton("next_sprint")
            return
        end
    end
end
