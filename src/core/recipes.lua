local Recipes = {}

-- ── Recipe definitions ────────────────────────────────────────────────────────
-- parentRole: card.role on the worker (parent) card
-- parentType: alternative match by card.cardType (for non-role matches)
-- childType:  card.cardType of the work item (child) card
-- childSubType: optional card.subType filter
-- baseDuration: seconds, before tech debt bonus
-- techDebtBonus: extra seconds per Tech Debt card on board (0 = no bonus)
-- focusCost: focus consumed from the worker
-- outputs: array of { defKey, probability }. If one entry has probability 1.0 it's deterministic.
--          probability is cumulative: first entry checked with math.random() < probability.
-- sideEffects: optional array of extra defKeys to also spawn (always, no probability)
-- consumeWorker: bool (default false) — worker is also consumed (not used in current spec)
-- instantComplete: bool — complete on the very first update frame (duration=0 effectively)

local RECIPE_TABLE = {
    -- Product Owner refines requests
    {
        id = "po_qw_request",
        parentRole = "product_owner",
        childType = "request",
        childSubType = "quick_win",
        baseDuration = 4,
        techDebtBonus = 0,
        focusCost = 0,
        outputs = { { defKey = "quick_win_spec", probability = 1.0 } },
    },
    {
        id = "po_bigbet_request",
        parentRole = "product_owner",
        childType = "request",
        childSubType = "big_bet",
        baseDuration = 5,
        techDebtBonus = 0,
        focusCost = 0,
        outputs = { { defKey = "big_feature_spec", probability = 1.0 } },
    },
    {
        id = "po_client_request",
        parentRole = "product_owner",
        childType = "request",
        childSubType = "client",
        baseDuration = 4,
        techDebtBonus = 0,
        focusCost = 0,
        outputs = {
            { defKey = "quick_win_spec",   probability = 0.70 },
            { defKey = "big_feature_spec", probability = 1.00 },
        },
    },

    -- Fullstack Dev implementation
    {
        id = "fullstack_qw_spec",
        parentRole = "fullstack_dev",
        childType = "spec",
        childSubType = "quick_win",
        baseDuration = 8,
        techDebtBonus = 1,
        focusCost = 1,
        outputs = { { defKey = "release_quick_win", probability = 1.0 } },
    },
    {
        id = "fullstack_bigfeature_spec",
        parentRole = "fullstack_dev",
        childType = "spec",
        childSubType = "big_feature",
        baseDuration = 12,
        techDebtBonus = 1,
        focusCost = 2,
        outputs = { { defKey = "release_major_feature", probability = 1.0 } },
        sideEffects = { "tech_debt" },  -- always also spawn 1 Tech Debt
    },

    -- Frontend Dev implementation
    {
        id = "frontend_qw_spec",
        parentRole = "frontend_dev",
        childType = "spec",
        childSubType = "quick_win",
        baseDuration = 7,
        techDebtBonus = 1,
        focusCost = 1,
        outputs = { { defKey = "release_quick_win", probability = 1.0 } },
    },
    {
        id = "frontend_bigfeature_spec",
        parentRole = "frontend_dev",
        childType = "spec",
        childSubType = "big_feature",
        baseDuration = 8,
        techDebtBonus = 1,
        focusCost = 1,
        outputs = { { defKey = "frontend_build", probability = 1.0 } },
    },

    -- Backend Dev implementation
    {
        id = "backend_bigfeature_spec",
        parentRole = "backend_dev",
        childType = "spec",
        childSubType = "big_feature",
        baseDuration = 8,
        techDebtBonus = 1,
        focusCost = 1,
        outputs = { { defKey = "backend_build", probability = 1.0 } },
    },

    -- Build combination: Frontend Build + Backend Build → instant RC
    -- Both builds can stack on each other (either ordering works)
    {
        id = "build_combine",
        childType = "build",
        childSubType = "backend",
        parentType = "build",   -- parent is a frontend build
        parentSubType = "frontend",
        baseDuration = 0,
        techDebtBonus = 0,
        focusCost = 0,
        instantComplete = true,
        outputs = { { defKey = "release_major_feature", probability = 1.0 } },
    },
    {
        id = "build_combine_rev",
        childType = "build",
        childSubType = "frontend",
        parentType = "build",   -- parent is a backend build
        parentSubType = "backend",
        baseDuration = 0,
        techDebtBonus = 0,
        focusCost = 0,
        instantComplete = true,
        outputs = { { defKey = "release_major_feature", probability = 1.0 } },
    },

    -- QA testing
    {
        id = "qa_qw_rc",
        parentRole = "qa_tester",
        childType = "release",
        childSubType = "quick_win",
        baseDuration = 5,
        techDebtBonus = 0,
        focusCost = 1,
        outputs = { { defKey = "shipped_quick_win", probability = 1.0 } },
    },
    {
        id = "qa_major_rc",
        parentRole = "qa_tester",
        childType = "release",
        childSubType = "major_feature",
        baseDuration = 7,
        techDebtBonus = 0,
        focusCost = 1,
        outputs = { { defKey = "shipped_major_feature", probability = 1.0 } },
    },

    -- Tech Debt cleanup
    {
        id = "fullstack_debt",
        parentRole = "fullstack_dev",
        childType = "tech_debt",
        baseDuration = 6,
        techDebtBonus = 0,
        focusCost = 1,
        outputs = {},  -- consumes tech_debt, produces nothing
    },
    {
        id = "backend_debt",
        parentRole = "backend_dev",
        childType = "tech_debt",
        baseDuration = 5,
        techDebtBonus = 0,
        focusCost = 1,
        outputs = {},
    },

    -- Bug fixing
    {
        id = "qa_bug",
        parentRole = "qa_tester",
        childType = "bug",
        baseDuration = 5,
        techDebtBonus = 0,
        focusCost = 1,
        outputs = {},  -- removes bug
    },
    {
        id = "fullstack_bug",
        parentRole = "fullstack_dev",
        childType = "bug",
        baseDuration = 3,
        techDebtBonus = 0,
        focusCost = 1,
        outputs = {},  -- removes bug...
        sideEffects = { "tech_debt" }, -- ...but creates tech debt
    },

    -- Coffee restores focus (instant) — coffee dropped ON worker
    {
        id = "worker_coffee",
        parentType = "person",   -- any person card
        childType = "coffee",
        baseDuration = 0,
        techDebtBonus = 0,
        focusCost = 0,
        instantComplete = true,
        outputs = {},  -- no output card; focus restoration is a side effect
        restoreFocus = 1,  -- special flag: restore 1 focus to parent worker
    },

    -- Burnout cleared by coffee (5 seconds) — burnout dropped ON coffee card
    -- Parent = coffee card, child = burnout card
    {
        id = "coffee_burnout",
        parentType = "coffee",
        childType = "burnout",
        baseDuration = 5,
        techDebtBonus = 0,
        focusCost = 0,
        outputs = {},  -- removes both coffee and burnout
        clearBurnout = true,  -- special flag: look at childCard.ownerWorkerId to clear isBurnedOut
    },
}

