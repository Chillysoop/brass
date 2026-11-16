extends Control

const GameIcons = preload("res://scripts/game_icons.gd")
const CombatIcons = preload("res://scripts/combat_icons.gd")
const TilePacking = preload("res://scripts/tile_packing.gd")
const TileEnchantments = preload("res://scripts/tile_enchantments.gd")
const TileKeywords = preload("res://scripts/tile_keywords.gd")

const COLUMNS := TilePacking.STORAGE_COLUMNS
const ROWS := TilePacking.STORAGE_ROWS
const COMBINE_HEIGHT := 29.0
const DOCK_CELL_WIDTH := 26.0
const DOCK_ROW_HEIGHT := 34.0
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
var _stage: CenterContainer
var _frame: PanelContainer
var _layout: VBoxContainer
var _grid: ScrollContainer
var _board: VBoxContainer
var _rows: Array[Control] = []
var _tile_row_size := Vector2.ZERO
var _popup_tile_row_size := Vector2.ZERO
var _docked := false
var _heading: Label
var _close: Button
var _footer: HBoxContainer
var _dock_footer: HFlowContainer
var _status: Label
var _capacity: Label
var _send: Button
var _discard: Button
var _forge: Button
var _combine: Button
var _enchantment_rows: VBoxContainer
var _selected: Dictionary = {}
var _preview: Control
var _preview_row: Control
var _preview_key: Array = []
var _dragged_card: Control
var _focused_cell := Vector2i(-1, -1)


func configure(host: Control) -> void:
	_host = host
	if _board == null:
		_build()


func set_tile_size(beat_pitch: float, row_height: float) -> void:
	_popup_tile_row_size = Vector2(COLUMNS * beat_pitch, row_height)
	if not _docked:
		_apply_tile_size(_popup_tile_row_size)


func set_docked(docked: bool) -> void:
	if _docked == docked:
		return
	_docked = docked
	_frame.reparent(self if docked else _stage, false)
	_frame.set_anchors_and_offsets_preset(PRESET_FULL_RECT if docked else PRESET_TOP_LEFT)
	_frame.custom_minimum_size.x = 0 if docked else 740
	var border := _box(PANEL, GOLD_DARK, 12)
	if docked:
		border.content_margin_left = 6
		border.content_margin_right = 6
	_frame.add_theme_stylebox_override("panel", border)
	_heading.add_theme_font_size_override("font_size", 18 if docked else 22)
	_close.visible = not docked
	_grid.size_flags_vertical = SIZE_EXPAND_FILL if docked else SIZE_FILL
	size_flags_vertical = SIZE_EXPAND_FILL if docked else SIZE_FILL
	for button: Button in [_send, _discard, _forge, _combine]:
		button.reparent(_dock_footer if docked else _footer, false)
		button.add_theme_font_size_override("font_size", 12 if docked else 14)
	_status.reparent(_layout if docked else _footer, false)
	if docked:
		_layout.move_child(_status, _dock_footer.get_index())
	else:
		_footer.move_child(_status, 0)
	_footer.visible = not docked
	_dock_footer.visible = docked
	_status.add_theme_font_size_override("font_size", 12 if docked else 14)
	_discard.text = "Discard" if docked else "Discard selected"
	_discard.accessibility_name = "Discard selected tile"
	_apply_tile_size(Vector2(COLUMNS * DOCK_CELL_WIDTH, DOCK_ROW_HEIGHT) if docked else _popup_tile_row_size)


func _apply_tile_size(row_size: Vector2) -> void:
	_tile_row_size = row_size
	_board.custom_minimum_size.x = _tile_row_size.x
	for row: Control in _rows:
		row.get_parent().custom_minimum_size.y = row_size.y
		row.size = _tile_row_size
	_fit_grid.call_deferred()


