extends Control

const GameIcons = preload("res://scripts/game_icons.gd")

signal purchase_requested(id: String)
signal back_requested

const SKY = preload("res://assets/aether-sky.webp")
const INK := Color("#0c1721")
const PANEL := Color("#132430")
const BRASS := Color("#e6b978")
const BRONZE := Color("#8b633e")
const CREAM := Color("#f4e5c9")
const MUTED := Color("#a9bac0")
const TEAL := Color("#7ee3d7")
const LOCKED := Color("#85949c")
const ORIGIN := Vector2(0.50, 0.49)
const POINTS := {
	"stout_start": Vector2(0.32, 0.39),
	"curated_cache": Vector2(0.26, 0.20),
	"blink_artifice": Vector2(0.49, 0.15),
	"wayfarers_pin": Vector2(0.74, 0.27),
	"purse": Vector2(0.64, 0.65),
	"relic_archive": Vector2(0.83, 0.57),
	"shot_artifice": Vector2(0.48, 0.81),
	"guard_artifice": Vector2(0.16, 0.59),
	"navigation": Vector2(0.83, 0.78),
}
const ART_KEYS := {"shot_artifice": "shot", "guard_artifice": "guard", "navigation": "route"}

var _entries: Dictionary = {}
var _buttons: Dictionary = {}
var _selected := ""
var _marks := 0
var _purchase_enabled := true
var _serif: SystemFont
var _graph: Control
var _marks_label: Label
var _detail_title: Label
var _detail_kind: Label
var _detail_copy: Label
var _detail_state: Label
var _detail_requires: Label
var _detail_icon: Control
var _unlock: Button
var _icon_textures: Dictionary = {}


func render(marks: int, entries: Array, purchase_enabled := true) -> void:
	if _graph == null:
		_build()
	_marks = marks
	_purchase_enabled = purchase_enabled
	_entries.clear()
	for entry: Dictionary in entries:
		_entries[entry.id] = entry
	for marker: Button in _buttons.values():
		_graph.remove_child(marker)
		marker.queue_free()
	_buttons.clear()
	_marks_label.text = "◆  %d Aether Marks" % marks
	for id: String in _entries:
		_add_marker(id)
	if not _entries.has(_selected):
		_selected = "" if _entries.is_empty() else _entries.keys()[0]
	_refresh_details()
	_place_markers()
	if not _selected.is_empty():
		(_buttons[_selected] as Button).grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		back_requested.emit()


