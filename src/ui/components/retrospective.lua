local Retrospective = {}

local function drawDeveloperPlaceholder(theme, rect, name, work)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 24, 24)

    local headX = rect.x + rect.w * 0.50
    local headY = rect.y + rect.h * 0.38
    local headR = rect.w * 0.18

    love.graphics.circle("line", headX, headY, headR)
    love.graphics.arc("line", "open", headX, headY + rect.h * 0.15, rect.w * 0.28, math.pi * 1.05, math.pi * 1.95)

    theme:drawTextRightWithShadow(tostring(work) .. " work", rect.x, rect.y + 10, rect.w - 8, theme.fonts.small, { 1, 1, 1, 1 })
    theme:drawTextCenteredWithShadow(name, rect.x, rect.y + rect.h - 44, rect.w, theme.fonts.large, { 0.90, 0.20, 0.18, 1 })
end

function Retrospective.draw(theme, game, layout, getApplicantRect, drawButton)
    local w = layout.w

    theme:drawTextCenteredWithShadow("Retrospective", 0, 48, w, theme.fonts.display, theme.colors.text)
    theme:drawTextCenteredWithShadow("Guys. What worked? What didnt? What do we need to change?", 0, 120, w, theme.fonts.large, theme.colors.textDim)

    theme:drawTextWithShadow("Office Improvements", 110, 280, theme.fonts.display, theme.colors.text)
    theme:drawTextWithShadow("Applicants", layout.retrospective.applicantStartX, 280, theme.fonts.display, theme.colors.text)

    local office = layout.retrospective.officeRect
    love.graphics.setColor(0.24, 0.80, 0.68, 1)
    love.graphics.rectangle("fill", office.x, office.y, office.w, office.h)
    love.graphics.setColor(0.60, 0.67, 0.72, 1)
    love.graphics.rectangle("line", office.x, office.y, office.w, office.h)
    theme:drawTextCenteredWithShadow("Placeholder", office.x, office.y + office.h * 0.40, office.w, theme.fonts.display, { 0.46, 0.53, 0.60, 1 })

    for i, applicant in ipairs(game.applicants) do
        local rect = getApplicantRect(i)
        drawDeveloperPlaceholder(theme, rect, applicant.name, applicant.work)
    end

    if #game.developers >= 5 then
        theme:drawTextWithShadow("Team is full (5/5)", layout.retrospective.applicantStartX, layout.retrospective.applicantY + 210, theme.fonts.large, { 0.45, 0.48, 0.54, 1 })
    end

    drawButton(layout.buttons.nextSprint, "Next Sprint", true, { 0.55, 0.86, 0.95, 1 })
end

return Retrospective
