local Sprint = {}

local SPRINT_DURATION = 60
local RESOLVE_PHASE_DELAY = 0.5  -- seconds between each resolution phase
local SUMMARY_DISPLAY_DURATION = 3.0  -- how long summary is shown before auto-advancing

local state = {
    number = 1,
    elapsed = 0,
    phase = "playing",  -- "playing" | "resolving" | "summary" | "won" | "lost"
    loseReason = nil,
    resolvePhaseIndex = 0,
    resolvePhaseTimer = 0,
    summaryTimer = 0,
    stats = {
        salaryPaid = 0,
        moneyEarned = 0,
        bugsSpawned = 0,
        deadlineBonusMoney = 0,
    },
    winConditions = {
        majorFeaturesShipped = 0,
        backendDevHired = false,
    },
}

-- Phases executed at sprint end (in order)
local RESOLVE_PHASES = {
    "salary",
    "cashout_shipped",
    "deadline_miss",
    "untested_rc_to_bug",
    "tech_debt_bugs",
    "focus_reset",
    "deadline_attach",
    "check_win_lose",
    "next_sprint",
}

function Sprint.getState()
    return state
end

function Sprint.getTimeRemaining()
    return math.max(0, SPRINT_DURATION - state.elapsed)
end

function Sprint.isPlaying()
    return state.phase == "playing"
end

function Sprint.triggerLose(reason)
    if state.phase == "lost" or state.phase == "won" then return end
    state.phase = "lost"
    state.loseReason = reason or "unknown"
end

function Sprint.triggerWin()
    if state.phase == "lost" or state.phase == "won" then return end
    state.phase = "won"
end

function Sprint.reset()
    state.number = 1
    state.elapsed = 0
    state.phase = "playing"
    state.loseReason = nil
    state.resolvePhaseIndex = 0
    state.resolvePhaseTimer = 0
    state.summaryTimer = 0
    state.stats = { salaryPaid=0, moneyEarned=0, bugsSpawned=0, deadlineBonusMoney=0 }
    state.winConditions = { majorFeaturesShipped=0, backendDevHired=false }
end

function Sprint.recordMajorFeatureShipped()
    state.winConditions.majorFeaturesShipped = state.winConditions.majorFeaturesShipped + 1
end

function Sprint.recordBackendDevHired()
    state.winConditions.backendDevHired = true
end

-- Called every frame. callbacks = see main.lua
function Sprint.update(dt, callbacks)
    if state.phase == "won" or state.phase == "lost" then
        return
    end

    if state.phase == "playing" then
        state.elapsed = state.elapsed + dt

        -- Real-time lose checks
        local bugCount = callbacks.countCardsByType("bug")
        if bugCount >= 4 then
            Sprint.triggerLose("too_many_bugs")
            return
        end
        local burnoutCount = callbacks.countCardsByType("burnout")
        if burnoutCount >= 3 then
            Sprint.triggerLose("too_many_burnout")
            return
        end

        -- Sprint end
        if state.elapsed >= SPRINT_DURATION then
            state.phase = "resolving"
            state.resolvePhaseIndex = 0
            state.resolvePhaseTimer = RESOLVE_PHASE_DELAY
            state.stats = { salaryPaid=0, moneyEarned=0, bugsSpawned=0, deadlineBonusMoney=0 }
        end
        return
    end

    if state.phase == "resolving" then
        state.resolvePhaseTimer = state.resolvePhaseTimer - dt
        if state.resolvePhaseTimer > 0 then
            return
        end

        state.resolvePhaseIndex = state.resolvePhaseIndex + 1
        local phaseName = RESOLVE_PHASES[state.resolvePhaseIndex]

        if not phaseName then
            -- All phases done — show summary
            state.phase = "summary"
            state.summaryTimer = SUMMARY_DISPLAY_DURATION
            return
        end

        Sprint.executePhase(phaseName, callbacks)
        state.resolvePhaseTimer = RESOLVE_PHASE_DELAY
        return
    end

    if state.phase == "summary" then
        state.summaryTimer = state.summaryTimer - dt
        if state.summaryTimer <= 0 then
            state.phase = "playing"
        end
        return
    end
end

