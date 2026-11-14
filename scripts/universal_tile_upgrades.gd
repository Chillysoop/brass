extends RefCounted

const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]
const RANKS := ["I", "II", "III", "IV"]
const CORE_PULL_FORCE := {"pull": 735.0, "gravity_hook": 935.0}
const TECHNIQUE_GAINS := {
	"guard_bonus": 3, "displaced_bonus": 3, "distance_bonus": 3, "windup_bonus": 3,
	"low_hp_bonus": 3, "guard_break": 3, "guard": 2, "mark_bonus": 2, "splash_damage": 2,
	"splash": 12.0, "push": 38.0, "pull": 38.0, "retreat": 10.0,
}
const AUTHORED_SIGNATURES := {
	"rampart_counter": {
		"power": [
			{"label": "Shield Reckoning", "damage": 19, "range": 158.0, "guard_spend": 5, "icon": "battle"},
			{"label": "Iron Reckoning", "damage": 22, "range": 164.0, "guard_spend": 8, "icon": "battle"},
			{"label": "Last Reckoning", "damage": 25, "range": 170.0, "guard_spend": 10, "icon": "battle"},
		],
		"technique": [
			{"label": "Stand Together", "damage": 16, "range": 158.0, "guard_bonus": 9, "ally_guard": 6},
			{"label": "Aegis Relay", "damage": 19, "range": 164.0, "guard_bonus": 11, "ally_guard": 9},
			{"label": "Aegis Pact", "damage": 22, "range": 170.0, "guard_bonus": 13, "ally_guard": 12},
		],
	},
	"gravity_spike": {
		"power": [
			{"label": "Anchor Spike", "damage": 19, "range": 505.0, "displaced_bonus": 12, "pull": 860.0},
			{"label": "Anchor Breaker", "damage": 23, "range": 540.0, "displaced_bonus": 15, "pull": 900.0},
			{"label": "Anchorfall", "damage": 27, "range": 575.0, "displaced_bonus": 18, "pull": 980.0},
		],
		"technique": [
			{"label": "Gravity Net", "damage": 17, "range": 475.0, "displaced_bonus": 10, "pull": 720.0,
				"cluster_pull_radius": 110.0, "cluster_pull_force": 370.0, "icon": "area"},
			{"label": "Gravity Well", "damage": 20, "range": 500.0, "displaced_bonus": 12, "pull": 760.0,
				"cluster_pull_radius": 145.0, "cluster_pull_force": 475.0, "icon": "area"},
			{"label": "Gravity Vortex", "damage": 23, "range": 525.0, "displaced_bonus": 14, "pull": 800.0,
				"cluster_pull_radius": 175.0, "cluster_pull_force": 570.0, "icon": "area"},
		],
	},
	"horizon_round": {
		"power": [
			{"label": "Skyline Shot", "damage": 24, "range": 750.0, "distance_bonus": 23},
			{"label": "Far Horizon", "damage": 27, "range": 785.0, "distance_bonus": 30},
			{"label": "Daybreak Shot", "damage": 28, "range": 820.0, "distance_bonus": 32},
		],
		"technique": [
			{"label": "Spotter Round", "damage": 22, "range": 720.0, "distance_bonus": 10,
				"mark_bonus": 16, "mark_beats": 4, "ally_only_mark": true},
			{"label": "Beacon Round", "damage": 24, "range": 740.0, "distance_bonus": 12,
				"mark_bonus": 22, "mark_beats": 5, "ally_only_mark": true},
			{"label": "Signal Lance", "damage": 27, "range": 760.0, "distance_bonus": 14,
				"mark_bonus": 27, "mark_beats": 5, "ally_only_mark": true},
		],
	},
	"ghost_volley": {
		"power": [
			{"label": "Rift Ambush", "damage": 27, "range": 435.0, "ranged": false, "blink_strike": true, "icon": "teleport"},
			{"label": "Veilstrike", "damage": 32, "range": 470.0, "ranged": false, "blink_strike": true, "icon": "teleport"},
			{"label": "Phantom Ambush", "damage": 38, "range": 515.0, "ranged": false, "blink_strike": true, "icon": "teleport"},
		],
		"technique": [
			{"label": "Covering Shot", "damage": 17, "range": 480.0, "retreat": 105.0,
				"ranged_followup_bonus": 12, "ranged_followup_beats": 3},
			{"label": "Ghost Feint", "damage": 20, "range": 505.0, "retreat": 118.0,
				"ranged_followup_bonus": 17, "ranged_followup_beats": 4},
			{"label": "Fadefire Volley", "damage": 23, "range": 530.0, "retreat": 130.0,
				"ranged_followup_bonus": 22, "ranged_followup_beats": 5},
		],
	},
	"collision_hammer": {
		"power": [
			{"label": "Wrecking Drive", "damage": 28, "range": 180.0, "push": 840.0, "displaced_bonus": 12, "collision_bonus": 9},
			{"label": "Rivet Ram", "damage": 32, "range": 190.0, "push": 910.0, "displaced_bonus": 14, "collision_bonus": 13},
			{"label": "Wrecking Blow", "damage": 37, "range": 200.0, "push": 980.0, "displaced_bonus": 16, "collision_bonus": 18},
		],
		"technique": [
			{"label": "Scatter Swing", "damage": 24, "range": 180.0, "push": 650.0, "displaced_bonus": 11,
				"sweep_push_radius": 118.0, "sweep_push_force": 400.0, "icon": "area"},
			{"label": "Fault Sweep", "damage": 27, "range": 190.0, "push": 700.0, "displaced_bonus": 12,
				"sweep_push_radius": 140.0, "sweep_push_force": 480.0, "icon": "area"},
			{"label": "Shatterline", "damage": 30, "range": 200.0, "push": 760.0, "displaced_bonus": 14,
				"sweep_push_radius": 162.0, "sweep_push_force": 560.0, "icon": "area"},
		],
	},
	"triage_kit": {
		"power": [
			{"label": "Emergency Dose", "guard": 14, "heal": 20},
			{"label": "Critical Care", "guard": 17, "heal": 26},
			{"label": "Lifeline Kit", "guard": 20, "heal": 32},
		],
		"technique": [
			{"label": "Triage Mist", "support": "party", "party_heal": true, "guard": 6, "heal": 9},
			{"label": "Mercy Fog", "support": "party", "party_heal": true, "guard": 8, "heal": 12},
			{"label": "Mercy Rain", "support": "party", "party_heal": true, "guard": 10, "heal": 15},
		],
	},
}


