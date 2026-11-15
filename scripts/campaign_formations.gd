extends RefCounted

const BRASS := {
	1: {
		"opening": [["recruit"], ["brass_runner"], ["brass_riveter"]],
		"battle": [
			["brass_runner"], ["brass_riveter"], ["brass_shieldwright"], ["scout"], ["bruiser"],
			["brass_riveter", "recruit"], ["brass_runner", "scout"], ["brass_shieldwright", "brass_linksmith"],
			["brass_runner", "brass_linksmith"], ["brass_shieldwright", "recruit"],
		],
		"elite": [
			["veteran"], ["brass_sapper", "brass_shieldwright"], ["bruiser", "brass_linksmith"],
			["veteran", "brass_riveter"], ["brass_sapper", "scout"],
		],
	},
	2: {
		"battle": [
			["brass_springjack"], ["brass_rivet_hound"], ["brass_manifold"], ["brass_sparkbow"],
			["brass_springjack", "brass_sparkbow"], ["brass_rivet_hound", "brass_manifold"],
			["brass_sparkbow", "brass_linksmith"], ["brass_rivet_hound", "brass_runner"],
			["brass_manifold", "brass_shieldwright"], ["brass_sapper", "brass_springjack"],
		],
		"elite": [
			["brass_springjack", "brass_rivet_hound"], ["brass_sparkbow", "brass_manifold"],
			["veteran", "brass_sparkbow"], ["brass_manifold", "brass_linksmith"], ["brass_sapper", "brass_rivet_hound"],
		],
	},
	3: {
		"battle": [
			["brass_magnetar"], ["brass_grounder"], ["brass_flywheel"], ["brass_pressure_sentinel"],
			["brass_magnetar", "brass_pressure_sentinel"], ["brass_grounder", "brass_flywheel"],
			["brass_magnetar", "brass_manifold"], ["brass_grounder", "brass_riveter"],
			["brass_springjack", "brass_pressure_sentinel"], ["brass_flywheel", "brass_sparkbow"],
		],
		"elite": [
			["brass_pressure_sentinel", "brass_grounder"], ["brass_magnetar", "brass_flywheel"],
			["brass_grounder", "veteran"], ["brass_pressure_sentinel", "brass_sapper"],
			["brass_flywheel", "brass_magnetar", "brass_sparkbow"],
		],
	},
}

const CROWN := {
	1: {
		"opening": [["relay_recruit"], ["crown_page"]],
		"battle": [
			["crown_page"], ["crown_slinger"], ["crown_glaiveguard"], ["relay_runner"],
			["crown_glaiveguard", "crown_spotter"], ["crown_slinger", "crown_spotter"],
			["relay_runner", "crown_slinger"], ["crown_page", "relay_guard"],
			["crown_glaiveguard", "relay_recruit"], ["crown_slinger", "crown_page"],
		],
		"elite": [
			["relay_lancer"], ["relay_lancer", "crown_spotter"], ["crown_glaiveguard", "relay_guard"],
			["crown_glaiveguard", "crown_mender"], ["relay_lancer", "crown_slinger"],
		],
	},
	2: {
		"battle": [
			["crown_feintblade"], ["crown_twinspur"], ["crown_ballista"],
			["crown_twinspur", "crown_war_drummer"], ["crown_glaiveguard", "crown_war_drummer"],
			["crown_feintblade", "crown_ballista"], ["crown_twinspur", "crown_spotter"],
			["crown_feintblade", "relay_guard"], ["relay_runner", "crown_ballista"], ["crown_slinger", "crown_feintblade"],
		],
		"elite": [
			["crown_feintblade", "crown_war_drummer"], ["crown_twinspur", "crown_ballista"],
			["relay_lancer", "crown_war_drummer"], ["crown_feintblade", "crown_mender"],
			["crown_twinspur", "relay_guard"],
		],
	},
	3: {
		"battle": [
			["crown_storm_templar"], ["crown_banneret"], ["crown_beacon_sentry"], ["crown_oathbreaker"],
			["crown_storm_templar", "crown_banneret"], ["crown_beacon_sentry", "crown_galvanist"],
			["crown_oathbreaker", "crown_chorister"], ["crown_banneret", "crown_chorister"],
			["crown_oathbreaker", "crown_beacon_sentry"],
			["crown_ballista", "crown_galvanist"], ["crown_storm_templar", "crown_slinger"],
			["crown_banneret", "crown_feintblade"], ["crown_storm_templar", "crown_war_drummer"],
			["crown_twinspur", "crown_beacon_sentry"],
		],
		"elite": [
			["crown_storm_templar", "crown_beacon_sentry"], ["crown_banneret", "crown_galvanist"],
			["crown_storm_templar", "crown_chorister"], ["crown_oathbreaker", "crown_galvanist"],
			["crown_beacon_sentry", "crown_war_drummer"], ["crown_banneret", "crown_mender"],
			["crown_storm_templar", "crown_ballista", "crown_galvanist"],
		],
	},
}

