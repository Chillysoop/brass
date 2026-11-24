extends SceneTree

const GameActionMenu = preload("res://scripts/game_action_menu.gd")
var failures: Array[String] = []
var calls := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for dimensions: Vector2i in [Vector2i(1280, 800), Vector2i(856, 565), Vector2i(856, 535)]:
		root.size = dimensions
		var host := Control.new()
		root.add_child(host)
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var header := HBoxContainer.new()
		host.add_child(header)
		header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		header.offset_left = 16
		header.offset_right = -16
		header.offset_top = 12
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(spacer)
		var menu := GameActionMenu.new()
		host.add_child(menu)
		menu.configure(host)
		header.add_child(menu.trigger)
		var disabled := Button.new()
		disabled.text = "Unavailable"
		disabled.disabled = true
		disabled.pressed.connect(func(): calls += 1000)
		menu.add_action(disabled)
		var group := VBoxContainer.new()
		menu.content.add_child(group)
		var last: Button
		for index in range(18):
			var item := Button.new()
			item.text = "Action %d" % index
			item.pressed.connect(func(): calls += 1)
			group.add_child(item)
			last = item
		await _settle()
		_check(not menu.visible and menu.trigger.is_visible_in_tree(), "The single top-right menu trigger is visible while its actions are collapsed.")
		_click(menu.trigger.get_global_rect().get_center())
		await _settle()
		_check(menu.visible and root.get_visible_rect().grow(0.1).encloses(menu.panel.get_global_rect()), "A long utility list stays inside %s." % dimensions)
		_check(menu.panel.get_global_rect().position.y >= menu.trigger.get_global_rect().end.y,
			"The utility panel opens below its top-right trigger.")
		if dimensions.y < 700:
			_check(menu._scroller.get_v_scroll_bar().visible, "Only the utility list scrolls when it has more actions than fit.")
		menu._scroller.ensure_control_visible(last)
		await _settle()
		var before := calls
		_click(last.get_global_rect().get_center())
		await _settle()
		_check(calls == before + 1 and not menu.visible, "Nested actions retain their callback and close the menu after activation.")
		menu.open()
		await _settle()
		_click(Vector2(20, root.size.y * 0.5))
		await _settle()
		_check(not menu.visible and root.gui_get_focus_owner() == menu.trigger, "Clicking outside dismisses the menu and restores trigger focus.")
		menu.open()
		await _settle()
		var cancel := InputEventKey.new()
		cancel.keycode = KEY_ESCAPE
		cancel.pressed = true
		Input.parse_input_event(cancel)
		await _settle()
		_check(not menu.visible, "Escape dismisses the utility menu.")
		host.queue_free()
		await process_frame
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("Game action menu placement, nested callbacks, long utility lists, outside click and Escape passed.")
	quit(0 if failures.is_empty() else 1)


func _settle() -> void:
	for frame in range(4):
		await process_frame


func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)


func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
