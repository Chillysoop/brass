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
const BASH_TIERS := [
	["bash"],
	["shield_ram", "hook_bash"],
	["bulwark_charge", "rebound"],
	["sunwall", "graviton"],
	["dawn_bastion", "event_horizon"],
]
const HERO_CLASSES := {
	"warden": {"label": "Warden", "description": "Gain 4 guard on the first Bash-family hit each loop."},
	"bulwark": {"label": "Bulwark", "description": "Reduce the first strike you take each loop by 6."},
	"breaker": {"label": "Breaker", "description": "A push that sends a foe into another deals 5 extra damage to both."},
	"hexwright": {"label": "Hexwright", "description": "Pull tiles draw enemies in with extra force."},
	"wayfarer": {"label": "Wayfarer", "description": "Move faster for three beats after teleporting."},
	"lancer": {"label": "Lancer", "description": "Moving 80 units charges your next hit for 6 bonus damage."},
	"cantor": {"label": "Cantor", "description": "Echo 3 guard to the lowest-HP ally when you grant guard, including yourself."},
	"apothecary": {"label": "Apothecary", "description": "Your first tile hit each loop heals 2 HP. Excess healing becomes guard."},
	"rune_smith": {"label": "Rune Smith", "description": "Finish a tile at least 3 beats wide to charge your next hit for 5 bonus damage."},
	"starshot": {"label": "Starshot", "description": "Deal 5 bonus damage to targets more than 200 units away."},
	"cinder_mage": {"label": "Cinder Mage", "description": "Once per loop, hitting a displaced enemy burns it for 6 damage."},
	"duelist": {"label": "Duelist", "description": "Repeated hits on one target build up to 6 bonus damage. Resets when you switch."}
}
const CAMPAIGN_ENEMIES := {
	"recruit": {"name": "Clockwork Recruit", "art": "clockwork", "hp": 30, "radius": 24.0, "speed": 87.0,
		"spacing": 85.0, "reach": 128.0, "damage": 3, "first": 116, "cooldown": 170, "windup": 27},
	"bruiser": {"name": "Rivet Bruiser", "art": "clockwork", "hp": 134, "radius": 29.0, "speed": 80.0,
		"spacing": 93.0, "reach": 155.0, "damage": 11, "first": 115, "cooldown": 139, "windup": 27, "push": 235.0},
	"scout": {"name": "Clockwork Scout", "art": "scout", "hp": 53, "radius": 17.0, "speed": 68.0,
		"spacing": 145.0, "reach": 224.0, "damage": 7, "first": 157, "cooldown": 143, "windup": 25},
	"veteran": {"name": "Rivet Captain", "art": "clockwork", "hp": 168, "radius": 33.0, "speed": 83.0,
		"spacing": 95.0, "reach": 171.0, "damage": 14, "first": 116, "cooldown": 129, "windup": 31, "push": 310.0},
	"boss": {"name": "The Tollkeeper", "art": "clockwork", "hp": 330, "radius": 40.0, "speed": 86.0,
		"spacing": 107.0, "reach": 204.0, "damage": 16, "first": 125, "cooldown": 123, "windup": 39, "push": 345.0}
}

