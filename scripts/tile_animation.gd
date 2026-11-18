extends RefCounted

const Catalog = preload("res://scripts/tile_animation_catalog.gd")
const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]
const CORE_POWER := [
	"shield_ram", "bulwark_charge", "sunwall", "dawn_bastion",
	"phase_cut", "rift_lunge", "void_dance", "starfall_step",
	"longshot", "deadeye", "rail_shot", "star_piercer",
	"riposte", "counterwall", "iron_rebuke", "last_stand",
	"shockwave", "quake", "fault_line", "worldbreaker",
]
const CORE_TECHNIQUE := [
	"hook_bash", "rebound", "graviton", "event_horizon",
	"ward_step", "mirror_step", "prism_stride", "sanctuary_gate",
	"split_shot", "volley", "flak_burst", "meteor_volley",
	"rally_guard", "ward_link", "shield_chorus", "aegis_network",
	"sundering_slam", "armor_crush", "hammerfall", "skybreaker",
]

# More specialized effects precede general contact flourishes in a crowded fight.
const FEATURE_FIELDS := {
	"overflow": ["heal_overflow_guard", "heal_overflow_on_hit"],
	"intercept": ["intercept_guard"],
	"harmony": ["harmony_guard", "chorus_guard"],
	"echo": ["chorus_echo_damage", "blink_echo_damage"],
	"rune": ["rune_heavy_bonus", "rune_quick_bonus"],
	"chain": ["collision_bonus", "collision_chain_push"],
	"crit": ["long_critical_bonus", "distance_bonus"],
	"finish": ["low_hp_bonus", "duel_kill_bonus"],
	"repeat": ["repeat_target_damage", "duel_stack_gain"],
	"block": ["recent_block_damage", "guard_bonus", "guard_bonus_cap", "bastion_party_guard"],
	"windup": ["windup_bonus", "splash_windup_bonus"],
	"travel": ["lance_travel_bonus"],
	"ally": ["ally_guard", "heal_party_guard", "party_heal", "weakest_bonus"],
	"blink": ["blink_strike", "blink_on_hit_retreat", "teleport_followup_damage"],
	"charge": ["charge", "charge_carry", "flank_charge", "charge_path_damage"],
	"return": ["retreat", "dash_followup_damage", "ranged_followup_bonus", "lance_return_bonus"],
	"mark": ["mark_bonus", "chorus_mark_bonus"],
	"burn": ["ember_burn_damage", "burning_bonus"],
	"pierce": ["guard_break", "splash_guard_break", "guard_spend"],
	"pull": ["pull", "cluster_pull_radius", "convergence_damage_per_pull", "isolation_damage"],
	"push": ["push", "sweep_push_radius", "displaced_bonus"],
	"splash": ["splash", "radius", "block_wave_damage"],
	"heal": ["heal", "healing_damage_bonus"],
	"guard": ["guard", "guard_on_hit"],
}
const FEATURE_COUNTS := {
	"echo": "chorus_echo_charges", "rune": "rune_quick_hits", "chain": "collision_chain_hops",
	"pull": "convergence_targets", "splash": "splash_targets",
}
const AREA_FIELDS := ["splash", "radius", "sweep_push_radius", "cluster_pull_radius", "block_wave_radius", "ember_burn_radius"]


static func recipe(id: String, tile: Dictionary, profile: Dictionary) -> Dictionary:
	var base_id: String = tile.get("base_tile", id)
	var motif: Dictionary = Catalog.MOTIFS.get(base_id, {})
	if motif.is_empty():
		return {}
	return {
		"motif": motif, "family": profile.style,
		"beats": int(tile.get("width", 2)), "rank": maxi(0, RARITIES.find(tile.get("rarity", "common"))),
		"branch": _branch(id), "features": _features(tile),
		"color": profile.color, "accent": profile.accent,
	}


static func _branch(id: String) -> String:
	if id.ends_with("_power") or id in CORE_POWER:
		return "power"
	if id.ends_with("_technique") or id in CORE_TECHNIQUE:
		return "technique"
	return "base"


static func _features(tile: Dictionary) -> Array[Dictionary]:
	var features: Array[Dictionary] = []
	for kind: String in FEATURE_FIELDS:
		var fields: Array[String] = []
		var amount := 0.0
		for field: String in FEATURE_FIELDS[kind]:
			var value: Variant = tile.get(field, 0)
			if (value is bool and value) or ((value is int or value is float) and float(value) > 0.0):
				fields.append(field)
				amount = maxf(amount, float(value))
		if fields.is_empty():
			continue
		var count := maxi(1, int(tile.get(FEATURE_COUNTS.get(kind, ""), 1)))
		var area := fields.any(func(field: String): return field in AREA_FIELDS)
		if kind == "ally":
			count = 3 if tile.get("party_heal", false) or tile.has("heal_party_guard") else 2
		features.append({"kind": kind, "amount": amount, "count": mini(count, 5), "area": area, "fields": fields})
	return features
