-- MD Mayhem - shared helpers every mutation core builds on.
--
-- All rules are installed as *global* effects: Effect.GlobalEffect() creates an
-- effect that belongs to no card, and Duel.RegisterEffect puts it on the field
-- for the whole duel. This is the same mechanism the stock proc_skill.lua and
-- Auxiliary.BeginPuzzle use, so it needs no custom card, no .cdb entry and no
-- deck slot - the opponent does not even have to install the plugin, because
-- only the duel host runs the core.

local M = MAYHEM

-- Win reason id. constant.lua defines WIN_REASON_* up to 0x59 with gaps;
-- 0x5a is free, so the client falls back to its generic "wins" message.
M.WIN_REASON = 0x5a

--- Routine progress notes, off unless MAYHEM_CONFIG.debug is set.
-- EDOPro tags every script message with the "Script Error" string and, when
-- coreLogOutput includes the chat bit, prints it in red in the duel chat. Normal
-- play must therefore stay silent; turn debug on only to diagnose.
function M.Log(message)
	if MAYHEM_CONFIG and MAYHEM_CONFIG.debug then
		M.Warn(message)
	end
end

--- Something actually went wrong: always reported, however noisy.
function M.Warn(message)
	if Debug and Debug.Message then
		Debug.Message("[MAYHEM] " .. tostring(message))
	end
end

--- Installs a permanent field rule that applies to both players.
-- code          : EFFECT_* constant
-- value         : number, or function(e, ...) depending on the effect
-- player_target : pass true for effects the core reads off a player
--                 (EFFECT_DRAW_COUNT, EFFECT_SPSUMMON_COUNT_LIMIT, ...)
function M.FieldRule(code, value, player_target)
	local e = Effect.GlobalEffect()
	e:SetType(EFFECT_TYPE_FIELD)
	if player_target then
		e:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	end
	e:SetCode(code)
	e:SetTargetRange(1, 1) -- 1 = self, 1 = opponent, i.e. everyone
	e:SetValue(value)
	Duel.RegisterEffect(e, 0)
	return e
end

--- Installs a duel-wide trigger.
-- event      : EVENT_* constant (EVENT_PHASE + PHASE_* is allowed)
-- op         : function(e, tp, eg, ep, ev, re, r, rp)
-- countlimit : optional cap on how often it may fire in the duel
function M.OnEvent(event, op, countlimit)
	local e = Effect.GlobalEffect()
	e:SetType(EFFECT_TYPE_FIELD + EFFECT_TYPE_CONTINUOUS)
	e:SetCode(event)
	if countlimit then
		e:SetCountLimit(countlimit)
	end
	e:SetOperation(op)
	Duel.RegisterEffect(e, 0)
	return e
end

--- Runs op once at the start of the duel, before the opening hands are drawn.
function M.OnStartup(op)
	return M.OnEvent(EVENT_STARTUP, op, 1)
end

--- Sets both players' starting life points immediately, before the duel begins.
-- Used to replace the encoded core number the host typed into Starting LP with
-- the real value. Debug.SetPlayerInfo writes lp and start_lp directly, which is
-- what makes this safe to call at load time rather than at EVENT_STARTUP.
function M.SetStartingLP(lp)
	for player = 0, 1 do
		Debug.SetPlayerInfo(player, lp, Duel.GetStartingHand(player), Duel.GetDrawCount(player))
	end
	M.Log("starting LP set to " .. Duel.GetLP(0))

	-- The players' life point counters do NOT come from the core: the host builds
	-- MSG_START itself out of host_info.start_lp (generic_duel.cpp), which is the
	-- number typed into the Starting LP box. Debug.SetPlayerInfo writes the core's
	-- LP silently, so without this the screen would keep showing the encoded code.
	-- Duel.SetLP always emits MSG_LPUPDATE, even for an unchanged value, so this
	-- re-broadcasts whatever the LP is once the duel has actually started. It is
	-- order-independent: a core that sets its own LP through SetPlayerRules
	-- broadcasts too, so both orderings end on the same value.
	M.OnStartup(function()
		for player = 0, 1 do
			Duel.SetLP(player, Duel.GetLP(player))
		end
	end)
end

--- Overrides starting LP, opening hand size and per-turn draw for both players.
-- Any omitted field keeps whatever the host picked in the room settings.
-- Must be called from inside OnStartup: Debug.SetPlayerInfo rewrites the raw
-- player state, and the opening draw has not happened yet at that point.
function M.SetPlayerRules(opts)
	for player = 0, 1 do
		Debug.SetPlayerInfo(
			player,
			opts.lp or Duel.GetLP(player),
			opts.hand or Duel.GetStartingHand(player),
			opts.draw or Duel.GetDrawCount(player)
		)
		-- Debug.SetPlayerInfo writes the LP field directly without telling the
		-- client, so push the value again through the normal path to keep both
		-- life point counters on screen in sync.
		if opts.lp then
			Duel.SetLP(player, opts.lp)
		end
	end
	-- Read the values back out of the engine, so the log proves the duel state
	-- actually changed rather than just recording what we asked for.
	M.Log(string.format("player rules now: lp %d/%d, hand %d/%d, draw %d/%d",
		Duel.GetLP(0), Duel.GetLP(1),
		Duel.GetStartingHand(0), Duel.GetStartingHand(1),
		Duel.GetDrawCount(0), Duel.GetDrawCount(1)))
end
