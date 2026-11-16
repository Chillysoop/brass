extends RefCounted

const SPECIALTY_COMMONS := {
	"warden": ["iron_vow", "bellows_strike", "reversal_plate", "rampart_rush"],
	"bulwark": ["iron_vow", "line_guard", "aegis_intercept", "shieldshock"],
	"breaker": ["bellows_strike", "rake", "domino_maul", "impact_driver"],
	"hexwright": ["shrapnel", "tether_dart", "convergence_pulse", "severing_tether"],
	"wayfarer": ["retreat_shot", "slip_cut", "mirror_dart", "veil_step"],
	"lancer": ["spur", "slip_cut", "phalanx_charge", "recoil_thrust"],
	"cantor": ["line_guard", "lantern_shot", "guard_refrain", "echo_chime"],
	"apothecary": ["pilgrim_aid", "lantern_shot", "tonic_dart", "catalyst_flask"],
	"rune_smith": ["stave_crush", "tap_bolt", "hammer_stamp", "quick_etch"],
	"starshot": ["retreat_shot", "spark_shot", "backdraft_bolt", "parallax_shot"],
	"cinder_mage": ["furnace_burst", "bellows_strike", "cinder_brand", "wildfire_globe"],
	"duelist": ["finishing_cut", "slip_cut", "pinpoint_lunge", "vanishing_cut"],
}

