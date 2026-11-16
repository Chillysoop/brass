extends Control

const GameIcons = preload("res://scripts/game_icons.gd")
const CombatIcons = preload("res://scripts/combat_icons.gd")
const ArenaSim = preload("res://scripts/arena_sim.gd")
const AttackAnimation = preload("res://scripts/attack_animation.gd")
const HeroChoreography = preload("res://scripts/hero_attack_choreography.gd")
const EnemyChoreography = preload("res://scripts/enemy_attack_choreography.gd")
const CombatSpritePose = preload("res://scripts/combat_sprite_pose.gd")
const WORLD_SIZE := Vector2(1000.0, 520.0)
const MAX_CASTS := 48
const MAX_COMBAT_NUMBERS := 64
const COMBAT_NUMBER_LIFETIME := 1.05
const CRITICAL_NUMBER_LIFETIME := 1.55
const COMBAT_NUMBER_RISE := 23.0
const COMBAT_NUMBER_PADDING := 6.0
const COMBAT_NUMBER_POP := 1.16
const CURVED_CHARGE_SECONDS := 0.11
const INK := Color("#182126")
const FRAME := Color("#47534b")
const SAND := Color("#be955f")
const HERO_COLOR := Color("#62cfbd")
const ENEMY_COLOR := Color("#df8262")
const GOLD := Color("#f3cb80")
const WHITE := Color("#fff0d2")
const TELEPORT_COLOR := Color("#b2afd9")
const RELAY_SHIELD_COLOR := Color("#91e2f4")
const AIM_COLOR := Color("#ad463e")
const AIM_EDGE := Color("#4e2530")
const SWEEP_EDGE := Color("#542835")
const SWEEP_LIGHT := Color("#ffde97")
const ALLY_INTENT_ICONS := {"crown_war_drummer": "haste", "crown_galvanist": "teleport", "mender_repair": "heal"}
const RIGHT_RELAY_COLOR := Color("#e7b3ff")
const DOCK_WINCH_COLOR := Color("#e6c193")
const REPAIR_COLOR := Color("#a9e5bd")
const REPAIRMASTER_DASH := "repairmaster_dash"
const REPAIRMASTER_REPAIR := "repairmaster_repair"
const VANGUARD_CHARGE := "brass_vanguard_charge"
const CANNON_SHOT := "brass_cannon_shot"
const VANGUARD_COLOR := Color("#ff9e7c")
const CANNON_COLOR := Color("#ffe5ac")
const CANNON_SMOKE := Color("#3d2b36")
const CANNON_MUZZLE_OFFSET := Vector2(-0.66, -0.53)
const ARENA_TEXTURES := {"glass": "glass_arena", "crown": "crown_arena", "moonwreck": "moonwreck_arena"}
const ARENA_PATHS := {
	"arena": "res://assets/arena.webp",
	"glass_arena": "res://assets/glass-arena.webp",
	"crown_arena": "res://assets/crown-arena.webp",
	"moonwreck_arena": "res://assets/moonwreck-arena.webp",
}
const EFFECT_LENGTHS := {
	"pull": 0.42,
	"push": 0.33,
	"teleport": 0.56,
	"veil_echo": 0.38,
	"hit": 0.38,
	"guard": 0.36,
	"miss": 0.42,
	"defeat_unit": 0.46,
	"hazard_burst": 0.55,
	"heal": 0.60,
	"repair_heal": 0.60,
	"repair_interrupted": 0.65,
	"repair_separated": 0.65,
	"brass_cannon_impact": 0.55,
	"marshal_plate_broken": 1.1,
	"marshal_sweep_weathered": 0.75,
	"relay_interrupted": 0.65,
	"relay_link_broken": 0.42,
	"relay_marshal_separated": 0.55,
	"wreckmaster_slam": 0.42,
	"wreckmaster_slam_miss": 0.55,
	"tidekeeper_unanchored": 0.55,
	"admiral_reversed": 0.55,
	"afterimage": 0.44,
	"barrage_rack": 0.34,
	"siege_fuse": 0.46,
	"stepped_gear": 0.32,
	"twin_bell": 0.46,
	"guard_relay": 0.48,
	"flanking_standard": 0.60,
	"switchback_lens": 0.36,
	"longshot_prism": 0.38,
	"class_relic": 0.52,
	"class_relic_ready": 0.52,
	"class_relic_wave": 0.44,
	"retreat": 0.46,
	"charge": 0.50,
	"mark": 0.36,
	"mark_spent": 0.32,
	"guard_break": 0.34,
	"guard_spent": 0.34,
	"cluster_pull": 0.46,
	"ranged_followup_ready": 0.40,
	"ranged_followup_spent": 0.26,
	"sweep_push": 0.42,
	"hammer_collision": 0.30,
	"chorus_mark": 0.42,
	"chorus_mark_spent": 0.36,
	"chorus_guard": 0.42,
	"rune_charge_ready": 0.45,
	"rune_charge_spent": 0.33,
	"duel_stack": 0.24,
	"duel_kill_ready": 0.42,
	"duel_kill_spent": 0.30,
	"ember_ignite": 0.45,
	"ember_tick": 0.30,
	"bastion_ready": 0.35,
	"bastion_release": 0.48,
	"lance_travel_spent": 0.34,
	"lance_return_ready": 0.40,
	"lance_return_spent": 0.34,
	"counter": 0.38,
	"arc": 0.40,
	"ranged_warning": 0.33,
	"bell_ring": 0.49,
	"spring_jam": 0.65,
	"reinforcement": 0.65,
	"tar_slow": 0.45,
	"fuse_disarmed": 0.55,
	"haste": 0.42,
}
const MARK_COLOR := CombatIcons.PALETTE["mark"]
const MIN_CAST_DISPLAY_SECONDS := 0.24
const SIGNATURE_WINDUP_LABELS := {
	"recruit": "SPRING WINDUP", "bruiser": "SHOVE", "veteran": "SABER SWING", "boss": "TOLL STRIKE",
	"crown_page_advance": "ADVANCE", "relay_recruit": "BRACED", "relay_runner_press": "HEAVY WINDUP",
	"dockhand_parry": "PARRY", "chain_warden": "CHAIN REEL", "glass_skirmisher_feint": "FEINT",
	VANGUARD_CHARGE: "VANGUARD CHARGE", CANNON_SHOT: "CANNON SHOT",
}
const RELIC_EFFECTS := ["afterimage", "barrage_rack", "siege_fuse", "stepped_gear", "twin_bell", "switchback_lens",
	"longshot_prism", "guard_relay", "flanking_standard"]
const CLASS_RELIC_GLYPHS := {
	"warden_shield_rivet": "guard", "bulwark_watch_badge": "windup", "breaker_impact_pin": "push",
	"hexwright_tow_hook": "pull", "wayfarer_glass_compass": "teleport", "lancer_trail_spur": "splash",
	"cantor_echo_clasp": "haste", "apothecary_tonic_charm": "heal", "rune_smith_seal": "mark",
	"starshot_sight_glass": "range", "cinder_mage_ember_locket": "burn", "duelist_second_point": "attack",
}
const ENCOUNTER_EFFECTS := {
	"recruit_jammed": "spring_jam",
	"tollkeeper_repair_interrupted": "repair_interrupted",
	"tollkeeper_repair_separated": "repair_separated",
	"repairmaster_interrupted": "repair_interrupted",
	"brass_duo_disrupted": "relay_interrupted",
	"marshal_shattered": "marshal_plate_broken",
	"marshal_pressure_break": "marshal_plate_broken",
	"marshal_defense_break": "marshal_plate_broken",
	"marshal_sweep_weathered": "marshal_sweep_weathered",
	"relay_interrupted": "relay_interrupted",
	"relay_link_broken": "relay_link_broken",
	"relay_marshal_interrupted": "relay_interrupted",
	"relay_marshal_separated": "relay_marshal_separated",
	"crown_regent_interrupted": "relay_interrupted",
	"crown_link_separated": "relay_marshal_separated",
	"dock_winch_interrupted": "relay_interrupted",
	"wreckmaster_slam": "wreckmaster_slam",
	"wreckmaster_slam_miss": "wreckmaster_slam_miss",
	"tidekeeper_slam": "wreckmaster_slam",
	"tidekeeper_unanchored": "tidekeeper_unanchored",
	"tidekeeper_interrupted": "relay_interrupted",
	"admiral_sweep": "wreckmaster_slam",
	"admiral_unanchored": "tidekeeper_unanchored",
	"admiral_reversed": "admiral_reversed",
	"admiral_interrupted": "relay_interrupted",
	"powder_runner_disarmed": "fuse_disarmed",
	"reef_diver_interrupted": "relay_interrupted",
	"glass_lacquerer_interrupted": "relay_interrupted",
	"dock_shellback_interrupted": "relay_interrupted",
	"brass_flywheel_canceled": "relay_interrupted",
	"brass_pressure_vented": "relay_interrupted",
}
const FLOATING_CUES := {
	"spring_jam": "SPRING JAMMED",
	"repair_interrupted": "REPAIR INTERRUPTED",
	"repair_separated": "OUT OF REPAIR RANGE",
	"marshal_plate_broken": "PLATE BROKEN",
	"marshal_sweep_weathered": "SWEEP WEATHERED",
	"relay_interrupted": "INTERRUPTED",
	"relay_link_broken": "LINK BROKEN",
	"relay_marshal_separated": "SEPARATED",
	"tidekeeper_unanchored": "UNANCHORED",
	"admiral_reversed": "UNDERTOW REVERSED",
	"fuse_disarmed": "DISARMED",
}

var units: Array = []
var combat_tick := 0
var playback_paused := false
var _windups: Dictionary = {}
var _reinforcement_warning: Dictionary = {}
var location := "brass"
var _textures: Dictionary = {}
var _positions: Dictionary = {}
var _curved_charges: Dictionary = {}
var _sprite_geometry: Dictionary = {}
var _combat_sprites: Dictionary = {}
var _gait_phases: Dictionary = {}
var _gait_strengths: Dictionary = {}
var _effects: Array[Dictionary] = []
var _combat_numbers: Array[Dictionary] = []
var _combat_number_font := SystemFont.new()
var _combat_number_layout_size := Vector2.ZERO
var _attack_casts: Array[Dictionary] = []
var _actor_casts: Dictionary = {}
var _hero_clips: Array[Array] = []
var _hero_profiles: Dictionary = {}
var _enemy_profiles: Dictionary = {}
var _attack_rate := 1.0
var _animation_time := 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_number_font.font_names = PackedStringArray(["Segoe UI", "DejaVu Sans"])
	_combat_number_font.font_weight = 800
	custom_minimum_size.y = maxf(custom_minimum_size.y, 250.0)
	for key in ARENA_PATHS:
		var path: String = ARENA_PATHS[key]
		if ResourceLoader.exists(path, "Texture2D"):
			_textures[key] = ResourceLoader.load(path, "Texture2D") as Texture2D
	resized.connect(queue_redraw)


func reset_view(units_data: Array, lanes: Array = [], reinforcement: Dictionary = {}) -> void:
	units = units_data
	combat_tick = 0
	_reinforcement_warning = reinforcement
	_windups.clear()
	_effects.clear()
	_combat_numbers.clear()
	_attack_casts.clear()
	_actor_casts.clear()
	_hero_clips.clear()
	_attack_rate = 1.0
	for lane: Array in lanes:
		var clips: Array[Dictionary] = []
		for entry: Dictionary in lane:
			if not ArenaSim.TILES.has(entry.id):
				continue
			var right_edge := (int(entry.start) + int(ArenaSim.TILES[entry.id].width)) * ArenaSim.TICKS_PER_BEAT
			clips.append({"right_edge": right_edge,
				"ready": maxi(int(entry.start) * ArenaSim.TICKS_PER_BEAT, right_edge - 31),
				"profile": _hero_profile(entry.id)})
		_hero_clips.append(clips)
	_positions.clear()
	_curved_charges.clear()
	_combat_sprites.clear()
	_gait_phases.clear()
	_gait_strengths.clear()
	_animation_time = 0.0
	for unit in units:
		_positions[unit.id] = unit.pos
	queue_redraw()


