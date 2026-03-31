local Sound = {
    sources = {},
    volume = 1.0,
}

local SOUND_FILES = {
    ultra_light_tap = "assets/soundfx/ultra_light_tap.wav",
    short_light_tap = "assets/soundfx/short_light_tap.wav",
    error = "assets/soundfx/error.wav",
    notification = "assets/soundfx/notification.wav",
    tick = "assets/soundfx/ultra_light_tap.wav",
    bling = "assets/soundfx/short_light_tap.wav",
}

function Sound:init()
    for name, path in pairs(SOUND_FILES) do
        local ok, source = pcall(function()
            return love.audio.newSource(path, "static")
        end)

        if ok and source then
            self.sources[name] = source
        end
    end
end

function Sound:play(name, options)
    options = options or {}
    local source = self.sources[name]

    if not source then
        return
    end

    local clone = source:clone()
    clone:setVolume((options.volume or 1.0) * self.volume)

    if options.pitch then
        clone:setPitch(options.pitch)
    end

    clone:play()
end

function Sound:setVolume(volume)
    self.volume = math.max(0, math.min(1, volume or 1))
end

function Sound:stopAll()
    for _, source in pairs(self.sources) do
        source:stop()
    end
end

return Sound
