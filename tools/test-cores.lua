-- MD Mayhem - offline harness for runtime wiring and mutation cores.
-- Usage: lua tools/test-cores.lua [path-to-EDOPro]

local function game_path()
	if arg[1] then return arg[1] end
	local file = io.open(".game-path", "r")
	if file then
		local remembered = (file:read("l") or ""):gsub("%s+$", "")
		file:close()
		if remembered ~= "" then return (remembered:gsub("\\", "/")) end
	end
	error("No EDOPro folder known. Run tools/install.ps1 once, or pass it explicitly")
end

local GAME_PATH = game_path()
local GENERATED = "install/generated/"
local recorder

local function source_path(name)
	local core = name:match("^mayhem_core_(.+)$")
	if core then return "src/cores/" .. core end
	return "src/runtime/" .. name
end

local function reset()
	recorder = {
		effects = {}, flags = {}, calls = {}, loaded = {}, lp = { 8000, 8000 },
		hand = { 5, 5 }, draw = { 1, 1 }, turn_player = 0, matching_count = 0,
		matching_groups = {},
		field_groups = {},
		deck_counts = { 40, 40 },
	}
end

local function record(name, ...)
	local call = { name = name, args = { ... } }
	table.insert(recorder.calls, call)
	return call
end

local function group(count, cards)
	local g = { _count = count or 0, _cards = cards or {}, _cursor = 0 }
	setmetatable(g, { __len = function(self) return self._count end })
	function g:GetCount() return self._count end
	function g:GetFirst() self._cursor = 1 return self._cards[1] end
	function g:GetNext() self._cursor = self._cursor + 1 return self._cards[self._cursor] end
	function g:IsExists(filter, minimum, except, ...)
		local found = 0
		for _, card in ipairs(self._cards) do
			if card ~= except and filter(card, ...) then found = found + 1 end
		end
		return found >= minimum
	end
	function g:Filter(filter, except, ...)
		local cards = {}
		for _, card in ipairs(self._cards) do
			if card ~= except and filter(card, ...) then table.insert(cards, card) end
		end
		return group(#cards, cards)
	end
	function g:GetMinGroup(value)
		local minimum, cards
		for _, card in ipairs(self._cards) do
			local current = value(card)
			if minimum == nil or current < minimum then minimum, cards = current, { card }
			elseif current == minimum then table.insert(cards, card) end
		end
		return group(cards and #cards or 0, cards or {}), minimum
	end
	function g:GetMaxGroup(value)
		local maximum, cards
		for _, card in ipairs(self._cards) do
			local current = value(card)
			if maximum == nil or current > maximum then maximum, cards = current, { card }
			elseif current == maximum then table.insert(cards, card) end
		end
		return group(cards and #cards or 0, cards or {}), maximum
	end
	function g:Select(_, minimum) return group(math.min(minimum, self._count), self._cards) end
	function g:DeleteGroup() end
	return g
end

local function new_effect()
	local effect = { target_range = {}, type = 0, label = 0 }
	function effect:SetType(value) self.type = value end
	function effect:SetCode(value) self.code = value end
	function effect:SetValue(value) self.value = value end
	function effect:SetProperty(value) self.property = value end
	function effect:SetCountLimit(value) self.count_limit = value end
	function effect:SetOperation(value) self.operation = value end
	function effect:SetCondition(value) self.condition = value end
	function effect:SetTarget(value) self.target = value end
	function effect:SetCost(value) self.cost = value end
	function effect:SetCategory(value) self.category = value end
	function effect:SetRange(value) self.range = value end
	function effect:SetReset(value, count) self.reset, self.reset_count = value, count end
	function effect:SetLabel(value) self.label = value end
	function effect:GetLabel() return self.label end
	-- Duel.RegisterEffect marks a global effect EFFECT_FLAG_FIELD_ONLY, so
	-- Effect.Reset removes it from the field again.
	function effect:Reset() self.was_reset = true end
	function effect:SetTargetRange(a, b) self.target_range = { a, b } end
	return effect
end

Effect = { GlobalEffect = new_effect, CreateEffect = new_effect }
Card = setmetatable({}, { __index = function(_, name)
	return function(card, ...) return card[name](card, ...) end
end })

Debug = {
	Message = function(...) record("Debug.Message", ...) end,
	ShowHint = function(...) record("Debug.ShowHint", ...) end,
	SetPlayerInfo = function(player, lp, hand, draw)
		record("Debug.SetPlayerInfo", player, lp, hand, draw)
		recorder.lp[player + 1], recorder.hand[player + 1], recorder.draw[player + 1] = lp, hand, draw
	end,
}

Duel = {
	RegisterEffect = function(effect, player)
		effect.registered_player = player
		table.insert(recorder.effects, effect)
	end,
	EnableGlobalFlag = function(flag) recorder.flags[flag] = true end,
	SetLP = function(player, lp) record("Duel.SetLP", player, lp) recorder.lp[player + 1] = lp end,
	GetLP = function(player) return recorder.lp[(player or 0) + 1] end,
	GetStartingHand = function(player) return recorder.hand[(player or 0) + 1] end,
	GetDrawCount = function(player) return recorder.draw[(player or 0) + 1] end,
	GetTurnPlayer = function() return recorder.turn_player end,
	GetAttacker = function() return recorder.attacker end,
	GetAttackTarget = function() return recorder.attack_target end,
	GetTurnCount = function() return recorder.turn_count or 1 end,
	GetChainInfo = function() return nil, recorder.chain_player or 0 end,
	IsPhase = function(phase) return recorder.phase == phase end,
	GetDecktopGroup = function(player, count) record("Duel.GetDecktopGroup", player, count) return group(count) end,
	GetMatchingGroupCount = function(...) record("Duel.GetMatchingGroupCount", ...) return recorder.matching_count end,
	GetMatchingGroup = function(filter, player, location, other, except, ...)
		record("Duel.GetMatchingGroup", filter, player, location, other, except, ...)
		return recorder.matching_groups[player + 1] or group(0)
	end,
	GetFieldGroup = function(player, location, other)
		record("Duel.GetFieldGroup", player, location, other)
		return recorder.field_groups[player + 1] or group(0)
	end,
	GetFieldGroupCount = function(player, location, other)
		if location == LOCATION_DECK and other == 0 then return recorder.deck_counts[player + 1] end
		return (recorder.field_groups[player + 1] or group(0)):GetCount()
	end,
	GetLocationCount = function() return 1 end,
	IsExistingMatchingCard = function() return false end,
	IsPlayerCanDraw = function() return true end,
	SelectMatchingCard = function(player, filter, owner, location, other, minimum, maximum, except)
		record("Duel.SelectMatchingCard", player, filter, owner, location, other, minimum, maximum, except)
		return group(maximum)
	end,
	SendtoHand = function(cards, player, reason) record("Duel.SendtoHand", cards, player, reason) return cards:GetCount() end,
	ConfirmCards = function(...) record("Duel.ConfirmCards", ...) end,
	ShuffleHand = function(...) record("Duel.ShuffleHand", ...) end,
	Hint = function(...) record("Duel.Hint", ...) end,
	Recover = function(...) record("Duel.Recover", ...) return select(2, ...) end,
	Damage = function(...) record("Duel.Damage", ...) return select(2, ...) end,
	Draw = function(...) record("Duel.Draw", ...) return select(2, ...) end,
	Win = function(...) record("Duel.Win", ...) end,
	Destroy = function(...) record("Duel.Destroy", ...) return 1 end,
	SendtoGrave = function(...) record("Duel.SendtoGrave", ...) return 1 end,
	SendtoDeck = function(...) record("Duel.SendtoDeck", ...) return 1 end,
	Remove = function(...) record("Duel.Remove", ...) return 1 end,
	SpecialSummon = function(...) record("Duel.SpecialSummon", ...) return 1 end,
	ShuffleDeck = function(...) record("Duel.ShuffleDeck", ...) end,
	NegateActivation = function(...) record("Duel.NegateActivation", ...) return true end,
	NegateEffect = function(...) record("Duel.NegateEffect", ...) return true end,
	SSet = function(...) record("Duel.SSet", ...) return 1 end,
	TossDice = function(...) record("Duel.TossDice", ...) return 3 end,
	SelectYesNo = function(...) record("Duel.SelectYesNo", ...) return true end,
	CalculateDamage = function(...) record("Duel.CalculateDamage", ...) end,
	IsDuelType = function() return false end,
}

function Duel.LoadScript(name)
	if recorder.loaded[name] then return true end
	recorder.loaded[name] = true
	for _, path in ipairs({ source_path(name), GENERATED .. name, GAME_PATH .. "/script/" .. name }) do
		local chunk = loadfile(path)
		if chunk then chunk() return true end
	end
	return false
end

local function effects_with(code)
	local found = {}
	for _, effect in ipairs(recorder.effects) do
		if effect.code == code then table.insert(found, effect) end
	end
	return found
end

local function effect_with(code)
	return effects_with(code)[1]
end

local function calls(name)
	local found = {}
	for _, call in ipairs(recorder.calls) do
		if call.name == name then table.insert(found, call) end
	end
	return found
end

local function called(name) return calls(name)[1] end

local function fire_all(code, ...)
	for _, effect in ipairs(effects_with(code)) do
		if effect.operation then effect.operation(effect, ...) end
	end
end

local function run(config, starting_lp)
	reset()
	recorder.lp = { starting_lp or 8000, starting_lp or 8000 }
	MAYHEM, MAYHEM_CONFIG = nil, nil
	assert(Duel.LoadScript("constant.lua"), "constant.lua not found in " .. GAME_PATH)
	recorder.loaded["mayhem_config.lua"] = true
	MAYHEM_CONFIG = config
	assert(Duel.LoadScript("mayhem_bootstrap.lua"), "bootstrap not found")
end

run({ enabled = {} })
local CODE_BASE = MAYHEM_LP_CODE_BASE
local DEFAULT_LP = MAYHEM_DEFAULT_LP
local tests = {}

tests["plan ahead starts empty and skips every draw phase"] = function()
	run({ enabled = { "20_plan_ahead_of_time" } })
	local skip = effect_with(EFFECT_SKIP_DP)
	assert(skip and skip.target_range[1] == 1 and skip.target_range[2] == 1, "Draw Phase not skipped for both players")
	fire_all(EVENT_STARTUP, 0)
	assert(recorder.hand[1] == 0 and recorder.hand[2] == 0, "opening hands were not set to zero")
end

tests["plan ahead adds exactly two cards for each player at standby"] = function()
	run({ enabled = { "20_plan_ahead_of_time" } })
	recorder.matching_count = 8
	fire_all(EVENT_PHASE + PHASE_STANDBY, 0)
	local selected, moved = calls("Duel.SelectMatchingCard"), calls("Duel.SendtoHand")
	assert(#selected == 2 and #moved == 2, "both players must tutor")
	assert(selected[1].args[6] == 2 and selected[1].args[7] == 2, "tutor must select exactly two")
	assert(#calls("Duel.ConfirmCards") == 2 and #calls("Duel.ShuffleHand") == 2, "tutored cards not revealed/shuffled")
end

tests["only the strong destroys one lowest-ATK monster on each field"] = function()
	local function monster(attack)
		return { IsFaceup = function() return true end, GetAttack = function() return attack end }
	end
	run({ enabled = { "21_only_the_strong_survive" } })
	recorder.matching_groups = {
		group(3, { monster(1000), monster(1000), monster(2500) }),
		group(2, { monster(500), monster(2000) }),
	}
	fire_all(EVENT_PHASE + PHASE_END, 0)
	local destroyed = calls("Duel.Destroy")
	assert(#destroyed == 2, "each field must lose one monster")
	assert(destroyed[1].args[1]:GetCount() == 1 and destroyed[2].args[1]:GetCount() == 1,
		"a tie must still destroy exactly one monster")
end

tests["raw force blocks both monster and Spell Trap setting"] = function()
	run({ enabled = { "22_raw_force_no_strategy" } })
	local monster, backrow = effect_with(EFFECT_CANNOT_MSET), effect_with(EFFECT_CANNOT_SSET)
	assert(monster and backrow, "both Set restrictions are required")
	assert(monster.property == EFFECT_FLAG_PLAYER_TARGET and backrow.property == EFFECT_FLAG_PLAYER_TARGET,
		"Set restrictions must target both players")
end

tests["stop hitting me locks the attacker after the first attack"] = function()
	run({ enabled = { "23_stop_hitting_me" } })
	recorder.attacker = { GetControler = function() return 1 end }
	fire_all(EVENT_ATTACK_ANNOUNCE, 0)
	local locks = effects_with(EFFECT_CANNOT_ATTACK_ANNOUNCE)
	assert(#locks == 1 and locks[1].registered_player == 1, "attacking player was not locked")
	assert(locks[1].target_range[1] == LOCATION_MZONE and locks[1].target_range[2] == 0,
		"lock must affect monsters of only that player")
	assert(locks[1].target(locks[1], recorder.attacker) == false,
		"the first attacker must retain any additional attacks")
end

tests["it should have been mine mills before the draw"] = function()
	run({ enabled = { "24_it_should_have_been_mine" } })
	recorder.turn_player = 1
	fire_all(EVENT_PREDRAW, 0)
	local mill = called("Duel.SendtoGrave")
	assert(mill and mill.args[1]:GetCount() == 1 and mill.args[2] == REASON_RULE, "top card was not milled by rule")
end

tests["this sound familiar rejects duplicate Main Deck names"] = function()
	local function card(code) return { GetOriginalCode = function() return code end } end
	run({ enabled = { "25_this_sound_familiar" } })
	recorder.field_groups = {
		group(3, { card(1), card(2), card(1) }),
		group(2, { card(3), card(4) }),
	}
	fire_all(EVENT_STARTUP, 0)
	local win = called("Duel.Win")
	assert(win and win.args[1] == 1, "opponent must win against the duplicate deck")
end

tests["there can be only one kind remembers used Extra Deck types"] = function()
	local card = {
		IsType = function(_, value) return value == TYPE_LINK end,
		IsLocation = function(_, value) return value == LOCATION_EXTRA end,
		IsSummonLocation = function(_, value) return value == LOCATION_EXTRA end,
		GetControler = function() return 0 end,
		GetSummonPlayer = function() return 0 end,
	}
	run({ enabled = { "26_there_can_be_only_one_kind" } })
	local lock = effect_with(EFFECT_CANNOT_SPECIAL_SUMMON)
	-- The engine reads summon bans through the target callback and treats a
	-- missing one as a blanket ban, so the predicate must not sit on the value.
	assert(lock and lock.target and lock.value == nil,
		"summon ban must carry its predicate as a target")
	assert(lock.property == EFFECT_FLAG_PLAYER_TARGET, "summon ban must target players")
	assert(lock.target(lock, card, 0) == false, "unused summon type should be legal")
	local summoned = effect_with(EVENT_SPSUMMON_SUCCESS)
	summoned.operation(summoned, 0, group(1, { card }))
	assert(lock.target(lock, card, 0) == true, "used summon type was not blocked")
end

tests["keep drawing refills both hands to five"] = function()
	run({ enabled = { "27_keep_drawing" } })
	recorder.field_groups = { group(2), group(4) }
	recorder.deck_counts = { 2, 40 }
	fire_all(EVENT_PHASE + PHASE_END, 0)
	local draws = calls("Duel.Draw")
	assert(#draws == 2 and draws[1].args[2] == 2 and draws[2].args[2] == 1,
		"refill must clamp to the cards available in Deck")
end

tests["strength and efficiency install their field rules"] = function()
	run({ enabled = { "29_strength_of_the_weak", "30_be_more_efficient" } })
	assert(effect_with(EFFECT_IMMUNE_EFFECT), "weakest-monster immunity missing")
	assert(effect_with(EFFECT_MAX_MZONE).value == 3, "monster zone cap missing")
	assert(effect_with(EFFECT_MAX_SZONE).value == 3, "Spell Trap zone cap missing")
end

tests["leaking vrain registers a startup summon"] = function()
	run({ enabled = { "28_leaking_vrain" } })
	assert(effect_with(EVENT_STARTUP), "startup Link summon missing")
end

tests["droll limit locks the hand and draws only after five cards"] = function()
	local function added_card(player)
		return {
			GetControler = function() return player end,
			IsLocation = function(_, value) return value == LOCATION_HAND end,
			IsReason = function() return false end,
		}
	end
	run({ enabled = { "31_droll_lock_limit" } })
	local to_hand = effect_with(EFFECT_CANNOT_TO_HAND)
	assert(to_hand and to_hand.target, "hand quota lock missing")
	assert(to_hand.target(to_hand, added_card(0)) == false, "an empty quota must let cards through")
	-- EFFECT_CANNOT_DRAW is presence-only in the engine, so it may exist only
	-- while the quota is actually spent.
	assert(effect_with(EFFECT_CANNOT_DRAW) == nil, "draw lock must not exist before the quota runs out")
	for _ = 1, 5 do fire_all(EVENT_TO_HAND, 0, group(1, { added_card(0) })) end
	local lock = effect_with(EFFECT_CANNOT_DRAW)
	assert(lock and lock.registered_player == 0 and lock.target_range[1] == 1 and lock.target_range[2] == 0,
		"a spent quota must lock only that player's draws")
	assert(to_hand.target(to_hand, added_card(0)) == true, "a spent quota must block further cards")
	assert(to_hand.target(to_hand, added_card(1)) == false, "the quota is per player")
	fire_all(EVENT_PHASE_START + PHASE_DRAW, 0)
	assert(lock.was_reset, "the draw lock must be removed when the quota resets")
	assert(to_hand.target(to_hand, added_card(0)) == false, "the quota did not reset")
end

tests["quick LP recycling wand and first-turn rules register"] = function()
	run({ enabled = { "32_you_have_to_be_quick", "33_recycling", "34_verres_wand_silver", "35_first_turn_advantage_silver" } })
	assert(effect_with(EVENT_PRE_DAMAGE_CALCULATE), "Verre battle hook missing")
	assert(effect_with(EFFECT_CANNOT_INACTIVATE) and effect_with(EFFECT_CANNOT_DISEFFECT), "first-turn protection missing")
	local first_draw = effect_with(EFFECT_DRAW_COUNT)
	assert(first_draw and first_draw.value == 1 and first_draw.reset == RESET_PHASE + PHASE_DRAW,
		"first Draw Phase must be fixed at one card, then expire")
	fire_all(EVENT_STARTUP, 0)
	assert(recorder.lp[1] == 10000 and recorder.lp[2] == 10000, "starting LP not 10000")
end

tests["once victory and trash hooks register"] = function()
	run({ enabled = { "36_you_can_only_use_once", "37_create_your_own_victory", "38_this_card_is_trash" } })
	assert(effect_with(EVENT_CHAIN_SOLVED), "copy banish hook missing")
	assert(effect_with(EVENT_ADJUST), "alternate victory hook missing")
	local chain = effect_with(EVENT_CHAINING)
	assert(chain, "first activation hook missing")
	chain.operation(chain, 0, nil, 0, 1, nil, 0, 0)
	assert(called("Duel.NegateActivation"), "first activation was not negated")
end

tests["mirror and titan register summon and End Phase hooks"] = function()
	run({ enabled = { "39_mirror_mirror_on_the_wall", "40_clash_of_the_titan" } })
	assert(effect_with(EVENT_SUMMON_SUCCESS) and effect_with(EVENT_FLIP_SUMMON_SUCCESS), "mirror summon hooks missing")
	assert(#effects_with(EVENT_SPSUMMON_SUCCESS) >= 1, "mirror Special Summon hook missing")
	assert(effect_with(EVENT_PHASE + PHASE_END), "Titan End Phase hook missing")
end

tests["arrival pain set gambling and mulligan hooks register"] = function()
	run({ enabled = { "41_unexpected_arrival", "42_shared_pain", "43_what_is_it_gonna_be", "44_restricted_gambling", "45_literally_just_mulligan" } })
	assert(effect_with(EFFECT_DRAW_COUNT).value == 0, "Unexpected Arrival did not replace the draw")
	assert(effect_with(EVENT_DAMAGE), "Shared Pain hook missing")
	assert(effect_with(EFFECT_CANNOT_ACTIVATE), "gambling activation quota missing")
	assert(effect_with(EFFECT_CANNOT_SUMMON) and effect_with(EFFECT_CANNOT_FLIP_SUMMON), "gambling summon quota missing")
	assert(effect_with(EFFECT_CANNOT_ACTIVATE).property == EFFECT_FLAG_PLAYER_TARGET,
		"activation quota must target players")
	assert(effect_with(EFFECT_CANNOT_SPECIAL_SUMMON).property == EFFECT_FLAG_PLAYER_TARGET,
		"Special Summon quota must target players")
	-- Activation bans are evaluated as a value, summon bans as a target. Putting
	-- a predicate on the wrong one silently bans the action for the whole duel.
	assert(effect_with(EFFECT_CANNOT_ACTIVATE).value and not effect_with(EFFECT_CANNOT_ACTIVATE).target,
		"activation quota belongs on the value")
	for _, code in ipairs({ EFFECT_CANNOT_SUMMON, EFFECT_CANNOT_FLIP_SUMMON, EFFECT_CANNOT_SPECIAL_SUMMON }) do
		local ban = effect_with(code)
		assert(ban.target and ban.value == nil, "summon quota belongs on the target")
	end
end

tests["restricted gambling only locks summons once the roll is used up"] = function()
	local function monster(player)
		return { GetSummonPlayer = function() return player end }
	end
	run({ enabled = { "44_restricted_gambling" } })
	fire_all(EVENT_PHASE_START + PHASE_DRAW, 0) -- TossDice stub rolls 3
	local ban = effect_with(EFFECT_CANNOT_SPECIAL_SUMMON)
	assert(ban.target(ban, monster(0), 0) == false, "the first summon must be allowed")
	for _ = 1, 3 do fire_all(EVENT_SUMMON_SUCCESS, 0, group(1, { monster(0) })) end
	assert(ban.target(ban, monster(0), 0) == true, "the fourth summon must be blocked")
	assert(ban.target(ban, monster(1), 1) == false, "the quota is per player")
end

tests["punch grave gift RPS and comeback hooks register"] = function()
	run({ enabled = { "46_once_punch", "47_back_from_the_grave", "48_gift_from_your_enemy", "49_rock_paper_scissors", "50_yugih5_comeback" } })
	assert(effect_with(EVENT_PHASE_START + PHASE_BATTLE), "Battle Phase reset missing")
	assert(#effects_with(EFFECT_IMMUNE_EFFECT) == 3, "RPS needs three immunity rules")
	assert(effect_with(EFFECT_SKIP_BP), "Comeback must remove the normal Battle Phase")
end

tests["final seven cores install their contracts"] = function()
	run({ enabled = { "51_quick_play_owner_turn", "52_speed_duel_mentioned", "53_boss_is_always_boss", "54_break_the_loop", "55_gambling_draw", "56_energy_dominate", "57_magic_consume_silver" } })
	assert(#effects_with(EFFECT_ACTIVATE_COST) == 2, "energy and magic activation costs missing")
	assert(effect_with(EFFECT_SPSUMMON_COST), "energy Special Summon cost missing")
	assert(effect_with(EFFECT_SKIP_BP) == nil, "unrelated Battle Phase rule leaked")
	fire_all(EVENT_STARTUP, 0)
	assert(#calls("Debug.Message") >= 3, "energy and Speed Duel announcements missing")
end

tests["energy starts at twelve spends two or four and refreshes the turn player"] = function()
	run({ enabled = { "56_energy_dominate" } })
	local activation = effect_with(EFFECT_ACTIVATE_COST)
	local summon = effect_with(EFFECT_SPSUMMON_COST)
	local function card(types)
		return { IsType = function(_, mask) return (types & mask) ~= 0 end }
	end
	local function activating(types, effect_types)
		local handler = card(types)
		return {
			GetHandler = function() return handler end,
			IsHasType = function(_, mask) return (effect_types & mask) ~= 0 end,
		}
	end

	fire_all(EVENT_STARTUP, 0)
	local normal = activating(TYPE_SPELL, EFFECT_TYPE_ACTIVATE)
	assert(activation.target(activation, normal), "normal Spell must spend energy")
	assert(activation.cost(activation, normal, 0), "player should afford a 2-energy Spell")
	activation.operation(activation, 0)
	assert(calls("Debug.Message")[3].args[1]:find("10/12", 1, true), "normal activation must leave 10")

	local quick = activating(TYPE_MONSTER, EFFECT_TYPE_QUICK_O)
	assert(activation.cost(activation, quick, 0), "player should afford a 4-energy Quick Effect")
	activation.operation(activation, 0)
	assert(calls("Debug.Message")[4].args[1]:find("6/12", 1, true), "Quick Effect must leave 6")

	recorder.turn_player = 0
	fire_all(EVENT_PHASE_START + PHASE_STANDBY, 0)
	assert(calls("Debug.Message")[5].args[1]:find("12/12", 1, true), "own Standby must refill to 12")
	local monster = card(TYPE_MONSTER)
	monster.GetSummonPlayer = function() return 0 end
	assert(summon.cost(summon, monster, 0), "player should afford a Special Summon")
	summon.operation(summon, 0)
	summon.operation(summon, 0)
	assert(calls("Debug.Message")[6].args[1]:find("10/12", 1, true),
		"a simultaneous Special Summon must spend exactly two once")
	fire_all(EVENT_SPSUMMON_SUCCESS, 0, group(1, { monster }))
	summon.operation(summon, 0)
	assert(calls("Debug.Message")[7].args[1]:find("8/12", 1, true),
		"the next Special Summon action must spend again")
	fire_all(EVENT_SPSUMMON_NEGATED, 0, group(1, { monster }))
	summon.operation(summon, 0)
	assert(calls("Debug.Message")[8].args[1]:find("6/12", 1, true),
		"a negated summon must release the group guard for the next action")
end

tests["catalogue code 20 applies Plan Ahead of Time"] = function()
	run({ enabled = {} }, CODE_BASE + 20)
	assert(MAYHEM.active[1] == "20_plan_ahead_of_time", "code 20 did not load its core")
	assert(effect_with(EFFECT_SKIP_DP), "catalogue params were not applied")
end

tests["legacy config core ids map to numbered filenames"] = function()
	run({ enabled = { "energy_dominate" } })
	assert(MAYHEM.active[1] == "56_energy_dominate", "legacy config id was not aliased")
	assert(effect_with(EFFECT_SPSUMMON_COST), "aliased Energy core did not load")
end

tests["encoded and unknown codes always restore sane LP"] = function()
	run({ enabled = {} }, CODE_BASE + 20)
	assert(recorder.lp[1] == DEFAULT_LP and recorder.lp[2] == DEFAULT_LP, "valid code leaked into LP")
	run({ enabled = {} }, CODE_BASE + 9999)
	assert(recorder.lp[1] == DEFAULT_LP and recorder.lp[2] == DEFAULT_LP, "unknown code leaked into LP")
	assert(#MAYHEM.active == 0, "unknown code activated a core")
end

tests["normal Starting LP remains untouched"] = function()
	run({ enabled = {} }, 8000)
	assert(called("Debug.SetPlayerInfo") == nil, "normal duel state was modified")
	assert(#MAYHEM.active == 0, "normal duel activated a core")
end

local names = {}
for name in pairs(tests) do table.insert(names, name) end
table.sort(names)

local failed = 0
for _, name in ipairs(names) do
	local ok, err = pcall(tests[name])
	if ok then print("PASS  " .. name)
	else failed = failed + 1 print("FAIL  " .. name .. "\n      " .. tostring(err)) end
end
print(string.format("\n%d passed, %d failed", #names - failed, failed))
os.exit(failed == 0 and 0 or 1)
