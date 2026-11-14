extends Control

const GameIcons = preload("res://scripts/game_icons.gd")
const ArenaSim = preload("res://scripts/arena_sim.gd")
const WORLD_SIZE := Vector2(1000.0, 520.0)
const INK := Color("#182126")
const FRAME := Color("#47534b")
const SAND := Color("#be955f")
const HERO_COLOR := Color("#62cfbd")
const ENEMY_COLOR := Color("#df8262")
const GOLD := Color("#f3cb80")
const WHITE := Color("#fff0d2")
const TELEPORT_COLOR := Color("#b2afd9")
const RELAY_SHIELD_COLOR := Color("#91e2f4")
const RIGHT_RELAY_COLOR := Color("#e7b3ff")
const DOCK_WINCH_COLOR := Color("#e6c193")
const ARENA_TEXTURES := {"glass": "glass_arena", "crown": "crown_arena", "moonwreck": "moonwreck_arena"}
const SPRITE_PATHS := {
	"arena": "res://assets/arena.webp",
	"warden": "res://assets/warden.png",
	"hexwright": "res://assets/hexwright.png",
	"marksman": "res://assets/marksman.png",
	"apothecary": "res://assets/apothecary.png",
	"duelist": "res://assets/duelist.png",
	"runesmith": "res://assets/runesmith.png",
	"brass_sapper": "res://assets/brass_sapper.png",
	"glass_duelist": "res://assets/glass_duelist.png",
	"crown_mender": "res://assets/crown_mender.png",
	"dock_corsair": "res://assets/dock_corsair.png",
	"clockwork": "res://assets/clockwork.png",
	"scout": "res://assets/scout.png",
	"marshal": "res://assets/marshal.png",
	"regent": "res://assets/regent.png",
	"glass_hunter": "res://assets/glass_hunter.png",
	"glass_skirmisher": "res://assets/glass_skirmisher.png",
	"glass_twin": "res://assets/glass_twin.png",
	"prism_warden": "res://assets/prism_warden.png",
	"tempered_colossus": "res://assets/tempered_colossus.png",
	"relay_guard": "res://assets/relay_guard.png",
	"relay_captain": "res://assets/relay_captain.png",
	"relay_marshal": "res://assets/relay_marshal.png",
	"crown_regent": "res://assets/crown_regent.png",
	"dock_winch": "res://assets/dock_winch.png",
	"dock_bruiser": "res://assets/dock_bruiser.png",
	"wreckmaster": "res://assets/wreckmaster.png",
	"tidekeeper": "res://assets/tidekeeper.png",
	"drowned_admiral": "res://assets/drowned_admiral.png",
	"glass_arena": "res://assets/glass-arena.webp",
	"crown_arena": "res://assets/crown-arena.webp",
	"moonwreck_arena": "res://assets/moonwreck-arena.webp",
}
const EFFECT_LENGTHS := {
	"pull": 0.42,
	"push": 0.33,
	"teleport": 0.45,
	"hit": 0.38,
	"guard": 0.36,
	"miss": 0.42,
	"defeat_unit": 0.46,
	"hazard_burst": 0.55,
	"heal": 0.60,
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
}
const ELITE_RELIC_EFFECTS := ["afterimage", "barrage_rack", "siege_fuse"]
const ENCOUNTER_EFFECTS := {
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
}
const FLOATING_CUES := {
	"relay_interrupted": "INTERRUPTED",
	"relay_link_broken": "LINK BROKEN",
	"relay_marshal_separated": "SEPARATED",
	"tidekeeper_unanchored": "UNANCHORED",
	"admiral_reversed": "UNDERTOW REVERSED",
}

var units: Array = []
var combat_tick := 0
var _windups: Dictionary = {}
var location := "brass"
var _textures: Dictionary = {}
var _positions: Dictionary = {}
var _facing: Dictionary = {}
var _effects: Array[Dictionary] = []
var _animation_time := 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = maxf(custom_minimum_size.y, 250.0)
	for key in SPRITE_PATHS:
		var path: String = SPRITE_PATHS[key]
		if ResourceLoader.exists(path, "Texture2D"):
			_textures[key] = ResourceLoader.load(path, "Texture2D") as Texture2D
	resized.connect(queue_redraw)


