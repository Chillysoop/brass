extends RefCounted


static func hexwright_pull_bonus(sim, actor: Dictionary, target: Dictionary, tile_id: String, tile: Dictionary) -> int:
	if tile.has("convergence_damage_per_pull"):
		return _convergence_bonus(sim, actor, target, tile_id, tile)
	if tile.has("isolation_damage"):
		return _isolation_bonus(sim, actor, target, tile_id, tile)
	return 0


static func _convergence_bonus(sim, actor: Dictionary, target: Dictionary, tile_id: String, tile: Dictionary) -> int:
	var center: Vector2 = target.pos
	var neighbors: Array[Dictionary] = _other_enemies(sim, actor, target, tile.convergence_radius)
	var pulled := 0
	for neighbor: Dictionary in neighbors.slice(0, int(tile.convergence_targets)):
		var start: Vector2 = neighbor.pos
		var landing := _pull_landing(sim, actor, neighbor, tile_id, center, tile.convergence_force)
		if landing.distance_squared_to(center) < start.distance_squared_to(center):
			pulled += 1
	return pulled * int(tile.convergence_damage_per_pull)


static func _isolation_bonus(sim, actor: Dictionary, target: Dictionary, tile_id: String, tile: Dictionary) -> int:
	var start: Vector2 = target.pos
	var neighbors: Array[Dictionary] = _other_enemies(sim, actor, target, INF)
	var origin: Vector2 = sim._attack_origin(actor)
	var landing := _pull_landing(sim, actor, target, tile_id, origin, tile.isolation_pull_force)
	if neighbors.is_empty():
		return 0
	var ally_position: Vector2 = neighbors[0].pos
	var separation := landing.distance_to(ally_position) - start.distance_to(ally_position)
	return int(tile.isolation_damage) if separation >= float(tile.isolation_distance) else 0


static func _other_enemies(sim, actor: Dictionary, target: Dictionary, radius: float) -> Array[Dictionary]:
	var neighbors: Array[Dictionary] = sim._enemies_in_area(actor, target.pos, radius)
	neighbors.erase(target)
	sim._sort_by_distance(neighbors, target.pos)
	return neighbors


static func _pull_landing(sim, actor: Dictionary, target: Dictionary, tile_id: String, center: Vector2, force: float) -> Vector2:
	var start: Vector2 = target.pos
	var offset := center - start
	if offset.is_zero_approx():
		return start
	if actor.get("class") == "hexwright":
		force += 90.0
	if not sim._displace("pull", actor, target, tile_id, offset, force):
		return start
	# Resolve the bonus at the tile edge using the pull's landing, clipped to obstacles.
	var launch: Vector2 = target.impulse
	var travel := launch.length_squared() / (2.0 * float(sim.IMPULSE_DECAY))
	var endpoint: Vector2 = sim._bounded(start + launch.normalized() * travel, target.radius)
	return sim._slide_landing(target, endpoint)
