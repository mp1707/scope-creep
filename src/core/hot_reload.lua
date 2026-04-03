-- Hot Reload for Scope Creep
-- Watches Lua files and reloads code while preserving runtime state.

local HotReload = {
    enabled = true,
    checkInterval = 0.5,
    lastCheck = 0,
    fileModTimes = {},
    reloadMessage = nil,
    reloadMessageTime = 0,

    getState = nil,
    setState = nil,
    onReload = nil,
}

local function collectLuaFiles(dir, files)
    files = files or {}

    local okItems, items = pcall(love.filesystem.getDirectoryItems, dir)
    if not okItems or not items then
        return files
    end

    for _, item in ipairs(items) do
        local path = dir .. "/" .. item
        local info = love.filesystem.getInfo(path)
        if info then
            if info.type == "directory" then
                collectLuaFiles(path, files)
            elseif item:match("%.lua$") then
                files[path] = info.modtime or 0
            end
        end
    end

    return files
end

local function snapshotFileTimes()
    local files = collectLuaFiles("src", {})

    local mainInfo = love.filesystem.getInfo("main.lua")
    if mainInfo then
        files["main.lua"] = mainInfo.modtime or 0
    end

    return files
end

local function hasAnyChanges(previous, current)
    for path, modtime in pairs(current) do
        if previous[path] ~= modtime then
            return true
        end
    end

    for path, _ in pairs(previous) do
        if current[path] == nil then
            return true
        end
    end

    return false
end

function HotReload:reload()
    local savedState = nil
    if self.getState then
        local ok, state = pcall(self.getState)
        if ok then
            savedState = state
        end
    end

    for name, _ in pairs(package.loaded) do
        if name:match("^src%.") and name ~= "src.core.hot_reload" then
            package.loaded[name] = nil
        end
    end

    if self.onReload then
        local okReload, err = pcall(self.onReload)
        if not okReload then
            print("Hot reload error: " .. tostring(err))
            return
        end
    end

    if savedState and self.setState then
        local okSet, err = pcall(self.setState, savedState)
        if not okSet then
            print("Hot reload state restore error: " .. tostring(err))
        end
    end

    self.fileModTimes = snapshotFileTimes()
    self.reloadMessage = "Reloaded"
    self.reloadMessageTime = love.timer.getTime()
end

function HotReload:update(dt)
    if not self.enabled then
        return
    end

    self.lastCheck = self.lastCheck + dt
    if self.lastCheck < self.checkInterval then
        return
    end

    self.lastCheck = 0

    local currentFiles = snapshotFileTimes()
    if hasAnyChanges(self.fileModTimes, currentFiles) then
        self:reload()
    else
        self.fileModTimes = currentFiles
    end
end

function HotReload:draw(drawHeight, viewportScale)
    if not self.reloadMessage then
        return
    end

    local elapsed = love.timer.getTime() - self.reloadMessageTime
    if elapsed > 2 then
        self.reloadMessage = nil
        return
    end

    local alpha = 1
    if elapsed > 1.4 then
        alpha = (2 - elapsed) / 0.6
    end

    local color = { 0.22, 0.78, 0.47, math.max(0, alpha) }
    local height = drawHeight or love.graphics.getHeight()
    local scale = tonumber(viewportScale) or 1
    if scale <= 0 then
        scale = 1
    end

    love.graphics.setColor(0, 0, 0, 0.38 * color[4])
    love.graphics.print(self.reloadMessage, 18, height - 34, 0, 1 / scale, 1 / scale)
    love.graphics.setColor(color)
    love.graphics.print(self.reloadMessage, 16, height - 36, 0, 1 / scale, 1 / scale)
    love.graphics.setColor(1, 1, 1, 1)
end

HotReload.fileModTimes = snapshotFileTimes()

return HotReload
