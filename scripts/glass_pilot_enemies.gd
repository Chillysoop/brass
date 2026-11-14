extends RefCounted

const ENEMIES := {
	"glass_mirrorback": {
		"name": "Glass Mirrorback", "art": "glass_mirrorback", "special": "glass_mirrorback",
		"hp": 65, "radius": 25.0, "speed": 86.0, "spacing": 91.0, "reach": 150.0,
		"damage": 6, "first": 34, "cooldown": 170, "windup": 42, "stance_reach": 335.0,
		"hint": "Reflects part of the first hit that reaches its HP during the stance. Bait it under Guard, or wait to strike.",
	},
	"glass_annealer": {
		"name": "Kiln Annealer", "art": "glass_annealer", "special": "glass_annealer",
		"hp": 58, "radius": 23.0, "speed": 84.0, "spacing": 148.0, "reach": 180.0,
		"damage": 6, "first": 70, "cooldown": 183, "windup": 42, "guard_reach": 167.0,
		"hint": "Grants Guard to a nearby ally. Focus the Annealer or push or pull the pair apart.",
	},
	"glass_lens_arbalist": {
		"name": "Lens Arbalist", "art": "glass_lens_arbalist", "special": "glass_lens_arbalist",
		"hp": 60, "radius": 21.0, "speed": 76.0, "spacing": 265.0, "reach": 440.0,
		"damage": 6, "first": 83, "cooldown": 150, "windup": 41, "far_threshold": 220.0, "target": "farthest",
		"hint": "Aims at the farthest hero and deals extra damage at long range. Close the gap or time Guard.",
	},
	"glass_kiln_ram": {
		"name": "Kiln Ram", "art": "glass_kiln_ram", "special": "glass_kiln_ram",
		"hp": 81, "radius": 31.0, "speed": 94.0, "spacing": 84.0, "reach": 167.0,
		"damage": 8, "first": 93, "cooldown": 164, "windup": 27,
		"hint": "Telegraphs a headbutt that knocks a hero away. Shove the ram out of reach or follow with a ranged tile.",
	},
	"glass_shard_conductor": {
		"name": "Shard Conductor", "art": "glass_shard_conductor", "special": "glass_shard_conductor",
		"hp": 73, "radius": 23.0, "speed": 86.0, "spacing": 172.0, "reach": 248.0,
		"damage": 8, "first": 79, "cooldown": 155, "windup": 38, "chain_radius": 112.0,
		"hint": "Shocks a hero and arcs to the nearest ally beside them. Spread out or give both heroes Guard.",
	},
	"glass_ash_siphon": {
		"name": "Ash Siphon", "art": "glass_ash_siphon", "special": "glass_ash_siphon",
		"hp": 64, "radius": 22.0, "speed": 93.0, "spacing": 107.0, "reach": 156.0,
		"damage": 7, "first": 89, "cooldown": 161, "windup": 32,
		"hint": "Heals from damage that reaches a hero's HP. Catch the strike with Guard or push it out of reach.",
	},
	"glass_quench_sentinel": {
		"name": "Quench Sentinel", "art": "glass_quench_sentinel", "special": "glass_quench_sentinel",
		"hp": 75, "radius": 26.0, "speed": 89.0, "spacing": 98.0, "reach": 168.0,
		"damage": 7, "first": 92, "cooldown": 156, "windup": 34,
		"hint": "Strips up to 7 Guard before a jab. Use displacement to make it miss or stack enough Guard for both.",
	},
	"glass_furnace_knight": {
		"name": "Furnace Knight", "art": "glass_furnace_knight", "special": "glass_furnace_knight",
		"hp": 89, "radius": 31.0, "speed": 80.0, "spacing": 93.0, "reach": 164.0,
		"damage": 8, "first": 99, "cooldown": 154, "windup": 35,
		"hint": "Builds heat and damage after strikes that reach HP. Focus it early or use Guard to keep it cool.",
	},
}


static func begin(sim, enemy: Dictionary, target: Dictionary, attack: Dictionary) -> bool:
	var move: String = attack.special
	var position: Vector2 = enemy.pos
	var distance := position.distance_to(target.pos)
	var message: String
	match move:
		"glass_mirrorback":
			if distance > attack.stance_reach:
				return false
			message = "%s raises its mirror. The next hit can rebound." % enemy.name
		"glass_annealer":
			target = _guard_target(sim, enemy, attack.guard_reach)
			if target.is_empty():
				return false
			message = "%s readies Guard for %s." % [enemy.name, target.name]
		_:
			if distance > attack.reach:
				return false
			match move:
				"glass_lens_arbalist":
					message = "%s sights %s. Its shot hits harder past %d range." % [enemy.name, target.name, int(attack.far_threshold)]
				"glass_kiln_ram":
					message = "%s lines up a headbutt on %s." % [enemy.name, target.name]
				"glass_shard_conductor":
					message = "%s charges an arc through %s and a nearby ally." % [enemy.name, target.name]
				"glass_ash_siphon":
					message = "%s winds up a draining strike on %s." % [enemy.name, target.name]
				"glass_quench_sentinel":
					message = "%s prepares to shatter %s's Guard." % [enemy.name, target.name]
				"glass_furnace_knight":
					message = "%s winds up at %s. Heat %d of 3." % [enemy.name, target.name, enemy.get("furnace_heat", 0)]
				_:
					return false
	enemy.special_intent = move
	enemy.intent = target.id
	enemy.intent_tick = sim.tick + int(attack.windup)
	sim._emit("intent", message, enemy, target, move)
	return true


