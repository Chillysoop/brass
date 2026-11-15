extends RefCounted


const ENEMIES := {
	"brass_runner": {
		"name": "Wire Runner", "art": "brass_runner", "special": "brass_runner",
		"hp": 28, "radius": 20.0, "speed": 116.0, "spacing": 86.0, "reach": 115.0,
		"damage": 3, "first": 95, "cooldown": 143, "windup": 22,
		"hint": "Closes quickly for a light strike. Land a quick attack or have Guard ready.",
	},
	"brass_riveter": {
		"name": "Pneumatic Riveter", "art": "brass_riveter", "special": "brass_riveter",
		"hp": 28, "radius": 20.0, "speed": 78.0, "spacing": 110.0, "reach": 265.0,
		"damage": 5, "first": 108, "cooldown": 192, "windup": 42,
		"hint": "Takes two beats to sight a heavy rivet. Set Guard before it fires or push it out of reach.",
	},
	"brass_shieldwright": {
		"name": "Shieldwright", "art": "brass_shieldwright", "special": "brass_shieldwright",
		"hp": 60, "radius": 25.0, "speed": 91.0, "spacing": 92.0, "reach": 138.0,
		"damage": 6, "first": 70, "cooldown": 154, "windup": 39, "guard_amount": 10,
		"hint": "Alternates strikes with personal Guard plates. Hit before the plate or strip its Guard after.",
	},
	"brass_linksmith": {
		"name": "Linksmith", "art": "brass_linksmith", "special": "brass_linksmith",
		"hp": 44, "radius": 22.0, "speed": 88.0, "spacing": 125.0, "reach": 165.0,
		"damage": 4, "first": 65, "cooldown": 166, "windup": 38, "guard_reach": 176.0, "guard_amount": 11,
		"hint": "Installs Guard on a nearby ally. Focus the Linksmith or push or pull the pair apart.",
	},
	"brass_springjack": {
		"name": "Springjack", "art": "brass_springjack", "special": "brass_springjack",
		"hp": 74, "radius": 27.0, "speed": 93.0, "spacing": 88.0, "reach": 155.0,
		"damage": 8, "first": 94, "cooldown": 151, "windup": 37, "force": 380.0,
		"hint": "A piston hit that reaches HP knocks its target away. Block the hit or use a ranged follow-up.",
	},
	"brass_rivet_hound": {
		"name": "Rivet Hound", "art": "brass_rivet_hound", "special": "brass_rivet_hound",
		"hp": 64, "radius": 24.0, "speed": 116.0, "spacing": 95.0, "reach": 255.0,
		"damage": 7, "first": 62, "cooldown": 152, "windup": 33, "target": "lowest_hp",
		"hint": "Pounces on the hero with the lowest HP. Cover that hero with Guard or push the hound away during its windup.",
	},
	"brass_manifold": {
		"name": "Manifold", "art": "brass_manifold", "special": "brass_manifold",
		"hp": 86, "radius": 30.0, "speed": 78.0, "spacing": 117.0, "reach": 170.0,
		"damage": 8, "first": 88, "cooldown": 177, "windup": 43,
		"hint": "Vents pressure in a ring. Fight from range or push the Manifold to carry the ring away.",
	},
	"brass_sparkbow": {
		"name": "Sparkbow", "art": "brass_sparkbow", "special": "brass_sparkbow",
		"hp": 64, "radius": 23.0, "speed": 75.0, "spacing": 205.0, "reach": 390.0,
		"damage": 8, "first": 56, "cooldown": 155, "windup": 44, "line_width": 22.0, "target": "farthest",
		"hint": "Locks a piercing shot on a line toward the farthest hero. Shift the formation or shield heroes along the line.",
	},
	"brass_magnetar": {
		"name": "Magnetar", "art": "brass_magnetar", "special": "brass_magnetar",
		"hp": 72, "radius": 25.0, "speed": 84.0, "spacing": 135.0, "reach": 165.0,
		"damage": 7, "first": 48, "cooldown": 163, "windup": 42, "magnet_reach": 315.0, "force": 450.0,
		"hint": "Pulls the hero with the most Guard within reach. Save Guard for after the pull or push the magnet away.",
	},
	"brass_grounder": {
		"name": "Grounder", "art": "brass_grounder", "special": "brass_grounder",
		"hp": 76, "radius": 26.0, "speed": 87.0, "spacing": 98.0, "reach": 162.0,
		"damage": 8, "first": 86, "cooldown": 151, "windup": 33, "guard_amount": 8,
		"hint": "A hit that reaches HP charges the Grounder's Guard. Block it completely or break its range.",
	},
	"brass_flywheel": {
		"name": "Flywheel", "art": "brass_flywheel", "special": "brass_flywheel",
		"hp": 75, "radius": 28.0, "speed": 99.0, "spacing": 103.0, "reach": 164.0,
		"damage": 7, "first": 74, "cooldown": 133, "windup": 38, "interrupt_damage": 14,
		"hint": "Hits that reach HP build spinning momentum. Block its strike or land a 14-damage hit during its windup to stop it and reset momentum.",
	},
	"brass_pressure_sentinel": {
		"name": "Pressure Sentinel", "art": "brass_pressure_sentinel", "special": "brass_pressure_sentinel",
		"hp": 88, "radius": 29.0, "speed": 82.0, "spacing": 104.0, "reach": 184.0,
		"damage": 13, "first": 68, "cooldown": 173, "windup": 58,
		"hint": "Builds pressure before a heavy strike. Up to two separate tile hits vent it for 4 less damage each, or time Guard.",
	},
}


