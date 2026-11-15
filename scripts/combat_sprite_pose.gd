extends RefCounted

const GRID_COLUMNS := 14
const GRID_ROWS := 16

var _geometry: Dictionary
var _mesh := ArrayMesh.new()
var _vertices := PackedVector2Array()
var _last_pose := Vector4.INF
var _last_arms := Vector3.INF


static func geometry(texture: Texture2D, forward: float) -> Dictionary:
	var uv_region := Rect2(Vector2.ZERO, Vector2.ONE)
	var draw_texture := texture
	if texture is AtlasTexture:
		var sheet := texture as AtlasTexture
		var sheet_size := sheet.atlas.get_size()
		draw_texture = sheet.atlas
		# Sample within the cutout when the sprite borders another atlas entry.
		uv_region = Rect2((sheet.region.position + Vector2(0.5, 0.5)) / sheet_size,
			(sheet.region.size - Vector2.ONE) / sheet_size)
	var image := texture.get_image()
	var bounds := Rect2(Vector2.ZERO, Vector2.ONE)
	var waist := 0.5
	var feet := waist
	if image != null and not image.is_empty():
		var used := image.get_used_rect()
		if used.has_area():
			var full_size := Vector2(image.get_size())
			bounds = Rect2(Vector2(used.position) / full_size, Vector2(used.size) / full_size)
			waist = _horizontal_center(image, used, 0.46, 0.67)
			feet = _horizontal_center(image, used, 0.82, 0.98)
	var split := lerpf(waist, feet, 0.6)
	var joints := [
		(bounds.position + Vector2(waist + forward * 0.10, 0.47) * bounds.size) - Vector2(0.5, 1.0),
		(bounds.position + Vector2(waist - forward * 0.12, 0.47) * bounds.size) - Vector2(0.5, 1.0),
	]
	var points := PackedVector2Array()
	var weights := PackedVector4Array()
	var uvs := PackedVector2Array()
	var triangles := PackedInt32Array()
	for row in range(GRID_ROWS + 1):
		for column in range(GRID_COLUMNS + 1):
			var uv := Vector2(float(column) / GRID_COLUMNS, float(row) / GRID_ROWS)
			points.append(uv - Vector2(0.5, 1.0))
			uvs.append(uv_region.position + uv_region.size * uv)
			var pos := (uv - bounds.position) / bounds.size
			var side := (pos.x - waist) * forward
			var shoulder_band := smoothstep(0.22, 0.43, pos.y) * (1.0 - smoothstep(0.65, 0.91, pos.y))
			var front_arm := smoothstep(0.04, 0.33, side) * shoulder_band
			var back_arm := smoothstep(0.04, 0.30, -side) * shoulder_band
			var leg := smoothstep(0.59, 0.96, pos.y) * (1.0 - maxf(front_arm, back_arm) * 0.8)
			var front_leg := smoothstep(-0.085, 0.085, (pos.x - split) * forward)
			weights.append(Vector4(front_leg * leg, (1.0 - front_leg) * leg, front_arm, back_arm))
			if row < GRID_ROWS and column < GRID_COLUMNS:
				var index := row * (GRID_COLUMNS + 1) + column
				var below := index + GRID_COLUMNS + 1
				triangles.append_array([index, index + 1, below + 1, index, below + 1, below])
	return {"texture": draw_texture, "points": points, "uvs": uvs, "weights": weights, "triangles": triangles,
		"pivots": joints, "forward": forward, "aspect": texture.get_size().aspect()}


static func _horizontal_center(image: Image, bounds: Rect2i, top: float, bottom: float) -> float:
	var alpha_total := 0.0
	var weighted_x := 0.0
	var first_y := bounds.position.y + floori(bounds.size.y * top)
	var last_y := bounds.position.y + ceili(bounds.size.y * bottom)
	var x_step := maxi(1, roundi(bounds.size.x / 60.0))
	var y_step := maxi(1, roundi(bounds.size.y / 72.0))
	for y in range(first_y, last_y, y_step):
		for x in range(bounds.position.x, bounds.end.x, x_step):
			var alpha := image.get_pixel(x, y).a
			weighted_x += (x - bounds.position.x) * alpha
			alpha_total += alpha
	if alpha_total <= 0.01:
		return 0.5
	return clampf(weighted_x / (alpha_total * bounds.size.x), 0.29, 0.71)


