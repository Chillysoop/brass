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

# Local material responses describe mechanics without inventing another victim or hit.
# Texture keys come from the authored combat particle atlas. Streams and pulses count
# visual emissions; the combat simulation remains the sole owner of actual damage.
const PARTICLE_LAYERS := {
	"overflow": {"gesture": "fountain", "material": "shield", "secondary": "heal", "scatter": "radial", "finish": "rise"},
	"intercept": {"gesture": "dome", "material": "shield", "secondary": "brass", "scatter": "tight", "finish": "linger"},
	"harmony": {"gesture": "pulse", "material": "arc", "secondary": "shield", "scatter": "paired", "finish": "rise"},
	"echo": {"gesture": "recoil", "material": "phase", "secondary": "aether", "scatter": "paired", "finish": "curl"},
	"rune": {"gesture": "collapse", "material": "aether", "secondary": "brass", "scatter": "column", "finish": "linger"},
	"chain": {"gesture": "arc", "material": "brass", "secondary": "spark", "scatter": "paired", "finish": "fall"},
	"crit": {"gesture": "lance", "material": "crystal", "secondary": "spark", "scatter": "tight", "finish": "spray"},
	"finish": {"gesture": "drop", "material": "slash", "secondary": "spark", "scatter": "tight", "finish": "fall"},
	"repeat": {"gesture": "pulse", "material": "spark", "secondary": "aether", "scatter": "paired", "finish": "spray"},
	"block": {"gesture": "recoil", "material": "shield", "secondary": "brass", "scatter": "column", "finish": "fall"},
	"windup": {"gesture": "fountain", "material": "aether", "secondary": "ember", "scatter": "column", "finish": "rise"},
	"travel": {"gesture": "dash", "material": "spark", "secondary": "dust", "scatter": "column", "finish": "spray"},
	"ally": {"gesture": "arc", "material": "heal", "secondary": "shield", "scatter": "paired", "finish": "rise"},
	"blink": {"gesture": "blink", "material": "phase", "secondary": "crystal", "scatter": "paired", "finish": "curl"},
	"charge": {"gesture": "dash", "material": "dust", "secondary": "brass", "scatter": "column", "finish": "spray"},
	"return": {"gesture": "recoil", "material": "phase", "secondary": "smoke", "scatter": "tight", "finish": "curl"},
	"mark": {"gesture": "orbit", "material": "aether", "secondary": "arc", "scatter": "tight", "finish": "linger"},
	"burn": {"gesture": "fountain", "material": "ember", "secondary": "smoke", "scatter": "column", "finish": "rise"},
	"pierce": {"gesture": "lance", "material": "crystal", "secondary": "brass", "scatter": "tight", "finish": "spray"},
	"pull": {"gesture": "spiral", "material": "aether", "secondary": "phase", "scatter": "radial", "finish": "implode"},
	"push": {"gesture": "fan", "material": "dust", "secondary": "brass", "scatter": "fan", "finish": "spray"},
	"splash": {"gesture": "pulse", "material": "smoke", "secondary": "dust", "scatter": "radial", "finish": "fall"},
	"heal": {"gesture": "fountain", "material": "heal", "secondary": "aether", "scatter": "column", "finish": "rise"},
	"guard": {"gesture": "dome", "material": "shield", "secondary": "aether", "scatter": "radial", "finish": "linger"},
}


static func recipe(id: String, tile: Dictionary, profile: Dictionary) -> Dictionary:
	var base_id: String = tile.get("base_tile", id)
	var motif: Dictionary = Catalog.MOTIFS.get(base_id, {})
	if motif.is_empty():
		return {}
	var features := _features(tile)
	return {
		"motif": motif, "family": profile.style,
		"beats": int(tile.get("width", 2)), "rank": maxi(0, RARITIES.find(tile.get("rarity", "common"))),
		"branch": _branch(id), "features": features,
		"particles": motif.get("particles", {}), "particle_layers": _particle_layers(features),
		"sprite_fusion": profile.get("sprite_fusion", ""), "signature_effect": profile.get("signature_effect", ""),
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


static func _particle_layers(features: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for feature: Dictionary in features:
		var layer: Dictionary = PARTICLE_LAYERS.get(feature.kind, {}).duplicate()
		if layer.is_empty():
			continue
		layer.kind = feature.kind
		layer.streams = clampi(int(feature.count), 1, 5)
		layer.pulses = 2 if feature.kind in ["echo", "harmony", "repeat", "chain"] else 1
		layer.amount = feature.amount
		layer.area = feature.area
		result.append(layer)
	return result
