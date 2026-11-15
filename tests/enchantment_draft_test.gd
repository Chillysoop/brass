extends SceneTree

const FrontierRun := preload("res://scripts/frontier_run.gd")

var failures: Array[String] = []
var path := "user://enchantment-draft-test-%d.json" % Time.get_ticks_usec()


func _initialize() -> void:
	_check_draft()
	for suffix: String in ["", ".tmp", ".bak"]:
		var saved := path + suffix
		if FileAccess.file_exists(saved):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(saved))
	if failures.is_empty():
		print("Enchantment Aether Chart gate, draft on three Brass difficulties, save and resume, and skip pass.")
	for failure in failures:
		printerr(failure)
	quit(0 if failures.is_empty() else 1)


func _check_draft() -> void:
	var run := FrontierRun.new()
	run.load_save(path)
	run.profile.marks = 21
	_check(not run.buy_meta("enchantments"), "Tile Enchantments must require Gravity Hook.")
	if not _check(run.start_run(42) and _win_opening(run), "Win the opening on a locked profile."):
		return
	_check(run.data.get("phase") == "map" and run.enchantment_offers().is_empty()
		and not run.choose_enchantment("guarded") and not run.buy_meta("enchantments"),
		"A locked expedition cannot draft or buy enchantments.")
	if not _check(run.abandon_run() and run.buy_meta("stout_start") and run.buy_meta("curated_cache")
			and run.buy_meta("enchantments"), "Buy Tile Enchantments between expeditions with the prerequisite."):
		return
	_check(run.profile.marks == 0 and not run.buy_meta("enchantments"), "Charge 8 Marks once for the enchantment unlock.")
	if not _check(run.start_run(42) and _draft_opening(run) and run.finish_combat(false, 0)
			and run.data.get("phase") == "result" and run.enchantment_offers().is_empty() and run.abandon_run(),
			"Defeat at the opening must not open the enchantment draft."):
		return

	var expected := ["guarded", "longshot", "splash"]
	run.profile.medium_unlocked = true
	run.profile.hard_unlocked = true
	for difficulty: String in ["easy", "medium", "hard"]:
		if not _check(run.start_run(42, difficulty) and _win_opening(run), "Win the Brass Frontier opening on %s." % difficulty):
			return
		var draft := run.enchantment_offers()
		_check(run.data.get("phase") == "enchantment" and draft.map(func(offer: Dictionary): return offer.id) == expected,
			"Offer all three enchantments after resolving the standard tile reward.")
		_check(run.load_save(path) and run.enchantment_offers() == draft, "Resume the same open draft.")
		var original_save_path := run.save_path
		run.save_path = path + ".missing/file.json"
		_check(not run.choose_enchantment("guarded") and run.data.get("phase") == "enchantment"
			and run.active_enchantment().is_empty(), "A failed save must restore the open draft.")
		run.save_path = original_save_path
		var chosen := "skip" if difficulty == "medium" else "longshot"
		_check(not run.choose_enchantment("warded") and run.choose_enchantment(chosen),
			"Reject an invalid choice and confirm a valid pick or skip.")
		_check(run.load_save(path) and run.data.get("phase") == "map" and run.active_enchantment() ==
			("" if chosen == "skip" else chosen) and not run.choose_enchantment("guarded"),
			"The draft resolves to the map and the choice persists without another claim.")
		_check(run.abandon_run(), "Return to title before starting another expedition.")
	run.profile.glass_easy_unlocked = true
	_check(run.start_run(42, "easy", "glass") and _win_opening(run) and run.data.get("phase") == "map",
		"The first enchantment draft applies only to Brass Frontier.")


func _win_opening(run: FrontierRun) -> bool:
	return _draft_opening(run) and run.finish_combat(true, 85) and run.reward("skip")


func _draft_opening(run: FrontierRun) -> bool:
	return run.choose_hero(run.data.offers[0]) and run.choose_relic("pocket_bell") \
		and run.choose_starter("bash")


func _check(success: bool, label: String) -> bool:
	if not success:
		failures.append(label)
	return success
