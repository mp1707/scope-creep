local Theme = {}

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

local function withAlpha(color, alpha)
    return { color[1], color[2], color[3], alpha }
end

Theme.palette = {
    darkBlue = hexColor("#0B0E33"),      -- dark blue
    primaryBlue = hexColor("#3B82F6"),   -- primary blue
    lightBlue = hexColor("#60A5FA"),     -- light blue
    primaryPurple = hexColor("#A855F7"), -- primary purple
    lightPurple = hexColor("#C084FC"),   -- light purple
    primaryGreen = hexColor("#22C55E"),  -- primary green
    lightGreen = hexColor("#4ADE80"),    -- light green
    primaryRed = hexColor("#EF4444"),    -- primary red
    darkRed = hexColor("#B91C1C"),       -- dark red
    gold = hexColor("#FFB300"),          -- gold
    yellow = hexColor("#FDE047"),        -- yellow highlight
    orange = hexColor("#F97316"),        -- orange
    bronze = hexColor("#CD7F32"),        -- bronze
    silver = hexColor("#94A3B8"),        -- silver
    lightGray = hexColor("#E2E8F0"),     -- light gray
    darkGray = hexColor("#475569"),      -- dark gray
    peach = hexColor("#FDBA74"),         -- peach
    white = hexColor("#FFFFFF"),         -- white
    uiBackground = hexColor("#FFFFFF"),  -- ui background blue
    black = hexColor("#000000"),         -- black
}

Theme.colors = {
    background = Theme.palette.uiBackground,
    text = Theme.palette.white,
    textPrimary = Theme.palette.darkBlue,
    textMuted = Theme.palette.darkGray,
    borderStrong = Theme.palette.darkBlue,
    gridLine = withAlpha(Theme.palette.silver, 0.32),
    shadowSoft = withAlpha(Theme.palette.black, 0.15),
    shadowMedium = withAlpha(Theme.palette.black, 0.12),
    shadowStrong = withAlpha(Theme.palette.black, 0.38),
    cardShadow = Theme.palette.darkBlue,
    letterbox = Theme.palette.black,
    personHover = {
        fill = Theme.palette.white,
        border = Theme.palette.darkBlue,
        text = Theme.palette.darkBlue,
        indicatorFill = Theme.palette.lightBlue,
        indicatorEmpty = Theme.palette.silver,
    },
    consultingHover = {
        fill = Theme.palette.white,
        border = Theme.palette.darkBlue,
        text = Theme.palette.darkBlue,
    },
    newDayButton = {
        fill = Theme.palette.lightBlue,
        border = Theme.palette.darkBlue,
        text = Theme.palette.darkBlue,
        label = Theme.palette.lightGray,
        shadow = withAlpha(Theme.palette.black, 0.15),
    },
    consultingZone = {
        body = Theme.palette.peach,
        bodyRaised = Theme.palette.yellow,
        header = Theme.palette.orange,
        headerRaised = Theme.palette.gold,
        border = Theme.palette.darkBlue,
        text = Theme.palette.darkBlue,
        shadow = withAlpha(Theme.palette.black, 0.12),
    },
    workBar = {
        track = Theme.palette.white,
        border = Theme.palette.darkBlue,
        fill = Theme.palette.primaryBlue,
    },
    reloadToast = {
        text = Theme.palette.primaryGreen,
        shadow = withAlpha(Theme.palette.black, 0.38),
    },
}

