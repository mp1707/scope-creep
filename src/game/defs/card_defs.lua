local CardDefs = {}

local function hexColor(hex)
    local value = (hex or ""):gsub("#", "")
    if #value ~= 6 then
        return { 1, 1, 1, 1 }
    end
    local r = tonumber(value:sub(1, 2), 16) or 255
    local g = tonumber(value:sub(3, 4), 16) or 255
    local b = tonumber(value:sub(5, 6), 16) or 255
    return { r / 255, g / 255, b / 255, 1 }
end

local ICONS = {
    steve = "assets/handdrawn/characters/steve.png",
    star = "assets/handdrawn/cardIcons/star.png",
    bug = "assets/handdrawn/cardIcons/bug.png",
    exclamation = "assets/handdrawn/cardIcons/exclamationmark.png",
    money = "assets/handdrawn/cardIcons/money.png",
    software = "assets/handdrawn/cardIcons/mail.png",
}

local STYLES = {
    blue = {
        headerColor = hexColor("#AEDBFF"),
        bodyColor = hexColor("#F2FAFF"),
        borderColor = hexColor("#1A2A3A"),
        textColor = hexColor("#1A2A3A"),
    },
    yellow = {
        headerColor = hexColor("#F1D878"),
        bodyColor = hexColor("#FFF2BA"),
        borderColor = hexColor("#1A2A3A"),
        textColor = hexColor("#1A2A3A"),
    },
    orange = {
        headerColor = hexColor("#E8A04C"),
        bodyColor = hexColor("#FFE4BE"),
        borderColor = hexColor("#1A2A3A"),
        textColor = hexColor("#1A2A3A"),
    },
    green = {
        headerColor = hexColor("#5BAD6A"),
        bodyColor = hexColor("#D2EDD5"),
        borderColor = hexColor("#1A2A3A"),
        textColor = hexColor("#1A2A3A"),
    },
    red = {
        headerColor = hexColor("#C94040"),
        bodyColor = hexColor("#FFE5E5"),
        borderColor = hexColor("#1A2A3A"),
        textColor = hexColor("#1A2A3A"),
    },
    gray = {
        headerColor = hexColor("#9CA3AF"),
        bodyColor = hexColor("#E5E7EB"),
        borderColor = hexColor("#1A2A3A"),
        textColor = hexColor("#1A2A3A"),
    },
    project = {
        headerColor = hexColor("#84B4E6"),
        bodyColor = hexColor("#E8F2FB"),
        borderColor = hexColor("#1A2A3A"),
        textColor = hexColor("#1A2A3A"),
    },
    money = {
        headerColor = hexColor("#8BC18D"),
        bodyColor = hexColor("#D2EDD5"),
        borderColor = hexColor("#1A2A3A"),
        textColor = hexColor("#1A2A3A"),
    },
}

local DEFS = {
    junior_dev = {
        id = "junior_dev",
        displayName = "Junior Dev",
        kind = "employee",
        role = "dev",
        iconPath = ICONS.steve,
        visualCardType = "person",
        description = "big dreams",
        workRate = 0.5,
        salaryCost = 1,
        style = STYLES.blue,
    },
    junior_tester = {
        id = "junior_tester",
        displayName = "Junior Tester",
        kind = "employee",
        role = "tester",
        iconPath = ICONS.steve,
        visualCardType = "person",
        description = "already bored",
        workRate = 0.5,
        salaryCost = 1,
        style = STYLES.blue,
    },
    software = {
        id = "software",
        displayName = "Software",
        kind = "project",
        iconPath = ICONS.software,
        visualCardType = "infrastructure",
        description = "Project anchor for features and issues",
        style = STYLES.project,
    },
    mini_requirement = {
        id = "mini_requirement",
        displayName = "Mini Requirement",
        kind = "todo",
        processRole = "dev",
        baseDuration = 5,
        iconPath = ICONS.star,
        visualCardType = "request",
        description = "Small customer requirement",
        style = STYLES.yellow,
    },
    untested_feature = {
        id = "untested_feature",
        displayName = "Untested Feature",
        kind = "todo",
        processRole = "tester",
        baseDuration = 5,
        iconPath = ICONS.star,
        visualCardType = "release",
        description = "Developed, but not tested",
        style = STYLES.orange,
    },
    mini_feature = {
        id = "mini_feature",
        displayName = "Mini Feature",
        kind = "feature",
        iconPath = ICONS.star,
        visualCardType = "shipped",
        description = "Tested and shipped",
        style = STYLES.green,
    },
    bug = {
        id = "bug",
        displayName = "Bug",
        kind = "todo",
        processRole = "dev",
        baseDuration = 5,
        iconPath = ICONS.bug,
        visualCardType = "bug",
        description = "Needs fixing",
        style = STYLES.red,
    },
    security_issue = {
        id = "security_issue",
        displayName = "Security Issue",
        kind = "todo",
        processRole = "dev",
        baseDuration = 20,
        iconPath = ICONS.exclamation,
        visualCardType = "bug",
        description = "Deletes money every 30s",
        style = STYLES.red,
    },
    tech_debt = {
        id = "tech_debt",
        displayName = "Tech Debt",
        kind = "todo",
        processRole = "dev",
        baseDuration = 5,
        iconPath = ICONS.exclamation,
        visualCardType = "tech_debt",
        description = "+2s to new dev jobs",
        style = STYLES.gray,
    },
    money = {
        id = "money",
        displayName = "Money",
        kind = "resource",
        iconPath = ICONS.money,
        visualCardType = "money",
        description = "Salary and payroll resource",
        value = 1,
        style = STYLES.money,
    },
}

function CardDefs.get(defId)
    return DEFS[defId]
end

function CardDefs.all()
    return DEFS
end

function CardDefs.getSalaryCost(card)
    if not card then
        return 0
    end
    local def = DEFS[card.defId]
    if not def or def.kind ~= "employee" then
        return 0
    end
    return def.salaryCost or 1
end

function CardDefs.toCardConfig(defId)
    local def = DEFS[defId]
    if not def then
        return nil
    end

    return {
        cardType = def.visualCardType or "default",
        role = def.role,
        title = def.displayName,
        effect = def.description,
        iconPath = def.iconPath,
        style = def.style,
        value = def.value,
        moneyAmount = def.value,
    }
end

return CardDefs
