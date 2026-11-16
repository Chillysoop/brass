extends Control

const FrontierRun = preload("res://scripts/frontier_run.gd")
const ArenaSim = preload("res://scripts/arena_sim.gd")
const ExpeditionMenu = preload("res://scripts/expedition_menu.gd")
const AetherChartMenu = preload("res://scripts/aether_chart_menu.gd")
const ClassRosterMenu = preload("res://scripts/class_roster_menu.gd")
const GameIcons = preload("res://scripts/game_icons.gd")
const CombatIcons = preload("res://scripts/combat_icons.gd")
const ClassDecks = preload("res://scripts/class_decks.gd")
const ClassMasteries = preload("res://scripts/class_masteries.gd")
const TileKeywords = preload("res://scripts/tile_keywords.gd")
const TileEnchantments = preload("res://scripts/tile_enchantments.gd")
const RelicPortraitShader = preload("res://assets/relic-portrait.gdshader")
const INK := Color("#101820")
const PANEL := Color("#182632")
const PANEL_DARK := Color("#111f2a")
const EDGE := Color("#40515c")
const CREAM := Color("#f3e7d1")
const GOLD := Color("#ecc482")
const MUTED := Color("#aababc")
const TEAL := Color("#9ddbd1")
const RUST := Color("#e8a28b")
const RELIC_MUTED := Color("#d3c1c7")
const TILE_DESCRIPTION_EXCLUSIONS: Array[String] = ["beat", "range"]
const TYPE_GLYPHS := {
	"battle": "×", "opening": "×", "elite": "◆", "shop": "◈", "event": "?", "rest": "+", "boss": "✦"
}
const TYPE_NAMES := {
	"battle": "Battle", "opening": "Opening battle", "elite": "Elite", "shop": "Shop",
	"event": "Event", "rest": "Rest site", "boss": "Boss"
}
const COMPACT_ROUTE_NAMES := {
	"Roadside Quartermaster": "Roadside Shop", "Crucible Quartermaster": "Crucible Shop",
	"Furnace Overlook": "Furnace View", "Polished Barricade": "Polished Wall",
	"Tempered Colossus": "Colossus", "Refraction Engine": "Refraction",
	"Signalkeeper's Loft": "Signal Loft", "Cloudbreak Lookout": "Cloudbreak",
	"Signalman's Infirmary": "Signal Infirmary", "Standard-Bearer's Supply": "Standard Supply",
	"Upper Beacon Shelter": "Beacon Shelter", "Bell Tower Approach": "Bell Tower",
	"Breakwater Sentinels": "Sea Wall Guard", "Blackwater Moorings": "Blackwater Dock",
	"Glasswright's Cart": "Glasswright Cart", "Pearl Diver's Bench": "Diver's Bench",
	"Storm-Tossed Crate": "Storm Crate", "Wreckwright's Stores": "Wreckwright Shop",
	"Royal Signal Corps": "Royal Signal", "Royal Signal Guard": "Royal Guard",
	"Regent's Honor Guard": "Regent Guard", "Lenswright's Bench": "Lens Bench",
	"Signal Scriptorium": "Signal Scribe", "Semaphore Exchange": "Signal Exchange",
	"Bannerwright's Stall": "Banner Stall", "Liftmaster's Supply": "Lift Supply",
	"Lenswright's Cart": "Lens Cart", "Blackglass Shelter": "Blackglass Camp",
	"Semaphore Terrace": "Signal Terrace", "Crown Signal Array": "Crown Array",
	"Windbreak Station": "Windbreak", "Lantern Chandlery": "Lantern Shop",
	"Sea Wall Traverse": "Sea Wall", "Saltwater Exchange": "Salt Exchange",
}
const REINFORCEMENT_NAMES := {"Dust Patrol": "Dust Ambush", "Piston Guard": "Piston Wave"}
const MAP_ART := {
	"brass": "res://assets/frontier-map.webp",
	"glass": "res://assets/glass-map.webp",
	"crown": "res://assets/crown-map.webp",
	"moonwreck": "res://assets/moonwreck-map.webp",
}
const RELIC_DRAFT_TONES := {
	"afterimage": Color("#c8b7ec"), "barrage_rack": Color("#efbe8a"), "siege_fuse": Color("#9ddbd1"),
	"twin_bell": Color("#f1cc79"), "switchback_lens": Color("#9dcce7"), "longshot_prism": Color("#d7bcee"),
	"guard_relay": Color("#9ddbd1"), "flanking_standard": Color("#efae81"),
	"tollkeeper_signet": Color("#f2c185"), "bastion_medal": Color("#9ddbd1"), "guild_ledger": Color("#d3bded"),
	"tollkeeper_repair_kit": Color("#b5d5a0"), "bellmaker_clapper": Color("#f2b68b"),
	"bellmaker_long_echo": Color("#a8d9eb"), "bellmaker_resonant_plate": Color("#dfc4ee"),
}

var _host
var _run
var _layout: VBoxContainer
var _top_actions: HBoxContainer
var _bottom_actions: HBoxContainer
var _expedition_menu: ExpeditionMenu
var _aether_chart: AetherChartMenu
var _class_roster: ClassRosterMenu
var _choosing_starter := false
var _display_font: SystemFont
var _battle_overlay := false


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
	_expedition_menu.save_slot_requested.connect(func(slot: int):
		if not _host.run_select_save_slot(slot):
			_expedition_menu.render(_run, "slots")
	)
	_expedition_menu.reset_save_slot_requested.connect(func(slot: int):
		if not _host.run_start_new_game_slot(slot, true):
			_expedition_menu.render(_run, "slots")
	)
	_expedition_menu.quit_requested.connect(func(): get_tree().quit())
	_aether_chart = AetherChartMenu.new()
	_aether_chart.name = "AetherChartMenu"
	add_child(_aether_chart)
	_aether_chart.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_aether_chart.purchase_requested.connect(_buy_chart_node)
	_aether_chart.back_requested.connect(_host.run_menu)
	_aether_chart.roster_requested.connect(func(): render(_run, "roster"))
	_class_roster = ClassRosterMenu.new()
	_class_roster.name = "ClassRosterMenu"
	add_child(_class_roster)
	_class_roster.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_class_roster.purchase_requested.connect(_buy_roster_class)
	_class_roster.starter_requested.connect(_pick_starter_class)
	_class_roster.deck_requested.connect(_show_class_deck)
	_class_roster.back_requested.connect(_close_class_roster)


func render(model, page_override: String = "", battle_overlay := false) -> void:
	_run = model
	_battle_overlay = battle_overlay
	for child in get_children():
		if child in [_expedition_menu, _aether_chart, _class_roster]:
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
	if phase in ["roster", "starter_roster"]:
		_choosing_starter = phase == "starter_roster"
		_class_roster.show()
		_render_class_roster()
		return
	var compact_classes := phase in ["hero", "recruit", "masteries"] and get_viewport_rect().size.y < 680.0
	_shell(phase, compact_classes)
	match phase:
		"hero", "relic", "starter", "recruit", "recruit_starter": _draft(phase, compact_classes)
		"masteries": _masteries_page(compact_classes)
		"map": _map()
		"reward": _reward()
		"boss_relic": _boss_relic_draft()
		"enchantment": _enchantment_draft()
		"shop": _shop()
		"event": _event()
		"rest": _rest()
		"result": _result()
	if phase != "result":
		if phase == "map":
			_reward_placement_banner(_footer_actions(), false)
	_layout.modulate.a = 0.70
	create_tween().tween_property(_layout, "modulate:a", 1.0, 0.16)


