-- First turn advantage Silver - first-turn effects cannot have activation/effect negated.
MAYHEM.Register("35_first_turn_advantage_silver", {
	apply = function()
		-- This expires at the end of the duel's first Draw Phase. Avoid consulting
		-- Duel.GetDrawCount from an EFFECT_DRAW_COUNT value callback: doing so asks
		-- the engine to evaluate the same effect recursively.
		local draw = Effect.GlobalEffect()
		draw:SetType(EFFECT_TYPE_FIELD)
		draw:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
		draw:SetCode(EFFECT_DRAW_COUNT)
		draw:SetTargetRange(1, 1)
		draw:SetValue(1)
		draw:SetReset(RESET_PHASE + PHASE_DRAW)
		Duel.RegisterEffect(draw, 0)
		-- DRAW_COUNT cannot enable the first player's otherwise-skipped draw.
		-- PREDRAW respects a skipped Draw Phase; rooms that already draw on turn
		-- one keep the engine's draw instead of receiving a second copy here.
		MAYHEM.OnEvent(EVENT_PREDRAW, function()
			if Duel.GetTurnCount() == 1 and not Duel.IsDuelType(DUEL_1ST_TURN_DRAW) then
				Duel.Draw(Duel.GetTurnPlayer(), 1, REASON_RULE)
			end
		end)
		local function protected(e, chain)
			local _, player = Duel.GetChainInfo(chain, CHAININFO_TRIGGERING_EFFECT, CHAININFO_TRIGGERING_PLAYER)
			return Duel.GetTurnCount() <= 2 and player == Duel.GetTurnPlayer()
		end
		MAYHEM.FieldRule(EFFECT_CANNOT_INACTIVATE, protected)
		MAYHEM.FieldRule(EFFECT_CANNOT_DISEFFECT, protected)
	end,
})
