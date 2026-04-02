local Theme = require("src.ui.theme")

local Button = {}
Button.__index = Button

-- Button.new creates a new 3D-press button.
-- faceColor and shadowColor are {r,g,b,a} tables (use Theme.colors.*).
function Button.new(x, y, w, h, label, faceColor, shadowColor)
    return setmetatable({
        x           = x,
        y           = y,
        w           = w,
        h           = h,
        label       = label,
        faceColor   = faceColor,
        shadowColor = shadowColor,
        depth       = 6,
        rx          = 8,
        _pressed    = false,
        _hovered    = false,
    }, Button)
end

function Button:update()
    local mx, my = love.mouse.getPosition()
    local gx, gy = screenToGame(mx, my)
    if not gx then
        self._hovered = false
        self._pressed = false
        return
    end
    self._hovered = gx >= self.x and gx <= self.x + self.w
                and gy >= self.y and gy <= self.y + self.h
    self._pressed = self._hovered and love.mouse.isDown(1)
end

function Button:draw()
    local depth = self.depth
    local dy    = self._pressed and depth or 0
    local rx    = self.rx
    local fc    = self.faceColor
    local sc    = self.shadowColor

    -- 3D depth layer (hidden when pressed)
    if not self._pressed then
        love.graphics.setColor(sc)
        love.graphics.rectangle("fill",
            self.x, self.y + depth,
            self.w, self.h, rx)
    end

    -- Face (shifts down on press)
    local brightness = self._hovered and 1.08 or 1.0
    love.graphics.setColor(fc[1] * brightness, fc[2] * brightness, fc[3] * brightness, fc[4])
    love.graphics.rectangle("fill",
        self.x, self.y + dy,
        self.w, self.h, rx)

    -- Label centered on face
    local font = Theme.fonts.button
    love.graphics.setFont(font)
    love.graphics.setColor(Theme.colors.btnText)
    local textW = font:getWidth(self.label)
    local textH = font:getHeight()
    love.graphics.print(
        self.label,
        math.floor(self.x + (self.w - textW) / 2),
        math.floor(self.y + dy + (self.h - textH) / 2)
    )
end

return Button