func _shell(phase: String, compact_classes: bool) -> void:
	var base := ColorRect.new()
	base.color = Color(INK, 0.88) if _battle_overlay else INK
	base.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(base)
	base.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	if phase in ["relic", "boss_relic"] or (phase == "reward" and not _run.elite_relic_offers().is_empty()):
		base.color = Color.TRANSPARENT
		var light := Gradient.new()
		light.colors = PackedColorArray([Color(0.23, 0.14, 0.23, 0.94), Color(0.063, 0.038, 0.075, 0.89)])
		var wash := GradientTexture2D.new()
		wash.gradient = light
		wash.fill = GradientTexture2D.FILL_RADIAL
		wash.fill_from = Vector2(0.5, 0.4)
		wash.fill_to = Vector2(0.96, 0.95)
		var backdrop := _icon_view(wash, 0)
		backdrop.stretch_mode = TextureRect.STRETCH_SCALE
		base.add_child(backdrop)
		backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 14 if _battle_overlay else 37)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6 if _battle_overlay else (14 if compact_classes else 25))
	_layout = VBoxContainer.new()
	_bottom_actions = null
	_layout.add_theme_constant_override("separation", 5 if _battle_overlay else (8 if compact_classes else 13))
	margin.add_child(_layout)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	_layout.add_child(bar)
	if not _battle_overlay and phase != "result":
		var save_title := _button("Save & title", _host.run_save_title)
		save_title.name = "SaveTitle"
		bar.add_child(save_title)
	if _battle_overlay:
		_reward_placement_banner(bar)
	var title := _label(_run.save_error if _battle_overlay else "BRASS & AETHER",
		15 if _battle_overlay else 19, RUST if _battle_overlay else GOLD)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	if _battle_overlay:
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.tooltip_text = title.text
	bar.add_child(title)
	if phase != "result":
		for member: Dictionary in ([] if _battle_overlay else _party()):
			var member_id: String = member.get("id", "")
			var hp_text := "%d/%d" % [int(member.hp), int(member.max_hp)]
			var health := CombatIcons.stat("health", hp_text, 17)
			if not member_id.is_empty():
				health.add_child(GameIcons.hero_badge(member_id))
				health.move_child(health.get_child(health.get_child_count() - 1), 0)
				health.tooltip_text = "%s health: %s" % [_hero_name(member_id), hp_text]
				health.accessibility_name = health.tooltip_text
			bar.add_child(health)
		bar.add_child(CombatIcons.stat("gold", str(int(_run.data.get("gold", 0)))))
	_top_actions = HBoxContainer.new()
	_top_actions.add_theme_constant_override("separation", 8)
	bar.add_child(_top_actions)
	if phase != "map" and not _battle_overlay:
		_reward_placement_banner(_layout)
	if phase == "reward":
		_add_enchantment_notice(_layout)
	if not _battle_overlay and not _run.save_error.is_empty():
		_layout.add_child(_label(_run.save_error, 15, RUST))


func _reward_placement_banner(parent: BoxContainer, storage_shortcut := true) -> void:
	var placement: Dictionary = _run.current_reward_placement()
	var tile: Dictionary = ArenaSim.TILES.get(placement.get("id", ""), {})
	if tile.is_empty():
		return
	var stored := placement.has("row")
	var text := "%s sent to storage" % tile.label
	if not stored:
		var party := _party()
		var lane := int(placement.get("lane", -1))
		var owner := _hero_name(party[lane].id) if lane >= 0 and lane < party.size() else ""
		text = "%s added to timeline" % tile.label if owner.is_empty() else "%s added to %s’s timeline" % [tile.label, owner]
	var row := HBoxContainer.new()
	row.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(row)
	if parent == _bottom_actions:
		parent.move_child(row, 0)
	var notice := _label(text, 17, TEAL)
	notice.name = "RewardPlacement"
	notice.size_flags_horizontal = SIZE_EXPAND_FILL
	notice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	notice.tooltip_text = text
	row.add_child(notice)
	if stored and storage_shortcut:
		_add_storage_shortcut(row)


func _add_storage_shortcut(parent: BoxContainer) -> void:
	var open := _button("Open storage", _host.run_open_reward_storage)
	open.name = "OpenRewardStorage"
	parent.add_child(open)


func _add_enchantment_notice(parent: BoxContainer) -> void:
	var copy: String = _run.data.get("enchantment_notice", "")
	if not copy.is_empty():
		var notice := _label(copy, 16, TEAL)
		notice.name = "EnchantmentNotice"
		notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(notice)


