local Theme = require("src.ui.theme")

local NineSlice = {}
NineSlice.__index = NineSlice

function NineSlice.new(image, cornerSize)
    local self = setmetatable({}, NineSlice)

    self.image = image or Theme.nineSlice.image
    self.cornerSize = cornerSize or Theme.nineSlice.cornerSize

    if not self.image then
        error("NineSlice: No image provided and Theme.nineSlice.image is nil")
    end

    local iw, ih = self.image:getDimensions()
    local cs = self.cornerSize
    local centerW = iw - cs * 2
    local centerH = ih - cs * 2

    self.quads = {
        love.graphics.newQuad(0, 0, cs, cs, iw, ih),
        love.graphics.newQuad(cs, 0, centerW, cs, iw, ih),
        love.graphics.newQuad(iw - cs, 0, cs, cs, iw, ih),
        love.graphics.newQuad(0, cs, cs, centerH, iw, ih),
        love.graphics.newQuad(cs, cs, centerW, centerH, iw, ih),
        love.graphics.newQuad(iw - cs, cs, cs, centerH, iw, ih),
        love.graphics.newQuad(0, ih - cs, cs, cs, iw, ih),
        love.graphics.newQuad(cs, ih - cs, centerW, cs, iw, ih),
        love.graphics.newQuad(iw - cs, ih - cs, cs, cs, iw, ih),
    }

    self.sourceCenter = { w = centerW, h = centerH }

    return self
end

function NineSlice:draw(x, y, width, height, color, scale)
    local s = scale or 1
    local cs = self.cornerSize * s
    local img = self.image
    local q = self.quads

    if color then
        love.graphics.setColor(color)
    else
        love.graphics.setColor(1, 1, 1, 1)
    end

    local centerW = width - cs * 2
    local centerH = height - cs * 2

    if centerW < 0 then centerW = 0 end
    if centerH < 0 then centerH = 0 end

    local scaleX = centerW / self.sourceCenter.w
    local scaleY = centerH / self.sourceCenter.h

    love.graphics.draw(img, q[1], x, y, 0, s, s)
    love.graphics.draw(img, q[3], x + width - cs, y, 0, s, s)
    love.graphics.draw(img, q[7], x, y + height - cs, 0, s, s)
    love.graphics.draw(img, q[9], x + width - cs, y + height - cs, 0, s, s)

    love.graphics.draw(img, q[2], x + cs, y, 0, scaleX, s)
    love.graphics.draw(img, q[8], x + cs, y + height - cs, 0, scaleX, s)
    love.graphics.draw(img, q[4], x, y + cs, 0, s, scaleY)
    love.graphics.draw(img, q[6], x + width - cs, y + cs, 0, s, scaleY)

    love.graphics.draw(img, q[5], x + cs, y + cs, 0, scaleX, scaleY)

    love.graphics.setColor(1, 1, 1, 1)
end

local _instance = nil

function NineSlice.getInstance()
    if not _instance then
        _instance = NineSlice.new()
    end
    return _instance
end

return NineSlice
