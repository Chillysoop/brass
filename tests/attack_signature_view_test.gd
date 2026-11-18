extends SceneTree

const AttackAnimation = preload("res://scripts/attack_animation.gd")
const HeroChoreography = preload("res://scripts/hero_attack_choreography.gd")
const EnemyChoreography = preload("res://scripts/enemy_attack_choreography.gd")
const ArenaSim = preload("res://scripts/arena_sim.gd")
const FRAME_SIZE := Vector2i(400, 280)

var failures: Array[String] = []


class ReleaseSample extends Node2D:
	var profile: Dictionary
	var age: float
	var footprint: Vector2

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(FRAME_SIZE)), Color("#1c2832"))
		var start := Vector2(100, 220)
		var target := Vector2(265, 220)
		var progress := age / AttackAnimation.lifetime(profile)
		AttackAnimation.draw_cast_back(self, profile, start, target, start, progress, 29.0, true, footprint)
		AttackAnimation.draw_cast(self, profile, start, target, start, progress, 29.0, true, footprint)


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("Signature artwork pixel smoke requires a rendering display; run this script without --headless.")
		quit()
		return
	call_deferred("_run")


func _run() -> void:
	var cases: Array[Dictionary] = [
		{"id": "meteor", "profile": HeroChoreography.profile("meteor_seal", ArenaSim.TILES.meteor_seal),
			"footprint": Vector2(58, 28)},
		{"id": "skyline", "profile": HeroChoreography.profile("horizon_round_upgrade_rare_power", ArenaSim.TILES.horizon_round_upgrade_rare_power),
			"footprint": Vector2.ZERO},
		{"id": "marshal_sweep", "profile": EnemyChoreography.profile("marshal_sweep"),
			"footprint": Vector2(83, 39)},
		{"id": "hammer", "profile": HeroChoreography.profile("bash", ArenaSim.TILES.bash),
			"footprint": Vector2.ZERO},
	]
	var records: Array[Dictionary] = []
	for spec: Dictionary in cases:
		for late: bool in [false, true]:
			var pair: Array[SubViewport] = []
			for signature: bool in [false, true]:
				var viewport := SubViewport.new()
				viewport.size = FRAME_SIZE
				viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
				root.add_child(viewport)
				var sample := ReleaseSample.new()
				sample.profile = spec.profile.duplicate(true)
				if not signature:
					sample.profile.signature_effect = ""
				sample.age = float(AttackAnimation.SIGNATURE_SECONDS[spec.id]) + 0.02 if late else 0.04
				sample.footprint = spec.footprint
				viewport.add_child(sample)
				pair.append(viewport)
			records.append({"id": spec.id, "late": late, "pair": pair})
	for _frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var proof := Image.create(FRAME_SIZE.x * 2, FRAME_SIZE.y * cases.size(), false, Image.FORMAT_RGBA8)
	var row := 0
	for record: Dictionary in records:
		var base: Image = record.pair[0].get_texture().get_image()
		var signature: Image = record.pair[1].get_texture().get_image()
		var changed := _changed_pixels(base, signature)
		if record.late:
			_check(changed == 0, "%s must finish its original kinetic cadence rather than lingering for the sheet's longer lifetime." % record.id)
		else:
			_check(changed >= 30, "%s must visibly retain its distinct kinetic accent over official release art." % record.id)
			if record.id == "meteor":
				_check(_changed_pixels(base, signature, 225) == 0,
					"Meteor retains its descending body without adding the old second ground explosion.")
			proof.blit_rect(base, Rect2i(Vector2i.ZERO, FRAME_SIZE), Vector2i(0, row * FRAME_SIZE.y))
			proof.blit_rect(signature, Rect2i(Vector2i.ZERO, FRAME_SIZE), Vector2i(FRAME_SIZE.x, row * FRAME_SIZE.y))
			row += 1
		print("%s %s changed pixels: %d" % [record.id, "expired" if record.late else "release", changed])
	var output := OS.get_environment("TEMP").path_join("brass-signature-vfx-proof.png")
	proof.save_png(output)
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("Meteor, Skyline, Marshal sweep, and hammer kinetic accents passed real-render pixel smoke. " + output)
	quit(0 if failures.is_empty() else 1)


func _changed_pixels(first: Image, second: Image, first_row := 0) -> int:
	var count := 0
	var first_data := first.get_data()
	var second_data := second.get_data()
	for pixel in range(first_row * first.get_width(), first.get_width() * first.get_height()):
		var offset := pixel * 4
		var difference := 0
		for channel in range(3):
			difference += absi(int(first_data[offset + channel]) - int(second_data[offset + channel]))
		if difference >= 12:
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