func _start_new_run(seed_value: int, difficulty: String, location: String) -> void:
	if not _run.can_start(difficulty, location):
		return
	if _run.data.is_empty():
		_host.run_start(seed_value, difficulty, location)
		return
	if _run.data.get("phase") == "result":
		if _run.finish_run():
			_host.run_start(seed_value, difficulty, location)
		else:
			_host.run_menu()
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Start a new expedition?"
	dialog.dialog_text = "This replaces the expedition in progress. Your unlocks and Aether Marks carry into the next run."
	dialog.ok_button_text = "Start new expedition"
	dialog.confirmed.connect(func():
		if _run.abandon_run():
			_host.run_start(seed_value, difficulty, location)
		else:
			_host.run_menu()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func _draft(phase: String, compact_classes: bool) -> void:
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
	var loadouts: Array = _run.recruit_loadout_offers()
	if not loadouts.is_empty():
		subtitle += " · All heroes share the same clock."
	if phase == "relic":
		_relic_heading(title, "")
	else:
		_page_title(title, subtitle, compact_classes)
	var cards := _cards_row()
	var offers: Array = _run.data.get("offers", [])
	if phase == "hero" and _run.can_choose_starter():
		var roster := _button("Choose from roster", func(): render(_run, "starter_roster"))
		roster.name = "ChooseStarterFromRoster"
		_footer_actions().add_child(roster)
	if phase == "relic" and not _run.build_relic_offers().is_empty():
		var switch := _button("Classic relics", func(): _toggle_relic_draft(cards))
		switch.name = "RelicDraftSwitch"
		_footer_actions().add_child(switch)
		offers = _run.build_relic_offers()
	if phase == "relic":
		_add_starter_relic_cards(cards, offers)
	elif loadouts.is_empty():
		_add_draft_cards(cards, offers, phase, compact_classes)
	else:
		_add_recruit_loadouts(cards, loadouts)
	var masteries: Array = _run.mastery_offers()
	if not masteries.is_empty():
		var active := ClassMasteries.info(_run.selected_mastery())
		var mastery := _button("Class mastery" if active.is_empty() else active.label, func(): render(_run, "masteries"))
		mastery.name = "ChooseClassMastery"
		mastery.tooltip_text = "Choose an optional bonus for this expedition." if active.is_empty() else active.description
		GameIcons.decorate(mastery, "elite", 17)
		_footer_actions().add_child(mastery)


func _add_recruit_loadouts(cards: HBoxContainer, offers: Array) -> void:
	for offer: Dictionary in offers:
		var card := _panel_stack(cards, Vector2(0, 290), true)
		card.get_parent().size_flags_vertical = SIZE_SHRINK_CENTER
		card.add_child(_label(offer.label, 27, CREAM, true))
		var pitch := _label(offer.description, 17, MUTED)
		pitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(pitch)
		for id: String in offer.tiles:
			var spec: Dictionary = ArenaSim.TILES[id]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			card.add_child(row)
			var icon := GameIcons.icon(GameIcons.tile(id, spec))
			if icon:
				row.add_child(_icon_view(icon, 42))
			var tile := VBoxContainer.new()
			tile.size_flags_horizontal = SIZE_EXPAND_FILL
			row.add_child(tile)
			var title := _label(spec.label, 17, CREAM)
			title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tile.add_child(title)
			tile.add_child(CombatIcons.tile_stats(spec, 14))
			tile.add_child(TileKeywords.description(spec.description, 14, MUTED, TILE_DESCRIPTION_EXCLUSIONS))
		var pick := _button("Choose loadout", func():
			_run.choose_recruit_loadout(offer.id)
			_host.run_return(), true)
		pick.name = "RecruitLoadout_" + offer.id
		card.add_child(pick)


func _masteries_page(compact: bool) -> void:
	var class_id: String = _run.data.get("pending_recruit", _run.data.hero)
	_page_title(_hero_name(class_id) + " mastery", "Choose an optional bonus to your class passive for this expedition.", compact)
	var cards := _cards_row()
	var active: String = _run.selected_mastery()
	for mastery: Dictionary in _run.mastery_offers():
		var card := _choice(cards, mastery.label, mastery.description, "Equipped" if mastery.id == active else "Equip mastery",
			func(): _pick_mastery(mastery.id))
		var choice := card.get_child(card.get_child_count() - 1) as Button
		choice.name = "MasteryOption_" + mastery.id
		card.get_parent().size_flags_vertical = SIZE_SHRINK_CENTER
		_add_card_icon(card, mastery.get("icon", "elite"))
	var footer := _footer_actions()
	if not active.is_empty():
		var remove := _button("Remove mastery", func(): _pick_mastery(""))
		remove.name = "NoClassMastery"
		footer.add_child(remove)
	var next: String = {"relic": "Continue to relics", "starter": "Continue to starter tile"}.get(_run.data.phase,
		"Continue to loadouts" if not _run.recruit_loadout_offers().is_empty() else "Continue to starter tile")
	var continue_draft := _button(next, _host.run_return, false, compact)
	continue_draft.name = "ContinueMasteryDraft"
	footer.add_child(continue_draft)


func _pick_mastery(id: String) -> void:
	_run.choose_mastery(id)
	_host.run_return()


func _toggle_relic_draft(cards: HBoxContainer) -> void:
	var switch := _bottom_actions.get_node("RelicDraftSwitch") as Button
	var show_classic := switch.text == "Classic relics"
	switch.text = "Build relics" if show_classic else "Classic relics"
	for card in cards.get_children():
		cards.remove_child(card)
		card.queue_free()
	var offers: Array = _run.data.get("offers", []) if show_classic else _run.build_relic_offers()
	_add_starter_relic_cards(cards, offers)


func _add_starter_relic_cards(cards: HBoxContainer, offers: Array) -> void:
	for id: String in offers:
		_relic_draft_card(cards, id, "StarterRelic_", func(): _pick_draft("relic", id))


func _add_draft_cards(cards: HBoxContainer, offers: Array, phase: String, compact_classes: bool) -> void:
	for id: String in offers:
		if phase in ["hero", "recruit"]:
			_add_class_draft_card(cards, id, phase, compact_classes)
			continue
		var entry: Dictionary = ArenaSim.TILES[id]
		var info := str(entry.get("description", ""))
		var card := _choice(cards, entry.label, info, "Choose", func(): _pick_draft(phase, id))
		var hero_id: String = _run.data.get("pending_recruit", _run.data.get("hero", ""))
		_add_tile_header(card, id, entry, hero_id)
		if id == ClassDecks.starter(hero_id):
			var badge := _label("Class starter", 15, TEAL)
			card.add_child(badge)
			card.move_child(badge, 3)


func _add_class_draft_card(cards: HBoxContainer, id: String, phase: String, compact: bool) -> void:
	var entry: Dictionary = FrontierRun.HEROES[id]
	var card := _panel_stack(cards, Vector2(0, 280), true)
	if compact:
		card.get_parent().add_theme_stylebox_override("panel", _box(PANEL, EDGE, 9, 8))
		card.add_theme_constant_override("separation", 6)
	_add_portrait(card, GameIcons.hero_art(id), 86 if compact else 205)
	var title := _label(entry.label, 21 if compact else 27, CREAM, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(title)
	var deck := _label(ClassDecks.summary(id), 14 if compact else 15, TEAL)
	deck.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(deck)
	var details := _label(entry.description, 14 if compact else 17, MUTED)
	details.name = "ChoiceDetails"
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if compact:
		var description_scroll := ScrollContainer.new()
		description_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		description_scroll.custom_minimum_size.y = 36
		description_scroll.size_flags_vertical = SIZE_EXPAND_FILL
		details.size_flags_horizontal = SIZE_EXPAND_FILL
		description_scroll.add_child(details)
		card.add_child(description_scroll)
	else:
		details.size_flags_vertical = SIZE_EXPAND_FILL
		card.add_child(details)
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 6)
	card.add_child(actions)
	var deck_button := _button("View class deck", func(): _show_class_deck(id), false, compact)
	deck_button.name = "ClassDeck_" + id
	deck_button.size_flags_horizontal = SIZE_EXPAND_FILL
	if not compact:
		GameIcons.decorate(deck_button, "review", 17)
	actions.add_child(deck_button)
	if id in _run.profile.mastered_classes:
		var mastery := _button("Choose mastery", func(): _pick_draft(phase, id, true), false, compact)
		mastery.name = "ChooseMasteryFor_" + id
		mastery.tooltip_text = "Choose this hero and view their mastery options."
		mastery.add_theme_color_override("font_color", GOLD)
		if not compact:
			GameIcons.decorate(mastery, "elite", 17)
		actions.add_child(mastery)
	var choose := _button("Choose", func(): _pick_draft(phase, id), true, compact)
	choose.name = ("ChooseHero_" if phase == "hero" else "ChooseRecruit_") + id
	card.add_child(choose)


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
	var summary := VBoxContainer.new()
	summary.add_theme_constant_override("separation", 3)
	var details := TileKeywords.description("", 15, CREAM)
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
			tile.text = spec.label
			tile.custom_minimum_size.y = 30
			tile.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			tile.size_flags_horizontal = SIZE_EXPAND_FILL
			var tooltip: String = "%s · %s\n%s\n%s" % [_hero_name(hero_id), GameIcons.rarity_name(spec), GameIcons.tile_stats(spec), spec.description]
			var critical := GameIcons.critical_tooltip(tile_id, hero_id)
			if not critical.is_empty():
				tooltip += "\n" + critical
			tile.tooltip_text = TileKeywords.with_definitions(tooltip, spec.description)
			tile.mouse_default_cursor_shape = CURSOR_POINTING_HAND
			GameIcons.decorate(tile, GameIcons.tile(tile_id, spec), 18)
			var fill := PANEL.lerp(GameIcons.rarity(spec), 0.16 if tile_id == signature else 0.07)
			tile.add_theme_stylebox_override("normal", _rarity_frame(spec, fill, 6, 8))
			tile.add_theme_stylebox_override("hover", _rarity_frame(spec, fill.lightened(0.12), 6, 8))
			tile.add_theme_stylebox_override("pressed", _rarity_frame(spec, fill.lightened(0.18), 6, 8))
			var detail_copy := "%s · %s" % [spec.label, spec.description]
			if tile_id == signature:
				detail_copy = "%s signature · %s" % [_hero_name(hero_id), detail_copy]
				_show_deck_tile(summary, details, spec, detail_copy)
			tile.pressed.connect(func(): _show_deck_tile(summary, details, spec, detail_copy))
			tile.focus_entered.connect(func(): _show_deck_tile(summary, details, spec, detail_copy))
			grid.add_child(tile)
	summary.add_child(details)
	deck.add_child(summary)
	deck.add_child(_label("Combine 3 matching tiles to choose an upgrade.", 15, MUTED))
	dialog.popup_centered(Vector2i(1030, 530))


func _show_deck_tile(summary: VBoxContainer, details: RichTextLabel, spec: Dictionary, copy: String) -> void:
	var previous := summary.get_node_or_null("TileStats")
	if previous != null:
		summary.remove_child(previous)
		previous.queue_free()
	var stats := CombatIcons.tile_stats(spec, 15)
	summary.add_child(stats)
	summary.move_child(stats, 0)
	TileKeywords.set_description(details, copy)


func _pick_draft(phase: String, id: String, choose_mastery := false) -> void:
	if phase in ["hero", "recruit"]:
		_after_class_choice(_run.choose_hero(id), choose_mastery)
		return
	match phase:
		"relic": _run.choose_relic(id)
		"starter": _run.choose_starter(id)
		"recruit_starter": _run.choose_recruit_starter(id)
	_host.run_return()


func _after_class_choice(advanced: bool, choose_mastery: bool) -> void:
	if advanced and choose_mastery and not _run.mastery_offers().is_empty():
		render(_run, "masteries")
	else:
		_refresh_after_choice(advanced)


func _map() -> void:
	_page_title(_location_name(), _route_caption())
	var region := HBoxContainer.new()
	region.add_theme_constant_override("separation", 15)
	region.size_flags_vertical = SIZE_EXPAND_FILL
	_layout.add_child(region)
	region.add_child(_map_board())
	var sidebar := _panel_stack(region, Vector2(270, 0))
	var scroll := ScrollContainer.new()
	scroll.name = "RouteDetails"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	sidebar.add_child(scroll)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 13)
	scroll.add_child(details)
	var relic_names := PackedStringArray()
	for id: String in _run.data.get("relics", []):
		relic_names.append(FrontierRun.RELICS.get(id, {}).get("label", id.capitalize()))
	var relics := _label("Relics  ·  " + ", ".join(relic_names), 15, MUTED)
	relics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(relics)
	if not str(_run.data.get("node_notice", "")).is_empty():
		details.add_child(_notice())
	_add_enchantment_notice(details)
	sidebar.add_child(HSeparator.new())
	sidebar.add_child(_label("Route key", 17, GOLD))
	var keys := GridContainer.new()
	keys.name = "RouteKey"
	keys.columns = 2
	keys.add_theme_constant_override("h_separation", 14)
	keys.add_theme_constant_override("v_separation", 8)
	sidebar.add_child(keys)
	for type in ["battle", "elite", "shop", "event", "rest", "boss"]:
		var key := HBoxContainer.new()
		key.add_theme_constant_override("separation", 9)
		keys.add_child(key)
		var texture := GameIcons.icon(type)
		if texture != null:
			key.add_child(_icon_view(texture, 22))
		key.add_child(_label(TYPE_NAMES[type] if texture else "%s   %s" % [TYPE_GLYPHS[type], TYPE_NAMES[type]], 15, MUTED))
	var footer := _footer_actions()
	footer.name = "ExpeditionMapFooter"
	if _run.loadout.storage.any(func(row: Array) -> bool: return not row.is_empty()):
		_add_storage_shortcut(footer)
	footer.add_child(_button("Manage tiles", func(): _host.run_show_arena()))


