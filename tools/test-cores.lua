-- MD Mayhem - offline test harness for the mutation cores.
--
-- Runs the real bootstrap against stub Duel/Effect/Debug globals, so a core can
-- be checked in a second without launching EDOPro and playing a duel. The real
-- constant.lua from the installed client is loaded first, which means the tests
-- assert against the same EFFECT_/EVENT_ numbers the engine uses.
--
--   lua tools/test-cores.lua [path-to-EDOPro]

--- The client's own constant.lua is loaded so assertions use real effect
--- numbers, which means the harness needs to know where EDOPro is. Same source
--- as every other tool: whatever install.ps1 confirmed and remembered.
local function game_path()
	if arg[1] then return arg[1] end
	local file = io.open(".game-path", "r")
	if file then
		local remembered = (file:read("l") or ""):gsub("%s+$", "")
		file:close()
		if remembered ~= "" then return (remembered:gsub("\\", "/")) end
	end
	error("No EDOPro folder known. Run tools/install.ps1 once, or pass the folder "
		.. "as an argument: lua tools/test-cores.lua <path-to-EDOPro>")
end

local GAME_PATH = game_path()
local GENERATED = "install/generated/"

--- Maps an installed flat file name back to its place in the split source tree,
--- so the harness reads exactly the files install.ps1 would ship.
local function source_path(name)
	local core = name:match("^mayhem_core_(.+)$")
	if core then return "src/cores/" .. core end
	return "src/runtime/" .. name
end

-- ---------------------------------------------------------------- stub engine
local recorder

local function reset()
	recorder = { effects = {}, flags = {}, calls = {}, loaded = {}, lp = 8000 }
end

local function record(name, ...)
	table.insert(recorder.calls, { name = name, args = { ... } })
end

local function new_effect()
	local effect = { target_range = {}, type = 0 }
	function effect:SetType(value) self.type = value end
	function effect:SetCode(value) self.code = value end
	function effect:SetValue(value) self.value = value end
	function effect:SetProperty(value) self.property = value end
	function effect:SetCountLimit(value) self.count_limit = value end
	function effect:SetOperation(value) self.operation = value end
	function effect:SetTargetRange(self_range, opponent_range)
		self.target_range = { self_range, opponent_range }
	end
	return effect
end

Effect = { GlobalEffect = new_effect, CreateEffect = new_effect }

Debug = {
	Message = function(...) record("Debug.Message", ...) end,
	ShowHint = function(...) record("Debug.ShowHint", ...) end,
	-- libdebug.cpp writes player.lp and player.start_lp directly, so a later
	-- Duel.GetLP sees the new value. The stub has to do the same or it cannot
	-- catch ordering bugs between the decode and a core's own LP change.
	SetPlayerInfo = function(player, lp, hand, draw)
		record("Debug.SetPlayerInfo", player, lp, hand, draw)
		recorder.lp = lp
	end,
}

Duel = {
	RegisterEffect = function(effect) table.insert(recorder.effects, effect) end,
	EnableGlobalFlag = function(flag) recorder.flags[flag] = true end,
	SetLP = function(player, lp)
		record("Duel.SetLP", player, lp)
		recorder.lp = lp
	end,
	Recover = function(...) record("Duel.Recover", ...) end,
	Win = function(...) record("Duel.Win", ...) end,
	GetLP = function() return recorder.lp end,
	GetStartingHand = function() return 5 end,
	GetDrawCount = function() return 1 end,
	GetTurnPlayer = function() return 0 end,
	-- Overridden per test when a core inspects the field.
	GetFieldGroupCount = function() return 0 end,
}

--- Stands in for EDOPro's script reader: plugin modules first, client second.
function Duel.LoadScript(name)
	if recorder.loaded[name] then return true end
	recorder.loaded[name] = true
	for _, path in ipairs({ source_path(name), GENERATED .. name, GAME_PATH .. "/script/" .. name }) do
		local chunk = loadfile(path)
		if chunk then
			chunk()
			return true
		end
	end
	return false
