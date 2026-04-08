local GameStateSystem = require("src.game.systems.game_state_system")
local TimeSystem = require("src.game.systems.time_system")
local StackEvalSystem = require("src.game.systems.stack_eval_system")
local WorkSystem = require("src.game.systems.work_system")
local EffectSystem = require("src.game.systems.effect_system")
local SprintSystem = require("src.game.systems.sprint_system")
local PaydaySystem = require("src.game.systems.payday_system")
local PackSystem = require("src.game.systems.pack_system")
local GameOverSystem = require("src.game.systems.gameover_system")

local PackDefs = require("src.game.defs.pack_defs")
local RecipeDefs = require("src.game.defs.recipe_defs")

local Constants = require("src.app.constants")
local State = require("src.app.state")

local Systems = {
    gameState = nil,
    time = nil,
    stackEval = nil,
    work = nil,
    effects = nil,
    sprint = nil,
    payday = nil,
    packs = nil,
    gameover = nil,
    recipeById = {},
}

function Systems.setup()
    Systems.gameState = GameStateSystem.new()
    Systems.time = TimeSystem.new(Systems.gameState)
    Systems.stackEval = StackEvalSystem.new()
    Systems.work = WorkSystem.new()
    Systems.effects = EffectSystem.new(math.random)
    Systems.sprint = SprintSystem.new(Constants.SPRINT_DURATION_SECONDS)
    Systems.payday = PaydaySystem.new()
    Systems.packs = PackSystem.new(PackDefs)
    Systems.gameover = GameOverSystem.new()

    Systems.recipeById = {}
    for _, recipe in ipairs(RecipeDefs.all()) do
        Systems.recipeById[recipe.id] = recipe
    end
end

function Systems.evaluateStacks()
    State.lastStackEval = Systems.stackEval:evaluate(State.cards, RecipeDefs)
    return State.lastStackEval
end

return Systems