static func begin(sim, enemy: Dictionary, target: Dictionary, attack: Dictionary) -> bool:
	var move: String = attack.special
	var position: Vector2 = enemy.pos
	var message := "%s winds up." % enemy.name
	match move:
		"brass_shieldwright":
			if enemy.get("shieldwright_braced", false) or int(enemy.guard) > 18:
				enemy.erase("shieldwright_braced")
				return false
			if position.distance_to(target.pos) > attack.reach:
				return false
			target = enemy
			message = "Shieldwright readies a Guard plate."
		"brass_linksmith":
			target = _guard_ally(sim.units, enemy, attack.guard_reach)
			if target.is_empty():
				return false
			message = "Linksmith readies a plate for %s." % target.name
		"brass_magnetar":
			target = _guarded_target(sim.units, enemy, attack.magnet_reach)
			if target.is_empty():
				return false
			message = "Magnetar locks onto %s's Guard." % target.name
		_:
			if position.distance_to(target.pos) > attack.reach:
				return false
			match move:
				"brass_manifold":
					enemy["pilot_ring_radius"] = attack.reach
					message = "Manifold charges a pressure burst."
				"brass_sparkbow":
					enemy["pilot_aim_point"] = target.pos
					enemy["pilot_aim_width"] = attack.line_width
					message = "Sparkbow lines up a piercing shot."
				"brass_pressure_sentinel":
					enemy["pressure_vents"] = 0
					enemy.erase("pressure_last_hit")
					message = "Pressure Sentinel builds pressure. Hits during the windup weaken the strike."
				"brass_flywheel":
					message = "Flywheel winds up with %d momentum." % int(enemy.get("flywheel_momentum", 0))
				"brass_rivet_hound":
					message = "Rivet Hound prepares to pounce on %s." % target.name
				"brass_riveter":
					message = "Pneumatic Riveter sights %s." % target.name
	enemy.special_intent = move
	enemy.intent = target.id
	enemy.intent_tick = sim.tick + int(attack.windup)
	sim._emit("intent", message, enemy, target, move)
	return true


static func resolve(sim, enemy: Dictionary, target: Dictionary, attack: Dictionary, move: String) -> void:
	match move:
		"brass_shieldwright":
			enemy["shieldwright_braced"] = true
			sim._guard(enemy, attack.guard_amount, move)
			return
		"brass_linksmith":
			if target.get("hp", 0) > 0 and _within_reach(enemy, target, attack.guard_reach):
				sim._guard(target, attack.guard_amount, move, enemy)
			else:
				sim._emit("miss", "The Linksmith's cable cannot reach its ally.", enemy, target, move)
			return
		"brass_manifold":
			enemy.erase("pilot_ring_radius")
			_pulse(sim, enemy, attack)
			return
		"brass_sparkbow":
			_pierce(sim, enemy, attack)
			return
	var vents := int(enemy.get("pressure_vents", 0))
	enemy.erase("pressure_vents")
	enemy.erase("pressure_last_hit")
	if target.get("hp", 0) <= 0:
		return
	var reach: float = attack.get("magnet_reach", attack.reach)
	if not _within_reach(enemy, target, reach):
		sim._emit("miss", "%s moves out of %s's reach." % [target.name, enemy.name], enemy, target, move)
		return
	if move == "brass_magnetar" and target.guard <= 0:
		sim._emit("miss", "%s has no Guard left for the Magnetar to pull." % target.name, enemy, target, move)
		return
	if move == "brass_rivet_hound" and not _pounce(sim, enemy, target):
		sim._emit("miss", "Rivet Hound's pounce falls short of %s." % target.name, enemy, target, move)
		return
	var defender: Dictionary = sim._intercept_target(target)
	var damage: int = attack.damage
	if move == "brass_flywheel":
		damage += 3 * int(enemy.get("flywheel_momentum", 0))
	elif move == "brass_pressure_sentinel":
		damage = maxi(1, damage - 4 * vents)
	var before: int = defender.hp
	sim._damage(enemy, defender, damage, move)
	var offset: Vector2 = defender.pos - enemy.pos
	if move == "brass_magnetar" and defender.hp > 0:
		sim._displace("pull", enemy, defender, move, -offset, attack.force)
	if defender.hp >= before:
		return
	match move:
		"brass_springjack":
			if defender.hp > 0:
				sim._displace("push", enemy, defender, move, offset, attack.force)
		"brass_grounder":
			sim._guard(enemy, attack.guard_amount, move)
		"brass_flywheel":
			var prior := int(enemy.get("flywheel_momentum", 0))
			if prior < 3:
				enemy["flywheel_momentum"] = prior + 1
				sim._emit("heat", "Flywheel gains momentum (%d of 3)." % (prior + 1), enemy, enemy, move, prior + 1)


