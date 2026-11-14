extends Control

const ArenaSim = preload("res://scripts/arena_sim.gd")
const ArenaView = preload("res://scripts/arena_view.gd")
const INK := Color("#101820")
const PANEL := Color("#192732")
const EDGE := Color("#3c505b")
const GOLD := Color("#ecc482")
const CREAM := Color("#f3e7d1")
const MUTED := Color("#aababc")
const TEAL := Color("#9ddbd1")
const RUST := Color("#e8a28b")
const LABELS := {
	"nearest": "Nearest", "farthest": "Farthest", "lowest_hp": "Lowest HP",
	"highest_hp": "Highest HP", "self": "Self"
}

var sim = ArenaSim.new()
var lanes: Array = []
var defaults: Array[String] = []
var fixture := "duo"
var speed := 1
var state := "setup"
var selected: Dictionary = {}
var lane_stack: VBoxContainer
var palette: HBoxContainer
var arena
var fixture_picker: OptionButton
var speed_picker: OptionButton
var action: Button
var status: Label
var log_text: Label
var setup_hint: Label
var playheads: Array[ColorRect] = []
var log_lines: Array[String] = []

func _ready() -> void:
	theme = _theme()
	_build()
	_load_fixture("duo")

func _theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 15
	for kind in ["Button", "OptionButton"]:
		result.set_color("font_color", kind, CREAM)
		result.set_color("font_hover_color", kind, CREAM)
		result.set_color("font_pressed_color", kind, GOLD)
		result.set_color("font_disabled_color", kind, MUTED)
		result.set_stylebox("normal", kind, _box(Color("#263642"), EDGE))
		result.set_stylebox("hover", kind, _box(Color("#324653"), TEAL))
		result.set_stylebox("pressed", kind, _box(Color("#3e3a30"), GOLD))
		result.set_stylebox("disabled", kind, _box(Color("#202d37"), EDGE))
		result.set_stylebox("focus", kind, _box(Color.TRANSPARENT, GOLD))
	result.set_color("font_color", "Label", CREAM)
	return result

func _box(fill: Color, line: Color, radius := 6) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = line
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 9
	box.content_margin_right = 9
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box

func _label(value: String, points := 15, color := CREAM) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", color)
	return label

