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

local function darken(color, amount)
    local factor = 1 - math.max(0, math.min(1, amount or 0))
    return {
        color[1] * factor,
        color[2] * factor,
        color[3] * factor,
        color[4] or 1,
    }
end

Theme.palette = {
    ink = hexColor("#1A2A3A"),
    white = hexColor("#FFFFFF"),
    black = hexColor("#000000"),
    uiBackground = hexColor("#F4EFE4"),
    developerHeader = hexColor("#AEDBFF"),
    developerBody = hexColor("#F2FAFF"),
    featureHeader = hexColor("#F1D878"),
    featureBody = hexColor("#FFF2BA"),
    featureBodySoft = hexColor("#FFF7D7"),
    mutedPaper = hexColor("#EFE7CC"),
    blue = hexColor("#84B4E6"),
    red = hexColor("#E38B7E"),
    green = hexColor("#8BC18D"),
    greenSoft = hexColor("#D2EDD5"),
    -- New card type colors
    specAmber = hexColor("#E8C547"),
    specAmberSoft = hexColor("#FFF0A0"),
    rcPurpleHeader = hexColor("#C3A0E8"),
    rcPurpleBody = hexColor("#F2EDFF"),
    shippedGreen = hexColor("#5BAD6A"),
    burnoutRed = hexColor("#C94040"),
    burnoutRedSoft = hexColor("#FFE5E5"),
    deadlineOrange = hexColor("#E87A30"),
    deadlineOrangeSoft = hexColor("#FFF0E0"),
    coffeeBody = hexColor("#D4A96A"),
    coffeeSoft = hexColor("#FFF6E8"),
}

Theme.colors = {
    background = Theme.palette.uiBackground,
    text = Theme.palette.ink,
    textPrimary = Theme.palette.ink,
    textMuted = withAlpha(Theme.palette.ink, 0.72),
    borderStrong = Theme.palette.ink,
    icon = Theme.palette.ink,
    shadowTint = Theme.palette.ink,
    cardShadow = Theme.palette.ink,
    letterbox = Theme.palette.black,
    personHover = {
        fill = Theme.palette.featureBodySoft,
        border = Theme.palette.ink,
        text = Theme.palette.ink,
    },
    consultingHover = {
        fill = Theme.palette.featureBody,
        border = Theme.palette.ink,
        text = Theme.palette.ink,
    },
    newDayButton = {
        fill = Theme.palette.featureBody,
        fillHover = darken(Theme.palette.featureBody, 0.05),
        fillPressed = darken(Theme.palette.featureBody, 0.1),
        border = Theme.palette.ink,
        text = Theme.palette.ink,
        label = withAlpha(Theme.palette.ink, 0.6),
    },
    consultingZone = {
        body = Theme.palette.featureBodySoft,
        bodyRaised = Theme.palette.featureBody,
        header = Theme.palette.featureHeader,
        headerRaised = Theme.palette.featureHeader,
        border = Theme.palette.ink,
        text = Theme.palette.ink,
    },
    workBar = {
        track = Theme.palette.mutedPaper,
        border = Theme.palette.ink,
        fill = Theme.palette.ink,
    },
    reloadToast = {
        text = Theme.palette.ink,
        shadow = withAlpha(Theme.palette.black, 0.35),
    },
}