# The first core Common is also a starter option.
const DECKS := {
	"warden": {
		"summary": "Shield strikes and knockback",
		"common": ["shield_tap", "bash", "brace", "guard", "pike_thrust", "shove", "sweep", "shot", "cover", "first_aid"],
		"uncommon": ["shoulder_check", "bulwark_bell", "field_dressing", "hook_sweep"],
		"extra_common": ["iron_arc", "iron_vow", "line_guard", "pilgrim_aid", "rake", "bellows_strike", "spur", "stave_crush",
			"reversal_plate", "rampart_rush"],
		"signature": "rampart_counter",
		"extra_uncommon": ["ward_lantern", "piercing_burst", "reverse_cut"],
		"forge": ["bash", "guard"],
	},
	"bulwark": {
		"summary": "Party protection and heavy hits",
		"common": ["pike_thrust", "cover", "breaker_maul", "guard", "brace", "slam", "shield_tap", "first_aid", "bash", "shot"],
		"uncommon": ["bulwark_bell", "field_dressing", "shoulder_check", "sundering_bolt"],
		"extra_common": ["iron_arc", "iron_vow", "line_guard", "pilgrim_aid", "short_fuse", "bellows_strike", "lantern_shot", "stave_crush",
			"aegis_intercept", "shieldshock"],
		"signature": "bastion_oath",
		"extra_uncommon": ["ward_lantern", "piercing_burst", "flare_mortar"],
		"forge": ["bash", "guard", "slam"],
	},
	"breaker": {
		"summary": "Knockback, collisions, and wide swings",
		"common": ["breaker_maul", "shove", "slam", "bash", "sweep", "grapple", "pike_thrust", "blink", "shot", "shield_tap"],
		"uncommon": ["hook_sweep", "shoulder_check", "scattershot", "sundering_bolt"],
		"extra_common": ["iron_arc", "short_fuse", "rake", "furnace_burst", "tether_dart", "bellows_strike", "spur", "stave_crush",
			"domino_maul", "impact_driver"],
		"signature": "collision_hammer",
		"extra_uncommon": ["piercing_burst", "reverse_cut", "flare_mortar"],
		"forge": ["bash", "slam"],
	},
	"hexwright": {
		"summary": "Pull enemies into clustered attacks",
		"common": ["grapple", "pull", "sweep", "shrapnel", "signal_flare", "blink", "pike_thrust", "shot", "bash", "brace"],
		"uncommon": ["hook_sweep", "watchfire", "scattershot", "shoulder_check"],
		"extra_common": ["line_guard", "short_fuse", "rake", "furnace_burst", "tether_dart", "bellows_strike", "lantern_shot", "spark_shot",
			"convergence_pulse", "severing_tether"],
		"signature": "gravity_spike",
		"extra_uncommon": ["ward_lantern", "piercing_burst", "flare_mortar"],
		"forge": ["bash", "blink", "slam"],
	},
	"wayfarer": {
		"summary": "Teleport, retreat, and strike again",
		"common": ["blink", "retreat_shot", "finishing_cut", "snap_shot", "jab", "pike_thrust", "cover", "shot", "bash", "signal_flare"],
		"uncommon": ["crossfire", "shoulder_check", "scattershot", "field_dressing"],
		"extra_common": ["pilgrim_aid", "short_fuse", "tether_dart", "lantern_shot", "slip_cut", "spur", "spark_shot", "crosscut",
			"mirror_dart", "veil_step"],
		"signature": "ghost_volley",
		"extra_uncommon": ["ward_lantern", "piercing_burst", "reverse_cut"],
		"forge": ["bash", "blink", "shot"],
	},
	"lancer": {
		"summary": "Build momentum by closing and retreating",
		"common": ["retreat_shot", "pike_thrust", "shove", "jab", "blink", "grapple", "finishing_cut", "brace", "shot", "bash"],
		"uncommon": ["shoulder_check", "crossfire", "hook_sweep", "sundering_bolt"],
		"extra_common": ["iron_vow", "rake", "tether_dart", "bellows_strike", "slip_cut", "spur", "crosscut", "tap_bolt",
			"phalanx_charge", "recoil_thrust"],
		"signature": "comet_charge",
		"extra_uncommon": ["reverse_cut", "piercing_burst", "flare_mortar"],
		"forge": ["bash", "blink"],
	},
	"cantor": {
		"summary": "Share Guard and mark targets for follow-ups",
		"common": ["signal_flare", "cover", "guard", "brace", "first_aid", "shield_tap", "pike_thrust", "shot", "bash", "sweep"],
		"uncommon": ["bulwark_bell", "watchfire", "field_dressing", "crossfire"],
		"extra_common": ["iron_vow", "line_guard", "pilgrim_aid", "short_fuse", "lantern_shot", "spark_shot", "tap_bolt", "stave_crush",
			"guard_refrain", "echo_chime"],
		"signature": "chorus_bolt",
		"extra_uncommon": ["ward_lantern", "piercing_burst", "flare_mortar"],
		"forge": ["bash", "guard", "shot"],
	},
	"apothecary": {
		"summary": "Quick attacks, healing, and sustain",
		"common": ["snap_shot", "first_aid", "finishing_cut", "jab", "cover", "shield_tap", "grapple", "guard", "shot", "bash"],
		"uncommon": ["field_dressing", "bulwark_bell", "sundering_bolt", "hook_sweep"],
		"extra_common": ["iron_arc", "iron_vow", "line_guard", "pilgrim_aid", "lantern_shot", "slip_cut", "crosscut", "tap_bolt",
			"tonic_dart", "catalyst_flask"],
		"signature": "triage_kit",
		"extra_uncommon": ["ward_lantern", "reverse_cut", "flare_mortar"],
		"forge": ["bash", "guard"],
	},
	"rune_smith": {
		"summary": "Charge quick follow-ups with wide tiles",
		"common": ["slam", "breaker_maul", "snap_shot", "sweep", "shrapnel", "brace", "guard", "signal_flare", "shot", "bash"],
		"uncommon": ["watchfire", "sundering_bolt", "scattershot", "bulwark_bell"],
		"extra_common": ["iron_arc", "iron_vow", "short_fuse", "furnace_burst", "bellows_strike", "lantern_shot", "tap_bolt", "stave_crush",
			"hammer_stamp", "quick_etch"],
		"signature": "runic_anvil",
		"extra_uncommon": ["ward_lantern", "piercing_burst", "flare_mortar"],
		"forge": ["bash", "slam", "guard"],
	},
	"starshot": {
		"summary": "Long-range criticals and evasive movement",
		"common": ["rivet_bolt", "retreat_shot", "signal_flare", "snap_shot", "shrapnel", "pull", "blink", "shot", "bash", "cover"],
		"uncommon": ["sundering_bolt", "crossfire", "scattershot", "watchfire"],
		"extra_common": ["short_fuse", "furnace_burst", "tether_dart", "lantern_shot", "slip_cut", "spark_shot", "tap_bolt", "line_guard",
			"backdraft_bolt", "parallax_shot"],
		"signature": "horizon_round",
		"extra_uncommon": ["piercing_burst", "reverse_cut", "flare_mortar"],
		"forge": ["bash", "shot"],
	},
	"cinder_mage": {
		"summary": "Displace enemies and hit the cluster",
		"common": ["shrapnel", "grapple", "shove", "pull", "slam", "signal_flare", "rivet_bolt", "blink", "shot", "bash"],
		"uncommon": ["watchfire", "hook_sweep", "shoulder_check", "crossfire"],
		"extra_common": ["short_fuse", "rake", "furnace_burst", "tether_dart", "bellows_strike", "lantern_shot", "spark_shot", "stave_crush",
			"cinder_brand", "wildfire_globe"],
		"signature": "cinder_wave",
		"extra_uncommon": ["piercing_burst", "reverse_cut", "flare_mortar"],
		"forge": ["bash", "slam", "blink"],
	},
	"duelist": {
		"summary": "Quick hits on one target and finishing blows",
		"common": ["jab", "finishing_cut", "shield_tap", "pike_thrust", "snap_shot", "blink", "signal_flare", "grapple", "shot", "bash"],
		"uncommon": ["shoulder_check", "sundering_bolt", "hook_sweep", "crossfire"],
		"extra_common": ["iron_arc", "iron_vow", "rake", "slip_cut", "spur", "crosscut", "tap_bolt", "stave_crush",
			"pinpoint_lunge", "vanishing_cut"],
		"signature": "needle_point",
		"extra_uncommon": ["ward_lantern", "reverse_cut", "flare_mortar"],
		"forge": ["bash", "blink", "shot"],
	},
}


static func common(hero_id: String) -> Array:
	var deck := _deck(hero_id)
	return deck.common + deck.extra_common


static func specialties(hero_id: String) -> Array:
	return SPECIALTY_COMMONS.get(hero_id, [])


static func uncommon(hero_id: String) -> Array:
	var deck := _deck(hero_id)
	return deck.uncommon + [deck.signature] + deck.extra_uncommon


static func core_uncommon(hero_id: String) -> Array:
	return _deck(hero_id).uncommon.duplicate()


static func signature(hero_id: String) -> String:
	return _deck(hero_id).signature


static func is_signature(tile_id: String) -> bool:
	for deck: Dictionary in DECKS.values():
		if deck.signature == tile_id:
			return true
	return false


static func forge_families(hero_id: String) -> Array:
	return _deck(hero_id).forge.duplicate()


static func summary(hero_id: String) -> String:
	return _deck(hero_id).summary


static func starter(hero_id: String) -> String:
	return _deck(hero_id).common[0]


static func _deck(hero_id: String) -> Dictionary:
	return DECKS.get(hero_id, DECKS.warden)
