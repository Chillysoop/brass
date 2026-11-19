extends Control

# Borderless equipment artwork shared by rewards, hover cards and forge choices.
var _picture: TextureRect
var _tone := Color.WHITE
var _active := false


func configure(texture: Texture2D, tone: Color, height: float) -> void:
	_tone = tone
	custom_minimum_size = Vector2(0, height)
	mouse_filter = MOUSE_FILTER_IGNORE
	_picture = TextureRect.new()
	_picture.texture = texture
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_picture)
	_picture.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_picture.offset_top = 3
	_picture.offset_bottom = -3
	resized.connect(queue_redraw)
	queue_redraw()


func highlight(active: bool) -> void:
	_active = active
	if is_instance_valid(_picture):
		_picture.modulate = Color.WHITE if active else Color(0.9, 0.9, 0.9)
	queue_redraw()


func _draw() -> void:
	var center := size * Vector2(0.5, 0.56)
	var radius := minf(size.x * 0.36, size.y * 0.48)
	for index in range(8, 0, -1):
		var fraction := float(index) / 8.0
		draw_circle(center, radius * fraction,
			Color(_tone, (0.045 if _active else 0.022) * (1.1 - fraction)), true)
	for index in range(4):
		var angle := -0.6 + index * 1.65
		var at := center + Vector2.RIGHT.rotated(angle) * Vector2(radius * 0.95, radius * 0.66)
		draw_circle(at, 1.3 if _active else 0.8, Color(_tone, 0.75 if _active else 0.38), true)
