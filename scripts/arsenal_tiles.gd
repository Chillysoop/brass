extends RefCounted

const COMMON_IDS := [
	"jab", "pike_thrust", "sweep", "shield_tap", "shove", "grapple", "retreat_shot", "signal_flare",
	"snap_shot", "rivet_bolt", "finishing_cut", "brace", "cover", "first_aid", "shrapnel", "breaker_maul",
]
const UNCOMMON_IDS := [
	"scattershot", "shoulder_check", "crossfire", "hook_sweep", "sundering_bolt", "watchfire",
	"field_dressing", "bulwark_bell",
]
const ENEMY_TARGETS := ["nearest", "farthest", "lowest_hp", "highest_hp"]

const SPECS := {
	"jab": {
		"label": "Jab", "width": 1, "range": 118.0, "damage": 7, "rarity": "common",
		"targets": ENEMY_TARGETS, "icon": "battle", "description": "Make a quick strike at close range.",
	},
	"pike_thrust": {
		"label": "Pike Thrust", "width": 2, "range": 232.0, "damage": 15, "rarity": "common",
		"targets": ENEMY_TARGETS, "icon": "battle", "description": "Strike from farther away than most melee attacks.",
	},
	"sweep": {
		"label": "Sweep", "width": 3, "range": 152.0, "damage": 15, "rarity": "common",
		"splash": 125.0, "splash_damage": 12, "targets": ENEMY_TARGETS, "icon": "area",
		"description": "Deal 12 damage to each other enemy within 125 range of the target.",
	},
	"shield_tap": {
		"label": "Shield Tap", "width": 2, "range": 145.0, "damage": 12, "rarity": "common",
		"guard": 4, "targets": ENEMY_TARGETS, "icon": "guard", "description": "Gain 4 Guard on hit.",
	},
	"shove": {
		"label": "Shove", "width": 1, "range": 130.0, "damage": 3, "rarity": "common",
		"push": 410.0, "targets": ENEMY_TARGETS, "icon": "push", "description": "Push the target away.",
	},
	"grapple": {
		"label": "Grapple", "width": 2, "range": 390.0, "damage": 8, "rarity": "common",
		"pull": 540.0, "targets": ENEMY_TARGETS, "icon": "pull", "description": "Pull the target toward you.",
	},
	"retreat_shot": {
		"label": "Retreat Shot", "width": 2, "range": 455.0, "damage": 11, "rarity": "common",
		"ranged": true, "retreat": 125.0, "targets": ENEMY_TARGETS, "icon": "shot",
		"description": "Fire, then dash away from the target by up to 125.",
	},
	"signal_flare": {
		"label": "Signal Flare", "width": 2, "range": 545.0, "damage": 7, "rarity": "common",
		"ranged": true, "mark_bonus": 7, "mark_beats": 3, "targets": ENEMY_TARGETS, "icon": "shot",
		"description": "Mark the target. The next tile to hit it within 3 beats deals 7 extra damage.",
	},
	"snap_shot": {
		"label": "Snap Shot", "short_label": "Snap", "width": 1, "range": 325.0, "damage": 6, "rarity": "common",
		"ranged": true, "targets": ENEMY_TARGETS, "icon": "shot",
		"description": "Fire a quick shot at short range.",
	},
	"rivet_bolt": {
		"label": "Rivet Bolt", "width": 2, "range": 470.0, "damage": 11, "rarity": "common",
		"ranged": true, "windup_bonus": 9, "targets": ENEMY_TARGETS, "icon": "shot",
		"description": "Deal 9 extra damage to a target winding up an attack.",
	},
	"finishing_cut": {
		"label": "Finishing Cut", "width": 2, "range": 155.0, "damage": 13, "rarity": "common",
		"low_hp_bonus": 9, "targets": ENEMY_TARGETS, "icon": "battle",
		"description": "Deal 9 extra damage to a target below half HP.",
	},
	"brace": {
		"label": "Brace", "width": 1, "range": 0.0, "damage": 0, "rarity": "common",
		"guard": 4, "targets": ["self"], "icon": "guard", "description": "Gain 4 Guard.",
	},
	"cover": {
		"label": "Cover", "width": 2, "range": 0.0, "damage": 0, "rarity": "common",
		"guard": 9, "support": "weakest", "targets": ["self"], "icon": "guard",
		"description": "Give 9 Guard to the living hero with the lowest HP.",
	},
	"first_aid": {
		"label": "First Aid", "width": 2, "range": 0.0, "damage": 0, "rarity": "common",
		"guard": 3, "heal": 6, "targets": ["self"], "icon": "rest",
		"description": "Gain 3 Guard. Restore up to 6 HP once per fight.",
	},
	"shrapnel": {
		"label": "Shrapnel", "width": 3, "range": 435.0, "damage": 13, "rarity": "common",
		"ranged": true, "splash": 105.0, "splash_damage": 9, "targets": ENEMY_TARGETS, "icon": "area",
		"description": "Deal 9 damage to each other enemy within 105 range of the target.",
	},
	"breaker_maul": {
		"label": "Breaker Maul", "width": 4, "range": 180.0, "damage": 28, "rarity": "common",
		"guard_break": 8, "targets": ENEMY_TARGETS, "icon": "battle",
		"description": "Strip up to 8 Guard before the hit.",
	},
	"scattershot": {
		"label": "Scattershot", "width": 3, "range": 365.0, "damage": 18, "rarity": "uncommon",
		"ranged": true, "splash": 147.0, "splash_damage": 13, "targets": ENEMY_TARGETS, "icon": "area",
		"description": "Deal 13 damage to each other enemy within 147 range of the target.",
	},
	"shoulder_check": {
		"label": "Shoulder Check", "width": 3, "range": 425.0, "damage": 19, "rarity": "uncommon",
		"charge": true, "push": 475.0, "guard": 6, "targets": ENEMY_TARGETS, "icon": "push",
		"description": "Rush the target if the path is clear. Hit, push it away, and gain 6 Guard.",
	},
	"crossfire": {
		"label": "Crossfire", "width": 3, "range": 460.0, "damage": 15, "rarity": "uncommon",
		"ranged": true, "splash": 105.0, "splash_damage": 10, "retreat": 150.0,
		"targets": ENEMY_TARGETS, "icon": "area",
		"description": "Deal 10 damage to each other enemy within 105 range of the target, then dash away by up to 150.",
	},
	"hook_sweep": {
		"label": "Hook Sweep", "width": 3, "range": 345.0, "damage": 16, "rarity": "uncommon",
		"pull": 620.0, "splash": 115.0, "splash_damage": 11, "targets": ENEMY_TARGETS, "icon": "pull",
		"description": "Deal 11 damage to each other enemy within 115 range of the target. Pull the target toward you.",
	},
	"sundering_bolt": {
		"label": "Sundering Bolt", "width": 3, "range": 595.0, "damage": 20, "rarity": "uncommon",
		"ranged": true, "guard_break": 12, "targets": ENEMY_TARGETS, "icon": "shot",
		"description": "Strip up to 12 Guard before the hit.",
	},
	"watchfire": {
		"label": "Watchfire", "width": 4, "range": 525.0, "damage": 18, "rarity": "uncommon",
		"ranged": true, "splash": 138.0, "splash_damage": 12, "mark_bonus": 9, "mark_beats": 4,
		"targets": ENEMY_TARGETS, "icon": "area",
		"description": "Deal 12 damage to nearby enemies within 138 range. The next tile to hit the main target within 4 beats deals 9 extra damage.",
	},
	"field_dressing": {
		"label": "Field Dressing", "width": 3, "range": 0.0, "damage": 0, "rarity": "uncommon",
		"guard": 6, "heal": 10, "support": "weakest", "targets": ["self"], "icon": "rest",
		"description": "Give 6 Guard to the living hero with the lowest HP. Restore up to 10 HP to that hero once per fight.",
	},
	"bulwark_bell": {
		"label": "Bulwark Bell", "width": 3, "range": 0.0, "damage": 0, "rarity": "uncommon",
		"guard": 9, "support": "party", "targets": ["self"], "icon": "guard",
		"description": "Give 9 Guard to every living hero.",
	},
}
