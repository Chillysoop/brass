extends Control

const FrontierRun = preload("res://scripts/frontier_run.gd")
const ArenaSim = preload("res://scripts/arena_sim.gd")
const ExpeditionMenu = preload("res://scripts/expedition_menu.gd")
const AetherChartMenu = preload("res://scripts/aether_chart_menu.gd")
const GameIcons = preload("res://scripts/game_icons.gd")
const ClassDecks = preload("res://scripts/class_decks.gd")
const INK := Color("#101820")
const PANEL := Color("#182632")
const PANEL_DARK := Color("#111f2a")
const EDGE := Color("#40515c")
const CREAM := Color("#f3e7d1")
const GOLD := Color("#ecc482")
const MUTED := Color("#aababc")
const TEAL := Color("#9ddbd1")
const RUST := Color("#e8a28b")
const TYPE_GLYPHS := {
	"battle": "×", "opening": "×", "elite": "◆", "shop": "◈", "event": "?", "rest": "+", "boss": "✦"
}
const TYPE_NAMES := {
	"battle": "Battle", "opening": "Opening battle", "elite": "Elite", "shop": "Shop",
	"event": "Event", "rest": "Rest site", "boss": "Boss"
}
const BOSS_BRIEFS := {
	"gilded_marshal": {
		"portrait": "marshal",
		"hint": "A push or pull exposes the Marshal's plating for three beats. Land a hit with another hero during that window to shatter it."
	},
	"iron_regent": {
		"portrait": "regent",
		"hint": "When the Regent raises its seals, land hits from all three heroes within four beats to break its defenses and cancel its sweep."
	},
	"crucible_twins": {
		"portrait": "glass_twin",
		"hint": "Glass keeps its distance while Ember closes in. Use your targeting rules to focus one twin before turning on the other."
	},
	"prism_warden": {
		"portrait": "prism_warden",
		"hint": "Push or pull the Warden, then strike with your other hero within three beats to shatter the prism ward. Give guard to your ranged leader and the hero with the lowest HP."
	},
	"tempered_colossus": {
		"portrait": "tempered_colossus",
		"hint": "When Forge Sweep begins, push or pull the Colossus with one hero. Hit with a different hero, then with your third hero. All three actions must land in order during the same nine-beat window. Shatter its armor to stop the sweep."
	},
	"relay_captain": {
		"portrait": "relay_captain",
		"hint": "Relay Charge begins on beat 2 and strikes at the end of beat 7. Land Bash or another push or pull within that window to interrupt it."
	},
	"relay_marshal": {
		"portrait": "relay_marshal",
		"hint": "When Linked Charge starts, use Pull to separate the Marshal from its Guard. Then land Bash with your other hero before the charge finishes. Pushes can also separate the pair, and if the Guard falls, any hero can interrupt with a push."
	},
	"crown_regent": {
		"portrait": "crown_regent",
		"hint": "Crown Charge starts on beat 2 and strikes at the end of beat 9. Use a different hero to displace each Guard, then push the Regent with your third hero before the links return. Use Left Guard, Right Guard, and Crown Regent in the tile targeting menu."
	},
	"wreckmaster": {
		"portrait": "wreckmaster",
		"hint": "Harpoon pulls its target close at the end of beat 3. Deck Slam hits inside the marked circle at the end of beat 6. Time a push between them to create distance, or use Guard before impact."
	},
	"tidekeeper": {
		"portrait": "tidekeeper",
		"hint": "Twin Harpoons pull both heroes close at the end of beat 3. Before Breakwater Slam strikes at the end of beat 8, push the Tidekeeper with one hero, then push or pull it with the other. If only one hero is standing, they can do both."
	},
	"drowned_admiral": {
		"portrait": "drowned_admiral",
		"hint": "Undertow draws your party in at the end of beat 3. Before the sweep lands at the end of beat 9, push the Admiral with one hero, pull with another, then push with the third. A smaller surviving party can interrupt in fewer steps."
	}
}
const MAP_ART := {
	"brass": "res://assets/frontier-map.webp",
	"glass": "res://assets/glass-map.webp",
	"crown": "res://assets/crown-map.webp",
	"moonwreck": "res://assets/moonwreck-map.webp",
}
const ENEMY_HINTS := {
	"brass_sapper": "Marks the ground before firing.",
	"glass_duelist": "Blinks toward the weakest hero.",
	"crown_mender": "Repairs wounded allies.",
	"dock_corsair": "Hooks a hero into melee range.",
	"dock_winch": "Pulls a bruiser into striking range.",
	"relay_guard": "Shields a nearby ally.",
}
const ELITE_RELIC_TONES := {
	"afterimage": Color("#c8b7ec"), "barrage_rack": Color("#efbe8a"), "siege_fuse": Color("#9ddbd1"),
}

var _host
var _run
var _layout: VBoxContainer
var _top_actions: HBoxContainer
var _bottom_actions: HBoxContainer
var _expedition_menu: ExpeditionMenu
var _aether_chart: AetherChartMenu
var _display_font: SystemFont


func configure(host: Control) -> void:
	_host = host
	_display_font = SystemFont.new()
	_display_font.font_names = PackedStringArray(["Georgia", "Cambria"])
	_expedition_menu = ExpeditionMenu.new()
	_expedition_menu.name = "ExpeditionMenu"
	add_child(_expedition_menu)
	_expedition_menu.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_expedition_menu.start_requested.connect(_start_new_run)
	_expedition_menu.resume_requested.connect(_host.run_resume)
	_expedition_menu.chart_requested.connect(_host.run_show_chart)
	_expedition_menu.practice_requested.connect(_host.run_practice)
	_expedition_menu.quit_requested.connect(func(): get_tree().quit())
	_aether_chart = AetherChartMenu.new()
	_aether_chart.name = "AetherChartMenu"
	add_child(_aether_chart)
	_aether_chart.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_aether_chart.purchase_requested.connect(_buy_chart_node)
	_aether_chart.back_requested.connect(_host.run_menu)


