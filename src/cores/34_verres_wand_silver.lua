-- Verre's Wand Silver - reveal any number of Spells to boost a battling monster.
MAYHEM.Register("34_verres_wand_silver", {
	defaults = { attack_per_spell = 500 },
	apply = function(params)
		MAYHEM.OnEvent(EVENT_PRE_DAMAGE_CALCULATE, function()
			for _, monster in ipairs({ Duel.GetAttacker(), Duel.GetAttackTarget() }) do
				if monster then
					local player = monster:GetControler()
					local count = Duel.GetMatchingGroupCount(Card.IsType,
						player, LOCATION_HAND, 0, nil, TYPE_SPELL)
					if count > 0 then
						Duel.Hint(HINT_SELECTMSG, player, HINTMSG_CONFIRM)
						local shown = Duel.SelectMatchingCard(player, Card.IsType,
							player, LOCATION_HAND, 0, 0, count, nil, TYPE_SPELL)
						if #shown > 0 then
							Duel.ConfirmCards(1 - player, shown)
							local boost = Effect.CreateEffect(monster)
							boost:SetType(EFFECT_TYPE_SINGLE)
							boost:SetCode(EFFECT_UPDATE_ATTACK)
							boost:SetValue(#shown * params.attack_per_spell)
							boost:SetReset(RESET_EVENT + RESETS_STANDARD + RESET_PHASE + PHASE_DAMAGE)
							monster:RegisterEffect(boost)
						end
					end
				end
			end
		end)
	end,
})
