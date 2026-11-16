extends RefCounted

const ClassRelics = preload("res://scripts/class_relics.gd")

const WARDEN := "warden_shield_rivet"
const BULWARK := "bulwark_watch_badge"
const BREAKER := "breaker_impact_pin"
const HEXWRIGHT := "hexwright_tow_hook"
const WAYFARER := "wayfarer_glass_compass"
const LANCER := "lancer_trail_spur"
const CANTOR := "cantor_echo_clasp"
const APOTHECARY := "apothecary_tonic_charm"
const RUNE_SMITH := "rune_smith_seal"
const STARSHOT := "starshot_sight_glass"
const CINDER_MAGE := "cinder_mage_ember_locket"
const DUELIST := "duelist_second_point"


static func equip(hero: Dictionary, id: String) -> void:
	if not id.is_empty() and ClassRelics.owner(id) == hero.get("class"):
		hero["class_relic"] = id


static func on_guard_block(sim, hero: Dictionary, tile_id: String) -> void:
	_grant_guard(sim, WARDEN, hero, hero, ClassRelics.WARDEN_GUARD, tile_id)


static func on_intercept(sim, hero: Dictionary, ally: Dictionary) -> void:
	_grant_guard(sim, BULWARK, hero, ally, ClassRelics.BULWARK_GUARD, "bulwark")


static func on_ally_guard(sim, hero: Dictionary, ally: Dictionary, tile_id: String) -> void:
	if hero.id != ally.id and _is_current_tile(sim, hero, tile_id):
		_grant_guard(sim, BULWARK, hero, ally, ClassRelics.BULWARK_GUARD, tile_id)


static func on_push(sim, hero: Dictionary, enemy: Dictionary, tile_id: String) -> void:
	if enemy.hp <= 0 or not _is_current_tile(sim, hero, tile_id) or not _spend(sim, hero, BREAKER):
		return
	var extra := ClassRelics.BREAKER_COLLISION_DAMAGE
	if enemy.has("collision_push"):
		enemy.collision_push["impact_pin"] = extra
	var dealt := _extra_hit(sim, hero, enemy, tile_id, extra, BREAKER)
	_report(sim, hero, enemy, tile_id, dealt, "The push dealt %d damage" % dealt)


static func on_pull(sim, hero: Dictionary, enemy: Dictionary, tile_id: String) -> void:
	if enemy.hp <= 0 or not _is_current_tile(sim, hero, tile_id) or not _spend(sim, hero, HEXWRIGHT):
		return
	var dealt := _extra_hit(sim, hero, enemy, tile_id, ClassRelics.HEXWRIGHT_PULL_DAMAGE, HEXWRIGHT)
	_report(sim, hero, enemy, tile_id, dealt, "The pull dealt %d damage" % dealt)


static func on_mark_spent(sim, owner_id: String, ally: Dictionary, tile_id: String, grant_tile: String) -> void:
	if owner_id.is_empty() or owner_id == ally.get("id", "") or ally.get("hp", 0) <= 0:
		return
	var owner: Dictionary = sim._find_unit(owner_id)
	_grant_guard(sim, CANTOR, owner, ally, ClassRelics.CANTOR_GUARD, tile_id, {"grant_tile": grant_tile})


static func on_tile_heal(sim, hero: Dictionary, recipient: Dictionary, tile_id: String) -> void:
	if not _spend(sim, hero, APOTHECARY) or recipient.has("class_tonic"):
		return
	recipient["class_tonic"] = {"owner": hero.id, "tile": tile_id}
	sim._emit("class_relic_ready", "Tonic Charm primes %s's next hit." % recipient.name,
		hero, recipient, APOTHECARY, ClassRelics.APOTHECARY_HIT_DAMAGE, Vector2.INF, Vector2.INF,
		{"source_tile": tile_id})


static func on_rune_released(sim, hero: Dictionary, tile_id: String) -> void:
	if _is_current_tile(sim, hero, tile_id):
		_grant_guard(sim, RUNE_SMITH, hero, hero, ClassRelics.RUNE_SMITH_GUARD, tile_id)


static func primary_bonus(sim, hero: Dictionary, enemy: Dictionary, tile_id: String) -> int:
	var bonus := _tonic_bonus(sim, hero, enemy, tile_id)
	match hero.get("class_relic", ""):
		WAYFARER:
			if _recent_motion(sim, hero, "last_teleport_tick", false) and _spend(sim, hero, WAYFARER):
				bonus += ClassRelics.WAYFARER_HIT_DAMAGE
				_report(sim, hero, enemy, tile_id, ClassRelics.WAYFARER_HIT_DAMAGE)
		DUELIST:
			if hero.get("last_primary_tile_target", "") == enemy.id and _spend(sim, hero, DUELIST):
				bonus += ClassRelics.DUELIST_HIT_DAMAGE
				_report(sim, hero, enemy, tile_id, ClassRelics.DUELIST_HIT_DAMAGE)
	return bonus


static func critical_bonus(sim, hero: Dictionary, enemy: Dictionary, tile_id: String) -> int:
	if not sim.is_ranged_tile(tile_id) or not _spend(sim, hero, STARSHOT):
		return 0
	var extra := ClassRelics.STARSHOT_CRIT_DAMAGE
	_report(sim, hero, enemy, tile_id, extra)
	return extra


