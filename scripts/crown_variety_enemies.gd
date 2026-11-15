extends RefCounted

const ENEMIES := {
	"crown_page": {
		"name": "Crown Page", "art": "crown_page", "special": "crown_page",
		"hp": 31, "radius": 20.0, "speed": 91.0, "spacing": 82.0, "reach": 140.0,
		"damage": 3, "first": 82, "cooldown": 155, "windup": 38,
		"hint": "Winds up a short strike. Finish a Guard tile before the hit, or push the Page away.",
	},
	"crown_slinger": {
		"name": "Crown Slinger", "art": "crown_slinger", "special": "crown_slinger",
		"hp": 40, "radius": 21.0, "speed": 77.0, "spacing": 125.0, "reach": 220.0,
		"damage": 4, "first": 90, "cooldown": 154, "windup": 38,
		"hint": "Steps back after a sling shot. Follow with a ranged tile or bring the Slinger back with a pull.",
	},
	"crown_glaiveguard": {
		"name": "Crown Glaiveguard", "art": "crown_glaiveguard", "special": "crown_glaiveguard",
		"hp": 58, "radius": 26.0, "speed": 82.0, "spacing": 100.0, "reach": 163.0,
		"damage": 7, "first": 76, "cooldown": 174, "windup": 56,
		"hint": "Sweeps a wide ring after a long windup. Push it away or time Guard before the sweep.",
	},
	"crown_spotter": {
		"name": "Crown Spotter", "art": "crown_spotter", "special": "crown_spotter",
		"hp": 37, "radius": 21.0, "speed": 76.0, "spacing": 140.0, "reach": 245.0,
		"damage": 3, "first": 59, "cooldown": 150, "windup": 24,
		"hint": "Marks a hero so the next enemy strike deals 3 more damage. Focus the Spotter or Guard the follow-up.",
	},
	"crown_war_drummer": {
		"name": "Crown War Drummer", "art": "crown_war_drummer", "special": "crown_war_drummer",
		"hp": 53, "radius": 23.0, "speed": 81.0, "spacing": 143.0, "reach": 147.0,
		"damage": 5, "first": 70, "cooldown": 145, "windup": 19, "drum_reach": 215.0,
		"hint": "Speeds up an ally's windup by up to one beat. Focus the drummer, split the pair, or move Guard earlier.",
	},
	"crown_feintblade": {
		"name": "Crown Feintblade", "art": "crown_feintblade", "special": "crown_feintblade",
		"hp": 65, "radius": 22.0, "speed": 102.0, "spacing": 93.0, "reach": 152.0,
		"damage": 8, "first": 103, "cooldown": 142, "windup": 36,
		"hint": "Strikes whichever hero is nearest when the windup ends. Keep a guarded hero close or push it out of reach.",
	},
	"crown_twinspur": {
		"name": "Crown Twinspur", "art": "crown_twinspur", "special": "crown_twinspur",
		"hp": 66, "radius": 24.0, "speed": 88.0, "spacing": 103.0, "reach": 154.0,
		"damage": 6, "first": 70, "cooldown": 151, "windup": 48, "followup_ticks": 19,
		"hint": "Strikes the same hero twice. Push it between hits or save enough Guard for both.",
	},
	"crown_ballista": {
		"name": "Relay Ballista", "art": "crown_ballista", "special": "crown_ballista",
		"hp": 61, "radius": 26.0, "speed": 71.0, "spacing": 225.0, "reach": 385.0, "target": "farthest",
		"damage": 10, "first": 92, "cooldown": 162, "windup": 50,
		"hint": "Fires along a marked line and can hit multiple heroes. Move across the line or focus the Ballista early.",
	},
	"crown_storm_templar": {
		"name": "Storm Templar", "art": "crown_storm_templar", "special": "crown_storm_templar",
		"hp": 79, "radius": 30.0, "speed": 81.0, "spacing": 94.0, "reach": 144.0,
		"damage": 9, "first": 106, "cooldown": 156, "windup": 49,
		"hint": "Its ring draws in heroes who lose HP to the pulse. Use Guard to hold position, or fight from outside the ring.",
	},
	"crown_banneret": {
		"name": "Crown Banneret", "art": "crown_banneret", "special": "crown_banneret",
		"hp": 69, "radius": 25.0, "speed": 84.0, "spacing": 99.0, "reach": 158.0,
		"damage": 7, "first": 95, "cooldown": 150, "windup": 39,
		"hint": "When left alone, it gains Guard and hits harder. Target it before its allies or push it out of attack range.",
	},
	"crown_galvanist": {
		"name": "Crown Galvanist", "art": "crown_galvanist", "special": "crown_galvanist",
		"hp": 64, "radius": 23.0, "speed": 88.0, "spacing": 118.0, "reach": 165.0,
		"damage": 6, "first": 75, "cooldown": 158, "windup": 40, "swap_reach": 250.0,
		"hint": "Swaps places with a nearby ally. Move them apart or choose a targeting rule that follows the threat.",
	},
	"crown_beacon_sentry": {
		"name": "Beacon Sentry", "art": "crown_beacon_sentry", "special": "crown_beacon_sentry",
		"hp": 73, "radius": 25.0, "speed": 71.0, "spacing": 243.0, "reach": 452.0, "target": "farthest",
		"damage": 12, "first": 92, "cooldown": 167, "windup": 58, "blast_radius": 73.0,
		"hint": "Marks the farthest hero's position for a heavy shot. Blink or move off the mark, or have Guard ready.",
	},
	"crown_oathbreaker": {
		"name": "Crown Oathbreaker", "art": "crown_oathbreaker", "special": "crown_oathbreaker",
		"hp": 73, "radius": 26.0, "speed": 79.0, "spacing": 104.0, "reach": 149.0,
		"damage": 8, "first": 89, "cooldown": 157, "windup": 44,
		"hint": "The first hit after its strike raises a short brace. Use small hits or delay your heavy attack until it drops.",
	},
	"crown_chorister": {
		"name": "Crown Chorister", "art": "crown_chorister", "special": "crown_chorister",
		"hp": 62, "radius": 23.0, "speed": 79.0, "spacing": 163.0, "reach": 195.0,
		"damage": 6, "first": 101, "cooldown": 160, "windup": 40, "mend_reach": 220.0, "mend_radius": 48.0,
		"hint": "Restores 9 HP to a wounded ally who stays in the chime's marked area. Push the ally clear or finish it first.",
	},
}