func _map_board() -> Control:
	var map_art: String = MAP_ART.get(_run.data.get("location", "brass"), MAP_ART.brass)
	var board := _board(Vector2.ZERO, map_art)
	board.name = "ExpeditionMapBoard"
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
	var buttons: Array[Button] = []
	for id: String in nodes:
		var node: Dictionary = nodes[id]
		var type: String = node.type
		var reachable: bool = active.has(id)
		var past: bool = id in visited
		var full_label := battle_title(node)
		var label := _compact_route_name(node, full_label)
		var button := _button(label, func(): _choose_node(id), reachable)
		button.custom_minimum_size.y = 0.0
		for state in ["normal", "hover", "pressed"]:
			var frame := button.get_theme_stylebox(state).duplicate() as StyleBox
			frame.content_margin_top = 4.0
			frame.content_margin_bottom = 4.0
			button.add_theme_stylebox_override(state, frame)
		GameIcons.decorate(button, "battle" if type == "opening" else type, 21)
		if button.icon == null:
			button.text = "%s  %s" % [TYPE_GLYPHS.get(type, "·"), label]
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.disabled = not reachable
		button.add_theme_font_size_override("font_size", 14)
		button.tooltip_text = "%s · %s%s" % [full_label, TYPE_NAMES.get(type, type.capitalize()), " · completed" if past else (" · reachable" if reachable else " · unavailable")]
		if type == "boss":
			button.name = {"tollkeeper": "TollkeeperBossNode", "brass_bellmaker": "BellmakerBossNode",
				"crucible_twins": "CrucibleTwinsBossNode", "glass_refraction_engine": "RefractionEngineBossNode"}.get(node.boss_id, "FirstBossNode")
		if node.has("reinforcement_beat"):
			button.name = "ReinforcementNode"
			button.tooltip_text += "\nReinforcements arrive on beat %d." % int(node.reinforcement_beat)
		button.accessibility_name = button.tooltip_text
		button.add_theme_stylebox_override("disabled", _box(PANEL_DARK, GOLD.darkened(0.35) if past else EDGE.darkened(0.15), 6, 4))
		button.add_theme_color_override("font_disabled_color", GOLD if past else MUTED.darkened(0.11))
		board.add_child(button)
		var point: Vector2 = points[id]
		button.anchor_left = point.x
		button.anchor_right = point.x
		button.anchor_top = point.y
		button.anchor_bottom = point.y
		buttons.append(button)
	var row_spacing := 0.81 / maxf(1.0, layers.size() - 1)
	board.resized.connect(func(): _fit_route_nodes(board, buttons, row_spacing))
	_fit_route_nodes(board, buttons, row_spacing)
	return board


static func battle_title(node: Dictionary) -> String:
	var type: String = node.get("type", "")
	var label: String = node.get("label", TYPE_NAMES.get(type, type.capitalize()))
	if node.has("reinforcement_beat"):
		return REINFORCEMENT_NAMES.get(label, "%s Reinforcements" % label)
	return label


static func _compact_route_name(node: Dictionary, full_label: String) -> String:
	var label := full_label.trim_prefix("The ")
	if node.has("reinforcement_beat") and not node.get("label", "") in REINFORCEMENT_NAMES:
		var original: String = node.get("label", "Patrol")
		return "%s Wave" % original.get_slice(" ", 0)
	return COMPACT_ROUTE_NAMES.get(label, label)


func _fit_route_nodes(board: Control, buttons: Array[Button], row_spacing: float) -> void:
	var width := minf(181.0, board.size.x * 0.265)
	var height := clampf(board.size.y * row_spacing - 4.0, 0.0, 41.0)
	for button in buttons:
		var font := button.get_theme_font("font")
		var frame_inset := button.get_theme_stylebox("normal").get_minimum_size().x
		var text_width := width - frame_inset - (27.0 if button.icon else 0.0)
		var points := 14
		while points > 12 and font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, points).x > text_width:
			points -= 1
		button.add_theme_font_size_override("font_size", points)
		button.offset_left = -width / 2.0
		button.offset_right = width / 2.0
		button.offset_top = -height / 2.0
		button.offset_bottom = height / 2.0


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
	_refresh_after_choice(_run.choose_node(id))


func _refresh_after_choice(advanced: bool) -> void:
	if advanced or not _run.save_error.is_empty():
		_host.run_return()


func _reward() -> void:
	var relic_offers: Array = _run.elite_relic_offers()
	if not relic_offers.is_empty():
		_elite_relic_draft(relic_offers)
		return
	var boss: bool = _run.data.get("node", {}).get("type") == "boss"
	var final_boss: bool = boss and _run.is_final_boss()
	var place_by_drag := _battle_overlay and not final_boss
	var title := "Final trophy · ends this expedition" if final_boss else ("Legendary reward" if boss else "Choose a reward")
	var milestone := ""
	var mystery: String = _run.mystery_kind()
	if boss:
		milestone = "%s Your trophy is recorded in the recap. Aether Marks and unlocks carry forward." % str(_run.data.get("node_notice", "")) if final_boss else "Leg %d cleared" % _leg_number()
	elif mystery == "salvage_bench":
		title = "Copy a Common tile"
	elif mystery == "class_cache":
		title = "Choose a class Uncommon"
	var lane: int = _run.reward_lane()
	var party := _party()
	var owner := _reward_owner(lane, party)
	if place_by_drag:
		title = {"salvage_bench": "Drag a copy to the sequence", "class_cache": "Drag an Uncommon to the sequence"}.get(
			mystery, "Drag a tile to the sequence")
	if lane >= 0 and lane < party.size():
		var hero_id: String = party[lane].id
		_reward_heading(title, milestone, hero_id)
		if final_boss and _battle_overlay:
			_layout.add_child(_label("Recorded in the recap. Marks and unlocks carry forward.", 15, MUTED))
	else:
		_page_title(title, milestone)
	var offers: Array = _run.data.get("offers", [])
	var wrapping: VBoxContainer
	var cards: HBoxContainer
	if mystery == "salvage_bench" and offers.size() > 4:
		wrapping = _scrolling_card_rows()
	else:
		cards = _cards_row()
	var notice := _notice()
	for index in range(offers.size()):
		if wrapping != null and index % 3 == 0:
			cards = _cards_row(wrapping)
		var id: String = offers[index]
		var tile: Dictionary = ArenaSim.TILES[id]
		var hint: String = _run.reward_hint(id)
		if hint in ["Third copy", "Owned copy"]:
			hint = ""
		if not owner.is_empty() and tile.get("base_tile", id) == ClassDecks.signature(owner):
			hint = "Signature tile" if hint.is_empty() else "Signature tile · " + hint
		var card := _choice(cards, tile.label, tile.description + ("\n" + hint if not hint.is_empty() else ""),
			"Send to storage" if place_by_drag else "Select", func():
				if place_by_drag:
					_send_reward_to_storage(id, notice)
				else:
					_claim_reward(id, notice))
		var select_tile: Button = card.get_child(card.get_child_count() - 1)
		select_tile.name = "RewardTile_" + id
		_add_tile_header(card, id, tile, owner, _battle_overlay)
		_add_reward_copy_pips(card.get_child(0), select_tile, id)
		if place_by_drag:
			_enable_reward_card_drag(card, id, select_tile)
		else:
			_enable_reward_card_click(card, select_tile)
	if not _battle_overlay:
		_layout.add_child(notice)
	var actions := _footer_actions()
	if _battle_overlay:
		notice.text = ""
		notice.autowrap_mode = TextServer.AUTOWRAP_OFF
		notice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		notice.size_flags_horizontal = SIZE_EXPAND_FILL
		actions.add_child(notice)
	if not final_boss and not place_by_drag:
		actions.add_child(_button("Manage tiles", func(): _host.run_show_arena()))
	var bonus: int = _run.reward_skip_gold()
	var skip := _button("Skip for +%d gold" % bonus if bonus > 0 else "Skip reward", func(): _claim_reward("skip", notice))
	skip.name = "SkipReward"
	if bonus == 0 and not final_boss and _run.reward_count() > 1:
		skip.tooltip_text = "The gold bonus is paid once per fight."
	actions.add_child(skip)
	var price: int = _run.reward_reroll_price()
	if price > 0:
		var reroll := _button("Reroll · %d gold" % price, func(): _reroll_reward(notice))
		reroll.name = "RerollReward"
		reroll.disabled = int(_run.data.gold) < price
		reroll.tooltip_text = "The price doubles each time you reroll in this act."
		if _run.reward_reroll_prefers_copy():
			reroll.tooltip_text = "This reroll favors a tile you already own. " + reroll.tooltip_text
		actions.add_child(reroll)