static func trail_bonus(sim, hero: Dictionary) -> int:
	if hero.get("class_relic") == LANCER and _recent_motion(sim, hero, "last_dash_tick", true) \
			and _spend(sim, hero, LANCER):
		return ClassRelics.LANCER_HIT_DAMAGE
	return 0


static func trail_wave(sim, hero: Dictionary, enemy: Dictionary, tile_id: String) -> void:
	var center: Vector2 = enemy.pos
	var radius := ClassRelics.LANCER_WAVE_RADIUS
	sim._emit("class_relic_wave", "Trail Spur releases a shockwave.", hero, enemy, LANCER, 0, center, center,
		{"radius": radius, "source_tile": tile_id})
	var splash := 0
	for neighbor: Dictionary in sim._enemies_in_area(hero, center, radius):
		if neighbor.id != enemy.id:
			splash += _extra_hit(sim, hero, neighbor, tile_id, ClassRelics.LANCER_WAVE_DAMAGE, LANCER, center)
	var extra := ClassRelics.LANCER_HIT_DAMAGE
	_report(sim, hero, enemy, tile_id, extra + splash, "+%d impact damage and %d splash damage" % [extra, splash], center,
		{"splash_damage": splash, "radius": radius})


static func burn_bonus(sim, hero: Dictionary, tile_id: String) -> int:
	if sim.TILES.has(tile_id) and _spend(sim, hero, CINDER_MAGE):
		return ClassRelics.CINDER_BURN_DAMAGE
	return 0


static func burn_spark(sim, hero: Dictionary, enemy: Dictionary, tile_id: String) -> void:
	var center: Vector2 = enemy.pos
	var neighbors: Array[Dictionary] = sim._splash_neighbors(hero, enemy, ClassRelics.CINDER_SPARK_RADIUS)
	var splash := 0
	var sparked := ""
	if not neighbors.is_empty():
		sim._sort_by_distance(neighbors, center)
		sparked = neighbors[0].id
		splash = _extra_hit(sim, hero, neighbors[0], tile_id, ClassRelics.CINDER_SPARK_DAMAGE, CINDER_MAGE, center)
	var extra := ClassRelics.CINDER_BURN_DAMAGE
	_report(sim, hero, enemy, tile_id, extra + splash, "+%d Burn damage and %d splash damage" % [extra, splash], center,
		{"splash_damage": splash, "secondary_target": sparked})


static func _tonic_bonus(sim, hero: Dictionary, enemy: Dictionary, tile_id: String) -> int:
	if not hero.has("class_tonic"):
		return 0
	var tonic: Dictionary = hero.class_tonic
	hero.erase("class_tonic")
	var owner: Dictionary = sim._find_unit(tonic.owner)
	if owner.is_empty():
		return 0
	var extra := ClassRelics.APOTHECARY_HIT_DAMAGE
	_report(sim, owner, enemy, tile_id, extra, "%s's hit gained %d damage" % [hero.name, extra], sim._attack_origin(hero),
		{"beneficiary": hero.id, "grant_tile": tonic.tile})
	return extra


static func _recent_motion(sim, hero: Dictionary, key: String, current_tick: bool) -> bool:
	var moved: int = hero.get(key, -1)
	return moved >= 0 and (current_tick or moved < sim.tick) and sim.tick - moved <= ClassRelics.MOBILITY_BEATS * sim.TICKS_PER_BEAT


static func _is_current_tile(sim, hero: Dictionary, tile_id: String) -> bool:
	return sim._activation.get("actor") == hero.id and sim._activation.get("tile") == tile_id


static func _spend(sim, hero: Dictionary, id: String) -> bool:
	if hero.get("class_relic", "") != id or hero.get("hp", 0) <= 0 \
			or hero.get("class_relic_loop", -1) == sim._loop_index():
		return false
	hero["class_relic_loop"] = sim._loop_index()
	return true


static func _grant_guard(sim, id: String, owner: Dictionary, recipient: Dictionary, amount: int,
		tile_id: String, details := {}) -> void:
	if recipient.get("hp", 0) <= 0:
		return
	var gain := mini(amount, sim.MAX_GUARD - int(recipient.guard))
	if gain <= 0 or not _spend(sim, owner, id):
		return
	sim._guard(recipient, gain, id, owner, false)
	_report(sim, owner, recipient, tile_id, gain, "%s gained %d Guard" % [recipient.name, gain], Vector2.INF, details)


static func _extra_hit(sim, hero: Dictionary, target: Dictionary, tile_id: String, amount: int, id: String,
		origin := Vector2.INF) -> int:
	var before: int = target.hp
	var details := {"class_relic": id, "source_tile": tile_id}
	if origin != Vector2.INF:
		details["strike_origin"] = origin
	sim._damage(hero, target, amount, tile_id, ClassRelics.definition(id).label, details)
	return before - int(target.hp)


static func _report(sim, owner: Dictionary, target: Dictionary, tile_id: String, amount: int,
		effect := "", origin := Vector2.INF, details := {}) -> void:
	var id: String = owner.class_relic
	var meta := details.duplicate()
	meta["source_tile"] = tile_id
	meta["class_relic"] = true
	var label: String = ClassRelics.definition(id).label
	var tile_label: String = sim.TILES.get(tile_id, {}).get("label", "Intercept" if tile_id == "bulwark" else "Guard block")
	sim._relic_proc(id, label, amount, owner, target, tile_label, sim._beat(), effect, origin, meta)
