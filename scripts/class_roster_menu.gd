extends Control

const GameIcons = preload("res://scripts/game_icons.gd")
const SKY = preload("res://assets/aether-sky.webp")
const INK := Color("#0c1721")
const PANEL := Color("#132430")
const BRASS := Color("#e6b978")
const BRONZE := Color("#8b633e")
const CREAM := Color("#f4e5c9")
const MUTED := Color("#a9bac0")
const TEAL := Color("#7ee3d7")

signal purchase_requested(id: String)
signal starter_requested(id: String)
signal deck_requested(id: String)
signal back_requested

var _entries: Dictionary = {}
var _buttons: Dictionary = {}
var _portraits: Dictionary = {}
var _selected := ""
var _marks := 0
var _purchase_enabled := true
var _picker := false
var _serif: SystemFont
var _grid: GridContainer
var _back: Button
var _heading: Label
var _counter: Label
var _currency: Label
var _portrait: TextureRect
var _portrait_lock: Control
var _title: Label
var _status: Label
var _copy: Label
var _hint: Label
var _deck: Button
var _action: Button


func render(entries: Array, marks: int, purchase_enabled := true) -> void:
	var previous_mode := _picker
	_picker = false
	_marks = marks
	_purchase_enabled = purchase_enabled
	_render(entries, previous_mode != _picker)


func render_picker(entries: Array) -> void:
	var previous_mode := _picker
	_picker = true
	_render(entries, previous_mode != _picker)


func _render(entries: Array, reset_selection: bool) -> void:
	if _grid == null:
		_build()
	_heading.text = "Choose your starter" if _picker else "Class roster"
	_back.text = "‹   Draft three" if _picker else "‹   Aether Chart"
	_currency.text = "◆  %d Aether Marks" % _marks
	_currency.get_parent().visible = not _picker
	for button: Button in _buttons.values():
		_grid.remove_child(button)
		button.queue_free()
	_buttons.clear()
	_entries.clear()
	var unlocked_count := 0
	var preferred := ""
	for entry: Dictionary in entries:
		_entries[entry.id] = entry
		if entry.owned:
			unlocked_count += 1
		if preferred.is_empty() and bool(entry.owned) == _picker:
			preferred = entry.id
		_add_card(entry)
	_counter.text = "%d / %d classes unlocked" % [unlocked_count, entries.size()]
	if reset_selection or not _entries.has(_selected):
		_selected = preferred if not preferred.is_empty() else _entries.keys().front()
	_select(_selected)
	(_buttons[_selected] as Button).grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		back_requested.emit()


func _build() -> void:
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
	_build_header(layout)

	var body := HBoxContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	layout.add_child(body)
	var board := PanelContainer.new()
	board.size_flags_horizontal = SIZE_EXPAND_FILL
	board.add_theme_stylebox_override("panel", _box(Color(0.047, 0.090, 0.129, 0.86), BRONZE, 12, 12))
	body.add_child(board)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	board.add_child(stack)
	_counter = _label("", 14, TEAL)
	stack.add_child(_counter)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.size_flags_vertical = SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	stack.add_child(_grid)
	_build_details(body)


func _build_header(layout: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	layout.add_child(header)
	_back = _button("", func(): back_requested.emit())
	_back.name = "BackFromClassRoster"
	_back.custom_minimum_size = Vector2(156, 48)
	_back.tooltip_text = "Go back (Esc)"
	header.add_child(_back)
	var title_frame := PanelContainer.new()
	title_frame.size_flags_horizontal = SIZE_EXPAND_FILL
	title_frame.add_theme_stylebox_override("panel", _box(INK, BRONZE, 10, 6))
	header.add_child(title_frame)
	_heading = _label("", 31, CREAM, true)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_frame.add_child(_heading)
	var currency_frame := PanelContainer.new()
	currency_frame.custom_minimum_size.x = 156
	currency_frame.add_theme_stylebox_override("panel", _box(INK, BRONZE, 10, 6))
	header.add_child(currency_frame)
	_currency = _label("", 16, TEAL)
	_currency.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	currency_frame.add_child(_currency)


func _build_details(body: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 320
	panel.add_theme_stylebox_override("panel", _box(INK, BRONZE, 12, 18, 2))
	body.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	panel.add_child(stack)
	var frame := PanelContainer.new()
	frame.size_flags_vertical = SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", _box(PANEL, Color("#354751"), 8, 4))
	stack.add_child(frame)
	_portrait = _portrait_view(Vector2(150, 150))
	frame.add_child(_portrait)
	_portrait_lock = GameIcons.lock_badge(_portrait, 90.0)
	_title = _label("", 29, CREAM, true)
	_title.name = "SelectedClassName"
	stack.add_child(_title)
	_status = _label("", 14, TEAL)
	_status.name = "SelectedClassStatus"
	stack.add_child(_status)
	_copy = _label("", 19, CREAM)
	_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_copy)
	_hint = _label("", 14, MUTED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_hint)
	_deck = _button("View class deck", func(): deck_requested.emit(_selected))
	_deck.name = "ViewRosterClassDeck"
	_deck.custom_minimum_size.y = 34
	stack.add_child(_deck)
	_action = _button("", _confirm, true)
	_action.custom_minimum_size.y = 47
	stack.add_child(_action)


func _add_card(entry: Dictionary) -> void:
	var id: String = entry.id
	var button := _button("", func(): _select(id))
	button.name = "ClassRoster_" + id
	button.tooltip_text = "%s · %s" % [entry.label, _state(entry)]
	button.custom_minimum_size = Vector2(116, 108)
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.size_flags_vertical = SIZE_EXPAND_FILL
	_grid.add_child(button)
	_buttons[id] = button
	var layout := VBoxContainer.new()
	layout.mouse_filter = MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 0)
	button.add_child(layout)
	layout.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	layout.offset_left = 4
	layout.offset_top = 5
	layout.offset_right = -4
	layout.offset_bottom = -7
	var face := _portrait_view(Vector2(50, 51))
	face.texture = _portrait_for(id)
	face.modulate = Color.WHITE if entry.owned else Color("#a1a2aa")
	face.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(face)
	if not entry.owned:
		GameIcons.lock_badge(face, 43.0)
	var title := _label(entry.label, 18, CREAM, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)
	var badge := _label(_state(entry), 13, TEAL if entry.owned else BRASS)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(badge)


