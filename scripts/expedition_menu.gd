extends Control

signal start_requested(seed: int, difficulty: String, location: String)
signal resume_requested
signal chart_requested
signal practice_requested
signal quit_requested
signal page_changed(page: String, location: String)

const INK := Color("#0d1826")
const NAVY := Color("#172733")
const BRASS := Color("#bc925b")
const GOLD := Color("#f0c987")
const IVORY := Color("#f4e9d2")
const MUTED := Color("#b7c2bd")
const TEAL := Color("#9de0d3")
const CORAL := Color("#e9a68d")
const REGIONS := {
	"brass": {
		"name": "Brass Frontier", "art": "region-brass.webp", "fallback": "frontier-map.webp",
		"description": "Cross the sunlit frontier to challenge its clockwork guardians.",
		"unlock": "", "implemented": true
	},
	"glass": {
		"name": "Glass Foundry", "art": "region-glass.webp", "fallback": "glass-map.webp",
		"description": "Enter a furnace district of glass hunters and molten automata.",
		"unlock": "Clear Brass Frontier Medium to unlock.", "implemented": true
	},
	"crown": {
		"name": "Crown Relay", "art": "region-crown.webp", "fallback": "",
		"description": "Storm a skyborne relay guarded by the Crown's signal keepers.",
		"unlock": "Clear Glass Foundry Medium to unlock.", "implemented": false
	},
	"moonwreck": {
		"name": "Moonwreck Docks", "art": "region-moonwreck.webp", "fallback": "",
		"description": "Explore the tidebound ruins of a fallen skyfleet.",
		"unlock": "Clear Crown Relay Medium to unlock.", "implemented": false
	}
}
const DIFFICULTIES := {
	"easy": {"bosses": "1 boss", "heroes": "1 hero", "recruit": "Lead the expedition alone."},
	"medium": {"bosses": "2 bosses", "heroes": "2 heroes", "recruit": "Recruit a second hero after the first boss."},
	"hard": {"bosses": "3 bosses", "heroes": "3 heroes", "recruit": "Recruit a hero after each of the first two bosses."}
}

var _run
var _page := "title"
var _location := "brass"
var _display_font := SystemFont.new()
var _focus_target: Control
var _seed_input: LineEdit
var _seed_warning: Label
var _start_buttons: Array[Button] = []
var _seed_text := ""


func _ready() -> void:
	_display_font.font_names = PackedStringArray(["Georgia", "Cambria"])


func render(model, page: String = "title", location: String = "brass") -> void:
	_run = model
	_seed_text = ""
	_show_page(page, location)


func _show_page(page: String, location: String = "brass") -> void:
	_page = page
	_location = location
	if _page == "difficulty" and (not REGIONS.has(_location) or not _run.can_start("easy", _location)):
		_page = "regions"
	_focus_target = null
	_seed_input = null
	_seed_warning = null
	_start_buttons.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	show()
	match _page:
		"regions": _regions()
		"difficulty": _difficulty()
		_: _title()
	if _focus_target != null:
		_focus_target.grab_focus.call_deferred()
	page_changed.emit(_page, _location)


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.is_action_pressed("ui_cancel"):
		return
	match _page:
		"regions": _show_page("title")
		"difficulty": _show_page("regions", _location)
		_: return
	get_viewport().set_input_as_handled()


