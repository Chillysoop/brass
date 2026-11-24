extends Control

class SequenceTileButton extends Button:
	var preview: Callable

	func _make_custom_tooltip(_for_text: String) -> Object:
		return preview.call()


const ArenaSim = preload("res://scripts/arena_sim.gd")
const ArenaView = preload("res://scripts/arena_view.gd")
const StorageScreen = preload("res://scripts/storage_screen.gd")
const ForgeScreen = preload("res://scripts/forge_screen.gd")
const CombatMeter = preload("res://scripts/combat_meter.gd")
const GameIcons = preload("res://scripts/game_icons.gd")
const CombatIcons = preload("res://scripts/combat_icons.gd")
const TilePacking = preload("res://scripts/tile_packing.gd")
const TileEnchantments = preload("res://scripts/tile_enchantments.gd")
const TileKeywords = preload("res://scripts/tile_keywords.gd")
const FrontierRun = preload("res://scripts/frontier_run.gd")
const FrontierScreen = preload("res://scripts/frontier_screen.gd")
const ArsenalTiles = preload("res://scripts/arsenal_tiles.gd")
const ClassExpansionTiles = preload("res://scripts/class_expansion_tiles.gd")
const ClassDecks = preload("res://scripts/class_decks.gd")
const ClassRelics = preload("res://scripts/class_relics.gd")
const UniversalTileUpgrades = preload("res://scripts/universal_tile_upgrades.gd")
const PRACTICE_TILES := ["pull", "bash", "guard", "shot", "blink", "slam"]
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
	"highest_hp": "Highest HP", "self": "Self",
	"relay_left": "Left Guard", "relay_right": "Right Guard", "relay_regent": "Crown Regent"
}
const TARGET_ICONS := {
	"nearest": "←", "farthest": "→", "highest_hp": "♥", "lowest_hp": "♡",
	"self": "◆", "relay_left": "L", "relay_right": "R", "relay_regent": "♛"
}

var sim = ArenaSim.new()
var run = FrontierRun.new()
var campaign := false
var encounter_setup := false
var camp_forge := false
var frontier_screen
var return_button: Button
var reset_button: Button
var camp_button: Button
var discard_dialog: ConfirmationDialog
var lanes: Array = []
var defaults: Array[String] = []
var fixture := "duo"
var speed := 1
var state := "setup"
var selected: Dictionary = {}
var storage_rows: Array = []
var suppressed_combines: Dictionary = {}
var pending_forge: Dictionary = {}
var decline_dialog: ConfirmationDialog
var arena_screen: MarginContainer
var storage_screen: Control
var storage_popup_layer: Control
var forge_screen: Control
var storage_button: Button
var enchantment_button: Button
var relic_strip: HBoxContainer
var relic_badges: Dictionary = {}
var relic_pulses: Dictionary = {}
var lane_stack: VBoxContainer
var lane_scroller: ScrollContainer
var battle_layout_pending := false
var tile_layout_columns: Array[int] = []
var palette: HBoxContainer
var arsenal_button: Button
var arsenal_panel: PanelContainer
var arena
var battle_stage: HBoxContainer
var combat_sidebar: VBoxContainer
var relic_focus_layer: Control
var save_title_button: Button
var battle_heading: Label
var fixture_picker: OptionButton
var speed_controls: HBoxContainer
var speed_buttons: Array[Button] = []
var action: Button
var combat_meter: CombatMeter
var combat_meter_toggle: Button
var retry_button: Button
var combat_meter_open := false
var battle_name := ""
var battle_snapshot: Dictionary = {}
var retry_options: Dictionary = {}
var retry_result: Dictionary = {}
var combat_save_pending := false
var showing_rewards := false
var result_animation: Tween
var result_text: Label
var result_banner: PanelContainer
var lane_health: Array[ProgressBar] = []
var lane_health_labels: Array[Label] = []
var setup_hint: Label
var playheads: Array[ColorRect] = []
var tile_cards: Array[Dictionary] = []
var edge_tick := 0
var edge_tiles: Dictionary = {}
const TILE_PULSE_TICKS := 24
var drag_board: Control
var drag_overlay: Control
var drag_pointer := Vector2.ZERO
var drag_preview_key: Array = []
var faded_cards: Dictionary = {}

func _ready() -> void:
	theme = _theme()
	_build()
	_load_fixture("duo")
	run.load_active_save_slot()
	run_menu()

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
	arena_screen = margin
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
	save_title_button = _button("Save & title", run_save_title)
	save_title_button.name = "SaveTitle"
	header.add_child(save_title_button)
	battle_heading = _label("BRASS & AETHER", 26, GOLD)
	battle_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(battle_heading)
	fixture_picker = OptionButton.new()
	fixture_picker.add_item("Two heroes")
	fixture_picker.add_item("Solo hero")
	fixture_picker.add_item("Forge practice")
	fixture_picker.add_item("Blink forge practice")
	fixture_picker.add_item("Shot and Guard practice")
	fixture_picker.item_selected.connect(func(index: int): _load_fixture(["duo", "solo", "forge", "blink_forge", "build_forge"][index]))
	_build_speed_controls(header)
	storage_button = _button("Tile storage", _toggle_storage)
	storage_button.icon = StorageScreen.ICON
	storage_button.add_theme_constant_override("icon_max_width", 26)
	storage_button.tooltip_text = "Drag tiles between storage and timelines."
	reset_button = _button("Reset fight", _reset_fight)
	return_button = _button("Title", _leave_arena)
	header.add_child(return_button)
	header.move_child(return_button, 0)
	combat_meter_toggle = _button("Combat stats", _toggle_combat_meter)
	combat_meter_toggle.name = "CombatStatsToggle"
	combat_meter_toggle.toggle_mode = true
	combat_meter_toggle.tooltip_text = "Show or hide tile totals for damage, assists, kills, and healing."
	GameIcons.decorate(combat_meter_toggle, "review", 18)
	header.add_child(combat_meter_toggle)
	retry_button = _button("Retry in Practice", _retry_in_practice)
	retry_button.name = "RetryInPractice"
	retry_button.tooltip_text = "Replay this fight with the original party, health, and equipment."
	action = _button("Start battle", _action)
	action.custom_minimum_size.x = 130
	action.add_theme_stylebox_override("normal", _box(Color("#59462f"), GOLD))
	header.add_child(action)

	battle_stage = HBoxContainer.new()
	battle_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_stage.add_theme_constant_override("separation", 12)
	stack.add_child(battle_stage)
	arena = ArenaView.new()
	arena.name = "Battlefield"
	arena.custom_minimum_size.y = 290
	arena.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_stage.add_child(arena)
	combat_sidebar = VBoxContainer.new()
	combat_sidebar.name = "CombatSidebar"
	combat_sidebar.custom_minimum_size.x = 245
	battle_stage.add_child(combat_sidebar)
	_build_result_banner()
	combat_meter = CombatMeter.new()
	combat_meter.name = "CombatMeter"
	combat_meter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	combat_sidebar.add_child(combat_meter)
	var sequence_bar := HBoxContainer.new()
	stack.add_child(sequence_bar)
	relic_strip = HBoxContainer.new()
	relic_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	relic_strip.add_theme_constant_override("separation", 5)
	sequence_bar.add_child(relic_strip)
	enchantment_button = _button("", _toggle_storage)
	enchantment_button.name = "OpenEnchantment"
	sequence_bar.add_child(enchantment_button)
	sequence_bar.add_child(storage_button)
	lane_stack = VBoxContainer.new()
	lane_stack.add_theme_constant_override("separation", 5)
	lane_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lane_scroller = ScrollContainer.new()
	lane_scroller.name = "PartySequences"
	lane_scroller.custom_minimum_size.y = 69
	lane_scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lane_scroller.follow_focus = true
	stack.add_child(lane_scroller)
	lane_scroller.add_child(lane_stack)
	stack.resized.connect(_queue_battle_layout)
	stack.minimum_size_changed.connect(_queue_battle_layout)
	lane_stack.minimum_size_changed.connect(_queue_battle_layout)
	combat_sidebar.minimum_size_changed.connect(_queue_battle_layout)
	combat_sidebar.visibility_changed.connect(_queue_battle_layout)
	arena_screen.visibility_changed.connect(_queue_battle_layout)
	var tray := HBoxContainer.new()
	tray.alignment = BoxContainer.ALIGNMENT_END
	tray.add_theme_constant_override("separation", 6)
	stack.add_child(tray)
	palette = HBoxContainer.new()
	palette.add_theme_constant_override("separation", 5)
	palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tray.add_child(palette)
	arsenal_button = _button("Combat tiles", _toggle_practice_arsenal)
	arsenal_button.name = "PracticeArsenal"
	GameIcons.decorate(arsenal_button, "battle", 15)
	arsenal_button.tooltip_text = "Browse and equip combat tiles in Arena Practice."
	tray.add_child(arsenal_button)
	tray.add_child(fixture_picker)
	tray.add_child(retry_button)
	tray.add_child(reset_button)
	camp_button = _button("Forge selected", _open_camp_forge)
	camp_button.name = "ForgeSelected"
	tray.add_child(camp_button)
	setup_hint = _label("", 14, MUTED)
	setup_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(setup_hint)
	storage_popup_layer = Control.new()
	storage_popup_layer.name = "StoragePopupLayer"
	storage_popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(storage_popup_layer)
	storage_screen = StorageScreen.new()
	storage_popup_layer.add_child(storage_screen)
	storage_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	storage_screen.configure(self)
	storage_screen.hide()
	storage_screen.visibility_changed.connect(_queue_battle_layout)
	storage_screen._frame.minimum_size_changed.connect(_queue_battle_layout)
	relic_focus_layer = Control.new()
	relic_focus_layer.name = "RelicChoiceFocus"
	relic_focus_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(relic_focus_layer)
	relic_focus_layer.hide()
	battle_stage.item_rect_changed.connect(_fit_relic_focus)
	resized.connect(_fit_relic_focus)
	_build_practice_arsenal()
	forge_screen = ForgeScreen.new()
	add_child(forge_screen)
	forge_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	forge_screen.configure(self)
	forge_screen.hide()
	decline_dialog = ConfirmationDialog.new()
	decline_dialog.title = "Decline combine?"
	decline_dialog.ok_button_text = "Decline combine"
	add_child(decline_dialog)
	discard_dialog = ConfirmationDialog.new()
	discard_dialog.title = "Discard tile?"
	discard_dialog.ok_button_text = "Discard"
	discard_dialog.confirmed.connect(_discard_selected)
	add_child(discard_dialog)
	frontier_screen = FrontierScreen.new()
	add_child(frontier_screen)
	frontier_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frontier_screen.configure(self)
	_queue_battle_layout()


func _queue_battle_layout() -> void:
	if is_instance_valid(storage_popup_layer):
		storage_popup_layer.visible = arena_screen.visible
	if battle_layout_pending:
		return
	battle_layout_pending = true
	_fit_battle_layout.call_deferred()


func _fit_relic_focus() -> void:
	if not is_instance_valid(relic_focus_layer) or not is_instance_valid(battle_stage):
		return
	var bounds := arena_screen.get_global_rect()
	var left := float(arena_screen.get_theme_constant("margin_left"))
	var right := float(arena_screen.get_theme_constant("margin_right"))
	var bottom := float(arena_screen.get_theme_constant("margin_bottom"))
	var top := battle_stage.global_position.y
	relic_focus_layer.global_position = Vector2(bounds.position.x + left, top)
	relic_focus_layer.size = Vector2(maxf(0.0, bounds.size.x - left - right), maxf(0.0, bounds.end.y - bottom - top))


func _fit_battle_layout() -> void:
	battle_layout_pending = false
	if not is_instance_valid(lane_scroller) or not arena_screen.is_visible_in_tree():
		return
	if tile_layout_columns != _tile_layout_columns():
		_rebuild_loadout()
		_queue_battle_layout()
		return
	var stack := battle_stage.get_parent() as VBoxContainer
	# Preserve tile and targeting sizes. Give the arena only the height left after
	# the party and header, scrolling the party only when even a short arena cannot fit.
	var chrome := stack.get_combined_minimum_size().y - battle_stage.get_combined_minimum_size().y \
		- lane_scroller.get_combined_minimum_size().y
	var content_height := size.y - arena_screen.get_theme_constant("margin_top") - arena_screen.get_theme_constant("margin_bottom")
	var available := maxf(0.0, content_height - chrome)
	var stage_minimum := maxf(160.0, combat_sidebar.get_combined_minimum_size().y if combat_sidebar.visible else 0.0)
	if storage_screen.visible and not storage_screen._docked:
		var storage_chrome: float = storage_screen._frame.get_combined_minimum_size().y - storage_screen._grid.get_combined_minimum_size().y
		stage_minimum = maxf(stage_minimum, storage_chrome + storage_screen._tile_row_size.y + 4.0)
	var lanes_height := minf(lane_stack.get_combined_minimum_size().y, maxf(69.0, available - stage_minimum))
	var arena_height := minf(290.0, maxf(stage_minimum, available - lanes_height))
	if not is_equal_approx(lane_scroller.custom_minimum_size.y, lanes_height):
		lane_scroller.custom_minimum_size.y = lanes_height
	if not is_equal_approx(arena.custom_minimum_size.y, arena_height):
		arena.custom_minimum_size.y = arena_height
	storage_popup_layer.global_position = battle_stage.global_position
	storage_popup_layer.size = battle_stage.size

