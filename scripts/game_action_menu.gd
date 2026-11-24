extends Control

const PANEL := Color("#14232d")
const EDGE := Color("#b39460")
const TEXT := Color("#f3e7d1")

var trigger: Button
var panel: PanelContainer
var content: VBoxContainer
var _owner: Control
var _scroller: ScrollContainer


func _init() -> void:
	name = "GameActionMenu"
	mouse_filter = Control.MOUSE_FILTER_STOP
	trigger = Button.new()
	trigger.name = "GameMenuToggle"
	trigger.text = "☰"
	trigger.tooltip_text = "Game menu"
	trigger.accessibility_name = "Game menu"
	trigger.custom_minimum_size = Vector2(42, 34)
	trigger.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trigger.pressed.connect(func(): close() if visible else open())
	panel = PanelContainer.new()
	panel.name = "GameMenuPanel"
	var surface := StyleBoxFlat.new()
	surface.bg_color = PANEL
	surface.border_color = EDGE
	surface.set_border_width_all(1)
	surface.set_corner_radius_all(8)
	surface.content_margin_left = 12
	surface.content_margin_right = 12
	surface.content_margin_top = 12
	surface.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", surface)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	_scroller = ScrollContainer.new()
	_scroller.name = "GameMenuViewport"
	_scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroller.follow_focus = true
	panel.add_child(_scroller)
	content = VBoxContainer.new()
	content.name = "GameMenuActions"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	_scroller.add_child(content)
	content.child_entered_tree.connect(_wire_action)
	resized.connect(_fit)
	hide()


func configure(host: Control) -> void:
	_owner = host
	if get_parent() == null:
		host.add_child(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trigger.add_theme_color_override("font_color", TEXT)
	trigger.add_theme_font_size_override("font_size", 20)
	content.minimum_size_changed.connect(_fit)


func add_action(control: Control, close_on_press := true) -> void:
	if not close_on_press:
		control.set_meta("menu_keep_open", true)
	if control.get_parent() != null:
		control.reparent(content, false)
	else:
		content.add_child(control)
	_wire_action(control)


func add_existing(control: Control, close_on_press := true) -> void:
	add_action(control, close_on_press)


func wire_action(control: Control) -> void:
	_wire_action(control)


func _wire_action(node: Node) -> void:
	if not node is Control:
		return
	var control := node as Control
	if control.get_parent() == content or control is BaseButton:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if control is BaseButton:
		control.custom_minimum_size.y = maxf(32.0, control.custom_minimum_size.y)
		if not control is OptionButton and not control.get_meta("menu_keep_open", false) \
				and not control.pressed.is_connected(_close_after_action):
			control.pressed.connect(_close_after_action)
	elif control is Container:
		if not control.child_entered_tree.is_connected(_wire_action):
			control.child_entered_tree.connect(_wire_action)
		for child: Node in control.get_children():
			_wire_action(child)


func _close_after_action() -> void:
	if is_inside_tree() and not is_queued_for_deletion():
		_close_from_action.call_deferred()


func _close_from_action() -> void:
	close(false)


func open() -> void:
	if not is_instance_valid(trigger) or not trigger.is_visible_in_tree():
		return
	show()
	move_to_front()
	_fit()
	_fit.call_deferred()
	for child: Node in content.get_children():
		if child is Control and child.visible and child.focus_mode != Control.FOCUS_NONE:
			child.grab_focus()
			break


func close(restore_focus := true) -> void:
	hide()
	if restore_focus and is_instance_valid(trigger) and trigger.is_visible_in_tree():
		trigger.grab_focus()


func is_open() -> bool:
	return visible


func _fit() -> void:
	if not visible or not is_instance_valid(trigger) or not trigger.is_inside_tree():
		return
	var width := minf(maxf(250.0, content.get_combined_minimum_size().x + 24.0), maxf(1.0, size.x - 16.0))
	var below := trigger.get_global_rect().end.y - global_position.y + 7.0
	var height := minf(content.get_combined_minimum_size().y + 24.0, maxf(48.0, size.y - below - 8.0))
	panel.size = Vector2(width, height)
	panel.position = Vector2(maxf(8.0, size.x - width - 8.0), clampf(below, 8.0, maxf(8.0, size.y - height - 8.0)))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
