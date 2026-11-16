extends RefCounted

const ENEMY_TARGETS := ["nearest", "farthest", "lowest_hp", "highest_hp"]

const SPECS := {
	"aegis_intercept": {
		"label": "Aegis Intercept", "width": 2, "range": 166.0, "damage": 9, "rarity": "common",
		"guard": 6, "support": "weakest", "intercept_guard": 6, "intercept_beats": 3,
		"targets": ENEMY_TARGETS, "icon": "guard",
		"description": "Strike and give 6 Guard to the living hero with the lowest HP. Gain 6 Guard before your next intercept within 3 beats.",
	},
	"shieldshock": {
		"label": "Shieldshock", "width": 3, "range": 180.0, "damage": 17, "rarity": "common",
		"recent_block_damage": 5, "recent_block_beats": 3, "block_wave_damage": 7, "block_wave_radius": 135.0,
		"targets": ENEMY_TARGETS, "icon": "area",
		"description": "If your Guard absorbed damage within 3 beats, deal 5 extra damage to the target and 7 damage to each other enemy within 135 units of it.",
	},
	"domino_maul": {
		"label": "Domino Maul", "width": 3, "range": 178.0, "damage": 17, "rarity": "common",
		"push": 775.0, "collision_bonus": 7, "collision_chain_push": 700.0,
		"targets": ENEMY_TARGETS, "icon": "push",
		"description": "Knock the target back. If it collides with an enemy, both take 7 extra collision damage and the second enemy is knocked onward for one more collision.",
	},
	"impact_driver": {
		"label": "Impact Driver", "width": 4, "range": 190.0, "damage": 26, "rarity": "common",
		"guard_break": 8, "windup_bonus": 8, "targets": ENEMY_TARGETS, "icon": "battle",
		"description": "Strip up to 8 Guard before the hit. Deal 8 extra damage if the target is winding up.",
	},
	"phalanx_charge": {
		"label": "Phalanx Charge", "width": 3, "range": 465.0, "damage": 15, "rarity": "common",
		"charge": true, "charge_carry": true, "charge_path_damage": 7, "charge_path_radius": 45.0,
		"targets": ENEMY_TARGETS, "icon": "battle",
		"description": "Rush and strike, then pass the target's shoulder if there is room. Deal 7 damage to other enemies whose bodies come within 45 units of your path.",
	},
	"recoil_thrust": {
		"label": "Recoil Thrust", "width": 2, "range": 210.0, "damage": 14, "rarity": "common",
		"retreat": 125.0, "lance_return_bonus": 7, "lance_return_beats": 3,
		"targets": ENEMY_TARGETS, "icon": "battle",
		"description": "Strike, then dash away up to 125 units. If you move, your next charge hit within 3 beats deals 7 extra damage.",
	},
}


static func prime_intercept(sim, actor: Dictionary, tile_id: String, tile: Dictionary) -> void:
	if tile.has("intercept_guard"):
		actor["intercept_aegis"] = {
			"guard": int(tile.intercept_guard), "tile": tile_id,
			"until": sim.tick + int(tile.intercept_beats) * sim.TICKS_PER_BEAT,
		}


static func reinforce_intercept(sim, actor: Dictionary) -> void:
	var aegis: Dictionary = actor.get("intercept_aegis", {})
	if aegis.is_empty():
		return
	actor.erase("intercept_aegis")
	if sim.tick <= aegis.until:
		sim._guard_from_tile(actor, actor, aegis.guard, aegis.tile)


static func apply_attack_followup(sim, actor: Dictionary, target: Dictionary, tile_id: String, tile: Dictionary,
		impact: Vector2, route: PackedVector2Array) -> void:
	if tile.has("block_wave_damage"):
		_shield_wave(sim, actor, target, tile_id, tile, impact)
	if tile.has("charge_path_damage"):
		_charge_path(sim, actor, target, tile_id, tile, route)


static func _shield_wave(sim, actor: Dictionary, target: Dictionary, tile_id: String, tile: Dictionary, impact: Vector2) -> void:
	var last_block := int(actor.get("last_guard_block_tick", -1))
	if last_block < 0 or sim.tick - last_block > int(tile.recent_block_beats) * sim.TICKS_PER_BEAT:
		return
	for enemy: Dictionary in sim._enemies_in_area(actor, impact, tile.block_wave_radius):
		if enemy.id != target.id:
			sim._damage(actor, enemy, int(tile.block_wave_damage), tile_id, "Shieldshock wave")


static func _charge_path(sim, actor: Dictionary, target: Dictionary, tile_id: String, tile: Dictionary, route: PackedVector2Array) -> void:
	if route.size() < 2:
		return
	for enemy: Dictionary in sim.units:
		if enemy.id == target.id or enemy.side == actor.side or enemy.hp <= 0:
			continue
		var radius: float = tile.charge_path_radius + enemy.radius
		for index in range(1, route.size()):
			var start := route[index - 1]
			var segment := route[index] - start
			var length_squared := segment.length_squared()
			if length_squared < 1.0:
				continue
			var offset: Vector2 = enemy.pos - start
			var progress := offset.dot(segment) / length_squared
			if (index == 1 and progress <= 0.0) or (index == route.size() - 1 and progress >= 1.0):
				continue
			if offset.distance_squared_to(segment * clampf(progress, 0.0, 1.0)) <= radius * radius:
				sim._damage(actor, enemy, int(tile.charge_path_damage), tile_id, "Phalanx sweep")
				break


static func chain_collision(sim, source: Dictionary, moving: Dictionary, other: Dictionary, setup: Dictionary) -> void:
	if other.hp <= 0:
		return
	var tile_id: String = setup.get("source_tile", "")
	var tile: Dictionary = sim.TILES.get(tile_id, {})
	var force: float = tile.get("collision_chain_push", 0.0)
	var remaining := int(setup.get("remaining_hops", tile.get("collision_chain_hops", 1)))
	if force <= 0.0 or remaining <= 0:
		return
	var offset: Vector2 = other.pos - moving.pos
	if offset.is_zero_approx():
		return
	var previous: Dictionary = other.get("collision_push", {})
	sim._displace("push", source, other, tile_id, offset, force)
	var relay: Dictionary = other.get("collision_push", {})
	if not relay.is_empty() and not is_same(previous, relay):
		relay["remaining_hops"] = remaining - 1
		relay["collision_depth"] = int(setup.get("collision_depth", 0)) + 1
		relay["collision_visited"] = setup.get("collision_visited", [moving.id]) + [other.id]
