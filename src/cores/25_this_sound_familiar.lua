-- This sound familiar - duplicate names in the Main Deck cause a startup loss.
MAYHEM.Register("25_this_sound_familiar", {
	apply = function()
		MAYHEM.OnStartup(function()
			local illegal = {}
			for player = 0, 1 do
				local seen = {}
				local deck = Duel.GetFieldGroup(player, LOCATION_DECK, 0)
				local card = deck:GetFirst()
				while card do
					local code = card:GetOriginalCode()
					if seen[code] then illegal[player + 1] = true break end
					seen[code] = true
					card = deck:GetNext()
				end
			end
			if illegal[1] and illegal[2] then Duel.Win(PLAYER_NONE, MAYHEM.WIN_REASON)
			elseif illegal[1] then Duel.Win(1, MAYHEM.WIN_REASON)
			elseif illegal[2] then Duel.Win(0, MAYHEM.WIN_REASON) end
		end)
	end,
})
