-- Han Dien / High Friction - hard cap on Special Summons per turn, per player.
--
-- EFFECT_SPSUMMON_COUNT_LIMIT is the same engine rule "Vanity's Fiend"-style
-- cards use, so the core counts and blocks by itself. No manual counting, no
-- replay review: an illegal Special Summon simply cannot be declared.
MAYHEM.Register("high_friction", {
	defaults = { max_special_summons = 5 },
	apply = function(params)
		-- The core only tracks per-turn Special Summon counts when asked to.
		Duel.EnableGlobalFlag(GLOBALFLAG_SPSUMMON_COUNT)
		MAYHEM.FieldRule(EFFECT_SPSUMMON_COUNT_LIMIT, params.max_special_summons, true)
	end,
})
