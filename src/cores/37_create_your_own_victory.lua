-- Create your own Victory - collect three copies of five names across public zones.
MAYHEM.Register("37_create_your_own_victory", {
	defaults = { copies = 3, names = 5 },
	apply = function(params)
		MAYHEM.OnEvent(EVENT_ADJUST, function()
			for player = 0, 1 do
				local cards = Duel.GetFieldGroup(player,
					LOCATION_ONFIELD + LOCATION_GRAVE + LOCATION_REMOVED, 0)
				local counts = {}
				local card = cards:GetFirst()
				while card do
					if not card:IsLocation(LOCATION_REMOVED) or card:IsFaceup() then
						local code = card:GetOriginalCode()
						counts[code] = (counts[code] or 0) + 1
					end
					card = cards:GetNext()
				end
				local names = 0
				for _, count in pairs(counts) do if count >= params.copies then names = names + 1 end end
				if names >= params.names then Duel.Win(player, MAYHEM.WIN_REASON) return end
			end
		end)
	end,
})
