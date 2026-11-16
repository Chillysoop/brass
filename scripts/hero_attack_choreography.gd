extends RefCounted

const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]
const WHITE := Color("#fff4d5")
const PALETTES := {
	"slash": [Color("#eed9ad"), Color("#fff8df")],
	"thrust": [Color("#e9dcaa"), Color("#fffbe8")],
	"heavy": [Color("#ec9b56"), Color("#ffe2a3")],
	"pull": [Color("#aa9aec"), Color("#e0d4ff")],
	"shot": [Color("#f4bf68"), Color("#fff6c9")],
	"burst": [Color("#f09654"), Color("#ffdf86")],
	"guard": [Color("#78dae3"), Color("#d9fbff")],
	"ward": [Color("#69cfc0"), Color("#c8fff1")],
	"blink": [Color("#b097f1"), Color("#e6d8ff")],
	"dash": [Color("#84dce9"), Color("#fff2c1")],
	"mine": [Color("#eaa765"), Color("#ffeaa8")],
	"heal": [Color("#99de9b"), Color("#e8ffb9")],
	"mark": [Color("#eab0ef"), Color("#ffe9a0")],
	"spin": [Color("#f2ac79"), Color("#fff2c4")],
	"bolt": [Color("#89c8f2"), Color("#e6f8ff")],
}

# Keep the familiar family readable while giving recognizable equipment its own accent.
const MOTIF_COLORS := {
	"bash": Color("#e7c382"), "slam": Color("#e88e52"), "shockwave": Color("#f3c556"),
	"fault_line": Color("#f49a67"), "skybreaker": Color("#eebc8d"),
	"dawn_bastion": Color("#f5bf5c"), "sunwall": Color("#edcb7c"), "event_horizon": Color("#aa86e5"),
	"grapple": Color("#adc6ce"), "hook_bash": Color("#a1d6d7"), "gravity_hook": Color("#a28ff0"),
	"longshot": Color("#e2cf96"), "deadeye": Color("#ffe597"), "rail_shot": Color("#89daee"),
	"star_piercer": Color("#b2f1ff"), "meteor_volley": Color("#f8925e"), "meteor_seal": Color("#f7ab63"),
	"phase_cut": Color("#adceff"), "sanctuary_gate": Color("#95eed9"), "starfall_step": Color("#c7b2ff"),
	"rampart_counter": Color("#6fbddf"), "bastion_oath": Color("#81cfcf"),
	"collision_hammer": Color("#f0a063"), "gravity_spike": Color("#a98eea"),
	"ghost_volley": Color("#aabbff"), "comet_charge": Color("#f6cb70"),
	"chorus_bolt": Color("#c6a3e8"), "triage_kit": Color("#8be5a7"),
	"runic_anvil": Color("#eaa160"), "horizon_round": Color("#8bd8f1"),
	"cinder_wave": Color("#f18c66"), "needle_point": Color("#e6cafa"),
	"backdraft_bolt": Color("#f99860"), "parallax_shot": Color("#c6b8ff"),
	"reversal_plate": Color("#eaca82"), "rampart_rush": Color("#ef895a"),
	"convergence_pulse": Color("#b48cf2"), "severing_tether": Color("#64cdd4"),
	"tonic_dart": Color("#9de7a5"), "catalyst_flask": Color("#e2ca69"),
	"pinpoint_lunge": Color("#f4e9b8"), "vanishing_cut": Color("#dc92c5"),
}

const MOTIF_VARIANTS := {
	"bash": 0, "shield_ram": 1, "rebound": 2, "dawn_bastion": 3,
	"shot": 0, "longshot": 1, "split_shot": 2, "deadeye": 3,
	"blink": 0, "phase_cut": 1, "ward_step": 2, "rift_lunge": 3,
	"guard": 0, "brace": 1, "ward_link": 2, "shield_chorus": 3,
	"slam": 0, "shockwave": 1, "sundering_slam": 2, "quake": 3,
	"pull": 0, "gravity_hook": 1, "grapple": 2, "tether_dart": 3,
	"backdraft_bolt": 2, "parallax_shot": 3,
}

