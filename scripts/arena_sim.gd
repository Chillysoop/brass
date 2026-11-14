extends RefCounted

const BEATS := 12
const TICKS_PER_BEAT := 21
const TICKS_PER_SECOND := 60
const LOOP_TICKS := BEATS * TICKS_PER_BEAT
const ARENA_SIZE := Vector2(1000, 520)
const WALL_MARGIN := 26.0
const IMPULSE_CAP := 1000.0
const IMPULSE_DECAY := 1850.0
const TARGET_RULES := ["nearest", "farthest", "lowest_hp", "highest_hp"]

const TILES := {
	"pull": {
		"label": "Pull", "width": 3, "range": 610.0, "damage": 5,
		"targets": TARGET_RULES, "description": "Drag an enemy toward you."
	},
	"bash": {
		"label": "Bash", "width": 2, "range": 150.0, "damage": 17,
		"targets": TARGET_RULES, "description": "Hit an enemy and knock them back."
	},
	"guard": {
		"label": "Guard", "width": 2, "range": 0.0, "damage": 0,
		"targets": ["self"], "description": "Gain 10 guard to absorb incoming damage."
	},
	"shot": {
		"label": "Shot", "width": 2, "range": 535.0, "damage": 14,
		"targets": TARGET_RULES, "description": "Strike one enemy at range."
	},
	"blink": {
		"label": "Blink", "width": 3, "range": 430.0, "damage": 8,
		"targets": TARGET_RULES, "description": "Teleport behind an enemy and strike."
	},
	"slam": {
		"label": "Slam", "width": 4, "range": 190.0, "damage": 20,
		"targets": TARGET_RULES, "description": "Strike near the target and push every enemy caught in the impact."
	}
}

var units: Array[Dictionary] = []
var trace: Array[Dictionary] = []
var tick := 0
var outcome := ""

var _lanes: Array[Array] = []
var _events: Array[Dictionary] = []


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


func start(hero_lanes: Array, fixture: String = "duo") -> void:
	tick = 0
	outcome = ""
	units.clear()
	trace.clear()
	_events.clear()
	_lanes.clear()
	var solo := fixture == "solo"
	if solo:
		units.append(_unit("hero_1", "Warden", "hero", 0, Vector2(270, 270), 165, 23.0, 122.0, 92.0))
		units.append(_unit("clockwork", "Clockwork", "enemy", -1, Vector2(715, 254), 273, 32.0, 75.0, 112.0))
	else:
		units.append(_unit("hero_1", "Hexwright", "hero", 0, Vector2(220, 228), 74, 20.0, 90.0, 225.0))
		units.append(_unit("hero_2", "Warden", "hero", 1, Vector2(270, 302), 100, 23.0, 122.0, 96.0))
		units.append(_unit("clockwork", "Clockwork", "enemy", -1, Vector2(720, 251), 265, 32.0, 68.0, 108.0))
		units.append(_unit("scout", "Clockwork Scout", "enemy", -1, Vector2(490, 154), 49, 17.0, 40.0, 155.0))
	for lane in range(1 if solo else 2):
		var tiles: Array = hero_lanes[lane] if lane < hero_lanes.size() else []
		_lanes.append(_valid_tiles(tiles))


func step() -> Array[Dictionary]:
	_events = []
	if outcome != "" or units.is_empty():
		return _events
	tick += 1
	_move_units()
	if tick % TICKS_PER_BEAT == 0:
		_activate_lanes()
	_run_enemies()
	if tick >= 3600 and tick % 30 == 0:
		_end_stalemate()
	_check_outcome()
	if tick % LOOP_TICKS == 0 and outcome == "":
		_emit("loop", "%d loops complete." % floori(float(tick) / LOOP_TICKS))
	return _events


func target_for(lane: int, tile_id: String, rule: String) -> Dictionary:
	if not TILES.has(tile_id) or lane < 0 or lane >= _lanes.size():
		return {}
	var actor: Dictionary = units[lane]
	if actor.hp <= 0:
		return {}
	if tile_id == "guard":
		return actor
	return _select(actor, rule, TILES[tile_id].range)


func _unit(id: String, unit_name: String, side: String, lane: int, position: Vector2, health: int, radius: float, speed: float, preferred_range: float) -> Dictionary:
	return {
		"id": id, "name": unit_name, "side": side, "lane": lane, "pos": position, "prev_pos": position,
		"hp": health, "max_hp": health, "guard": 0, "radius": radius, "velocity": Vector2.ZERO,
		"impulse": Vector2.ZERO, "speed": speed, "preferred_range": preferred_range, "last_bash_loop": -1,
		"intent": "", "intent_tick": 0, "next_attack": 112 if id == "scout" else 146
	}