func _build_speed_controls(header: HBoxContainer) -> void:
	speed_controls = HBoxContainer.new()
	speed_controls.name = "CombatSpeed"
	speed_controls.add_theme_constant_override("separation", 3)
	header.add_child(speed_controls)
	var group := ButtonGroup.new()
	for multiplier in range(1, 4):
		var button := _button("", func(): speed = multiplier)
		button.name = "CombatSpeed%dx" % multiplier
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(36, 32)
		button.tooltip_text = "%d× combat speed" % multiplier
		button.accessibility_name = button.tooltip_text
		button.add_theme_stylebox_override("pressed", _box(Color("#59462f"), GOLD))
		button.add_theme_stylebox_override("hover_pressed", _box(Color("#635237"), GOLD))
		speed_controls.add_child(button)
		var glyph := Control.new()
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(glyph)
		glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		glyph.draw.connect(_draw_speed_icon.bind(glyph, multiplier))
		glyph.resized.connect(glyph.queue_redraw)
		speed_buttons.append(button)
	speed_buttons[speed - 1].set_pressed_no_signal(true)


func _draw_speed_icon(glyph: Control, multiplier: int) -> void:
	const TRIANGLE_SIZE := Vector2(7, 10)
	const SPACING := 9.0
	var row_width := TRIANGLE_SIZE.x + (multiplier - 1) * SPACING
	var first := (glyph.size - Vector2(row_width, TRIANGLE_SIZE.y)) / 2.0
	for index in range(multiplier):
		var point := first + Vector2(index * SPACING, 0)
		glyph.draw_colored_polygon(PackedVector2Array([
			point, point + Vector2(TRIANGLE_SIZE.x, TRIANGLE_SIZE.y * 0.5), point + Vector2(0, TRIANGLE_SIZE.y)
		]), CREAM)


func _build_result_banner() -> void:
	var positioner := CenterContainer.new()
	positioner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena.add_child(positioner)
	positioner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_banner = PanelContainer.new()
	result_banner.name = "BattleResultBanner"
	result_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_banner.custom_minimum_size = Vector2(290, 76)
	positioner.add_child(result_banner)
	result_text = _label("", 43, GOLD)
	result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_banner.add_child(result_text)
	result_banner.hide()

func _animate_result() -> void:
	var won: bool = sim.outcome == "victory"
	var accent := GOLD if won else RUST
	var frame := _box(Color("#202a29") if won else Color("#322224"), accent, 8)
	frame.set_border_width_all(2)
	frame.shadow_color = Color(0.04, 0.05, 0.04, 0.6)
	frame.shadow_size = 4
	result_banner.add_theme_stylebox_override("panel", frame)
	result_text.text = "VICTORY" if won else "DEFEAT"
	result_text.add_theme_color_override("font_color", accent)
	result_banner.pivot_offset = result_banner.custom_minimum_size * 0.5
	result_banner.modulate.a = 0.0
	result_banner.scale = Vector2(0.9, 0.9)
	result_banner.show()
	result_animation = create_tween()
	result_animation.tween_property(result_banner, "modulate:a", 1.0, 0.15)
	result_animation.parallel().tween_property(result_banner, "scale", Vector2.ONE, 0.21).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	result_animation.tween_interval(0.34)
	result_animation.tween_property(result_banner, "modulate:a", 0.0, 0.15)
	result_animation.tween_callback(_complete_result_animation)

func _hide_result_animation() -> void:
	if result_animation != null:
		result_animation.kill()
		result_animation = null
	result_banner.hide()

func _complete_result_animation() -> void:
	_hide_result_animation()
	if campaign and state == "finished" and not combat_save_pending:
		if sim.outcome == "victory" and run.has_combat_reward():
			run_return()
	_update_controls()

func _teaching_timeline() -> bool:
	return campaign and encounter_setup and run.should_teach_timeline()

func _load_fixture(next_fixture: String) -> void:
	fixture = "solo" if next_fixture == "solo" else "duo"
	lanes = ArenaSim.default_lanes(fixture)
	storage_rows = [
		[_entry("bash", 0, "nearest"), _entry("bash", 2, "nearest"), _entry("bash", 4, "nearest")],
		[_entry("slam", 0, "nearest"), _entry("pull", 5, "farthest")],
		[_entry("blink", 2, "nearest")]
	]
	if next_fixture == "forge":
		lanes[1] = [_entry("sunwall", 0, "nearest"), _entry("sunwall", 4, "nearest"), _entry("sunwall", 8, "nearest")]
	elif next_fixture == "blink_forge":
		lanes[0] = [_entry("blink", 0, "nearest"), _entry("blink", 3, "nearest"), _entry("blink", 6, "nearest")]
		lanes[1] = [_entry("prism_stride", 0, "nearest"), _entry("prism_stride", 4, "nearest"), _entry("prism_stride", 8, "nearest")]
	elif next_fixture == "build_forge":
		lanes[0] = [_entry("shot", 0, "farthest"), _entry("shot", 2, "farthest"), _entry("shot", 4, "farthest")]
		lanes[1] = [_entry("guard", 0, "self"), _entry("guard", 2, "self"), _entry("guard", 4, "self")]
	suppressed_combines.clear()
	defaults.clear()
	for _lane_index in range(lanes.size()):
		defaults.append("nearest")
	_reset_fight()

func _entry(id: String, start: int, target: String) -> Dictionary:
	return {"id": id, "start": start, "target": target}

func _reset_fight() -> void:
	_hide_result_animation()
	arsenal_panel.hide()
	state = "setup"
	combat_save_pending = false
	edge_tick = 0
	edge_tiles.clear()
	combat_meter.reset()
	selected.clear()
	pending_forge.clear()
	_start_sim()
	arena.reset_view(sim.units, lanes, sim.pending_reinforcement())
	_rebuild_loadout()
	_update_controls()

func _action() -> void:
	match state:
		"setup":
			if _editing_camp_forge():
				_resume_camp_forge()
				return
			if campaign and not encounter_setup:
				_leave_arena()
				return
			if (campaign or not retry_options.is_empty()) and not _party_has_tiles():
				setup_hint.text = "Equip a tile on a living hero before starting the battle."
				return
			selected.clear()
			storage_screen.hide()
			arsenal_panel.hide()
			edge_tick = 0
			edge_tiles.clear()
			combat_meter.reset()
			if campaign:
				battle_name = FrontierScreen.battle_title(run.data.get("node", {}))
				battle_snapshot = {
					"options": run.encounter(), "lanes": lanes.duplicate(true),
					"storage": storage_rows.duplicate(true), "defaults": defaults.duplicate(),
					"suppressed": suppressed_combines.duplicate()
				}
			elif retry_options.is_empty():
				battle_name = "Arena Practice"
			_start_sim()
			arena.reset_view(sim.units, lanes, sim.pending_reinforcement())
			state = "running"
			_rebuild_loadout()
		"running": state = "paused"
		"paused": state = "running"
		"finished":
			if campaign:
				if combat_save_pending:
					_save_finished_battle()
					_update_controls()
				else:
					run_return()
				return
			_reset_fight()
	_update_controls()

func _physics_process(_delta: float) -> void:
	if state != "running":
		return
	edge_tick = 0
	var first_activation: int = sim.activations.size()
	for step_index in range(speed):
		var events: Array = sim.step()
		combat_meter.record(events, sim.units)
		# At higher speeds, show the boundary for the frame even if a later step passes it.
		if sim.tick % ArenaSim.TICKS_PER_BEAT == 0:
			edge_tick = sim.tick
		arena.present(sim.units, events, sim.tick, sim.visual_cues, speed, sim.pending_reinforcement())
		for event: Dictionary in events:
			if event.kind == "relic_proc":
				_pulse_relic(event.tile)
		if not sim.outcome.is_empty():
			state = "finished"
			if campaign:
				_save_finished_battle()
			else:
				_animate_result()
			break
	for index in range(first_activation, sim.activations.size()):
		var activation: Dictionary = sim.activations[index]
		if activation.status != "unavailable":
			edge_tiles[Vector2i(activation.lane, activation.start)] = activation.tick
	_update_controls()

func _save_finished_battle() -> void:
	var remaining_hp: Array[int] = []
	for index in range(lanes.size()):
		remaining_hp.append(sim.units[index].hp)
	combat_save_pending = not run.finish_combat(sim.outcome == "victory", remaining_hp, combat_meter.snapshot())
	if not combat_save_pending:
		_animate_result()

func _update_controls() -> void:
	arena.playback_paused = state == "paused"
	var animating := result_animation != null
	action.text = {"setup": "Start battle", "running": "Pause", "paused": "Resume", "finished": "Edit loadout"}[state]
	if campaign and (state == "finished" or not encounter_setup):
		if combat_save_pending:
			action.text = "Retry save"
		else:
			action.text = "Back to smith" if _traveling_smith_forge() else "Continue"
	if _editing_camp_forge():
		action.text = "Back to forge"
	if campaign and state == "finished" and sim.outcome == "defeat" and not combat_save_pending:
		action.text = "See results"
	action.tooltip_text = run.save_error if combat_save_pending else ""
	action.visible = not (campaign and animating) and not showing_rewards
	save_title_button.visible = campaign and not combat_save_pending and not animating and state in ["setup", "finished"]
	var battle_title := FrontierScreen.battle_title(run.data.get("node", {}))
	battle_heading.text = battle_title if campaign and (encounter_setup or showing_rewards) and not battle_title.is_empty() else "BRASS & AETHER"
	combat_meter_toggle.visible = (not campaign or encounter_setup or (showing_rewards and run.has_combat_reward())) \
		and not relic_focus_layer.visible
	combat_meter_toggle.set_pressed_no_signal(combat_meter_open)
	combat_meter.visible = combat_meter_toggle.visible and combat_meter_open
	combat_sidebar.visible = combat_meter.visible or _placing_tile_reward()
	reset_button.visible = not campaign
	fixture_picker.visible = not campaign and retry_options.is_empty()
	return_button.visible = not campaign
	return_button.text = "Back to battle result" if not retry_result.is_empty() else "Title"
	camp_button.visible = camp_forge and not _editing_camp_forge() and not storage_screen.visible
	fixture_picker.disabled = state != "setup"
	storage_button.disabled = not _can_edit_loadout()
	storage_button.visible = not _placing_tile_reward()
	var stored_tiles := 0
	for stored_row: Array in storage_rows:
		stored_tiles += stored_row.size()
	storage_button.text = "Tile storage · %d" % stored_tiles if stored_tiles > 0 else "Tile storage"
	storage_button.add_theme_color_override("font_color", GOLD)
	storage_button.tooltip_text = "Shared tile storage · %d tiles. Drag tiles between this stash and your sequence." % stored_tiles
	var enchantments := _held_enchantments()
	enchantment_button.visible = state == "setup" and not enchantments.is_empty()
	if enchantment_button.visible:
		enchantment_button.text = "Enchantments"
		enchantment_button.tooltip_text = "Equip, move, or remove enchantments in Tile storage."
	speed_controls.visible = not campaign or (encounter_setup and state != "finished")
	var speed_button := speed_buttons[speed - 1]
	if not speed_button.button_pressed:
		speed_button.set_pressed_no_signal(true)
	retry_button.visible = campaign and state == "finished" and not combat_save_pending \
		and not animating and not battle_snapshot.is_empty() and not str(sim.outcome).is_empty()
	palette.visible = state == "setup" and not campaign and retry_options.is_empty()
	arsenal_button.visible = palette.visible
	palette.get_parent().visible = not campaign or camp_forge or retry_button.visible
	setup_hint.visible = state == "setup"
	var elapsed: int = sim.tick
	var teaching := _teaching_timeline()
	var display_tick := edge_tick if edge_tick > 0 else elapsed
	for lane_index in range(lane_health.size()):
		var hero: Dictionary = sim.units[lane_index]
		var health := lane_health[lane_index]
		var health_label := lane_health_labels[lane_index]
		var fallen: bool = hero.hp <= 0
		health.value = hero.hp
		health.visible = not fallen
		health.tooltip_text = "%s · %d / %d HP" % [hero.name, hero.hp, hero.max_hp]
		health_label.text = "Fallen" if fallen else "%d/%d" % [hero.hp, hero.max_hp]
		health_label.add_theme_color_override("font_color", RUST if fallen else MUTED)
	for head in playheads:
		head.visible = state != "setup"
		var fraction := ArenaSim.loop_progress(display_tick)
		head.anchor_left = fraction
		head.anchor_right = fraction
		head.offset_left = -1
		head.offset_right = 1
	for lane_index in range(tile_cards.size()):
		var fallen: bool = sim.units[lane_index].hp <= 0
		for start: int in tile_cards[lane_index]:
			var card: Control = tile_cards[lane_index][start]
			var marker: Control = card.get_meta("timing_marker")
			var age := elapsed - int(edge_tiles.get(Vector2i(lane_index, start), -60))
			var fired := age < TILE_PULSE_TICKS and (state in ["running", "paused"] or animating)
			var teaching_edge: bool = teaching and state == "setup" and lane_index == 0 and start == int(lanes[0][0].start)
			marker.visible = fired or teaching_edge
			marker.modulate.a = 1.0 - smoothstep(0.0, float(TILE_PULSE_TICKS), float(age)) if fired else 1.0
			card.modulate.a = 0.40 if fallen else 1.0
			var back: Control = card.get_meta("tile_back")
			back.modulate.a = card.modulate.a

