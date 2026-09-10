-- Stop hitting me - after a player's first attack, that player cannot attack again this turn.
MAYHEM.Register("23_stop_hitting_me", {
	apply = function()
		MAYHEM.OnEvent(EVENT_ATTACK_ANNOUNCE, function()
			local attacker = Duel.GetAttacker()
			local player = attacker:GetControler()
			local lock = Effect.GlobalEffect()
			lock:SetType(EFFECT_TYPE_FIELD)
			lock:SetCode(EFFECT_CANNOT_ATTACK_ANNOUNCE)
			lock:SetTargetRange(LOCATION_MZONE, 0)
			lock:SetTarget(function(e, card) return card ~= attacker end)
			lock:SetReset(RESET_PHASE + PHASE_END)
			Duel.RegisterEffect(lock, player)
		end)
	end,
})
