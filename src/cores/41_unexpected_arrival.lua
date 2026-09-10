-- Unexpected Arrival - replace the normal draw with a legal monster from the Deck.
MAYHEM.Register("41_unexpected_arrival", {
	apply = function()
		MAYHEM.FieldRule(EFFECT_DRAW_COUNT, 0, true)
		MAYHEM.OnEvent(EVENT_PREDRAW, function(e)
			local player = Duel.GetTurnPlayer()
			local function legal(card)
				return card:IsType(TYPE_MONSTER)
					and card:IsCanBeSpecialSummoned(e, 0, player, false, false)
			end
			if Duel.GetLocationCount(player, LOCATION_MZONE) > 0
				and Duel.IsExistingMatchingCard(legal, player, LOCATION_DECK, 0, 1, nil) then
				Duel.Hint(HINT_SELECTMSG, player, HINTMSG_SPSUMMON)
				local card = Duel.SelectMatchingCard(player, legal,
					player, LOCATION_DECK, 0, 1, 1, nil):GetFirst()
				if card then Duel.SpecialSummon(card, 0, player, player, false, false, POS_FACEUP) end
			end
		end)
	end,
})