func _title() -> void:
	_backdrop("title-art.webp", "arena.webp", 1.0)
	_gradient(self, [Color("#101c28"), Color(0.06, 0.10, 0.14, 0.89), Color(0.06, 0.10, 0.14, 0.12)], [0.0, 0.42, 0.72])
	var screen := _inset(self, 53, 38)
	var rows := _stack(14)
	screen.add_child(rows)
	var content := HBoxContainer.new()
	content.size_flags_vertical = SIZE_EXPAND_FILL
	rows.add_child(content)
	var left := _stack(11)
	left.custom_minimum_size.x = 438
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(left)
	var wordmark := _label("Brass &\nAether", 67, IVORY, true)
	wordmark.add_theme_color_override("font_shadow_color", Color("#0a121b"))
	wordmark.add_theme_constant_override("shadow_offset_x", 2)
	wordmark.add_theme_constant_override("shadow_offset_y", 3)
	left.add_child(wordmark)
	left.add_child(_rule())
	left.add_child(_space(13))
	var resumable: bool = not _run.data.is_empty()
	if resumable:
		var caption: String = "View run result" if _run.data.get("phase") == "result" else "Continue"
		var resume := _button(caption, func(): resume_requested.emit(), true)
		resume.name = "ContinueRun"
		left.add_child(resume)
		_focus_target = resume
		left.add_child(_label(_resume_caption(), 16, TEAL))
	var start := _button("New Expedition", func(): _show_page("regions"), not resumable)
	start.name = "NewExpedition"
	left.add_child(start)
	if _focus_target == null:
		_focus_target = start
	var chart := _button("Aether Chart", func(): chart_requested.emit())
	chart.name = "AetherChart"
	left.add_child(chart)
	var practice := _button("Arena Practice", func(): practice_requested.emit())
	practice.name = "ArenaPractice"
	left.add_child(practice)
	var quit := _button("Quit", func(): quit_requested.emit(), false, true)
	quit.name = "Quit"
	left.add_child(quit)
	var footer := _label("%d Aether Marks" % int(_run.profile.get("marks", 0)), 15, GOLD)
	rows.add_child(footer)
	if not _run.save_error.is_empty():
		rows.add_child(_label(_run.save_error, 15, CORAL))


func _regions() -> void:
	_backdrop("title-art.webp", "arena.webp", 0.26)
	var layout := _body()
	_header(layout, "Choose a region", "Title", func(): _show_page("title"))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 14)
	cards.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(cards)
	for id: String in REGIONS:
		var region: Dictionary = REGIONS[id]
		var available: bool = region.implemented and _run.can_start("easy", id)
		var status := _region_status(id, available)
		var card := _card(cards, available)
		var art := _art_frame(card, region.art, region.fallback, available, true)
		art.size_flags_vertical = SIZE_EXPAND_FILL
		var copy := _card_copy(card, 260)
		copy.add_child(_label(status, 13, TEAL if available else CORAL))
		copy.add_child(_label(region.name, 29, IVORY, true))
		copy.add_child(_wrap(region.description, 15, MUTED))
		var hint: String = _region_hint(id)
		var button := _button("Select region" if available else status, func(): _select_region(id), available)
		button.name = "Region_" + id
		button.disabled = not available
		button.tooltip_text = hint
		if not available:
			copy.add_child(_wrap(hint, 14, MUTED))
		var spacer := Control.new()
		spacer.size_flags_vertical = SIZE_EXPAND_FILL
		copy.add_child(spacer)
		copy.add_child(button)
		if available and (_focus_target == null or id == _location):
			_focus_target = button


func _select_region(location: String) -> void:
	if _run.can_start("easy", location):
		_show_page("difficulty", location)


func _difficulty() -> void:
	var region: Dictionary = REGIONS[_location]
	_backdrop(region.art, region.fallback, 0.25)
	var layout := _body()
	_header(layout, region.name, "Regions", func(): _show_page("regions", _location))
	layout.add_child(_label("Choose a difficulty", 21, GOLD))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 15)
	cards.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(cards)
	for difficulty: String in DIFFICULTIES:
		_difficulty_card(cards, difficulty)
	_seed_editor(layout)


func _difficulty_card(cards: HBoxContainer, difficulty: String) -> void:
	var spec: Dictionary = DIFFICULTIES[difficulty]
	var available: bool = _run.can_start(difficulty, _location)
	var status := _difficulty_status(difficulty, available)
	var card := _card(cards, available)
	var emblem := "difficulty-%s.webp" % difficulty
	var has_emblem := ResourceLoader.exists("res://assets/" + emblem)
	if has_emblem:
		_art_frame(card, emblem, "", available, false)
	var copy := _card_copy(card, 0, true)
	copy.size_flags_vertical = SIZE_EXPAND_FILL
	if not has_emblem:
		copy.add_child(_label(["◇", "✧", "✦"][DIFFICULTIES.keys().find(difficulty)], 42, GOLD))
	copy.add_child(_label(difficulty.capitalize(), 38, IVORY, true))
	copy.add_child(_label(status, 14, TEAL if available else CORAL))
	copy.add_child(_rule())
	copy.add_child(_label(spec.bosses + "  ·  " + spec.heroes, 19, IVORY))
	copy.add_child(_wrap(spec.recruit, 16, MUTED))
	var spacer := Control.new()
	spacer.size_flags_vertical = SIZE_EXPAND_FILL
	copy.add_child(spacer)
	var hint: String = _difficulty_hint(difficulty)
	if not available:
		copy.add_child(_wrap(hint, 14, MUTED))
	var button := _button("Start " + difficulty.capitalize() if available else status, func(): _launch(difficulty), available)
	button.name = "Difficulty_" + difficulty
	button.disabled = not available
	button.tooltip_text = hint
	copy.add_child(button)
	if available:
		_start_buttons.append(button)
		if _focus_target == null:
			_focus_target = button


