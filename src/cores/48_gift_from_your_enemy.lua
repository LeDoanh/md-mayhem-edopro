-- Gift from your Enemy - each player gives the opponent a monster from their Deck.
MAYHEM.Register("48_gift_from_your_enemy", {
	apply = function()
		MAYHEM.OnPhase(PHASE_STANDBY, function(e)
			for owner = 0, 1 do
				local target = 1 - owner
				local function legal(card)
					return card:IsType(TYPE_MONSTER)
						and card:IsCanBeSpecialSummoned(e, 0, owner, false, false, POS_FACEUP, target)
				end
				if Duel.GetLocationCount(target, LOCATION_MZONE) > 0
					and Duel.IsExistingMatchingCard(legal, owner, LOCATION_DECK, 0, 1, nil) then
					Duel.Hint(HINT_SELECTMSG, owner, HINTMSG_SPSUMMON)
					local card = Duel.SelectMatchingCard(owner, legal,
						owner, LOCATION_DECK, 0, 1, 1, nil):GetFirst()
					if card then Duel.SpecialSummon(card, 0, owner, target, false, false, POS_FACEUP) end
				end
			end
		end)
	end,
})
