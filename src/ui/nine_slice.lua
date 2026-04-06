local NineSlice = {}

local imageCache = {}
local imageLoadAttempted = {}
local quadCache = setmetatable({}, { __mode = "k" })

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function getSourceRect(options, imageWidth, imageHeight)
    local sourceX = math.floor(tonumber(options.sourceX) or 0)
    local sourceY = math.floor(tonumber(options.sourceY) or 0)
    local sourceWidth = math.floor(tonumber(options.sourceWidth) or imageWidth)
    local sourceHeight = math.floor(tonumber(options.sourceHeight) or imageHeight)

    sourceX = clamp(sourceX, 0, math.max(0, imageWidth - 1))
    sourceY = clamp(sourceY, 0, math.max(0, imageHeight - 1))
    sourceWidth = clamp(sourceWidth, 1, imageWidth - sourceX)
    sourceHeight = clamp(sourceHeight, 1, imageHeight - sourceY)

    return sourceX, sourceY, sourceWidth, sourceHeight
end

local function getInsets(options, sourceWidth, sourceHeight)
    local left = math.floor(tonumber(options.left) or (sourceWidth * 0.25))
    local right = math.floor(tonumber(options.right) or (sourceWidth * 0.25))
    local top = math.floor(tonumber(options.top) or (sourceHeight * 0.25))
    local bottom = math.floor(tonumber(options.bottom) or (sourceHeight * 0.25))

    left = clamp(left, 0, math.max(0, sourceWidth - 2))
    right = clamp(right, 0, math.max(0, sourceWidth - left - 1))
    top = clamp(top, 0, math.max(0, sourceHeight - 2))
    bottom = clamp(bottom, 0, math.max(0, sourceHeight - top - 1))

    return left, right, top, bottom
end

local function getDestInsets(options, left, right, top, bottom)
    local destLeft = tonumber(options.destLeft) or left
    local destRight = tonumber(options.destRight) or right
    local destTop = tonumber(options.destTop) or top
    local destBottom = tonumber(options.destBottom) or bottom

    destLeft = math.max(0, destLeft)
    destRight = math.max(0, destRight)
    destTop = math.max(0, destTop)
    destBottom = math.max(0, destBottom)

    return destLeft, destRight, destTop, destBottom
end

local function getImage(path)
    if not path or path == "" then
        return nil
    end

    if imageCache[path] or imageLoadAttempted[path] then
        return imageCache[path]
    end

    imageLoadAttempted[path] = true
    local ok, image = pcall(love.graphics.newImage, path)
    if not ok then
        return nil
    end

    image:setFilter("linear", "linear")
    imageCache[path] = image
    return image
end

local function getQuads(image, sourceX, sourceY, sourceWidth, sourceHeight, left, right, top, bottom)
    local key = string.format(
        "%d:%d:%d:%d:%d:%d:%d:%d",
        sourceX,
        sourceY,
        sourceWidth,
        sourceHeight,
        left,
        right,
        top,
        bottom
    )
    local imageEntry = quadCache[image]
    if not imageEntry then
        imageEntry = {}
        quadCache[image] = imageEntry
    end

    if imageEntry[key] then
        return imageEntry[key]
    end

    local imageWidth = image:getWidth()
    local imageHeight = image:getHeight()
    local centerWidth = math.max(1, sourceWidth - left - right)
    local centerHeight = math.max(1, sourceHeight - top - bottom)
    local sourceRight = sourceX + sourceWidth
    local sourceBottom = sourceY + sourceHeight

    local quads = {
        source = {
            left = left,
            right = right,
            top = top,
            bottom = bottom,
            centerWidth = centerWidth,
            centerHeight = centerHeight,
        },
        topLeft = love.graphics.newQuad(sourceX, sourceY, left, top, imageWidth, imageHeight),
        top = love.graphics.newQuad(sourceX + left, sourceY, centerWidth, top, imageWidth, imageHeight),
        topRight = love.graphics.newQuad(sourceRight - right, sourceY, right, top, imageWidth, imageHeight),
        left = love.graphics.newQuad(sourceX, sourceY + top, left, centerHeight, imageWidth, imageHeight),
        center = love.graphics.newQuad(sourceX + left, sourceY + top, centerWidth, centerHeight, imageWidth, imageHeight),
        right = love.graphics.newQuad(sourceRight - right, sourceY + top, right, centerHeight, imageWidth, imageHeight),
        bottomLeft = love.graphics.newQuad(sourceX, sourceBottom - bottom, left, bottom, imageWidth, imageHeight),
        bottom = love.graphics.newQuad(sourceX + left, sourceBottom - bottom, centerWidth, bottom, imageWidth, imageHeight),
        bottomRight = love.graphics.newQuad(sourceRight - right, sourceBottom - bottom, right, bottom, imageWidth, imageHeight),
    }

    imageEntry[key] = quads
    return quads