func _add_reward_copy_pips(header: HBoxContainer, action: Button, id: String) -> void:
	var status: Dictionary = _host.run_reward_copy_status(id)
	if status.is_empty():
		return
	var indicator := Control.new()
	indicator.name = "RewardCopyPips"
	indicator.custom_minimum_size = Vector2(30, 20)
	indicator.size_flags_vertical = SIZE_SHRINK_CENTER
	indicator.mouse_filter = MOUSE_FILTER_PASS
	indicator.draw.connect(_draw_reward_copy_pips.bind(indicator))
	header.add_child(indicator)
	_update_reward_copy_pips(indicator, action, id, status)


func refresh_reward_copy_pips() -> void:
	if not is_inside_tree() or not is_visible_in_tree() or not is_instance_valid(_layout):
		return
	for id: String in _run.data.get("offers", []):
		var action := _layout.find_child("RewardTile_" + id, true, false) as Button
		if action == null:
			continue
		var indicator := action.get_parent().find_child("RewardCopyPips", true, false) as Control
		if indicator != null:
			_update_reward_copy_pips(indicator, action, id, _host.run_reward_copy_status(id))


func _update_reward_copy_pips(indicator: Control, action: Button, id: String, status: Dictionary) -> void:
	var owned: int = status.owned
	var completes_set: bool = status.completes_set
	var unit := "copy" if owned == 1 else "copies"
	var summary := "%d matching %s on eligible timelines or in shared storage." % [owned, unit]
	if completes_set:
		summary += " This offer completes a set of three."
	elif owned >= 2:
		summary += " Make room for the upgrade to combine this offer."
	indicator.set_meta("owned_copies", owned)
	indicator.set_meta("completes_set", completes_set)
	indicator.tooltip_text = summary
	indicator.accessibility_name = summary
	action.accessibility_name = "%s. %s. %s" % [ArenaSim.TILES[id].label, action.text, summary]
	indicator.queue_redraw()


func _draw_reward_copy_pips(indicator: Control) -> void:
	var owned := mini(2, int(indicator.get_meta("owned_copies")))
	var complete: bool = indicator.get_meta("completes_set")
	for index in range(3):
		var center := Vector2(5 + 10 * index, indicator.size.y * 0.5)
		if index < owned:
			indicator.draw_circle(center, 3.4, GOLD if complete else TEAL, true, -1.0, true)
		else:
			var offered := index == owned
			indicator.draw_circle(center, 3.4, GOLD if offered else EDGE.lightened(0.22), false, 1.2, true)
			if offered and complete:
				indicator.draw_circle(center, 1.5, GOLD, true, -1.0, true)


func _enable_reward_card_drag(card: VBoxContainer, id: String, storage_button: Button) -> void:
	var panel := card.get_parent() as PanelContainer
	panel.name = "DragReward_" + id
	var spec: Dictionary = ArenaSim.TILES[id]
	var begin_drag := func(_position: Vector2, source: Control):
		var preview := _label(spec.label, 17, GameIcons.rarity(spec))
		preview.position = Vector2(12, -28)
		source.set_drag_preview(preview)
		return {"id": id, "reward": true}
	var remaining: Array[Node] = [panel]
	while not remaining.is_empty():
		var source := remaining.pop_back() as Control
		if source == null or source == storage_button:
			continue
		remaining.append_array(source.get_children())
		if source.mouse_filter != MOUSE_FILTER_IGNORE:
			source.mouse_default_cursor_shape = CURSOR_DRAG
			source.set_drag_forwarding(begin_drag.bind(source), Callable(), Callable())
	storage_button.tooltip_text = "Send %s to the first free span in storage." % spec.label


func _enable_reward_card_click(card: VBoxContainer, action: Button) -> void:
	var panel := card.get_parent() as PanelContainer
	var press := []
	var on_input := func(event: InputEvent, receiver: Control):
		if action.disabled or not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			press.assign([event.global_position])
			receiver.accept_event()
		elif not press.is_empty():
			var origin: Vector2 = press.pop_back()
			receiver.accept_event()
			if origin.distance_squared_to(event.global_position) <= 100.0:
				action.pressed.emit()
	# Keep the real button for keyboard navigation and leave every keyword hover in place.
	var remaining: Array[Node] = [panel]
	while not remaining.is_empty():
		var node := remaining.pop_back() as Control
		if node == null or node == action:
			continue
		remaining.append_array(node.get_children())
		if node.mouse_filter != MOUSE_FILTER_IGNORE:
			node.mouse_default_cursor_shape = CURSOR_POINTING_HAND
			node.gui_input.connect(on_input.bind(node))


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
	var art := GameIcons.hero_art(hero_id)
	if art:
		row.add_child(_icon_view(art, 32 if _battle_overlay else 54))
	var hero := _label(_hero_name(hero_id), 26 if _battle_overlay else 34, CREAM, true)
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
		if _battle_overlay:
			context.tooltip_text = milestone
			context.mouse_filter = MOUSE_FILTER_STOP
		else:
			_layout.add_child(_label(milestone, 17, MUTED))


func _elite_relic_draft(offers: Array) -> void:
	var title := "Choose a party relic" if _run.party_elite_relic_draft() else "Choose an elite relic"
	_relic_heading(title, "Tile rewards follow.")
	var cards := _cards_row()
	for offer: Dictionary in offers:
		var id: String = offer.id
		_relic_draft_card(cards, id, "EliteRelic_", func(): _refresh_after_choice(_run.choose_elite_relic(id)),
			offer.role, offer.companion, offer.get("owner", ""))


func _boss_relic_draft() -> void:
	_relic_heading("Choose a boss relic", "%s · Applies to the whole crew, including recruits." % _run.data.node.label)
	var cards := _cards_row()
	for offer: Dictionary in _run.boss_relic_offers():
		var id: String = offer.id
		_relic_draft_card(cards, id, "BossRelic_", func(): _claim_boss_relic(id))
	var skip := _button("Skip relic", func(): _claim_boss_relic("skip"))
	skip.name = "SkipBossRelic"
	_footer_actions().add_child(skip)


