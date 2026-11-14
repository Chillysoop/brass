extends RefCounted

const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]
const RANKS := ["I", "II", "III", "IV"]
const CORE_PULL_FORCE := {"pull": 735.0, "gravity_hook": 935.0}
const TECHNIQUE_GAINS := {
	"guard_bonus": 3, "displaced_bonus": 3, "distance_bonus": 3, "windup_bonus": 3,
	"low_hp_bonus": 3, "guard_break": 3, "guard": 2, "mark_bonus": 2, "splash_damage": 2,
	"splash": 12.0, "push": 38.0, "pull": 38.0, "retreat": 10.0,
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
		lines.append("%d reach." % int(tile.range))
		if tile.has("pull_before_hit"):
			lines.append("Pull the target with %d force before the hit." % int(tile.pull))
		if tile.has("guard_break"):
			lines.append("Strip up to %d Guard before the hit." % tile.guard_break)
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
		if tile.has("pull") and not tile.has("pull_before_hit"):
			lines.append("Pull the target with %d force." % int(tile.pull))
		if tile.has("retreat"):
			lines.append("Back away by up to %d." % int(tile.retreat))
		if tile.has("mark_bonus"):
			lines.append("The next hit on the target within %d beats deals %d extra damage." % [tile.mark_beats, tile.mark_bonus])
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
		var recipient := "the lowest-HP living hero" if tile.get("support") == "weakest" else "yourself"
		lines.append("Restore up to %d HP to %s once per fight." % [tile.heal, recipient])
	return " ".join(lines)
