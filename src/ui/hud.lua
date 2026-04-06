local Hud = {}

local Theme = require("src.ui.theme")
local UiPanel = require("src.ui.ui_panel")

local APP_WIDTH = 1920
local APP_HEIGHT = 1080

local HUD_PANEL_PADDING = 14
local HUD_MARGIN = 20

local replayButtonState = {
    hovered = false,
    pressed = false,
}

local function hexColor(hex)
    local value = (hex or ""):gsub("#", "")
    if #value ~= 6 then return { 1, 1, 1, 1 } end
    local r = tonumber(value:sub(1, 2), 16) or 255
    local g = tonumber(value:sub(3, 4), 16) or 255
    local b = tonumber(value:sub(5, 6), 16) or 255
    return { r / 255, g / 255, b / 255, 1 }
end

local COLOR_DANGER = hexColor("#C94040")
local COLOR_WARNING = hexColor("#E87A30")
local COLOR_OK = hexColor("#1A2A3A")
local COLOR_PANEL_BG = hexColor("#F4EFE4")

local function formatTime(seconds)
    local s = math.max(0, math.floor(seconds))
    return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local function drawTextCentered(text, cx, cy, font, scale, color)
    local w = font:getWidth(text) * scale
    local h = font:getHeight() * scale
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    love.graphics.print(text, cx - w * 0.5, cy - h * 0.5, 0, scale, scale)
end

-- Draw the sprint + timer panel (top-left)
local function drawSprintPanel(sprintState, viewportScale)
    if not sprintState then return end

    local font = Theme.fonts.cardHeader or love.graphics.getFont()
    local bigFont = Theme.fonts.default or font
    local scale = 1 / (viewportScale or 1)

    local timeRemaining = math.max(0, 60 - (sprintState.elapsed or 0))
    local timeStr = formatTime(timeRemaining)
    local sprintStr = "Sprint " .. tostring(sprintState.number or 1) .. " / 5"

    local panelW = 160
    local panelH = 72
    local panelX = HUD_MARGIN
    local panelY = HUD_MARGIN

    love.graphics.setFont(font)
    local sprintTextW = font:getWidth(sprintStr) * scale
    love.graphics.setFont(bigFont)
    local timeTextW = bigFont:getWidth(timeStr) * scale
    panelW = math.max(panelW, math.max(sprintTextW, timeTextW) + HUD_PANEL_PADDING * 2)

    UiPanel.drawPanel(panelX, panelY, panelW, panelH, {
        bodyColor = COLOR_PANEL_BG,
        borderColor = Theme.palette.ink,
    })

    love.graphics.setFont(font)
    local sprintColor = COLOR_OK
    love.graphics.setColor(sprintColor[1], sprintColor[2], sprintColor[3], 0.7)
    local sprintY = panelY + HUD_PANEL_PADDING
    love.graphics.print(sprintStr, panelX + HUD_PANEL_PADDING, sprintY, 0, scale, scale)

    -- Timer: red when ≤ 10s
    love.graphics.setFont(bigFont)
    local timerColor = timeRemaining <= 10 and COLOR_DANGER or COLOR_OK
    local timerY = sprintY + font:getHeight() * scale + 4
    love.graphics.setColor(timerColor[1], timerColor[2], timerColor[3], 1)
    love.graphics.print(timeStr, panelX + HUD_PANEL_PADDING, timerY, 0, scale, scale)

    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw money + stats panel (top-right)
local function drawStatsPanel(money, bugCount, burnoutCount, viewportScale)
    local font = Theme.fonts.cardHeader or love.graphics.getFont()
    local scale = 1 / (viewportScale or 1)
    local lineH = font:getHeight() * scale
    local gap = 6

    local lines = {
        { label = string.format("Money: %d", math.max(0, money or 0)),    color = COLOR_OK },
        { label = string.format("Bugs: %d / 4",  bugCount or 0),          color = (bugCount or 0) >= 3 and COLOR_DANGER or ((bugCount or 0) >= 2 and COLOR_WARNING or COLOR_OK) },
        { label = string.format("Burnout: %d / 3", burnoutCount or 0),    color = (burnoutCount or 0) >= 2 and COLOR_WARNING or COLOR_OK },
    }

    local maxW = 0
    for _, line in ipairs(lines) do
        local w = font:getWidth(line.label) * scale
        if w > maxW then maxW = w end
    end

    local panelW = maxW + HUD_PANEL_PADDING * 2
    local panelH = #lines * lineH + (#lines - 1) * gap + HUD_PANEL_PADDING * 2
    local panelX = APP_WIDTH - panelW - HUD_MARGIN
    local panelY = HUD_MARGIN

    UiPanel.drawPanel(panelX, panelY, panelW, panelH, {
        bodyColor = COLOR_PANEL_BG,
        borderColor = Theme.palette.ink,
    })

    love.graphics.setFont(font)
    for i, line in ipairs(lines) do
        local ly = panelY + HUD_PANEL_PADDING + (i - 1) * (lineH + gap)
        love.graphics.setColor(line.color[1], line.color[2], line.color[3], line.color[4] or 1)
        love.graphics.print(line.label, panelX + HUD_PANEL_PADDING, ly, 0, scale, scale)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw the sprint-end summary overlay