func _build() -> void:
	for id: String in ART_KEYS:
		_icon_textures[id] = GameIcons.icon(ART_KEYS[id])
	_serif = SystemFont.new()
	_serif.font_names = PackedStringArray(["Georgia", "Cambria", "Times New Roman", "Liberation Serif"])
	var backdrop := TextureRect.new()
	backdrop.texture = SKY
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 23)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 17)
	layout.add_child(header)
	var back := _button("‹   Title", func(): back_requested.emit(), false)
	back.name = "ChartBack"
	back.custom_minimum_size = Vector2(156, 48)
	back.size_flags_vertical = SIZE_SHRINK_CENTER
	back.tooltip_text = "Return to title (Esc)"
	header.add_child(back)
	var title_card := PanelContainer.new()
	title_card.size_flags_horizontal = SIZE_EXPAND_FILL
	title_card.add_theme_stylebox_override("panel", _box(INK, BRONZE, 12, 2))
	header.add_child(title_card)
	var title := _label("✦   The Aether Chart   ✦", 32, CREAM, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_card.add_child(title)
	var currency := PanelContainer.new()
	currency.custom_minimum_size = Vector2(156, 48)
	currency.size_flags_vertical = SIZE_SHRINK_CENTER
	currency.add_theme_stylebox_override("panel", _box(INK, BRONZE, 12, 2))
	header.add_child(currency)
	_marks_label = _label("", 16, TEAL)
	_marks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	currency.add_child(_marks_label)

	var region := HBoxContainer.new()
	region.size_flags_vertical = SIZE_EXPAND_FILL
	region.add_theme_constant_override("separation", 19)
	layout.add_child(region)
	var board := PanelContainer.new()
	board.size_flags_horizontal = SIZE_EXPAND_FILL
	board.add_theme_stylebox_override("panel", _box(Color(0.035, 0.071, 0.10, 0.18), BRONZE, 13, 1))
	region.add_child(board)
	var chart_stack := VBoxContainer.new()
	chart_stack.add_theme_constant_override("separation", 0)
	board.add_child(chart_stack)
	_graph = Control.new()
	_graph.custom_minimum_size = Vector2(530, 380)
	_graph.size_flags_vertical = SIZE_EXPAND_FILL
	_graph.mouse_filter = MOUSE_FILTER_IGNORE
	_graph.draw.connect(_draw_graph)
	_graph.resized.connect(_place_markers)
	chart_stack.add_child(_graph)
	var legend := HBoxContainer.new()
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_theme_constant_override("separation", 22)
	chart_stack.add_child(legend)
	legend.add_child(_label("●  Unlocked", 14, TEAL))
	legend.add_child(_label("◇  Available", 14, BRASS))
	legend.add_child(_label("○  Locked", 14, LOCKED))
	_build_details(region)


func _build_details(region: Control) -> void:
	var border := PanelContainer.new()
	border.custom_minimum_size.x = 335
	border.add_theme_stylebox_override("panel", _box(BRONZE, BRASS, 15, 2, 4))
	region.add_child(border)
	var inner := PanelContainer.new()
	inner.add_theme_stylebox_override("panel", _box(INK, Color("#584b42"), 11, 1, 22))
	border.add_child(inner)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 13)
	inner.add_child(details)

	_detail_icon = Control.new()
	_detail_icon.custom_minimum_size.y = 140
	_detail_icon.mouse_filter = MOUSE_FILTER_IGNORE
	_detail_icon.draw.connect(_draw_detail_icon)
	_detail_icon.resized.connect(_detail_icon.queue_redraw)
	details.add_child(_detail_icon)
	_detail_title = _label("", 31, CREAM, true)
	_detail_title.name = "SelectedUpgrade"
	_detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_detail_title)
	_detail_kind = _label("", 15, BRASS)
	_detail_kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details.add_child(_detail_kind)
	var rule := ColorRect.new()
	rule.color = Color("#604d3b")
	rule.custom_minimum_size.y = 1
	rule.mouse_filter = MOUSE_FILTER_IGNORE
	details.add_child(rule)
	_detail_copy = _label("", 20, CREAM, true)
	_detail_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_detail_copy)
	_detail_state = _label("", 16, TEAL)
	_detail_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_detail_state)
	_detail_requires = _label("", 15, MUTED)
	_detail_requires.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(_detail_requires)
	var space := Control.new()
	space.size_flags_vertical = SIZE_EXPAND_FILL
	details.add_child(space)
	_unlock = _button("Unlock", _request_purchase, true)
	_unlock.name = "UnlockUpgrade"
	_unlock.custom_minimum_size.y = 60
	details.add_child(_unlock)


func _add_marker(id: String) -> void:
	var entry: Dictionary = _entries[id]
	var marker := Button.new()
	marker.name = id
	marker.text = entry.label
	marker.tooltip_text = entry.label + " · " + _state_name(entry)
	marker.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	for style in ["normal", "hover", "pressed", "focus", "disabled"]:
		marker.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		marker.add_theme_color_override(color, Color.TRANSPARENT)
	marker.clip_text = true
	marker.pressed.connect(func(): _select(id))
	marker.mouse_entered.connect(_graph.queue_redraw)
	marker.mouse_exited.connect(_graph.queue_redraw)
	marker.focus_entered.connect(_graph.queue_redraw)
	marker.focus_exited.connect(_graph.queue_redraw)
	_graph.add_child(marker)
	_buttons[id] = marker


func _place_markers() -> void:
	for id: String in _buttons:
		var marker: Button = _buttons[id]
		marker.position = _point(id) * _graph.size - Vector2(45, 43)
		marker.size = Vector2(90, 86)
	_graph.queue_redraw()


