extends RefCounted

const COMMON_IDS := [
	"iron_arc", "iron_vow", "line_guard", "pilgrim_aid", "short_fuse", "rake", "furnace_burst", "tether_dart",
	"bellows_strike", "lantern_shot", "slip_cut", "spur", "spark_shot", "crosscut", "tap_bolt", "stave_crush",
]
const UNCOMMON_IDS := [
	"ward_lantern", "piercing_burst", "reverse_cut", "flare_mortar",
	"rampart_counter", "bastion_oath", "collision_hammer", "gravity_spike", "ghost_volley", "comet_charge",
	"chorus_bolt", "triage_kit", "runic_anvil", "horizon_round", "cinder_wave", "needle_point",
]
const ENEMY_TARGETS := ["nearest", "farthest", "lowest_hp", "highest_hp"]

const SPECS := {
	"iron_arc": {
		"label": "Iron Arc", "width": 3, "range": 165.0, "damage": 17, "rarity": "common",
		"guard_bonus": 7, "targets": ENEMY_TARGETS, "icon": "guard",
		"description": "Deal 7 extra damage while you have Guard.",
	},
	"iron_vow": {
		"label": "Iron Vow", "width": 3, "range": 155.0, "damage": 12, "rarity": "common",
		"guard_bonus": 7, "guard": 6, "targets": ENEMY_TARGETS, "icon": "guard",
		"description": "Deal 7 extra damage if you have Guard. Gain 6 Guard on hit.",
	},
	"line_guard": {
		"label": "Line Guard", "width": 2, "range": 0.0, "damage": 0, "rarity": "common",
		"guard": 5, "support": "party", "targets": ["self"], "icon": "guard",
		"description": "Give 5 Guard to every living hero.",
	},
	"pilgrim_aid": {
		"label": "Pilgrim Aid", "width": 3, "range": 0.0, "damage": 0, "rarity": "common",
		"guard": 5, "heal": 8, "support": "weakest", "targets": ["self"], "icon": "rest",
		"description": "Give the living hero with the lowest HP 5 Guard. Restore up to 8 HP to that hero once per fight.",
	},
	"short_fuse": {
		"label": "Short Fuse", "width": 2, "range": 370.0, "damage": 9, "rarity": "common",
		"ranged": true, "splash": 80.0, "splash_damage": 8, "targets": ENEMY_TARGETS, "icon": "area",
		"description": "Deal 8 damage to every other enemy within 80 range of the target.",
	},
	"rake": {
		"label": "Rake", "width": 2, "range": 170.0, "damage": 11, "rarity": "common",
		"displaced_bonus": 8, "targets": ENEMY_TARGETS, "icon": "battle",
		"description": "Deal 8 extra damage if the target was pushed or pulled in the last 3 beats.",
	},
	"furnace_burst": {
		"label": "Furnace Burst", "width": 4, "range": 350.0, "damage": 18, "rarity": "common",
		"ranged": true, "displaced_bonus": 9, "splash": 108.0, "splash_damage": 12,
		"targets": ENEMY_TARGETS, "icon": "area",
		"description": "Deal 9 extra damage if the target was pushed or pulled in the last 3 beats. Deal 12 damage to other enemies within 108 range of it.",
	},
	"tether_dart": {
		"label": "Tether Dart", "short_label": "Tether", "width": 1, "range": 290.0, "damage": 3, "rarity": "common",
		"ranged": true, "pull": 335.0, "targets": ENEMY_TARGETS, "icon": "pull",
		"description": "Pull the target toward you.",
	},
	"bellows_strike": {
		"label": "Bellows Strike", "width": 2, "range": 218.0, "damage": 12, "rarity": "common",
		"push": 360.0, "targets": ENEMY_TARGETS, "icon": "push",
		"description": "Push the target away from you.",
	},
	"lantern_shot": {
		"label": "Lantern Shot", "width": 3, "range": 460.0, "damage": 12, "rarity": "common",
		"ranged": true, "mark_bonus": 9, "mark_beats": 4, "targets": ENEMY_TARGETS, "icon": "shot",
		"description": "Mark the target. The next tile to hit it within 4 beats deals 9 extra damage.",
	},
	"slip_cut": {
		"label": "Slip Cut", "width": 2, "range": 145.0, "damage": 13, "rarity": "common",
		"retreat": 55.0, "targets": ENEMY_TARGETS, "icon": "battle",
		"description": "Strike, then back away from the target by up to 55.",
	},
	"spur": {
		"label": "Spur", "width": 2, "range": 235.0, "damage": 12, "rarity": "common",
		"charge": true, "guard": 2, "targets": ENEMY_TARGETS, "icon": "battle",
		"description": "Rush the target if the path is clear. Hit and gain 2 Guard.",
	},
	"spark_shot": {
		"label": "Spark Shot", "width": 2, "range": 570.0, "damage": 9, "rarity": "common",
		"ranged": true, "distance_bonus": 7, "targets": ENEMY_TARGETS, "icon": "shot",
		"description": "Deal 7 extra damage beyond 210 range.",
	},
	"crosscut": {
		"label": "Crosscut", "short_label": "Cross", "width": 1, "range": 125.0, "damage": 5, "rarity": "common",
		"low_hp_bonus": 5, "targets": ENEMY_TARGETS, "icon": "battle",
		"description": "Deal 5 extra damage to a target below half HP.",
	},
	"tap_bolt": {
		"label": "Tap Bolt", "short_label": "Tap", "width": 1, "range": 310.0, "damage": 4, "rarity": "common",
		"ranged": true, "windup_bonus": 5, "targets": ENEMY_TARGETS, "icon": "shot",
		"description": "Deal 5 extra damage to a target winding up an attack.",
	},
	"stave_crush": {
		"label": "Stave Crush", "width": 3, "range": 185.0, "damage": 21, "rarity": "common",
		"guard_break": 5, "targets": ENEMY_TARGETS, "icon": "battle",
		"description": "Strip up to 5 Guard before the hit.",
	},
	"ward_lantern": {
		"label": "Ward Lantern", "width": 4, "range": 0.0, "damage": 0, "rarity": "uncommon",
		"guard": 9, "heal": 8, "support": "party", "targets": ["self"], "icon": "rest",
		"description": "Give every living hero 9 Guard. Restore up to 8 HP to yourself once per fight.",
	},
	"piercing_burst": {
		"label": "Piercing Burst", "width": 3, "range": 450.0, "damage": 17, "rarity": "uncommon",
		"ranged": true, "guard_break": 6, "splash": 90.0, "splash_damage": 10,
		"targets": ENEMY_TARGETS, "icon": "area",
		"description": "Strip up to 6 Guard before the hit. Deal 10 damage to every other enemy within 90 range of the target.",
	},
	"reverse_cut": {
		"label": "Reverse Cut", "width": 2, "range": 190.0, "damage": 15, "rarity": "uncommon",
		"charge": true, "retreat": 72.0, "targets": ENEMY_TARGETS, "icon": "battle",
		"description": "Rush the target if the path is clear. Hit, then back away by up to 72.",
	},
	"flare_mortar": {
		"label": "Flare Mortar", "width": 3, "range": 470.0, "damage": 14, "rarity": "uncommon",
		"ranged": true, "windup_bonus": 8, "splash": 132.0, "splash_damage": 9,
		"targets": ENEMY_TARGETS, "icon": "area",
		"description": "Deal 8 extra damage if the target is winding up. Deal 9 damage to other enemies within 132 range of it.",
	},
	"rampart_counter": {
		"label": "Rampart Counter", "width": 2, "range": 158.0, "damage": 14, "rarity": "uncommon",
		"guard_bonus": 9, "targets": ENEMY_TARGETS, "icon": "guard",
		"description": "Deal 9 extra damage while you have Guard.",
	},
	"bastion_oath": {
		"label": "Bastion Oath", "width": 4, "range": 172.0, "damage": 16, "rarity": "uncommon",
		"guard_bonus": 10, "guard": 8, "support": "party", "targets": ENEMY_TARGETS, "icon": "guard",
		"description": "Deal 10 extra damage if you have Guard. Give every living hero 8 Guard on hit.",
	},
	"collision_hammer": {
		"label": "Collision Hammer", "width": 4, "range": 173.0, "damage": 24, "rarity": "uncommon",
		"displaced_bonus": 11, "push": 750.0, "targets": ENEMY_TARGETS, "icon": "push",
		"description": "Deal 11 extra damage if the target was pushed or pulled in the last 3 beats. Knock it back.",
	},
	"gravity_spike": {
		"label": "Gravity Spike", "width": 3, "range": 475.0, "damage": 15, "rarity": "uncommon",
		"ranged": true, "displaced_bonus": 10, "pull": 720.0, "targets": ENEMY_TARGETS, "icon": "pull",
		"description": "Deal 10 extra damage if the target was pushed or pulled in the last 3 beats. Pull it toward you.",
	},
	"ghost_volley": {
		"label": "Ghost Volley", "width": 3, "range": 470.0, "damage": 14, "rarity": "uncommon",
		"ranged": true, "retreat": 95.0, "mark_bonus": 9, "mark_beats": 3, "targets": ENEMY_TARGETS, "icon": "shot",
		"description": "Fire and back away by up to 95. The next tile to hit the target within 3 beats deals 9 extra damage.",
	},
	"comet_charge": {
		"label": "Comet Charge", "width": 3, "range": 410.0, "damage": 21, "rarity": "uncommon",
		"charge": true, "push": 620.0, "windup_bonus": 8, "targets": ENEMY_TARGETS, "icon": "push",
		"description": "Rush the target if the path is clear and knock it back. Deal 8 extra damage if it is winding up.",
	},
	"chorus_bolt": {
		"label": "Chorus Bolt", "width": 3, "range": 450.0, "damage": 12, "rarity": "uncommon",
		"ranged": true, "mark_bonus": 9, "mark_beats": 3, "guard": 6, "support": "weakest",
		"targets": ENEMY_TARGETS, "icon": "shot",
		"description": "Give 6 Guard to the living hero with the lowest HP on hit. The next tile to hit the target within 3 beats deals 9 extra damage.",
	},
	"triage_kit": {
		"label": "Triage Kit", "width": 4, "range": 0.0, "damage": 0, "rarity": "uncommon",
		"guard": 11, "heal": 14, "support": "weakest", "targets": ["self"], "icon": "rest",
		"description": "Give the living hero with the lowest HP 11 Guard. Restore up to 14 HP to that hero once per fight.",
	},
	"runic_anvil": {
		"label": "Runic Anvil", "width": 5, "range": 165.0, "damage": 30, "rarity": "uncommon",
		"guard_break": 10, "splash": 115.0, "splash_damage": 14, "targets": ENEMY_TARGETS, "icon": "area",
		"description": "Strip up to 10 Guard before the hit. Deal 14 damage to every other enemy within 115 range of the target.",
	},
	"horizon_round": {
		"label": "Horizon Round", "width": 4, "range": 720.0, "damage": 21, "rarity": "uncommon",
		"ranged": true, "distance_bonus": 15, "mark_bonus": 7, "mark_beats": 3, "targets": ENEMY_TARGETS, "icon": "shot",
		"description": "Deal 15 extra damage beyond 210 range. The next tile to hit the target within 3 beats deals 7 extra damage.",
	},
	"cinder_wave": {
		"label": "Cinder Wave", "width": 3, "range": 330.0, "damage": 15, "rarity": "uncommon",
		"ranged": true, "displaced_bonus": 10, "splash": 150.0, "splash_damage": 11,
		"targets": ENEMY_TARGETS, "icon": "area",
		"description": "Deal 10 extra damage if the target was pushed or pulled in the last 3 beats. Deal 11 damage to other enemies within 150 range of it.",
	},
	"needle_point": {
		"label": "Needle Point", "short_label": "Needle", "width": 1, "range": 125.0, "damage": 7, "rarity": "uncommon",
		"low_hp_bonus": 5, "targets": ENEMY_TARGETS, "icon": "battle",
		"description": "Deal 5 extra damage to a target below half HP.",
	},
}
