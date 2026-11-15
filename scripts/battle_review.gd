extends PanelContainer

signal close_requested
signal retry_requested
signal event_selected(event: Dictionary)

const ArenaSim = preload("res://scripts/arena_sim.gd")
const FrontierRun = preload("res://scripts/frontier_run.gd")
const GameIcons = preload("res://scripts/game_icons.gd")
const INK := Color("#101820")
const PANEL := Color("#192732")
const EDGE := Color("#3c505b")
const GOLD := Color("#ecc482")
const CREAM := Color("#f3e7d1")
const MUTED := Color("#aababc")
const TEAL := Color("#9ddbd1")
const RUST := Color("#e8a28b")
const RULE_NAMES := {
	"nearest": "Nearest", "farthest": "Farthest", "lowest_hp": "Lowest HP", "highest_hp": "Highest HP",
	"self": "Self", "relay_left": "Left Guard", "relay_right": "Right Guard", "relay_regent": "Crown Regent"
}
const BOSS_CAPTIONS := {
	"tollkeeper_rallies": "The Tollkeeper rallies",
	"tollkeeper_hit": "The Tollkeeper lands a strike",
	"tollkeeper_miss": "The Tollkeeper misses a strike",
	"marshal_plate": "The Marshal raises its plating",
	"marshal_exposed": "The Marshal’s plating opens",
	"marshal_shattered": "The Marshal’s plating shatters",
	"marshal_window_missed": "The Marshal’s plating closes",
	"marshal_plate_worn": "A hit wears down the Marshal’s plating",
	"marshal_sweep_weathered": "The crew weathers Gilded Sweep",
	"marshal_sweep_hit": "Gilded Sweep damages the crew",
	"marshal_pressure_break": "Sustained hits break the plating",
	"marshal_defense_break": "Weathering Gilded Sweep breaks the plating",
	"regent_seals": "The Regent raises three seals",
	"regent_seal_struck": "A Regent seal breaks",
	"regent_shattered": "All three Regent seals break",
	"regent_window_missed": "The Regent’s seals reset",
	"crucible_rally": "The surviving Crucible Twin rallies",
	"prism_ward": "The Prism Warden raises its ward",
	"prism_exposed": "The prism ward opens",
	"prism_shattered": "The prism ward shatters",
	"prism_window_missed": "The prism ward closes",
	"colossus_forging": "Forge Sweep begins",
	"colossus_displaced": "The Colossus is displaced",
	"colossus_cracked": "The Colossus’s guard cracks",
	"colossus_shattered": "The Colossus’s guard shatters",
	"colossus_forge_sweep": "Forge Sweep releases",
	"relay_charge": "Relay Charge begins",
	"relay_interrupted": "Relay Charge is interrupted",
	"relay_discharge": "Relay Charge releases",
	"relay_marshal_charge": "Linked Charge begins",
	"relay_marshal_separated": "The Marshal’s shield breaks",
	"relay_marshal_interrupted": "Linked Charge is interrupted",
	"relay_marshal_discharge": "Linked Charge releases",
	"crown_regent_charge": "Crown Charge begins",
	"crown_link_separated": "A Guard’s link breaks",
	"crown_regent_interrupted": "Crown Charge is interrupted",
	"crown_regent_discharge": "Crown Charge releases",
	"wreckmaster_slam_windup": "Deck Slam begins",
	"wreckmaster_slam": "Deck Slam hits the party",
	"wreckmaster_slam_miss": "Deck Slam misses the party",
	"tidekeeper_slam_windup": "Breakwater Slam begins",
	"tidekeeper_unanchored": "The Tidekeeper loses its anchor",
	"tidekeeper_interrupted": "Breakwater Slam is interrupted",
	"tidekeeper_slam": "Breakwater Slam hits the party",
	"tidekeeper_slam_dodged": "The party dodges Breakwater Slam",
	"admiral_sweep_windup": "Undertow Sweep begins",
	"admiral_unanchored": "The Admiral loses its anchor",
	"admiral_reversed": "The undertow reverses",
	"admiral_interrupted": "Undertow Sweep is interrupted",
	"admiral_sweep": "Undertow Sweep hits the party",
	"admiral_sweep_dodged": "The party dodges Undertow Sweep"
}

