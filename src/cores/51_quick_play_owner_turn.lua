-- Fucking Quick-Play - Quick-Play Spells may only be activated on their controller's turn.
MAYHEM.Register("51_quick_play_owner_turn", {
	apply = function()
		MAYHEM.FieldRule(EFFECT_CANNOT_ACTIVATE, function(e, effect)
			local card = effect:GetHandler()
			return card:IsType(TYPE_QUICKPLAY) and card:GetControler() ~= Duel.GetTurnPlayer()
		end, true)
	end,
})
