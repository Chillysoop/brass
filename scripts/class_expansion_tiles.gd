extends RefCounted

const COMMON_IDS := [
	"iron_arc", "iron_vow", "line_guard", "pilgrim_aid", "short_fuse", "rake", "furnace_burst", "tether_dart",
	"bellows_strike", "lantern_shot", "slip_cut", "spur", "spark_shot", "crosscut", "tap_bolt", "stave_crush",
	"backdraft_bolt", "parallax_shot",
	"reversal_plate", "rampart_rush", "convergence_pulse", "severing_tether",
	"tonic_dart", "catalyst_flask", "pinpoint_lunge", "vanishing_cut",
	"aegis_intercept", "shieldshock", "domino_maul", "impact_driver", "phalanx_charge", "recoil_thrust",
	"guard_refrain", "echo_chime", "hammer_stamp", "quick_etch", "mirror_dart", "veil_step", "cinder_brand", "wildfire_globe",
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
		"retreat": 92.0, "targets": ENEMY_TARGETS, "icon": "battle",
		"description": "Strike, then dash away from the target by up to 92.",
	},
	"spur": {
		"label": "Spur", "width": 2, "range": 325.0, "damage": 12, "rarity": "common",
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
	"backdraft_bolt": {
		"label": "Backdraft Bolt", "width": 2, "range": 520.0, "damage": 14, "rarity": "common",
		"ranged": true, "retreat": 60.0, "dash_followup_damage": 7, "dash_followup_beats": 2,
		"targets": ENEMY_TARGETS, "icon": "shot",
		"description": "Fire and backstep up to 60 units. Dash or backstep in the prior 2 beats to fire a second hit for 7 damage.",
	},
	"parallax_shot": {
		"label": "Parallax Shot", "width": 3, "range": 680.0, "damage": 19, "rarity": "common",
		"ranged": true, "long_critical_bonus": 0.20, "targets": ENEMY_TARGETS, "icon": "shot",
		"description": "From more than 210 units away, add 20 percentage points to this shot's critical chance.",
	},
	"reversal_plate": {
		"label": "Reversal Plate", "width": 2, "range": 160.0, "damage": 14, "rarity": "common",
		"guard": 5, "recent_block_damage": 8, "recent_block_beats": 3, "targets": ENEMY_TARGETS, "icon": "guard",
		"description": "Gain 5 Guard on hit. Deal 8 extra damage if your Guard absorbed an enemy hit in the last 3 beats.",
	},
	"rampart_rush": {
		"label": "Rampart Rush", "width": 3, "range": 375.0, "damage": 16, "rarity": "common",
		"charge": true, "push": 570.0, "sweep_push_radius": 120.0, "sweep_push_force": 390.0,
		"guard": 4, "targets": ENEMY_TARGETS, "icon": "push",
		"description": "Rush and knock back the target and other enemies within 120 units of the impact. Gain 4 Guard on hit.",
	},
	"convergence_pulse": {
		"label": "Convergence Pulse", "short_label": "Convergence", "width": 3, "range": 475.0, "damage": 15, "rarity": "common",
		"ranged": true, "convergence_radius": 210.0, "convergence_force": 620.0, "convergence_targets": 3,
		"convergence_damage_per_pull": 4, "targets": ENEMY_TARGETS, "icon": "pull",
		"description": "Draw up to 3 other enemies within 210 units toward the target. Deal 4 extra damage to the target for each enemy moved inward.",
	},
	"severing_tether": {
		"label": "Severing Tether", "width": 2, "range": 465.0, "damage": 12, "rarity": "common",
		"ranged": true, "isolation_pull_force": 675.0, "isolation_distance": 44.0, "isolation_damage": 7,
		"targets": ENEMY_TARGETS, "icon": "pull",
		"description": "Pull the target toward you. Deal 7 extra damage if the pull moves it at least 44 units farther from its nearest ally.",
	},
	"tonic_dart": {
		"label": "Tonic Dart", "width": 2, "range": 450.0, "damage": 10, "rarity": "common",
		"ranged": true, "heal": 4, "guard": 1, "heal_overflow_on_hit": true, "targets": ENEMY_TARGETS, "icon": "rest",
		"description": "On hit, give 1 Guard to the living hero missing the most HP. Once per fight, if they are injured, also restore up to 4 HP and convert leftover healing to Guard.",
	},
	"catalyst_flask": {
		"label": "Catalyst Flask", "width": 3, "range": 410.0, "damage": 15, "rarity": "common",
		"ranged": true, "splash": 110.0, "splash_damage": 6, "healing_damage_bonus": 4, "targets": ENEMY_TARGETS, "icon": "area",
		"description": "Splash other enemies within 110 units for 6 damage. If a hero has already regained HP this loop, the hit and splash deal 4 more damage.",
	},
	"pinpoint_lunge": {
		"label": "Pinpoint Lunge", "width": 2, "range": 335.0, "damage": 13, "rarity": "common",
		"charge": true, "flank_charge": true, "repeat_target_damage": 6, "targets": ENEMY_TARGETS, "icon": "battle",
		"description": "Curve around the target when there is room, or rush directly. Deal 6 extra damage if your last landed attack hit the same enemy.",
	},
	"vanishing_cut": {
		"label": "Vanishing Cut", "width": 3, "range": 420.0, "damage": 15, "rarity": "common",
		"blink_strike": true, "low_hp_bonus": 6, "duel_kill_bonus": 7, "targets": ENEMY_TARGETS, "icon": "teleport",
		"description": "Blink beside the target and strike. Deal 6 extra damage below half HP. On kill, your next hit on another enemy within 12 beats deals 7 extra damage.",
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
		"label": "Reverse Cut", "width": 2, "range": 280.0, "damage": 15, "rarity": "uncommon",
		"charge": true, "retreat": 126.0, "targets": ENEMY_TARGETS, "icon": "battle",
		"description": "Rush the target if the path is clear. Hit, then dash away by up to 126.",
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
		"ranged": true, "retreat": 150.0, "mark_bonus": 9, "mark_beats": 3, "targets": ENEMY_TARGETS, "icon": "shot",
		"description": "Fire and dash away by up to 150. The next tile to hit the target within 3 beats deals 9 extra damage.",
	},
	"comet_charge": {
		"label": "Comet Charge", "width": 3, "range": 540.0, "damage": 21, "rarity": "uncommon",
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
