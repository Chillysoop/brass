extends RefCounted

const ArsenalTiles = preload("res://scripts/arsenal_tiles.gd")
const ClassExpansionTiles = preload("res://scripts/class_expansion_tiles.gd")
const UniversalTileUpgrades = preload("res://scripts/universal_tile_upgrades.gd")
const GlassPilotEnemies = preload("res://scripts/glass_pilot_enemies.gd")
const MoonPilotEnemies = preload("res://scripts/moon_pilot_enemies.gd")
const BrassVarietyEnemies = preload("res://scripts/brass_variety_enemies.gd")
const CrownVarietyEnemies = preload("res://scripts/crown_variety_enemies.gd")
const TileEnchantments = preload("res://scripts/tile_enchantments.gd")
const ClassMasteries = preload("res://scripts/class_masteries.gd")
const StarterSpecialtyEffects = preload("res://scripts/starter_specialty_effects.gd")
const ApothecaryTiles = preload("res://scripts/apothecary_tiles.gd")
const VanguardSpecialties = preload("res://scripts/vanguard_specialties.gd")
const ArtificeSpecialties = preload("res://scripts/artifice_specialties.gd")
const PILOT_ENEMY_SCRIPTS := {
	"brass": BrassVarietyEnemies, "glass": GlassPilotEnemies,
	"crown": CrownVarietyEnemies, "moonwreck": MoonPilotEnemies,
}
const CORE_ENEMY_REGIONS := {
	"recruit": "brass", "scout": "brass", "bruiser": "brass", "veteran": "brass",
	"glass_recruit": "glass", "glass_hunter": "glass", "glass_skirmisher": "glass", "glass_overseer": "glass",
	"relay_recruit": "crown", "relay_runner": "crown", "relay_lancer": "crown",
	"dock_recruit": "moonwreck", "dock_bruiser": "moonwreck",
}

const BEATS := 12
const LANCE_TRAVEL_CAP := 80.0
const TICKS_PER_BEAT := 21
const TICKS_PER_SECOND := 60
const LOOP_TICKS := BEATS * TICKS_PER_BEAT
const ARENA_SIZE := Vector2(1000, 520)
const WALL_MARGIN := 26.0
const PURSUIT_SPRINT_START := 125.0
const PURSUIT_SPRINT_FULL := 255.0
const PURSUIT_SPRINT_BONUS := 0.46
const RETREAT_LOOKAHEAD := 52.0
const IMPULSE_CAP := 1000.0
const IMPULSE_DECAY := 1850.0
const MARSHAL_SWEEP_EXTRA_REACH := 48.0
const MARSHAL_MEDIUM_PLATE := 120
const MARSHAL_MEDIUM_SWEEP_DAMAGE := 26
const MARSHAL_WEATHERED_SWEEP_WEAR := 48
const COLOSSUS_SWEEP_BEATS := 9
const COLOSSUS_EXTRA_REACH := 110.0
const RELAY_LINK_REACH := 115.0
const RELAY_BREAK_REACH := 162.0
const RELAY_CHARGE_BEATS := 6
const RELAY_MARSHAL_CHARGE_BEATS := 8
const CROWN_CHARGE_BEATS := 8
const CROWN_LINK_RECONNECT_BEATS := 5
const CROWN_TARGET_RULES := ["relay_left", "relay_right", "relay_regent"]
const DOCK_WINCH_TICKS := 42
const WRECKMASTER_HARPOON_TICKS := 2 * TICKS_PER_BEAT - 1
const WRECKMASTER_SLAM_TICKS := 3 * TICKS_PER_BEAT
const WRECKMASTER_SLAM_RADIUS := 126.0
const TIDEKEEPER_SLAM_BEATS := 5
const TIDEKEEPER_SLAM_RADIUS := 310.0
const ADMIRAL_SWEEP_BEATS := 6
const ADMIRAL_SWEEP_RADIUS := 330.0
const PRECISION_BONUS_RANGE := 210.0
const PRECISION_SPACING := 245.0
const BASE_CRITICAL_CHANCE := 0.05
const CRITICAL_DAMAGE_MULTIPLIER := 1.5
const STARSHOT_CRITICAL_CHANCE := 0.15
const STARSHOT_LONG_CRITICAL_CHANCE := 0.30
const STARSHOT_CRITICAL_STEP := 64.0
const CRITICAL_RNG_SALT := 182827
const DISPLACEMENT_BONUS_WINDOW := 3 * TICKS_PER_BEAT
const COLLISION_WINDOW_TICKS := 24
const BARRAGE_GUARD_BREAK := 8
const SIEGE_PULL_REACH := 185.0
const SIEGE_PULL_DISTANCE := 82.0
const MAX_GUARD := 28
const OVERFLOW_HEAL_CAP := 6
const LONGSHOT_PRISM_RANGE := 180.0
const TOLLKEEPER_SIGNET_DAMAGE := 3
const TOLLKEEPER_SIGNET_LAST_BEAT := 4
const BASTION_MEDAL_GUARD := 3
const TOLLKEEPER_REPAIR_KIT_HP := 3
const BELLMAKER_CLAPPER_RADIUS := 110.0
const BELLMAKER_CLAPPER_DAMAGE := 8
const BELLMAKER_LONG_ECHO_DAMAGE := 4
const BELLMAKER_RESONANT_PLATE_GUARD := 4
const TOLLKEEPER_REPAIR_CUE := "tollkeeper_repair"
const BOSS_REVIEW_STAGES := {
	"tollkeeper_repair": "start", "tollkeeper_repair_interrupted": "success", "tollkeeper_repair_separated": "success",
	"marshal_plate": "start", "marshal_exposed": "progress", "marshal_shattered": "success",
	"marshal_plate_worn": "progress", "marshal_sweep_weathered": "progress",
	"marshal_pressure_break": "success", "marshal_defense_break": "success",
	"regent_seals": "start", "regent_seal_struck": "progress", "regent_shattered": "success",
	"crucible_rally": "progress", "prism_ward": "start", "prism_exposed": "progress", "prism_shattered": "success",
	"colossus_forging": "start", "colossus_displaced": "progress", "colossus_cracked": "progress", "colossus_shattered": "success",
	"relay_charge": "start", "relay_interrupted": "success", "relay_discharge": "miss",
	"relay_marshal_charge": "start", "relay_marshal_separated": "progress", "relay_marshal_interrupted": "success",
	"crown_regent_charge": "start", "crown_link_separated": "progress", "crown_regent_interrupted": "success",
	"wreckmaster_slam_windup": "start", "wreckmaster_slam_miss": "success",
	"tidekeeper_slam_windup": "start", "tidekeeper_unanchored": "progress", "tidekeeper_interrupted": "success",
	"admiral_sweep_windup": "start", "admiral_unanchored": "progress", "admiral_reversed": "progress", "admiral_interrupted": "success",
}
const TARGET_RULES := ["nearest", "farthest", "lowest_hp", "highest_hp"]
const RANGED_TILES := [
	"pull", "gravity_hook", "shot", "hook_bash", "graviton", "event_horizon", "meteor_seal",
	"ward_step", "mirror_step", "prism_stride", "sanctuary_gate",
	"longshot", "split_shot", "deadeye", "volley", "rail_shot", "flak_burst", "star_piercer", "meteor_volley",
]
const BASH_TIERS := [
	["bash"],
	["shield_ram", "hook_bash"],
	["bulwark_charge", "rebound"],
	["sunwall", "graviton"],
	["dawn_bastion", "event_horizon"],
]
const BLINK_TIERS := [
	["blink"],
	["phase_cut", "ward_step"],
	["rift_lunge", "mirror_step"],
	["void_dance", "prism_stride"],
	["starfall_step", "sanctuary_gate"],
]
const SHOT_TIERS := [
	["shot"],
	["longshot", "split_shot"],
	["deadeye", "volley"],
	["rail_shot", "flak_burst"],
	["star_piercer", "meteor_volley"],
]
const GUARD_TIERS := [
	["guard"],
	["riposte", "rally_guard"],
	["counterwall", "ward_link"],
	["iron_rebuke", "shield_chorus"],
	["last_stand", "aegis_network"],
]
const SLAM_TIERS := [
	["slam"],
	["shockwave", "sundering_slam"],
	["quake", "armor_crush"],
	["fault_line", "hammerfall"],
	["worldbreaker", "skybreaker"],
]
const CORE_FORGE_FAMILIES := {
	"bash": BASH_TIERS, "blink": BLINK_TIERS, "shot": SHOT_TIERS, "guard": GUARD_TIERS, "slam": SLAM_TIERS,
}
const HERO_CLASSES := {
	"warden": {"label": "Warden", "description": "Gain 4 guard on the first Bash-family hit each loop."},
	"bulwark": {"label": "Bulwark", "description": "Once per loop, intercept an ally's incoming strike and reduce it by 6. Alone, reduce your first strike."},
	"breaker": {"label": "Breaker", "description": "A push that sends a foe into another deals 5 extra damage to both."},
	"hexwright": {"label": "Hexwright", "description": "Pull tiles draw enemies in with extra force."},
	"wayfarer": {"label": "Wayfarer", "description": "Move faster for three beats after teleporting."},
	"lancer": {"label": "Lancer", "description": "Moving 80 units charges your next hit for 6 bonus damage."},
	"cantor": {"label": "Cantor", "description": "Echo 3 guard to the lowest-HP ally when you grant guard, including yourself."},
	"apothecary": {"label": "Apothecary", "description": "Your first tile hit each loop heals 2 HP. Excess healing becomes guard."},
	"rune_smith": {"label": "Rune Smith", "description": "Finish a tile at least 3 beats wide to charge your next hit for 5 bonus damage."},
	"starshot": {"label": "Starshot", "description": "Ranged critical chance is 15%, rising to 30% beyond 210 units. The first critical shot each loop can dash back. Deal 5 extra damage beyond 200 units."},
	"cinder_mage": {"label": "Cinder Mage", "description": "Once per loop, hitting a displaced enemy burns it for 6 damage."},
	"duelist": {"label": "Duelist", "description": "Repeated hits on one target build up to 6 bonus damage. Resets when you switch."}
}
const CAMPAIGN_ENEMIES := {
	"recruit": {"name": "Clockwork Recruit", "art": "brass_recruit", "hp": 30, "radius": 24.0, "speed": 87.0,
		"spacing": 85.0, "reach": 128.0, "damage": 3, "first": 116, "cooldown": 170, "windup": 27},
	"bruiser": {"name": "Rivet Bruiser", "art": "brass_bruiser", "hp": 134, "radius": 29.0, "speed": 80.0,
		"spacing": 93.0, "reach": 155.0, "damage": 11, "first": 115, "cooldown": 139, "windup": 27, "push": 235.0},
	"scout": {"name": "Clockwork Scout", "art": "scout", "hp": 53, "radius": 17.0, "speed": 68.0,
		"spacing": 145.0, "reach": 224.0, "damage": 7, "first": 157, "cooldown": 143, "windup": 25},
	"veteran": {"name": "Rivet Captain", "art": "brass_captain", "hp": 168, "radius": 33.0, "speed": 83.0,
		"spacing": 95.0, "reach": 171.0, "damage": 14, "first": 116, "cooldown": 129, "windup": 31, "push": 310.0},
	"brass_sapper": {"name": "Rivet Bombardier", "art": "brass_sapper", "hp": 65, "radius": 22.0, "speed": 74.0,
		"spacing": 252.0, "reach": 405.0, "damage": 9, "first": 119, "cooldown": 143, "windup": 42,
		"special": "bombard", "blast_radius": 89.0},
	"boss": {"name": "The Tollkeeper", "art": "brass_tollkeeper", "hp": 330, "radius": 40.0, "speed": 86.0,
		"spacing": 107.0, "reach": 204.0, "damage": 16, "first": 125, "cooldown": 123, "windup": 39, "push": 345.0, "displacement": 0.55},
	"tollkeeper_drone": {"name": "Repair Drone", "art": "tollkeeper_drone", "hp": 36, "radius": 19.0, "speed": 75.0,
		"spacing": 77.0, "reach": 132.0, "damage": 4, "first": 133, "cooldown": 172, "windup": 49,
		"special": "repair", "repair_reach": 132.0, "repair_amount": 14, "repair_cue": TOLLKEEPER_REPAIR_CUE},
	"marshal": {"name": "The Gilded Marshal", "art": "marshal", "hp": 860, "radius": 48.0, "speed": 89.0,
		"spacing": 122.0, "reach": 227.0, "damage": 38, "first": 110, "cooldown": 105, "windup": 49, "push": 415.0, "displacement": 0.7},
	"regent": {"name": "The Iron Regent", "art": "regent", "hp": 1140, "radius": 51.0, "speed": 86.0,
		"spacing": 118.0, "reach": 222.0, "damage": 43, "first": 114, "cooldown": 112, "windup": 54, "push": 380.0, "displacement": 0.6},
	"glass_recruit": {"name": "Glass Apprentice", "art": "glass_recruit", "hp": 34, "radius": 24.0, "speed": 87.0,
		"spacing": 83.0, "reach": 131.0, "damage": 4, "first": 115, "cooldown": 173, "windup": 31, "target": "ranged_damage"},
	"glass_hunter": {"name": "Glass Hunter", "art": "glass_hunter", "hp": 103, "radius": 24.0, "speed": 85.0,
		"spacing": 131.0, "reach": 218.0, "damage": 11, "first": 118, "cooldown": 136, "windup": 33, "target": "ranged_damage"},
	"glass_skirmisher": {"name": "Kiln Skirmisher", "art": "glass_skirmisher", "hp": 52, "radius": 18.0, "speed": 123.0,
		"spacing": 85.0, "reach": 129.0, "damage": 7, "first": 132, "cooldown": 154, "windup": 24, "target": "lowest_hp"},
	"glass_overseer": {"name": "Kiln Overseer", "art": "glass_overseer", "hp": 157, "radius": 33.0, "speed": 85.0,
		"spacing": 112.0, "reach": 202.0, "damage": 13, "first": 113, "cooldown": 122, "windup": 36, "target": "ranged_damage"},
	"glass_duelist": {"name": "Kiln Duelist", "art": "glass_duelist", "hp": 59, "radius": 20.0, "speed": 107.0,
		"spacing": 164.0, "reach": 255.0, "damage": 9, "first": 129, "cooldown": 149, "windup": 31,
		"special": "blink_strike", "target": "lowest_hp"},
	"glass_twin": {"name": "Crucible Twin · Glass", "art": "glass_twin", "hp": 139, "radius": 33.0, "speed": 89.0,
		"spacing": 136.0, "reach": 215.0, "damage": 12, "first": 120, "cooldown": 139, "windup": 37, "target": "ranged_damage",
		"twin": true, "displacement": 0.76},
	"ember_twin": {"name": "Crucible Twin · Ember", "art": "ember_twin", "hp": 139, "radius": 33.0, "speed": 99.0,
		"spacing": 91.0, "reach": 160.0, "damage": 13, "first": 146, "cooldown": 143, "windup": 32, "target": "lowest_hp",
		"twin": true, "push": 210.0, "displacement": 0.76},
	"prism_warden": {"name": "The Prism Warden", "art": "prism_warden", "hp": 870, "radius": 46.0, "speed": 98.0,
		"spacing": 136.0, "reach": 266.0, "damage": 29, "first": 120, "cooldown": 118, "windup": 49,
		"target": "ranged_damage", "push": 320.0, "displacement": 0.82},
	"tempered_colossus": {"name": "The Tempered Colossus", "art": "tempered_colossus", "hp": 1220, "radius": 52.0, "speed": 86.0,
		"spacing": 130.0, "reach": 232.0, "damage": 39, "first": 116, "cooldown": 117, "windup": 48,
		"target": "ranged_damage", "push": 335.0, "displacement": 0.66},
	"relay_recruit": {"name": "Relay Initiate", "art": "relay_recruit", "hp": 34, "radius": 21.0, "speed": 91.0,
		"spacing": 83.0, "reach": 128.0, "damage": 4, "first": 118, "cooldown": 174, "windup": 30,
		"windup_displacement": 0.45},
	"relay_runner": {"name": "Relay Runner", "art": "relay_runner", "hp": 59, "radius": 19.0, "speed": 101.0,
		"spacing": 88.0, "reach": 149.0, "damage": 8, "first": 124, "cooldown": 155, "windup": 27},
	"relay_guard": {"name": "Relay Guard", "art": "relay_guard", "hp": 62, "radius": 25.0, "speed": 80.0,
		"spacing": 105.0, "reach": 145.0, "damage": 4, "first": 150, "cooldown": 186, "windup": 33, "support": true},
	"relay_lancer": {"name": "Crown Lancer", "art": "relay_lancer", "hp": 130, "radius": 31.0, "speed": 90.0,
		"spacing": 105.0, "reach": 171.0, "damage": 11, "first": 120, "cooldown": 151, "windup": 33, "push": 215.0},
	"crown_mender": {"name": "Relay Mender", "art": "crown_mender", "hp": 58, "radius": 24.0, "speed": 79.0,
		"spacing": 160.0, "reach": 204.0, "damage": 6, "first": 138, "cooldown": 166, "windup": 35,
		"special": "repair", "repair_reach": 260.0},
	"relay_captain": {"name": "The Relay Captain", "art": "relay_captain", "hp": 380, "radius": 42.0, "speed": 91.0,
		"spacing": 108.0, "reach": 190.0, "damage": 14, "first": 121, "cooldown": 128, "windup": 33, "push": 270.0,
		"displacement": 0.58},
	"relay_marshal": {"name": "The Relay Marshal", "art": "relay_marshal", "hp": 750, "radius": 46.0, "speed": 93.0,
		"spacing": 110.0, "reach": 208.0, "damage": 24, "first": 121, "cooldown": 117, "windup": 39, "push": 300.0,
		"displacement": 0.82},
	"crown_regent": {"name": "The Crown Regent", "art": "crown_regent", "hp": 1100, "radius": 49.0, "speed": 90.0,
		"spacing": 116.0, "reach": 220.0, "damage": 33, "first": 116, "cooldown": 115, "windup": 45, "push": 330.0,
		"displacement": 0.72},
	"dock_recruit": {"name": "Dockhand", "art": "dock_recruit", "hp": 33, "radius": 22.0, "speed": 90.0,
		"spacing": 85.0, "reach": 130.0, "damage": 4, "first": 118, "cooldown": 178, "windup": 29},
	"dock_bruiser": {"name": "Dock Bruiser", "art": "dock_bruiser", "hp": 112, "radius": 31.0, "speed": 69.0,
		"spacing": 92.0, "reach": 147.0, "damage": 10, "first": 130, "cooldown": 151, "windup": 32},
	"dock_winch": {"name": "Winch Operator", "art": "dock_winch", "hp": 60, "radius": 24.0, "speed": 73.0,
		"spacing": 102.0, "reach": 147.0, "damage": 4, "first": 52, "cooldown": 190, "windup": 34},
	"dock_corsair": {"name": "Dock Corsair", "art": "dock_corsair", "hp": 78, "radius": 26.0, "speed": 94.0,
		"spacing": 95.0, "reach": 154.0, "damage": 9, "first": 29, "cooldown": 142, "windup": 32,
		"special": "grapple", "grapple_reach": 320.0},
	"wreckmaster": {"name": "The Wreckmaster", "art": "wreckmaster", "hp": 386, "radius": 42.0, "speed": 87.0,
		"spacing": 112.0, "reach": 177.0, "damage": 10, "first": 128, "cooldown": 140, "windup": 37},
	"tidekeeper": {"name": "The Tidekeeper", "art": "tidekeeper", "hp": 755, "radius": 46.0, "speed": 87.0,
		"spacing": 108.0, "reach": 191.0, "damage": 22, "first": 136, "cooldown": 119, "windup": 37,
		"push": 315.0, "displacement": 0.77},
	"drowned_admiral": {"name": "The Drowned Admiral", "art": "drowned_admiral", "hp": 1150, "radius": 50.0, "speed": 87.0,
		"spacing": 111.0, "reach": 205.0, "damage": 31, "first": 150, "cooldown": 119, "windup": 39,
		"push": 345.0, "displacement": 0.73}
}