func reset_view(units_data: Array) -> void:
	units = units_data
	combat_tick = 0
	_windups.clear()
	_effects.clear()
	_positions.clear()
	_facing.clear()
	_animation_time = 0.0
	for unit in units:
		_positions[unit.id] = unit.pos
	queue_redraw()


func present(units_data: Array, events: Array, tick := 0) -> void:
	units = units_data
	combat_tick = tick
	for unit: Dictionary in units:
		var finish := int(unit.get("intent_tick", 0))
		if unit.side != "enemy" or unit.hp <= 0 or str(unit.get("intent", "")).is_empty() or finish <= tick:
			_windups.erase(unit.id)
		elif int(_windups.get(unit.id, Vector2i.ZERO).y) != finish:
			_windups[unit.id] = Vector2i(tick, finish)
	for event in events:
		var tile: String = event.get("tile", "")
		if tile == "relay_link_broken" and str(event.target).begins_with("crown_regent"):
			continue
		var kind: String = ENCOUNTER_EFFECTS.get(tile, event.get("kind", ""))
		if kind == "relic_proc" and tile in ELITE_RELIC_EFFECTS:
			kind = tile
		if not EFFECT_LENGTHS.has(kind):
			continue
		if kind in ["relay_marshal_separated", "relay_interrupted", "admiral_reversed"]:
			for index in range(_effects.size() - 1, -1, -1):
				var older := _effects[index]
				if older.target == event.target and FLOATING_CUES.has(older.kind):
					_effects.remove_at(index)
		if kind == "teleport":
			_positions[event.actor] = event.to
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
	_animation_time += delta
	var changed := false
	var blend := 1.0 - exp(-delta * 29.0)
	for unit in units:
		var position: Vector2 = unit.pos
		var previous: Vector2 = _positions.get(unit.id, position)
		if previous.distance_squared_to(position) > 0.005:
			_positions[unit.id] = previous.lerp(position, blend)
			changed = true
		else:
			_positions[unit.id] = position
		var velocity: Vector2 = unit.get("velocity", Vector2.ZERO)
		if absf(velocity.x) > 18.0:
			_facing[unit.id] = signf(velocity.x)
	for index in range(_effects.size() - 1, -1, -1):
		var effect := _effects[index]
		effect.age += delta
		if effect.age >= EFFECT_LENGTHS[effect.kind]:
			_effects.remove_at(index)
		changed = true
	if changed or _has_animated_warning():
		queue_redraw()


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
	for effect in _effects:
		_draw_ground_effect(effect, field)
	var ordered_units := units.duplicate()
	ordered_units.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.y < b.pos.y)
	for unit in ordered_units:
		if unit.hp <= 0:
			continue
		var point := _project(_positions.get(unit.id, unit.pos), field)
		_draw_unit(unit, point, sprite_scale)
	for effect in _effects:
		_draw_feedback(effect, field)


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


