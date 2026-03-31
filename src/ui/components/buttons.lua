local Buttons = {}

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function Buttons.drawButton(theme, rect, label, enabled, color)
    local mx, my = love.mouse.getPosition()
    local hover = enabled and mx >= rect.x and mx <= rect.x + rect.w and my >= rect.y and my <= rect.y + rect.h

    local base = { color[1], color[2], color[3], color[4] or 1 }
    if not enabled then
        base = { 0.70, 0.72, 0.75, 0.7 }
    elseif hover then
        base = {
            clamp(base[1] + 0.06, 0, 1),
            clamp(base[2] + 0.06, 0, 1),
            clamp(base[3] + 0.06, 0, 1),
            1,
        }
    end

    love.graphics.setColor(base)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 16, 16)

    local textY = rect.y + rect.h * 0.22
    theme:drawTextCenteredWithShadow(label, rect.x, textY, rect.w, theme.fonts.large, theme.colors.text)
end

function Buttons.drawSprint(theme, layout, buttonEnabled)
    Buttons.drawButton(theme, layout.buttons.playCard, "Play Card", buttonEnabled("play_card"), { 0.61, 0.88, 0.68, 1 })
    Buttons.drawButton(theme, layout.buttons.endDay, "End Day", buttonEnabled("end_day"), { 0.55, 0.86, 0.95, 1 })
end

return Buttons
