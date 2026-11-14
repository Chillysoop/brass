extends SceneTree

const Arena := preload("res://arena.tscn")
const FrontierRun := preload("res://scripts/frontier_run.gd")
const TEST_SEED := 81243

var failures: Array[String] = []
var save_path := "user://expedition-menu-test-%d.json" % Time.get_ticks_usec()
var game: Control
var menu: Control
var chart: Control


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	game = Arena.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.run.load_save(save_path)
	game.run.profile.marks = 20
	game.run_menu()
	menu = game.frontier_screen.find_child("ExpeditionMenu", true, false)
	chart = game.frontier_screen.find_child("AetherChartMenu", true, false)
	_check(menu != null and chart != null, "Title and chart must be integrated in the actual game scene.")
	if menu != null and chart != null:
		await _check_navigation()
		await _check_chart()
		await _check_crown_entry()
		await _check_glass_hard_entry()
	game.queue_free()
	await process_frame
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Expedition menu, saved run resume, and Aether Chart checks passed.")
	quit(0 if failures.is_empty() else 1)


func _check_navigation() -> void:
	_check(menu.is_visible_in_tree() and not chart.is_visible_in_tree(), "A fresh game opens on the title menu.")
	await _press_named(menu, "NewExpedition")
	_check(game.run.data.is_empty(), "Starting from the title must open region selection before creating a run.")
	_check_disabled(menu, "Region_glass", "Locked")
	_check_disabled(menu, "Region_crown", "Locked")
	_check_disabled(menu, "Region_moonwreck", "Coming soon")
	await _press_named(menu, "Back")
	await _press_named(menu, "NewExpedition")
	await _press_named(menu, "Region_brass")
	_check(game.run.data.is_empty(), "Selecting a region must open difficulty selection before creating a run.")
	_check_disabled(menu, "Difficulty_medium", "Locked")
	_check_disabled(menu, "Difficulty_hard", "Locked")
	var seed := menu.find_child("RunSeed", true, false) as LineEdit
	_check(seed != null, "Difficulty selection exposes the optional run seed.")
	if seed != null:
		seed.text = "0"
		seed.text_changed.emit(seed.text)
		_check_disabled(menu, "Difficulty_easy", "Start Easy")
		seed.text = str(TEST_SEED)
		seed.text_changed.emit(seed.text)
	await _press_named(menu, "Difficulty_easy")
	_check(game.run.data.get("phase") == "hero", "An available difficulty starts the hero draft.")
	_check(game.run.data.get("location") == "brass" and game.run.data.get("difficulty") == "easy",
		"The chosen region and difficulty must reach the run model.")
	_check(game.run.data.get("seed") == TEST_SEED, "The optional seed must reach the run model.")
	if game.run.data.get("phase") != "hero":
		return
	await _press_text(game.frontier_screen, "Choose")
	_check(game.run.data.get("phase") == "relic", "Choosing a hero advances the draft.")
	await _press_text(game.frontier_screen, "Save & title")
	_check(menu.is_visible_in_tree(), "Save & title returns from a draft to the title.")
	var restored := FrontierRun.new()
	_check(restored.load_save(save_path) and restored.data.get("phase") == "relic",
		"The latest draft phase is saved on disk.")
	await _press_named(menu, "ContinueRun")
	_check(game.run.data.get("phase") == "relic" and not menu.is_visible_in_tree(),
		"Continue reopens the saved draft.")
	await _press_text(game.frontier_screen, "Save & title")


