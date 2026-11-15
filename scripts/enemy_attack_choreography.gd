extends RefCounted

# Regional weapon colors stay warm by default. Enchanted weapons and ally support
# use glass, signal, or seawater colors so they read clearly beside the threat rings.
const PALETTE := {
	"copper": Color("#f3966b"), "rust": Color("#dc654d"), "amber": Color("#f4bf68"),
	"iron": Color("#d7adb1"), "steam": Color("#e4dacc"), "ember": Color("#ff8a56"),
	"ivory": Color("#ffebc2"), "flame": Color("#ff6046"), "gold": Color("#f4d58c"),
	"glass": Color("#a9f2d7"), "prism": Color("#73daf5"), "shard": Color("#bcdcff"),
	"violet": Color("#c38eda"), "lilac": Color("#dfbcf4"), "signal": Color("#f5919d"),
	"foam": Color("#75dad1"), "sea": Color("#79afce"), "moon": Color("#c2e3fb"),
	"tar": Color("#aa8fc4"), "mend": Color("#a4dea2"), "white": Color("#fff3d8"),
}

# Style, main color, accent, shape variant, scale, weight, and trail count.
const MOVES := {
	# Arena practice and established campaign enemies.
	"clockwork": ["heavy", "rust", "copper", 0, 1.2, 1.4, 2],
	"recruit": ["slash", "copper", "iron", 0, 0.75, 0.76, 1],
	"scout": ["shot", "amber", "copper", 0, 0.75, 0.67, 1],
	"bruiser": ["heavy", "rust", "amber", 1, 1.13, 1.38, 2],
	"veteran": ["heavy", "amber", "copper", 2, 1.28, 1.48, 3],
	"brass_sapper": ["shot", "copper", "steam", 1, 0.85, 0.95, 1],
	"sapper_blast": ["mine", "ember", "amber", 2, 1.24, 1.35, 4],
	"boss": ["heavy", "gold", "rust", 3, 1.34, 1.52, 3],
	"marshal": ["slash", "gold", "ivory", 2, 1.30, 1.40, 2],
	"marshal_sweep": ["spin", "gold", "copper", 1, 1.42, 1.54, 3],
	"regent": ["heavy", "iron", "signal", 1, 1.42, 1.50, 4],
	"regent_sweep": ["spin", "rust", "gold", 3, 1.50, 1.72, 4],

	# Brass Frontier.
	"brass_runner": ["slash", "copper", "white", 1, 0.76, 0.70, 1],
	"brass_riveter": ["shot", "rust", "steam", 2, 1.04, 1.23, 2],
	"brass_shieldwright": ["guard", "iron", "gold", 1, 0.99, 1.10, 2],
	"brass_shieldwright_strike": ["heavy", "iron", "gold", 0, 0.87, 1.00, 1],
	"brass_linksmith": ["ward", "gold", "glass", 0, 0.93, 0.80, 2],
	"brass_linksmith_strike": ["slash", "gold", "iron", 0, 0.68, 0.76, 1],
	"brass_springjack": ["thrust", "copper", "steam", 3, 1.19, 1.34, 3],
	"brass_rivet_hound": ["dash", "rust", "gold", 2, 0.96, 0.89, 3],
	"brass_manifold": ["burst", "steam", "amber", 2, 1.28, 1.24, 4],
	"brass_sparkbow": ["bolt", "amber", "steam", 0, 1.15, 1.15, 2],
	"brass_magnetar": ["pull", "violet", "gold", 2, 1.13, 1.20, 4],
	"brass_magnetar_strike": ["thrust", "violet", "iron", 0, 0.86, 0.94, 1],
	"brass_grounder": ["bolt", "gold", "prism", 2, 0.96, 0.94, 3],
	"brass_flywheel": ["spin", "copper", "steam", 0, 1.02, 1.12, 4],
	"brass_pressure_sentinel": ["heavy", "ember", "steam", 3, 1.30, 1.58, 5],

	# Glass Foundry.
	"glass_recruit": ["thrust", "glass", "gold", 0, 0.73, 0.75, 1],
	"glass_hunter": ["shot", "glass", "amber", 1, 0.96, 0.97, 2],
	"glass_skirmisher": ["slash", "shard", "glass", 3, 0.84, 0.78, 2],
	"glass_overseer": ["heavy", "glass", "copper", 2, 1.04, 1.25, 2],
	"glass_duelist": ["thrust", "shard", "lilac", 3, 0.91, 0.84, 2],
	"duelist_blink": ["blink", "prism", "lilac", 1, 1.06, 0.98, 3],
	"glass_twin": ["bolt", "prism", "shard", 3, 1.24, 1.27, 3],
	"ember_twin": ["heavy", "flame", "amber", 1, 1.24, 1.37, 3],
	"prism_warden": ["bolt", "glass", "lilac", 3, 1.39, 1.25, 4],
	"tempered_colossus": ["heavy", "flame", "glass", 0, 1.44, 1.57, 4],
	"colossus_forging": ["spin", "ember", "prism", 2, 1.50, 1.68, 5],
	"glass_cullet_slinger": ["shot", "shard", "steam", 0, 0.84, 0.88, 2],
	"glass_kiln_porter": ["heavy", "ember", "shard", 3, 1.02, 1.22, 2],
	"glass_facet_hound": ["slash", "glass", "prism", 1, 0.78, 0.86, 2],
	"glass_lacquerer": ["guard", "glass", "amber", 3, 0.91, 0.77, 3],
	"glass_lacquerer_strike": ["shot", "glass", "gold", 2, 0.73, 0.75, 1],
	"glass_crucible_binder": ["ward", "glass", "ember", 2, 1.00, 0.94, 2],
	"glass_crucible_binder_strike": ["thrust", "glass", "ember", 1, 0.72, 0.79, 1],
	"glass_mirrorback": ["guard", "shard", "lilac", 2, 1.09, 0.94, 4],
	"glass_mirrorback_strike": ["slash", "shard", "lilac", 2, 0.88, 0.85, 1],
	"glass_mirrorback_counter": ["bolt", "lilac", "shard", 1, 1.11, 1.10, 3],
	"glass_annealer": ["ward", "prism", "ivory", 1, 1.04, 1.00, 3],
	"glass_annealer_strike": ["slash", "prism", "ivory", 1, 0.79, 0.82, 1],
	"glass_lens_arbalist": ["shot", "prism", "gold", 3, 1.19, 1.10, 2],
	"glass_kiln_ram": ["heavy", "amber", "prism", 0, 1.08, 1.22, 1],
	"glass_shard_conductor": ["bolt", "shard", "prism", 2, 1.07, 1.12, 3],
	"glass_ash_siphon": ["thrust", "tar", "ember", 2, 0.98, 1.07, 2],
	"glass_quench_sentinel": ["thrust", "prism", "steam", 3, 1.06, 1.16, 2],
	"glass_furnace_knight": ["heavy", "flame", "gold", 2, 1.22, 1.34, 3],

	# Crown Relay.
	"relay_recruit": ["thrust", "ivory", "lilac", 0, 0.70, 0.74, 1],
	"relay_runner": ["slash", "signal", "ivory", 1, 0.83, 0.84, 2],
	"relay_guard": ["heavy", "ivory", "prism", 0, 0.96, 1.06, 2],
	"relay_lancer": ["thrust", "lilac", "gold", 2, 1.06, 1.21, 3],
	"crown_mender": ["shot", "lilac", "ivory", 1, 0.82, 0.75, 1],
	"mender_repair": ["heal", "mend", "prism", 1, 0.93, 0.88, 2],
	"relay_captain": ["heavy", "lilac", "gold", 1, 1.22, 1.29, 2],
	"relay_charge": ["thrust", "signal", "prism", 3, 1.37, 1.46, 4],
	"relay_marshal": ["slash", "lilac", "ivory", 2, 1.32, 1.34, 3],
	"relay_marshal_charge": ["spin", "lilac", "prism", 2, 1.47, 1.56, 4],
	"crown_regent": ["heavy", "violet", "gold", 3, 1.40, 1.49, 3],
	"crown_regent_charge": ["burst", "signal", "lilac", 3, 1.50, 1.71, 5],
	"crown_page": ["slash", "ivory", "gold", 0, 0.69, 0.74, 1],
	"crown_slinger": ["shot", "gold", "violet", 2, 0.84, 0.82, 2],
	"crown_glaiveguard": ["spin", "ivory", "gold", 0, 1.12, 1.23, 2],
	"crown_spotter": ["mark", "signal", "ivory", 1, 0.92, 0.94, 3],
	"crown_spotter_strike": ["shot", "signal", "gold", 0, 0.78, 0.79, 1],
	"crown_war_drummer": ["ward", "violet", "gold", 3, 1.10, 1.04, 4],
	"crown_war_drummer_strike": ["heavy", "violet", "copper", 0, 0.84, 0.85, 1],
	"crown_feintblade": ["slash", "violet", "signal", 3, 1.04, 1.00, 2],
	"crown_twinspur": ["thrust", "ivory", "signal", 1, 0.91, 0.93, 2],
	"crown_twinspur_followup": ["slash", "signal", "gold", 1, 1.06, 1.04, 2],
	"crown_ballista": ["shot", "ivory", "prism", 3, 1.32, 1.30, 3],
	"crown_storm_templar": ["spin", "violet", "prism", 1, 1.20, 1.30, 3],
	"crown_banneret": ["thrust", "gold", "lilac", 1, 1.02, 1.12, 2],
	"crown_galvanist": ["blink", "violet", "gold", 3, 1.18, 1.20, 4],
	"crown_galvanist_strike": ["thrust", "violet", "prism", 0, 0.90, 0.90, 1],
	"crown_beacon_sentry": ["mine", "signal", "gold", 3, 1.13, 1.19, 4],
	"crown_oathbreaker": ["heavy", "signal", "iron", 2, 1.10, 1.24, 2],
	"crown_chorister": ["heal", "mend", "lilac", 3, 1.05, 0.83, 3],
	"crown_chorister_strike": ["shot", "lilac", "gold", 0, 0.80, 0.76, 1],

	# Moonwreck Docks.
	"dock_recruit": ["slash", "sea", "copper", 0, 0.72, 0.72, 1],
	"dock_bruiser": ["heavy", "copper", "foam", 1, 1.08, 1.23, 2],
	"dock_winch": ["thrust", "sea", "iron", 0, 0.79, 0.83, 1],
	"dock_winch_windup": ["pull", "gold", "foam", 0, 0.89, 0.92, 3],
	"dock_corsair": ["slash", "foam", "copper", 2, 0.95, 0.96, 2],
	"corsair_hook": ["pull", "sea", "gold", 1, 1.04, 1.09, 2],
	"wreckmaster": ["heavy", "sea", "amber", 0, 1.19, 1.27, 2],
	"wreckmaster_harpoon": ["pull", "foam", "rust", 0, 1.23, 1.18, 3],
	"wreckmaster_slam_windup": ["burst", "amber", "sea", 1, 1.30, 1.38, 3],
	"tidekeeper": ["slash", "foam", "moon", 3, 1.28, 1.39, 3],
	"tidekeeper_harpoon": ["pull", "foam", "moon", 2, 1.31, 1.31, 4],
	"tidekeeper_slam_windup": ["burst", "sea", "foam", 2, 1.42, 1.55, 4],
	"drowned_admiral": ["heavy", "sea", "moon", 3, 1.39, 1.46, 4],
	"admiral_undertow": ["pull", "moon", "sea", 3, 1.50, 1.50, 5],
	"admiral_sweep_windup": ["spin", "moon", "foam", 3, 1.50, 1.74, 5],
	"dock_saltblade": ["slash", "foam", "ivory", 1, 0.82, 0.84, 2],
	"dock_torchbearer": ["spin", "amber", "copper", 2, 1.03, 1.04, 3],
	"dock_bilge_sapper": ["mine", "foam", "moon", 0, 0.94, 0.91, 4],
	"dock_shellback": ["guard", "sea", "foam", 0, 1.06, 1.12, 3],
	"dock_shellback_strike": ["heavy", "sea", "foam", 2, 0.90, 0.98, 1],
	"dock_hull_harrier": ["dash", "foam", "sea", 3, 1.01, 1.07, 3],
	"powder_runner": ["shot", "flame", "amber", 2, 1.15, 1.20, 4],
	"tar_pitcher": ["shot", "tar", "sea", 1, 0.92, 0.95, 3],
	"deck_ram": ["dash", "sea", "iron", 1, 1.21, 1.32, 4],
	"patch_rigger": ["ward", "foam", "moon", 2, 0.92, 0.85, 2],
	"patch_rigger_strike": ["thrust", "sea", "copper", 0, 0.78, 0.79, 1],
	"reef_diver": ["thrust", "moon", "sea", 3, 1.02, 1.04, 3],
	"signal_gunner": ["shot", "gold", "sea", 3, 1.16, 1.21, 3],
	"signal_gunner_strike": ["thrust", "gold", "sea", 1, 0.83, 0.91, 1],
	"chain_warden": ["slash", "iron", "sea", 3, 1.07, 1.19, 3],
	"chain_warden_strike": ["heavy", "iron", "sea", 1, 0.93, 1.06, 2],
	"wreck_bell": ["burst", "moon", "gold", 0, 1.23, 1.33, 4],
}

