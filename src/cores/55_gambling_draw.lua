-- Gambling Gambling - replace each normal draw with one die roll for both players.
MAYHEM.Register("55_gambling_draw", {
	apply = function()
		MAYHEM.FieldRule(EFFECT_DRAW_COUNT, 0, true)
		MAYHEM.OnEvent(EVENT_PREDRAW, function()
			local result = Duel.TossDice(Duel.GetTurnPlayer(), 1)
			for player = 0, 1 do
				-- A compulsory draw must reach the engine even with too few cards:
				-- its normal deck-out handling decides the result.
				Duel.Draw(player, result, REASON_RULE)
			end
		end)
	end,
})