-- Build a fast lookup by (parentRole|parentType, childType, childSubType)
local function makeKey(parentRole, parentType, parentSubType, childType, childSubType)
    return (parentRole or "") .. "|" .. (parentType or "") .. "|" .. (parentSubType or "")
        .. "|" .. (childType or "") .. "|" .. (childSubType or "")
end

local recipeIndex = {}
for _, recipe in ipairs(RECIPE_TABLE) do
    local key = makeKey(
        recipe.parentRole, recipe.parentType, recipe.parentSubType,
        recipe.childType, recipe.childSubType
    )
    if not recipeIndex[key] then
        recipeIndex[key] = {}
    end
    table.insert(recipeIndex[key], recipe)
end

-- ── Public API ────────────────────────────────────────────────────────────────

-- Count all cards of a given type (and optional subType) on the board
function Recipes.countCardsOfType(allCards, cardType, subType)
    local count = 0
    for _, card in ipairs(allCards) do
        if card.cardType == cardType then
            if subType == nil or card.subType == subType then
                count = count + 1
            end
        end
    end
    return count
end

-- Try to find a matching recipe given parent and child cards
-- Returns recipe table or nil
function Recipes.findMatch(parentCard, childCard, allCards)
    if not parentCard or not childCard then return nil end

    local pRole = parentCard.role or ""
    local pType = parentCard.cardType or ""
    local pSubType = parentCard.subType or ""
    local cType = childCard.cardType or ""
    local cSubType = childCard.subType or ""

    -- Try role-based match first
    local key1 = makeKey(pRole, "", "", cType, cSubType)
    if recipeIndex[key1] then
        return recipeIndex[key1][1]
    end

    -- Try role match without subType
    local key2 = makeKey(pRole, "", "", cType, "")
    if pRole ~= "" and recipeIndex[key2] and cSubType ~= "" then
        -- Make sure the recipe doesn't require a specific subType we don't have
        local r = recipeIndex[key2][1]
        if not r.childSubType or r.childSubType == "" then
            return r
        end
    end

    -- Try cardType-based match (for build+build, coffee+person, etc.)
    local key3 = makeKey("", pType, pSubType, cType, cSubType)
    if recipeIndex[key3] then
        return recipeIndex[key3][1]
    end

    -- Try cardType match without subType
    local key4 = makeKey("", pType, "", cType, cSubType)
    if recipeIndex[key4] then
        local r = recipeIndex[key4][1]
        if not r.parentSubType or r.parentSubType == "" then
            return r
        end
    end

    -- Try cardType match without any subType
    local key5 = makeKey("", pType, "", cType, "")
    if pType ~= "" and recipeIndex[key5] and cSubType ~= "" then
        local r = recipeIndex[key5][1]
        if (not r.parentSubType or r.parentSubType == "") and (not r.childSubType or r.childSubType == "") then
            return r
        end
    end

    return nil
