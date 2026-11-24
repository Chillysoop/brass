extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const ForgeScreen = preload("res://scripts/forge_screen.gd")
const TilePacking = preload("res://scripts/tile_packing.gd")
const TileKeywords = preload("res://scripts/tile_keywords.gd")
const FrontierRun = preload("res://scripts/frontier_run.gd")

class PreviewHost extends RefCounted:
	func tile_hover_card(id: String, _owner: String, _enchantment: String) -> Control:
		return TileKeywords.description(ArenaSim.TILES[id].description, 14, Color.WHITE)

class ForgeHost extends Control:
	var campaign := false
	var retry_options := {"relics": ["pocket_bell", "barrage_rack"]}
	var run := {"data": {"phase": "combat", "relics": ["pocket_bell", "barrage_rack"]}}
	var frontier_screen := PreviewHost.new()
	var chosen := ""
	var closed := false
	var saved := false
	var kept := false
	var editable := false
	var fits := true
	func tile_spec(id: String) -> Dictionary:
		return ArenaSim.TILES[id]
	func forge_owner() -> String:
		return ""
	func forge_layout(_id: String) -> Dictionary:
		return {}
	func forge_can_fit(_id: String) -> bool:
		return fits
	func forge_choose(id: String, _plan: Variant) -> void:
		chosen = id
	func forge_close() -> void:
		closed = true
	func run_save_title() -> void:
		saved = true
	func run_keep_reward_tile() -> void:
		kept = true
	func forge_edit_layout(_id: String) -> void:
		editable = true

var failures: Array[String] = []
var host: ForgeHost
var forge: ForgeScreen
var checked := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	host = ForgeHost.new()
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	forge = ForgeScreen.new()
	host.add_child(forge)
	forge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	forge.configure(host)
	var ids: Array = ArenaSim.TILES.keys()
	ids.sort_custom(func(a: String, b: String): return ArenaSim.TILES[a].description.length() > ArenaSim.TILES[b].description.length())
	if DisplayServer.get_name() != "headless":
		ids = ids.slice(0, 12) + ["bash", "shield_ram", "blink"] + ids.filter(func(id: String): return TilePacking.forge_tiers(id).is_empty())
	for window_size: Vector2i in [Vector2i(856, 535), Vector2i(856, 565), Vector2i(1280, 800)]:
		root.size = window_size
		for id: String in ids:
			if TilePacking.forge_tiers(id).is_empty():
				forge.open("bash", 1)
				forge._inspect(id)
			else:
				forge.open(id, 1)
			await _settle()
			_check_copy_and_tree(id)
			checked += 1
		forge.open("vanishing_cut_upgrade_legendary_power", 1)
		await _settle()
		await _proof("forge-full-copy-%d-%d" % [window_size.x, window_size.y])
	await _check_relic_header()
	await _check_actions()
	host.queue_free()
	await process_frame
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("Forge full-text visibility, grounded paths, top-right utilities and direct/manual upgrade behavior passed in %d catalog/view cases." % checked)
	quit(0 if failures.is_empty() else 1)


func _check_copy_and_tree(id: String) -> void:
	var viewport := root.get_visible_rect().grow(1.0)
	var copy := forge._detail_description
	_check(not copy.scroll_active and copy.fit_content and copy.get_parsed_text() == ArenaSim.TILES[id].description,
		"Forge always exposes the exact complete %s ability without a text scrollbar." % id)
	_check(copy.get_content_height() <= copy.size.y + 1.0
		and viewport.encloses(copy.get_global_rect()) and viewport.encloses(forge._details.get_global_rect()),
		"Full %s description fits %s: %d inside %s; panel %s." % [id, root.size, copy.get_content_height(), copy.get_global_rect(), forge._details.get_global_rect()])
	_check(copy.get_theme_font_size("normal_font_size") >= 14, "Ability text never shrinks below 14px.")
	_check(viewport.encloses(forge._board.get_global_rect()) and viewport.encloses(forge._menu.trigger.get_global_rect()),
		"Forge tree and game menu stay inside %s." % root.size)
	for card: Button in forge._cards.values():
		var title: Label = card.get_meta("choice_name")
		_check(card.get_theme_stylebox("normal") is StyleBoxFlat and viewport.encloses(card.get_global_rect())
			and card.get_global_rect().grow(1.0).encloses(title.get_global_rect()),
			"Grounded %s path and complete name fit its own card at %s." % [card.name, root.size])


