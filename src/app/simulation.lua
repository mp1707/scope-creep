local State = require("src.app.state")
local Systems = require("src.app.systems")
local Factory = require("src.app.cards.factory")
local Stacking = require("src.app.cards.stacking")
local Motion = require("src.app.cards.motion")
local GameFlow = require("src.app.game_flow")

local Simulation = {}

local function updateRunningPhase(simDt, evalBefore)
    local boardChanged = false

    local completions = Systems.work:update(simDt, evalBefore.cardsByUid)
    for _, completion in ipairs(completions) do
        local evalNow = Systems.evaluateStacks()
        if GameFlow.resolveCompletion(completion, evalNow.cardsByUid) then
            boardChanged = true
        end
    end

    if boardChanged then
        Systems.evaluateStacks()
    end

    if Systems.effects:updateSecurityTimers(simDt, State.cards, GameFlow.systemCallbacks) then
        Systems.evaluateStacks()
    end

    if Systems.effects:mergeBugsIfNeeded(State.cards, GameFlow.systemCallbacks) then
        Systems.evaluateStacks()
    end

    if GameFlow.runSecurityGameOverCheck() then
        return true
    end

    if Systems.sprint:update(simDt) then
        GameFlow.enterPayday()
        return true
    end

    return false
end

function Simulation.update(dt)
    local timing = Systems.time:step(dt)
    local realDt = timing.realDt
    local simDt = timing.simDt

    Stacking.updateAttachedCardTargets()

    local evalBefore = Systems.evaluateStacks()
    local phase = Systems.gameState:getPhase()

    if phase == "running" or phase == "paused" then
        local techDebtCount = Systems.effects:getTechDebtCount(State.cards)
        Systems.work:sync(evalBefore.workCandidates, evalBefore.cardsByUid, Systems.recipeById, techDebtCount)
    else
        Systems.work:clear(evalBefore.cardsByUid)
    end

    if phase == "running" then
        if updateRunningPhase(simDt, evalBefore) then
            return
        end
    elseif Systems.gameState:isPayday() then
        local evalPayday = Systems.evaluateStacks()
        Systems.payday:applyPayrollAssignments(State.cards, evalPayday)
    end

    Systems.packs:update(realDt, State.cards, {
        removeCard = function(card)
            Factory.removeCard(card)
        end,
    })

    Systems.payday:updateFiredLabels(realDt)

    phase = Systems.gameState:getPhase()
    if phase == "running" or phase == "paused" then
        local lost, reason = Systems.gameover:checkSecurityIssueLoss(State.cards)
        if lost then
            Systems.gameState:setGameOver(reason)
        end
    end
end

function Simulation.updateCards(dt, worldX, worldY)
    for _, card in ipairs(State.cards) do
        if not card.motionState then
            local pointerX, pointerY = nil, nil
            if card:isDragging() then
                pointerX = worldX
                pointerY = worldY
            end
            card:update(dt, pointerX, pointerY)
        end
    end

    Motion.updatePhysicalCardMotions(dt)
end

return Simulation
