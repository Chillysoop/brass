extends SceneTree

const Arena = preload("res://arena.tscn")
const FrontierRun = preload("res://scripts/frontier_run.gd")
const ArenaSim = preload("res://scripts/arena_sim.gd")
var failures: Array[String] = []
var save_path := "user://frontier-playtest-%s.json" % str(Time.get_ticks_usec())

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = Arena.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.run.load_save(save_path)
	game.run_start(42)
	var run: RefCounted = game.run
	_check(run.profile.meta.is_empty(), "Fresh save starts with no meta upgrades.")
	var hero: String = "warden" if "warden" in run.data.offers else run.data.offers[0]
	_check(run.choose_hero(hero), "Hero draft")
	_check(run.choose_relic("pocket_bell"), "Relic draft")
	_check(run.choose_starter("bash"), "Starter tile draft")
	var battles := 0
	for step in range(30):
		match run.data.phase:
			"combat":
				game.run_show_arena()
				game._action()
				game.speed = 2
				for tick in range(3000):
					game._physics_process(1.0 / 60)
					if game.state == "finished":
						break
				_check(game.sim.outcome == "victory", "Win %s (%d HP)" % [run.data.node.label, run.data.hp])
				battles += 1
				if game.sim.outcome != "victory":
					break
				game._action()
			"reward":
				var id: String = run.data.offers[0]
				if run.data.node.type != "boss":
					for preferred in ["hook_bash", "shield_ram", "bash", "shot", "slam"]:
						if preferred in run.data.offers:
							id = preferred
							break
				if not game.run_claim_reward(id):
					_check(game.run_claim_reward("skip"), "Skip a reward if its tile cannot fit.")
			"map":
				var next: Array = run.available_nodes()
				_check(not next.is_empty(), "Route has a reachable node.")
				if next.is_empty():
					break
				var node: Dictionary = next[0]
				for option: Dictionary in next:
					if option.type == "battle":
						node = option
						break
				_check(run.choose_node(node.id), "Travel to a reachable node.")
				game.run_return()
			"shop":
				run.shop_heal()
				run.leave_node()
			"event":
				_check(run.event_choice(0), "Resolve event.")
			"rest":
				_check(run.rest("heal"), "Heal before the boss.")
			"result":
				break
			_:
				_check(false, "Unexpected run phase: " + str(run.data.phase))
				break
	_check(battles >= 3, "Run should include multiple combat nodes.")
	_check(run.data.get("result") == "victory" and run.data.phase == "result", "Fresh run should defeat the Tollkeeper.")
	_check(run.profile.medium_unlocked and int(run.profile.marks) >= 19, "Boss should bank the first clear and unlock Medium.")
	var restored := FrontierRun.new()
	_check(restored.load_save(save_path) and restored.data.get("result") == "victory", "Victory must survive reload.")
	_check(not restored.finish_combat(true, 100), "Resuming the recap cannot pay the boss twice.")
	_check(not restored.buy_meta("stout_start"), "Meta purchases are blocked until the run is closed.")
	_check(restored.finish_run() and restored.buy_meta("stout_start"), "Spend marks between runs.")
	_check(restored.start_run(42) and int(restored.data.max_hp) == 108, "Bought HP upgrade applies to the next run.")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	for failure in failures:
		printerr(failure)
	if failures.is_empty():
		print("Frontier playthrough passed: %d fights, %d HP at the clear." % [battles, run.data.hp])
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
