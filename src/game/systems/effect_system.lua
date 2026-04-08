local EffectSystem = {}
EffectSystem.__index = EffectSystem

local SECURITY_DELETE_INTERVAL = 30

local function sortByAge(a, b)
    local aCreated = a.createdAt or 0
    local bCreated = b.createdAt or 0
    if aCreated == bCreated then
        return (a.uid or 0) < (b.uid or 0)
    end
    return aCreated < bCreated
end

function EffectSystem.new(randomFn)
    local self = setmetatable({}, EffectSystem)
    self.randomFn = randomFn or math.random
    return self
end

function EffectSystem:setRandom(randomFn)
    self.randomFn = randomFn or self.randomFn
end

function EffectSystem:countByDefId(cards, defId)
    local count = 0
    for _, card in ipairs(cards) do
        if card.defId == defId and not card.markedForRemoval then
            count = count + 1
        end
    end
    return count
end

function EffectSystem:getTechDebtCount(cards)
    return self:countByDefId(cards, "tech_debt")
end

function EffectSystem:mergeBugsIfNeeded(cards, callbacks)
    local changed = false

    while true do
        local freeBugs = {}
        for _, card in ipairs(cards) do
            if card.defId == "bug"
                and not card.markedForRemoval
                and not card.recipeActive
                and not card.locked
            then
                table.insert(freeBugs, card)
            end
        end

        if #freeBugs < 3 then
            break
        end

        table.sort(freeBugs, sortByAge)
        local bugA = freeBugs[1]
        local bugB = freeBugs[2]
        local bugC = freeBugs[3]

        local centerX = ((bugA.x or 0) + (bugB.x or 0) + (bugC.x or 0)) / 3
        local centerY = ((bugA.y or 0) + (bugB.y or 0) + (bugC.y or 0)) / 3

        callbacks.removeCard(bugA)
        callbacks.removeCard(bugB)
        callbacks.removeCard(bugC)
        callbacks.spawnCard("security_issue", centerX, centerY, { withBounce = true })

        changed = true
    end

    return changed
end

function EffectSystem:updateSecurityTimers(simDt, cards, callbacks)
    if simDt <= 0 then
        return false
    end

    local changed = false

    for _, card in ipairs(cards) do
        if card.defId == "security_issue" and not card.markedForRemoval then
            card.effectTimers = card.effectTimers or {}
            local timer = card.effectTimers.securityDeleteMoney or 0
            timer = timer + simDt

            while timer >= SECURITY_DELETE_INTERVAL do
                timer = timer - SECURITY_DELETE_INTERVAL

                local moneyCards = {}
                for _, moneyCard in ipairs(cards) do
                    if moneyCard.defId == "money"
                        and not moneyCard.markedForRemoval
                        and not moneyCard.payrollAssigned
                    then
                        table.insert(moneyCards, moneyCard)
                    end
                end

                if #moneyCards > 0 then
                    local randomValue = self.randomFn()
                    if randomValue < 0 then randomValue = 0 end
                    if randomValue > 0.999999 then randomValue = 0.999999 end
                    local randomIndex = math.floor(randomValue * #moneyCards) + 1
                    local victim = moneyCards[randomIndex]
                    callbacks.removeCard(victim)
                    changed = true
                end
            end

            card.effectTimers.securityDeleteMoney = timer
        end
    end

    return changed
end

return EffectSystem