func render(rows: Array, selected: Dictionary, offers: Array, camp := false, can_combine := false,
		enchantments := [], protect_selected := false) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	var scroll_top := _grid.scroll_vertical
	_focused_cell = focus.get_meta("storage_cell", Vector2i(-1, -1)) if is_instance_valid(focus) else Vector2i(-1, -1)
	_selected = selected.duplicate()
	_end_drag()
	_rows.clear()
	for child in _board.get_children():
		_board.remove_child(child)
		child.queue_free()
	var used := 0
	for row_index in range(ROWS):
		var tiles: Array = rows[row_index] if row_index < rows.size() else []
		used += _build_row(row_index, tiles, offers)
	_capacity.text = ("%d / %d" if _docked else "%d / %d cells used") % [used, COLUMNS * ROWS]
	_capacity.tooltip_text = "%d of %d storage cells used" % [used, COLUMNS * ROWS]
	_send.disabled = not _selected.has("row")
	_discard.disabled = not _selected.has("lane") or protect_selected
	_discard.tooltip_text = "Return to the forge before discarding this tile." if protect_selected else ""
	_forge.visible = camp
	_forge.disabled = not _selected.has("lane")
	_combine.visible = can_combine
	_render_enchantments(enchantments)
	if _selected.is_empty():
		var message := "Drag to move tiles." if _docked else "Drag between storage and the timeline."
		if camp:
			message = "Select a tile in the sequence or storage to upgrade."
		show_message("Select a tile to enchant." if _enchantment_rows.visible and not camp else message)
	else:
		var tile: Dictionary = _host.tile_spec(_selected.id)
		show_message("%s selected" % tile.get("label", _selected.id))
	_fit_grid.call_deferred()
	_grid.set_deferred("scroll_vertical", scroll_top)


func _render_enchantments(enchantments: Array) -> void:
	for child in _enchantment_rows.get_children():
		_enchantment_rows.remove_child(child)
		child.queue_free()
	_enchantment_rows.visible = not enchantments.is_empty()
	for entry: Dictionary in enchantments:
		var id: String = entry.id
		var info := TileEnchantments.info(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_enchantment_rows.add_child(row)
		row.add_child(GameIcons.enchantment_badge(id, 19))
		var caption := "%s · %s" % [info.label, "Unequipped" if entry.host.is_empty() else entry.host]
		var label := _label(caption, 12 if _docked else 14, GameIcons.enchantment_color(id))
		label.size_flags_horizontal = SIZE_EXPAND_FILL
		label.size_flags_vertical = SIZE_SHRINK_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = MOUSE_FILTER_PASS
		label.tooltip_text = "%s\n%s" % [caption, info.description]
		row.add_child(label)
		var button := _button(entry.button, func(): _host.storage_enchant_selected(id))
		button.name = "EnchantSelected_" + id
		button.accessibility_name = "%s %s" % [entry.button, info.label]
		button.disabled = not entry.eligible
		var detail: String = info.description
		if not entry.eligible:
			detail = "Select a compatible tile in storage or on the timeline.\n" + detail
		elif not entry.replaced.is_empty():
			var replaced: String = TileEnchantments.info(entry.replaced).label
			button.accessibility_name = "Equip %s in place of %s" % [info.label, replaced]
			detail = "%s returns to the available enchantments.\n%s" % [replaced, detail]
		button.tooltip_text = detail
		if _docked:
			button.add_theme_font_size_override("font_size", 12)
		row.add_child(button)


func show_message(message: String) -> void:
	if _status != null:
		_status.text = message
		_status.tooltip_text = message


func _build() -> void:
	name = "TileStoragePopup"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage = CenterContainer.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame = PanelContainer.new()
	_frame.custom_minimum_size.x = 740
	_frame.add_theme_stylebox_override("panel", _box(PANEL, GOLD_DARK, 12))
	_stage.add_child(_frame)
	_layout = VBoxContainer.new()
	_layout.add_theme_constant_override("separation", 5)
	_frame.add_child(_layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_layout.add_child(header)
	_heading = _label("Tile storage", 22, GOLD)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_heading)
	_capacity = _label("", 14, TEAL)
	_capacity.mouse_filter = Control.MOUSE_FILTER_PASS
	_capacity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_capacity)
	_close = _button("Close", func(): _host.storage_close())
	_close.name = "CloseStorage"
	header.add_child(_close)
	_grid = ScrollContainer.new()
	_grid.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid.follow_focus = true
	_layout.add_child(_grid)
	_board = VBoxContainer.new()
	_board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_board.add_theme_constant_override("separation", 4)
	_grid.add_child(_board)
	_enchantment_rows = VBoxContainer.new()
	_enchantment_rows.name = "HeldEnchantments"
	_enchantment_rows.add_theme_constant_override("separation", 3)
	_layout.add_child(_enchantment_rows)
	_enchantment_rows.hide()

	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 12)
	_layout.add_child(_footer)
	_dock_footer = HFlowContainer.new()
	_dock_footer.add_theme_constant_override("h_separation", 4)
	_dock_footer.add_theme_constant_override("v_separation", 3)
	_layout.add_child(_dock_footer)
	_dock_footer.hide()
	_status = _label("", 14, MUTED)
	_status.mouse_filter = Control.MOUSE_FILTER_PASS
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(_status)
	_send = _button("To timeline", func(): _host.storage_send_to_timeline())
	_send.disabled = true
	_footer.add_child(_send)
	_discard = _button("Discard selected", func(): _host.storage_discard())
	_discard.name = "DiscardSelected"
	_discard.disabled = true
	_footer.add_child(_discard)
	_forge = _button("Forge selected", func(): _host.storage_forge())
	_forge.name = "StorageForgeSelected"
	_forge.hide()
	_footer.add_child(_forge)
	_combine = _button("Combine 3", func(): _host.storage_combine_selected())
	_combine.name = "CombineSelected"
	_combine.tooltip_text = "Combine three matching copies from your timelines or storage."
	_combine.hide()
	_footer.add_child(_combine)
	resized.connect(_fit_grid)


