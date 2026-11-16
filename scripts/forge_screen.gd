extends Control

const ArenaSim = preload("res://scripts/arena_sim.gd")
const TilePacking = preload("res://scripts/tile_packing.gd")
const GameIcons = preload("res://scripts/game_icons.gd")
const CombatIcons = preload("res://scripts/combat_icons.gd")
const TileKeywords = preload("res://scripts/tile_keywords.gd")
const INK := Color("#101820")
const PANEL := Color("#192732")
const EDGE := Color("#3c505b")
const GOLD := Color("#ecc482")
const CREAM := Color("#f3e7d1")
const MUTED := Color("#aababc")
const BLOCKED := Color("#f0ad90")
const CLEAR := Color("#85d8cd")
const TARGETS := {
	"nearest": "Nearest", "farthest": "Farthest", "lowest_hp": "Lowest HP",
	"highest_hp": "Highest HP", "self": "Self"
}

var _host
var _source_id := ""
var _tiers: Array = []
var _next_ids: Array = []
var _inspected_id := ""
var _is_combine := true
var _cards: Dictionary = {}
var _title: Label
var _subtitle: Label
var _owner_slot: HBoxContainer
var _board: Panel
var _columns: HBoxContainer
var _links: Control
var _detail_name: Label
var _detail_stats: HBoxContainer
var _detail_description: RichTextLabel
var _room_instruction: Label
var _layout_preview: HBoxContainer
var _confirm: Button
var _edit_layout: Button
var _keep_reward: Button
var _save_reward: Button
var _error: Label
var _merge_intro: Panel
var _merge_tween: Tween


func configure(host: Control) -> void:
	_host = host
	if _columns == null:
		_build()


func open(source_id: String, copies := 3, reward := false, can_keep_reward := false, inspected := "") -> void:
	_clear_merge_intro()
	_source_id = source_id
	_tiers = TilePacking.forge_tiers(source_id)
	_next_ids = TilePacking.next_options(source_id)
	_is_combine = copies == 3
	var source: Dictionary = _host.tile_spec(source_id)
	_title.text = "Upgrade ready!" if _is_combine else "Tile forge"
	_subtitle.text = ("Choose an upgrade path for %s" if _is_combine else "Upgrade %s") % source.label
	if reward:
		_subtitle.text = "%s · uses the reward and two owned copies" % _subtitle.text
	for child in _owner_slot.get_children():
		_owner_slot.remove_child(child)
		child.queue_free()
	var origin := GameIcons.tile_origin(source_id, source)
	var owner: String = _host.forge_owner()
	var class_id := owner if not owner.is_empty() else origin
	if not class_id.is_empty():
		_owner_slot.add_child(GameIcons.hero_badge(class_id, false))
	if not owner.is_empty() and not origin.is_empty() and origin != owner:
		_subtitle.text += " · %s signature" % GameIcons.hero_label(origin)
	_keep_reward.visible = reward
	_keep_reward.disabled = not can_keep_reward
	_keep_reward.tooltip_text = "No room for the original tile." if not can_keep_reward else "Claim the tile without combining."
	_save_reward.visible = reward or _host.campaign
	_error.hide()
	for child in _columns.get_children():
		_columns.remove_child(child)
		child.queue_free()
	_cards.clear()
	for tier in range(_tiers.size()):
		if not _tiers[tier].is_empty():
			_add_tier(tier)
	var focus_id := inspected if _cards.has(inspected) else source_id
	_inspect(focus_id)
	show()
	_links.queue_redraw()
	if _is_combine and not _next_ids.is_empty():
		_show_merge_intro(source)
		(_cards[_next_ids.front()] as Button).grab_focus()
	else:
		(_cards[focus_id] as Button).grab_focus()


func show_error(message: String) -> void:
	_error.text = message
	_error.show()


