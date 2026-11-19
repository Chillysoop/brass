extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const Choreography = preload("res://scripts/hero_attack_choreography.gd")
const AttackAnimation = preload("res://scripts/attack_animation.gd")
const CASES := ["shot", "sear", "sweep", "jab"]
const SOCKETS := {"muzzle": Vector2(160, 100), "cast": Vector2(170, 80),
	"blade": Vector2(175, 130), "hand": Vector2(130, 170), "feet": Vector2(100, 240)}
var failures: Array[String] = []


class Sample extends Node2D:
	var profile: Dictionary
	func _draw() -> void:
		AttackAnimation.draw_cast_back(self, profile, Vector2(100, 240), Vector2(340, 240), Vector2(100, 240), 0.04, 26.0, true)
		AttackAnimation.draw_cast(self, profile, Vector2(100, 240), Vector2(340, 240), Vector2(100, 240), 0.04, 26.0, true)


func _initialize() -> void:
	var profile := Choreography.profile("shot", ArenaSim.TILES.shot)
	var original: Dictionary = profile.tile_animation
	profile.emission_sockets = SOCKETS
	profile.actor_origin = Vector2(100, 240)
	var local := AttackAnimation._emission_recipe(profile)
	_check(local.get("emission_sockets") == SOCKETS and not original.has("emission_sockets"),
		"A cast supplies live emission sockets without mutating its shared tile recipe.")
	if DisplayServer.get_name() == "headless":
		print("Live emission recipe isolation checked; pixel socket checks require a rendering display.")
		_finish()
		return
	call_deferred("_run")


func _run() -> void:
	var records := []
	for id: String in CASES:
		var pair: Array[SubViewport] = []
		for attached: bool in [false, true]:
			var viewport := SubViewport.new()
			viewport.size = Vector2i(420, 320)
			viewport.transparent_bg = true
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(viewport)
			var sample := Sample.new()
			sample.profile = Choreography.profile(id, ArenaSim.TILES[id])
			if attached:
				sample.profile.emission_sockets = SOCKETS
				sample.profile.actor_origin = Vector2(100, 240)
			viewport.add_child(sample)
			pair.append(viewport)
		records.append({"id": id, "pair": pair})
	for _frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var proof := Image.create(840, 320 * CASES.size(), false, Image.FORMAT_RGBA8)
	for index in range(records.size()):
		var record: Dictionary = records[index]
		var original: Image = record.pair[0].get_texture().get_image()
		var attached: Image = record.pair[1].get_texture().get_image()
		var name := "muzzle" if record.id == "shot" else "cast" if record.id == "sear" else "blade"
		var at: Vector2 = SOCKETS[name]
		var region := Rect2i(Vector2i(at) - Vector2i(27, 27), Vector2i(54, 54))
		_check(_pixels(attached, region) > _pixels(original, region) + 5,
			"%s emission visibly originates at its animated %s socket." % [record.id, name])
		_check(_pixels(attached, Rect2i(314, 194, 52, 42)) > 5,
			"%s retains the actual target's contact while moving its weapon origin." % record.id)
		proof.blit_rect(original, Rect2i(0, 0, 420, 320), Vector2i(0, index * 320))
		proof.blit_rect(attached, Rect2i(0, 0, 420, 320), Vector2i(420, index * 320))
	proof.save_png(OS.get_environment("TEMP").path_join("brass-weapon-emission-proof.png"))
	if failures.is_empty():
		print("Shots, spells, slashes and thrusts attach to live weapon sockets while preserving target contact.")
	_finish()


func _pixels(picture: Image, region: Rect2i) -> int:
	var count := 0
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			count += int(picture.get_pixel(x, y).a > 0.05)
	return count


func _finish() -> void:
	for failure: String in failures:
		printerr(failure)
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
