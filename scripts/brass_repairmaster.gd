extends RefCounted

const BOSS_ID := "brass_repairmaster"
const DRONE_ID := "repairmaster_drone"
const DASH := "repairmaster_dash"
const REPAIR := "repairmaster_repair"
const INTERRUPTED := "repairmaster_interrupted"
const COMPLETED := "repairmaster_repair_completed"

const REPAIR_REACH := 155.0
const HEAL_AMOUNT := 46
const BURST_THRESHOLD := 32
const DISPLACEMENT_THRESHOLD := 18.0
const DASH_RANGE := 320.0
const DASH_BEATS := 2
const REPAIR_BEATS := 4
const HARD_REPAIR_RECOVERY := 104
const ORDER_THRESHOLDS := [70, 35]


static func spawn(sim, y: float, hard: bool) -> void:
	sim._add_campaign_enemy(BOSS_ID, Vector2(631, y))
	var boss: Dictionary = sim.units.back()
	if hard:
		boss.hp = 980
		boss.max_hp = 980
		boss.attack.damage = 41
		boss.attack.first += sim.TICKS_PER_BEAT
		boss.next_attack = boss.attack.first
		boss.attack.cooldown = HARD_REPAIR_RECOVERY + sim.TICKS_PER_BEAT
		boss["repairmaster_repair_recovery"] = HARD_REPAIR_RECOVERY
	boss["repairmaster_orders_used"] = 0
	boss["repairmaster_next_order"] = 0
	boss["repairmaster_damage_taken"] = 0
	boss["repairmaster_interrupt_damage"] = BURST_THRESHOLD
	for offset: float in [-124.0, 124.0]:
		sim._add_campaign_enemy(DRONE_ID, Vector2(740, y + offset), 0 if offset < 0.0 else 29)
		var drone: Dictionary = sim.units.back()
		if hard:
			drone.hp = 72
			drone.max_hp = 72
			drone.attack.damage = 6
		drone["repairmaster_owner"] = boss.id
		drone["repairmaster_charge"] = true


static func before_turn(sim, boss: Dictionary) -> bool:
	if not str(boss.intent).is_empty():
		if not _is_active(boss):
			return false
		var drone: Dictionary = sim._find_unit(boss.intent)
		if drone.get("hp", 0) <= 0:
			_cancel(sim, boss, drone, "drone_destroyed", "The Repairmaster's chosen drone was destroyed.")
			return true
		if boss.intent_attack_id == REPAIR and _position(boss).distance_to(_position(drone)) > REPAIR_REACH:
			_cancel(sim, boss, drone, "out_of_range", "The Repairmaster lost its repair link.")
			return true
		return false
	var used: int = boss.repairmaster_orders_used
	if used >= ORDER_THRESHOLDS.size() or sim.tick < boss.repairmaster_next_order \
			or int(boss.hp) * 100 > int(boss.max_hp) * ORDER_THRESHOLDS[used]:
		return false
	var drone := _nearest_charged_drone(sim.units, boss)
	if drone.is_empty():
		return false
	drone.repairmaster_charge = false
	boss.repairmaster_orders_used += 1
	boss.repairmaster_damage_taken = 0
	boss["repairmaster_dash_landing"] = _plan_dash(sim, boss, drone)
	sim._start_enemy_intent(boss, drone.id, sim.tick + DASH_BEATS * sim.TICKS_PER_BEAT, DASH)
	sim._emit("intent", "The Repairmaster lines up a dash to a repair drone.", boss, drone, DASH, 0,
		Vector2.INF, boss.repairmaster_dash_landing)
	return true


static func resolve(sim, boss: Dictionary, drone: Dictionary, cue: String) -> void:
	if cue == DASH:
		var start := _position(boss)
		var landing: Vector2 = sim._slide_landing(boss, boss.repairmaster_dash_landing)
		boss.erase("repairmaster_dash_landing")
		if not landing.is_equal_approx(start):
			boss.pos = landing
			boss.prev_pos = landing
			boss.impulse = Vector2.ZERO
			boss.velocity = Vector2.ZERO
			sim._emit("charge", "The Repairmaster dashes toward its drone.", boss, drone, DASH, 0, start, landing,
				{"route": PackedVector2Array([start, landing])})
		if drone.get("hp", 0) <= 0 or landing.distance_to(_position(drone)) > REPAIR_REACH:
			sim._emit("miss", "The Repairmaster can't dock with the drone.", boss, drone, DASH)
			_cancel(sim, boss, drone, "dash_blocked", "The Repairmaster couldn't reach the drone.")
			return
		sim._start_enemy_intent(boss, drone.id, sim.tick + REPAIR_BEATS * sim.TICKS_PER_BEAT, REPAIR)
		sim._emit("intent", "The Repairmaster starts channeling a repair.", boss, drone, REPAIR)
		return
	if drone.get("hp", 0) <= 0 or _position(boss).distance_to(_position(drone)) > REPAIR_REACH:
		sim._emit("miss", "The repair link breaks.", boss, drone, REPAIR)
		_cancel(sim, boss, drone, "out_of_range", "The Repairmaster lost its repair link.")
		return
	var restored := mini(HEAL_AMOUNT, int(boss.max_hp) - int(boss.hp))
	_clear_order(sim, boss)
	boss.next_attack = sim.tick + int(boss.get("repairmaster_repair_recovery", boss.attack.cooldown))
	if restored <= 0:
		return
	boss.hp += restored
	var message := "The drone restores %d HP to the Repairmaster." % restored
	sim._emit("heal", message, drone, boss, REPAIR, restored)
	sim._review_boss_event("miss", COMPLETED, message, boss, drone, "heal")