func render(model, page_override: String = "") -> void:
	_run = model
	for child in get_children():
		if child in [_expedition_menu, _aether_chart]:
			child.hide()
			continue
		remove_child(child)
		child.queue_free()
	show()
	var phase: String = page_override if not page_override.is_empty() else _run.data.get("phase", "menu")
	if phase == "menu":
		_expedition_menu.show()
		_expedition_menu.render(_run)
		return
	if phase == "chart":
		_aether_chart.show()
		_chart()
		return
	_shell(phase)
	match phase:
		"hero", "relic", "starter", "recruit", "recruit_starter": _draft(phase)
		"map": _map()
		"combat": _combat()
		"reward": _reward()
		"shop": _shop()
		"event": _event()
		"rest": _rest()
		"result": _result()
	if phase != "result":
		var footer := _footer_actions()
		var save_title := _button("Save & title", func(): _host.run_menu())
		footer.add_child(save_title)
		footer.move_child(save_title, 0)
	_layout.modulate.a = 0.70
	create_tween().tween_property(_layout, "modulate:a", 1.0, 0.16)


func _shell(phase: String) -> void:
	var base := ColorRect.new()
	base.color = INK
	base.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(base)
	base.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 37)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 25)
	_layout = VBoxContainer.new()
	_bottom_actions = null
	_layout.add_theme_constant_override("separation", 13)
	margin.add_child(_layout)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	_layout.add_child(bar)
	var title := _label("BRASS & AETHER", 19, GOLD)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	bar.add_child(title)
	if phase != "result":
		for member: Dictionary in _party():
			var member_id: String = member.get("id", "")
			var hp_text := "%d / %d HP" % [int(member.hp), int(member.max_hp)]
			if not member_id.is_empty():
				hp_text = _hero_name(member_id) + "  " + hp_text
			bar.add_child(_label(hp_text, 15, TEAL if int(member.hp) > 0 else RUST))
		bar.add_child(_label("%d gold" % int(_run.data.get("gold", 0)), 15, GOLD))
	_top_actions = HBoxContainer.new()
	_top_actions.add_theme_constant_override("separation", 8)
	bar.add_child(_top_actions)
	if not _run.save_error.is_empty():
		_layout.add_child(_label(_run.save_error, 15, RUST))


