-- Rock Paper Scissors - Monsters beat Spells, Spells beat Traps, Traps beat Monsters.
MAYHEM.Register("49_rock_paper_scissors", {
	apply = function()
		local rules = {
			{ LOCATION_MZONE, TYPE_MONSTER, TYPE_SPELL },
			{ LOCATION_SZONE, TYPE_SPELL, TYPE_TRAP },
			{ LOCATION_SZONE, TYPE_TRAP, TYPE_MONSTER },
		}
		for _, values in ipairs(rules) do
			local location, protected_type, source_type = values[1], values[2], values[3]
			local rule = Effect.GlobalEffect()
			rule:SetType(EFFECT_TYPE_FIELD)
			rule:SetProperty(EFFECT_FLAG_SET_AVAILABLE)
			rule:SetCode(EFFECT_IMMUNE_EFFECT)
			rule:SetTargetRange(location, location)
			rule:SetTarget(function(e, card) return card:IsType(protected_type) end)
			rule:SetValue(function(e, other) return other:IsActiveType(source_type) end)
			Duel.RegisterEffect(rule, 0)
		end
	end,
})
