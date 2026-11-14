extends Control

const COLUMNS := 8
const ROWS := 3
const TILE_HEIGHT := 56.0
const COMBINE_HEIGHT := 36.0
const INK := Color("#101820")
const PANEL := Color("#192732")
const EDGE := Color("#3c505b")
const GOLD := Color("#ecc482")
const CREAM := Color("#f3e7d1")
const MUTED := Color("#aababc")
const TEAL := Color("#9ddbd1")
const RUST := Color("#e8a28b")
const EMPTY := Color("#1b2a35")
const STORED := Color("#254949")
const SELECTED := Color("#50462f")
const GOLD_DARK := Color("#493823")

var _host: Control
var _board: VBoxContainer
var _status: Label
var _capacity: Label
var _send: Button
var _selected: Dictionary = {}
var _preview: Panel
var _preview_row: Control


func configure(host: Control) -> void:
	_host = host
	if _board == null:
		_build()


func render(rows: Array, selected: Dictionary, offers: Array) -> void:
	_selected = selected.duplicate()
	_clear_preview()
	for child in _board.get_children():
		_board.remove_child(child)
		child.queue_free()
	var used := 0
	for row_index in range(ROWS):
		var tiles: Array = rows[row_index] if row_index < rows.size() else []
		used += _build_row(row_index, tiles, offers)
	_capacity.text = "%d / %d cells used" % [used, COLUMNS * ROWS]
	_send.disabled = int(_selected.get("row", -1)) < 0 or int(_selected.get("lane", 0)) != -1
	if _selected.is_empty():
		show_message("Select a tile to move it, or drag it to an empty cell.")
	else:
		var tile: Dictionary = _host.tile_spec(_selected.id)
		show_message("%s selected · choose a starting cell." % tile.get("label", _selected.id))


func show_message(message: String) -> void:
	if _status != null:
		_status.text = message


func _build() -> void:
	var background := ColorRect.new()
	background.color = INK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 15)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	layout.add_child(header)
	var heading := _label("Tile storage", 28, GOLD)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	header.add_child(_button("Back to arena", func(): _host.storage_close()))
	layout.add_child(_label("Pack tiles in rows. Three touching copies of the same tile can combine.", 15, MUTED))

	var stage := CenterContainer.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.use_top_left = false
	layout.add_child(stage)
	var frame := PanelContainer.new()
	frame.custom_minimum_size.x = 740
	frame.add_theme_stylebox_override("panel", _box(PANEL, EDGE, 12))
	stage.add_child(frame)
	var inset := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		inset.add_theme_constant_override("margin_" + side, 16)
	frame.add_child(inset)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 8)
	inset.add_child(contents)
	_capacity = _label("", 14, TEAL)
	contents.add_child(_capacity)
	_board = VBoxContainer.new()
	_board.add_theme_constant_override("separation", 6)
	contents.add_child(_board)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	layout.add_child(footer)
	_status = _label("", 15, MUTED)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_status)
	_send = _button("Transfer selected to timeline", func(): _host.storage_send_to_timeline())
	_send.disabled = true
	footer.add_child(_send)


func _build_row(row_index: int, tiles: Array, offers: Array) -> int:
	var band := VBoxContainer.new()
	band.add_theme_constant_override("separation", 3)
	_board.add_child(band)
	var offer_strip := Control.new()
	offer_strip.custom_minimum_size.y = COMBINE_HEIGHT
	band.add_child(offer_strip)
	for offer: Dictionary in offers:
		if int(offer.get("row", -1)) == row_index:
			_build_offer(offer_strip, row_index, offer)

	var row := Control.new()
	row.custom_minimum_size.y = TILE_HEIGHT
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.mouse_exited.connect(_clear_preview)
	band.add_child(row)
	var occupied := PackedByteArray()
	occupied.resize(COLUMNS)
	var used := 0
	for item: Dictionary in tiles:
		var tile: Dictionary = _host.tile_spec(item.id)
		var start: int = item.start
		var width := int(tile.get("width", 0))
		if start < 0 or width < 1 or start + width > COLUMNS:
			continue
		for column in range(start, start + width):
			occupied[column] = 1
		_build_tile(row, row_index, item, tile)
		used += width
	for column in range(COLUMNS):
		if occupied[column] == 1:
			continue
		var cell := _button("", func(): _place_selected(row_index, column))
		cell.add_theme_stylebox_override("normal", _box(EMPTY, EDGE, 3))
		cell.tooltip_text = "Storage row %d, column %d" % [row_index + 1, column + 1]
		_span(row, cell, column, 1)
		_drop_target(cell, row, row_index, column, 1)
	return used


