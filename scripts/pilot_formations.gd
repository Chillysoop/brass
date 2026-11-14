extends RefCounted

const GLASS := {
	2: {
		"battle": [
			["glass_mirrorback"], ["glass_lens_arbalist"], ["glass_kiln_ram"],
			["glass_mirrorback", "glass_lens_arbalist"], ["glass_kiln_ram", "glass_annealer"],
			["glass_mirrorback", "glass_skirmisher"], ["glass_kiln_ram", "glass_hunter"],
			["glass_duelist", "glass_lens_arbalist"],
		],
		"elite": [
			["glass_mirrorback", "glass_annealer"], ["glass_kiln_ram", "glass_lens_arbalist"],
			["glass_kiln_ram", "glass_duelist"], ["glass_mirrorback", "glass_hunter"],
		],
	},
	3: {
		"battle": [
			["glass_shard_conductor"], ["glass_ash_siphon"], ["glass_quench_sentinel"], ["glass_furnace_knight"],
			["glass_furnace_knight", "glass_shard_conductor"], ["glass_quench_sentinel", "glass_ash_siphon"],
			["glass_quench_sentinel", "glass_annealer"], ["glass_furnace_knight", "glass_lens_arbalist"],
			["glass_kiln_ram", "glass_shard_conductor"],
		],
		"elite": [
			["glass_furnace_knight", "glass_ash_siphon"], ["glass_quench_sentinel", "glass_shard_conductor"],
			["glass_furnace_knight", "glass_mirrorback"], ["glass_shard_conductor", "glass_duelist"],
		],
	},
}

const MOONWRECK := {
	2: {
		"battle": [
			["tar_pitcher"], ["deck_ram"], ["dock_corsair"], ["dock_bruiser"],
			["deck_ram", "patch_rigger"], ["tar_pitcher", "powder_runner"],
			["dock_corsair", "powder_runner"], ["dock_bruiser", "patch_rigger"], ["deck_ram", "dock_recruit"],
		],
		"elite": [
			["powder_runner"],
			["deck_ram", "powder_runner"], ["powder_runner", "patch_rigger"],
			["dock_corsair", "tar_pitcher"], ["deck_ram", "dock_winch"],
		],
	},
	3: {
		"battle": [
			["reef_diver"], ["signal_gunner"], ["chain_warden"], ["powder_runner"], ["deck_ram"],
			["chain_warden", "reef_diver"], ["wreck_bell", "signal_gunner"],
			["chain_warden", "tar_pitcher"], ["wreck_bell", "patch_rigger"], ["deck_ram", "signal_gunner"],
		],
		"elite": [
			["wreck_bell"],
			["chain_warden", "signal_gunner"], ["wreck_bell", "reef_diver"],
			["wreck_bell", "powder_runner"], ["reef_diver", "dock_corsair"],
		],
	}
}


static func choose(location: String, act: int, kind: String, seed_value: int, history: Array) -> Array:
	var region := GLASS if location == "glass" else MOONWRECK
	if location not in ["glass", "moonwreck"] or not region.has(act) or not region[act].has(kind):
		return []
	var formations: Array = region[act][kind]
	var recent: Array = []
	var sightings := {}
	var recent_limit := 2 if kind == "battle" else 1
	for entry: Dictionary in history:
		for enemy: String in entry.enemies:
			sightings[enemy] = int(sightings.get(enemy, 0)) + 1
		if entry.kind == kind:
			recent.append(_lineup(entry.enemies))
			if recent.size() > recent_limit:
				recent.pop_front()

	var eligible := formations.filter(func(team: Array): return _lineup(team) not in recent)
	if eligible.is_empty():
		eligible = formations
	var best_score := -100000
	var best: Array = []
	for team: Array in eligible:
		var unfamiliar := 0
		var prior_sightings := 0
		for enemy: String in team:
			var count := int(sightings.get(enemy, 0))
			unfamiliar += int(count == 0)
			prior_sightings += count
		# Give fresh solos and fresh teams the same chance so that first
		# appearances are spread across the route.
		var score := roundi(100.0 * unfamiliar / team.size()) - prior_sightings
		if score > best_score:
			best_score = score
			best = [team]
		elif score == best_score:
			best.append(team)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return _deployment(best[rng.randi_range(0, best.size() - 1)], kind == "elite")


static func _lineup(team: Array) -> Array:
	var sorted := team.duplicate()
	sorted.sort()
	return sorted


static func _deployment(team: Array, elite: bool) -> Array:
	if team.size() == 1:
		var health_scale := 1.8 if elite else 1.55
		if team[0] == "dock_bruiser":
			health_scale = 1.10
		return [_spawn(team[0], 615.0, 0.0, 0, health_scale, 1.05 if elite else 1.0)]
	if elite:
		return [
			_spawn(team[0], 622.0, -49.0, 0, 1.32, 1.06),
			_spawn(team[1], 692.0, 88.0, 22, 1.05, 1.0),
		]
	return [
		_spawn(team[0], 599.0, -57.0, 0, 1.0, 1.0),
		_spawn(team[1], 654.0, 69.0, 18, 0.8, 0.9),
	]


static func _spawn(id: String, x: float, dy: float, delay: int, health_scale: float, damage_scale: float) -> Dictionary:
	return {"id": id, "x": x, "dy": dy, "delay": delay, "health_scale": health_scale, "damage_scale": damage_scale}