const CORE_TILES := {
	"pull": {
		"label": "Pull", "width": 3, "range": 610.0, "damage": 5,
		"targets": TARGET_RULES, "description": "Drag an enemy toward you."
	},
	"gravity_hook": {
		"label": "Gravity Hook", "width": 3, "range": 720.0, "damage": 8, "rarity": "common",
		"targets": TARGET_RULES, "description": "Reach across the arena and pull an enemy in with extra force."
	},
	"bash": {
		"label": "Bash", "width": 2, "range": 150.0, "damage": 17,
		"family": "bash", "rarity": "common",
		"targets": TARGET_RULES, "description": "Hit an enemy and knock them back."
	},
	"guard": {
		"label": "Guard", "width": 2, "range": 0.0, "damage": 0,
		"family": "guard", "rarity": "common", "guard": 10,
		"targets": ["self"], "description": "Gain 10 guard to absorb incoming damage."
	},
	"shot": {
		"label": "Shot", "width": 2, "range": 535.0, "damage": 14,
		"family": "shot", "rarity": "common",
		"targets": TARGET_RULES, "description": "Strike one enemy at range."
	},
	"longshot": {
		"label": "Longshot", "width": 2, "range": 610.0, "damage": 17,
		"family": "shot", "rarity": "uncommon", "distance_bonus": 6,
		"targets": TARGET_RULES, "description": "Hit one enemy. Deal 6 extra damage beyond 210 range."
	},
	"split_shot": {
		"label": "Split Shot", "width": 2, "range": 490.0, "damage": 16,
		"family": "shot", "rarity": "uncommon", "splash": 130.0, "splash_targets": 1, "splash_damage": 12,
		"targets": TARGET_RULES, "description": "Hit one enemy, then deal 12 damage to its nearest neighbor within 130 range."
	},
	"deadeye": {
		"label": "Deadeye", "width": 3, "range": 675.0, "damage": 25,
		"family": "shot", "rarity": "rare", "distance_bonus": 11,
		"targets": TARGET_RULES, "description": "Hit one enemy. Deal 11 extra damage beyond 210 range."
	},
	"volley": {
		"label": "Volley", "width": 3, "range": 535.0, "damage": 22,
		"family": "shot", "rarity": "rare", "splash": 150.0, "splash_targets": 2, "splash_damage": 17,
		"targets": TARGET_RULES, "description": "Hit one enemy, then deal 17 damage to up to two neighbors within 150 range."
	},
	"rail_shot": {
		"label": "Rail Shot", "width": 4, "range": 735.0, "damage": 33,
		"family": "shot", "rarity": "epic", "distance_bonus": 16,
		"targets": TARGET_RULES, "description": "Hit one enemy. Deal 16 extra damage beyond 210 range."
	},
	"flak_burst": {
		"label": "Flak Burst", "width": 4, "range": 580.0, "damage": 28,
		"family": "shot", "rarity": "epic", "splash": 165.0, "splash_damage": 23,
		"targets": TARGET_RULES, "description": "Hit one enemy and deal 23 damage to every other enemy within 165 range of it."
	},
	"star_piercer": {
		"label": "Star Piercer", "width": 5, "range": 800.0, "damage": 43,
		"family": "shot", "rarity": "legendary", "distance_bonus": 23,
		"targets": TARGET_RULES, "description": "Hit one enemy. Deal 23 extra damage beyond 210 range."
	},
	"meteor_volley": {
		"label": "Meteor Volley", "width": 5, "range": 625.0, "damage": 37,
		"family": "shot", "rarity": "legendary", "splash": 200.0, "splash_damage": 30,
		"targets": TARGET_RULES, "description": "Hit one enemy and deal 30 damage to every other enemy within 200 range of it."
	},
	"riposte": {
		"label": "Riposte", "width": 2, "range": 150.0, "damage": 13,
		"family": "guard", "rarity": "uncommon", "guard": 8, "guard_bonus_cap": 10,
		"targets": TARGET_RULES, "description": "Strike and spend up to 10 guard for extra damage. Gain 8 guard even if no target is in range."
	},
	"rally_guard": {
		"label": "Rally Guard", "width": 2, "range": 0.0, "damage": 0,
		"family": "guard", "rarity": "uncommon", "guard": 13, "support": "weakest",
		"targets": ["self"], "description": "Give yourself and your lowest-health ally 13 guard each."
	},
	"counterwall": {
		"label": "Counterwall", "width": 3, "range": 175.0, "damage": 20,
		"family": "guard", "rarity": "rare", "guard": 12, "guard_bonus_cap": 14,
		"targets": TARGET_RULES, "description": "Strike and spend up to 14 guard for extra damage. Gain 12 guard even if no target is in range."
	},
	"ward_link": {
		"label": "Ward Link", "width": 3, "range": 0.0, "damage": 0,
		"family": "guard", "rarity": "rare", "guard": 17, "support": "weakest",
		"targets": ["self"], "description": "Give yourself and your lowest-health ally 17 guard each."
	},
	"iron_rebuke": {
		"label": "Iron Rebuke", "width": 4, "range": 200.0, "damage": 27,
		"family": "guard", "rarity": "epic", "guard": 16, "guard_bonus_cap": 18, "push": 620.0,
		"targets": TARGET_RULES, "description": "Strike and push. Spend up to 18 guard for extra damage. Gain 16 guard even if no target is in range."
	},
	"shield_chorus": {
		"label": "Shield Chorus", "width": 4, "range": 0.0, "damage": 0,
		"family": "guard", "rarity": "epic", "guard": 17, "support": "party",
		"targets": ["self"], "description": "Give every living hero 17 guard."
	},
	"last_stand": {
		"label": "Last Stand", "width": 5, "range": 225.0, "damage": 37,
		"family": "guard", "rarity": "legendary", "guard": 21, "guard_bonus_cap": 22, "push": 810.0,
		"targets": TARGET_RULES, "description": "Strike and push. Spend up to 22 guard for extra damage. Gain 21 guard even if no target is in range."
	},
	"aegis_network": {
		"label": "Aegis Network", "width": 5, "range": 0.0, "damage": 0,
		"family": "guard", "rarity": "legendary", "guard": 20, "support": "party", "weakest_bonus": 7,
		"targets": ["self"], "description": "Give every living hero 20 guard. Your lowest-health hero gets 7 extra."
	},
	"blink": {
		"label": "Blink", "width": 3, "range": 560.0, "damage": 8,
		"family": "blink", "rarity": "common",
		"targets": TARGET_RULES, "description": "Teleport behind an enemy and strike."
	},
	"phase_cut": {
		"label": "Phase Cut", "width": 3, "range": 620.0, "damage": 25,
		"family": "blink", "rarity": "uncommon",
		"targets": TARGET_RULES, "description": "Teleport behind an enemy and deal a heavier strike from longer range."
	},
	"ward_step": {
		"label": "Ward Step", "width": 3, "range": 560.0, "damage": 19,
		"family": "blink", "rarity": "uncommon", "retreat": 173.0, "guard": 10,
		"targets": TARGET_RULES, "description": "Teleport away from the target and strike it. Gain 10 guard."
	},
	"rift_lunge": {
		"label": "Rift Lunge", "width": 3, "range": 665.0, "damage": 29,
		"family": "blink", "rarity": "rare", "push": 610.0,
		"targets": TARGET_RULES, "description": "Teleport behind an enemy, then strike and knock it away from your landing point."
	},
	"mirror_step": {
		"label": "Mirror Step", "width": 3, "range": 600.0, "damage": 23,
		"family": "blink", "rarity": "rare", "retreat": 216.0, "guard": 13,
		"targets": TARGET_RULES, "description": "Teleport farther away from the target and strike it. Gain 13 guard."
	},
	"void_dance": {
		"label": "Void Dance", "width": 4, "range": 710.0, "damage": 33,
		"family": "blink", "rarity": "epic", "splash": 145.0,
		"targets": TARGET_RULES, "description": "Teleport behind an enemy and strike it and other enemies near it."
	},
	"prism_stride": {
		"label": "Prism Stride", "width": 4, "range": 650.0, "damage": 25,
		"family": "blink", "rarity": "epic", "retreat": 245.0, "guard": 15, "guard_radius": 305.0,
		"targets": TARGET_RULES, "description": "Teleport away and strike the target. Give yourself and allies near your landing point 15 guard."
	},
	"starfall_step": {
		"label": "Starfall Step", "width": 5, "range": 790.0, "damage": 39,
		"family": "blink", "rarity": "legendary", "splash": 185.0, "push": 790.0,
		"targets": TARGET_RULES, "description": "Teleport behind an enemy. Strike and knock back every enemy near it, including the target."
	},
	"sanctuary_gate": {
		"label": "Sanctuary Gate", "width": 5, "range": 725.0, "damage": 33,
		"family": "blink", "rarity": "legendary", "retreat": 280.0, "guard": 21, "guard_radius": INF,
		"targets": TARGET_RULES, "description": "Teleport away and strike the target. Give every living ally 21 guard."
	},
	"slam": {
		"label": "Slam", "width": 4, "range": 190.0, "damage": 20,
		"family": "slam", "rarity": "common", "radius": 115.0, "push": 520.0,
		"targets": TARGET_RULES, "description": "Strike near the target and push every enemy caught in the impact."
	},
	"shockwave": {
		"label": "Shockwave", "width": 4, "range": 205.0, "damage": 24,
		"family": "slam", "rarity": "uncommon", "radius": 160.0, "push": 630.0,
		"targets": TARGET_RULES, "description": "Strike and push enemies in a wider area around the target."
	},
	"sundering_slam": {
		"label": "Sundering Slam", "width": 4, "range": 200.0, "damage": 28,
		"family": "slam", "rarity": "uncommon", "radius": 115.0, "push": 545.0, "guard_break": 10,
		"targets": TARGET_RULES, "description": "Remove up to 10 Guard from each enemy caught in the impact, then strike and push them."
	},
	"quake": {
		"label": "Quake", "width": 4, "range": 225.0, "damage": 28,
		"family": "slam", "rarity": "rare", "radius": 190.0, "push": 710.0,
		"targets": TARGET_RULES, "description": "Strike and push enemies in a broad area around the target."
	},
	"armor_crush": {
		"label": "Armor Crush", "width": 4, "range": 215.0, "damage": 34,
		"family": "slam", "rarity": "rare", "radius": 125.0, "push": 570.0, "guard_break": 16,
		"targets": TARGET_RULES, "description": "Remove up to 16 Guard from each enemy caught in the impact, then strike and push them."
	},
	"fault_line": {
		"label": "Fault Line", "width": 4, "range": 245.0, "damage": 32,
		"family": "slam", "rarity": "epic", "radius": 220.0, "push": 790.0,
		"targets": TARGET_RULES, "description": "Strike and shove enemies across a wide area around the target."
	},
	"hammerfall": {
		"label": "Hammerfall", "width": 4, "range": 230.0, "damage": 40,
		"family": "slam", "rarity": "epic", "radius": 140.0, "push": 640.0, "guard_break": 22,
		"targets": TARGET_RULES, "description": "Remove up to 22 Guard from each enemy caught in the impact, then strike and push them."
	},
	"worldbreaker": {
		"label": "Worldbreaker", "width": 5, "range": 280.0, "damage": 43,
		"family": "slam", "rarity": "legendary", "radius": 260.0, "push": 910.0,
		"targets": TARGET_RULES, "description": "Strike and scatter enemies in a large area around the target."
	},
	"skybreaker": {
		"label": "Skybreaker", "width": 5, "range": 250.0, "damage": 52,
		"family": "slam", "rarity": "legendary", "radius": 160.0, "push": 760.0, "guard_break": 28,
		"targets": TARGET_RULES, "description": "Remove up to 28 Guard from each enemy caught in the impact, then strike and push them."
	},
	"shield_ram": {
		"label": "Shield Ram", "width": 2, "range": 160.0, "damage": 21,
		"family": "bash", "rarity": "uncommon", "guard_on_hit": 8,
		"targets": TARGET_RULES, "description": "Hit and push an enemy. Gain 8 Guard on hit."
	},
	"hook_bash": {
		"label": "Hook Bash", "width": 2, "range": 490.0, "damage": 18,
		"family": "bash", "rarity": "uncommon",
		"targets": TARGET_RULES, "description": "Hit at range and pull the enemy toward you."
	},
	"bulwark_charge": {
		"label": "Bulwark Charge", "width": 3, "range": 330.0, "damage": 28,
		"family": "bash", "rarity": "rare", "guard_on_hit": 12,
		"targets": TARGET_RULES, "description": "Rush the target if the path is clear, then hit and push. Gain 12 Guard on hit."
	},
	"rebound": {
		"label": "Rebound", "width": 3, "range": 275.0, "damage": 24,
		"family": "bash", "rarity": "rare",
		"targets": TARGET_RULES, "description": "Hit and push. Deal 12 extra damage if the target is still moving from a push or pull."
	},
	"sunwall": {
		"label": "Sunwall", "width": 4, "range": 205.0, "damage": 26,
		"family": "bash", "rarity": "epic",
		"targets": TARGET_RULES, "description": "Push a cluster around the target. Give 14 guard to yourself and nearby allies."
	},
	"graviton": {
		"label": "Graviton", "width": 4, "range": 540.0, "damage": 28,
		"family": "bash", "rarity": "epic",
		"targets": TARGET_RULES, "description": "Hit and reel in the target. Pull nearby enemies into the impact point."
	},
	"dawn_bastion": {
		"label": "Dawn Bastion", "width": 5, "range": 260.0, "damage": 38,
		"family": "bash", "rarity": "legendary",
		"targets": TARGET_RULES, "description": "Hit and scatter a cluster around the target. Give every living ally 22 guard."
	},
	"event_horizon": {
		"label": "Event Horizon", "width": 6, "range": 620.0, "damage": 39,
		"family": "bash", "rarity": "legendary",
		"targets": TARGET_RULES, "description": "Damage and pull enemies around the target. Interrupt their active windups."
	},
	"meteor_seal": {
		"label": "Meteor Seal", "width": 5, "range": 580.0, "damage": 42, "radius": 175.0, "rarity": "legendary",
		"targets": TARGET_RULES, "description": "Drop a meteor on the target, damaging nearby enemies."
	}
}

static var _arsenal_tiles: Dictionary = ArsenalTiles.SPECS.merged(ClassExpansionTiles.SPECS).merged(
	VanguardSpecialties.SPECS).merged(ArtificeSpecialties.SPECS)
static var TILES: Dictionary = CORE_TILES.merged(_arsenal_tiles)
static var FORGE_FAMILIES: Dictionary = CORE_FORGE_FAMILIES.duplicate()

var units: Array[Dictionary] = []
var trace: Array[Dictionary] = []
var visual_cues: Array[Dictionary] = []
var activations: Array[Dictionary] = []
var boss_events: Array[Dictionary] = []
var tick := 0
var outcome := ""
var _reinforcement_wave: Dictionary = {}

var _lanes: Array[Array] = []
var _events: Array[Dictionary] = []
var _activation: Dictionary = {}
var _compass_loop := -1
var _towline_loop := -1
var _towline_mark: Dictionary = {}
var _metronome_loop := -1
var _barrage_hits: Dictionary = {}
var _siege_loop := -1
var _spent_timeline_relics: Dictionary = {}
var _overflow_healed := 0
var _twin_bell_hits: Dictionary = {}
var _healed_tiles: Dictionary = {}
var _last_party_heal_loop := -1
var _enemy_pursuit_sprints := false
var _critical_seed := 0
var _critical_streams: Dictionary = {}


static func _static_init() -> void:
	var upgrades := UniversalTileUpgrades.build(TILES)
	TILES.merge(upgrades.specs, true)
	FORGE_FAMILIES.merge(upgrades.families)
	for id: String in upgrades.specs:
		if not CORE_TILES.has(id):
			_arsenal_tiles[id] = TILES[id]
	_arsenal_tiles.make_read_only()
	TILES.make_read_only()
	FORGE_FAMILIES.make_read_only()


static func is_ranged_tile(tile_id: String) -> bool:
	return tile_id in RANGED_TILES or TILES.get(tile_id, {}).get("ranged", false)


static func critical_chance(class_id: String, tile_id: String, distance: float) -> float:
	var tile: Dictionary = TILES.get(tile_id, {})
	if tile.get("damage", 0) <= 0:
		return 0.0
	var at_distance := distance > PRECISION_BONUS_RANGE
	var chance := BASE_CRITICAL_CHANCE
	if class_id == "starshot" and is_ranged_tile(tile_id):
		chance = STARSHOT_LONG_CRITICAL_CHANCE if at_distance else STARSHOT_CRITICAL_CHANCE
	if at_distance:
		chance += float(tile.get("long_critical_bonus", 0.0))
	return minf(chance, 1.0)


static func is_blink_tile(tile_id: String) -> bool:
	var tile: Dictionary = TILES.get(tile_id, {})
	return tile.get("family", "") == "blink" or tile.get("blink_strike", false) or tile.has("blink_on_hit_retreat")


static func can_trigger_afterimage(tile_id: String) -> bool:
	var tile: Dictionary = TILES[tile_id]
	return tile.damage > 0 and not is_blink_tile(tile_id) and tile_id != "bulwark_charge" \
		and not tile.has("retreat") and not tile.get("charge", false)


static func default_lanes(fixture: String = "duo") -> Array:
	if fixture == "solo":
		return [[
			{"id": "pull", "start": 1, "target": "farthest"},
			{"id": "bash", "start": 4, "target": "nearest"},
			{"id": "shot", "start": 6, "target": "nearest"},
			{"id": "slam", "start": 8, "target": "nearest"}
		]]
	return [
		[
			{"id": "pull", "start": 1, "target": "farthest"},
			{"id": "shot", "start": 5, "target": "lowest_hp"},
			{"id": "blink", "start": 8, "target": "nearest"}
		],
		[
			{"id": "guard", "start": 0, "target": "self"},
			{"id": "bash", "start": 4, "target": "nearest"},
			{"id": "slam", "start": 8, "target": "nearest"}
		]
	]


func start(hero_lanes: Array, fixture: String = "duo", options: Dictionary = {}) -> void:
	tick = 0
	outcome = ""
	units.clear()
	trace.clear()
	visual_cues = []
	activations.clear()
	boss_events.clear()
	_activation = {}
	_events.clear()
	_lanes.clear()
	_compass_loop = -1
	_towline_loop = -1
	_towline_mark.clear()
	_metronome_loop = -1
	_barrage_hits.clear()
	_siege_loop = -1
	_spent_timeline_relics.clear()
	_overflow_healed = 0
	_twin_bell_hits.clear()
	_healed_tiles.clear()
	_last_party_heal_loop = -1
	_reinforcement_wave.clear()
	_critical_seed = int(options.get("seed", 0))
	_critical_streams.clear()
	_enemy_pursuit_sprints = not options.is_empty() and options.get("encounter") != "boss"
	if not options.is_empty():
		var reinforcements: Array = options.get("reinforcements", [])
		if not reinforcements.is_empty() and not options.get("formation", []).is_empty() and options.get("encounter") != "boss":
			var beat := clampi(int(options.get("reinforcement_beat", 7)), 1, BEATS)
			_reinforcement_wave = {"formation": reinforcements.duplicate(true), "tick": beat * TICKS_PER_BEAT, "beat": beat}
		_start_campaign(options)
	elif fixture == "solo":
		units.append(_unit("hero_1", "Warden", "hero", 0, Vector2(270, 270), 165, 23.0, 122.0, 92.0))
		units.append(_unit("clockwork", "Clockwork", "enemy", -1, Vector2(715, 254), 273, 32.0, 75.0, 112.0))
		units.back()["sprite"] = "clockwork"
	else:
		units.append(_unit("hero_1", "Hexwright", "hero", 0, Vector2(220, 228), 74, 20.0, 90.0, 225.0))
		units[0]["sprite"] = "hexwright"
		units.append(_unit("hero_2", "Warden", "hero", 1, Vector2(270, 302), 100, 23.0, 122.0, 96.0))
		units.append(_unit("clockwork", "Clockwork", "enemy", -1, Vector2(720, 251), 265, 32.0, 68.0, 108.0))
		units.back()["sprite"] = "clockwork"
		units.append(_unit("scout", "Clockwork Scout", "enemy", -1, Vector2(490, 154), 49, 17.0, 40.0, 155.0))
		units.back()["sprite"] = "scout"
	for unit in units:
		if unit.side != "hero":
			break
		var lane: int = unit.lane
		var tiles: Array = hero_lanes[lane] if lane < hero_lanes.size() else []
		_lanes.append(_valid_tiles(tiles, unit.get("mastery", {})))
		var ranged_damage := 0
		var ranged_reach := INF
		var has_precision: bool = unit.get("class") == "starshot"
		var has_close_attack := false
		for tile: Dictionary in _lanes[lane]:
			var spec: Dictionary = TILES[tile.id]
			var ranged := is_ranged_tile(tile.id)
			if ranged:
				ranged_damage += int(spec.damage)
				if spec.damage > 0:
					ranged_reach = minf(ranged_reach, tile.reach)
			has_precision = has_precision or spec.has("distance_bonus") or spec.has("ranged_followup_bonus") \
				or spec.has("long_critical_bonus")
			has_close_attack = has_close_attack or (spec.damage > 0
				and (not ranged or tile.reach < PRECISION_SPACING or spec.get("blink_strike", false)))
			if spec.has("lance_travel_bonus"):
				unit["lance_travel"] = 0.0
		unit["ranged_damage"] = ranged_damage
		if not has_close_attack and is_finite(ranged_reach):
			# Keep space without drifting beyond the shortest equipped shot.
			var spacing := PRECISION_SPACING if has_precision else minf(ranged_reach * 0.65, PRECISION_SPACING)
			unit.preferred_range = maxf(unit.preferred_range, minf(spacing, ranged_reach - 24.0))
			unit["ranged_standoff"] = true
			unit["ranged_reach"] = ranged_reach


func _start_campaign(options: Dictionary) -> void:
	var heroes: Array = options.get("heroes", [])
	if heroes.is_empty():
		heroes = [options]
	var relics: Array = options.get("relics", []).duplicate()
	var relic: String = options.get("relic", "")
	if not relic.is_empty() and relic not in relics:
		relics.append(relic)
	for lane in range(heroes.size()):
		var hero_options: Dictionary = heroes[lane]
		var hero_id: String = hero_options.get("hero", hero_options.get("id", "warden"))
		var hero: Dictionary = HERO_CLASSES.get(hero_id, HERO_CLASSES.warden)
		var max_hp := maxi(1, int(hero_options.get("max_hp", 100)))
		var y := 265.0 + (lane - (heroes.size() - 1) * 0.5) * 96.0
		var unit := _unit("hero_%d" % (lane + 1), hero.label, "hero", lane, Vector2(285, y), max_hp, 23.0, 153.0, 86.0)
		unit.hp = clampi(int(hero_options.get("hp", max_hp)), 0, max_hp)
		unit["class"] = hero_id
		var mastery := ClassMasteries.for_class(hero_id, hero_options.get("mastery", ""))
		if not mastery.is_empty():
			unit["mastery"] = mastery
		unit["relics"] = relics
		units.append(unit)

	var rng := RandomNumberGenerator.new()
	rng.seed = int(options.get("seed", 0))
	var y := rng.randf_range(217.0, 289.0)
	var encounter: String = options.get("encounter", "opening")
	var difficulty: String = options.get("difficulty", "easy")
	var segment := clampi(int(options.get("segment", 1)), 1, 3)
	var encounter_seed := int(options.get("seed", 0))
	var alternate := posmod(encounter_seed ^ (encounter_seed >> 8), 3) == 1
	var formation: Array = options.get("formation", [])
	if options.get("location", "brass") == "glass":
		_start_glass_encounter(encounter, rng, y, difficulty, segment, options.get("boss_id", ""), alternate, formation)
		return
	if options.get("location", "brass") == "crown":
		_start_crown_encounter(encounter, rng, y, difficulty, segment, options.get("boss_id", ""), alternate, formation)
		return
	if options.get("location", "brass") == "moonwreck":
		_start_moonwreck_encounter(encounter, rng, y, difficulty, segment, options.get("boss_id", ""), alternate, formation)
		return
	var health_scale: float = {"medium": [1.12, 2.15, 2.15], "hard": [1.21, 2.35, 3.0]}.get(difficulty, [1.0, 1.0, 1.0])[segment - 1]
	var damage_scale: float = {"medium": [1.07, 1.58, 1.58], "hard": [1.10, 1.64, 1.80]}.get(difficulty, [1.0, 1.0, 1.0])[segment - 1]
	var first_gate := encounter == "opening" and segment == 1 and difficulty != "hard"
	if first_gate:
		health_scale *= 0.8
	if not formation.is_empty() and encounter != "boss":
		_spawn_formation(formation, y, health_scale, damage_scale)
		return
	match encounter:
		"battle":
			if alternate:
				_add_campaign_enemy("brass_sapper", Vector2(610, y + 46.0), 0, health_scale, damage_scale)
				_add_campaign_enemy("recruit", Vector2(538, y - 38.0), 13, 1.35 * health_scale, damage_scale)
			elif rng.randi_range(0, 1) == 0:
				_add_campaign_enemy("bruiser", Vector2(615, y), 0, health_scale, damage_scale)
				if segment >= 2:
					_add_campaign_enemy("scout", Vector2(684, y + 95.0), 12, 1.0, damage_scale)
			else:
				_add_campaign_enemy("scout", Vector2(583, y - 58.0), 0, health_scale, damage_scale)
				_add_campaign_enemy("scout", Vector2(684, y + 72.0), 20, health_scale, damage_scale)
		"elite":
			_add_campaign_enemy("veteran", Vector2(636, y), 0, health_scale, damage_scale)
			_add_campaign_enemy("brass_sapper" if alternate else "scout", Vector2(673, y + 113.0), 0,
				health_scale * (0.86 if alternate else 1.0), damage_scale)
			if difficulty == "hard" and segment == 3:
				_add_campaign_enemy("scout", Vector2(673, y - 113.0), 40, 1.5, damage_scale)
		"boss":
			var fallback := "tollkeeper"
			if difficulty == "hard" and segment == 3:
				fallback = "iron_regent"
			elif difficulty in ["medium", "hard"] and segment >= 2:
				fallback = "gilded_marshal"
			var boss_id: String = options.get("boss_id", fallback)
			match boss_id:
				"brass_bellmaker":
					_add_campaign_enemy("brass_bellmaker", Vector2(647, y), 0, health_scale, damage_scale)
				"iron_regent":
					_add_campaign_enemy("regent", Vector2(647, y))
				"gilded_marshal":
					_add_campaign_enemy("marshal", Vector2(647, y), 0, 1.10 if difficulty == "hard" else 1.0, 1.06 if difficulty == "hard" else 1.0)
					if difficulty == "medium":
						var marshal: Dictionary = units.back()
						marshal["marshal_plate_max_integrity"] = MARSHAL_MEDIUM_PLATE
						marshal["marshal_plate_integrity"] = 0
						marshal.attack.damage = 32
						marshal.attack.cooldown = 126
				_:
					if boss_id == "tollkeeper" and difficulty == "easy" and segment == 1 and options.get("boss_variant") == "repair_drone":
						_add_campaign_enemy("boss", Vector2(647, y), 0, 0.84, 0.94)
						var tollkeeper_id: String = units.back().id
						_add_campaign_enemy("tollkeeper_drone", Vector2(676, y + 76.0))
						units.back()["repair_partner"] = tollkeeper_id
					else:
						_add_campaign_enemy("boss", Vector2(647, y), 0, health_scale, damage_scale)
		_:
			_add_campaign_enemy("recruit", Vector2(522, y), 0, 0.8 if first_gate else 1.0)


func _start_glass_encounter(encounter: String, rng: RandomNumberGenerator, y: float, difficulty: String, segment: int, boss_id: String, alternate: bool, formation: Array) -> void:
	var extra_leg := difficulty != "easy" and segment >= 2
	var third_leg := difficulty == "hard" and segment == 3
	var health_scale: float = {"medium": [1.14, 2.15, 2.15], "hard": [1.20, 2.27, 2.90]}.get(difficulty, [1.0, 1.0, 1.0])[segment - 1]
	var damage_scale: float = {"medium": [1.08, 1.51, 1.51], "hard": [1.12, 1.55, 1.70]}.get(difficulty, [1.0, 1.0, 1.0])[segment - 1]
	if not formation.is_empty() and encounter != "boss":
		_spawn_formation(formation, y, health_scale, damage_scale)
		return
	match encounter:
		"battle":
			if alternate:
				_add_campaign_enemy("glass_duelist", Vector2(589, y - 60.0), 0, health_scale, damage_scale)
				_add_campaign_enemy("glass_skirmisher", Vector2(656, y + 64.0), 25, health_scale, damage_scale)
			elif rng.randi_range(0, 1) == 0:
				_add_campaign_enemy("glass_hunter", Vector2(615, y), 0, health_scale, damage_scale)
				if extra_leg:
					_add_campaign_enemy("glass_skirmisher", Vector2(686, y + 90.0), 16, 1.15, damage_scale)
			else:
				_add_campaign_enemy("glass_skirmisher", Vector2(589, y - 63.0), 0, health_scale, damage_scale)
				var partner := "glass_hunter" if extra_leg else "glass_skirmisher"
				_add_campaign_enemy(partner, Vector2(668, y + 68.0), 25, health_scale, damage_scale)
		"elite":
			_add_campaign_enemy("glass_overseer", Vector2(644, y), 0, health_scale, damage_scale)
			_add_campaign_enemy("glass_duelist" if alternate else "glass_skirmisher", Vector2(676, y + 108.0),
				25, health_scale, damage_scale)
			if third_leg:
				_add_campaign_enemy("glass_hunter", Vector2(676, y - 108.0), 47, 1.25, damage_scale)
		"boss":
			if boss_id == GlassPilotEnemies.REFRACTION_ENGINE:
				_add_campaign_enemy(GlassPilotEnemies.REFRACTION_ENGINE, Vector2(642, y), 0, health_scale, damage_scale)
			elif boss_id == "tempered_colossus" or (boss_id.is_empty() and third_leg):
				_add_campaign_enemy("tempered_colossus", Vector2(635, y))
			elif boss_id == "prism_warden" or (boss_id.is_empty() and extra_leg):
				_add_campaign_enemy("prism_warden", Vector2(647, y), 0, 1.06 if difficulty == "hard" else 1.0, 1.02 if difficulty == "hard" else 1.0)
			else:
				_add_campaign_enemy("glass_twin", Vector2(615, y - 70.0), 0, health_scale, damage_scale)
				_add_campaign_enemy("ember_twin", Vector2(661, y + 62.0), 0, health_scale, damage_scale)
		_:
			_add_campaign_enemy("glass_recruit", Vector2(522, y), 0, health_scale, damage_scale)


func pending_reinforcement() -> Dictionary:
	return _reinforcement_wave.get("warning", {}) if outcome.is_empty() else {}


func _spawn_formation(formation: Array, y: float, health_scale: float, damage_scale: float, arrival := false) -> void:
	for spawn: Dictionary in formation:
		_add_campaign_enemy(spawn.id, Vector2(spawn.x, y + float(spawn.dy)), int(spawn.delay),
			health_scale * float(spawn.health_scale), damage_scale * float(spawn.damage_scale))
		if arrival:
			var enemy: Dictionary = units.back()
			enemy.next_attack = tick + maxi(1, int(enemy.next_attack))
			enemy.pos = _reinforcement_spawn_position(enemy)
			enemy.prev_pos = enemy.pos
			_emit("reinforcement", "%s has arrived." % enemy.name, enemy, enemy)
	if not arrival and not _reinforcement_wave.is_empty():
		var positions := PackedVector2Array()
		for spawn: Dictionary in _reinforcement_wave.formation:
			positions.append(Vector2(spawn.x, y + float(spawn.dy)))
		_reinforcement_wave.y = y
		_reinforcement_wave.health_scale = health_scale
		_reinforcement_wave.damage_scale = damage_scale
		_reinforcement_wave.warning = {"beat": _reinforcement_wave.beat, "tick": _reinforcement_wave.tick, "positions": positions}
		_reinforcement_wave.warning.make_read_only()


func _arrive_reinforcements() -> void:
	if tick != int(_reinforcement_wave.get("tick", -1)):
		return
	_spawn_formation(_reinforcement_wave.formation, _reinforcement_wave.y,
		_reinforcement_wave.health_scale, _reinforcement_wave.damage_scale, true)
	_reinforcement_wave.clear()


func _reinforcement_spawn_position(enemy: Dictionary) -> Vector2:
	var preferred := _bounded(enemy.pos, enemy.radius)
	if _free_position(preferred, enemy):
		return preferred
	for distance: float in [48.0, 96.0, 144.0]:
		for direction in range(8):
			var candidate := _bounded(preferred + Vector2.DOWN.rotated(direction * TAU / 8.0) * distance, enemy.radius)
			if _free_position(candidate, enemy):
				return candidate
	return preferred


