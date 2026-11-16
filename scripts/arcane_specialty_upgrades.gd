extends RefCounted


const PATHS := {
	"tonic_dart": {
		"power": {
			"label": "Potent Dose",
			"gains": {"damage": 3, "heal": 2, "range": 15.0},
			"stages": [
				{"name": "Triage Needle", "effects": {"low_hp_bonus": 3}},
				{"name": "Restorative Spike", "effects": {"healing_damage_bonus": 3}},
				{"name": "Catalytic Lancet", "effects": {"mark_bonus": 4, "mark_beats": 3}},
				{"name": "Panacea Dart", "effects": {"heal_party_guard": 4}},
			],
		},
		"technique": {
			"label": "Protective Serum",
			"gains": {"damage": 1, "guard": 2, "range": 15.0},
			"stages": [
				{"name": "Brace Serum", "effects": {"guard_bonus": 3}},
				{"name": "Relay Injector", "effects": {"ally_guard": 3}},
				{"name": "Antishock Ampoule", "effects": {"recent_block_damage": 4, "recent_block_beats": 3}},
				{"name": "Aegis Inoculation", "effects": {"bastion_block_threshold": 5, "bastion_party_guard": 4, "bastion_beats": 4}},
			],
		},
	},
	"catalyst_flask": {
		"power": {
			"label": "Reactive Flask",
			"gains": {"damage": 3, "healing_damage_bonus": 2},
			"stages": [
				{"name": "Reactive Phial", "effects": {"burning_bonus": 4}},
				{"name": "Etching Reagent", "effects": {"guard_break": 4}},
				{"name": "Caustic Burst", "effects": {"push": 290.0}},
				{"name": "Sunstone Retort", "effects": {"ember_burn_damage": 3, "ember_burn_ticks": 3}},
			],
		},
		"technique": {
			"label": "Dispersion Flask",
			"gains": {"damage": 1, "splash_damage": 2, "splash": 16.0, "range": 15.0},
			"stages": [
				{"name": "Vent Flask", "effects": {"retreat": 48.0}},
				{"name": "Vapour Draw", "effects": {"cluster_pull_radius": 115.0, "cluster_pull_force": 340.0}},
				{"name": "Recovery Mist", "effects": {"guard": 1, "heal": 3, "support": "weakest"}},
				{"name": "Field Condenser", "effects": {"heal_overflow_guard": 3, "party_heal": true}},
			],
		},
	},
	"backdraft_bolt": {
		"power": {
			"label": "Twin Ignition",
			"gains": {"damage": 3, "dash_followup_damage": 3, "range": 10.0},
			"stages": [
				{"name": "Fusebolt", "effects": {"windup_bonus": 3}},
				{"name": "Wake Repeater", "effects": {"displaced_bonus": 4}},
				{"name": "Hot Chamber", "effects": {"guard_break": 4}},
				{"name": "Blast Cartridge", "effects": {"splash": 105.0, "splash_damage": 5}},
			],
		},
		"technique": {
			"label": "Skirmisher's Step",
			"properties": {"ranged_followup_bonus": 3, "ranged_followup_beats": 2},
			"gains": {"damage": 1, "retreat": 15.0, "dash_followup_beats": 1, "ranged_followup_bonus": 2},
			"stages": [
				{"name": "Heel Spark", "effects": {"push": 240.0}},
				{"name": "Covering Flare", "effects": {"ally_guard": 3}},
				{"name": "Breakaway Volley", "effects": {"mark_bonus": 4, "mark_beats": 3}},
				{"name": "Turnwind Shot", "effects": {"teleport_followup_damage": 5, "teleport_followup_beats": 3}},
			],
		},
	},
	"parallax_shot": {
		"power": {
			"label": "Far Sight",
			"gains": {"damage": 4, "long_critical_bonus": 0.06, "range": 25.0},
			"stages": [
				{"name": "Rangefinder Shot", "effects": {"distance_bonus": 3}},
				{"name": "Needle Optic", "effects": {"guard_break": 4}},
				{"name": "Split Aperture", "effects": {"splash": 95.0, "splash_damage": 4}},
				{"name": "Horizon Breaker", "effects": {"low_hp_bonus": 7}},
			],
		},
		"technique": {
			"label": "Spotter Lens",
			"properties": {"mark_bonus": 4, "mark_beats": 3},
			"gains": {"damage": 2, "mark_bonus": 2, "range": 20.0},
			"stages": [
				{"name": "Trace Lens", "effects": {"chorus_mark_bonus": 2, "chorus_mark_beats": 4}},
				{"name": "Relay Optic", "effects": {"ally_guard": 3}},
				{"name": "Holdfast Scope", "effects": {"windup_bonus": 5}},
				{"name": "Crew Sightline", "effects": {"chorus_guard": 4, "chorus_guard_beats": 4}},
			],
		},
	},
	"guard_refrain": {
		"power": {
			"label": "Fortress Refrain",
			"gains": {"damage": 3, "guard": 1, "range": 15.0},
			"stages": [
				{"name": "Steadfast Verse", "effects": {"guard_bonus": 3}},
				{"name": "Bulwark Stanza", "effects": {"recent_block_damage": 4, "recent_block_beats": 3}},
				{"name": "Retort Hymn", "effects": {"block_wave_damage": 3, "block_wave_radius": 95.0}},
				{"name": "Iron Chorale", "effects": {"bastion_block_threshold": 5, "bastion_party_guard": 4, "bastion_beats": 4}},
			],
		},
		"technique": {
			"label": "Perfect Harmony",
			"gains": {"damage": 1, "harmony_guard": 2, "range": 15.0},
			"stages": [
				{"name": "Shared Verse", "effects": {"chorus_guard": 3, "chorus_guard_beats": 3}},
				{"name": "Choral Salve", "effects": {"heal": 2, "party_heal": true}},
				{"name": "Cadence of Hands", "effects": {"mark_bonus": 3, "mark_beats": 3}},
				{"name": "Concord Procession", "effects": {"chorus_mark_bonus": 4, "chorus_mark_beats": 3}},
			],
		},
	},
	"echo_chime": {
		"power": {
			"label": "Thunder Chime",
			"gains": {"damage": 3, "guard": 1, "chorus_echo_damage": 3},
			"stages": [
				{"name": "Bronze Echo", "effects": {"guard_break": 3}},
				{"name": "Hammered Overtone", "effects": {"splash": 95.0, "splash_damage": 3}},
				{"name": "Resonant Rebuke", "effects": {"windup_bonus": 5}},
				{"name": "Thunder Carillon", "effects": {"chorus_mark_bonus": 4, "chorus_mark_beats": 3}},
			],
		},
		"technique": {
			"label": "Second Voice",
			"properties": {"chorus_echo_charges": 2},
			"gains": {"damage": 1, "chorus_echo_damage": 1, "chorus_echo_radius": 15.0, "chorus_echo_beats": 1},
			"stages": [
				{"name": "Choir Token", "effects": {"chorus_mark_bonus": 2, "chorus_mark_beats": 3}},
				{"name": "Processional Chime", "effects": {"support": "party"}},
				{"name": "Evening Bell", "effects": {"heal": 2, "party_heal": true}},
				{"name": "Vesper Chorus", "effects": {"heal_party_guard": 3}},
			],
		},
	},
	"hammer_stamp": {
		"power": {
			"label": "Siege Stamp",
			"gains": {"damage": 4, "guard_break": 3, "range": 8.0},
			"stages": [
				{"name": "Wedge Stamp", "effects": {"windup_bonus": 4}},
				{"name": "Anvil Driver", "effects": {"push": 440.0}},
				{"name": "Ricochet Die", "effects": {"collision_bonus": 6}},
				{"name": "Siege Press", "effects": {"collision_chain_push": 430.0, "collision_chain_hops": 1}},
			],
		},
		"technique": {
			"label": "Triple Stamp",
			"properties": {"rune_quick_hits": 3},
			"gains": {"damage": 2, "rune_quick_bonus": 1, "range": 5.0},
			"stages": [
				{"name": "Pocket Die", "effects": {"guard": 3, "guard_bonus": 3}},
				{"name": "Scored Matrix", "effects": {"mark_bonus": 4, "mark_beats": 3}},
				{"name": "Keeper's Press", "effects": {"ally_guard": 4}},
				{"name": "Inlaid Sentinel", "effects": {"bastion_block_threshold": 5, "bastion_party_guard": 4, "bastion_beats": 4}},
			],
		},
	},
	"quick_etch": {
		"power": {
			"label": "Deep Engraving",
			"gains": {"damage": 2, "rune_heavy_bonus": 2, "range": 12.0},
			"stages": [
				{"name": "Fine-Cut Rune", "effects": {"guard_break": 2}},
				{"name": "Reprise Sigil", "effects": {"repeat_target_damage": 4}},
				{"name": "Resonance Cut", "effects": {"splash": 86.0, "splash_damage": 3}},
				{"name": "Grand Inscription", "effects": {"chorus_mark_bonus": 4, "chorus_mark_beats": 4}},
			],
		},
		"technique": {
			"label": "Ward Glyph",
			"properties": {"guard": 2},
			"gains": {"damage": 1, "guard": 1, "range": 15.0},
			"stages": [
				{"name": "Pocket Ward", "effects": {"ally_guard": 2}},
				{"name": "Warded Line", "effects": {"recent_block_damage": 3, "recent_block_beats": 3}},
				{"name": "Seal of Succor", "effects": {"heal": 2, "heal_overflow_guard": 2}},
				{"name": "Runic Canopy", "effects": {"party_heal": true, "heal_party_guard": 2}},
			],
		},
	},
	"mirror_dart": {
		"power": {
			"label": "Prism Dart",
			"gains": {"damage": 3, "teleport_followup_damage": 2, "range": 15.0},
			"stages": [
				{"name": "Facet Pick", "effects": {"guard_break": 3}},
				{"name": "Prism Weight", "effects": {"push": 350.0}},
				{"name": "Reflected Knock", "effects": {"displaced_bonus": 4}},
				{"name": "Throughglass Spike", "effects": {"blink_on_hit_retreat": 80.0}},
			],
		},
		"technique": {
			"label": "Shattered Mirror",
			"properties": {"splash": 75.0, "splash_damage": 2},
			"gains": {"damage": 1, "teleport_followup_beats": 1, "splash": 10.0, "splash_damage": 2},
			"stages": [
				{"name": "Mirror Scatter", "effects": {"mark_bonus": 3, "mark_beats": 3}},
				{"name": "Shiverglass", "effects": {"retreat": 55.0}},
				{"name": "Afterglint", "effects": {"ranged_followup_bonus": 4, "ranged_followup_beats": 3}},
				{"name": "Hall of Reflections", "effects": {"chorus_echo_damage": 5, "chorus_echo_radius": 120.0, "chorus_echo_beats": 3}},
			],
		},
	},
	"veil_step": {
		"power": {
			"label": "Farstep Shot",
			"gains": {"damage": 3, "range": 18.0, "blink_on_hit_retreat": 18.0},
			"stages": [
				{"name": "Window Shot", "effects": {"windup_bonus": 3}},
				{"name": "Folded Angle", "effects": {"low_hp_bonus": 4}},
				{"name": "Farplane Shot", "effects": {"teleport_followup_damage": 5, "teleport_followup_beats": 3}},
				{"name": "Vanishing Point", "effects": {"duel_kill_bonus": 5}},
			],
		},
		"technique": {
			"label": "Phantom Step",
			"properties": {"blink_echo_damage": 5},
			"gains": {"damage": 1, "blink_echo_damage": 2, "blink_on_hit_retreat": 8.0},
			"stages": [
				{"name": "Shadowproof", "effects": {"guard": 3}},
				{"name": "Hand-Off Mirage", "effects": {"mark_bonus": 4, "mark_beats": 3}},
				{"name": "False Reflection", "effects": {"ally_guard": 4}},
				{"name": "Crossed Portals", "effects": {"chorus_echo_damage": 5, "chorus_echo_radius": 115.0, "chorus_echo_beats": 4}},
			],
		},
	},
	"sear": {
		"power": {
			"label": "Hot Needle",
			"gains": {"damage": 2, "range": 12.0},
			"stages": [
				{"name": "White-Hot Pin", "effects": {"guard_break": 2}},
				{"name": "Heat Lance", "effects": {"push": 235.0}},
				{"name": "Smoulder Shot", "effects": {"ember_burn_damage": 3, "ember_burn_ticks": 2}},
				{"name": "Last Coal", "effects": {"ember_burn_on_hit": true}},
			],
		},
		"technique": {
			"label": "Kindled Shot",
			"gains": {"damage": 1, "burning_bonus": 2},
			"stages": [
				{"name": "Stoke Guard", "effects": {"guard": 3, "harmony_guard": 2}},
				{"name": "Brand Check", "effects": {"recent_block_damage": 4, "recent_block_beats": 3}},
				{"name": "Ash Shelter", "effects": {"block_wave_damage": 3, "block_wave_radius": 85.0}},
				{"name": "Hearth Screen", "effects": {"bastion_block_threshold": 5, "bastion_party_guard": 4, "bastion_beats": 4}},
			],
		},
	},
	"cinder_brand": {
		"power": {
			"label": "Forgebrand",
			"gains": {"damage": 3, "ember_burn_damage": 2, "range": 10.0},
			"stages": [
				{"name": "Copper Brand", "effects": {"displaced_bonus": 4}},
				{"name": "Kiln Hammer", "effects": {"collision_bonus": 5}},
				{"name": "Hearth Brand", "effects": {"burning_bonus": 4}},
				{"name": "Everlight Brand", "effects": {"ember_burn_on_hit": true}},
			],
		},
		"technique": {
			"label": "Cinder Spray",
			"properties": {"ember_burn_radius": 85.0},
			"gains": {"damage": 1, "push": 44.0, "ember_burn_radius": 12.0, "ember_burn_damage": 1},
			"stages": [
				{"name": "Fanned Cinder", "effects": {"splash": 92.0, "splash_damage": 4}},
				{"name": "Ember Relay", "effects": {"mark_bonus": 3, "mark_beats": 3}},
				{"name": "Hearth Backstep", "effects": {"retreat": 55.0}},
				{"name": "Soot Screen", "effects": {"ranged_followup_bonus": 4, "ranged_followup_beats": 3}},
			],
		},
	},
	"wildfire_globe": {
		"power": {
			"label": "Flashfire",
			"gains": {"damage": 4, "splash_damage": 3, "splash": 8.0},
			"stages": [
				{"name": "Flashpoint", "effects": {"burning_bonus": 4}},
				{"name": "Combustion Flask", "effects": {"guard_break": 4}},
				{"name": "Furnace Sphere", "effects": {"push": 360.0}},
				{"name": "Sunburst Vessel", "effects": {"sweep_push_radius": 125.0, "sweep_push_force": 280.0}},
			],
		},
		"technique": {
			"label": "Fireline",
			"gains": {"damage": 2, "ember_burn_damage": 1, "ember_burn_ticks": 1, "ember_burn_radius": 18.0},
			"stages": [
				{"name": "Drafted Flame", "effects": {"ranged_followup_bonus": 3, "ranged_followup_beats": 3}},
				{"name": "Smoke Cover", "effects": {"ally_guard": 3}},
				{"name": "Lantern Drift", "effects": {"chorus_guard": 3, "chorus_guard_beats": 3}},
				{"name": "Carried Wildfire", "effects": {"mark_bonus": 4, "mark_beats": 3}},
			],
		},
	},
}
