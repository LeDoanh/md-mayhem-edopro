-- This card is trash - negate each player's first activation every turn.
MAYHEM.Register("38_this_card_is_trash", {
	apply = function()
		local used = { false, false }
		MAYHEM.OnEvent(EVENT_TURN_END, function() used = { false, false } end)
		MAYHEM.OnEvent(EVENT_CHAINING, function(e, tp, eg, ep, chain, effect, reason, player)
			if used[player + 1] then return end
			used[player + 1] = true
			if Duel.NegateActivation(chain) == 0 then Duel.NegateEffect(chain) end
		end)
	end,
})
