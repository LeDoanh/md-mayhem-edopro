-- Speed-duel Mentioned? - verifies the room flag that Lua cannot change itself.
MAYHEM.Register("52_speed_duel_mentioned", {
	apply = function()
		MAYHEM.OnStartup(function()
			if not Duel.IsDuelType(DUEL_MODE_SPEED) then
				MAYHEM.Warn("Speed-duel Mentioned? requires the host to select Speed Duel mode")
			end
		end)
	end,
})