func resume_layout() -> void:
	open(_source_id, 1, false, false, _inspected_id)


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = INK
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_top", 29)
	margin.add_theme_constant_override("margin_bottom", 29)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 17)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	_save_reward = _button("Save & title", _host.run_save_title)
	_save_reward.name = "SaveRewardCombine"
	_save_reward.custom_minimum_size = Vector2(112, 40)
	header.add_child(_save_reward)
	_title = _label("Tile forge", 34, GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var back := _button("Back", func(): _host.forge_close())
	back.name = "BackFromForge"
	back.custom_minimum_size = Vector2(100, 40)
	header.add_child(back)
	var source_row := HBoxContainer.new()
	source_row.add_theme_constant_override("separation", 10)
	layout.add_child(source_row)
	_owner_slot = HBoxContainer.new()
	source_row.add_child(_owner_slot)
	_subtitle = _label("", 16, MUTED)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_row.add_child(_subtitle)

	_board = Panel.new()
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.custom_minimum_size.y = 360
	_board.add_theme_stylebox_override("panel", _box(Color("#132029"), EDGE))
	layout.add_child(_board)
	_links = Control.new()
	_links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_links.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_links.draw.connect(_draw_links)
	_links.resized.connect(_links.queue_redraw)
	_board.add_child(_links)

	var board_margin := MarginContainer.new()
	board_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_margin.add_theme_constant_override("margin_left", 22)
	board_margin.add_theme_constant_override("margin_right", 22)
	board_margin.add_theme_constant_override("margin_top", 24)
	board_margin.add_theme_constant_override("margin_bottom", 24)
	_board.add_child(board_margin)
	_columns = HBoxContainer.new()
	_columns.add_theme_constant_override("separation", 30)
	board_margin.add_child(_columns)

	var details := PanelContainer.new()
	details.custom_minimum_size.y = 155
	var detail_style := _box(PANEL, EDGE)
	detail_style.content_margin_left = 18
	detail_style.content_margin_right = 18
	detail_style.content_margin_top = 15
	detail_style.content_margin_bottom = 15
	details.add_theme_stylebox_override("panel", detail_style)
	layout.add_child(details)
	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation", 18)
	details.add_child(detail_row)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 7)
	detail_row.add_child(copy)
	_detail_name = _label("", 25, CREAM)
	copy.add_child(_detail_name)
	_detail_stats = HBoxContainer.new()
	_detail_stats.add_theme_constant_override("separation", 12)
	copy.add_child(_detail_stats)
	_detail_description = TileKeywords.description("", 16, MUTED)
	copy.add_child(_detail_description)
	_room_instruction = _label("", 15, BLOCKED)
	_room_instruction.name = "ForgeRoomInstruction"
	_room_instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(_room_instruction)
	_layout_preview = HBoxContainer.new()
	_layout_preview.name = "ForgeSpacePreview"
	_layout_preview.add_theme_constant_override("separation", 3)
	copy.add_child(_layout_preview)

	var actions := VBoxContainer.new()
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	actions.add_theme_constant_override("separation", 7)
	detail_row.add_child(actions)
	_confirm = _button("Choose a next-tier tile", _confirm_upgrade)
	_confirm.custom_minimum_size = Vector2(240, 48)
	actions.add_child(_confirm)
	_edit_layout = _button("Edit timeline", func(): _host.forge_edit_layout(_inspected_id))
	_edit_layout.name = "EditForgeLayout"
	_edit_layout.custom_minimum_size.y = 38
	actions.add_child(_edit_layout)
	_keep_reward = _button("Keep original tile", func(): _host.run_keep_reward_tile())
	_keep_reward.name = "KeepRewardTile"
	_keep_reward.custom_minimum_size.y = 34
	actions.add_child(_keep_reward)
	_error = _label("", 15, Color("#e8a28b"))
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_error)
	_error.hide()


