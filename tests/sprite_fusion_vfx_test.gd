extends SceneTree

const Vfx = preload("res://scripts/sprite_fusion_vfx.gd")
const AttackAnimation = preload("res://scripts/attack_animation.gd")
const HeroChoreography = preload("res://scripts/hero_attack_choreography.gd")
const EnemyChoreography = preload("res://scripts/enemy_attack_choreography.gd")
const ArenaSim = preload("res://scripts/arena_sim.gd")

var failures: Array[String] = []


func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Vfx.ROOT + "manifest.json"))
	var license := FileAccess.get_file_as_string(Vfx.ROOT + "LICENSE.txt")
	_check("Copyright (c) 2026 Hugo Duprez" in license and "MIT License" in license,
		"The official source's MIT attribution must travel with its generated images.")
	for source: Dictionary in manifest.sources:
		_check(FileAccess.file_exists(Vfx.ROOT + source.file) and source.page.begins_with("https://www.spritefusion.com/"),
			"Every effect needs its actual official source and provenance page.")
	for key: String in Vfx.CLIPS:
		var clip: Dictionary = manifest.clips.get(key, {})
		_check(clip.get("frames") == Vfx.CLIPS[key], "The %s player must use the number of baked source frames." % key)
		for layer: String in ["front", "back"]:
			var texture := load(Vfx.ROOT + key + "_" + layer + ".png") as Texture2D
			var compact: Vector2i = Vector2i.ONE if layer in clip.empty_layers else Vector2i(clip.frame_size[0] * 8, clip.frame_size[1] * ceili(float(Vfx.CLIPS[key]) / 8))
			_check(texture != null and texture.get_size() == Vector2(compact),
				"The %s %s layer must contain complete, evenly sized frames." % [key, layer])
	for key: String in ["slash", "impact", "muzzle", "gold_ray", "arc_ray", "explosion", "holy_light", "shield", "heal", "dash", "blink", "fire"]:
		var texture := load(Vfx.ROOT + key + "_front.png") as Texture2D
		var clip: Dictionary = manifest.clips[key]
		var image := texture.get_image().get_region(Rect2i(0, 0, clip.frame_size[0], clip.frame_size[1]))
		_check(image.get_used_rect().has_area(), "The %s contact effect must be visible in its release frame." % key)
		if key in ["impact", "explosion", "holy_light", "shield", "fire", "gold_ray", "arc_ray"]:
			var contact := Vector2i(clip.anchor[0] + (50 if key.ends_with("ray") else 0), clip.anchor[1])
			_check(_contact_pixels(image, contact) >= 16,
				"The %s release must already light its actual contact, without replaying the source's preparation." % key)
	var early := AttackAnimation.hero_anticipation(42, 147, 43, 5)
	var late := AttackAnimation.hero_anticipation(42, 147, 146, 5)
	_check(early.get("beats") == 5 and early.charge < 0.02 and late.charge > 0.98
		and AttackAnimation.hero_anticipation(42, 147, 41, 5).is_empty()
		and AttackAnimation.hero_anticipation(42, 147, 147, 5).is_empty(),
		"A long tile prepares from the beginning, uses simulation progress, and stops at the exact release edge.")
	_check(HeroChoreography.profile("sear", ArenaSim.TILES.sear).sprite_fusion == "fire"
		and HeroChoreography.profile("wildfire_globe", ArenaSim.TILES.wildfire_globe).sprite_fusion == "fire"
		and HeroChoreography.profile("chorus_bolt", ArenaSim.TILES.chorus_bolt).sprite_fusion == "holy_light"
		and HeroChoreography.profile("convergence_pulse", ArenaSim.TILES.convergence_pulse).sprite_fusion == "black_hole"
		and EnemyChoreography.profile("crown_chorister").sprite_fusion == "holy_light",
		"Fire, song, gravity, and enemy support must select effects by their actual combat identity.")
	var route := PackedVector2Array([Vector2.ZERO, Vector2(20, 0), Vector2(20, 60)])
	var corner_sample := Vfx._motion_sample(route, 50.0)
	var repeated_sample := Vfx._motion_sample(PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2(10, 0)]), 4.0)
	_check(corner_sample.point == Vector2(20, 30) and corner_sample.direction == Vector2.DOWN
		and repeated_sample.point == Vector2(4, 0) and repeated_sample.direction == Vector2.RIGHT,
		"Authored movement stamps follow the actual swept route and local direction rather than cutting across its corners.")
	for message in failures:
		printerr(message)
	if failures.is_empty():
		print("Official Sprite Fusion VFX sources, atlas layers, release frames, and full-tile anticipation passed.")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _contact_pixels(image: Image, contact: Vector2i) -> int:
	var count := 0
	for y in range(maxi(0, contact.y - 12), mini(image.get_height(), contact.y + 13)):
		for x in range(maxi(0, contact.x - 12), mini(image.get_width(), contact.x + 13)):
			if image.get_pixel(x, y).a > 0.1:
				count += 1
	return count
