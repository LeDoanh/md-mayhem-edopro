-- What is it gonna be? - each player Sets an immune non-Counter Spell/Trap at End Phase.
MAYHEM.Register("43_what_is_it_gonna_be", {
	apply = function()
		MAYHEM.OnPhase(PHASE_END, function()
			for player = 0, 1 do
				local function legal(card)
					return card:IsType(TYPE_SPELL + TYPE_TRAP)
						and not card:IsType(TYPE_COUNTER) and card:IsSSetable()
				end
				if Duel.GetLocationCount(player, LOCATION_SZONE) > 0
					and Duel.IsExistingMatchingCard(legal, player, LOCATION_DECK, 0, 1, nil) then
					Duel.Hint(HINT_SELECTMSG, player, HINTMSG_SET)
					local card = Duel.SelectMatchingCard(player, legal,
						player, LOCATION_DECK, 0, 1, 1, nil):GetFirst()
					if card and Duel.SSet(player, card) > 0 then
						local immune = Effect.CreateEffect(card)
						immune:SetType(EFFECT_TYPE_SINGLE)
						immune:SetProperty(EFFECT_FLAG_SINGLE_RANGE + EFFECT_FLAG_SET_AVAILABLE)
						immune:SetCode(EFFECT_IMMUNE_EFFECT)
						immune:SetRange(LOCATION_SZONE)
						immune:SetValue(function() return true end)
						card:RegisterEffect(immune)
					end
				end
			end
		end)
	end,
})