end

-- Compute effective duration for a recipe given current board state
function Recipes.computeDuration(recipe, allCards)
    local base = recipe.baseDuration or 0
    local debtCount = Recipes.countCardsOfType(allCards, "tech_debt")
    local bonus = (recipe.techDebtBonus or 0) * debtCount
    return base + bonus
end

-- Start a recipe on parent+child pair. Sets fields on child (work item) card.
-- Returns true if started.
function Recipes.startRecipe(parentCard, childCard, recipe, allCards)
    if not parentCard or not childCard or not recipe then return false end

    local duration = Recipes.computeDuration(recipe, allCards)

    childCard.recipeActive = true
    childCard.recipeElapsed = 0
    childCard.recipeDuration = duration
    childCard.recipePartnerId = parentCard.id
    childCard.workProgress = 0

    -- Mark partner on parent too (so we can cancel from either end)
    parentCard.recipePartnerId = childCard.id

    return true
end

-- Cancel a recipe on a card (and its partner if found)
function Recipes.cancelRecipe(card, allCards)
    if not card then return end

    local partnerId = card.recipePartnerId
    card.recipeActive = false
    card.recipeElapsed = 0
    card.recipeDuration = nil
    card.recipePartnerId = nil
    card.workProgress = 0

    if partnerId and allCards then
        for _, other in ipairs(allCards) do
            if other.id == partnerId then
                other.recipeActive = false
                other.recipeElapsed = 0
                other.recipeDuration = nil
                other.recipePartnerId = nil
                other.workProgress = 0
                break
            end
        end
    end
end

