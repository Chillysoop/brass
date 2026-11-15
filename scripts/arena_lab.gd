extends Control

const ArenaSim = preload("res://scripts/arena_sim.gd")
const ArenaView = preload("res://scripts/arena_view.gd")
const StorageScreen = preload("res://scripts/storage_screen.gd")
const ForgeScreen = preload("res://scripts/forge_screen.gd")
const BattleReview = preload("res://scripts/battle_review.gd")
const GameIcons = preload("res://scripts/game_icons.gd")
const TilePacking = preload("res://scripts/tile_packing.gd")
const TileEnchantments = preload("res://scripts/tile_enchantments.gd")
const FrontierRun = preload("res://scripts/frontier_run.gd")
const FrontierScreen = preload("res://scripts/frontier_screen.gd")
const ArsenalTiles = preload("res://scripts/arsenal_tiles.gd")
const ClassExpansionTiles = preload("res://scripts/class_expansion_tiles.gd")
const ClassDecks = preload("res://scripts/class_decks.gd")
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
var forge_screen: Control
var storage_button: Button
var enchantment_button: Button
var relic_strip: HBoxContainer
var relic_badges: Dictionary = {}
var relic_pulses: Dictionary = {}
var lane_stack: VBoxContainer
var palette: HBoxContainer
var arsenal_button: Button
var arsenal_panel: PanelContainer
var arena
var fixture_picker: OptionButton
var speed_picker: OptionButton
var action: Button
var review_button: Button
var battle_review: Control
var reviewed_event: Dictionary = {}
var battle_name := ""
var battle_snapshot: Dictionary = {}
var retry_options: Dictionary = {}
var status: Label
var lane_health: Array[ProgressBar] = []
var colossus_status: Label
var relay_status: Label
var dock_status: Label
var setup_hint: Label
var playheads: Array[ColorRect] = []
var tile_cards: Array[Dictionary] = []
var edge_tick := 0
var edge_tiles: Dictionary = {}
var drag_board: Control
var drag_overlay: Control
var drag_pointer := Vector2.ZERO
var drag_preview_key: Array = []
var faded_cards: Array[Control] = []