func _relic_heading(title: String, subtitle: String) -> void:
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 3)
	_layout.add_child(heading)
	var label := _label(title, 24 if _battle_overlay else 48, GOLD, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_child(label)
	if not subtitle.is_empty() and _battle_overlay:
		label.tooltip_text = subtitle
		label.mouse_filter = MOUSE_FILTER_STOP
	elif not subtitle.is_empty():
		var caption := _label(subtitle, 16, RELIC_MUTED)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		heading.add_child(caption)
	if not _battle_overlay:
		var margin := _layout.get_parent() as MarginContainer
		var fit_heading := func():
			var compact := size.y < 630
			label.add_theme_font_size_override("font_size", 36 if compact else 48)
			_layout.add_theme_constant_override("separation", 7 if compact else 13)
			margin.add_theme_constant_override("margin_top", 12 if compact else 25)
			margin.add_theme_constant_override("margin_bottom", 12 if compact else 25)
		_layout.resized.connect(fit_heading)
		fit_heading.call()


func _relic_draft_card(cards: HBoxContainer, id: String, button_prefix: String, select: Callable,
		role := "", companion := "", owner := "") -> void:
	var spec: Dictionary = FrontierRun.RELICS[id]
	var tone: Color = RELIC_DRAFT_TONES.get(id, GOLD)
	var card := _panel_stack(cards, Vector2.ZERO, true)
	card.add_theme_constant_override("separation", 2 if _battle_overlay else 6)
	var panel := card.get_parent() as PanelContainer
	panel.name = "RelicChoice_" + id
	panel.size_flags_vertical = SIZE_FILL if _battle_overlay else SIZE_SHRINK_CENTER
	var surround := StyleBoxEmpty.new()
	var inset := 3 if _battle_overlay else 12
	surround.content_margin_left = inset
	surround.content_margin_right = inset
	panel.add_theme_stylebox_override("panel", surround)

	var art := GameIcons.relic_art(id)
	var portrait := _icon_view(art, 63 if _battle_overlay else 205)
	portrait.name = "RelicPortrait"
	portrait.custom_minimum_size.x = 0
	if art is AtlasTexture:
		var material := ShaderMaterial.new()
		material.shader = RelicPortraitShader
		material.set_shader_parameter("portrait_region", Vector4(art.region.position.x, art.region.position.y,
			art.region.size.x, art.region.size.y))
		portrait.material = material
	card.add_child(portrait)
	portrait.modulate.a = 0.25
	portrait.create_tween().tween_property(portrait, "modulate:a", 1.0, 0.22).set_delay(panel.get_index() * 0.045)
	var title := _label(spec.label, 20 if _battle_overlay else 29, CREAM, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(title)
	if not owner.is_empty():
		_add_relic_owner(card, owner)
	if not role.is_empty():
		var role_label := _label(role, 13, tone)
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(role_label)
	var details := TileKeywords.description(spec.description, 13 if _battle_overlay else 17, RELIC_MUTED)
	details.name = "ChoiceDetails"
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _battle_overlay:
		details.add_theme_constant_override("line_separation", -1)
		details.fit_content = false
		details.scroll_active = true
		details.custom_minimum_size.y = 34
		details.size_flags_vertical = SIZE_EXPAND_FILL
	card.add_child(details)
	if not companion.is_empty():
		var tile: Dictionary = ArenaSim.TILES[companion]
		var hint := _label("Tile offer · " + tile.label, 13, GameIcons.rarity(tile))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.tooltip_text = "%s · %s" % [tile.get("rarity", "common").capitalize(), _hero_name(_reward_owner(_run.reward_lane(), _party()))]
		hint.mouse_filter = MOUSE_FILTER_PASS
		card.add_child(hint)

	var button := _button("Claim relic", select, true)
	button.name = button_prefix + id
	var claim: String = spec.label if owner.is_empty() else "%s for %s" % [spec.label, _hero_name(owner)]
	button.accessibility_name = "Claim %s. %s" % [claim, spec.description]
	button.size_flags_horizontal = SIZE_SHRINK_CENTER
	var fills := {"normal": Color("#3c2838"), "hover": Color("#664743"), "pressed": Color("#4b323c")}
	for state: String in fills:
		var fill: Color = fills[state]
		var surface := _box(fill, Color.TRANSPARENT, 16, 5 if _battle_overlay else 9)
		surface.content_margin_left = 16
		surface.content_margin_right = 16
		button.add_theme_stylebox_override(state, surface)
	button.add_theme_color_override("font_color", GOLD)
	card.add_child(button)
	if not _battle_overlay:
		var fit_card := func():
			var compact := size.y < 630 or size.x < 960
			portrait.custom_minimum_size.y = 112 if compact else 205
			title.add_theme_font_size_override("font_size", 22 if compact else 29)
			details.add_theme_font_size_override("normal_font_size", 14 if compact else 17)
		_layout.resized.connect(fit_card)
		fit_card.call()
	_enable_reward_card_click(card, button)
	if panel.get_index() == 0:
		button.grab_focus()


func _add_relic_owner(card: VBoxContainer, owner: String) -> void:
	var marker := HBoxContainer.new()
	marker.alignment = BoxContainer.ALIGNMENT_CENTER
	marker.add_theme_constant_override("separation", 4)
	marker.add_child(_icon_view(GameIcons.hero_art(owner), 20 if _battle_overlay else 25))
	var lane := _party().find_custom(func(hero: Dictionary): return hero.id == owner)
	var tone := TEAL if lane < 0 else CombatIcons.hero_color(lane)
	var label := _label("%s only" % _hero_name(owner), 13 if _battle_overlay else 15, tone)
	label.name = "ClassRelicOwner"
	label.size_flags_vertical = SIZE_SHRINK_CENTER
	marker.add_child(label)
	card.add_child(marker)


func _claim_boss_relic(id: String) -> void:
	_refresh_after_choice(_run.choose_boss_relic(id))


func _enchantment_draft() -> void:
	_page_title("Choose an enchantment", "Claim it for Tile storage or equip it now.")
	var cards := _cards_row()
	cards.size_flags_vertical = SIZE_SHRINK_BEGIN
	for offer: Dictionary in _run.enchantment_offers():
		var id: String = offer.id
		var tone := GameIcons.enchantment_color(id)
		var card := _panel_stack(cards, Vector2(0, 180), true)
		card.get_parent().add_theme_stylebox_override("panel", _box(PANEL, tone.darkened(0.50), 9, 14))
		var badge := GameIcons.enchantment_badge(id, 48)
		card.add_child(badge)
		var button := _button(offer.label, func(): _claim_enchantment(id), true)
		button.name = "Enchantment_" + id
		button.accessibility_name = "Claim %s. %s" % [offer.label, offer.description]
		card.add_child(button)
		var description := TileKeywords.description(offer.description, 16, MUTED)
		description.size_flags_vertical = SIZE_EXPAND_FILL
		card.add_child(description)
		_enable_reward_card_click(card, button)
		_add_enchantment_equip(card, id)
		if card.get_parent().get_index() == 0:
			button.grab_focus()
	var skip := _button("Skip enchantment", func(): _claim_enchantment("skip"))
	skip.name = "SkipEnchantment"
	_footer_actions().add_child(skip)


func _add_enchantment_equip(card: VBoxContainer, id: String) -> void:
	var targets := _enchantment_targets(id)
	if targets.is_empty():
		return
	var action: Button
	if targets.size() == 1:
		var target: Dictionary = targets[0]
		action = _button("Equip on " + target.label, func(): _claim_enchantment(id, target.destination))
		action.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		action.tooltip_text = target.label
	else:
		var menu := MenuButton.new()
		menu.text = "Equip on…"
		menu.flat = false
		menu.focus_mode = FOCUS_ALL
		var choices := menu.get_popup()
		for index in range(targets.size()):
			choices.add_item(targets[index].label, index)
		choices.id_pressed.connect(func(index: int): _claim_enchantment(id, targets[index].destination))
		action = menu
	action.name = "EquipDraftEnchantment_" + id
	action.accessibility_name = "%s · %s" % [action.text, TileEnchantments.info(id).label]
	card.add_child(action)


func _enchantment_targets(id: String) -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	var heroes := _party()
	for inventory: String in ["lanes", "storage"]:
		var rows: Array = _run.loadout[inventory]
		for row in range(rows.size()):
			for tile: Dictionary in rows[row]:
				var spec: Dictionary = ArenaSim.TILES[tile.id]
				if tile.has("enchantment") or not TileEnchantments.is_eligible(id, spec, tile.id):
					continue
				var stored := inventory == "storage"
				var destination := {"id": tile.id, "start": tile.start}
				destination["row" if stored else "lane"] = row
				var place := "Storage %d" % (row + 1) if stored else _hero_name(heroes[row].id)
				var caption := "%s · %s · %d" % [spec.label, place, int(tile.start) + 1]
				targets.append({"label": caption, "destination": destination})
	return targets


func _claim_enchantment(id: String, destination := {}) -> void:
	if _run.choose_enchantment(id, destination) or not _run.save_error.is_empty():
		_host.run_return()


func _claim_reward(id: String, notice: Label) -> void:
	if _host.run_claim_reward(id):
		_host.run_return()
	else:
		notice.text = _run.save_error if not _run.save_error.is_empty() else "No room for this tile. Manage tiles to free a continuous span."
		notice.tooltip_text = notice.text


func _send_reward_to_storage(id: String, notice: Label) -> void:
	if not _host.run_send_reward_to_storage(id):
		notice.text = _run.save_error if not _run.save_error.is_empty() else "No room in storage. Rearrange tiles or drag the reward to your sequence."
		notice.tooltip_text = notice.text
		notice.mouse_filter = MOUSE_FILTER_STOP


func _reroll_reward(notice: Label) -> void:
	if _run.reroll_reward():
		_host.run_return()
	else:
		notice.text = _run.save_error if not _run.save_error.is_empty() else "No new selection is available for this reward."
		notice.tooltip_text = notice.text


func _shop() -> void:
	_page_title(_run.data.get("node", {}).get("label", "Relay Market"), "")
	var notice := _notice()
	var offers: Array = _run.shop_stock()
	var deck_offer: String = _run.shop_deck_offer_id()
	var has_ledger_stock := offers.any(func(id: String):
		return id != deck_offer and not _run.shop_class_offer_owner(id).is_empty())
	var compact := has_ledger_stock or offers.size() > 4
	var cards: HBoxContainer
	var ledger_cards: HBoxContainer
	if not has_ledger_stock:
		cards = _cards_row()
	else:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		scroll.size_flags_vertical = SIZE_EXPAND_FILL
		_layout.add_child(scroll)
		var stock := VBoxContainer.new()
		stock.size_flags_horizontal = SIZE_EXPAND_FILL
		stock.add_theme_constant_override("separation", 10)
		scroll.add_child(stock)
		cards = _cards_row(stock)
		stock.add_child(_label("Guild Ledger", 19, GOLD, true))
		ledger_cards = _cards_row(stock)
		ledger_cards.name = "GuildLedgerStock"
	for id: String in offers:
		var tile: Dictionary = ArenaSim.TILES[id]
		var price: int = _run.shop_price(id)
		var purchased: bool = _run.shop_tile_purchased(id)
		var owner: String = _run.shop_class_offer_owner(id)
		var row := cards if owner.is_empty() or id == deck_offer else ledger_cards
		var caption := "Purchased" if purchased else "Buy · %d gold" % price
		var destination: String = "" if purchased else _host.run_shop_placement_label(id)
		var unavailable := purchased or int(_run.data.get("gold", 0)) < price or destination.is_empty()
		var body: String = tile.description
		if not purchased:
			body += "\n" + (destination if not destination.is_empty() else "Make room to buy this tile.")
		var card := _choice(row, tile.label, body, caption, func(): _buy_tile(id, notice), unavailable)
		var purchase: Button = card.get_child(card.get_child_count() - 1)
		purchase.name = "ShopTile_" + id
		var panel := card.get_parent() as PanelContainer
		if compact:
			panel.custom_minimum_size.y = 0
			card.add_theme_constant_override("separation", 8)
			card.get_child(0).add_theme_font_size_override("font_size", 22)
			card.get_child(1).add_theme_font_size_override("font_size", 15)
			_add_tile_header(card, id, tile, owner, true)
		else:
			_add_tile_header(card, id, tile, owner)
		if purchased:
			panel.add_theme_stylebox_override("panel", _box(Color("#1b242b"), Color("#56636a"), 9, 12 if compact else 18))
			card.modulate = Color("#a9afb4")
	if offers.is_empty():
		cards.add_child(_label("No tiles left.", 20, MUTED))
	_layout.add_child(notice)
	_continue(_leave)
	var actions := _footer_actions()
	actions.add_child(_button("Manage tiles", func(): _host.run_show_arena()))
	var heal_label := "Heal 15 HP each · 12 gold" if _party().size() > 1 else "Heal 15 HP · 12 gold"
	if _run.data.get("shop_healed", false):
		heal_label = "Heal used"
	elif not _party_needs_healing():
		heal_label = "Party at full health"
	var healing := _button(heal_label, func():
		_refresh_after_choice(_run.shop_heal())
	)
	healing.name = "ShopHeal"
	healing.disabled = int(_run.data.get("gold", 0)) < 12 or _run.data.get("shop_healed", false) or not _party_needs_healing()
	actions.add_child(healing)
	var relic_id: String = _run.data.get("shop_relic", "")
	if FrontierRun.RELICS.has(relic_id):
		var relic: Dictionary = FrontierRun.RELICS[relic_id]
		var buy_relic := _button("%s · 30 gold" % relic.label, func():
			_refresh_after_choice(_run.shop_buy_relic())
		)
		buy_relic.disabled = int(_run.data.get("gold", 0)) < 30
		buy_relic.tooltip_text = relic.description
		actions.add_child(buy_relic)


func _buy_tile(id: String, notice: Label) -> void:
	if _host.run_buy_shop(id):
		_host.run_return()
	else:
		notice.text = _run.save_error if not _run.save_error.is_empty() else "No room for this tile. Manage tiles to free a continuous span."


func _event() -> void:
	var mystery: String = _run.mystery_kind()
	if not mystery.is_empty():
		_mystery_event(mystery)
		return
	_page_title(_run.data.get("node", {}).get("label", "Roadside encounter"), _run.event_text())
	var cards := _cards_row()
	var options: Array = _run.event_options()
	for index in range(options.size()):
		var unavailable: bool = not _run.event_option_available(index)
		_choice(cards, str(options[index]), "", "Choose", func(): _pick_event(index), unavailable)
	_continue(_leave, "Leave this encounter.")


func _mystery_event(kind: String) -> void:
	match kind:
		"salvage_bench":
			_page_title("Salvage Bench", "Make one copy of a Common tile you own.")
			var available: bool = not _run.mystery_salvage_tiles().is_empty()
			var body := "Use the copy on your timeline or combine it with two you already own." if available else "You have no Common tiles to copy yet."
			_single_mystery_card("Copy a tile", body, "Browse tiles", "MysterySalvageOpen", _begin_mystery_salvage, available)
		"traveling_smith":
			_page_title("Traveling Smith", "Upgrade one tile for free.")
			var available := _has_smith_tile()
			var body := "Choose a tile from your timeline or storage and pick either forge branch." if available else "The smith has no upgrades for your current tiles."
			_single_mystery_card("One-tier upgrade", body, "Open forge", "MysterySmithOpen", func(): _host.run_mystery_forge(), available)
		"class_cache":
			_page_title("Class Cache", "Pick a category to find an Uncommon tile from your class deck.")
			var cards := _cards_row()
			var icons := {"damage": "battle", "support": "guard", "movement": "teleport"}
			for category: Dictionary in _run.mystery_cache_categories():
				var id: String = category.id
				var card := _choice(cards, category.label, category.description, "Browse tiles", func():
					_run.mystery_choose_cache_category(id)
					_host.run_return()
				)
				card.get_child(card.get_child_count() - 1).name = "MysteryCategory_" + id
				_add_card_icon(card, icons[id])
	var leave := _continue(_leave)
	leave.text = "Leave"
	leave.name = "LeaveMystery"


func _single_mystery_card(title: String, body: String, label: String, button_name: String, chosen: Callable, available: bool) -> void:
	var row := _cards_row()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var card := _choice(row, title, body, label, chosen, not available)
	var panel := card.get_parent() as PanelContainer
	panel.custom_minimum_size = Vector2(520, 320)
	panel.size_flags_horizontal = SIZE_SHRINK_CENTER
	panel.size_flags_vertical = SIZE_SHRINK_CENTER
	card.get_child(card.get_child_count() - 1).name = button_name
	_add_card_icon(card, "forge")


func _begin_mystery_salvage() -> void:
	_run.mystery_begin_salvage()
	_host.run_return()


func _has_smith_tile() -> bool:
	for row: Array in _run.loadout.lanes + _run.loadout.storage:
		for tile: Dictionary in row:
			if not _run.mystery_smith_options(tile.id).is_empty():
				return true
	return false


func _pick_event(index: int) -> void:
	_run.event_choice(index)
	_host.run_return()


func _rest() -> void:
	_page_title(_run.data.get("node", {}).get("label", "Rest site"), "")
	var cards := _cards_row()
	var can_heal := _party_needs_healing()
	_add_card_icon(_choice(cards, "Rest", "Recover up to 30% of max HP per hero.", "Heal" if can_heal else "Party at full health",
		func(): _run.rest("heal"); _host.run_return(), not can_heal), "rest")
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
		var recorded := PackedStringArray()
		for member: Dictionary in _party():
			var tile_id: String = trophies.get(member.id, "")
			if ArenaSim.TILES.has(tile_id):
				recorded.append("%s · %s" % [_hero_name(member.id), ArenaSim.TILES[tile_id].label])
		var legacy_trophy: String = _run.data.get("trophy", "")
		if trophies.is_empty() and ArenaSim.TILES.has(legacy_trophy):
			recorded.append(ArenaSim.TILES[legacy_trophy].label)
		if not recorded.is_empty():
			detail += "\n\nRecorded trophies\n" + "\n".join(recorded)
		var mastered := PackedStringArray()
		for id: String in _run.data.get("new_masteries", []):
			mastered.append(_hero_name(id))
		if not mastered.is_empty():
			detail += "\n\nMasteries unlocked · " + ", ".join(mastered)
	detail += "\n\n+%d Aether Marks this run." % int(_run.data.get("marks_earned", 0))
	detail += "\n%d Aether Marks available." % int(_run.profile.get("marks", 0))
	_choice(cards, "Victory" if victory else "Defeat", detail, "", Callable())
	_continue(func(): _finish(false)).text = "Back to title"
	_footer_actions().add_child(_button("Open Aether Chart", func(): _finish(true)))


func _finish(show_chart: bool) -> void:
	if _run.finish_run():
		if show_chart:
			_host.run_show_chart()
		else:
			_host.run_menu()
	elif not _run.save_error.is_empty():
		_host.run_return()


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
				"shot_artifice": "Camp and reward unlock", "guard_artifice": "Camp and reward unlock",
				"enchantments": "Reward unlock"
			}.get(id, "Upgrade")
		})
	_aether_chart.render(int(_run.profile.get("marks", 0)), entries, _run.data.is_empty())


