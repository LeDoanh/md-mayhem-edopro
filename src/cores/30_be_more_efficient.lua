-- Be more efficient - at most three monsters and three S/T cards, including Field Spells.
MAYHEM.Register("30_be_more_efficient", {
	defaults = { monster_zones = 3, spell_trap_zones = 3 },
	apply = function(params)
		MAYHEM.FieldRule(EFFECT_MAX_MZONE, params.monster_zones, true)
		-- MAX_SZONE only counts the five ordinary slots, not the Field Zone.
		MAYHEM.FieldRule(EFFECT_MAX_SZONE, function(e, player)
			return params.spell_trap_zones - (Duel.GetFieldCard(player, LOCATION_SZONE, 5) and 1 or 0)
		end, true)
		local function field_full(card, player)
			return card:IsType(TYPE_FIELD)
				and not Duel.GetFieldCard(player, LOCATION_SZONE, 5)
				and Duel.GetFieldGroupCount(player, LOCATION_SZONE, 0) >= params.spell_trap_zones
		end
		-- Field Spell activation/set bypass MAX_SZONE. Replacing an existing
		-- Field Spell or activating one already set does not occupy a new slot.
		MAYHEM.FieldRule(EFFECT_CANNOT_ACTIVATE, function(e, re, player)
			return re:IsHasType(EFFECT_TYPE_ACTIVATE) and field_full(re:GetHandler(), player)
		end)
		MAYHEM.PlayerRestriction(EFFECT_CANNOT_SSET, function(e, card, player)
			return field_full(card, player)
		end)
		-- Effects can place Field Spells directly, bypassing activation/set
		-- restrictions. Referee any overflow after resolution; the controller
		-- chooses the excess, sent by rule (so immunity cannot prevent cleanup).
		local adjusting = false
		MAYHEM.OnEvent(EVENT_ADJUST, function()
			if adjusting then return end
			adjusting = true
			for player = 0, 1 do
				local excess = Duel.GetFieldGroupCount(player, LOCATION_SZONE, 0) - params.spell_trap_zones
				if excess > 0 then
					Duel.Hint(HINT_SELECTMSG, player, HINTMSG_TOGRAVE)
					local cards = Duel.GetFieldGroup(player, LOCATION_SZONE, 0):Select(player, excess, excess, nil)
					Duel.SendtoGrave(cards, REASON_RULE)
				end
			end
			adjusting = false
		end)
	end,
})
