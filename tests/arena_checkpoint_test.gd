extends SceneTree

const ArenaScene = preload("res://arena.tscn")
const FrontierRun = preload("res://scripts/frontier_run.gd")

const SAVE_PATH := "user://arena-checkpoint-test.json"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var lab = ArenaScene.instantiate()
	root.add_child(lab)
	lab.set_physics_process(false)
	var run: FrontierRun = lab.run
	run.load_save(SAVE_PATH)
	if _check(run.start_run(42) and run.choose_hero("warden")
		and run.choose_relic(run.data.offers[0]) and run.choose_starter("bash"), "Start the real first fight with one tile."):
		_check_discard(lab)
		_check_battle_save(lab)
		_check_camp_save(lab)
	lab.queue_free()
	await process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		var path := ProjectSettings.globalize_path(SAVE_PATH + suffix)
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			DirAccess.remove_absolute(path)
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("Last-tile guard, battle save retry, Save & title, and camp forge rollback passed.")
	quit(0 if failures.is_empty() else 1)


func _check_discard(lab: Control) -> void:
	lab.run_show_arena()
	lab._open_storage()
	var first := {"id": "bash", "lane": 0, "start": 0}
	lab._select(first)
	var discard := lab.storage_screen.find_child("DiscardSelected", true, false) as Button
	discard.pressed.emit()
	_check(not lab.discard_dialog.visible and lab.lanes[0].size() == 1,
		"Discard selected must refuse to open confirmation for the last equipped tile.")
	lab.storage_place(0, 0, first)
	lab._action()
	_check(lab.state == "setup" and lab.storage_rows[0].size() == 1,
		"Moving the last tile to storage is allowed and prevents starting until it is equipped.")
	lab.storage_pick(0, lab.storage_rows[0][0])
	discard.pressed.emit()
	_check(not lab.discard_dialog.visible and lab.storage_rows[0].size() == 1,
		"The last tile cannot be discarded from storage either.")
	var stored := {"id": "bash", "lane": -1, "row": 0, "start": 0}
	if _set_save_block(true):
		lab._place(stored, 0, 2)
		_check(lab.lanes[0].is_empty() and lab.storage_rows[0].size() == 1 and not lab.run.save_error.is_empty(),
			"A rejected write rolls the tile move back to storage.")
		_set_save_block(false)
	lab._place(stored, 0, 2)
	var restored := FrontierRun.new()
	_check(restored.load_save(SAVE_PATH) and restored.loadout.lanes[0].size() == 1
		and restored.loadout.lanes[0][0].start == 2 and restored.loadout.storage[0].is_empty(),
		"A normal transfer restores the last tile to the timeline and saves its firing position.")


func _check_battle_save(lab: Control) -> void:
	var run: FrontierRun = lab.run
	var before := run.data.duplicate(true)
	if not _set_save_block(true):
		return
	lab.action.pressed.emit()
	for step in range(2600):
		lab._physics_process(1.0 / 60.0)
		if lab.state == "finished":
			break
	_check(lab.sim.outcome == "victory" and lab.action.text == "Retry save" and not lab.victory_badge.visible,
		"An unwritten win should stay in the arena with Retry save instead of Victory.")
	_check(run.data == before and not run.save_error.is_empty(), "The failed win leaves the run at its prior checkpoint.")
	var completed_tick: int = lab.sim.tick
	_set_save_block(false)
	lab.action.pressed.emit()
	_check(lab.sim.tick == completed_tick and lab.victory_badge.visible and lab.action.text == "Continue",
		"Retry save records the result without replaying the battle.")
	var restored := FrontierRun.new()
	_check(restored.load_save(SAVE_PATH) and restored.data.phase == "reward" and restored.data.gold == int(before.gold) + 12,
		"Reload after retry grants the opening reward and its gold exactly once.")
	lab.action.pressed.emit()
	if not _set_save_block(true):
		return
	(lab.frontier_screen.find_child("SaveTitle", true, false) as Button).pressed.emit()
	_check(lab.frontier_screen.find_child("SaveTitle", true, false) != null and not run.save_error.is_empty(),
		"Save & title reports a failed save on the current screen.")
	_set_save_block(false)
	(lab.frontier_screen.find_child("SaveTitle", true, false) as Button).pressed.emit()
	_check(lab.frontier_screen.find_child("SaveTitle", true, false) == null and run.save_error.is_empty(),
		"Save & title retries the write and opens the title when it succeeds.")


func _check_camp_save(lab: Control) -> void:
	var run: FrontierRun = lab.run
	run.data.phase = "rest"
	run.data.node = run.data.layers[-2][0].duplicate(true)
	run.data.offers = []
	if not _check(run.save(), "Save the camp checkpoint before trying the forge."):
		return
	lab.run_rest_forge()
	lab._select({"id": "bash", "lane": 0, "start": 2})
	lab.camp_button.pressed.emit()
	if not _check(lab.forge_screen.visible and _set_save_block(true), "Open the camp forge and block its write."):
		return
	lab.forge_choose("shield_ram")
	_check(lab.forge_screen.visible and run.data.phase == "rest" and lab.lanes[0][0].id == "bash"
		and not run.save_error.is_empty(), "A failed camp upgrade keeps Bash and the forge open.")
	_set_save_block(false)
	lab.forge_choose("shield_ram")
	var restored := FrontierRun.new()
	_check(restored.load_save(SAVE_PATH) and restored.data.phase == "map" and restored.loadout.lanes[0][0].id == "shield_ram",
		"A successful retry saves the upgrade and consumes the rest site together.")


func _set_save_block(blocked: bool) -> bool:
	var path := ProjectSettings.globalize_path(SAVE_PATH + ".tmp")
	var result := DirAccess.make_dir_absolute(path) if blocked else DirAccess.remove_absolute(path)
	return _check(result == OK, "Set isolated save write failure to %s." % blocked)


func _check(passed: bool, description: String) -> bool:
	if not passed:
		failures.append(description)
	return passed