func _add_campaign_enemy(kind: String, position: Vector2, delay := 0, health_scale := 1.0, damage_scale := 1.0) -> void:
	var source: Dictionary = CAMPAIGN_ENEMIES.get(kind, {})
	var pilot: String = CORE_ENEMY_REGIONS.get(kind, "")
	if source.is_empty():
		for region: String in PILOT_ENEMY_SCRIPTS:
			source = PILOT_ENEMY_SCRIPTS[region].ENEMIES.get(kind, {})
			if not source.is_empty():
				pilot = region
				break
	var spec := source.duplicate()
	if CORE_ENEMY_REGIONS.has(kind):
		spec["special"] = kind
	spec.damage = roundi(spec.damage * damage_scale)
	var enemy := _unit("%s_%d" % [kind, units.size()], spec.name, "enemy", -1, position,
		roundi(spec.hp * health_scale), spec.radius, spec.speed, spec.spacing)
	enemy["attack"] = spec
	enemy["attack_id"] = kind
	enemy["sprite"] = spec.art
	if not pilot.is_empty():
		enemy["pilot_region"] = pilot
	enemy.next_attack = int(spec.first) + delay
	if kind == "marshal":
		enemy["marshal_plated"] = false
		enemy["marshal_exposed_until"] = 0
	elif kind == "prism_warden":
		enemy["prism_warded"] = false
		enemy["prism_window_until"] = 0
	elif kind == "tempered_colossus":
		enemy["colossus_stage"] = 0
		enemy["colossus_window_until"] = 0
		enemy["colossus_sweep_radius"] = spec.reach + COLOSSUS_EXTRA_REACH
		enemy["colossus_first"] = ""
		enemy["colossus_second"] = ""
		enemy["colossus_shattered"] = false
	elif kind == "relay_guard":
		enemy["relay_link_target"] = ""
	elif kind == "relay_captain":
		enemy["relay_charge_active"] = false
	elif kind == "relay_marshal":
		enemy["relay_charge_active"] = false
		enemy["relay_combo_stage"] = 0
		enemy["relay_breaker"] = ""
	elif kind == "crown_regent":
		enemy["relay_charge_active"] = false
		enemy["relay_shield_sources"] = []
		enemy["crown_breakers"] = {}
		enemy["crown_guard_ids"] = []
		enemy["crown_charge_interrupted"] = false
	elif kind == "dock_winch":
		enemy["dock_winch_ally"] = ""
	elif kind == "wreckmaster":
		enemy["wreckmaster_phase"] = 0
		enemy["wreckmaster_slam_radius"] = WRECKMASTER_SLAM_RADIUS
	elif kind == "tidekeeper":
		enemy["tidekeeper_phase"] = 0
		enemy["tidekeeper_slam_radius"] = TIDEKEEPER_SLAM_RADIUS
		enemy["tidekeeper_targets"] = []
		enemy["tidekeeper_breaker"] = ""
	elif kind == "drowned_admiral":
		enemy["admiral_phase"] = 0
		enemy["admiral_sweep_radius"] = ADMIRAL_SWEEP_RADIUS
		enemy["admiral_targets"] = []
		enemy["admiral_breaker"] = ""
		enemy["admiral_reverser"] = ""
	if kind == "regent":
		enemy["regent_sealed"] = false
		enemy["regent_seals_left"] = 0
		enemy["regent_window_until"] = 0
	units.append(enemy)


func _start_crown_encounter(encounter: String, rng: RandomNumberGenerator, y: float, difficulty: String, segment: int, boss_id: String, alternate: bool, formation: Array) -> void:
	var medium := difficulty == "medium"
	var hard := difficulty == "hard"
	var extra_leg := (medium or hard) and segment >= 2
	var third_leg := hard and segment == 3
	var health_scale: float = {"medium": [1.10, 2.05, 2.05], "hard": [1.14, 2.15, 2.82]}.get(difficulty, [1.0, 1.0, 1.0])[segment - 1]
	var damage_scale: float = {"medium": [1.07, 1.55, 1.55], "hard": [1.08, 1.59, 1.72]}.get(difficulty, [1.0, 1.0, 1.0])[segment - 1]
	if not formation.is_empty() and encounter != "boss":
		_spawn_formation(formation, y, health_scale, damage_scale)
		_refresh_relay_links(false)
		return
	match encounter:
		"battle":
			var partner := "relay_runner" if rng.randi_range(0, 1) == 0 else "relay_lancer"
			var lancer := partner == "relay_lancer"
			_add_campaign_enemy(partner, Vector2(603, y - 15.0), 0, (0.54 if lancer else 1.0) * health_scale, (0.81 if lancer else 1.0) * damage_scale)
			_add_campaign_enemy("crown_mender" if alternate else "relay_guard", Vector2(668, y + 46.0),
				22, health_scale, damage_scale)
		"elite":
			_add_campaign_enemy("relay_lancer", Vector2(623, y - 12.0), 0, health_scale, damage_scale)
			_add_campaign_enemy("crown_mender" if alternate else "relay_guard", Vector2(692, y + 44.0),
				15, 1.25 * health_scale, damage_scale)
			if third_leg:
				_add_campaign_enemy("relay_runner", Vector2(669, y - 114.0), 40, 1.55, damage_scale)
		"boss":
			if boss_id == "crown_regent" or (boss_id.is_empty() and third_leg):
				_start_crown_regent(y)
			elif boss_id == "relay_marshal" or (boss_id.is_empty() and extra_leg):
				_add_campaign_enemy("relay_marshal", Vector2(610, y - 18.0), 0, 1.05 if hard else 1.0, 1.04 if hard else 1.0)
				_add_campaign_enemy("relay_guard", Vector2(704, y + 21.0), 12, 2.65 if hard else 2.55, 1.50 if hard else 1.45)
			else:
				_add_campaign_enemy("relay_captain", Vector2(622, y), 0, health_scale, damage_scale)
		_:
			_add_campaign_enemy("relay_recruit", Vector2(522, y))
	_refresh_relay_links(false)


func _start_crown_regent(y: float) -> void:
	_add_campaign_enemy("crown_regent", Vector2(580, y))
	var regent: Dictionary = units.back()
	for side in [-1, 1]:
		_add_campaign_enemy("relay_guard", Vector2(530, y + side * 68.0), 14 if side < 0 else 38, 2.35, 1.55)
		var guard: Dictionary = units.back()
		guard.name = "Left Relay Guard" if side < 0 else "Right Relay Guard"
		guard["crown_role"] = "relay_left" if side < 0 else "relay_right"
		guard["crown_regent_id"] = regent.id
		regent.crown_guard_ids.append(guard.id)
	regent["crown_role"] = "relay_regent"


func _start_moonwreck_encounter(encounter: String, rng: RandomNumberGenerator, y: float, difficulty: String, segment: int, boss_id: String, alternate: bool, formation: Array) -> void:
	var hard := difficulty == "hard"
	var second_leg := (difficulty == "medium" or hard) and segment >= 2
	var third_leg := hard and segment == 3
	var health_scale: float = {"medium": [1.0, 2.22, 2.22], "hard": [1.0, 2.34, 2.95]}.get(difficulty, [1.0, 1.0, 1.0])[segment - 1]
	var damage_scale: float = {"medium": [1.0, 1.60, 1.60], "hard": [1.0, 1.64, 1.80]}.get(difficulty, [1.0, 1.0, 1.0])[segment - 1]
	if not formation.is_empty() and encounter != "boss":
		_spawn_formation(formation, y, health_scale, damage_scale)
		return
	match encounter:
		"battle":
			var flank := -1.0 if rng.randi_range(0, 1) == 0 else 1.0
			if alternate:
				_add_campaign_enemy("dock_corsair", Vector2(573, y + flank * 38.0), 0, health_scale, damage_scale)
				_add_campaign_enemy("dock_recruit", Vector2(638, y - flank * 54.0), 15, 1.30 * health_scale, damage_scale)
			else:
				_add_campaign_enemy("dock_bruiser", Vector2(633, y + flank * 42.0), 0, 0.65 * health_scale, damage_scale)
				_add_campaign_enemy("dock_winch", Vector2(563, y - flank * 28.0), 0, 0.86 * health_scale, damage_scale)
		"elite":
			_add_campaign_enemy("dock_bruiser", Vector2(655, y + 42.0), 0, 1.18 * health_scale, 1.15 * damage_scale)
			_add_campaign_enemy("dock_corsair" if alternate else "dock_winch", Vector2(571, y - 31.0), 0,
				health_scale * (0.90 if alternate else 1.12), damage_scale)
			if third_leg:
				_add_campaign_enemy("dock_recruit", Vector2(650, y - 113.0), 46, 3.1, damage_scale)
		"boss":
			if boss_id == "drowned_admiral" or (boss_id.is_empty() and third_leg):
				_add_campaign_enemy("drowned_admiral", Vector2(595, 265.0))
			elif boss_id == "tidekeeper" or (boss_id.is_empty() and second_leg):
				_add_campaign_enemy("tidekeeper", Vector2(595, 265.0), 0, 1.04 if hard else 1.0)
			else:
				_add_campaign_enemy("wreckmaster", Vector2(595, 265.0))
		_:
			_add_campaign_enemy("dock_recruit", Vector2(521, y))


func step() -> Array[Dictionary]:
	_events = []
	visual_cues = []
	if outcome != "" or units.is_empty():
		return _events
	tick += 1
	for unit in units:
		var exposure: int = unit.get("marshal_exposed_until", 0)
		if exposure > 0 and tick > exposure:
			unit.marshal_exposed_until = 0
			if unit.hp > 0:
				var message := "The Marshal's plating closed before another hero landed a hit. Move that hero's strike within three beats of the push or pull."
				if unit.has("marshal_plate_integrity"):
					message = "The team interrupt window closed. Earlier plate wear still counts."
				_review_boss_event("miss", "marshal_window_missed", message, unit)
		var prism_window: int = unit.get("prism_window_until", 0)
		if prism_window > 0 and tick > prism_window:
			unit.prism_window_until = 0
			if unit.hp > 0:
				_review_boss_event("miss", "prism_window_missed", "The Prism Warden's ward closed before the other hero landed a hit. Bring that hero's strike closer to the push or pull.", unit)
		var seal_window: int = unit.get("regent_window_until", 0)
		if seal_window > 0 and tick > seal_window:
			if unit.hp > 0:
				var contributors: Array = unit.regent_contributors
				var missing := PackedStringArray()
				for hero in units:
					if hero.side == "hero" and hero.id not in contributors:
						missing.append(hero.name if hero.hp > 0 else "%s (fallen)" % hero.name)
				var message := "The Regent's seals reset. %d of 3 heroes landed a hit in the four-beat window." % contributors.size()
				if not missing.is_empty():
					message += " Still needed a hit from %s." % ", ".join(missing)
				_review_boss_event("miss", "regent_window_missed", message, unit)
			unit.regent_window_until = 0
			unit.regent_seals_left = 3
			unit.regent_contributors.clear()
	if (tick - 1) % LOOP_TICKS == 0:
		_spent_timeline_relics.clear()
		_overflow_healed = 0
		for unit in units:
			if unit.hp > 0 and _has_relic(unit, "pocket_bell"):
				_guard(unit, 5, "pocket_bell")
	_move_units()
	_arrive_reinforcements()
	_refresh_relay_links()
	if tick % TICKS_PER_BEAT == 0:
		_activate_lanes()
	_run_enemies()
	_run_burns()
	if tick >= 3600 and tick % 30 == 0:
		_end_stalemate()
	_check_outcome()
	if tick % LOOP_TICKS == 0 and outcome == "":
		_emit("loop", "%d loops complete." % floori(float(tick) / LOOP_TICKS))
	return _events


func target_for(lane: int, tile_id: String, rule: String, enchantment := "") -> Dictionary:
	if not TILES.has(tile_id) or lane < 0 or lane >= _lanes.size():
		return {}
	var actor: Dictionary = units[lane]
	if actor.hp <= 0:
		return {}
	var tile: Dictionary = TILES[tile_id]
	if tile.targets == ["self"]:
		if _arsenal_tiles.has(tile_id):
			return _arsenal_support_target(actor, tile)
		return _guard_recipient(actor, tile)
	var eligible := TileEnchantments.is_eligible(enchantment, tile, tile_id)
	var target := _select(actor, rule, _tile_reach(tile_id, enchantment if eligible else "", actor.get("mastery", {})))
	return actor if target.is_empty() and tile.get("family") == "guard" else target


func target_rules(tile_id: String) -> Array:
	if not TILES.has(tile_id):
		return []
	var base: Array = TILES[tile_id].targets
	if "self" not in base and units.any(func(unit: Dictionary) -> bool: return unit.get("crown_role") == "relay_regent"):
		return base + CROWN_TARGET_RULES
	return base


func _unit(id: String, unit_name: String, side: String, lane: int, position: Vector2, health: int, radius: float, speed: float, preferred_range: float) -> Dictionary:
	return {
		"id": id, "name": unit_name, "side": side, "lane": lane, "pos": position, "prev_pos": position,
		"hp": health, "max_hp": health, "guard": 0, "radius": radius, "velocity": Vector2.ZERO,
		"impulse": Vector2.ZERO, "speed": speed, "preferred_range": preferred_range, "last_bash_loop": -1,
		"facing": 1.0 if side == "hero" else -1.0,
		"intent": "", "intent_tick": 0, "next_attack": 112 if id == "scout" else 146
	}


func _valid_tiles(tiles: Array, mastery: Dictionary) -> Array:
	var validated: Array = []
	var occupied := PackedByteArray()
	occupied.resize(BEATS)
	for tile in tiles:
		if not tile is Dictionary:
			continue
		var id: String = tile.get("id", "")
		if not TILES.has(id):
			continue
		var spec: Dictionary = TILES[id]
		var start_beat: int = tile.get("start", -1)
		var end_beat: int = start_beat + spec.width
		if start_beat < 0 or end_beat > BEATS:
			continue
		if occupied.slice(start_beat, end_beat).has(1):
			continue
		for beat in range(start_beat, end_beat):
			occupied[beat] = 1
		var rule: String = tile.get("target", "nearest")
		if rule not in target_rules(id):
			rule = spec.targets[0]
		var enchantment: String = tile.get("enchantment", "")
		if not TileEnchantments.is_eligible(enchantment, spec, id):
			enchantment = ""
		validated.append({"id": id, "start": start_beat, "end": end_beat, "target": rule,
			"enchantment": enchantment, "reach": _tile_reach(id, enchantment, mastery)})
	return validated


func _tile_reach(tile_id: String, enchantment: String, mastery: Dictionary) -> float:
	var reach: float = TILES[tile_id].range
	if enchantment == "longshot":
		reach += TileEnchantments.RANGE_BONUS
	if mastery.get("effect") == "reach" and TILES[tile_id].damage > 0 and is_ranged_tile(tile_id):
		reach += float(mastery.amount)
	return reach


func _move_units() -> void:
	const DELTA := 1.0 / TICKS_PER_SECOND
	var next_positions: Array[Vector2] = []
	var travel_steps := {}
	for unit in units:
		var position: Vector2 = unit.pos
		unit.prev_pos = position
		if unit.hp <= 0:
			unit["drive_velocity"] = Vector2.ZERO
			next_positions.append(position)
			continue
		var focus := _select(unit, _movement_target_rule(unit))
		var attack_target := _find_unit(unit.intent) if unit.intent != "" else {}
		var facing_target: Dictionary = attack_target if attack_target.get("side") != unit.side \
			and attack_target.get("hp", 0) > 0 else focus
		if not facing_target.is_empty():
			var facing_offset: float = facing_target.pos.x - position.x
			if absf(facing_offset) > 8.0:
				unit.facing = signf(facing_offset)
		var drive := Vector2.ZERO
		var repair_partner := _find_unit(unit.repair_partner) if unit.has("repair_partner") else {}
		if unit.intent == "" and repair_partner.get("hp", 0) > 0:
			var offset: Vector2 = repair_partner.pos - position
			drive = offset.normalized() * clampf((offset.length() - unit.preferred_range) * 4.0, 0.0, unit.speed)
		elif unit.intent == "" and unit.get("attack", {}).get("support", false):
			drive = _relay_support_drive(unit, focus)
		elif not focus.is_empty() and unit.intent == "":
			drive = _pursuit_drive(unit, focus)
		var impulse: Vector2 = unit.impulse
		unit["drive_velocity"] = drive
		unit.velocity = drive + impulse
		unit.impulse = impulse.move_toward(Vector2.ZERO, IMPULSE_DECAY * DELTA)
		var candidate: Vector2 = position + unit.velocity * DELTA
		var next := _bounded(candidate, unit.radius)
		if unit.has("dock_wall_source"):
			MoonPilotEnemies.resolve_wall_slam(self, unit, impulse, candidate, next)
		if impulse.is_zero_approx() and not next.is_equal_approx(position) \
				and (unit.get("class") == "lancer" or unit.has("lance_travel")):
			travel_steps[next_positions.size()] = next - position
		next_positions.append(next)
	for i in range(units.size()):
		if units[i].hp <= 0:
			continue
		for j in range(i + 1, units.size()):
			if units[j].hp <= 0:
				continue
			var offset := next_positions[j] - next_positions[i]
			var distance := offset.length()
			var minimum: float = units[i].radius + units[j].radius + 3.0
			if distance >= minimum:
				continue
			_breaker_collision(units[i], units[j])
			_breaker_collision(units[j], units[i])
			var direction := offset / distance if distance > 0.001 else Vector2.RIGHT
			var separation := direction * minf((minimum - distance) * 0.32, 10.0)
			next_positions[i] = _bounded(next_positions[i] - separation, units[i].radius)
			next_positions[j] = _bounded(next_positions[j] + separation, units[j].radius)
	for i in range(units.size()):
		var unit: Dictionary = units[i]
		if travel_steps.has(i):
			var step: Vector2 = travel_steps[i]
			var actual: Vector2 = next_positions[i] - unit.pos
			var walked := clampf(actual.dot(step.normalized()), 0.0, step.length())
			if unit.has("lance_travel"):
				unit.lance_travel = minf(LANCE_TRAVEL_CAP, unit.lance_travel + walked)
			if unit.get("class") == "lancer":
				unit["travel"] = minf(LANCE_TRAVEL_CAP, unit.get("travel", 0.0) + walked)
		unit.pos = next_positions[i]


func _pursuit_drive(unit: Dictionary, focus: Dictionary) -> Vector2:
	var offset: Vector2 = focus.pos - unit.pos
	var margin: float = offset.length() - unit.preferred_range
	var speed: float = unit.speed
	if tick < unit.get("haste_until", 0):
		speed *= 1.42
	if tick < unit.get("tar_slow_until", 0):
		speed *= 0.65
	var direction := offset.normalized()
	if margin >= 0.0:
		if unit.has("class") or (_enemy_pursuit_sprints and unit.side == "enemy"):
			speed *= 1.0 + PURSUIT_SPRINT_BONUS * smoothstep(PURSUIT_SPRINT_START, PURSUIT_SPRINT_FULL, margin)
		return direction * minf(margin * 4.0, speed)
	if not unit.get("ranged_standoff", false):
		return Vector2.ZERO
	var retreat_speed := minf(-margin * 5.0, speed * 0.72)
	return _retreat_direction(unit, focus.pos, -direction) * retreat_speed


func _retreat_direction(unit: Dictionary, threat: Vector2, away: Vector2) -> Vector2:
	var position: Vector2 = unit.pos
	var lookahead := position + away * RETREAT_LOOKAHEAD
	var bounded := _bounded(lookahead, unit.radius)
	var available := bounded - position
	if available.dot(away) >= RETREAT_LOOKAHEAD * 0.88:
		return away
	var directions: Array[Vector2] = []
	if not is_equal_approx(lookahead.x, bounded.x):
		directions.append_array([Vector2.DOWN, Vector2.UP])
	if not is_equal_approx(lookahead.y, bounded.y):
		directions.append_array([Vector2.RIGHT, Vector2.LEFT])
	var best_direction := available.normalized()
	var best_clearance := -INF
	for direction: Vector2 in directions:
		var endpoint := _bounded(position + direction * RETREAT_LOOKAHEAD, unit.radius)
		if position.distance_squared_to(endpoint) < RETREAT_LOOKAHEAD * RETREAT_LOOKAHEAD * 0.25:
			continue
		var clearance := endpoint.distance_squared_to(threat)
		if clearance > best_clearance:
			best_direction = direction
			best_clearance = clearance
	return best_direction


func _bounded(position: Vector2, radius: float) -> Vector2:
	var margin := WALL_MARGIN + radius
	return Vector2(clampf(position.x, margin, ARENA_SIZE.x - margin), clampf(position.y, margin, ARENA_SIZE.y - margin))


func _select(actor: Dictionary, rule: String, reach: float = INF, origin: Vector2 = Vector2.INF) -> Dictionary:
	var best := {}
	var best_score := INF
	var crown_target: bool = rule in CROWN_TARGET_RULES
	var position: Vector2 = actor.pos if origin == Vector2.INF else origin
	for candidate in units:
		if candidate.side == actor.side or candidate.hp <= 0:
			continue
		if crown_target and candidate.get("crown_role", "") != rule:
			continue
		var distance := position.distance_squared_to(candidate.pos)
		if distance > reach * reach:
			continue
		var score := distance
		match rule:
			"farthest":
				score = -distance
			"lowest_hp":
				score = candidate.hp
			"highest_hp":
				score = -candidate.hp
			"ranged_damage":
				score = -candidate.get("ranged_damage", 0)
		if score < best_score:
			best = candidate
			best_score = score
	# A defeated named guard should not leave that tile inert for the rest of the fight.
	if best.is_empty() and crown_target and not units.any(func(unit: Dictionary) -> bool:
		return unit.hp > 0 and unit.get("crown_role", "") == rule):
		return _select(actor, "nearest", reach, origin)
	return best


func _attack_target_rule(unit: Dictionary) -> String:
	return unit.get("attack", {}).get("target", "nearest")


func _movement_target_rule(unit: Dictionary) -> String:
	if unit.side == "hero":
		var lane: int = unit.lane
		for tile: Dictionary in _lanes[lane]:
			if tile.target == "relay_regent" and TILES[tile.id].range < 200.0:
				return "relay_regent"
	return _attack_target_rule(unit)


func _refresh_relay_links(emit_events := true) -> void:
	for guard in units:
		if not guard.has("relay_link_target"):
			continue
		var current := _find_unit(guard.relay_link_target)
		if not current.is_empty():
			var origin: Vector2 = guard.pos
			if guard.hp > 0 and current.hp > 0 and origin.distance_squared_to(current.pos) <= RELAY_BREAK_REACH * RELAY_BREAK_REACH:
				continue
			_break_relay_link(guard)
		if guard.hp <= 0 or tick < guard.get("relay_relink_tick", 0):
			continue
		var ally := _relay_ally(guard, RELAY_LINK_REACH)
		if ally.is_empty():
			continue
		guard.relay_link_target = ally.id
		if ally.has("relay_shield_sources"):
			ally.relay_shield_sources.append(guard.id)
			ally.crown_breakers.erase(guard.id)
		else:
			ally["relay_shield_source"] = guard.id
		if ally.get("relay_charge_active", false) and ally.get("sprite") == "relay_marshal":
			ally.relay_combo_stage = 1
			ally.relay_breaker = ""
		if emit_events:
			_emit("guard", "%s links a shield to %s." % [guard.name, ally.name], guard, ally, "relay_link")


func _relay_ally(guard: Dictionary, reach: float = INF) -> Dictionary:
	var best := {}
	var best_distance := reach * reach
	var origin: Vector2 = guard.pos
	if guard.has("crown_regent_id"):
		var regent := _find_unit(guard.crown_regent_id)
		if not regent.is_empty() and regent.hp > 0 and origin.distance_squared_to(regent.pos) <= best_distance:
			return regent
		return {}
	for ally in units:
		if ally.side != guard.side or ally.hp <= 0 or ally.has("relay_link_target"):
			continue
		var source: String = ally.get("relay_shield_source", "")
		if source != "" and source != guard.id:
			continue
		var distance := origin.distance_squared_to(ally.pos)
		if distance <= best_distance and (best.is_empty() or distance < best_distance):
			best = ally
			best_distance = distance
	return best


func _break_relay_link(guard: Dictionary, breaker: Dictionary = {}) -> void:
	var ally := _find_unit(guard.relay_link_target)
	guard.relay_link_target = ""
	var crown_guard := guard.has("crown_regent_id")
	guard["relay_relink_tick"] = tick + TICKS_PER_BEAT * (CROWN_LINK_RECONNECT_BEATS if crown_guard else 2)
	if crown_guard:
		if not ally.is_empty():
			ally.relay_shield_sources.erase(guard.id)
			if ally.relay_charge_active and guard.hp > 0 and not breaker.is_empty():
				ally.crown_breakers[guard.id] = breaker.id
				_emit("interrupt", "%s breaks the %s link." % [breaker.name, guard.name], breaker, guard, "crown_link_separated")
			else:
				ally.crown_breakers.erase(guard.id)
			_emit("interrupt", "The Regent loses the %s shield." % guard.name, guard, ally, "relay_link_broken")
		return
	if not ally.is_empty() and ally.get("relay_shield_source", "") == guard.id:
		ally.relay_shield_source = ""
		_emit("interrupt", "%s loses its relay shield." % ally.name, guard, ally, "relay_link_broken")
		if ally.get("relay_charge_active", false) and ally.get("sprite") == "relay_marshal":
			ally.relay_breaker = breaker.get("id", "")
			ally.relay_combo_stage = 3 if ally.relay_breaker.is_empty() else 2
			if ally.relay_combo_stage == 2:
				_emit("interrupt", "%s separates the shield. Use a different hero's Bash before the link reforms." % breaker.name,
					breaker, ally, "relay_marshal_separated")


func _relay_support_drive(guard: Dictionary, focus: Dictionary) -> Vector2:
	var ally := _relay_ally(guard)
	var origin: Vector2 = guard.pos
	if not ally.is_empty():
		var offset: Vector2 = ally.pos - origin
		if offset.length() > 77.0:
			return offset.normalized() * clampf((offset.length() - 77.0) * 4.0, 0.0, guard.speed)
	if focus.is_empty():
		return Vector2.ZERO
	var toward_hero: Vector2 = focus.pos - origin
	return toward_hero.normalized() * clampf((toward_hero.length() - guard.preferred_range) * 4.0, 0.0, guard.speed)