func present(units_data: Array, events: Array, tick := 0, attack_cues: Array = [], playback_speed := 1,
		reinforcement: Dictionary = {}) -> void:
	units = units_data
	combat_tick = tick
	_reinforcement_warning = reinforcement
	_attack_rate = float(playback_speed)
	for unit: Dictionary in units:
		var finish := int(unit.get("intent_tick", 0))
		if unit.side != "enemy" or unit.hp <= 0 or str(unit.get("intent", "")).is_empty() or finish <= tick:
			_windups.erase(unit.id)
		else:
			var previous: Vector2i = _windups.get(unit.id, Vector2i.ZERO)
			var started := int(unit.get("intent_start_tick", previous.x if finish <= previous.y else tick))
			if previous != Vector2i(started, finish):
				_windups[unit.id] = Vector2i(started, finish)
	for cue: Dictionary in attack_cues:
		var profile := _hero_profile(cue.tile) if cue.kind == "hero_cast" else _enemy_profile(cue.tile, cue.get("attack", {}))
		var effect := cue.duplicate()
		effect["profile"] = profile
		effect["age"] = 0.0
		effect["lifetime"] = AttackAnimation.lifetime(profile)
		_attack_casts.append(effect)
		_actor_casts[cue.actor] = effect
		if _attack_casts.size() > MAX_CASTS:
			var oldest: Dictionary = _attack_casts.pop_front()
			if _actor_casts.get(oldest.actor, {}) == oldest:
				_actor_casts.erase(oldest.actor)
	for event in events:
		var tile: String = event.get("tile", "")
		if event.kind in ["hit", "heal", "guard"]:
			_add_combat_number(event)
		if tile == "relay_link_broken" and str(event.target).begins_with("crown_regent"):
			continue
		var kind: String = ENCOUNTER_EFFECTS.get(tile, event.get("kind", ""))
		if kind == "relic_proc":
			if tile in RELIC_EFFECTS:
				kind = tile
			elif CLASS_RELIC_GLYPHS.has(tile):
				kind = "class_relic"
		elif kind == "heal" and _is_repair_cue(tile):
			kind = "repair_heal"
		if not EFFECT_LENGTHS.has(kind):
			continue
		if kind in ["relay_marshal_separated", "relay_interrupted", "admiral_reversed"]:
			for index in range(_effects.size() - 1, -1, -1):
				var older := _effects[index]
				if older.target == event.target and FLOATING_CUES.has(older.kind):
					_effects.remove_at(index)
		if kind in ["charge", "retreat", "teleport"]:
			_register_movement_effect(kind, event)
		elif kind in ["push", "pull"] and _curved_charges.erase(event.target):
			_positions[event.target] = event.from
		var effect: Dictionary = event.duplicate()
		effect["kind"] = kind
		effect["age"] = 0.0
		if kind == "wreckmaster_slam":
			for unit: Dictionary in units:
				if unit.id == event.actor:
					effect["slam_radius"] = _dock_sweep_radius(unit)
					break
		_effects.append(effect)
	queue_redraw()


func _process(delta: float) -> void:
	if playback_paused:
		return
	_animation_time += delta
	var changed := false
	var blend := 1.0 - exp(-delta * 29.0)
	for unit in units:
		var position: Vector2 = unit.pos
		var charge: Dictionary = _curved_charges.get(unit.id, {})
		if not charge.is_empty():
			_positions[unit.id] = _advance_curved_charge(unit.id, position, charge, delta)
			_update_gait(unit, Vector2.ZERO, delta)
			changed = true
			continue
		var previous: Vector2 = _positions.get(unit.id, position)
		var traveled := Vector2.ZERO
		if previous.distance_squared_to(position) > 0.005:
			var displayed := previous.lerp(position, blend)
			traveled = displayed - previous
			_positions[unit.id] = displayed
			changed = true
		else:
			_positions[unit.id] = position
		_update_gait(unit, traveled, delta)
	for index in range(_effects.size() - 1, -1, -1):
		var effect := _effects[index]
		effect.age += delta
		if effect.age >= EFFECT_LENGTHS[effect.kind]:
			_effects.remove_at(index)
		changed = true
	for index in range(_combat_numbers.size() - 1, -1, -1):
		var number := _combat_numbers[index]
		number.age += delta
		if number.age >= number.lifetime:
			_combat_numbers.remove_at(index)
		changed = true
	for index in range(_attack_casts.size() - 1, -1, -1):
		var cast := _attack_casts[index]
		# Accelerated playback can cross an entire windup between renders.
		# Give the resulting cast a visible release while the sim runs at full speed.
		var rate := minf(_attack_rate, maxf(1.0, float(cast.lifetime) / MIN_CAST_DISPLAY_SECONDS))
		cast.age += delta * rate
		if cast.age >= cast.lifetime:
			if _actor_casts.get(cast.actor, {}) == cast:
				_actor_casts.erase(cast.actor)
			_attack_casts.remove_at(index)
		changed = true
	if changed or _has_animated_warning():
		queue_redraw()


func _register_movement_effect(kind: String, event: Dictionary) -> void:
	if _curved_charges.erase(event.actor):
		_positions[event.actor] = event.from
	if kind == "teleport":
		_positions[event.actor] = event.to
	elif kind == "charge":
		var enemy_charge: bool = event.get("tile", "") in [REPAIRMASTER_DASH, VANGUARD_CHARGE]
		var route: PackedVector2Array = event.get("route", PackedVector2Array())
		var step_count := 2 if enemy_charge else 3
		if route.size() >= step_count and (enemy_charge or str(event.actor).begins_with("hero_")):
			_positions[event.actor] = route[0]
			_curved_charges[event.actor] = {"route": route, "age": 0.0}


func _advance_curved_charge(actor: String, position: Vector2, charge: Dictionary, delta: float) -> Vector2:
	charge.age += delta
	var progress := float(charge.age) / CURVED_CHARGE_SECONDS
	if progress >= 1.0:
		_curved_charges.erase(actor)
		return position
	var route: PackedVector2Array = charge.route
	var sample := ease(progress, 0.68) * (route.size() - 1)
	var index := mini(floori(sample), route.size() - 2)
	var point := route[index].lerp(route[index + 1], sample - index)
	# The simulation can walk on from the landing while the rendering catches up.
	return point + (position - route[-1]) * smoothstep(0.63, 1.0, progress)


func _update_gait(unit: Dictionary, traveled: Vector2, delta: float) -> void:
	var drive: Vector2 = unit.get("drive_velocity", Vector2.ZERO)
	var driven := maxf(0.0, traveled.dot(drive.normalized()))
	if driven <= 0.01:
		_gait_strengths[unit.id] = 0.0
		return
	var phase: float = _gait_phases.get(unit.id, float(posmod(hash(unit.id), 627)) * 0.01)
	var facing: float = unit.get("facing", 1.0 if unit.side == "hero" else -1.0)
	var direction := -1.0 if drive.x * facing < -6.0 else 1.0
	var stride_length := maxf(34.0, float(unit.radius) * 1.8)
	_gait_phases[unit.id] = fposmod(phase + TAU * driven * direction / stride_length, TAU)
	_gait_strengths[unit.id] = minf(1.0, minf(drive.length(), driven / maxf(delta, 0.0001)) / 76.0)


func _draw() -> void:
	if size.x < 12.0 or size.y < 12.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	var board_size := Vector2(minf(size.x - 4.0, (size.y - 4.0) * 2.36), size.y - 4.0)
	var board := Rect2((size - board_size) * 0.5, board_size)
	var field_top := 0.40 if location in ["crown", "moonwreck"] else 0.27
	var field := Rect2(board.position + board.size * Vector2(0.10, field_top), board.size * Vector2(0.80, 0.87 - field_top))
	var sprite_scale := minf(field.size.x / WORLD_SIZE.x, field.size.y / WORLD_SIZE.y)
	_draw_arena(board)
	if location == "crown":
		_draw_relay_links(field)
	_draw_intents(field)
	if not _reinforcement_warning.is_empty():
		_draw_reinforcement_markers(field)
	for effect in _effects:
		_draw_ground_effect(effect, field)
	_draw_afterimages(field, sprite_scale)
	var ordered_units := units.duplicate()
	ordered_units.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var first: Vector2 = _positions.get(a.id, a.pos)
		var second: Vector2 = _positions.get(b.id, b.pos)
		return first.y < second.y)
	var hud_space: Array[Rect2] = []
	var cannon_muzzles: Dictionary[String, Vector2] = {}
	for unit in ordered_units:
		if unit.hp <= 0:
			continue
		var point := _project(_positions.get(unit.id, unit.pos), field)
		hud_space.append(_draw_unit(unit, point, sprite_scale, cannon_muzzles))
	_draw_repairmaster_cues(field)
	for cast: Dictionary in _attack_casts:
		if cast.tile in [REPAIRMASTER_DASH, REPAIRMASTER_REPAIR]:
			continue
		var moving: bool = cast.profile.style in ["blink", "dash"]
		var origin: Vector2 = cast.from if moving else cast.get("strike_from", cast.from)
		var start := _project(origin, field)
		var target := _project(cast.to, field)
		var arrival := _project(cast.get("arrival", cast.from), field)
		var radius := clampf(float(cast.get("radius", 0.0)), 0.0, 240.0)
		var progress := float(cast.age) / float(cast.lifetime)
		var cast_size := clampf(sprite_scale * 61.0, 16.0, 39.0)
		if cast.tile == CANNON_SHOT:
			var muzzle: Vector2 = cannon_muzzles.get(cast.actor, start - Vector2(0, 28))
			_draw_cannon_release(muzzle, target, progress)
			continue
		if cast.tile == VANGUARD_CHARGE:
			if not cast.get("contact_points", []).is_empty():
				var contact := _project(cast.contact_points[0], field)
				_draw_vanguard_contact(contact, arrival.direction_to(contact), progress)
			continue
		AttackAnimation.draw_cast(self, cast.profile, start, target, arrival, progress,
			cast_size, cast.get("landed", true), radius * field.size / WORLD_SIZE)
		if radius <= 0.0 and cast.profile.style in ["pull", "bolt", "shot", "ward", "heal"]:
			for contact: Vector2 in cast.get("contact_points", []):
				var end := _project(contact, field)
				if end.distance_squared_to(target) > 36.0:
					AttackAnimation.draw_secondary_contact(self, cast.profile, start, end, progress, cast_size)
	for effect in _effects:
		_draw_feedback(effect, field)
	if not _combat_numbers.is_empty():
		_layout_combat_numbers(field, sprite_scale, hud_space)
		for number in _combat_numbers:
			if number.bounds.has_area():
				_draw_combat_number(number)
	_draw_marshal_cues(board)
	if not _reinforcement_warning.is_empty():
		_draw_reinforcement_countdown(board)


func _draw_arena(board: Rect2) -> void:
	var background: Texture2D = _textures.get(ARENA_TEXTURES.get(location, "arena"), _textures.get("arena"))
	if background:
		draw_texture_rect(background, board, false)
	else:
		draw_rect(board, INK.lightened(0.08))
		var center := board.get_center() + Vector2(0.0, board.size.y * 0.035)
		var radius := board.size * Vector2(0.48, 0.46)
		_draw_ellipse(center, radius, Color("#664938"))
		_draw_ellipse(center - Vector2(0.0, board.size.y * 0.035), radius * 0.95, Color("#936e4d"))
		_draw_ellipse(center, radius * 0.9, SAND)
		for index in range(16):
			var offset := Vector2(sin(index * 3.21), cos(index * 6.37)) * radius * 0.64
			var start := center + offset
			draw_line(start, start + Vector2(7.0 + index * 1.7, 1.0), Color("#ae8354"), 1.0, true)
	draw_rect(board, FRAME, false, 2.0)

func _sprite_facing(unit: Dictionary, cast: Dictionary) -> float:
	if not cast.is_empty() and not cast.get("from_afterimage", false):
		var origin: Vector2 = cast.get("strike_from", cast.from)
		if cast.get("profile", {}).get("style", "") in ["blink", "dash"]:
			origin = cast.get("arrival", origin)
			if _curved_charges.has(unit.id):
				origin = _positions.get(unit.id, origin)
		var direction: Vector2 = cast.to - origin
		if absf(direction.x) > 8.0:
			for target: Dictionary in units:
				if target.id == cast.target and target.side != unit.side:
					return signf(direction.x)
	return unit.get("facing", 1.0 if unit.side == "hero" else -1.0)


func _draw_afterimages(field: Rect2, unit_scale: float) -> void:
	for unit: Dictionary in units:
		var departure: Dictionary = unit.get("afterimage", {})
		if unit.hp > 0 and not departure.is_empty():
			var point := _project(departure.position, field)
			_draw_echo(unit, point, unit_scale, departure.get("facing", 1.0), 0.66)
		var cast: Dictionary = _actor_casts.get(unit.id, {})
		if cast.get("from_afterimage", false):
			var point := _project(cast.strike_from, field)
			var facing := -1.0 if cast.to.x < cast.strike_from.x else 1.0
			var remaining := 1.0 - float(cast.age) / float(cast.lifetime)
			_draw_echo(unit, point, unit_scale, facing, remaining)


