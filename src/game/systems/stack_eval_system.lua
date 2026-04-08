local StackEvalSystem = {}
StackEvalSystem.__index = StackEvalSystem

local function pushByParent(childrenByParent, parentId, child)
    if not childrenByParent[parentId] then
        childrenByParent[parentId] = {}
    end
    table.insert(childrenByParent[parentId], child)
end

local function sortByCreation(a, b)
    local aCreated = a.createdAt or 0
    local bCreated = b.createdAt or 0
    if aCreated == bCreated then
        return (a.uid or 0) < (b.uid or 0)
    end
    return aCreated < bCreated
end

function StackEvalSystem.new()
    local self = setmetatable({}, StackEvalSystem)
    return self
end

function StackEvalSystem:evaluate(cards, recipeDefs)
    local cardsByUid = {}
    local childrenByParent = {}

    for _, card in ipairs(cards) do
        cardsByUid[card.uid] = card
    end

    for _, card in ipairs(cards) do
        local parentId = card.stackParentId
        if parentId and cardsByUid[parentId] then
            pushByParent(childrenByParent, parentId, card)
        end
    end

    for _, children in pairs(childrenByParent) do
        table.sort(children, sortByCreation)
    end

    local roots = {}
    for _, card in ipairs(cards) do
        local parentId = card.stackParentId
        if not parentId or not cardsByUid[parentId] then
            table.insert(roots, card)
        end
    end
    table.sort(roots, sortByCreation)

    local stacks = {}

    local function collectStackMembers(root)
        local members = {}
        local queue = { root }
        local queueIndex = 1

        while queueIndex <= #queue do
            local current = queue[queueIndex]
            queueIndex = queueIndex + 1
            table.insert(members, current)

            local children = childrenByParent[current.uid]
            if children then
                for _, child in ipairs(children) do
                    table.insert(queue, child)
                end
            end
        end

        table.sort(members, sortByCreation)
        return members
    end

    local workCandidates = {}
    local payrollPairs = {}

    for _, root in ipairs(roots) do
        local members = collectStackMembers(root)
        local workers = {}
        local todos = {}
        local softwareCards = {}
        local employeeCards = {}
        local moneyCards = {}

        for _, card in ipairs(members) do
            if card.kind == "employee" then
                table.insert(workers, card)
                table.insert(employeeCards, card)
            elseif card.kind == "todo" then
                table.insert(todos, card)
            elseif card.kind == "project" and card.defId == "software" then
                table.insert(softwareCards, card)
            elseif card.defId == "money" then
                table.insert(moneyCards, card)
            end
        end

        local stack = {
            id = root.uid,
            rootUid = root.uid,
            members = members,
            workerCount = #workers,
            todoCount = #todos,
            softwareCards = softwareCards,
            employeeCards = employeeCards,
            moneyCards = moneyCards,
        }

        if #workers == 1 and #todos == 1 then
            local worker = workers[1]
            local target = todos[1]
            local recipe = recipeDefs.find(worker.role, target.defId)
            if recipe then
                local memberUids = {}
                for _, member in ipairs(members) do
                    table.insert(memberUids, member.uid)
                end

                table.insert(workCandidates, {
                    stackId = root.uid,
                    workerUid = worker.uid,
                    targetUid = target.uid,
                    recipeId = recipe.id,
                    softwareUids = (function()
                        local softwareUids = {}
                        for _, software in ipairs(softwareCards) do
                            table.insert(softwareUids, software.uid)
                        end
                        return softwareUids
                    end)(),
                    memberUids = memberUids,
                })
            end
        end

        if #members == 2 and #employeeCards == 1 and #moneyCards == 1 then
            table.insert(payrollPairs, {
                stackId = root.uid,
                employeeUid = employeeCards[1].uid,
                moneyUid = moneyCards[1].uid,
            })
        end

        table.insert(stacks, stack)
    end

    return {
        cardsByUid = cardsByUid,
        childrenByParent = childrenByParent,
        roots = roots,
        stacks = stacks,
        workCandidates = workCandidates,
        payrollPairs = payrollPairs,
    }
end

return StackEvalSystem