func _activate_lanes() -> void:
	var current_beat := _beat()
	_twin_bell_hits.clear()
	for lane in range(_lanes.size()):
		var actor: Dictionary = units[lane]
		for tile in _lanes[lane]:
			if tile.end != current_beat:
				continue
			_activation = {
				"order": activations.size() + boss_events.size(), "tick": tick, "beat": current_beat, "loop": _loop_index() + 1,
				"lane": lane, "tile": tile.id, "start": tile.start, "actor": actor.id, "hero": actor.name, "rule": tile.target,
				"status": "landed", "reason": "", "target": "", "target_name": "", "damage": 0, "guard": 0,
			}
			if not tile.enchantment.is_empty():
				_activation["enchantment"] = tile.enchantment
			activations.append(_activation)
			if actor.hp <= 0:
				_activation.status = "unavailable"
				_activation.reason = "%s had already fallen." % actor.name
			else:
				var origin: Vector2 = actor.pos
				var first_event := _events.size()
				_cast(actor, tile.id, tile.target, tile.reach)
				_apply_enchantment(actor, tile)
				if actor.has("mastery"):
					_apply_mastery(actor, tile.id)
				_apply_bastion_medal(actor, tile.id)
				_apply_bellmaker_finishes(actor, tile.id)
				_apply_starshot_critical_step(actor, tile.id)
				_add_tile_visual_cue(actor, tile.id, origin, first_event)
				if actor.get("class") == "rune_smith" and TILES[tile.id].width >= 3:
					actor["rune_charged"] = true
				if _activation.status == "landed":
					_prime_rune_charge(actor, tile.id)
					_activation.reason = (_activation_result(_activation) + " " + str(_activation.reason)).strip_edges()
				elif _activation.has("effect_details"):
					var notes: Array = _activation.get("effect_details", [])
					_activation.reason = (str(_activation.reason) + " " + " ".join(notes)).strip_edges()
			_activation = {}


func _apply_enchantment(actor: Dictionary, tile: Dictionary) -> void:
	match tile.enchantment:
		"guarded":
			if actor.hp <= 0:
				return
			var amount := int(TileEnchantments.GUARD_AMOUNT)
			var gain := mini(amount, MAX_GUARD - int(actor.guard))
			_guard_from_tile(actor, actor, amount, tile.id)
			var effect := "Guarded granted %d Guard." % gain if gain > 0 else "Guarded fired at full Guard."
			_activation.get_or_add("effect_details", []).append(effect)
		"longshot":
			_activation.get_or_add("effect_details", []).append("Longshot extended reach to %d." % roundi(tile.reach))
		"splash":
			if not _activation.get("primary_hit", false):
				return
			var target := _find_unit(_activation.target)
			if target.is_empty():
				return
			var neighbors := _splash_neighbors(actor, target, TileEnchantments.SPLASH_RADIUS)
			if neighbors.is_empty():
				return
			_sort_by_distance(neighbors, target.pos)
			var enemy: Dictionary = neighbors[0]
			var previous_hp: int = enemy.hp
			var damage := maxi(1, roundi(TILES[tile.id].damage * TileEnchantments.SPLASH_RATIO))
			_damage(actor, enemy, damage, tile.id, "Splash")
			var dealt: int = previous_hp - enemy.hp
			var effect := "Splash dealt %d damage to %s." % [dealt, enemy.name] if dealt > 0 else "%s blocked Splash." % enemy.name
			_activation.get_or_add("effect_details", []).append(effect)


func _mastery_hit(actor: Dictionary, target: Dictionary, tile_id: String) -> int:
	if not actor.has("mastery") or target.side != "enemy" or _activation.get("actor") != actor.id or _activation.get("tile") != tile_id:
		return 0
	if actor.get("mastery_loop", -1) == _loop_index():
		return 0
	var mastery: Dictionary = actor.mastery
	if not _matches_mastery_hit(mastery.trigger, actor, target, TILES[tile_id].width):
		return 0
	if mastery.effect == "damage":
		actor["mastery_loop"] = _loop_index()
		_record_mastery("%s adds %d damage." % [mastery.label, mastery.amount])
		return mastery.amount
	_activation.get_or_add("mastery_target", target.id)
	return 0


func _matches_mastery_hit(trigger: String, actor: Dictionary, target: Dictionary, width: int) -> bool:
	match trigger:
		"hit": return true
		"guarded_hit": return actor.guard > 0
		"close_hit": return _attack_origin(actor).distance_to(target.pos) <= ClassMasteries.CLOSE_REACH
		"distant_hit": return _attack_origin(actor).distance_to(target.pos) > ClassMasteries.LONG_REACH
		"displaced_hit": return tick <= int(target.get("displaced_until", -1))
		"teleport_hit": return _activation.get("teleported", false)
		"momentum_hit": return float(actor.get("travel", 0.0)) >= LANCE_TRAVEL_CAP
		"quick_rune_hit": return width <= 2 and actor.get("rune_charged", false)
		"wide_hit": return width >= 3
		"new_target_hit": return actor.get("focus_target", "") != target.id
		"low_hp_hit": return 2 * int(target.hp) <= int(target.max_hp)
		"marked_hit":
			for key: String in ["arsenal_mark", "ally_mark", "cantor_mark", "chorus_echo"]:
				if int(target.get(key, {}).get("expires", -1)) >= tick:
					return true
	return false


func _apply_mastery(actor: Dictionary, tile_id: String) -> void:
	var target_id: String = _activation.get("mastery_target", "")
	_activation.erase("mastery_target")
	if actor.hp <= 0 or actor.get("mastery_loop", -1) == _loop_index():
		return
	var mastery: Dictionary = actor.mastery
	var ready := not target_id.is_empty()
	match mastery.trigger:
		"wide_tile": ready = TILES[tile_id].width >= 3
		"guard_tile": ready = _activation.guard > 0
		"teleport": ready = _activation.get("teleported", false)
		"ranged_reach":
			if TILES[tile_id].damage > 0 and is_ranged_tile(tile_id):
				_record_mastery("%s adds %d reach." % [mastery.label, mastery.amount])
			return
	if not ready:
		return
	actor["mastery_loop"] = _loop_index()
	var amount: int = mastery.amount
	match mastery.effect:
		"guard":
			_grant_mastery_guard(actor, actor, tile_id, amount, mastery.label)
		"ally_guard":
			_grant_mastery_guard(actor, _weakest_other_ally(actor), tile_id, amount, mastery.label)
		"party_guard":
			for ally: Dictionary in units:
				if ally.side == actor.side and ally.hp > 0:
					_grant_mastery_guard(actor, ally, tile_id, amount, mastery.label)
		"heal":
			var healed := _restore_mastery_health(actor, actor, tile_id, amount, mastery.label)
			if healed < amount:
				_grant_mastery_guard(actor, actor, tile_id, amount - healed, mastery.label)
		"ally_heal":
			var recipient := actor
			for ally: Dictionary in units:
				if ally.side == actor.side and ally.hp > 0 and ally.max_hp - ally.hp > recipient.max_hp - recipient.hp:
					recipient = ally
			_restore_mastery_health(actor, recipient, tile_id, amount, mastery.label)
		"splash":
			var target := _find_unit(target_id)
			var neighbors := _splash_neighbors(actor, target, ClassMasteries.SPLASH_REACH)
			if not neighbors.is_empty():
				_sort_by_distance(neighbors, target.pos)
				var enemy: Dictionary = neighbors[0]
				var previous_hp: int = enemy.hp
				_damage(actor, enemy, amount, tile_id, mastery.label)
				_record_mastery("%s deals %d damage to %s." % [mastery.label, previous_hp - enemy.hp, enemy.name])


func _grant_mastery_guard(actor: Dictionary, recipient: Dictionary, tile_id: String, amount: int, label: String) -> void:
	var gain := mini(amount, MAX_GUARD - int(recipient.guard))
	_guard(recipient, amount, tile_id, actor, false)
	if gain > 0:
		_record_mastery("%s gives %s %d Guard." % [label, recipient.name, gain])


func _restore_mastery_health(actor: Dictionary, recipient: Dictionary, tile_id: String, amount: int, label: String) -> int:
	var healed := mini(amount, int(recipient.max_hp) - int(recipient.hp))
	if healed > 0:
		recipient.hp += healed
		var message := "%s restores %d HP to %s." % [label, healed, recipient.name]
		_emit("heal", message, actor, recipient, tile_id, healed)
	return healed


func _record_mastery(message: String) -> void:
	_activation.get_or_add("effect_details", []).append(message)


func _add_tile_visual_cue(actor: Dictionary, tile_id: String, origin: Vector2, first_event: int) -> void:
	var target := _find_unit(_activation.target)
	var tile: Dictionary = TILES[tile_id]
	var radius: float = tile.get("radius", tile.get("splash", tile.get("convergence_radius",
		tile.get("block_wave_radius", tile.get("guard_radius", 0.0)))))
	var impact: Vector2 = target.get("pos", origin)
	var anchored := false
	var contact_points: Array[Vector2] = []
	for index in range(first_event, _events.size()):
		var event: Dictionary = _events[index]
		if event.actor != actor.id or event.tile != tile_id or event.kind not in ["hit", "guard", "heal", "pull", "push"]:
			continue
		var point: Vector2 = event.from if event.kind in ["push", "pull"] else event.to
		if not anchored and event.target == _activation.target:
			impact = point
			anchored = true
		if point not in contact_points:
			contact_points.append(point)
	visual_cues.append({
		"kind": "hero_cast", "tick": tick, "actor": actor.id, "tile": tile_id,
		"target": _activation.target, "from": origin, "to": impact, "contact_points": contact_points,
		"strike_from": _activation.get("attack_origin", origin), "from_afterimage": _activation.has("attack_origin"),
		"arrival": actor.pos,
		"landed": _activation.status == "landed", "radius": radius if is_finite(radius) else 0.0,
	})


func _cast(actor: Dictionary, tile_id: String, rule: String, reach := -1.0) -> void:
	var tile: Dictionary = TILES[tile_id]
	if reach < 0.0:
		reach = tile.range
	var arsenal := _arsenal_tiles.has(tile_id)
	if arsenal and tile.damage == 0:
		var recipient := _arsenal_support_target(actor, tile)
		_review_activation_target(recipient)
		_apply_arsenal_support(actor, recipient, tile_id, tile)
		return
	if tile.get("family") == "guard":
		_cast_guard(actor, tile_id, tile, rule, reach)
		return
	var target := _select_attack_target(actor, tile_id, rule, reach)
	if target.is_empty():
		var out_of_range := _select(actor, rule)
		if not out_of_range.is_empty():
			_review_activation_target(out_of_range)
			_emit("miss", "%s: %s was out of range." % [actor.name, tile.label], actor, out_of_range, tile_id)
			if not _activation.is_empty():
				var position: Vector2 = actor.pos
				_activation.reason = "%s was out of range (%d away, %d reach)." % [out_of_range.name, roundi(position.distance_to(out_of_range.pos)), roundi(reach)]
		elif not _activation.is_empty():
			_activation.status = "miss"
			_activation.reason = "No eligible enemy remained when the tile finished."
		return
	_review_activation_target(target)
	if arsenal:
		_cast_arsenal_attack(actor, target, tile_id, tile)
		return
	if tile.get("family") != "blink":
		_prepare_siege_fuse(actor, target, tile_id)
	match tile_id:
		"pull", "gravity_hook":
			var force := 935.0 if tile_id == "gravity_hook" else 735.0
			if actor.name == "Hexwright":
				force += 155.0
			var direction: Vector2 = _attack_origin(actor) - target.pos
			_displace("pull", actor, target, tile_id, direction, force)
			_damage(actor, target, tile.damage, tile_id)
		"bash":
			_strike_and_push(actor, target, tile_id, tile.damage, 600.0)
		"shield_ram":
			_strike_and_push(actor, target, tile_id, tile.damage, 635.0)
			_guard_from_tile(actor, actor, tile.guard_on_hit, tile_id)
		"hook_bash":
			_damage(actor, target, tile.damage, tile_id)
			_pull_toward(actor, target, tile_id, _attack_origin(actor), 780.0)
		"bulwark_charge":
			if _charge(actor, target, tile_id):
				_strike_and_push(actor, target, tile_id, tile.damage, 810.0)
				_guard_from_tile(actor, actor, tile.guard_on_hit, tile_id)
			else:
				_emit("miss", "%s: Bulwark Charge has no clear path." % actor.name, actor, target, tile_id)
				return
		"rebound":
			var impulse: Vector2 = target.impulse
			var bonus := 12 if not impulse.is_zero_approx() else 0
			_strike_and_push(actor, target, tile_id, tile.damage + bonus, 710.0)
		"sunwall":
			_area_push(actor, target, tile_id, tile.damage, 155.0, 650.0)
			_guard_allies(actor, tile_id, 14, 235.0, true)
		"graviton":
			_gravity_strike(actor, target, tile_id, 170.0, false)
		"dawn_bastion":
			_area_push(actor, target, tile_id, tile.damage, 205.0, 875.0)
			_guard_allies(actor, tile_id, 22, INF, true)
		"event_horizon":
			_gravity_strike(actor, target, tile_id, 245.0, true)
		"meteor_seal":
			for enemy in _enemies_in_area(actor, target.pos, tile.radius):
				_damage(actor, enemy, tile.damage, tile_id)
		_:
			match tile.get("family", ""):
				"blink": _cast_blink(actor, target, tile_id, tile)
				"shot": _cast_shot(actor, target, tile_id, tile)
				"slam": _area_push(actor, target, tile_id, tile.damage, tile.radius, tile.push, tile.get("guard_break", 0))
	if tile.get("family") == "bash":
		_warden_guard(actor, tile_id)


func _select_attack_target(actor: Dictionary, tile_id: String, rule: String, reach: float) -> Dictionary:
	if actor.has("afterimage") and can_trigger_afterimage(tile_id):
		var echo: Dictionary = actor.afterimage
		actor.erase("afterimage")
		var target := _select(actor, rule, reach, echo.position)
		if not target.is_empty():
			_activation["attack_origin"] = echo.position
			_relic_proc("afterimage", "Afterimage", 0, actor, target, echo.source, echo.beat, "Struck from the Blink departure point", echo.position)
			return target
	return _select(actor, rule, reach)


func _attack_origin(actor: Dictionary) -> Vector2:
	return _activation.get("attack_origin", actor.pos) if _activation.get("actor") == actor.id else actor.pos


func _prepare_siege_fuse(actor: Dictionary, target: Dictionary, tile_id: String) -> void:
	var tile: Dictionary = TILES[tile_id]
	if tile.width < 4 or tile.damage <= 0 or _siege_loop == _loop_index() or not _has_relic(actor, "siege_fuse"):
		return
	_siege_loop = _loop_index()
	var count := 0
	var center: Vector2 = target.pos
	for enemy in _enemies_in_area(actor, center, SIEGE_PULL_REACH):
		if enemy.id == target.id:
			continue
		var start: Vector2 = enemy.pos
		var destination := _siege_pull_landing(enemy, center)
		if start.is_equal_approx(destination):
			continue
		enemy.pos = destination
		enemy.prev_pos = destination
		enemy["displaced_until"] = tick + DISPLACEMENT_BONUS_WINDOW
		_emit("pull", "Siege Fuse draws %s toward %s." % [enemy.name, target.name], actor, enemy, "siege_fuse",
			roundi(start.distance_to(destination)), start, destination, {"source_tile": tile_id})
		_break_displaced_relay_link(enemy, destination, actor)
		count += 1
	if count > 0:
		var effect := "Pulled one enemy inward" if count == 1 else "Pulled %d enemies inward" % count
		_relic_proc("siege_fuse", "Siege Fuse", count, actor, target, tile.label, 0, effect, center)


func _siege_pull_landing(enemy: Dictionary, center: Vector2) -> Vector2:
	var start: Vector2 = enemy.pos
	var resistance: float = enemy.get("attack", {}).get("displacement", 1.0)
	var end := _bounded(start.move_toward(center, SIEGE_PULL_DISTANCE * resistance), enemy.radius)
	return _slide_landing(enemy, end)


func _slide_landing(mover: Dictionary, end: Vector2) -> Vector2:
	var start: Vector2 = mover.pos
	if end.is_equal_approx(start):
		return start
	var fraction := 1.0
	for unit: Dictionary in units:
		if unit.id == mover.id or unit.hp <= 0:
			continue
		var minimum: float = mover.radius + unit.radius + 3.0
		var offset: Vector2 = unit.pos - start
		if offset.length_squared() <= minimum * minimum:
			if offset.dot(end - start) > 0.0:
				return start
			continue
		var contact := Geometry2D.segment_intersects_circle(start, end, unit.pos, minimum)
		if contact >= 0.0:
			fraction = minf(fraction, contact)
	return start.lerp(end, fraction)


func _review_activation_target(target: Dictionary) -> void:
	if not _activation.is_empty():
		_activation.target = target.id
		_activation.target_name = target.name


func _activation_result(activation: Dictionary) -> String:
	var parts := PackedStringArray()
	if activation.damage > 0:
		parts.append("%d damage dealt" % activation.damage)
	if activation.guard > 0:
		parts.append("%d Guard granted" % activation.guard)
	var notes: Array = activation.get("effect_details", [])
	var result := ", ".join(parts) + "." if not parts.is_empty() else ""
	if not notes.is_empty():
		return (result + " " + " ".join(notes)).strip_edges()
	if not result.is_empty():
		return result
	var tile: Dictionary = TILES[activation.tile]
	if tile.damage == 0 or (tile.get("family") == "guard" and activation.target_name == activation.hero):
		return "Guard was already full."
	return "The tile connected. The target blocked all damage."


func _arsenal_support_target(actor: Dictionary, tile: Dictionary) -> Dictionary:
	var recipient := actor
	if tile.get("support") == "weakest":
		for ally: Dictionary in units:
			if ally.side == actor.side and ally.hp > 0 and ally.hp < recipient.hp:
				recipient = ally
	return recipient


func _apply_arsenal_support(actor: Dictionary, recipient: Dictionary, tile_id: String, tile: Dictionary) -> void:
	var guard: int = tile.get("guard", 0)
	if guard > 0:
		if tile.get("support") == "party":
			_guard_allies(actor, tile_id, guard, INF, true)
		else:
			_guard_from_tile(actor, recipient, guard, tile_id)
	var healing: int = tile.get("heal", 0)
	if healing <= 0 or _activation.is_empty():
		return
	if tile.get("party_heal", false):
		for ally: Dictionary in units:
			if ally.side == actor.side and ally.hp > 0:
				_heal_from_tile(actor, ally, tile_id, healing, ally.lane)
	else:
		_heal_from_tile(actor, recipient, tile_id, healing)


func _heal_from_tile(actor: Dictionary, recipient: Dictionary, tile_id: String, healing: int, recipient_lane := -1) -> void:
	var placement := Vector3i(actor.lane, _activation.start, recipient_lane)
	var gained := mini(healing, recipient.max_hp - recipient.hp)
	if gained <= 0 or _healed_tiles.has(placement):
		return
	_healed_tiles[placement] = true
	recipient.hp += gained
	_emit("heal", "%s restores %d HP to %s." % [TILES[tile_id].label, gained, recipient.name], actor, recipient, tile_id, gained)


func _cast_arsenal_attack(actor: Dictionary, target: Dictionary, tile_id: String, tile: Dictionary) -> void:
	var start: Vector2 = actor.pos
	if tile.get("blink_strike", false) and not _blink_to_target(actor, target, tile_id, 0.0):
		return
	if tile.get("charge", false) and not _charge(actor, target, tile_id):
		_emit("miss", "%s: %s has no clear path." % [actor.name, tile.label], actor, target, tile_id)
		return
	var impact: Vector2 = target.pos
	_prepare_siege_fuse(actor, target, tile_id)
	var damage: int = tile.damage + _distance_bonus(actor, target, tile)
	var healing_bonus := int(tile.get("healing_damage_bonus", 0)) if _last_party_heal_loop == _loop_index() else 0
	damage += healing_bonus
	if tile.has("recent_block_damage") and tick - int(actor.get("last_guard_block_tick", -LOOP_TICKS)) \
			<= int(tile.recent_block_beats) * TICKS_PER_BEAT:
		damage += int(tile.recent_block_damage)
	if actor.get("last_primary_tile_target", "") == target.id:
		damage += int(tile.get("repeat_target_damage", 0))
	var last_blink := int(actor.get("last_teleport_tick", -1))
	if tile.has("teleport_followup_damage") and last_blink >= 0 and last_blink < tick \
			and tick - last_blink <= int(tile.teleport_followup_beats) * TICKS_PER_BEAT:
		damage += int(tile.teleport_followup_damage)
	if target.hp * 2 < target.max_hp:
		damage += int(tile.get("low_hp_bonus", 0))
	if not str(target.intent).is_empty() and target.intent_tick >= tick:
		damage += int(tile.get("windup_bonus", 0))
	if actor.guard > 0:
		damage += int(tile.get("guard_bonus", 0))
	if tick <= target.get("displaced_until", -1):
		damage += int(tile.get("displaced_bonus", 0))
	var spent_guard := mini(actor.guard, int(tile.get("guard_spend", 0)))
	if spent_guard > 0:
		actor.guard -= spent_guard
		var bonus := spent_guard * 2
		damage += bonus
		_emit("guard_spent", "%s spends %d Guard for %d extra damage." % [actor.name, spent_guard, bonus],
			actor, actor, tile_id, spent_guard)
	var pull_first: bool = tile.get("pull_before_hit", false)
	if pull_first:
		_pull_toward(actor, target, tile_id, _attack_origin(actor), tile.pull)
	damage += StarterSpecialtyEffects.hexwright_pull_bonus(self, actor, target, tile_id, tile)
	var burning: bool = tile.get("ember_burn_if_burning", false) and ArtificeSpecialties.is_burning(target)
	_strip_guard(actor, target, tile_id, int(tile.get("guard_break", 0)))
	_damage(actor, target, damage, tile_id)
	VanguardSpecialties.apply_attack_followup(self, actor, target, tile_id, tile, start, impact)
	if tile.has("dash_followup_damage") and target.hp > 0:
		var last_dash := int(actor.get("last_dash_tick", -1))
		if last_dash >= 0 and last_dash < tick and tick - last_dash <= int(tile.dash_followup_beats) * TICKS_PER_BEAT:
			_damage(actor, target, int(tile.dash_followup_damage), tile_id, "Backdraft", {"dash_followup": true})
	_apply_splash(actor, target, tile_id, tile, healing_bonus)
	if target.hp > 0:
		if tile.has("push"):
			var moved := _displace("push", actor, target, tile_id, target.pos - _attack_origin(actor), tile.push)
			if moved and tile.has("lance_return_bonus"):
				_prime_return_charge(actor, tile_id, tile)
		if tile.has("pull") and not pull_first:
			_pull_toward(actor, target, tile_id, _attack_origin(actor), tile.pull)
		if tile.has("mark_bonus") and not _activation.is_empty():
			_apply_arsenal_mark(actor, target, tile_id, tile)
		if tile.has("chorus_mark_bonus") or tile.has("chorus_guard"):
			_apply_cantor_mark(actor, target, tile_id, tile)
		if tile.has("chorus_echo_damage"):
			ArtificeSpecialties.prime_echo(self, actor, target, tile_id, tile)
	var burn_ready: bool = burning if tile.get("ember_burn_if_burning", false) else tick <= target.get("displaced_until", -1)
	if tile.has("ember_burn_damage") and burn_ready:
		_apply_ember_burn(actor, target, tile_id, tile, impact)
	if tile.has("cluster_pull_radius"):
		_cluster_pull(actor, target, tile_id, impact, tile.cluster_pull_radius, tile.cluster_pull_force)
	if tile.has("sweep_push_radius"):
		_sweep_push(actor, target, tile_id, impact, tile.sweep_push_radius, tile.sweep_push_force)
	if tile.has("retreat") and _retreat_from(actor, target, tile_id, tile.retreat):
		if tile.has("ranged_followup_bonus"):
			_prime_ranged_followup(actor, tile_id, tile)
		if tile.has("lance_return_bonus"):
			_prime_return_charge(actor, tile_id, tile)
	if tile.has("blink_on_hit_retreat"):
		_blink_to_target(actor, target, tile_id, tile.blink_on_hit_retreat, false)
	if tile.get("heal_overflow_on_hit", false):
		ApothecaryTiles.apply_tonic(self, actor, tile_id, tile)
	elif tile.has("guard"):
		_apply_arsenal_support(actor, _arsenal_support_target(actor, tile), tile_id, tile)
		if tile.has("harmony_guard"):
			ArtificeSpecialties.apply_harmony_guard(self, actor, tile_id, tile)
		if tile.has("intercept_guard"):
			VanguardSpecialties.prime_intercept(self, actor, tile_id, tile)
	if tile.has("ally_guard"):
		_guard_from_tile(actor, _weakest_other_ally(actor), tile.ally_guard, tile_id)
	if tile.has("bastion_party_guard"):
		_prime_bastion_ward(actor, tile_id, tile)


func _apply_ember_burn(actor: Dictionary, target: Dictionary, tile_id: String, tile: Dictionary, impact: Vector2) -> void:
	var targets: Array = [target] if target.hp > 0 else []
	if tile.has("ember_burn_radius"):
		targets = _enemies_in_area(actor, impact, tile.ember_burn_radius)
	for enemy: Dictionary in targets:
		var burns: Dictionary = enemy.get_or_add("ember_burns", {})
		var active: Dictionary = burns.get(actor.id, {})
		if not active.is_empty() and active.damage * active.remaining > tile.ember_burn_damage * tile.ember_burn_ticks:
			continue
		burns[actor.id] = {"damage": tile.ember_burn_damage, "remaining": tile.ember_burn_ticks,
			"next_tick": int(active.get("next_tick", tick + TICKS_PER_BEAT)), "tile": tile_id}
		_emit("ember_ignite", "%s ignites %s for %d beats." % [tile.label, enemy.name, tile.ember_burn_ticks],
			actor, enemy, tile_id, tile.ember_burn_damage)


func _weakest_other_ally(actor: Dictionary) -> Dictionary:
	var recipient := {}
	for ally: Dictionary in units:
		if ally.side == actor.side and ally.id != actor.id and ally.hp > 0:
			if recipient.is_empty() or ally.hp < recipient.hp:
				recipient = ally
	return actor if recipient.is_empty() else recipient


func _cluster_pull(actor: Dictionary, target: Dictionary, tile_id: String, impact: Vector2, radius: float, force: float) -> void:
	var pulled := 0
	for neighbor: Dictionary in _enemies_in_area(actor, impact, radius):
		if neighbor.id != target.id and _pull_toward(actor, neighbor, tile_id, impact, force):
			pulled += 1
	if pulled > 0:
		var count := "one nearby enemy" if pulled == 1 else "%d nearby enemies" % pulled
		_emit("cluster_pull", "%s pulls %s toward the impact." % [TILES[tile_id].label, count],
			actor, target, tile_id, pulled, impact, impact)