var _events: Array[Dictionary] = []
var _visible_events: Array[Dictionary] = []
var _summary: Label
var _encounter: Label
var _filters: Dictionary = {}
var _list: ItemList
var _stamp: Label
var _title: Label
var _tile_badges: HBoxContainer
var _detail: Label
var _hint: Label
var _close: Button
var _retry: Button
var _focus_misses := false


func open(activations: Array, boss_events: Array, outcome: String, encounter := "", can_retry := false,
		show_back := true, previous_event := {}) -> void:
	if _list == null:
		_build()
	_events.clear()
	var counts := {"landed": 0, "miss": 0, "unavailable": 0}
	var preceding := {}
	for activation: Dictionary in activations:
		var entry := activation.duplicate()
		var previous: Dictionary = preceding.get(entry.lane, {})
		if entry.status == "miss" and not previous.is_empty() and previous.loop == entry.loop \
				and previous.status == "landed" and ArenaSim.is_blink_tile(previous.tile):
			entry["preceding_teleport"] = ArenaSim.TILES[previous.tile].label
		preceding[entry.lane] = entry
		_events.append(entry)
		counts[activation.status] += 1
	for event: Dictionary in boss_events:
		var entry := event.duplicate()
		entry["boss_event"] = event.tile
		entry["tile"] = event.get("source_tile", "")
		_events.append(entry)
	_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.order < b.order)
	_encounter.text = outcome.capitalize() if encounter.is_empty() else "%s  ·  %s" % [outcome.capitalize(), encounter]
	_encounter.add_theme_color_override("font_color", TEAL if outcome == "victory" else RUST)
	var results := "%d landed   ·   %d missed" % [counts.landed, counts.miss]
	if counts.unavailable > 0:
		results += "   ·   %d skipped after a hero fell" % counts.unavailable
	_summary.text = results
	_retry.visible = can_retry
	_close.visible = show_back
	_filters.boss.visible = not boss_events.is_empty()
	_filters.relics.visible = activations.any(func(event: Dictionary): return not event.get("relics", []).is_empty())
	_focus_misses = outcome == "defeat"
	show()
	_show_filter("all")
	if not previous_event.is_empty():
		for index in range(_visible_events.size()):
			if _visible_events[index].order == previous_event.order:
				_list.select(index)
				_list.ensure_current_is_visible()
				_select(index)
				break
	if not _visible_events.is_empty():
		_list.grab_focus()
	else:
		(_filters.all as Button).grab_focus()