static func build(base_tiles: Dictionary) -> Dictionary:
	var specs := {}
	var families := {}
	for id: String in base_tiles:
		var original: Dictionary = base_tiles[id]
		var rarity: String = original.get("rarity", "common")
		var first := RARITIES.find(rarity)
		if original.has("family") or first < 0 or first == RARITIES.size() - 1:
			continue
		var base := original.duplicate()
		base.family = id
		base.rarity = rarity
		specs[id] = base
		var tiers: Array = []
		for tier in range(RARITIES.size()):
			var choices: Array = []
			if tier == first:
				choices.append(id)
			elif tier > first:
				for style: String in ["power", "technique"]:
					var upgraded_id := "%s_upgrade_%s_%s" % [id, RARITIES[tier], style]
					specs[upgraded_id] = _upgrade(id, base, tier, tier - first, style == "technique")
					choices.append(upgraded_id)
			tiers.append(choices)
		families[id] = tiers
	return {"specs": specs, "families": families}


static func _upgrade(id: String, base: Dictionary, tier: int, ranks: int, technique: bool) -> Dictionary:
	var tile := base.duplicate()
	tile.base_tile = id
	tile.rarity = RARITIES[tier]
	if AUTHORED_SIGNATURES.has(id):
		var choice := "technique" if technique else "power"
		if id == "rampart_counter" and not technique:
			tile.erase("guard_bonus")
		if (id == "horizon_round" and not technique) or id == "ghost_volley":
			tile.erase("mark_bonus")
			tile.erase("mark_beats")
		if id == "ghost_volley" and not technique:
			tile.erase("retreat")
		tile.merge(AUTHORED_SIGNATURES[id][choice][ranks - 1], true)
		tile.description = _describe_upgrade(tile)
		return tile
	var style: String
	if tile.damage > 0:
		style = "Keen" if technique else "Heavy"
		if CORE_PULL_FORCE.has(id):
			tile.pull = CORE_PULL_FORCE[id]
			tile.pull_before_hit = true
			tile.ranged = true
			tile.icon = "pull"
		var damage_scaling := 0.12 if technique else 0.24
		var damage_gain := maxi(1 if technique else 2, roundi(float(base.damage) * damage_scaling))
		tile.damage += damage_gain * ranks
		if technique:
			var reach_gain := 25.0 if tile.get("ranged", false) else 12.0
			tile.range += ranks * reach_gain
			for field: String in TECHNIQUE_GAINS:
				if tile.has(field):
					tile[field] += TECHNIQUE_GAINS[field] * ranks
			for force: String in ["push", "pull"]:
				if tile.has(force):
					tile[force] = minf(tile[force], 1000.0)
			if tile.has("mark_beats"):
				tile.mark_beats += floori(ranks * 0.5)
	else:
		style = "Restoring" if technique else "Warding"
		var guard_gain := 1 if technique else maxi(2, roundi(float(base.guard) * 0.30))
		tile.guard = mini(28, int(base.guard) + guard_gain * ranks)
		var heal: int = base.get("heal", 0)
		if technique or heal > 0:
			tile.heal = heal + ranks * (4 if technique else 1)
	tile.label = "%s · %s %s" % [base.label, style, RANKS[ranks - 1]]
	var caption: String = base.get("short_label", base.label)
	tile.short_label = "%s %s" % [style, caption] if tile.width == 1 else "%s %s" % [caption, style]
	tile.description = _describe_upgrade(tile)
	return tile


