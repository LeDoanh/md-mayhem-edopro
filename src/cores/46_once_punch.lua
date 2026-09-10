-- Once Punch - the first attacker of each Battle Phase doubles its ATK for damage.
MAYHEM.Register("46_once_punch", {
	apply = function()
		local used = false
		MAYHEM.OnEvent(EVENT_PHASE_START + PHASE_BATTLE, function() used = false end)
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