func _show_merge_intro(source: Dictionary) -> void:
	const TILE_SIZE := Vector2(118, 84)
	const SEPARATION := 17.0
	_merge_intro = Panel.new()
	_merge_intro.name = "ForgeMergeIntro"
	_merge_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_merge_intro.add_theme_stylebox_override("panel", _box(Color("#18242a"), GOLD))
	_board.add_child(_merge_intro)
	_merge_intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_merge_intro.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stage := Control.new()
	stage.name = "MatchingTiles"
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.custom_minimum_size = Vector2(TILE_SIZE.x * 3 + SEPARATION * 2, TILE_SIZE.y)
	center.add_child(stage)
	var rarity := GameIcons.rarity(source)
	var tiles: Array[PanelContainer] = []
	var art := GameIcons.icon(GameIcons.tile(_source_id, source))
	for index in range(3):
		var tile := PanelContainer.new()
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.position.x = index * (TILE_SIZE.x + SEPARATION)
		tile.size = TILE_SIZE
		tile.pivot_offset = TILE_SIZE * 0.5
		var frame := _box(PANEL.lerp(rarity, 0.14), rarity, 2)
		frame.border_width_top = 4
		tile.add_theme_stylebox_override("panel", frame)
		stage.add_child(tile)
		tiles.append(tile)
		var contents := VBoxContainer.new()
		contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contents.alignment = BoxContainer.ALIGNMENT_CENTER
		contents.add_theme_constant_override("separation", 3)
		tile.add_child(contents)
		var glyph := TextureRect.new()
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.custom_minimum_size.y = 30
		glyph.texture = art
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		contents.add_child(glyph)
		var label := _label(source.label, 13, CREAM)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		contents.add_child(label)
	var merged := tiles[1]
	stage.move_child(merged, -1)
	var glow := merged.get_theme_stylebox("panel") as StyleBoxFlat
	_merge_tween = create_tween()
	_merge_tween.tween_interval(0.10)
	_merge_tween.tween_property(tiles[0], "position", merged.position, 0.24) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_merge_tween.parallel().tween_property(tiles[2], "position", merged.position, 0.24) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for index in [0, 2]:
		_merge_tween.parallel().tween_property(tiles[index], "modulate:a", 0.0, 0.10).set_delay(0.14)
	_merge_tween.tween_property(merged, "scale", Vector2.ONE * 1.16, 0.075)
	_merge_tween.parallel().tween_property(glow, "bg_color", Color("#725631"), 0.075)
	_merge_tween.tween_property(merged, "scale", Vector2.ONE, 0.10)
	_merge_tween.tween_property(_merge_intro, "modulate:a", 0.0, 0.12)
	_merge_tween.tween_callback(func():
		_merge_tween = null
		_clear_merge_intro())


func _clear_merge_intro() -> void:
	if _merge_tween != null:
		_merge_tween.kill()
		_merge_tween = null
	if _merge_intro != null:
		_board.remove_child(_merge_intro)
		_merge_intro.queue_free()
		_merge_intro = null


func _add_tier(tier: int) -> void:
	var ids: Array = _tiers[tier]
	var available: bool = ids[0] in _next_ids
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 108
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 7)
	_columns.add_child(column)

	var spec: Dictionary = _host.tile_spec(ids[0])
	var rarity := GameIcons.rarity_badge(spec)
	rarity.add_theme_font_size_override("font_size", 19)
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(rarity)
	var note := "Choose one" if available else ("Current rarity" if _source_id in ids else "Inspect")
	var state_label := _label(note, 13, GOLD if available else MUTED)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(state_label)
	var options := VBoxContainer.new()
	options.size_flags_vertical = Control.SIZE_EXPAND_FILL
	options.alignment = BoxContainer.ALIGNMENT_CENTER
	options.add_theme_constant_override("separation", 40)
	column.add_child(options)
	for id: String in ids:
		var tile: Dictionary = _host.tile_spec(id)
		var card := _button(tile.label, func(): _inspect(id))
		GameIcons.decorate(card, GameIcons.tile(id, tile), 25)
		card.custom_minimum_size.y = 88
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_theme_font_size_override("font_size", 17)
		card.add_theme_color_override("font_color", CREAM)
		card.add_theme_color_override("font_hover_color", CREAM)
		card.add_theme_color_override("font_pressed_color", CREAM)
		var detail_copy: String = "%s\n%s" % [GameIcons.tile_stats(tile), tile.description]
		card.tooltip_text = TileKeywords.with_definitions("%s · %s" % [GameIcons.rarity_name(tile), detail_copy], detail_copy)
		var focus := _box(Color.TRANSPARENT, CREAM, 2)
		focus.draw_center = false
		card.add_theme_stylebox_override("focus", focus)
		card.item_rect_changed.connect(_links.queue_redraw)
		options.add_child(card)
		_cards[id] = card


