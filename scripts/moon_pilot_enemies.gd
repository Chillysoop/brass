extends RefCounted

const ENEMIES := {
	"dock_saltblade": {
		"name": "Saltblade", "art": "dock_saltblade", "special": "dock_saltblade",
		"hp": 28, "radius": 21.0, "speed": 101.0, "spacing": 83.0, "reach": 133.0,
		"damage": 4, "first": 75, "cooldown": 156, "windup": 27,
		"hint": "Backsteps if Guard absorbs its slash. Follow it with a ranged tile, or close in after the slash lands.",
	},
	"dock_torchbearer": {
		"name": "Torchbearer", "art": "dock_torchbearer", "special": "dock_torchbearer",
		"hp": 34, "radius": 23.0, "speed": 87.0, "spacing": 87.0, "reach": 129.0,
		"damage": 7, "first": 74, "cooldown": 177, "windup": 47,
		"hint": "Slowly raises its lantern before swinging through the marked circle. Time Guard or push the torchbearer out of range.",
	},
	"dock_bilge_sapper": {
		"name": "Bilge Sapper", "art": "dock_bilge_sapper", "special": "dock_bilge_sapper",
		"hp": 37, "radius": 22.0, "speed": 83.0, "spacing": 159.0, "reach": 310.0,
		"damage": 5, "first": 63, "cooldown": 154, "windup": 39, "blast_radius": 52.0,
		"hint": "Marks a spot with brine. Step or blink off it before the splash, or use Guard to block the damage.",
	},
	"dock_shellback": {
		"name": "Shellback", "art": "dock_shellback", "special": "dock_shellback",
		"hp": 46, "radius": 26.0, "speed": 75.0, "spacing": 91.0, "reach": 144.0,
		"damage": 5, "first": 81, "cooldown": 168, "windup": 41,
		"hint": "Raises 8 Guard if it finishes locking its shell. Hit for at least 17 HP during the windup to break the shell for the fight.",
	},
	"dock_hull_harrier": {
		"name": "Hull Harrier", "art": "dock_hull_harrier", "special": "dock_hull_harrier",
		"hp": 42, "radius": 22.0, "speed": 99.0, "spacing": 86.0, "reach": 156.0,
		"damage": 5, "first": 70, "cooldown": 149, "windup": 36,
		"hint": "Swings to the far side of its target and strikes. Push it out of range while it readies the rope.",
	},
	"powder_runner": {
		"name": "Powder Runner", "art": "powder_runner", "hint": "Land two separate tile hits during its fuse, or defeat it before the shot.",
		"hp": 50, "radius": 23.0, "speed": 88.0, "spacing": 156.0, "target": "lowest_hp",
		"reach": 410.0, "damage": 11, "first": 31, "cooldown": 160, "windup": 65, "special": "powder_runner",
	},
	"tar_pitcher": {
		"name": "Tar Pitcher", "art": "tar_pitcher", "hint": "Throws tar at the farthest hero. Block the hit to keep moving at full speed.",
		"hp": 48, "radius": 23.0, "speed": 76.0, "spacing": 180.0, "target": "farthest",
		"reach": 400.0, "damage": 4, "first": 59, "cooldown": 132, "windup": 32, "special": "tar_pitcher",
	},
	"deck_ram": {
		"name": "Deck Ram", "art": "deck_ram", "hint": "Charges down a marked line. Move across it or push the ram out of reach.",
		"hp": 69, "radius": 29.0, "speed": 86.0, "spacing": 104.0,
		"reach": 200.0, "damage": 8, "first": 56, "cooldown": 145, "windup": 39, "special": "deck_ram",
	},
	"patch_rigger": {
		"name": "Patch Rigger", "art": "patch_rigger", "hint": "Gives Guard to a wounded crewmate. Pressure the rigger or split them apart.",
		"hp": 47, "radius": 23.0, "speed": 81.0, "spacing": 169.0,
		"reach": 190.0, "damage": 4, "first": 53, "cooldown": 136, "windup": 36,
		"special": "patch_rigger", "patch_reach": 175.0, "patch_guard": 10,
	},
	"reef_diver": {
		"name": "Reef Diver", "art": "reef_diver", "hint": "A tile hit during its windup cancels the strike but sends the diver back. Use a quick hit or Guard the strike.",
		"hp": 56, "radius": 24.0, "speed": 93.0, "spacing": 118.0, "target": "lowest_hp",
		"reach": 157.0, "damage": 8, "first": 71, "cooldown": 139, "windup": 40, "special": "reef_diver",
	},
	"signal_gunner": {
		"name": "Signal Gunner", "art": "signal_gunner", "hint": "Lines up a heavy shot against distant heroes. Close the distance or time Guard.",
		"hp": 48, "radius": 22.0, "speed": 74.0, "spacing": 255.0, "target": "farthest",
		"reach": 244.0, "damage": 5, "first": 28, "cooldown": 144, "windup": 39,
		"special": "signal_gunner", "rifle_min": 244.0, "rifle_max": 530.0, "rifle_bonus": 6,
	},
	"chain_warden": {
		"name": "Chain Warden", "art": "chain_warden", "hint": "Strips up to 8 Guard from the most guarded hero in reach before striking.",
		"hp": 65, "radius": 27.0, "speed": 85.0, "spacing": 106.0,
		"reach": 166.0, "damage": 7, "first": 54, "cooldown": 139, "windup": 35, "special": "chain_warden",
	},
	"wreck_bell": {
		"name": "Wreck Bell", "art": "wreck_bell", "hint": "Rings out to knock nearby heroes away. Spread out or push the bell out of range.",
		"hp": 60, "radius": 28.0, "speed": 74.0, "spacing": 122.0,
		"reach": 155.0, "damage": 5, "first": 65, "cooldown": 158, "windup": 44, "special": "wreck_bell",
	},
}