func _draw_echo(unit: Dictionary, point: Vector2, unit_scale: float, facing: float, opacity: float) -> void:
	var texture := GameIcons.hero_art(unit.get("class", unit.get("sprite", unit.id)))
	if texture == null:
		return
	var height := maxf(39.0, unit_scale * 132.0)
	var width := height * texture.get_size().aspect()
	var ring := Vector2(height * 0.27, height * 0.12)
	_draw_ellipse(point, ring, Color("#422a60", opacity * 0.65))
	_draw_ellipse(point, ring * 0.82, Color("#c7a9ff", opacity * 0.72))
	draw_set_transform(point, 0.0, Vector2(facing, 1.0))
	draw_texture_rect(texture, Rect2(-width * 0.5, -height, width, height), false, Color("#bc91f4", opacity * 0.81))
	draw_set_transform(Vector2.ZERO)


func _combat_sprite(id: String, key: String, texture: Texture2D, friendly: bool) -> CombatSpritePose:
	if not _combat_sprites.has(id):
		if not _sprite_geometry.has(key):
			_sprite_geometry[key] = CombatSpritePose.geometry(texture, 1.0 if friendly else -1.0)
		_combat_sprites[id] = CombatSpritePose.new(_sprite_geometry[key])
	return _combat_sprites[id]


func _draw_unit(unit: Dictionary, point: Vector2, unit_scale: float,
		cannon_muzzles: Dictionary[String, Vector2]) -> Rect2:
	var friendly: bool = unit.side == "hero"
	var accent := HERO_COLOR if friendly else ENEMY_COLOR
	if friendly and location == "glass":
		accent = Color("#c4fff0")
	var art_key := String(unit.get("sprite", unit.id))
	var hero_class := ""
	if friendly:
		hero_class = unit.get("class", art_key)
		art_key = GameIcons.portrait(hero_class)
	var texture: Texture2D = GameIcons.hero_art(hero_class) if friendly else GameIcons.enemy_art(art_key)
	var radius := maxf(8.0, float(unit.radius) * unit_scale)
	var model_height := 132.0
	if art_key in ["tempered_colossus", "crown_regent", "wreckmaster", "tidekeeper", "drowned_admiral"]:
		model_height = 218.0
	elif art_key in ["marshal", "regent", "glass_twin", "ember_twin", "prism_warden", "relay_captain", "relay_marshal", "brass_bellmaker", "brass_tollkeeper", "brass_repairmaster", "glass_refraction_engine"]:
		model_height = 191.0
	elif art_key in ["brass_captain", "brass_vanguard"]:
		model_height = 161.0
	elif art_key == "brass_cannon":
		model_height = 186.0
	elif art_key == "brass_bruiser":
		model_height = 145.0
	elif art_key == "clockwork":
		model_height = 154.0
	elif art_key in ["tollkeeper_drone", "repairmaster_drone"]:
		model_height = 108.0
	var art_height := maxf(39.0, unit_scale * model_height)
	var motion: float = _gait_strengths.get(unit.id, 0.0)
	var stride: float = _gait_phases.get(unit.id, 0.0)
	var bounce := Vector2(0.0, -absf(sin(stride)) * motion * 1.7)
	var lean := sin(stride) * motion * 0.022
	var cast: Dictionary = _actor_casts.get(unit.id, {})
	var prepare := _windup_details(unit)
	var release_duration := AttackAnimation.release_duration(cast.profile) if not cast.is_empty() else 0.18
	var from_afterimage: bool = cast.get("from_afterimage", false)
	var acting := not cast.is_empty() and not from_afterimage and float(cast.age) < release_duration
	var facing := _sprite_facing(unit, cast if acting else {})
	var pose := Vector4.ZERO
	var brace := 0.0
	var arm_swing := sin(stride) * motion * 0.19
	var arms := Vector3(-arm_swing, arm_swing, 0.0)
	if acting:
		brace = pow(1.0 - float(cast.age) / release_duration, 1.7)
		pose = AttackAnimation.pose(cast.profile, brace, facing, true)
		arms = CombatSpritePose.arm_pose(cast.profile, brace, true)
	elif not prepare.is_empty():
		brace = smoothstep(0.04, 1.0, prepare.charge)
		pose = AttackAnimation.pose(prepare.profile, brace, facing, false)
		arms = CombatSpritePose.arm_pose(prepare.profile, brace, false)
	bounce += Vector2(pose.x, pose.y) * art_height
	lean += pose.z
	var flash := 0.0
	for effect in _effects:
		if effect.kind != "hit":
			continue
		if effect.target == unit.id:
			flash = maxf(flash, 1.0 - float(effect.age) * 10.0)
		if not acting and not from_afterimage and effect.actor == unit.id and float(effect.age) < 0.16:
			var hit_direction: Vector2 = (effect.to - effect.from).normalized()
			var recoil := sin(float(effect.age) / 0.16 * PI)
			bounce += hit_direction * recoil * 7.0
			lean += hit_direction.x * recoil * 0.08
	_draw_ellipse(point + Vector2(1.5, 2.0), Vector2(radius * 1.2, radius * 0.36), Color(0.1, 0.09, 0.08, 0.43))
	if texture:
		var flip := 1.0 if (facing > 0.0) == friendly else -1.0
		var scale := Vector2(flip * (1.0 - pose.w * 0.67), 1.0 + pose.w)
		var transform := Transform2D(lean, scale, 0.0, point + bounce)
		if art_key == "brass_cannon":
			arms = Vector3.ZERO
			if cast.get("tile") == CANNON_SHOT:
				cannon_muzzles[unit.id] = transform * (CANNON_MUZZLE_OFFSET * art_height)
		draw_set_transform_matrix(transform)
		var tint := RIGHT_RELAY_COLOR.lerp(Color.WHITE, 0.32) if unit.get("crown_role") == "relay_right" else Color.WHITE
		_combat_sprite(unit.id, art_key, texture, friendly).draw(self, art_height,
			CombatSpritePose.leg_pose(stride, motion * (1.0 - brace * 0.75), brace), arms, tint.lerp(GOLD, flash * 0.6))
		draw_set_transform(Vector2.ZERO)
	else:
		var body_center := point + bounce - Vector2(0.0, art_height * 0.37)
		var body_radius := art_height * 0.3
		draw_circle(body_center, body_radius, INK, true, -1.0, true)
		draw_circle(body_center, body_radius * 0.8, accent.darkened(0.38), true, -1.0, true)
		draw_circle(body_center, body_radius * 0.8, accent, false, 2.0, true)
		var initial := String(unit.name).left(1)
		_draw_centered(initial, body_center + Vector2(0.0, 5.0), 15, WHITE)
	if not acting and not prepare.is_empty():
		var emphasis: float = maxf(0.52, prepare.charge) if not friendly and _attack_rate > 1.0 else prepare.charge
		AttackAnimation.windup(self, point + bounce, facing, art_height, emphasis, prepare.profile)
	var health_width := clampf(radius * 2.7, 31.0, 58.0)
	var bar_offset := 7.0 if friendly else 13.0
	var bar := Rect2(point + Vector2(-health_width * 0.5, -art_height - bar_offset), Vector2(health_width, 5.0))
	draw_rect(bar.grow(1.0), Color("#202923"))
	draw_rect(bar, accent.darkened(0.71))
	var health_ratio := clampf(float(unit.hp) / maxf(1.0, float(unit.max_hp)), 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * health_ratio, bar.size.y)), accent)
	if int(unit.get("crown_oathbrace_until", 0)) > combat_tick:
		draw_line(bar.position + Vector2(0.0, -2.0), bar.position + Vector2(bar.size.x, -2.0), RELAY_SHIELD_COLOR, 2.0, true)
	elif float(unit.get("guard", 0)) > 0.0:
		draw_line(bar.position + Vector2(0.0, -2.0), bar.position + Vector2(bar.size.x, -2.0), CombatIcons.PALETTE["guard"], 2.0, true)
	_draw_status_badges(unit, bar)
	if unit.has("repairmaster_orders_used"):
		var batteries := 0
		for drone: Dictionary in units:
			if drone.get("repairmaster_owner") == unit.id and drone.hp > 0 and drone.get("repairmaster_charge", false):
				batteries += 1
		for index in range(2):
			_draw_repair_cell(bar, index, index < batteries)
	elif unit.has("repairmaster_charge"):
		_draw_repair_cell(bar, 0, unit.repairmaster_charge)
	var stacks: int = unit.get("furnace_heat", unit.get("flywheel_momentum", 0))
	for index in range(stacks):
		var pip := Vector2(bar.end.x + 5.0 + index * 6.0, bar.get_center().y)
		draw_circle(pip, 2.4, ENEMY_COLOR.lightened(0.2), true, -1.0, true)
	if _windups.has(unit.id):
		var window: Vector2i = _windups[unit.id]
		var charge := clampf(inverse_lerp(float(window.x), float(window.y), float(combat_tick)), 0.0, 1.0)
		var rapid := _attack_rate > 1.0
		var gauge := Rect2(bar.position + Vector2(0, 9), Vector2(bar.size.x, 6.0 if rapid else 4.0))
		var attack_id: String = unit.get("intent_attack_id", "")
		var repairing := _is_repair_cue(attack_id)
		var retreating := attack_id == REPAIRMASTER_DASH
		var repair_cycle := repairing or retreating
		var charge_color := REPAIR_COLOR if repair_cycle else GOLD.lerp(ENEMY_COLOR, charge * charge)
		if attack_id == VANGUARD_CHARGE:
			charge_color = VANGUARD_COLOR
		elif attack_id == CANNON_SHOT:
			charge_color = CANNON_COLOR
		draw_rect(gauge.grow(1), INK)
		draw_rect(gauge, REPAIR_COLOR.darkened(0.76) if repair_cycle else Color("#593b29"))
		draw_rect(Rect2(gauge.position, Vector2(gauge.size.x * charge, gauge.size.y)), charge_color)
		if rapid:
			draw_rect(gauge.grow(0.5), Color(charge_color, lerpf(0.56, 1.0, charge)), false, 1.0)
		_draw_status_badge("heal" if repairing else "windup", Vector2(gauge.position.x - 8.0, gauge.get_center().y),
			charge_color if rapid else Color.TRANSPARENT)
		if repairing:
			var caption := "REPAIR LINK" if attack_id == REPAIRMASTER_REPAIR else "REPAIRING"
			_draw_centered(caption, bar.get_center() - Vector2(0.0, 9.0), 13, REPAIR_COLOR)
		elif retreating:
			_draw_centered("FALLING BACK", bar.get_center() - Vector2(0.0, 9.0), 13, REPAIR_COLOR)
		if attack_id == REPAIRMASTER_REPAIR:
			var threshold := float(unit.get("repairmaster_interrupt_damage", 0.0))
			if threshold > 0.0:
				var damage_taken := int(unit.get("repairmaster_damage_taken", 0))
				var damage_progress := clampf(damage_taken / threshold, 0.0, 1.0)
				var interrupt_track := Rect2(gauge.position + Vector2(0.0, gauge.size.y + 3.0), Vector2(gauge.size.x, 2.0))
				draw_rect(interrupt_track.grow(1.0), INK)
				draw_rect(interrupt_track, Color("#73463a"))
				draw_rect(Rect2(interrupt_track.position, Vector2(interrupt_track.size.x * damage_progress, interrupt_track.size.y)), ENEMY_COLOR)
				_draw_centered("Interrupt %d/%d" % [damage_taken, int(threshold)],
					interrupt_track.get_center() + Vector2(0, 11), 10, WHITE)
		var special: String = unit.get("special_intent", "")
		var windup_label: String = SIGNATURE_WINDUP_LABELS.get(attack_id, "")
		if attack_id == "veteran" and not str(unit.get("captain_rally", "")).is_empty():
			windup_label = "FALL BACK"
		elif attack_id == "boss" and unit.get("enraged", false):
			windup_label = "RALLY STRIKE"
		if not windup_label.is_empty():
			var warning_color := charge_color if attack_id in [VANGUARD_CHARGE, CANNON_SHOT] else WHITE
			_draw_centered(windup_label, bar.get_center() - Vector2(0.0, 9.0), 12, warning_color)
		if special in ["powder_runner", "brass_pressure_sentinel"]:
			var progress_count: int = unit.get("powder_hits", unit.get("pressure_vents", 0))
			for index in range(2):
				var pip := gauge.end + Vector2(5.0 + index * 6.0, -2.0)
				draw_circle(pip, 2.3, HERO_COLOR if index < progress_count else GOLD, true, -1.0, true)
	elif _attack_rate > 1.0 and cast.get("kind", "") == "enemy_cast":
		_draw_enemy_release(cast, Vector2(bar.get_center().x, bar.end.y + 7.0))
	if int(unit.get("tar_slow_until", 0)) > combat_tick:
		draw_arc(point, radius, 0.0, PI, 16, Color("#be915d"), 2.0, true)
	if unit.get("marshal_plated", false):
		var exposed_until := int(unit.get("marshal_exposed_until", 0))
		var exposed := exposed_until > 0
		var plate_color := HERO_COLOR if exposed else GOLD
		var label := "ARMOR OPEN" if exposed else "PLATED"
		var remaining := 1.0
		if unit.has("marshal_plate_max_integrity"):
			remaining = float(unit.marshal_plate_integrity) / float(unit.marshal_plate_max_integrity)
			label = "PLATE %d%%" % ceili(remaining * 100.0)
			if exposed:
				var beats_left := maxi(1, ceili(float(exposed_until - combat_tick) / ArenaSim.TICKS_PER_BEAT))
				label = "OPEN · %d %s" % [beats_left, "BEAT" if beats_left == 1 else "BEATS"]
			draw_arc(point, radius * 1.4, -PI * 0.5, TAU - PI * 0.5, 32, Color(GOLD, 0.24), 2.0, true)
		_draw_centered(label, bar.get_center() - Vector2(0.0, 9.0), 14, plate_color)
		draw_arc(point, radius * 1.4, -PI * 0.5, TAU * remaining - PI * 0.5, 32, Color(plate_color, 0.8), 2.0, true)
	if unit.get("regent_sealed", false):
		var count: int = unit.get("regent_seals_left", 3)
		var seal_color := HERO_COLOR if int(unit.get("regent_window_until", 0)) > 0 else GOLD
		_draw_centered("%d SEALS" % count, bar.get_center() - Vector2(0.0, 9.0), 14, seal_color)
		draw_arc(point, radius * 1.4, 0.0, TAU * count / 3.0, 32, Color(seal_color, 0.8), 2.0, true)
	if unit.get("prism_warded", false):
		var exposed: bool = int(unit.get("prism_window_until", 0)) > 0
		var ward_color := HERO_COLOR if exposed else TELEPORT_COLOR
		_draw_centered("WARD OPEN" if exposed else "PRISM WARD", bar.get_center() - Vector2(0.0, 9.0), 14, ward_color)
		draw_arc(point, radius * 1.4, 0.0, TAU, 32, Color(ward_color, 0.8), 2.0, true)
	if art_key == "tempered_colossus":
		_draw_colossus_stage(unit, point, radius, bar)
	if unit.get("relay_charge_active", false):
		_draw_relay_charge(unit, point, radius, bar)
	var crown_sources: Array = unit.get("relay_shield_sources", [])
	if not str(unit.get("relay_shield_source", "")).is_empty() or not crown_sources.is_empty():
		var position := point - Vector2(0.0, art_height * 0.38)
		draw_arc(position, art_height * 0.40, 0.0, TAU, 28, Color(RELAY_SHIELD_COLOR, 0.78), 2.0, true)
		if crown_sources.is_empty():
			_draw_shield_mark(Vector2(bar.end.x + 9.0, bar.get_center().y), RELAY_SHIELD_COLOR)
		else:
			var offset := 9.0
			for source: Dictionary in units:
				if source.id in crown_sources:
					_draw_shield_mark(Vector2(bar.end.x + offset, bar.get_center().y), _relay_link_color(source))
					offset += 12.0
	var role: String = unit.get("crown_role", "")
	if role in ["relay_left", "relay_right"]:
		var caption := "LEFT GUARD" if role == "relay_left" else "RIGHT GUARD"
		_draw_centered(caption, bar.get_center() - Vector2(0.0, 9.0), 12, _relay_link_color(unit))
	var wreck_phase: int = unit.get("wreckmaster_phase", 0)
	var tide_phase: int = unit.get("tidekeeper_phase", 0)
	var admiral_phase: int = unit.get("admiral_phase", 0)
	if admiral_phase > 0:
		var caption: String = ["", "UNDERTOW", "UNDERTOW SWEEP · PUSH", "UNDERTOW SWEEP · PULL", "UNDERTOW SWEEP · FINAL PUSH"][admiral_phase]
		_draw_centered(caption, bar.get_center() - Vector2(0.0, 9.0), 14, GOLD)
		if admiral_phase >= 2:
			_draw_combo_ring(point, radius * 1.45, 3, admiral_phase - 2)
	elif tide_phase > 0:
		var caption: String = ["", "TWIN HARPOONS", "BREAKWATER SLAM · PUSH", "BREAKWATER SLAM · FOLLOW UP"][tide_phase]
		_draw_centered(caption, bar.get_center() - Vector2(0.0, 9.0), 14, GOLD)
		if tide_phase >= 2:
			_draw_combo_ring(point, radius * 1.45, 2, tide_phase - 2)
	elif wreck_phase > 0:
		_draw_centered("HARPOON" if wreck_phase == 1 else "DECK SLAM", bar.get_center() - Vector2(0.0, 9.0), 14, GOLD)
	elif not str(unit.get("dock_winch_ally", "")).is_empty():
		_draw_centered("WINCH PULL", bar.get_center() - Vector2(0.0, 9.0), 13, DOCK_WINCH_COLOR)
	if _windups.has(unit.id):
		return bar.grow_individual(30.0, 26.0, 30.0, 16.0)
	return bar.grow_individual(13.0, 5.0, 13.0, 13.0)