func _start_new_run(seed_value: int, difficulty: String, location: String) -> void:
	if not _run.can_start(difficulty, location):
		return
	if _run.data.is_empty():
		_host.run_start(seed_value, difficulty, location)
		return
	if _run.data.get("phase") == "result":
		_run.finish_run()
		_host.run_start(seed_value, difficulty, location)
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Start a new run?"
	dialog.dialog_text = "Starting a new run replaces your current expedition."
	dialog.ok_button_text = "Start new run"
	dialog.confirmed.connect(func():
		_run.abandon_run()
		_host.run_start(seed_value, difficulty, location)
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func _draft(phase: String) -> void:
	var recruit_rank := "third" if _party().size() == 2 else "second"
	var title: String = {
		"hero": "Choose your hero", "relic": "Choose a starter relic", "starter": "Choose your first tile",
		"recruit": "Recruit your %s hero" % recruit_rank, "recruit_starter": "Equip your recruit"
	}[phase]
	var subtitle: String = {
		"recruit": "New recruits join at full health.",
	}.get(phase, "")
	if phase in ["starter", "recruit_starter"]:
		subtitle = _hero_name(_run.data.get("pending_recruit", _run.data.get("hero", "")))
	_page_title(title, subtitle)
	var cards := _cards_row()
	var offers: Array = _run.data.get("offers", [])
	if phase == "relic" and not _run.build_relic_offers().is_empty():
		var switch := _button("Classic relics", func(): _toggle_relic_draft(cards))
		switch.name = "RelicDraftSwitch"
		_footer_actions().add_child(switch)
		offers = _run.build_relic_offers()
	_add_draft_cards(cards, offers, phase)


func _toggle_relic_draft(cards: HBoxContainer) -> void:
	var switch := _bottom_actions.get_node("RelicDraftSwitch") as Button
	var show_classic := switch.text == "Classic relics"
	switch.text = "Build relics" if show_classic else "Classic relics"
	for card in cards.get_children():
		cards.remove_child(card)
		card.queue_free()
	var offers: Array = _run.data.get("offers", []) if show_classic else _run.build_relic_offers()
	_add_draft_cards(cards, offers, "relic")


func _add_draft_cards(cards: HBoxContainer, offers: Array, phase: String) -> void:
	for id: String in offers:
		var entry: Dictionary
		match phase:
			"hero", "recruit": entry = FrontierRun.HEROES[id]
			"relic": entry = FrontierRun.RELICS[id]
			_: entry = ArenaSim.TILES[id]
		var info := _tile_info(entry) if phase in ["starter", "recruit_starter"] else str(entry.get("description", ""))
		var card := _choice(cards, entry.label, info, "Choose", func(): _pick_draft(phase, id))
		if phase in ["hero", "recruit"]:
			_add_portrait(card, GameIcons.portrait(id), 205)
			var deck := _label(ClassDecks.summary(id), 15, TEAL)
			deck.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card.add_child(deck)
			card.move_child(deck, 2)
			var deck_button := _button("View class deck", func(): _show_class_deck(id))
			deck_button.name = "ClassDeck_" + id
			GameIcons.decorate(deck_button, "review", 17)
			card.add_child(deck_button)
			card.move_child(deck_button, card.get_child_count() - 2)
		elif phase == "relic":
			_add_card_icon(card, GameIcons.relic(id))
		else:
			var hero_id: String = _run.data.get("pending_recruit", _run.data.get("hero", ""))
			_add_tile_header(card, id, entry, hero_id)
			if id == ClassDecks.starter(hero_id):
				var badge := _label("Class starter", 15, TEAL)
				card.add_child(badge)
				card.move_child(badge, 3)


func _show_class_deck(hero_id: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "%s deck" % _hero_name(hero_id)
	dialog.ok_button_text = "Close"
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.add_theme_stylebox_override("panel", _box(PANEL_DARK, EDGE, 10, 17))
	add_child(dialog)
	var deck := VBoxContainer.new()
	deck.add_theme_constant_override("separation", 7)
	dialog.add_child(deck)
	var common: Array = ClassDecks.common(hero_id)
	var uncommon: Array = ClassDecks.uncommon(hero_id)
	var signature: String = ClassDecks.signature(hero_id)
	var details := _label("", 15, CREAM)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size = Vector2(640, 42)
	for pool in [common, uncommon]:
		var rarity_spec: Dictionary = ArenaSim.TILES[pool[0]]
		var heading := HBoxContainer.new()
		heading.add_theme_constant_override("separation", 8)
		deck.add_child(heading)
		heading.add_child(GameIcons.hero_badge(hero_id, false))
		var rarity := GameIcons.rarity_badge(rarity_spec)
		rarity.text += "  ·  %d" % pool.size()
		rarity.add_theme_font_size_override("font_size", 16)
		heading.add_child(rarity)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 9)
		grid.add_theme_constant_override("v_separation", 4)
		deck.add_child(grid)
		for tile_id: String in pool:
			var spec: Dictionary = ArenaSim.TILES[tile_id]
			var tile := Button.new()
			tile.text = "%s  ·  %s" % [spec.label, GameIcons.tile_stats(spec).replace("damage", "dmg")]
			tile.custom_minimum_size.y = 30
			tile.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			tile.size_flags_horizontal = SIZE_EXPAND_FILL
			tile.tooltip_text = "%s · %s\n%s" % [_hero_name(hero_id), GameIcons.rarity_name(spec), spec.description]
			tile.mouse_default_cursor_shape = CURSOR_POINTING_HAND
			GameIcons.decorate(tile, GameIcons.tile(tile_id, spec), 18)
			var fill := PANEL.lerp(GameIcons.rarity(spec), 0.16 if tile_id == signature else 0.07)
			tile.add_theme_stylebox_override("normal", _rarity_frame(spec, fill, 6, 8))
			tile.add_theme_stylebox_override("hover", _rarity_frame(spec, fill.lightened(0.12), 6, 8))
			tile.add_theme_stylebox_override("pressed", _rarity_frame(spec, fill.lightened(0.18), 6, 8))
			var detail_copy := "%s · %s" % [spec.label, spec.description]
			if tile_id == signature:
				detail_copy = "%s signature · %s" % [_hero_name(hero_id), detail_copy]
				details.text = detail_copy
			tile.pressed.connect(func(): details.text = detail_copy)
			tile.focus_entered.connect(func(): details.text = detail_copy)
			grid.add_child(tile)
	deck.add_child(details)
	deck.add_child(_label("Combine 3 matching tiles to choose an upgrade.", 15, MUTED))
	dialog.popup_centered(Vector2i(1030, 530))


func _pick_draft(phase: String, id: String) -> void:
	match phase:
		"hero": _run.choose_hero(id)
		"relic": _run.choose_relic(id)
		"starter": _run.choose_starter(id)
		"recruit": _run.choose_recruit(id)
		"recruit_starter": _run.choose_recruit_starter(id)
	_host.run_return()


func _map() -> void:
	_page_title(_location_name(), _route_caption())
	var region := HBoxContainer.new()
	region.add_theme_constant_override("separation", 15)
	region.size_flags_vertical = SIZE_EXPAND_FILL
	_layout.add_child(region)
	var elite_detail := _label("", 15, CREAM)
	elite_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elite_detail.hide()
	var map := _map_board(elite_detail)
	region.add_child(map)
	var sidebar := _panel_stack(region, Vector2(270, 0))
	var relic_names := PackedStringArray()
	for id: String in _run.data.get("relics", []):
		relic_names.append(FrontierRun.RELICS.get(id, {}).get("label", id.capitalize()))
	var relics := _label("Relics  ·  " + ", ".join(relic_names), 15, MUTED)
	relics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sidebar.add_child(relics)
	sidebar.add_child(elite_detail)
	if not str(_run.data.get("node_notice", "")).is_empty():
		sidebar.add_child(_notice())
	sidebar.add_child(HSeparator.new())
	var keys := _label("Route key", 17, GOLD)
	sidebar.add_child(keys)
	for type in ["battle", "elite", "shop", "event", "rest", "boss"]:
		var key := HBoxContainer.new()
		key.add_theme_constant_override("separation", 9)
		sidebar.add_child(key)
		var texture := GameIcons.icon(type)
		if texture != null:
			key.add_child(_icon_view(texture, 22))
		key.add_child(_label(TYPE_NAMES[type] if texture else "%s   %s" % [TYPE_GLYPHS[type], TYPE_NAMES[type]], 15, MUTED))
	_footer_actions().add_child(_button("Manage tiles", func(): _host.run_show_arena()))


func _map_board(elite_detail: Label) -> Control:
	var map_art: String = MAP_ART.get(_run.data.get("location", "brass"), MAP_ART.brass)
	var board := _board(Vector2(655, 500), map_art)
	var layers: Array = _run.data.get("layers", [])
	var leg_start := (_leg_number() - 1) * FrontierRun.NODES_PER_SEGMENT
	if layers.size() > FrontierRun.NODES_PER_SEGMENT:
		layers = layers.slice(maxi(0, leg_start - 1), leg_start + FrontierRun.NODES_PER_SEGMENT)
	var nodes := {}
	var points := {}
	var active := {}
	var visited: Array = _run.data.get("visited", [])
	var current_id: String = _run.data.get("node", {}).get("id", "")
	for node: Dictionary in _run.available_nodes():
		active[node.id] = true
	for row_index in range(layers.size()):
		var layer: Array = layers[row_index]
		for index in range(layer.size()):
			var node: Dictionary = layer[index]
			var x := 0.5 if layer.size() == 1 else lerpf(0.22, 0.78, float(index) / (layer.size() - 1))
			var y := lerpf(0.91, 0.10, float(row_index) / maxf(1.0, layers.size() - 1))
			points[node.id] = Vector2(x, y)
			nodes[node.id] = node
	var lines := _ink_layer(board)
	lines.draw.connect(func():
		_draw_route_field(lines, map_art)
		for id in nodes:
			for destination in nodes[id].next:
				if points.has(destination):
					var traversed: bool = id in visited and destination in visited
					var current_edge: bool = id == current_id and active.has(destination)
					var tone := TEAL if current_edge else (Color("#9b865e") if traversed else Color("#3f5661"))
					lines.draw_dashed_line(points[id] * lines.size, points[destination] * lines.size, tone, 2.0, 6.0, true, true)
	)
	for id: String in nodes:
		var node: Dictionary = nodes[id]
		var type: String = node.type
		var reachable: bool = active.has(id)
		var past: bool = id in visited
		var label: String = node.get("label", TYPE_NAMES.get(type, type.capitalize()))
		var button := _button(label, func(): _choose_node(id), reachable)
		GameIcons.decorate(button, "battle" if type == "opening" else type, 21)
		if button.icon == null:
			button.text = "%s  %s" % [TYPE_GLYPHS.get(type, "·"), label]
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.disabled = not reachable
		button.add_theme_font_size_override("font_size", 14)
		button.tooltip_text = "%s · %s%s" % [label, TYPE_NAMES.get(type, type.capitalize()), " · completed" if past else (" · reachable" if reachable else " · unavailable")]
		if reachable and type == "elite":
			var preview := _elite_preview_copy(node)
			if not preview.is_empty():
				button.tooltip_text = preview
				var show_preview := func():
					elite_detail.text = preview
					elite_detail.show()
				button.mouse_entered.connect(show_preview)
				button.focus_entered.connect(show_preview)
		button.add_theme_stylebox_override("disabled", _box(PANEL_DARK, GOLD.darkened(0.35) if past else EDGE.darkened(0.15), 6, 6))
		button.add_theme_color_override("font_disabled_color", GOLD if past else MUTED.darkened(0.11))
		_at(board, button, points[id], Vector2(181, 39))
	return board


func _elite_preview_copy(node: Dictionary) -> String:
	var info: Dictionary = _run.elite_preview(node)
	if info.is_empty():
		return ""
	var preview := ArenaSim.new()
	preview.start(_run.loadout.lanes, "solo", info.encounter)
	var enemies := PackedStringArray()
	var threat := ""
	for unit: Dictionary in preview.units:
		if unit.side != "enemy" or unit.name in enemies:
			continue
		enemies.append(unit.name)
		if threat.is_empty() and ENEMY_HINTS.has(unit.sprite):
			threat = ENEMY_HINTS[unit.sprite]
	var tile: Dictionary = ArenaSim.TILES[info.tile]
	var formation := ", ".join(enemies)
	if not threat.is_empty():
		formation += "\n" + threat
	var reward := "%s (%s)" % [tile.label, str(tile.rarity).capitalize()]
	if _party().size() > 1:
		reward += " · " + _hero_name(_party()[0].id)
	if info.get("relic_draft", false):
		reward += "\nChoose a relic after victory"
	return "%s\n%s\n\nReward choice · %s" % [node.label, formation, reward]


func _draw_route_field(canvas: Control, image_path: String) -> void:
	if ResourceLoader.exists(image_path):
		return
	for band in range(12):
		var path := PackedVector2Array()
		for step in range(54):
			var x := float(step) / 53.0
			var y := 0.08 + band * 0.075 + 0.018 * sin(x * 11.0 + band * 0.41) + 0.014 * cos(x * 28.0 - band * 0.63)
			path.append(Vector2(x * canvas.size.x, y * canvas.size.y))
		canvas.draw_polyline(path, Color(0.36, 0.47, 0.45, 0.19), 1.25, true)


func _choose_node(id: String) -> void:
	if _run.choose_node(id):
		_host.run_return()


func _combat() -> void:
	var node: Dictionary = _run.data.get("node", {})
	var type: String = node.get("encounter_override", node.get("type", "battle"))
	var caption := "%s  ·  %s" % [TYPE_NAMES.get(type, "Battle"), _route_caption()]
	if type == "elite" and _run.will_draft_elite_relic():
		caption += "  ·  Relic draft"
	_page_title(node.get("label", "Opening battle"), caption)
	var region := _cards_row()
	var boss_id: String = node.get("boss_id", "")
	var brief: Dictionary = BOSS_BRIEFS.get(boss_id, {})
	var instruction: String = brief.get("hint", "")
	_continue(func(): _host.run_show_arena())
	var detail := _choice(region, "Boss counter" if not instruction.is_empty() else "", instruction, "", Callable())
	if brief.has("portrait"):
		_add_portrait(detail, brief.portrait)
	else:
		_add_enemy_preview(detail)


func _add_enemy_preview(card: VBoxContainer) -> void:
	var preview := ArenaSim.new()
	preview.start(_run.loadout.lanes, "solo", _run.encounter())
	var formation := HBoxContainer.new()
	formation.add_theme_constant_override("separation", 14)
	card.add_child(formation)
	card.move_child(formation, 0)
	var shown := {}
	for unit: Dictionary in preview.units:
		if unit.side != "enemy" or shown.has(unit.name):
			continue
		shown[unit.name] = true
		var enemy := _panel_stack(formation, Vector2.ZERO, true)
		_add_portrait(enemy, unit.sprite)
		enemy.add_child(_label(unit.name, 21, CREAM, true))
		if ENEMY_HINTS.has(unit.sprite):
			var hint := _label(ENEMY_HINTS[unit.sprite], 15, MUTED)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			enemy.add_child(hint)


func _reward() -> void:
	var relic_offers: Array = _run.elite_relic_offers()
	if not relic_offers.is_empty():
		_elite_relic_draft(relic_offers)
		return
	var boss: bool = _run.data.get("node", {}).get("type") == "boss"
	var final_boss: bool = boss and _run.is_final_boss()
	var title := "Choose a trophy" if final_boss else ("Legendary reward" if boss else "Choose a reward")
	var milestone := ""
	if boss:
		milestone = str(_run.data.get("node_notice", "")) if final_boss else "Leg %d cleared · Recruit for Leg %d next" % [_leg_number(), _leg_number() + 1]
	var lane: int = _run.reward_lane()
	var party := _party()
	var owner := _reward_owner(lane, party)
	if lane >= 0 and lane < party.size():
		var hero_id: String = party[lane].id
		_reward_heading(title, milestone, hero_id)
	else:
		_page_title(title, milestone)
	var cards := _cards_row()
	var notice := _notice()
	var selected := {"id": ""}
	var advance := _continue(func(): _claim_reward(selected.id, notice))
	advance.disabled = true
	var group := ButtonGroup.new()
	for id: String in _run.data.get("offers", []):
		var tile: Dictionary = ArenaSim.TILES[id]
		var hint: String = _run.reward_hint(id)
		if _host.run_can_combine_reward(id):
			hint = "Combine with 2 owned copies" if hint in ["", "Third copy", "Owned copy"] else "%s · Combine with 2 owned copies" % hint
		if not owner.is_empty() and tile.get("base_tile", id) == ClassDecks.signature(owner):
			hint = "Signature tile" if hint.is_empty() else "Signature tile · " + hint
		var card := _choice(cards, tile.label, _tile_info(tile) + ("\n\n" + hint if not hint.is_empty() else ""), "Select", func():
			selected.id = id
			advance.disabled = false
			notice.text = ""
		)
		var select_tile: Button = card.get_child(card.get_child_count() - 1)
		select_tile.name = "RewardTile_" + id
		select_tile.toggle_mode = true
		select_tile.button_group = group
		_add_tile_header(card, id, tile, owner)
		var panel := card.get_parent() as PanelContainer
		select_tile.toggled.connect(func(pressed: bool):
			panel.add_theme_stylebox_override("panel", _tile_card_frame(tile, pressed))
		)
	_layout.add_child(notice)
	var actions := _footer_actions()
	if not final_boss:
		actions.add_child(_button("Manage tiles", func(): _host.run_show_arena()))
	var bonus: int = _run.reward_skip_gold()
	var skip := _button("Skip for +%d gold" % bonus if bonus > 0 else "Skip reward", func(): _claim_reward("skip", notice))
	skip.name = "SkipReward"
	actions.add_child(skip)


func _reward_owner(lane: int, party: Array) -> String:
	if lane >= 0 and lane < party.size():
		return str(party[lane].id)
	var node: Dictionary = _run.data.get("node", {})
	if not party.is_empty() and node.get("encounter_override", node.get("type", "")) in ["opening", "battle", "elite", "boss"]:
		return str(party[0].id)
	return ""


func _reward_heading(title: String, milestone: String, hero_id: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 13)
	_layout.add_child(row)
	var art := load("res://assets/%s.png" % GameIcons.portrait(hero_id)) as Texture2D
	if art:
		row.add_child(_icon_view(art, 54))
	var hero := _label(_hero_name(hero_id), 34, CREAM, true)
	hero.name = "RewardHero"
	row.add_child(hero)
	var context := _label(title, 18, MUTED)
	context.size_flags_horizontal = SIZE_EXPAND_FILL
	context.size_flags_vertical = SIZE_SHRINK_CENTER
	row.add_child(context)
	var count: int = _run.reward_count()
	if count > 1:
		var progress := _label("Pick %d of %d" % [_run.reward_position() + 1, count], 17, GOLD)
		progress.name = "RewardProgress"
		progress.size_flags_vertical = SIZE_SHRINK_CENTER
		row.add_child(progress)
	if not milestone.is_empty():
		_layout.add_child(_label(milestone, 17, MUTED))


func _elite_relic_draft(offers: Array) -> void:
	_page_title("Choose an elite relic", "Tile reward follows.")
	var cards := _cards_row()
	var selected := {"id": ""}
	var advance := _continue(func():
		if _run.choose_elite_relic(selected.id):
			_host.run_return()
	)
	advance.disabled = true
	var group := ButtonGroup.new()
	for offer: Dictionary in offers:
		var id: String = offer.id
		var spec: Dictionary = FrontierRun.RELICS[id]
		var tone: Color = ELITE_RELIC_TONES[id]
		var card := _choice(cards, spec.label, spec.description, "Select", func():
			selected.id = id
			advance.disabled = false
		)
		var panel := card.get_parent() as PanelContainer
		panel.size_flags_vertical = SIZE_SHRINK_CENTER
		panel.custom_minimum_size.y = 426
		panel.add_theme_stylebox_override("panel", _box(PANEL, tone.darkened(0.50), 9, 18))
		var select_relic: Button = card.get_child(card.get_child_count() - 1)
		select_relic.name = "EliteRelic_" + id
		select_relic.toggle_mode = true
		select_relic.button_group = group
		select_relic.toggled.connect(func(pressed: bool):
			panel.add_theme_stylebox_override("panel", _box(PANEL, tone if pressed else tone.darkened(0.50), 9, 18))
		)
		if panel.get_index() == 0:
			select_relic.grab_focus()
		var role := _label(offer.role, 15, tone)
		card.add_child(role)
		card.move_child(role, 0)
		var companion: String = offer.companion
		var support := HBoxContainer.new()
		support.custom_minimum_size.y = 24
		card.add_child(support)
		card.move_child(support, select_relic.get_index())
		if not companion.is_empty():
			var tile: Dictionary = ArenaSim.TILES[companion]
			var texture := GameIcons.icon(GameIcons.tile(companion, tile))
			if texture != null:
				support.add_child(_icon_view(texture, 21))
			support.add_child(_label("Tile offer · " + tile.label, 15, GameIcons.rarity(tile)))
			support.add_child(GameIcons.rarity_badge(tile, true))
			var owner := _reward_owner(_run.reward_lane(), _party())
			if not owner.is_empty():
				support.add_child(GameIcons.hero_badge(owner))
		_add_card_icon(card, GameIcons.relic(id), tone)


func _claim_reward(id: String, notice: Label) -> void:
	if _host.run_claim_reward(id):
		_host.run_return()
	else:
		notice.text = _run.save_error if not _run.save_error.is_empty() else "No room for this tile. Manage tiles to free a continuous span."


func _shop() -> void:
	_page_title(_run.data.get("node", {}).get("label", "Relay Market"), "")
	var cards := _cards_row()
	var notice := _notice()
	for id: String in _run.data.get("offers", []):
		var tile: Dictionary = ArenaSim.TILES[id]
		var price: int = _run.shop_price(id)
		var card := _choice(cards, tile.label, _tile_info(tile), "Buy · %d gold" % price, func(): _buy_tile(id, notice), int(_run.data.get("gold", 0)) < price)
		_add_tile_header(card, id, tile)
	if _run.data.get("offers", []).is_empty():
		cards.add_child(_label("No tiles left.", 20, MUTED))
	_layout.add_child(notice)
	_continue(_leave)
	var actions := _footer_actions()
	actions.add_child(_button("Manage tiles", func(): _host.run_show_arena()))
	var heal_label := "Heal 15 HP each · 12 gold" if _party().size() > 1 else "Heal 15 HP · 12 gold"
	var healing := _button(heal_label, func():
		if _run.shop_heal():
			_host.run_return()
	)
	healing.disabled = int(_run.data.get("gold", 0)) < 12 or _run.data.get("shop_healed", false) or not _party_needs_healing()
	actions.add_child(healing)
	var relic_id: String = _run.data.get("shop_relic", "")
	if FrontierRun.RELICS.has(relic_id):
		var relic: Dictionary = FrontierRun.RELICS[relic_id]
		var buy_relic := _button("%s · 30 gold" % relic.label, func():
			if _run.shop_buy_relic():
				_host.run_return()
		)
		buy_relic.disabled = int(_run.data.get("gold", 0)) < 30
		buy_relic.tooltip_text = relic.description
		actions.add_child(buy_relic)


func _buy_tile(id: String, notice: Label) -> void:
	if _host.run_buy_shop(id):
		_host.run_return()
	else:
		notice.text = "No room for this tile. Manage tiles to free a continuous span."


func _event() -> void:
	_page_title(_run.data.get("node", {}).get("label", "Roadside encounter"), _run.event_text())
	var cards := _cards_row()
	var options: Array = _run.event_options()
	for index in range(options.size()):
		var unavailable: bool = not _run.event_option_available(index)
		_choice(cards, str(options[index]), "", "Choose", func(): _pick_event(index), unavailable)
	_continue(_leave, "Leave this encounter.")


func _pick_event(index: int) -> void:
	_run.event_choice(index)
	_host.run_return()


func _rest() -> void:
	_page_title(_run.data.get("node", {}).get("label", "Rest site"), "")
	var cards := _cards_row()
	_add_card_icon(_choice(cards, "Rest", "Recover 30% max HP per hero.", "Heal", func(): _run.rest("heal"); _host.run_return()), "rest")
	_add_card_icon(_choice(cards, "Forge", "Advance one tile to the next rarity.", "Open forge", func(): _host.run_rest_forge()), "forge")
	_continue(_leave)


func _leave() -> void:
	_run.leave_node()
	_host.run_return()


func _result() -> void:
	var victory: bool = _run.data.get("result", "") == "victory"
	_page_title(_location_name() + " cleared" if victory else "Expedition ended", _route_caption())
	var cards := _cards_row()
	var detail := "Aether Marks earned during the run are banked."
	if victory:
		var boss_name: String = _run.data.get("node", {}).get("label", "the final boss")
		detail = "You defeated %s." % boss_name
		var notice: String = _run.data.get("node_notice", "")
		if not notice.is_empty():
			detail += "\n" + notice
	if victory:
		var trophies: Dictionary = _run.data.get("trophies", {})
		for member: Dictionary in _party():
			var tile_id: String = trophies.get(member.id, "")
			if ArenaSim.TILES.has(tile_id):
				detail += "\n%s  ·  %s" % [_hero_name(member.id), ArenaSim.TILES[tile_id].label]
		var legacy_trophy: String = _run.data.get("trophy", "")
		if trophies.is_empty() and ArenaSim.TILES.has(legacy_trophy):
			detail += "\nVictory reward  ·  " + ArenaSim.TILES[legacy_trophy].label
	detail += "\n+%d Aether Marks this run." % int(_run.data.get("marks_earned", 0))
	detail += "\n%d Aether Marks available." % int(_run.profile.get("marks", 0))
	_choice(cards, "Victory" if victory else "Defeat", detail, "", Callable())
	_continue(func(): _finish(false))
	_footer_actions().add_child(_button("Open Aether Chart", func(): _finish(true)))


func _finish(show_chart: bool) -> void:
	if _run.finish_run():
		if show_chart:
			_host.run_show_chart()
		else:
			_host.run_menu()


func _difficulty_name() -> String:
	return str(_run.data.get("difficulty", "easy")).capitalize()


func _location_name() -> String:
	return FrontierRun.LOCATION_LABELS.get(_run.data.get("location", "brass"), "Brass Frontier")


func _route_caption() -> String:
	var parts := PackedStringArray([_difficulty_name()])
	var legs: int = FrontierRun.SEGMENT_COUNTS.get(_run.data.get("difficulty", "easy"), 1)
	if legs > 1:
		parts.append("Leg %d of %d" % [_leg_number(), legs])
	parts.append("Seed %s" % str(_run.data.get("seed", "")))
	return "  ·  ".join(parts)


func _leg_number() -> int:
	return int(_run.data.get("segment", 1))


func _hero_name(id: String) -> String:
	return FrontierRun.HEROES.get(id, {}).get("label", id.capitalize())


func _party() -> Array:
	var members: Array = _run.data.get("heroes", [])
	if not members.is_empty() or not _run.data.has("hp"):
		return members
	return [{
		"id": _run.data.get("hero", ""), "hp": int(_run.data.hp),
		"max_hp": int(_run.data.get("max_hp", _run.data.hp))
	}]


func _party_needs_healing() -> bool:
	for member: Dictionary in _party():
		if int(member.hp) < int(member.max_hp):
			return true
	return false


func _chart() -> void:
	var owned: Array = _run.profile.get("meta", [])
	var entries: Array[Dictionary] = []
	for id: String in FrontierRun.META_NODES:
		var spec: Dictionary = FrontierRun.META_NODES[id]
		var prerequisites: Array = spec.requires
		var available := true
		for prerequisite: String in prerequisites:
			if prerequisite not in owned:
				available = false
				break
		entries.append({
			"id": id,
			"label": spec.label,
			"description": spec.description,
			"cost": spec.cost,
			"prerequisites": prerequisites,
			"purchased": id in owned,
			"available": available,
			"branch": {
				"stout_start": "Vitality", "purse": "Supplies", "relic_archive": "Supplies", "navigation": "Navigation"
			}.get(id, "Artifice"),
			"kind": {
				"stout_start": "Starting health", "purse": "Starting gold",
				"curated_cache": "Tile unlock", "relic_archive": "Relic unlock",
				"blink_artifice": "Camp and reward unlock", "wayfarers_pin": "Relic unlock", "navigation": "Event unlock",
				"shot_artifice": "Camp and reward unlock", "guard_artifice": "Camp and reward unlock"
			}.get(id, "Upgrade")
		})
	_aether_chart.render(int(_run.profile.get("marks", 0)), entries, _run.data.is_empty())


func _buy_chart_node(id: String) -> void:
	if _run.buy_meta(id):
		_chart()


func _page_title(title: String, subtitle: String) -> void:
	_layout.add_child(_label(title, 44, CREAM, true))
	if subtitle.is_empty():
		return
	var text := _label(subtitle, 17, MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_layout.add_child(text)


func _notice() -> Label:
	var note := _label(_run.data.get("node_notice", ""), 15, TEAL)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return note


func _cards_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 15)
	row.size_flags_vertical = SIZE_EXPAND_FILL
	_layout.add_child(row)
	return row


func _continue(chosen: Callable, tooltip := "") -> Button:
	var button := _button("Continue", chosen, true)
	button.name = "Continue"
	button.custom_minimum_size.x = 130
	button.tooltip_text = tooltip
	_top_actions.add_child(button)
	return button


func _footer_actions() -> HBoxContainer:
	if not is_instance_valid(_bottom_actions):
		_bottom_actions = HBoxContainer.new()
		_bottom_actions.alignment = BoxContainer.ALIGNMENT_END
		_bottom_actions.add_theme_constant_override("separation", 8)
		_layout.add_child(_bottom_actions)
	return _bottom_actions


func _choice(parent: Control, name: String, body: String, cta: String, chosen: Callable, disabled := false) -> VBoxContainer:
	var card := _panel_stack(parent, Vector2(0, 280), true)
	if not name.is_empty():
		var title := _label(name, 27, CREAM, true)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(title)
	var details := _label(body, 17, MUTED)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.size_flags_vertical = SIZE_EXPAND_FILL
	card.add_child(details)
	if not cta.is_empty():
		var action := _button(cta, chosen, true)
		action.disabled = disabled
		card.add_child(action)
	return card


func _tile_info(tile: Dictionary) -> String:
	return "%s\n%s" % [GameIcons.tile_stats(tile), tile.description]


func _add_tile_header(card: VBoxContainer, id: String, spec: Dictionary, owner := "") -> void:
	var panel := card.get_parent() as PanelContainer
	panel.add_theme_stylebox_override("panel", _tile_card_frame(spec))
	var color := GameIcons.rarity(spec)
	_add_card_icon(card, GameIcons.tile(id, spec), color)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var rarity := GameIcons.rarity_badge(spec)
	rarity.text += "  " + GameIcons.rarity_pips(spec)
	rarity.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(rarity)
	var origin := GameIcons.tile_origin(id, spec)
	var class_id := owner if not owner.is_empty() else origin
	if not class_id.is_empty():
		row.add_child(GameIcons.hero_badge(class_id, false))
		panel.tooltip_text = "%s signature" % _hero_name(origin) if owner.is_empty() else _hero_name(owner)
		if not owner.is_empty() and not origin.is_empty() and origin != owner:
			panel.tooltip_text += " · %s signature" % _hero_name(origin)
	card.add_child(row)
	card.move_child(row, 0)


func _tile_card_frame(spec: Dictionary, selected := false) -> StyleBoxFlat:
	var color := GameIcons.rarity(spec)
	var frame := _rarity_frame(spec, PANEL.lerp(color, 0.13 if selected else 0.04), 9, 18)
	if selected:
		frame.set_border_width_all(2)
		frame.border_width_left = 5
	return frame


func _rarity_frame(spec: Dictionary, fill: Color, radius: int, margin: int) -> StyleBoxFlat:
	var frame := _box(fill, GameIcons.rarity(spec), radius, margin)
	frame.border_width_left = 4
	return frame


func _icon_view(texture: Texture2D, height: int) -> TextureRect:
	var view := TextureRect.new()
	view.texture = texture
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.custom_minimum_size = Vector2(height, height)
	view.mouse_filter = MOUSE_FILTER_IGNORE
	return view


func _add_card_icon(card: VBoxContainer, key: String, accent := GOLD) -> void:
	var texture := GameIcons.icon(key)
	if texture == null:
		return
	var art := PanelContainer.new()
	art.add_theme_stylebox_override("panel", _box(PANEL_DARK, accent.darkened(0.40), 9, 12))
	art.add_child(_icon_view(texture, 94))
	card.add_child(art)
	card.move_child(art, 0)


func _add_portrait(card: VBoxContainer, id: String, height := 138) -> void:
	var path := "res://assets/%s.png" % id
	if not ResourceLoader.exists(path):
		return
	var portrait := TextureRect.new()
	portrait.texture = load(path) as Texture2D
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size.y = height
	portrait.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(portrait)
	card.move_child(portrait, 0)


func _panel_stack(parent: Control, minimum: Vector2, expand := false) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(PANEL, EDGE, 9, 18))
	panel.custom_minimum_size = minimum
	if expand:
		panel.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 13)
	panel.add_child(stack)
	return stack


