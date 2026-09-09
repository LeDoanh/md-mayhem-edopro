-- Nang Luong / Energy Surge - the turn player recovers LP each Standby Phase.
MAYHEM.Register("energy_surge", {
	defaults = { amount = 1000 },
	apply = function(params)
		MAYHEM.OnEvent(EVENT_PHASE + PHASE_STANDBY, function()
			Duel.Recover(Duel.GetTurnPlayer(), params.amount, REASON_RULE)
		end)
	end,
})
