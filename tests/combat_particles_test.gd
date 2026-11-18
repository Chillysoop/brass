extends SceneTree

const Particles = preload("res://scripts/combat_particles.gd")
const ArenaSim = preload("res://scripts/arena_sim.gd")
const Choreography = preload("res://scripts/hero_attack_choreography.gd")
var failures: Array[String] = []


func _initialize() -> void:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(Particles.ROOT + "manifest.json"))
	if not _check(manifest is Dictionary and manifest.get("version") == 1, "Particle manifest must be valid."):
		_finish()
		return
	var pixels := Image.new()
	var decode := pixels.load_png_from_buffer(FileAccess.get_file_as_bytes(Particles.ROOT + "particles.png"))
	if not _check(decode == OK and not pixels.is_empty(), "Original particle atlas must load."):
		_finish()
		return
	_check(pixels.get_size() == Vector2i(576, 576), "Particle atlas layout matches the runtime sampler.")
	var frames := {}
	for row in range(Particles.MATERIALS.size()):
		var material: String = Particles.MATERIALS[row]
		var clip: Dictionary = manifest.clips.get(material, {})
		var dimensions: Array = clip.get("frame_size", [])
		_check(int(clip.get("row", -1)) == row and int(clip.get("frames", 0)) == 12
			and dimensions.size() == 2 and Vector2(dimensions[0], dimensions[1]) == Particles.FRAME,
			"%s material matches its actual atlas cells." % material)
		var palette := {}
		for frame in range(12):
			var cell := pixels.get_region(Rect2i(frame * 48, row * 48, 48, 48))
			_check(cell.get_used_rect().has_area(), "%s frame %d contains visible art." % [material, frame])
			var digest := cell.get_data().hex_encode()
			_check(not frames.has(digest), "%s frame %d retains its own animated texture." % [material, frame])
			frames[digest] = true
			for index in range(48):
				_check(cell.get_pixel(index, 0).a == 0.0 and cell.get_pixel(index, 47).a == 0.0
					and cell.get_pixel(0, index).a == 0.0 and cell.get_pixel(47, index).a == 0.0,
					"%s frame %d has no clipped or bleeding material at its borders." % [material, frame])
			for y in range(48):
				for x in range(48):
					var color := cell.get_pixel(x, y)
					if color.a > 0.3:
						palette[color.to_html(false)] = true
		_check(palette.size() >= 4, "%s has internal pixel shading." % material)
	for id: String in ArenaSim.TILES:
		var recipe: Dictionary = Choreography.profile(id, ArenaSim.TILES[id]).tile_animation
		_check(not recipe.particles.is_empty(), "%s has a finished textured prescription." % id)
		for response: Dictionary in [recipe.particles] + recipe.particle_layers:
			_check(response.material in Particles.MATERIALS and response.secondary in Particles.MATERIALS,
				"%s uses real authored particle textures." % id)
	_finish()


func _finish() -> void:
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("144 shaded pixel particle frames and all 745 textured tile prescriptions passed border, shading, animation and material checks.")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
	return condition
