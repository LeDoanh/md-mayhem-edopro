-- Break the Loop - send all face-up Continuous Spells/Traps to the GY at End Phase.
MAYHEM.Register("54_break_the_loop", {
	apply = function()
		MAYHEM.OnEvent(EVENT_PHASE + PHASE_END, function()
			local function continuous(card)
				return card:IsFaceup() and card:IsType(TYPE_CONTINUOUS)
					and card:IsType(TYPE_SPELL + TYPE_TRAP)
			end
			local cards = Duel.GetMatchingGroup(continuous, 0, LOCATION_SZONE, LOCATION_SZONE, nil)
			if #cards > 0 then Duel.SendtoGrave(cards, REASON_RULE) end
		end)
	end,
})