func _draw_unit(unit: Dictionary, point: Vector2, unit_scale: float) -> void:
	var friendly: bool = unit.side == "hero"
	var accent := HERO_COLOR if friendly else ENEMY_COLOR
	if friendly and location == "glass":
		accent = Color("#c4fff0")
	var art_key := String(unit.get("sprite", unit.id))
	if friendly:
		art_key = unit.get("sprite", GameIcons.portrait(unit.get("class", "warden")))
	var texture: Texture2D = _textures.get(art_key)
	if texture == null and friendly:
		texture = _textures.get("warden")
	if texture == null and art_key == "marshal":
		texture = _textures.get("clockwork")
	var radius := maxf(8.0, float(unit.radius) * unit_scale)
	var model_height := 132.0
	if art_key in ["tempered_colossus", "crown_regent", "wreckmaster", "tidekeeper", "drowned_admiral"]:
		model_height = 218.0
	elif art_key in ["marshal", "regent", "glass_twin", "prism_warden", "relay_captain", "relay_marshal"]:
		model_height = 191.0
	elif art_key == "clockwork":
		model_height = 154.0
	var art_height := maxf(39.0, unit_scale * model_height)
	var facing := float(_facing.get(unit.id, 1.0 if friendly else -1.0))
	var velocity: Vector2 = unit.get("velocity", Vector2.ZERO)
	var motion := minf(velocity.length() / 100.0, 1.0)
	var stride := _animation_time * 16.0 + float(unit.lane)
	var bounce := Vector2(0.0, -absf(sin(stride)) * motion * 3.0)
	var lean := sin(stride) * motion * 0.022
	if not str(unit.get("intent", "")).is_empty():
		var windup := maxf(0.0, float(unit.get("intent_tick", 0) - combat_tick))
		lean -= facing * (1.0 - clampf(windup / 36.0, 0.0, 1.0)) * 0.11
	var flash := 0.0
	for effect in _effects:
		if effect.kind != "hit":
			continue
		if effect.target == unit.id:
			flash = maxf(flash, 1.0 - float(effect.age) * 10.0)
		if effect.actor == unit.id and float(effect.age) < 0.16:
			var hit_direction: Vector2 = (effect.to - effect.from).normalized()
			var recoil := sin(float(effect.age) / 0.16 * PI)
			bounce += hit_direction * recoil * 7.0
			lean += hit_direction.x * recoil * 0.08
	_draw_ellipse(point + Vector2(1.5, 2.0), Vector2(radius * 1.2, radius * 0.36), Color(0.1, 0.09, 0.08, 0.43))
	if texture:
		var width := art_height * texture.get_size().aspect()
		var flip := 1.0 if (facing > 0.0) == friendly else -1.0
		draw_set_transform(point + bounce, lean, Vector2(flip, 1.0))
		var tint := GOLD.lightened(0.35) if art_key == "marshal" and not _textures.has("marshal") else Color.WHITE
		if unit.name == "Crucible Twin · Ember":
			tint = Color("#ffc391")
		elif unit.get("crown_role") == "relay_right":
			tint = RIGHT_RELAY_COLOR.lerp(Color.WHITE, 0.32)
		draw_texture_rect(texture, Rect2(-width * 0.5, -art_height, width, art_height), false, tint.lerp(GOLD, flash * 0.6))
		draw_set_transform(Vector2.ZERO)
	else:
		var body_center := point - Vector2(0.0, art_height * 0.37)
		var body_radius := art_height * 0.3
		draw_circle(body_center, body_radius, INK, true, -1.0, true)
		draw_circle(body_center, body_radius * 0.8, accent.darkened(0.38), true, -1.0, true)
		draw_circle(body_center, body_radius * 0.8, accent, false, 2.0, true)
		var initial := String(unit.name).left(1)
		_draw_centered(initial, body_center + Vector2(0.0, 5.0), 15, WHITE)
	var health_width := clampf(radius * 2.7, 31.0, 58.0)
	var bar_offset := 7.0 if friendly else 13.0
	var bar := Rect2(point + Vector2(-health_width * 0.5, -art_height - bar_offset), Vector2(health_width, 5.0))
	draw_rect(bar.grow(1.0), Color("#202923"))
	draw_rect(bar, accent.darkened(0.71))
	var health_ratio := clampf(float(unit.hp) / maxf(1.0, float(unit.max_hp)), 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * health_ratio, bar.size.y)), accent)
	if float(unit.get("guard", 0)) > 0.0:
		draw_line(bar.position + Vector2(0.0, -2.0), bar.position + Vector2(bar.size.x, -2.0), GOLD, 2.0, true)
	if _windups.has(unit.id):
		var window: Vector2i = _windups[unit.id]
		var charge := clampf(inverse_lerp(float(window.x), float(window.y), float(combat_tick)), 0.0, 1.0)
		var gauge := Rect2(bar.position + Vector2(0, 9), Vector2(bar.size.x, 4))
		draw_rect(gauge.grow(1), INK)
		draw_rect(gauge, Color("#593b29"))
		draw_rect(Rect2(gauge.position, Vector2(gauge.size.x * charge, gauge.size.y)), GOLD.lerp(ENEMY_COLOR, charge * charge))
	if unit.get("marshal_plated", false):
		var exposed: bool = int(unit.get("marshal_exposed_until", 0)) > 0
		var plate_color := HERO_COLOR if exposed else GOLD
		_draw_centered("ARMOR OPEN" if exposed else "PLATED", bar.get_center() - Vector2(0.0, 9.0), 14, plate_color)
		draw_arc(point, radius * 1.4, 0.0, TAU, 32, Color(plate_color, 0.8), 2.0, true)
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
	var points := PackedVector2Array([
		center + Vector2(-4, -4), center + Vector2(4, -4), center + Vector2(4, 0),
		center + Vector2(0, 5), center + Vector2(-4, 0), center + Vector2(-4, -4)
	])
	draw_colored_polygon(points, Color(INK, 0.9))
	draw_polyline(points, color, 1.5, true)


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
			var lift := Vector2(0.0, -11.0)
			var color := _relay_link_color(guard)
			draw_line(start + lift, end + lift, Color(INK, 0.70), 6.0, true)
			_draw_arrow(start + lift, end + lift, color)
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


