local Surface = require("src.ui.components.surface")

local Buttons = {}

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function Buttons.drawButton(theme, rect, label, enabled, color, isPressed)
    local mx, my = love.mouse.getPosition()
    if _G.screenToGame then
        mx, my = _G.screenToGame(mx, my)
    end

    local hover = enabled and mx and my and mx >= rect.x and mx <= rect.x + rect.w and my >= rect.y and my <= rect.y + rect.h

    local base = { color[1], color[2], color[3], color[4] or 1 }
    if not enabled then
        base = theme.colors.buttonDisabled
    elseif hover then
        base = {
            clamp(base[1] + 0.06, 0, 1),
            clamp(base[2] + 0.06, 0, 1),
            clamp(base[3] + 0.06, 0, 1),
            1,
        }
    end

    local y = Surface.draw(rect, {
        color = base,
        shadowOffset = 4,
        pressed = isPressed and enabled,
    })

    local textY = y + (rect.h - theme.fonts.large:getHeight()) * 0.5
    theme:drawTextCenteredWithShadow(label, rect.x, textY, rect.w, theme.fonts.large, theme.colors.text)
end

function Buttons.drawSprint(theme, layout, buttonEnabled, pressedButtonId)
    Buttons.drawButton(theme, layout.buttons.playCard, "Play Card", buttonEnabled("play_card"), theme.colors.buttonPlay, pressedButtonId == "play_card")
    Buttons.drawButton(theme, layout.buttons.endDay, "End Day", buttonEnabled("end_day"), theme.colors.buttonEnd, pressedButtonId == "end_day")
end

return Buttons
