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


static func find_copies(lanes: Array, storage: Array, id: String, count: int, eligible_lanes: Array,
		preferred := {}) -> Array:
	if count < 1 or next_options(id).is_empty():
		return []
	var copies: Array[Dictionary] = []
	for lane: int in eligible_lanes:
		for item: Dictionary in lanes[lane]:
			if item.id == id:
				copies.append({"lane": lane, "start": item.start, "id": id})
	for row in range(storage.size()):
		for item: Dictionary in storage[row]:
			if item.id == id:
				copies.append({"lane": -1, "row": row, "start": item.start, "id": id})
	if copies.size() < count:
		return []
	var index := copies.find(preferred)
	if index > 0:
		copies.push_front(copies.pop_at(index))
	return copies.slice(0, count)


static func combine_destination(lanes: Array, storage: Array, copies: Array, upgrade: String,
		eligible_lanes := []) -> Dictionary:
	var groups := []
	for copy: Dictionary in copies:
		var group := {"lane": copy.lane} if not copy.has("row") else {"lane": -1, "row": copy.row}
		if group not in groups:
			groups.append(group)
	for lane: int in eligible_lanes:
		var group := {"lane": lane}
		if group not in groups:
			groups.append(group)
	for row in range(storage.size()):
		var group := {"lane": -1, "row": row}
		if group not in groups:
			groups.append(group)

	# Preserve a source slot if it fits before considering other spots.
	for copy: Dictionary in copies:
		if _combine_fits(lanes, storage, copies, copy, upgrade):
			return copy
	for group: Dictionary in groups:
		var capacity := STORAGE_COLUMNS if group.has("row") else ArenaSim.BEATS
		for start in range(capacity - int(ArenaSim.TILES[upgrade].width) + 1):
			var destination: Dictionary = group.merged({"start": start})
			if _combine_fits(lanes, storage, copies, destination, upgrade):
				return destination
	return {}


static func apply_combination(lanes: Array, storage: Array, copies: Array, destination: Dictionary,
		upgrade: String, target: String) -> bool:
	if copies.is_empty() or destination.is_empty() or upgrade not in next_options(copies[0].id):
		return false
	if not _combine_fits(lanes, storage, copies, destination, upgrade):
		return false
	var removals := []
	for copy: Dictionary in copies:
		var items := _combine_row(lanes, storage, copy)
		var index := items.find_custom(func(item: Dictionary): return item.start == copy.start and item.id == copy.id)
		if index < 0 or copy.id != copies[0].id:
			return false
		var item: Dictionary = items[index]
		if removals.any(func(removal: Dictionary): return is_same(removal.item, item)):
			return false
		removals.append({"items": items, "item": item})
	for removal: Dictionary in removals:
		removal.items.erase(removal.item)
	var items := _combine_row(lanes, storage, destination)
	items.append({"id": upgrade, "start": int(destination.start), "target": target})
	items.sort_custom(func(a: Dictionary, b: Dictionary): return a.start < b.start)
	return true


static func _combine_fits(lanes: Array, storage: Array, copies: Array, destination: Dictionary, upgrade: String) -> bool:
	var row := _combine_row(lanes, storage, destination)
	var remaining := row.filter(func(item: Dictionary):
		for copy: Dictionary in copies:
			if copy.lane == destination.lane and copy.get("row", -1) == destination.get("row", -1) \
					and copy.start == item.start and copy.id == item.id:
				return false
		return true
	)
	var capacity := STORAGE_COLUMNS if destination.has("row") else ArenaSim.BEATS
	return can_place(remaining, upgrade, destination.start, capacity)


static func _combine_row(lanes: Array, storage: Array, position: Dictionary) -> Array:
	return storage[position.row] if position.has("row") else lanes[position.lane]


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