func _point(id: String) -> Vector2:
	if POINTS.has(id):
		return POINTS[id]
	var index := _entries.keys().find(id)
	var angle := TAU * float(index) / maxf(float(_entries.size()), 1.0)
	return ORIGIN + Vector2.from_angle(angle) * Vector2(0.32, 0.26)


func _state_name(entry: Dictionary) -> String:
	if entry.purchased:
		return "Unlocked"
	return "Available" if entry.available else "Locked"


func _state_color(entry: Dictionary) -> Color:
	if entry.purchased:
		return TEAL
	return BRASS if entry.available else LOCKED


func _select(id: String) -> void:
	_selected = id
	_refresh_details()
	_graph.queue_redraw()


func _refresh_details() -> void:
	var entry: Dictionary = _entries.get(_selected, {})
	if entry.is_empty():
		_detail_title.text = "Aether Chart"
		_detail_kind.text = ""
		_detail_copy.text = ""
		_detail_state.text = ""
		_detail_requires.text = ""
		_unlock.disabled = true
		return
	var state := _state_name(entry)
	var cost: int = entry.cost
	_detail_title.text = entry.label
	_detail_kind.text = "%s  ·  %s" % [entry.get("branch", ""), entry.get("kind", "Upgrade")]
	_detail_copy.text = entry.description
	_detail_state.text = state if entry.purchased else "%s  ·  %d Marks" % [state, cost]
	_detail_state.add_theme_color_override("font_color", _state_color(entry))
	var missing := PackedStringArray()
	for parent: String in entry.get("prerequisites", []):
		var prerequisite: Dictionary = _entries.get(parent, {})
		if not prerequisite.is_empty() and not prerequisite.purchased:
			missing.append(prerequisite.label)
	if entry.purchased:
		_detail_requires.text = "Applies to future expeditions."
	elif not _purchase_enabled:
		_detail_requires.text = "Complete the current run to spend Marks."
	elif not missing.is_empty():
		_detail_requires.text = "Requires " + ", ".join(missing) + "."
	elif _marks < cost:
		var remaining := cost - _marks
		_detail_requires.text = "Earn %d more %s to unlock." % [remaining, "Mark" if remaining == 1 else "Marks"]
	else:
		_detail_requires.text = ""
	_unlock.text = "Unlocked" if entry.purchased else "Unlock   ◆   %d" % cost
	_unlock.disabled = not _can_buy(entry)
	_detail_icon.queue_redraw()


func _can_buy(entry: Dictionary) -> bool:
	return _purchase_enabled and not entry.purchased and entry.available and _marks >= int(entry.cost)


func _request_purchase() -> void:
	var entry: Dictionary = _entries.get(_selected, {})
	if not entry.is_empty() and _can_buy(entry):
		purchase_requested.emit(_selected)


func _draw_graph() -> void:
	var bounds := _graph.size
	if bounds.x < 1 or bounds.y < 1:
		return
	var center := ORIGIN * bounds
	for radius: float in [65.0, 91.0, 130.0]:
		_graph.draw_arc(center, radius, 0, TAU, 80, Color(BRONZE, 0.29), 1.0, true)
	for id: String in _entries:
		var entry: Dictionary = _entries[id]
		var destination := _point(id) * bounds
		var prerequisites: Array = entry.get("prerequisites", [])
		if prerequisites.is_empty():
			_draw_edge(center, destination, entry.purchased, entry.available)
		for parent: String in prerequisites:
			if _entries.has(parent):
				_draw_edge(_point(parent) * bounds, destination, entry.purchased, entry.available)
	_draw_medallion(_graph, center, 39.0, BRASS, "origin", false)
	for id: String in _entries:
		var entry: Dictionary = _entries[id]
		var point := _point(id) * bounds
		var accent := _state_color(entry)
		var marker: Button = _buttons[id]
		var focused := marker.has_focus() or marker.is_hovered()
		_draw_medallion(_graph, point, 35.0, accent, id, id == _selected or focused)
		if entry.purchased:
			_graph.draw_circle(point + Vector2(26, -24), 6, TEAL, true, -1, true)
		var title: String = entry.label
		_draw_centered(_graph, title, point + Vector2(0, 60), 18, CREAM if entry.available or entry.purchased else MUTED)