-- Roll the output defKey based on recipe.outputs probabilities
local function rollOutput(recipe)
    if not recipe.outputs or #recipe.outputs == 0 then
        return nil
    end
    if #recipe.outputs == 1 then
        return recipe.outputs[1].defKey
    end
    local roll = math.random()
    for _, entry in ipairs(recipe.outputs) do
        if roll < entry.probability then
            return entry.defKey
        end
    end
    return recipe.outputs[#recipe.outputs].defKey
end

-- Complete a recipe. Calls callbacks to mutate game state.
-- callbacks = {
--   spawnCard(defKey, x, y, overrides) -> card,
--   removeCard(card),
--   getCardById(id) -> card,
--   countCardsByType(cardType, subType) -> number,
--   addFocusToWorker(workerCard, amount),
--   spawnBurnoutForWorker(workerCard),
--   onMajorFeatureShipped(),
-- }
function Recipes.complete(parentCard, childCard, recipe, allCards, callbacks)
    if not parentCard or not childCard or not recipe then return end

    -- Clear recipe state on both cards before spawning (so they don't block)
    local spawnX = childCard.x
    local spawnY = childCard.y
    local workerCard = parentCard  -- the worker is always the parent

    -- Deduct focus from worker (if worker is a person)
    local focusCost = recipe.focusCost or 0
    if focusCost > 0 and parentCard.cardType == "person" and parentCard.focus ~= nil then
        if parentCard.focus <= 0 then
            -- Already at 0 — spawn burnout
            if callbacks.spawnBurnoutForWorker then
                callbacks.spawnBurnoutForWorker(parentCard)
            end
        else
            parentCard.focus = math.max(0, parentCard.focus - focusCost)
            if parentCard.focus <= 0 then
                -- Just hit 0 from this task — also spawn burnout
                if callbacks.spawnBurnoutForWorker then
                    callbacks.spawnBurnoutForWorker(parentCard)
                end
            end
        end
    end

    -- Special: coffee restores focus
    if recipe.restoreFocus and recipe.restoreFocus > 0 then
        if parentCard.cardType == "person" and parentCard.focus ~= nil then
            local maxF = parentCard.maxFocus or 2
            parentCard.focus = math.min(maxF, (parentCard.focus or 0) + recipe.restoreFocus)
        end
    end

    -- Special: clear burnout (childCard is the burnout card, ownerWorkerId points to its worker)
    if recipe.clearBurnout then
        local ownerId = childCard.ownerWorkerId
        if ownerId and allCards then
            for _, c in ipairs(allCards) do
                if c.id == ownerId then
                    c.isBurnedOut = false
                    break
                end
            end
        end
    end

    -- Clear recipe fields on both cards
    Recipes.cancelRecipe(childCard, allCards)

    -- Remove input cards
    if callbacks.removeCard then
        callbacks.removeCard(childCard)
        -- Workers (person cards) persist; everything else is consumed
        if parentCard.cardType ~= "person" then
            callbacks.removeCard(parentCard)
        end
    end

    -- Spawn output card(s)
    local outputDefKey = rollOutput(recipe)
    local spawnedCard = nil
    if outputDefKey and callbacks.spawnCard then
        spawnedCard = callbacks.spawnCard(outputDefKey, spawnX, spawnY, {
            hasDeadline = childCard.hasDeadline or false,
        })
        -- Track major features shipped
        if outputDefKey == "shipped_major_feature" and callbacks.onMajorFeatureShipped then
            callbacks.onMajorFeatureShipped()
        end
    end

    -- Spawn side effects (e.g., tech_debt from fullstack big feature)
    if recipe.sideEffects and callbacks.spawnCard then
        for _, sideKey in ipairs(recipe.sideEffects) do
            callbacks.spawnCard(sideKey, spawnX + 40, spawnY + 20, {})
        end
    end

    return spawnedCard
end

-- Convenience: find the recipe for a currently-active child card
function Recipes.findRecipeForActiveCard(card)
    if not card or not card.recipeActive then return nil end
    for _, recipe in ipairs(RECIPE_TABLE) do
        -- We find by ID stored on the card if available, otherwise search
    end
    -- Fallback: look through all recipes. In practice we store recipeId on card.
    return nil
end

-- Return the full recipe table (for introspection/testing)
function Recipes.getAll()
    return RECIPE_TABLE
end

return Recipes
