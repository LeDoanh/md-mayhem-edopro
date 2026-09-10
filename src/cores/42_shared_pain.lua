-- Shared Pain - every damage event deals the same damage to the other player once.
MAYHEM.Register("42_shared_pain", {
	apply = function()
		MAYHEM.OnEvent(EVENT_DAMAGE, function(e, tp, eg, damaged, amount, effect, reason)
			if reason & REASON_RULE ~= 0 then return end
			Duel.Damage(1 - damaged, amount, REASON_RULE)
		end)
	end,
})
