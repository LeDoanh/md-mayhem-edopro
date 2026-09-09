-- MD Mayhem - operator config.
--
-- Per-match core selection does NOT happen here. The host picks a core in the
-- client, by typing a code into the Host window's Starting LP box:
--
--   Starting LP = 1000000 + <core code>      e.g. 1000008 = Han Dien Vang
--
-- Run `python tools/list-codes.py` for the current list. The catalogue lives in
-- cores.json and is compiled to mayhem_catalogue.lua by build-catalogue.py.
-- A normal Starting LP (anything below 1000000) is left completely alone, so
-- casual and AI games are unaffected.
--
-- This file only holds settings that apply to every match. Edit the installed
-- copy at <EDOPro>/expansions/script/mdmayhem/mayhem_config.lua; changes take
-- effect on the next duel, no restart needed.

MAYHEM_CONFIG = {
	-- Progress notes for diagnosing a core. Leave off: EDOPro labels every
	-- script message "Script Error" and prints it in red in the duel chat, so
	-- this looks alarming even when everything is fine. Real problems (an
	-- unknown code, a broken core) are reported either way.
	debug = false,

	-- Cores forced on in every duel, whatever the host typed. Normally empty:
	-- an entry here also applies to your casual and AI games.
	enabled = {},

	-- Parameter overrides for the cores listed in `enabled` above.
	params = {},
}
