extends Control

const TilePacking = preload("res://scripts/tile_packing.gd")
const GameIcons = preload("res://scripts/game_icons.gd")
const INK := Color("#101820")
const PANEL := Color("#192732")
const EDGE := Color("#3c505b")
const GOLD := Color("#ecc482")
const CREAM := Color("#f3e7d1")
const MUTED := Color("#aababc")
const TEAL := Color("#9ddbd1")
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
var _columns: HBoxContainer
var _links: Control
var _detail_name: Label
var _detail_stats: Label
var _detail_description: Label
var _confirm: Button
var _keep_reward: Button
var _save_reward: Button
var _error: Label


func configure(host: Control) -> void:
	_host = host
	if _columns == null:
		_build()


func open(source_id: String, copies := 3, reward := false, can_keep_reward := false) -> void:
	_source_id = source_id
	_tiers = TilePacking.forge_tiers(source_id)
	_next_ids = TilePacking.next_options(source_id)
	_is_combine = copies == 3
	var source: Dictionary = _host.tile_spec(source_id)
	_title.text = "Combine tiles" if reward else "Tile forge"
	_subtitle.text = "Combine 3 × %s" % source.label if _is_combine else "Upgrade %s" % source.label
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
	_save_reward.visible = reward
	_error.hide()
	for child in _columns.get_children():
		_columns.remove_child(child)
		child.queue_free()
	_cards.clear()
	for tier in range(_tiers.size()):
		if not _tiers[tier].is_empty():
			_add_tier(tier)
	_inspect(source_id)
	show()
	_links.queue_redraw()
	(_cards[source_id] as Button).grab_focus()


func show_error(message: String) -> void:
	_error.text = message
	_error.show()


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
	_title = _label("Tile forge", 34, GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_save_reward = _button("Save & title", func(): _host.run_menu())
	_save_reward.name = "SaveRewardCombine"
	_save_reward.custom_minimum_size = Vector2(112, 40)
	header.add_child(_save_reward)
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

	var board := Panel.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size.y = 360
	board.add_theme_stylebox_override("panel", _box(Color("#132029"), EDGE))
	layout.add_child(board)
	_links = Control.new()
	_links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_links.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_links.draw.connect(_draw_links)
	_links.resized.connect(_links.queue_redraw)
	board.add_child(_links)

	var board_margin := MarginContainer.new()
	board_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board_margin.add_theme_constant_override("margin_left", 22)
	board_margin.add_theme_constant_override("margin_right", 22)
	board_margin.add_theme_constant_override("margin_top", 24)
	board_margin.add_theme_constant_override("margin_bottom", 24)
	board.add_child(board_margin)
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
	_detail_stats = _label("", 15, TEAL)
	_detail_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(_detail_stats)
	_detail_description = _label("", 16, MUTED)
	_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(_detail_description)

	var actions := VBoxContainer.new()
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	actions.add_theme_constant_override("separation", 7)
	detail_row.add_child(actions)
	_confirm = _button("Choose a next-tier tile", _confirm_upgrade)
	_confirm.custom_minimum_size = Vector2(240, 48)
	actions.add_child(_confirm)
	_keep_reward = _button("Keep original tile", func(): _host.run_keep_reward_tile())
	_keep_reward.name = "KeepRewardTile"
	_keep_reward.custom_minimum_size.y = 34
	actions.add_child(_keep_reward)
	_error = _label("", 15, Color("#e8a28b"))
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_error)
	_error.hide()


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
		var card := _button("%s\n%s" % [tile.label, GameIcons.tile_stats(tile)], func(): _inspect(id))
		GameIcons.decorate(card, GameIcons.tile(id, tile), 25)
		card.custom_minimum_size.y = 88
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_theme_font_size_override("font_size", 17)
		card.add_theme_color_override("font_color", CREAM)
		card.add_theme_color_override("font_hover_color", CREAM)
		card.add_theme_color_override("font_pressed_color", CREAM)
		card.tooltip_text = "%s · %s\n%s" % [GameIcons.rarity_name(tile), GameIcons.tile_stats(tile), tile.description]
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
	_inspected_id = id
	var tile: Dictionary = _host.tile_spec(id)
	var rarity := GameIcons.rarity_name(tile)
	var targeting := PackedStringArray()
	for rule: String in tile.get("targets", []):
		targeting.append(TARGETS.get(rule, rule.capitalize()))
	var stats := PackedStringArray([rarity, GameIcons.tile_stats(tile)])
	if not targeting.is_empty():
		stats.append(", ".join(targeting))
	var can_choose := id in _next_ids
	var fits: bool = not can_choose or _host.forge_can_fit(id)
	if can_choose and fits:
		var beat: int = _host.forge_firing_beat(id)
		if beat > 0:
			stats.append("Fires on beat %d" % beat)
	_detail_name.text = tile.label
	_detail_stats.text = "  ·  ".join(stats)
	_detail_stats.add_theme_color_override("font_color", GameIcons.rarity(tile))
	_detail_description.text = tile.description
	_confirm.disabled = not can_choose or not fits
	var prompt := "Combine into " if _is_combine else "Upgrade to "
	_confirm.text = prompt + tile.label if can_choose else "Choose a next-tier tile"
	if not fits:
		_confirm.text = "Needs more room"
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