static func begin(sim, enemy: Dictionary, target: Dictionary, attack: Dictionary) -> bool:
	var move: String = attack.special
	var distance: float = enemy.pos.distance_to(target.pos)
	var message := "%s winds up at %s." % [enemy.name, target.name]
	match move:
		"crown_war_drummer":
			target = _drum_target(sim, enemy, attack.drum_reach)
			if target.is_empty():
				return false
			message = "%s raises the tempo for %s." % [enemy.name, target.name]
		"crown_galvanist":
			target = _swap_target(sim, enemy, attack.swap_reach)
			if target.is_empty():
				return false
			message = "%s prepares to swap places with %s." % [enemy.name, target.name]
		"crown_chorister":
			target = sim._repair_target(enemy, attack.mend_reach)
			if target.is_empty():
				return false
			enemy["blast_center"] = target.pos
			enemy["blast_radius"] = attack.mend_radius
			message = "%s rings a healing chime for %s." % [enemy.name, target.name]
		_:
			if distance > attack.reach:
				return false
			match move:
				"crown_glaiveguard", "crown_storm_templar":
					enemy["pilot_ring_radius"] = attack.reach
					message = "%s prepares to strike every hero in the marked ring." % enemy.name
				"crown_spotter":
					if not _has_ally(sim, enemy):
						return false
					message = "%s signals a follow-up hit on %s." % [enemy.name, target.name]
				"crown_feintblade":
					message = "%s starts a feint. The nearest hero will take the strike." % enemy.name
				"crown_twinspur":
					message = "%s prepares two strikes against %s." % [enemy.name, target.name]
				"crown_ballista":
					enemy["pilot_aim_point"] = target.pos
					enemy["pilot_aim_width"] = 26.0
					message = "%s sights down the marked line." % enemy.name
				"crown_banneret":
					if not _has_ally(sim, enemy):
						message = "%s stands alone and raises its Guard." % enemy.name
				"crown_beacon_sentry":
					enemy["blast_center"] = target.pos
					enemy["blast_radius"] = attack.blast_radius
					message = "%s lights the spot where its shot will land." % enemy.name
				"crown_oathbreaker":
					message = "%s winds up a strike and prepares to brace." % enemy.name
	_windup(sim, enemy, target, move, int(attack.windup), message)
	return true


