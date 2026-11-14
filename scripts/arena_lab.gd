extends Control

const ArenaSim = preload("res://scripts/arena_sim.gd")
const ArenaView = preload("res://scripts/arena_view.gd")
const StorageScreen = preload("res://scripts/storage_screen.gd")
const ForgeScreen = preload("res://scripts/forge_screen.gd")
const BattleReview = preload("res://scripts/battle_review.gd")
const TilePacking = preload("res://scripts/tile_packing.gd")
const FrontierRun = preload("res://scripts/frontier_run.gd")
const FrontierScreen = preload("res://scripts/frontier_screen.gd")
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

var sim = ArenaSim.new()
var run = FrontierRun.new()
var campaign := false
var encounter_setup := false
var camp_forge := false
var frontier_screen
var return_button: Button
var reset_button: Button
var camp_button: Button
var remove_button: Button
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
var lane_stack: VBoxContainer
var palette: HBoxContainer
var arena
var fixture_picker: OptionButton
var speed_picker: OptionButton
var action: Button
var review_button: Button
var battle_review: Control
var reviewed_event: Dictionary = {}
var battle_name := ""
var status: Label
var log_text: Label
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
var log_lines: Array[String] = []

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
	fixture_picker.item_selected.connect(func(index: int): _load_fixture(["duo", "solo", "forge", "blink_forge"][index]))
	header.add_child(fixture_picker)
	speed_picker = OptionButton.new()
	speed_picker.add_item("1× speed")
	speed_picker.add_item("2× speed")
	speed_picker.item_selected.connect(func(index: int): speed = index + 1)
	header.add_child(speed_picker)
	storage_button = _button("Tile storage", _open_storage)
	storage_button.tooltip_text = "Open storage. An equipped or practice tile stays selected for placement."
	header.add_child(storage_button)
	reset_button = _button("Reset fight", _reset_fight)
	header.add_child(reset_button)
	return_button = _button("Title", _leave_arena)
	header.add_child(return_button)
	review_button = _button("Battle review", _toggle_review)
	review_button.name = "OpenBattleReview"
	review_button.hide()
	header.add_child(review_button)
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
	battle_review.event_selected.connect(_review_event)
	battle_review.hide()
	stack.add_child(battle_review)
	var readout := HBoxContainer.new()
	readout.add_theme_constant_override("separation", 16)
	stack.add_child(readout)
	status = _label("", 15, GOLD)
	status.custom_minimum_size.x = 150
	readout.add_child(status)
	log_text = _label("", 15, MUTED)
	log_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	readout.add_child(log_text)
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
	lane_stack = VBoxContainer.new()
	lane_stack.add_theme_constant_override("separation", 5)
	stack.add_child(lane_stack)
	var tray := HBoxContainer.new()
	tray.add_theme_constant_override("separation", 6)
	stack.add_child(tray)
	tray.add_child(_label("Tiles", 15, GOLD))
	palette = HBoxContainer.new()
	palette.add_theme_constant_override("separation", 5)
	palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tray.add_child(palette)
	remove_button = _button("Remove selected", _remove_selected)
	tray.add_child(remove_button)
	camp_button = _button("Forge selected", _open_camp_forge)
	tray.add_child(camp_button)
	setup_hint = _label("", 14, MUTED)
	setup_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(setup_hint)
	storage_screen = StorageScreen.new()
	add_child(storage_screen)
	storage_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	storage_screen.configure(self)
	storage_screen.hide()
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
	suppressed_combines.clear()
	defaults.clear()
	for _lane_index in range(lanes.size()):
		defaults.append("nearest")
	_reset_fight()

func _entry(id: String, start: int, target: String) -> Dictionary:
	return {"id": id, "start": start, "target": target}

func _reset_fight() -> void:
	_close_review()
	state = "setup"
	edge_tick = 0
	edge_tiles.clear()
	selected.clear()
	pending_forge.clear()
	log_lines.clear()
	_start_sim()
	arena.reset_view(sim.units)
	_rebuild_loadout()
	_update_controls()

