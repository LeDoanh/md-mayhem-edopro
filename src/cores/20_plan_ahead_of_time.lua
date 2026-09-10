-- Plan Ahead of Time - no opening hand or Draw Phase; tutor twice at Standby.
MAYHEM.Register("20_plan_ahead_of_time", {
	defaults = { standby_add = 2 },
	apply = function(params)
		MAYHEM.OnStartup(function()
			MAYHEM.SetPlayerRules({ hand = 0 })
		end)
		MAYHEM.FieldRule(EFFECT_SKIP_DP, 1, true)
		MAYHEM.OnPhase(PHASE_STANDBY, function()
			for player = 0, 1 do
				local count = math.min(params.standby_add,
					Duel.GetMatchingGroupCount(Card.IsAbleToHand, player, LOCATION_DECK, 0, nil))
				if count > 0 then
					Duel.Hint(HINT_SELECTMSG, player, HINTMSG_ATOHAND)
					local cards = Duel.SelectMatchingCard(player, Card.IsAbleToHand,
						player, LOCATION_DECK, 0, count, count, nil)
					if Duel.SendtoHand(cards, nil, REASON_RULE) > 0 then
						Duel.ConfirmCards(1 - player, cards)
						Duel.ShuffleHand(player)
					end
				end
			end
		end)
	end,
})