static func resolve(sim, enemy: Dictionary, target: Dictionary, attack: Dictionary, move: String) -> void:
	if move == "glass_mirrorback" or target.get("hp", 0) <= 0:
		return
	var position: Vector2 = enemy.pos
	var distance := position.distance_to(target.pos)
	if move == "glass_annealer":
		if distance <= attack.guard_reach:
			sim._guard(target, 9, move, enemy)
		else:
			sim._emit("miss", "%s moves beyond the kiln's Guard." % target.name, enemy, target, move)
		return
	if distance > attack.reach:
		sim._emit("miss", "%s moves out of %s's reach." % [target.name, enemy.name], enemy, target, move)
		return
	var defender: Dictionary = sim._intercept_target(target)
	var damage: int = attack.damage
	match move:
		"glass_lens_arbalist":
			if distance >= attack.far_threshold:
				damage += 7
				sim._emit("ranged_warning", "%s lands a long shot." % enemy.name, enemy, defender, move, 7)
		"glass_quench_sentinel":
			var removed := mini(defender.guard, 7)
			if removed > 0:
				defender.guard -= removed
				sim._emit("guard_break", "%s breaks %d Guard." % [enemy.name, removed], enemy, defender, move, removed)
		"glass_furnace_knight":
			damage += 3 * int(enemy.get("furnace_heat", 0))
	var hp_before: int = defender.hp
	sim._damage(enemy, defender, damage, "enemy_attack")
	var hp_lost: int = hp_before - defender.hp
	match move:
		"glass_kiln_ram":
			if defender.hp > 0:
				sim._displace("push", enemy, defender, move, defender.pos - position, 370.0)
		"glass_shard_conductor":
			_chain(sim, enemy, target, defender, attack)
		"glass_ash_siphon":
			var recovered := mini(hp_lost, int(enemy.max_hp - enemy.hp))
			if recovered > 0:
				enemy.hp += recovered
				sim._emit("heal", "%s siphons %d HP." % [enemy.name, recovered], enemy, enemy, move, recovered)
		"glass_furnace_knight":
			if hp_lost > 0 and int(enemy.get("furnace_heat", 0)) < 3:
				enemy.furnace_heat = int(enemy.get("furnace_heat", 0)) + 1
				sim._emit("heat", "%s gains heat (%d of 3)." % [enemy.name, enemy.furnace_heat], enemy, enemy, move, enemy.furnace_heat)


static func on_tile_hit(sim, attacker: Dictionary, enemy: Dictionary, amount: int, _tile_id: String, _order: int) -> void:
	if enemy.get("special_intent", "") != "glass_mirrorback" or amount <= 0:
		return
	enemy.special_intent = ""
	enemy.intent = ""
	enemy.intent_tick = 0
	enemy.next_attack = sim.tick + int(enemy.attack.cooldown)
	var reflected := clampi(ceili(amount * 0.55), 1, 15)
	sim._emit("counter", "%s reflects %d damage at %s." % [enemy.name, reflected, attacker.name], enemy, attacker, "glass_mirrorback_counter", reflected)
	sim._damage(enemy, attacker, reflected, "glass_mirrorback_counter")


static func _guard_target(sim, enemy: Dictionary, radius: float) -> Dictionary:
	var position: Vector2 = enemy.pos
	var closest := radius * radius
	var result := {}
	for ally: Dictionary in sim.units:
		if ally.side != enemy.side or ally.id == enemy.id or ally.hp <= 0 or ally.guard > 19:
			continue
		var squared := position.distance_squared_to(ally.pos)
		if squared <= closest and (result.is_empty() or squared < closest):
			closest = squared
			result = ally
	return result


static func _chain(sim, enemy: Dictionary, target: Dictionary, defender: Dictionary, attack: Dictionary) -> void:
	var center: Vector2 = target.pos
	var nearest := {}
	var closest: float = attack.chain_radius * attack.chain_radius
	for ally: Dictionary in sim._enemies_in_area(enemy, center, attack.chain_radius):
		if ally.id == target.id or ally.id == defender.id:
			continue
		var squared := center.distance_squared_to(ally.pos)
		if nearest.is_empty() or squared < closest:
			nearest = ally
			closest = squared
	if nearest.is_empty():
		return
	var damage := maxi(1, floori(attack.damage * 0.5))
	sim._emit("arc", "%s arcs to %s." % [enemy.name, nearest.name], enemy, nearest, "glass_shard_conductor", damage, center)
	sim._damage(enemy, nearest, damage, "glass_shard_arc")
