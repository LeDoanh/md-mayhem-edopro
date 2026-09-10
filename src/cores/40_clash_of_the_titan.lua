-- Clash of the Titan - replace all monsters with an untouchable, unusable ATK-sum Token.
MAYHEM.Register("40_clash_of_the_titan", {
	apply = function()
		Duel.LoadScript("mayhem_token_codes.lua")
		MAYHEM.OnEvent(EVENT_PHASE + PHASE_END, function()
			local player = Duel.GetTurnPlayer()
			local monsters = Duel.GetFieldGroup(0, LOCATION_MZONE, LOCATION_MZONE)
			local attacks, card = {}, monsters:GetFirst()
			while card do attacks[card] = math.max(0, card:GetAttack()) card = monsters:GetNext() end
			if #monsters == 0 or Duel.Destroy(monsters, REASON_RULE) == 0
				or Duel.GetLocationCount(player, LOCATION_MZONE) <= 0 then return end
			local total = 0
			for destroyed, attack in pairs(attacks) do
				if destroyed:IsReason(REASON_DESTROY) then total = total + attack end
			end
			local token = Duel.CreateToken(player, MAYHEM_TOKEN_CODE)
			for code, value in pairs({
				[EFFECT_SET_ATTACK_FINAL] = total,
				[EFFECT_CANNOT_BE_MATERIAL] = 1,
				[EFFECT_UNRELEASABLE_SUM] = 1,
				[EFFECT_UNRELEASABLE_NONSUM] = 1,
			}) do
				local rule = Effect.CreateEffect(token)
				rule:SetType(EFFECT_TYPE_SINGLE)
				rule:SetCode(code)
				rule:SetValue(value)
				token:RegisterEffect(rule)
			end
			local immune = Effect.CreateEffect(token)
			immune:SetType(EFFECT_TYPE_SINGLE)
			immune:SetCode(EFFECT_IMMUNE_EFFECT)
			immune:SetValue(function(e, other) return other:GetOwner() ~= e:GetOwner() end)
			token:RegisterEffect(immune)
			Duel.SpecialSummon(token, 0, player, player, false, false, POS_FACEUP_ATTACK)
		end)
	end,
})