func _draw_edge(start: Vector2, finish: Vector2, owned: bool, available: bool) -> void:
	var direction := start.direction_to(finish)
	var begin := start + direction * 35
	var end := finish - direction * 35
	var color := TEAL if owned else (Color("#be9a64") if available else Color("#607782"))
	_graph.draw_line(begin, end, Color(color, 0.14), 10.0, true)
	if owned or available:
		_graph.draw_line(begin, end, Color(color, 0.95), 2.5, true)
	else:
		_graph.draw_dashed_line(begin, end, color, 1.8, 7.0, true, true)
	var midpoint := begin.lerp(end, 0.5)
	_graph.draw_circle(midpoint, 3, color, true, -1, true)


func _draw_detail_icon() -> void:
	var entry: Dictionary = _entries.get(_selected, {})
	if not entry.is_empty():
		var center := _detail_icon.size * 0.5
		_detail_icon.draw_arc(center, 60, 0, TAU, 84, Color(BRONZE, 0.4), 1.0, true)
		_draw_medallion(_detail_icon, center, 48.0, _state_color(entry), _selected, true)


func _draw_medallion(canvas: Control, center: Vector2, radius: float, accent: Color, icon: String, highlighted: bool) -> void:
	if highlighted:
		canvas.draw_circle(center, radius + 11, Color(accent, 0.08), true, -1, true)
		canvas.draw_arc(center, radius + 6, 0, TAU, 72, Color(accent, 0.7), 2.0, true)
	canvas.draw_circle(center, radius + 2, Color("#091019"), true, -1, true)
	canvas.draw_circle(center, radius, Color("#162c38"), true, -1, true)
	canvas.draw_arc(center, radius, 0, TAU, 64, accent, 2.7, true)
	canvas.draw_arc(center, radius - 6, 0, TAU, 64, Color(accent, 0.38), 1.0, true)
	for offset: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		canvas.draw_circle(center + offset * radius, 2.1, accent, true, -1, true)
	_draw_icon(canvas, center, radius / 35.0, icon, accent)