func _action() -> void:
	match state:
		"setup":
			if campaign and (not encounter_setup or not _party_has_tiles()):
				setup_hint.text = "Equip a tile on a living hero before starting the battle."
				return
			selected.clear()
			log_lines.clear()
			edge_tick = 0
			edge_tiles.clear()
			battle_name = str(run.data.get("node", {}).get("label", "")) if campaign else "Arena Practice"
			_start_sim()
			arena.reset_view(sim.units)
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
		arena.present(sim.units, events)
		for event in events:
			var line: String = event.get("message", "")
			if not line.is_empty():
				log_lines.push_front(line)
				if log_lines.size() > 8:
					log_lines.pop_back()
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
	if campaign and state == "finished":
		action.text = "Continue"
	action.visible = not campaign or encounter_setup
	reset_button.visible = not campaign
	fixture_picker.visible = not campaign
	return_button.text = "Return to run" if campaign else "Title"
	return_button.disabled = campaign and state in ["running", "paused"]
	camp_button.visible = camp_forge
	remove_button.text = "Discard selected" if campaign else "Remove selected"
	remove_button.disabled = state != "setup"
	fixture_picker.disabled = state != "setup"
	storage_button.disabled = state != "setup"
	var reviewing := battle_review.visible
	review_button.visible = state == "finished" and not reviewing
	status.get_parent().visible = not reviewing
	palette.get_parent().visible = not reviewing
	setup_hint.visible = not reviewing
	var cycle := ArenaSim.LOOP_TICKS
	var elapsed: int = sim.tick
	var display_tick := int(reviewed_event.get("tick", 0)) if reviewing else (edge_tick if edge_tick > 0 else elapsed)
	var progress := 0 if display_tick == 0 else 1 + (display_tick - 1) % cycle
	var beat := ceili(float(progress) / ArenaSim.TICKS_PER_BEAT)
	match state:
		"setup":
			status.text = "PRE-FIGHT SETUP" if not campaign or encounter_setup else "MANAGE TILES"
			log_text.text = "Try Pull · Farthest at beat 4, then Bash · Nearest at beat 6." if not campaign else _party_status()
		"finished":
			status.text = "%s · %.1fs" % [sim.outcome.to_upper(), elapsed / 60.0]
		_:
			status.text = "%s %02d / 12 · %.1fs" % ["Paused" if state == "paused" else "Beat", beat, elapsed / 60.0]
	if state != "setup" and not log_lines.is_empty():
		log_text.text = "   /   ".join(log_lines.slice(0, 3))
		log_text.tooltip_text = "\n".join(log_lines)
	else:
		log_text.tooltip_text = ""
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
	battle_review.open(sim.activations, sim.boss_events, sim.outcome, battle_name)
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

func _party_status() -> String:
	var parts := PackedStringArray()
	for index in range(lanes.size()):
		var hero: Dictionary = sim.units[index]
		parts.append("%s %d/%d HP" % [hero.name, hero.hp, hero.max_hp])
	parts.append("%d gold" % int(run.data.gold))
	return "  ·  ".join(parts)

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
	for lane_index in range(lanes.size()):
		_build_lane(lane_index)
	for id: String in ([] if campaign else PRACTICE_TILES):
		var tile: Dictionary = ArenaSim.TILES[id]
		var payload := {"id": id}
		var button := _button("%s · %d" % [tile.label, tile.width], func(): _select(payload))
		button.tooltip_text = tile.description
		button.disabled = state != "setup"
		if selected.get("id") == id and not selected.has("lane"):
			button.add_theme_stylebox_override("normal", _box(Color("#4d4430"), GOLD))
		_drag_source(button, payload)
		palette.add_child(button)
	if camp_forge:
		setup_hint.text = "Select an upgradeable tile, then choose Forge selected."
	else:
		setup_hint.text = "Drag tiles to slide neighbors aside. Tiles fire at their right edge."

