extends RefCounted

const ArenaSim = preload("res://scripts/arena_sim.gd")
const GameIcons = preload("res://scripts/game_icons.gd")
const METRICS := ["damage", "assists", "kills", "healing"]
const MAX_SAVED_ROWS := 3 * ArenaSim.BEATS
const MAX_SAVED_TOTAL := 10000000

var _rows := {}
var _contributors := {}
var _defeated := {}


func reset() -> void:
	_rows.clear()
	_contributors.clear()
	_defeated.clear()


func record(events: Array, units: Array) -> bool:
	if events.is_empty():
		return false
	var by_id := {}
	for unit: Dictionary in units:
		by_id[unit.id] = unit
	var changed := false
	for event: Dictionary in events:
		var kind: String = event.get("kind", "")
		if kind not in ["hit", "heal", "push", "pull", "defeat_unit"]:
			continue
		var actor: Dictionary = by_id.get(event.get("actor", ""), {})
		var target: Dictionary = by_id.get(event.get("target", ""), {})
		var source := _source(actor, event)
		var amount := int(event.get("amount", 0))
		if kind == "heal" and not source.is_empty() and target.get("side") == "hero" and amount > 0:
			_count(source, "healing", amount)
			changed = true
		if target.get("side") != "enemy" or _defeated.has(target.id):
			continue
		if kind == "defeat_unit":
			_defeated[target.id] = true
			var contributors: Dictionary = _contributors.get(target.id, {})
			_contributors.erase(target.id)
			if source.is_empty():
				continue
			_count(source, "kills", 1)
			var killer := _key(source)
			for key: String in contributors:
				if key != killer:
					_count(contributors[key], "assists", 1)
			changed = true
			continue
		if source.is_empty():
			continue
		if kind == "hit":
			if amount > 0:
				_count(source, "damage", amount)
				changed = true
			if amount > 0 or int(event.get("blocked", 0)) > 0:
				_mark_contributor(target.id, source)
		elif kind in ["push", "pull"]:
			var start: Vector2 = event.get("from", Vector2.ZERO)
			if not start.is_equal_approx(event.get("to", Vector2.ZERO)):
				_mark_contributor(target.id, source)
	return changed


func _source(actor: Dictionary, event: Dictionary) -> Dictionary:
	var tile: String = event.get("source_tile", event.get("tile", ""))
	if actor.get("side") != "hero" or not ArenaSim.TILES.has(tile):
		return {}
	var hero: String = actor.name
	var class_id: String = actor.get("class", GameIcons.hero_class_for_label(hero))
	return {"actor": actor.id, "tile": tile, "lane": actor.lane, "hero": hero, "class_id": class_id}


func _key(source: Dictionary) -> String:
	return "%s/%s" % [source.actor, source.tile]


func _mark_contributor(enemy_id: String, source: Dictionary) -> void:
	var contributors: Dictionary = _contributors.get_or_add(enemy_id, {})
	contributors[_key(source)] = source


func _count(source: Dictionary, metric: String, amount: int) -> void:
	var key := _key(source)
	if not _rows.has(key):
		var row := source.duplicate()
		for field: String in METRICS:
			row[field] = 0
		_rows[key] = row
	_rows[key][metric] += amount


func ranked(metric: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if metric not in METRICS:
		return rows
	for row: Dictionary in _rows.values():
		if row[metric] > 0:
			rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a[metric] != b[metric]:
			return a[metric] > b[metric]
		if a.lane != b.lane:
			return a.lane < b.lane
		return ArenaSim.TILES[a.tile].label.naturalnocasecmp_to(ArenaSim.TILES[b.tile].label) < 0
	)
	return rows


func snapshot() -> Dictionary:
	return {"rows": _rows.values().duplicate(true)}


func restore(data: Variant) -> void:
	reset()
	if not data is Dictionary:
		return
	var saved: Variant = data.get("rows", [])
	if not saved is Array:
		return
	for candidate: Variant in saved.slice(0, MAX_SAVED_ROWS):
		if not candidate is Dictionary:
			continue
		var tile: Variant = candidate.get("tile", "")
		var class_id: Variant = candidate.get("class_id", "")
		var lane := _saved_number(candidate.get("lane", -1), 2)
		if lane < 0 or not tile is String or not ArenaSim.TILES.has(tile) \
				or not class_id is String or not ArenaSim.HERO_CLASSES.has(class_id):
			continue
		var source := {"lane": lane, "actor": "hero_%d" % (lane + 1), "tile": tile,
			"class_id": class_id, "hero": GameIcons.hero_label(class_id)}
		if _rows.has(_key(source)):
			continue
		for metric: String in METRICS:
			var value := _saved_number(candidate.get(metric, 0), MAX_SAVED_TOTAL)
			if value > 0:
				_count(source, metric, value)


func _saved_number(value: Variant, maximum: int) -> int:
	if not (value is int or value is float):
		return -1
	var number := float(value)
	if not is_finite(number) or number < 0 or number > maximum or floorf(number) != number:
		return -1
	return int(number)