static func begin(sim, enemy: Dictionary, target: Dictionary, attack: Dictionary) -> bool:
	var origin: Vector2 = enemy.pos
	var distance := origin.distance_to(target.pos)
	var message: String
	match attack.special:
		"patch_rigger":
			target = _wounded_ally(sim.units, enemy, attack.patch_reach)
			if target.is_empty():
				return false
			message = "Patch Rigger readies a shield for %s." % target.name
		"signal_gunner":
			if distance < attack.rifle_min or distance > attack.rifle_max:
				return false
			message = "Signal Gunner lines up a long shot at %s." % target.name
		"chain_warden":
			target = _most_guarded_hero(sim.units, enemy, attack.reach)
			if target.is_empty():
				return false
			message = "Chain Warden readies a Guard-breaking swing at %s." % target.name
		_:
			if distance > attack.reach:
				return false
			match attack.special:
				"dock_saltblade":
					message = "Saltblade prepares a slash. Guard makes it backstep."
				"dock_torchbearer":
					enemy["pilot_ring_radius"] = attack.reach
					message = "Torchbearer slowly raises its lantern for a swing."
				"dock_bilge_sapper":
					enemy["blast_center"] = target.pos
					enemy["blast_radius"] = attack.blast_radius
					message = "Bilge Sapper marks a brine splash. Move clear of the circle."
				"dock_shellback":
					if enemy.get("cracked_shell", false):
						return false
					message = "Shellback locks its shell. A hit for 17 HP cracks it."
				"dock_hull_harrier":
					message = "Hull Harrier readies a swing around %s." % target.name
				"powder_runner":
					enemy["powder_hits"] = 0
					enemy.erase("powder_last_hit")
					message = "Powder Runner lights the fuse. Land two separate tile hits to disarm it."
				"tar_pitcher":
					message = "Tar Pitcher aims tar at %s." % target.name
				"deck_ram":
					enemy["pilot_aim_point"] = target.pos
					enemy["pilot_aim_width"] = 40.0
					message = "Deck Ram lines up a charge. Move clear of the marked line."
				"reef_diver":
					message = "Reef Diver readies a harpoon. Hit it during the windup to force it back."
				"wreck_bell":
					enemy["pilot_ring_radius"] = 155.0
					message = "Wreck Bell prepares to ring. Move clear of its radius."
				_:
					return false
	enemy["special_intent"] = attack.special
	enemy.intent = target.id
	enemy.intent_tick = sim.tick + int(attack.windup)
	sim._emit("intent", message, enemy, target, attack.special)
	return true