func _draw_links() -> void:
	for tier in range(_tiers.size() - 1):
		for from_id: String in _tiers[tier]:
			if not _cards.has(from_id):
				continue
			var start: Rect2 = _cards[from_id].get_global_rect()
			for to_id: String in _tiers[tier + 1]:
				if not _cards.has(to_id):
					continue
				var finish: Rect2 = _cards[to_id].get_global_rect()
				var offset := _links.global_position
				var left := Vector2(start.end.x, start.get_center().y) - offset
				var right := Vector2(finish.position.x, finish.get_center().y) - offset
				var chosen := from_id == _source_id and to_id in _next_ids
				var line_color := GOLD if chosen else Color("#526770")
				var bend := 8.0
				_links.draw_polyline(PackedVector2Array([
					left, left + Vector2(bend, 0), right - Vector2(bend, 0), right
				]), line_color, 2.5 if chosen else 1.5, true)


func _inspect(id: String) -> void:
	_clear_merge_intro()
	_inspected_id = id
	var tile: Dictionary = _host.tile_spec(id)
	var rarity := GameIcons.rarity_name(tile)
	var targeting := PackedStringArray()
	for rule: String in tile.get("targets", []):
		targeting.append(TARGETS.get(rule, rule.capitalize()))
	var can_choose := id in _next_ids
	var fits: bool = not can_choose or _host.forge_can_fit(id)
	for child in _detail_stats.get_children():
		_detail_stats.remove_child(child)
		child.queue_free()
	var tier := _label(rarity, 14, GameIcons.rarity(tile))
	tier.mouse_filter = Control.MOUSE_FILTER_PASS
	if not targeting.is_empty():
		tier.tooltip_text = "Targeting: " + ", ".join(targeting)
		tier.accessibility_name = rarity + ". " + tier.tooltip_text
	_detail_stats.add_child(tier)
	_detail_stats.add_child(CombatIcons.tile_stats(tile))
	_detail_name.text = tile.label
	TileKeywords.set_description(_detail_description, tile.description)
	_confirm.disabled = not can_choose or not fits
	var prompt := "Combine into " if _is_combine else "Upgrade to "
	_confirm.text = prompt + tile.label if can_choose else "Choose a next-tier tile"
	var layout: Dictionary = _host.forge_layout(id) if can_choose else {}
	if not fits and layout.is_empty():
		_confirm.text = "Needs more room"
	_show_layout(layout, tile, fits)
	_confirm.add_theme_stylebox_override("normal", _box(Color("#5b442a"), GOLD))
	_confirm.add_theme_stylebox_override("hover", _box(Color("#715637"), GOLD))
	_confirm.add_theme_stylebox_override("pressed", _box(Color("#45311d"), GOLD))
	for card_id: String in _cards:
		var card: Button = _cards[card_id]
		var available := card_id in _next_ids
		var selected := card_id == id
		var option: Dictionary = _host.tile_spec(card_id)
		var color := GameIcons.rarity(option)
		var fill := PANEL.lerp(color, 0.24 if selected else (0.13 if available else 0.04))
		var frame := _box(fill, color, 2 if selected or available else 1)
		frame.border_width_top = 5 if selected or available else 3
		card.add_theme_stylebox_override("normal", frame)
		var hover := frame.duplicate() as StyleBoxFlat
		hover.bg_color = fill.lightened(0.11)
		card.add_theme_stylebox_override("hover", hover)
		var pressed := frame.duplicate() as StyleBoxFlat
		pressed.bg_color = fill.darkened(0.10)
		card.add_theme_stylebox_override("pressed", pressed)


