-- Focused regressions for the zone cap and owner-aware hand quota.
local path = arg[1]
if not path then
	local file = assert(io.open('.game-path'))
	path = file:read('l'):gsub('%s+$', '')
	file:close()
end
Duel = { LoadScript = function() end }
dofile(path .. '/script/constant.lua')
local registered, definitions = {}, {}
Effect = { GlobalEffect = function()
	return setmetatable({}, { __index = function(_, key)
		if key == 'Reset' then return function(e) e.reset = true end end
		return function(e, ...) e[key] = {...} end
	end })
end }
Duel = { RegisterEffect = function(e) registered[e.SetCode[1]] = e end }
MAYHEM = { Register = function(id, def) definitions[id] = def end }
dofile('src/runtime/mayhem_engine.lua')
local function apply(id)
	registered = {}
	dofile('src/cores/' .. id .. '.lua')
	definitions[id].apply(definitions[id].defaults)
end
local counts, fields = {3, 0}, {}
Duel.GetFieldCard = function(p) return fields[p+1] end
Duel.GetFieldGroupCount = function(p) return counts[p+1] end
apply('30_be_more_efficient')
local field = { IsType = function(_, t) return t == TYPE_FIELD end }
local normal = { IsType = function() return false end }
local function activation(card, activating)
	return { GetHandler = function() return card end, IsHasType = function() return activating end }
end
local cap = registered[EFFECT_MAX_SZONE].SetValue[1]
local activate = registered[EFFECT_CANNOT_ACTIVATE].SetValue[1]
local set = registered[EFFECT_CANNOT_SSET].SetTarget[1]
assert(cap(nil, 0) == 3)
assert(activate(nil, activation(field, true), 0) and set(nil, field, 0))
assert(not activate(nil, activation(field, false), 0), 'must allow existing field effects')
assert(not set(nil, normal, 0), 'ordinary slots use MAX_SZONE')
assert(not set(nil, field, 1), 'opponent has independent capacity')
fields[1], counts[1] = field, 3
assert(cap(nil, 0) == 2, 'field consumes one of three slots')
assert(not activate(nil, activation(field, true), 0) and not set(nil, field, 0), 'allow replacement/flip')
fields[1], counts[1] = nil, 2
assert(not set(nil, field, 0), 'allow third S/T as field')
local adjust = registered[EVENT_ADJUST].SetOperation[1]
local removed = 0
Duel.Hint = function() end
Duel.GetFieldGroup = function(p)
	return { Select = function(_, chooser, minimum, maximum)
		assert(chooser == p and minimum == maximum)
		return { player = p, count = minimum }
	end }
end
Duel.SendtoGrave = function(g, reason)
	assert(reason == REASON_RULE)
	adjust() -- nested adjust must not recurse into another selection
	counts[g.player+1] = counts[g.player+1] - g.count
	removed = removed + g.count
end
counts = {4, 5}
adjust()
assert(counts[1] == 3 and counts[2] == 3 and removed == 3)
adjust()
assert(removed == 3, 'no cleanup at legal capacity')
print('PASS core30 field capacity, replacement, independent players, overflow and reentrancy')

apply('31_droll_lock_limit')
Duel.IsPhase = function() return false end
local function card(owner, controller)
	return { GetOwner = function() return owner end, GetControler = function() return controller end,
		IsLocation = function(_, loc) return loc == LOCATION_HAND end, IsReason = function() return false end }
end
local arrival = { GetFirst = function() return card(0, 0) end, GetNext = function() end }
for i = 1, 5 do registered[EVENT_TO_HAND].SetOperation[1](nil, 0, arrival) end
local blocked = registered[EFFECT_CANNOT_TO_HAND].SetTarget[1]
assert(blocked(nil, card(0, 1)), 'stolen monster must use exhausted owner quota')
assert(not blocked(nil, card(1, 0)), 'exhausted controller must not block other owner')
registered[EVENT_PHASE_START + PHASE_DRAW].SetOperation[1]()
assert(not blocked(nil, card(0, 1)), 'quota resets next turn')
print('PASS core31 stolen-card owner quota and next-turn reset')