func _draw_enemy_release(cast: Dictionary, center: Vector2) -> void:
	var progress := clampf(float(cast.age) / float(cast.lifetime), 0.0, 1.0)
	var opacity := 1.0 - smoothstep(0.28, 1.0, progress)
	var reach := lerpf(6.0, 9.0, progress)
	var points := PackedVector2Array([
		center + Vector2(0.0, -reach), center + Vector2(reach, 0.0),
		center + Vector2(0.0, reach), center + Vector2(-reach, 0.0), center + Vector2(0.0, -reach),
	])
	var tone := REPAIR_COLOR if _is_repair_cue(cast.tile) else SWEEP_LIGHT
	draw_polyline(points, Color(INK, opacity), 4.0, true)
	draw_polyline(points, Color(tone, opacity), 1.6, true)
	if cast.get("landed", true):
		draw_circle(center, 2.0, Color(tone, opacity), true, -1.0, true)


func _draw_repair_cell(bar: Rect2, index: int, available: bool) -> void:
	var center := Vector2(bar.end.x + 6.0 + index * 8.0, bar.get_center().y)
	var cell := Rect2(center - Vector2(2.5, 2.5), Vector2(5.0, 5.0))
	draw_rect(cell.grow(1.0), INK)
	draw_rect(cell, REPAIR_COLOR if available else REPAIR_COLOR.darkened(0.76))
	draw_line(cell.position + Vector2(1.0, -1.0), cell.position + Vector2(4.0, -1.0), REPAIR_COLOR.darkened(0.22), 1.0)


func _draw_status_badges(unit: Dictionary, bar: Rect2) -> void:
	var badges: Array[String] = ["health"]
	if int(unit.get("guard", 0)) > 0 or int(unit.get("crown_oathbrace_until", 0)) > combat_tick:
		badges.append("guard")
	if int(unit.get("burn_left", 0)) > 0 or not unit.get("ember_burns", {}).is_empty():
		badges.append("burn")
	if int(unit.get("arsenal_mark", {}).get("expires", -1)) >= combat_tick \
			or int(unit.get("cantor_mark", {}).get("expires", -1)) >= combat_tick \
			or int(unit.get("chorus_echo", {}).get("expires", -1)) >= combat_tick \
			or int(unit.get("crown_spotter_until", 0)) > combat_tick:
		badges.append("mark")
	if int(unit.get("haste_until", 0)) > combat_tick:
		badges.append("haste")
	if int(unit.get("tar_slow_until", 0)) > combat_tick:
		badges.append("slow")
	for index in range(badges.size()):
		var center := Vector2(bar.position.x - 8.0 - index * 11.0, bar.get_center().y)
		_draw_status_badge(badges[index], center)


func _draw_status_badge(id: String, center: Vector2, tint := Color.TRANSPARENT) -> void:
	var opacity := 1.0 if tint == Color.TRANSPARENT else tint.a
	draw_circle(center, 5.5, Color(INK, 0.93 * opacity), true, -1.0, true)
	CombatIcons.draw(self, id, center, 10.0, tint)


func _hero_profile(id: String) -> Dictionary:
	if not _hero_profiles.has(id):
		_hero_profiles[id] = HeroChoreography.profile(id, ArenaSim.TILES.get(id, {}))
	return _hero_profiles[id]


func _enemy_profile(id: String, attack: Dictionary) -> Dictionary:
	if not _enemy_profiles.has(id):
		_enemy_profiles[id] = EnemyChoreography.profile(id, attack)
	return _enemy_profiles[id]


func _windup_details(unit: Dictionary) -> Dictionary:
	if unit.side == "enemy":
		if not _windups.has(unit.id):
			return {}
		var window: Vector2i = _windups[unit.id]
		var charge := clampf(inverse_lerp(float(window.x), float(window.y), float(combat_tick)), 0.0, 1.0)
		return {"charge": charge, "profile": _enemy_profile(unit.get("intent_attack_id", unit.get("sprite", unit.id)), unit.get("attack", {}))}
	var lane: int = unit.lane
	if combat_tick <= 0 or lane < 0 or lane >= _hero_clips.size():
		return {}
	var loop_tick := posmod(combat_tick - 1, ArenaSim.LOOP_TICKS) + 1
	for clip: Dictionary in _hero_clips[lane]:
		if loop_tick > clip.ready and loop_tick < clip.right_edge:
			return {"charge": inverse_lerp(float(clip.ready), float(clip.right_edge), float(loop_tick)), "profile": clip.profile}
	return {}


func _draw_relay_charge(unit: Dictionary, point: Vector2, radius: float, bar: Rect2) -> void:
	var stage: int = unit.get("relay_combo_stage", 0)
	var caption := "RELAY CHARGE"
	if unit.get("sprite") == "relay_marshal":
		match stage:
			1: caption = "LINKED CHARGE · SEPARATE"
			2: caption = "LINKED CHARGE · FOLLOW UP"
			_: caption = "LINKED CHARGE · INTERRUPT"
	elif unit.get("sprite") == "crown_regent":
		var sources: Array = unit.get("relay_shield_sources", [])
		caption = "CROWN CHARGE · BREAK LINKS" if not sources.is_empty() else "CROWN CHARGE · INTERRUPT"
	_draw_centered(caption, bar.get_center() - Vector2(0.0, 9.0), 14, GOLD)
	if stage in [1, 2]:
		_draw_combo_ring(point, radius * 1.45, 2, stage - 1)
	else:
		draw_arc(point, radius * 1.45, 0.0, TAU, 28, GOLD, 2.5, true)

func _draw_combo_ring(point: Vector2, radius: float, steps: int, completed: int) -> void:
	var angle := TAU / float(steps)
	for index in range(steps):
		var start := index * angle
		var color := HERO_COLOR if index < completed else GOLD
		if index > completed:
			color = GOLD.darkened(0.6)
		draw_arc(point, radius, start, start + angle - 0.18, 18, color, 3.0, true)

func _draw_shield_mark(center: Vector2, color: Color) -> void:
	_draw_status_badge("guard", center, color)


func _draw_relay_links(field: Rect2) -> void:
	for guard: Dictionary in units:
		var target_id: String = guard.get("relay_link_target", "")
		if guard.hp <= 0 or target_id.is_empty():
			continue
		for ally: Dictionary in units:
			if ally.id != target_id or ally.hp <= 0:
				continue
			var start := _project(_positions.get(guard.id, guard.pos), field)
			var end := _project(_positions.get(ally.id, ally.pos), field)
			_draw_support_link(start, end, _relay_link_color(guard))
			break


func _relay_link_color(guard: Dictionary) -> Color:
	return RIGHT_RELAY_COLOR if guard.get("crown_role") == "relay_right" else RELAY_SHIELD_COLOR


