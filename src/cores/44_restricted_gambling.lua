-- Restricted Gambling - one die sets each player's activation and summon quotas for the turn.
MAYHEM.Register("44_restricted_gambling", {
	apply = function()
		local limit, activations, summons = 6, { 0, 0 }, { 0, 0 }
		MAYHEM.OnEvent(EVENT_PHASE_START + PHASE_DRAW, function()
			limit, activations, summons = Duel.TossDice(Duel.GetTurnPlayer(), 1), { 0, 0 }, { 0, 0 }
		end)
		MAYHEM.OnEvent(EVENT_CHAINING, function(e, tp, eg, ep, ev, re, r, player)
			activations[player + 1] = activations[player + 1] + 1
		end)
		local function register_summons(e, tp, cards)
			local seen = {}
			local card = cards:GetFirst()
			while card do seen[card:GetSummonPlayer()] = true card = cards:GetNext() end
			for player in pairs(seen) do summons[player + 1] = summons[player + 1] + 1 end
		end
		MAYHEM.OnEvent(EVENT_SUMMON_SUCCESS, register_summons)
		MAYHEM.OnEvent(EVENT_FLIP_SUMMON_SUCCESS, register_summons)
		MAYHEM.OnEvent(EVENT_SPSUMMON_SUCCESS, register_summons)
		MAYHEM.FieldRule(EFFECT_CANNOT_ACTIVATE, function(e, re, player)
			return activations[player + 1] >= limit
		end, true)
		local function summon_lock(e, card, player) return summons[player + 1] >= limit end
		MAYHEM.PlayerRestriction(EFFECT_CANNOT_SUMMON, summon_lock)
		MAYHEM.PlayerRestriction(EFFECT_CANNOT_FLIP_SUMMON, summon_lock)
		MAYHEM.PlayerRestriction(EFFECT_CANNOT_SPECIAL_SUMMON, summon_lock)
	end,
})