func _seed_editor(layout: VBoxContainer) -> void:
	var section := HBoxContainer.new()
	section.add_theme_constant_override("separation", 13)
	layout.add_child(section)
	section.add_child(_label("Run seed", 16, GOLD))
	_seed_input = LineEdit.new()
	_seed_input.name = "RunSeed"
	_seed_input.placeholder_text = "Random unless entered"
	_seed_input.max_length = 10
	_seed_input.custom_minimum_size = Vector2(222, 40)
	_seed_input.text = _seed_text
	_seed_input.text_changed.connect(_seed_changed)
	section.add_child(_seed_input)
	_seed_warning = _label("", 14, CORAL)
	_seed_warning.size_flags_horizontal = SIZE_EXPAND_FILL
	section.add_child(_seed_warning)
	_seed_changed(_seed_text)


func _seed_changed(value: String) -> void:
	_seed_text = value
	var valid := _seed_is_valid()
	_seed_warning.text = "" if valid else "Enter a whole number from 1 to 4294967295."
	for button in _start_buttons:
		button.disabled = not valid


func _seed_is_valid() -> bool:
	var seed_value := _seed_text.strip_edges()
	return seed_value.is_empty() or (seed_value.is_valid_int() and int(seed_value) >= 1 and int(seed_value) <= 4294967295)


func _launch(difficulty: String) -> void:
	if _seed_is_valid() and _run.can_start(difficulty, _location):
		start_requested.emit(int(_seed_text), difficulty, _location)


func _resume_caption() -> String:
	var location: String = _run.data.get("location", "brass")
	var region: Dictionary = REGIONS.get(location, REGIONS.brass)
	return "%s  ·  %s" % [region.name, str(_run.data.get("difficulty", "easy")).capitalize()]


func _region_status(id: String, available: bool) -> String:
	if available:
		return "Available"
	return "Locked" if REGIONS[id].implemented else "Coming soon"


func _region_hint(id: String) -> String:
	if id == "crown" and _run.profile.get("crown_easy_unlocked", false):
		return "Unlocked. This region arrives in a future update."
	return REGIONS[id].unlock


func _difficulty_status(difficulty: String, available: bool) -> String:
	if not available:
		return "Coming soon" if _location == "glass" and difficulty == "hard" else "Locked"
	var profile_key := ""
	match _location:
		"brass":
			profile_key = {"easy": "medium_unlocked", "medium": "hard_unlocked", "hard": "brass_hard_cleared"}[difficulty]
		"glass":
			profile_key = {"easy": "glass_medium_unlocked", "medium": "glass_hard_unlocked"}.get(difficulty, "")
	return "Cleared" if _run.profile.get(profile_key, false) else "Available"


func _difficulty_hint(difficulty: String) -> String:
	if _location == "glass" and difficulty == "hard":
		if _run.profile.get("glass_hard_unlocked", false):
			return "Unlocked. Hard arrives in a future update."
		return "Clear Glass Foundry Medium to unlock when available."
	if difficulty == "easy":
		return "Begin a solo expedition."
	if difficulty == "medium":
		return "Clear %s Easy to unlock." % REGIONS[_location].name
	return "Clear %s Medium to unlock." % REGIONS[_location].name


func _backdrop(art: String, fallback: String, brightness: float) -> void:
	var base := ColorRect.new()
	base.color = INK
	base.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(base)
	base.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_image(self, art, fallback, Color(brightness, brightness, brightness))


func _gradient(parent: Control, colors: Array[Color], offsets: Array[float]) -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(offsets)
	gradient.colors = PackedColorArray(colors)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 512
	texture.height = 4
	var overlay := TextureRect.new()
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.texture = texture
	overlay.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)


