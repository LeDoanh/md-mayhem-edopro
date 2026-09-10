-- Energy Dominate - 12 energy, refreshed at own Standby; actions spend 2 or 4.
MAYHEM.Register("56_energy_dominate", {
	defaults = { max_energy = 12, normal_cost = 2, quick_cost = 4 },
	apply = function(params)
		local energy = { params.max_energy, params.max_energy }
		local summon_pending = { false, false }
		local function announce(player, reason)
			MAYHEM.AnnounceEnergy(player, energy[player + 1], params.max_energy, reason)
		end
		local function spend(player, amount)
			energy[player + 1] = energy[player + 1] - amount
			announce(player, "spent " .. amount)
		end
		MAYHEM.OnStartup(function() announce(0, "started") announce(1, "started") end)
		MAYHEM.OnEvent(EVENT_PHASE_START + PHASE_STANDBY, function()
			local player = Duel.GetTurnPlayer()
			energy[player + 1] = params.max_energy
			announce(player, "refreshed")
		end)

		local activation = Effect.GlobalEffect()
		activation:SetType(EFFECT_TYPE_FIELD)
		activation:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
		activation:SetCode(EFFECT_ACTIVATE_COST)
		activation:SetTargetRange(1, 1)
		local function activation_cost(effect)
			local card = effect:GetHandler()
			if card:IsType(TYPE_QUICKPLAY + TYPE_COUNTER)
				or effect:IsHasType(EFFECT_TYPE_QUICK_O | EFFECT_TYPE_QUICK_F) then
				return params.quick_cost
			end
			if card:IsType(TYPE_SPELL + TYPE_TRAP) then return params.normal_cost end
			return 0
		end
		activation:SetTarget(function(e, effect) return activation_cost(effect) > 0 end)
		activation:SetCost(function(e, effect, player)
			local cost = activation_cost(effect)
			e:SetLabel(cost)
			return energy[player + 1] >= cost
		end)
		activation:SetOperation(function(e, player) spend(player, e:GetLabel()) end)
		Duel.RegisterEffect(activation, 0)

		local summon = Effect.GlobalEffect()
		summon:SetType(EFFECT_TYPE_FIELD)
		summon:SetCode(EFFECT_SPSUMMON_COST)
		summon:SetTargetRange(LOCATION_ALL, LOCATION_ALL)
		summon:SetTarget(function(e, card) return card:IsType(TYPE_MONSTER) end)
		summon:SetCost(function(e, card, player) return energy[player + 1] >= params.normal_cost end)
		summon:SetOperation(function(e, player)
			-- The core invokes this once per monster in a simultaneous summon. Treat
			-- that group as one action and pay exactly once; the completion event
			-- releases the guard for the next summon action.
			if not summon_pending[player + 1] then
				summon_pending[player + 1] = true
				spend(player, params.normal_cost)
			end
		end)
		Duel.RegisterEffect(summon, 0)
		local function finish_summon(e, tp, cards)
			local card = cards:GetFirst()
			while card do
				summon_pending[card:GetSummonPlayer() + 1] = false
				card = cards:GetNext()
			end
		end
		MAYHEM.OnEvent(EVENT_SPSUMMON_SUCCESS, finish_summon)
		MAYHEM.OnEvent(EVENT_SPSUMMON_NEGATED, finish_summon)
	end,
})
