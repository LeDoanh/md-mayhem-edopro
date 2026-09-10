-- Litterally just Mulligan - optionally recycle the whole hand at each Standby Phase.
MAYHEM.Register("45_literally_just_mulligan", {
	apply = function()
		MAYHEM.OnPhase(PHASE_STANDBY, function()
			for player = 0, 1 do
				local hand = Duel.GetFieldGroup(player, LOCATION_HAND, 0)
				local count = #hand
				if count > 0 and Duel.SelectYesNo(player, HINTMSG_TODECK) then
					if Duel.SendtoDeck(hand, nil, SEQ_DECKSHUFFLE, REASON_RULE) > 0 then
						Duel.ShuffleDeck(player)
						Duel.Draw(player, count, REASON_RULE)
					end
				end
			end
		end)
	end,
})
