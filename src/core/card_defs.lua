local CardDefs = {}

local STEVE_ICON_PATH        = "assets/handdrawn/characters/steve.png"
local MONEY_ICON_PATH        = "assets/handdrawn/cardIcons/money.png"
local COFFEE_ICON_PATH       = "assets/handdrawn/cardIcons/coffee.png"
local MAIL_ICON_PATH         = "assets/handdrawn/cardIcons/mail.png"
local STAR_ICON_PATH         = "assets/handdrawn/cardIcons/star.png"
local BUG_ICON_PATH          = "assets/handdrawn/cardIcons/bug.png"
local FIRE_ICON_PATH         = "assets/handdrawn/cardIcons/fire.png"
local CALENDAR_ICON_PATH     = "assets/handdrawn/cardIcons/calendar.png"
local EXCLAMATION_ICON_PATH  = "assets/handdrawn/cardIcons/exclamationmark.png"

-- All card definitions. Keys are used in recipes as defKey.
-- Starting cards also listed in STARTING_LAYOUT below.
local DEFS = {
    -- ── People ──────────────────────────────────────────────────────────────
    product_owner = {
        cardType = "person",
        role = "product_owner",
        title = "Product Owner",
        effect = "Refines requests into specs",
        iconPath = STEVE_ICON_PATH,
        maxFocus = 2,
        focus = 2,
    },
    fullstack_dev = {
        cardType = "person",
        role = "fullstack_dev",
        title = "Fullstack Dev",
        effect = "Can do it all, but spreads thin",
        iconPath = STEVE_ICON_PATH,
        maxFocus = 2,
        focus = 2,
    },
    frontend_dev = {
        cardType = "person",
        role = "frontend_dev",
        title = "Frontend Dev",
        effect = "Fast with UI work",
        iconPath = STEVE_ICON_PATH,
        maxFocus = 2,
        focus = 2,
    },
    qa_tester = {
        cardType = "person",
        role = "qa_tester",
        title = "QA Tester",
        effect = "Ships don't sail without QA",
        iconPath = STEVE_ICON_PATH,
        maxFocus = 2,
        focus = 2,
    },
    backend_dev = {
        cardType = "person",
        role = "backend_dev",
        title = "Backend Dev",
        effect = "Cleans up debt efficiently",
        iconPath = STEVE_ICON_PATH,
        maxFocus = 2,
        focus = 2,
    },

    -- ── Infrastructure ───────────────────────────────────────────────────────
    coffee_machine = {
        cardType = "infrastructure",
        role = "coffee_machine",
        title = "Coffee Machine",
        effect = "Generates Coffee every 20s (max 2)",
        iconPath = COFFEE_ICON_PATH,
    },
    sprint_timer = {
        cardType = "infrastructure",
        role = "sprint_timer",
        title = "Sprint Timer",
        effect = "60 seconds per sprint",
        iconPath = CALENDAR_ICON_PATH,
    },
    hire_market = {
        cardType = "infrastructure",
        role = "hire_market",
        title = "Hire Market",
        effect = "Drop 3 Money to hire a dev",
        iconPath = MAIL_ICON_PATH,
    },
    business_opportunity = {
        cardType = "infrastructure",
        role = "business_opportunity",
        title = "Biz Opportunity",
        effect = "Drop 2 Money: get 2 Client Requests",
        iconPath = STAR_ICON_PATH,
    },

    -- ── Economy ──────────────────────────────────────────────────────────────
    money = {
        cardType = "money",
        title = "Money",
        moneyAmount = 1,
        effect = "Ka-ching",
        iconPath = MONEY_ICON_PATH,
    },
    coffee = {
        cardType = "coffee",
        title = "Coffee",
        effect = "Restores 1 Focus or clears Burnout",
        iconPath = COFFEE_ICON_PATH,
    },

    -- ── Work Requests ────────────────────────────────────────────────────────
    quick_win_request = {
        cardType = "request",
        subType = "quick_win",
        title = "Quick Win Request",
        effect = "PO converts this in 4s",
        iconPath = MAIL_ICON_PATH,
    },
    big_bet_request = {
        cardType = "request",
        subType = "big_bet",
        title = "Big Bet Request",
        effect = "PO converts this in 5s",
        iconPath = MAIL_ICON_PATH,
    },
    client_request = {
        cardType = "request",
        subType = "client",
        title = "Client Request",
        effect = "70% Quick Win, 30% Big Feature",
        iconPath = MAIL_ICON_PATH,
    },

    -- ── Specs (generated) ────────────────────────────────────────────────────
    quick_win_spec = {
        cardType = "spec",
        subType = "quick_win",
        title = "Quick Win Spec",
        effect = "Dev builds this in ~7-8s",
        iconPath = STAR_ICON_PATH,
    },
    big_feature_spec = {
        cardType = "spec",
        subType = "big_feature",
        title = "Big Feature Spec",
        effect = "Needs FE + BE or brave Fullstack",
        iconPath = STAR_ICON_PATH,
    },

    -- ── Builds (intermediate) ────────────────────────────────────────────────
    frontend_build = {
        cardType = "build",
        subType = "frontend",
        title = "Frontend Build",
        effect = "Combine with Backend Build",
        iconPath = STAR_ICON_PATH,
    },
    backend_build = {
        cardType = "build",
        subType = "backend",
        title = "Backend Build",
        effect = "Combine with Frontend Build",
        iconPath = STAR_ICON_PATH,
    },

    -- ── Release Candidates (generated) ──────────────────────────────────────
    release_quick_win = {
        cardType = "release",
        subType = "quick_win",
        title = "Release Candidate",
        effect = "QA ships this in 5s",
        iconPath = EXCLAMATION_ICON_PATH,
    },
    release_major_feature = {
        cardType = "release",
        subType = "major_feature",
        title = "Release Candidate",
        effect = "QA ships this in 7s (Major)",
        iconPath = EXCLAMATION_ICON_PATH,
    },

    -- ── Shipped Work (generated) ─────────────────────────────────────────────
    shipped_quick_win = {
        cardType = "shipped",
        subType = "quick_win",
        title = "Shipped Quick Win",
        effect = "Converts to 2 Money at sprint end",
        moneyAmount = 2,
        iconPath = STAR_ICON_PATH,
    },
    shipped_major_feature = {
        cardType = "shipped",
        subType = "major_feature",
        title = "Shipped Major Feature",
        effect = "Converts to 6 Money at sprint end",
        moneyAmount = 6,
        iconPath = STAR_ICON_PATH,
    },

    -- ── Problems ─────────────────────────────────────────────────────────────
    tech_debt = {
        cardType = "tech_debt",
        title = "Tech Debt",
        effect = "+1s to all dev recipes per card",
        iconPath = EXCLAMATION_ICON_PATH,
    },
    deadline = {
        cardType = "deadline",
        title = "Deadline",
        effect = "+1 Money if shipped, +1 Bug if missed",
        iconPath = CALENDAR_ICON_PATH,
    },
    bug = {
        cardType = "bug",
        title = "Bug",
        effect = "4 Bugs on board = game over",
        iconPath = BUG_ICON_PATH,
    },
    burnout = {
        cardType = "burnout",
        title = "Burnout",
        effect = "This dev has 1 Focus next sprint",
        iconPath = FIRE_ICON_PATH,
        ownerWorkerId = nil,
    },
}

