-- There can be only one kind - each Extra Deck summon type may be used once per player.
MAYHEM.Register("26_there_can_be_only_one_kind", {
	apply = function()
		local used = { {}, {} }
		local kinds = { TYPE_FUSION, TYPE_SYNCHRO, TYPE_XYZ, TYPE_LINK }
		local function kind(card)
			for _, value in ipairs(kinds) do if card:IsType(value) then return value end end
		end
		MAYHEM.PlayerRestriction(EFFECT_CANNOT_SPECIAL_SUMMON, function(e, card, player)
			local value = kind(card)
			return card:IsLocation(LOCATION_EXTRA) and value and used[player + 1][value] or false
		end)
		MAYHEM.OnEvent(EVENT_SPSUMMON_SUCCESS, function(e, tp, cards)
			local card = cards:GetFirst()
			while card do
				local value = kind(card)
				if value and card:IsSummonLocation(LOCATION_EXTRA) then
					used[card:GetSummonPlayer() + 1][value] = true
				end
				card = cards:GetNext()
			end
		end)
	end,
})