Theme.cardStyles = {
    person = {
        bodyColor = Theme.palette.developerBody,
        headerColor = Theme.palette.developerHeader,
        borderColor = Theme.palette.ink,
        textColor = Theme.palette.ink,
    },
    developer = {
        bodyColor = Theme.palette.developerBody,
        headerColor = Theme.palette.developerHeader,
        borderColor = Theme.palette.ink,
        textColor = Theme.palette.ink,
    },
    feature = {
        bodyColor = Theme.palette.featureBody,
        headerColor = Theme.palette.featureHeader,
        borderColor = Theme.palette.ink,
        textColor = Theme.palette.ink,
    },
    money = {
        bodyColor = Theme.palette.greenSoft,
        headerColor = Theme.palette.green,
        borderColor = Theme.palette.ink,
        textColor = Theme.palette.ink,
    },
    resource = {
        bodyColor = Theme.palette.featureBodySoft,
        headerColor = Theme.palette.featureHeader,
        borderColor = Theme.palette.ink,
        textColor = Theme.palette.ink,
    },
    opportunity = {
        bodyColor = Theme.palette.featureBody,
        headerColor = Theme.palette.featureHeader,
        borderColor = Theme.palette.ink,
        textColor = Theme.palette.ink,
    },
    event = {
        bodyColor = Theme.palette.featureBody,
        headerColor = Theme.palette.developerHeader,
        borderColor = Theme.palette.ink,
        textColor = Theme.palette.ink,
    },
    management = {
        bodyColor = Theme.palette.featureBodySoft,
        headerColor = Theme.palette.developerHeader,
        borderColor = Theme.palette.ink,
        textColor = Theme.palette.ink,
    },
    problem = {
        bodyColor = Theme.palette.featureBodySoft,
        headerColor = Theme.palette.red,
        borderColor = Theme.palette.ink,
        textColor = Theme.palette.ink,
    },
    bug = {
        bodyColor = Theme.palette.featureBodySoft,
        headerColor = Theme.palette.red,
        borderColor = Theme.palette.ink,
        textColor = Theme.palette.ink,
    },
    support = {
        bodyColor = Theme.palette.greenSoft,
        headerColor = Theme.palette.green,
        borderColor = Theme.palette.ink,
        textColor = Theme.palette.ink,
    },
    tooling = {
        bodyColor = Theme.palette.greenSoft,
        headerColor = Theme.palette.green,
        borderColor = Theme.palette.ink,
        textColor = Theme.palette.ink,
    },
    default = {
        bodyColor = Theme.palette.featureBodySoft,
        headerColor = Theme.palette.developerHeader,
        borderColor = Theme.palette.ink,
        textColor = Theme.palette.ink,
    },
    -- New card types for the prototype
    request = {
        bodyColor = Theme.palette.featureBody,
        headerColor = Theme.palette.featureHeader,
        borderColor = Theme.palette.ink,
        textColor = Theme.palette.ink,
    },
    spec = {
        bodyColor = Theme.palette.specAmberSoft,
        headerColor = Theme.palette.specAmber,
        borderColor = Theme.palette.ink,
        textColor = Theme.palette.ink,
    },
    build = {
        bodyColor = Theme.palette.developerBody,
        headerColor = Theme.palette.developerHeader,
        borderColor = Theme.palette.ink,
        textColor = Theme.palette.ink,
    },
    release = {
        bodyColor = Theme.palette.rcPurpleBody,
        headerColor = Theme.palette.rcPurpleHeader,
        borderColor = Theme.palette.ink,
        textColor = Theme.palette.ink,
    },
    shipped = {
        bodyColor = Theme.palette.greenSoft,
        headerColor = Theme.palette.shippedGreen,
        borderColor = Theme.palette.ink,
        textColor = Theme.palette.ink,
    },
    burnout = {
        bodyColor = Theme.palette.burnoutRedSoft,
        headerColor = Theme.palette.burnoutRed,
        borderColor = Theme.palette.ink,
        textColor = Theme.palette.ink,
    },
    deadline = {
        bodyColor = Theme.palette.deadlineOrangeSoft,
        headerColor = Theme.palette.deadlineOrange,
        borderColor = Theme.palette.ink,
        textColor = Theme.palette.ink,
    },
    coffee = {
        bodyColor = Theme.palette.coffeeSoft,
        headerColor = Theme.palette.coffeeBody,
        borderColor = Theme.palette.ink,
        textColor = Theme.palette.ink,
    },
    infrastructure = {
        bodyColor = Theme.palette.greenSoft,
        headerColor = Theme.palette.green,
        borderColor = Theme.palette.ink,
        textColor = Theme.palette.ink,
    },
    tech_debt = {
        bodyColor = Theme.palette.featureBodySoft,
        headerColor = Theme.palette.red,
        borderColor = Theme.palette.ink,
        textColor = Theme.palette.ink,
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
        path = "assets/handdrawn/ui/9sliceBorder.png",
        sourceX = 0,
        sourceY = 0,
        sourceWidth = 256,
        sourceHeight = 256,
        sourceLeft = 56,
        sourceRight = 56,
        sourceTop = 56,
        sourceBottom = 56,
        drawLeft = 16,
        drawRight = 16,
        drawTop = 16,
        drawBottom = 16,
    },
}

Theme.ui = {
    border9slice = {
        path = "assets/handdrawn/ui/9sliceBorder.png",
        sourceX = 0,
        sourceY = 0,
        sourceWidth = 256,
        sourceHeight = 256,
        sourceLeft = 56,
        sourceRight = 56,
        sourceTop = 56,
        sourceBottom = 56,
        destLeft = 16,
        destRight = 16,
        destTop = 16,
        destBottom = 16,
    },
    surface9slice = {
        path = "assets/handdrawn/ui/9sliceSurface.png",
        sourceX = 0,
        sourceY = 0,
        sourceWidth = 256,
        sourceHeight = 256,
        sourceLeft = 56,
        sourceRight = 56,
        sourceTop = 56,
        sourceBottom = 56,
        destLeft = 16,
        destRight = 16,
        destTop = 16,
        destBottom = 16,
    },
}

local FONT_DEFS = {
    default = { path = "assets/fonts/PatrickHand-Regular.ttf", size = 32 },
    title = { path = "assets/fonts/PatrickHand-Regular.ttf", size = 96 },
    cardHeader = { path = "assets/fonts/PatrickHand-Regular.ttf", size = 20 },
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
