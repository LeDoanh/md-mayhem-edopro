-- Focused behavior regressions; run from repository root with lua.
local file = assert(io.open(".game-path"))
local game = (file:read("l")):gsub("%s+$", ""):gsub("\\", "/")
file:close()
Duel = { LoadScript = function() end }
dofile(game .. "/script/constant.lua")
local events, phases, rules, summons = {}, {}, {}, {}
local attacker
local function effect()
    return setmetatable({}, { __index = function(_, key)
        return function(self, value) self[key:sub(4):lower()] = value end
    end })
end
Effect = { CreateEffect = effect, GlobalEffect = effect }
local function card(attack, player)
    return {
        effects = {}, GetAttack = function() return attack end,
        GetControler = function() return player end,
        RegisterEffect = function(self, e) table.insert(self.effects, e) end,
    }
end
MAYHEM = {
    Register = function(_, definition) definition.apply() end,
    OnEvent = function(code, operation) events[code] = operation end,
    OnPhase = function(code, operation) phases[code] = operation end,
}
Duel = {
    GetAttacker = function() return attacker end,
    RegisterEffect = function(e) table.insert(rules, e) end,
    LoadScript = function() MAYHEM_TOKEN_CODE = 1 end,
    GetLocationCount = function() return 5 end,
    CreateToken = function(player) return card(0, player) end,
    SpecialSummon = function(token) table.insert(summons, token) end,
}
local function summon(monster)
    events[EVENT_SPSUMMON_SUCCESS](nil, 0, {
        GetFirst = function() return monster end, GetNext = function() end,
    })
end
dofile("src/cores/39_mirror_mirror_on_the_wall.lua")
local sheep = card(0, 0)
sheep.IsType = function(_, kind) return kind == TYPE_TOKEN end
summon(sheep)
assert(#summons == 1, "an external Token must be mirrored")
summon(summons[1])
assert(#summons == 1, "Mirror's Token must not recurse")
local monster = card(1800, 1)
summon(monster)
assert(#summons == 2 and summons[2].effects[1].value == 1800)

dofile("src/cores/46_once_punch.lua")
attacker = card(2000, 0)
phases[PHASE_BATTLE_START]()
events[EVENT_ATTACK_ANNOUNCE]()
assert(#attacker.effects == 0, "ATK must stay unchanged before Damage Step")
-- Negate first attack, then attack again with the same monster.
events[EVENT_ATTACK_ANNOUNCE]()
events[EVENT_BATTLE_START]()
assert(#attacker.effects == 0, "a negated first attack must not leak a boost")
phases[PHASE_BATTLE_START]()
events[EVENT_ATTACK_ANNOUNCE]()
events[EVENT_BATTLE_START]()
assert(#attacker.effects == 1 and attacker.effects[1].value == 2000)
assert(attacker.effects[1].reset & PHASE_DAMAGE ~= 0)
events[EVENT_ATTACK_ANNOUNCE]()
events[EVENT_BATTLE_START]()
assert(#attacker.effects == 1, "only the first attack receives a boost")

dofile("src/cores/53_boss_is_always_boss.lua")
local immune = rules[#rules].value
assert(not immune(nil, { GetOwner = function() return monster end }, monster),
    "the protected monster must retain its own effects")
assert(immune(nil, { GetOwner = function() return sheep end }, monster),
    "other cards' effects must be ignored")
print("PASS combat regressions: Mirror tokens, Once Punch timing, Boss immunity")
