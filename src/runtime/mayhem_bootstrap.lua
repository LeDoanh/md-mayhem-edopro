-- MD Mayhem - bootstrap: builds the registry and applies the selected cores.
--
-- Load order inside a duel:
--   constant.lua -> utility.lua -> init.lua -> this file
--     -> mayhem_engine.lua     (shared helpers)
--     -> mayhem_config.lua     (always-on cores, operator settings)
--     -> mayhem_catalogue.lua  (generated: code -> label + cores)
--
-- Per-match selection comes from the Host window's Starting LP box: the host
-- types MAYHEM_LP_CODE_BASE + <core code>. Starting LP is one of the very few
-- values that reach the duel core (OCG_DuelOptions), it is an unclamped uint32,
-- and the selected core sets the real life points afterwards. Nothing in the
-- client is patched or overridden, so EDOPro's own game modes are left alone.
--
-- Each duel gets a fresh Lua state, so MAYHEM is rebuilt from scratch every game.

MAYHEM = {
	VERSION = "0.4.0",
	cores = {},   -- id -> core definition, filled in by MAYHEM.Register
	active = {},  -- ids applied to this duel, in the order they were applied
	labels = {},  -- human-readable names of what was selected
}

--- Called by every mayhem_core_<id>.lua at load time.
-- def.defaults : table of tunable parameters (optional)
-- def.apply    : function(params) that installs the rule (required)
function MAYHEM.Register(id, def)
	MAYHEM.cores[id] = def
end

Duel.LoadScript("mayhem_engine.lua")
Duel.LoadScript("mayhem_config.lua")
Duel.LoadScript("mayhem_catalogue.lua")

local config = MAYHEM_CONFIG or {}

MAYHEM.Log("bootstrap " .. MAYHEM.VERSION .. " loaded")

local function is_active(id)
	for _, active_id in ipairs(MAYHEM.active) do
		if active_id == id then return true end
	end
	return false
end

--- Merges a core's defaults with the caller's overrides.
local function merge(defaults, overrides)
	local params = {}
	for key, value in pairs(defaults or {}) do
		params[key] = value
	end
	for key, value in pairs(overrides or {}) do
		params[key] = value
	end
	return params
end

--- Installs one core. Applying the same core twice would stack two conflicting
--- rules, so the second attempt is refused and logged instead.
function MAYHEM.ApplyCore(id, params)
	if not MAYHEM.cores[id] then
		Duel.LoadScript("mayhem_core_" .. id .. ".lua")
	end
	local core = MAYHEM.cores[id]
	if not core or type(core.apply) ~= "function" then
		MAYHEM.Warn("unknown core '" .. tostring(id) .. "' - skipped")
		return false
	end
	if is_active(id) then
		MAYHEM.Warn("core '" .. id .. "' already active - second copy skipped")
		return false
	end
	core.apply(merge(core.defaults, params))
	table.insert(MAYHEM.active, id)
	MAYHEM.Log("applied core '" .. id .. "'")
	return true
end

--- Applies catalogue entry `code`, as selected through the Starting LP box.
function MAYHEM.ApplyCode(code)
	local entry = (MAYHEM_CATALOGUE or {})[code]
	if not entry then
		MAYHEM.Warn("no catalogue entry for code " .. tostring(code))
		return false
	end
	MAYHEM.Log("code " .. code .. ": " .. (entry.label or "?"))
	table.insert(MAYHEM.labels, code .. " " .. (entry.label or "?"))
	for id, params in pairs(entry.cores or {}) do
		MAYHEM.ApplyCore(id, params)
	end
	return true
end

--- Reads the core selection out of the starting life points.
-- Runs now rather than at EVENT_STARTUP so the real LP is restored before any
-- core registers its own startup rule; a core that sets LP therefore still wins.
local function apply_lp_code()
	local base = MAYHEM_LP_CODE_BASE
	if not base then return end
	local encoded = Duel.GetLP(0)
	if encoded < base then return end

	local code = encoded - base
	local entry = (MAYHEM_CATALOGUE or {})[code]
	-- The encoded number must never survive as real life points, whether or not
	-- the code turned out to be valid.
	MAYHEM.SetStartingLP((entry and entry.lp) or MAYHEM_DEFAULT_LP or 8000)
	MAYHEM.ApplyCode(code)
end

apply_lp_code()

-- Always-on cores from the config file.
for _, id in ipairs(config.enabled or {}) do
	MAYHEM.ApplyCore(id, (config.params or {})[id])
end

-- There is deliberately no in-duel announcement: EDOPro's client has no handler
-- for MSG_SHOW_HINT (97 `case MSG_` arms in duelclient.cpp, none of them that),
-- so Debug.ShowHint is dropped on the floor. The visible confirmation is the life
-- point counter snapping from the typed code to the real value.