func _build_tile(row: Control, row_index: int, item: Dictionary, tile: Dictionary) -> void:
	var payload := {"id": item.id, "lane": -1, "row": row_index, "start": item.start}
	var chosen := int(_selected.get("row", -1)) == row_index and int(_selected.get("start", -1)) == int(item.start)
	var name := String(tile.get("label", item.id))
	var width: int = tile.width
	var card := _button(name, func(): _host.storage_pick(row_index, item))
	card.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.tooltip_text = "%s · width %d\n%s" % [name, width, tile.get("description", "")]
	card.add_theme_stylebox_override("normal", _box(SELECTED if chosen else STORED, GOLD if chosen else TEAL))
	card.add_theme_stylebox_override("hover", _box(STORED.lightened(0.16), GOLD))
	card.add_theme_stylebox_override("pressed", _box(SELECTED, GOLD))
	_span(row, card, int(item.start), width)
	_drop_target(card, row, row_index, int(item.start), width, payload)


func _build_offer(strip: Control, row_index: int, offer: Dictionary) -> void:
	var start := int(offer.start)
	var width := int(offer.width)
	var wrapper := PanelContainer.new()
	wrapper.add_theme_stylebox_override("panel", _box(GOLD_DARK, GOLD))
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 5)
	var caption := _label("Combine", 13, GOLD)
	actions.add_child(caption)
	var accept := _button("Yes", func(): _host.storage_combine(row_index, start, true))
	var decline := _button("No", func(): _host.storage_combine(row_index, start, false))
	accept.add_theme_stylebox_override("normal", _box(GOLD, GOLD))
	accept.add_theme_color_override("font_color", INK)
	actions.add_child(accept)
	actions.add_child(decline)
	wrapper.add_child(actions)
	_span(strip, wrapper, start, width)


func _span(parent: Control, control: Control, start: int, width: int) -> void:
	parent.add_child(control)
	control.anchor_left = float(start) / COLUMNS
	control.anchor_right = float(start + width) / COLUMNS
	control.anchor_bottom = 1.0
	control.offset_left = 2.0
	control.offset_right = -2.0
	control.offset_top = 1.0
	control.offset_bottom = -1.0


func _place_selected(row: int, start: int) -> void:
	if not _selected.is_empty():
		_host.storage_place(row, start, _selected)
	else:
		show_message("Select a tile first.")


func _drop_target(control: Control, row: Control, row_index: int, column: int, span: int, payload := {}) -> void:
	var column_at := func(point: Vector2) -> int:
		return column + clampi(floori(point.x / row.size.x * COLUMNS), 0, span - 1)
	var approved_column := [-1]
	var get_data := Callable()
	if not payload.is_empty():
		get_data = func(_point: Vector2):
			var tile: Dictionary = _host.tile_spec(payload.id)
			var preview := _label(tile.get("label", payload.id), 16, GOLD)
			control.set_drag_preview(preview)
			return payload
	control.set_drag_forwarding(
		get_data,
		func(point: Vector2, data: Variant) -> bool:
			if not data is Dictionary:
				return false
			var start: int = column_at.call(point)
			var allowed: bool = _host.storage_can_place(row_index, start, data)
			approved_column[0] = start if allowed else -1
			var tile: Dictionary = _host.tile_spec(data.get("id", ""))
			var width := mini(int(tile.get("width", 0)), COLUMNS - start)
			if width > 0:
				_show_preview(row, start, width, allowed)
			return allowed,
		func(_point: Vector2, data: Variant):
			_clear_preview()
			if approved_column[0] >= 0:
				_host.storage_place(row_index, approved_column[0], data)
	)


func _show_preview(row: Control, start: int, width: int, allowed: bool) -> void:
	if _preview == null or _preview_row != row:
		_clear_preview()
		_preview = Panel.new()
		_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_preview_row = row
		row.add_child(_preview)
	_preview.anchor_left = float(start) / COLUMNS
	_preview.anchor_right = float(start + width) / COLUMNS
	_preview.anchor_bottom = 1.0
	_preview.offset_left = 2.0
	_preview.offset_right = -2.0
	_preview.offset_top = 1.0
	_preview.offset_bottom = -1.0
	var tint := TEAL if allowed else RUST
	_preview.add_theme_stylebox_override("panel", _box(Color(tint, 0.22), tint))


func _clear_preview() -> void:
	if _preview != null:
		_preview.hide()
		_preview.queue_free()
	_preview = null
	_preview_row = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_clear_preview()


func _button(value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _box(Color("#263642"), EDGE))
	button.add_theme_stylebox_override("hover", _box(Color("#324653"), TEAL))
	button.add_theme_stylebox_override("pressed", _box(SELECTED, GOLD))
	button.add_theme_stylebox_override("disabled", _box(PANEL, EDGE))
	button.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, GOLD))
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", CREAM)
	button.add_theme_color_override("font_pressed_color", CREAM)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.pressed.connect(callback)
	return button


func _label(value: String, points: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", color)
	return label


func _box(fill: Color, line: Color, radius := 5) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = line
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box