func _buy_chart_node(id: String) -> void:
	if _run.buy_meta(id):
		_chart()


func _render_class_roster() -> void:
	var available: Array = _run.available_classes()
	var entries: Array[Dictionary] = []
	for id: String in FrontierRun.HEROES:
		var hero: Dictionary = FrontierRun.HEROES[id]
		entries.append({"id": id, "label": hero.label, "description": hero.description,
			"cost": _run.class_unlock_cost(id), "owned": id in available,
			"mastery": id in _run.profile.mastered_classes})
	if _choosing_starter:
		_class_roster.render_picker(entries)
	else:
		_class_roster.render(entries, int(_run.profile.marks), _run.data.is_empty())


func _buy_roster_class(id: String) -> void:
	if not _choosing_starter and _run.buy_class(id):
		_render_class_roster()


func _pick_starter_class(id: String, choose_mastery: bool) -> void:
	if _choosing_starter:
		_after_class_choice(_run.choose_preferred_hero(id), choose_mastery)


func _close_class_roster() -> void:
	if _choosing_starter:
		_host.run_return()
	else:
		render(_run, "chart")


func _page_title(title: String, subtitle: String, compact := false) -> void:
	_layout.add_child(_label(title, 27 if _battle_overlay or compact else 44, CREAM, true))
	if subtitle.is_empty():
		return
	var text := _label(subtitle, 15 if compact else 17, MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_layout.add_child(text)


func _notice() -> Label:
	var note := _label(_run.data.get("node_notice", ""), 15, TEAL)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return note


func _cards_row(parent: Control = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9 if _battle_overlay else 15)
	row.size_flags_vertical = SIZE_EXPAND_FILL
	if parent == null:
		parent = _layout
	parent.add_child(row)
	return row


func _scrolling_card_rows() -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_layout.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 15)
	scroll.add_child(rows)
	return rows


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