func _draw_colossus_stage(unit: Dictionary, point: Vector2, radius: float, bar: Rect2) -> void:
	var stage: int = unit.get("colossus_stage", 0)
	if unit.get("colossus_shattered", false):
		_draw_centered("ARMOR SHATTERED", bar.get_center() - Vector2(0.0, 9.0), 14, HERO_COLOR)
		return
	if stage == 0:
		return
	var caption: String = ["", "PUSH OR PULL", "FOLLOW-UP HIT", "FINAL HIT"][stage]
	_draw_centered(caption, bar.get_center() - Vector2(0.0, 9.0), 14, GOLD)
	for index in range(3):
		var start_angle := index * TAU / 3.0
		var color := HERO_COLOR if index < stage - 1 else GOLD
		if index >= stage:
			color = GOLD.darkened(0.6)
		draw_arc(point, radius * 1.45, start_angle, start_angle + TAU / 3.0 - 0.18, 18, color, 3.0, true)


func _draw_marshal_cues(board: Rect2) -> void:
	for unit in units:
		if not unit.has("marshal_plate_integrity") or unit.hp <= 0:
			continue
		var baseline := Vector2(board.get_center().x, board.position.y + 24.0)
		if _windups.has(unit.id) and unit.get("intent_attack_id") == "marshal_sweep":
			var damage: int = unit.get("marshal_sweep_damage", ArenaSim.MARSHAL_MEDIUM_SWEEP_DAMAGE)
			var caption := "GILDED SWEEP · %d DAMAGE" % damage
			var text_width := get_theme_default_font().get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15).x
			var badge := Rect2(baseline - Vector2(text_width * 0.5 + 12.0, 18.0), Vector2(text_width + 24.0, 25.0))
			draw_rect(badge, Color(SWEEP_EDGE, 0.94))
			draw_rect(badge, Color(SWEEP_LIGHT, 0.76), false, 1.0)
			_draw_centered(caption, baseline, 15, SWEEP_LIGHT)
		elif unit.get("marshal_plated", false) and int(unit.get("marshal_exposed_until", 0)) > 0:
			_draw_centered("PLATE OPEN", baseline, 14, HERO_COLOR)
		break


func _draw_intents(field: Rect2) -> void:
	for unit in units:
		var target_id: String = unit.get("intent", "")
		if unit.hp <= 0 or target_id.is_empty():
			continue
		var special: String = unit.get("special_intent", "")
		if unit.has("blast_center"):
			var radius: Vector2 = float(unit.blast_radius) * field.size / WORLD_SIZE
			var center := _project(unit.blast_center, field)
			if special == "bellmaker_shot":
				_draw_sweep_warning(center, radius, Color("#f8bd91"))
				var notch := minf(radius.x, radius.y) * 0.34
				for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
					draw_line(center + direction * notch * 0.38, center + direction * notch, Color("#ffe0b0"), 2.0, true)
			elif special == "crown_chorister":
				_draw_sweep_warning(center, radius, RELAY_SHIELD_COLOR)
			else:
				_draw_sweep_warning(center, radius)
			continue
		var start := _project(_positions.get(unit.id, unit.pos), field)
		var attack_id: String = unit.get("intent_attack_id", "")
		if attack_id in [REPAIRMASTER_DASH, REPAIRMASTER_REPAIR]:
			continue
		if attack_id == ArenaSim.TOLLKEEPER_REPAIR_CUE:
			_draw_repair_intent(unit, target_id, start, field)
			continue
		if special == "glass_mirrorback":
			var flicker := 0.75 + sin(_animation_time * 15.0) * 0.18
			draw_arc(start, 24.0, 0.0, TAU, 32, Color(RELAY_SHIELD_COLOR, flicker), 3.0, true)
			continue
		if unit.has("pilot_ring_radius"):
			var radius: Vector2 = float(unit.pilot_ring_radius) * field.size / WORLD_SIZE
			if unit.has("pilot_inner_ring_radius"):
				var inner: Vector2 = float(unit.pilot_inner_ring_radius) * field.size / WORLD_SIZE
				_draw_ring_warning(start, inner, radius, Color("#cab9fa"))
			elif special == "crown_page_advance":
				_draw_sweep_warning(start, radius, RELAY_SHIELD_COLOR)
			elif special == "bellmaker_ring":
				_draw_sweep_warning(start, radius, GOLD)
			elif special == "glass_refraction_discharge":
				_draw_sweep_warning(start, radius, Color("#b9bfff"))
			elif unit.get("intent_attack_id") == "marshal_sweep":
				var windup: Dictionary = _windup_details(unit)
				_draw_marshal_sweep_warning(start, radius, windup.get("charge", 0.0))
			else:
				_draw_sweep_warning(start, radius)
			continue
		if unit.has("pilot_aim_point"):
			var origin: Vector2 = unit.get("pilot_aim_origin", unit.get("refraction_origin", unit.pos))
			var endpoint := origin.move_toward(unit.pilot_aim_point, float(unit.attack.reach))
			if attack_id in [VANGUARD_CHARGE, CANNON_SHOT]:
				var progress: float = _windup_details(unit).get("charge", 0.0)
				_draw_brass_duo_warning(origin, endpoint, float(unit.pilot_aim_width), field,
					attack_id == CANNON_SHOT, progress)
				continue
			var edge := (endpoint - origin).normalized().orthogonal() * float(unit.pilot_aim_width)
			var upper := _project(origin + edge, field)
			var lower := _project(origin - edge, field)
			var upper_end := _project(endpoint + edge, field)
			var lower_end := _project(endpoint - edge, field)
			var beam_color := AIM_COLOR
			if special == "glass_refraction_beam":
				beam_color = Color("#91e9ff")
				if origin.distance_to(unit.pos) >= unit.attack.alignment:
					beam_color.a = 0.35
			draw_colored_polygon(PackedVector2Array([upper, upper_end, lower_end, lower]), Color(beam_color, beam_color.a * 0.23))
			var cap := float(unit.pilot_aim_width) * field.size / WORLD_SIZE
			_draw_ellipse(_project(origin, field), cap, Color(beam_color, beam_color.a * 0.12))
			_draw_ellipse(_project(endpoint, field), cap, Color(beam_color, beam_color.a * 0.12))
			var edge_color := Color(AIM_EDGE, beam_color.a * 0.72)
			draw_dashed_line(upper, upper_end, edge_color, 4.4, 8.0)
			draw_dashed_line(lower, lower_end, edge_color, 4.4, 8.0)
			draw_dashed_line(upper, upper_end, beam_color.lightened(0.28), 2.1, 8.0)
			draw_dashed_line(lower, lower_end, beam_color.lightened(0.28), 2.1, 8.0)
			continue
		var wreck_phase: int = unit.get("wreckmaster_phase", 0)
		var tide_phase: int = unit.get("tidekeeper_phase", 0)
		var admiral_phase: int = unit.get("admiral_phase", 0)
		if wreck_phase == 2 or tide_phase >= 2 or admiral_phase >= 2:
			var slam_radius := _dock_sweep_radius(unit)
			_draw_sweep_warning(start, slam_radius * field.size / WORLD_SIZE)
			continue
		var sweep_radius: float = unit.get("colossus_sweep_radius", 0.0)
		if sweep_radius > 0.0 and int(unit.get("colossus_stage", 0)) > 0:
			_draw_sweep_warning(start, sweep_radius * field.size / WORLD_SIZE)
			continue
		var secondary: String = unit.get("prism_secondary", "")
		if special == "chain_warden":
			secondary = unit.get("chain_mate", "")
		var marked: Array = [target_id, secondary]
		if tide_phase == 1:
			marked = unit.get("tidekeeper_targets", [])
		elif admiral_phase == 1:
			marked = unit.get("admiral_targets", [])
		var winch_ally: String = unit.get("dock_winch_ally", "")
		if not winch_ally.is_empty():
			for ally: Dictionary in units:
				if ally.id == winch_ally and ally.hp > 0:
					var rope_end := _project(_positions.get(ally.id, ally.pos), field)
					draw_line(start, rope_end, Color(INK, 0.82), 5.0, true)
					draw_line(start, rope_end, DOCK_WINCH_COLOR, 2.0, true)
					start = rope_end
					break
		for target in units:
			if target.hp <= 0 or target.id not in marked:
				continue
			var end := _project(_positions.get(target.id, target.pos), field)
			if special == "glass_shard_conductor":
				_draw_sweep_warning(end, float(unit.attack.chain_radius) * field.size / WORLD_SIZE)
			if target.side == unit.side:
				var icon: String = ALLY_INTENT_ICONS.get(unit.get("intent_attack_id", special), "guard")
				_draw_support_link(start, end, CombatIcons.PALETTE[icon], icon)
				continue
			var warning := AIM_COLOR
			if special in ["powder_runner", "signal_gunner", "glass_lens_arbalist"]:
				warning = GOLD
			if unit.get("relay_charge_active", false) or wreck_phase == 1 or tide_phase == 1 or admiral_phase == 1:
				warning = GOLD
			elif special == "chain_warden" or not winch_ally.is_empty():
				warning = DOCK_WINCH_COLOR
			elif target.id == secondary:
				warning = TELEPORT_COLOR.darkened(0.21)
			_draw_aim_warning(start, end, warning)


func _is_repair_cue(attack_id: String) -> bool:
	return attack_id in [ArenaSim.TOLLKEEPER_REPAIR_CUE, REPAIRMASTER_REPAIR]


func _draw_repairmaster_retreat(start: Vector2, end: Vector2) -> void:
	var distance := start.distance_to(end)
	if distance >= 24.0:
		var direction := start.direction_to(end)
		var trail_start := start + direction * 11.0
		var trail_end := end - direction * 11.0
		draw_dashed_line(trail_start, trail_end, Color(INK, 0.84), 5.0, 11.0)
		draw_dashed_line(trail_start, trail_end, REPAIR_COLOR, 2.0, 11.0)
		_draw_motion_chevron(start.lerp(end, 0.57), direction, 11.0, REPAIR_COLOR, INK)
	_draw_ellipse(end, Vector2(13.0, 7.0), Color(INK, 0.55))
	draw_arc(end, 13.0, 0.0, TAU, 26, REPAIR_COLOR, 1.9, true)


func _draw_repairmaster_cues(field: Rect2) -> void:
	for unit: Dictionary in units:
		if not _windups.has(unit.id):
			continue
		var cue: String = unit.get("intent_attack_id", "")
		if cue == REPAIRMASTER_DASH and unit.has("repairmaster_dash_landing"):
			var origin := _project(_positions.get(unit.id, unit.pos), field)
			_draw_repairmaster_retreat(origin, _project(unit.repairmaster_dash_landing, field))
			continue
		if cue != REPAIRMASTER_REPAIR:
			continue
		for drone: Dictionary in units:
			if drone.id == unit.intent and drone.hp > 0:
				var source := _project(_positions.get(drone.id, drone.pos), field)
				var target := _project(_positions.get(unit.id, unit.pos), field)
				_draw_repairmaster_link(source, target, 1.0)
				break
	for effect: Dictionary in _effects:
		if effect.kind == "repair_heal" and effect.tile == REPAIRMASTER_REPAIR:
			var source := _project(effect.from, field)
			var target := _project(effect.to, field)
			_draw_repairmaster_link(source, target, 1.0 - effect.age / EFFECT_LENGTHS.repair_heal)


func _draw_repairmaster_link(source: Vector2, target: Vector2, opacity: float) -> void:
	var start := source - Vector2(0.0, 17.0)
	var end := target - Vector2(0.0, 28.0)
	var bend := start.lerp(end, 0.5) + Vector2(32.0, -13.0)
	var beam := PackedVector2Array()
	for index in range(13):
		beam.append(start.bezier_interpolate(bend, bend, end, float(index) / 12.0))
	draw_polyline(beam, Color("#233b34", opacity * 0.92), 7.0, true)
	draw_polyline(beam, Color(REPAIR_COLOR, opacity * 0.85), 3.0, true)
	draw_circle(start, 4.0, Color(REPAIR_COLOR, opacity), true, -1.0, true)
	for offset: float in [0.0, 0.33, 0.66]:
		var relay := start.bezier_interpolate(bend, bend, end, fposmod(_animation_time * 2.8 + offset, 1.0))
		draw_circle(relay, 2.1, Color(WHITE, opacity), true, -1.0, true)
	if opacity > 0.45:
		_draw_status_badge("heal", end, REPAIR_COLOR)


func _draw_support_link(start: Vector2, end: Vector2, color: Color, icon := "guard") -> void:
	var raised := Vector2(0.0, -12.0)
	if start.distance_squared_to(end) > 49.0:
		draw_line(start + raised, end + raised, Color("#254158", color.a * 0.88), 5.0, true)
		draw_line(start + raised, end + raised, color, 2.5, true)
		_draw_status_badge(icon, start.lerp(end, 0.50) + raised, color)
	_draw_ellipse(end, Vector2(15.0, 7.0), Color("#254158", color.a * 0.44))
	_draw_status_badge(icon, end + raised, color)