func _image(parent: Control, file: String, fallback: String, tint: Color, stretch := TextureRect.STRETCH_KEEP_ASPECT_COVERED) -> void:
	var path := "res://assets/" + file
	if not ResourceLoader.exists(path):
		if fallback.is_empty():
			return
		path = "res://assets/" + fallback
		if not ResourceLoader.exists(path):
			return
	var picture := TextureRect.new()
	picture.texture = load(path)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = stretch
	picture.modulate = tint
	picture.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(picture)
	picture.set_anchors_and_offsets_preset(PRESET_FULL_RECT)


func _body() -> VBoxContainer:
	var margin := _inset(self, 44, 31)
	var layout := _stack(13)
	margin.add_child(layout)
	return layout


func _header(layout: VBoxContainer, title: String, back: String, callback: Callable) -> void:
	var row := HBoxContainer.new()
	layout.add_child(row)
	var label := _label(title, 48, IVORY, true)
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(label)
	var button := _button("‹  " + back, callback)
	button.name = "Back"
	button.custom_minimum_size.x = 122
	button.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(button)
	layout.add_child(_rule())


func _card(parent: Control, highlighted: bool) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	panel.size_flags_vertical = SIZE_EXPAND_FILL
	panel.custom_minimum_size.x = 160
	panel.add_theme_stylebox_override("panel", _box(Color("#182837"), BRASS if highlighted else Color("#53616a"), 10, 4))
	parent.add_child(panel)
	var contents := _stack(0)
	panel.add_child(contents)
	return contents


func _card_copy(card: VBoxContainer, minimum_height: int, expand := false) -> VBoxContainer:
	var padding := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 13)
	padding.custom_minimum_size.y = minimum_height
	if expand:
		padding.size_flags_vertical = SIZE_EXPAND_FILL
	card.add_child(padding)
	var copy := _stack(8)
	padding.add_child(copy)
	return copy


func _art_frame(parent: VBoxContainer, file: String, fallback: String, active: bool, portrait: bool) -> Control:
	var panel := Panel.new()
	panel.clip_contents = true
	panel.custom_minimum_size.y = 350 if portrait else 235
	var tint := Color.WHITE if active else Color("#a0a9ae")
	panel.add_theme_stylebox_override("panel", _box(Color("#101d28") * tint, BRASS, 6, 0))
	parent.add_child(panel)
	var stretch := TextureRect.STRETCH_KEEP_ASPECT_COVERED if portrait else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image(panel, file, fallback, tint, stretch)
	var edge := Panel.new()
	edge.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(edge)
	edge.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var metal := _box(Color.TRANSPARENT, BRASS if active else Color("#6d695e"), 4, 0)
	metal.set_border_width_all(2)
	edge.add_theme_stylebox_override("panel", metal)
	return panel


func _inset(parent: Control, x: int, y: int) -> MarginContainer:
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, x)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, y)
	parent.add_child(margin)
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	return margin


func _stack(separation: int) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", separation)
	return stack


func _space(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer


func _rule() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color("#9c744b")
	line.custom_minimum_size.y = 1
	line.mouse_filter = MOUSE_FILTER_IGNORE
	return line


func _wrap(value: String, points: int, color: Color) -> Label:
	var label := _label(value, points, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _label(value: String, points: int, color: Color, display := false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", color)
	if display:
		label.add_theme_font_override("font", _display_font)
	return label


func _button(caption: String, activate: Callable, primary := false, quiet := false) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 46
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.pressed.connect(activate)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", IVORY if not quiet else MUTED)
	button.add_theme_color_override("font_hover_color", IVORY)
	button.add_theme_color_override("font_disabled_color", MUTED)
	var fill := Color("#594027") if primary else NAVY
	var stroke := GOLD if primary else Color("#627379")
	button.add_theme_stylebox_override("normal", _box(fill, stroke, 5, 11))
	button.add_theme_stylebox_override("hover", _box(fill.lightened(0.18), GOLD, 5, 11))
	button.add_theme_stylebox_override("pressed", _box(fill.darkened(0.18), GOLD, 5, 11))
	button.add_theme_stylebox_override("disabled", _box(Color("#202b35"), Color("#425460"), 5, 11))
	var focus := _box(Color.TRANSPARENT, TEAL, 5, 0)
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	return button


func _box(fill: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style