func _toggle_combat_meter() -> void:
	combat_meter_open = combat_meter_toggle.button_pressed
	_update_controls()


func _retry_in_practice() -> void:
	if not campaign or state != "finished" or combat_save_pending or battle_snapshot.is_empty():
		return
	retry_result = {"sim": sim, "meter": combat_meter.snapshot(), "encounter_setup": encounter_setup}
	var practice := battle_snapshot.duplicate(true)
	retry_options = practice.options
	lanes = practice.lanes
	storage_rows = practice.storage
	defaults.assign(practice.defaults)
	suppressed_combines = practice.suppressed
	sim = ArenaSim.new()
	frontier_screen.hide()
	showing_rewards = false
	campaign = false
	_reset_fight()

func _return_to_battle_result() -> void:
	var original := retry_result
	retry_result = {}
	retry_options = {}
	_hide_result_animation()
	storage_screen.hide()
	selected.clear()
	edge_tiles.clear()
	edge_tick = 0
	campaign = true
	encounter_setup = original.encounter_setup
	state = "finished"
	sim = original.sim
	combat_meter.restore(original.meter)
	_read_run_loadout()
	arena.location = run.data.get("location", "brass")
	arena.reset_view(sim.units, lanes)
	if run.has_combat_reward():
		_show_rewards()
	else:
		_rebuild_loadout()
		_update_controls()

func _party_has_tiles() -> bool:
	for index in range(lanes.size()):
		if int(sim.units[index].hp) > 0 and not lanes[index].is_empty():
			return true
	return false

func _rebuild_loadout() -> void:
	_clear_drag_preview()
	tile_layout_columns = _tile_layout_columns()
	for child in lane_stack.get_children():
		lane_stack.remove_child(child)
		child.queue_free()
	for child in palette.get_children():
		palette.remove_child(child)
		child.queue_free()
	playheads.clear()
	tile_cards.clear()
	lane_health.clear()
	lane_health_labels.clear()
	_rebuild_relic_strip()
	var tile_row_height := _tile_row_height()
	for lane_index in range(lanes.size()):
		_build_lane(lane_index, tile_row_height)
	for id: String in ([] if campaign else PRACTICE_TILES):
		var tile: Dictionary = ArenaSim.TILES[id]
		var payload := {"id": id}
		var button := _button("%s · %d" % [tile.label, tile.width], func(): _select(payload))
		GameIcons.decorate(button, GameIcons.tile(id, tile), 16)
		button.tooltip_text = _practice_tile_tooltip(id, tile)
		button.disabled = state != "setup"
		var active: bool = selected.get("id") == id and not selected.has("lane")
		_style_tile_button(button, tile, Color("#263642"), active)
		_drag_source(button, payload)
		palette.add_child(button)
	if _editing_camp_forge():
		var upgrade: String = pending_forge.layout_upgrade
		var label: String = ArenaSim.TILES[upgrade].label
		var source_name: String = ArenaSim.TILES[pending_forge.camp.id].label
		setup_hint.text = "%s fits. Select Back to forge to apply it." % label if forge_can_fit(upgrade) \
			else "Make room after %s for %s, then select Back to forge." % [source_name, label]
	elif camp_forge:
		var blocker: String = run.camp_forge_blocker(selected)
		camp_button.disabled = not blocker.is_empty()
		camp_button.tooltip_text = blocker
		setup_hint.text = "Click any tile in your sequence or storage to upgrade it one tier. No matching copies needed." if selected.is_empty() else blocker
	elif campaign and not run.recovered_starter.is_empty():
		setup_hint.text = "%s was restored to your timeline so you can continue." % ArenaSim.TILES[run.recovered_starter].label
	elif state == "setup" and _teaching_timeline() and not lanes[0].is_empty():
		var starter: Dictionary = lanes[0][0]
		var tile: Dictionary = ArenaSim.TILES[starter.id]
		setup_hint.text = "Drag %s to change its timing. Tiles fire at their right edge." % tile.label
	else:
		setup_hint.text = "Drag tiles to slide neighbors aside. Tiles fire at their right edge."
	if storage_screen.visible:
		_render_storage()
	_queue_battle_layout()


func _build_practice_arsenal() -> void:
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arsenal_panel = PanelContainer.new()
	arsenal_panel.name = "ArsenalTilePicker"
	arsenal_panel.custom_minimum_size.x = 760
	arsenal_panel.add_theme_stylebox_override("panel", _box(PANEL, GOLD, 10))
	center.add_child(arsenal_panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 5)
	arsenal_panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var heading := _label("Combat tiles", 21, GOLD)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var collection := OptionButton.new()
	collection.name = "PracticeTileCollection"
	collection.add_item("Arsenal")
	collection.add_item("Class expansion")
	collection.add_item("Signature upgrades")
	header.add_child(collection)
	header.add_child(_button("Close", arsenal_panel.hide))
	var pages: Array[VBoxContainer] = []
	for pools: Array in [[ArsenalTiles.COMMON_IDS, ArsenalTiles.UNCOMMON_IDS],
			[ClassExpansionTiles.COMMON_IDS, ClassExpansionTiles.UNCOMMON_IDS]]:
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 5)
		page.visible = pages.is_empty()
		pages.append(page)
		layout.add_child(page)
		_add_practice_tiles(page, pools)
	var signature_page := VBoxContainer.new()
	signature_page.hide()
	pages.append(signature_page)
	layout.add_child(signature_page)
	var signature_scroll := ScrollContainer.new()
	signature_scroll.name = "PracticeSignatureScroll"
	signature_scroll.custom_minimum_size = Vector2(1070, 300)
	signature_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	signature_scroll.follow_focus = true
	signature_page.add_child(signature_scroll)
	var signatures := VBoxContainer.new()
	signatures.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	signatures.add_theme_constant_override("separation", 5)
	signature_scroll.add_child(signatures)
	for hero_id: String in FrontierRun.HEROES:
		var signature := ClassDecks.signature(hero_id)
		if not UniversalTileUpgrades.AUTHORED_SIGNATURES.has(signature):
			continue
		signatures.add_child(_label(FrontierRun.HEROES[hero_id].label, 15, GOLD))
		var tiers := TilePacking.forge_tiers(signature)
		_add_practice_tiles(signatures, [tiers[2] + tiers[3] + tiers[4]], 6)
	collection.item_selected.connect(func(index: int):
		for page_index in range(pages.size()):
			pages[page_index].visible = page_index == index
	)
	arsenal_panel.hide()


func _add_practice_tiles(page: VBoxContainer, pools: Array, columns := 4) -> void:
	for ids: Array in pools:
		if ids != pools.front():
			page.add_child(HSeparator.new())
		var grid := GridContainer.new()
		grid.columns = columns
		grid.add_theme_constant_override("h_separation", 5)
		grid.add_theme_constant_override("v_separation", 4)
		page.add_child(grid)
		for id: String in ids:
			var tile: Dictionary = ArenaSim.TILES[id]
			var payload := {"id": id}
			var button := _button("%s · %d" % [tile.label, tile.width], func():
				if selected == payload:
					selected.clear()
				_select(payload)
				arsenal_panel.hide()
				if selected.get("id") == id:
					setup_hint.text = "%s · %s" % [tile.label, tile.description]
			)
			button.name = "PracticeTile_" + id
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			GameIcons.decorate(button, GameIcons.tile(id, tile), 17)
			var compact := columns > 4
			if compact:
				button.add_theme_font_size_override("font_size", 13)
			_style_tile_button(button, tile, Color("#263642"), false, 20 if compact else 14)
			_add_tile_badges(button, tile, GameIcons.tile_origin(id, tile))
			button.tooltip_text = _practice_tile_tooltip(id, tile)
			_drag_source(button, payload)
			grid.add_child(button)


func _practice_tile_tooltip(id: String, tile: Dictionary) -> String:
	var origin := GameIcons.tile_origin(id, tile)
	var signature := "\n%s signature" % GameIcons.hero_label(origin) if not origin.is_empty() else ""
	var stats := GameIcons.tile_stats(tile)
	var tooltip := "%s · %s · %s%s\n%s" % [tile.label, GameIcons.rarity_name(tile), stats, signature, tile.description]
	return TileKeywords.with_definitions(tooltip, stats + "\n" + tile.description)


func _toggle_practice_arsenal() -> void:
	if arsenal_panel.visible:
		arsenal_panel.hide()
	else:
		if storage_screen.visible:
			storage_close()
		arsenal_panel.show()
		var collection := arsenal_panel.find_child("PracticeTileCollection", true, false) as OptionButton
		collection.grab_focus()


func _rebuild_relic_strip() -> void:
	for child in relic_strip.get_children():
		relic_strip.remove_child(child)
		child.queue_free()
	relic_pulses.clear()
	relic_badges.clear()
	var options: Dictionary = run.data if campaign else retry_options
	var equipped: Array = options.get("relics", [])
	var heroes: Array = options.get("heroes", [])
	for id: String in equipped:
		var relic: Dictionary = FrontierRun.RELICS.get(id, {})
		if relic.is_empty():
			continue
		var badge := TextureRect.new()
		badge.texture = GameIcons.icon(GameIcons.relic(id))
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.custom_minimum_size = Vector2(28, 28)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_STOP
		var owner := ClassRelics.owner(id)
		var label: String = relic.label
		if not owner.is_empty():
			label += " · %s only" % GameIcons.hero_label(owner)
			badge.name = "ClassRelicStatus_" + id
			var lane := heroes.find_custom(func(hero: Dictionary): return hero.get("id", hero.get("hero")) == owner)
			if lane >= 0:
				var mark := ColorRect.new()
				mark.color = CombatIcons.hero_color(lane)
				mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
				badge.add_child(mark)
				mark.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
				mark.offset_left = 4
				mark.offset_right = -4
				mark.offset_top = -2
		badge.tooltip_text = "%s\n%s" % [label, relic.description]
		badge.accessibility_name = label
		relic_strip.add_child(badge)
		relic_badges[id] = badge


func _pulse_relic(id: String) -> void:
	var badge: TextureRect = relic_badges.get(id)
	if not is_instance_valid(badge):
		return
	if relic_pulses.has(id) and relic_pulses[id].is_running():
		relic_pulses[id].kill()
	badge.self_modulate = Color("#ffca70")
	var pulse := badge.create_tween()
	pulse.tween_property(badge, "self_modulate", Color.WHITE, 0.5)
	relic_pulses[id] = pulse

func _tile_row_height() -> int:
	var target_rows := 1
	for lane: Array in lanes:
		for tile: Dictionary in lane:
			target_rows = maxi(target_rows, ceili(float(sim.target_rules(tile.id).size()) / _tile_target_columns(ArenaSim.TILES[tile.id].width)))
	return 69 + (target_rows - 1) * 20