Theme.cardStyles = {
    person = {
        bodyColor = Theme.palette.lightGray,
        headerColor = Theme.palette.lightBlue,
        borderColor = Theme.palette.darkBlue,
        textColor = Theme.palette.darkBlue,
        indicatorFill = Theme.palette.primaryBlue,
        indicatorEmpty = Theme.palette.silver,
    },
    developer = {
        bodyColor = Theme.palette.lightGray,
        headerColor = Theme.palette.lightBlue,
        borderColor = Theme.palette.darkBlue,
        textColor = Theme.palette.darkBlue,
        indicatorFill = Theme.palette.primaryBlue,
        indicatorEmpty = Theme.palette.silver,
    },
    feature = {
        bodyColor = Theme.palette.lightGray,
        headerColor = Theme.palette.gold,
        borderColor = Theme.palette.darkBlue,
        textColor = Theme.palette.darkBlue,
        indicatorFill = Theme.palette.yellow,
        indicatorEmpty = Theme.palette.bronze,
    },
    money = {
        bodyColor = Theme.palette.lightGray,
        headerColor = Theme.palette.primaryGreen,
        borderColor = Theme.palette.darkBlue,
        textColor = Theme.palette.darkBlue,
        indicatorFill = Theme.palette.primaryGreen,
        indicatorEmpty = Theme.palette.lightGreen,
    },
    resource = {
        bodyColor = Theme.palette.lightGray,
        headerColor = Theme.palette.primaryGreen,
        borderColor = Theme.palette.darkBlue,
        textColor = Theme.palette.darkBlue,
        indicatorFill = Theme.palette.primaryGreen,
        indicatorEmpty = Theme.palette.lightGreen,
    },
    opportunity = {
        bodyColor = Theme.palette.lightGray,
        headerColor = Theme.palette.primaryPurple,
        borderColor = Theme.palette.darkBlue,
        textColor = Theme.palette.darkBlue,
        indicatorFill = Theme.palette.primaryPurple,
        indicatorEmpty = Theme.palette.lightPurple,
    },
    event = {
        bodyColor = Theme.palette.lightGray,
        headerColor = Theme.palette.primaryPurple,
        borderColor = Theme.palette.darkBlue,
        textColor = Theme.palette.darkBlue,
        indicatorFill = Theme.palette.primaryPurple,
        indicatorEmpty = Theme.palette.lightPurple,
    },
    management = {
        bodyColor = Theme.palette.lightGray,
        headerColor = Theme.palette.primaryPurple,
        borderColor = Theme.palette.darkBlue,
        textColor = Theme.palette.darkBlue,
        indicatorFill = Theme.palette.primaryPurple,
        indicatorEmpty = Theme.palette.lightPurple,
    },
    problem = {
        bodyColor = Theme.palette.lightGray,
        headerColor = Theme.palette.primaryRed,
        borderColor = Theme.palette.darkBlue,
        textColor = Theme.palette.darkBlue,
        indicatorFill = Theme.palette.darkRed,
        indicatorEmpty = Theme.palette.peach,
    },
    bug = {
        bodyColor = Theme.palette.lightGray,
        headerColor = Theme.palette.primaryRed,
        borderColor = Theme.palette.darkBlue,
        textColor = Theme.palette.darkBlue,
        indicatorFill = Theme.palette.darkRed,
        indicatorEmpty = Theme.palette.peach,
    },
    support = {
        bodyColor = Theme.palette.lightGray,
        headerColor = Theme.palette.orange,
        borderColor = Theme.palette.darkBlue,
        textColor = Theme.palette.darkBlue,
        indicatorFill = Theme.palette.orange,
        indicatorEmpty = Theme.palette.peach,
    },
    tooling = {
        bodyColor = Theme.palette.lightGray,
        headerColor = Theme.palette.orange,
        borderColor = Theme.palette.darkBlue,
        textColor = Theme.palette.darkBlue,
        indicatorFill = Theme.palette.orange,
        indicatorEmpty = Theme.palette.peach,
    },
    default = {
        bodyColor = Theme.palette.lightGray,
        headerColor = Theme.palette.silver,
        borderColor = Theme.palette.darkBlue,
        textColor = Theme.palette.darkBlue,
        indicatorFill = Theme.palette.darkGray,
        indicatorEmpty = Theme.palette.lightGray,
    },
}

Theme.fonts = {}
Theme.fontScale = nil
Theme.card = {
    icon = {
        bodySize = 82,
        personSize = 128,
        featureSize = 74,
        resourceSize = 90,
        eventSize = 84,
        problemSize = 84,
        supportSize = 82,
    },
    background9slice = {
        -- Keep this centralized so future asset renames only change one path.
        path = "assets/handdrawn/borders/cardBorder9slice.png",
        sourceX = 24,
        sourceY = 24,
        sourceWidth = 205,
        sourceHeight = 211,
        sourceLeft = 16,
        sourceRight = 16,
        sourceTop = 16,
        sourceBottom = 16,
        drawLeft = 6,
        drawRight = 6,
        drawTop = 6,
        drawBottom = 6,
    },
}

local FONT_DEFS = {
    default = { path = "assets/fonts/PatrickHand-Regular.ttf", size = 32 },
    title = { path = "assets/fonts/PatrickHand-Regular.ttf", size = 96 },
    cardHeader = { path = "assets/fonts/PatrickHand-Regular.ttf", size = 22 },
    cardBody = { path = "assets/fonts/PatrickHand-Regular.ttf", size = 16 },
    uiButton = { path = "assets/fonts/PatrickHand-Regular.ttf", size = 22 },
}

local function quantizeScale(value)
    local scale = tonumber(value) or 1
    if scale <= 0 then
        scale = 1
    end
    return math.floor(scale * 100 + 0.5) / 100
end

function Theme.load(viewScale)
    local scale = quantizeScale(viewScale)
    if Theme.fontScale == scale and next(Theme.fonts) then
        love.graphics.setFont(Theme.fonts.default)
        return
    end

    Theme.fontScale = scale
    for key, definition in pairs(FONT_DEFS) do
        local fontSize = math.max(1, math.floor(definition.size * scale + 0.5))
        local font = love.graphics.newFont(definition.path, fontSize)
        font:setFilter("linear", "linear")
        Theme.fonts[key] = font
    end

    love.graphics.setFont(Theme.fonts.default)
end

return Theme