-- Starting board layout: { defKey, col, row } — arranged on a grid
-- Grid origin: about (WORLD_WIDTH*0.3, WORLD_HEIGHT*0.35)
-- Col spacing: CARD_WIDTH + 60, Row spacing: CARD_HEIGHT + 30
CardDefs.STARTING_LAYOUT = {
    -- Col 0: Workers
    { defKey = "product_owner",       col = 0, row = 0 },
    { defKey = "fullstack_dev",       col = 0, row = 1 },
    { defKey = "frontend_dev",        col = 0, row = 2 },
    { defKey = "qa_tester",           col = 0, row = 3 },
    -- Col 1: Infrastructure
    { defKey = "coffee_machine",      col = 1, row = 0 },
    { defKey = "sprint_timer",        col = 1, row = 1 },
    { defKey = "hire_market",         col = 1, row = 2 },
    { defKey = "business_opportunity",col = 1, row = 3 },
    -- Col 2: Money
    { defKey = "money",               col = 2, row = 0 },
    { defKey = "money",               col = 2, row = 1 },
    { defKey = "money",               col = 2, row = 2 },
    -- Col 3: Work Requests
    { defKey = "quick_win_request",   col = 3, row = 0 },
    { defKey = "quick_win_request",   col = 3, row = 1 },
    { defKey = "big_bet_request",     col = 3, row = 2 },
    -- Col 4: Client Requests
    { defKey = "client_request",      col = 4, row = 0 },
    { defKey = "client_request",      col = 4, row = 1 },
    -- Col 5: Pressure
    { defKey = "tech_debt",           col = 5, row = 0 },
    { defKey = "deadline",            col = 5, row = 1 },
}

function CardDefs.get(defKey)
    return DEFS[defKey]
end

-- Returns a shallow copy of the def, merged with overrides
function CardDefs.createConfig(defKey, overrides)
    local def = DEFS[defKey]
    if not def then
        return overrides or {}
    end
    local config = {}
    for k, v in pairs(def) do
        config[k] = v
    end
    if overrides then
        for k, v in pairs(overrides) do
            config[k] = v
        end
    end
    return config
end

-- Returns the worker salary cost (1 per dev/QA, 0 for PO)
function CardDefs.getSalaryCost(card)
    if not card or card.cardType ~= "person" then
        return 0
    end
    local freeRoles = { product_owner = true }
    if freeRoles[card.role] then
        return 0
    end
    return 1
end

-- Returns true if this card type counts toward "workers that pay salary"
function CardDefs.isPaidWorker(card)
    return CardDefs.getSalaryCost(card) > 0
end

return CardDefs
