-- Raw force no strategy - neither player may Set monsters, Spells, or Traps.
MAYHEM.Register("22_raw_force_no_strategy", {
	apply = function()
		MAYHEM.FieldRule(EFFECT_CANNOT_MSET, 1, true)
		MAYHEM.FieldRule(EFFECT_CANNOT_SSET, 1, true)
	end,
})