func _build_lane(lane_index: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	lane_stack.add_child(row)
	var identity := VBoxContainer.new()
	identity.custom_minimum_size.x = 123
	identity.add_theme_constant_override("separation", 1)
	row.add_child(identity)
	var hero: Dictionary = sim.units[lane_index]
	var identity_label := "%s · Down" % hero.name if campaign and hero.hp <= 0 else str(hero.name)
	identity.add_child(_label(identity_label, 16, TEAL))
	if campaign and run.data.get("location", "brass") == "glass":
		var ranged_damage := 0
		for item: Dictionary in lanes[lane_index]:
			if item.id in ArenaSim.RANGED_TILES:
				ranged_damage += int(ArenaSim.TILES[item.id].damage)
		var ranged := _label("%d ranged damage" % ranged_damage, 12, MUTED)
		ranged.tooltip_text = "Total base damage from ranged tiles on this lane. Foundry hunters use it to choose a target."
		identity.add_child(ranged)
	var all := OptionButton.new()
	all.add_theme_font_size_override("font_size", 12)
	all.add_item("Set all targets")
	for target: String in sim.target_rules("bash"):
		all.add_item(LABELS[target])
		all.set_item_metadata(all.item_count - 1, target)
	all.tooltip_text = "Applies to compatible tiles and sets the default for newly placed tiles."
	all.disabled = state != "setup"
	all.item_selected.connect(func(index: int):
		if index > 0:
			_set_all(lane_index, all.get_item_metadata(index))
	)
	identity.add_child(all)

	var board := Control.new()
	var cards := {}
	tile_cards.append(cards)
	var offers: Array = _combine_offers(lanes[lane_index]) if state == "setup" else []
	var offer_height := 0 if offers.is_empty() else 33
	board.custom_minimum_size.y = 69 + offer_height
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
		_add_span(board, prompt, offer.start, offer.width, 0, -71)
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
	var name_button := _button(tile.label, func(): _select(payload))
	name_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	name_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_button.add_theme_font_size_override("font_size", 13)
	var tint := Color("#254949") if item.id in ["pull", "guard"] or tile.get("family") == "blink" else Color("#583b35")
	name_button.tooltip_text = _tile_tooltip(lane_index, item, tile)
	name_button.add_theme_stylebox_override("normal", _box(tint, GOLD if active else EDGE))
	name_button.add_theme_stylebox_override("disabled", _box(tint, EDGE))
	name_button.disabled = state != "setup"
	card.add_child(name_button)
	_drag_source(name_button, payload, board, lane_index, offer_height)
	var targets := OptionButton.new()
	targets.clip_text = true
	targets.fit_to_longest_item = false
	targets.add_theme_font_size_override("font_size", 11)
	var available_rules: Array = sim.target_rules(item.id)
	var current_rule: String = item.target if item.target in available_rules else available_rules[0]
	for rule: String in available_rules:
		targets.add_item(LABELS[rule])
		targets.set_item_metadata(targets.item_count - 1, rule)
		if current_rule == rule:
			targets.select(targets.item_count - 1)
	if "relay_regent" in available_rules:
		targets.tooltip_text = "Left Guard, Right Guard, and Crown Regent lock onto those units by name."
	elif item.target != current_rule:
		targets.tooltip_text = "This fight uses %s. Your saved Crown Regent target rule is kept." % LABELS[current_rule]
	targets.disabled = state != "setup" or targets.item_count == 1
	targets.item_selected.connect(func(index: int):
		item.target = targets.get_item_metadata(index)
		_save_loadout()
		var new_preview: Dictionary = sim.target_for(lane_index, item.id, item.target)
		name_button.tooltip_text = _tile_tooltip(lane_index, item, tile)
		setup_hint.text = "%s · %s" % [tile.label, new_preview.get("name", "No eligible target")]
	)
	card.add_child(targets)
	_drop_destination(targets, board, lane_index, offer_height)
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

func _tile_tooltip(lane_index: int, item: Dictionary, tile: Dictionary) -> String:
	var available_rules: Array = sim.target_rules(item.id)
	var rule: String = item.target if item.target in available_rules else available_rules[0]
	var preview: Dictionary = sim.target_for(lane_index, item.id, rule)
	return "%s\nFires on beat %d · %s" % [
		tile.description, item.start + tile.width, preview.get("name", "No target in range at setup")
	]

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
		var preview := _label(tile.label, 17, GOLD)
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
	var key := [lane_index, start, data.get("lane", -1), data.get("start", -1), data.id]
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
	var caption := _label(tile.label if copy.is_empty() else copy, 13, accent)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.add_child(caption)

func _fade_drag_card(card: Control) -> void:
	card.modulate.a = 0.16
	faded_cards.append(card)

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
	if payload.has("lane"):
		var original := _take_tile(payload)
		if original.is_empty():
			return
		target = original.target
	else:
		suppressed_combines.erase(payload.id)
	_apply_nudge(lanes[lane_index], plan)
	lanes[lane_index].append(_entry(payload.id, start, target))
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

func _remove_selected() -> void:
	if state != "setup" or selected.get("lane", -1) < 0:
		return
	_confirm_discard()

func _confirm_discard() -> void:
	if campaign:
		discard_dialog.dialog_text = "Discard %s for this run?" % ArenaSim.TILES[selected.id].label
		discard_dialog.popup_centered()
		return
	_discard_selected()

func _discard_selected() -> void:
	_take_tile(selected)
	selected.clear()
	if storage_screen.visible:
		_render_storage()
	else:
		_rebuild_loadout()
	_save_loadout()

func tile_spec(id: String) -> Dictionary:
	return ArenaSim.TILES.get(id, {})

func _open_storage() -> void:
	if state == "setup":
		arena_screen.hide()
		storage_screen.show()
		_render_storage()

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
	storage_screen.render(storage_rows, selected, all_offers, camp_forge)

func storage_pick(row: int, item: Dictionary) -> void:
	var payload := {"id": item.id, "lane": -1, "row": row, "start": item.start}
	selected = {} if selected == payload else payload
	_render_storage()

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
	var target: String = valid[0]
	if payload.has("lane"):
		var original := _take_tile(payload)
		if original.is_empty():
			return
		target = original.target
	else:
		suppressed_combines.erase(payload.id)
	_apply_nudge(storage_rows[row], plan)
	storage_rows[row].append(_entry(payload.id, start, target))
	storage_rows[row].sort_custom(func(a: Dictionary, b: Dictionary): return a.start < b.start)
	selected.clear()
	_render_storage()
	_save_loadout()

func storage_send_to_timeline() -> void:
	if selected.has("row"):
		storage_close()
		setup_hint.text = "Choose an empty starting beat for %s." % ArenaSim.TILES[selected.id].label
		lane_stack.get_child(0).get_child(1).get_child(0).grab_focus()

func storage_discard() -> void:
	if selected.has("row"):
		_confirm_discard()

func storage_forge() -> void:
	if camp_forge and selected.has("row"):
		_open_camp_forge()

func storage_combine(row: int, start: int, accept: bool) -> void:
	_offer_combine(row, -1, start, accept)

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
	return not campaign or ArenaSim.TILES.get(id, {}).get("family") != "blink" or "blink_artifice" in run.profile.meta

func _combine_offers(items: Array) -> Array[Dictionary]:
	return TilePacking.offers(items, suppressed_combines).filter(func(offer: Dictionary): return _forge_family_available(offer.id))

func _offer_combine(row: int, lane: int, start: int, accept: bool) -> void:
	if state != "setup":
		return
	var items: Array = storage_rows[row] if row >= 0 else lanes[lane]
	for offer in _combine_offers(items):
		if offer.start != start:
			continue
		pending_forge = {"row": row, "lane": lane, "offer": offer}
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
	var target := ""
	for index in range(items.size() - 1, -1, -1):
		var item: Dictionary = items[index]
		if item.start >= offer.start and item.start < offer.start + offer.width:
			target = item.target
			items.remove_at(index)
	items.append(_entry(id, offer.start, _forge_target(id, target)))
	items.sort_custom(func(a: Dictionary, b: Dictionary): return a.start < b.start)
	suppressed_combines.erase(id)
	selected.clear()
	_save_loadout()
	forge_close()

func forge_close() -> void:
	var from_storage: bool = pending_forge.get("row", -1) >= 0 or pending_forge.get("camp", {}).has("row")
	pending_forge.clear()
	forge_screen.hide()
	if from_storage:
		_open_storage()
	else:
		storage_close()

func _start_sim() -> void:
	arena.location = run.data.get("location", "brass") if campaign else "brass"
	if campaign:
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

func _save_loadout() -> void:
	if campaign:
		run.loadout = {"lanes": lanes, "storage": storage_rows, "defaults": defaults, "suppressed": suppressed_combines}
		run.save()

func _show_frontier(page := "") -> void:
	_close_review()
	state = "setup"
	campaign = false
	camp_forge = false
	arena_screen.hide()
	storage_screen.hide()
	forge_screen.hide()
	frontier_screen.show()
	frontier_screen.render(run, page)

func _leave_arena() -> void:
	if campaign:
		_save_loadout()
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

func _open_camp_forge() -> void:
	if not camp_forge or run.data.get("phase") != "rest":
		return
	var id: String = selected.get("id", "")
	if not selected.has("lane") or TilePacking.next_options(id).is_empty():
		_show_inventory_message("Select a tile that has a forge upgrade.")
		return
	if not _forge_family_available(id):
		_show_inventory_message("Unlock Blink Artifice in the Aether Chart to forge Blink.")
		return
	pending_forge = {"camp": selected.duplicate()}
	arena_screen.hide()
	storage_screen.hide()
	forge_screen.open(selected.id, 1)

func _commit_camp_forge(id: String) -> void:
	var source: Dictionary = pending_forge.camp
	if run.data.get("phase") != "rest" or not _forge_family_available(source.id) or id not in TilePacking.next_options(source.id):
		return
	var stored: bool = source.has("row")
	var items: Array = storage_rows[source.row] if stored else lanes[source.lane]
	var capacity := TilePacking.STORAGE_COLUMNS if stored else ArenaSim.BEATS
	if not TilePacking.can_place(items, id, source.start, capacity, source.start):
		forge_close()
		_show_inventory_message("Make room next to the tile for the wider upgrade.")
		return
	for item: Dictionary in items:
		if item.start == source.start and item.id == source.id:
			item.id = id
			item.target = _forge_target(id, item.target)
			suppressed_combines.erase(id)
			pending_forge.clear()
			run.rest("forge")
			_save_loadout()
			run_return()
			return

func _forge_target(id: String, previous: String) -> String:
	var valid: Array = ArenaSim.TILES[id].targets
	return previous if previous in valid or (previous in ArenaSim.CROWN_TARGET_RULES and "nearest" in valid) else valid[0]

func _show_inventory_message(message: String) -> void:
	if storage_screen.visible:
		storage_screen.show_message(message)
	else:
		setup_hint.text = message

func _loot_destination(id: String) -> Dictionary:
	var owned: Dictionary = run.loadout
	var heroes: Array = run.data.get("heroes", [])
	for lane in range(owned.lanes.size()):
		if lane < heroes.size() and int(heroes[lane].hp) <= 0:
			continue
		for beat in range(ArenaSim.BEATS):
			if TilePacking.can_place(owned.lanes[lane], id, beat, ArenaSim.BEATS):
				return {"items": owned.lanes[lane], "start": beat}
	for row: Array in owned.storage:
		for column in range(TilePacking.STORAGE_COLUMNS):
			if TilePacking.can_place(row, id, column, TilePacking.STORAGE_COLUMNS):
				return {"items": row, "start": column}
	return {}

func _claim_loot(id: String, commit: Callable) -> bool:
	if not ArenaSim.TILES.has(id):
		return false
	var destination := _loot_destination(id)
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
	if id == "skip" or run.is_final_boss():
		return run.reward(id)
	return _claim_loot(id, run.reward)

func run_buy_shop(id: String) -> bool:
	if not ArenaSim.TILES.has(id):
		return run.shop_buy(id)
	return _claim_loot(id, run.shop_buy)
