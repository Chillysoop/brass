extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const Choreography = preload("res://scripts/hero_attack_choreography.gd")
const AttackAnimation = preload("res://scripts/attack_animation.gd")
const CELL := Vector2i(600, 240)
const BATCH := 12
const SOURCE := Vector2(85, 185)
const TARGET := Vector2(500, 185)
const PHASES := [0.0, 0.0, 0.35, 0.65]

var failures: Array[String] = []


class EffectCell extends Node2D:
	var tile: Dictionary
	var landed := true
	var phase := 0.0
	var visual_scale := 26.0
	func _draw() -> void:
		var target := SOURCE if landed and tile.self_target else TARGET
		AttackAnimation.draw_cast_back(self, tile.profile, SOURCE, target, SOURCE, phase, visual_scale, landed)
		AttackAnimation.draw_cast(self, tile.profile, SOURCE, target, SOURCE, phase, visual_scale, landed)


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: tile particle contact regression requires GPU rendering.")
		quit()
		return
	call_deferred("_run")


func _run() -> void:
	var ids := ArenaSim.TILES.keys()
	ids.sort()
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	for visual_scale: float in [26.0, 55.0]:
		await _check_scale(viewport, ids, visual_scale)
	viewport.queue_free()
	for failure: String in failures.slice(0, 30):
		printerr(failure)
	print("%d tiles checked at release zero and three local miss phases, at 26px and 55px scales; %d failures." % [ids.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)


func _check_scale(viewport: SubViewport, ids: Array, visual_scale: float) -> void:
	for first in range(0, ids.size(), BATCH):
		for child in viewport.get_children():
			viewport.remove_child(child)
			child.queue_free()
		var count := mini(BATCH, ids.size() - first)
		viewport.size = Vector2i(CELL.x * PHASES.size(), CELL.y * count)
		for row in range(count):
			var id: String = ids[first + row]
			var spec: Dictionary = ArenaSim.TILES[id]
			var tile := {"profile": Choreography.profile(id, spec), "self_target": spec.targets == ["self"]}
			for column in range(PHASES.size()):
				var clip := Control.new()
				clip.position = Vector2(column * CELL.x, row * CELL.y)
				clip.size = Vector2(CELL)
				clip.clip_contents = true
				viewport.add_child(clip)
				var cell := EffectCell.new()
				cell.tile = tile
				cell.landed = column == 0
				cell.phase = PHASES[column]
				cell.visual_scale = visual_scale
				clip.add_child(cell)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await process_frame
		await RenderingServer.frame_post_draw
		var raster := viewport.get_texture().get_image()
		for row in range(count):
			var id: String = ids[first + row]
			var spec: Dictionary = ArenaSim.TILES[id]
			var actual_contact := SOURCE if spec.targets == ["self"] else TARGET
			var contact := Rect2i(Vector2i(actual_contact) + Vector2i(-85, -130 + row * CELL.y), Vector2i(170, 160))
			_check(_visible(raster, contact, 12) >= 12, "%s has no visible contact at exact release progress zero, scale %.0f." % [id, visual_scale])
			for column in range(1, PHASES.size()):
				var cell_origin := Vector2i(column * CELL.x, row * CELL.y)
				var remote := Rect2i(cell_origin + Vector2i(310, 20), Vector2i(290, 220))
				_check(_visible(raster, remote, 1) == 0, "%s paints the remote enemy on a miss at phase %.2f, scale %.0f." % [id, PHASES[column], visual_scale])
				if column == 1:
					var local := Rect2i(cell_origin + Vector2i(0, 20), Vector2i(260, 220))
					_check(_visible(raster, local, 8) >= 8, "%s needs a visible local whiff at release." % id)
		if first % (BATCH * 12) == 0:
			print("Checked contact and miss pixels for %d/%d tiles at scale %.0f." % [first + count, ids.size(), visual_scale])


func _visible(raster: Image, bounds: Rect2i, stop_at: int) -> int:
	var region := raster.get_region(bounds)
	var occupied := region.get_used_rect()
	if not occupied.has_area():
		return 0
	region = region.get_region(occupied)
	region.convert(Image.FORMAT_RGBA8)
	var bytes := region.get_data()
	var count := 0
	for offset in range(3, bytes.size(), 4):
		if bytes[offset] >= 7:
			count += 1
			if count >= stop_at:
				return count
	return count


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