static func on_damage(sim, actor: Dictionary, target: Dictionary, dealt: int) -> void:
	var boss := _active_boss_for(sim, target)
	if boss.is_empty():
		return
	if target.id == boss.id and boss.hp > 0 and boss.intent_attack_id == REPAIR:
		boss.repairmaster_damage_taken += dealt
		if int(boss.repairmaster_damage_taken) >= BURST_THRESHOLD:
			_cancel(sim, boss, sim._find_unit(boss.intent), "damage", "The crew damages the Repairmaster enough to stop the repair.", actor)
	elif target.id == boss.intent and target.hp <= 0:
		_cancel(sim, boss, target, "drone_destroyed", "The Repairmaster's chosen drone was destroyed.", actor)


static func on_displacement(sim, actor: Dictionary, target: Dictionary, projected_travel: float) -> void:
	if projected_travel < DISPLACEMENT_THRESHOLD:
		return
	var boss := _active_boss_for(sim, target)
	if not boss.is_empty() and target.id in [boss.id, boss.intent]:
		_cancel(sim, boss, sim._find_unit(boss.intent), "displacement", "The crew disrupts the Repairmaster's alignment.", actor)


static func _active_boss_for(sim, target: Dictionary) -> Dictionary:
	var boss: Dictionary = target if target.get("attack_id") == BOSS_ID else sim._find_unit(target.get("repairmaster_owner", ""))
	return boss if boss.get("hp", 0) > 0 and _is_active(boss) else {}


static func _is_active(boss: Dictionary) -> bool:
	return not str(boss.intent).is_empty() and boss.get("intent_attack_id") in [DASH, REPAIR]


static func _nearest_charged_drone(units: Array, boss: Dictionary) -> Dictionary:
	var best := {}
	var nearest := INF
	for unit: Dictionary in units:
		if unit.get("repairmaster_owner") != boss.id or not unit.get("repairmaster_charge", false) or unit.hp <= 0:
			continue
		var distance := _position(boss).distance_squared_to(_position(unit))
		if distance < nearest:
			nearest = distance
			best = unit
	return best


static func _plan_dash(sim, boss: Dictionary, drone: Dictionary) -> Vector2:
	var origin := _position(boss)
	var center := _position(drone)
	var spacing: float = boss.radius + drone.radius + 9.0
	if origin.distance_to(center) <= spacing:
		return origin
	var direction := center.direction_to(origin)
	var direct := origin
	for angle: float in [0.0, 0.62, -0.62, 1.05, -1.05]:
		var desired: Vector2 = sim._bounded(origin.move_toward(center + direction.rotated(angle) * spacing, DASH_RANGE), boss.radius)
		if angle == 0.0:
			direct = desired
		if sim._free_position(desired, boss) and sim._slide_landing(boss, desired).is_equal_approx(desired):
			return desired
	return direct


static func _cancel(sim, boss: Dictionary, drone: Dictionary, reason: String, message: String, actor := {}) -> void:
	_clear_order(sim, boss)
	boss.next_attack = sim.tick + 2 * sim.TICKS_PER_BEAT
	sim._emit("interrupt", message, boss, drone, INTERRUPTED, 0, Vector2.INF, Vector2.INF,
		{"counter": reason, "counter_actor": actor.get("id", "")})


static func _clear_order(sim, boss: Dictionary) -> void:
	boss.intent = ""
	boss.intent_tick = 0
	boss.erase("repairmaster_dash_landing")
	boss.repairmaster_damage_taken = 0
	boss.repairmaster_next_order = sim.tick + 5 * sim.TICKS_PER_BEAT


static func _position(unit: Dictionary) -> Vector2:
	return unit.pos