end

-- ------------------------------------------------------------------ utilities
local function effect_with(code)
	for _, effect in ipairs(recorder.effects) do
		if effect.code == code then return effect end
	end
	return nil
end

local function called(name)
	for _, call in ipairs(recorder.calls) do
		if call.name == name then return call end
	end
	return nil
end

local function fire_startup()
	local effect = effect_with(EVENT_STARTUP)
	assert(effect, "no EVENT_STARTUP effect registered")
	effect.operation(effect, 0)
end

--- Loads constant.lua, then applies the given config through the real bootstrap.
local function run(config, starting_lp)
	reset()
	recorder.lp = starting_lp or 8000
	MAYHEM, MAYHEM_CONFIG = nil, nil
	assert(Duel.LoadScript("constant.lua"), "constant.lua not found in " .. GAME_PATH)
	-- The bootstrap normally reads mayhem_config.lua off disk; inject instead.
	recorder.loaded["mayhem_config.lua"] = true
	MAYHEM_CONFIG = config
	assert(Duel.LoadScript("mayhem_bootstrap.lua"), "bootstrap not found")
end

-- ---------------------------------------------------------------------- tests
-- Load the generated catalogue once so the tests can address real codes.
run({ enabled = {} })
MAYHEM_LP_CODE_BASE_FOR_TESTS = MAYHEM_LP_CODE_BASE

local tests = {}

tests["speed_blitz sets starting LP on both players"] = function()
	run({ enabled = { "speed_blitz" }, params = { speed_blitz = { lp = 4000 } } })
	fire_startup()
	local call = called("Duel.SetLP")
	assert(call and call.args[2] == 4000, "LP was not set to 4000")
	local info = called("Debug.SetPlayerInfo")
	assert(info and info.args[2] == 4000, "player info LP not updated")
end

tests["high_friction caps special summons and enables the counter"] = function()
	run({ enabled = { "high_friction" }, params = { high_friction = { max_special_summons = 5 } } })
	assert(recorder.flags[GLOBALFLAG_SPSUMMON_COUNT], "spsummon counter not enabled")
	local effect = effect_with(EFFECT_SPSUMMON_COUNT_LIMIT)
	assert(effect, "no spsummon limit effect")
	assert(effect.value == 5, "wrong limit: " .. tostring(effect.value))
	assert(effect.target_range[1] == 1 and effect.target_range[2] == 1, "must hit both players")
	assert(effect.property == EFFECT_FLAG_PLAYER_TARGET, "missing player target flag")
end

tests["resource_starvation shrinks the opening hand"] = function()
	run({ enabled = { "resource_starvation" }, params = { resource_starvation = { hand = 3 } } })
	fire_startup()
	local info = called("Debug.SetPlayerInfo")
	assert(info and info.args[3] == 3, "opening hand not set to 3")
end

tests["thrift rewrites the per-turn draw count"] = function()
	run({ enabled = { "thrift" }, params = { thrift = { draw = 0 } } })
	local effect = effect_with(EFFECT_DRAW_COUNT)
	assert(effect and effect.value == 0, "draw count not zeroed")
end

tests["energy_surge recovers LP for the turn player at standby"] = function()
	run({ enabled = { "energy_surge" } })
	local effect = effect_with(EVENT_PHASE + PHASE_STANDBY)
	assert(effect, "no standby trigger")
	effect.operation(effect, 0)
	local call = called("Duel.Recover")
	assert(call and call.args[1] == 0 and call.args[2] == 1000, "wrong recovery")
end

tests["first_blood hands the win to the player who dealt the damage"] = function()
	run({ enabled = { "first_blood" } })
	local effect = effect_with(EVENT_BATTLE_DAMAGE)
	assert(effect and effect.count_limit == 1, "battle damage trigger must fire once")
	effect.operation(effect, 0, nil, 1) -- player 1 took the damage
	local call = called("Duel.Win")
	assert(call and call.args[1] == 0, "player 0 should win")
end

