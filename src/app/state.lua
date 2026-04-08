-- Mutable application state. Other modules require this module to read
-- and mutate the board, drag state, and transient UI flags.

local State = {
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

function State.reset()
    State.time = 0
    State.nextUid = 1
    State.cards = {}
    State.lastStackEval = nil

    State.dragState.draggingCards = {}
    State.dragState.dragRootCard = nil
    State.dragState.dragPressStartScreenX = nil
    State.dragState.dragPressStartScreenY = nil
    State.dragState.panningWorld = false

    State.uiState.nextButtonPressed = false
end

function State.allocateUid()
    local uid = State.nextUid
    State.nextUid = uid + 1
    return uid
end

function State.getCardByUid(uid)
    if uid == nil then
        return nil
    end
    for _, card in ipairs(State.cards) do
        if card.uid == uid then
            return card
        end
    end
    return nil
end

function State.bringCardsToFront(cardsToRaise)
    local selected = {}
    for _, card in ipairs(cardsToRaise) do
        selected[card] = true
    end

    local reordered = {}
    for _, card in ipairs(State.cards) do
        if not selected[card] then
            table.insert(reordered, card)
        end
    end
    for _, card in ipairs(State.cards) do
        if selected[card] then
            table.insert(reordered, card)
        end
    end

    State.cards = reordered
end

return State