func _draw_intents(field: Rect2) -> void:
	for unit in units:
		var target_id: String = unit.get("intent", "")
		if unit.hp <= 0 or target_id.is_empty():
			continue
		if unit.has("blast_center"):
			_draw_sweep_warning(_project(unit.blast_center, field), float(unit.blast_radius) * field.size / WORLD_SIZE)
			continue
		var start := _project(_positions.get(unit.id, unit.pos), field)
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
			var warning := ENEMY_COLOR.darkened(0.34)
			if unit.get("sprite") == "crown_mender":
				warning = HERO_COLOR.darkened(0.16)
			if unit.get("relay_charge_active", false) or wreck_phase == 1 or tide_phase == 1 or admiral_phase == 1:
				warning = GOLD
			elif not winch_ally.is_empty():
				warning = DOCK_WINCH_COLOR
			elif target.id == secondary:
				warning = TELEPORT_COLOR.darkened(0.21)
			draw_dashed_line(start, end, Color(warning, 0.8), 2.0, 6.0)
			draw_arc(end, 14.0 + sin(_animation_time * 22.0) * 2.0, 0.0, TAU, 24, warning, 2.0, true)


func _has_animated_warning() -> bool:
	for unit: Dictionary in units:
		if unit.hp > 0 and not str(unit.get("intent", "")).is_empty():
			return true
	return false


func _dock_sweep_radius(unit: Dictionary) -> float:
	return unit.get("admiral_sweep_radius", unit.get("tidekeeper_slam_radius", unit.get("wreckmaster_slam_radius", 0.0)))


func _draw_sweep_warning(center: Vector2, radius: Vector2) -> void:
	var warning := Color("#f29c76")
	_draw_ellipse(center, radius, Color(warning, 0.11))
	for dash in range(24):
		var start := float(dash) * TAU / 24.0
		var points := PackedVector2Array()
		for step in range(4):
			points.append(center + Vector2.RIGHT.rotated(start + float(step) * 0.054) * radius)
		draw_polyline(points, warning, 2.0, true)


