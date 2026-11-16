extends RefCounted

const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]
const RANKS := ["I", "II", "III", "IV"]
const CORE_PULL_FORCE := {"pull": 735.0, "gravity_hook": 935.0}
const TECHNIQUE_GAINS := {
	"guard_bonus": 3, "displaced_bonus": 3, "distance_bonus": 3, "windup_bonus": 3,
	"low_hp_bonus": 3, "guard_break": 3, "guard": 2, "mark_bonus": 2, "splash_damage": 2,
	"splash": 12.0, "push": 38.0, "pull": 38.0, "retreat": 10.0,
	"dash_followup_damage": 2, "long_critical_bonus": 0.05,
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
	"runic_anvil": {
		"power": [
			{"label": "Weight Rune", "damage": 34, "range": 170.0, "guard_break": 12, "rune_heavy_bonus": 10},
			{"label": "Siege Rune", "damage": 38, "range": 180.0, "guard_break": 14, "rune_heavy_bonus": 14},
			{"label": "Titan Rune", "damage": 42, "range": 190.0, "guard_break": 16, "rune_heavy_bonus": 19},
		],
		"technique": [
			{"label": "Spark Anvil", "damage": 31, "range": 170.0, "splash_damage": 15,
				"rune_quick_bonus": 4, "rune_quick_hits": 2, "icon": "forge"},
			{"label": "Ember Anvil", "damage": 34, "range": 175.0, "splash_damage": 17,
				"rune_quick_bonus": 5, "rune_quick_hits": 3, "icon": "forge"},
			{"label": "Star Anvil", "damage": 37, "range": 185.0, "splash_damage": 19,
				"rune_quick_bonus": 6, "rune_quick_hits": 3, "icon": "forge"},
		],
	},
	"needle_point": {
		"power": [
			{"label": "Needle Lock", "short_label": "Lock", "damage": 8, "duel_stack_gain": 3, "duel_stack_cap": 9},
			{"label": "Piercing Rhythm", "short_label": "Rhythm", "damage": 9, "range": 130.0,
				"duel_stack_gain": 4, "duel_stack_cap": 12},
			{"label": "Master's Point", "short_label": "Point", "damage": 10, "range": 135.0,
				"duel_stack_gain": 5, "duel_stack_cap": 15},
		],
		"technique": [
			{"label": "Passing Cut", "short_label": "Passing", "damage": 8, "low_hp_bonus": 6, "duel_kill_bonus": 8},
			{"label": "Victor's Step", "short_label": "Victor", "damage": 9, "range": 130.0, "low_hp_bonus": 7,
				"duel_kill_bonus": 11},
			{"label": "Finishing Dance", "short_label": "Dance", "damage": 10, "range": 135.0, "low_hp_bonus": 8,
				"duel_kill_bonus": 14},
		],
	},
	"chorus_bolt": {
		"power": [
			{"label": "Battle Chorus", "damage": 15, "range": 465.0, "guard": 7, "chorus_mark_bonus": 11, "chorus_mark_beats": 4},
			{"label": "War Choir", "damage": 18, "range": 485.0, "guard": 8, "chorus_mark_bonus": 14, "chorus_mark_beats": 5},
			{"label": "Grand Refrain", "damage": 21, "range": 510.0, "guard": 10, "chorus_mark_bonus": 17, "chorus_mark_beats": 6},
		],
		"technique": [
			{"label": "Ward Chime", "damage": 14, "range": 465.0, "guard": 8,
				"chorus_guard": 5, "chorus_guard_beats": 4, "icon": "guard"},
			{"label": "Shield Hymn", "damage": 16, "range": 485.0, "guard": 10,
				"chorus_guard": 7, "chorus_guard_beats": 5, "icon": "guard"},
			{"label": "Sanctuary Song", "damage": 19, "range": 510.0, "guard": 12,
				"chorus_guard": 9, "chorus_guard_beats": 6, "icon": "guard"},
		],
	},
	"bastion_oath": {
		"power": [
			{"label": "Vigil Strike", "damage": 20, "range": 180.0, "guard_bonus": 11, "guard": 13, "support": "weakest"},
			{"label": "Guardian's Vow", "damage": 24, "range": 190.0, "guard_bonus": 13, "guard": 16, "support": "weakest"},
			{"label": "Last Bulwark", "damage": 28, "range": 200.0, "guard_bonus": 15, "guard": 20, "support": "weakest"},
		],
		"technique": [
			{"label": "Shield Beacon", "damage": 19, "range": 180.0, "guard": 7, "support": "self",
				"bastion_block_threshold": 6, "bastion_party_guard": 7, "bastion_beats": 5},
			{"label": "Bastion Relay", "damage": 22, "range": 190.0, "guard": 8, "support": "self",
				"bastion_block_threshold": 7, "bastion_party_guard": 9, "bastion_beats": 6},
			{"label": "Unbroken Line", "damage": 25, "range": 200.0, "guard": 9, "support": "self",
				"bastion_block_threshold": 8, "bastion_party_guard": 11, "bastion_beats": 7},
		],
	},
	"comet_charge": {
		"power": [
			{"label": "Running Lance", "damage": 23, "range": 440.0, "push": 660.0, "windup_bonus": 6, "lance_travel_bonus": 12},
			{"label": "Meteor Run", "damage": 27, "range": 475.0, "push": 700.0, "windup_bonus": 7, "lance_travel_bonus": 16},
			{"label": "Thunder Gallop", "damage": 31, "range": 510.0, "push": 750.0, "windup_bonus": 8, "lance_travel_bonus": 20},
		],
		"technique": [
			{"label": "Second Pass", "damage": 22, "range": 430.0, "push": 725.0, "windup_bonus": 6,
				"lance_return_bonus": 10, "lance_return_beats": 4},
			{"label": "Turnback Charge", "damage": 25, "range": 465.0, "push": 780.0, "windup_bonus": 7,
				"lance_return_bonus": 14, "lance_return_beats": 5},
			{"label": "Comet's Return", "damage": 28, "range": 500.0, "push": 830.0, "windup_bonus": 8,
				"lance_return_bonus": 18, "lance_return_beats": 6},
		],
	},
	"cinder_wave": {
		"power": [
			{"label": "Coal Brand", "damage": 18, "range": 345.0, "splash_damage": 11,
				"ember_burn_damage": 4, "ember_burn_ticks": 3},
			{"label": "Kilnbrand", "damage": 21, "range": 365.0, "splash_damage": 12,
				"ember_burn_damage": 5, "ember_burn_ticks": 4},
			{"label": "Evercoal", "damage": 24, "range": 385.0, "splash_damage": 14,
				"ember_burn_damage": 5, "ember_burn_ticks": 5},
		],
		"technique": [
			{"label": "Ember Wake", "damage": 16, "range": 345.0, "splash_damage": 12,
				"ember_burn_damage": 4, "ember_burn_ticks": 2, "ember_burn_radius": 142.0},
			{"label": "Cinder Bloom", "damage": 19, "range": 365.0, "splash_damage": 14,
				"ember_burn_damage": 5, "ember_burn_ticks": 2, "ember_burn_radius": 165.0},
			{"label": "Ashstorm", "damage": 22, "range": 385.0, "splash_damage": 17,
				"ember_burn_damage": 6, "ember_burn_ticks": 2, "ember_burn_radius": 185.0},
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
		if (id == "horizon_round" and not technique) or id in ["ghost_volley", "chorus_bolt"]:
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
		if tile.has("dash_followup_damage"):
			lines.append("If you dashed or backstepped in the last %d beats, land a second hit for %d damage." % [
				tile.dash_followup_beats, tile.dash_followup_damage])
		if tile.has("long_critical_bonus"):
			lines.append("From more than 210 units away, add %d percentage points to this shot's critical chance." % [
				roundi(tile.long_critical_bonus * 100.0)])
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
		if tile.has("rune_heavy_bonus"):
			lines.append("On hit, empower your next attack tile at least 3 beats wide within 12 beats. Its first target takes %d extra damage." % tile.rune_heavy_bonus)
		if tile.has("rune_quick_bonus"):
			lines.append("On hit, empower your next %d attack tiles 1–2 beats wide within 12 beats. Each deals %d extra damage to its first target." % [
				tile.rune_quick_hits, tile.rune_quick_bonus])
		if tile.has("duel_stack_gain"):
			lines.append("Repeat Needle Point hits on the same enemy build %d bonus damage per repeat, up to %d. Hitting another enemy resets the bonus." % [
				tile.duel_stack_gain, tile.duel_stack_cap])
		if tile.has("duel_kill_bonus"):
			lines.append("On kill, your next hit on another enemy within 12 beats deals %d extra damage." % tile.duel_kill_bonus)
		if tile.has("chorus_mark_bonus"):
			lines.append("Mark the target for %d beats. Up to two other heroes each deal %d extra damage on their first hit against it." % [
				tile.chorus_mark_beats, tile.chorus_mark_bonus])
		if tile.has("chorus_guard"):
			lines.append("Mark the target for %d beats. The next hit on it from another hero gives all living heroes %d Guard." % [
				tile.chorus_guard_beats, tile.chorus_guard])
		if tile.has("lance_travel_bonus"):
			lines.append("Gain up to %d damage for walking 80 units. Hitting with this upgrade resets the distance." % tile.lance_travel_bonus)
		if tile.has("lance_return_bonus"):
			lines.append("If this hit pushes an enemy, your next charging hit within %d beats deals %d extra damage." % [
				tile.lance_return_beats, tile.lance_return_bonus])
		if tile.has("ember_burn_damage"):
			var burn_target := "the target"
			if tile.has("ember_burn_radius"):
				burn_target = "surviving enemies within %d range of the impact" % int(tile.ember_burn_radius)
			lines.append("If the target was pushed or pulled in the last 3 beats, burn %s for %d damage per beat for %d beats." % [
				burn_target, tile.ember_burn_damage, tile.ember_burn_ticks])
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
	if tile.has("bastion_block_threshold"):
		lines.append("On hit, ready a ward for %d beats. Absorb at least %d damage with Guard from a single enemy hit to give each living hero %d Guard once." % [
			tile.bastion_beats, tile.bastion_block_threshold, tile.bastion_party_guard])
	if tile.has("heal"):
		var recipient := "yourself"
		if tile.get("party_heal", false):
			recipient = "each living hero"
		elif tile.get("support") == "weakest":
			recipient = "the lowest-HP living hero"
		lines.append("Restore up to %d HP to %s once per fight." % [tile.heal, recipient])
	return " ".join(lines)