const SIGNATURE_EFFECTS := {
	"bash": "hammer", "shield_ram": "hammer", "rebound": "hammer", "bulwark_charge": "hammer",
	"slam": "hammer", "meteor_seal": "meteor",
}


static func profile(id: String, tile: Dictionary) -> Dictionary:
	var base_id: String = tile.get("base_tile", id)
	var style := _style(base_id, tile)
	var palette: Array = PALETTES[style]
	var color: Color = MOTIF_COLORS.get(base_id, palette[0])
	var accent: Color = palette[1]
	var rarity := maxi(0, RARITIES.find(tile.get("rarity", "common")))
	var width: int = tile.get("width", 2)
	var damage: float = tile.get("damage", 0)
	var pattern := id.hash()
	var base_variant: int = MOTIF_VARIANTS.get(base_id, base_id.hash() % 4)
	var technique := id.ends_with("_technique")
	var variant := (base_variant + (rarity if base_id != id else 0) + (2 if technique else 0)) % 4
	var variation := float((pattern >> 3) % 1009) / 1009.0
	var trail_count := 1 + int(width >= 3) + int(width >= 5) + int(variant >= 2)
	if tile.has("splash") or style in ["spin", "burst"]:
		trail_count += 1
	if technique:
		accent = accent.lerp(PALETTES.ward[0], 0.22)
	var signature_effect: String = SIGNATURE_EFFECTS.get(base_id, "")
	if base_id == "horizon_round" and id != base_id and not technique:
		signature_effect = "skyline"
	return {
		"style": style,
		"color": color.lerp(accent, variation * 0.20),
		"accent": accent.lerp(WHITE, variation * 0.22),
		"scale": clampf(0.72 + width * 0.075 + rarity * 0.055 + variation * 0.11, 0.65, 1.5),
		"variant": variant,
		"weight": clampf(0.66 + width * 0.10 + damage * 0.004 + rarity * 0.06 + variation * 0.10, 0.6, 1.8),
		"trail_count": mini(5, trail_count),
		"signature_effect": signature_effect,
	}


static func _style(base_id: String, tile: Dictionary) -> String:
	if int(tile.get("damage", 0)) <= 0:
		if int(tile.get("heal", 0)) > 0:
			return "heal"
		return "ward" if tile.get("support", "self") != "self" else "guard"
	if tile.get("family", "") == "blink" or tile.get("blink_strike", false):
		return "blink"
	if tile.get("charge", false) or base_id == "bulwark_charge":
		return "dash"
	if tile.has("pull") or tile.has("convergence_damage_per_pull") or tile.has("isolation_damage") \
			or base_id in ["pull", "gravity_hook", "hook_bash", "graviton", "event_horizon"]:
		return "pull"
	match base_id:
		"bash", "shield_ram", "rebound", "shove", "shield_tap", "bellows_strike", "rampart_counter", "riposte", "reversal_plate":
			return "thrust"
		"jab", "pike_thrust", "needle_point":
			return "thrust"
		"sweep", "iron_arc", "crosscut":
			return "spin"
		"meteor_seal", "meteor_volley", "flare_mortar", "short_fuse", "furnace_burst", "cinder_wave":
			return "burst"
		"rail_shot", "star_piercer", "rivet_bolt", "tap_bolt", "sundering_bolt", "spark_shot", "backdraft_bolt", "tonic_dart":
			return "bolt"
		"chorus_bolt":
			return "ward" if tile.has("chorus_guard") else "mark"
	if tile.get("family", "") == "shot" or tile.get("ranged", false):
		if tile.has("mark_bonus") or tile.has("chorus_mark_bonus"):
			return "mark"
		return "burst" if tile.has("splash") else "shot"
	if tile.get("family", "") == "slam" or int(tile.get("width", 2)) >= 4 \
			or tile.has("guard_break") or tile.has("sweep_push_radius"):
		return "heavy"
	return "slash"
