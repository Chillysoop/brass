extends RefCounted

const ENEMY_TARGETS := ["nearest", "farthest", "lowest_hp", "highest_hp"]
const SPECS := {
	"guard_refrain": {
		"label": "Guard Refrain", "width": 2, "range": 410.0, "damage": 9, "rarity": "common",
		"ranged": true, "guard": 4, "harmony_guard": 3, "support": "party", "targets": ENEMY_TARGETS, "icon": "guard",
		"description": "On hit, give every living hero 4 Guard. Other heroes whose tiles finish on the same beat gain 3 extra Guard.",
	},
	"echo_chime": {
		"label": "Echo Chime", "width": 2, "range": 450.0, "damage": 10, "rarity": "common",
		"ranged": true, "guard": 3, "support": "weakest", "chorus_echo_damage": 6, "chorus_echo_radius": 125.0, "chorus_echo_beats": 3,
		"targets": ENEMY_TARGETS, "icon": "relic",
		"description": "On hit, give 3 Guard to the living hero with the lowest HP. Within 3 beats, another hero can hit the target to echo 6 damage to its nearest other enemy within 125 units.",
	},
	"hammer_stamp": {
		"label": "Hammer Stamp", "width": 3, "range": 215.0, "damage": 23, "rarity": "common",
		"guard_break": 3, "rune_quick_bonus": 4, "rune_quick_hits": 2, "targets": ENEMY_TARGETS, "icon": "forge",
		"description": "Strip up to 3 Guard before the hit. Your next two hits from tiles up to 2 beats wide within 12 beats deal 4 extra damage each.",
	},
	"quick_etch": {
		"label": "Quick Etch", "width": 1, "range": 350.0, "damage": 6, "rarity": "common",
		"ranged": true, "rune_heavy_bonus": 5, "targets": ENEMY_TARGETS, "icon": "forge",
		"description": "Your next hit from a tile at least 3 beats wide within 12 beats deals 5 extra damage.",
	},
	"mirror_dart": {
		"label": "Mirror Dart", "width": 2, "range": 450.0, "damage": 11, "rarity": "common",
		"ranged": true, "teleport_followup_damage": 6, "teleport_followup_beats": 3,
		"targets": ENEMY_TARGETS, "icon": "shot",
		"description": "Deal 6 extra damage if you successfully teleported in the previous 3 beats.",
	},
	"veil_step": {
		"label": "Veil Step", "width": 2, "range": 430.0, "damage": 11, "rarity": "common",
		"ranged": true, "blink_on_hit_retreat": 115.0, "targets": ENEMY_TARGETS, "icon": "teleport",
		"description": "Fire a shot, then blink up to 115 units away from the target if there is room.",
	},
	"cinder_brand": {
		"label": "Cinder Brand", "width": 2, "range": 440.0, "damage": 12, "rarity": "common",
		"ranged": true, "push": 300.0, "ember_burn_damage": 3, "ember_burn_ticks": 2, "targets": ENEMY_TARGETS, "icon": "battle",
		"description": "Knock the target back. If it was pushed or pulled in the last 3 beats, burn it for 3 damage per beat for 2 beats.",
	},
	"wildfire_globe": {
		"label": "Wildfire Globe", "width": 3, "range": 435.0, "damage": 16, "rarity": "common",
		"ranged": true, "splash": 120.0, "splash_damage": 5, "ember_burn_damage": 3, "ember_burn_ticks": 2,
		"ember_burn_radius": 135.0, "ember_burn_if_burning": true, "targets": ENEMY_TARGETS, "icon": "area",
		"description": "Deal 5 damage to other enemies within 120 units of the target. If the target was already burning, burn surviving enemies within 135 units of it for 3 damage per beat for 2 beats.",
	},
}


static func apply_harmony_guard(sim, actor: Dictionary, tile_id: String, tile: Dictionary) -> void:
	var beat: int = sim._beat()
	for ally: Dictionary in sim.units:
		if ally.side != actor.side or ally.id == actor.id or ally.hp <= 0:
			continue
		if sim._lanes[ally.lane].any(func(other: Dictionary): return other.end == beat):
			sim._guard_from_tile(actor, ally, tile.harmony_guard, tile_id)


static func prime_echo(sim, actor: Dictionary, target: Dictionary, tile_id: String, tile: Dictionary) -> void:
	var beats: int = tile.chorus_echo_beats
	target["chorus_echo"] = {"marker": actor.id, "tile": tile_id, "expires": sim.tick + beats * sim.TICKS_PER_BEAT,
		"damage": tile.chorus_echo_damage, "reach": tile.chorus_echo_radius}
	sim._emit("mark", "%s sets an echo on %s for %d beats." % [tile.label, target.name, beats],
		actor, target, tile_id, tile.chorus_echo_damage)


static func resolve_ally_echo(sim, actor: Dictionary, target: Dictionary) -> void:
	var echo: Dictionary = target.get("chorus_echo", {})
	if echo.is_empty():
		return
	if echo.expires < sim.tick:
		target.erase("chorus_echo")
		return
	if echo.marker == actor.id:
		return
	var marker: Dictionary = sim._find_unit(echo.marker)
	var nearby: Array[Dictionary] = sim._splash_neighbors(actor, target, echo.reach)
	if marker.is_empty() or nearby.is_empty():
		return
	sim._sort_by_distance(nearby, target.pos)
	target.erase("chorus_echo")
	sim._damage(marker, nearby.front(), echo.damage, echo.tile, "Echo Chime", {"chorus_echo": true})


static func is_burning(enemy: Dictionary) -> bool:
	return int(enemy.get("burn_left", 0)) > 0 or not enemy.get("ember_burns", {}).is_empty()
