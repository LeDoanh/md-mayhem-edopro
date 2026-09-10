-- Keep drawing - both players refill to five cards at every End Phase.
MAYHEM.Register("27_keep_drawing", {
	defaults = { hand = 5 },
	apply = function(params)
		MAYHEM.OnPhase(PHASE_END, function()
			for player = 0, 1 do
				local missing = params.hand - Duel.GetFieldGroupCount(player, LOCATION_HAND, 0)
				local available = Duel.GetFieldGroupCount(player, LOCATION_DECK, 0)
				local amount = math.min(missing, available)
				if amount > 0 and Duel.IsPlayerCanDraw(player, amount) then
					Duel.Draw(player, amount, REASON_RULE)
				end
			end
		end)
	end,
})