func _choice(parent: Control, name: String, body: String, cta: String, chosen: Callable,
		disabled := false, tile_preview := false) -> VBoxContainer:
	var compact := _battle_overlay or tile_preview
	var card := _panel_stack(parent, Vector2(0, 0 if compact else 280), true)
	if compact:
		card.add_theme_constant_override("separation", 3 if _battle_overlay and not tile_preview else 5)
	if not name.is_empty():
		var title := _label(name, 22 if compact else 27, CREAM, true)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if _battle_overlay and not tile_preview:
			title.add_theme_font_size_override("font_size", 18)
			title.max_lines_visible = 2
			title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			title.tooltip_text = name
			title.mouse_filter = MOUSE_FILTER_PASS
		card.add_child(title)
	var details: Control
	if compact:
		var copy := TileKeywords.description(body, 14, MUTED, TILE_DESCRIPTION_EXCLUSIONS)
		copy.add_theme_constant_override("line_separation", -1)
		copy.fit_content = tile_preview
		copy.scroll_active = not tile_preview
		copy.custom_minimum_size.y = 0 if tile_preview else 28
		details = copy
	else:
		var copy := _label(body, 17, MUTED)
		copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details = copy
	details.name = "ChoiceDetails"
	details.size_flags_vertical = SIZE_EXPAND_FILL
	card.add_child(details)
	if not cta.is_empty():
		var action := _button(cta, chosen, true)
		action.disabled = disabled
		card.add_child(action)
	return card


func tile_hover_card(id: String, owner: String, enchantment_id: String) -> Control:
	var spec: Dictionary = ArenaSim.TILES[id]
	var body: String = spec.description
	var enchantment := TileEnchantments.info(enchantment_id)
	if not enchantment.is_empty():
		body += "\n\n%s · %s" % [enchantment.label, enchantment.description]
	var preview := VBoxContainer.new()
	preview.name = "TimelineTilePreview"
	preview.custom_minimum_size.x = 300
	var card := _choice(preview, spec.label, body, "", Callable(), false, true)
	var title := card.get_child(0) as Label
	var description := card.get_node("ChoiceDetails") as RichTextLabel
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_add_tile_header(card, id, spec, owner, true)
	# Godot sizes tooltips before their containers lay out the text.
	var frame := (card.get_parent() as PanelContainer).get_theme_stylebox("panel")
	description.size.x = preview.get_combined_minimum_size().x - frame.get_minimum_size().x
	return preview


func _add_tile_header(card: VBoxContainer, id: String, spec: Dictionary, owner := "", compact := false) -> void:
	var description := card.get_node("ChoiceDetails") as Control
	var copy := description as Label
	if copy != null:
		var details := TileKeywords.description(copy.text, copy.get_theme_font_size("font_size"),
			copy.get_theme_color("font_color"), TILE_DESCRIPTION_EXCLUSIONS)
		details.name = copy.name
		var position := copy.get_index()
		card.remove_child(copy)
		copy.queue_free()
		card.add_child(details)
		card.move_child(details, position)
		description = details
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3 if compact else 7)
	content.size_flags_vertical = SIZE_EXPAND_FILL
	card.add_child(content)
	card.move_child(content, description.get_index())
	var stats := CombatIcons.tile_stats(spec, 14 if compact else 16)
	var attack := stats.get_node_or_null("AttackStat") as Control
	if attack != null:
		attack.tooltip_text += "\n" + GameIcons.critical_tooltip(id, owner)
		attack.accessibility_name = attack.tooltip_text
	content.add_child(stats)
	description.reparent(content, false)
	description.size_flags_vertical = SIZE_EXPAND_FILL
	if _battle_overlay and not (description as RichTextLabel).fit_content:
		content.custom_minimum_size.y = description.custom_minimum_size.y
		description.custom_minimum_size.y = 0
	var panel := card.get_parent() as PanelContainer
	var color := GameIcons.rarity(spec)
	panel.add_theme_stylebox_override("panel", _tile_card_frame(spec, false, 12 if compact else 18))
	var icon_key := GameIcons.tile(id, spec)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if compact:
		var texture := GameIcons.icon(icon_key)
		if texture != null:
			row.add_child(_icon_view(texture, 34))
	else:
		_add_card_icon(card, icon_key, color)
	var rarity := GameIcons.rarity_badge(spec)
	rarity.text += "  " + GameIcons.rarity_pips(spec)
	rarity.size_flags_horizontal = SIZE_EXPAND_FILL
	if compact:
		rarity.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(rarity)
	var origin := GameIcons.tile_origin(id, spec)
	var class_id := owner if not owner.is_empty() else origin
	if not class_id.is_empty():
		row.add_child(GameIcons.hero_badge(class_id, compact))
		panel.tooltip_text = "%s signature" % _hero_name(origin) if owner.is_empty() else _hero_name(owner)
		if not owner.is_empty() and not origin.is_empty() and origin != owner:
			panel.tooltip_text += " · %s signature" % _hero_name(origin)
	card.add_child(row)
	card.move_child(row, 0)


func _tile_card_frame(spec: Dictionary, selected := false, margin := 18) -> StyleBoxFlat:
	var color := GameIcons.rarity(spec)
	var frame := _rarity_frame(spec, PANEL.lerp(color, 0.13 if selected else 0.04), 9, margin)
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


func _add_portrait(card: VBoxContainer, texture: Texture2D, height: int) -> void:
	if texture == null:
		return
	var portrait := TextureRect.new()
	portrait.texture = texture
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size.y = height
	portrait.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(portrait)
	card.move_child(portrait, 0)


func _panel_stack(parent: Control, minimum: Vector2, expand := false) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(PANEL, EDGE, 9, 13 if _battle_overlay else 18))
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


func _label(value: String, points: int, color: Color, display := false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", points)
	label.add_theme_color_override("font_color", color)
	if display and _display_font:
		label.add_theme_font_override("font", _display_font)
	return label


func _button(title: String, activate: Callable, primary := false, compact := false) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 30 if compact else (33 if _battle_overlay else 41)
	if compact:
		button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(activate)
	var fill := Color("#60492d") if primary else PANEL_DARK
	var border := GOLD if primary else EDGE
	var inset := 5 if compact else (7 if _battle_overlay else 12)
	button.add_theme_stylebox_override("normal", _box(fill, border, 6, inset))
	button.add_theme_stylebox_override("hover", _box(fill.lightened(0.12), GOLD, 6, inset))
	button.add_theme_stylebox_override("pressed", _box(fill.darkened(0.14), GOLD, 6, inset))
	button.add_theme_stylebox_override("disabled", _box(PANEL_DARK, EDGE, 6, inset))
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