static func on_tile_hit(sim, attacker: Dictionary, enemy: Dictionary, amount: int, _tile_id: String, order: int) -> void:
	if amount <= 0 or enemy.intent == "" or sim.tick > enemy.intent_tick:
		return
	match enemy.get("special_intent", ""):
		"brass_flywheel":
			if amount < int(enemy.attack.interrupt_damage):
				return
			enemy["flywheel_momentum"] = 0
			enemy.intent = ""
			enemy.intent_tick = 0
			enemy.erase("special_intent")
			enemy.next_attack = sim.tick + int(enemy.attack.cooldown)
			sim._emit("interrupt", "The heavy hit stops the Flywheel and clears its momentum.", attacker, enemy, "brass_flywheel_canceled")
		"brass_pressure_sentinel":
			if int(enemy.pressure_vents) >= 2 or order == int(enemy.get("pressure_last_hit", -1)):
				return
			enemy.pressure_vents += 1
			enemy["pressure_last_hit"] = order
			sim._emit("interrupt", "The hit vents the Sentinel's pressure.", attacker, enemy, "brass_pressure_vented", enemy.pressure_vents)


static func _within_reach(enemy: Dictionary, target: Dictionary, reach: float) -> bool:
	var origin: Vector2 = enemy.pos
	return origin.distance_squared_to(target.pos) <= reach * reach


static func _guard_ally(units: Array, enemy: Dictionary, reach: float) -> Dictionary:
	var best := {}
	var origin: Vector2 = enemy.pos
	var best_distance := reach * reach
	for ally: Dictionary in units:
		if ally.side != enemy.side or ally.id == enemy.id or ally.hp <= 0 or ally.guard > 17:
			continue
		var distance := origin.distance_squared_to(ally.pos)
		if distance <= best_distance and (best.is_empty() or distance < best_distance):
			best_distance = distance
			best = ally
	return best


static func _guarded_target(units: Array, enemy: Dictionary, reach: float) -> Dictionary:
	var best := {}
	var high := 0
	for hero: Dictionary in units:
		if hero.side != "hero" or hero.hp <= 0 or hero.guard <= high or not _within_reach(enemy, hero, reach):
			continue
		high = int(hero.guard)
		best = hero
	return best


static func _pulse(sim, enemy: Dictionary, attack: Dictionary) -> void:
	sim._emit("bell_ring", "Manifold vents pressure.", enemy, enemy, "brass_manifold", roundi(attack.reach))
	for hero: Dictionary in sim._enemies_in_area(enemy, enemy.pos, attack.reach):
		sim._damage(enemy, hero, attack.damage, "brass_manifold")


static func _pierce(sim, enemy: Dictionary, attack: Dictionary) -> void:
	var origin: Vector2 = enemy.pos
	var endpoint := origin.move_toward(enemy.pilot_aim_point, float(attack.reach))
	enemy.erase("pilot_aim_point")
	enemy.erase("pilot_aim_width")
	sim._emit("ranged_warning", "Sparkbow fires along the marked line.", enemy, {}, "brass_sparkbow", 0, origin, endpoint)
	for hero: Dictionary in sim.units:
		if hero.side != "hero" or hero.hp <= 0:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(hero.pos, origin, endpoint)
		if closest.distance_squared_to(hero.pos) <= attack.line_width * attack.line_width:
			sim._damage(enemy, hero, attack.damage, "brass_sparkbow")


static func _pounce(sim, enemy: Dictionary, target: Dictionary) -> bool:
	var origin: Vector2 = enemy.pos
	var contact: float = enemy.radius + target.radius + 6.0
	var distance := origin.distance_to(target.pos)
	var desired := origin.move_toward(target.pos, maxf(0.0, distance - contact))
	var landing: Vector2 = sim._slide_landing(enemy, sim._bounded(desired, enemy.radius))
	if origin.distance_squared_to(landing) > 1.0:
		enemy.pos = landing
		enemy.prev_pos = landing
		sim._emit("charge", "Rivet Hound pounces toward %s." % target.name, enemy, target, "brass_rivet_hound", 0, origin, landing)
	return landing.distance_to(target.pos) <= contact + 22.0