func _draw_ground_effect(effect: Dictionary, field: Rect2) -> void:
	var kind: String = effect.kind
	var from_point := _project(effect.from, field)
	var to_point := _project(effect.to, field)
	var progress := float(effect.age) / float(EFFECT_LENGTHS[kind])
	var opacity := 1.0 - progress
	match kind:
		"hit":
			if ArenaSim.TILES.get(effect.tile, {}).get("family") == "shot":
				var lift := Vector2(0.0, -19.0)
				var tracer := Color(GOLD, pow(opacity, 4.0))
				draw_line(from_point + lift, to_point + lift, tracer, 2.0, true)
				draw_circle(from_point + lift, 4.0 * opacity, tracer, true, -1.0, true)
		"pull", "push":
			var siege_pull: bool = effect.tile == "siege_fuse"
			var color := HERO_COLOR if kind == "pull" else GOLD
			if kind == "pull" and not siege_pull:
				for unit in units:
					if unit.id == effect.actor:
						var origin := _project(_positions.get(unit.id, unit.pos), field)
						draw_line(origin, from_point, Color(color, opacity * 0.68), 2.0, true)
						break
			draw_line(from_point, to_point, Color(INK, opacity * 0.54), 4.0, true)
			_draw_arrow(from_point, to_point, Color(color, opacity))
		"teleport":
			draw_dashed_line(from_point, to_point, Color(TELEPORT_COLOR, opacity * 0.75), 2.0, 6.0)
			draw_arc(from_point, 7.0 + progress * 18.0, 0.0, TAU, 24, Color(TELEPORT_COLOR, opacity), 2.0, true)
			draw_arc(to_point, 8.0 + opacity * 14.0, 0.0, TAU, 24, Color(TELEPORT_COLOR, opacity), 2.0, true)
			for index in range(5):
				var ray := Vector2.RIGHT.rotated(index * TAU / 5.0 + progress * 1.7)
				draw_circle(to_point + ray * (8.0 + progress * 27.0), 2.2 * opacity, Color(TELEPORT_COLOR, opacity), true, -1.0, true)
		"afterimage":
			var lift := Vector2(0.0, -19.0)
			var shimmer := Color(TELEPORT_COLOR.lightened(0.15), opacity)
			draw_dashed_line(from_point + lift, to_point + lift, shimmer, 2.0, 7.0)
			draw_arc(from_point, 9.0 + progress * 14.0, 0.0, TAU, 24, shimmer, 2.5, true)
		"barrage_rack":
			var center := to_point - Vector2(0.0, 16.0)
			for index in range(5):
				var ray := Vector2.RIGHT.rotated(index * TAU / 5.0)
				draw_line(center + ray * (5.0 + progress * 13.0), center + ray * (13.0 + progress * 19.0), Color(GOLD, opacity), 2.5, true)
		"siege_fuse":
			var radius := lerpf(36.0, 10.0, progress)
			for index in range(6):
				var angle := index * TAU / 6.0
				draw_arc(to_point, radius, angle, angle + 0.60, 6, Color(HERO_COLOR, opacity), 2.5, true)
		"hazard_burst":
			var extent := float(effect.amount) * field.size / WORLD_SIZE
			_draw_ellipse(from_point, extent * lerpf(0.38, 1.0, progress), Color(GOLD, opacity * 0.53))
			for index in range(10):
				var ray := Vector2.RIGHT.rotated(index * TAU / 10.0)
				var spark := from_point + ray * extent * progress * 0.85 - Vector2(0, sin(progress * PI) * (20.0 + 5.0 * (index % 3)))
				draw_circle(spark, 2.0 + opacity * 1.6, Color(GOLD, opacity), true, -1.0, true)
		"guard", "heal", "defeat_unit", "relay_interrupted", "relay_link_broken", "relay_marshal_separated", "tidekeeper_unanchored", "admiral_reversed":
			var color := GOLD if kind == "guard" else ENEMY_COLOR
			if kind == "heal":
				color = HERO_COLOR
			if FLOATING_CUES.has(kind):
				color = RELAY_SHIELD_COLOR
			draw_arc(to_point, 7.0 + progress * 24.0, 0.0, TAU, 24, Color(color, opacity), 2.0, true)
		"wreckmaster_slam":
			var radius: float = effect.get("slam_radius", 0.0)
			var impact_radius := radius * field.size / WORLD_SIZE * lerpf(0.4, 1.0, progress)
			_draw_ellipse(from_point, impact_radius, Color(ENEMY_COLOR, opacity * 0.22))


func _draw_feedback(effect: Dictionary, field: Rect2) -> void:
	var kind: String = effect.kind
	if kind not in ["hit", "miss", "wreckmaster_slam_miss"] and not FLOATING_CUES.has(kind):
		return
	var point := _project(effect.to, field)
	var progress := float(effect.age) / float(EFFECT_LENGTHS[kind])
	var opacity := 1.0 - progress
	var label := "MISS"
	var color := WHITE
	if kind == "wreckmaster_slam_miss":
		label = "SLAM MISSED"
	if FLOATING_CUES.has(kind):
		label = FLOATING_CUES[kind]
		color = RELAY_SHIELD_COLOR
	if kind == "hit":
		color = GOLD if String(effect.actor).begins_with("hero") else ENEMY_COLOR.lightened(0.19)
		label = str(effect.amount)
		var impact := point - Vector2(0.0, 16.0)
		for index in range(4):
			var ray := Vector2.RIGHT.rotated(index * TAU / 4.0 + 0.7)
			draw_line(impact + ray * (4.0 + progress * 8.0), impact + ray * (10.0 + progress * 11.0), Color(color, opacity), 2.0, true)
	_draw_centered(label, point - Vector2(0.0, 24.0 + progress * 25.0), 15, Color(color, opacity))


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