func _draw_icon(canvas: Control, center: Vector2, scale_factor: float, icon: String, accent: Color) -> void:
	var texture: Texture2D = _icon_textures.get(icon)
	if texture != null:
		var extent := Vector2.ONE * (42.0 * scale_factor)
		canvas.draw_texture_rect(texture, Rect2(center - extent * 0.5, extent), false, Color.WHITE.lerp(accent, 0.25))
		return
	match icon:
		"stout_start":
			_icon_polygon(canvas, center, scale_factor, [
				Vector2(-14, -10), Vector2(0, -15), Vector2(14, -10),
				Vector2(12, 5), Vector2(0, 16), Vector2(-12, 5)
			], accent)
			canvas.draw_line(center + Vector2(-5, 0) * scale_factor, center + Vector2(5, 0) * scale_factor, INK, 2.5, true)
			canvas.draw_line(center + Vector2(0, -5) * scale_factor, center + Vector2(0, 5) * scale_factor, INK, 2.5, true)
		"purse":
			for offset in [8.0, 2.0, -4.0, -10.0]:
				var coin_center := center + Vector2(0, offset * scale_factor)
				canvas.draw_circle(coin_center, 11.0 * scale_factor, accent, true, -1, true)
				canvas.draw_circle(coin_center, 11.0 * scale_factor, INK, false, 1.2, true)
		"curated_cache":
			canvas.draw_line(center + Vector2(0, -16) * scale_factor, center + Vector2(0, 5) * scale_factor, accent, 3.0, true)
			canvas.draw_arc(center + Vector2(6, 5) * scale_factor, 6 * scale_factor, 0, PI, 20, accent, 3.0, true)
			canvas.draw_line(center + Vector2(12, 5) * scale_factor, center + Vector2(12, -1) * scale_factor, accent, 3.0, true)
			canvas.draw_circle(center + Vector2(0, -14) * scale_factor, 5.0 * scale_factor, accent, false, 2, true)
		"relic_archive":
			_icon_polygon(canvas, center, scale_factor, [
				Vector2(-15, -10), Vector2(-4, -12), Vector2(0, -8), Vector2(4, -12),
				Vector2(15, -10), Vector2(15, 10), Vector2(4, 8), Vector2(0, 12),
				Vector2(-4, 8), Vector2(-15, 10)
			], accent)
			canvas.draw_line(center + Vector2(0, -8) * scale_factor, center + Vector2(0, 8) * scale_factor, INK, 2.0, true)
		"blink_artifice":
			canvas.draw_arc(center - Vector2(5, 0) * scale_factor, 11 * scale_factor, 0.55, TAU - 0.55, 28, accent, 2.7, true)
			_icon_polygon(canvas, center, scale_factor, [
				Vector2(-5, -3), Vector2(7, -3), Vector2(7, -9), Vector2(18, 0),
				Vector2(7, 9), Vector2(7, 3), Vector2(-5, 3)
			], accent)
		"wayfarers_pin":
			_icon_polygon(canvas, center, scale_factor, [
				Vector2(-10, -11), Vector2(0, -19), Vector2(10, -11), Vector2(0, 1)
			], accent)
			canvas.draw_circle(center + Vector2(0, -10) * scale_factor, 3.5 * scale_factor, INK, true, -1, true)
			canvas.draw_line(center, center + Vector2(0, 14) * scale_factor, accent, 2.5, true)
			canvas.draw_line(center + Vector2(-5, 9) * scale_factor, center + Vector2(5, 9) * scale_factor, accent, 2.0, true)
		_:
			_icon_polygon(canvas, center, scale_factor, [
				Vector2(0, -19), Vector2(5, -5), Vector2(19, 0), Vector2(5, 5),
				Vector2(0, 19), Vector2(-5, 5), Vector2(-19, 0), Vector2(-5, -5)
			], accent)


func _icon_polygon(canvas: Control, center: Vector2, scale_factor: float, shape: Array, color: Color) -> void:
	var points := PackedVector2Array()
	for point: Vector2 in shape:
		points.append(center + point * scale_factor)
	canvas.draw_colored_polygon(points, color)


func _draw_centered(canvas: Control, copy: String, baseline: Vector2, font_size: int, color: Color) -> void:
	var width := _serif.get_string_size(copy, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var start := baseline - Vector2(width * 0.5, 0)
	canvas.draw_string_outline(_serif, start, copy, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, INK)
	canvas.draw_string(_serif, start, copy, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _box(fill: Color, edge: Color, radius: int, stroke: int, padding := 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(stroke)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style


func _label(copy: String, points: int, color: Color, serif := false) -> Label:
	var label := Label.new()
	label.text = copy
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", color)
	if serif:
		label.add_theme_font_override("font", _serif)
	return label


func _button(copy: String, action: Callable, primary: bool) -> Button:
	var button := Button.new()
	button.text = copy
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", CREAM)
	button.add_theme_color_override("font_pressed_color", CREAM)
	button.add_theme_color_override("font_disabled_color", MUTED)
	var fill := Color("#165256") if primary else PANEL
	button.add_theme_stylebox_override("normal", _box(fill, BRASS if primary else BRONZE, 8, 2))
	button.add_theme_stylebox_override("hover", _box(fill.lightened(0.18), BRASS, 8, 2))
	button.add_theme_stylebox_override("pressed", _box(fill.darkened(0.15), BRASS, 8, 2))
	button.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, TEAL, 8, 2))
	button.add_theme_stylebox_override("disabled", _box(Color("#192833"), BRONZE.darkened(0.33), 8, 1))
	button.add_theme_font_override("font", _serif)
	button.add_theme_font_size_override("font_size", 23 if primary else 18)
	button.pressed.connect(action)
	return button