func _tile_layout_columns() -> Array[int]:
	var columns: Array[int] = []
	for width in range(1, ArenaSim.BEATS + 1):
		columns.append(_tile_target_columns(width))
	return columns


func _tile_target_columns(width: int) -> int:
	var scrollbar := lane_scroller.get_v_scroll_bar()
	var scrollbar_width := scrollbar.size.x if scrollbar.visible else 0.0
	var board_width := arena_screen.size.x - arena_screen.get_theme_constant("margin_left") \
		- arena_screen.get_theme_constant("margin_right") - 157.0 - 8.0 - scrollbar_width
	var spacing := 1 if width == 1 else 2
	var span := width * board_width / ArenaSim.BEATS - 2.0
	return maxi(1, floori((span + spacing) / (16.0 + spacing)))

func _build_lane(lane_index: int, row_height: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	lane_stack.add_child(row)
	var identity := VBoxContainer.new()
	identity.custom_minimum_size.x = 157
	identity.add_theme_constant_override("separation", 3)
	row.add_child(identity)
	var hero: Dictionary = sim.units[lane_index]
	var class_id := _lane_hero_class(lane_index)
	var profile := HBoxContainer.new()
	profile.add_theme_constant_override("separation", 6)
	identity.add_child(profile)
	var portrait := TextureRect.new()
	portrait.texture = GameIcons.hero_art(class_id)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(33, 33)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	profile.add_child(portrait)
	var health_column := VBoxContainer.new()
	health_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_column.add_theme_constant_override("separation", 2)
	profile.add_child(health_column)
	var hero_name := _label(hero.name, 15, CombatIcons.hero_color(lane_index))
	hero_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	health_column.add_child(name_row)
	if not class_id.is_empty():
		name_row.add_child(GameIcons.hero_badge(class_id))
	name_row.add_child(hero_name)
	var mastery: Dictionary = hero.get("mastery", {})
	if not mastery.is_empty():
		var badge := _label("✦", 13, GOLD)
		badge.mouse_filter = Control.MOUSE_FILTER_STOP
		badge.tooltip_text = "%s · %s" % [mastery.label, mastery.description]
		name_row.add_child(badge)
	var health_row := HBoxContainer.new()
	health_row.add_theme_constant_override("separation", 3)
	health_column.add_child(health_row)
	health_row.add_child(CombatIcons.icon("health", 11))
	var health := ProgressBar.new()
	health.accessibility_name = "%s health" % hero.name
	health.show_percentage = false
	health.max_value = hero.max_hp
	health.value = hero.hp
	health.custom_minimum_size.y = 7
	health.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	health.add_theme_stylebox_override("background", _box(INK, EDGE, 2))
	health.add_theme_stylebox_override("fill", _box(Color("#368d72"), TEAL, 2))
	health_row.add_child(health)
	lane_health.append(health)
	var hp := _label("%d/%d" % [hero.hp, hero.max_hp], 12, MUTED)
	hp.name = "LaneHealthText"
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_row.add_child(hp)
	lane_health_labels.append(hp)
	var all := _target_buttons(sim.target_rules("bash"), defaults[lane_index], func(rule: String): _set_all(lane_index, rule), true)
	identity.add_child(all)

	var board := Control.new()
	var cards := {}
	tile_cards.append(cards)
	var offers: Array = _combine_offers(lanes[lane_index]) if _can_edit_loadout() and not camp_forge else []
	var offer_height := 0 if offers.is_empty() else 33
	board.custom_minimum_size.y = row_height + offer_height
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(board)
	if lane_index == 0:
		board.resized.connect(func():
			storage_screen.set_tile_size(board.size.x / ArenaSim.BEATS, row_height)
		)
		storage_screen.set_tile_size(board.size.x / ArenaSim.BEATS, row_height)
	_drop_destination(board, board, lane_index, offer_height)
	for beat in range(ArenaSim.BEATS):
		var cell := _button(str(beat + 1), func(): _place_selected(lane_index, beat))
		cell.tooltip_text = "Place at beat %d" % (beat + 1)
		cell.disabled = not _can_edit_loadout()
		cell.add_theme_font_size_override("font_size", 12)
		cell.add_theme_color_override("font_color", MUTED)
		_add_span(board, cell, beat, 1, offer_height, 0)
		_drop_destination(cell, board, lane_index, offer_height)
	for item: Dictionary in lanes[lane_index]:
		_build_tile(board, lane_index, item, offer_height)
	for offer: Dictionary in offers:
		var prompt := _combine_prompt(-1, lane_index, offer)
		_add_span(board, prompt, offer.start, offer.width, 0, -row_height - 2)
	var head := ColorRect.new()
	head.color = GOLD
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(head)
	head.anchor_bottom = 1
	head.offset_bottom = 0
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

func _build_tile(board: Control, lane_index: int, item: Dictionary, offer_height: int) -> void:
	var tile: Dictionary = ArenaSim.TILES[item.id]
	var active: bool = selected.get("lane", -1) == lane_index and selected.get("start", -1) == item.start
	var payload := {"id": item.id, "lane": lane_index, "start": item.start}
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 1)
	_add_span(board, card, item.start, tile.width, offer_height + 1, -1)
	card.offset_right = 0
	card.set_meta("tile", item)
	tile_cards[lane_index][item.start] = card
	var tile_title: String = tile.get("short_label", tile.label)
	var name_button := SequenceTileButton.new()
	name_button.text = tile_title
	name_button.pressed.connect(func(): _select(payload, true))
	var class_id := _lane_hero_class(lane_index)
	name_button.preview = frontier_screen.tile_hover_card.bind(item.id, class_id, item.get("enchantment", ""))
	var icon_key := GameIcons.tile(item.id, tile)
	GameIcons.decorate(name_button, icon_key, 15 if tile.width == 1 else 20)
	name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if tile.width == 1:
		name_button.add_theme_constant_override("h_separation", 3)
		name_button.clip_text = true
	name_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_button.add_theme_font_size_override("font_size", 13)
	var tones := {
		"guard": Color("#254949"), "teleport": Color("#413653"), "shot": Color("#273f52"),
		"pull": Color("#254949"), "rest": Color("#334c3e"), "elite": Color("#47384a"),
	}
	var family: String = tile.get("family", "")
	var tint: Color = tones.get(family, tones.get(icon_key, Color("#583b35")))
	var rarity_edge := GameIcons.rarity(tile).darkened(0.36)
	var tile_back := Panel.new()
	tile_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile_back.add_theme_stylebox_override("panel", _box(tint.darkened(0.30), GOLD if active else rarity_edge))
	_add_span(board, tile_back, item.start, tile.width, offer_height + 1, -1)
	tile_back.offset_right = 0
	board.move_child(tile_back, card.get_index())
	card.set_meta("tile_back", tile_back)
	name_button.tooltip_text = _tile_tooltip(lane_index, item, tile)
	var metric := CombatIcons.tile_corner_stat(tile)
	_style_tile_button(name_button, tile, tint, active, 16, tile.width == 1, not metric.is_empty())
	name_button.disabled = not _can_edit_loadout()
	card.add_child(name_button)
	_add_tile_badges(name_button, tile, class_id)
	_add_enchantment_badge(name_button, item)
	CombatIcons.add_tile_corner(name_button, metric)
	_drag_source(name_button, payload, board, lane_index, offer_height)
	var available_rules: Array = sim.target_rules(item.id)
	var current_rule: String = item.target if item.target in available_rules else available_rules[0]
	var choose := func(rule: String):
		var before := _inventory_checkpoint()
		item.target = rule
		if not _persist_inventory(before):
			return
		name_button.tooltip_text = _tile_tooltip(lane_index, item, tile)
		var target_caption := _setup_target_caption(lane_index, item, item.target)
		setup_hint.text = "%s · %s" % [tile.label, LABELS[rule] if target_caption.is_empty() else target_caption]
	var target_group := ButtonGroup.new()
	var rule_rows := []
	var columns := _tile_target_columns(tile.width)
	for first in range(0, available_rules.size(), columns):
		rule_rows.append(available_rules.slice(first, first + columns))
	for rules: Array in rule_rows:
		var targets := _target_buttons(rules, current_rule, choose, false, target_group)
		if tile.width == 1:
			targets.add_theme_constant_override("separation", 1)
		card.add_child(targets)
		_drop_destination(targets, board, lane_index, offer_height)
		for target_button: Control in targets.get_children():
			if target_button is Button:
				_drop_destination(target_button, board, lane_index, offer_height)
	var marker := Panel.new()
	marker.name = "TimingMarker"
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pulse_color := CombatIcons.hero_color(lane_index)
	var rim := _box(Color(pulse_color, 0.08), pulse_color)
	rim.set_border_width_all(2)
	rim.shadow_color = Color(pulse_color, 0.35)
	rim.shadow_size = 3
	marker.add_theme_stylebox_override("panel", rim)
	board.add_child(marker)
	marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marker.anchor_left = float(item.start) / ArenaSim.BEATS
	marker.anchor_right = float(item.start + int(tile.width)) / ArenaSim.BEATS
	marker.offset_left = 2
	marker.offset_right = 0
	marker.offset_top = offer_height + 1
	marker.offset_bottom = -1
	var firing_edge := ColorRect.new()
	firing_edge.color = pulse_color.lightened(0.30)
	firing_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(firing_edge)
	firing_edge.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	firing_edge.offset_left = -4
	firing_edge.offset_right = 0
	marker.hide()
	card.set_meta("timing_marker", marker)


func _style_tile_button(button: Button, tile: Dictionary, tint: Color, active: bool,
		badge_space := 0, compact := false, show_stat := false) -> void:
	var rarity := GameIcons.rarity(tile)
	for mode: String in ["normal", "hover", "pressed", "disabled"]:
		var fill := tint.lightened(0.12) if mode == "hover" else tint
		if mode == "pressed" or active:
			fill = fill.lerp(GOLD, 0.16)
		var box := _box(fill, rarity)
		box.border_width_top = 3
		box.content_margin_top = maxf(4, badge_space)
		box.content_margin_bottom = 2
		if compact:
			box.content_margin_left = 5
			box.content_margin_right = 5
		if show_stat:
			box.content_margin_right = 25
		button.add_theme_stylebox_override(mode, box)


func _add_tile_badges(button: Button, tile: Dictionary, class_id: String) -> void:
	var rarity_badge := GameIcons.rarity_badge(tile, true)
	button.add_child(rarity_badge)
	rarity_badge.position = Vector2(6, 3)
	if not class_id.is_empty():
		var hero_badge := GameIcons.hero_badge(class_id)
		button.add_child(hero_badge)
		hero_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 4)
		hero_badge.offset_top = 3

func _add_enchantment_badge(button: Button, item: Dictionary) -> void:
	if item.has("enchantment"):
		var badge := GameIcons.enchantment_badge(item.enchantment, 15)
		button.add_child(badge)
		badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
		badge.offset_top = 2