func _fit_grid() -> void:
	if _docked:
		_grid.custom_minimum_size = Vector2(_tile_row_size.x, 0)
		return
	var chrome_height := _frame.get_combined_minimum_size().y - _grid.get_combined_minimum_size().y
	var board_height := _board.get_combined_minimum_size().y
	var grid_height := minf(board_height, maxf(_tile_row_size.y, floorf(size.y - chrome_height - 4.0)))
	var scrollbar_width := _grid.get_v_scroll_bar().get_combined_minimum_size().x if grid_height < board_height else 0.0
	_grid.custom_minimum_size = Vector2(ceilf(_tile_row_size.x + scrollbar_width), grid_height)


func _build_row(row_index: int, tiles: Array, offers: Array) -> int:
	var band := VBoxContainer.new()
	band.add_theme_constant_override("separation", 1)
	_board.add_child(band)
	var offer_strip := Control.new()
	band.add_child(offer_strip)
	offer_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for offer: Dictionary in offers:
		if int(offer.get("row", -1)) == row_index:
			offer_strip.custom_minimum_size.y = COMBINE_HEIGHT
			_build_offer(offer_strip, row_index, offer)

	# Containers round their child widths. Keep the tile pitch exact inside the reserved row.
	var row_space := Control.new()
	row_space.custom_minimum_size.y = _tile_row_size.y
	row_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(row_space)
	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row_space.add_child(row)
	row.size = _tile_row_size
	_rows.append(row)
	_drop_target(row, row, row_index, tiles)
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
		_build_tile(row, row_index, item, tile, tiles)
		used += width
	for column in range(COLUMNS):
		if occupied[column] == 1:
			continue
		var cell := _button("", func(): _place_selected(row_index, column))
		cell.add_theme_stylebox_override("normal", _box(EMPTY, EDGE, 3))
		cell.tooltip_text = "Storage row %d, column %d" % [row_index + 1, column + 1]
		_span(row, cell, column, 1)
		_keep_cell_focus(cell, row_index, column)
		_drop_target(cell, row, row_index, tiles)
	return used


