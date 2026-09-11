-- Droll and Lock Bird is looking at you - cap non-normal-draw cards added per turn.
MAYHEM.Register("31_droll_lock_limit", {
	defaults = { max_cards = 5 },
	apply = function(params)
		local added = { 0, 0 }
		-- EFFECT_CANNOT_DRAW is read by presence only (field::is_player_can_draw
		-- -> is_player_affected_by_effect), so a predicate on it would never be
		-- consulted and every effect draw would be banned for the whole duel.
		-- The lock is therefore registered per player once the quota runs out and
		-- removed again when the quota resets.
		local draw_lock = {}
		local function lock_draws(player)
			if draw_lock[player + 1] then return end
			local e = Effect.GlobalEffect()
			e:SetType(EFFECT_TYPE_FIELD)
			e:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
			e:SetCode(EFFECT_CANNOT_DRAW)
			e:SetTargetRange(1, 0) -- only the player this effect is registered for
			Duel.RegisterEffect(e, player)
			draw_lock[player + 1] = e
		end
		MAYHEM.OnEvent(EVENT_PHASE_START + PHASE_DRAW, function()
			added = { 0, 0 }
			for player = 0, 1 do
				local lock = draw_lock[player + 1]
				if lock then
					lock:Reset()
					draw_lock[player + 1] = nil
				end
			end
		end)
		MAYHEM.OnEvent(EVENT_TO_HAND, function(e, tp, cards)
			local card = cards:GetFirst()
			while card do
				if not (Duel.IsPhase(PHASE_DRAW) and card:IsReason(REASON_DRAW)) then
					local player = card:GetControler()
					if card:IsLocation(LOCATION_HAND) then
						added[player + 1] = added[player + 1] + 1
						if added[player + 1] >= params.max_cards then lock_draws(player) end
					end
				end
				card = cards:GetNext()
			end
		end)
		local to_hand = Effect.GlobalEffect()
		to_hand:SetType(EFFECT_TYPE_FIELD)
		to_hand:SetCode(EFFECT_CANNOT_TO_HAND)
		to_hand:SetTargetRange(LOCATION_ALL, LOCATION_ALL)
		to_hand:SetTarget(function(e, card)
			-- A stolen card returns to its owner's hand, not its controller's.
			return added[card:GetOwner() + 1] >= params.max_cards
		end)
		Duel.RegisterEffect(to_hand, 0)
	end,
})
