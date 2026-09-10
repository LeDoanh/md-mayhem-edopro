-- You have to be quick - both players stay fixed at 10000 LP.
MAYHEM.Register("32_you_have_to_be_quick", {
	defaults = { lp = 10000 },
	apply = function(params)
		MAYHEM.OnStartup(function() MAYHEM.SetPlayerRules({ lp = params.lp }) end)
		MAYHEM.OnPhase(PHASE_END, function()
			for player = 0, 1 do Duel.SetLP(player, params.lp) end
		end)
	end,
})
