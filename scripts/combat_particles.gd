extends RefCounted

# Authored pixel materials shared by bounded, deterministic combat emitters.
# These are textured sprites, never drawn wireframes or actor/physics objects.
const ROOT := "res://assets/combat_particles/"
const MATERIALS := ["spark", "ember", "smoke", "brass", "aether", "shield", "heal", "phase", "crystal", "slash", "dust", "arc"]
const FRAME := Vector2(48, 48)
const COLUMNS := 12
static var _texture: CanvasTexture
static var _regions: Dictionary = {}


static func available() -> bool:
	return ResourceLoader.exists(ROOT + "particles.png", "Texture2D")


static func stamp(canvas: CanvasItem, material: String, at: Vector2, age: float, diameter: float,
		angle := 0.0, tint := Color.WHITE, aspect := Vector2.ONE) -> void:
	if age < 0.0 or age >= 1.0 or tint.a <= 0.005 or diameter < 0.5:
		return
	var row := MATERIALS.find(material)
	if row < 0:
		return
	if _texture == null:
		_texture = CanvasTexture.new()
		_texture.diffuse_texture = load(ROOT + "particles.png")
		_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var frame := clampi(floori(age * COLUMNS), 0, COLUMNS - 1)
	var key := row * COLUMNS + frame
	if not _regions.has(key):
		var origin := Vector2(frame, row) / Vector2(COLUMNS, MATERIALS.size())
		var extent := Vector2.ONE / Vector2(COLUMNS, MATERIALS.size())
		# Half-texel inset prevents neighboring animation cells bleeding into rotated stamps.
		var inset := Vector2.ONE * 0.5 / _texture.get_size()
		_regions[key] = PackedVector2Array([origin + inset,
			origin + Vector2(extent.x, 0) + Vector2(-inset.x, inset.y),
			origin + extent - inset, origin + Vector2(0, extent.y) + Vector2(inset.x, -inset.y)])
	var points := PackedVector2Array()
	var half := Vector2.ONE * diameter * 0.5 * aspect
	var center := at.round()
	for corner: Vector2 in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]:
		points.append(center + corner.rotated(angle))
	canvas.draw_polygon(points, PackedColorArray([tint]), _regions[key], _texture)


static func tint(color: Color, alpha: float, material := "") -> Color:
	# Preserve the metal, smoke and flame shading painted into each material.
	var influence := 0.14 if material in ["ember", "brass", "smoke", "dust", "heal"] else 0.30
	var result := Color.WHITE.lerp(color, influence)
	result.a = clampf(alpha, 0.0, 1.0)
	return result
