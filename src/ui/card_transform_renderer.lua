-- Card Transform Renderer
-- Draws card-like UI through a temporary canvas when transforms are active.
-- Matches Space Eels smoothing to avoid staircase artifacts on tilt/scale/rotate.

local CardTransformRenderer = {}

local canvasCache = {}
local EPSILON = 0.001

local function isIdentityTransform(rotation, scaleX, scaleY, shearX, shearY)
    if math.abs(rotation) > EPSILON then return false end
    if math.abs(scaleX - 1) > EPSILON then return false end
    if math.abs(scaleY - 1) > EPSILON then return false end
    if math.abs(shearX) > EPSILON then return false end
    if math.abs(shearY) > EPSILON then return false end
    return true
end

local function getCanvas(width, height, padding)
    local canvasW = math.max(1, math.floor(width + padding * 2 + 0.5))
    local canvasH = math.max(1, math.floor(height + padding * 2 + 0.5))
    local key = tostring(canvasW) .. "x" .. tostring(canvasH)

    local canvas = canvasCache[key]
    if not canvas then
        canvas = love.graphics.newCanvas(canvasW, canvasH)
        canvas:setFilter("nearest", "nearest")
        canvasCache[key] = canvas
    end

    return canvas
end

-- config:
--   x, y, width, height: destination rect (top-left + size)
--   drawFn(x, y, width, height, alpha): draws the card contents
--   alpha: final output alpha (default 1)
--   rotation, scaleX, scaleY, scale, shearX, shearY: transforms around card center
--   padding: offscreen canvas padding (default 6)
--   snap: pixel-snap destination position (default true)
--   forceCanvas: force canvas path even when transform is identity (default false)
function CardTransformRenderer.draw(config)
    local drawFn = config.drawFn
    if not drawFn then
        return
    end

    local x = config.x or 0
    local y = config.y or 0
    local width = config.width or 0
    local height = config.height or 0

    local alpha = config.alpha or 1
    local rotation = config.rotation or 0
    local scale = config.scale
    local scaleX = config.scaleX or scale or 1
    local scaleY = config.scaleY or scale or 1
    local shearX = config.shearX or 0
    local shearY = config.shearY or 0
    local padding = config.padding or 6
    local snap = config.snap ~= false
    local forceCanvas = config.forceCanvas == true

    local drawX = x
    local drawY = y
    if snap then
        drawX = math.floor(drawX + 0.5)
        drawY = math.floor(drawY + 0.5)
    end

    if not forceCanvas and isIdentityTransform(rotation, scaleX, scaleY, shearX, shearY) then
        drawFn(drawX, drawY, width, height, alpha)
        return
    end

    local canvas = getCanvas(width, height, padding)

    -- Render card face flat into offscreen canvas.
    love.graphics.push("all")
    love.graphics.setCanvas({ canvas, stencil = true })
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.origin()
    drawFn(padding, padding, width, height, 1)
    love.graphics.pop()

    -- Draw transformed canvas with linear filtering to smooth edges.
    canvas:setFilter("linear", "linear")
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(
        canvas,
        drawX + width / 2,
        drawY + height / 2,
        rotation,
        scaleX, scaleY,
        width / 2 + padding,
        height / 2 + padding,
        shearX, shearY
    )
    canvas:setFilter("nearest", "nearest")

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha")
end

return CardTransformRenderer
