-- Boss is alway Boss - every face-up monster tied for highest ATK ignores card effects.
MAYHEM.Register("53_boss_is_always_boss", {
	apply = function()
		local rule = Effect.GlobalEffect()
		rule:SetType(EFFECT_TYPE_FIELD)
		rule:SetCode(EFFECT_IMMUNE_EFFECT)
		rule:SetTargetRange(LOCATION_MZONE, LOCATION_MZONE)
		rule:SetTarget(function(e, card)
			if not card:IsFaceup() then return false end
			local monsters = Duel.GetMatchingGroup(Card.IsFaceup, 0,
				LOCATION_MZONE, LOCATION_MZONE, nil)
			if #monsters == 0 then return false end
			local _, attack = monsters:GetMaxGroup(Card.GetAttack)
			return card:GetAttack() == attack
		end)
		rule:SetValue(function() return true end)
		Duel.RegisterEffect(rule, 0)
	end,
})