func _check_relic_header() -> void:
	root.size = Vector2i(856, 535)
	var original_relics: Array = host.retry_options.relics
	host.retry_options.relics = FrontierRun.RELICS.keys().slice(0, 30)
	forge.open("bash", 3)
	forge._clear_merge_intro()
	await _settle()
	var viewport := root.get_visible_rect().grow(1.0)
	var relic_strip := forge._relics.get_parent() as ScrollContainer
	_check(forge._relics.get_child_count() == 30 and relic_strip != null
		and relic_strip.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO
		and relic_strip.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"Thirty Forge relics remain available in a horizontal-only inventory strip.")
	_check(viewport.encloses(relic_strip.get_global_rect())
		and viewport.encloses(forge._confirm.get_global_rect())
		and viewport.encloses(forge._menu.trigger.get_global_rect())
		and relic_strip.get_global_rect().end.x <= forge._confirm.global_position.x,
		"A full relic inventory keeps the primary upgrade and game menu inside the compact header.")
	var scrollbar := relic_strip.get_h_scroll_bar()
	_check(scrollbar.visible and scrollbar.max_value > scrollbar.page,
		"Overflowing Forge relics scroll horizontally instead of growing the header.")
	for icon: TextureRect in forge._relics.get_children():
		_check(icon.mouse_filter == Control.MOUSE_FILTER_STOP and not icon.tooltip_text.is_empty(),
			"Every overflow relic keeps its passive hover description.")
	_check_copy_and_tree("bash")
	await _proof("forge-thirty-relics-856-535")
	host.retry_options.relics = original_relics


func _check_actions() -> void:
	root.size = Vector2i(856, 535)
	forge.open("bash", 3, true, true)
	forge._clear_merge_intro()
	await _settle()
	_check(forge._menu.trigger.get_global_rect().position.x > root.size.x * 0.5
		and forge._relics.get_child_count() == 2 and forge._relics.get_global_rect().position.x < root.size.x * 0.5,
		"Relics remain at top left and utilities at top right.")
	for action: Button in [forge._save_reward, forge._edit_layout, forge._keep_reward]:
		_check(action.get_parent() == forge._menu.content, "Forge utility actions belong to the shared game menu.")
	forge._menu.open()
	await _settle()
	_check(root.get_visible_rect().encloses(forge._menu.panel.get_global_rect()), "The open utility menu fits compact Forge.")
	forge._save_reward.pressed.emit()
	await _settle()
	_check(host.saved, "Save & title remains connected through the game menu.")
	forge.open("bash", 3, true, true)
	forge._clear_merge_intro()
	forge._pick_path("shield_ram")
	_check(host.chosen == "shield_ram", "Reward paths still apply on one valid click.")
	host.chosen = ""
	forge.open("bash", 3)
	forge._clear_merge_intro()
	forge._pick_path("hook_bash")
	_check(host.chosen.is_empty() and not forge._confirm.disabled, "Manual combinations still inspect before confirmation.")
	forge._confirm.pressed.emit()
	_check(host.chosen == "hook_bash", "The pinned primary confirmation applies the inspected manual path.")
	host.chosen = ""
	host.campaign = true
	host.run.data.phase = "rest"
	forge.open("bash", 1)
	forge._pick_path("shield_ram")
	_check(host.chosen == "shield_ram", "Single-copy rest paths retain their direct pick behavior.")
	forge._menu.open()
	await _settle()
	await _proof("forge-game-menu")


func _settle() -> void:
	for frame in range(5):
		await process_frame


func _proof(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://%s.png" % label)


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
