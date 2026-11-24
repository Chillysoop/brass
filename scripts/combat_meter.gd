extends PanelContainer

const ArenaSim = preload("res://scripts/arena_sim.gd")
const CombatIcons = preload("res://scripts/combat_icons.gd")
const CombatTotals = preload("res://scripts/combat_totals.gd")
const GameIcons = preload("res://scripts/game_icons.gd")

const PANEL := Color("#192732")
const RECESS := Color("#111e28")
const EDGE := Color("#3c505b")
const GOLD := Color("#ecc482")
const CREAM := Color("#f3e7d1")
const MUTED := Color("#aababc")
const LABELS := {"damage": "Damage", "assists": "Assists", "kills": "Kills", "healing": "Healing"}
const ICONS := {"damage": "attack", "assists": "assists", "kills": "kills", "healing": "heal"}
const HELP := {
	"damage": "Health lost to this tile after Guard. Excess damage is excluded.",
	"assists": "Hit or moved an enemy before a different tile defeated it. One assist per tile and enemy.",
	"kills": "Enemies defeated by this tile.",
	"healing": "Health this tile actually restored.",
}
const EMPTY := {"damage": "No damage", "assists": "No assists", "kills": "No kills", "healing": "No healing"}

var totals := CombatTotals.new()
var metric := "damage"
var _tabs := {}
var _leaderboard: VBoxContainer
var _scroller: ScrollContainer
var _empty: Label
var _rows: Array[PanelContainer] = []


func _ready() -> void:
	name = "CombatMeter"
	custom_minimum_size.x = 245
	size_flags_vertical = SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", _frame(Color(PANEL, 0.80), Color(EDGE, 0.88), 10))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	add_child(body)
	body.add_child(_label("Combat stats", 19, GOLD))
	var tabs := GridContainer.new()
	tabs.columns = 4
	tabs.add_theme_constant_override("h_separation", 5)
	tabs.add_theme_constant_override("v_separation", 4)
	body.add_child(tabs)
	var group := ButtonGroup.new()
	for id: String in CombatTotals.METRICS:
		var tab := Button.new()
		tab.name = "CombatMetric_" + id
		var name_row := HBoxContainer.new()
		name_row.mouse_filter = MOUSE_FILTER_IGNORE
		name_row.add_theme_constant_override("separation", 4)
		name_row.add_child(CombatIcons.icon(ICONS[id], 21))
		tab.add_child(name_row)
		name_row.set_anchors_and_offsets_preset(PRESET_CENTER, PRESET_MODE_MINSIZE)
		tab.accessibility_name = LABELS[id]
		tab.tooltip_text = "%s · %s" % [LABELS[id], HELP[id]]
		tab.custom_minimum_size = Vector2(44, 36)
		tab.size_flags_horizontal = SIZE_EXPAND_FILL
		tab.toggle_mode = true
		tab.button_group = group
		tab.pressed.connect(func(): set_metric(id))
		_tabs[id] = tab
		tabs.add_child(tab)
	_empty = _label("", 14, MUTED)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.custom_minimum_size.y = 42
	body.add_child(_empty)
	_scroller = ScrollContainer.new()
	_scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroller.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_child(_scroller)
	_leaderboard = VBoxContainer.new()
	_leaderboard.name = "CombatRanks"
	_leaderboard.size_flags_horizontal = SIZE_EXPAND_FILL
	_leaderboard.add_theme_constant_override("separation", 4)
	_scroller.add_child(_leaderboard)
	visibility_changed.connect(func():
		if is_visible_in_tree():
			_update_rows()
	)
	set_metric(metric)


func reset() -> void:
	totals.reset()
	if _scroller != null:
		_scroller.scroll_vertical = 0
	_update_rows()


func record(events: Array, units: Array) -> void:
	if totals.record(events, units) and is_visible_in_tree():
		_update_rows()


func snapshot() -> Dictionary:
	return totals.snapshot()


func restore(summary: Variant) -> void:
	totals.restore(summary)
	if _scroller != null:
		_scroller.scroll_vertical = 0
	_update_rows()