func _sweep_push(actor: Dictionary, target: Dictionary, tile_id: String, impact: Vector2, radius: float, force: float) -> void:
	var pushed := 0
	var origin := _attack_origin(actor)
	for neighbor: Dictionary in _enemies_in_area(actor, impact, radius):
		if neighbor.id == target.id:
			continue
		_displace("push", actor, neighbor, tile_id, neighbor.pos - origin, force)
		pushed += 1
	if pushed > 0:
		var count := "one nearby enemy" if pushed == 1 else "%d nearby enemies" % pushed
		_emit("sweep_push", "%s knocks back %s." % [TILES[tile_id].label, count],
			actor, target, tile_id, pushed, impact, impact)


func _apply_arsenal_mark(actor: Dictionary, target: Dictionary, tile_id: String, tile: Dictionary) -> void:
	var for_ally: bool = tile.get("ally_only_mark", false)
	target["ally_mark" if for_ally else "arsenal_mark"] = {
		"bonus": tile.mark_bonus, "expires": tick + tile.mark_beats * TICKS_PER_BEAT,
		"order": _activation.order, "marker": actor.id,
	}
	var message := "%s marks %s for %d beats." % [tile.label, target.name, tile.mark_beats]
	if for_ally:
		message += " Only another hero can spend it."
	_emit("mark", message, actor, target, tile_id, tile.mark_bonus)


func _apply_cantor_mark(actor: Dictionary, target: Dictionary, tile_id: String, tile: Dictionary) -> void:
	var bonus: int = tile.get("chorus_mark_bonus", 0)
	var guard: int = tile.get("chorus_guard", 0)
	var beats: int = tile.get("chorus_mark_beats", tile.get("chorus_guard_beats", 0))
	target["cantor_mark"] = {
		"marker": actor.id, "expires": tick + beats * TICKS_PER_BEAT,
		"bonus": bonus, "guard": guard, "contributors": [],
	}
	var message := "%s marks %s for %d beats. %s" % [tile.label, target.name, beats,
		"The next hit from each of two other heroes gains damage." if bonus > 0
		else "A hit from another hero grants the party Guard."]
	_emit("chorus_mark", message, actor, target, tile_id, bonus if bonus > 0 else guard)


func _retreat_from(actor: Dictionary, target: Dictionary, tile_id: String, distance: float) -> bool:
	var start: Vector2 = actor.pos
	var threat: Vector2 = target.pos
	var away := threat.direction_to(start)
	if away.is_zero_approx():
		away = Vector2.LEFT
	for angle in [0.0, 0.55, -0.55, 1.05, -1.05]:
		var destination := _bounded(start + away.rotated(angle) * distance, actor.radius)
		var landing := _slide_landing(actor, destination)
		if landing.distance_squared_to(threat) <= start.distance_squared_to(threat) or landing.distance_squared_to(start) < 1.0:
			continue
		actor.pos = landing
		actor.prev_pos = landing
		actor["last_dash_tick"] = tick
		_emit("retreat", "%s retreats from %s." % [actor.name, target.name], actor, target, tile_id, 0, start, landing)
		return true
	return false


func _prime_ranged_followup(actor: Dictionary, tile_id: String, tile: Dictionary) -> void:
	var beats: int = tile.ranged_followup_beats
	var bonus: int = tile.ranged_followup_bonus
	actor["ranged_followup"] = {"until": tick + beats * TICKS_PER_BEAT, "bonus": bonus}
	_emit("ranged_followup_ready", "%s readies +%d damage on their next ranged hit within %d beats." % [actor.name, bonus, beats],
		actor, actor, tile_id, bonus)


func _cast_shot(actor: Dictionary, target: Dictionary, tile_id: String, tile: Dictionary) -> void:
	var damage: int = tile.damage + _distance_bonus(actor, target, tile)
	_damage(actor, target, damage, tile_id)
	_apply_splash(actor, target, tile_id, tile)


func _distance_bonus(actor: Dictionary, target: Dictionary, tile: Dictionary) -> int:
	var bonus: int = tile.get("distance_bonus", 0)
	if bonus > 0 and _attack_origin(actor).distance_squared_to(target.pos) > PRECISION_BONUS_RANGE * PRECISION_BONUS_RANGE:
		return bonus
	return 0


func _apply_splash(actor: Dictionary, target: Dictionary, tile_id: String, tile: Dictionary, bonus := 0) -> void:
	if not tile.has("splash"):
		return
	var neighbors := _splash_neighbors(actor, target, tile.splash)
	if tile.has("splash_targets"):
		_sort_by_distance(neighbors, target.pos)
		neighbors.resize(mini(neighbors.size(), tile.splash_targets))
	for enemy: Dictionary in neighbors:
		_damage(actor, enemy, tile.splash_damage + bonus, tile_id)


func _splash_neighbors(actor: Dictionary, target: Dictionary, radius: float) -> Array[Dictionary]:
	var neighbors := _enemies_in_area(actor, target.pos, radius)
	neighbors.erase(target)
	return neighbors


func _sort_by_distance(units_in_range: Array[Dictionary], center: Vector2) -> void:
	units_in_range.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var first := center.distance_squared_to(a.pos)
		var second := center.distance_squared_to(b.pos)
		return a.id < b.id if first == second else first < second)


func _cast_guard(actor: Dictionary, tile_id: String, tile: Dictionary, rule: String, reach: float) -> void:
	if tile.has("guard_bonus_cap"):
		var target := _select_attack_target(actor, tile_id, rule, reach)
		_review_activation_target(actor if target.is_empty() else target)
		if not target.is_empty():
			_prepare_siege_fuse(actor, target, tile_id)
			var spent := mini(actor.guard, tile.guard_bonus_cap)
			actor.guard -= spent
			var damage: int = tile.damage + spent
			if tile.has("push"):
				_strike_and_push(actor, target, tile_id, damage, tile.push)
			else:
				_damage(actor, target, damage, tile_id)
		_guard_from_tile(actor, actor, tile.guard, tile_id)
		if target.is_empty() and not _activation.is_empty():
			_activation.reason = "No enemy was in reach for the strike."
		return
	var recipient := _guard_recipient(actor, tile)
	_review_activation_target(recipient)
	if tile.get("support") == "party":
		_guard_allies(actor, tile_id, tile.guard, INF, true)
		if tile.has("weakest_bonus"):
			_guard_from_tile(actor, recipient, tile.weakest_bonus, tile_id)
	else:
		_guard_from_tile(actor, actor, tile.guard, tile_id)
		if recipient.id != actor.id:
			_guard_from_tile(actor, recipient, tile.guard, tile_id)


func _guard_recipient(actor: Dictionary, tile: Dictionary) -> Dictionary:
	var lowest := {}
	var support: String = tile.get("support", "")
	if support == "weakest" or tile.has("weakest_bonus"):
		for ally: Dictionary in units:
			if ally.side != actor.side or ally.hp <= 0 or (support == "weakest" and ally.id == actor.id):
				continue
			if lowest.is_empty() or ally.hp < lowest.hp:
				lowest = ally
	return actor if lowest.is_empty() else lowest


func _cast_blink(actor: Dictionary, target: Dictionary, tile_id: String, tile: Dictionary) -> void:
	if not _blink_to_target(actor, target, tile_id, tile.get("retreat", 0.0)):
		return
	_prepare_siege_fuse(actor, target, tile_id)
	var enemies: Array = _enemies_in_area(actor, target.pos, tile.splash) if tile.has("splash") else [target]
	for enemy: Dictionary in enemies:
		if tile.has("push"):
			_strike_and_push(actor, enemy, tile_id, tile.damage, tile.push)
		else:
			_damage(actor, enemy, tile.damage, tile_id)
	if tile.has("guard"):
		_guard_allies(actor, tile_id, tile.guard, tile.get("guard_radius", 0.0), true)


func _blink_to_target(actor: Dictionary, target: Dictionary, tile_id: String, retreat: float, report_failure := true) -> bool:
	var departure: Vector2 = actor.pos
	var facing: float = actor.facing
	var label: String = TILES[tile_id].label
	if not _teleport(actor, target, tile_id, retreat):
		if report_failure:
			_emit("miss", "%s: %s had no clear landing." % [actor.name, label], actor, target, tile_id)
		return false
	if _has_relic(actor, "afterimage"):
		actor["afterimage"] = {"position": departure, "facing": facing, "source": label, "beat": _beat()}
	return true


func _warden_guard(actor: Dictionary, tile_id: String) -> void:
	var loop_index := floori(float(tick - 1) / LOOP_TICKS)
	if actor.name == "Warden" and actor.last_bash_loop != loop_index:
		actor.last_bash_loop = loop_index
		_guard(actor, 4, tile_id)


func _strike_and_push(actor: Dictionary, target: Dictionary, tile_id: String, damage: int, force: float) -> void:
	_damage(actor, target, damage, tile_id)
	if target.hp > 0:
		_displace("push", actor, target, tile_id, target.pos - _attack_origin(actor), force)


func _area_push(actor: Dictionary, target: Dictionary, tile_id: String, damage: int, radius: float, force: float, guard_break := 0) -> void:
	for enemy in _enemies_in_area(actor, target.pos, radius):
		_strip_guard(actor, enemy, tile_id, guard_break)
		_strike_and_push(actor, enemy, tile_id, damage, force)


func _strip_guard(actor: Dictionary, target: Dictionary, tile_id: String, limit: int) -> void:
	var stripped := mini(target.guard, limit)
	if stripped > 0:
		target.guard -= stripped
		_emit("guard_break", "%s strips %d Guard from %s." % [TILES[tile_id].label, stripped, target.name], actor, target, tile_id, stripped)


func _enemies_in_area(actor: Dictionary, center: Vector2, radius: float) -> Array[Dictionary]:
	var affected: Array[Dictionary] = []
	for enemy in units:
		var point: Vector2 = enemy.pos
		if enemy.side != actor.side and enemy.hp > 0 and point.distance_to(center) <= radius:
			affected.append(enemy)
	return affected


func _guard_allies(actor: Dictionary, tile_id: String, amount: int, radius: float = INF, direct_grant := false) -> void:
	var position: Vector2 = actor.pos
	for ally in units:
		if ally.side == actor.side and ally.hp > 0 and position.distance_to(ally.pos) <= radius:
			if direct_grant:
				_guard_from_tile(actor, ally, amount, tile_id)
			else:
				_guard(ally, amount, tile_id, actor)


func _guard_from_tile(actor: Dictionary, recipient: Dictionary, amount: int, tile_id: String) -> void:
	_guard(recipient, amount, tile_id, actor)
	if amount > 0 and not _activation.is_empty() and _has_relic(actor, "bastion_medal"):
		_activation.get_or_add("bastion_recipients", {})[recipient.id] = recipient


func _apply_bastion_medal(actor: Dictionary, tile_id: String) -> void:
	if not _activation.has("bastion_recipients"):
		return
	var recipients: Dictionary = _activation.bastion_recipients
	_activation.erase("bastion_recipients")
	# Add the bonus after the tile's own grants, which may trigger passives or Overflow Chalice.
	for recipient: Dictionary in recipients.values():
		var bonus := mini(BASTION_MEDAL_GUARD, MAX_GUARD - int(recipient.guard))
		if recipient.hp <= 0 or bonus <= 0:
			continue
		recipient.guard += bonus
		_activation.guard += bonus
		_relic_proc("bastion_medal", "Bastion Medal", bonus, actor, recipient, TILES[tile_id].label,
			_activation.beat, "Granted %d extra Guard" % bonus)


func _apply_bellmaker_finishes(actor: Dictionary, tile_id: String) -> void:
	var tile: Dictionary = TILES[tile_id]
	if tile.damage == 0 and _has_relic(actor, "bellmaker_clapper") \
			and int(actor.get("bellmaker_clapper_loop", -1)) != _loop_index():
		var enemies := _enemies_in_area(actor, actor.pos, BELLMAKER_CLAPPER_RADIUS)
		if not enemies.is_empty():
			actor["bellmaker_clapper_loop"] = _loop_index()
			_emit("bell_ring", "Bellmaker's Clapper rings out.", actor, actor, "bellmaker_clapper", int(BELLMAKER_CLAPPER_RADIUS))
			var damage := 0
			for enemy: Dictionary in enemies:
				var before: int = enemy.hp
				_damage(actor, enemy, BELLMAKER_CLAPPER_DAMAGE, tile_id, "Bellmaker's Clapper")
				damage += before - int(enemy.hp)
			_relic_proc("bellmaker_clapper", "Bellmaker's Clapper", damage, actor, enemies[0], tile.label,
				_activation.beat, "The shockwave hit %d and dealt %d damage in total" % [enemies.size(), damage])
	if tile.width >= 3 and _has_relic(actor, "bellmaker_resonant_plate") \
			and int(actor.get("bellmaker_resonant_plate_loop", -1)) != _loop_index():
		actor["bellmaker_resonant_plate_loop"] = _loop_index()
		var gain := mini(BELLMAKER_RESONANT_PLATE_GUARD, MAX_GUARD - int(actor.guard))
		if gain > 0:
			_guard(actor, gain, tile_id, {}, false)
			_relic_proc("bellmaker_resonant_plate", "Resonant Plate", gain, actor, actor, tile.label,
				_activation.beat, "Granted %d extra Guard" % gain)


func _gravity_strike(actor: Dictionary, target: Dictionary, tile_id: String, radius: float, collapse: bool) -> void:
	var impact: Vector2 = target.pos
	for enemy in _enemies_in_area(actor, impact, radius):
		if enemy.id == target.id or collapse:
			_damage(actor, enemy, TILES[tile_id].damage, tile_id)
		if collapse and enemy.intent != "" and enemy.get("colossus_stage", 0) == 0 \
				and not enemy.get("relay_charge_active", false) and enemy.get("wreckmaster_phase", 0) == 0 \
				and enemy.get("tidekeeper_phase", 0) == 0 and enemy.get("admiral_phase", 0) == 0 \
				and enemy.get("dock_winch_ally", "") == "":
			enemy.intent = ""
			enemy.next_attack = tick + TICKS_PER_BEAT * 3
			_emit("interrupt", "%s interrupts %s." % [TILES[tile_id].label, enemy.name], actor, enemy, tile_id)
		var center: Vector2 = _attack_origin(actor) if enemy.id == target.id else impact
		_pull_toward(actor, enemy, tile_id, center, 990.0 if collapse else 860.0)


func _pull_toward(actor: Dictionary, enemy: Dictionary, tile_id: String, center: Vector2, force: float) -> bool:
	var offset: Vector2 = center - enemy.pos
	if enemy.hp <= 0 or offset.length_squared() <= 0.001:
		return false
	_displace("pull", actor, enemy, tile_id, offset, force + (90.0 if actor.get("class") == "hexwright" else 0.0))
	return true


func _charge(actor: Dictionary, target: Dictionary, tile_id: String) -> bool:
	var origin: Vector2 = actor.pos
	var destination: Vector2 = target.pos
	var direction := origin.direction_to(destination)
	var clearance: float = actor.radius + target.radius + 18.0
	var distance := origin.distance_to(destination)
	if distance <= clearance:
		return true
	# A body in the direct path can leave a clear approach to either flank.
	var flank := acos(clearance / distance)
	for angle in [0.0, flank * 0.5, -flank * 0.5, flank, -flank]:
		var landing := _bounded(destination - direction.rotated(angle) * clearance, actor.radius)
		if not _free_position(landing, actor) or not _slide_landing(actor, landing).is_equal_approx(landing):
			continue
		actor.pos = landing
		actor.impulse = Vector2.ZERO
		if landing.distance_squared_to(origin) >= 1.0:
			actor["last_dash_tick"] = tick
		_emit("charge", "%s dashes toward %s." % [actor.name, target.name], actor, target, tile_id, 0, origin, landing)
		return true
	return false


func _displace(kind: String, actor: Dictionary, target: Dictionary, tile_id: String, offset: Vector2, force: float) -> bool:
	if kind == "push" and _has_relic(actor, "copper_compass") and _compass_loop != _loop_index():
		_compass_loop = _loop_index()
		force += 145.0
	force *= float(target.get("attack", {}).get("displacement", 1.0))
	if target.get("special_intent") == "relay_recruit":
		force *= float(target.attack.windup_displacement)
	if force > 0.0:
		target.erase("dock_wall_source")
		_track_collision_push(kind, actor, target, tile_id)
	var direction := offset.normalized() if offset.length_squared() > 0.001 else Vector2.RIGHT
	var start_position: Vector2 = target.pos
	var impulse: Vector2 = target.impulse + direction * force
	target.impulse = impulse.limit_length(IMPULSE_CAP)
	var launch: Vector2 = target.impulse
	var endpoint := _bounded(start_position + launch.normalized() * (launch.length_squared() / (2.0 * IMPULSE_DECAY)), target.radius)
	var moved := force > 0.0 and not start_position.is_equal_approx(endpoint)
	if moved:
		target["displaced_until"] = tick + DISPLACEMENT_BONUS_WINDOW
		if _activation.get("actor") == actor.id and _activation.get("tile") == tile_id \
				and actor.get("mastery", {}).get("trigger") == kind:
			_activation.get_or_add("mastery_target", target.id)
	var action := "pulls" if kind == "pull" else "knocks back"
	_emit(kind, "%s %s %s." % [actor.name, action, target.name], actor, target, tile_id, roundi(force), start_position, endpoint)
	if not _activation.is_empty() and actor.side == "hero" and target.side == "enemy" and target.hp > 0 \
			and force > 0.0 and _has_relic(actor, "towline_knot") and _towline_loop != _loop_index():
		_towline_loop = _loop_index()
		_towline_mark = {
			"target": target.id, "expires": tick + 2 * TICKS_PER_BEAT, "order": _activation.order,
			"source": TILES[tile_id].label, "source_beat": _activation.beat,
		}
	_break_displaced_relay_link(target, endpoint, actor if actor.side == "hero" else {})
	if target.get("marshal_plated", false) and actor.side == "hero" and force > 100.0:
		_expose_marshal(actor, target)
	elif target.get("prism_warded", false) and actor.side == "hero" and force > 100.0:
		_expose_prism(actor, target)
	elif target.get("colossus_stage", 0) == 1 and actor.side == "hero" and force > 100.0:
		target.colossus_stage = 2
		target.colossus_first = actor.id
		_emit("interrupt", "%s displaces the Colossus. Hit it with a different hero." % actor.name,
			actor, target, "colossus_displaced")
	elif target.get("relay_charge_active", false) and actor.side == "hero" and force > 100.0:
		_interrupt_relay_charge(actor, target, kind)
	elif target.get("dock_winch_ally", "") != "" and actor.side == "hero" and force > 100.0:
		_clear_winch_intent(target)
		target.next_attack = tick + TICKS_PER_BEAT * 5
		_emit("interrupt", "%s interrupts Winch Pull." % actor.name, actor, target, "dock_winch_interrupted")
	elif target.get("tidekeeper_phase", 0) >= 2 and actor.side == "hero" and force > 85.0:
		_displace_tidekeeper(actor, target, kind)
	elif target.get("admiral_phase", 0) >= 2 and actor.side == "hero" and force > 85.0:
		_displace_admiral(actor, target, kind)
	return moved


func _track_collision_push(kind: String, actor: Dictionary, target: Dictionary, tile_id: String) -> void:
	var bonus: int = TILES.get(tile_id, {}).get("collision_bonus", 0) if kind == "push" else 0
	var passive: bool = kind == "push" and actor.get("class") == "breaker"
	if bonus == 0 and not passive:
		# A new push or pull takes over a signature tile's collision setup.
		if target.get("collision_push", {}).has("tile"):
			target.erase("collision_push")
		return
	var setup := {"source": actor.id, "source_tile": tile_id, "until": tick + COLLISION_WINDOW_TICKS,
		"damage": bonus + (5 if passive else 0)}
	if bonus > 0:
		setup["tile"] = tile_id
		setup["bonus"] = bonus
		setup["activation"] = _activation
	target["collision_push"] = setup


func _teleport(actor: Dictionary, target: Dictionary, tile_id: String, retreat: float) -> bool:
	var start_position: Vector2 = actor.pos
	var target_position: Vector2 = target.pos
	var direction := start_position.direction_to(target_position)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var spacing: float = target.radius + actor.radius + 22.0
	var anchor := target_position
	if retreat > 0.0:
		direction = -direction
		anchor = start_position
		spacing = retreat
	for angle in [0.0, 0.52, -0.52, 1.05, -1.05, PI / 2.0, -PI / 2.0, PI]:
		var landing := _bounded(anchor + direction.rotated(angle) * spacing, actor.radius)
		if retreat > 0.0 and landing.distance_to(target_position) < start_position.distance_to(target_position) + 12.0:
			continue
		if not _free_position(landing, actor):
			continue
		actor.pos = landing
		actor.prev_pos = landing
		actor.velocity = Vector2.ZERO
		actor.impulse = Vector2.ZERO
		actor["last_teleport_tick"] = tick
		if actor.get("class") == "wayfarer":
			actor["haste_until"] = tick + TICKS_PER_BEAT * 3
		var action := "blinks away from" if retreat > 0.0 else "blinks beside"
		_emit("teleport", "%s %s %s." % [actor.name, action, target.name], actor, target, tile_id, 0, start_position, landing)
		if _has_relic(actor, "wayfarers_pin") and actor.get("wayfarers_pin_loop", -1) != _loop_index():
			actor["wayfarers_pin_loop"] = _loop_index()
			_guard(actor, 6, "wayfarers_pin")
		return true
	return false


func _free_position(position: Vector2, actor: Dictionary) -> bool:
	for unit in units:
		if unit.hp > 0 and unit.id != actor.id and position.distance_to(unit.pos) < unit.radius + actor.radius + 5.0:
			return false
	return true


func _run_enemies() -> void:
	for enemy in units:
		if enemy.side != "enemy" or enemy.hp <= 0:
			continue
		if enemy.get("sprite") == "tempered_colossus" and not enemy.colossus_shattered:
			if tick > LOOP_TICKS and tick % LOOP_TICKS == 1:
				_begin_forge_sweep(enemy)
				continue
		elif enemy.get("sprite") == "crown_regent" and not enemy.crown_charge_interrupted and tick % LOOP_TICKS == TICKS_PER_BEAT + 1:
			_begin_relay_charge(enemy)
			continue
		elif enemy.get("sprite") in ["relay_captain", "relay_marshal"] and tick % LOOP_TICKS == TICKS_PER_BEAT + 1:
			_begin_relay_charge(enemy)
			continue
		elif enemy.get("sprite") == "wreckmaster" and tick % LOOP_TICKS == TICKS_PER_BEAT + 1:
			_begin_wreckmaster_harpoon(enemy)
			continue
		elif enemy.get("sprite") == "tidekeeper" and tick % LOOP_TICKS == TICKS_PER_BEAT + 1:
			_begin_tidekeeper_harpoons(enemy)
			continue
		elif enemy.get("sprite") == "drowned_admiral" and tick % LOOP_TICKS == TICKS_PER_BEAT + 1:
			_begin_admiral_undertow(enemy)
			continue
		if enemy.intent != "":
			if enemy.get("intent_attack_id") == TOLLKEEPER_REPAIR_CUE:
				var partner := _find_unit(enemy.intent)
				if partner.get("hp", 0) <= 0:
					_cancel_tollkeeper_repair(enemy, partner, "tollkeeper_repair_interrupted", "The repair fails when the Tollkeeper falls.")
					continue
				if not _in_repair_range(enemy, partner):
					_cancel_tollkeeper_repair(enemy, partner, "tollkeeper_repair_separated", "The repair link breaks when the drone and the Tollkeeper separate.")
					continue
			var winch_ally: String = enemy.get("dock_winch_ally", "")
			if winch_ally != "" and _find_unit(winch_ally).get("hp", 0) <= 0:
				_clear_winch_intent(enemy)
				enemy.next_attack = tick + TICKS_PER_BEAT
				continue
			if tick >= enemy.intent_tick:
				_resolve_intent(enemy)
			continue
		if tick < enemy.next_attack:
			continue
		if enemy.has("dock_winch_ally") and _begin_winch_pull(enemy):
			continue
		var rule := _attack_target_rule(enemy)
		var target := _select(enemy, rule)
		if target.is_empty():
			continue
		var position: Vector2 = enemy.pos
		var attack: Dictionary = enemy.get("attack", {})
		var pilot: Variant = PILOT_ENEMY_SCRIPTS.get(enemy.get("pilot_region", ""))
		if pilot != null:
			if pilot.begin(self, enemy, target, attack):
				continue
		elif attack.has("special") and _begin_variant_attack(enemy, target, attack):
			continue
		if enemy.has("repair_partner") and _find_unit(enemy.repair_partner).get("hp", 0) > 0:
			continue
		var reach: float = attack.get("reach", 290.0 if enemy.id == "scout" else 155.0)
		if position.distance_to(target.pos) > reach:
			continue
		var action_id: String = enemy.get("attack_id", enemy.id)
		if action_id == attack.get("special", ""):
			action_id += "_strike"
		var message := "%s winds up at %s." % [enemy.name, target.name]
		if enemy.get("sprite") == "prism_warden":
			message = _prism_mark(enemy, target)
		elif enemy.get("marshal_plated", false):
			action_id = "marshal_sweep"
			message = "The Marshal charges a sweep. Push or pull it, then follow up with your other hero."
			if enemy.has("marshal_plate_integrity"):
				enemy["pilot_ring_radius"] = attack.reach + MARSHAL_SWEEP_EXTRA_REACH
				message = "Gilded Sweep · %d damage inside the ring. Interrupt with your crew, block it with Guard, or move clear." % MARSHAL_MEDIUM_SWEEP_DAMAGE
		elif enemy.get("regent_sealed", false):
			action_id = "regent_sweep"
			message = "The Regent charges a sweep. Land a hit from each hero within 4 beats to break its seals."
		elif rule == "ranged_damage":
			message = "%s marks %s, the highest ranged damage dealer." % [enemy.name, target.name]
		elif rule == "lowest_hp":
			message = "%s rushes %s, the lowest-HP hero." % [enemy.name, target.name]
		_start_enemy_intent(enemy, target.id, tick + int(attack.get("windup", 24)), action_id)
		_emit("intent", message, enemy, target, "enemy_attack")


func _start_enemy_intent(enemy: Dictionary, target_id: String, end_tick: int, attack_id: String) -> void:
	enemy.intent = target_id
	enemy.intent_tick = end_tick
	enemy["intent_start_tick"] = tick
	enemy["intent_attack_id"] = attack_id