const ALIASES := {
	"collossus_forge_sweep": "colossus_forging",
	"colossus_forge_sweep": "colossus_forging",
	"relay_discharge": "relay_charge", "relay_marshal_discharge": "relay_marshal_charge",
	"crown_regent_discharge": "crown_regent_charge", "dock_winch_pull": "dock_winch_windup",
	"wreckmaster_slam": "wreckmaster_slam_windup", "tidekeeper_slam": "tidekeeper_slam_windup",
	"admiral_sweep": "admiral_sweep_windup", "gilded_marshal": "marshal", "iron_regent": "regent",
}


static func profile(id: String, attack: Dictionary = {}) -> Dictionary:
	var key: String = ALIASES.get(id, id)
	var spec: Array = MOVES.get(key, [])
	if spec.is_empty():
		return _fallback(key, attack)
	return {
		"style": spec[0], "color": PALETTE[spec[1]], "accent": PALETTE[spec[2]],
		"variant": spec[3], "scale": spec[4], "weight": spec[5], "trail_count": spec[6],
	}


static func _fallback(id: String, attack: Dictionary) -> Dictionary:
	# A fallback attack on a specialist never draws the effect of its special.
	var base: String = id.trim_suffix("_strike")
	var signature: Array = MOVES.get(base, [])
	var style := "slash"
	if float(attack.get("reach", 0.0)) > 210.0:
		style = "shot"
	elif float(attack.get("push", 0.0)) > 0.0:
		style = "heavy"
	var color: Color = PALETTE["copper"] if signature.is_empty() else PALETTE[signature[1]]
	var accent: Color = PALETTE["white"] if signature.is_empty() else PALETTE[signature[2]]
	return {"style": style, "color": color, "accent": accent, "variant": int(id.hash() % 4),
		"scale": 0.82, "weight": 0.9, "trail_count": 1}