tests["sealed_magic blocks spell activations only"] = function()
	run({ enabled = { "sealed_magic" } })
	local effect = effect_with(EFFECT_CANNOT_ACTIVATE)
	assert(effect, "no activation lock")
	local function activation(card_type)
		return { GetHandler = function()
			return { IsType = function(_, wanted) return wanted == card_type end }
		end }
	end
	assert(effect.value(effect, activation(TYPE_SPELL), 0) == true, "spell should be blocked")
	assert(effect.value(effect, activation(TYPE_TRAP), 0) == false, "trap should be allowed")
end

tests["extra_embargo drops the game on an oversized extra deck"] = function()
	run({ enabled = { "extra_embargo" }, params = { extra_embargo = { max_extra = 6 } } })
	Duel.GetFieldGroupCount = function(player)
		if player == 1 then return 8 end
		return 6
	end
	fire_startup()
	Duel.GetFieldGroupCount = function() return 0 end
	local call = called("Duel.Win")
	assert(call and call.args[1] == 0, "player 0 should win against the illegal deck")
end

tests["an unknown core is skipped instead of breaking the duel"] = function()
	run({ enabled = { "not_a_real_core" } })
	assert(#MAYHEM.active == 0, "nothing should be active")
	assert(#recorder.effects == 0, "nothing should be registered")
end


tests["a code typed into Starting LP applies its catalogue entry"] = function()
	-- 1000008 = "Han Dien Vang", a 5 Special Summon cap.
	run({ enabled = {} }, MAYHEM_LP_CODE_BASE_FOR_TESTS + 8)
	local effect = effect_with(EFFECT_SPSUMMON_COUNT_LIMIT)
	assert(effect and effect.value == 5, "catalogue params were not applied")
	assert(MAYHEM.labels[1]:find("8"), "code not recorded for the banner")
end

tests["the encoded number never survives as real life points"] = function()
	run({ enabled = {} }, MAYHEM_LP_CODE_BASE_FOR_TESTS + 15) -- Nhat Kich, sets no LP
	local info = called("Debug.SetPlayerInfo")
	assert(info and info.args[2] == MAYHEM_DEFAULT_LP,
		"LP should fall back to the default, got " .. tostring(info and info.args[2]))
end

tests["an unknown code leaves the duel on stock rules with sane LP"] = function()
	run({ enabled = {} }, MAYHEM_LP_CODE_BASE_FOR_TESTS + 9999)
	assert(#MAYHEM.active == 0, "nothing should be applied")
	local info = called("Debug.SetPlayerInfo")
	assert(info and info.args[2] == MAYHEM_DEFAULT_LP, "LP was not restored")
end

tests["a normal Starting LP is left completely alone"] = function()
	run({ enabled = {} }, 8000)
	assert(#MAYHEM.active == 0, "nothing should be applied")
	assert(called("Debug.SetPlayerInfo") == nil, "player info must not be touched")
end

tests["the corrected life points are broadcast to the clients"] = function()
	-- MSG_START carries the number the host typed, not the core's LP, so the
	-- plugin has to re-send it or the counter would keep showing the code.
	run({ enabled = {} }, MAYHEM_LP_CODE_BASE_FOR_TESTS + 15) -- Nhat Kich, no LP core
	fire_startup()
	local call = called("Duel.SetLP")
	assert(call and call.args[2] == MAYHEM_DEFAULT_LP,
		"expected an LP broadcast of " .. MAYHEM_DEFAULT_LP ..
		", got " .. tostring(call and call.args[2]))
end

-- ----------------------------------------------------------------- test runner
local names = {}
for name in pairs(tests) do table.insert(names, name) end
table.sort(names)

local failed = 0
for _, name in ipairs(names) do
	local ok, err = pcall(tests[name])
	if ok then
		print("PASS  " .. name)
	else
		failed = failed + 1
		print("FAIL  " .. name .. "\n      " .. tostring(err))
	end
end

print(string.format("\n%d passed, %d failed", #names - failed, failed))
os.exit(failed == 0 and 0 or 1)
