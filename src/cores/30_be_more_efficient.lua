-- Be more efficient - each player has at most three Monster and three Spell/Trap Zones.
MAYHEM.Register("30_be_more_efficient", {
	defaults = { monster_zones = 3, spell_trap_zones = 3 },
	apply = function(params)
		MAYHEM.FieldRule(EFFECT_MAX_MZONE, params.monster_zones, true)
		MAYHEM.FieldRule(EFFECT_MAX_SZONE, params.spell_trap_zones, true)
	end,
})