func _valid_tiles(tiles: Array) -> Array:
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
		if not spec.targets.has(rule):
			rule = spec.targets[0]
		validated.append({"id": id, "start": start_beat, "end": end_beat, "target": rule})
	return validated


func _move_units() -> void:
	const DELTA := 1.0 / TICKS_PER_SECOND
	var next_positions: Array[Vector2] = []
	for unit in units:
		var position: Vector2 = unit.pos
		unit.prev_pos = position
		if unit.hp <= 0:
			next_positions.append(position)
			continue
		var focus := _select(unit, "nearest")
		var drive := Vector2.ZERO
		if not focus.is_empty() and unit.intent == "":
			var offset: Vector2 = focus.pos - position
			var distance := offset.length()
			var speed: float = unit.speed
			var margin: float = distance - unit.preferred_range
			drive = offset.normalized() * clampf(margin * 4.0, 0.0, speed)
		var impulse: Vector2 = unit.impulse
		unit.velocity = drive + impulse
		unit.impulse = impulse.move_toward(Vector2.ZERO, IMPULSE_DECAY * DELTA)
		next_positions.append(_bounded(position + unit.velocity * DELTA, unit.radius))
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
			var direction := offset / distance if distance > 0.001 else Vector2.RIGHT
			var separation := direction * minf((minimum - distance) * 0.32, 10.0)
			next_positions[i] = _bounded(next_positions[i] - separation, units[i].radius)
			next_positions[j] = _bounded(next_positions[j] + separation, units[j].radius)
	for i in range(units.size()):
		units[i].pos = next_positions[i]


func _bounded(position: Vector2, radius: float) -> Vector2:
	var margin := WALL_MARGIN + radius
	return Vector2(clampf(position.x, margin, ARENA_SIZE.x - margin), clampf(position.y, margin, ARENA_SIZE.y - margin))


func _select(actor: Dictionary, rule: String, reach: float = INF) -> Dictionary:
	var best := {}
	var best_score := INF
	for candidate in units:
		if candidate.side == actor.side or candidate.hp <= 0:
			continue
		var position: Vector2 = actor.pos
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
		if score < best_score:
			best = candidate
			best_score = score
	return best


func _activate_lanes() -> void:
	var current_beat := _beat()
	for lane in range(_lanes.size()):
		var actor: Dictionary = units[lane]
		if actor.hp <= 0:
			continue
		for tile in _lanes[lane]:
			if tile.end == current_beat:
				_cast(actor, tile.id, tile.target)


func _cast(actor: Dictionary, tile_id: String, rule: String) -> void:
	var tile: Dictionary = TILES[tile_id]
	if tile_id == "guard":
		_guard(actor, 10, tile_id)
		return
	var target := _select(actor, rule, tile.range)
	if target.is_empty():
		var out_of_range := _select(actor, rule)
		if not out_of_range.is_empty():
			_emit("miss", "%s: %s was out of range." % [actor.name, tile.label], actor, out_of_range, tile_id)
		return
	match tile_id:
		"pull":
			var force := 890.0 if actor.name == "Hexwright" else 735.0
			var direction: Vector2 = actor.pos - target.pos
			_displace("pull", actor, target, tile_id, direction, force)
			_damage(actor, target, tile.damage, tile_id)
		"bash":
			var direction: Vector2 = target.pos - actor.pos
			_damage(actor, target, tile.damage, tile_id)
			if target.hp > 0:
				_displace("push", actor, target, tile_id, direction, 600.0)
			var loop_index := floori(float(tick - 1) / LOOP_TICKS)
			if actor.name == "Warden" and actor.last_bash_loop != loop_index:
				actor.last_bash_loop = loop_index
				_guard(actor, 4, tile_id)
		"blink":
			if _teleport(actor, target):
				_damage(actor, target, tile.damage, tile_id)
			else:
				_emit("miss", "%s: Blink had no clear landing." % actor.name, actor, target, tile_id)
		"slam":
			var impact: Vector2 = target.pos
			for enemy in units:
				var point: Vector2 = enemy.pos
				if enemy.side != actor.side and enemy.hp > 0 and point.distance_to(impact) <= 115.0:
					_damage(actor, enemy, tile.damage, tile_id)
					if enemy.hp > 0:
						_displace("push", actor, enemy, tile_id, point - actor.pos, 520.0)
		"shot":
			_damage(actor, target, tile.damage, tile_id)


func _displace(kind: String, actor: Dictionary, target: Dictionary, tile_id: String, offset: Vector2, force: float) -> void:
	var direction := offset.normalized() if offset.length_squared() > 0.001 else Vector2.RIGHT
	var start_position: Vector2 = target.pos
	var impulse: Vector2 = target.impulse + direction * force
	target.impulse = impulse.limit_length(IMPULSE_CAP)
	var launch: Vector2 = target.impulse
	var endpoint := _bounded(start_position + launch.normalized() * (launch.length_squared() / (2.0 * IMPULSE_DECAY)), target.radius)
	var action := "pulls" if kind == "pull" else "knocks back"
	_emit(kind, "%s %s %s." % [actor.name, action, target.name], actor, target, tile_id, roundi(force), start_position, endpoint)


