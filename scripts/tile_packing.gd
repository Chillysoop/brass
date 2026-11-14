extends RefCounted

const ArenaSim = preload("res://scripts/arena_sim.gd")
const STORAGE_COLUMNS := 8
const STORAGE_ROWS := 3


static func can_place(items: Array, id: String, start: int, capacity: int, ignored_start := -1) -> bool:
	if not ArenaSim.TILES.has(id) or start < 0:
		return false
	var end: int = start + ArenaSim.TILES[id].width
	if end > capacity:
		return false
	for item: Dictionary in items:
		if item.start != ignored_start and start < item.start + ArenaSim.TILES[item.id].width and end > item.start:
			return false
	return true


static func nudge_plan(items: Array, id: String, start: int, capacity: int, ignored_start := -1) -> Dictionary:
	if not ArenaSim.TILES.has(id) or start < 0:
		return {}
	var end: int = start + ArenaSim.TILES[id].width
	if end > capacity:
		return {}
	if can_place(items, id, start, capacity, ignored_start):
		return {"start": start, "moves": {}}

	var neighbors := items.filter(func(item: Dictionary): return item.start != ignored_start)
	neighbors.sort_custom(func(a: Dictionary, b: Dictionary): return a.start < b.start)
	var best_moves := {}
	var best_cost := -1
	# Try each possible insertion point while preserving the order of existing tiles.
	for split in range(neighbors.size() + 1):
		var moves := {}
		var left := start
		for index in range(split - 1, -1, -1):
			var item: Dictionary = neighbors[index]
			left = mini(item.start, left - ArenaSim.TILES[item.id].width)
			if left != item.start:
				moves[item.start] = left
		if left < 0:
			continue
		var right := end
		for index in range(split, neighbors.size()):
			var item: Dictionary = neighbors[index]
			var position := maxi(item.start, right)
			if position != item.start:
				moves[item.start] = position
			right = position + ArenaSim.TILES[item.id].width
		if right > capacity:
			continue
		var cost := 0
		for origin: int in moves:
			cost += absi(int(moves[origin]) - origin)
		if best_cost < 0 or cost < best_cost or (cost == best_cost and moves.size() < best_moves.size()):
			best_cost = cost
			best_moves = moves
	return {} if best_cost < 0 else {"start": start, "moves": best_moves}


static func forge_tiers(id: String) -> Array:
	var family: String = ArenaSim.TILES.get(id, {}).get("family", "")
	return ArenaSim.FORGE_FAMILIES.get(family, [])


static func next_options(id: String) -> Array:
	var tiers := forge_tiers(id)
	for tier in range(tiers.size() - 1):
		if id in tiers[tier]:
			return tiers[tier + 1]
	return []


static func offers(items: Array, suppressed: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var index := 0
	while index + 2 < items.size():
		var item: Dictionary = items[index]
		var id: String = item.id
		var width: int = ArenaSim.TILES[id].width
		var second: Dictionary = items[index + 1]
		var third: Dictionary = items[index + 2]
		var matching: bool = id == second.id and id == third.id
		var touching: bool = second.start == item.start + width and third.start == second.start + width
		if matching and touching and not suppressed.has(id) and not next_options(id).is_empty():
			result.append({"id": id, "start": item.start, "width": width * 3})
			index += 3
		else:
			index += 1
	return result
