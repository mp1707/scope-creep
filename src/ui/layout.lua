local Layout = {}

local BASE_SCREEN_W = 1920
local BASE_SCREEN_H = 1080

function Layout.compute(state)
    local w, h = love.graphics.getDimensions()
    local scale = math.min(w / BASE_SCREEN_W, h / BASE_SCREEN_H)

    local sidebarW = math.floor(340 * scale)
    local sidebarX = w - sidebarW - math.floor(28 * scale)

    local mainLeft = math.floor(28 * scale)
    local mainRight = sidebarX - math.floor(20 * scale)
    local mainW = mainRight - mainLeft
    local boardTop = math.floor(80 * scale)

    local handCardH = math.floor(210 * scale)
    local boardBottom = h - handCardH - math.floor(110 * scale)
    if boardBottom < boardTop + math.floor(220 * scale) then
        boardBottom = boardTop + math.floor(220 * scale)
    end

    local boardH = boardBottom - boardTop

    local rowCount = math.max(1, #state.rows)
    local rowGap = math.floor(16 * scale)
    local rowAvailable = boardH - rowGap * (rowCount - 1)
    local maxRowH = rowAvailable / rowCount

    local devW = math.floor(math.min(140 * scale, maxRowH * 0.92))
    local devH = devW

    local devGap = math.floor(24 * scale)
    local colGap = math.floor(20 * scale)

    local slotH = math.floor(math.min(210 * scale, maxRowH * 0.94))
    local slotWByHeight = math.floor(slotH * 0.78)
    local slotWByWidth = math.floor((mainW - devW - devGap - colGap * 3) / 4)
    local slotW = math.max(86, math.min(slotWByHeight, slotWByWidth))
    slotH = math.floor(math.max(100, math.min(slotH, slotW * 1.35)))

    local pipelineW = slotW * 4 + colGap * 3
    local totalBoardW = devW + devGap + pipelineW
    local boardX = mainLeft + math.floor((mainW - totalBoardW) * 0.5)
    if boardX < mainLeft then
        boardX = mainLeft
    end
    local pipelineX = boardX + devW + devGap
    local boardRight = boardX + totalBoardW

    local rowH = math.max(devH, slotH)
    local totalRowsH = rowCount * rowH + (rowCount - 1) * rowGap
    local rowsStartY = boardTop + math.floor((boardH - totalRowsH) * 0.5)

    local rows = {}
    for i = 1, rowCount do
        local rowY = rowsStartY + (i - 1) * (rowH + rowGap)
        local slotY = rowY + math.floor((rowH - slotH) * 0.5)

        local r = {
            y = rowY,
            devRect = {
                x = boardX,
                y = rowY + math.floor((rowH - devH) * 0.5),
                w = devW,
                h = devH,
            },
            inProgressRect = { x = pipelineX, y = slotY, w = slotW, h = slotH },
            testingRect = { x = pipelineX + (slotW + colGap), y = slotY, w = slotW, h = slotH },
            rolloutRect = { x = pipelineX + 2 * (slotW + colGap), y = slotY, w = slotW, h = slotH },
            doneRect = { x = pipelineX + 3 * (slotW + colGap), y = slotY, w = slotW, h = slotH },
            inProgressCardRect = nil,
            testingCardRect = nil,
            rolloutCardRect = nil,
            shipButtonRect = nil,
        }
        table.insert(rows, r)
    end

    local buttonW = math.floor(220 * scale)
    local buttonH = math.floor(74 * scale)
    local buttonX = sidebarX - buttonW - math.floor(24 * scale)
    local buttonPlayY = h - handCardH - math.floor(100 * scale)
    local buttonEndY = buttonPlayY + buttonH + math.floor(18 * scale)

    local handLeft = boardX + math.floor(28 * scale)
    local handRight = buttonX - math.floor(24 * scale)
    if handRight < handLeft + 300 then
        handRight = boardRight - math.floor(18 * scale)
    end

    local handCardW = math.floor(math.min(180 * scale, (handRight - handLeft) / 4.4))
    handCardH = math.floor(handCardW * 1.35)

    local handY = h - handCardH - math.floor(26 * scale)

    local sidebarRect = {
        x = sidebarX,
        y = boardTop,
        w = sidebarW,
        h = boardBottom - boardTop + math.floor(20 * scale),
    }

    local backlogRect = {
        x = sidebarX + math.floor(76 * scale),
        y = h - math.floor(156 * scale),
        w = math.floor(95 * scale),
        h = math.floor(125 * scale),
    }

    return {
        w = w,
        h = h,
        scale = scale,

        boardX = boardX,
        boardRight = boardRight,
        boardTop = boardTop,
        boardBottom = boardBottom,
        boardDropRect = {
            x = boardX,
            y = boardTop,
            w = boardRight - boardX,
            h = boardBottom - boardTop,
        },

        rows = rows,
        pipelineX = pipelineX,
        slotW = slotW,
        slotH = slotH,

        hand = {
            left = handLeft,
            right = handRight,
            y = handY,
            cardW = handCardW,
            cardH = handCardH,
        },

        buttons = {
            playCard = {
                id = "play_card",
                x = buttonX,
                y = buttonPlayY,
                w = buttonW,
                h = buttonH,
            },
            endDay = {
                id = "end_day",
                x = buttonX,
                y = buttonEndY,
                w = buttonW,
                h = buttonH,
            },
            nextSprint = {
                id = "next_sprint",
                x = math.floor((w - math.floor(280 * scale)) * 0.5),
                y = h - math.floor(140 * scale),
                w = math.floor(280 * scale),
                h = math.floor(76 * scale),
            },
        },

        sidebar = {
            rect = sidebarRect,
            backlogRect = backlogRect,
        },

        retrospective = {
            officeRect = {
                x = math.floor(180 * scale),
                y = math.floor(370 * scale),
                w = math.floor(200 * scale),
                h = math.floor(230 * scale),
            },
            applicantStartX = math.floor(640 * scale),
            applicantY = math.floor(370 * scale),
            applicantGap = math.floor(40 * scale),
            applicantW = math.floor(180 * scale),
            applicantH = math.floor(180 * scale),
        },
    }
end

return Layout