static func resolve(sim, enemy: Dictionary, target: Dictionary, attack: Dictionary, move: String) -> void:
	if move == "dock_torchbearer":
		_resolve_lantern_swing(sim, enemy, attack)
		return
	if move == "dock_bilge_sapper":
		_resolve_brine(sim, enemy, attack)
		return
	if move == "dock_shellback":
		sim._guard(enemy, 8, move)
		return
	if move == "deck_ram":
		_resolve_deck_ram(sim, enemy, attack)
		return
	if move == "wreck_bell":
		_resolve_wreck_bell(sim, enemy, attack)
		return
	if move == "powder_runner":
		enemy.erase("powder_hits")
		enemy.erase("powder_last_hit")
	if target.get("hp", 0) <= 0:
		return
	var origin: Vector2 = enemy.pos
	var distance := origin.distance_to(target.pos)
	var reach: float = attack.get("patch_reach", attack.get("rifle_max", attack.reach))
	if distance > reach or distance < attack.get("rifle_min", 0.0):
		sim._emit("miss", "%s's windup misses %s." % [enemy.name, target.name], enemy, target, move)
		return
	if move == "patch_rigger":
		sim._guard(target, attack.patch_guard, move, enemy)
		return
	if move == "dock_hull_harrier" and not sim._teleport(enemy, target, move, 0.0):
		sim._emit("miss", "Hull Harrier finds no room to swing through.", enemy, target, move)
		return
	var defender: Dictionary = sim._intercept_target(target)
	var damage: int = attack.damage
	if move == "chain_warden":
		var stripped := mini(defender.guard, 8)
		if stripped > 0:
			defender.guard -= stripped
			sim._emit("guard_break", "Chain Warden strips %d Guard from %s." % [stripped, defender.name],
				enemy, defender, move, stripped)
	elif move == "signal_gunner":
		damage += int(attack.rifle_bonus)
	var hp_before: int = defender.hp
	var guard_before: int = defender.guard
	sim._damage(enemy, defender, damage, move)
	if move == "dock_saltblade" and defender.guard < guard_before:
		sim._retreat_from(enemy, defender, move, 64.0)
	if move == "tar_pitcher" and defender.hp > 0 and defender.hp < hp_before:
		defender["tar_slow_until"] = sim.tick + 2 * sim.TICKS_PER_BEAT
		sim._emit("tar_slow", "Tar slows %s for two beats." % defender.name, enemy, defender, move)


static func on_tile_hit(sim, attacker: Dictionary, enemy: Dictionary, amount: int, _tile_id: String, order: int) -> void:
	if amount <= 0 or enemy.intent == "" or sim.tick > enemy.intent_tick:
		return
	match enemy.get("special_intent", ""):
		"dock_shellback":
			if amount >= 17:
				enemy["cracked_shell"] = true
				_cancel_windup(sim, enemy)
				sim._emit("interrupt", "The hit cracks Shellback's shell.", attacker, enemy, "dock_shellback_interrupted")
		"powder_runner":
			if order == enemy.get("powder_last_hit", -1):
				return
			enemy["powder_last_hit"] = order
			enemy.powder_hits += 1
			if enemy.powder_hits == 1:
				sim._emit("interrupt", "First hit on the fuse. One more disarms it.", attacker, enemy, "powder_runner_progress", 1)
				return
			_cancel_windup(sim, enemy)
			enemy.erase("powder_hits")
			enemy.erase("powder_last_hit")
			sim._emit("interrupt", "Two tile hits disarm the fuse.", attacker, enemy, "powder_runner_disarmed", 2)
		"reef_diver":
			_cancel_windup(sim, enemy)
			sim._teleport(enemy, attacker, "reef_diver_retreat", 96.0)
			sim._emit("interrupt", "The hit interrupts the Reef Diver's harpoon.", attacker, enemy, "reef_diver_interrupted")


