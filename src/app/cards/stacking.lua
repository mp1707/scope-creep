local Constants = require("src.app.constants")
local State = require("src.app.state")
local Utils = require("src.app.utils")
local Queries = require("src.app.cards.queries")

local Stacking = {}

local clamp = Utils.clamp

function Stacking.findBestStackTarget(cardToSnap, excludedCards)
    local best = nil
    local bestDistSq = Constants.STACK_SNAP_DISTANCE * Constants.STACK_SNAP_DISTANCE

    for _, other in ipairs(State.cards) do
        if other ~= cardToSnap and not (excludedCards and excludedCards[other]) then
            if Queries.canAttachCard(cardToSnap, other, excludedCards) then
                local snapX = other.targetX
                local snapY = other.targetY + Constants.STACK_OFFSET_Y
                local dx = cardToSnap.targetX - snapX
                local dy = cardToSnap.targetY - snapY
                local distSq = dx * dx + dy * dy
                if distSq <= bestDistSq then
                    bestDistSq = distSq
                    best = { parent = other, x = snapX, y = snapY }
                end
            end
        end
    end

    return best
end

function Stacking.applyStackSnap(cardToSnap, excludedCards)
    local target = Stacking.findBestStackTarget(cardToSnap, excludedCards)
    if not target then
        cardToSnap.stackParentId = nil
        return false
    end

    cardToSnap.stackParentId = target.parent.uid
    cardToSnap.targetX = clamp(target.x, 0, Constants.WORLD_WIDTH - (cardToSnap.width or Constants.CARD_WIDTH))
    cardToSnap.targetY = clamp(target.y, 0, Constants.WORLD_HEIGHT - (cardToSnap.height or Constants.CARD_HEIGHT))
    return true
end

function Stacking.updateAttachedCardTargets()
    for _, card in ipairs(State.cards) do
        if card.stackParentId and not card:isDragging() and not card.motionState then
            local parent = State.getCardByUid(card.stackParentId)
            if parent then
                card.targetX = clamp(parent.targetX, 0, Constants.WORLD_WIDTH - (card.width or Constants.CARD_WIDTH))
                card.targetY = clamp(parent.targetY + Constants.STACK_OFFSET_Y, 0,
                    Constants.WORLD_HEIGHT - (card.height or Constants.CARD_HEIGHT))
            else
                card.stackParentId = nil
            end
        end
    end
end

return Stacking
