-- Once Punch - the first attacker of each Battle Phase doubles its ATK for damage.
MAYHEM.Register("46_once_punch", {
	apply = function()
		local used = false
		-- PHASE_BATTLE_START is the step that opens a Battle Phase; PHASE_BATTLE
		-- itself never raises a start event, so a reset hooked there is dead and
		-- only the first attacker of the whole duel would be boosted.
		MAYHEM.OnPhase(PHASE_BATTLE_START, function() used = false end)
		MAYHEM.OnEvent(EVENT_ATTACK_ANNOUNCE, function()
			if used then return end
			used = true
			local attacker = Duel.GetAttacker()
			local boost = Effect.CreateEffect(attacker)
			boost:SetType(EFFECT_TYPE_SINGLE)
			boost:SetCode(EFFECT_UPDATE_ATTACK)
			boost:SetValue(attacker:GetAttack())
			boost:SetReset(RESET_EVENT + RESETS_STANDARD + RESET_PHASE + PHASE_DAMAGE)
			attacker:RegisterEffect(boost)
		end)
	end,
})
