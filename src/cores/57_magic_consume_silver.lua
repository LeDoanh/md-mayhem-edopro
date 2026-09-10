-- Magic consume Silver - reveal a Spell as monster-effect activation cost, max three uses/card.
MAYHEM.Register("57_magic_consume_silver", {
	defaults = { max_reveals = 3 },
	apply = function(params)
		local uses = {}
		local function available(card) return card:IsType(TYPE_SPELL) and (uses[card] or 0) < params.max_reveals end
		local cost = Effect.GlobalEffect()
		cost:SetType(EFFECT_TYPE_FIELD)
		cost:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
		cost:SetCode(EFFECT_ACTIVATE_COST)
		cost:SetTargetRange(1, 1)
		cost:SetTarget(function(e, effect) return effect:IsMonsterEffect() end)
		cost:SetCost(function(e, effect, player)
			return Duel.IsExistingMatchingCard(available, player, LOCATION_HAND, 0, 1, nil)
		end)
		cost:SetOperation(function(e, player)
			Duel.Hint(HINT_SELECTMSG, player, HINTMSG_CONFIRM)
			local card = Duel.SelectMatchingCard(player, available,
				player, LOCATION_HAND, 0, 1, 1, nil):GetFirst()
			if card then
				Duel.ConfirmCards(1 - player, card)
				uses[card] = (uses[card] or 0) + 1
			end
		end)
		Duel.RegisterEffect(cost, 0)
	end,
})
