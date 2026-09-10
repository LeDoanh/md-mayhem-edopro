-- Recycling - shuffle both Graveyards and banished piles back every End Phase.
MAYHEM.Register("33_recycling", {
	apply = function()
		MAYHEM.OnPhase(PHASE_END, function()
			for player = 0, 1 do
				local cards = Duel.GetFieldGroup(player, LOCATION_GRAVE + LOCATION_REMOVED, 0)
				cards = cards:Filter(Card.IsAbleToDeck, nil)
				if #cards > 0 then Duel.SendtoDeck(cards, nil, SEQ_DECKSHUFFLE, REASON_RULE) end
				Duel.ShuffleDeck(player)
			end
		end)
	end,
})