func _build() -> void:
	name = "BattleReview"
	size_flags_vertical = SIZE_EXPAND_FILL
	custom_minimum_size.y = 285.0
	add_theme_stylebox_override("panel", _box(INK, EDGE, 12))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	column.add_child(header)
	header.add_child(_label("Battle review", 24, GOLD))
	_encounter = _label("", 15, MUTED)
	_encounter.size_flags_horizontal = SIZE_EXPAND_FILL
	_encounter.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(_encounter)

	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	column.add_child(filters)
	var group := ButtonGroup.new()
	for entry in [["all", "All events"], ["misses", "Misses"], ["boss", "Boss counter"], ["relics", "Relics"]]:
		var id: String = entry[0]
		var button := _button(entry[1], func(): _show_filter(id))
		button.name = "Review_" + id
		button.toggle_mode = true
		button.button_group = group
		filters.add_child(button)
		_filters[id] = button
	_summary = _label("", 15, MUTED)
	_summary.size_flags_horizontal = SIZE_EXPAND_FILL
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	filters.add_child(_summary)

	var body := HBoxContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	column.add_child(body)
	_list = ItemList.new()
	_list.name = "ReviewEvents"
	_list.size_flags_horizontal = SIZE_EXPAND_FILL
	_list.custom_minimum_size.y = 155.0
	_list.add_theme_stylebox_override("panel", _box(PANEL, EDGE, 6))
	_list.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, GOLD, 0))
	_list.add_theme_stylebox_override("selected", _box(Color("#2e4752"), TEAL, 0))
	_list.add_theme_stylebox_override("selected_focus", _box(Color("#385661"), TEAL, 0))
	_list.add_theme_constant_override("v_separation", 7)
	_list.item_selected.connect(_select)
	body.add_child(_list)

	var details_panel := PanelContainer.new()
	details_panel.custom_minimum_size.x = 380.0
	details_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	details_panel.size_flags_stretch_ratio = 0.70
	details_panel.add_theme_stylebox_override("panel", _box(PANEL, EDGE, 10))
	body.add_child(details_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details_panel.add_child(scroll)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 4)
	details.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(details)
	_stamp = _label("", 13, MUTED)
	_title = _label("", 21, CREAM)
	_detail = _label("", 15, CREAM)
	_hint = _label("", 14, TEAL)
	_tile_badges = HBoxContainer.new()
	_tile_badges.add_theme_constant_override("separation", 8)
	_tile_badges.hide()
	for control in [_stamp, _tile_badges, _title, _detail, _hint]:
		details.add_child(control)
	for label in [_stamp, _title, _detail, _hint]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 8)
	column.add_child(footer)
	_close = _button("Back to arena", func(): close_requested.emit())
	_close.name = "CloseBattleReview"
	footer.add_child(_close)
	_retry = _button("Retry in Practice", func(): retry_requested.emit())
	_retry.tooltip_text = "Replay this fight with the original party and inventory."
	footer.add_child(_retry)


func _show_filter(filter: String) -> void:
	for id: String in _filters:
		(_filters[id] as Button).set_pressed_no_signal(id == filter)
	_list.clear()
	_visible_events.clear()
	var preferred := -1
	for event: Dictionary in _events:
		var is_boss := event.has("boss_event")
		var is_miss: bool = not is_boss and event.status == "miss"
		var procs: Array = event.get("relics", [])
		if (filter == "misses" and not is_miss) or (filter == "boss" and not is_boss) or (filter == "relics" and procs.is_empty()):
			continue
		var index := _visible_events.size()
		_visible_events.append(event)
		var caption := _event_caption(event)
		if filter == "relics":
			var names := PackedStringArray()
			for proc: Dictionary in procs:
				names.append(FrontierRun.RELICS.get(proc.id, {}).get("label", proc.id))
			caption = ", ".join(names) + " · " + ArenaSim.TILES[event.tile].label
		_list.add_item("Loop %d · Beat %02d    %s" % [event.loop, event.beat, caption])
		_list.set_item_tooltip(index, event.get("message", event.get("reason", "")))
		_list.set_item_custom_fg_color(index, _event_color(event))
		if preferred == -1 and _focus_misses and (is_miss or event.get("stage") == "miss"):
			preferred = index
	if _visible_events.is_empty():
		_stamp.text = ""
		_tile_badges.hide()
		_title.text = "No misses" if filter == "misses" else "No combat events to review"
		_title.add_theme_color_override("font_color", CREAM)
		_detail.text = ""
		_hint.text = ""
		event_selected.emit({})
		return
	var index := maxi(preferred, 0)
	_list.select(index)
	_list.ensure_current_is_visible()
	_select(index)


