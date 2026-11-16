extends RefCounted

# Each entry introduces a combat rule. The stat tuning for the original tile is applied separately.
const ATTACK_STAGES := {
	"pierce": {"name": "Armor-Piercing", "key": "guard_break", "effects": {"guard_break": 4}},
	"punish": {"name": "Opportunist", "key": "windup_bonus", "effects": {"windup_bonus": 5}},
	"finish": {"name": "Executioner", "key": "low_hp_bonus", "effects": {"low_hp_bonus": 5}},
	"focus": {"name": "Long Sight", "key": "distance_bonus", "effects": {"distance_bonus": 5}},
	"stagger": {"name": "Stagger Strike", "key": "displaced_bonus", "effects": {"displaced_bonus": 5}},
	"collision": {"name": "Ricochet", "key": "collision_bonus", "effects": {"collision_bonus": 4}},
	"ignite": {"name": "Incendiary", "key": "ember_burn_damage", "effects": {
		"ember_burn_on_hit": true, "ember_burn_damage": 2, "ember_burn_ticks": 2}},
	"shock": {"name": "Shockwave", "key": "splash", "effects": {"splash": 90.0, "splash_damage": 5}},
	"scatter": {"name": "Blast Wave", "key": "sweep_push_radius", "effects": {
		"sweep_push_radius": 110.0, "sweep_push_force": 385.0}},
	"mark": {"name": "Signal", "key": "mark_bonus", "effects": {"mark_bonus": 5, "mark_beats": 3}},
	"cover": {"name": "Covering", "key": "ally_guard", "effects": {"ally_guard": 3}},
	"retreat": {"name": "Backstep", "key": "retreat", "effects": {"retreat": 72.0}},
	"gather": {"name": "Vortex", "key": "cluster_pull_radius", "effects": {
		"cluster_pull_radius": 125.0, "cluster_pull_force": 460.0}},
	"followup": {"name": "Return Fire", "key": "ranged_followup_bonus", "effects": {
		"ranged_followup_bonus": 5, "ranged_followup_beats": 3}},
	"ward": {"name": "Bastion", "key": "bastion_block_threshold", "effects": {
		"bastion_block_threshold": 4, "bastion_party_guard": 4, "bastion_beats": 4}},
}

const ATTACK_TRACKS := {
	"melee": [
		["pierce", "punish", "finish", "shock", "ignite", "stagger"],
		["cover", "mark", "retreat", "scatter", "ward", "gather"],
	],
	"ranged": [
		["pierce", "focus", "ignite", "finish", "punish", "shock"],
		["mark", "retreat", "followup", "cover", "gather", "ward"],
	],
	"area": [
		["punish", "pierce", "ignite", "scatter", "finish", "stagger"],
		["gather", "cover", "mark", "retreat", "ward"],
	],
	"hook": [
		["stagger", "pierce", "finish", "ignite", "punish", "shock"],
		["gather", "mark", "cover", "retreat", "ward"],
	],
	"impact": [
		["collision", "stagger", "pierce", "finish", "punish", "ignite"],
		["scatter", "cover", "retreat", "mark", "ward"],
	],
}

const SUPPORT_TRACKS := [
	[
		{"name": "Bastion", "effects": {"bastion_block_threshold": 4, "bastion_party_guard": 4, "bastion_beats": 4}},
		{"name": "Bodyguard", "effects": {"ally_guard": 4}},
		{"name": "Shield Chorus", "effects": {"harmony_guard": 4}},
		{"name": "Recovery Ward", "effects": {"heal_overflow_guard": 4}, "minimum_heal": 6},
	],
	[
		{"name": "Spare Dose", "effects": {"heal_overflow_guard": 4}},
		{"name": "Rally Dose", "effects": {"heal_party_guard": 3}},
		{"name": "Field Clinic", "effects": {"party_heal": true}},
		{"name": "Chorus Clinic", "effects": {"harmony_guard": 4}},
	],
]


static func stages_for(tile: Dictionary, technique: bool) -> Array:
	var track := int(technique)
	if tile.damage == 0:
		return SUPPORT_TRACKS[track]
	var eligible: Array = []
	for id: String in ATTACK_TRACKS[_attack_track(tile)][track]:
		var stage: Dictionary = ATTACK_STAGES[id]
		if not tile.has(stage.key):
			eligible.append(stage)
	return eligible


static func _attack_track(tile: Dictionary) -> String:
	if tile.has("pull"):
		return "hook"
	if tile.has("push"):
		return "impact"
	if tile.has("splash"):
		return "area"
	return "ranged" if tile.get("ranged", false) else "melee"
