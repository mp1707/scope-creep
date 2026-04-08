local TimeSystem = {}
TimeSystem.__index = TimeSystem

function TimeSystem.new(gameStateSystem)
    local self = setmetatable({}, TimeSystem)
    self.gameStateSystem = gameStateSystem
    self.totalRealTime = 0
    self.totalSimTime = 0
    return self
end

function TimeSystem:step(dt)
    local realDt = math.max(0, dt or 0)
    self.totalRealTime = self.totalRealTime + realDt

    local simDt = 0
    if self.gameStateSystem:isSimulationRunning() then
        simDt = realDt * self.gameStateSystem:getSpeedFactor()
    end

    self.totalSimTime = self.totalSimTime + simDt

    return {
        realDt = realDt,
        simDt = simDt,
    }
end

function TimeSystem:getSimTime()
    return self.totalSimTime
end

function TimeSystem:serialize()
    return {
        totalRealTime = self.totalRealTime,
        totalSimTime = self.totalSimTime,
    }
end

function TimeSystem:deserialize(snapshot)
    if type(snapshot) ~= "table" then
        return
    end
    self.totalRealTime = snapshot.totalRealTime or self.totalRealTime
    self.totalSimTime = snapshot.totalSimTime or self.totalSimTime
end

return TimeSystem
