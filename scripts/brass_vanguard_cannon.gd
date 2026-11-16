extends RefCounted

const BOSS_ID := "brass_vanguard_cannon"
const VANGUARD := "brass_vanguard"
const CANNON := "brass_cannon"
const CHARGE := "brass_vanguard_charge"
const SHOT := "brass_cannon_shot"
const IMPACT := "brass_cannon_impact"
const DISRUPTED := "brass_duo_disrupted"

const ENEMIES := {
	VANGUARD: {"name": "Vanguard Captain", "art": VANGUARD, "hp": 650,
		"radius": 35.0, "speed": 116.0, "spacing": 106.0, "reach": 405.0,
		"damage": 34, "first": 71, "cooldown": 100, "windup": 33, "push": 480.0, "displacement": 0.80,
		"aim_width": 43.0, "alignment": 63.0, "overrun": 35.0},
	CANNON: {"name": "Siege Cannoneer", "art": CANNON, "hp": 560,
		"radius": 42.0, "speed": 54.0, "spacing": 435.0, "reach": 795.0,
		"damage": 39, "first": 102, "cooldown": 139, "windup": 63, "target": "farthest", "displacement": 0.88,
		"aim_width": 40.0, "alignment": 50.0, "splash_radius": 105.0, "splash_damage": 12},
}


static func spawn(sim, height: float, seed: int) -> void:
	var cannon_forward := ((seed ^ (seed >> 8)) & 1) != 0
	var flank := 1.0 if ((seed ^ (seed >> 10)) & 2) == 0 else -1.0
	var vanguard := Vector2(802, height - 112.0 * flank) if cannon_forward else Vector2(626, height - 84.0)
	var cannon := Vector2(555, height + 78.0 * flank) if cannon_forward else Vector2(759, height + 96.0)
	sim._add_campaign_enemy(VANGUARD, vanguard, 29 if cannon_forward else 0)
	sim._add_campaign_enemy(CANNON, cannon)


static func begin(sim, boss: Dictionary, target: Dictionary, attack: Dictionary) -> void:
	var origin: Vector2 = boss.pos
	var aim: Vector2 = target.pos
	var distance := origin.distance_to(aim)
	if distance > float(attack.reach):
		return
	var direction := origin.direction_to(aim)
	if direction.is_zero_approx():
		direction = Vector2.LEFT
	var vanguard: bool = boss.attack_id == VANGUARD
	var distance_limit: float = attack.reach
	var bounds := Rect2(Vector2.ZERO, sim.ARENA_SIZE)
	if vanguard:
		distance_limit = minf(distance_limit, distance + attack.overrun)
		bounds = bounds.grow(-sim.WALL_MARGIN - float(boss.radius))
	var endpoint := _ray_endpoint(origin, direction, distance_limit, bounds)
	boss["pilot_aim_origin"] = origin
	boss["pilot_aim_point"] = endpoint
	boss["pilot_aim_width"] = attack.aim_width
	var cue := CHARGE if vanguard else SHOT
	sim._start_enemy_intent(boss, target.id, sim.tick + int(attack.windup), cue)
	var message := "The Vanguard Captain prepares to charge." if vanguard else "The Siege Cannoneer sights its lane."
	sim._emit("intent", message, boss, target, cue, 0, origin, endpoint, {"width": attack.aim_width})
	sim._review_boss_event("start", cue, message, boss, target)


static func interrupt_if_displaced(sim, boss: Dictionary) -> bool:
	if boss.intent.is_empty() or not boss.has("pilot_aim_origin"):
		return false
	var origin: Vector2 = boss.pilot_aim_origin
	if origin.distance_to(boss.pos) < float(boss.attack.alignment):
		return false
	var target: String = boss.intent
	var cue: String = boss.intent_attack_id
	_clear_aim(boss)
	boss.next_attack = sim.tick + 2 * sim.TICKS_PER_BEAT
	sim._emit("interrupt", "%s loses its line." % boss.name, boss, boss, DISRUPTED, 0, origin, boss.pos,
		{"attack_id": cue, "marked_hero": target})
	return true


