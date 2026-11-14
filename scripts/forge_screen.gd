extends Control

const ArenaSim = preload("res://scripts/arena_sim.gd")
const INK := Color("#101820")
const PANEL := Color("#192732")
const EDGE := Color("#3c505b")
const GOLD := Color("#ecc482")
const CREAM := Color("#f3e7d1")
const MUTED := Color("#aababc")
const TEAL := Color("#9ddbd1")
const RARITIES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const TARGETS := {
	"nearest": "Nearest", "farthest": "Farthest", "lowest_hp": "Lowest HP",
	"highest_hp": "Highest HP", "self": "Self"
}

var _host
var _source_id := ""
var _next_ids: Array = []
var _inspected_id := ""
var _cards: Dictionary = {}
var _subtitle: Label
var _columns: HBoxContainer
var _links: Control
var _detail_name: Label
var _detail_stats: Label
var _detail_description: Label
var _confirm: Button


func configure(host: Control) -> void:
	_host = host
	if _columns == null:
		_build()


func open(source_id: String, copies := 3) -> void:
	_source_id = source_id
	_next_ids = []
	for tier in range(ArenaSim.BASH_TIERS.size() - 1):
		if source_id in ArenaSim.BASH_TIERS[tier]:
			_next_ids = ArenaSim.BASH_TIERS[tier + 1]
			break
	var source: Dictionary = _host.tile_spec(source_id)
	_subtitle.text = "Three %s tiles are ready to combine. Inspect any tile, then choose from the next rarity." % source.label if copies == 3 else "Upgrade one %s at the rest site. Inspect any tile, then choose from the next rarity." % source.label
	for child in _columns.get_children():
		_columns.remove_child(child)
		child.queue_free()
	_cards.clear()
	for tier in range(ArenaSim.BASH_TIERS.size()):
		_add_tier(tier)
	_inspect(source_id)
	show()
	_links.queue_redraw()
	(_cards[source_id] as Button).grab_focus()


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
	var title := _label("Tile forge", 34, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var back := _button("Back", func(): _host.forge_close())
	back.custom_minimum_size = Vector2(100, 40)
	header.add_child(back)
	_subtitle = _label("", 16, MUTED)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_subtitle)

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

	_confirm = _button("Choose a next-tier tile", _confirm_upgrade)
	_confirm.custom_minimum_size = Vector2(240, 48)
	_confirm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	detail_row.add_child(_confirm)


func _add_tier(tier: int) -> void:
	var ids: Array = ArenaSim.BASH_TIERS[tier]
	var available: bool = ids[0] in _next_ids
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 108
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 7)
	_columns.add_child(column)

	var rarity := _label(RARITIES[tier], 19, GOLD if available else CREAM)
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
		var card := _button("%s\n%d beats" % [tile.label, tile.width], func(): _inspect(id))
		card.custom_minimum_size.y = 88
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_theme_font_size_override("font_size", 17)
		card.item_rect_changed.connect(_links.queue_redraw)
		options.add_child(card)
		_cards[id] = card


func _draw_links() -> void:
	for tier in range(ArenaSim.BASH_TIERS.size() - 1):
		for from_id: String in ArenaSim.BASH_TIERS[tier]:
			if not _cards.has(from_id):
				continue
			var start: Rect2 = _cards[from_id].get_global_rect()
			for to_id: String in ArenaSim.BASH_TIERS[tier + 1]:
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
	var rarity := ""
	for tier in range(ArenaSim.BASH_TIERS.size()):
		if id in ArenaSim.BASH_TIERS[tier]:
			rarity = RARITIES[tier]
			break
	var targeting := PackedStringArray()
	for rule: String in tile.get("targets", []):
		targeting.append(TARGETS.get(rule, rule.capitalize()))
	var stats := PackedStringArray([rarity, "%d beats" % tile.width, "%d damage" % tile.damage])
	if not targeting.is_empty():
		stats.append(", ".join(targeting))
	_detail_name.text = tile.label
	_detail_stats.text = "  ·  ".join(stats)
	_detail_description.text = tile.description
	var can_choose := id in _next_ids
	_confirm.disabled = not can_choose
	_confirm.text = "Combine into " + tile.label if can_choose else "Choose a next-tier tile"
	_confirm.add_theme_stylebox_override("normal", _box(Color("#5b442a"), GOLD))
	_confirm.add_theme_stylebox_override("hover", _box(Color("#715637"), GOLD))
	_confirm.add_theme_stylebox_override("pressed", _box(Color("#45311d"), GOLD))
	for card_id: String in _cards:
		var card: Button = _cards[card_id]
		var available := card_id in _next_ids
		var selected := card_id == id
		var fill := Color("#392f25") if available else PANEL
		var border := GOLD if available else EDGE
		if selected:
			fill = Color("#5b442a") if available else Color("#233e41")
			border = GOLD if available else TEAL
		card.add_theme_stylebox_override("normal", _box(fill, border, 2 if selected else 1))
		card.add_theme_stylebox_override("hover", _box(fill.lightened(0.13), border))
		card.add_theme_stylebox_override("pressed", _box(fill.darkened(0.1), border))


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