func _resolve_intent(enemy: Dictionary) -> void:
	var target := _find_unit(enemy.intent)
	var origin: Vector2 = enemy.pos
	var attack_id: String = enemy.get("intent_attack_id", enemy.get("special_intent", enemy.get("attack_id", enemy.id)))
	var attack: Dictionary = enemy.get("attack", {})
	if enemy.get("sprite") == "marshal" and not enemy.has("marshal_plate_integrity"):
		attack_id = "marshal_sweep" if enemy.get("marshal_plated", false) else "marshal"
	elif enemy.get("sprite") == "regent":
		attack_id = "regent_sweep" if enemy.get("regent_sealed", false) else "regent"
	var hit_point: Vector2 = target.get("pos", origin)
	var radius := _enemy_sweep_radius(enemy, attack)
	var locked_aim := enemy.has("pilot_aim_point")
	var cue_origin := origin
	if enemy.has("blast_center"):
		hit_point = enemy.blast_center
		radius = enemy.blast_radius
	elif locked_aim:
		cue_origin = enemy.get("refraction_origin", origin)
		hit_point = cue_origin.move_toward(enemy.pilot_aim_point, float(attack.reach))
	elif enemy.get("dock_winch_ally", "") != "":
		target = _find_unit(enemy.dock_winch_ally)
		hit_point = target.get("pos", origin)
	elif radius > 0.0:
		hit_point = origin
	var valid_target: bool = target.get("hp", 0) > 0 or radius > 0.0 or locked_aim

	var first_event := _events.size()
	_resolve_enemy_attack(enemy)
	var missed := false
	var contact_points: Array[Vector2] = []
	var impact_target := ""
	for index in range(first_event, _events.size()):
		var event: Dictionary = _events[index]
		if event.actor != enemy.id:
			continue
		if event.kind == "miss":
			missed = true
		elif event.kind == "hit" or event.kind == "heal" or event.kind == "pull":
			if impact_target.is_empty():
				impact_target = event.target
			var point: Vector2 = event.from if event.kind == "pull" else event.to
			if point not in contact_points:
				contact_points.append(point)
	if radius == 0.0 and (not locked_aim or attack_id == GlassPilotEnemies.HUNTER_SHOT) and not contact_points.is_empty():
		hit_point = contact_points[0]
	visual_cues.append({
		"kind": "enemy_cast", "tick": tick, "actor": enemy.id, "tile": attack_id, "attack": attack,
		"target": target.get("id", "") if impact_target.is_empty() else impact_target,
		"from": cue_origin, "to": hit_point, "arrival": enemy.pos, "radius": radius,
		"landed": (valid_target and not missed) or not contact_points.is_empty(), "contact_points": contact_points,
	})


func _enemy_sweep_radius(enemy: Dictionary, attack: Dictionary) -> float:
	if enemy.get("wreckmaster_phase", 0) >= 2:
		return enemy.wreckmaster_slam_radius
	if enemy.get("tidekeeper_phase", 0) >= 2:
		return enemy.tidekeeper_slam_radius
	if enemy.get("admiral_phase", 0) >= 2:
		return enemy.admiral_sweep_radius
	if enemy.get("relay_charge_active", false) and enemy.get("sprite") in ["relay_marshal", "crown_regent"]:
		return attack.reach + 125.0
	if enemy.get("colossus_stage", 0) > 0:
		return enemy.colossus_sweep_radius
	if enemy.get("marshal_plated", false) and not enemy.has("marshal_plate_integrity"):
		return attack.reach + MARSHAL_SWEEP_EXTRA_REACH
	if enemy.get("regent_sealed", false):
		return attack.reach + 70.0
	return enemy.get("pilot_ring_radius", 0.0)


func _resolve_enemy_attack(enemy: Dictionary) -> void:
	var intent: String = enemy.intent
	var attack: Dictionary = enemy.get("attack", {})
	enemy.intent = ""
	enemy.next_attack = tick + int(attack.get("cooldown", 116 if enemy.id == "scout" else 138))
	var special_intent: String = enemy.get("special_intent", "")
	if not special_intent.is_empty():
		enemy.erase("special_intent")
		var pilot: Variant = PILOT_ENEMY_SCRIPTS.get(enemy.get("pilot_region", ""))
		if pilot != null:
			pilot.resolve(self, enemy, _find_unit(intent), attack, special_intent)
		else:
			_resolve_variant_attack(enemy, _find_unit(intent), attack, special_intent)
		return
	if enemy.get("dock_winch_ally", "") != "":
		_resolve_winch_pull(enemy, intent)
		return
	if enemy.get("wreckmaster_phase", 0) > 0:
		_resolve_wreckmaster(enemy, intent)
		return
	if enemy.get("tidekeeper_phase", 0) > 0:
		_resolve_tidekeeper(enemy, intent, attack)
		return
	if enemy.get("admiral_phase", 0) > 0:
		_resolve_admiral(enemy, intent, attack)
		return
	if enemy.get("relay_charge_active", false):
		var marshal: bool = enemy.get("sprite") == "relay_marshal"
		enemy.relay_charge_active = false
		enemy.intent_tick = 0
		var marked := _find_unit(intent)
		if enemy.get("sprite") == "crown_regent":
			_review_boss_event("miss", "crown_regent_discharge", "Crown Charge released before the counter landed. Check whether two different heroes broke the live links and a third pushed the Regent before either link reformed.", enemy, marked)
			enemy.crown_breakers.clear()
			_emit("intent", "The Crown Regent releases Crown Charge.", enemy, marked, "crown_regent_discharge")
			_sweep(enemy, attack, 125.0, 11)
			return
		if marshal:
			var next_step := "Separate the shield before the charge ends." if enemy.relay_combo_stage == 1 else "Move the follow-up push earlier, and use a different hero if someone broke the link."
			_review_boss_event("miss", "relay_marshal_discharge", "Linked Charge released. " + next_step, enemy, marked)
			enemy.relay_combo_stage = 0
			enemy.relay_breaker = ""
			_emit("intent", "The Relay Marshal releases Linked Charge.", enemy, marked, "relay_marshal_discharge")
			_sweep(enemy, attack, 125.0, 14)
			return
		_emit("intent", "The Relay Captain releases its charged strike.", enemy, marked, "relay_discharge")
		if not marked.is_empty() and marked.hp > 0:
			var defender := _intercept_target(marked)
			_damage(enemy, defender, 32, "enemy_attack")
			if defender.hp > 0:
				_displace("push", enemy, defender, "enemy_attack", defender.pos - enemy.pos, 345.0)
		return
	if enemy.get("colossus_stage", 0) > 0:
		var next_step: String = ["", "Move a push or pull into the windup.", "Land a hit with a second hero after moving the Colossus.", "Move the remaining hero's hit into the windup."][enemy.colossus_stage]
		_review_boss_event("miss", "colossus_forge_sweep", "Forge Sweep released. " + next_step, enemy)
		_reset_colossus_sequence(enemy)
		_emit("intent", "The Tempered Colossus releases its Forge Sweep.", enemy, enemy, "colossus_forge_sweep")
		_sweep(enemy, attack, COLOSSUS_EXTRA_REACH, 8)
		return
	if enemy.get("sprite") == "prism_warden":
		_prism_beam(enemy, intent, attack)
		return
	if enemy.has("marshal_plate_integrity") and enemy.get("intent_attack_id") == "marshal_sweep":
		_resolve_medium_marshal_sweep(enemy, attack)
		return
	if enemy.get("marshal_plated", false) and not enemy.has("marshal_plate_integrity"):
		_sweep(enemy, attack, MARSHAL_SWEEP_EXTRA_REACH, 5)
		return
	if enemy.get("regent_sealed", false):
		_sweep(enemy, attack, 70.0, 2)
		return
	var position: Vector2 = enemy.pos
	var reach: float = attack.get("reach", 290.0 if enemy.id == "scout" else 155.0)
	for target in units:
		if target.id != intent or target.hp <= 0:
			continue
		if position.distance_to(target.pos) > reach:
			_emit("miss", "%s's windup misses %s." % [enemy.name, target.name], enemy, target, "enemy_attack")
			return
		var damage: int = attack.get("damage", 9 if enemy.id == "scout" else 21)
		if enemy.get("enraged", false):
			damage += 3
		var defender := _intercept_target(target)
		_damage(enemy, defender, damage, "enemy_attack")
		var force: float = attack.get("push", 430.0 if enemy.id == "clockwork" else 0.0)
		if force > 0.0 and defender.hp > 0:
			var offset: Vector2 = defender.pos - position
			_displace("push", enemy, defender, "enemy_attack", offset, force)
		return


func _begin_variant_attack(enemy: Dictionary, target: Dictionary, attack: Dictionary) -> bool:
	var position: Vector2 = enemy.pos
	var distance := position.distance_to(target.pos)
	var message: String
	var intent_tile: String
	match attack.special:
		"bombard":
			if distance > attack.reach:
				return false
			enemy["blast_center"] = target.pos
			enemy["blast_radius"] = attack.blast_radius
			message = "Mortar lands in two beats. Move out of the ring."
			intent_tile = "sapper_blast"
		"blink_strike":
			if distance > attack.reach:
				return false
			message = "Kiln Duelist readies a blink strike on %s." % target.name
			intent_tile = "duelist_blink"
		"repair":
			target = _repair_target(enemy, attack.repair_reach)
			if target.is_empty():
				return false
			intent_tile = attack.get("repair_cue", "mender_repair")
			message = "%s prepares to repair %s." % [enemy.name, target.name]
			if intent_tile == TOLLKEEPER_REPAIR_CUE:
				message = "The drone prepares a repair. Hit it or separate it from the Tollkeeper."
		"grapple":
			if distance <= attack.reach or distance > attack.grapple_reach:
				return false
			message = "Dock Corsair aims a boarding hook at %s." % target.name
			intent_tile = "corsair_hook"
	enemy["special_intent"] = attack.special
	_start_enemy_intent(enemy, target.id, tick + int(attack.windup), intent_tile)
	_emit("intent", message, enemy, target, intent_tile)
	return true


func _resolve_variant_attack(enemy: Dictionary, target: Dictionary, attack: Dictionary, move: String) -> void:
	if move == "bombard":
		var center: Vector2 = enemy.blast_center
		var radius: float = enemy.blast_radius
		enemy.erase("blast_center")
		enemy.erase("blast_radius")
		_emit("hazard_burst", "Mortar strikes.", enemy, {}, "sapper_blast", roundi(radius), center, center)
		for hero in _enemies_in_area(enemy, center, radius):
			_damage(enemy, hero, attack.damage, "sapper_blast")
		return
	if target.get("hp", 0) <= 0:
		return
	var position: Vector2 = enemy.pos
	var distance := position.distance_to(target.pos)
	match move:
		"blink_strike":
			if distance <= attack.reach and _teleport(enemy, target, "duelist_blink", 0.0):
				_damage(enemy, _intercept_target(target), attack.damage, "enemy_attack")
			else:
				_emit("miss", "Kiln Duelist misses its blink strike.", enemy, target, "duelist_blink")
		"repair":
			var cue: String = attack.get("repair_cue", "mender_repair")
			if distance > attack.repair_reach:
				_emit("miss", "%s's repair target is out of range." % enemy.name, enemy, target, cue)
				return
			var amount := mini(int(attack.get("repair_amount", 14)), int(target.max_hp - target.hp))
			if amount > 0:
				target.hp += amount
				var message := "%s repairs %d HP on %s." % [enemy.name, amount, target.name]
				if cue == TOLLKEEPER_REPAIR_CUE:
					message = "The repair drone restores %d HP to the Tollkeeper." % amount
				_emit("heal", message, enemy, target, cue, amount)
				if cue == TOLLKEEPER_REPAIR_CUE:
					_review_boss_event("miss", "tollkeeper_repair_completed", message, enemy, target, "heal")
		"grapple":
			if distance <= attack.grapple_reach:
				var travel := maxf(0.0, distance - 70.0)
				if travel > 0.0:
					var force := minf(700.0, sqrt(2.0 * IMPULSE_DECAY * travel))
					_displace("pull", enemy, target, "corsair_hook", position - target.pos, force)
				enemy.next_attack = tick + TICKS_PER_BEAT
			else:
				_emit("miss", "Dock Corsair's boarding hook falls short.", enemy, target, "corsair_hook")


func _repair_target(mender: Dictionary, reach: float) -> Dictionary:
	if mender.has("repair_partner"):
		var partner := _find_unit(mender.repair_partner)
		if partner.get("hp", 0) > 0 and partner.hp < partner.max_hp and _in_repair_range(mender, partner):
			return partner
		return {}
	var position: Vector2 = mender.pos
	var weakest := {}
	var lowest_health := 1.0
	for ally in units:
		if ally.side != mender.side or ally.id == mender.id or ally.hp <= 0 or position.distance_squared_to(ally.pos) > reach * reach:
			continue
		var health: float = float(ally.hp) / ally.max_hp
		if health < lowest_health:
			weakest = ally
			lowest_health = health
	return weakest


func _in_repair_range(drone: Dictionary, partner: Dictionary) -> bool:
	var position: Vector2 = drone.pos
	var reach: float = drone.attack.repair_reach
	return position.distance_squared_to(partner.pos) <= reach * reach


func _cancel_tollkeeper_repair(drone: Dictionary, partner: Dictionary, cue: String, message: String) -> void:
	drone.intent = ""
	drone.intent_tick = 0
	drone.erase("special_intent")
	drone.next_attack = tick + int(drone.attack.cooldown)
	_emit("interrupt", message, drone, partner, cue)


func _sweep(enemy: Dictionary, attack: Dictionary, extra_reach: float, bonus_damage: int) -> void:
	var affected := _enemies_in_area(enemy, enemy.pos, attack.reach + extra_reach)
	for target in affected:
		# A sweep hits each hero in the arc once. Bulwark still reduces their own hit.
		_damage(enemy, target, attack.damage + bonus_damage, "enemy_attack")
		if target.hp > 0:
			_displace("push", enemy, target, "enemy_attack", target.pos - enemy.pos, attack.push)
	if affected.is_empty():
		_emit("miss", "%s's sweep hits no one." % enemy.name, enemy, enemy, "enemy_attack")


func _resolve_medium_marshal_sweep(enemy: Dictionary, attack: Dictionary) -> void:
	var radius: float = enemy.get("pilot_ring_radius", attack.reach + MARSHAL_SWEEP_EXTRA_REACH)
	enemy.erase("pilot_ring_radius")
	var affected := _enemies_in_area(enemy, enemy.pos, radius)
	var hp_lost := 0
	for hero: Dictionary in affected:
		var hp_before: int = hero.hp
		_damage(enemy, hero, MARSHAL_MEDIUM_SWEEP_DAMAGE, "enemy_attack")
		if hero.hp < hp_before:
			hp_lost += hp_before - int(hero.hp)
			if hero.hp > 0:
				_displace("push", enemy, hero, "enemy_attack", hero.pos - enemy.pos, attack.push)
	if affected.is_empty():
		_emit("miss", "The heroes stay clear of Gilded Sweep.", enemy, enemy, "enemy_attack")
	if hp_lost > 0:
		var message := "Gilded Sweep costs the crew %d HP." % hp_lost
		if enemy.marshal_plated:
			message += " Fully guard or clear the ring to wear down the plating."
		_review_boss_event("miss", "marshal_sweep_hit", message, enemy)
		return
	var response := "The crew stays clear of Gilded Sweep." if affected.is_empty() else "Guard absorbs Gilded Sweep without HP loss."
	enemy.next_attack += TICKS_PER_BEAT
	var wear := mini(int(enemy.marshal_plate_integrity), MARSHAL_WEATHERED_SWEEP_WEAR)
	if wear > 0:
		response += " The plating loses %d integrity." % wear
	_emit("interrupt", response, enemy, enemy, "marshal_sweep_weathered", wear)
	_wear_marshal_plate(enemy, enemy, wear, "defense")


func _begin_winch_pull(enemy: Dictionary) -> bool:
	var target := _select(enemy, "nearest")
	if target.is_empty():
		return false
	var origin: Vector2 = enemy.pos
	for ally in units:
		if ally.hp <= 0 or not ally.id.begins_with("dock_bruiser") or origin.distance_squared_to(ally.pos) > 300.0 * 300.0:
			continue
		enemy.dock_winch_ally = ally.id
		_start_enemy_intent(enemy, target.id, tick + DOCK_WINCH_TICKS, "dock_winch_windup")
		_emit("intent", "Winch Pull in 2 beats. The Operator is drawing the Bruiser toward %s." % target.name,
			enemy, target, "dock_winch_windup")
		return true
	return false


func _resolve_winch_pull(enemy: Dictionary, intent: String) -> void:
	var ally := _find_unit(enemy.dock_winch_ally)
	_clear_winch_intent(enemy)
	var target := _find_unit(intent)
	if ally.is_empty() or ally.hp <= 0 or target.is_empty() or target.hp <= 0:
		return
	var offset: Vector2 = target.pos - ally.pos
	var clearance: float = ally.radius + target.radius + 24.0
	if offset.length() <= clearance:
		return
	_emit("intent", "The Winch Operator pulls the Bruiser toward %s." % target.name, enemy, ally, "dock_winch_pull")
	var force := minf(810.0, sqrt(2.0 * IMPULSE_DECAY * (offset.length() - clearance)))
	_displace("pull", enemy, ally, "dock_winch", offset, force)


func _clear_winch_intent(enemy: Dictionary) -> void:
	enemy.dock_winch_ally = ""
	enemy.intent = ""
	enemy.intent_tick = 0


func _begin_wreckmaster_harpoon(enemy: Dictionary) -> void:
	var target := _select(enemy, "nearest")
	if target.is_empty():
		return
	enemy.wreckmaster_phase = 1
	_start_enemy_intent(enemy, target.id, tick + WRECKMASTER_HARPOON_TICKS, "wreckmaster_harpoon")
	_emit("intent", "Harpoon at the end of beat 3. Expect a close Deck Slam next.", enemy, target, "wreckmaster_harpoon")


func _resolve_wreckmaster(enemy: Dictionary, intent: String) -> void:
	var target := _find_unit(intent)
	if enemy.wreckmaster_phase == 1:
		if not target.is_empty() and target.hp > 0:
			var offset: Vector2 = enemy.pos - target.pos
			var travel := maxf(0.0, offset.length() - 73.0)
			if travel > 0.0:
				_emit("intent", "The Wreckmaster harpoons %s." % target.name, enemy, target, "wreckmaster_pull")
				var force := minf(950.0, sqrt(2.0 * IMPULSE_DECAY * travel))
				_displace("pull", enemy, target, "wreckmaster_harpoon", offset, force)
		enemy.wreckmaster_phase = 2
		_start_enemy_intent(enemy, intent, tick + WRECKMASTER_SLAM_TICKS, "wreckmaster_slam_windup")
		_emit("intent", "Deck Slam at the end of beat 6. Push the Wreckmaster away or brace.", enemy, target, "wreckmaster_slam_windup")
		return
	enemy.wreckmaster_phase = 0
	enemy.intent_tick = 0
	_emit("intent", "The Wreckmaster slams the deck.", enemy, enemy, "wreckmaster_slam")
	var affected := _enemies_in_area(enemy, enemy.pos, enemy.wreckmaster_slam_radius)
	if affected.is_empty():
		_emit("miss", "Deck Slam misses. No hero is close enough.", enemy, target, "wreckmaster_slam_miss")
	else:
		_review_boss_event("miss", "wreckmaster_slam", "Deck Slam caught %s. Schedule a push between the harpoon and the end of beat 6, or add Guard before impact." % affected[0].name, enemy, affected[0])
	for hero in affected:
		_damage(enemy, hero, 15, "enemy_attack")


func _begin_tidekeeper_harpoons(enemy: Dictionary) -> void:
	var target := _select(enemy, "nearest")
	if target.is_empty():
		return
	enemy.tidekeeper_targets.clear()
	for unit in units:
		if unit.side == "hero" and unit.hp > 0:
			enemy.tidekeeper_targets.append(unit.id)
	enemy.tidekeeper_phase = 1
	_start_enemy_intent(enemy, target.id, tick + WRECKMASTER_HARPOON_TICKS, "tidekeeper_harpoon")
	_emit("intent", "Twin Harpoons pull the party in at the end of beat 3.", enemy, target, "tidekeeper_harpoon")


func _resolve_tidekeeper(enemy: Dictionary, intent: String, attack: Dictionary) -> void:
	if enemy.tidekeeper_phase == 1:
		for target_id: String in enemy.tidekeeper_targets:
			var hero := _find_unit(target_id)
			if hero.hp <= 0:
				continue
			var offset: Vector2 = enemy.pos - hero.pos
			var travel := maxf(0.0, offset.length() - 80.0)
			if travel > 0.0:
				_emit("intent", "Twin Harpoons reel in %s." % hero.name, enemy, hero, "tidekeeper_pull")
				var force := minf(930.0, sqrt(2.0 * IMPULSE_DECAY * travel))
				_displace("pull", enemy, hero, "tidekeeper_harpoon", offset, force)
		enemy.tidekeeper_phase = 2
		_start_enemy_intent(enemy, intent, tick + TIDEKEEPER_SLAM_BEATS * TICKS_PER_BEAT, "tidekeeper_slam_windup")
		_emit("intent", "Breakwater Slam in %d beats. Push the Tidekeeper off its anchor." % TIDEKEEPER_SLAM_BEATS,
			enemy, enemy, "tidekeeper_slam_windup")
		return
	var affected := _enemies_in_area(enemy, enemy.pos, enemy.tidekeeper_slam_radius)
	if affected.is_empty():
		_review_boss_event("success", "tidekeeper_slam_dodged", "Breakwater Slam released, but the whole party was outside its range.", enemy)
	else:
		var next_step := "Push the Tidekeeper after the harpoons land." if enemy.tidekeeper_phase == 2 else "Follow the first push with a push or pull from the other hero."
		_review_boss_event("miss", "tidekeeper_slam", "Breakwater Slam hit %d. %s" % [affected.size(), next_step], enemy)
	_clear_tidekeeper_intent(enemy)
	_emit("intent", "The Tidekeeper releases Breakwater Slam.", enemy, enemy, "tidekeeper_slam", affected.size())
	for hero in affected:
		_damage(enemy, hero, attack.damage + 7, "enemy_attack")
		if hero.hp > 0:
			_displace("push", enemy, hero, "enemy_attack", hero.pos - enemy.pos, attack.push)


func _displace_tidekeeper(actor: Dictionary, enemy: Dictionary, kind: String) -> void:
	if enemy.tidekeeper_phase == 2:
		if kind == "push":
			enemy.tidekeeper_phase = 3
			enemy.tidekeeper_breaker = actor.id
			_emit("interrupt", "%s knocks the Tidekeeper off its anchor. Follow with a push or pull." % actor.name,
				actor, enemy, "tidekeeper_unanchored")
		return
	var different_hero: bool = enemy.tidekeeper_breaker != actor.id
	if not different_hero:
		for unit in units:
			if unit.side == "hero" and unit.hp > 0 and unit.id != actor.id:
				return
	_clear_tidekeeper_intent(enemy)
	enemy.next_attack = tick + TICKS_PER_BEAT * 3
	_emit("interrupt", "%s cancels Breakwater Slam." % actor.name, actor, enemy, "tidekeeper_interrupted", int(different_hero))


func _clear_tidekeeper_intent(enemy: Dictionary) -> void:
	enemy.tidekeeper_phase = 0
	enemy.tidekeeper_targets.clear()
	enemy.tidekeeper_breaker = ""
	enemy.intent = ""
	enemy.intent_tick = 0


func _begin_admiral_undertow(enemy: Dictionary) -> void:
	var target := _select(enemy, "nearest")
	if target.is_empty():
		return
	for unit in units:
		if unit.side == "hero" and unit.hp > 0:
			enemy.admiral_targets.append(unit.id)
	enemy.admiral_phase = 1
	_start_enemy_intent(enemy, target.id, tick + WRECKMASTER_HARPOON_TICKS, "admiral_undertow")
	_emit("intent", "Undertow pulls the party in at the end of beat 3.", enemy, target, "admiral_undertow")


func _resolve_admiral(enemy: Dictionary, intent: String, attack: Dictionary) -> void:
	if enemy.admiral_phase == 1:
		for target_id: String in enemy.admiral_targets:
			var hero := _find_unit(target_id)
			if hero.hp <= 0:
				continue
			var offset: Vector2 = enemy.pos - hero.pos
			var travel := maxf(0.0, offset.length() - 84.0)
			if travel > 0.0:
				_emit("intent", "The Undertow draws %s in." % hero.name, enemy, hero, "admiral_pull")
				var force := minf(965.0, sqrt(2.0 * IMPULSE_DECAY * travel))
				_displace("pull", enemy, hero, "admiral_undertow", offset, force)
		enemy.admiral_phase = 2
		_start_enemy_intent(enemy, intent, tick + ADMIRAL_SWEEP_BEATS * TICKS_PER_BEAT, "admiral_sweep_windup")
		_emit("intent", "Undertow Sweep in %d beats. Push the Admiral off its anchor." % ADMIRAL_SWEEP_BEATS,
			enemy, enemy, "admiral_sweep_windup")
		return
	var affected := _enemies_in_area(enemy, enemy.pos, enemy.admiral_sweep_radius)
	if affected.is_empty():
		_review_boss_event("success", "admiral_sweep_dodged", "Undertow Sweep released, but the whole party was outside its range.", enemy)
	else:
		var next_step: String = ["", "", "Push to break the anchor.", "Pull with a different hero to reverse the undertow.", "Push with the remaining hero before the sweep releases."][enemy.admiral_phase]
		_review_boss_event("miss", "admiral_sweep", "Undertow Sweep hit %d. %s" % [affected.size(), next_step], enemy)
	_clear_admiral_intent(enemy)
	_emit("intent", "The Drowned Admiral releases Undertow Sweep.", enemy, enemy, "admiral_sweep", affected.size())
	for hero in affected:
		_damage(enemy, hero, attack.damage + 7, "enemy_attack")
		if hero.hp > 0:
			_displace("push", enemy, hero, "enemy_attack", hero.pos - enemy.pos, attack.push)