function Sprint.executePhase(phaseName, callbacks)
    local allCards = callbacks.getAllCards()

    if phaseName == "salary" then
        -- Pay 1 Money per paid worker by removing money cards from board
        local salary = 0
        for _, card in ipairs(allCards) do
            if card.cardType == "person" then
                local cost = callbacks.getSalaryCost(card)
                salary = salary + cost
            end
        end
        state.stats.salaryPaid = salary
        if salary > 0 then
            local ok = callbacks.spendMoney(salary)
            if not ok then
                Sprint.triggerLose("bankruptcy")
            end
        end

    elseif phaseName == "cashout_shipped" then
        -- Convert shipped cards to Money cards
        local toRemove = {}
        for _, card in ipairs(allCards) do
            if card.cardType == "shipped" then
                local amount = card.moneyAmount or (card.subType == "major_feature" and 6 or 2)
                local bonus = card.hasDeadline and 1 or 0
                local total = amount + bonus
                state.stats.moneyEarned = state.stats.moneyEarned + total
                if bonus > 0 then
                    state.stats.deadlineBonusMoney = state.stats.deadlineBonusMoney + bonus
                end
                if card.subType == "major_feature" then
                    Sprint.recordMajorFeatureShipped()
                end
                -- Spawn money cards at the shipped card's position
                callbacks.addMoney(total, card.x, card.y)
                table.insert(toRemove, card)
            end
        end
        for _, card in ipairs(toRemove) do
            callbacks.removeCard(card)
        end

    elseif phaseName == "deadline_miss" then
        -- Unshipped cards with deadline attached create extra bug
        for _, card in ipairs(allCards) do
            if card.hasDeadline and (card.cardType == "release" or card.cardType == "spec") then
                callbacks.spawnCard("bug",
                    card.x + 30, card.y - 10, {})
                state.stats.bugsSpawned = state.stats.bugsSpawned + 1
                card.hasDeadline = false
            end
        end

    elseif phaseName == "untested_rc_to_bug" then
        -- Release candidates not with a QA tester become bugs
        local toConvert = {}
        for _, card in ipairs(allCards) do
            if card.cardType == "release" then
                -- Check if it's parented to a QA tester
                local underQA = false
                if card.stackParentId then
                    local parent = callbacks.getCardById(card.stackParentId)
                    if parent and parent.role == "qa_tester" then
                        underQA = true
                    end
                end
                if not underQA then
                    table.insert(toConvert, card)
                end
            end
        end
        for _, card in ipairs(toConvert) do
            -- Convert in-place: change cardType
            card.cardType = "bug"
            card.title = "Bug"
            card.effect = "Untested RC became a bug"
            card.iconPath = "assets/handdrawn/cardIcons/bug.png"
            card.subType = nil
            card.hasDeadline = false
            card.recipeActive = false
            card.recipePartnerId = nil
            card.recipeElapsed = 0
            state.stats.bugsSpawned = state.stats.bugsSpawned + 1
        end

    elseif phaseName == "tech_debt_bugs" then
        -- Every 2 Tech Debt → spawn 1 Bug
        local debtCount = 0
        for _, card in ipairs(allCards) do
            if card.cardType == "tech_debt" then
                debtCount = debtCount + 1
            end
        end
        local newBugs = math.floor(debtCount / 2)
        for i = 1, newBugs do
            -- Spawn near center of world
            local bx = 800 + (i - 1) * 60
            local by = 500
            callbacks.spawnCard("bug", bx, by, {})
            state.stats.bugsSpawned = state.stats.bugsSpawned + 1
        end

    elseif phaseName == "focus_reset" then
        -- Reset focus on all workers
        for _, card in ipairs(allCards) do
            if card.cardType == "person" and card.maxFocus ~= nil then
                if card.isBurnedOut then
                    card.maxFocus = 1
                    card.focus = 1
                    card.isBurnedOut = false  -- clear for next sprint
                else
                    card.focus = card.maxFocus
                end
            end
        end

    elseif phaseName == "deadline_attach" then
        -- Clear existing deadlines
        for _, card in ipairs(allCards) do
            card.hasDeadline = false
        end
        -- Attach to leftmost unshipped spec or RC
        local target = nil
        local minX = math.huge
        for _, card in ipairs(allCards) do
            if (card.cardType == "spec" or card.cardType == "release") then
                if card.x < minX then
                    minX = card.x
                    target = card
                end
            end
        end
        if target then
            target.hasDeadline = true
        end

    elseif phaseName == "check_win_lose" then
        -- Check lose conditions one more time after processing
        local bugCount = callbacks.countCardsByType("bug")
        if bugCount >= 4 then
            Sprint.triggerLose("too_many_bugs")
            return
        end
        local burnoutCount = callbacks.countCardsByType("burnout")
        if burnoutCount >= 3 then
            Sprint.triggerLose("too_many_burnout")
            return
        end
        -- Win check: 5 sprints survived
        if state.number >= 5 then
            local wc = state.winConditions
            if wc.majorFeaturesShipped >= 1 and wc.backendDevHired then
                Sprint.triggerWin()
            end
        end

    elseif phaseName == "next_sprint" then
        state.number = state.number + 1
        state.elapsed = 0
    end
end

-- Serialize sprint state for hot-reload
function Sprint.serialize()
    return {
        number = state.number,
        elapsed = state.elapsed,
        phase = state.phase,
        loseReason = state.loseReason,
        winConditions = {
            majorFeaturesShipped = state.winConditions.majorFeaturesShipped,
            backendDevHired = state.winConditions.backendDevHired,
        },
    }
end

function Sprint.deserialize(saved)
    if type(saved) ~= "table" then return end
    state.number = saved.number or 1
    state.elapsed = saved.elapsed or 0
    state.phase = saved.phase or "playing"
    state.loseReason = saved.loseReason
    state.resolvePhaseIndex = 0
    state.resolvePhaseTimer = 0
    state.summaryTimer = 0
    state.stats = { salaryPaid=0, moneyEarned=0, bugsSpawned=0, deadlineBonusMoney=0 }
    if type(saved.winConditions) == "table" then
        state.winConditions.majorFeaturesShipped = saved.winConditions.majorFeaturesShipped or 0
        state.winConditions.backendDevHired = saved.winConditions.backendDevHired or false
    end
end

return Sprint