func _build_tile(row: Control, row_index: int, item: Dictionary, tile: Dictionary, tiles: Array) -> void:
	var payload := {"id": item.id, "lane": -1, "row": row_index, "start": item.start}
	var chosen := int(_selected.get("row", -1)) == row_index and int(_selected.get("start", -1)) == int(item.start)
	var name := String(tile.get("label", item.id))
	var caption: String = tile.get("short_label", name)
	var width: int = tile.width
	var metric := {} if _docked else CombatIcons.tile_corner_stat(tile)
	var icon_only := _docked and width == 1
	var card := _button("" if icon_only else caption, func(): _host.storage_pick(row_index, item))
	card.name = "StoredTile_%s_%d_%d" % [item.id, row_index, item.start]
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	GameIcons.decorate(card, GameIcons.tile(item.id, tile), 15 if width == 1 or _docked else 22)
	if _docked:
		card.add_theme_constant_override("h_separation", 3)
		card.add_theme_font_size_override("font_size", 11)
		card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if icon_only else HORIZONTAL_ALIGNMENT_LEFT
	elif width == 1:
		card.add_theme_constant_override("h_separation", 3)
		card.add_theme_font_size_override("font_size", 13)
	card.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var origin := GameIcons.tile_origin(item.id, tile)
	var ownership := "Shared storage"
	if not origin.is_empty():
		ownership += " · %s signature" % GameIcons.hero_label(origin)
	var copy: String = tile.get("description", "")
	card.tooltip_text = "%s · %s · %s\n%s\n%s" % [name, GameIcons.rarity_name(tile), GameIcons.tile_stats(tile), ownership, copy]
	var enchantment := TileEnchantments.info(item.get("enchantment", ""))
	if not enchantment.is_empty():
		card.tooltip_text += "\n%s · %s" % [enchantment.label, enchantment.description]
		copy += "\n" + enchantment.description
	card.tooltip_text = TileKeywords.with_definitions(card.tooltip_text, GameIcons.tile_stats(tile) + "\n" + copy)
	card.accessibility_name = name
	var rarity := GameIcons.rarity(tile)
	for mode: String in ["normal", "hover", "pressed"]:
		var fill := STORED.lightened(0.16) if mode == "hover" else STORED
		if chosen or mode == "pressed":
			fill = SELECTED
		var box := _box(fill, rarity)
		box.border_width_top = 3
		box.content_margin_top = 4 if _docked else 16
		box.content_margin_bottom = 2
		if _docked:
			box.content_margin_left = 3
			box.content_margin_right = 3
		elif width == 1:
			box.content_margin_left = 4
			box.content_margin_right = 4
		if not metric.is_empty():
			box.content_margin_right = 25
		card.add_theme_stylebox_override(mode, box)
	_span(row, card, int(item.start), width, true)
	_keep_cell_focus(card, row_index, item.start)
	_drop_target(card, row, row_index, tiles, payload)
	if _docked:
		return
	var rarity_badge := GameIcons.rarity_badge(tile, true)
	card.add_child(rarity_badge)
	rarity_badge.position = Vector2(6, 3)
	if not origin.is_empty():
		var hero_badge := GameIcons.hero_badge(origin)
		card.add_child(hero_badge)
		hero_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 4)
		hero_badge.offset_top = 3
	if not enchantment.is_empty():
		var badge := GameIcons.enchantment_badge(enchantment.id, 15)
		card.add_child(badge)
		badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
		badge.offset_top = 2
	CombatIcons.add_tile_corner(card, metric)


func _keep_cell_focus(button: Button, row: int, column: int) -> void:
	var cell := Vector2i(column, row)
	button.set_meta("storage_cell", cell)
	if cell == _focused_cell:
		button.grab_focus()


func _build_offer(strip: Control, row_index: int, offer: Dictionary) -> void:
	var start := int(offer.start)
	var width := int(offer.width)
	var wrapper := PanelContainer.new()
	var backing := _box(GOLD_DARK, GOLD)
	backing.content_margin_top = 0
	backing.content_margin_bottom = 0
	if _docked:
		backing.content_margin_left = 3
		backing.content_margin_right = 3
	wrapper.add_theme_stylebox_override("panel", backing)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 5)
	if not _docked:
		actions.add_child(_label("Combine", 13, GOLD))
	var accept := _button("✓" if _docked else "Yes", func(): _host.storage_combine(row_index, start, true))
	var decline := _button("×" if _docked else "No", func(): _host.storage_combine(row_index, start, false))
	accept.tooltip_text = "Combine three matching tiles"
	decline.tooltip_text = "Keep these tiles separate"
	accept.accessibility_name = accept.tooltip_text
	decline.accessibility_name = decline.tooltip_text
	accept.add_theme_stylebox_override("normal", _box(GOLD, GOLD))
	accept.add_theme_color_override("font_color", INK)
	for button: Button in [accept, decline]:
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for state: String in ["normal", "hover", "pressed", "focus"]:
			var style := button.get_theme_stylebox(state) as StyleBoxFlat
			style.content_margin_top = 1
			style.content_margin_bottom = 1
			if _docked:
				style.content_margin_left = 4
				style.content_margin_right = 4
	actions.add_child(accept)
	actions.add_child(decline)
	wrapper.add_child(actions)
	_span(strip, wrapper, start, width)


func _span(parent: Control, control: Control, start: int, width: int, tile := false) -> void:
	parent.add_child(control)
	control.anchor_left = float(start) / COLUMNS
	control.anchor_right = float(start + width) / COLUMNS
	control.anchor_bottom = 1.0
	control.offset_left = 2.0
	control.offset_right = 0.0 if tile else -2.0
	control.offset_top = 1.0
	control.offset_bottom = -1.0