func _displace_admiral(actor: Dictionary, enemy: Dictionary, kind: String) -> void:
	var living: Array[String] = []
	for unit in units:
		if unit.side == "hero" and unit.hp > 0:
			living.append(unit.id)
	match int(enemy.admiral_phase):
		2:
			if kind != "push":
				return
			if living.size() == 1:
				_cancel_admiral_sweep(actor, enemy, false)
				return
			enemy.admiral_phase = 3
			enemy.admiral_breaker = actor.id
			var follow_up := "Another hero must Pull." if living.size() >= 3 else "The other hero can push or pull to cancel."
			_emit("interrupt", "%s breaks the anchor. %s" % [actor.name, follow_up], actor, enemy, "admiral_unanchored")
		3:
			if actor.id == enemy.admiral_breaker and living.size() > 1:
				return
			if living.size() < 3:
				_cancel_admiral_sweep(actor, enemy, false)
				return
			if kind != "pull":
				return
			enemy.admiral_phase = 4
			enemy.admiral_reverser = actor.id
			_emit("interrupt", "%s reverses the Undertow. The third hero must push." % actor.name,
				actor, enemy, "admiral_reversed")
		4:
			if kind != "push":
				return
			var unused := living.filter(func(id: String) -> bool: return id != enemy.admiral_breaker and id != enemy.admiral_reverser)
			if unused.is_empty() or actor.id in unused:
				_cancel_admiral_sweep(actor, enemy, living.size() == 3)


func _cancel_admiral_sweep(actor: Dictionary, enemy: Dictionary, full_counter: bool) -> void:
	_clear_admiral_intent(enemy)
	enemy.next_attack = tick + TICKS_PER_BEAT * 3
	_emit("interrupt", "%s cancels Undertow Sweep." % actor.name, actor, enemy, "admiral_interrupted", int(full_counter))


func _clear_admiral_intent(enemy: Dictionary) -> void:
	enemy.admiral_phase = 0
	enemy.admiral_targets.clear()
	enemy.admiral_breaker = ""
	enemy.admiral_reverser = ""
	enemy.intent = ""
	enemy.intent_tick = 0


func _begin_relay_charge(enemy: Dictionary) -> void:
	var target := _select(enemy, "nearest")
	if target.is_empty():
		return
	var marshal: bool = enemy.get("sprite") == "relay_marshal"
	var crown: bool = enemy.get("sprite") == "crown_regent"
	var beats := CROWN_CHARGE_BEATS if crown else (RELAY_MARSHAL_CHARGE_BEATS if marshal else RELAY_CHARGE_BEATS)
	var action_id := "crown_regent_charge" if crown else ("relay_marshal_charge" if marshal else "relay_charge")
	_start_enemy_intent(enemy, target.id, tick + TICKS_PER_BEAT * beats - 1, action_id)
	enemy.relay_charge_active = true
	if crown:
		enemy.crown_breakers.clear()
		_emit("intent", "Crown Charge in 8 beats. Separate each Guard with a different hero, then Bash the Regent.",
			enemy, target, "crown_regent_charge")
		return
	if marshal:
		enemy.relay_breaker = ""
		enemy.relay_combo_stage = 3 if enemy.get("relay_shield_source", "") == "" else 1
		var message := "Linked Charge in 8 beats. Separate the link, then Bash the Marshal with your other hero."
		if enemy.relay_combo_stage == 3:
			message = "Linked Charge in 8 beats. The Marshal is unshielded. Bash it to interrupt."
		_emit("intent", message, enemy, target, "relay_marshal_charge")
		return
	_emit("intent", "Relay Charge in 6 beats. Interrupt it with Bash or another push or pull.",
		enemy, target, "relay_charge")


func _interrupt_relay_charge(actor: Dictionary, enemy: Dictionary, kind: String) -> void:
	var marshal: bool = enemy.get("sprite") == "relay_marshal"
	if enemy.get("sprite") == "crown_regent":
		if kind != "push" or not enemy.relay_shield_sources.is_empty():
			return
		var contributors := {}
		var live_links := 0
		for guard_id: String in enemy.crown_guard_ids:
			var guard := _find_unit(guard_id)
			if guard.is_empty() or guard.hp <= 0:
				continue
			live_links += 1
			var breaker: String = enemy.crown_breakers.get(guard_id, "")
			if breaker.is_empty() or breaker == actor.id or contributors.has(breaker):
				return
			contributors[breaker] = true
		enemy.crown_charge_interrupted = true
		enemy.crown_breakers.clear()
		_emit("interrupt", "%s interrupts Crown Charge." % actor.name, actor, enemy,
			"crown_regent_interrupted", int(live_links == 2))
	elif marshal:
		if kind != "push" or enemy.relay_combo_stage == 1 or enemy.relay_breaker == actor.id:
			return
		var linked_combo: bool = enemy.relay_combo_stage == 2
		enemy.relay_combo_stage = 0
		enemy.relay_breaker = ""
		_emit("interrupt", "%s interrupts Linked Charge." % actor.name, actor, enemy,
			"relay_marshal_interrupted", int(linked_combo))
	else:
		_emit("interrupt", "%s interrupts the Relay Captain's charge." % actor.name, actor, enemy, "relay_interrupted")
	enemy.relay_charge_active = false
	enemy.intent = ""
	enemy.intent_tick = 0
	enemy.next_attack = tick + TICKS_PER_BEAT * 5


func _break_displaced_relay_link(target: Dictionary, endpoint: Vector2, breaker: Dictionary) -> void:
	if target.has("relay_shield_sources"):
		for guard_id: String in target.relay_shield_sources.duplicate():
			var linked := _find_unit(guard_id)
			if not linked.is_empty() and endpoint.distance_squared_to(linked.pos) > RELAY_BREAK_REACH * RELAY_BREAK_REACH:
				_break_relay_link(linked, breaker)
		return
	var guard := target if target.has("relay_link_target") else _find_unit(target.get("relay_shield_source", ""))
	if guard.is_empty() or guard.relay_link_target == "":
		return
	var ally := _find_unit(guard.relay_link_target)
	if ally.is_empty():
		return
	var stationary: Vector2 = ally.pos if target.id == guard.id else guard.pos
	if endpoint.distance_squared_to(stationary) > RELAY_BREAK_REACH * RELAY_BREAK_REACH:
		_break_relay_link(guard, breaker)


func _begin_forge_sweep(enemy: Dictionary) -> void:
	var target := _select(enemy, _attack_target_rule(enemy))
	if target.is_empty():
		return
	_start_enemy_intent(enemy, target.id, tick + TICKS_PER_BEAT * COLOSSUS_SWEEP_BEATS - 1, "colossus_forging")
	enemy.colossus_stage = 1
	enemy.colossus_window_until = enemy.intent_tick
	_emit("intent", "Forge Sweep in 9 beats. Push or pull the Colossus, then land hits from two different allies.",
		enemy, target, "colossus_forging")


func _reset_colossus_sequence(enemy: Dictionary) -> void:
	enemy.colossus_stage = 0
	enemy.colossus_window_until = 0
	enemy.colossus_first = ""
	enemy.colossus_second = ""


func _colossus_damage(actor: Dictionary, enemy: Dictionary, amount: int) -> int:
	match int(enemy.colossus_stage):
		2:
			if actor.id != enemy.colossus_first:
				enemy.colossus_stage = 3
				enemy.colossus_second = actor.id
				_emit("interrupt", "%s cracks the Colossus's guard. Hit it with the remaining hero." % actor.name,
					actor, enemy, "colossus_cracked")
		3:
			if actor.id != enemy.colossus_first and actor.id != enemy.colossus_second:
				_reset_colossus_sequence(enemy)
				enemy.colossus_shattered = true
				enemy.guard = 0
				enemy.intent = ""
				enemy.next_attack = tick + TICKS_PER_BEAT * 5
				_emit("interrupt", "%s shatters the guard. The Colossus staggers and its Forge Sweep is canceled." % actor.name,
					actor, enemy, "colossus_shattered")
				return amount + 28
	return maxi(1, roundi(amount * 0.60))


func _prism_mark(enemy: Dictionary, ranged_leader: Dictionary) -> String:
	var weak := _select(enemy, "lowest_hp")
	enemy["prism_secondary"] = "" if weak.is_empty() or weak.id == ranged_leader.id else weak.id
	if enemy.prism_warded:
		if enemy.prism_secondary != "":
			return "The Prism Warden marks %s and %s. Shatter its ward to stop the beams." % [ranged_leader.name, weak.name]
		return "The Prism Warden focuses both beams on %s. Shatter its ward to stop them." % ranged_leader.name
	if enemy.prism_secondary != "":
		return "The Prism Warden marks ranged leader %s and low-health %s." % [ranged_leader.name, weak.name]
	return "The Prism Warden focuses both beams on %s." % ranged_leader.name


func _prism_beam(enemy: Dictionary, primary: String, attack: Dictionary) -> void:
	var secondary: String = enemy.get("prism_secondary", "")
	enemy["prism_secondary"] = ""
	var primary_damage: int = attack.damage
	if enemy.prism_warded:
		primary_damage += 5
	# Both lenses converge when the same hero is both the ranged leader and the weakest.
	if secondary.is_empty():
		primary_damage += 5
	_prism_hit(enemy, primary, primary_damage, attack)
	if not secondary.is_empty():
		_prism_hit(enemy, secondary, maxi(1, roundi(primary_damage * 0.73)), attack)


func _prism_hit(enemy: Dictionary, target_id: String, damage: int, attack: Dictionary) -> void:
	var target := _find_unit(target_id)
	if target.is_empty() or target.hp <= 0:
		return
	var position: Vector2 = enemy.pos
	if position.distance_to(target.pos) > attack.reach + 70.0:
		_emit("miss", "The prism beam misses %s." % target.name, enemy, target, "enemy_attack")
		return
	var defender := _intercept_target(target)
	_damage(enemy, defender, damage, "enemy_attack")
	if defender.hp > 0:
		_displace("push", enemy, defender, "enemy_attack", defender.pos - position, attack.push)


func _intercept_target(target: Dictionary) -> Dictionary:
	for ally in units:
		if ally.side != target.side or ally.id == target.id or ally.hp <= 0 or ally.get("class") != "bulwark":
			continue
		if ally.get("bulwark_loop", -1) == _loop_index():
			continue
		VanguardSpecialties.reinforce_intercept(self, ally)
		_emit("intercept", "%s intercepts the attack on %s." % [ally.name, target.name], ally, target, "bulwark")
		return ally
	return target


func _guard(recipient: Dictionary, amount: int, tile_id: String, source: Dictionary = {}, echo := true) -> void:
	var gain := mini(amount, MAX_GUARD - recipient.guard)
	var actor := recipient if source.is_empty() else source
	recipient.guard += gain
	if amount > gain and tile_id == _activation.get("tile") and actor.id == _activation.get("actor") \
			and _has_relic(actor, "overflow_chalice"):
		_heal_guard_overflow(actor, tile_id, amount - gain)
	if gain > 0:
		_emit("guard", "%s gains %d guard." % [recipient.name, gain], actor, recipient, tile_id, gain)
		if echo and actor.get("class") == "cantor":
			var weakest := recipient
			for ally in units:
				if ally.side == actor.side and ally.hp > 0 and ally.hp < weakest.hp:
					weakest = ally
			_guard(weakest, 3, "cantor", actor, false)


func _heal_guard_overflow(actor: Dictionary, tile_id: String, excess: int) -> void:
	if _overflow_healed >= OVERFLOW_HEAL_CAP:
		return
	var recipient := {}
	var missing := 0
	for ally: Dictionary in units:
		if ally.side == actor.side and ally.hp > 0 and ally.max_hp - ally.hp > missing:
			recipient = ally
			missing = ally.max_hp - ally.hp
	if recipient.is_empty():
		return
	var healed := mini(mini(excess, missing), OVERFLOW_HEAL_CAP - _overflow_healed)
	_overflow_healed += healed
	recipient.hp += healed
	var effect := "Overflow restored %d HP to %s" % [healed, recipient.name]
	_emit("heal", effect + ".", actor, recipient, "overflow_chalice", healed, Vector2.INF, Vector2.INF,
		{"source_tile": tile_id})
	_relic_proc("overflow_chalice", "Overflow Chalice", healed, actor, recipient, TILES[tile_id].label, _activation.beat, effect)


func _apply_tollkeeper_repair_kit(hero: Dictionary) -> void:
	if not _has_relic(hero, "tollkeeper_repair_kit") or int(hero.get("tollkeeper_repair_kit_loop", -1)) == _loop_index():
		return
	hero["tollkeeper_repair_kit_loop"] = _loop_index()
	var healed := mini(TOLLKEEPER_REPAIR_KIT_HP, int(hero.max_hp) - int(hero.hp))
	if healed <= 0:
		return
	hero.hp += healed
	var effect := "Restored %d HP to %s after a full block" % [healed, hero.name]
	_emit("heal", effect, hero, hero, "tollkeeper_repair_kit", healed)
	_relic_proc("tollkeeper_repair_kit", "Tollkeeper's Repair Kit", healed, hero, hero, "A fully blocked enemy hit", 0, effect)


func _roll_critical(actor: Dictionary, target: Dictionary, tile_id: String) -> bool:
	if _activation.get("actor") != actor.id or _activation.get("tile") != tile_id \
			or _activation.get("target") != target.id or actor.side != "hero" or target.side != "enemy" \
			or _activation.has("critical"):
		return false
	var chance := critical_chance(actor.get("class", ""), tile_id, _attack_origin(actor).distance_to(target.pos))
	if chance <= 0.0:
		return false
	if not _critical_streams.has(actor.lane):
		var stream := RandomNumberGenerator.new()
		stream.seed = _critical_seed ^ CRITICAL_RNG_SALT ^ (actor.lane * 7919)
		_critical_streams[actor.lane] = stream
	var rng: RandomNumberGenerator = _critical_streams[actor.lane]
	var critical := rng.randf() < chance
	_activation["critical"] = critical
	return critical


func _apply_starshot_critical_step(actor: Dictionary, tile_id: String) -> void:
	if actor.get("class") != "starshot" or not actor.get("ranged_standoff", false) \
			or not _activation.get("critical_wounded", false) or not is_ranged_tile(tile_id) \
			or _activation.has("attack_origin") or TILES[tile_id].has("retreat") or is_blink_tile(tile_id) \
			or actor.get("critical_step_loop", -1) == _loop_index():
		return
	var target := _find_unit(_activation.target)
	if target.is_empty() or target.hp <= 0:
		return
	var gap: float = actor.pos.distance_to(target.pos)
	var distance := minf(STARSHOT_CRITICAL_STEP, actor.ranged_reach - gap - 24.0)
	if distance >= 12.0 and _retreat_from(actor, target, tile_id, distance):
		actor["critical_step_loop"] = _loop_index()


func _damage(actor: Dictionary, target: Dictionary, amount: int, tile_id: String, extra_hit := "",
		source_details: Dictionary = {}) -> void:
	if target.hp <= 0:
		return
	var critical := false
	if TILES.has(tile_id):
		if extra_hit.is_empty():
			amount += _mastery_hit(actor, target, tile_id)
			amount = _class_attack_damage(actor, target, tile_id, amount)
			if not _activation.is_empty() and actor.side == "hero" and target.side == "enemy":
				if _activation.actor == actor.id and _activation.target == target.id and _activation.tile == tile_id:
					ArtificeSpecialties.resolve_ally_echo(self, actor, target)
				amount += _consume_arsenal_mark(actor, target, tile_id)
				amount += _consume_cantor_mark(actor, target, tile_id)
				amount += _consume_ranged_followup(actor, target, tile_id)
				amount += _lance_hit_bonus(actor, target, tile_id)
				amount += _consume_rune_charge(actor, target, tile_id)
				amount += _needle_attack_bonus(actor, target, tile_id)
				amount += _relic_attack_bonus(actor, target)
				if tile_id == _activation.tile and actor.id == _activation.actor and amount > 0:
					amount += _timeline_relic_bonus(actor, target, tile_id)
				_apply_barrage_rack(actor, target, tile_id)
			critical = amount > 0 and _roll_critical(actor, target, tile_id)
			if critical:
				amount = roundi(amount * CRITICAL_DAMAGE_MULTIPLIER)
		if target.get("marshal_plated", false) and actor.side == "hero":
			amount = _marshal_damage(actor, target, amount, extra_hit.is_empty())
		elif target.get("prism_warded", false) and actor.side == "hero":
			amount = _prism_damage(actor, target, amount)
		elif target.get("regent_sealed", false) and actor.side == "hero":
			amount = _regent_damage(actor, target, amount)
		elif target.get("colossus_stage", 0) > 0 and actor.side == "hero":
			amount = _colossus_damage(actor, target, amount)
		if target.get("relay_shield_source", "") != "":
			var prevented := mini(amount - 1, roundi(amount * 0.45))
			if prevented > 0:
				amount -= prevented
				_emit("guard", "%s's relay shield blocks %d damage." % [target.name, prevented],
					_find_unit(target.relay_shield_source), target, "relay_absorb", prevented)
		if target.has("relay_shield_sources") and not target.relay_shield_sources.is_empty():
			var prevented := mini(amount - 1, roundi(amount * 0.30 * target.relay_shield_sources.size()))
			if prevented > 0:
				amount -= prevented
				_emit("guard", "The Crown shields block %d damage." % prevented,
					_find_unit(target.relay_shield_sources[0]), target, "relay_absorb", prevented)
	if amount > 0 and actor.side == "enemy" and target.has("crown_spotter_until"):
		amount += CrownVarietyEnemies.consume_spotter_mark(self, actor, target)
	if actor.side == "hero" and target.has("crown_oathbrace_until"):
		amount -= CrownVarietyEnemies.block_oathbreaker_hit(self, actor, target, amount)
	var enemy_strike: bool = tile_id == "enemy_attack" or actor.has("pilot_region")
	if enemy_strike and target.get("class") == "bulwark" and target.get("bulwark_loop", -1) != _loop_index():
		target["bulwark_loop"] = _loop_index()
		amount = maxi(0, amount - 6)
	var blocked := mini(amount, target.guard)
	target.guard -= blocked
	if blocked > 0 and actor.side == "enemy" and target.side == "hero":
		target["last_guard_block_tick"] = tick
		if _has_relic(target, "bridgeplate") and int(target.get("bridgeplate_used_loop", -1)) != _loop_index():
			target["bridgeplate_ready_loop"] = _loop_index()
	var dealt := mini(amount - blocked, target.hp)
	target.hp -= dealt
	var action: String = TILES[tile_id].label if TILES.has(tile_id) else "Strike"
	if not extra_hit.is_empty():
		action = extra_hit
	elif tile_id == "cinder_mage":
		action = "Burn"
	elif tile_id == "breaker":
		action = "Collision"
	elif tile_id == "sapper_blast":
		action = "Mortar"
	var blocked_text := " (%d blocked)" % blocked if blocked > 0 else ""
	var hit_verb := "critically hits" if critical else "hits"
	var hit_message := "%s: %s %s %s for %d%s." % [actor.name, action, hit_verb, target.name, dealt, blocked_text]
	var impact_details := source_details.duplicate()
	impact_details["blocked"] = blocked
	impact_details["critical"] = critical
	_emit("hit", hit_message, actor, target, tile_id, dealt, _attack_origin(actor), Vector2.INF, impact_details)
	if critical:
		_activation["critical_wounded"] = dealt > 0
		_activation.get_or_add("effect_details", []).append("Critical hit.")
	if blocked > 0 and dealt == 0 and actor.side == "enemy" and target.side == "hero":
		_apply_tollkeeper_repair_kit(target)
	if dealt > 0 and target.hp > 0 and actor.side == "hero" and not str(target.intent).is_empty() \
			and target.get("intent_attack_id") == TOLLKEEPER_REPAIR_CUE:
		_cancel_tollkeeper_repair(target, _find_unit(target.intent), "tollkeeper_repair_interrupted", "A hit interrupts the drone's repair.")
	if extra_hit.is_empty() and dealt > 0 and target.hp > 0 and actor.side == "hero" \
			and _activation.get("tile") == tile_id and _activation.get("actor") == actor.id:
		var pilot: Variant = PILOT_ENEMY_SCRIPTS.get(target.get("pilot_region", ""))
		if pilot != null:
			pilot.on_tile_hit(self, actor, target, dealt, tile_id, _activation.order)
	if actor.side == "enemy" and target.side == "hero" and target.has("bastion_ward"):
		_release_bastion_ward(target, blocked)
	if target.hp == 0:
		if extra_hit.is_empty() and not _activation.is_empty() and actor.side == "hero" and target.side == "enemy":
			_prime_duel_followup(actor, target, tile_id)
		target.velocity = Vector2.ZERO
		target.impulse = Vector2.ZERO
		target.intent = ""
		if target.get("relay_charge_active", false):
			target.relay_charge_active = false
			target.intent_tick = 0
			if target.has("relay_combo_stage"):
				target.relay_combo_stage = 0
				target.relay_breaker = ""
		if target.has("dock_winch_ally"):
			target.dock_winch_ally = ""
			target.intent_tick = 0
		if target.has("wreckmaster_phase"):
			target.wreckmaster_phase = 0
			target.intent_tick = 0
		if target.has("tidekeeper_phase"):
			_clear_tidekeeper_intent(target)
		if target.has("admiral_phase"):
			_clear_admiral_intent(target)
		var relay := target if target.has("relay_link_target") else _find_unit(target.get("relay_shield_source", ""))
		if not relay.is_empty() and relay.relay_link_target != "":
			_break_relay_link(relay)
		if target.has("relay_shield_sources"):
			for guard_id: String in target.relay_shield_sources.duplicate():
				_break_relay_link(_find_unit(guard_id))
		_emit("defeat_unit", "%s falls." % target.name, actor, target, tile_id, 0,
			Vector2.INF, Vector2.INF, source_details)
		if target.get("attack", {}).get("twin", false):
			_rally_twin(target)
	elif target.name == "The Tollkeeper" and target.hp * 2 <= target.max_hp and not target.get("enraged", false):
		target["enraged"] = true
		target.next_attack = mini(target.next_attack, tick + 20)
		_guard(target, 11, "tollkeeper_rallies")
		_emit("intent", "The Tollkeeper rallies. Its strikes now hit harder.", target, actor, "enemy_attack")
		_review_boss_event("progress", "tollkeeper_rallies", "The Tollkeeper gained Guard and its strikes now hit harder. Time a push to open space or add Guard before its next strike.", target, actor)
	elif target.get("sprite") == "marshal" and target.hp * 5 <= target.max_hp * 3 and not target.get("marshal_raised", false):
		target["marshal_raised"] = true
		target.marshal_plated = true
		_guard(target, 18, "marshal_plate")
		var message := "The Marshal raises its plating. Push or pull it, then strike with your other hero."
		if target.has("marshal_plate_integrity"):
			target.marshal_plate_integrity = target.marshal_plate_max_integrity
			message = "The Marshal raises its plating. Team interrupts shatter it. Hits and sweeps without HP loss wear it down."
		_emit("intent", message, target, actor, "marshal_plate")
	elif target.get("sprite") == "prism_warden" and target.hp * 5 <= target.max_hp * 3 and not target.get("prism_raised", false):
		target["prism_raised"] = true
		target.prism_warded = true
		_guard(target, 18, "prism_ward")
		_emit("intent", "The Prism Warden raises its ward. Move it with one hero, then hit with the other.", target, actor, "prism_ward")
	elif target.get("sprite") == "regent" and target.hp * 5 <= target.max_hp * 3 and not target.get("regent_raised", false):
		target["regent_raised"] = true
		target.regent_sealed = true
		target.regent_seals_left = 3
		target["regent_contributors"] = []
		_guard(target, 22, "regent_seals")
		_emit("intent", "The Regent raises three seals. Land a hit from each hero within 4 beats to break them.", target, actor, "regent_seals")


func _prime_bastion_ward(actor: Dictionary, tile_id: String, tile: Dictionary) -> void:
	var threshold: int = tile.bastion_block_threshold
	actor["bastion_ward"] = {
		"tile": tile_id, "threshold": threshold, "guard": tile.bastion_party_guard,
		"until": tick + int(tile.bastion_beats) * TICKS_PER_BEAT, "activation": _activation,
	}
	_emit("bastion_ready", "Ready to shield allies when Guard absorbs %d damage from one hit." % threshold,
		actor, actor, tile_id, threshold)


func _release_bastion_ward(carrier: Dictionary, blocked: int) -> void:
	var ward: Dictionary = carrier.bastion_ward
	if tick > ward.until:
		carrier.erase("bastion_ward")
		return
	if blocked < ward.threshold:
		return
	carrier.erase("bastion_ward")
	_guard_allies(carrier, ward.tile, ward.guard)
	var message := "Absorbed %d damage with Guard, granting up to %d Guard to each living hero." % [blocked, ward.guard]
	_emit("bastion_release", message, carrier, carrier, ward.tile, ward.guard)
	var activation: Dictionary = ward.activation
	if not activation.is_empty():
		activation.get_or_add("effect_details", []).append(message)
		activation.reason = _activation_result(activation)


func _prime_return_charge(actor: Dictionary, tile_id: String, tile: Dictionary) -> void:
	var bonus: int = tile.lance_return_bonus
	actor["lance_return"] = {"bonus": bonus, "until": tick + int(tile.lance_return_beats) * TICKS_PER_BEAT}
	var movement := "backstep" if tile.has("retreat") else "push"
	_emit("lance_return_ready", "The %s readies a charge for %d extra damage." % [movement, bonus], actor, actor, tile_id, bonus)


func _lance_hit_bonus(actor: Dictionary, target: Dictionary, tile_id: String) -> int:
	var tile: Dictionary = TILES[tile_id]
	if not tile.get("charge", false) and tile_id != "bulwark_charge":
		return 0
	var bonus := 0
	var travel_cap: int = tile.get("lance_travel_bonus", 0)
	if travel_cap > 0:
		var traveled: float = actor.get("lance_travel", 0.0)
		var travel_bonus := roundi(travel_cap * traveled / LANCE_TRAVEL_CAP)
		actor["lance_travel"] = 0.0
		if travel_bonus > 0:
			_emit("lance_travel_spent", "Travel adds %d damage to the charge." % travel_bonus,
				actor, target, tile_id, travel_bonus, _attack_origin(actor))
		bonus += travel_bonus
	var followup: Dictionary = actor.get("lance_return", {})
	if not followup.is_empty():
		actor.erase("lance_return")
		if tick <= followup.until:
			_emit("lance_return_spent", "The return charge adds %d damage." % followup.bonus,
				actor, target, tile_id, followup.bonus, _attack_origin(actor))
			bonus += int(followup.bonus)
	return bonus


func _prime_rune_charge(actor: Dictionary, tile_id: String) -> void:
	var tile: Dictionary = TILES[tile_id]
	var heavy: int = tile.get("rune_heavy_bonus", 0)
	var quick: int = tile.get("rune_quick_bonus", 0)
	if heavy <= 0 and quick <= 0:
		return
	var hits: int = tile.get("rune_quick_hits", 1) if quick > 0 else 1
	var bonus := maxi(heavy, quick)
	var width := "quick" if quick > 0 else "wide"
	var key := "quick_rune_charge" if quick > 0 else "wide_rune_charge"
	actor[key] = {"hits": hits, "bonus": bonus, "until": tick + LOOP_TICKS}
	_emit("rune_charge_ready", "%s charges %d %s hits for +%d damage each." % [actor.name, hits, width, bonus],
		actor, actor, tile_id, bonus)