func _draw_brass_duo_warning(origin: Vector2, endpoint: Vector2, half_width: float,
		field: Rect2, cannon: bool, progress: float) -> void:
	if endpoint.is_equal_approx(origin):
		return
	var heading := origin.direction_to(endpoint)
	var edge := heading.orthogonal() * half_width
	var first := _project(origin + edge, field)
	var second := _project(origin - edge, field)
	var first_end := _project(endpoint + edge, field)
	var second_end := _project(endpoint - edge, field)
	var start := _project(origin, field)
	var end := _project(endpoint, field)
	var tone := CANNON_COLOR if cannon else VANGUARD_COLOR
	var outline := Color(CANNON_SMOKE if cannon else AIM_EDGE, 0.87)
	var warning := Color(AIM_COLOR, 0.22 + progress * 0.14)
	var lane := _project_lane_cap(origin, -heading, half_width, field)
	var end_cap := _project_lane_cap(endpoint, heading, half_width, field)
	lane.append_array(end_cap)
	draw_colored_polygon(lane, warning)
	if cannon:
		for rail: Array in [[first, first_end], [second, second_end]]:
			draw_line(rail[0], rail[1], outline, 5.4, true)
			draw_line(rail[0], rail[1], tone, 2.1, true)
		draw_polyline(end_cap, outline, 5.4, true)
		draw_polyline(end_cap, tone, 2.1, true)
		draw_dashed_line(start, end, Color(tone, 0.55 + progress * 0.28), 1.9, 7.0)
	else:
		for rail: Array in [[first, first_end], [second, second_end]]:
			draw_dashed_line(rail[0], rail[1], outline, 5.2, 9.0)
			draw_dashed_line(rail[0], rail[1], tone, 2.0, 9.0)
		var direction := start.direction_to(end)
		for fraction: float in [0.36, 0.65, 0.91]:
			_draw_motion_chevron(start.lerp(end, fraction), direction, 12.0, tone, outline)


