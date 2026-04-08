local SprintSystem = {}
SprintSystem.__index = SprintSystem

function SprintSystem.new(duration)
    local self = setmetatable({}, SprintSystem)
    self.duration = duration or 60
    self.sprintTimer = 0
    self.sprintNumber = 1
    return self
end

function SprintSystem:getSprintTimer()
    return self.sprintTimer
end

function SprintSystem:getSprintNumber()
    return self.sprintNumber
end

function SprintSystem:getRemainingTime()
    local remaining = self.duration - self.sprintTimer
    if remaining < 0 then
        remaining = 0
    end
    return remaining
end

function SprintSystem:update(simDt)
    if simDt <= 0 then
        return false
    end

    self.sprintTimer = self.sprintTimer + simDt
    if self.sprintTimer >= self.duration then
        self.sprintTimer = self.duration
        return true
    end

    return false
end

function SprintSystem:resetForNextSprint()
    self.sprintTimer = 0
    self.sprintNumber = self.sprintNumber + 1
end

function SprintSystem:serialize()
    return {
        duration = self.duration,
        sprintTimer = self.sprintTimer,
        sprintNumber = self.sprintNumber,
    }
end

function SprintSystem:deserialize(snapshot)
    if type(snapshot) ~= "table" then
        return
    end

    self.duration = snapshot.duration or self.duration
    self.sprintTimer = snapshot.sprintTimer or self.sprintTimer
    self.sprintNumber = snapshot.sprintNumber or self.sprintNumber
end

return SprintSystem