func _teleport(actor: Dictionary, target: Dictionary) -> bool:
	var start_position: Vector2 = actor.pos
	var target_position: Vector2 = target.pos
	var direction := start_position.direction_to(target_position)
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var spacing: float = target.radius + actor.radius + 22.0
	for angle in [0.0, 0.52, -0.52, 1.05, -1.05, PI / 2.0, -PI / 2.0, PI]:
		var landing := _bounded(target_position + direction.rotated(angle) * spacing, actor.radius)
		if not _free_position(landing, actor):
			continue
		actor.pos = landing
		actor.prev_pos = landing
		actor.velocity = Vector2.ZERO
		actor.impulse = Vector2.ZERO
		_emit("teleport", "%s blinks beside %s." % [actor.name, target.name], actor, target, "blink", 0, start_position, landing)
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
		if enemy.intent != "":
			if tick >= enemy.intent_tick:
				_resolve_intent(enemy)
			continue
		if tick < enemy.next_attack:
			continue
		var target := _select(enemy, "nearest")
		if target.is_empty():
			continue
		var position: Vector2 = enemy.pos
		var reach := 290.0 if enemy.id == "scout" else 155.0
		if position.distance_to(target.pos) > reach:
			continue
		enemy.intent = target.id
		enemy.intent_tick = tick + 24
		_emit("intent", "%s winds up at %s." % [enemy.name, target.name], enemy, target, "enemy_attack")


func _resolve_intent(enemy: Dictionary) -> void:
	var intent: String = enemy.intent
	enemy.intent = ""
	enemy.next_attack = tick + (116 if enemy.id == "scout" else 138)
	var position: Vector2 = enemy.pos
	var reach := 290.0 if enemy.id == "scout" else 155.0
	for target in units:
		if target.id != intent or target.hp <= 0:
			continue
		if position.distance_to(target.pos) > reach:
			_emit("miss", "%s's windup misses %s." % [enemy.name, target.name], enemy, target, "enemy_attack")
			return
		var damage := 9 if enemy.id == "scout" else 21
		_damage(enemy, target, damage, "enemy_attack")
		if enemy.id == "clockwork" and target.hp > 0:
			var offset: Vector2 = target.pos - position
			_displace("push", enemy, target, "enemy_attack", offset, 430.0)
		return


func _guard(actor: Dictionary, amount: int, tile_id: String) -> void:
	var gain := mini(amount, 28 - actor.guard)
	actor.guard += gain
	if gain > 0:
		_emit("guard", "%s gains %d guard." % [actor.name, gain], actor, actor, tile_id, gain)


func _damage(actor: Dictionary, target: Dictionary, amount: int, tile_id: String) -> void:
	var blocked := mini(amount, target.guard)
	target.guard -= blocked
	var dealt := mini(amount - blocked, target.hp)
	target.hp -= dealt
	var action: String = TILES[tile_id].label if TILES.has(tile_id) else "Strike"
	var blocked_text := " (%d blocked)" % blocked if blocked > 0 else ""
	var details := "%s: %s hits %s for %d%s." % [actor.name, action, target.name, dealt, blocked_text]
	_emit("hit", details, actor, target, tile_id, dealt)
	if target.hp == 0:
		target.velocity = Vector2.ZERO
		target.impulse = Vector2.ZERO
		target.intent = ""
		_emit("defeat_unit", "%s falls." % target.name, actor, target, tile_id)


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
	elif not alive_enemy:
		outcome = "victory"
	if outcome != "":
		_emit("outcome", "Victory. The arena is clear." if outcome == "victory" else "Defeat. The crew has fallen.")


func _beat() -> int:
	return 0 if tick == 0 else floori(float((tick - 1) % LOOP_TICKS) / TICKS_PER_BEAT) + 1


func _emit(kind: String, message: String, actor: Dictionary = {}, target: Dictionary = {}, tile_id: String = "", amount: int = 0, start_position: Vector2 = Vector2.INF, end_position: Vector2 = Vector2.INF) -> void:
	var event := {
		"kind": kind, "tick": tick, "beat": _beat(), "actor": actor.get("id", ""), "target": target.get("id", ""),
		"tile": tile_id, "amount": amount, "message": message,
		"from": actor.get("pos", Vector2.ZERO) if start_position == Vector2.INF else start_position,
		"to": target.get("pos", Vector2.ZERO) if end_position == Vector2.INF else end_position
	}
	trace.append(event)
	_events.append(event)