const TILES := {
	"pull": {
		"label": "Pull", "width": 3, "range": 610.0, "damage": 5,
		"targets": TARGET_RULES, "description": "Drag an enemy toward you."
	},
	"gravity_hook": {
		"label": "Gravity Hook", "width": 3, "range": 720.0, "damage": 8, "rarity": "common",
		"targets": TARGET_RULES, "description": "Reach across the arena and pull an enemy in with extra force."
	},
	"bash": {
		"label": "Bash", "width": 2, "range": 150.0, "damage": 17,
		"family": "bash", "rarity": "common",
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
	},
	"shield_ram": {
		"label": "Shield Ram", "width": 2, "range": 160.0, "damage": 21,
		"family": "bash", "rarity": "uncommon",
		"targets": TARGET_RULES, "description": "Hit and push an enemy. Gain 8 guard."
	},
	"hook_bash": {
		"label": "Hook Bash", "width": 2, "range": 490.0, "damage": 18,
		"family": "bash", "rarity": "uncommon",
		"targets": TARGET_RULES, "description": "Hit at range and pull the enemy toward you."
	},
	"bulwark_charge": {
		"label": "Bulwark Charge", "width": 3, "range": 330.0, "damage": 28,
		"family": "bash", "rarity": "rare",
		"targets": TARGET_RULES, "description": "Rush the target if the path is clear, then hit and push. Gain 12 guard on hit."
	},
	"rebound": {
		"label": "Rebound", "width": 3, "range": 275.0, "damage": 24,
		"family": "bash", "rarity": "rare",
		"targets": TARGET_RULES, "description": "Hit and push. Deal 12 extra damage if the target is still moving from a push or pull."
	},
	"sunwall": {
		"label": "Sunwall", "width": 4, "range": 205.0, "damage": 26,
		"family": "bash", "rarity": "epic",
		"targets": TARGET_RULES, "description": "Push a cluster around the target. Give 14 guard to yourself and nearby allies."
	},
	"graviton": {
		"label": "Graviton", "width": 4, "range": 540.0, "damage": 28,
		"family": "bash", "rarity": "epic",
		"targets": TARGET_RULES, "description": "Hit and reel in the target. Pull nearby enemies into the impact point."
	},
	"dawn_bastion": {
		"label": "Dawn Bastion", "width": 5, "range": 260.0, "damage": 38,
		"family": "bash", "rarity": "legendary",
		"targets": TARGET_RULES, "description": "Hit and scatter a cluster around the target. Give every living ally 22 guard."
	},
	"event_horizon": {
		"label": "Event Horizon", "width": 6, "range": 620.0, "damage": 39,
		"family": "bash", "rarity": "legendary",
		"targets": TARGET_RULES, "description": "Damage and pull enemies around the target. Interrupt their active windups."
	},
	"meteor_seal": {
		"label": "Meteor Seal", "width": 5, "range": 580.0, "damage": 42, "rarity": "legendary",
		"targets": TARGET_RULES, "description": "Drop a meteor on the target, damaging nearby enemies."
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


func start(hero_lanes: Array, fixture: String = "duo", options: Dictionary = {}) -> void:
	tick = 0
	outcome = ""
	units.clear()
	trace.clear()
	_events.clear()
	_lanes.clear()
	var solo := fixture == "solo" or not options.is_empty()
	if not options.is_empty():
		_start_campaign(options)
	elif solo:
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


func _start_campaign(options: Dictionary) -> void:
	var hero_id: String = options.get("hero", "warden")
	var hero: Dictionary = HERO_CLASSES.get(hero_id, HERO_CLASSES.warden)
	var max_hp := maxi(1, int(options.get("max_hp", 100)))
	var unit := _unit("hero_1", hero.label, "hero", 0, Vector2(285, 265), max_hp, 23.0, 153.0, 86.0)
	unit.hp = clampi(int(options.get("hp", max_hp)), 0, max_hp)
	unit["class"] = hero_id
	unit["relics"] = options.get("relics", []).duplicate()
	var relic: String = options.get("relic", "")
	if not relic.is_empty() and relic not in unit.relics:
		unit.relics.append(relic)
	units.append(unit)

	var rng := RandomNumberGenerator.new()
	rng.seed = int(options.get("seed", 0))
	var y := rng.randf_range(217.0, 289.0)
	match options.get("encounter", "opening"):
		"battle":
			if rng.randi_range(0, 1) == 0:
				_add_campaign_enemy("bruiser", Vector2(615, y))
			else:
				_add_campaign_enemy("scout", Vector2(583, y - 58.0))
				_add_campaign_enemy("scout", Vector2(684, y + 72.0), 20)
		"elite":
			_add_campaign_enemy("veteran", Vector2(636, y))
			_add_campaign_enemy("scout", Vector2(673, y + 113.0))
		"boss":
			_add_campaign_enemy("boss", Vector2(647, y))
		_:
			_add_campaign_enemy("recruit", Vector2(522, y))


func _add_campaign_enemy(kind: String, position: Vector2, delay := 0) -> void:
	var spec: Dictionary = CAMPAIGN_ENEMIES[kind]
	var enemy := _unit("%s_%d" % [kind, units.size()], spec.name, "enemy", -1, position,
		spec.hp, spec.radius, spec.speed, spec.spacing)
	enemy["attack"] = spec
	enemy["sprite"] = spec.art
	enemy.next_attack = int(spec.first) + delay
	units.append(enemy)


func step() -> Array[Dictionary]:
	_events = []
	if outcome != "" or units.is_empty():
		return _events
	tick += 1
	if (tick - 1) % LOOP_TICKS == 0:
		for unit in units:
			if unit.hp > 0 and _has_relic(unit, "pocket_bell"):
				_guard(unit, 5, "pocket_bell")
	_move_units()
	if tick % TICKS_PER_BEAT == 0:
		_activate_lanes()
	_run_enemies()
	_run_burns()
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
			if tick < unit.get("haste_until", 0):
				speed *= 1.42
			var margin: float = distance - unit.preferred_range
			drive = offset.normalized() * clampf(margin * 4.0, 0.0, speed)
		var impulse: Vector2 = unit.impulse
		unit.velocity = drive + impulse
		unit.impulse = impulse.move_toward(Vector2.ZERO, IMPULSE_DECAY * DELTA)
		var next := _bounded(position + unit.velocity * DELTA, unit.radius)
		if unit.get("class") == "lancer":
			unit["travel"] = minf(80.0, unit.get("travel", 0.0) + position.distance_to(next))
		next_positions.append(next)
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
			_breaker_collision(units[i], units[j])
			_breaker_collision(units[j], units[i])
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
				if actor.get("class") == "rune_smith" and TILES[tile.id].width >= 3:
					actor["rune_charged"] = true


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
		"pull", "gravity_hook":
			var force := 935.0 if tile_id == "gravity_hook" else 735.0
			if actor.name == "Hexwright":
				force += 155.0
			var direction: Vector2 = actor.pos - target.pos
			_displace("pull", actor, target, tile_id, direction, force)
			_damage(actor, target, tile.damage, tile_id)
		"bash":
			_strike_and_push(actor, target, tile_id, tile.damage, 600.0)
		"shield_ram":
			_strike_and_push(actor, target, tile_id, tile.damage, 635.0)
			_guard(actor, 8, tile_id)
		"hook_bash":
			_damage(actor, target, tile.damage, tile_id)
			_pull_toward(actor, target, tile_id, actor.pos, 780.0)
		"bulwark_charge":
			if _charge(actor, target, tile_id):
				_strike_and_push(actor, target, tile_id, tile.damage, 810.0)
				_guard(actor, 12, tile_id)
			else:
				_emit("miss", "%s: Bulwark Charge has no clear path." % actor.name, actor, target, tile_id)
				return
		"rebound":
			var impulse: Vector2 = target.impulse
			var bonus := 12 if not impulse.is_zero_approx() else 0
			_strike_and_push(actor, target, tile_id, tile.damage + bonus, 710.0)
		"sunwall":
			_area_push(actor, target, tile_id, tile.damage, 155.0, 650.0)
			_guard_allies(actor, tile_id, 14, 235.0)
		"graviton":
			_gravity_strike(actor, target, tile_id, 170.0, false)
		"dawn_bastion":
			_area_push(actor, target, tile_id, tile.damage, 205.0, 875.0)
			_guard_allies(actor, tile_id, 22)
		"event_horizon":
			_gravity_strike(actor, target, tile_id, 245.0, true)
		"blink":
			if _teleport(actor, target):
				_damage(actor, target, tile.damage, tile_id)
			else:
				_emit("miss", "%s: Blink had no clear landing." % actor.name, actor, target, tile_id)
		"slam":
			_area_push(actor, target, tile_id, tile.damage, 115.0, 520.0)
		"shot":
			_damage(actor, target, tile.damage, tile_id)
		"meteor_seal":
			for enemy in _enemies_in_area(actor, target.pos, 175.0):
				_damage(actor, enemy, tile.damage, tile_id)
	if tile.get("family") == "bash":
		_warden_guard(actor, tile_id)


func _warden_guard(actor: Dictionary, tile_id: String) -> void:
	var loop_index := floori(float(tick - 1) / LOOP_TICKS)
	if actor.name == "Warden" and actor.last_bash_loop != loop_index:
		actor.last_bash_loop = loop_index
		_guard(actor, 4, tile_id)


func _strike_and_push(actor: Dictionary, target: Dictionary, tile_id: String, damage: int, force: float) -> void:
	_damage(actor, target, damage, tile_id)
	if target.hp > 0:
		_displace("push", actor, target, tile_id, target.pos - actor.pos, force)


func _area_push(actor: Dictionary, target: Dictionary, tile_id: String, damage: int, radius: float, force: float) -> void:
	for enemy in _enemies_in_area(actor, target.pos, radius):
		_strike_and_push(actor, enemy, tile_id, damage, force)


func _enemies_in_area(actor: Dictionary, center: Vector2, radius: float) -> Array[Dictionary]:
	var affected: Array[Dictionary] = []
	for enemy in units:
		var point: Vector2 = enemy.pos
		if enemy.side != actor.side and enemy.hp > 0 and point.distance_to(center) <= radius:
			affected.append(enemy)
	return affected


func _guard_allies(actor: Dictionary, tile_id: String, amount: int, radius: float = INF) -> void:
	var position: Vector2 = actor.pos
	for ally in units:
		if ally.side == actor.side and ally.hp > 0 and position.distance_to(ally.pos) <= radius:
			_guard(ally, amount, tile_id, actor)


func _gravity_strike(actor: Dictionary, target: Dictionary, tile_id: String, radius: float, collapse: bool) -> void:
	var impact: Vector2 = target.pos
	for enemy in _enemies_in_area(actor, impact, radius):
		if enemy.id == target.id or collapse:
			_damage(actor, enemy, TILES[tile_id].damage, tile_id)
		if collapse and enemy.intent != "":
			enemy.intent = ""
			enemy.next_attack = tick + TICKS_PER_BEAT * 3
			_emit("interrupt", "%s interrupts %s." % [TILES[tile_id].label, enemy.name], actor, enemy, tile_id)
		var center: Vector2 = actor.pos if enemy.id == target.id else impact
		_pull_toward(actor, enemy, tile_id, center, 990.0 if collapse else 860.0)


func _pull_toward(actor: Dictionary, enemy: Dictionary, tile_id: String, center: Vector2, force: float) -> void:
	var offset: Vector2 = center - enemy.pos
	if enemy.hp > 0 and offset.length_squared() > 0.001:
		_displace("pull", actor, enemy, tile_id, offset, force + (90.0 if actor.get("class") == "hexwright" else 0.0))


func _charge(actor: Dictionary, target: Dictionary, tile_id: String) -> bool:
	var origin: Vector2 = actor.pos
	var destination: Vector2 = target.pos
	var direction := origin.direction_to(destination)
	var clearance: float = actor.radius + target.radius + 18.0
	if origin.distance_to(destination) <= clearance:
		return true
	var landing := _bounded(destination - direction * clearance, actor.radius)
	for unit in units:
		if unit.hp <= 0 or unit.id == actor.id:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(unit.pos, origin, landing)
		if closest.distance_to(unit.pos) < actor.radius + unit.radius + 5.0:
			return false
	actor.pos = landing
	actor.impulse = Vector2.ZERO
	_emit("charge", "%s charges toward %s." % [actor.name, target.name], actor, target, tile_id, 0, origin, landing)
	return true


func _displace(kind: String, actor: Dictionary, target: Dictionary, tile_id: String, offset: Vector2, force: float) -> void:
	if kind == "push":
		if _has_relic(actor, "copper_compass") and actor.get("compass_loop", -1) != _loop_index():
			actor["compass_loop"] = _loop_index()
			force += 145.0
		if actor.get("class") == "breaker":
			target["breaker_source"] = actor.id
			target["breaker_until"] = tick + 24
	if target.get("attack", {}).get("name") == "The Tollkeeper":
		force *= 0.55
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
		if actor.get("class") == "wayfarer":
			actor["haste_until"] = tick + TICKS_PER_BEAT * 3
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
		var attack: Dictionary = enemy.get("attack", {})
		var reach: float = attack.get("reach", 290.0 if enemy.id == "scout" else 155.0)
		if position.distance_to(target.pos) > reach:
			continue
		enemy.intent = target.id
		enemy.intent_tick = tick + int(attack.get("windup", 24))
		_emit("intent", "%s winds up at %s." % [enemy.name, target.name], enemy, target, "enemy_attack")


func _resolve_intent(enemy: Dictionary) -> void:
	var intent: String = enemy.intent
	var attack: Dictionary = enemy.get("attack", {})
	enemy.intent = ""
	enemy.next_attack = tick + int(attack.get("cooldown", 116 if enemy.id == "scout" else 138))
	var position: Vector2 = enemy.pos
	var reach: float = attack.get("reach", 290.0 if enemy.id == "scout" else 155.0)
	for target in units:
		if target.id != intent or target.hp <= 0:
			continue
		if position.distance_to(target.pos) > reach:
			_emit("miss", "%s's windup misses %s." % [enemy.name, target.name], enemy, target, "enemy_attack")
			return
		var damage: int = attack.get("damage", 9 if enemy.id == "scout" else 21)
		if enemy.get("enraged", false):
			damage += 3
		_damage(enemy, target, damage, "enemy_attack")
		var force: float = attack.get("push", 430.0 if enemy.id == "clockwork" else 0.0)
		if force > 0.0 and target.hp > 0:
			var offset: Vector2 = target.pos - position
			_displace("push", enemy, target, "enemy_attack", offset, force)
		return


func _guard(recipient: Dictionary, amount: int, tile_id: String, source: Dictionary = {}, echo := true) -> void:
	var gain := mini(amount, 28 - recipient.guard)
	recipient.guard += gain
	if gain > 0:
		var actor := recipient if source.is_empty() else source
		_emit("guard", "%s gains %d guard." % [recipient.name, gain], actor, recipient, tile_id, gain)
		if echo and actor.get("class") == "cantor":
			var weakest := recipient
			for ally in units:
				if ally.side == actor.side and ally.hp > 0 and ally.hp < weakest.hp:
					weakest = ally
			_guard(weakest, 3, "cantor", actor, false)


func _damage(actor: Dictionary, target: Dictionary, amount: int, tile_id: String) -> void:
	if target.hp <= 0:
		return
	if TILES.has(tile_id):
		amount = _class_attack_damage(actor, target, amount)
	if tile_id == "enemy_attack" and target.get("class") == "bulwark" and target.get("bulwark_loop", -1) != _loop_index():
		target["bulwark_loop"] = _loop_index()
		amount = maxi(0, amount - 6)
	var blocked := mini(amount, target.guard)
	target.guard -= blocked
	var dealt := mini(amount - blocked, target.hp)
	target.hp -= dealt
	var action: String = TILES[tile_id].label if TILES.has(tile_id) else "Strike"
	if tile_id == "cinder_mage":
		action = "Burn"
	elif tile_id == "breaker":
		action = "Collision"
	var blocked_text := " (%d blocked)" % blocked if blocked > 0 else ""
	var details := "%s: %s hits %s for %d%s." % [actor.name, action, target.name, dealt, blocked_text]
	_emit("hit", details, actor, target, tile_id, dealt)
	if target.hp == 0:
		target.velocity = Vector2.ZERO
		target.impulse = Vector2.ZERO
		target.intent = ""
		_emit("defeat_unit", "%s falls." % target.name, actor, target, tile_id)
	elif target.name == "The Tollkeeper" and target.hp * 2 <= target.max_hp and not target.get("enraged", false):
		target["enraged"] = true
		target.next_attack = mini(target.next_attack, tick + 20)
		_guard(target, 11, "tollkeeper_rallies")
		_emit("intent", "The Tollkeeper rallies. Its strikes now hit harder.", target, actor, "enemy_attack")


func _class_attack_damage(actor: Dictionary, target: Dictionary, amount: int) -> int:
	match actor.get("class", ""):
		"lancer":
			if actor.get("travel", 0.0) >= 80.0:
				actor["travel"] = 0.0
				amount += 6
		"apothecary":
			if actor.get("heal_loop", -1) != _loop_index():
				actor["heal_loop"] = _loop_index()
				var healed := mini(2, actor.max_hp - actor.hp)
				actor.hp += healed
				if healed > 0:
					_emit("heal", "Apothecary restores %d HP." % healed, actor, actor, "apothecary", healed)
				if healed < 2:
					_guard(actor, 2 - healed, "apothecary")
		"rune_smith":
			if actor.get("rune_charged", false):
				actor["rune_charged"] = false
				amount += 5
		"starshot":
			var position: Vector2 = actor.pos
			if position.distance_squared_to(target.pos) > 200.0 * 200.0:
				amount += 5
		"cinder_mage":
			var impulse: Vector2 = target.impulse
			if impulse.length_squared() > 1.0 and actor.get("burn_loop", -1) != _loop_index():
				actor["burn_loop"] = _loop_index()
				target["burn_source"] = actor.id
				target["burn_tick"] = tick + TICKS_PER_BEAT
				target["burn_left"] = 2
		"duelist":
			var streak := 0
			if actor.get("focus_target", "") == target.id:
				streak = mini(3, actor.get("focus_streak", 0) + 1)
			actor["focus_target"] = target.id
			actor["focus_streak"] = streak
			amount += 2 * streak
	return amount


func _run_burns() -> void:
	for target in units:
		if target.hp <= 0 or target.get("burn_left", 0) == 0 or tick < target.get("burn_tick", 0):
			continue
		var source := _find_unit(target.burn_source)
		target.burn_left -= 1
		target.burn_tick += TICKS_PER_BEAT
		if not source.is_empty():
			_damage(source, target, 3, "cinder_mage")


func _breaker_collision(moving: Dictionary, other: Dictionary) -> void:
	if moving.hp <= 0 or other.hp <= 0 or moving.side != other.side or tick > moving.get("breaker_until", -1):
		return
	var impulse: Vector2 = moving.impulse
	var contact: Vector2 = other.pos - moving.pos
	if impulse.dot(contact.normalized()) < 100.0:
		return
	var source := _find_unit(moving.get("breaker_source", ""))
	if source.is_empty():
		return
	moving["breaker_until"] = -1
	_damage(source, moving, 5, "breaker")
	_damage(source, other, 5, "breaker")


func _find_unit(id: String) -> Dictionary:
	for unit in units:
		if unit.id == id:
			return unit
	return {}


func _has_relic(unit: Dictionary, relic: String) -> bool:
	return relic in unit.get("relics", [])


func _loop_index() -> int:
	return (tick - 1) / LOOP_TICKS


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