func _ready() -> void:
	theme = _theme()
	_build()
	_load_fixture("duo")
	run.load_save()
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
	var title := _label("BRASS & AETHER", 26, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	fixture_picker = OptionButton.new()
	fixture_picker.add_item("Two heroes")
	fixture_picker.add_item("Solo hero")
	fixture_picker.add_item("Forge practice")
	fixture_picker.add_item("Blink forge practice")
	fixture_picker.add_item("Shot and Guard practice")
	fixture_picker.item_selected.connect(func(index: int): _load_fixture(["duo", "solo", "forge", "blink_forge", "build_forge"][index]))
	speed_picker = OptionButton.new()
	speed_picker.add_item("1× speed")
	speed_picker.add_item("2× speed")
	speed_picker.item_selected.connect(func(index: int): speed = index + 1)
	storage_button = _button("Tile storage", _toggle_storage)
	GameIcons.decorate(storage_button, "forge", 18)
	storage_button.tooltip_text = "Drag tiles between storage and timelines."
	reset_button = _button("Reset fight", _reset_fight)
	return_button = _button("Title", _leave_arena)
	review_button = _button("Battle review", _toggle_review)
	GameIcons.decorate(review_button, "review", 18)
	review_button.name = "OpenBattleReview"
	review_button.hide()
	action = _button("Start battle", _action)
	action.custom_minimum_size.x = 130
	action.add_theme_stylebox_override("normal", _box(Color("#59462f"), GOLD))
	header.add_child(action)

	arena = ArenaView.new()
	arena.name = "Battlefield"
	arena.custom_minimum_size.y = 290
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(arena)
	battle_review = BattleReview.new()
	battle_review.name = "BattleReview"
	battle_review.size_flags_vertical = Control.SIZE_EXPAND_FILL
	battle_review.close_requested.connect(_close_review)
	battle_review.retry_requested.connect(_retry_in_practice)
	battle_review.event_selected.connect(_review_event)
	battle_review.hide()
	stack.add_child(battle_review)
	var readout := HBoxContainer.new()
	readout.add_theme_constant_override("separation", 16)
	stack.add_child(readout)
	status = _label("", 15, GOLD)
	status.custom_minimum_size.x = 150
	readout.add_child(status)
	colossus_status = _label("", 15, GOLD)
	colossus_status.name = "ColossusStatus"
	colossus_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	colossus_status.hide()
	stack.add_child(colossus_status)
	relay_status = _label("", 15, TEAL)
	relay_status.name = "RelayStatus"
	relay_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	relay_status.hide()
	stack.add_child(relay_status)
	dock_status = _label("", 15, TEAL)
	dock_status.name = "DockStatus"
	dock_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	dock_status.hide()
	stack.add_child(dock_status)
	var sequence_bar := HBoxContainer.new()
	stack.add_child(sequence_bar)
	var sequence_label := _label("Timeline", 15, GOLD)
	sequence_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sequence_bar.add_child(sequence_label)
	relic_strip = HBoxContainer.new()
	relic_strip.add_theme_constant_override("separation", 5)
	sequence_bar.add_child(relic_strip)
	enchantment_button = _button("", _toggle_storage)
	enchantment_button.name = "OpenEnchantment"
	sequence_bar.add_child(enchantment_button)
	sequence_bar.add_child(storage_button)
	lane_stack = VBoxContainer.new()
	lane_stack.add_theme_constant_override("separation", 5)
	stack.add_child(lane_stack)
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
	tray.add_child(speed_picker)
	tray.add_child(review_button)
	tray.add_child(reset_button)
	tray.add_child(return_button)
	camp_button = _button("Forge selected", _open_camp_forge)
	camp_button.name = "ForgeSelected"
	tray.add_child(camp_button)
	setup_hint = _label("", 14, MUTED)
	setup_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(setup_hint)
	storage_screen = StorageScreen.new()
	arena.add_child(storage_screen)
	storage_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	storage_screen.configure(self)
	storage_screen.hide()
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
	_close_review()
	arsenal_panel.hide()
	state = "setup"
	edge_tick = 0
	edge_tiles.clear()
	selected.clear()
	pending_forge.clear()
	_start_sim()
	arena.reset_view(sim.units, lanes)
	_rebuild_loadout()
	_update_controls()

func _action() -> void:
	match state:
		"setup":
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
			if campaign:
				battle_name = str(run.data.get("node", {}).get("label", ""))
				battle_snapshot = {
					"options": run.encounter(), "lanes": lanes.duplicate(true),
					"storage": storage_rows.duplicate(true), "defaults": defaults.duplicate(),
					"suppressed": suppressed_combines.duplicate()
				}
			elif retry_options.is_empty():
				battle_name = "Arena Practice"
			_start_sim()
			arena.reset_view(sim.units, lanes)
			state = "running"
			_rebuild_loadout()
		"running": state = "paused"
		"paused": state = "running"
		"finished":
			if campaign:
				run_return()
				return
			_reset_fight()
	_update_controls()

func _physics_process(_delta: float) -> void:
	if state != "running":
		return
	edge_tick = 0
	edge_tiles.clear()
	var first_activation: int = sim.activations.size()
	for step_index in range(speed):
		var events: Array = sim.step()
		# At 2×, show the boundary for the frame even if it was the first of two steps.
		if sim.tick % ArenaSim.TICKS_PER_BEAT == 0:
			edge_tick = sim.tick
		arena.present(sim.units, events, sim.tick, sim.visual_cues, speed)
		for event: Dictionary in events:
			if event.kind == "relic_proc":
				_pulse_relic(event.tile)
		if not sim.outcome.is_empty():
			state = "finished"
			if campaign:
				var remaining_hp: Array[int] = []
				for index in range(lanes.size()):
					remaining_hp.append(sim.units[index].hp)
				run.finish_combat(sim.outcome == "victory", remaining_hp)
				if sim.outcome == "defeat":
					_open_review()
			break
	for index in range(first_activation, sim.activations.size()):
		var activation: Dictionary = sim.activations[index]
		if activation.status != "unavailable":
			edge_tiles[Vector2i(activation.lane, activation.start)] = true
	_update_controls()

func _update_controls() -> void:
	action.text = {"setup": "Start battle", "running": "Pause", "paused": "Resume", "finished": "Edit loadout"}[state]
	if campaign and (state == "finished" or not encounter_setup):
		action.text = "Back to smith" if _traveling_smith_forge() else "Continue"
	action.visible = true
	reset_button.visible = not campaign
	fixture_picker.visible = not campaign and retry_options.is_empty()
	return_button.visible = not campaign
	return_button.text = "Back to expedition" if not retry_options.is_empty() else "Title"
	camp_button.visible = camp_forge
	fixture_picker.disabled = state != "setup"
	storage_button.disabled = state != "setup"
	var enchantment := TileEnchantments.info(_active_enchantment())
	enchantment_button.visible = state == "setup" and not enchantment.is_empty()
	if enchantment_button.visible:
		enchantment_button.text = enchantment.label
		enchantment_button.tooltip_text = enchantment.description + "\nAssign or move this enchantment in Tile storage."
		GameIcons.decorate(enchantment_button, enchantment.icon, 18)
	var reviewing := battle_review.visible
	speed_picker.visible = not reviewing and (not campaign or (encounter_setup and state != "finished"))
	review_button.visible = state == "finished" and not reviewing
	palette.visible = state == "setup" and not campaign and retry_options.is_empty()
	arsenal_button.visible = palette.visible
	palette.get_parent().visible = not campaign or camp_forge or review_button.visible or speed_picker.visible
	setup_hint.visible = state == "setup"
	var cycle := ArenaSim.LOOP_TICKS
	var elapsed: int = sim.tick
	var display_tick := int(reviewed_event.get("tick", 0)) if reviewing else (edge_tick if edge_tick > 0 else elapsed)
	var progress := 0 if display_tick == 0 else 1 + (display_tick - 1) % cycle
	var beat := ceili(float(progress) / ArenaSim.TICKS_PER_BEAT)
	match state:
		"setup":
			status.text = "PRE-FIGHT SETUP" if not campaign or encounter_setup else "MANAGE TILES"
			if _traveling_smith_forge():
				status.text = "TRAVELING SMITH"
			if not retry_options.is_empty():
				status.text = "PRACTICE · " + battle_name
		"finished":
			status.text = "" if sim.outcome == "victory" else "Defeat"
			if campaign and sim.outcome == "victory" and run.data.node.type == "boss":
				var leg := int(run.data.get("segment", 1))
				status.text = run.data.node_notice if run.is_final_boss() else "Leg %d cleared" % leg
		_:
			status.text = "%s %02d / 12 · %.1fs" % ["Paused" if state == "paused" else "Beat", beat, elapsed / 60.0]
	status.get_parent().visible = not reviewing and not status.text.is_empty()
	for lane_index in range(lane_health.size()):
		var hero: Dictionary = sim.units[lane_index]
		lane_health[lane_index].value = hero.hp
		lane_health[lane_index].tooltip_text = "%s · %d / %d HP" % [hero.name, hero.hp, hero.max_hp]
	_update_colossus_status()
	_update_relay_status()
	_update_dock_status()
	if reviewing:
		colossus_status.hide()
		relay_status.hide()
		dock_status.hide()
	for head in playheads:
		head.visible = state != "setup" and (not reviewing or not reviewed_event.is_empty())
		var fraction := ArenaSim.loop_progress(display_tick)
		head.anchor_left = fraction
		head.anchor_right = fraction
		head.offset_left = -1
		head.offset_right = 1
	for lane_index in range(tile_cards.size()):
		for start: int in tile_cards[lane_index]:
			var card: Control = tile_cards[lane_index][start]
			var marker: Control = card.get_meta("timing_marker")
			var tile: Dictionary = card.get_meta("tile")
			marker.visible = (reviewing and reviewed_event.get("lane", -1) == lane_index
				and reviewed_event.get("start", -1) == start and reviewed_event.get("tile", "") == tile.id) \
				or (not reviewing and edge_tiles.has(Vector2i(lane_index, start)))

func _toggle_review() -> void:
	if battle_review.visible:
		_close_review()
	else:
		_open_review()

func _open_review() -> void:
	if state != "finished":
		return
	arena.hide()
	battle_review.open(sim.activations, sim.boss_events, sim.outcome, battle_name, campaign and not battle_snapshot.is_empty())
	_update_controls()

func _close_review() -> void:
	if not battle_review.visible:
		return
	battle_review.hide()
	reviewed_event.clear()
	arena.show()
	_update_controls()
	if review_button.is_visible_in_tree():
		review_button.grab_focus()

func _review_event(event: Dictionary) -> void:
	reviewed_event = event.duplicate()
	_update_controls()


func _retry_in_practice() -> void:
	if not campaign or battle_snapshot.is_empty():
		return
	var focus := reviewed_event.duplicate()
	_close_review()
	retry_options = battle_snapshot.options
	lanes = battle_snapshot.lanes
	storage_rows = battle_snapshot.storage
	defaults.assign(battle_snapshot.defaults)
	suppressed_combines = battle_snapshot.suppressed
	battle_snapshot.clear()
	campaign = false
	_reset_fight()
	if focus.get("lane", -1) >= 0 and focus.get("start", -1) >= 0:
		var card: Control = tile_cards[focus.lane].get(focus.start)
		if card != null and card.get_meta("tile").id == focus.tile:
			_select({"id": focus.tile, "lane": focus.lane, "start": focus.start})

func _update_colossus_status() -> void:
	colossus_status.hide()
	if not campaign or not encounter_setup or run.data.get("node", {}).get("boss_id") != "tempered_colossus":
		return
	for unit: Dictionary in sim.units:
		if unit.get("sprite") != "tempered_colossus":
			continue
		colossus_status.show()
		var stage: int = unit.get("colossus_stage", 0)
		var instruction := ""
		var color := GOLD
		match stage:
			1:
				instruction = "1 of 3 · Push or pull the Colossus."
			2, 3:
				var contributors: Array = [unit.get("colossus_first", ""), unit.get("colossus_second", "")]
				var eligible := PackedStringArray()
				for hero: Dictionary in sim.units:
					if hero.side == "hero" and hero.hp > 0 and hero.id not in contributors:
						eligible.append(hero.name)
				instruction = "%d of 3 · Hit with %s." % [stage, " or ".join(eligible)] if not eligible.is_empty() else "%d of 3 · A different hero must land the next hit." % stage
		if stage > 0:
			var remaining := maxi(0, int(unit.get("colossus_window_until", unit.get("intent_tick", 0))) - sim.tick)
			instruction = "Forge Sweep · %s  %.1f beats left" % [instruction, float(remaining) / ArenaSim.TICKS_PER_BEAT]
			if remaining <= 2 * ArenaSim.TICKS_PER_BEAT:
				color = RUST
		elif unit.get("colossus_shattered", false):
			instruction = "Armor shattered · Forge Sweep canceled."
			color = TEAL
		else:
			instruction = "Forge Sweep · Push or pull, then hit with each of your other two heroes in order."
		colossus_status.text = instruction
		colossus_status.tooltip_text = instruction
		colossus_status.add_theme_color_override("font_color", color)
		return

func _update_relay_status() -> void:
	relay_status.hide()
	if not campaign or not encounter_setup or run.data.get("location") != "crown":
		return
	var leader: Dictionary = {}
	var guard_alive := false
	var protected := PackedStringArray()
	for unit: Dictionary in sim.units:
		if unit.hp <= 0:
			continue
		if unit.get("sprite") in ["relay_captain", "relay_marshal", "crown_regent"]:
			leader = unit
		if unit.has("relay_link_target"):
			guard_alive = true
		if not str(unit.get("relay_shield_source", "")).is_empty():
			protected.append(unit.name)
	if leader.is_empty() and not guard_alive:
		return
	if leader.get("sprite") == "crown_regent":
		_update_regent_status(leader)
		return
	var cues := PackedStringArray()
	var color := TEAL
	var marshal: bool = leader.get("sprite") == "relay_marshal"
	if leader.get("relay_charge_active", false):
		var remaining := maxi(0, int(leader.get("intent_tick", 0)) - sim.tick)
		var beat_time := "%.1f beats left" % (float(remaining) / ArenaSim.TICKS_PER_BEAT)
		if marshal:
			cues.append("Linked Charge · %s · %s" % [_marshal_charge_instruction(leader), beat_time])
		else:
			cues.append("Relay Charge · Push or pull the Captain · " + beat_time)
		color = RUST if remaining <= 2 * ArenaSim.TICKS_PER_BEAT else GOLD
	elif not leader.is_empty():
		if marshal:
			cues.append("Linked Charge · Separate the Marshal from the Guard, then push the Marshal with another hero.")
		else:
			cues.append("Relay Charge · Interrupt with a push or pull when it begins.")
	if not protected.is_empty():
		cues.append("Shielded: " + ", ".join(protected))
	elif guard_alive:
		cues.append("Relay Guard · Links a nearby ally")
	var instruction := "  /  ".join(cues)
	relay_status.text = instruction
	relay_status.tooltip_text = instruction
	relay_status.add_theme_color_override("font_color", color)
	relay_status.show()

func _update_regent_status(regent: Dictionary) -> void:
	var active: bool = regent.get("relay_charge_active", false)
	var sources: Array = regent.get("relay_shield_sources", [])
	var breakers: Dictionary = regent.get("crown_breakers", {})
	var eligible := _eligible_hero_names(_live_regent_breakers(breakers))
	var guidance := "Use tile targeting to assign each Guard to a different hero. Save a push from your third hero for the Regent."
	var color := TEAL
	if regent.get("crown_charge_interrupted", false):
		guidance = "Interrupted · The Regent won't charge again."
	elif active:
		var remaining := maxi(0, int(regent.get("intent_tick", 0)) - sim.tick)
		guidance = "Displace a linked Guard" if not sources.is_empty() else "Push the Regent"
		if not eligible.is_empty():
			guidance += " with " + " or ".join(eligible)
		else:
			guidance = "No eligible hero remains to interrupt"
		guidance += " · %.1f beats left" % (float(remaining) / ArenaSim.TICKS_PER_BEAT)
		color = RUST if remaining <= 2 * ArenaSim.TICKS_PER_BEAT else GOLD
	relay_status.text = "%s · %s  /  %s" % [
		"Crown Charge", guidance, _regent_link_summary(regent, sources)]
	relay_status.tooltip_text = relay_status.text
	relay_status.add_theme_color_override("font_color", color)
	relay_status.show()

func _eligible_hero_names(excluded: Array) -> PackedStringArray:
	var names := PackedStringArray()
	for hero: Dictionary in sim.units:
		if hero.side == "hero" and hero.hp > 0 and hero.id not in excluded:
			names.append(hero.name)
	return names

func _live_regent_breakers(breakers: Dictionary) -> Array:
	var actors: Array = []
	for guard: Dictionary in sim.units:
		if guard.hp > 0 and breakers.has(guard.id):
			actors.append(breakers[guard.id])
	return actors

func _regent_link_summary(regent: Dictionary, sources: Array) -> String:
	var labels := PackedStringArray()
	for guard: Dictionary in sim.units:
		if not guard.has("relay_link_target"):
			continue
		var side := str(guard.name).get_slice(" ", 0)
		var note := "Unlinked"
		if guard.hp <= 0:
			note = "Defeated"
		elif guard.id in sources:
			note = "Linked"
		else:
			var delay: int = int(guard.get("relay_relink_tick", 0)) - sim.tick
			if delay > 0:
				note = "Relinks in %.1f beats" % (float(delay) / ArenaSim.TICKS_PER_BEAT)
		labels.append("%s: %s" % [side, note])
	if labels.is_empty():
		return "%s unshielded" % regent.name
	return "  ·  ".join(labels)

func _marshal_charge_instruction(marshal: Dictionary) -> String:
	match int(marshal.get("relay_combo_stage", 0)):
		1:
			return "1 of 2 · Pull or push the pair apart"
		2:
			var eligible := _eligible_hero_names([marshal.get("relay_breaker", "")])
			if not eligible.is_empty():
				return "2 of 2 · Push the Marshal with " + " or ".join(eligible)
			return "2 of 2 · A different hero must push the Marshal"
	return "Push the Marshal with any hero"

func _update_dock_status() -> void:
	dock_status.hide()
	if not campaign or not encounter_setup or run.data.get("location") != "moonwreck":
		return
	for unit: Dictionary in sim.units:
		if unit.hp <= 0:
			continue
		var instruction := ""
		var color := TEAL
		var remaining := maxi(0, int(unit.get("intent_tick", 0)) - sim.tick)
		var time := "%.1f beats left" % (float(remaining) / ArenaSim.TICKS_PER_BEAT)
		match unit.get("sprite", ""):
			"wreckmaster":
				match int(unit.get("wreckmaster_phase", 0)):
					1:
						instruction = "Harpoon · Pulls %s close · %s" % [_combatant_name(unit.intent, "the marked hero"), time]
						color = GOLD
					2:
						instruction = "Deck Slam · Hits inside the marked circle · %s" % time
						color = RUST
					_:
						instruction = "Harpoon → Deck Slam · Push after the pull to create distance, or Guard before impact."
			"tidekeeper":
				var phase: int = unit.get("tidekeeper_phase", 0)
				instruction = _tidekeeper_instruction(unit, phase)
				if phase > 0:
					instruction += " · " + time
					color = RUST if phase >= 2 and remaining <= 2 * ArenaSim.TICKS_PER_BEAT else GOLD
			"drowned_admiral":
				var phase: int = unit.get("admiral_phase", 0)
				instruction = _admiral_instruction(unit, phase)
				if phase > 0:
					instruction += " · " + time
					color = RUST if phase >= 2 and remaining <= 2 * ArenaSim.TICKS_PER_BEAT else GOLD
			"dock_winch":
				var ally: String = unit.get("dock_winch_ally", "")
				if not ally.is_empty():
					instruction = "Winch Pull · %s toward %s · Push or pull the Operator to interrupt · %s" % [
						_combatant_name(ally, "Bruiser"), _combatant_name(unit.intent, "your hero"), time]
					color = GOLD
				else:
					instruction = "Winch Operator · Can pull a bruiser toward your hero."
		if not instruction.is_empty():
			dock_status.text = instruction
			dock_status.tooltip_text = instruction
			dock_status.add_theme_color_override("font_color", color)
			dock_status.show()
			return

func _tidekeeper_instruction(unit: Dictionary, phase: int) -> String:
	match phase:
		1:
			return "Twin Harpoons · Pulls %s close" % _marked_hero_names(unit.get("tidekeeper_targets", []))
		2:
			return "Breakwater Slam · 1 of 2 · Push the Tidekeeper"
		3:
			var eligible := _eligible_hero_names([unit.get("tidekeeper_breaker", "")])
			if eligible.is_empty():
				eligible = _eligible_hero_names([])
			return "Breakwater Slam · 2 of 2 · Push or pull with " + " or ".join(eligible)
	return "Twin Harpoons → Breakwater Slam · Push with one hero, then push or pull with your other hero."

func _admiral_instruction(unit: Dictionary, phase: int) -> String:
	match phase:
		1:
			return "Undertow · Pulls %s close" % _marked_hero_names(unit.get("admiral_targets", []))
		2:
			if _eligible_hero_names([]).size() == 1:
				return "Undertow Sweep · Push the Admiral to interrupt"
			return "Undertow Sweep · 1 of 3 · Push the Admiral"
		3:
			var eligible := _eligible_hero_names([unit.get("admiral_breaker", "")])
			if eligible.is_empty():
				eligible = _eligible_hero_names([])
			if _eligible_hero_names([]).size() < 3:
				return "Undertow Sweep · Push or pull with " + " or ".join(eligible)
			return "Undertow Sweep · 2 of 3 · Pull with " + " or ".join(eligible)
		4:
			var eligible := _eligible_hero_names([unit.get("admiral_breaker", ""), unit.get("admiral_reverser", "")])
			if eligible.is_empty():
				eligible = _eligible_hero_names([])
			return "Undertow Sweep · 3 of 3 · Push with " + " or ".join(eligible)
	return "Undertow Sweep · Push, Pull, then push again, using a different hero for each step."

func _marked_hero_names(ids: Array) -> String:
	var names := PackedStringArray()
	for id: String in ids:
		names.append(_combatant_name(id, "a marked hero"))
	if names.size() > 2:
		return ", ".join(names.slice(0, names.size() - 1)) + " and " + names[-1]
	return " and ".join(names) if not names.is_empty() else "the marked heroes"

func _combatant_name(id: String, fallback: String) -> String:
	for unit: Dictionary in sim.units:
		if unit.id == id:
			return unit.name
	return fallback

func _party_has_tiles() -> bool:
	for index in range(lanes.size()):
		if int(sim.units[index].hp) > 0 and not lanes[index].is_empty():
			return true
	return false

func _rebuild_loadout() -> void:
	_clear_drag_preview()
	for child in lane_stack.get_children():
		lane_stack.remove_child(child)
		child.queue_free()
	for child in palette.get_children():
		palette.remove_child(child)
		child.queue_free()
	playheads.clear()
	tile_cards.clear()
	lane_health.clear()
	_rebuild_relic_strip()
	for lane_index in range(lanes.size()):
		_build_lane(lane_index)
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
	if camp_forge:
		setup_hint.text = "Select a tile to upgrade for free, then choose Forge selected." if _traveling_smith_forge() \
			else "Select an upgradeable tile, then choose Forge selected."
	else:
		setup_hint.text = "Drag tiles to slide neighbors aside. Tiles fire at their right edge."
	if storage_screen.visible:
		_render_storage()


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
	return "%s · %s · %s%s\n%s" % [tile.label, GameIcons.rarity_name(tile), GameIcons.tile_stats(tile), signature, tile.description]


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
	var equipped: Array = run.data.get("relics", []) if campaign else retry_options.get("relics", [])
	for id: String in equipped:
		var relic: Dictionary = FrontierRun.RELICS.get(id, {})
		if relic.is_empty():
			continue
		var badge := Button.new()
		GameIcons.decorate(badge, GameIcons.relic(id), 18)
		badge.custom_minimum_size = Vector2(30, 30)
		badge.tooltip_text = "%s\n%s" % [relic.label, relic.description]
		badge.focus_mode = Control.FOCUS_NONE
		badge.mouse_default_cursor_shape = Control.CURSOR_HELP
		relic_strip.add_child(badge)
		relic_badges[id] = badge


func _pulse_relic(id: String) -> void:
	var badge: Button = relic_badges.get(id)
	if not is_instance_valid(badge):
		return
	if relic_pulses.has(id) and relic_pulses[id].is_running():
		relic_pulses[id].kill()
	badge.self_modulate = Color("#ffca70")
	var pulse := badge.create_tween()
	pulse.tween_property(badge, "self_modulate", Color.WHITE, 0.5)
	relic_pulses[id] = pulse

func _build_lane(lane_index: int) -> void:
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
	var art: String = hero.get("sprite", GameIcons.portrait(hero.get("class", "warden")))
	portrait.texture = load("res://assets/%s.png" % art) as Texture2D
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(33, 33)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	profile.add_child(portrait)
	var health_column := VBoxContainer.new()
	health_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_column.add_theme_constant_override("separation", 2)
	profile.add_child(health_column)
	var hero_name := _label(hero.name, 15, TEAL)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	health_column.add_child(name_row)
	if not class_id.is_empty():
		name_row.add_child(GameIcons.hero_badge(class_id))
	name_row.add_child(hero_name)
	var health := ProgressBar.new()
	health.show_percentage = false
	health.max_value = hero.max_hp
	health.value = hero.hp
	health.custom_minimum_size.y = 7
	health.add_theme_stylebox_override("background", _box(INK, EDGE, 2))
	health.add_theme_stylebox_override("fill", _box(Color("#368d72"), TEAL, 2))
	health_column.add_child(health)
	lane_health.append(health)
	if campaign and run.data.get("location", "brass") == "glass":
		var ranged_damage := 0
		for item: Dictionary in lanes[lane_index]:
			if ArenaSim.is_ranged_tile(item.id):
				ranged_damage += int(ArenaSim.TILES[item.id].damage)
		hero_name.tooltip_text = "%d ranged damage · Foundry threat" % ranged_damage
	var all := _target_buttons(sim.target_rules("bash"), defaults[lane_index], func(rule: String): _set_all(lane_index, rule), true)
	identity.add_child(all)

	var board := Control.new()
	var cards := {}
	tile_cards.append(cards)
	var offers: Array = _combine_offers(lanes[lane_index]) if state == "setup" else []
	var offer_height := 0 if offers.is_empty() else 33
	var row_height := 69
	if lanes[lane_index].any(func(item: Dictionary):
		return ArenaSim.TILES[item.id].width == 1 and sim.target_rules(item.id).size() > 4
	):
		row_height += 20
	board.custom_minimum_size.y = row_height + offer_height
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(board)
	_drop_destination(board, board, lane_index, offer_height)
	for beat in range(ArenaSim.BEATS):
		var cell := _button(str(beat + 1), func(): _place_selected(lane_index, beat))
		cell.tooltip_text = "Place at beat %d" % (beat + 1)
		cell.disabled = state != "setup"
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
	var name_button := _button(tile_title, func(): _select(payload))
	var icon_key := GameIcons.tile(item.id, tile)
	GameIcons.decorate(name_button, icon_key, 15 if tile.width == 1 else 20)
	name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if tile.width == 1:
		name_button.add_theme_constant_override("h_separation", 3)
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
	_style_tile_button(name_button, tile, tint, active, 16, tile.width == 1, tile.damage > 0)
	name_button.disabled = state != "setup"
	card.add_child(name_button)
	_add_tile_badges(name_button, tile, _lane_hero_class(lane_index))
	_add_enchantment_badge(name_button, item)
	if tile.damage > 0:
		var amount := _label(str(int(tile.damage)), 12, CREAM)
		amount.name = "TileDamage"
		amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		name_button.add_child(amount)
		amount.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		amount.offset_left = -26
		amount.offset_right = -6
		amount.offset_top = -21
		amount.offset_bottom = -4
	_drag_source(name_button, payload, board, lane_index, offer_height)
	var available_rules: Array = sim.target_rules(item.id)
	var current_rule: String = item.target if item.target in available_rules else available_rules[0]
	var choose := func(rule: String):
		item.target = rule
		_save_loadout()
		var new_preview: Dictionary = sim.target_for(lane_index, item.id, item.target, item.get("enchantment", ""))
		name_button.tooltip_text = _tile_tooltip(lane_index, item, tile)
		setup_hint.text = "%s · %s" % [tile.label, new_preview.get("name", "No eligible target")]
	var target_group := ButtonGroup.new()
	var rule_rows := [available_rules]
	if tile.width == 1 and available_rules.size() > 4:
		rule_rows = [available_rules.slice(0, 4), available_rules.slice(4)]
	for rules: Array in rule_rows:
		var targets := _target_buttons(rules, current_rule, choose, false, target_group)
		card.add_child(targets)
		_drop_destination(targets, board, lane_index, offer_height)
		for target_button: Control in targets.get_children():
			if target_button is Button:
				_drop_destination(target_button, board, lane_index, offer_height)
	var marker := Panel.new()
	marker.name = "TimingMarker"
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rim := _box(Color(1, 0.83, 0.50, 0.15), GOLD)
	rim.set_border_width_all(2)
	marker.add_theme_stylebox_override("panel", rim)
	board.add_child(marker)
	marker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marker.anchor_left = float(item.start) / ArenaSim.BEATS
	marker.anchor_right = float(item.start + int(tile.width)) / ArenaSim.BEATS
	marker.offset_left = 2
	marker.offset_right = 0
	marker.offset_top = offer_height + 1
	marker.offset_bottom = -1
	marker.hide()
	card.set_meta("timing_marker", marker)


func _style_tile_button(button: Button, tile: Dictionary, tint: Color, active: bool,
		badge_space := 0, compact := false, show_damage := false) -> void:
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
		if show_damage:
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
		button.disabled = state != "setup" or rules.size() == 1
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
	var preview: Dictionary = sim.target_for(lane_index, item.id, rule, item.get("enchantment", ""))
	var owner := _lane_hero_class(lane_index)
	var origin := GameIcons.tile_origin(item.id, tile)
	var identity := "Equipped by %s" % sim.units[lane_index].name
	if not origin.is_empty() and origin != owner:
		identity += " · %s signature" % GameIcons.hero_label(origin)
	var tooltip := "%s · %s · %s\n%s\n%s\nFires on beat %d · %s" % [
		tile.label, GameIcons.rarity_name(tile), GameIcons.tile_stats(tile), identity, tile.description,
		item.start + tile.width, preview.get("name", "No target in range at setup")
	]
	var enchantment := TileEnchantments.info(item.get("enchantment", ""))
	if not enchantment.is_empty():
		tooltip += "\n%s · %s" % [enchantment.label, enchantment.description]
	return tooltip


func _lane_hero_class(lane: int) -> String:
	if lane < 0 or lane >= sim.units.size():
		return ""
	var hero: Dictionary = sim.units[lane]
	return hero.get("class", GameIcons.hero_class_for_label(hero.name))

func _set_all(lane_index: int, rule: String) -> void:
	defaults[lane_index] = rule
	var skipped := 0
	for item: Dictionary in lanes[lane_index]:
		if rule in sim.target_rules(item.id):
			item.target = rule
		else:
			skipped += 1
	_rebuild_loadout()
	_save_loadout()
	setup_hint.text = "Set compatible tiles to %s%s." % [
		LABELS[rule], " · %d unchanged" % skipped if skipped else ""
	]

func _select(payload: Dictionary) -> void:
	if state != "setup":
		return
	selected = {} if selected == payload else payload.duplicate()
	_rebuild_loadout()
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
		if state != "setup":
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
			if not data is Dictionary or state != "setup":
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
	board.add_child(drag_overlay)
	drag_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cards: Dictionary = tile_cards[lane_index]
	var source_lane := int(data.get("lane", -1))
	if source_lane >= 0 and source_lane < tile_cards.size() and tile_cards[source_lane].has(data.get("start", -1)):
		_fade_drag_card(tile_cards[source_lane][data.start])
	var moves: Dictionary = plan.get("moves", {})
	for original: int in moves:
		var card: Control = cards[original]
		_fade_drag_card(card)
		_add_drag_tile(card.get_meta("tile").id, moves[original], top, TEAL)
	_add_drag_tile(data.id, start, top, RUST if plan.is_empty() else GOLD, "No room" if plan.is_empty() else "")

func _add_drag_tile(id: String, start: int, top: int, accent: Color, copy := "") -> void:
	var tile: Dictionary = ArenaSim.TILES[id]
	var ghost := PanelContainer.new()
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.add_theme_stylebox_override("panel", _box(Color("#20323e"), accent))
	_add_span(drag_overlay, ghost, start, tile.width, top + 1, -1)
	ghost.offset_right = 0
	var firing_beat := start + int(tile.width)
	var timing := "Beat %d" % firing_beat if tile.width == 1 else "%s · Beat %d" % [tile.label, firing_beat]
	var caption := _label(timing if copy.is_empty() else copy, 13, accent)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.add_child(caption)

func _fade_drag_card(card: Control) -> void:
	card.modulate.a = 0.16
	faded_cards.append(card)
	var tile_back: Control = card.get_meta("tile_back", null)
	if tile_back != null:
		tile_back.modulate.a = 0.16
		faded_cards.append(tile_back)

func _clear_drag_preview() -> void:
	for card in faded_cards:
		if is_instance_valid(card):
			card.modulate.a = 1.0
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
	if state != "setup":
		return {}
	var ignored: int = payload.get("start", -1) if payload.get("lane", -1) == lane_index else -1
	return TilePacking.nudge_plan(lanes[lane_index], payload.get("id", ""), start, ArenaSim.BEATS, ignored)

func _can_place(payload: Dictionary, lane_index: int, start: int) -> bool:
	var ignored: int = payload.get("start", -1) if payload.get("lane", -1) == lane_index else -1
	return state == "setup" and TilePacking.can_place(lanes[lane_index], payload.get("id", ""), start, ArenaSim.BEATS, ignored)

func _place_selected(lane_index: int, beat: int) -> void:
	if selected.is_empty():
		setup_hint.text = "Select a tile first."
		return
	_place(selected, lane_index, beat)

func _place(payload: Dictionary, lane_index: int, start: int, nudge := false) -> void:
	var plan := _timeline_nudge_plan(lane_index, start, payload) if nudge else {}
	if (nudge and plan.is_empty()) or (not nudge and not _can_place(payload, lane_index, start)):
		setup_hint.text = "That tile overlaps another tile or extends beyond beat 12."
		return
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
	_apply_nudge(lanes[lane_index], plan)
	lanes[lane_index].append(entry)
	lanes[lane_index].sort_custom(func(a: Dictionary, b: Dictionary): return a.start < b.start)
	selected.clear()
	_rebuild_loadout()
	_save_loadout()

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
	if campaign:
		discard_dialog.dialog_text = "Discard %s for this run?" % ArenaSim.TILES[selected.id].label
		discard_dialog.popup_centered()
		return
	_discard_selected()

func _discard_selected() -> void:
	if state != "setup" or not selected.has("lane") or _take_tile(selected).is_empty():
		return
	selected.clear()
	_rebuild_loadout()
	_save_loadout()

func tile_spec(id: String) -> Dictionary:
	return ArenaSim.TILES.get(id, {})

func _open_storage() -> void:
	if state == "setup":
		arsenal_panel.hide()
		arena_screen.show()
		storage_screen.show()
		_render_storage()

func _toggle_storage() -> void:
	if storage_screen.visible:
		storage_close()
	else:
		_open_storage()

func storage_close() -> void:
	storage_screen.hide()
	arena_screen.show()
	_rebuild_loadout()

func _render_storage() -> void:
	var all_offers: Array[Dictionary] = []
	for row in range(storage_rows.size()):
		for offer in _combine_offers(storage_rows[row]):
			offer.row = row
			all_offers.append(offer)
	storage_screen.render(storage_rows, selected, all_offers, camp_forge, not _selected_combine_copies().is_empty(),
		_enchantment_controls())

func _active_enchantment() -> String:
	return run.active_enchantment() if campaign or not retry_options.is_empty() else ""

func _selected_tile() -> Dictionary:
	if not selected.has("lane"):
		return {}
	var items: Array = storage_rows[selected.row] if selected.has("row") else lanes[selected.lane]
	for item: Dictionary in items:
		if item.start == selected.start and item.id == selected.id:
			return item
	return {}

func _enchantment_host() -> Dictionary:
	for items: Array in lanes + storage_rows:
		for item: Dictionary in items:
			if item.has("enchantment"):
				return item
	return {}

func _enchantment_controls() -> Dictionary:
	var id := _active_enchantment()
	if id.is_empty():
		return {}
	var host := _enchantment_host()
	var item := _selected_tile()
	var eligible := TileEnchantments.is_eligible(id, tile_spec(item.get("id", "")), item.get("id", ""))
	var caption := "Enchant selected" if host.is_empty() else "Move to selected"
	if not host.is_empty() and is_same(host, item):
		caption = "Remove enchantment"
	return {"id": id, "host": tile_spec(host.get("id", "")).get("label", ""), "eligible": eligible, "button": caption}

func storage_enchant_selected() -> void:
	if state != "setup" or not storage_screen.visible:
		return
	var id := _active_enchantment()
	var item := _selected_tile()
	if not TileEnchantments.is_eligible(id, tile_spec(item.get("id", "")), item.get("id", "")):
		return
	var previous := _enchantment_host()
	previous.erase("enchantment")
	if not is_same(previous, item):
		item.enchantment = id
	if not _save_loadout():
		item.erase("enchantment")
		if not previous.is_empty():
			previous.enchantment = id
		storage_screen.show_message(run.save_error)
		return
	_rebuild_loadout()

func storage_pick(row: int, item: Dictionary) -> void:
	var payload := {"id": item.id, "lane": -1, "row": row, "start": item.start}
	selected = {} if selected == payload else payload
	_rebuild_loadout()

func storage_can_place(row: int, start: int, payload: Dictionary) -> bool:
	var ignored: int = payload.get("start", -1) if payload.get("row", -1) == row else -1
	return state == "setup" and TilePacking.can_place(storage_rows[row], payload.get("id", ""), start, TilePacking.STORAGE_COLUMNS, ignored)

func storage_nudge_plan(row: int, start: int, payload: Dictionary) -> Dictionary:
	if state != "setup":
		return {}
	var ignored: int = payload.get("start", -1) if payload.get("row", -1) == row else -1
	return TilePacking.nudge_plan(storage_rows[row], payload.get("id", ""), start, TilePacking.STORAGE_COLUMNS, ignored)

func storage_place(row: int, start: int, payload: Dictionary, nudge := false) -> void:
	var plan := storage_nudge_plan(row, start, payload) if nudge else {}
	if (nudge and plan.is_empty()) or (not nudge and not storage_can_place(row, start, payload)):
		storage_screen.show_message("That tile needs a clear span in one row.")
		return
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
	selected.clear()
	_rebuild_loadout()
	_save_loadout()

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
	if not selected.has("lane") or suppressed_combines.has(selected.id):
		return []
	return TilePacking.find_copies(lanes, storage_rows, selected.id, 3, range(lanes.size()), selected)

func storage_combine_selected() -> void:
	if state != "setup" or not storage_screen.visible:
		return
	var copies := _selected_combine_copies()
	if copies.is_empty():
		return
	pending_forge = {"inventory_copies": copies, "storage_open": true}
	arena_screen.hide()
	storage_screen.hide()
	forge_screen.open(selected.id)

func _commit_inventory_combine(id: String) -> void:
	var copies: Array = pending_forge.inventory_copies
	var destination := TilePacking.combine_destination(lanes, storage_rows, copies, id, range(lanes.size()))
	if destination.is_empty():
		return
	var target := _combine_target(lanes, storage_rows, copies, destination, id)
	if not TilePacking.apply_combination(lanes, storage_rows, copies, destination, id, target):
		return
	suppressed_combines.erase(id)
	selected.clear()
	_save_loadout()
	forge_close()

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

func _forge_family_available(id: String) -> bool:
	var family: String = ArenaSim.TILES.get(id, {}).get("family", "")
	return (not campaign and retry_options.is_empty()) or run.forge_family_available(family)

func _combine_offers(items: Array) -> Array[Dictionary]:
	return TilePacking.offers(items, suppressed_combines)

func _offer_combine(row: int, lane: int, start: int, accept: bool) -> void:
	if state != "setup":
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

func _cancel_decline() -> void:
	if decline_dialog.confirmed.is_connected(_decline_combine):
		decline_dialog.confirmed.disconnect(_decline_combine)
	pending_forge.clear()

func _decline_combine() -> void:
	if decline_dialog.canceled.is_connected(_cancel_decline):
		decline_dialog.canceled.disconnect(_cancel_decline)
	suppressed_combines[pending_forge.offer.id] = true
	_save_loadout()
	forge_close()

func forge_choose(id: String) -> void:
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
		_commit_camp_forge(id)
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
	var target := _combine_target(lanes, storage_rows, copies, copies[0], id)
	if not TilePacking.apply_combination(lanes, storage_rows, copies, copies[0], id, target):
		return
	suppressed_combines.erase(id)
	selected.clear()
	_save_loadout()
	forge_close()

func forge_can_fit(id: String) -> bool:
	if pending_forge.has("reward"):
		return not _reward_upgrade_destination(pending_forge.copies, id).is_empty()
	if pending_forge.has("inventory_copies"):
		return not TilePacking.combine_destination(lanes, storage_rows, pending_forge.inventory_copies, id, range(lanes.size())).is_empty()
	if pending_forge.has("camp"):
		var source: Dictionary = pending_forge.camp
		var stored := source.has("row")
		var items: Array = storage_rows[source.row] if stored else lanes[source.lane]
		var capacity := TilePacking.STORAGE_COLUMNS if stored else ArenaSim.BEATS
		return TilePacking.can_place(items, id, source.start, capacity, source.start)
	return int(ArenaSim.TILES[id].width) <= int(pending_forge.offer.width)

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

func forge_firing_beat(id: String) -> int:
	if pending_forge.has("reward"):
		var destination := _reward_upgrade_destination(pending_forge.copies, id)
		return 0 if destination.is_empty() or destination.has("row") else int(destination.start) + int(ArenaSim.TILES[id].width)
	if pending_forge.has("inventory_copies"):
		var destination := TilePacking.combine_destination(lanes, storage_rows, pending_forge.inventory_copies, id, range(lanes.size()))
		return 0 if destination.is_empty() or destination.has("row") else int(destination.start) + int(ArenaSim.TILES[id].width)
	if pending_forge.has("camp"):
		var source: Dictionary = pending_forge.camp
		return 0 if source.has("row") else int(source.start) + int(ArenaSim.TILES[id].width)
	return 0 if int(pending_forge.row) >= 0 else int(pending_forge.offer.start) + int(ArenaSim.TILES[id].width)

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

func _show_frontier(page := "") -> void:
	_close_review()
	state = "setup"
	campaign = false
	camp_forge = false
	battle_snapshot.clear()
	retry_options = {}
	arena_screen.hide()
	arsenal_panel.hide()
	storage_screen.hide()
	forge_screen.hide()
	pending_forge.clear()
	if page.is_empty() and _open_reward_combine():
		return
	frontier_screen.show()
	frontier_screen.render(run, page)

func _leave_arena() -> void:
	if campaign:
		_save_loadout()
		run_return()
	elif not retry_options.is_empty():
		run_return()
	else:
		run_menu()

func run_menu() -> void:
	_show_frontier("menu")

func run_show_chart() -> void:
	_show_frontier("chart")

func run_return() -> void:
	_show_frontier()

func run_start(seed_value := 0, difficulty := "easy", location := "brass") -> void:
	if run.start_run(seed_value, difficulty, location):
		run_return()
	else:
		run_menu()

func run_resume() -> void:
	run_return()

func run_practice() -> void:
	campaign = false
	camp_forge = false
	frontier_screen.hide()
	arena_screen.show()
	fixture_picker.select(0)
	_load_fixture("duo")

func run_show_arena() -> void:
	campaign = true
	encounter_setup = run.data.phase == "combat"
	lanes = run.loadout.lanes
	storage_rows = run.loadout.storage
	defaults.assign(run.loadout.defaults)
	suppressed_combines = run.loadout.suppressed
	frontier_screen.hide()
	storage_screen.hide()
	forge_screen.hide()
	arena_screen.show()
	_reset_fight()

func run_rest_forge() -> void:
	camp_forge = true
	run_show_arena()

func run_open_enchantment_loadout() -> void:
	run_show_arena()
	_open_storage()

func run_mystery_forge() -> void:
	if run.data.get("phase") == "event" and run.mystery_kind() == "traveling_smith":
		run_rest_forge()

func _traveling_smith_forge() -> bool:
	return camp_forge and run.data.get("phase") == "event" and run.mystery_kind() == "traveling_smith"

func _open_camp_forge() -> void:
	var smith := _traveling_smith_forge()
	if not camp_forge or (run.data.get("phase") != "rest" and not smith):
		return
	var id: String = selected.get("id", "")
	if not selected.has("lane") or TilePacking.next_options(id).is_empty():
		_show_inventory_message("Select a tile that has a forge upgrade.")
		return
	if not _forge_family_available(id):
		var family: String = ArenaSim.TILES[id].get("family", "")
		var unlock: Dictionary = FrontierRun.META_NODES[FrontierRun.FORGE_UNLOCKS[family]]
		_show_inventory_message("Unlock %s in the Aether Chart." % unlock.label)
		return
	if smith and run.mystery_smith_options(id).is_empty():
		_show_inventory_message("Choose a tile the smith can upgrade.")
		return
	pending_forge = {"camp": selected.duplicate(), "storage_open": storage_screen.visible}
	arena_screen.hide()
	storage_screen.hide()
	forge_screen.open(selected.id, 1)

func _commit_camp_forge(id: String) -> void:
	var source: Dictionary = pending_forge.camp
	if _traveling_smith_forge():
		if run.choose_mystery_upgrade(source, id):
			run_return()
		else:
			forge_screen.show_error(run.save_error if not run.save_error.is_empty() else "This tile cannot use that upgrade. Make room or choose another tile.")
		return
	if run.data.get("phase") != "rest" or not _forge_family_available(source.id) or id not in TilePacking.next_options(source.id):
		return
	var stored: bool = source.has("row")
	var items: Array = storage_rows[source.row] if stored else lanes[source.lane]
	if not forge_can_fit(id):
		forge_close()
		_show_inventory_message("Make room next to the tile for the wider upgrade.")
		return
	for item: Dictionary in items:
		if item.start == source.start and item.id == source.id:
			item.id = id
			item.target = _forge_target(id, item.target)
			TileEnchantments.keep_if_eligible(item, tile_spec(id))
			suppressed_combines.erase(id)
			pending_forge.clear()
			run.rest("forge")
			_save_loadout()
			run_return()
			return

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
				return {"items": owned.lanes[lane], "start": beat}
	for row: Array in owned.storage:
		for column in range(TilePacking.STORAGE_COLUMNS):
			if TilePacking.can_place(row, id, column, TilePacking.STORAGE_COLUMNS):
				return {"items": row, "start": column}
	return {}

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
	if commit.call(id):
		return true
	items.erase(entry)
	if was_suppressed:
		run.loadout.suppressed[id] = true
	return false

func run_claim_reward(id: String) -> bool:
	if not _pending_reward_id().is_empty():
		return false
	if id == "skip" or run.is_final_boss():
		return run.reward(id)
	if run_can_combine_reward(id):
		run.data.reward_combine = {"id": id}
		if run.save():
			return true
		run.data.erase("reward_combine")
		return false
	return _claim_loot(id, run.reward, run.reward_lane())

func _pending_reward_id() -> String:
	return run.data.get("reward_combine", {}).get("id", "") if run.data.get("phase") == "reward" else ""

func _reward_combine_copies(id: String) -> Array:
	if run.data.get("phase") != "reward" or run.is_final_boss() or id not in run.data.offers or not run.elite_relic_offers().is_empty():
		return []
	return TilePacking.find_copies(run.loadout.lanes, run.loadout.storage, id, 2, _reward_combine_lanes())

func _reward_combine_lanes() -> Array:
	var lane: int = run.reward_lane()
	return range(run.loadout.lanes.size()) if lane < 0 else [lane]

func _reward_upgrade_destination(copies: Array, id: String) -> Dictionary:
	return TilePacking.combine_destination(run.loadout.lanes, run.loadout.storage, copies, id, _reward_combine_lanes())

func run_can_combine_reward(id: String) -> bool:
	var copies := _reward_combine_copies(id)
	return copies.size() == 2 and TilePacking.next_options(id).any(
		func(upgrade: String): return not _reward_upgrade_destination(copies, upgrade).is_empty()
	)

func _open_reward_combine() -> bool:
	var id := _pending_reward_id()
	if id.is_empty():
		return false
	if not run_can_combine_reward(id):
		run.data.erase("reward_combine")
		run.save()
		return false
	pending_forge = {"reward": id, "copies": _reward_combine_copies(id)}
	frontier_screen.hide()
	forge_screen.open(id, 3, true, not _loot_destination(id, run.reward_lane()).is_empty())
	return true

func run_keep_reward_tile() -> bool:
	var id := _pending_reward_id()
	if id.is_empty() or _loot_destination(id, run.reward_lane()).is_empty():
		return false
	return _finish_reward_combine(func(): return _claim_loot(id, run.reward, run.reward_lane()))

func _claim_reward_upgrade(id: String) -> void:
	var source_id := _pending_reward_id()
	var copies: Array = pending_forge.copies
	if id not in TilePacking.next_options(source_id):
		return
	var destination := _reward_upgrade_destination(copies, id)
	if destination.is_empty():
		forge_screen.show_error("Make room for the upgrade or return to the reward choices.")
		return
	var target := _combine_target(run.loadout.lanes, run.loadout.storage, copies, destination, id)
	_finish_reward_combine(func():
		if not TilePacking.apply_combination(run.loadout.lanes, run.loadout.storage, copies, destination, id, target):
			return false
		run.loadout.suppressed.erase(source_id)
		run.loadout.suppressed.erase(id)
		return run.reward(source_id)
	)

func _finish_reward_combine(claim: Callable) -> bool:
	var pending: Dictionary = run.data.reward_combine
	var inventory: Dictionary = run.loadout.duplicate(true)
	run.data.erase("reward_combine")
	if claim.call():
		run_return()
		return true
	run.data.reward_combine = pending
	run.loadout = inventory
	forge_screen.show_error(run.save_error if not run.save_error.is_empty() else "This reward could not be claimed.")
	return false

func run_buy_shop(id: String) -> bool:
	if not ArenaSim.TILES.has(id):
		return run.shop_buy(id)
	return _claim_loot(id, run.shop_buy, run.shop_class_offer_lane(id))
