-- Mong Manh / Resource Starvation - smaller opening hand for both players.
MAYHEM.Register("resource_starvation", {
	defaults = { hand = 3 },
	apply = function(params)
		MAYHEM.OnStartup(function()
			MAYHEM.SetPlayerRules({ hand = params.hand })
		end)
	end,
})