local function drawSummaryOverlay(sprintState, viewportScale)
    if not sprintState then return end

    local alpha = 0.82
    love.graphics.setColor(0, 0, 0, alpha * 0.6)
    love.graphics.rectangle("fill", 0, 0, APP_WIDTH, APP_HEIGHT)

    local font = Theme.fonts.cardHeader or love.graphics.getFont()
    local bigFont = Theme.fonts.default or font
    local scale = 1 / (viewportScale or 1)
    local lineH = font:getHeight() * scale

    local stats = sprintState.stats or {}
    local lines = {
        { text = "Sprint " .. (sprintState.number or 1) .. " Complete!", font = bigFont, big = true },
        { text = string.format("Salary paid: %d", stats.salaryPaid or 0) },
        { text = string.format("Money earned: %d", stats.moneyEarned or 0) },
        { text = string.format("New bugs: %d", stats.bugsSpawned or 0) },
        { text = "Next sprint starting..." },
    }

    local panelW = 380
    local panelH = 0
    local gap = 8
    for _, line in ipairs(lines) do
        local lh = (line.big and bigFont or font):getHeight() * scale
        panelH = panelH + lh + gap
    end
    panelH = panelH + HUD_PANEL_PADDING * 2

    local panelX = (APP_WIDTH - panelW) * 0.5
    local panelY = (APP_HEIGHT - panelH) * 0.5

    UiPanel.drawPanel(panelX, panelY, panelW, panelH, {
        bodyColor = COLOR_PANEL_BG,
        borderColor = Theme.palette.ink,
    })

    local ty = panelY + HUD_PANEL_PADDING
    for _, line in ipairs(lines) do
        local f = line.big and bigFont or font
        love.graphics.setFont(f)
        local lh = f:getHeight() * scale
        local lw = f:getWidth(line.text) * scale
        local color = line.big and Theme.palette.ink or (Theme.colors and Theme.colors.textMuted or Theme.palette.ink)
        love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
        love.graphics.print(line.text, panelX + (panelW - lw) * 0.5, ty, 0, scale, scale)
        ty = ty + lh + gap
    end

    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw win screen
local function drawWinScreen(viewportScale)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, APP_WIDTH, APP_HEIGHT)

    local font = Theme.fonts.cardHeader or love.graphics.getFont()
    local bigFont = Theme.fonts.default or font
    local scale = 1 / (viewportScale or 1)

    local panelW = 480
    local panelH = 220
    local panelX = (APP_WIDTH - panelW) * 0.5
    local panelY = (APP_HEIGHT - panelH) * 0.5

    UiPanel.drawPanel(panelX, panelY, panelW, panelH, {
        bodyColor = Theme.palette.greenSoft or { 0.82, 0.93, 0.83, 1 },
        borderColor = Theme.palette.ink,
    })

    love.graphics.setFont(bigFont)
    local title = "You Survived 5 Sprints!"
    local tw = bigFont:getWidth(title) * scale
    love.graphics.setColor(0.1, 0.4, 0.15, 1)
    love.graphics.print(title, panelX + (panelW - tw) * 0.5, panelY + 30, 0, scale, scale)

    love.graphics.setFont(font)
    local subtitle = "A real company. Congrats."
    local sw = font:getWidth(subtitle) * scale
    love.graphics.setColor(Theme.palette.ink[1], Theme.palette.ink[2], Theme.palette.ink[3], 0.7)
    love.graphics.print(subtitle, panelX + (panelW - sw) * 0.5, panelY + 30 + bigFont:getHeight() * scale + 14, 0, scale, scale)

    -- Play Again button
    local btnW, btnH = 180, 44
    local btnX = panelX + (panelW - btnW) * 0.5
    local btnY = panelY + panelH - btnH - 24
    local btnColor = replayButtonState.hovered and { 0.6, 0.88, 0.64, 1 } or { 0.72, 0.93, 0.75, 1 }
    UiPanel.drawPanel(btnX, btnY, btnW, btnH, {
        bodyColor = btnColor,
        borderColor = Theme.palette.ink,
    })
    local btnLabel = "Play Again"
    local blw = font:getWidth(btnLabel) * scale
    local blh = font:getHeight() * scale
    love.graphics.setColor(Theme.palette.ink[1], Theme.palette.ink[2], Theme.palette.ink[3], 1)
    love.graphics.print(btnLabel, btnX + (btnW - blw) * 0.5, btnY + (btnH - blh) * 0.5, 0, scale, scale)
    replayButtonState.rect = { x = btnX, y = btnY, w = btnW, h = btnH }

    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1, 1)