func _consume_rune_charge(actor: Dictionary, target: Dictionary, tile_id: String) -> int:
	var key := "quick_rune_charge" if TILES[tile_id].width <= 2 else "wide_rune_charge"
	var charge: Dictionary = actor.get(key, {})
	if charge.is_empty():
		return 0
	if tick > charge.until:
		actor.erase(key)
		return 0
	if _activation.get("signature_rune_spent", false):
		return 0
	_activation["signature_rune_spent"] = true
	charge.hits -= 1
	var bonus: int = charge.bonus
	if charge.hits <= 0:
		actor.erase(key)
	_emit("rune_charge_spent", "%s's rune adds %d damage." % [actor.name, bonus],
		actor, target, tile_id, bonus, _attack_origin(actor))
	return bonus


func _needle_attack_bonus(actor: Dictionary, target: Dictionary, tile_id: String) -> int:
	var bonus := _consume_duel_followup(actor, target, tile_id)
	if target.id != _activation.target:
		return bonus
	var focus: Dictionary = actor.get("needle_focus", {})
	if target.id != focus.get("target", ""):
		actor.erase("needle_focus")
		focus = {}
	var tile: Dictionary = TILES[tile_id]
	if tile.get("family", "") != "needle_point":
		return bonus
	var gain: int = tile.get("duel_stack_gain", 0)
	if focus.is_empty():
		actor["needle_focus"] = {"target": target.id, "bonus": 0}
	elif gain > 0:
		focus.bonus = mini(focus.bonus + gain, tile.duel_stack_cap)
		_emit("duel_stack", "%s's focus adds %d damage against %s." % [actor.name, focus.bonus, target.name],
			actor, target, tile_id, focus.bonus, _attack_origin(actor))
		bonus += focus.bonus
	return bonus


func _prime_duel_followup(actor: Dictionary, target: Dictionary, tile_id: String) -> void:
	var bonus: int = TILES.get(tile_id, {}).get("duel_kill_bonus", 0)
	if bonus <= 0:
		return
	actor["duel_followup"] = {"target": target.id, "bonus": bonus, "until": tick + LOOP_TICKS}
	_emit("duel_kill_ready", "%s's next hit on another enemy gains %d damage." % [actor.name, bonus],
		actor, actor, tile_id, bonus)


func _consume_duel_followup(actor: Dictionary, target: Dictionary, tile_id: String) -> int:
	var followup: Dictionary = actor.get("duel_followup", {})
	if followup.is_empty():
		return 0
	if tick > followup.until:
		actor.erase("duel_followup")
		return 0
	if followup.target == target.id:
		return 0
	actor.erase("duel_followup")
	_emit("duel_kill_spent", "%s carries %d bonus damage into the next attack." % [actor.name, followup.bonus],
		actor, target, tile_id, followup.bonus, _attack_origin(actor))
	return followup.bonus


func _consume_ranged_followup(actor: Dictionary, target: Dictionary, tile_id: String) -> int:
	var followup: Dictionary = actor.get("ranged_followup", {})
	if followup.is_empty():
		return 0
	if tick > followup.until:
		actor.erase("ranged_followup")
		return 0
	if not is_ranged_tile(tile_id):
		return 0
	actor.erase("ranged_followup")
	_emit("ranged_followup_spent", "%s adds %d damage with a ranged follow-up." % [actor.name, followup.bonus],
		actor, target, tile_id, followup.bonus, _attack_origin(actor))
	return followup.bonus


func _consume_arsenal_mark(actor: Dictionary, target: Dictionary, tile_id: String) -> int:
	for key: String in ["ally_mark", "arsenal_mark"]:
		var mark: Dictionary = target.get(key, {})
		if mark.is_empty():
			continue
		if mark.expires < tick:
			target.erase(key)
			continue
		if mark.order == _activation.order or (key == "ally_mark" and mark.marker == actor.id):
			continue
		target.erase(key)
		var label := "Ally mark" if key == "ally_mark" else "Mark"
		_emit("mark_spent", "%s on %s adds %d damage." % [label, target.name, mark.bonus],
			actor, target, tile_id, mark.bonus)
		return mark.bonus
	return 0


func _consume_cantor_mark(actor: Dictionary, target: Dictionary, tile_id: String) -> int:
	var mark: Dictionary = target.get("cantor_mark", {})
	if mark.is_empty():
		return 0
	if mark.expires < tick:
		target.erase("cantor_mark")
		return 0
	if actor.id == mark.marker or actor.id in mark.contributors:
		return 0
	if mark.guard > 0:
		target.erase("cantor_mark")
		_guard_allies(actor, tile_id, mark.guard)
		_emit("chorus_guard", "The mark on %s grants each living hero up to %d Guard." % [target.name, mark.guard],
			actor, target, tile_id, mark.guard)
		return 0
	mark.contributors.append(actor.id)
	if mark.contributors.size() == 2:
		target.erase("cantor_mark")
	_emit("chorus_mark_spent", "The mark on %s adds %d damage to %s's hit." % [target.name, mark.bonus, actor.name],
		actor, target, tile_id, mark.bonus)
	return mark.bonus


func _relic_attack_bonus(actor: Dictionary, target: Dictionary) -> int:
	var bonus := 0
	if target.id == _towline_mark.get("target") and tick <= _towline_mark.expires and _activation.order != _towline_mark.order:
		bonus += _relic_proc("towline_knot", "Towline Knot", 9, actor, target, _towline_mark.source, _towline_mark.source_beat)
		_towline_mark.clear()
	if int(actor.get("bridgeplate_ready_loop", -1)) == _loop_index():
		actor["bridgeplate_ready_loop"] = -1
		actor["bridgeplate_used_loop"] = _loop_index()
		bonus += _relic_proc("bridgeplate", "Bridgeplate", 8, actor, target, "Guard absorbed a hit")
	if _has_relic(actor, "brass_metronome") and _metronome_loop != _loop_index() and _has_gap_before_activation():
		_metronome_loop = _loop_index()
		bonus += _relic_proc("brass_metronome", "Brass Metronome", 8, actor, target, "Empty beat before the tile")
	return bonus


func _timeline_relic_bonus(actor: Dictionary, target: Dictionary, tile_id: String) -> int:
	var bonus := _twin_bell_bonus(actor, target, tile_id)
	if _activation.beat <= TOLLKEEPER_SIGNET_LAST_BEAT and _has_relic(actor, "tollkeeper_signet"):
		bonus += _relic_proc("tollkeeper_signet", "Tollkeeper's Signet", TOLLKEEPER_SIGNET_DAMAGE,
			actor, target, TILES[tile_id].label, _activation.beat, "", _attack_origin(actor))
	if target.id != _activation.target:
		return bonus
	if _has_relic(actor, "bellmaker_long_echo") and is_ranged_tile(tile_id) \
			and int(actor.get("bellmaker_long_echo_loop", -1)) != _loop_index():
		actor["bellmaker_long_echo_loop"] = _loop_index()
		bonus += _relic_proc("bellmaker_long_echo", "Long Echo", BELLMAKER_LONG_ECHO_DAMAGE,
			actor, target, TILES[tile_id].label, _activation.beat, "", _attack_origin(actor))
	bonus += _stepped_gear_bonus(actor, target, tile_id)
	bonus += _switchback_lens_bonus(actor, target, tile_id)
	if _has_relic(actor, "longshot_prism") and not _spent_timeline_relics.has("longshot_prism"):
		var origin := _attack_origin(actor)
		var distance := origin.distance_to(target.pos)
		if distance >= LONGSHOT_PRISM_RANGE:
			_spent_timeline_relics["longshot_prism"] = true
			bonus += _relic_proc("longshot_prism", "Longshot Prism", 11, actor, target, "Hit from %d units away" % roundi(distance), 0, "", origin)
	if _has_relic(actor, "mercy_seal") and not _spent_timeline_relics.has("mercy_seal") \
			and target.hp * 4 <= target.max_hp and actor.guard < MAX_GUARD:
		_spent_timeline_relics["mercy_seal"] = true
		var gained := mini(6, MAX_GUARD - actor.guard)
		_guard(actor, gained, "mercy_seal", {}, false)
		_relic_proc("mercy_seal", "Mercy Seal", gained, actor, actor, target.name, 0, "Gained %d Guard" % gained)
	return bonus


func _twin_bell_bonus(actor: Dictionary, target: Dictionary, tile_id: String) -> int:
	if not _has_relic(actor, "twin_bell") or _spent_timeline_relics.has("twin_bell"):
		return 0
	var previous: Dictionary = _twin_bell_hits.get(target.id, {})
	if previous.is_empty():
		_twin_bell_hits[target.id] = {"actor": actor.id, "source": "%s's %s" % [actor.name, TILES[tile_id].label]}
	elif previous.actor != actor.id:
		_spent_timeline_relics["twin_bell"] = true
		return _relic_proc("twin_bell", "Twin Bell", 12, actor, target, previous.source, _activation.beat)
	return 0


func _stepped_gear_bonus(actor: Dictionary, target: Dictionary, tile_id: String) -> int:
	if not _has_relic(actor, "stepped_gear") or _spent_timeline_relics.has("stepped_gear") or TILES[tile_id].width > 2:
		return 0
	for preceding: Dictionary in _lanes[_activation.lane]:
		if preceding.end == _activation.start and TILES[preceding.id].width >= 3:
			_spent_timeline_relics["stepped_gear"] = true
			return _relic_proc("stepped_gear", "Stepped Gear", 7, actor, target, TILES[preceding.id].label, preceding.end)
	return 0


func _switchback_lens_bonus(actor: Dictionary, target: Dictionary, tile_id: String) -> int:
	if not _has_relic(actor, "switchback_lens"):
		return 0
	var previous: Dictionary = actor.get("switchback_last_hit", {})
	if previous.get("order", -1) == _activation.order:
		return 0
	actor["switchback_last_hit"] = {"target": target.id, "source": TILES[tile_id].label, "beat": _activation.beat, "order": _activation.order}
	if previous.is_empty() or previous.target == target.id or actor.get("switchback_loop", -1) == _loop_index():
		return 0
	actor["switchback_loop"] = _loop_index()
	return _relic_proc("switchback_lens", "Switchback Lens", 10, actor, target, previous.source, previous.beat)


func _apply_barrage_rack(actor: Dictionary, target: Dictionary, tile_id: String) -> void:
	if int(TILES[tile_id].width) > 2 or not _has_relic(actor, "barrage_rack"):
		return
	var previous: Dictionary = _barrage_hits.get(target.id, {})
	if previous.get("order", -1) == _activation.order:
		return
	if not previous.is_empty() and tick - int(previous.tick) <= 2 * TICKS_PER_BEAT:
		_barrage_hits.erase(target.id)
		var stripped := mini(BARRAGE_GUARD_BREAK, target.guard)
		if stripped > 0:
			target.guard -= stripped
			_relic_proc("barrage_rack", "Barrage Rack", stripped, actor, target, previous.source, previous.beat,
				"Stripped %d Guard before the hit" % stripped)
		return
	_barrage_hits[target.id] = {"order": _activation.order, "tick": tick, "beat": _activation.beat, "source": TILES[tile_id].label}


func _has_gap_before_activation() -> bool:
	var start: int = _activation.start
	if start == 0 and tick <= LOOP_TICKS:
		return false
	var previous_edge := BEATS if start == 0 else start
	return not _lanes[_activation.lane].any(func(tile: Dictionary): return tile.end == previous_edge)


func _relic_proc(id: String, label: String, amount: int, actor: Dictionary, target: Dictionary, source: String,
		source_beat := 0, effect := "", origin := Vector2.INF) -> int:
	var message := effect if not effect.is_empty() else "+%d damage" % amount
	_emit("relic_proc", "%s · %s" % [label, message], actor, target, id, amount, origin)
	if not _activation.is_empty():
		var proc := {"id": id, "amount": amount, "target_name": target.name, "source": source, "source_beat": source_beat}
		if not effect.is_empty():
			proc["effect"] = effect
		_activation.get_or_add("relics", []).append(proc)
		var event: Dictionary = trace.back()
		event["source_tile"] = _activation.tile
		event["lane"] = _activation.lane
		event["start"] = _activation.start
	return amount


func _regent_damage(actor: Dictionary, regent: Dictionary, amount: int) -> int:
	if regent.regent_window_until == 0:
		regent.regent_window_until = tick + TICKS_PER_BEAT * 4
	if actor.id not in regent.regent_contributors:
		regent.regent_contributors.append(actor.id)
		regent.regent_seals_left -= 1
		if regent.regent_seals_left == 0:
			regent.regent_sealed = false
			regent.regent_window_until = 0
			regent.guard = 0
			regent.intent = ""
			regent.next_attack = tick + TICKS_PER_BEAT * 6
			_emit("interrupt", "All three heroes shatter the Regent's seals and stagger it!", actor, regent, "regent_shattered")
			return amount + 22
		_emit("interrupt", "%s strikes a seal. %d distinct heroes still needed." % [actor.name, regent.regent_seals_left],
			actor, regent, "regent_seal_struck")
	return maxi(1, roundi(amount * 0.62))


func _rally_twin(fallen: Dictionary) -> void:
	for unit in units:
		if unit.id == fallen.id or unit.hp <= 0 or not unit.get("attack", {}).get("twin", false):
			continue
		unit["enraged"] = true
		unit.next_attack = mini(unit.next_attack, tick + 20)
		_guard(unit, 11, "crucible_rally")
		_emit("intent", "%s rallies after their twin falls." % unit.name, unit, fallen, "crucible_rally")


func _expose_marshal(actor: Dictionary, marshal: Dictionary) -> void:
	if marshal.marshal_exposed_until > 0:
		return
	marshal.marshal_exposed_until = tick + TICKS_PER_BEAT * 3
	marshal["marshal_opened_by"] = actor.id
	_emit("interrupt", "%s exposes the Marshal for 3 beats. Follow up with your other hero." % actor.name,
		actor, marshal, "marshal_exposed")


func _expose_prism(actor: Dictionary, warden: Dictionary) -> void:
	if warden.prism_window_until > 0:
		return
	warden.prism_window_until = tick + TICKS_PER_BEAT * 3
	warden["prism_opened_by"] = actor.id
	_emit("interrupt", "%s exposes the prism ward for 3 beats." % actor.name, actor, warden, "prism_exposed")


func _prism_damage(actor: Dictionary, warden: Dictionary, amount: int) -> int:
	if warden.prism_window_until == 0:
		return maxi(1, roundi(amount * 0.65))
	if warden.prism_opened_by == actor.id:
		return amount
	warden.prism_warded = false
	warden.prism_window_until = 0
	warden.prism_secondary = ""
	warden.guard = 0
	warden.intent = ""
	warden.next_attack = tick + TICKS_PER_BEAT * 5
	_emit("interrupt", "%s shatters the prism ward and interrupts the Warden!" % actor.name, actor, warden, "prism_shattered")
	return amount + 20


func _marshal_damage(actor: Dictionary, marshal: Dictionary, amount: int, direct_hit: bool) -> int:
	if marshal.marshal_exposed_until > 0 and marshal.marshal_opened_by != actor.id:
		_break_marshal_plate(marshal)
		marshal.intent = ""
		marshal.next_attack = tick + TICKS_PER_BEAT * 5
		if marshal.has("marshal_plate_integrity"):
			marshal["marshal_last_break"] = "team"
			marshal.erase("pilot_ring_radius")
		_emit("interrupt", "%s shatters the Marshal's plating and staggers it!" % actor.name,
			actor, marshal, "marshal_shattered")
		return amount + 18
	var reduced := maxi(1, roundi(amount * 0.62))
	if direct_hit and amount > 0 and marshal.has("marshal_plate_integrity"):
		if _wear_marshal_plate(actor, marshal, maxi(1, amount - reduced), "pressure"):
			return amount
	if marshal.marshal_exposed_until > 0:
		return amount
	return reduced


func _wear_marshal_plate(actor: Dictionary, marshal: Dictionary, amount: int, approach: String) -> bool:
	if amount <= 0 or not marshal.marshal_plated:
		return false
	marshal.marshal_plate_integrity = maxi(0, int(marshal.marshal_plate_integrity) - amount)
	if marshal.marshal_plate_integrity > 0:
		if approach == "pressure":
			_emit("interrupt", "The hit wears down the plate. %d integrity remains." % marshal.marshal_plate_integrity,
				actor, marshal, "marshal_plate_worn", amount)
		return false
	_break_marshal_plate(marshal)
	marshal["marshal_last_break"] = approach
	if approach == "pressure":
		var message := "Sustained hits break the Marshal's plating."
		if not str(marshal.intent).is_empty() and marshal.get("intent_attack_id") == "marshal_sweep":
			message += " The charging sweep still releases."
		_emit("interrupt", message, actor, marshal, "marshal_pressure_break", amount)
	else:
		_emit("interrupt", "Weathering the sweep breaks the Marshal's plating.",
			actor, marshal, "marshal_defense_break", amount)
	return true


func _break_marshal_plate(marshal: Dictionary) -> void:
	marshal.marshal_plated = false
	marshal.marshal_exposed_until = 0
	marshal.guard = 0
	if marshal.has("marshal_plate_integrity"):
		marshal.marshal_plate_integrity = 0


func _class_attack_damage(actor: Dictionary, target: Dictionary, tile_id: String, amount: int) -> int:
	match actor.get("class", ""):
		"lancer":
			if actor.get("travel", 0.0) >= 80.0:
				actor["travel"] = 0.0
				amount += 6
		"apothecary":
			if actor.get("heal_loop", -1) != _loop_index():
				actor["heal_loop"] = _loop_index()
				var healed := mini(2, actor.max_hp - actor.hp)
				actor.hp += healed
				if healed > 0:
					_emit("heal", "Apothecary restores %d HP." % healed, actor, actor, "apothecary", healed,
						Vector2.INF, Vector2.INF, {"source_tile": tile_id})
				if healed < 2:
					_guard(actor, 2 - healed, "apothecary")
		"rune_smith":
			if actor.get("rune_charged", false):
				actor["rune_charged"] = false
				amount += 5
		"starshot":
			var position := _attack_origin(actor)
			if position.distance_squared_to(target.pos) > 200.0 * 200.0:
				amount += 5
		"cinder_mage":
			var impulse: Vector2 = target.impulse
			if impulse.length_squared() > 1.0 and actor.get("burn_loop", -1) != _loop_index():
				actor["burn_loop"] = _loop_index()
				target["burn_source"] = actor.id
				target["burn_tile"] = tile_id
				target["burn_tick"] = tick + TICKS_PER_BEAT
				target["burn_left"] = 2
		"duelist":
			var streak := 0
			if actor.get("focus_target", "") == target.id:
				streak = mini(3, actor.get("focus_streak", 0) + 1)
			actor["focus_target"] = target.id
			actor["focus_streak"] = streak
			amount += 2 * streak
	return amount


func _run_burns() -> void:
	for target in units:
		if target.hp <= 0:
			continue
		if target.get("burn_left", 0) > 0 and tick >= target.get("burn_tick", 0):
			var source := _find_unit(target.burn_source)
			target.burn_left -= 1
			target.burn_tick += TICKS_PER_BEAT
			if not source.is_empty():
				_damage(source, target, 3, "cinder_mage", "", {"source_tile": target.get("burn_tile", "")})
		if target.hp > 0 and target.has("ember_burns"):
			_tick_ember_burns(target)


func _tick_ember_burns(target: Dictionary) -> void:
	var burns: Dictionary = target.ember_burns
	for source_id: String in burns.keys():
		var burn: Dictionary = burns[source_id]
		if tick < burn.next_tick:
			continue
		var source := _find_unit(source_id)
		burn.next_tick += TICKS_PER_BEAT
		burn.remaining -= 1
		if burn.remaining == 0:
			burns.erase(source_id)
		if source.is_empty():
			continue
		var before: int = target.hp
		_damage(source, target, burn.damage, "cinder_mage", "", {"source_tile": burn.tile})
		_emit("ember_tick", "%s burns %s for %d damage." % [TILES[burn.tile].label, target.name, before - int(target.hp)],
			source, target, burn.tile, before - int(target.hp))
		if target.hp <= 0:
			break


func _breaker_collision(moving: Dictionary, other: Dictionary) -> void:
	var setup: Dictionary = moving.get("collision_push", {})
	if moving.hp <= 0 or other.hp <= 0 or moving.side != other.side or tick > setup.get("until", -1):
		return
	if other.id == setup.get("collision_origin", ""):
		return
	var impulse: Vector2 = moving.impulse
	var contact: Vector2 = other.pos - moving.pos
	if impulse.dot(contact.normalized()) < 100.0:
		return
	var source := _find_unit(setup.source)
	if source.is_empty():
		return
	moving.erase("collision_push")
	if setup.has("tile"):
		var message := "%s knocks %s into %s, adding %d collision damage to each." % [
			TILES[setup.tile].label, moving.name, other.name, setup.bonus,
		]
		_emit("hammer_collision", message, source, other, setup.tile, setup.bonus, moving.pos, other.pos)
		var activation: Dictionary = setup.activation
		if not activation.is_empty():
			activation.get_or_add("effect_details", []).append(message)
			activation.reason = _activation_result(activation)
	var details := {"source_tile": setup.get("source_tile", "")}
	_damage(source, moving, setup.damage, "breaker", "", details)
	_damage(source, other, setup.damage, "breaker", "", details)
	VanguardSpecialties.chain_collision(self, source, moving, other, setup)


func _find_unit(id: String) -> Dictionary:
	for unit in units:
		if unit.id == id:
			return unit
	return {}


func _has_relic(unit: Dictionary, relic: String) -> bool:
	return relic in unit.get("relics", [])


func _loop_index() -> int:
	return (tick - 1) / LOOP_TICKS


func _end_stalemate() -> void:
	var damage := 3 + floori(float(tick - 3600) / 30.0)
	for unit in units:
		if unit.hp > 0:
			_damage(unit, unit, damage, "overtime")


func _check_outcome() -> void:
	var alive_hero := false
	var alive_enemy := false
	for unit in units:
		if unit.hp <= 0:
			continue
		if unit.side == "hero":
			alive_hero = true
		else:
			alive_enemy = true
	if not alive_hero:
		outcome = "defeat"
	elif not alive_enemy and _reinforcement_wave.is_empty():
		outcome = "victory"
	if outcome != "":
		_emit("outcome", "Victory. The arena is clear." if outcome == "victory" else "Defeat. The crew has fallen.")


static func _tick_in_loop(at_tick: int) -> int:
	return 0 if at_tick <= 0 else (at_tick - 1) % LOOP_TICKS + 1


static func loop_progress(at_tick: int) -> float:
	return float(_tick_in_loop(at_tick)) / LOOP_TICKS


func _beat() -> int:
	return ceili(float(_tick_in_loop(tick)) / TICKS_PER_BEAT)


func _emit(kind: String, message: String, actor: Dictionary = {}, target: Dictionary = {}, tile_id: String = "",
		amount: int = 0, start_position: Vector2 = Vector2.INF, end_position: Vector2 = Vector2.INF,
		details: Dictionary = {}) -> void:
	var event := {
		"kind": kind, "tick": tick, "beat": _beat(), "actor": actor.get("id", ""), "target": target.get("id", ""),
		"tile": tile_id, "amount": amount, "message": message,
		"from": actor.get("pos", Vector2.ZERO) if start_position == Vector2.INF else start_position,
		"to": target.get("pos", Vector2.ZERO) if end_position == Vector2.INF else end_position
	}
	event.merge(details)
	trace.append(event)
	_events.append(event)
	if kind == "heal" and amount > 0 and target.get("side") == "hero":
		_last_party_heal_loop = _loop_index()
	if not _activation.is_empty() and actor.get("id") == _activation.actor and tile_id == _activation.tile:
		match kind:
			"miss":
				_activation.status = "miss"
				_activation.reason = message.get_slice(": ", 1)
			"hit":
				_activation.damage += amount
				if target.id == _activation.target:
					actor["last_primary_tile_target"] = target.id
					if _activation.get("enchantment") == "splash":
						_activation["primary_hit"] = true
			"guard":
				_activation.guard += amount
				if actor.id != target.id and TILES[tile_id].has("ally_guard"):
					_activation.get_or_add("effect_details", []).append(message)
			"teleport":
				_activation["teleported"] = true
				if TILES[tile_id].get("blink_strike", false):
					_activation.get_or_add("effect_details", []).append(message)
			"heal", "retreat", "charge", "mark", "mark_spent", "guard_break", "guard_spent", "cluster_pull":
				_activation.get_or_add("effect_details", []).append(message)
			"ranged_followup_ready", "ranged_followup_spent", "sweep_push", "chorus_mark", "chorus_mark_spent", "chorus_guard":
				_activation.get_or_add("effect_details", []).append(message)
			"rune_charge_ready", "rune_charge_spent", "duel_stack", "duel_kill_ready", "duel_kill_spent", "ember_ignite":
				_activation.get_or_add("effect_details", []).append(message)
			"bastion_ready", "lance_travel_spent", "lance_return_ready", "lance_return_spent":
				_activation.get_or_add("effect_details", []).append(message)
	if kind in ["intent", "interrupt", "miss"] and BOSS_REVIEW_STAGES.has(tile_id):
		_review_boss_event(BOSS_REVIEW_STAGES[tile_id], tile_id, message, actor, target, kind)
	elif tile_id == "enemy_attack" and actor.get("name") == "The Tollkeeper":
		match kind:
			"hit":
				_review_boss_event("miss", "tollkeeper_hit", message + " Try a push during its windup or time Guard before impact.", actor, target, kind)
			"miss":
				_review_boss_event("success", "tollkeeper_miss", message, actor, target, kind)


func _review_boss_event(stage: String, tile_id: String, message: String, actor: Dictionary, target: Dictionary = {}, kind := "intent") -> void:
	var event := {
		"order": activations.size() + boss_events.size(), "tick": tick, "beat": _beat(), "loop": _loop_index() + 1,
		"stage": stage, "kind": kind, "tile": tile_id, "message": message,
		"actor": actor.get("id", ""), "actor_name": actor.get("name", ""),
		"target": target.get("id", ""), "target_name": target.get("name", ""),
	}
	if not _activation.is_empty():
		event["source_tile"] = _activation.tile
		event["lane"] = _activation.lane
		event["start"] = _activation.start
	boss_events.append(event)
