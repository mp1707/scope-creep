local Theme = {}

Theme.colors = {
    background       = { 0.863, 0.737, 0.545, 1 },  -- #dcbc8b
    boardFrame       = { 0.820, 0.816, 0.812, 1 },  -- #d1d0cf
    board            = { 0.973, 0.961, 0.929, 1 },  -- off-white writing surface
    boardBorder      = { 0.094, 0.071, 0.055, 1 },  -- near-black
    boardInnerShadow = { 0.812, 0.800, 0.796, 1 },  -- #cfcccb

    -- Sticky notes
    stickyNote       = { 0.953, 0.906, 0.816, 1 },  -- #f3e7d0
    stickyNoteShadow = { 0.733, 0.612, 0.451, 1 },  -- #bb9c73
    stickyNoteText   = { 0.102, 0.102, 0.180, 1 },  -- #1A1A2E

    -- Buttons
    btnEndDayFace    = { 0.361, 0.545, 0.369, 1 },  -- #5c8b5e muted forest green
    btnEndDayShadow  = { 0.239, 0.380, 0.251, 1 },  -- #3d6140
    btnDiscardFace   = { 0.722, 0.361, 0.322, 1 },  -- #b85c52 clay red
    btnDiscardShadow = { 0.490, 0.247, 0.220, 1 },  -- #7d3f38
    btnText          = { 0.973, 0.961, 0.929, 1 },  -- off-white
}

Theme.fonts = {}

function Theme.load()
    Theme.fonts.heading     = love.graphics.newFont("assets/fonts/Kalam-Bold.ttf", 80)
    Theme.fonts.body        = love.graphics.newFont("assets/fonts/PatrickHand-Regular.ttf", 32)
    Theme.fonts.noteHeading = love.graphics.newFont("assets/fonts/Kalam-Bold.ttf", 26)
    Theme.fonts.noteBody    = love.graphics.newFont("assets/fonts/PatrickHand-Regular.ttf", 22)
    Theme.fonts.button      = love.graphics.newFont("assets/fonts/Kalam-Bold.ttf", 28)

    for _, font in pairs(Theme.fonts) do
        font:setFilter("linear", "linear")
    end
end

return Theme