const GLASS := {
	1: {
		"opening": [["glass_recruit"], ["glass_cullet_slinger"], ["glass_kiln_porter"]],
		"battle": [
			["glass_cullet_slinger"], ["glass_kiln_porter"], ["glass_facet_hound"], ["glass_lacquerer"],
			["glass_facet_hound", "glass_crucible_binder"], ["glass_kiln_porter", "glass_crucible_binder"],
			["glass_cullet_slinger", "glass_skirmisher"], ["glass_facet_hound", "glass_recruit"],
			["glass_kiln_porter", "glass_lacquerer"], ["glass_lacquerer", "glass_hunter"],
		],
		"elite": [
			["glass_overseer"], ["glass_duelist", "glass_crucible_binder"],
			["glass_facet_hound", "glass_lacquerer"], ["glass_kiln_porter", "glass_hunter"],
			["glass_facet_hound", "glass_cullet_slinger"],
		],
	},
	2: {
		"battle": [
			["glass_annealer", "glass_facet_hound"], ["glass_mirrorback", "glass_cullet_slinger"],
			["glass_kiln_ram", "glass_lacquerer"], ["glass_kiln_porter", "glass_lens_arbalist"],
		],
		"elite": [["glass_mirrorback", "glass_crucible_binder"], ["glass_lens_arbalist", "glass_lacquerer"]],
	},
	3: {
		"battle": [
			["glass_shard_conductor", "glass_facet_hound"], ["glass_ash_siphon", "glass_lacquerer"],
			["glass_quench_sentinel", "glass_cullet_slinger"], ["glass_furnace_knight", "glass_kiln_porter"],
		],
		"elite": [["glass_furnace_knight", "glass_crucible_binder"], ["glass_quench_sentinel", "glass_shard_conductor", "glass_cullet_slinger"]],
	},
}

const MOONWRECK := {
	1: {
		"opening": [["dock_recruit"], ["dock_saltblade"], ["dock_torchbearer"]],
		"battle": [
			["dock_saltblade"], ["dock_torchbearer"], ["dock_bilge_sapper"], ["dock_shellback"], ["dock_hull_harrier"],
			["dock_shellback", "dock_winch"], ["dock_saltblade", "dock_bilge_sapper"],
			["dock_torchbearer", "dock_hull_harrier"], ["dock_corsair", "dock_recruit"],
			["dock_hull_harrier", "dock_winch"],
		],
		"elite": [
			["dock_bruiser"], ["dock_shellback", "dock_bilge_sapper"], ["dock_bruiser", "dock_torchbearer"],
			["dock_corsair", "dock_hull_harrier"], ["dock_bruiser", "dock_saltblade"],
		],
	},
	2: {
		"battle": [
			["deck_ram", "dock_shellback"], ["tar_pitcher", "dock_hull_harrier"],
			["powder_runner", "dock_torchbearer"], ["dock_saltblade", "patch_rigger"],
		],
		"elite": [["powder_runner", "dock_bilge_sapper"], ["dock_shellback", "patch_rigger"]],
	},
	3: {
		"battle": [
			["wreck_bell", "dock_hull_harrier"], ["reef_diver", "dock_bilge_sapper"],
			["chain_warden", "dock_shellback"], ["signal_gunner", "dock_saltblade"],
		],
		"elite": [["wreck_bell", "dock_torchbearer"], ["reef_diver", "signal_gunner", "dock_hull_harrier"]],
	},
}

const ROSTERS := {"brass": BRASS, "crown": CROWN, "glass": GLASS, "moonwreck": MOONWRECK}

const COMPACT_PARTNERS := [
	"brass_linksmith", "relay_guard", "crown_war_drummer", "crown_chorister", "glass_annealer",
	"glass_crucible_binder", "patch_rigger", "dock_winch",
]


static func deploy(team: Array, kind: String, act: int, seed_value: int) -> Array:
	if kind == "opening":
		var damage := 0.65 if team[0] in ["glass_kiln_porter", "dock_torchbearer"] else 1.0
		return [_spawn(team[0], 522.0, 0.0, 0, 1.0, damage)]
	var elite := kind == "elite"
	if team.size() == 1:
		var health := 1.75 if elite else (1.15 if act == 1 else 1.47)
		if team[0] in ["bruiser", "dock_bruiser", "veteran", "relay_lancer", "glass_overseer"]:
			health = 1.03 if elite else 0.87
		return [_spawn(team[0], 610.0, 0.0, 0, health, 1.04 if elite else 1.0)]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 219733
	var flank := -1.0 if rng.randi_range(0, 1) == 0 else 1.0
	var compact := team.any(func(enemy: String): return enemy in COMPACT_PARTNERS)
	var spread := 38.0 if compact else 64.0
	var front_health := (1.17 if elite else 0.88) if act == 1 else (1.25 if elite else 1.0)
	var back_health := (0.82 if elite else 0.69) if act == 1 else (1.0 if elite else 0.82)
	var formation := [
		_spawn(team[0], 595.0, -flank * spread, 0, front_health, 1.03 if elite else 1.0),
		_spawn(team[1], 652.0, flank * spread, 16 + rng.randi_range(0, 9), back_health, 0.90),
	]
	if team.size() == 3:
		formation.append(_spawn(team[2], 711.0, -flank * 15.0, 36, 0.57, 0.78))
	return formation


static func _spawn(id: String, x: float, dy: float, delay: int, health_scale: float, damage_scale: float) -> Dictionary:
	return {"id": id, "x": x, "dy": dy, "delay": delay, "health_scale": health_scale, "damage_scale": damage_scale}
