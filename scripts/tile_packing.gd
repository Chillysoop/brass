extends RefCounted

const ArenaSim = preload("res://scripts/arena_sim.gd")
const TileEnchantments = preload("res://scripts/tile_enchantments.gd")
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


static func timeline_drop_plan(lanes: Array, storage: Array, lane_index: int, start: int, payload: Dictionary) -> Dictionary:
	var id: String = payload.get("id", "")
	if lane_index < 0 or lane_index >= lanes.size() or not ArenaSim.TILES.has(id) or start < 0:
		return {}
	var width: int = ArenaSim.TILES[id].width
	if start + width > ArenaSim.BEATS:
		return {}
	var items: Array = lanes[lane_index]
	var reward: bool = payload.get("reward", false)
	var stored := not reward and payload.has("row")
	var source_lane: int = payload.get("lane", -1) if not stored and not reward else -1
	if not stored and source_lane < 0 and not reward:
		return nudge_plan(items, id, start, ArenaSim.BEATS)
	var source_start: int = payload.get("start", -1)
	var source_row: int = payload.get("row", -1) if stored else -1
	var ignored := source_start if source_lane == lane_index else -1
	if not reward:
		var source_groups := storage if stored else lanes
		var source_index := source_row if stored else source_lane
		if source_index < 0 or source_index >= source_groups.size() or not source_groups[source_index].any(func(item: Dictionary):
				return item.start == source_start and item.id == id):
			return {}
		for item: Dictionary in items:
			if item.start == start and item.start != ignored and ArenaSim.TILES[item.id].width == width:
				return {"start": start, "moves": {}, "swap": start}

	var slide := nudge_plan(items, id, start, ArenaSim.BEATS, ignored)
	if not slide.is_empty():
		return slide
	var available_storage := storage
	if stored:
		available_storage = storage.duplicate()
		available_storage[source_row] = storage[source_row].filter(func(item: Dictionary): return item.start != source_start)
	return _timeline_stow_plan(items, available_storage, id, start, ignored)


static func _timeline_stow_plan(items: Array, storage: Array, id: String, start: int, ignored: int) -> Dictionary:
	var end: int = start + ArenaSim.TILES[id].width
	var displaced := items.filter(func(item: Dictionary):
		return item.start != ignored and item.start < end and item.start + ArenaSim.TILES[item.id].width > start)
	var best := {}
	var best_count := displaced.size() + 1
	var best_distance := 0
	# Try the covered tiles first, keeping as many equipped as the available spans allow.
	for mask in range(1, 1 << displaced.size()):
		var to_stow := []
		for index in range(displaced.size()):
			if (mask & (1 << index)) != 0:
				to_stow.append(displaced[index])
		if to_stow.size() > best_count:
			continue
		var remaining := items.filter(func(item: Dictionary): return item not in to_stow)
		var plan := nudge_plan(remaining, id, start, ArenaSim.BEATS, ignored)
		if plan.is_empty():
			continue
		var distance := 0
		for origin: int in plan.moves:
			distance += absi(int(plan.moves[origin]) - origin)
		if to_stow.size() == best_count and distance >= best_distance:
			continue
		var positions := _stow_positions(storage, to_stow)
		if positions.is_empty():
			continue
		best_count = to_stow.size()
		best_distance = distance
		plan.stows = positions
		best = plan
	return best


static func _stow_positions(storage: Array, items: Array) -> Array[Dictionary]:
	var occupied: Array[int] = []
	for row: Array in storage:
		var reserved := 0
		for item: Dictionary in row:
			reserved |= ((1 << int(ArenaSim.TILES[item.id].width)) - 1) << int(item.start)
		occupied.append(reserved)
	items.sort_custom(func(a: Dictionary, b: Dictionary):
		var left: int = ArenaSim.TILES[a.id].width
		var right: int = ArenaSim.TILES[b.id].width
		return left > right if left != right else int(a.start) < int(b.start))
	var placements: Array[Dictionary] = []
	if _reserve_stows(items, occupied, placements):
		return placements
	return []


static func _reserve_stows(items: Array, occupied: Array[int], placements: Array[Dictionary]) -> bool:
	var index := placements.size()
	if index == items.size():
		return true
	var item: Dictionary = items[index]
	var width: int = ArenaSim.TILES[item.id].width
	for row in range(occupied.size()):
		for position in range(STORAGE_COLUMNS - width + 1):
			var cells := ((1 << width) - 1) << position
			if (occupied[row] & cells) != 0:
				continue
			occupied[row] |= cells
			placements.append({"start": item.start, "row": row, "position": position})
			if _reserve_stows(items, occupied, placements):
				return true
			placements.pop_back()
			occupied[row] ^= cells
	return false