end

local LOSE_MESSAGES = {
    bankruptcy = "Ran out of money. Everyone quit.",
    too_many_bugs = "4 bugs live in production. Client revolted.",
    too_many_burnout = "3 devs burned out. The team walked.",
    unknown = "Something went horribly wrong.",
}

-- Draw lose screen
local function drawLoseScreen(loseReason, viewportScale)
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, APP_WIDTH, APP_HEIGHT)

    local font = Theme.fonts.cardHeader or love.graphics.getFont()
    local bigFont = Theme.fonts.default or font
    local scale = 1 / (viewportScale or 1)

    local panelW = 480
    local panelH = 220
    local panelX = (APP_WIDTH - panelW) * 0.5
    local panelY = (APP_HEIGHT - panelH) * 0.5

    UiPanel.drawPanel(panelX, panelY, panelW, panelH, {
        bodyColor = Theme.palette.burnoutRedSoft or { 1, 0.9, 0.9, 1 },
        borderColor = Theme.palette.ink,
    })

    love.graphics.setFont(bigFont)
    local title = "Company Collapsed"
    local tw = bigFont:getWidth(title) * scale
    love.graphics.setColor(0.7, 0.15, 0.15, 1)
    love.graphics.print(title, panelX + (panelW - tw) * 0.5, panelY + 30, 0, scale, scale)

    love.graphics.setFont(font)
    local msg = LOSE_MESSAGES[loseReason] or LOSE_MESSAGES.unknown
    local mw = font:getWidth(msg) * scale
    local maxMsgW = panelW - HUD_PANEL_PADDING * 2
    if mw > maxMsgW then
        -- wrap manually (simple: just clip for now)
        mw = maxMsgW
    end
    love.graphics.setColor(Theme.palette.ink[1], Theme.palette.ink[2], Theme.palette.ink[3], 0.8)
    love.graphics.printf(msg, panelX + HUD_PANEL_PADDING,
        panelY + 30 + bigFont:getHeight() * scale + 14,
        maxMsgW * (viewportScale or 1), "center", 0, scale, scale)

    -- Play Again button
    local btnW, btnH = 180, 44
    local btnX = panelX + (panelW - btnW) * 0.5
    local btnY = panelY + panelH - btnH - 24
    local btnColor = replayButtonState.hovered and { 1, 0.72, 0.72, 1 } or { 1, 0.82, 0.82, 1 }
    UiPanel.drawPanel(btnX, btnY, btnW, btnH, {
        bodyColor = btnColor,
        borderColor = Theme.palette.ink,
    })
    local btnLabel = "Try Again"
    local blw = font:getWidth(btnLabel) * scale
    local blh = font:getHeight() * scale
    love.graphics.setColor(Theme.palette.ink[1], Theme.palette.ink[2], Theme.palette.ink[3], 1)
    love.graphics.print(btnLabel, btnX + (btnW - blw) * 0.5, btnY + (btnH - blh) * 0.5, 0, scale, scale)
    replayButtonState.rect = { x = btnX, y = btnY, w = btnW, h = btnH }

    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ── Public API ────────────────────────────────────────────────────────────────

function Hud.draw(gameState, sprintState, viewportScale)
    local phase = sprintState and sprintState.phase or "playing"

    if phase == "won" then
        drawWinScreen(viewportScale)
        return
    end

    if phase == "lost" then
        drawLoseScreen(sprintState and sprintState.loseReason, viewportScale)
        return
    end

    -- Normal HUD
    drawSprintPanel(sprintState, viewportScale)
    drawStatsPanel(
        gameState and gameState.money or 0,
        gameState and gameState.bugCount or 0,
        gameState and gameState.burnoutCount or 0,
        viewportScale
    )

    -- Sprint-end summary
    if phase == "summary" then
        drawSummaryOverlay(sprintState, viewportScale)
    end
end

-- Returns the replay button rect (if visible), or nil
function Hud.getReplayButtonRect()
    if replayButtonState.rect then
        return replayButtonState.rect
    end
    return nil
end

function Hud.updateReplayButton(gameX, gameY, isMouseDown)
    local rect = replayButtonState.rect
    if not rect then return end
    local inside = gameX and gameY
        and gameX >= rect.x and gameX <= rect.x + rect.w
        and gameY >= rect.y and gameY <= rect.y + rect.h
    replayButtonState.hovered = inside or false
    replayButtonState.pressed = (inside and isMouseDown) or false
end

function Hud.isReplayButtonClicked(gameX, gameY)
    local rect = replayButtonState.rect
    if not rect then return false end
    return gameX and gameY
        and gameX >= rect.x and gameX <= rect.x + rect.w
        and gameY >= rect.y and gameY <= rect.y + rect.h
end

return Hud
