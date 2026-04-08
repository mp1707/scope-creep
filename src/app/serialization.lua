local Card = require("src.ui.card")
local BoosterPack = require("src.ui.booster_pack")
local CardDefs = require("src.game.defs.card_defs")

local State = require("src.app.state")
local Utils = require("src.app.utils")
local Factory = require("src.app.cards.factory")

local Serialization = {}

function Serialization.serializeCards()
    local snapshots = {}

    for _, card in ipairs(State.cards) do
        if not card.shipState then
            local snapshot = card:getSnapshot()

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
            snapshot.effectTimers = Utils.copyState(card.effectTimers)
            snapshot.markedForRemoval = card.markedForRemoval
            snapshot.renderAlpha = card.renderAlpha
            snapshot.packRuntime = Utils.copyState(card.packRuntime)

            table.insert(snapshots, snapshot)
        end
    end

    return snapshots
end

function Serialization.restoreCards(cardSnapshots)
    State.cards = {}
    local maxUid = 0

    for _, snapshot in ipairs(cardSnapshots or {}) do
        local restored
        if snapshot.objectType == "booster_pack" then
            restored = BoosterPack.new(snapshot)
            restored.packRuntime = Utils.copyState(snapshot.packRuntime)
            restored.kind = snapshot.kind or "pack"
            restored.defId = snapshot.defId
        else
            restored = Card.new(snapshot)
            restored.defId = snapshot.defId
            if restored.defId then
                Factory.applyCardRuntimeDefaults(restored, restored.defId, snapshot.createdAt)
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

        if restored.uid and restored.uid > maxUid then
            maxUid = restored.uid
        end

        table.insert(State.cards, restored)
    end

    if maxUid >= State.nextUid then
        State.nextUid = maxUid + 1
    end
end

return Serialization
