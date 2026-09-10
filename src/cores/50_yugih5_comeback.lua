-- yugiH5 Comeback - no Battle Phase; summoned monsters may immediately battle a monster.
MAYHEM.Register("50_yugih5_comeback", {
	apply = function()
		MAYHEM.FieldRule(EFFECT_SKIP_BP, 1, true)
		local function battle(e, tp, monsters)
			if Duel.GetTurnCount() == 1 then return end
			local monster = monsters:GetFirst()
			while monster do
				if Duel.GetTurnCount() == 2 then
					local half = Effect.CreateEffect(monster)
					half:SetType(EFFECT_TYPE_SINGLE)
					half:SetCode(EFFECT_SET_ATTACK_FINAL)
					half:SetValue(math.max(0, monster:GetAttack() // 2))
					half:SetReset(RESET_EVENT + RESETS_STANDARD + RESET_PHASE + PHASE_END)
					monster:RegisterEffect(half)
				end
				local player = monster:GetControler()
				local targets = Duel.GetMatchingGroup(Card.IsFaceup, player, 0, LOCATION_MZONE, nil)
				if #targets > 0 and Duel.SelectYesNo(player, HINTMSG_ATTACK) then
					Duel.Hint(HINT_SELECTMSG, player, HINTMSG_ATTACKTARGET)
					Duel.CalculateDamage(monster, targets:Select(player, 1, 1, nil):GetFirst())
				end
				monster = monsters:GetNext()
			end
		end
		MAYHEM.OnEvent(EVENT_SUMMON_SUCCESS, battle)
		MAYHEM.OnEvent(EVENT_FLIP_SUMMON_SUCCESS, battle)
		MAYHEM.OnEvent(EVENT_SPSUMMON_SUCCESS, battle)
	end,
})