func _place_selected(row: int, start: int) -> void:
	if not _selected.is_empty():
		_host.storage_place(row, start, _selected)
	else:
		show_message("Select a tile first.")


func _drop_target(control: Control, row: Control, row_index: int, tiles: Array, payload := {}) -> void:
	var drop_start := func(data: Dictionary, width: int) -> int:
		var local: Vector2 = row.get_global_transform_with_canvas().affine_inverse() * _host.drag_pointer
		return clampi(floori(local.x * COLUMNS / row.size.x) - int(data.get("grab_offset", 0)), 0, COLUMNS - width)
	var get_data := Callable()
	if not payload.is_empty():
		get_data = func(point: Vector2):
			var tile: Dictionary = _host.tile_spec(payload.id)
			var preview := Control.new()
			var caption := _label(tile.label, 16, GameIcons.rarity(tile))
			caption.position = Vector2(13, -32)
			preview.add_child(caption)
			var dragged := payload.duplicate()
			var local: Vector2 = row.get_global_transform().affine_inverse() * (control.get_global_transform() * point)
			dragged.grab_offset = clampi(floori(local.x * COLUMNS / row.size.x) - int(payload.start), 0, int(tile.width) - 1)
			control.set_drag_preview(preview)
			_dragged_card = control
			_dragged_card.modulate.a = 0.25
			return dragged
	control.set_drag_forwarding(
		get_data,
		func(_point: Vector2, data: Variant) -> bool:
			if not data is Dictionary:
				return false
			var tile: Dictionary = _host.tile_spec(data.get("id", ""))
			var width := int(tile.get("width", 0))
			if width < 1 or width > COLUMNS:
				return false
			var start: int = drop_start.call(data, width)
			var plan: Dictionary = _host.storage_nudge_plan(row_index, start, data)
			var ignored_start: int = data.get("start", -1) if data.get("row", -1) == row_index else -1
			_show_preview(row, tiles, start, tile, ignored_start, plan)
			return not plan.is_empty(),
		func(_point: Vector2, data: Variant):
			var tile: Dictionary = _host.tile_spec(data.id)
			var start: int = drop_start.call(data, tile.width)
			_end_drag()
			_host.storage_place(row_index, start, data, true)
	)


func _show_preview(row: Control, tiles: Array, start: int, incoming: Dictionary, ignored_start: int, plan: Dictionary) -> void:
	var key := [row, start, incoming.label, ignored_start, plan]
	if _preview_key == key:
		return
	_clear_preview()
	_preview_key = key
	_preview_row = row
	if plan.is_empty():
		_preview = _preview_card("No room", Color(RUST, 0.25), RUST)
		_span(row, _preview, start, incoming.width, true)
		return

	var backdrop := ColorRect.new()
	backdrop.color = PANEL
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview = backdrop
	row.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var occupied := PackedByteArray()
	occupied.resize(COLUMNS)
	var moves: Dictionary = plan.moves
	for item: Dictionary in tiles:
		if item.start == ignored_start:
			continue
		var tile: Dictionary = _host.tile_spec(item.id)
		var position: int = moves.get(item.start, item.start)
		for column in range(position, position + int(tile.width)):
			occupied[column] = 1
		var accent := GOLD if position != item.start else TEAL
		_span(backdrop, _preview_card(tile.label, STORED, accent), position, tile.width, true)
	for column in range(start, start + int(incoming.width)):
		occupied[column] = 1
	_span(backdrop, _preview_card(incoming.label, SELECTED, GOLD), start, incoming.width, true)
	for column in range(COLUMNS):
		if occupied[column] == 0:
			_span(backdrop, _preview_card("", EMPTY, EDGE), column, 1)


func _preview_card(value: String, fill: Color, edge: Color) -> Label:
	var card := _label(value, 14, CREAM)
	card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.add_theme_stylebox_override("normal", _box(fill, edge))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


func _clear_preview() -> void:
	if _preview != null:
		_preview.hide()
		_preview.queue_free()
	_preview = null
	_preview_row = null
	_preview_key.clear()


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		if _dragged_card != null or _preview != null:
			_end_drag()
	elif _preview_row != null:
		var hovered := get_viewport().gui_get_hovered_control()
		if hovered == null or (hovered != _preview_row and not _preview_row.is_ancestor_of(hovered)):
			_clear_preview()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_end_drag()


func _end_drag() -> void:
	if is_instance_valid(_dragged_card):
		_dragged_card.modulate.a = 1.0
	_dragged_card = null
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
