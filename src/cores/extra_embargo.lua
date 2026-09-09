-- Gioi Han / Extra Embargo - caps Extra Deck size.
--
-- EDOPro's deck checker cannot express "at most N Extra Deck cards", so the
-- rule is enforced as an automatic referee call at duel start: a player who
-- brought an oversized Extra Deck loses the game before turn 1.
MAYHEM.Register("extra_embargo", {
	defaults = { max_extra = 6 },
	apply = function(params)
		MAYHEM.OnStartup(function()
			for player = 0, 1 do
				local count = Duel.GetFieldGroupCount(player, LOCATION_EXTRA, 0)
				if count > params.max_extra then
					MAYHEM.Warn("player " .. player .. " lost: extra deck "
						.. count .. " > " .. params.max_extra)
					Duel.Win(1 - player, MAYHEM.WIN_REASON)
					return
				end
			end
		end)
	end,
})
