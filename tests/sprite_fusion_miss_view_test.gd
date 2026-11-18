extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const HeroChoreography = preload("res://scripts/hero_attack_choreography.gd")
const AttackAnimation = preload("res://scripts/attack_animation.gd")
const CASES := ["shot", "sear", "veil_step", "sweep"]

class EffectCanvas extends Control:
	var landed := false
	var phase := 0.0
	func _draw() -> void:
		for index in range(CASES.size()):
			var id: String = CASES[index]
			var profile: Dictionary = HeroChoreography.profile(id, ArenaSim.TILES[id])
			var start := Vector2(85, 140 + index * 200)
			var target := Vector2(550, start.y)
			AttackAnimation.draw_cast_back(self, profile, start, target, start, phase, 26.0, landed)
			AttackAnimation.draw_cast(self, profile, start, target, start, phase, 26.0, landed)

var failures: Array[String] = []
var miss_view: SubViewport
var hit_view: SubViewport
var miss_canvas: EffectCanvas
var hit_canvas: EffectCanvas
var phase := 0
var finished := false


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("Sprite Fusion miss pixel regression requires GPU rendering; skipped on headless display.")
		quit()
		return
	call_deferred("_begin")


func _viewport(landed: bool) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 800)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := EffectCanvas.new()
	canvas.landed = landed
	viewport.add_child(canvas)
	if landed:
		hit_canvas = canvas
	else:
		miss_canvas = canvas
	return viewport


func _begin() -> void:
	miss_view = _viewport(false)
	hit_view = _viewport(true)
	RenderingServer.frame_post_draw.connect(_check_pixels)


func _check_pixels() -> void:
	if finished:
		return
	var misses := miss_view.get_texture().get_image()
	var hits := hit_view.get_texture().get_image()
	if misses == null or hits == null:
		failures.append("Rendered effect images must be available.")
	else:
		for index in range(CASES.size()):
			var top := index * 200
			var remote := Rect2i(280, top + 25, 340, 165)
			var local := Rect2i(10, top + 25, 205, 165)
			var contact := Rect2i(515, top + 80, 70, 100)
			if _visible_pixels(misses, remote) > 0:
				failures.append("%s missed but painted a remote contact at release phase %d." % [CASES[index], phase])
			if phase == 0 and _visible_pixels(misses, local) < 16:
				failures.append("%s must retain a visible local whiff." % CASES[index])
			if phase == 0 and CASES[index] != "sweep" and _visible_pixels(hits, contact) < 16:
				failures.append("%s actual hit must still light its precise remote contact." % CASES[index])
		if phase == 0:
			var output := OS.get_environment("TEMP").path_join("brass-sprite-fusion-misses.png")
			misses.save_png(output)
	phase += 1
	if phase < 3:
		miss_canvas.phase = phase * 0.25
		hit_canvas.phase = miss_canvas.phase
		miss_canvas.queue_redraw()
		hit_canvas.queue_redraw()
		return
	for failure: String in failures:
		printerr(failure)
	finished = true
	if failures.is_empty():
		print("Actual shot, bolt, Veil Step and sweep renders keep misses local while preserving real-hit contacts.")
	quit(0 if failures.is_empty() else 1)


func _visible_pixels(image: Image, region: Rect2i) -> int:
	var count := 0
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if image.get_pixel(x, y).a > 0.01:
				count += 1
	return count