func _project_lane_cap(center: Vector2, outward: Vector2, radius: float, field: Rect2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(9):
		var direction := outward.rotated(lerpf(-PI / 2.0, PI / 2.0, index / 8.0))
		points.append(_project(center + direction * radius, field))
	return points


func _draw_cannon_release(muzzle: Vector2, target: Vector2, progress: float) -> void:
	var contact := target - Vector2(0, 8)
	var direction := muzzle.direction_to(contact)
	var strength := 1.0 - smoothstep(0.0, 0.93, progress)
	var tail := muzzle.lerp(contact, smoothstep(0.10, 1.0, progress) * 0.66)
	var smoke := Color(CANNON_SMOKE, strength * 0.87)
	draw_line(tail, contact, smoke, lerpf(11.0, 5.0, progress), true)
	draw_line(tail, contact, Color(VANGUARD_COLOR, strength), 5.0, true)
	draw_line(tail, contact, Color(CANNON_COLOR, strength), 2.6, true)
	for puff in range(4):
		var offset := -direction * float(puff) * 5.0 - Vector2(0, progress * (12.0 + puff * 3.0))
		draw_circle(muzzle + offset, 4.8 + progress * 14.0, Color(smoke, strength * 0.40), true, -1, true)
	var flash := 1.0 - smoothstep(0.06, 0.46, progress)
	draw_circle(muzzle, 10.0 * flash, Color(VANGUARD_COLOR, flash), true, -1, true)
	draw_circle(muzzle, 5.0 * flash, Color(CANNON_COLOR, flash), true, -1, true)


func _draw_cannon_impact(center: Vector2, radius: Vector2, progress: float) -> void:
	var opacity := 1.0 - smoothstep(0.12, 1.0, progress)
	var expansion := sin(progress * PI * 0.5)
	var dust := radius * lerpf(0.23, 1.0, expansion)
	_draw_ellipse(center, dust, Color(CANNON_SMOKE, opacity * 0.28))
	_draw_dashed_ellipse(center, dust, Color(CANNON_SMOKE, opacity * 0.94), 6.4)
	_draw_dashed_ellipse(center, dust, Color(CANNON_COLOR, opacity), 2.8)
	for index in range(8):
		var ray := Vector2.RIGHT.rotated(index * TAU / 8.0 + 0.24)
		var point := center + ray * radius * (0.27 + expansion * 0.69)
		draw_line(point - ray * 9.0, point, Color(VANGUARD_COLOR, opacity), 3.0, true)


func _draw_vanguard_contact(center: Vector2, approach: Vector2, progress: float) -> void:
	var strike := center - Vector2(0, 13)
	var opacity := 1.0 - progress
	var facing := approach.angle()
	for index in range(3):
		var reach := 6.0 + index * 5.0 + progress * 10.0
		draw_arc(strike, reach, facing - 0.87, facing + 0.87, 16, Color(AIM_EDGE, opacity), 4.5, true)
		draw_arc(strike, reach, facing - 0.87, facing + 0.87, 16, Color(VANGUARD_COLOR, opacity), 2.2, true)


func _draw_aim_warning(start: Vector2, end: Vector2, color: Color) -> void:
	draw_dashed_line(start, end, Color(AIM_EDGE, 0.77), 4.0, 7.5)
	draw_dashed_line(start, end, Color(color.lightened(0.24), 0.89), 2.0, 7.5)
	var radius := 14.0 + sin(_animation_time * 22.0) * 2.0
	draw_arc(end, radius, 0.0, TAU, 24, Color(AIM_EDGE, 0.88), 3.9, true)
	draw_arc(end, radius, 0.0, TAU, 24, color.lightened(0.22), 1.9, true)
	if start.distance_squared_to(end) > 230.0:
		var point := start.lerp(end, 0.76)
		var back := end.direction_to(start) * 7.0
		var arrow := PackedVector2Array([point + back.rotated(0.65), point, point + back.rotated(-0.65)])
		draw_polyline(arrow, AIM_EDGE, 4.0, true)
		draw_polyline(arrow, color.lightened(0.28), 2.0, true)


func _draw_repair_intent(unit: Dictionary, target_id: String, start: Vector2, field: Rect2) -> void:
	var reach := float(unit.attack.get("repair_reach", 0.0))
	if reach > 0.0:
		_draw_sweep_warning(start, reach * field.size / WORLD_SIZE, Color(REPAIR_COLOR, 0.48))
	for target: Dictionary in units:
		if target.id != target_id or target.hp <= 0:
			continue
		var end := _project(_positions.get(target.id, target.pos), field)
		var in_range: bool = unit.pos.distance_to(target.pos) <= reach
		var tint := REPAIR_COLOR if in_range else REPAIR_COLOR.darkened(0.45)
		draw_dashed_line(start, end, tint, 2.0, 6.0)
		draw_arc(end, 12.0 + sin(_animation_time * 22.0) * 2.0, 0.0, TAU, 24, tint, 2.0, true)
		return


func _has_animated_warning() -> bool:
	if not _reinforcement_warning.is_empty():
		return true
	for unit: Dictionary in units:
		if unit.hp > 0 and not str(unit.get("intent", "")).is_empty():
			return true
	return false


func _draw_reinforcement_markers(field: Rect2) -> void:
	var glow := 0.65 + 0.2 * sin(_animation_time * 8.0)
	var tint := Color(GOLD, glow)
	for position: Vector2 in _reinforcement_warning.positions:
		var point := _project(position, field)
		var radius := Vector2(21.0, 11.0)
		_draw_ellipse(point, radius, Color(INK, 0.55))
		for direction in [-1.0, 1.0]:
			var side := point + Vector2(18.0 * direction, 0.0)
			draw_polyline(PackedVector2Array([side - Vector2(7.0 * direction, 8.0), side, side - Vector2(7.0 * direction, -8.0)]),
				tint, 2.0, true)
		draw_line(point - Vector2(3.0, 0.0), point + Vector2(3.0, 0.0), tint, 2.0, true)
		draw_line(point - Vector2(0.0, 3.0), point + Vector2(0.0, 3.0), tint, 2.0, true)


func _draw_reinforcement_countdown(board: Rect2) -> void:
	var badge := Rect2(board.end.x - 235.0, board.position.y + 12.0, 223.0, 30.0)
	var remaining := int(_reinforcement_warning.tick) - combat_tick
	var fill := 1.0 - clampf(float(remaining) / float(_reinforcement_warning.tick), 0.0, 1.0)
	var copy := "Reinforcements · Beat %d" % int(_reinforcement_warning.beat)
	if combat_tick > 0:
		var beats_left := ceili(float(remaining) / ArenaSim.TICKS_PER_BEAT)
		copy = "Reinforcements in %d %s" % [beats_left, "beat" if beats_left == 1 else "beats"]
	draw_rect(badge, Color(INK, 0.94))
	draw_rect(badge, Color(GOLD, 0.53), false, 1.0)
	var track := Rect2(badge.position + Vector2(1.0, badge.size.y - 3.0), Vector2(badge.size.x - 2.0, 2.0))
	draw_rect(track, Color(GOLD, 0.26))
	track.size.x *= fill
	if fill > 0.0:
		draw_rect(track, GOLD)
	_draw_centered(copy, badge.get_center() + Vector2(0.0, 4.0), 14, WHITE)


func _dock_sweep_radius(unit: Dictionary) -> float:
	return unit.get("admiral_sweep_radius", unit.get("tidekeeper_slam_radius", unit.get("wreckmaster_slam_radius", 0.0)))


func _draw_sweep_warning(center: Vector2, radius: Vector2, warning: Color = Color("#f29c76")) -> void:
	_draw_ellipse(center, radius, Color(warning, 0.11))
	_draw_dashed_ellipse(center, radius, warning)


func _draw_marshal_sweep_warning(center: Vector2, radius: Vector2, charge: float) -> void:
	_draw_ellipse(center, radius, Color(SWEEP_EDGE, 0.10 + charge * 0.08))
	_draw_dashed_ellipse(center, radius, SWEEP_EDGE, 6.0)
	_draw_dashed_ellipse(center, radius, SWEEP_LIGHT, 2.8)
	for index in range(8):
		var direction := Vector2.RIGHT.rotated(float(index) * TAU / 8.0)
		var point := center + direction * radius
		var outward := center.direction_to(point)
		var side := outward.orthogonal() * 5.5
		var notch := PackedVector2Array([point - outward * (9.0 + 5.0 * charge), point + side, point - side])
		draw_colored_polygon(notch, SWEEP_EDGE)


func _draw_ring_warning(center: Vector2, inner: Vector2, outer: Vector2, warning: Color) -> void:
	for section in range(32):
		var first := Vector2.RIGHT.rotated(section * TAU / 32.0)
		var second := Vector2.RIGHT.rotated((section + 1) * TAU / 32.0)
		draw_colored_polygon(PackedVector2Array([center + first * inner, center + first * outer,
			center + second * outer, center + second * inner]), Color(warning, 0.13))
	_draw_dashed_ellipse(center, inner, warning)
	_draw_dashed_ellipse(center, outer, warning)


func _draw_dashed_ellipse(center: Vector2, radius: Vector2, warning: Color, width := 2.0) -> void:
	for dash in range(24):
		var start := float(dash) * TAU / 24.0
		var points := PackedVector2Array()
		for step in range(4):
			points.append(center + Vector2.RIGHT.rotated(start + float(step) * 0.054) * radius)
		draw_polyline(points, warning, width, true)


func _draw_ground_effect(effect: Dictionary, field: Rect2) -> void:
	var kind: String = effect.kind
	var from_point := _project(effect.from, field)
	var to_point := _project(effect.to, field)
	var progress := float(effect.age) / float(EFFECT_LENGTHS[kind])
	var opacity := 1.0 - progress
	match kind:
		"counter", "arc", "ranged_warning", "haste":
			var lift := Vector2(0.0, -19.0)
			var tint := GOLD if kind == "ranged_warning" else RELAY_SHIELD_COLOR
			draw_line(from_point + lift, to_point + lift, Color(tint, opacity * opacity), 2.5, true)
		"bell_ring":
			var extent := float(effect.amount) * field.size / WORLD_SIZE
			var ring := extent * lerpf(0.22, 1.0, progress)
			draw_arc(to_point, ring.x, 0.0, TAU, 36, Color(GOLD, opacity), 2.0, true)
		"reinforcement":
			var radius := lerpf(12.0, 32.0, progress)
			_draw_ellipse(to_point, Vector2(radius, radius * 0.5), Color(GOLD, opacity * 0.28))
			for direction in [-1.0, 1.0]:
				var foot := to_point + Vector2(radius * direction, 0.0)
				draw_line(foot - Vector2(0.0, 27.0 * opacity), foot, Color(GOLD, opacity), 2.0, true)
		"tar_slow", "fuse_disarmed":
			var tint := HERO_COLOR if kind == "fuse_disarmed" else Color("#be915d")
			draw_arc(to_point, 9.0 + progress * 19.0, 0.0, TAU, 26, Color(tint, opacity), 2.0, true)
		"pull", "push":
			var siege_pull: bool = effect.tile == "siege_fuse"
			var color := HERO_COLOR if kind == "pull" else GOLD
			if kind == "pull" and not siege_pull:
				for unit in units:
					if unit.id == effect.actor:
						var origin := _project(_positions.get(unit.id, unit.pos), field)
						draw_line(origin, from_point, Color(color, opacity * 0.68), 2.0, true)
						break
			var line_weight := 5.8 if kind == "push" else 4.0
			draw_line(from_point, to_point, Color(INK, opacity * 0.66), line_weight, true)
			_draw_arrow(from_point, to_point, Color(color, opacity))
			if kind == "push":
				var direction := from_point.direction_to(to_point)
				var side := direction.orthogonal()
				for index in range(2):
					var flip := 1.0 if index == 0 else -1.0
					var offset := side * flip * (4.0 + progress * 4.0)
					var start := from_point.lerp(to_point, progress * 0.42) + offset
					var end := from_point.lerp(to_point, 0.52 + progress * 0.31) + offset
					draw_line(start, end, Color(color, opacity * 0.85), 2.4, true)
		"teleport":
			AttackAnimation.draw_blink_transition(self, from_point, to_point, progress)
		"veil_echo":
			var lift := Vector2(0, -18)
			var departure := from_point + lift
			var impact := to_point + lift
			var tip := departure.lerp(impact, clampf(progress * 2.6, 0.0, 1.0))
			draw_arc(departure, 9.0 + progress * 11.0, 0.0, TAU, 24, Color(TELEPORT_COLOR, opacity), 2.0, true)
			draw_dashed_line(departure, tip, Color(TELEPORT_COLOR, opacity * 0.85), 2.0, 6.0)
			draw_circle(tip, 3.5 * opacity, Color(WHITE, opacity), true, -1.0, true)
		"charge":
			if effect.tile == REPAIRMASTER_DASH:
				_draw_retreat_path(from_point, to_point, progress)
			else:
				var tone := VANGUARD_COLOR if effect.tile == VANGUARD_CHARGE else Color("#ffda91")
				_draw_charge_path(_project_charge_path(effect, field), progress, tone)
			var route: PackedVector2Array = effect.get("route", PackedVector2Array())
			var strike := int(effect.get("impact_index", -1))
			if strike >= 0 and strike < route.size():
				var pivot := _project(route[strike], field)
				var flash := 1.0 - smoothstep(0.10, 0.78, progress)
				draw_arc(pivot, lerpf(6.0, 14.0, progress), 0.0, TAU, 20, Color("#ffe6ad", flash), 2.0, true)
		"retreat":
			_draw_retreat_path(from_point, to_point, progress)
		"brass_cannon_impact":
			var blast := float(effect.get("radius", 0.0)) * field.size / WORLD_SIZE
			if blast.x > 0.0:
				_draw_cannon_impact(to_point, blast, progress)
		"ranged_followup_ready", "lance_return_ready":
			var center := to_point - Vector2(0.0, 16.0)
			var radius := lerpf(21.0, 8.0, progress)
			draw_arc(center, radius, -2.6, -0.5, 12, Color(TELEPORT_COLOR, opacity), 2.0, true)
		"ranged_followup_spent", "lance_travel_spent", "lance_return_spent":
			var lift := Vector2(0.0, -19.0)
			draw_line(from_point + lift, to_point + lift, Color(TELEPORT_COLOR, opacity), 3.0, true)
		"rune_charge_ready", "rune_charge_spent":
			var radius := lerpf(10.0, 24.0, progress)
			var color := HERO_COLOR if kind == "rune_charge_ready" else GOLD
			for index in range(4):
				var angle := index * TAU / 4.0
				draw_arc(to_point, radius, angle, angle + 0.8, 6, Color(color, opacity), 2.0, true)
		"duel_stack", "duel_kill_ready", "duel_kill_spent":
			var center := to_point - Vector2(0.0, 16.0)
			var spread := lerpf(5.0, 13.0, progress)
			var color := WHITE if kind == "duel_stack" else GOLD
			draw_line(center + Vector2(-spread, spread), center + Vector2(spread, -spread), Color(color, opacity), 2.3, true)
		"ember_ignite", "ember_tick":
			var radius := lerpf(10.0, 27.0, progress)
			var glow := Color(ENEMY_COLOR.lightened(0.30), opacity)
			for index in range(3):
				var angle := index * TAU / 3.0 + progress
				draw_arc(to_point, radius, angle, angle + 0.85, 7, glow, 2.5, true)
		"bastion_ready", "bastion_release":
			var radius := lerpf(9.0, 24.0, progress) if kind == "bastion_ready" else lerpf(16.0, 49.0, progress)
			for index in range(4):
				var angle := index * TAU / 4.0 + 0.20
				draw_arc(to_point, radius, angle, angle + 0.9, 8, Color(RELAY_SHIELD_COLOR, opacity), 2.5, true)
		"mark", "mark_spent":
			var radius := lerpf(26.0, 12.0, progress) if kind == "mark" else lerpf(12.0, 28.0, progress)
			for index in range(4):
				var angle := index * TAU / 4.0
				draw_arc(to_point, radius, angle, angle + 0.65, 7, Color(MARK_COLOR, opacity), 2.0, true)
		"chorus_mark", "chorus_mark_spent", "chorus_guard":
			var contracting := kind == "chorus_mark"
			var radius := lerpf(27.0, 13.0, progress) if contracting else lerpf(11.0, 36.0, progress)
			var color := HERO_COLOR if kind == "chorus_guard" else MARK_COLOR
			for index in range(3):
				var angle := index * TAU / 3.0
				draw_arc(to_point, radius, angle, angle + 1.1, 10, Color(color, opacity), 2.5, true)
		"afterimage":
			var shimmer := Color(TELEPORT_COLOR.lightened(0.15), opacity)
			var ring := Vector2(13.0, 5.5) * lerpf(0.86, 1.9, progress)
			_draw_ellipse(from_point, ring, Color("#472d67", opacity * 0.41))
			_draw_ellipse(from_point, ring * 0.85, Color(shimmer, opacity * 0.28))
		"barrage_rack", "guard_break", "guard_spent":
			var center := to_point - Vector2(0.0, 16.0)
			for index in range(5):
				var ray := Vector2.RIGHT.rotated(index * TAU / 5.0)
				draw_line(center + ray * (5.0 + progress * 13.0), center + ray * (13.0 + progress * 19.0), Color(GOLD, opacity), 2.5, true)
		"siege_fuse", "cluster_pull":
			var radius := lerpf(36.0, 10.0, progress)
			for index in range(6):
				var angle := index * TAU / 6.0
				draw_arc(to_point, radius, angle, angle + 0.60, 6, Color(HERO_COLOR, opacity), 2.5, true)
		"stepped_gear", "twin_bell":
			var radius := lerpf(11.0, 31.0, progress)
			var color := Color(GOLD, opacity)
			draw_arc(to_point, radius, 0.0, TAU, 28, color, 2.0, true)
			if kind == "twin_bell":
				draw_arc(to_point, radius + 8.0, 0.0, TAU, 28, color, 2.0, true)
		"guard_relay":
			var color := Color(RELAY_SHIELD_COLOR, opacity)
			var height := Vector2(0.0, -16.0)
			draw_line(from_point + height, to_point + height, Color(color, opacity * 0.38), 2.0, true)
			for center: Vector2 in [from_point + height, to_point + height]:
				draw_arc(center, lerpf(9.0, 25.0, progress), 0.0, TAU, 24, color, 2.5, true)
		"class_relic_ready":
			_draw_support_link(from_point, to_point, Color(CombatIcons.PALETTE.heal, opacity), "heal")
		"class_relic_wave":
			var extent := float(effect.get("radius", 0.0)) * field.size / WORLD_SIZE
			var ring := extent * lerpf(0.26, 1.0, progress)
			_draw_dashed_ellipse(from_point, ring, Color(INK, opacity * 0.75), 4.8)
			_draw_dashed_ellipse(from_point, ring, Color(CombatIcons.PALETTE.splash, opacity), 2.5)
		"class_relic":
			var glyph: String = CLASS_RELIC_GLYPHS[effect.tile]
			var tint := Color(CombatIcons.PALETTE[glyph], opacity)
			var radius := lerpf(17.0, 32.0, progress)
			_draw_ellipse(from_point, Vector2(radius, radius * 0.44), Color(tint, opacity * 0.24))
		"switchback_lens":
			var radius := lerpf(28.0, 13.0, progress)
			for index in range(2):
				var angle := index * PI + progress * 1.7
				draw_arc(to_point, radius, angle, angle + 1.2, 10, Color(RELAY_SHIELD_COLOR, opacity), 2.5, true)
		"longshot_prism":
			var lift := Vector2(0.0, -19.0)
			var color := Color(TELEPORT_COLOR.lightened(0.18), opacity * opacity)
			draw_line(from_point + lift, to_point + lift, color, 3.0, true)
			draw_circle(to_point + lift, lerpf(7.0, 2.0, progress), color, true, -1.0, true)
		"sweep_push":
			var radius := lerpf(10.0, 46.0, progress)
			for index in range(6):
				var angle := index * TAU / 6.0
				draw_arc(to_point, radius, angle, angle + 0.65, 6, Color(GOLD, opacity), 3.0, true)
		"hammer_collision":
			var impact := from_point.lerp(to_point, 0.5)
			for index in range(5):
				var direction := Vector2.RIGHT.rotated(index * TAU / 5.0)
				draw_line(impact + direction * (4.0 + progress * 8.0), impact + direction * (11.0 + progress * 13.0),
					Color(GOLD, opacity), 2.0, true)
		"hazard_burst":
			var extent := float(effect.amount) * field.size / WORLD_SIZE
			_draw_ellipse(from_point, extent * lerpf(0.38, 1.0, progress), Color(GOLD, opacity * 0.53))
			for index in range(10):
				var ray := Vector2.RIGHT.rotated(index * TAU / 10.0)
				var spark := from_point + ray * extent * progress * 0.85 - Vector2(0, sin(progress * PI) * (20.0 + 5.0 * (index % 3)))
				draw_circle(spark, 2.0 + opacity * 1.6, Color(GOLD, opacity), true, -1.0, true)
		"repair_heal":
			if effect.tile != REPAIRMASTER_REPAIR:
				draw_line(from_point, to_point, Color(REPAIR_COLOR, opacity * opacity), 2.5, true)
			draw_arc(to_point, 8.0 + progress * 21.0, 0.0, TAU, 24, Color(REPAIR_COLOR, opacity), 2.0, true)
		"repair_interrupted", "repair_separated":
			draw_arc(from_point, 8.0 + progress * 21.0, 0.0, TAU, 24, Color(REPAIR_COLOR, opacity), 2.0, true)
		"marshal_sweep_weathered":
			draw_arc(to_point, 13.0 + progress * 21.0, 0.0, TAU, 24, Color(HERO_COLOR, opacity), 2.5, true)
		"guard", "heal", "defeat_unit", "relay_interrupted", "relay_link_broken", "relay_marshal_separated", "tidekeeper_unanchored", "admiral_reversed", "spring_jam", "marshal_plate_broken":
			var color := RELAY_SHIELD_COLOR if kind == "guard" else ENEMY_COLOR
			if kind == "heal":
				color = HERO_COLOR
			if FLOATING_CUES.has(kind):
				color = RELAY_SHIELD_COLOR
			if kind == "guard" and effect.actor != effect.target and effect.amount > 0:
				_draw_support_link(from_point, to_point, Color(color, opacity))
			draw_arc(to_point, 7.0 + progress * 24.0, 0.0, TAU, 24, Color(color, opacity), 2.0, true)
		"wreckmaster_slam":
			var radius: float = effect.get("slam_radius", 0.0)
			var impact_radius := radius * field.size / WORLD_SIZE * lerpf(0.4, 1.0, progress)
			_draw_ellipse(from_point, impact_radius, Color(ENEMY_COLOR, opacity * 0.22))


func _project_charge_path(effect: Dictionary, field: Rect2) -> PackedVector2Array:
	var route: PackedVector2Array = effect.get("route", PackedVector2Array())
	if route.size() < 2:
		route = PackedVector2Array([effect.from, effect.to])
	var points := PackedVector2Array()
	for world_point: Vector2 in route:
		var point := _project(world_point, field)
		if points.is_empty() or points[-1].distance_squared_to(point) >= 1.0:
			points.append(point)
	return points


func _draw_charge_path(points: PackedVector2Array, progress: float, tone: Color) -> void:
	if points.size() < 2:
		return
	var opacity := 1.0 - smoothstep(0.28, 1.0, progress)
	var light := Color(tone, opacity)
	var edge := Color(INK, opacity * 0.90)
	var landing := points[-1]
	var direction := points[-2].direction_to(landing)
	var pulse := lerpf(9.0, 18.0, progress)
	_draw_ellipse(landing, Vector2(pulse, pulse * 0.43), Color(light, opacity * 0.30))
	draw_polyline(points, edge, 7.5, true)
	draw_polyline(points, light, 3.1, true)
	_draw_motion_chevron(landing, direction, 11.0, light, edge)


func _draw_retreat_path(departure: Vector2, landing: Vector2, progress: float) -> void:
	var length := departure.distance_to(landing)
	if length < 1.0:
		return
	var opacity := 1.0 - smoothstep(0.22, 1.0, progress)
	var light := Color("#a2efe1", opacity)
	var edge := Color(INK, opacity * 0.90)
	var direction := departure.direction_to(landing)
	var pulse := lerpf(7.0, 15.0, progress)
	_draw_ellipse(landing, Vector2(pulse, pulse * 0.43), Color(light, opacity * 0.28))
	draw_dashed_line(departure, landing, edge, 5.6, 5.0)
	draw_dashed_line(departure, landing, light, 2.1, 5.0)
	var arrow_size := clampf(length * 0.15, 4.0, 8.0)
	if length >= 15.0:
		_draw_motion_chevron(departure.lerp(landing, 0.52), direction, arrow_size, light, edge)
	_draw_motion_chevron(landing, direction, arrow_size, light, edge)


func _flanking_approaches(effect: Dictionary, field: Rect2) -> Array[Vector2]:
	var scale := field.size / WORLD_SIZE
	var current: Vector2 = effect.from - effect.to
	var previous: Vector2 = effect.get("previous_direction", Vector2.ZERO)
	return [(current * scale).normalized(), (previous * scale).normalized()]


func _draw_flanking_arrows(effect: Dictionary, field: Rect2, progress: float) -> void:
	var target := _project(effect.to, field) - Vector2(0.0, 10.0)
	var opacity := 1.0 - smoothstep(0.28, 1.0, progress)
	var radius := lerpf(33.0, 21.0, smoothstep(0.0, 0.48, progress))
	for approach: Vector2 in _flanking_approaches(effect, field):
		if not approach.is_zero_approx():
			_draw_motion_chevron(target + approach * radius, -approach, 11.0,
				Color("#ffe6ad", opacity), Color(INK, opacity * 0.94))


func _draw_motion_chevron(tip: Vector2, direction: Vector2, length: float, light: Color, edge: Color) -> void:
	var back := tip - direction * length
	var arm := direction.orthogonal() * length * 0.58
	var points := PackedVector2Array([back + arm, tip, back - arm])
	draw_polyline(points, edge, 6.1, true)
	draw_polyline(points, light, 2.8, true)


func _draw_class_relic_feedback(effect: Dictionary, field: Rect2) -> void:
	var glyph: String = CLASS_RELIC_GLYPHS.get(effect.tile, "")
	if glyph.is_empty():
		return
	var progress := float(effect.age) / float(EFFECT_LENGTHS[effect.kind])
	var opacity := 1.0 - smoothstep(0.46, 1.0, progress)
	var ready: bool = effect.kind == "class_relic_ready"
	var actor: String = effect.target if ready else effect.actor
	var origin: Vector2 = effect.to if ready else effect.from
	var center := _project(_positions.get(actor, origin), field) - Vector2(22.0, 17.0 + 12.0 * progress)
	var tone := Color(CombatIcons.PALETTE[glyph], opacity)
	var extent := lerpf(8.0, 10.0, smoothstep(0.0, 0.24, progress))
	draw_circle(center, extent, Color(INK, opacity * 0.96), true, -1.0, true)
	draw_circle(center, extent, tone, false, 1.15, true)
	CombatIcons.draw(self, glyph, center, 13.0, tone)


func _draw_feedback(effect: Dictionary, field: Rect2) -> void:
	var kind: String = effect.kind
	if kind in ["class_relic", "class_relic_ready"]:
		_draw_class_relic_feedback(effect, field)
		return
	if kind == "flanking_standard":
		_draw_flanking_arrows(effect, field, float(effect.age) / float(EFFECT_LENGTHS[kind]))
		return
	if kind not in ["hit", "miss", "wreckmaster_slam_miss"] and not FLOATING_CUES.has(kind):
		return
	var from_drone := kind in ["repair_interrupted", "repair_separated"]
	var point := _project(effect.from if from_drone else effect.to, field)
	var progress := float(effect.age) / float(EFFECT_LENGTHS[kind])
	var opacity := 1.0 - progress
	var label := "MISS"
	var color := WHITE
	if FLOATING_CUES.has(kind):
		label = FLOATING_CUES[kind]
		color = REPAIR_COLOR if from_drone else RELAY_SHIELD_COLOR
	match kind:
		"wreckmaster_slam_miss":
			label = "SLAM MISSED"
		"hit":
			color = GOLD if str(effect.actor).begins_with("hero") else ENEMY_COLOR.lightened(0.19)
			if effect.get("critical", false):
				color = Color("#ffd15e")
			var impact := point - Vector2(0.0, 16.0)
			for index in range(4):
				var ray := Vector2.RIGHT.rotated(index * TAU / 4.0 + 0.7)
				draw_line(impact + ray * (4.0 + progress * 8.0), impact + ray * (10.0 + progress * 11.0), Color(color, opacity), 2.0, true)
			return
	var lift := 24.0
	if kind == "marshal_plate_broken":
		lift = 52.0
	elif kind == "marshal_sweep_weathered":
		lift = 77.0
		color = HERO_COLOR
		if effect.get("partial", false):
			label = "SWEEP MITIGATED"
	_draw_centered(label, point - Vector2(0.0, lift + progress * 25.0), 15, Color(color, opacity))


func _add_combat_number(event: Dictionary) -> void:
	var healing: bool = event.kind == "heal"
	var guarding: bool = event.kind == "guard"
	var amount := int(event.amount)
	if (healing or guarding) and amount <= 0:
		return
	var critical: bool = event.kind == "hit" and event.get("critical", false) and amount > 0
	var blocked: bool = event.kind == "hit" and amount <= 0 and int(event.get("blocked", 0)) > 0
	var label := str(amount)
	var tone := Color("#fff0bf")
	var glyph := ""
	var font_size := 23
	if healing:
		label = "+%d" % amount
		tone = Color("#9ef5ab")
		glyph = "heal"
		font_size = 20
	elif guarding:
		label = str(amount) if event.tile == "relay_absorb" else "+%d" % amount
		tone = CombatIcons.PALETTE.guard
		glyph = "guard"
		font_size = 20
	elif blocked:
		label = "BLOCK"
		tone = Color("#a3dbff")
		glyph = "guard"
		font_size = 17
	else:
		if critical:
			label += "!"
			font_size = 31
		if str(event.target).begins_with("hero_"):
			tone = Color("#ff9885")
		elif critical:
			tone = Color("#ffe168")
		elif event.tile == "cinder_mage":
			tone = Color("#ffb772")
	_combat_numbers.append({"label": label, "tone": tone, "glyph": glyph, "position": event.to,
		"age": 0.0, "size": font_size, "critical": critical,
		"lifetime": CRITICAL_NUMBER_LIFETIME if critical else COMBAT_NUMBER_LIFETIME})
	if _combat_numbers.size() > MAX_COMBAT_NUMBERS:
		var oldest_normal := _combat_numbers.find_custom(func(number: Dictionary): return not number.critical)
		_combat_numbers.remove_at(maxi(0, oldest_normal))


func _layout_combat_numbers(field: Rect2, unit_scale: float, hud_space: Array[Rect2]) -> void:
	var resized := size != _combat_number_layout_size
	_combat_number_layout_size = size
	var occupied := hud_space.duplicate()
	for number in _combat_numbers:
		if resized:
			number.erase("bounds")
		elif number.has("bounds") and number.bounds.has_area():
			occupied.append(number.bounds)
	# Place new criticals first, and keep all assigned positions steady as the numbers rise.
	var lift := clampf(unit_scale * 110.0, 44.0, 78.0)
	for critical: bool in [true, false]:
		for number in _combat_numbers:
			if number.critical != critical or number.has("bounds"):
				continue
			var anchor := _project(number.position, field) - Vector2(0.0, lift)
			var bounds := _reserve_combat_number(number, anchor, occupied)
			number.bounds = bounds
			if bounds.has_area():
				occupied.append(bounds)


func _reserve_combat_number(number: Dictionary, anchor: Vector2, occupied: Array[Rect2]) -> Rect2:
	var max_size := roundi(float(number.size) * COMBAT_NUMBER_POP)
	var width := _combat_number_font.get_string_size(number.label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, max_size).x
	var icon_width := 0.0 if number.glyph.is_empty() else 18.0
	var extent := Vector2(width + icon_width, _combat_number_font.get_height(max_size) + COMBAT_NUMBER_RISE)
	extent += Vector2.ONE * (2.0 * COMBAT_NUMBER_PADDING)
	if extent.x + 8.0 > size.x or extent.y + 8.0 > size.y:
		return Rect2()
	var descent := _combat_number_font.get_descent(max_size)
	var origin := anchor - Vector2(extent.x * 0.5, extent.y - descent - COMBAT_NUMBER_PADDING)
	var stride := Vector2(maxf(54.0, extent.x + 4.0), extent.y + 4.0)
	var margin := Vector2(4.0, 4.0)
	for row: int in [0, -1, 1, -2, 2, -3, 3]:
		for column: int in [0, -1, 1, -2, 2]:
			var position := (origin + stride * Vector2(column, row)).clamp(margin, size - extent - margin)
			var bounds := Rect2(position, extent)
			if not occupied.any(func(other: Rect2): return other.intersects(bounds)):
				return bounds
	return Rect2()


func _draw_combat_number(number: Dictionary) -> void:
	var progress := float(number.age) / float(number.lifetime)
	var opacity := 1.0 - smoothstep(0.68 if number.critical else 0.5, 1.0, progress)
	var pop := lerpf(COMBAT_NUMBER_POP, 1.0, smoothstep(0.0, 0.21, progress))
	var size_px := roundi(float(number.size) * pop)
	var text: String = number.label
	var width := _combat_number_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px).x
	var max_size := roundi(float(number.size) * COMBAT_NUMBER_POP)
	var bounds: Rect2 = number.bounds
	var baseline := bounds.end.y - COMBAT_NUMBER_PADDING - _combat_number_font.get_descent(max_size) - COMBAT_NUMBER_RISE * progress
	var glyph: String = number.glyph
	var position := Vector2(bounds.get_center().x - width * 0.5, baseline)
	if not glyph.is_empty():
		position.x += 9.0
		var center := position - Vector2(10.0, size_px * 0.34)
		draw_circle(center, 7.0, Color(INK, opacity * 0.94), true, -1.0, true)
		CombatIcons.draw(self, glyph, center, 13.0, Color(number.tone, opacity))
	draw_string_outline(_combat_number_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px, 5, Color(INK, opacity))
	draw_string(_combat_number_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size_px, Color(number.tone, opacity))


func _draw_arrow(from_point: Vector2, to_point: Vector2, color: Color) -> void:
	if from_point.distance_squared_to(to_point) < 9.0:
		return
	draw_line(from_point, to_point, color, 2.0, true)
	var reverse := (from_point - to_point).normalized() * 8.0
	draw_line(to_point, to_point + reverse.rotated(0.53), color, 2.0, true)
	draw_line(to_point, to_point + reverse.rotated(-0.53), color, 2.0, true)


func _draw_centered(label: String, baseline: Vector2, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var start := baseline - Vector2(width * 0.5, 0.0)
	draw_string_outline(font, start, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 4, Color(INK, color.a))
	draw_string(font, start, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(48):
		points.append(center + Vector2.RIGHT.rotated(index * TAU / 48.0) * radius)
	draw_colored_polygon(points, color)


func _project(position: Vector2, field: Rect2) -> Vector2:
	return field.position + position / WORLD_SIZE * field.size
