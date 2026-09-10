-- Mirror Mirror on the Wall - every summoned monster gives the opponent an equal-ATK Token.
MAYHEM.Register("39_mirror_mirror_on_the_wall", {
	apply = function()
		Duel.LoadScript("mayhem_token_codes.lua")
		local function mirror(e, tp, monsters)
			local monster = monsters:GetFirst()
			while monster do
				if not monster:IsType(TYPE_TOKEN) then
					local target = 1 - monster:GetControler()
					if Duel.GetLocationCount(target, LOCATION_MZONE) > 0 then
						local token = Duel.CreateToken(target, MAYHEM_TOKEN_CODE)
						local attack = Effect.CreateEffect(token)
						attack:SetType(EFFECT_TYPE_SINGLE)
						attack:SetCode(EFFECT_SET_ATTACK_FINAL)
						attack:SetValue(math.max(0, monster:GetAttack()))
						token:RegisterEffect(attack)
						Duel.SpecialSummon(token, 0, target, target, false, false, POS_FACEUP_ATTACK)
					end
				end
				monster = monsters:GetNext()
			end
		end
		MAYHEM.OnEvent(EVENT_SUMMON_SUCCESS, mirror)
		MAYHEM.OnEvent(EVENT_FLIP_SUMMON_SUCCESS, mirror)
		MAYHEM.OnEvent(EVENT_SPSUMMON_SUCCESS, mirror)
	end,
})
