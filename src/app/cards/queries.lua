local RecipeDefs = require("src.game.defs.recipe_defs")
local State = require("src.app.state")
local Systems = require("src.app.systems")

local Queries = {}

function Queries.getDirectChild(parentCard, excludedCards)
    for _, candidate in ipairs(State.cards) do
        if candidate.stackParentId == parentCard.uid
            and not (excludedCards and excludedCards[candidate])
        then
            return candidate
        end
    end
    return nil
end

function Queries.isDescendant(card, potentialAncestor)
    local current = card
    while current and current.stackParentId do
        local parent = State.getCardByUid(current.stackParentId)
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

function Queries.isCardDragging(cardToFind)
    for _, card in ipairs(State.dragState.draggingCards) do
        if card == cardToFind then
            return true
        end
    end
    return false
end

function Queries.isCardLocked(card)
    if not card then
        return false
    end
    return card.locked or card.markedForRemoval
        or card.shipState ~= nil or card.motionState ~= nil
end

function Queries.isPayrollCard(card)
    return card and (card.kind == "employee" or card.defId == "money")
end

function Queries.isCardInteractive(card)
    if not card or card.markedForRemoval then
        return false
    end
    if Systems.gameState:isGameOver() then
        return false
    end
    if card.locked then
        return false
    end

    if Systems.gameState:isPayday() then
        return Queries.isPayrollCard(card)
    end

    return true
end

function Queries.hasRecipeInteraction(cardA, cardB)
    if cardA.role and cardB.defId and RecipeDefs.find(cardA.role, cardB.defId) then
        return true
    end
    if cardB.role and cardA.defId and RecipeDefs.find(cardB.role, cardA.defId) then
        return true
    end
    return false
end

function Queries.canAttachCard(cardToSnap, targetCard, excludedCards)
    if not cardToSnap or not targetCard or cardToSnap == targetCard then
        return false
    end
    if Queries.isCardLocked(cardToSnap) or Queries.isCardLocked(targetCard) then
        return false
    end
    if Queries.isDescendant(targetCard, cardToSnap) then
        return false
    end
    if cardToSnap.objectType == "booster_pack" or targetCard.objectType == "booster_pack" then
        return false
    end

    if Systems.gameState:isPayday() then
        if not Queries.isPayrollCard(cardToSnap) or not Queries.isPayrollCard(targetCard) then
            return false
        end
    end

    local existingChild = Queries.getDirectChild(targetCard, excludedCards)
    if existingChild and existingChild ~= cardToSnap then
        return false
    end

    return true
end

function Queries.collectStackFrom(card)
    local selected = {}

    local function collectFrom(root)
        table.insert(selected, root)
        for _, candidate in ipairs(State.cards) do
            if candidate.stackParentId == root.uid then
                collectFrom(candidate)
            end
        end
    end

    collectFrom(card)
    return selected
end

return Queries
