local GameStateSystem = {}
GameStateSystem.__index = GameStateSystem

function GameStateSystem.new()
    local self = setmetatable({}, GameStateSystem)
    self.phase = "boot"
    self.speedFactor = 1
    self.gameoverReason = nil
    return self
end

function GameStateSystem:getPhase()
    return self.phase
end

function GameStateSystem:setPhase(phase)
    self.phase = phase
end

function GameStateSystem:getSpeedFactor()
    return self.speedFactor
end

function GameStateSystem:toggleSpeed()
    if self.speedFactor == 1 then
        self.speedFactor = 2
    else
        self.speedFactor = 1
    end
    return self.speedFactor
end

function GameStateSystem:togglePause()
    if self.phase == "running" then
        self.phase = "paused"
        return self.phase
    end
    if self.phase == "paused" then
        self.phase = "running"
        return self.phase
    end
    return self.phase
end

function GameStateSystem:isSimulationRunning()
    return self.phase == "running"
end

function GameStateSystem:isPayday()
    return self.phase == "payday"
end

function GameStateSystem:isGameOver()
    return self.phase == "gameover"
end

function GameStateSystem:setGameOver(reason)
    self.phase = "gameover"
    self.gameoverReason = reason
end

function GameStateSystem:getGameOverReason()
    return self.gameoverReason
end

function GameStateSystem:serialize()
    return {
        phase = self.phase,
        speedFactor = self.speedFactor,
        gameoverReason = self.gameoverReason,
    }
end

function GameStateSystem:deserialize(snapshot)
    if type(snapshot) ~= "table" then
        return
    end
    self.phase = snapshot.phase or self.phase
    self.speedFactor = snapshot.speedFactor or self.speedFactor
    self.gameoverReason = snapshot.gameoverReason
end

return GameStateSystem
