local Theme = {}

Theme.colors = {
    background  = { 0.863, 0.737, 0.545, 1 },  -- #dcbc8b
    boardFrame       = { 0.820, 0.816, 0.812, 1 },  -- #d1d0cf
    board            = { 0.973, 0.961, 0.929, 1 },  -- off-white writing surface
    boardBorder      = { 0.094, 0.071, 0.055, 1 },  -- near-black
    boardInnerShadow = { 0.812, 0.800, 0.796, 1 },  -- #cfcccb
}

Theme.fonts = {}

function Theme.load()
    Theme.fonts.heading = love.graphics.newFont("assets/fonts/Kalam-Bold.ttf", 80)
    Theme.fonts.body    = love.graphics.newFont("assets/fonts/PatrickHand-Regular.ttf", 32)
    Theme.fonts.heading:setFilter("linear", "linear")
    Theme.fonts.body:setFilter("linear", "linear")
end

return Theme
