-- Toc Chien / Speed Blitz - short clock, low starting LP.
--
-- The clock itself is not reachable from Lua: EDOPro's time limit is a room
-- setting. The host still has to set Time Limit in the room; see room_settings
-- in cores.json. Everything the engine CAN enforce is enforced here.
MAYHEM.Register("speed_blitz", {
	defaults = { lp = 4000 },
	apply = function(params)
		MAYHEM.OnStartup(function()
			MAYHEM.SetPlayerRules({ lp = params.lp })
		end)
	end,
})