func _init(basis: Dictionary) -> void:
	_geometry = basis
	_vertices = basis.points.duplicate()
	var array := []
	array.resize(Mesh.ARRAY_MAX)
	array[Mesh.ARRAY_VERTEX] = _vertices
	array[Mesh.ARRAY_TEX_UV] = basis.uvs
	array[Mesh.ARRAY_INDEX] = basis.triangles
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array, [], {}, Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)


func draw(canvas: CanvasItem, height: float, pose: Vector4, arms: Vector3, tint: Color) -> void:
	if not pose.is_equal_approx(_last_pose) or not arms.is_equal_approx(_last_arms):
		_update_vertices(pose, arms)
		_last_pose = pose
		_last_arms = arms
	canvas.draw_mesh(_mesh, _geometry.texture, Transform2D(0.0, Vector2(height * _geometry.aspect, height),
		0.0, Vector2.ZERO), tint)


# The four leg channels contain front and rear stride displacement followed by foot lift.
# Arms contain the shoulder rotations and the extension of the leading hand.
func _update_vertices(pose: Vector4, arms: Vector3) -> void:
	var points: PackedVector2Array = _geometry.points
	var weights: PackedVector4Array = _geometry.weights
	var forward: float = _geometry.forward
	var aspect: float = _geometry.aspect
	var front := Transform2D(arms.x * forward, Vector2.ZERO)
	var back := Transform2D(arms.y * forward, Vector2.ZERO)
	var front_pivot: Vector2 = _geometry.pivots[0] * Vector2(aspect, 1.0)
	var back_pivot: Vector2 = _geometry.pivots[1] * Vector2(aspect, 1.0)
	for index in range(points.size()):
		var point := points[index]
		var weight := weights[index]
		var shift := Vector2((pose.x * weight.x + pose.y * weight.y) * forward,
			pose.z * weight.x + pose.w * weight.y)
		var local := point * Vector2(aspect, 1.0)
		var front_delta := front * (local - front_pivot) + front_pivot - local
		var back_delta := back * (local - back_pivot) + back_pivot - local
		front_delta.x += arms.z * forward
		shift += front_delta * weight.z + back_delta * weight.w
		shift.x /= aspect
		_vertices[index] = point + shift
	_mesh.surface_update_vertex_region(0, 0, _vertices.to_byte_array())


static func leg_pose(phase: float, motion: float, brace: float) -> Vector4:
	var swing := sin(phase) * motion
	var rise := cos(phase) * motion
	return Vector4(swing * 0.105 + brace * 0.025, -swing * 0.105 - brace * 0.045,
		-maxf(0.0, rise) * 0.070, -maxf(0.0, -rise) * 0.070)


static func arm_pose(profile: Dictionary, weight: float, released: bool) -> Vector3:
	var angle := Vector3(0.48, -0.20, 0.03)
	match profile.style:
		"slash", "spin": angle = Vector3(0.67, -0.28, 0.065)
		"heavy", "burst", "mine": angle = Vector3(0.80, 0.18, 0.05)
		"thrust", "dash": angle = Vector3(0.18, -0.22, 0.13)
		"shot", "bolt": angle = Vector3(-0.30, -0.19, -0.065)
		"pull": angle = Vector3(-0.18, 0.22, -0.12)
		"guard": angle = Vector3(-0.35, -0.28, 0.04)
		"ward", "heal", "mark", "blink": angle = Vector3(-0.58, -0.22, 0.025)
	if not released:
		if profile.style in ["shot", "bolt"]:
			angle = Vector3(-0.12, -0.07, 0.065)
		elif profile.style in ["guard", "ward", "heal", "mark", "blink"]:
			angle *= 0.7
		else:
			angle *= -0.75
	return angle * minf(weight * float(profile.weight), 1.3)
