-- Strength of the weak - the globally weakest face-up monsters ignore card effects.
MAYHEM.Register("29_strength_of_the_weak", {
	apply = function()
		local rule = Effect.GlobalEffect()
		rule:SetType(EFFECT_TYPE_FIELD)
		rule:SetCode(EFFECT_IMMUNE_EFFECT)
		rule:SetTargetRange(LOCATION_MZONE, LOCATION_MZONE)
		rule:SetTarget(function(e, card)
			if not card:IsFaceup() then return false end
			local monsters = Duel.GetMatchingGroup(Card.IsFaceup, 0,
				LOCATION_MZONE, LOCATION_MZONE, nil)
			if #monsters < 2 then return false end
			local _, attack = monsters:GetMinGroup(Card.GetAttack)
			return card:GetAttack() == attack
		end)
		rule:SetValue(function() return true end)
		Duel.RegisterEffect(rule, 0)
	end,
})