func _select(index: int) -> void:
	if index < 0 or index >= _visible_events.size():
		return
	var event := _visible_events[index]
	_stamp.text = "Loop %d  ·  Beat %d  ·  %.2fs" % [event.loop, event.beat, float(event.tick) / ArenaSim.TICKS_PER_SECOND]
	_title.text = _event_caption(event)
	_title.add_theme_color_override("font_color", _event_color(event))
	_show_tile_badges(event)
	if event.has("boss_event"):
		_detail.text = event.message
		var source: Dictionary = ArenaSim.TILES.get(event.tile, {})
		_hint.text = "Triggered by %s on lane %d." % [source.label, event.lane + 1] if not source.is_empty() and event.get("lane", -1) >= 0 else ""
	else:
		_detail.text = event.reason
		for proc: Dictionary in event.get("relics", []):
			var label: String = FrontierRun.RELICS.get(proc.id, {}).get("label", proc.id)
			var source: String = proc.source
			if int(proc.get("source_beat", 0)) > 0:
				source += " on beat %d" % int(proc.source_beat)
			var effect: String = proc.get("effect", "")
			if effect.is_empty():
				effect = "+%d damage to %s" % [proc.amount, proc.target_name]
			_detail.text += "\n%s · %s" % [label, effect]
			if not source.is_empty():
				_detail.text += "\n" + source
		var rule: String = RULE_NAMES.get(event.rule, str(event.rule).capitalize())
		var target: String = event.get("target_name", "")
		if event.rule == "self":
			var support: String = ArenaSim.TILES.get(event.tile, {}).get("support", "")
			if support == "weakest":
				rule = "Lowest-health ally"
			elif support == "party":
				rule = "All living allies"
				target = ""
		_hint.text = "Targeting: %s" % rule if target.is_empty() else "Targeting: %s  ·  %s" % [rule, target]
		if event.status == "miss":
			var advice := _miss_advice(event)
			if not advice.is_empty():
				_hint.text += "\n" + advice
	event_selected.emit(event)


func _show_tile_badges(event: Dictionary) -> void:
	for badge in _tile_badges.get_children():
		_tile_badges.remove_child(badge)
		badge.queue_free()
	var tile: Dictionary = ArenaSim.TILES.get(event.tile, {})
	_tile_badges.visible = not tile.is_empty()
	if tile.is_empty():
		return
	_tile_badges.add_child(GameIcons.rarity_badge(tile))
	var class_id := GameIcons.hero_class_for_label(event.get("hero", ""))
	if not class_id.is_empty():
		_tile_badges.add_child(GameIcons.hero_badge(class_id, false))
	var enchantment: String = event.get("enchantment", "")
	if not enchantment.is_empty():
		_tile_badges.add_child(GameIcons.enchantment_badge(enchantment))


func _event_caption(event: Dictionary) -> String:
	if event.has("boss_event"):
		return BOSS_CAPTIONS.get(event.boss_event, {
			"start": "Boss counter opens", "progress": "Boss counter advances",
			"success": "Boss counter succeeds", "miss": "Boss counter missed"
		}.get(event.get("stage", ""), "Boss action"))
	var label: String = ArenaSim.TILES.get(event.tile, {}).get("label", event.tile)
	var status: String = {"landed": "Landed", "miss": "Missed", "unavailable": "Hero fallen"}.get(event.status, "")
	return "%s · %s · %s" % [event.hero, label, status]


func _event_color(event: Dictionary) -> Color:
	var status: String = event.get("status", event.get("stage", ""))
	match status:
		"miss": return RUST
		"unavailable": return MUTED
		"success": return TEAL
		"progress", "start": return GOLD
	return CREAM


func _miss_advice(event: Dictionary) -> String:
	var copy: String = event.reason.to_lower()
	if "range" in copy:
		if event.has("preceding_teleport"):
			return "Try this tile before %s or use a longer-range tile after teleporting." % event.preceding_teleport
		return "Try a later beat, another target rule, or a Pull before this tile."
	if "landing" in copy or "path" in copy:
		return "Try another beat or target to give this move room."
	return ""


func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_requested.emit()


func _box(fill: Color, edge: Color, padding: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_content_margin(side, padding)
	return box


func _label(copy: String, points: int, color: Color) -> Label:
	var label := Label.new()
	label.text = copy
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", color)
	return label


func _button(copy: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = copy
	button.custom_minimum_size.y = 32.0
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	return button