func _select(id: String) -> void:
	_selected = id
	for class_id: String in _buttons:
		var button: Button = _buttons[class_id]
		var selected := class_id == id
		var edge := TEAL if selected else Color("#38525b")
		var fill := Color("#193e47") if selected else PANEL
		button.add_theme_stylebox_override("normal", _box(fill, edge, 8, 0, 2 if selected else 1))
		button.add_theme_stylebox_override("hover", _box(fill.lightened(0.15), BRASS, 8, 0, 2))
		button.add_theme_stylebox_override("pressed", _box(fill, TEAL, 8, 0, 2))
	var entry: Dictionary = _entries[id]
	_portrait.texture = _portrait_for(id)
	_portrait.modulate = Color.WHITE if entry.owned else Color("#b9b7c2")
	_portrait_lock.visible = not entry.owned
	_title.text = entry.label
	_status.text = _state(entry)
	_status.add_theme_color_override("font_color", TEAL if entry.owned else BRASS)
	_copy.text = entry.description
	_hint.text = ""
	if _picker:
		_action.name = "ChooseStarterClass"
		_action.text = "Start as %s" % entry.label if entry.owned else "Locked"
		_action.disabled = not entry.owned
		if not entry.owned:
			_hint.text = "Unlock this class on the Aether Chart."
	else:
		_action.name = "UnlockClass"
		_action.text = "Unlocked" if entry.owned else "Unlock   ◆   %d" % int(entry.cost)
		_action.disabled = not _can_buy(entry)
		if not entry.owned:
			if not _purchase_enabled:
				_hint.text = "Finish the current expedition to spend Marks."
			elif _marks < int(entry.cost):
				_hint.text = "Earn %d more %s to unlock." % [int(entry.cost) - _marks, "Mark" if int(entry.cost) - _marks == 1 else "Marks"]
	_hint.visible = not _hint.text.is_empty()


func _state(entry: Dictionary) -> String:
	if entry.owned:
		return "Starting class" if int(entry.cost) == 0 else "Unlocked"
	return "Locked · %d Marks" % int(entry.cost)


func _can_buy(entry: Dictionary) -> bool:
	return _purchase_enabled and not entry.owned and _marks >= int(entry.cost)


func _confirm() -> void:
	var entry: Dictionary = _entries[_selected]
	if _picker and entry.owned:
		starter_requested.emit(_selected)
	elif not _picker and _can_buy(entry):
		purchase_requested.emit(_selected)


func _portrait_for(id: String) -> Texture2D:
	if not _portraits.has(id):
		_portraits[id] = GameIcons.hero_art(id)
	return _portraits[id]


func _portrait_view(minimum: Vector2) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = minimum
	portrait.mouse_filter = MOUSE_FILTER_IGNORE
	return portrait


func _button(copy: String, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = copy
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", CREAM)
	button.add_theme_color_override("font_pressed_color", CREAM)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_font_size_override("font_size", 20 if primary else 16)
	var fill := Color("#165256") if primary else PANEL
	button.add_theme_stylebox_override("normal", _box(fill, BRASS if primary else BRONZE, 8, 7))
	button.add_theme_stylebox_override("hover", _box(fill.lightened(0.18), BRASS, 8, 7))
	button.add_theme_stylebox_override("pressed", _box(fill.darkened(0.15), BRASS, 8, 7))
	button.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, TEAL, 8, 0, 2))
	button.add_theme_stylebox_override("disabled", _box(Color("#192833"), BRONZE.darkened(0.33), 8, 7))
	button.pressed.connect(action)
	return button


func _label(copy: String, points: int, color: Color, serif := false) -> Label:
	var label := Label.new()
	label.text = copy
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", color)
	if serif:
		label.add_theme_font_override("font", _serif)
	return label


func _box(fill: Color, edge: Color, radius: int, padding: int, stroke := 1) -> StyleBoxFlat:
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
