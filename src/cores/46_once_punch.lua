-- Once Punch - the first attacker of each Battle Phase doubles its ATK for damage.
MAYHEM.Register("46_once_punch", {
	apply = function()
		local used = false
		local first_attacker
		-- PHASE_BATTLE_START is the step that opens a Battle Phase; PHASE_BATTLE
		-- itself never raises a start event, so a reset hooked there is dead and
		-- only the first attacker of the whole duel would be boosted.
		MAYHEM.OnPhase(PHASE_BATTLE_START, function() used = false; first_attacker = nil end)
		MAYHEM.OnEvent(EVENT_ATTACK_ANNOUNCE, function()
			first_attacker = nil
			if used then return end
			used = true
			first_attacker = Duel.GetAttacker()
		end)
		-- EVENT_BATTLE_START opens the Damage Step. A negated first attack
		-- consumes the bonus without ever attaching an ATK effect.
		MAYHEM.OnEvent(EVENT_BATTLE_START, function()
			local attacker = Duel.GetAttacker()
			if not first_attacker or attacker ~= first_attacker then return end
			first_attacker = nil
			local boost = Effect.CreateEffect(attacker)
			boost:SetType(EFFECT_TYPE_SINGLE)
			boost:SetCode(EFFECT_UPDATE_ATTACK)
			boost:SetValue(attacker:GetAttack())
			boost:SetReset(RESET_EVENT + RESETS_STANDARD + RESET_PHASE + PHASE_DAMAGE + PHASE_END)
			attacker:RegisterEffect(boost)
		end)
	end,
})
