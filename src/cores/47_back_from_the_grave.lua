-- Back From the Grave - each player revives one legal monster every End Phase.
MAYHEM.Register("47_back_from_the_grave", {
	apply = function()
		MAYHEM.OnPhase(PHASE_END, function(e)
			for player = 0, 1 do
				local function legal(card)
					return card:IsType(TYPE_MONSTER)
						and card:IsCanBeSpecialSummoned(e, 0, player, false, false)
				end
				if Duel.GetLocationCount(player, LOCATION_MZONE) > 0
					and Duel.IsExistingMatchingCard(legal, player, LOCATION_GRAVE, 0, 1, nil) then
					Duel.Hint(HINT_SELECTMSG, player, HINTMSG_SPSUMMON)
					local card = Duel.SelectMatchingCard(player, legal,
						player, LOCATION_GRAVE, 0, 1, 1, nil):GetFirst()
					if card then Duel.SpecialSummon(card, 0, player, player, false, false, POS_FACEUP) end
				end
			end
		end)
	end,
})
