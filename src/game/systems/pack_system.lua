local PackSystem = {}
PackSystem.__index = PackSystem

function PackSystem.new(packDefs)
    local self = setmetatable({}, PackSystem)
    self.packDefs = packDefs
    return self
end

local function randomAngle(randomFn)
    local randomValue = randomFn and randomFn() or math.random()
    return randomValue * math.pi * 2
end

function PackSystem:createPackRuntime(defId)
    local def = self.packDefs.get(defId)
    if not def then
        return nil
    end

    return {
        defId = defId,
        usesRemaining = def.uses,
        nextSequenceIndex = 1,
        removeFade = nil,
    }
end

function PackSystem:openPack(packCard, callbacks)
    if not packCard or packCard.objectType ~= "booster_pack" then
        return nil
    end

    local runtime = packCard.packRuntime
    if not runtime or runtime.usesRemaining <= 0 then
        return nil
    end

    local packDef = self.packDefs.get(runtime.defId)
    if not packDef then
        return nil
    end

    local spawnDefId = packDef.sequence[runtime.nextSequenceIndex]
    if not spawnDefId then
        return nil
    end

    local centerX = packCard.x + (packCard.width * 0.5)
    local centerY = packCard.y + (packCard.height * 0.5)

    local angle = randomAngle(callbacks.random)
    local radius = 54 + ((callbacks.random and callbacks.random() or math.random()) * 34)
    local spawnX = centerX + math.cos(angle) * radius
    local spawnY = centerY + math.sin(angle) * radius

    callbacks.spawnCard(spawnDefId, spawnX, spawnY, { withBounce = true })

    runtime.nextSequenceIndex = runtime.nextSequenceIndex + 1
    runtime.usesRemaining = runtime.usesRemaining - 1

    if runtime.usesRemaining <= 0 then
        runtime.usesRemaining = 0
        runtime.removeFade = {
            elapsed = 0,
            duration = 0.3,
        }
    end

    return spawnDefId
end

function PackSystem:update(realDt, cards, callbacks)
    for _, card in ipairs(cards) do
        if card.objectType == "booster_pack" and card.packRuntime and card.packRuntime.removeFade then
            local fade = card.packRuntime.removeFade
            fade.elapsed = fade.elapsed + realDt
            local progress = fade.elapsed / fade.duration
            if progress > 1 then
                progress = 1
            end

            card.renderAlpha = 1 - progress
            if progress >= 1 then
                callbacks.removeCard(card)
            end
        end
    end
end

return PackSystem
