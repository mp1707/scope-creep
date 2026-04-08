local Theme = require("src.ui.theme")
local UiPanel = require("src.ui.ui_panel")
local Constants = require("src.app.constants")
local State = require("src.app.state")
local Utils = require("src.app.utils")

local WorkBars = {}

local clamp = Utils.clamp

local function computeCapsuleFillRight(fillX, fillWidth, radius, progress)
    local p = clamp(progress or 0, 0, 1)
    if p <= 0 then
        return fillX
    end
    if p >= 1 then
        return fillX + fillWidth
    end
    local cap = math.min(math.max(0, radius), fillWidth * 0.5)
    return fillX + cap + (fillWidth - cap) * p
end

local function drawCapsuleFill(fillX, fillY, fillMaxWidth, fillHeight, progress, color)
    local radius = math.min(Constants.WORK_BAR_FILL_RADIUS, fillHeight * 0.5)
    local fillRight = computeCapsuleFillRight(fillX, fillMaxWidth, radius, progress)
    local visibleWidth = fillRight - fillX
    if visibleWidth <= 0 then
        return
    end

    local cap = math.min(radius, visibleWidth * 0.5)
    local centerY = fillY + fillHeight * 0.5
    local leftCx = fillX + cap
    local rightCx = fillRight - cap
    local bodyWidth = rightCx - leftCx

    Utils.setColorWithAlpha(color, 1)
    love.graphics.circle("fill", leftCx, centerY, cap, 20)
    if bodyWidth > 0 then
        love.graphics.rectangle("fill", leftCx, fillY, bodyWidth, fillHeight)
    end
    love.graphics.circle("fill", rightCx, centerY, cap, 20)
end

function WorkBars.draw(activeJobs)
    local colors = Theme.colors.workBar
    local H = Constants.WORK_BAR_HEIGHT
    local W = Constants.CARD_WIDTH

    for _, job in ipairs(activeJobs) do
        local worker = State.getCardByUid(job.workerUid)
        local target = State.getCardByUid(job.targetUid)
        if worker and target then
            local barX = worker.x
            local barY = math.min(worker.y, target.y) - 8 - H

            UiPanel.drawSurface(barX, barY, W, H, colors.track, { alpha = 1 })

            local progress = clamp((job.elapsed or 0) / math.max(0.0001, job.duration or 1), 0, 1)
            local fillX = barX + Constants.WORK_BAR_FILL_MARGIN_X
            local fillY = barY + Constants.WORK_BAR_FILL_MARGIN_Y
            local fillMaxWidth = math.max(0, W - Constants.WORK_BAR_FILL_MARGIN_X * 2 - Constants.WORK_BAR_FILL_RIGHT_TRIM)
            local fillHeight = math.max(0, H - Constants.WORK_BAR_FILL_MARGIN_Y * 2)

            if fillMaxWidth > 0 and fillHeight > 0 then
                drawCapsuleFill(fillX, fillY, fillMaxWidth, fillHeight, progress,
                    colors.fill or colors.border)
            end

            UiPanel.drawBorder(barX, barY, W, H, colors.border, { alpha = 1 })
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return WorkBars
