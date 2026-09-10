-- It should has been mine - mill the top card immediately before each normal draw.
MAYHEM.Register("24_it_should_have_been_mine", {
	apply = function()
		MAYHEM.OnEvent(EVENT_PREDRAW, function()
			local player = Duel.GetTurnPlayer()
			local top = Duel.GetDecktopGroup(player, 1)
			if #top > 0 then Duel.SendtoGrave(top, REASON_RULE) end
		end)
	end,
})
