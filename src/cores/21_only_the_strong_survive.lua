-- Only The Strong Survie - each field loses one lowest-ATK monster at End Phase.
MAYHEM.Register("21_only_the_strong_survive", {
	apply = function()
		MAYHEM.OnPhase(PHASE_END, function()
			for player = 0, 1 do
				local monsters = Duel.GetMatchingGroup(Card.IsFaceup,
					player, LOCATION_MZONE, 0, nil)
				if #monsters > 0 then
					local weakest = monsters:GetMinGroup(Card.GetAttack)
					if #weakest > 1 then
						Duel.Hint(HINT_SELECTMSG, player, HINTMSG_DESTROY)
						weakest = weakest:Select(player, 1, 1, nil)
					end
					Duel.Destroy(weakest, REASON_RULE)
				end
			end
		end)
	end,
})