static func resolve(sim, enemy: Dictionary, target: Dictionary, attack: Dictionary, move: String) -> void:
	match move:
		"crown_glaiveguard", "crown_storm_templar":
			_resolve_ring(sim, enemy, attack, move)
			return
		"crown_ballista":
			_resolve_ballista(sim, enemy, attack)
			return
		"crown_beacon_sentry":
			_resolve_beacon(sim, enemy, target, attack)
			return
		"crown_chorister":
			_resolve_chime(sim, enemy, target, attack)
			return
		"crown_war_drummer", "crown_galvanist":
			if target.get("hp", 0) <= 0:
				return
			if move == "crown_war_drummer":
				_resolve_drum(sim, enemy, target, attack)
			else:
				_resolve_swap(sim, enemy, target, attack)
			return
		"crown_feintblade":
			var original: String = target.get("id", "")
			target = sim._select(enemy, "nearest", attack.reach)
			if not target.is_empty() and target.id != original:
				sim._emit("mark_spent", "%s switches its strike to %s." % [enemy.name, target.name], enemy, target, move)
	if target.get("hp", 0) <= 0:
		return
	if enemy.pos.distance_to(target.pos) > attack.reach:
		sim._emit("miss", "%s's windup misses %s." % [enemy.name, target.name], enemy, target, move)
		return
	if move == "crown_spotter":
		if _has_ally(sim, enemy):
			target["crown_spotter_until"] = sim.tick + 3 * sim.TICKS_PER_BEAT
			sim._emit("mark", "%s marks %s for the next enemy strike." % [enemy.name, target.name], enemy, target, move, 3)
		return
	var damage: int = attack.damage
	if move == "crown_banneret" and not _has_ally(sim, enemy):
		damage += 4
		sim._guard(enemy, 8, move)
	var defender: Dictionary = sim._intercept_target(target)
	sim._damage(enemy, defender, damage, move)
	if move == "crown_oathbreaker":
		enemy["crown_oathbrace_trigger_until"] = sim.tick + 3 * sim.TICKS_PER_BEAT
		sim._emit("mark", "%s readies its brace for the first hit." % enemy.name, enemy, enemy, move)
	if move == "crown_slinger" and defender.hp > 0:
		sim._retreat_from(enemy, defender, move, 54.0)
	if move == "crown_twinspur" and target.hp > 0:
		_windup(sim, enemy, target, "crown_twinspur_followup", attack.followup_ticks,
			"%s follows with a second strike." % enemy.name)


static func on_tile_hit(sim, _attacker: Dictionary, enemy: Dictionary, _amount: int, _tile_id: String, _order: int) -> void:
	if int(enemy.get("crown_oathbrace_trigger_until", 0)) <= sim.tick:
		return
	enemy.erase("crown_oathbrace_trigger_until")
	enemy["crown_oathbrace_until"] = sim.tick + 2 * sim.TICKS_PER_BEAT
	sim._emit("guard", "%s braces against the next heavy hit." % enemy.name, enemy, enemy, "crown_oathbreaker")


static func consume_spotter_mark(sim, actor: Dictionary, target: Dictionary) -> int:
	var expires: int = target.get("crown_spotter_until", 0)
	target.erase("crown_spotter_until")
	if sim.tick >= expires:
		return 0
	sim._emit("mark_spent", "%s strikes %s's signal mark." % [actor.name, target.name], actor, target, "crown_spotter", 3)
	return 3


static func block_oathbreaker_hit(sim, actor: Dictionary, enemy: Dictionary, damage: int) -> int:
	if int(enemy.get("crown_oathbrace_until", 0)) <= sim.tick:
		enemy.erase("crown_oathbrace_until")
		return 0
	if damage < 12:
		return 0
	enemy.erase("crown_oathbrace_until")
	var blocked := mini(floori(damage * 0.5), 8)
	sim._emit("guard", "%s's brace blocks %d damage." % [enemy.name, blocked], enemy, actor,
		"crown_oathbreaker", blocked)
	return blocked


static func _windup(sim, enemy: Dictionary, target: Dictionary, move: String, length: int, message: String) -> void:
	enemy["special_intent"] = move
	enemy.intent = target.id
	enemy.intent_tick = sim.tick + length
	sim._emit("intent", message, enemy, target, move)


static func _has_ally(sim, enemy: Dictionary) -> bool:
	return sim.units.any(func(unit: Dictionary) -> bool:
		return unit.side == enemy.side and unit.id != enemy.id and unit.hp > 0)


static func _drum_target(sim, enemy: Dictionary, reach: float) -> Dictionary:
	var target := {}
	var earliest := INF
	for ally: Dictionary in sim.units:
		if ally.side != enemy.side or ally.id == enemy.id or ally.hp <= 0 or enemy.pos.distance_to(ally.pos) > reach:
			continue
		var ready: int = ally.intent_tick if ally.intent != "" else ally.next_attack
		if ready > sim.tick + 23 and ready < earliest:
			target = ally
			earliest = ready
	return target


static func _resolve_drum(sim, enemy: Dictionary, target: Dictionary, attack: Dictionary) -> void:
	if enemy.pos.distance_to(target.pos) > attack.drum_reach:
		sim._emit("miss", "%s is too far from the drumbeat." % target.name, enemy, target, "crown_war_drummer")
		return
	var field := "intent_tick" if target.intent != "" else "next_attack"
	var advance := mini(sim.TICKS_PER_BEAT, int(target[field]) - sim.tick - 2)
	if advance <= 0:
		return
	target[field] -= advance
	sim._emit("haste", "%s speeds up %s's attack." % [enemy.name, target.name], enemy, target,
		"crown_war_drummer", advance)