end

local function fitSegments(total, startSize, endSize)
    local start = startSize
    local finish = endSize
    local middle = total - start - finish

    if middle >= 0 then
        return start, middle, finish
    end

    local combined = start + finish
    if combined <= 0 then
        return 0, total, 0
    end

    local scale = total / combined
    start = start * scale
    finish = finish * scale
    return start, 0, finish
end

local function drawPart(image, quad, x, y, width, height, sourceWidth, sourceHeight)
    if width <= 0 or height <= 0 or sourceWidth <= 0 or sourceHeight <= 0 then
        return
    end

    love.graphics.draw(image, quad, x, y, 0, width / sourceWidth, height / sourceHeight)
end

function NineSlice.draw(imagePath, x, y, width, height, options)
    if width <= 0 or height <= 0 then
        return false
    end

    options = options or {}
    local image = getImage(imagePath)
    if not image then
        return false
    end

    local imageWidth = image:getWidth()
    local imageHeight = image:getHeight()
    if imageWidth <= 0 or imageHeight <= 0 then
        return false
    end

    local sourceX, sourceY, sourceWidth, sourceHeight = getSourceRect(options, imageWidth, imageHeight)
    local left, right, top, bottom = getInsets(options, sourceWidth, sourceHeight)
    if left <= 0 or right <= 0 or top <= 0 or bottom <= 0 then
        return false
    end

    local quads = getQuads(image, sourceX, sourceY, sourceWidth, sourceHeight, left, right, top, bottom)
    local source = quads.source
    local destLeft, destRight, destTop, destBottom = getDestInsets(options, left, right, top, bottom)
    local drawLeft, drawMiddleWidth, drawRight = fitSegments(width, destLeft, destRight)
    local drawTop, drawMiddleHeight, drawBottom = fitSegments(height, destTop, destBottom)

    local alpha = tonumber(options.alpha) or 1
    local tint = options.tint or { 1, 1, 1, 1 }
    local drawCenter = options.drawCenter ~= false
    local drawEdges = options.drawEdges ~= false
    local drawCorners = options.drawCorners ~= false
    love.graphics.setColor(tint[1] or 1, tint[2] or 1, tint[3] or 1, (tint[4] or 1) * alpha)

    local leftX = x
    local middleX = x + drawLeft
    local rightX = x + drawLeft + drawMiddleWidth
    local topY = y
    local middleY = y + drawTop
    local bottomY = y + drawTop + drawMiddleHeight

    if drawCorners then
        drawPart(image, quads.topLeft, leftX, topY, drawLeft, drawTop, source.left, source.top)
        drawPart(image, quads.topRight, rightX, topY, drawRight, drawTop, source.right, source.top)
    end
    if drawEdges then
        drawPart(image, quads.top, middleX, topY, drawMiddleWidth, drawTop, source.centerWidth, source.top)
    end

    if drawEdges then
        drawPart(image, quads.left, leftX, middleY, drawLeft, drawMiddleHeight, source.left, source.centerHeight)
    end
    if drawCenter then
        drawPart(image, quads.center, middleX, middleY, drawMiddleWidth, drawMiddleHeight, source.centerWidth, source.centerHeight)
    end
    if drawEdges then
        drawPart(image, quads.right, rightX, middleY, drawRight, drawMiddleHeight, source.right, source.centerHeight)
    end

    if drawCorners then
        drawPart(image, quads.bottomLeft, leftX, bottomY, drawLeft, drawBottom, source.left, source.bottom)
        drawPart(image, quads.bottomRight, rightX, bottomY, drawRight, drawBottom, source.right, source.bottom)
    end
    if drawEdges then
        drawPart(image, quads.bottom, middleX, bottomY, drawMiddleWidth, drawBottom, source.centerWidth, source.bottom)
    end

    return true
end

return NineSlice
