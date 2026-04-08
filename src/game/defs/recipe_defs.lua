local RecipeDefs = {}

local RECIPES = {
    {
        id = "dev_mini_requirement",
        workerRole = "dev",
        targetDefId = "mini_requirement",
        completionHandler = "dev_mini_requirement",
    },
    {
        id = "tester_untested_feature",
        workerRole = "tester",
        targetDefId = "untested_feature",
        completionHandler = "tester_untested_feature",
    },
    {
        id = "dev_bug",
        workerRole = "dev",
        targetDefId = "bug",
        completionHandler = "consume_only",
    },
    {
        id = "dev_tech_debt",
        workerRole = "dev",
        targetDefId = "tech_debt",
        completionHandler = "consume_only",
    },
    {
        id = "dev_security_issue",
        workerRole = "dev",
        targetDefId = "security_issue",
        completionHandler = "consume_only",
    },
}

local recipeIndex = {}
for _, recipe in ipairs(RECIPES) do
    local key = string.format("%s|%s", recipe.workerRole or "", recipe.targetDefId or "")
    recipeIndex[key] = recipe
end

local function randomFloat(randFn)
    local randomValue = randFn and randFn() or math.random()
    if randomValue < 0 then randomValue = 0 end
    if randomValue > 1 then randomValue = 1 end
    return randomValue
end

local handlers = {}

handlers.consume_only = function()
    return {
        consumeTarget = true,
        spawnDefIds = {},
    }
end

handlers.dev_mini_requirement = function(context)
    local spawnDefIds = { "untested_feature" }
    local worker = context.worker

    if worker and worker.defId == "junior_dev" then
        if randomFloat(context.rand) < 0.2 then
            table.insert(spawnDefIds, "tech_debt")
        end
    end

    return {
        consumeTarget = true,
        spawnDefIds = spawnDefIds,
    }
end

handlers.tester_untested_feature = function(context)
    local worker = context.worker
    if worker and worker.defId == "junior_tester" and randomFloat(context.rand) < 0.2 then
        return {
            consumeTarget = false,
            spawnDefIds = {},
        }
    end

    local spawnDefIds = { "mini_feature" }
    if randomFloat(context.rand) < 0.5 then
        table.insert(spawnDefIds, "bug")
    end

    return {
        consumeTarget = true,
        spawnDefIds = spawnDefIds,
    }
end

function RecipeDefs.find(workerRole, targetDefId)
    if not workerRole or not targetDefId then
        return nil
    end
    local key = string.format("%s|%s", workerRole, targetDefId)
    return recipeIndex[key]
end

function RecipeDefs.resolveCompletion(recipe, context)
    if not recipe then
        return nil
    end

    local handler = handlers[recipe.completionHandler]
    if not handler then
        return nil
    end

    return handler(context or {})
end

function RecipeDefs.all()
    return RECIPES
end

return RecipeDefs