static func _swap_target(sim, enemy: Dictionary, reach: float) -> Dictionary:
	var target := {}
	var farthest := 0.0
	for ally: Dictionary in sim.units:
		if ally.side != enemy.side or ally.id == enemy.id or ally.hp <= 0:
			continue
		var distance: float = enemy.pos.distance_to(ally.pos)
		if distance <= reach and distance > farthest:
			target = ally
			farthest = distance
	return target


static func _resolve_swap(sim, enemy: Dictionary, target: Dictionary, attack: Dictionary) -> void:
	if enemy.pos.distance_to(target.pos) > attack.swap_reach:
		sim._emit("miss", "%s is too far away to swap." % target.name, enemy, target, "crown_galvanist")
		return
	var origin: Vector2 = enemy.pos
	var destination: Vector2 = target.pos
	var swap_a: Vector2 = sim._bounded(destination, enemy.radius)
	var swap_b: Vector2 = sim._bounded(origin, target.radius)
	if swap_a.distance_to(swap_b) < enemy.radius + target.radius:
		return
	for unit: Dictionary in sim.units:
		if unit.hp <= 0 or unit.id == enemy.id or unit.id == target.id:
			continue
		if swap_a.distance_to(unit.pos) < enemy.radius + unit.radius \
				or swap_b.distance_to(unit.pos) < target.radius + unit.radius:
			sim._emit("miss", "%s has no room to swap." % enemy.name, enemy, target, "crown_galvanist")
			return
	enemy.pos = swap_a
	enemy.prev_pos = swap_a
	enemy.impulse = Vector2.ZERO
	target.pos = swap_b
	target.prev_pos = swap_b
	target.impulse = Vector2.ZERO
	sim._emit("teleport", "%s swaps places with %s." % [enemy.name, target.name], enemy, target, "crown_galvanist", 0, origin, swap_a)
	sim._emit("teleport", "%s lands at the other relay." % target.name, target, enemy, "crown_galvanist", 0, destination, swap_b)


static func _resolve_ring(sim, enemy: Dictionary, attack: Dictionary, move: String) -> void:
	enemy.erase("pilot_ring_radius")
	var center: Vector2 = enemy.pos
	for hero: Dictionary in sim._enemies_in_area(enemy, center, attack.reach):
		var before: int = hero.hp
		sim._damage(enemy, hero, attack.damage, move)
		if move == "crown_storm_templar" and hero.hp > 0 and hero.hp < before:
			sim._displace("pull", enemy, hero, move, center - hero.pos, 330.0)


static func _resolve_ballista(sim, enemy: Dictionary, attack: Dictionary) -> void:
	var origin: Vector2 = enemy.pos
	var end := origin.move_toward(enemy.pilot_aim_point, attack.reach)
	var width: float = enemy.pilot_aim_width
	enemy.erase("pilot_aim_point")
	enemy.erase("pilot_aim_width")
	sim._emit("ranged_warning", "%s fires down the line." % enemy.name, enemy, {}, "crown_ballista", 0, origin, end)
	for hero: Dictionary in sim.units:
		if hero.side != enemy.side and hero.hp > 0 \
				and Geometry2D.get_closest_point_to_segment(hero.pos, origin, end).distance_to(hero.pos) <= width:
			sim._damage(enemy, hero, attack.damage, "crown_ballista")


static func _resolve_beacon(sim, enemy: Dictionary, target: Dictionary, attack: Dictionary) -> void:
	var point: Vector2 = enemy.blast_center
	enemy.erase("blast_center")
	enemy.erase("blast_radius")
	if target.get("hp", 0) <= 0:
		return
	if target.pos.distance_to(point) > attack.blast_radius or enemy.pos.distance_to(point) > attack.reach:
		sim._emit("miss", "%s avoids the marked shot." % target.name, enemy, target, "crown_beacon_sentry")
		return
	sim._emit("ranged_warning", "%s fires at the mark." % enemy.name, enemy, target, "crown_beacon_sentry")
	sim._damage(enemy, sim._intercept_target(target), attack.damage, "crown_beacon_sentry")


static func _resolve_chime(sim, enemy: Dictionary, target: Dictionary, attack: Dictionary) -> void:
	var point: Vector2 = enemy.blast_center
	enemy.erase("blast_center")
	enemy.erase("blast_radius")
	if target.get("hp", 0) <= 0:
		return
	if target.pos.distance_to(point) > attack.mend_radius or enemy.pos.distance_to(point) > attack.mend_reach:
		sim._emit("miss", "%s is too far from the healing chime." % target.name, enemy, target, "crown_chorister")
		return
	var healed := mini(9, target.max_hp - target.hp)
	if healed > 0:
		target.hp += healed
		sim._emit("heal", "%s's chime restores %d HP to %s." % [enemy.name, healed, target.name],
			enemy, target, "crown_chorister", healed)
