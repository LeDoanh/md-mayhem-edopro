-- Leaking Vrain - each player Special Summons one legal Link from their Extra Deck at startup.
MAYHEM.Register("28_leaking_vrain", {
	apply = function()
		MAYHEM.OnStartup(function(e)
			for player = 0, 1 do
				if Duel.GetLocationCount(player, LOCATION_MZONE) > 0 then
					local function legal(card)
						return card:IsType(TYPE_LINK)
							and card:IsCanBeSpecialSummoned(e, 0, player, false, false)
					end
					if Duel.IsExistingMatchingCard(legal, player, LOCATION_EXTRA, 0, 1, nil) then
						Duel.Hint(HINT_SELECTMSG, player, HINTMSG_SPSUMMON)
						local card = Duel.SelectMatchingCard(player, legal,
							player, LOCATION_EXTRA, 0, 1, 1, nil):GetFirst()
						if card then Duel.SpecialSummon(card, 0, player, player, false, false, POS_FACEUP) end
					end
				end
			end
		end)
	end,
})
