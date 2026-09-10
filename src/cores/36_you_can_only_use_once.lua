-- You can only use ONCE - after a chain resolves, banish matching hand/Deck copies face-down.
MAYHEM.Register("36_you_can_only_use_once", {
	apply = function()
		MAYHEM.OnEvent(EVENT_CHAIN_SOLVED, function(e, tp, eg, ep, ev, effect, reason, player)
			if not effect or player == PLAYER_NONE then return end
			local handler = effect:GetHandler()
			if not handler then return end
			local code = handler:GetOriginalCode()
			local copies = Duel.GetMatchingGroup(Card.IsOriginalCode, player,
				LOCATION_HAND + LOCATION_DECK, 0, nil, code)
			if #copies > 0 then Duel.Remove(copies, POS_FACEDOWN, REASON_RULE) end
		end)
	end,
})
