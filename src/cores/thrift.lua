-- Tiet Kiem / Thrift - changes how many cards the turn player draws each turn.
-- draw = 0 turns the Draw Phase into a dead phase, which is the Gold variant.
MAYHEM.Register("thrift", {
	defaults = { draw = 2 },
	apply = function(params)
		MAYHEM.FieldRule(EFFECT_DRAW_COUNT, params.draw, true)
	end,
})
