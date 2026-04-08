local Theme = require("src.ui.theme")
local Constants = require("src.app.constants")
local Utils = require("src.app.utils")

local Background = {}

local officeBackgroundImage = nil
local loadAttempted = false
local coverQuadCache = setmetatable({}, { __mode = "k" })

local function getImage()
    if officeBackgroundImage or loadAttempted then
        return officeBackgroundImage
    end
    loadAttempted = true
    local ok, img = pcall(love.graphics.newImage, Constants.OFFICE_BACKGROUND_PATH)
    if not ok then
        return nil
    end
    img:setFilter("linear", "linear")
    officeBackgroundImage = img
    return officeBackgroundImage
end

local function drawImageCover(image, x, y, width, height)
    local iw, ih = image:getWidth(), image:getHeight()
    if iw <= 0 or ih <= 0 or width <= 0 or height <= 0 then
        return
    end

    local scale = math.max(width / iw, height / ih)
    local srcW = width / scale
    local srcH = height / scale
    local srcX = (iw - srcW) * 0.5
    local srcY = (ih - srcH) * 0.5

    local quad = coverQuadCache[image]
    if not quad then
        quad = love.graphics.newQuad(0, 0, 1, 1, iw, ih)
        coverQuadCache[image] = quad
    end

    quad:setViewport(srcX, srcY, srcW, srcH, iw, ih)
    love.graphics.draw(image, quad, x, y, 0, width / srcW, height / srcH)
end

function Background.draw()
    local image = getImage()
    if image then
        Utils.setColorWithAlpha(Theme.colors.background or { 1, 1, 1, 1 }, 1)
        drawImageCover(image, 0, 0, Constants.WORLD_WIDTH, Constants.WORLD_HEIGHT)
        if Theme.colors.backgroundWash then
            Utils.setColorWithAlpha(Theme.colors.backgroundWash, 1)
            love.graphics.rectangle("fill", 0, 0, Constants.WORLD_WIDTH, Constants.WORLD_HEIGHT)
        end
        love.graphics.setColor(1, 1, 1, 1)
        return
    end

    local fallback = Theme.colors.background or { 1, 1, 1, 1 }
    Utils.setColorWithAlpha(fallback, 1)
    love.graphics.rectangle("fill", 0, 0, Constants.WORLD_WIDTH, Constants.WORLD_HEIGHT)
    love.graphics.setColor(1, 1, 1, 1)
end

return Background
