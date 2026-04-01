local Surface = require("src.ui.components.surface")

local Retrospective = {}

local function drawCenteredLabel(theme, text, x, y, width, font, color)
    theme:drawTextCenteredWithShadow(text, x, y, width, font, color)
end

local function drawLeftLabel(theme, text, x, y, font, color)
    theme:drawTextWithShadow(text, x, y, font, color)
end

local function drawDeveloperPlaceholder(theme, rect, name, work)
    local y = Surface.draw(rect, {
        color = theme.colors.surface2,
        shadowOffset = 3,
        radius = 18,
    })

    local avatarRect = {
        x = rect.x + 10,
        y = y + 12,
        w = rect.w - 20,
        h = math.max(46, math.floor(rect.h * 0.44)),
    }
    love.graphics.setColor(0.95, 0.75, 0.48, 1)
    love.graphics.rectangle("fill", avatarRect.x, avatarRect.y, avatarRect.w, avatarRect.h, 10, 10)
    love.graphics.setColor(0.20, 0.16, 0.14, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", avatarRect.x, avatarRect.y, avatarRect.w, avatarRect.h, 10, 10)
    love.graphics.setLineWidth(1)

    drawCenteredLabel(theme, "dev", avatarRect.x, avatarRect.y + (avatarRect.h - theme.fonts.tiny:getHeight()) * 0.5, avatarRect.w, theme.fonts.tiny, theme.colors.text)
    drawCenteredLabel(theme, name, rect.x, y + rect.h - 64, rect.w, theme.fonts.normal, theme.colors.text)
    drawCenteredLabel(theme, tostring(work) .. " work", rect.x, y + rect.h - 32, rect.w, theme.fonts.tiny, theme.colors.textDim)
end

function Retrospective.draw(theme, game, layout, getApplicantRect, drawButton)
    local w = layout.w

    drawCenteredLabel(theme, "Retrospective", 0, 48, w, theme.fonts.display, { 0.93, 0.90, 0.84, 1 })
    drawCenteredLabel(theme, "What worked, what did not, and what should change?", 0, 124, w, theme.fonts.large, { 0.84, 0.80, 0.74, 1 })

    drawLeftLabel(theme, "Office Improvements", 110, 280, theme.fonts.display, { 0.93, 0.90, 0.84, 1 })
    drawLeftLabel(theme, "Applicants", layout.retrospective.applicantStartX, 280, theme.fonts.display, { 0.93, 0.90, 0.84, 1 })

    local office = layout.retrospective.officeRect
    local officeY = Surface.draw(office, {
        color = theme.colors.success,
        shadowOffset = 4,
        radius = 18,
    })

    drawCenteredLabel(theme, "Upgrade board\n(coming soon)", office.x, officeY + office.h * 0.36, office.w, theme.fonts.normal, theme.colors.text)

    for i, applicant in ipairs(game.applicants) do
        local rect = getApplicantRect(i)
        drawDeveloperPlaceholder(theme, rect, applicant.name, applicant.work)
    end

    if #game.developers >= 5 then
        drawLeftLabel(
            theme,
            "Team is full (5/5)",
            layout.retrospective.applicantStartX,
            layout.retrospective.applicantY + 210,
            theme.fonts.large,
            { 0.76, 0.86, 0.72, 1 }
        )
    end

    drawButton(layout.buttons.nextSprint, "Next Sprint", true, theme.colors.buttonEnd)
end

return Retrospective