static func forge_tiers(id: String) -> Array:
	var family: String = ArenaSim.TILES.get(id, {}).get("family", "")
	return ArenaSim.FORGE_FAMILIES.get(family, [])


static func next_options(id: String) -> Array:
	var tiers := forge_tiers(id)
	for tier in range(tiers.size() - 1):
		if id in tiers[tier]:
			return tiers[tier + 1]
	return []


static func find_copies(lanes: Array, storage: Array, id: String, eligible_lanes: Array,
		preferred := {}) -> Array:
	if next_options(id).is_empty():
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
	var index := copies.find(preferred)
	if index > 0:
		copies.push_front(copies.pop_at(index))
	return copies


static func combine_plan(lanes: Array, storage: Array, matches: Array, count: int, upgrade: String,
		eligible_lanes: Array, keep_first := false) -> Dictionary:
	if matches.size() < count:
		return {}
	var preferred := matches.slice(0, count)
	var width: int = ArenaSim.TILES[upgrade].width
	var positions := _combine_positions(preferred, eligible_lanes, storage.size(), width)
	for position: Dictionary in positions:
		if _combine_fits(lanes, storage, preferred, position, upgrade):
			return {"copies": preferred, "destination": position}
	if matches.size() == count:
		return {}
	# Try other destinations by finding which matching copies block each span.
	for position: Dictionary in _combine_positions(matches, eligible_lanes, storage.size(), width):
		var items := _combine_row(lanes, storage, position)
		var copies := _copies_to_clear_span(items, matches, count, position, width, keep_first)
		if not copies.is_empty():
			return {"copies": copies, "destination": position}
	return {}


static func _combine_positions(copies: Array, eligible_lanes: Array, storage_count: int, width: int) -> Array:
	var groups := []
	for copy: Dictionary in copies:
		var group := {"lane": copy.lane} if not copy.has("row") else {"lane": -1, "row": copy.row}
		if group not in groups:
			groups.append(group)
	for lane: int in eligible_lanes:
		var group := {"lane": lane}
		if group not in groups:
			groups.append(group)
	for row in range(storage_count):
		var group := {"lane": -1, "row": row}
		if group not in groups:
			groups.append(group)

	# Preserve a source slot if it fits before considering other spots.
	var positions := copies.duplicate()
	for group: Dictionary in groups:
		var capacity := STORAGE_COLUMNS if group.has("row") else ArenaSim.BEATS
		for start in range(capacity - width + 1):
			positions.append(group.merged({"start": start}))
	return positions


static func _copies_to_clear_span(items: Array, matches: Array, count: int, position: Dictionary,
		width: int, keep_first: bool) -> Array:
	var start: int = position.start
	var end := start + width
	var capacity := STORAGE_COLUMNS if position.has("row") else ArenaSim.BEATS
	if end > capacity:
		return []
	var copies := [matches[0]] if keep_first else []
	for item: Dictionary in items:
		if item.start >= end or item.start + ArenaSim.TILES[item.id].width <= start:
			continue
		var copy := position.merged({"id": item.id, "start": item.start}, true)
		if copy not in matches:
			return []
		if copy not in copies:
			copies.append(copy)
	if copies.size() > count:
		return []
	for copy: Dictionary in matches:
		if copies.size() == count:
			break
		if copy not in copies:
			copies.append(copy)
	return copies


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
	var enchantment: String = combination_enchantments(lanes, storage, copies, destination, upgrade).kept
	for removal: Dictionary in removals:
		removal.items.erase(removal.item)
	var items := _combine_row(lanes, storage, destination)
	var entry := {"id": upgrade, "start": int(destination.start), "target": target}
	if not enchantment.is_empty():
		entry.enchantment = enchantment
	items.append(entry)
	items.sort_custom(func(a: Dictionary, b: Dictionary): return a.start < b.start)
	return true


static func combination_enchantments(lanes: Array, storage: Array, copies: Array, destination: Dictionary,
		upgrade: String) -> Dictionary:
	var enchantments: Array[String] = []
	var retained := ""
	for copy: Dictionary in copies:
		var items := _combine_row(lanes, storage, copy)
		var index := items.find_custom(func(item: Dictionary): return item.start == copy.start and item.id == copy.id)
		if index < 0:
			continue
		var id: String = items[index].get("enchantment", "")
		if id.is_empty() or id in enchantments:
			continue
		enchantments.append(id)
		if not TileEnchantments.is_eligible(id, ArenaSim.TILES[upgrade], upgrade):
			continue
		var keeps_slot: bool = copy.lane == destination.lane and copy.start == destination.start \
			and copy.get("row", -1) == destination.get("row", -1)
		if retained.is_empty() or keeps_slot:
			retained = id
	enchantments.erase(retained)
	return {"kept": retained, "returned": enchantments}


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
