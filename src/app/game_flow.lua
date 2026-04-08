local RecipeDefs = require("src.game.defs.recipe_defs")

local Constants = require("src.app.constants")
local State = require("src.app.state")
local Systems = require("src.app.systems")
local Camera = require("src.app.camera")
local Factory = require("src.app.cards.factory")
local Queries = require("src.app.cards.queries")

local GameFlow = {}

-- Shared callback bundle for systems that need to spawn/remove cards.
GameFlow.systemCallbacks = {
    spawnCard = function(defId, x, y, options)
        return Factory.spawnCard(defId, x, y, options)
    end,
    removeCard = function(card)
        Factory.removeCard(card)
    end,
}

function GameFlow.runSecurityGameOverCheck()
    local lost, reason = Systems.gameover:checkSecurityIssueLoss(State.cards)
    if not lost then
        return false
    end

    Systems.gameState:setGameOver(reason)
    Systems.evaluateStacks()
    Systems.work:clear(State.lastStackEval.cardsByUid)
    return true
end

function GameFlow.resolveCompletion(completion, cardsByUid)
    local workerCard = cardsByUid[completion.workerUid]
    local targetCard = cardsByUid[completion.targetUid]
    local recipe = Systems.recipeById[completion.recipeId]

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
    local childCard = Queries.getDirectChild(targetCard)
    local targetX, targetY = targetCard.x, targetCard.y

    if consumeTarget then
        if not parentId and completion.softwareUids and #completion.softwareUids > 0 then
            local softwareCard = cardsByUid[completion.softwareUids[1]]
            if softwareCard and not Queries.getDirectChild(softwareCard) then
                parentId = softwareCard.uid
            end
        end

        Factory.removeCard(targetCard)
    end

    local spawned = {}
    for index, defId in ipairs(spawnDefIds) do
        local offsetX = (index - 1) * 16
        local offsetY = (index - 1) * 10
        local spawnedCard = Factory.spawnCard(defId, targetX + offsetX, targetY + offsetY, {
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
        State.bringCardsToFront(spawned)
    end

    return consumeTarget or (#spawned > 0)
end

function GameFlow.enterPayday()
    if Systems.gameState:getPhase() == "gameover" then
        return
    end

    Systems.gameState:setPhase("payday")

    local preEval = Systems.evaluateStacks()
    Systems.payday:enter(State.cards, preEval, {
        spawnCard = GameFlow.systemCallbacks.spawnCard,
        removeCard = GameFlow.systemCallbacks.removeCard,
        mergeBugs = function()
            Systems.effects:mergeBugsIfNeeded(State.cards, GameFlow.systemCallbacks)
        end,
    })

    local postEval = Systems.evaluateStacks()
    Systems.payday:applyPayrollAssignments(State.cards, postEval)
    Systems.work:clear(postEval.cardsByUid)

    GameFlow.runSecurityGameOverCheck()
end

function GameFlow.startNextSprintFromPayday()
    local eval = Systems.evaluateStacks()

    local result = Systems.payday:startNextSprint(State.cards, eval, {
        spawnCard = GameFlow.systemCallbacks.spawnCard,
        removeCard = GameFlow.systemCallbacks.removeCard,
    })

    Systems.effects:mergeBugsIfNeeded(State.cards, GameFlow.systemCallbacks)

    local noTeam, reason = Systems.gameover:checkNoEmployeeLoss(State.cards)
    if noTeam then
        Systems.gameState:setGameOver(reason)
        local refreshed = Systems.evaluateStacks()
        Systems.work:clear(refreshed.cardsByUid)
        return
    end

    Systems.sprint:resetForNextSprint()
    Systems.gameState:setPhase("running")

    local refreshed = Systems.evaluateStacks()
    Systems.payday:clearPayrollFlags(State.cards)
    Systems.work:clear(refreshed.cardsByUid)

    if result and result.employeeCount <= 0 then
        Systems.gameState:setGameOver("no_team_left")
    end
end

function GameFlow.bootstrapNewGame()
    State.reset()

    Systems.setup()
    Factory.createStartBoard()
    Systems.evaluateStacks()

    Systems.gameState:setPhase("running")

    Camera.reset()
    Camera.centerOn(Constants.WORLD_WIDTH * 0.5, Constants.WORLD_HEIGHT * 0.5)
end

return GameFlow
