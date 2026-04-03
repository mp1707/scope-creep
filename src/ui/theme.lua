local Theme = {}

Theme.colors = {
    background = { 1, 1, 1, 1 },
    text       = { 0, 0, 0, 1 },
}

Theme.fonts = {}

function Theme.load()
    Theme.fonts.default = love.graphics.newFont("assets/fonts/PatrickHand-Regular.ttf", 32)
    Theme.fonts.title = love.graphics.newFont("assets/fonts/PatrickHand-Regular.ttf", 96)

    Theme.fonts.default:setFilter("linear", "linear")
    Theme.fonts.title:setFilter("linear", "linear")

    love.graphics.setFont(Theme.fonts.default)
end

return Theme
