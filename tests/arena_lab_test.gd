extends SceneTree

const ArenaScene = preload("res://arena.tscn")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var lab = ArenaScene.instantiate()
	root.add_child(lab)
	await process_frame
	lab.set_physics_process(false)
	_check(lab.lanes.size() == 2, "Duo setup should start with two lanes.")
	var preview = lab.sim.target_for(0, "pull", "farthest")
	_check(preview.get("id") == "clockwork", "Pull's default preview should identify the far enemy.")
	var palette_tile: Button = lab.palette.get_child(2)
	_click(palette_tile.get_global_rect().get_center())
	await process_frame
	_check(lab.selected.get("id") == "guard", "Clicking the palette should select that tile.")
	var first_lane: Control = lab.lane_stack.get_child(0).get_child(1)
	var sixth_beat: Button = first_lane.get_child(5)
	_click(sixth_beat.get_global_rect().get_center())
	await process_frame
	_check(lab.lanes[0].size() == 3, "An occupied span must reject a clicked placement.")
	var second_lane: Control = lab.lane_stack.get_child(1).get_child(1)
	var third_beat: Button = second_lane.get_child(2)
	_click(third_beat.get_global_rect().get_center())
	await process_frame
	_check(lab.lanes[1].size() == 4, "Clicking an open span should place the selected tile.")
	lab._load_fixture("duo")
	await process_frame
	palette_tile = lab.palette.get_child(2)
	second_lane = lab.lane_stack.get_child(1).get_child(1)
	third_beat = second_lane.get_child(2)
	var from := palette_tile.get_global_rect().get_center()
	var to := third_beat.get_global_rect().get_center()
	_button_input(from, true)
	_motion(from, from.lerp(to, 0.6), true)
	_motion(from.lerp(to, 0.6), to, true)
	_button_input(to, false)
	await process_frame
	_check(lab.lanes[1].size() == 4, "Dragging the palette tile to an open span should place it.")
	lab._load_fixture("duo")
	lab._set_all(1, "lowest_hp")
	_check(lab.lanes[1][0].target == "self", "Set all must preserve Guard's target.")
	_check(lab.lanes[1][1].target == "lowest_hp", "Set all should update compatible tiles.")
	lab._load_fixture("duo")
	var original: Array = lab.lanes.duplicate(true)
	lab._place({"id": "pull"}, 0, 11)
	_check(lab.lanes == original, "An out-of-bounds drop must leave the layout unchanged.")
	lab._place({"id": "bash", "lane": 1, "start": 4}, 0, 2)
	_check(lab.lanes == original, "A failed cross-lane move must leave the original tile in place.")
	lab._place({"id": "guard"}, 0, 11)
	_check(lab.lanes == original, "A second out-of-bounds placement must leave the layout unchanged.")
	lab._place({"id": "guard"}, 1, 2)
	_check(lab.lanes[1].size() == original[1].size() + 1, "A tile should fit into a free span.")
	lab._load_fixture("duo")
	lab._action()
	lab.speed = 2
	lab._physics_process(1.0 / 60.0)
	_check(lab.sim.tick == 2, "2× speed should advance exactly two fixed steps.")
	lab._action()
	lab._physics_process(1.0 / 60.0)
	_check(lab.sim.tick == 2, "Pause should preserve the simulation tick.")
	lab._action()
	for step_index in range(3000):
		lab._physics_process(1.0 / 60.0)
		if lab.state == "finished":
			break
	_check(lab.sim.outcome == "victory", "The full fight should finish through the arena controls.")
	lab._reset_fight()
	_check(lab.state == "setup" and lab.lanes == original, "Reset should return to setup and retain the edited layout.")
	lab._load_fixture("solo")
	_check(lab.lanes.size() == 1, "Solo setup should switch to one lane.")
	if failures.is_empty():
		print("Arena controls checks passed.")
	else:
		for failure in failures:
			printerr(failure)
	lab.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _check(passed: bool, description: String) -> void:
	if not passed:
		failures.append(description)

func _click(point: Vector2) -> void:
	_button_input(point, true)
	_button_input(point, false)

func _button_input(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)

func _motion(from: Vector2, to: Vector2, dragging: bool) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	event.relative = to - from
	if dragging:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)
