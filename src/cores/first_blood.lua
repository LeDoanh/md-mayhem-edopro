-- Nhat Kich / First Blood - the first player to take battle damage loses.
MAYHEM.Register("first_blood", {
	apply = function()
		-- ep is the player the battle damage was dealt to.
		MAYHEM.OnEvent(EVENT_BATTLE_DAMAGE, function(e, tp, eg, ep)
			Duel.Win(1 - ep, MAYHEM.WIN_REASON)
		end, 1)
	end,
})
