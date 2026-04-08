local WorkSystem = {}
WorkSystem.__index = WorkSystem

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function makeJobKey(candidate)
    return tostring(candidate.targetUid)
end

function WorkSystem.new()
    local self = setmetatable({}, WorkSystem)
    self.activeJobs = {}
    return self
end

local function clearCardProgress(card)
    if not card then
        return
    end
    card.activeProgress = 0
    card.recipeActive = false
    card.recipeElapsed = 0
    card.recipeDuration = nil
    card.recipePartnerId = nil
end

function WorkSystem:clear(cardsByUid)
    for targetUid, _ in pairs(self.activeJobs) do
        local targetCard = cardsByUid and cardsByUid[tonumber(targetUid)]
        clearCardProgress(targetCard)
    end
    self.activeJobs = {}
end

local function computeDuration(worker, target, techDebtCount)
    local baseDuration = target.baseDuration or 0
    local workRate = worker.workRate or 1
    if workRate <= 0 then
        workRate = 1
    end

    local duration = baseDuration / workRate
    if worker.role == "dev" then
        duration = duration + ((techDebtCount or 0) * 2)
    end

    if duration <= 0 then
        duration = 0.01
    end

    return duration
end

function WorkSystem:sync(workCandidates, cardsByUid, recipeLookupById, techDebtCount)
    local desiredJobs = {}

    for _, candidate in ipairs(workCandidates or {}) do
        local targetCard = cardsByUid[candidate.targetUid]
        local workerCard = cardsByUid[candidate.workerUid]
        local recipe = recipeLookupById[candidate.recipeId]

        if targetCard and workerCard and recipe and not targetCard.locked and not workerCard.locked then
            desiredJobs[makeJobKey(candidate)] = {
                targetUid = candidate.targetUid,
                workerUid = candidate.workerUid,
                stackId = candidate.stackId,
                recipeId = candidate.recipeId,
                softwareUids = candidate.softwareUids,
                memberUids = candidate.memberUids,
            }
        end
    end

    for key, existingJob in pairs(self.activeJobs) do
        local desired = desiredJobs[key]
        if not desired
            or desired.workerUid ~= existingJob.workerUid
            or desired.stackId ~= existingJob.stackId
        then
            local targetCard = cardsByUid[existingJob.targetUid]
            clearCardProgress(targetCard)
            self.activeJobs[key] = nil
        end
    end

    for key, desired in pairs(desiredJobs) do
        if not self.activeJobs[key] then
            local targetCard = cardsByUid[desired.targetUid]
            local workerCard = cardsByUid[desired.workerUid]
            local duration = computeDuration(workerCard, targetCard, techDebtCount)

            self.activeJobs[key] = {
                targetUid = desired.targetUid,
                workerUid = desired.workerUid,
                stackId = desired.stackId,
                recipeId = desired.recipeId,
                softwareUids = desired.softwareUids,
                memberUids = desired.memberUids,
                elapsed = 0,
                duration = duration,
            }

            targetCard.recipeActive = true
            targetCard.recipeElapsed = 0
            targetCard.recipeDuration = duration
            targetCard.recipePartnerId = workerCard.uid
            targetCard.activeProgress = 0
        end
    end
end

function WorkSystem:update(simDt, cardsByUid)
    local completions = {}
    if simDt <= 0 then
        return completions
    end

    for key, job in pairs(self.activeJobs) do
        local targetCard = cardsByUid[job.targetUid]
        local workerCard = cardsByUid[job.workerUid]

        if not targetCard or not workerCard then
            self.activeJobs[key] = nil
        else
            job.elapsed = job.elapsed + simDt

            local progress = clamp(job.elapsed / job.duration, 0, 1)
            targetCard.activeProgress = progress
            targetCard.recipeElapsed = job.elapsed
            targetCard.recipeDuration = job.duration
            targetCard.recipePartnerId = workerCard.uid

            if progress >= 1 then
                table.insert(completions, {
                    targetUid = job.targetUid,
                    workerUid = job.workerUid,
                    stackId = job.stackId,
                    recipeId = job.recipeId,
                    softwareUids = job.softwareUids,
                    memberUids = job.memberUids,
                    duration = job.duration,
                })
                self.activeJobs[key] = nil
                clearCardProgress(targetCard)
            end
        end
    end

    return completions
end

function WorkSystem:getActiveJobs()
    local jobs = {}
    for _, job in pairs(self.activeJobs) do
        table.insert(jobs, job)
    end
    return jobs
end

function WorkSystem:serialize()
    local jobs = {}
    for key, job in pairs(self.activeJobs) do
        jobs[key] = {
            targetUid = job.targetUid,
            workerUid = job.workerUid,
            stackId = job.stackId,
            recipeId = job.recipeId,
            softwareUids = job.softwareUids,
            memberUids = job.memberUids,
            elapsed = job.elapsed,
            duration = job.duration,
        }
    end
    return {
        activeJobs = jobs,
    }
end

function WorkSystem:deserialize(snapshot)
    self.activeJobs = {}
    if type(snapshot) ~= "table" or type(snapshot.activeJobs) ~= "table" then
        return
    end

    for key, job in pairs(snapshot.activeJobs) do
        self.activeJobs[key] = {
            targetUid = job.targetUid,
            workerUid = job.workerUid,
            stackId = job.stackId,
            recipeId = job.recipeId,
            softwareUids = job.softwareUids,
            memberUids = job.memberUids,
            elapsed = job.elapsed or 0,
            duration = job.duration or 1,
        }
    end
end

return WorkSystem
