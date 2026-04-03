function love.conf(t)
    t.identity = "scope-creep"
    t.version = "11.4"

    t.window.title = "Scope Creep"
    t.window.width = 1920
    t.window.height = 1080
    t.window.resizable = true
    t.window.vsync = 1
    t.window.highdpi = true
    t.window.minwidth = 854
    t.window.minheight = 480

    t.modules.joystick = false
    t.modules.physics = false
    t.modules.video = false

    t.modules.audio = true
    t.modules.graphics = true
    t.modules.window = true
    t.modules.timer = true
    t.modules.keyboard = true
    t.modules.mouse = true
    t.modules.sound = true
    t.modules.font = true
    t.modules.image = true
end
