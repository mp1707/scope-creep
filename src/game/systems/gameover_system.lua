local GameOverSystem = {}
GameOverSystem.__index = GameOverSystem

function GameOverSystem.new()
    local self = setmetatable({}, GameOverSystem)
    return self
end

function GameOverSystem:checkSecurityIssueLoss(cards)
    local securityCount = 0
    for _, card in ipairs(cards) do
        if card.defId == "security_issue" and not card.markedForRemoval then
            securityCount = securityCount + 1
            if securityCount >= 3 then
                return true, "data_leak"
            end
        end
    end
    return false, nil
end

function GameOverSystem:checkNoEmployeeLoss(cards)
    local employeeCount = 0
    for _, card in ipairs(cards) do
        if card.kind == "employee" and not card.markedForRemoval then
            employeeCount = employeeCount + 1
        end
    end

    if employeeCount <= 0 then
        return true, "no_team_left"
    end

    return false, nil
end

return GameOverSystem