func _check_chart() -> void:
	if game.run.data.is_empty():
		_check(game.run.start_run(TEST_SEED), "Active-run chart test needs a started expedition.")
		game.run_menu()
	await _press_named(menu, "AetherChart")
	_check(chart.is_visible_in_tree() and not menu.is_visible_in_tree(), "Aether Chart opens from the title.")
	if not chart.is_visible_in_tree():
		return
	await _press_named(chart, "stout_start")
	var unlock := chart.find_child("UnlockUpgrade", true, false) as Button
	_check(unlock != null and unlock.disabled, "Upgrades cannot be purchased during an active run.")
	var marks := int(game.run.profile.marks)
	chart.purchase_requested.emit("stout_start")
	_check(game.run.profile.marks == marks and "stout_start" not in game.run.profile.meta,
		"The run model also rejects an active-run purchase.")
	_check(game.run.abandon_run(), "Close the test expedition before buying chart upgrades.")
	game.run_show_chart()
	await process_frame
	await _press_named(chart, "curated_cache")
	var details := chart.find_child("SelectedUpgrade", true, false) as Label
	_check(details != null and details.text == "Gravity Hook", "A locked graph node remains inspectable.")
	unlock = chart.find_child("UnlockUpgrade", true, false) as Button
	_check(unlock != null and unlock.disabled, "A locked upgrade cannot be purchased before its prerequisite.")
	await _press_named(chart, "stout_start")
	await _press_named(chart, "UnlockUpgrade")
	_check("stout_start" in game.run.profile.meta and int(game.run.profile.marks) == marks - 5,
		"Buying the selected starting upgrade deducts its exact cost.")
	await _press_named(chart, "curated_cache")
	await _press_named(chart, "UnlockUpgrade")
	_check("curated_cache" in game.run.profile.meta and int(game.run.profile.marks) == marks - 13,
		"Purchasing the prerequisite unlocks its downstream chart node.")
	var restored := FrontierRun.new()
	_check(restored.load_save(save_path) and "curated_cache" in restored.profile.meta,
		"Chart purchases persist across reload.")
	await _press_named(chart, "ChartBack")
	_check(menu.is_visible_in_tree() and not chart.is_visible_in_tree(), "Chart Back returns to the title.")


func _check_crown_entry() -> void:
	game.run.profile.crown_easy_unlocked = true
	game.run_menu()
	await _press_named(menu, "NewExpedition")
	await _press_named(menu, "Region_crown")
	_check_disabled(menu, "Difficulty_medium", "Locked")
	_check_disabled(menu, "Difficulty_hard", "Coming soon")
	await _press_named(menu, "Difficulty_easy")
	_check(game.run.data.get("phase") == "hero" and game.run.data.get("location") == "crown"
		and game.run.data.get("difficulty") == "easy", "Crown Easy should start from the expedition menu after its unlock.")
	_check(game.run.abandon_run(), "Close the test Crown expedition.")
	game.run.profile.crown_medium_unlocked = true
	game.run_menu()
	await _press_named(menu, "NewExpedition")
	await _press_named(menu, "Region_crown")
	await _press_named(menu, "Difficulty_medium")
	_check(game.run.data.get("phase") == "hero" and game.run.data.get("location") == "crown"
		and game.run.data.get("difficulty") == "medium", "Crown Medium should start from the expedition menu after its unlock.")
	_check(game.run.abandon_run(), "Close the test Crown Medium expedition.")


func _check_glass_hard_entry() -> void:
	game.run.profile.glass_easy_unlocked = true
	game.run.profile.glass_medium_unlocked = true
	game.run_menu()
	await _press_named(menu, "NewExpedition")
	await _press_named(menu, "Region_glass")
	_check_disabled(menu, "Difficulty_hard", "Locked")
	game.run.profile.glass_hard_unlocked = true
	game.run_menu()
	await _press_named(menu, "NewExpedition")
	await _press_named(menu, "Region_glass")
	await _press_named(menu, "Difficulty_hard")
	_check(game.run.data.get("phase") == "hero" and game.run.data.get("location") == "glass"
		and game.run.data.get("difficulty") == "hard", "Glass Hard should start from the expedition menu after its unlock.")


func _press_text(parent: Control, prefix: String) -> void:
	await process_frame
	for control in parent.find_children("*", "Button", true, false):
		var button := control as Button
		if button.is_visible_in_tree() and button.text.begins_with(prefix):
			_click(button, prefix)
			await process_frame
			return
	_check(false, "Expected a visible button starting with “%s”." % prefix)


func _press_named(parent: Control, node_name: String) -> void:
	await process_frame
	var button := parent.find_child(node_name, true, false) as Button
	_click(button, node_name)
	await process_frame


func _click(button: Button, description: String) -> void:
	if button == null or not button.is_visible_in_tree() or button.disabled:
		_check(false, "Expected an enabled button for %s." % description)
		return
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)


func _check_disabled(parent: Control, node_name: String, caption: String) -> void:
	var button := parent.find_child(node_name, true, false) as Button
	_check(button != null and button.is_visible_in_tree() and button.disabled and button.text == caption,
		"%s should be visible and disabled with the label %s." % [node_name, caption])


func _check(passed: bool, description: String) -> void:
	if not passed:
		failures.append(description)