static func _describe_upgrade(tile: Dictionary) -> String:
	var lines := PackedStringArray()
	if tile.damage > 0:
		if tile.get("charge", false):
			lines.append("Rush the target if the path is clear.")
		if tile.get("blink_strike", false):
			lines.append("Blink beside the target and strike if there is a clear landing.")
		lines.append("%d reach." % int(tile.range))
		if tile.has("pull_before_hit"):
			lines.append("Pull the target toward you with %d force before the hit." % int(tile.pull))
		if tile.has("guard_break"):
			lines.append("Strip up to %d Guard before the hit." % tile.guard_break)
		if tile.has("guard_spend"):
			lines.append("On hit, spend up to %d Guard for 2 extra damage per Guard spent." % tile.guard_spend)
		for bonus in [
			["guard_bonus", "while you have Guard"],
			["displaced_bonus", "if the target was pushed or pulled in the last 3 beats"],
			["distance_bonus", "beyond 210 range"],
			["windup_bonus", "if the target is winding up an attack"],
			["low_hp_bonus", "if the target is below half HP"],
		]:
			if tile.has(bonus[0]):
				lines.append("Deal %d extra damage %s." % [tile[bonus[0]], bonus[1]])
		if tile.has("splash"):
			lines.append("Deal %d damage to other enemies within %d range of the target." % [tile.splash_damage, int(tile.splash)])
		if tile.has("push"):
			lines.append("Push the target with %d force." % int(tile.push))
		if tile.has("collision_bonus"):
			lines.append("If the pushed target collides with another enemy shortly afterward, deal %d extra collision damage to both." % tile.collision_bonus)
		if tile.has("sweep_push_radius"):
			lines.append("Push other enemies within %d range of the impact away from you with %d force." % [
				int(tile.sweep_push_radius), int(tile.sweep_push_force)])
		if tile.has("pull") and not tile.has("pull_before_hit"):
			lines.append("Pull the target toward you with %d force." % int(tile.pull))
		if tile.has("cluster_pull_radius"):
			lines.append("Pull other enemies within %d range toward the impact point with %d force." % [
				int(tile.cluster_pull_radius), int(tile.cluster_pull_force)])
		if tile.has("retreat"):
			lines.append("Back away by up to %d." % int(tile.retreat))
		if tile.has("ranged_followup_bonus"):
			lines.append("If you back away, your next ranged hit within %d beats deals %d extra damage." % [
				tile.ranged_followup_beats, tile.ranged_followup_bonus])
		if tile.has("mark_bonus"):
			var follow_up := "The next hit from another hero" if tile.get("ally_only_mark", false) else "The next hit"
			lines.append("%s on the target within %d beats deals %d extra damage." % [follow_up, tile.mark_beats, tile.mark_bonus])
	if tile.has("ally_guard"):
		lines.append("On hit, give %d Guard to the living ally with the lowest HP. Gain it yourself if no ally is alive." % tile.ally_guard)
	if tile.has("guard"):
		var when := " on hit." if tile.damage > 0 else "."
		match tile.get("support", ""):
			"party":
				lines.append("Give every living hero %d Guard%s" % [tile.guard, when])
			"weakest":
				lines.append("Give the lowest-HP living hero %d Guard%s" % [tile.guard, when])
			_:
				lines.append("Gain %d Guard%s" % [tile.guard, when])
	if tile.has("heal"):
		var recipient := "yourself"
		if tile.get("party_heal", false):
			recipient = "each living hero"
		elif tile.get("support") == "weakest":
			recipient = "the lowest-HP living hero"
		lines.append("Restore up to %d HP to %s once per fight." % [tile.heal, recipient])
	return " ".join(lines)
