local Theme  = require("src.ui.theme")
local Button = require("src.ui.button")

local InfoPanel = {}

-- Panel sits to the right of the board (board right edge: 60+1455=1515)
local P = {
    x     = 1540,
    y     = 130,
    w     = 340,
    noteH = 128,
    noteGap = 14,
    btnH  = 68,
    btnGap = 14,
}

-- Hardcoded note data (no logic yet)
local NOTES = {
    {
        title = "Day 1 / 30",
        lines = { "Sprint 1 of 6" },
    },
    {
        title = "Budget",
        lines = { "$50,000 remaining", "$0 spent so far" },
    },
    {
        title = "Deadline",
        lines = { "Sprint ends in 5 days", "Release in 30 days" },
    },
    {
        title = "Team",
        lines = { "3 developers", "1 designer" },
    },
}

local _buttons = {}

local function drawStickyNote(x, y, w, h, note)
    local rx     = 5
    local shadow = Theme.colors.stickyNoteShadow
    local face   = Theme.colors.stickyNote
    local text   = Theme.colors.stickyNoteText

    -- Drop shadow
    love.graphics.setColor(shadow)
    love.graphics.rectangle("fill", x + 5, y + 5, w, h, rx)

    -- Face
    love.graphics.setColor(face)
    love.graphics.rectangle("fill", x, y, w, h, rx)

    -- Title
    love.graphics.setColor(text)
    love.graphics.setFont(Theme.fonts.noteHeading)
    love.graphics.print(note.title, x + 14, y + 12)

    -- Divider line under title
    love.graphics.setColor(text[1], text[2], text[3], 0.15)
    love.graphics.setLineWidth(1)
    love.graphics.line(x + 14, y + 44, x + w - 14, y + 44)

    -- Body lines
    love.graphics.setColor(text)
    love.graphics.setFont(Theme.fonts.noteBody)
    for i, line in ipairs(note.lines) do
        love.graphics.print(line, x + 14, y + 52 + (i - 1) * 26)
    end
end

function InfoPanel.load()
    local notesBottom = P.y + #NOTES * (P.noteH + P.noteGap) - P.noteGap
    local btnY1 = notesBottom + 22
    local btnY2 = btnY1 + P.btnH + P.btnGap

    _buttons.endDay = Button.new(
        P.x, btnY1, P.w, P.btnH,
        "End Day",
        Theme.colors.btnEndDayFace,
        Theme.colors.btnEndDayShadow
    )
    _buttons.discard = Button.new(
        P.x, btnY2, P.w, P.btnH,
        "Discard",
        Theme.colors.btnDiscardFace,
        Theme.colors.btnDiscardShadow
    )
end

function InfoPanel.update()
    _buttons.endDay:update()
    _buttons.discard:update()
end

function InfoPanel.draw()
    for i, note in ipairs(NOTES) do
        local ny = P.y + (i - 1) * (P.noteH + P.noteGap)
        drawStickyNote(P.x, ny, P.w, P.noteH, note)
    end

    _buttons.endDay:draw()
    _buttons.discard:draw()
end

return InfoPanel