static func resolve(sim, boss: Dictionary, marked: Dictionary, cue: String) -> void:
	var anchor: Vector2 = boss.pilot_aim_origin
	var endpoint: Vector2 = boss.pilot_aim_point
	_clear_aim(boss)
	if cue == CHARGE:
		_resolve_charge(sim, boss, marked, endpoint)
	else:
		_resolve_shell(sim, boss, marked, anchor, endpoint)


static func _resolve_charge(sim, boss: Dictionary, marked: Dictionary, endpoint: Vector2) -> void:
	var origin: Vector2 = boss.pos
	var destination := origin.move_toward(endpoint, float(boss.attack.reach))
	var landing: Vector2 = sim._slide_landing(boss, destination)
	var victim := _first_hero_in_lane(sim.units, origin, landing, boss.attack.aim_width)
	boss.pos = landing
	boss.prev_pos = landing
	boss.velocity = Vector2.ZERO
	boss.impulse = Vector2.ZERO
	if not origin.is_equal_approx(landing):
		sim._emit("charge", "The Vanguard Captain charges.", boss, victim if not victim.is_empty() else marked,
			CHARGE, 0, origin, landing, {"route": PackedVector2Array([origin, landing])})
	if victim.is_empty():
		sim._emit("miss", "The Vanguard Captain's charge misses.", boss, marked, CHARGE, 0, origin, landing)
		return
	sim._damage(boss, victim, boss.attack.damage, "enemy_attack", "Vanguard Charge",
		{"attack_id": CHARGE, "attack_component": "contact", "strike_origin": landing})
	if victim.hp > 0:
		var heading: Vector2 = endpoint - origin
		var offset: Vector2 = victim.pos - landing
		sim._displace("push", boss, victim, CHARGE, offset if not offset.is_zero_approx() else heading, boss.attack.push)


static func _resolve_shell(sim, boss: Dictionary, marked: Dictionary, origin: Vector2, endpoint: Vector2) -> void:
	var victim := _first_hero_in_lane(sim.units, origin, endpoint, boss.attack.aim_width)
	if victim.is_empty():
		sim._emit("miss", "The cannon shot misses.", boss, marked, SHOT, 0, origin, endpoint)
		return
	var impact := Geometry2D.get_closest_point_to_segment(victim.pos, origin, endpoint)
	var radius: float = boss.attack.splash_radius
	sim._emit(IMPACT, "The cannon shell bursts.", boss, victim, SHOT, 0, impact, impact, {"radius": radius})
	sim._damage(boss, victim, boss.attack.damage, "enemy_attack", "Cannon Shell",
		{"attack_id": SHOT, "attack_component": "contact", "strike_origin": origin})
	for hero: Dictionary in sim._enemies_in_area(boss, impact, radius):
		if hero.id != victim.id:
			sim._damage(boss, hero, boss.attack.splash_damage, "enemy_attack", "Shell Burst",
				{"attack_id": SHOT, "attack_component": "splash", "strike_origin": impact})


static func _first_hero_in_lane(units: Array, origin: Vector2, endpoint: Vector2, width: float) -> Dictionary:
	var first := {}
	var earliest := INF
	var direction := origin.direction_to(endpoint)
	for hero: Dictionary in units:
		if hero.side != "hero" or hero.hp <= 0:
			continue
		var position: Vector2 = hero.pos
		if (position - origin).dot(direction) < 0.0:
			continue
		var contact := origin if direction.is_zero_approx() else Geometry2D.get_closest_point_to_segment(position, origin, endpoint)
		var progress := origin.distance_squared_to(contact)
		var extent := width + float(hero.radius)
		if progress < earliest and contact.distance_squared_to(position) <= extent * extent:
			first = hero
			earliest = progress
	return first


static func _ray_endpoint(origin: Vector2, direction: Vector2, reach: float, bounds: Rect2) -> Vector2:
	var distance := reach
	for axis in range(2):
		if is_zero_approx(direction[axis]):
			continue
		var wall := bounds.end[axis] if direction[axis] > 0.0 else bounds.position[axis]
		distance = minf(distance, (wall - origin[axis]) / direction[axis])
	return origin + direction * maxf(0.0, distance)


static func _clear_aim(boss: Dictionary) -> void:
	boss.intent = ""
	boss.intent_tick = 0
	boss.erase("pilot_aim_origin")
	boss.erase("pilot_aim_point")
	boss.erase("pilot_aim_width")