func _target_buttons(rules: Array, current: String, choose: Callable, all := false, group: ButtonGroup = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if group == null:
		group = ButtonGroup.new()
	if all:
		var label := _label("All", 11, MUTED)
		row.add_child(label)
	for rule: String in rules:
		var button := _button(TARGET_ICONS[rule], func(): choose.call(rule))
		button.name = "Target_" + rule
		button.toggle_mode = true
		button.button_group = group
		button.set_pressed_no_signal(current == rule)
		button.disabled = not _can_edit_loadout() or rules.size() == 1
		button.custom_minimum_size = Vector2(16, 22)
		button.add_theme_font_size_override("font_size", 13)
		button.tooltip_text = LABELS[rule] + (" · all compatible tiles" if all else "")
		for style: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var active := style == "pressed" or style == "focus"
			var box := _box(Color("#394136") if active else Color("#1b2831"), GOLD if active else EDGE, 3)
			box.content_margin_left = 2
			box.content_margin_right = 2
			box.content_margin_top = 0
			box.content_margin_bottom = 0
			button.add_theme_stylebox_override(style, box)
		row.add_child(button)
	return row

func _tile_tooltip(lane_index: int, item: Dictionary, tile: Dictionary) -> String:
	var available_rules: Array = sim.target_rules(item.id)
	var rule: String = item.target if item.target in available_rules else available_rules[0]
	var owner := _lane_hero_class(lane_index)
	var origin := GameIcons.tile_origin(item.id, tile)
	var identity := "Equipped by %s" % sim.units[lane_index].name
	if not origin.is_empty() and origin != owner:
		identity += " · %s signature" % GameIcons.hero_label(origin)
	var tooltip := "%s · %s · %s\n%s\n%s" % [
		tile.label, GameIcons.rarity_name(tile), GameIcons.tile_stats(tile), identity, tile.description
	]
	var target_caption := _setup_target_caption(lane_index, item, rule)
	if not target_caption.is_empty():
		tooltip += " · " + target_caption
	var enchantment := TileEnchantments.info(item.get("enchantment", ""))
	var keyword_copy: String = GameIcons.tile_stats(tile) + "\n" + tile.description
	var critical := GameIcons.critical_tooltip(item.id, owner)
	if not critical.is_empty():
		tooltip += "\n" + critical
	if not enchantment.is_empty():
		tooltip += "\n%s · %s" % [enchantment.label, enchantment.description]
		keyword_copy += "\n" + enchantment.description
	return TileKeywords.with_definitions(tooltip, keyword_copy, FrontierScreen.TILE_DESCRIPTION_EXCLUSIONS)


func _setup_target_caption(lane_index: int, item: Dictionary, rule: String) -> String:
	if state != "setup" or (campaign and not encounter_setup):
		return ""
	if sim.units[lane_index].hp <= 0:
		return "Hero is fallen"
	var target: Dictionary = sim.target_for(lane_index, item.id, rule, item.get("enchantment", ""))
	return target.get("name", "Out of range at current positions")


func _lane_hero_class(lane: int) -> String:
	if lane < 0 or lane >= sim.units.size():
		return ""
	var hero: Dictionary = sim.units[lane]
	return hero.get("class", GameIcons.hero_class_for_label(hero.name))

func _set_all(lane_index: int, rule: String) -> void:
	var before := _inventory_checkpoint()
	defaults[lane_index] = rule
	var skipped := 0
	for item: Dictionary in lanes[lane_index]:
		if rule in sim.target_rules(item.id):
			item.target = rule
		else:
			skipped += 1
	if not _persist_inventory(before):
		return
	_rebuild_loadout()
	setup_hint.text = "Set compatible tiles to %s%s." % [
		LABELS[rule], " · %d unchanged" % skipped if skipped else ""
	]

func _select(payload: Dictionary, activate_forge := false) -> void:
	if not _can_edit_loadout():
		return
	selected = payload.duplicate() if activate_forge and camp_forge else ({} if selected == payload else payload.duplicate())
	_rebuild_loadout()
	if activate_forge and camp_forge and not _editing_camp_forge() and run.camp_forge_blocker(selected).is_empty():
		_open_camp_forge()
		return
	if not selected.is_empty():
		var first: Control
		if selected.get("lane", -1) >= 0:
			var row := lane_stack.get_child(selected.lane)
			first = row.get_child(1).get_child(selected.start)
		else:
			first = lane_stack.get_child(0).get_child(1).get_child(0)
		first.grab_focus()

func _drag_source(control: Control, payload: Dictionary, board: Control = null, lane_index := -1, top := 0) -> void:
	var get_data := func(point: Vector2):
		if not _can_edit_loadout():
			return null
		var tile: Dictionary = ArenaSim.TILES[payload.id]
		var drag := payload.duplicate()
		if board != null:
			var at := _lane_point(board, control, point)
			drag.grab_offset = clampi(floori(at.x * ArenaSim.BEATS / board.size.x) - int(payload.start), 0, int(tile.width) - 1)
		var preview := _label(tile.label, 17, GameIcons.rarity(tile))
		preview.position = Vector2(12, -28)
		control.set_drag_preview(preview)
		return drag
	if board == null:
		control.set_drag_forwarding(get_data, Callable(), Callable())
	else:
		_drop_destination(control, board, lane_index, top, get_data)

func _lane_point(board: Control, control: Control, point: Vector2) -> Vector2:
	return board.get_global_transform().affine_inverse() * (control.get_global_transform() * point)

func _drop_destination(control: Control, board: Control, lane_index: int, top: int, get_data := Callable()) -> void:
	var drop_start := func(data: Dictionary) -> int:
		var at := board.get_global_transform_with_canvas().affine_inverse() * drag_pointer
		var width := int(ArenaSim.TILES.get(data.get("id", ""), {}).get("width", 0))
		if width == 0 or at.y < top or not Rect2(Vector2.ZERO, board.size).has_point(at):
			return -1
		return clampi(floori(at.x * ArenaSim.BEATS / board.size.x) - int(data.get("grab_offset", 0)), 0, ArenaSim.BEATS - width)
	control.set_drag_forwarding(get_data,
		func(_point: Vector2, data: Variant) -> bool:
			if not data is Dictionary or not _can_edit_loadout():
				return false
			var start: int = drop_start.call(data)
			if start < 0:
				_clear_drag_preview()
				return false
			var plan := _timeline_nudge_plan(lane_index, start, data)
			_show_drag_preview(board, lane_index, top, start, data, plan)
			return not plan.is_empty(),
		func(_point: Vector2, data: Variant):
			var start: int = drop_start.call(data)
			if start >= 0:
				_place(data, lane_index, start, true)
	)

func _show_drag_preview(board: Control, lane_index: int, top: int, start: int, data: Dictionary, plan: Dictionary) -> void:
	var key := [lane_index, start, data.get("lane", -1), data.get("row", -1), data.get("start", -1), data.id]
	if drag_board == board and drag_preview_key == key:
		return
	_clear_drag_preview()
	drag_preview_key = key
	drag_board = board
	drag_overlay = Control.new()
	drag_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_overlay.z_index = 2
	board.add_child(drag_overlay)
	drag_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cards: Dictionary = tile_cards[lane_index]
	var source_lane := int(data.get("lane", -1))
	var source: Control = null
	if source_lane >= 0 and source_lane < tile_cards.size() and tile_cards[source_lane].has(data.get("start", -1)):
		source = tile_cards[source_lane][data.start]
		_fade_drag_card(source)
	var moves: Dictionary = plan.get("moves", {})
	for original: int in moves:
		var card: Control = cards[original]
		_fade_drag_card(card)
		var ghost := _add_drag_tile(card.get_meta("tile").id, moves[original], top, TEAL)
		_slide_drag_ghost(ghost, card)
	var swap_start: int = plan.get("swap", -1)
	if swap_start >= 0:
		var card: Control = cards[swap_start]
		_fade_drag_card(card)
		if source != null:
			var ghost := _add_drag_tile(card.get_meta("tile").id, source.get_meta("tile").start, top, TEAL)
			ghost.position = _lane_point(drag_overlay, source, Vector2.ZERO)
			_slide_drag_ghost(ghost, card)
	var stows: Array = plan.get("stows", [])
	for stow: Dictionary in stows:
		_fade_drag_card(cards[stow.start])
	var caption := "No room" if plan.is_empty() else ""
	if plan.is_empty():
		if data.get("reward", false) and not _reward_can_target(data.id, lane_index):
			caption = "Wrong hero"
			_show_inventory_message("Place this reward on the highlighted hero's sequence or send it to storage.")
		else:
			_show_inventory_message("No room for this drop. Free a span in the sequence or storage.")
	elif swap_start >= 0 and data.has("row"):
		caption = "Swap"
		_show_inventory_message("The equipped tile will move into the storage slot you dragged from.")
	if not stows.is_empty():
		caption = "%d to storage" % stows.size()
		_show_inventory_message("Displaced tiles will move to storage.")
	_add_drag_tile(data.id, start, top, RUST if plan.is_empty() else GOLD, caption)

func _add_drag_tile(id: String, start: int, top: int, accent: Color, copy := "") -> Control:
	var tile: Dictionary = ArenaSim.TILES[id]
	var ghost := PanelContainer.new()
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.add_theme_stylebox_override("panel", _box(Color("#20323e"), accent))
	_add_span(drag_overlay, ghost, start, tile.width, top + 1, -1)
	ghost.offset_right = 0
	var contents := HBoxContainer.new()
	contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contents.add_theme_constant_override("separation", 4)
	ghost.add_child(contents)
	if copy.is_empty():
		var art := TextureRect.new()
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.texture = GameIcons.icon(GameIcons.tile(id, tile))
		art.custom_minimum_size = Vector2(16, 16)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		contents.add_child(art)
	var caption := _label(tile.get("short_label", tile.label) if copy.is_empty() else copy, 13, accent)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_child(caption)
	return ghost

func _slide_drag_ghost(ghost: Control, source: Control) -> void:
	var destination := ghost.position
	ghost.position = _lane_point(drag_overlay, source, Vector2.ZERO)
	ghost.create_tween().tween_property(ghost, "position", destination, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _fade_drag_card(card: Control) -> void:
	faded_cards[card] = card.modulate.a
	card.modulate.a = 0.16
	var tile_back: Control = card.get_meta("tile_back", null)
	if tile_back != null:
		faded_cards[tile_back] = tile_back.modulate.a
		tile_back.modulate.a = 0.16

func _clear_drag_preview() -> void:
	for card in faded_cards:
		if is_instance_valid(card):
			card.modulate.a = faded_cards[card]
	faded_cards.clear()
	if is_instance_valid(drag_overlay):
		drag_overlay.hide()
		drag_overlay.queue_free()
	drag_board = null
	drag_overlay = null
	drag_preview_key.clear()

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		drag_pointer = event.position
	if is_instance_valid(drag_board) and (not arena_screen.is_visible_in_tree()
		or not drag_board.get_rect().has_point(drag_board.get_parent().get_global_transform_with_canvas().affine_inverse() * drag_pointer)):
		_clear_drag_preview()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and arsenal_panel.is_visible_in_tree():
		arsenal_panel.hide()
		arsenal_button.grab_focus()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_clear_drag_preview()

func _timeline_nudge_plan(lane_index: int, start: int, payload: Dictionary) -> Dictionary:
	if not _can_edit_loadout():
		return {}
	if payload.get("reward", false) and not _reward_can_target(payload.id, lane_index):
		return {}
	return TilePacking.timeline_drop_plan(lanes, storage_rows, lane_index, start, payload)

func _can_place(payload: Dictionary, lane_index: int, start: int) -> bool:
	var ignored: int = payload.get("start", -1) if payload.get("lane", -1) == lane_index else -1
	return _can_edit_loadout() and TilePacking.can_place(lanes[lane_index], payload.get("id", ""), start, ArenaSim.BEATS, ignored)

func _place_selected(lane_index: int, beat: int) -> void:
	if selected.is_empty():
		setup_hint.text = "Select a tile first."
		return
	_place(selected, lane_index, beat)

func _place(payload: Dictionary, lane_index: int, start: int, nudge := false) -> void:
	var plan := _timeline_nudge_plan(lane_index, start, payload) if nudge else {}
	if payload.get("reward", false):
		if not plan.is_empty():
			_drop_reward_on_timeline(payload.id, lane_index, start, plan)
		return
	if (nudge and plan.is_empty()) or (not nudge and not _can_place(payload, lane_index, start)):
		setup_hint.text = "No room for that tile."
		return
	if payload.get("lane", -1) == lane_index and payload.get("start", -1) == start:
		return
	var before := _inventory_checkpoint()
	var valid: Array = sim.target_rules(payload.id)
	var target: String = defaults[lane_index] if defaults[lane_index] in valid else valid[0]
	var entry := _entry(payload.id, start, target)
	if payload.has("lane"):
		entry = _take_tile(payload)
		if entry.is_empty():
			return
		entry.start = start
	else:
		suppressed_combines.erase(payload.id)
	var destination: Array = lanes[lane_index]
	var swap_start: int = plan.get("swap", -1)
	if swap_start >= 0:
		var swapped := _take_displaced_tile(destination, swap_start)
		swapped.start = payload.start
		var previous: Array = storage_rows[payload.row] if payload.has("row") else lanes[payload.lane]
		previous.append(swapped)
		previous.sort_custom(func(a: Dictionary, b: Dictionary): return a.start < b.start)
	_apply_stows(destination, storage_rows, plan)
	_apply_nudge(destination, plan)
	destination.append(entry)
	destination.sort_custom(func(a: Dictionary, b: Dictionary): return a.start < b.start)
	if not _persist_inventory(before):
		return
	selected.clear()
	_rebuild_loadout()
	var touched: Array[Dictionary] = [{"row": -1, "lane": lane_index, "start": start}]
	if swap_start >= 0:
		touched.append({"row": payload.get("row", -1), "lane": payload.lane, "start": payload.start})
	for position: int in plan.get("moves", {}).values():
		touched.append({"row": -1, "lane": lane_index, "start": position})
	for stow: Dictionary in plan.get("stows", []):
		touched.append({"row": stow.row, "lane": -1, "start": stow.position})
	for slot: Dictionary in touched:
		open_new_tile_combine(slot.row, slot.lane, slot.start)
		if forge_screen.visible:
			break

func _take_displaced_tile(items: Array, start: int) -> Dictionary:
	return items.pop_at(items.find_custom(func(item: Dictionary): return item.start == start))

func _apply_stows(items: Array, storage: Array, plan: Dictionary) -> void:
	for stow: Dictionary in plan.get("stows", []):
		var displaced := _take_displaced_tile(items, stow.start)
		displaced.start = stow.position
		var row: Array = storage[stow.row]
		row.append(displaced)
		row.sort_custom(func(a: Dictionary, b: Dictionary): return a.start < b.start)

func _apply_nudge(items: Array, plan: Dictionary) -> void:
	var moves: Dictionary = plan.get("moves", {})
	for item: Dictionary in items:
		item.start = moves.get(item.start, item.start)

func _take_tile(payload: Dictionary) -> Dictionary:
	var lane: Array = storage_rows[payload.row] if payload.has("row") else lanes[payload.lane]
	for index in range(lane.size()):
		if lane[index].start == payload.start and lane[index].id == payload.id:
			return lane.pop_at(index)
	return {}

func _confirm_discard() -> void:
	if not _can_discard_selected():
		return
	if campaign:
		discard_dialog.dialog_text = "Discard %s for this run?" % ArenaSim.TILES[selected.id].label
		discard_dialog.popup_centered()
		return
	_discard_selected()

func _can_discard_selected() -> bool:
	var item := _selected_tile()
	if not _can_edit_loadout() or item.is_empty():
		return false
	if _editing_camp_forge() and is_same(item, pending_forge.camp_tile):
		_show_inventory_message("Return to the forge before discarding the tile you are upgrading.")
		return false
	if not campaign and retry_options.is_empty():
		return true
	var count := 0
	for items: Array in lanes + storage_rows:
		count += items.size()
	if count > 1:
		return true
	_show_inventory_message("Keep at least one tile so you can start the next battle.")
	return false

func _discard_selected() -> void:
	if not _can_discard_selected():
		return
	var before := _inventory_checkpoint()
	if _take_tile(selected).is_empty() or not _persist_inventory(before):
		return
	selected.clear()
	_rebuild_loadout()

func tile_spec(id: String) -> Dictionary:
	return ArenaSim.TILES.get(id, {})

func _open_storage() -> void:
	if state == "setup":
		arsenal_panel.hide()
		arena_screen.show()
		storage_screen.show()
		camp_button.hide()
		_render_storage()

func _toggle_storage() -> void:
	if storage_screen.visible:
		storage_close()
	else:
		_open_storage()

func storage_close() -> void:
	if _placing_tile_reward():
		_set_reward_storage(true)
		_render_storage()
		_update_controls()
		return
	storage_screen.hide()
	arena_screen.show()
	_rebuild_loadout()
	_update_controls()

func _render_storage() -> void:
	var all_offers: Array[Dictionary] = []
	for row in range(storage_rows.size()):
		for offer in _combine_offers(storage_rows[row]):
			offer.row = row
			all_offers.append(offer)
	var protect_selected := _editing_camp_forge() and is_same(_selected_tile(), pending_forge.camp_tile)
	var can_forge := camp_forge and not _editing_camp_forge()
	var blocker: String = run.camp_forge_blocker(selected) if can_forge else ""
	storage_screen.render(storage_rows, selected, [] if camp_forge else all_offers, can_forge,
		not camp_forge and _selected_combine_copies().size() >= 3, _enchantment_controls(), protect_selected, blocker)

func _held_enchantments() -> Array:
	return run.enchantments() if campaign or not retry_options.is_empty() else []

func _selected_tile() -> Dictionary:
	if not selected.has("lane"):
		return {}
	var items: Array = storage_rows[selected.row] if selected.has("row") else lanes[selected.lane]
	for item: Dictionary in items:
		if item.start == selected.start and item.id == selected.id:
			return item
	return {}

func _enchantment_host(id: String) -> Dictionary:
	for items: Array in lanes + storage_rows:
		for item: Dictionary in items:
			if item.get("enchantment", "") == id:
				return item
	return {}

func _enchantment_controls() -> Array[Dictionary]:
	var controls: Array[Dictionary] = []
	var item := _selected_tile()
	var tile_id: String = item.get("id", "")
	var current: String = item.get("enchantment", "")
	for id: String in _held_enchantments():
		var host := _enchantment_host(id)
		var eligible := current == id or TileEnchantments.is_eligible(id, tile_spec(tile_id), tile_id)
		var caption := "Equip" if host.is_empty() else "Move"
		if current == id:
			caption = "Remove"
		elif not current.is_empty():
			caption = "Replace"
		controls.append({"id": id, "host": tile_spec(host.get("id", "")).get("label", ""),
			"eligible": eligible, "button": caption, "replaced": current if caption == "Replace" else ""})
	return controls

func storage_enchant_selected(id: String) -> void:
	if not _can_edit_loadout() or not storage_screen.visible or id not in _held_enchantments():
		return
	var item := _selected_tile()
	var tile_id: String = item.get("id", "")
	var removing: bool = item.get("enchantment", "") == id
	if not removing and not TileEnchantments.is_eligible(id, tile_spec(tile_id), tile_id):
		return
	var before := _inventory_checkpoint()
	_enchantment_host(id).erase("enchantment")
	if not removing:
		item.enchantment = id
	if not _persist_inventory(before):
		return
	_rebuild_loadout()

func storage_pick(row: int, item: Dictionary, activate_forge := false) -> void:
	var payload := {"id": item.id, "lane": -1, "row": row, "start": item.start}
	selected = payload if activate_forge and camp_forge else ({} if selected == payload else payload)
	_rebuild_loadout()
	if activate_forge and camp_forge and not _editing_camp_forge() and run.camp_forge_blocker(selected).is_empty():
		_open_camp_forge()

func storage_can_place(row: int, start: int, payload: Dictionary) -> bool:
	var ignored: int = payload.get("start", -1) if payload.get("row", -1) == row else -1
	return _can_edit_loadout() and TilePacking.can_place(storage_rows[row], payload.get("id", ""), start, TilePacking.STORAGE_COLUMNS, ignored)

func storage_nudge_plan(row: int, start: int, payload: Dictionary) -> Dictionary:
	if not _can_edit_loadout() or (payload.get("reward", false) and not _reward_can_target(payload.id, -1)):
		return {}
	var ignored: int = payload.get("start", -1) if payload.get("row", -1) == row else -1
	return TilePacking.nudge_plan(storage_rows[row], payload.get("id", ""), start, TilePacking.STORAGE_COLUMNS, ignored)

func storage_place(row: int, start: int, payload: Dictionary, nudge := false) -> void:
	var plan := storage_nudge_plan(row, start, payload) if nudge else {}
	if (nudge and plan.is_empty()) or (not nudge and not storage_can_place(row, start, payload)):
		storage_screen.show_message("That tile needs a clear span in one row.")
		return
	if payload.get("reward", false):
		if not _place_tile_reward(payload.id, {"row": row, "start": start}, plan):
			storage_screen.show_message(run.save_error if not run.save_error.is_empty() else "That reward could not be placed.")
		return
	var before := _inventory_checkpoint()
	var valid: Array = ArenaSim.TILES[payload.id].targets
	var entry := _entry(payload.id, start, valid[0])
	if payload.has("lane"):
		entry = _take_tile(payload)
		if entry.is_empty():
			return
		entry.start = start
	else:
		suppressed_combines.erase(payload.id)
	_apply_nudge(storage_rows[row], plan)
	storage_rows[row].append(entry)
	storage_rows[row].sort_custom(func(a: Dictionary, b: Dictionary): return a.start < b.start)
	if not _persist_inventory(before):
		return
	selected.clear()
	_rebuild_loadout()
	open_new_tile_combine(row, -1, start)

func storage_send_to_timeline() -> void:
	if selected.has("row"):
		setup_hint.text = "Choose an empty starting beat for %s." % ArenaSim.TILES[selected.id].label
		storage_screen.show_message(setup_hint.text)
		lane_stack.get_child(0).get_child(1).get_child(0).grab_focus()

func storage_discard() -> void:
	if storage_screen.visible and selected.has("lane"):
		_confirm_discard()

func storage_forge() -> void:
	if camp_forge and selected.has("lane"):
		_open_camp_forge()

func storage_combine(row: int, start: int, accept: bool) -> void:
	_offer_combine(row, -1, start, accept)

func _selected_combine_copies() -> Array:
	if _editing_camp_forge() or not selected.has("lane") or suppressed_combines.has(selected.id):
		return []
	return TilePacking.find_copies(lanes, storage_rows, selected.id, range(lanes.size()), selected)

func storage_combine_selected() -> void:
	if not _can_edit_loadout() or not storage_screen.visible:
		return
	var copies := _selected_combine_copies()
	if copies.size() < 3:
		return
	pending_forge = {"inventory_copies": copies, "storage_open": true}
	arena_screen.hide()
	storage_screen.hide()
	forge_screen.open(selected.id)

func _commit_inventory_combine(id: String) -> void:
	var plan := _inventory_upgrade_plan(id)
	if plan.is_empty():
		return
	var before := _inventory_checkpoint()
	var target := _combine_target(lanes, storage_rows, plan.copies, plan.destination, id)
	var notice := _combine_enchantment_notice(lanes, storage_rows, plan.copies, plan.destination, id)
	if not TilePacking.apply_combination(lanes, storage_rows, plan.copies, plan.destination, id, target):
		return
	suppressed_combines.erase(id)
	if not _persist_inventory(before):
		forge_screen.show_error(run.save_error)
		return
	selected.clear()
	_after_forge_upgrade()
	if not notice.is_empty():
		_show_inventory_message(notice)

func _inventory_upgrade_plan(id: String) -> Dictionary:
	return TilePacking.combine_plan(lanes, storage_rows, pending_forge.inventory_copies, 3, id, range(lanes.size()), true)

func _combine_prompt(row: int, lane: int, offer: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color("#3a3024"), GOLD))
	var buttons := HBoxContainer.new()
	panel.add_child(buttons)
	var label := _label("Combine", 13, GOLD)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(label)
	var yes := _button("Yes", func(): _offer_combine(row, lane, offer.start, true))
	yes.add_theme_stylebox_override("normal", _box(Color("#725831"), GOLD))
	buttons.add_child(yes)
	buttons.add_child(_button("No", func(): _offer_combine(row, lane, offer.start, false)))
	return panel

func _combine_offers(items: Array) -> Array[Dictionary]:
	if _editing_camp_forge():
		return []
	return TilePacking.offers(items, suppressed_combines)

func _offer_combine(row: int, lane: int, start: int, accept: bool) -> void:
	if not _can_edit_loadout():
		return
	var items: Array = storage_rows[row] if row >= 0 else lanes[lane]
	for offer in _combine_offers(items):
		if offer.start != start:
			continue
		pending_forge = {"row": row, "lane": lane, "offer": offer, "storage_open": storage_screen.visible}
		if accept:
			arena_screen.hide()
			storage_screen.hide()
			forge_screen.open(offer.id)
		else:
			decline_dialog.dialog_text = "Hide Combine for %s until you acquire another copy?" % ArenaSim.TILES[offer.id].label
			decline_dialog.confirmed.connect(_decline_combine, CONNECT_ONE_SHOT)
			decline_dialog.canceled.connect(_cancel_decline, CONNECT_ONE_SHOT)
			decline_dialog.popup_centered()
		return

func open_new_tile_combine(row: int, lane: int, start: int) -> void:
	var items: Array = storage_rows[row] if row >= 0 else lanes[lane]
	for offer: Dictionary in _combine_offers(items):
		if start >= offer.start and start < offer.start + offer.width:
			_offer_combine(row, lane, offer.start, true)
			return

func _cancel_decline() -> void:
	if decline_dialog.confirmed.is_connected(_decline_combine):
		decline_dialog.confirmed.disconnect(_decline_combine)
	pending_forge.clear()

func _decline_combine() -> void:
	if decline_dialog.canceled.is_connected(_cancel_decline):
		decline_dialog.canceled.disconnect(_cancel_decline)
	var before := _inventory_checkpoint()
	suppressed_combines[pending_forge.offer.id] = true
	if not _persist_inventory(before):
		pending_forge.clear()
		return
	forge_close()

func forge_choose(id: String, expected_plan: Variant = null) -> void:
	if pending_forge.is_empty() or not forge_screen.visible:
		return
	if pending_forge.has("reward"):
		_claim_reward_upgrade(id)
		return
	if pending_forge.has("inventory_copies"):
		if id in TilePacking.next_options(pending_forge.inventory_copies[0].id):
			_commit_inventory_combine(id)
		return
	if pending_forge.has("camp"):
		_commit_camp_forge(id, expected_plan)
		return
	var offer: Dictionary = pending_forge.offer
	if id not in TilePacking.next_options(offer.id):
		return
	var items: Array = storage_rows[pending_forge.row] if pending_forge.row >= 0 else lanes[pending_forge.lane]
	if not _combine_offers(items).has(offer):
		forge_close()
		return
	if ArenaSim.TILES[id].width > offer.width:
		return
	var copies := []
	var source_width: int = ArenaSim.TILES[offer.id].width
	for start: int in range(offer.start, offer.start + offer.width, source_width):
		var copy := {"lane": pending_forge.lane, "id": offer.id, "start": start}
		if pending_forge.row >= 0:
			copy.row = pending_forge.row
		copies.append(copy)
	var before := _inventory_checkpoint()
	var target := _combine_target(lanes, storage_rows, copies, copies[0], id)
	var notice := _combine_enchantment_notice(lanes, storage_rows, copies, copies[0], id)
	if not TilePacking.apply_combination(lanes, storage_rows, copies, copies[0], id, target):
		return
	suppressed_combines.erase(id)
	if not _persist_inventory(before):
		forge_screen.show_error(run.save_error)
		return
	selected.clear()
	_after_forge_upgrade()
	if not notice.is_empty():
		_show_inventory_message(notice)

func forge_can_fit(id: String) -> bool:
	if pending_forge.has("reward"):
		return not _reward_upgrade_plan(pending_forge.copies, id).is_empty()
	if pending_forge.has("inventory_copies"):
		return not _inventory_upgrade_plan(id).is_empty()
	if pending_forge.has("camp"):
		return not run.camp_forge_plan(pending_forge.camp, id).is_empty()
	return int(ArenaSim.TILES[id].width) <= int(pending_forge.offer.width)

func forge_layout(id: String) -> Dictionary:
	var source: Dictionary = pending_forge.get("camp", {})
	if source.is_empty() or id not in TilePacking.next_options(source.id):
		return {}
	var stored := source.has("row")
	var plan: Dictionary = run.camp_forge_plan(source, id)
	var items: Array = storage_rows[plan.get("destination_row", source.row)] if stored else lanes[source.lane]
	return {"source": source, "stored": stored, "plan": plan, "items": items,
		"capacity": TilePacking.STORAGE_COLUMNS if stored else ArenaSim.BEATS}

func forge_edit_layout(id: String) -> void:
	if not forge_screen.visible or forge_layout(id).is_empty():
		return
	pending_forge.layout_upgrade = id
	forge_screen.hide()
	arena_screen.show()
	_rebuild_loadout()
	_open_storage()
	_update_controls()
	action.grab_focus()

func _editing_camp_forge() -> bool:
	return pending_forge.has("layout_upgrade")

func _resume_camp_forge() -> void:
	pending_forge.erase("layout_upgrade")
	pending_forge.storage_open = storage_screen.visible
	selected = pending_forge.camp.duplicate()
	_rebuild_loadout()
	_update_controls()
	arena_screen.hide()
	storage_screen.hide()
	forge_screen.resume_layout()

func _track_camp_forge_tile() -> void:
	var source: Dictionary = pending_forge.camp_tile
	for lane in range(lanes.size()):
		for item: Dictionary in lanes[lane]:
			if is_same(item, source):
				pending_forge.camp = {"id": item.id, "lane": lane, "start": item.start}
				return
	for row in range(storage_rows.size()):
		for item: Dictionary in storage_rows[row]:
			if is_same(item, source):
				pending_forge.camp = {"id": item.id, "lane": -1, "row": row, "start": item.start}
				return

func forge_owner() -> String:
	if pending_forge.has("reward"):
		var heroes: Array = run.data.get("heroes", [])
		var lane := maxi(0, run.reward_lane())
		if lane < heroes.size():
			return heroes[lane].get("id", "")
		return run.data.get("hero", "")
	if pending_forge.has("inventory_copies"):
		var source: Dictionary = pending_forge.inventory_copies[0]
		return _lane_hero_class(source.lane)
	var source: Dictionary = pending_forge.get("camp", pending_forge)
	return _lane_hero_class(source.get("lane", -1))

func forge_close() -> void:
	if pending_forge.has("reward"):
		var pending: Dictionary = run.data.get("reward_combine", {})
		run.data.erase("reward_combine")
		if run.save():
			run_return()
		else:
			run.data.reward_combine = pending
			forge_screen.show_error(run.save_error)
		return
	var from_storage: bool = pending_forge.get("storage_open", false)
	pending_forge.clear()
	forge_screen.hide()
	if from_storage:
		_open_storage()
	else:
		storage_close()

func _start_sim() -> void:
	arena.location = retry_options.get("location", "brass")
	if not retry_options.is_empty():
		sim.start(lanes, "solo", retry_options)
	elif campaign:
		arena.location = run.data.get("location", "brass")
		var options: Dictionary = run.encounter()
		if options.is_empty():
			options = {
				"encounter": "opening", "hero": run.data.hero, "hp": run.data.hp,
				"max_hp": run.data.max_hp, "heroes": run.data.get("heroes", []),
				"difficulty": run.data.get("difficulty", "easy"), "location": arena.location,
				"segment": run.data.get("segment", 1), "relics": run.data.relics,
				"relic": run.data.relics[0] if not run.data.relics.is_empty() else ""
			}
		sim.start(lanes, "solo", options)
	else:
		sim.start(lanes, fixture)

func _save_loadout() -> bool:
	if campaign:
		run.loadout = {"lanes": lanes, "storage": storage_rows, "defaults": defaults, "suppressed": suppressed_combines}
		return run.save()
	return true

func _inventory_checkpoint() -> Dictionary:
	return run.loadout.duplicate(true) if campaign else {}

func _read_run_loadout() -> void:
	lanes = run.loadout.lanes
	storage_rows = run.loadout.storage
	defaults.assign(run.loadout.defaults)
	suppressed_combines = run.loadout.suppressed

func _restore_inventory(before: Dictionary) -> void:
	run.loadout = before
	_read_run_loadout()
	if _editing_camp_forge():
		var source: Dictionary = pending_forge.camp
		var items: Array = storage_rows[source.row] if source.has("row") else lanes[source.lane]
		for item: Dictionary in items:
			if item.start == source.start and item.id == source.id:
				pending_forge.camp_tile = item
				break
	_rebuild_loadout()

func _persist_inventory(before: Dictionary) -> bool:
	if _save_loadout():
		if _editing_camp_forge():
			_track_camp_forge_tile()
		if _placing_tile_reward():
			frontier_screen.refresh_reward_copy_pips()
		return true
	_restore_inventory(before)
	_show_inventory_message(run.save_error)
	return false

func _show_frontier(page := "") -> void:
	_hide_result_animation()
	showing_rewards = false
	state = "setup"
	combat_save_pending = false
	campaign = false
	camp_forge = false
	battle_snapshot.clear()
	retry_options = {}
	retry_result = {}
	arena_screen.hide()
	arsenal_panel.hide()
	_set_reward_storage(false)
	storage_screen.hide()
	forge_screen.hide()
	pending_forge.clear()
	_place_frontier_screen(self)
	if page.is_empty() and _open_reward_combine():
		return
	frontier_screen.show()
	frontier_screen.render(run, page)

func _place_frontier_screen(parent: Control) -> void:
	relic_focus_layer.visible = parent == relic_focus_layer and arena_screen.visible
	if frontier_screen.get_parent() != parent:
		frontier_screen.reparent(parent, false)
		frontier_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _set_reward_storage(docked: bool) -> void:
	var parent: Control = combat_sidebar if docked else storage_popup_layer
	if storage_screen.get_parent() != parent:
		storage_screen.reparent(parent, false)
		storage_screen.set_docked(docked)
		if not docked:
			storage_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	storage_screen.visible = docked

func _show_rewards() -> void:
	if not campaign or state != "finished":
		run_show_arena()
		state = "finished"
		if run.has_combat_reward():
			var saved_stats: Variant = run.data.get("combat_stats", {})
			if saved_stats is Dictionary:
				combat_meter.restore(saved_stats)
			arena.reset_view(sim.units.filter(func(unit: Dictionary): return unit.side == "hero"), lanes)
		else:
			arena.reset_view([], lanes)
	else:
		_read_run_loadout()
	if _open_reward_combine():
		arena_screen.hide()
		return
	showing_rewards = true
	_set_reward_storage(_placing_tile_reward())
	_rebuild_loadout()
	arena_screen.show()
	battle_stage.show()
	arena.show()
	forge_screen.hide()
	if lanes.size() > 1 and not run.elite_relic_offers().is_empty():
		_fit_relic_focus()
		_place_frontier_screen(relic_focus_layer)
	else:
		_place_frontier_screen(arena)
	frontier_screen.render(run, "", true)
	_update_controls()

func _leave_arena() -> void:
	if campaign:
		if _save_loadout():
			run_return()
		else:
			_show_inventory_message(run.save_error)
	elif not retry_result.is_empty():
		_return_to_battle_result()
	else:
		run_menu()

func run_menu() -> void:
	_show_frontier("menu")

func run_select_save_slot(slot: int) -> bool:
	if not run.select_save_slot(slot):
		return false
	run_menu()
	return true

func run_start_new_game_slot(slot: int, replace_existing: bool) -> bool:
	if not run.start_new_game_in_slot(slot, replace_existing):
		return false
	run_return()
	return true

func run_save_title() -> void:
	if run.save():
		run_menu()
	elif forge_screen.visible:
		forge_screen.show_error(run.save_error)
	elif campaign and state == "setup":
		_show_inventory_message(run.save_error)
	else:
		run_return()

func run_show_chart() -> void:
	_show_frontier("chart")

func run_return() -> void:
	if run.data.get("phase") == "combat":
		run_show_arena()
	elif run.data.get("phase") == "reward":
		_show_rewards()
	else:
		_show_frontier()

func run_start(seed_value := 0, difficulty := "easy", location := "brass") -> void:
	if run.start_run(seed_value, difficulty, location):
		run_return()
	else:
		run_menu()

func run_resume() -> void:
	run_return()

func run_practice() -> void:
	showing_rewards = false
	campaign = false
	camp_forge = false
	frontier_screen.hide()
	arena_screen.show()
	fixture_picker.select(0)
	_load_fixture("duo")

func run_show_arena(empty_arena := false) -> void:
	showing_rewards = false
	campaign = true
	encounter_setup = not empty_arena and run.data.phase == "combat"
	_read_run_loadout()
	frontier_screen.hide()
	_set_reward_storage(false)
	storage_screen.hide()
	forge_screen.hide()
	arena_screen.show()
	battle_stage.show()
	_reset_fight()
	if empty_arena:
		arena.reset_view([], lanes)

func run_rest_forge() -> void:
	camp_forge = true
	run_show_arena(true)
	_open_storage()

func _after_forge_upgrade() -> void:
	if campaign:
		camp_forge = camp_forge and (run.data.phase == "rest" or _traveling_smith_forge())
		run_show_arena(true)
	else:
		forge_close()
		arena.reset_view([], lanes)
	_open_storage()

func run_open_enchantment_loadout() -> void:
	run_show_arena()
	_open_storage()

func run_expand_reward_storage() -> void:
	if not _placing_tile_reward():
		return
	_set_reward_storage(false)
	storage_screen.show()
	_render_storage()

func run_open_reward_storage() -> void:
	var placement: Dictionary = run.current_reward_placement()
	run_show_arena()
	var row := int(placement.get("row", -1))
	if row >= 0 and row < storage_rows.size():
		for item: Dictionary in storage_rows[row]:
			if item.id == placement.id and int(item.start) == int(placement.start):
				selected = {"lane": -1, "row": row, "start": item.start, "id": item.id}
				break
	_open_storage()

func run_mystery_forge() -> void:
	if run.data.get("phase") == "event" and run.mystery_kind() == "traveling_smith":
		run_rest_forge()

func _traveling_smith_forge() -> bool:
	return camp_forge and run.data.get("phase") == "event" and run.mystery_kind() == "traveling_smith"

func _open_camp_forge() -> void:
	if _editing_camp_forge() or not camp_forge:
		return
	var blocker: String = run.camp_forge_blocker(selected)
	if not blocker.is_empty():
		_show_inventory_message(blocker)
		return
	var item := _selected_tile()
	if item.is_empty():
		return
	pending_forge = {"camp": selected.duplicate(), "camp_tile": item, "storage_open": storage_screen.visible}
	arena_screen.hide()
	storage_screen.hide()
	forge_screen.open(selected.id, 1)

func _commit_camp_forge(id: String, expected_plan: Variant) -> void:
	var source: Dictionary = pending_forge.camp
	var blocker: String = run.camp_forge_blocker(source)
	if not blocker.is_empty():
		forge_screen.show_error(blocker)
		return
	var plan: Dictionary = run.camp_forge_plan(source, id)
	if plan.is_empty():
		forge_screen.show_error("There is no room for this upgrade. Move or store a tile and try again.")
		return
	if expected_plan != null and expected_plan != plan:
		forge_screen.resume_layout()
		forge_screen.show_error("The layout changed. Review the new placement before confirming.")
		return
	if run.choose_camp_upgrade(source, id, plan):
		_after_forge_upgrade()
	else:
		forge_screen.show_error(run.save_error)

func _forge_target(id: String, previous: String) -> String:
	var valid: Array = ArenaSim.TILES[id].targets
	return previous if previous in valid or (previous in ArenaSim.CROWN_TARGET_RULES and "nearest" in valid) else valid[0]

func _combine_target(owned_lanes: Array, owned_storage: Array, copies: Array, destination: Dictionary, id: String) -> String:
	var source: Dictionary = destination if destination in copies else copies[0]
	var items: Array = owned_storage[source.row] if source.has("row") else owned_lanes[source.lane]
	for item: Dictionary in items:
		if item.start == source.start and item.id == source.id:
			return _forge_target(id, item.target)
	return ArenaSim.TILES[id].targets[0]

func _combine_enchantment_notice(owned_lanes: Array, owned_storage: Array, copies: Array,
		destination: Dictionary, upgrade: String) -> String:
	var result := TilePacking.combination_enchantments(owned_lanes, owned_storage, copies, destination, upgrade)
	var returned := PackedStringArray()
	for id: String in result.returned:
		returned.append(TileEnchantments.info(id).get("label", id))
	return "%s returned to storage." % ", ".join(returned) if not returned.is_empty() else ""

func _show_inventory_message(message: String) -> void:
	if storage_screen.visible:
		storage_screen.show_message(message)
	else:
		setup_hint.text = message

func _loot_destination(id: String, reward_lane := -1) -> Dictionary:
	var owned: Dictionary = run.loadout
	var heroes: Array = run.data.get("heroes", [])
	var destinations := range(owned.lanes.size()) if reward_lane < 0 else [reward_lane]
	for lane: int in destinations:
		if lane >= owned.lanes.size():
			continue
		if reward_lane < 0 and lane < heroes.size() and int(heroes[lane].hp) <= 0:
			continue
		for beat in range(ArenaSim.BEATS):
			if TilePacking.can_place(owned.lanes[lane], id, beat, ArenaSim.BEATS):
				return {"items": owned.lanes[lane], "start": beat, "lane": lane}
	for row in range(owned.storage.size()):
		for column in range(TilePacking.STORAGE_COLUMNS):
			if TilePacking.can_place(owned.storage[row], id, column, TilePacking.STORAGE_COLUMNS):
				return {"items": owned.storage[row], "start": column, "row": row}
	return {}

func _reward_placement(id: String, destination: Dictionary) -> Dictionary:
	var placement := {"id": id, "start": int(destination.start)}
	if destination.has("row"):
		placement.row = int(destination.row)
	else:
		placement.lane = int(destination.lane)
	return placement

func _claim_loot(id: String, commit: Callable, reward_lane := -1) -> bool:
	if not ArenaSim.TILES.has(id):
		return false
	var destination := _loot_destination(id, reward_lane)
	if destination.is_empty():
		return false
	var entry := _entry(id, destination.start, ArenaSim.TILES[id].targets[0])
	var items: Array = destination.items
	items.append(entry)
	items.sort_custom(func(a: Dictionary, b: Dictionary): return a.start < b.start)
	var was_suppressed: bool = run.loadout.suppressed.erase(id)
	if commit.call(id, _reward_placement(id, destination)):
		return true
	items.erase(entry)
	if was_suppressed:
		run.loadout.suppressed[id] = true
	return false

func _placing_tile_reward() -> bool:
	return showing_rewards and run.data.get("phase") == "reward" and not run.is_final_boss() and run.elite_relic_offers().is_empty()

func _can_edit_loadout() -> bool:
	return state == "setup" or _placing_tile_reward()

func _reward_can_target(id: String, lane: int) -> bool:
	return _placing_tile_reward() and id in run.data.offers and _pending_reward_id().is_empty() \
		and (lane < 0 or run.reward_lane() in [-1, lane])

func _drop_reward_on_timeline(id: String, lane: int, start: int, plan: Dictionary) -> bool:
	if _place_tile_reward(id, {"lane": lane, "start": start}, plan):
		return true
	_show_inventory_message(run.save_error if not run.save_error.is_empty() else "That reward could not be placed.")
	return false

func run_send_reward_to_storage(id: String) -> bool:
	if not _reward_can_target(id, -1):
		return false
	for row in range(storage_rows.size()):
		for column in range(TilePacking.STORAGE_COLUMNS):
			if TilePacking.can_place(storage_rows[row], id, column, TilePacking.STORAGE_COLUMNS):
				return _place_tile_reward(id, {"row": row, "start": column}, {"moves": {}})
	if run_can_combine_reward(id) and _begin_reward_combine(id, {"row": -1, "start": -1}):
		run_return()
		return true
	return false

func _place_tile_reward(id: String, placement: Dictionary, plan: Dictionary) -> bool:
	if plan.is_empty() or not _reward_can_target(id, int(placement.get("lane", -1))):
		return false
	var claimed: bool
	if run_can_combine_reward(id):
		claimed = _begin_reward_combine(id, placement)
	else:
		claimed = _commit_placed_reward(id, placement, plan)
	if claimed:
		selected.clear()
		run_return()
	return claimed

func _planned_reward_position(id: String, placement: Dictionary) -> Dictionary:
	var stored := placement.has("row")
	var index := int(placement.get("row", -1) if stored else placement.get("lane", -1))
	var rows: Array = run.loadout.storage if stored else run.loadout.lanes
	if index < 0 or index >= rows.size():
		return {}
	if stored:
		return TilePacking.nudge_plan(rows[index], id, int(placement.start), TilePacking.STORAGE_COLUMNS)
	return TilePacking.timeline_drop_plan(rows, run.loadout.storage, index, int(placement.start), {"id": id, "reward": true})

func _commit_placed_reward(id: String, placement: Dictionary, plan: Dictionary) -> bool:
	var before: Dictionary = run.loadout.duplicate(true)
	var items: Array = run.loadout.storage[int(placement.row)] if placement.has("row") else run.loadout.lanes[int(placement.lane)]
	_apply_stows(items, run.loadout.storage, plan)
	_apply_nudge(items, plan)
	items.append(_entry(id, int(placement.start), ArenaSim.TILES[id].targets[0]))
	items.sort_custom(func(a: Dictionary, b: Dictionary): return a.start < b.start)
	run.loadout.suppressed.erase(id)
	if run.reward(id, _reward_placement(id, placement)):
		return true
	_restore_inventory(before)
	return false

func _begin_reward_combine(id: String, placement := {}) -> bool:
	run.data.reward_combine = {"id": id, "placement": placement}
	if run.save():
		return true
	run.data.erase("reward_combine")
	return false

func run_claim_reward(id: String) -> bool:
	if not _pending_reward_id().is_empty():
		return false
	if id == "skip" or run.is_final_boss():
		return run.reward(id)
	if run_can_combine_reward(id):
		return _begin_reward_combine(id)
	return _claim_loot(id, run.reward, run.reward_lane())

func _pending_reward_id() -> String:
	return run.data.get("reward_combine", {}).get("id", "") if run.data.get("phase") == "reward" else ""

func _reward_combine_copies(id: String) -> Array:
	return TilePacking.find_copies(run.loadout.lanes, run.loadout.storage, id, _reward_combine_lanes())

func _reward_combine_lanes() -> Array:
	var lane: int = run.reward_lane()
	return range(run.loadout.lanes.size()) if lane < 0 else [lane]

func _reward_upgrade_plan(copies: Array, id: String) -> Dictionary:
	return TilePacking.combine_plan(run.loadout.lanes, run.loadout.storage, copies, 2, id, _reward_combine_lanes())

func run_can_combine_reward(id: String) -> bool:
	return run_reward_copy_status(id).get("completes_set", false)

func run_reward_copy_status(id: String) -> Dictionary:
	if run.data.get("phase") != "reward" or run.is_final_boss() or id not in run.data.offers or not run.elite_relic_offers().is_empty():
		return {}
	var options := TilePacking.next_options(id)
	if options.is_empty():
		return {}
	var copies := _reward_combine_copies(id)
	var completes_set := copies.size() >= 2 and options.any(
		func(upgrade: String): return not _reward_upgrade_plan(copies, upgrade).is_empty()
	)
	return {"owned": copies.size(), "completes_set": completes_set}

func _open_reward_combine() -> bool:
	var id := _pending_reward_id()
	if id.is_empty():
		return false
	if not run_can_combine_reward(id):
		run.data.erase("reward_combine")
		return false
	pending_forge = {"reward": id, "copies": _reward_combine_copies(id)}
	frontier_screen.hide()
	var placement: Dictionary = run.data.reward_combine.get("placement", {})
	var can_keep := not _loot_destination(id, run.reward_lane()).is_empty() if placement.is_empty() \
		else not _planned_reward_position(id, placement).is_empty()
	forge_screen.open(id, 3, true, can_keep)
	return true

func run_keep_reward_tile() -> bool:
	var id := _pending_reward_id()
	if id.is_empty():
		return false
	var placement: Dictionary = run.data.reward_combine.get("placement", {})
	if not placement.is_empty():
		var plan := _planned_reward_position(id, placement)
		return not plan.is_empty() and _finish_reward_combine(func(): return _commit_placed_reward(id, placement, plan))
	if _loot_destination(id, run.reward_lane()).is_empty():
		return false
	return _finish_reward_combine(func(): return _claim_loot(id, run.reward, run.reward_lane()))

func _claim_reward_upgrade(id: String) -> void:
	var source_id := _pending_reward_id()
	if id not in TilePacking.next_options(source_id):
		return
	var plan := _reward_upgrade_plan(pending_forge.copies, id)
	if plan.is_empty():
		forge_screen.show_error("Make room for the upgrade or return to the reward choices.")
		return
	var target := _combine_target(run.loadout.lanes, run.loadout.storage, plan.copies, plan.destination, id)
	var notice := _combine_enchantment_notice(run.loadout.lanes, run.loadout.storage, plan.copies, plan.destination, id)
	_finish_reward_combine(func():
		if not TilePacking.apply_combination(run.loadout.lanes, run.loadout.storage, plan.copies, plan.destination, id, target):
			return false
		run.loadout.suppressed.erase(source_id)
		run.loadout.suppressed.erase(id)
		if not notice.is_empty():
			run.data.enchantment_notice = notice
		return run.reward(source_id, _reward_placement(id, plan.destination)))

func _finish_reward_combine(claim: Callable) -> bool:
	var pending: Dictionary = run.data.reward_combine
	var inventory: Dictionary = run.loadout.duplicate(true)
	var previous_notice: String = run.data.get("enchantment_notice", "")
	run.data.erase("reward_combine")
	if claim.call():
		run_return()
		return true
	run.data.reward_combine = pending
	if previous_notice.is_empty():
		run.data.erase("enchantment_notice")
	else:
		run.data.enchantment_notice = previous_notice
	run.loadout = inventory
	forge_screen.show_error(run.save_error if not run.save_error.is_empty() else "This reward could not be claimed.")
	return false

func run_buy_shop(id: String) -> bool:
	if not ArenaSim.TILES.has(id):
		return run.shop_buy(id)
	return _claim_loot(id, run.shop_buy, run.shop_class_offer_lane(id))


func run_shop_placement_label(id: String) -> String:
	var destination := _loot_destination(id, run.shop_class_offer_lane(id))
	if destination.is_empty():
		return ""
	if destination.has("row"):
		return "Goes to tile storage"
	var heroes: Array = run.data.get("heroes", [])
	var hero_id: String = heroes[destination.lane].id if destination.lane < heroes.size() else run.data.get("hero", "")
	return "Goes to %s" % GameIcons.hero_label(hero_id)