static func _cancel_windup(sim, enemy: Dictionary) -> void:
	enemy.intent = ""
	enemy.intent_tick = 0
	enemy.next_attack = sim.tick + int(enemy.attack.cooldown)
	enemy.erase("special_intent")


static func _wounded_ally(units: Array, enemy: Dictionary, reach: float) -> Dictionary:
	var origin: Vector2 = enemy.pos
	var wounded := {}
	var lowest := 1.0
	for ally: Dictionary in units:
		if ally.side != enemy.side or ally.id == enemy.id or ally.hp <= 0 or ally.guard >= 10 \
				or origin.distance_to(ally.pos) > reach:
			continue
		var health := float(ally.hp) / float(ally.max_hp)
		if health < lowest:
			wounded = ally
			lowest = health
	return wounded


static func _most_guarded_hero(units: Array, enemy: Dictionary, reach: float) -> Dictionary:
	var origin: Vector2 = enemy.pos
	var target := {}
	var nearest := INF
	for hero: Dictionary in units:
		if hero.side == enemy.side or hero.hp <= 0:
			continue
		var distance := origin.distance_to(hero.pos)
		if distance <= reach and (target.is_empty() or hero.guard > target.guard \
				or (hero.guard == target.guard and distance < nearest)):
			target = hero
			nearest = distance
	return target


static func _resolve_deck_ram(sim, enemy: Dictionary, attack: Dictionary) -> void:
	var origin: Vector2 = enemy.pos
	var aim: Vector2 = enemy.pilot_aim_point
	var radius: float = enemy.pilot_aim_width
	enemy.erase("pilot_aim_point")
	enemy.erase("pilot_aim_width")
	var endpoint := origin.move_toward(aim, float(attack.reach))
	var landing: Vector2 = sim._slide_landing(enemy, sim._bounded(origin.move_toward(endpoint, 95.0), enemy.radius))
	enemy.pos = landing
	enemy.prev_pos = landing
	sim._emit("charge", "Deck Ram rushes the marked line.", enemy, {}, "deck_ram", 0, origin, endpoint)
	for hero: Dictionary in sim.units:
		if hero.side == enemy.side or hero.hp <= 0:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(hero.pos, origin, endpoint)
		if closest.distance_to(hero.pos) <= radius:
			sim._damage(enemy, hero, attack.damage, "deck_ram")


static func _resolve_wreck_bell(sim, enemy: Dictionary, attack: Dictionary) -> void:
	var radius: float = enemy.pilot_ring_radius
	enemy.erase("pilot_ring_radius")
	sim._emit("bell_ring", "Wreck Bell rings out.", enemy, enemy, "wreck_bell", roundi(radius))
	for hero: Dictionary in sim._enemies_in_area(enemy, enemy.pos, radius):
		sim._damage(enemy, hero, attack.damage, "wreck_bell")
		if hero.hp > 0:
			sim._displace("push", enemy, hero, "wreck_bell", hero.pos - enemy.pos, 375.0)


static func _resolve_lantern_swing(sim, enemy: Dictionary, attack: Dictionary) -> void:
	enemy.erase("pilot_ring_radius")
	var affected: Array = sim._enemies_in_area(enemy, enemy.pos, attack.reach)
	if affected.is_empty():
		sim._emit("miss", "Torchbearer's lantern swing misses.", enemy, enemy, "dock_torchbearer")
	for hero: Dictionary in affected:
		sim._damage(enemy, hero, attack.damage, "dock_torchbearer")


static func _resolve_brine(sim, enemy: Dictionary, attack: Dictionary) -> void:
	var center: Vector2 = enemy.blast_center
	enemy.erase("blast_center")
	enemy.erase("blast_radius")
	sim._emit("hazard_burst", "The brine splashes.", enemy, {}, "dock_bilge_sapper", int(attack.blast_radius), center, center)
	for hero: Dictionary in sim._enemies_in_area(enemy, center, attack.blast_radius):
		sim._damage(enemy, hero, attack.damage, "dock_bilge_sapper")