func set_metric(value: String) -> void:
	if value not in CombatTotals.METRICS:
		return
	metric = value
	if _tabs.has(metric):
		for id: String in _tabs:
			_tabs[id].set_pressed_no_signal(id == metric)
		_scroller.scroll_vertical = 0
	_update_rows()


func _update_rows() -> void:
	if _leaderboard == null:
		return
	var ranked := totals.ranked(metric)
	_empty.text = EMPTY[metric]
	_empty.visible = ranked.is_empty()
	_scroller.visible = not ranked.is_empty()
	var leader := int(ranked.front()[metric]) if not ranked.is_empty() else 1
	for index in range(ranked.size()):
		if index >= _rows.size():
			_rows.append(_build_row())
		_paint_row(_rows[index], ranked[index], leader)
		_rows[index].show()
	for index in range(ranked.size(), _rows.size()):
		_rows[index].hide()


func _build_row() -> PanelContainer:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _frame(Color(RECESS, 0.58), Color(EDGE, 0.66), 6))
	frame.mouse_filter = MOUSE_FILTER_PASS
	_leaderboard.add_child(frame)
	var column := VBoxContainer.new()
	column.mouse_filter = MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 3)
	frame.add_child(column)
	var heading := HBoxContainer.new()
	heading.mouse_filter = MOUSE_FILTER_IGNORE
	heading.add_theme_constant_override("separation", 4)
	column.add_child(heading)
	var art := TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(17, 17)
	art.mouse_filter = MOUSE_FILTER_IGNORE
	heading.add_child(art)
	var title := _label("", 14, CREAM)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.add_child(title)
	var amount := _label("", 15, GOLD)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var value := HBoxContainer.new()
	value.mouse_filter = MOUSE_FILTER_IGNORE
	value.add_theme_constant_override("separation", 3)
	var metric_icon := CombatIcons.icon(ICONS[metric], 14)
	value.add_child(metric_icon)
	value.add_child(amount)
	heading.add_child(value)
	var hero := _label("", 12, MUTED)
	column.add_child(hero)
	var bar := ProgressBar.new()
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.step = 0.0
	bar.custom_minimum_size.y = 3
	bar.add_theme_stylebox_override("background", _frame(EDGE, Color.TRANSPARENT, 0))
	column.add_child(bar)
	frame.set_meta("art", art)
	frame.set_meta("label", title)
	frame.set_meta("amount", amount)
	frame.set_meta("metric_icon", metric_icon)
	frame.set_meta("hero", hero)
	frame.set_meta("bar", bar)
	return frame


func _paint_row(frame: PanelContainer, row: Dictionary, leader: int) -> void:
	var tile: Dictionary = ArenaSim.TILES[row.tile]
	var color := CombatIcons.hero_color(row.lane)
	frame.get_meta("art").texture = GameIcons.icon(GameIcons.tile(row.tile, tile))
	frame.get_meta("label").text = tile.label
	frame.get_meta("amount").text = str(row[metric])
	var glyph: Control = frame.get_meta("metric_icon")
	glyph.set_meta("icon_id", ICONS[metric])
	glyph.accessibility_name = LABELS[metric]
	glyph.queue_redraw()
	var hero: Label = frame.get_meta("hero")
	hero.text = row.hero
	hero.add_theme_color_override("font_color", color)
	var bar: ProgressBar = frame.get_meta("bar")
	bar.add_theme_stylebox_override("fill", _frame(color, Color.TRANSPARENT, 0))
	bar.value = float(row[metric]) / leader
	frame.tooltip_text = "%s · %s\n%d %s\n%s" % [tile.label, row.hero, row[metric], LABELS[metric].to_lower(), HELP[metric]]
	frame.accessibility_name = "%s, %s, %d %s" % [tile.label, row.hero, row[metric], LABELS[metric].to_lower()]


func _label(value: String, size_points: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size_points)
	return label


func _frame(fill: Color, border: Color, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(0 if border == Color.TRANSPARENT else 1)
	box.set_corner_radius_all(5)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_content_margin(side, margin)
	return box