func _board(minimum: Vector2, image_path: String) -> Panel:
	var board := Panel.new()
	board.size_flags_horizontal = SIZE_EXPAND_FILL
	board.size_flags_vertical = SIZE_EXPAND_FILL
	board.custom_minimum_size = minimum
	board.clip_contents = true
	board.add_theme_stylebox_override("panel", _box(PANEL_DARK, EDGE, 9, 0))
	_background(board, image_path, Color(0.60, 0.68, 0.73, 0.50), TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	return board


func _background(parent: Control, path: String, tint: Color, stretch: TextureRect.StretchMode) -> void:
	if not ResourceLoader.exists(path):
		return
	var picture := TextureRect.new()
	picture.texture = load(path) as Texture2D
	picture.modulate = tint
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = stretch
	picture.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(picture)
	picture.set_anchors_and_offsets_preset(PRESET_FULL_RECT)


func _ink_layer(board: Control) -> Control:
	var drawing := Control.new()
	drawing.mouse_filter = MOUSE_FILTER_IGNORE
	board.add_child(drawing)
	drawing.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	drawing.resized.connect(drawing.queue_redraw)
	return drawing


func _at(board: Control, child: Control, location: Vector2, extent: Vector2) -> void:
	board.add_child(child)
	child.anchor_left = location.x
	child.anchor_right = location.x
	child.anchor_top = location.y
	child.anchor_bottom = location.y
	child.offset_left = -extent.x / 2.0
	child.offset_right = extent.x / 2.0
	child.offset_top = -extent.y / 2.0
	child.offset_bottom = extent.y / 2.0


func _label(value: String, points: int, color: Color, display := false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", color)
	if display and _display_font:
		label.add_theme_font_override("font", _display_font)
	return label


func _button(title: String, activate: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 41
	button.pressed.connect(activate)
	var fill := Color("#60492d") if primary else PANEL_DARK
	var border := GOLD if primary else EDGE
	button.add_theme_stylebox_override("normal", _box(fill, border, 6, 12))
	button.add_theme_stylebox_override("hover", _box(fill.lightened(0.12), GOLD, 6, 12))
	button.add_theme_stylebox_override("pressed", _box(fill.darkened(0.14), GOLD, 6, 12))
	button.add_theme_stylebox_override("disabled", _box(PANEL_DARK, EDGE, 6, 12))
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_disabled_color", MUTED.darkened(0.18))
	return button


func _box(fill: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin
	box.content_margin_bottom = margin
	return box
