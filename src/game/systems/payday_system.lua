local PaydaySystem = {}
PaydaySystem.__index = PaydaySystem

local function isEmployee(card)
    return card and card.kind == "employee"
end

local function isMoney(card)
    return card and card.defId == "money"
end

local function hasDirectSoftwareNeighbor(card, cardsByUid, childrenByParent)
    if not card then
        return false
    end

    local parent = cardsByUid[card.stackParentId]
    if parent and parent.defId == "software" then
        return true
    end

    local children = childrenByParent[card.uid]
    if children then
        for _, child in ipairs(children) do
            if child.defId == "software" then
                return true
            end
        end
    end

    return false
end

function PaydaySystem.new()
    local self = setmetatable({}, PaydaySystem)
    self.firedLabels = {}
    return self
end

function PaydaySystem:clearPayrollFlags(cards)
    for _, card in ipairs(cards) do
        card.assignedToPayroll = false
        card.payrollAssigned = false
        if card.defId == "money" or card.kind == "employee" then
            card.dimmed = false
        end
    end
end

function PaydaySystem:applyPayrollAssignments(cards, stackEvalResult)
    self:clearPayrollFlags(cards)

    for _, pair in ipairs(stackEvalResult.payrollPairs or {}) do
        local employee = stackEvalResult.cardsByUid[pair.employeeUid]
        local money = stackEvalResult.cardsByUid[pair.moneyUid]

        if isEmployee(employee) and isMoney(money) then
            employee.assignedToPayroll = true
            employee.dimmed = true
            money.payrollAssigned = true
            money.dimmed = true
        end
    end
end

function PaydaySystem:updateFiredLabels(realDt)
    for i = #self.firedLabels, 1, -1 do
        local label = self.firedLabels[i]
        label.elapsed = label.elapsed + realDt
        if label.elapsed >= label.duration then
            table.remove(self.firedLabels, i)
        end
    end
end

function PaydaySystem:getFiredLabels()
    return self.firedLabels
end

function PaydaySystem:enter(cards, stackEvalResult, callbacks)
    self:clearPayrollFlags(cards)

    local bugs = {}
    for _, card in ipairs(cards) do
        if card.defId == "bug" and not card.markedForRemoval then
            table.insert(bugs, card)
        end
    end

    for _, bug in ipairs(bugs) do
        callbacks.spawnCard("bug", (bug.x or 0) + 26, (bug.y or 0) + 18, { withBounce = true })
    end

    callbacks.mergeBugs()

    local revenueSpawnCount = 0
    for _, card in ipairs(cards) do
        if card.defId == "mini_feature"
            and not card.markedForRemoval
            and hasDirectSoftwareNeighbor(card, stackEvalResult.cardsByUid, stackEvalResult.childrenByParent)
        then
            callbacks.spawnCard("money", (card.x or 0) + 18, (card.y or 0) - 8, { withBounce = true })
            callbacks.spawnCard("money", (card.x or 0) + 38, (card.y or 0) + 8, { withBounce = true })
            revenueSpawnCount = revenueSpawnCount + 2
        end
    end

    self:applyPayrollAssignments(cards, stackEvalResult)

    return {
        revenueSpawned = revenueSpawnCount,
        bugDuplicates = #bugs,
    }
end

function PaydaySystem:startNextSprint(cards, stackEvalResult, callbacks)
    local removedEmployees = 0

    for i = #cards, 1, -1 do
        local card = cards[i]
        if card.kind == "employee" and not card.assignedToPayroll then
            table.insert(self.firedLabels, {
                x = card.x + (card.width * 0.5),
                y = card.y + (card.height * 0.4),
                text = "gekündigt",
                elapsed = 0,
                duration = 0.8,
            })
            callbacks.removeCard(card)
            removedEmployees = removedEmployees + 1
        end
    end

    for i = #cards, 1, -1 do
        local card = cards[i]
        if card.defId == "money" and card.payrollAssigned then
            callbacks.removeCard(card)
        end
    end

    self:clearPayrollFlags(cards)

    local childrenByParent = {}
    for _, card in ipairs(cards) do
        local parentId = card.stackParentId
        if parentId then
            if not childrenByParent[parentId] then
                childrenByParent[parentId] = {}
            end
            table.insert(childrenByParent[parentId], card)
        end
    end

    local function collectStackMembersFor(rootCard)
        local members = {}
        local visited = {}
        local queue = { rootCard }
        local index = 1

        while index <= #queue do
            local current = queue[index]
            index = index + 1
            if current and not visited[current.uid] then
                visited[current.uid] = true
                table.insert(members, current)
                local children = childrenByParent[current.uid]
                if children then
                    for _, child in ipairs(children) do
                        table.insert(queue, child)
                    end
                end
            end
        end

        return members
    end

    local spawnedRequirements = 0
    for _, card in ipairs(cards) do
        if card.defId == "software" and not card.markedForRemoval then
            local stackMembers = collectStackMembersFor(card)
            local hasOpenRequirement = false

            for _, member in ipairs(stackMembers) do
                if member.defId == "mini_requirement" or member.defId == "untested_feature" then
                    hasOpenRequirement = true
                    break
                end
            end

            if not hasOpenRequirement then
                callbacks.spawnCard("mini_requirement", (card.x or 0) + 24, (card.y or 0) + 26, { withBounce = true })
                spawnedRequirements = spawnedRequirements + 1
            end
        end
    end

    local employeeCount = 0
    for _, card in ipairs(cards) do
        if card.kind == "employee" and not card.markedForRemoval then
            employeeCount = employeeCount + 1
        end
    end

    return {
        removedEmployees = removedEmployees,
        spawnedRequirements = spawnedRequirements,
        employeeCount = employeeCount,
    }
end

return PaydaySystem