func _button(value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.pressed.connect(callback)
	return button

func _build() -> void:
	var background := ColorRect.new()
	background.color = INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 23)
	margin.add_theme_constant_override("margin_right", 23)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 9)
	stack.add_child(header)
	var title := _label("BRASS & AETHER", 26, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	fixture_picker = OptionButton.new()
	fixture_picker.add_item("Two heroes")
	fixture_picker.add_item("Solo hero")
	fixture_picker.item_selected.connect(func(index: int): _load_fixture("duo" if index == 0 else "solo"))
	header.add_child(fixture_picker)
	speed_picker = OptionButton.new()
	speed_picker.add_item("1× speed")
	speed_picker.add_item("2× speed")
	speed_picker.item_selected.connect(func(index: int): speed = index + 1)
	header.add_child(speed_picker)
	header.add_child(_button("Reset fight", _reset_fight))
	action = _button("Start battle", _action)
	action.custom_minimum_size.x = 130
	action.add_theme_stylebox_override("normal", _box(Color("#59462f"), GOLD))
	header.add_child(action)

	arena = ArenaView.new()
	arena.name = "Battlefield"
	arena.custom_minimum_size.y = 290
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(arena)
	var readout := HBoxContainer.new()
	readout.add_theme_constant_override("separation", 16)
	stack.add_child(readout)
	status = _label("", 15, GOLD)
	status.custom_minimum_size.x = 150
	readout.add_child(status)
	log_text = _label("", 15, MUTED)
	log_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	readout.add_child(log_text)
	lane_stack = VBoxContainer.new()
	lane_stack.add_theme_constant_override("separation", 5)
	stack.add_child(lane_stack)
	var tray := HBoxContainer.new()
	tray.add_theme_constant_override("separation", 6)
	stack.add_child(tray)
	tray.add_child(_label("Tiles", 15, GOLD))
	palette = HBoxContainer.new()
	palette.add_theme_constant_override("separation", 5)
	palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tray.add_child(palette)
	var erase := _button("Remove selected", _remove_selected)
	tray.add_child(erase)
	setup_hint = _label("", 14, MUTED)
	setup_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(setup_hint)

func _load_fixture(next_fixture: String) -> void:
	fixture = next_fixture
	lanes = ArenaSim.default_lanes(fixture)
	defaults.clear()
	for _lane_index in range(lanes.size()):
		defaults.append("nearest")
	_reset_fight()

func _entry(id: String, start: int, target: String) -> Dictionary:
	return {"id": id, "start": start, "target": target}

func _reset_fight() -> void:
	state = "setup"
	selected.clear()
	log_lines.clear()
	sim.start(lanes, fixture)
	arena.reset_view(sim.units)
	_rebuild_loadout()
	_update_controls()

func _action() -> void:
	match state:
		"setup":
			selected.clear()
			log_lines.clear()
			sim.start(lanes, fixture)
			arena.reset_view(sim.units)
			state = "running"
			_rebuild_loadout()
		"running": state = "paused"
		"paused": state = "running"
		"finished": _reset_fight()
	_update_controls()

func _physics_process(_delta: float) -> void:
	if state != "running":
		return
	for step_index in range(speed):
		var events: Array = sim.step()
		arena.present(sim.units, events)
		for event in events:
			var line: String = event.get("message", "")
			if not line.is_empty():
				log_lines.push_front(line)
				if log_lines.size() > 8:
					log_lines.pop_back()
		if not sim.outcome.is_empty():
			state = "finished"
			break
	_update_controls()

func _update_controls() -> void:
	action.text = {"setup": "Start battle", "running": "Pause", "paused": "Resume", "finished": "Edit loadout"}[state]
	fixture_picker.disabled = state != "setup"
	var cycle := ArenaSim.BEATS * ArenaSim.TICKS_PER_BEAT
	var elapsed: int = sim.tick
	var beat := 0 if elapsed == 0 else 1 + floori(float((elapsed - 1) % cycle) / ArenaSim.TICKS_PER_BEAT)
	match state:
		"setup":
			status.text = "PRE-FIGHT SETUP"
			log_text.text = "Try Pull · Farthest at beat 4, then Bash · Nearest at beat 6."
		"finished":
			status.text = "%s · %.1fs" % [sim.outcome.to_upper(), elapsed / 60.0]
		_:
			status.text = "%s %02d / 12 · %.1fs" % ["Paused" if state == "paused" else "Beat", beat, elapsed / 60.0]
	if state != "setup" and not log_lines.is_empty():
		log_text.text = "   /   ".join(log_lines.slice(0, 3))
		log_text.tooltip_text = "\n".join(log_lines)
	else:
		log_text.tooltip_text = ""
	for head in playheads:
		var board := head.get_parent() as Control
		head.visible = state != "setup"
		var progress := 0 if elapsed == 0 else 1 + (elapsed - 1) % cycle
		head.position.x = clampf(board.size.x * float(progress) / cycle, 0, maxf(0, board.size.x - 2))
		head.size.y = board.size.y

func _rebuild_loadout() -> void:
	for child in lane_stack.get_children():
		lane_stack.remove_child(child)
		child.queue_free()
	for child in palette.get_children():
		palette.remove_child(child)
		child.queue_free()
	playheads.clear()
	for lane_index in range(lanes.size()):
		_build_lane(lane_index)
	for id: String in ArenaSim.TILES:
		var tile: Dictionary = ArenaSim.TILES[id]
		var payload := {"id": id}
		var button := _button("%s · %d" % [tile.label, tile.width], func(): _select(payload))
		button.tooltip_text = tile.description
		button.disabled = state != "setup"
		if selected.get("id") == id and not selected.has("lane"):
			button.add_theme_stylebox_override("normal", _box(Color("#4d4430"), GOLD))
		_drag_source(button, payload)
		palette.add_child(button)
	setup_hint.text = "Drag a tile or select it, then select a starting beat. Select an equipped tile to move or remove it."

func _build_lane(lane_index: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	lane_stack.add_child(row)
	var identity := VBoxContainer.new()
	identity.custom_minimum_size.x = 123
	identity.add_theme_constant_override("separation", 1)
	row.add_child(identity)
	var hero: Dictionary = sim.units[lane_index]
	identity.add_child(_label(hero.name, 16, TEAL))
	var all := OptionButton.new()
	all.add_theme_font_size_override("font_size", 12)
	all.add_item("Set all targets")
	for target in ["nearest", "farthest", "lowest_hp", "highest_hp"]:
		all.add_item(LABELS[target])
		all.set_item_metadata(all.item_count - 1, target)
	all.tooltip_text = "Applies to compatible tiles and sets the default for newly placed tiles."
	all.disabled = state != "setup"
	all.item_selected.connect(func(index: int):
		if index > 0:
			_set_all(lane_index, all.get_item_metadata(index))
	)
	identity.add_child(all)

	var board := Control.new()
	board.custom_minimum_size.y = 69
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(board)
	for beat in range(ArenaSim.BEATS):
		var cell := _button(str(beat + 1), func(): _place_selected(lane_index, beat))
		cell.tooltip_text = "Place at beat %d" % (beat + 1)
		cell.disabled = state != "setup"
		cell.add_theme_font_size_override("font_size", 12)
		cell.add_theme_color_override("font_color", MUTED)
		_add_span(board, cell, beat, 1, 0, 0)
		_drop_destination(cell, lane_index, beat)
	for item: Dictionary in lanes[lane_index]:
		_build_tile(board, lane_index, item)
	var head := ColorRect.new()
	head.color = GOLD
	head.size = Vector2(2, 69)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(head)
	playheads.append(head)

func _add_span(parent: Control, child: Control, start: int, width: int, top: float, bottom: float) -> void:
	parent.add_child(child)
	child.anchor_left = float(start) / ArenaSim.BEATS
	child.anchor_right = float(start + width) / ArenaSim.BEATS
	child.anchor_bottom = 1
	child.offset_left = 2
	child.offset_right = -2
	child.offset_top = top
	child.offset_bottom = bottom

func _build_tile(board: Control, lane_index: int, item: Dictionary) -> void:
	var tile: Dictionary = ArenaSim.TILES[item.id]
	var active: bool = selected.get("lane", -1) == lane_index and selected.get("start", -1) == item.start
	var payload := {"id": item.id, "lane": lane_index, "start": item.start}
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 1)
	_add_span(board, card, item.start, tile.width, 1, -1)
	var name_button := _button(tile.label, func(): _select(payload))
	name_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_button.add_theme_font_size_override("font_size", 13)
	var tint := Color("#254949") if item.id in ["pull", "guard", "blink"] else Color("#583b35")
	name_button.tooltip_text = _tile_tooltip(lane_index, item, tile)
	name_button.add_theme_stylebox_override("normal", _box(tint, GOLD if active else EDGE))
	name_button.add_theme_stylebox_override("disabled", _box(tint, EDGE))
	name_button.disabled = state != "setup"
	card.add_child(name_button)
	_drag_source(name_button, payload, board, lane_index)
	var targets := OptionButton.new()
	targets.clip_text = true
	targets.fit_to_longest_item = false
	targets.add_theme_font_size_override("font_size", 11)
	for rule: String in tile.targets:
		targets.add_item(LABELS[rule])
		targets.set_item_metadata(targets.item_count - 1, rule)
		if item.target == rule:
			targets.select(targets.item_count - 1)
	targets.disabled = state != "setup" or targets.item_count == 1
	targets.item_selected.connect(func(index: int):
		item.target = targets.get_item_metadata(index)
		var new_preview: Dictionary = sim.target_for(lane_index, item.id, item.target)
		name_button.tooltip_text = _tile_tooltip(lane_index, item, tile)
		setup_hint.text = "%s · %s" % [tile.label, new_preview.get("name", "No eligible target")]
	)
	card.add_child(targets)

func _tile_tooltip(lane_index: int, item: Dictionary, tile: Dictionary) -> String:
	var preview: Dictionary = sim.target_for(lane_index, item.id, item.target)
	return "%s\nFires on beat %d · %s" % [
		tile.description, item.start + tile.width, preview.get("name", "No target in range at setup")
	]

func _set_all(lane_index: int, rule: String) -> void:
	defaults[lane_index] = rule
	var skipped := 0
	for item: Dictionary in lanes[lane_index]:
		if rule in ArenaSim.TILES[item.id].targets:
			item.target = rule
		else:
			skipped += 1
	_rebuild_loadout()
	setup_hint.text = "Set compatible tiles to %s%s." % [
		LABELS[rule], " · %d unchanged" % skipped if skipped else ""
	]

func _select(payload: Dictionary) -> void:
	if state != "setup":
		return
	selected = {} if selected == payload else payload.duplicate()
	_rebuild_loadout()
	if not selected.is_empty():
		var first: Control
		if selected.has("lane"):
			var row := lane_stack.get_child(selected.lane)
			first = row.get_child(1).get_child(selected.start)
		else:
			first = lane_stack.get_child(0).get_child(1).get_child(0)
		first.grab_focus()

func _drag_source(control: Control, payload: Dictionary, board: Control = null, lane_index := -1) -> void:
	var can_drop := Callable()
	var drop := Callable()
	if board != null:
		var beat_at := func(point: Vector2) -> int:
			var local_point: Vector2 = board.get_global_transform().affine_inverse() * (control.get_global_transform() * point)
			return clampi(floori(local_point.x / board.size.x * ArenaSim.BEATS), 0, ArenaSim.BEATS - 1)
		can_drop = func(point: Vector2, data: Variant):
			return data is Dictionary and _can_place(data, lane_index, beat_at.call(point))
		drop = func(point: Vector2, data: Variant): _place(data, lane_index, beat_at.call(point))
	control.set_drag_forwarding(
		func(_point: Vector2):
			if state != "setup":
				return null
			var preview := _label(ArenaSim.TILES[payload.id].label, 17, GOLD)
			control.set_drag_preview(preview)
			return payload,
		can_drop, drop
	)

func _drop_destination(control: Control, lane_index: int, beat: int) -> void:
	control.set_drag_forwarding(
		Callable(),
		func(_point: Vector2, data: Variant): return data is Dictionary and _can_place(data, lane_index, beat),
		func(_point: Vector2, data: Variant): _place(data, lane_index, beat)
	)

func _can_place(payload: Dictionary, lane_index: int, start: int) -> bool:
	if state != "setup" or start < 0 or not ArenaSim.TILES.has(payload.get("id")):
		return false
	var end: int = start + ArenaSim.TILES[payload.id].width
	if end > ArenaSim.BEATS:
		return false
	for item: Dictionary in lanes[lane_index]:
		if payload.get("lane", -1) == lane_index and payload.get("start", -1) == item.start:
			continue
		if start < item.start + ArenaSim.TILES[item.id].width and end > item.start:
			return false
	return true

func _place_selected(lane_index: int, beat: int) -> void:
	if selected.is_empty():
		setup_hint.text = "Select a tile first."
		return
	_place(selected, lane_index, beat)

func _place(payload: Dictionary, lane_index: int, start: int) -> void:
	if not _can_place(payload, lane_index, start):
		setup_hint.text = "That tile overlaps another tile or extends beyond beat 12."
		return
	var valid: Array = ArenaSim.TILES[payload.id].targets
	var target: String = defaults[lane_index] if defaults[lane_index] in valid else valid[0]
	if payload.has("lane"):
		var original := _take_tile(payload)
		if original.is_empty():
			return
		target = original.target
	lanes[lane_index].append(_entry(payload.id, start, target))
	lanes[lane_index].sort_custom(func(a: Dictionary, b: Dictionary): return a.start < b.start)
	selected.clear()
	_rebuild_loadout()

func _take_tile(payload: Dictionary) -> Dictionary:
	var lane: Array = lanes[payload.lane]
	for index in range(lane.size()):
		if lane[index].start == payload.start:
			return lane.pop_at(index)
	return {}

func _remove_selected() -> void:
	if state != "setup" or not selected.has("lane"):
		return
	_take_tile(selected)
	selected.clear()
	_rebuild_loadout()
