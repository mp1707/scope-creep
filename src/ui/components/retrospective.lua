local Surface = require("src.ui.components.surface")

local Retrospective = {}

local function drawDeveloperPlaceholder(theme, rect, name, work)
    local y = Surface.draw(rect, {
        color = theme.colors.surface2,
        shadowOffset = 3,
    })

    love.graphics.setColor(1, 1, 1, 0.9)

    local headX = rect.x + rect.w * 0.50
    local headY = y + rect.h * 0.38
    local headR = rect.w * 0.18

    love.graphics.circle("line", headX, headY, headR)
    love.graphics.arc("line", "open", headX, headY + rect.h * 0.15, rect.w * 0.28, math.pi * 1.05, math.pi * 1.95)

    theme:drawTextRightWithShadow(tostring(work) .. " work", rect.x, y + 10, rect.w - 8, theme.fonts.small, { 1, 1, 1, 1 })
    theme:drawTextCenteredWithShadow(name, rect.x, y + rect.h - 44, rect.w, theme.fonts.large, { 0.90, 0.20, 0.18, 1 })
    love.graphics.setColor(1, 1, 1, 1)
end

function Retrospective.draw(theme, game, layout, getApplicantRect, drawButton)
    local w = layout.w

    theme:drawTextCenteredWithShadow("Retrospective", 0, 48, w, theme.fonts.display, theme.colors.text)
    theme:drawTextCenteredWithShadow("Guys. What worked? What didnt? What do we need to change?", 0, 120, w, theme.fonts.large, theme.colors.textDim)

    theme:drawTextWithShadow("Office Improvements", 110, 280, theme.fonts.display, theme.colors.text)
    theme:drawTextWithShadow("Applicants", layout.retrospective.applicantStartX, 280, theme.fonts.display, theme.colors.text)

    local office = layout.retrospective.officeRect
    local officeY = Surface.draw(office, {
        color = theme.colors.success,
        shadowOffset = 4,
    })
    theme:drawTextCenteredWithShadow("Placeholder", office.x, officeY + office.h * 0.40, office.w, theme.fonts.display, theme.colors.text)

    for i, applicant in ipairs(game.applicants) do
        local rect = getApplicantRect(i)
        drawDeveloperPlaceholder(theme, rect, applicant.name, applicant.work)
    end

    if #game.developers >= 5 then
        theme:drawTextWithShadow("Team is full (5/5)", layout.retrospective.applicantStartX, layout.retrospective.applicantY + 210, theme.fonts.large, { 0.45, 0.48, 0.54, 1 })
    end

    drawButton(layout.buttons.nextSprint, "Next Sprint", true, theme.colors.buttonEnd)
end

return Retrospective
