local lane_eq = {}

function lane_eq.checkEqualibrium(lane)
	return lane_eq
end

function lane_eq.giveLastHitQueue(enemy_creeps, friendly_creeps)
	local attack_queue = {}
	
	enemy_creeps.sort(a, function(a, b)
		return a.GetHealth() < b.GetHealth()
	end)
	
	friendly_creeps.sort(a, function(a, b)
		return a.GetHealth() < b.GetHealth()
	end)
	
	-- TODO Actually implement intelligence around this
	attack_queue[1] = {enemy_creeps[1], 100}
	attack_queue[2] = {enemy_creeps[2], 100}
	
	return attack_queue
end

return lane_eq