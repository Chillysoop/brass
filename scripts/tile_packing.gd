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