func _show_layout(layout: Dictionary, upgrade: Dictionary, fits: bool) -> void:
	for child in _layout_preview.get_children():
		_layout_preview.remove_child(child)
		child.queue_free()
	var extra := 0
	if not layout.is_empty():
		extra = int(upgrade.width) - int(ArenaSim.TILES[layout.source.id].width)
	_layout_preview.visible = extra > 0
	_room_instruction.visible = extra > 0
	_edit_layout.visible = extra > 0 and not fits
	if extra <= 0:
		return
	_edit_layout.text = "Edit storage" if layout.stored else "Edit timeline"
	var source: Dictionary = ArenaSim.TILES[layout.source.id]
	var source_start := int(layout.source.start)
	var extension_start := source_start + int(source.width)
	var extension_end := source_start + int(upgrade.width)
	var cell_name := "cell" if layout.stored else "beat"
	var needed := "one free %s" % cell_name if extra == 1 else "%d free %ss" % [extra, cell_name]
	var blockers := PackedStringArray()
	for item: Dictionary in layout.items:
		if int(item.start) >= extension_end or int(item.start) + int(ArenaSim.TILES[item.id].width) <= extension_start:
			continue
		var label: String = ArenaSim.TILES[item.id].label
		if label not in blockers:
			blockers.append(label)
	if fits:
		_room_instruction.text = "Fits here with %s immediately after %s." % [needed, source.label]
	else:
		_room_instruction.text = "Needs %s immediately after %s." % [needed, source.label]
		if extension_end > int(layout.capacity):
			_room_instruction.text += " Move it earlier in the %s." % ("row" if layout.stored else "timeline")
		elif not blockers.is_empty():
			_room_instruction.text += " Blocked by %s." % ", ".join(blockers)
	_room_instruction.add_theme_color_override("font_color", CLEAR if fits else BLOCKED)
	for index in range(int(layout.capacity)):
		var occupant := ""
		for item: Dictionary in layout.items:
			if int(item.start) <= index and index < int(item.start) + int(ArenaSim.TILES[item.id].width):
				occupant = ArenaSim.TILES[item.id].label
				break
		var is_source := index >= source_start and index < extension_start
		var is_extension := index >= extension_start and index < extension_end
		var color := EDGE
		if is_source:
			color = GOLD
		elif is_extension:
			color = CLEAR if occupant.is_empty() else BLOCKED
		var cell := Label.new()
		cell.text = str(index + 1)
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		cell.custom_minimum_size.y = 23
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_font_size_override("font_size", 12)
		cell.add_theme_color_override("font_color", CREAM if is_source or is_extension else MUTED)
		var style := _box(INK.lerp(color, 0.25 if is_source or is_extension else 0.08), color)
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		style.set_corner_radius_all(4)
		cell.add_theme_stylebox_override("normal", style)
		var contents := occupant if not occupant.is_empty() else "Open"
		cell.tooltip_text = "%s %d · %s" % [cell_name.capitalize(), index + 1, contents]
		if is_extension and not occupant.is_empty():
			cell.tooltip_text += " blocks this upgrade"
		cell.accessibility_name = cell.tooltip_text
		_layout_preview.add_child(cell)


func _confirm_upgrade() -> void:
	if _inspected_id in _next_ids:
		_host.forge_choose(_inspected_id)


func _box(fill: Color, border: Color, border_width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_corner_radius_all(8)
	style.set_border_width_all(border_width)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _label(value: String, points: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", color)
	return label


func _button(value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.pressed.connect(action)
	return button
