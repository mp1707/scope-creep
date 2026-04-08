local UiShadow = require("src.ui.ui_shadow")
local Constants = require("src.app.constants")
local Utils = require("src.app.utils")
local State = require("src.app.state")

local Motion = {}

local clamp, lerp, damp = Utils.clamp, Utils.lerp, Utils.damp
local easeOutQuad = Utils.easeOutQuad

function Motion.createSideBounce(startX, startY, endX, endY, config)
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

local function normalizeMotion(motion, card)
    if motion.kind ~= "sideBounce" then
        motion.kind = "sideBounce"
    end
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

local function stepSideBounce(motion, card, dt)
    motion.elapsed = motion.elapsed + dt
    local progress = clamp(motion.elapsed / motion.duration, 0, 1)
    local splitA, splitB = motion.arcSplits[1], motion.arcSplits[2]
    local xSplitA, xSplitB = motion.xSplits[1], motion.xSplits[2]

    local moveT
    if progress < splitA then
        moveT = lerp(0, xSplitA, easeOutQuad(progress / splitA))
    elseif progress < splitB then
        moveT = lerp(xSplitA, xSplitB, easeOutQuad((progress - splitA) / (splitB - splitA)))
    else
        moveT = lerp(xSplitB, 1, easeOutQuad((progress - splitB) / (1 - splitB)))
    end

    card.x = lerp(motion.startX, motion.endX, moveT)

    local lift = 0
    if progress < splitA then
        lift = math.sin((progress / splitA) * math.pi) * motion.arcHeights[1]
    elseif progress < splitB then
        lift = math.sin(((progress - splitA) / (splitB - splitA)) * math.pi) * motion.arcHeights[2]
    elseif progress < 1 then
        lift = math.sin(((progress - splitB) / (1 - splitB)) * math.pi) * (motion.arcHeights[3] or 14)
    end

    card.y = lerp(motion.startY, motion.endY, moveT) - lift

    if progress >= 1 then
        card.x = motion.endX
        card.y = motion.endY
        motion.restElapsed = (motion.restElapsed or 0) + dt
        if motion.restElapsed >= motion.restHold then
            UiShadow.applyRole(card, "cardRest")
            card.motionState = nil
            card.rotation = 0
            card.renderAlpha = 1
        end
    end

    local direction = (motion.endX >= motion.startX) and 1 or -1
    card.rotation = damp(card.rotation or 0,
        math.sin(progress * math.pi) * motion.tilt * direction, 10, dt)
end

function Motion.updatePhysicalCardMotions(dt)
    for _, card in ipairs(State.cards) do
        local motion = card.motionState
        if motion then
            card.dragging = false
            card.targetScale = 1
            UiShadow.applyRole(card, "cardMotion")
            normalizeMotion(motion, card)
            stepSideBounce(motion, card, dt)

            card.x = clamp(card.x, 0, Constants.WORLD_WIDTH - (card.width or Constants.CARD_WIDTH))
            card.y = clamp(card.y, 0, Constants.WORLD_HEIGHT - (card.height or Constants.CARD_HEIGHT))
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

return Motion
