local Theme = require("src.ui.theme")

local Board = {}

local B = {
    x      = 60,
    y      = 130,
    w      = 1455,
    h      = math.floor(1080 * 0.70),
    rx     = 24,   -- outer corner radius
    shadow = 10,   -- drop shadow offset
    bw     = 5,    -- outer border width
    frame  = 16,   -- frame thickness (outer rect to inner surface)
}

-- Returns the dimensions of the inner writing surface
local function inner()
    local f = B.frame
    return {
        x  = B.x + f,
        y  = B.y + f,
        w  = B.w - f * 2,
        h  = B.h - f * 2,
        rx = math.max(4, B.rx - f),
    }
end

-- Inner shadow fading from shadowColor at the edge to transparent toward center
local function drawInnerShadow(x, y, w, h, rx, depth)
    local c = Theme.colors.boardInnerShadow
    for i = 1, depth do
        local t = 1 - (i / depth)
        love.graphics.setColor(c[1], c[2], c[3], t * t)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line",
            x + i, y + i,
            w - i * 2, h - i * 2,
            math.max(2, rx - i))
    end
    love.graphics.setLineWidth(1)
end

function Board.draw()
    local s = inner()

    -- Drop shadow
    love.graphics.setColor(0, 0, 0, 0.18)
    love.graphics.rectangle("fill",
        B.x + B.shadow, B.y + B.shadow,
        B.w, B.h, B.rx)

    -- Frame fill
    love.graphics.setColor(Theme.colors.boardFrame)
    love.graphics.rectangle("fill", B.x, B.y, B.w, B.h, B.rx)

    -- Outer border
    love.graphics.setColor(Theme.colors.boardBorder)
    love.graphics.setLineWidth(B.bw)
    love.graphics.rectangle("line", B.x, B.y, B.w, B.h, B.rx)
    love.graphics.setLineWidth(1)

    -- Inner writing surface
    love.graphics.setColor(Theme.colors.board)
    love.graphics.rectangle("fill", s.x, s.y, s.w, s.h, s.rx)

    -- Inner shadow
    drawInnerShadow(s.x, s.y, s.w, s.h, s.rx, 30)

    -- Inner border (black outline on the inner edge of the frame)
    love.graphics.setColor(Theme.colors.boardBorder)
    love.graphics.setLineWidth(B.bw)
    love.graphics.rectangle("line", s.x, s.y, s.w, s.h, s.rx)
    love.graphics.setLineWidth(1)
end

return Board
