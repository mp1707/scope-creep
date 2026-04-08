local Constants = require("src.app.constants")
local Utils = require("src.app.utils")

local Camera = {
    x = 0,
    y = 0,
    zoom = 1,
    minZoom = 0.65,
    maxZoom = 1.9,
    zoomStep = 1.12,
}

function Camera.getViewSize()
    local zoom = Camera.zoom
    if zoom <= 0 then
        zoom = 1
    end
    return Constants.APP_WIDTH / zoom, Constants.APP_HEIGHT / zoom
end

function Camera.clamp()
    local viewW, viewH = Camera.getViewSize()
    Camera.x = Utils.clamp(Camera.x, 0, math.max(0, Constants.WORLD_WIDTH - viewW))
    Camera.y = Utils.clamp(Camera.y, 0, math.max(0, Constants.WORLD_HEIGHT - viewH))
end

function Camera.centerOn(worldX, worldY)
    local viewW, viewH = Camera.getViewSize()
    Camera.x = (worldX or 0) - viewW * 0.5
    Camera.y = (worldY or 0) - viewH * 0.5
    Camera.clamp()
end

function Camera.gameToWorld(gameX, gameY)
    if gameX == nil or gameY == nil then
        return nil, nil
    end
    local zoom = Camera.zoom
    if zoom <= 0 then
        zoom = 1
    end
    return Camera.x + (gameX / zoom), Camera.y + (gameY / zoom)
end

function Camera.reset()
    Camera.x = 0
    Camera.y = 0
    Camera.zoom = 1
end

return Camera
