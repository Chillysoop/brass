extends RefCounted


const PATHS := {
	"tonic_dart": {
		"power": {
			"label": "Potent Dose",
			"gains": {"damage": 3, "heal": 2, "range": 15.0},
		},
		"technique": {
			"label": "Protective Serum",
			"gains": {"damage": 1, "guard": 2, "range": 15.0},
		},
	},
	"catalyst_flask": {
		"power": {
			"label": "Reactive Flask",
			"gains": {"damage": 3, "healing_damage_bonus": 2},
		},
		"technique": {
			"label": "Dispersion Flask",
			"gains": {"damage": 1, "splash_damage": 2, "splash": 16.0, "range": 15.0},
		},
	},
	"backdraft_bolt": {
		"power": {
			"label": "Twin Ignition",
			"gains": {"damage": 3, "dash_followup_damage": 3, "range": 10.0},
		},
		"technique": {
			"label": "Skirmisher's Step",
			"properties": {"ranged_followup_bonus": 3, "ranged_followup_beats": 2},
			"gains": {"damage": 1, "retreat": 15.0, "dash_followup_beats": 1, "ranged_followup_bonus": 2},
		},
	},
	"parallax_shot": {
		"power": {
			"label": "Far Sight",
			"gains": {"damage": 4, "long_critical_bonus": 0.06, "range": 25.0},
		},
		"technique": {
			"label": "Spotter Lens",
			"properties": {"mark_bonus": 4, "mark_beats": 3},
			"gains": {"damage": 2, "mark_bonus": 2, "range": 20.0},
		},
	},
	"guard_refrain": {
		"power": {
			"label": "Fortress Refrain",
			"gains": {"damage": 3, "guard": 1, "range": 15.0},
		},
		"technique": {
			"label": "Perfect Harmony",
			"gains": {"damage": 1, "harmony_guard": 2, "range": 15.0},
		},
	},
	"echo_chime": {
		"power": {
			"label": "Thunder Chime",
			"gains": {"damage": 3, "guard": 1, "chorus_echo_damage": 3},
		},
		"technique": {
			"label": "Second Voice",
			"properties": {"chorus_echo_charges": 2},
			"gains": {"damage": 1, "chorus_echo_damage": 1, "chorus_echo_radius": 15.0, "chorus_echo_beats": 1},
		},
	},
	"hammer_stamp": {
		"power": {
			"label": "Siege Stamp",
			"gains": {"damage": 4, "guard_break": 3, "range": 8.0},
		},
		"technique": {
			"label": "Triple Stamp",
			"properties": {"rune_quick_hits": 3},
			"gains": {"damage": 2, "rune_quick_bonus": 1, "range": 5.0},
		},
	},
	"quick_etch": {
		"power": {
			"label": "Deep Engraving",
			"gains": {"damage": 2, "rune_heavy_bonus": 2, "range": 12.0},
		},
		"technique": {
			"label": "Ward Glyph",
			"properties": {"guard": 2},
			"gains": {"damage": 1, "guard": 1, "range": 15.0},
		},
	},
	"mirror_dart": {
		"power": {
			"label": "Prism Dart",
			"gains": {"damage": 3, "teleport_followup_damage": 2, "range": 15.0},
		},
		"technique": {
			"label": "Shattered Mirror",
			"properties": {"splash": 75.0, "splash_damage": 2},
			"gains": {"damage": 1, "teleport_followup_beats": 1, "splash": 10.0, "splash_damage": 2},
		},
	},
	"veil_step": {
		"power": {
			"label": "Farstep Shot",
			"gains": {"damage": 3, "range": 18.0, "blink_on_hit_retreat": 18.0},
		},
		"technique": {
			"label": "Phantom Step",
			"properties": {"blink_echo_damage": 5},
			"gains": {"damage": 1, "blink_echo_damage": 2, "blink_on_hit_retreat": 8.0},
		},
	},
	"sear": {
		"power": {"label": "Hot Needle", "gains": {"damage": 2, "range": 12.0}},
		"technique": {"label": "Kindled Shot", "gains": {"damage": 1, "burning_bonus": 2}},
	},
	"cinder_brand": {
		"power": {
			"label": "Forgebrand",
			"gains": {"damage": 3, "ember_burn_damage": 2, "range": 10.0},
		},
		"technique": {
			"label": "Cinder Spray",
			"properties": {"ember_burn_radius": 85.0},
			"gains": {"damage": 1, "push": 44.0, "ember_burn_radius": 12.0, "ember_burn_damage": 1},
		},
	},
	"wildfire_globe": {
		"power": {
			"label": "Flashfire",
			"gains": {"damage": 4, "splash_damage": 3, "splash": 8.0},
		},
		"technique": {
			"label": "Fireline",
			"gains": {"damage": 2, "ember_burn_damage": 1, "ember_burn_ticks": 1, "ember_burn_radius": 18.0},
		},
	},
}
