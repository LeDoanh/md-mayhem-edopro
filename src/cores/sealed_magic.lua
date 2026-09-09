-- Phong An / Sealed Magic - neither player may activate Spell Cards.
--
-- Deck building is left alone on purpose: Spells may still be set, they just
-- cannot be activated, so decks stay legal against any banlist.
MAYHEM.Register("sealed_magic", {
	apply = function()
		MAYHEM.FieldRule(EFFECT_CANNOT_ACTIVATE, function(e, re, tp)
			return re:GetHandler():IsType(TYPE_SPELL)
		end)
	end,
})
