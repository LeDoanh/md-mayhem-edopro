-- MD Mayhem - EDOPro mutation-core plugin entry point.
--
-- EDOPro loads "./init.lua" into EVERY duel it creates, right after constant.lua
-- and utility.lua (gframe/game.cpp: Game::PopulateResourcesDirectories +
-- Game::SetupDuel). That makes this file the one and only hook the plugin needs.
--
-- Nothing is implemented here on purpose: the real modules live in
-- expansions/script/mdmayhem/ so this file never has to change again.
-- Duel.LoadScript resolves plain file names against EDOPro's script search
-- paths, which include every direct subfolder of expansions/script/.

local function load_plugin()
	if not (Duel and Duel.LoadScript) then
		return false, "this core has no Duel.LoadScript"
	end
	if Duel.LoadScript("mayhem_bootstrap.lua") then
		return true
	end
	-- Game::PopulateResourcesDirectories scans expansions/script/ once, at
	-- startup. A client that was already running when the plugin was installed
	-- never sees the folder, so the duel would otherwise just run stock rules
	-- with the typed code left sitting in the life points.
	return false, "mayhem_bootstrap.lua not found - restart EDOPro after installing"
end

local ok, reason = load_plugin()
if not ok and Debug and Debug.Message then
	Debug.Message("[MAYHEM] plugin did not load: " .. reason)
end
