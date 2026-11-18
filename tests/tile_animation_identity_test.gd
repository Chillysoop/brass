extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const HeroChoreography = preload("res://scripts/hero_attack_choreography.gd")
const AttackAnimation = preload("res://scripts/attack_animation.gd")
const CELL := Vector2i(400, 280)
const PHASES := [0.04, 0.18, 0.34, 0.52, 0.72, 0.91]
const GRID := 16
const NORMALIZED := 64
const BATCH := 12
const MIN_GEOMETRY_DISTANCE := 0.06
const MAX_RENDERER_JITTER := 0.08
const FOCUS_IDS := [
	"retreat_shot_upgrade_legendary_power", "snap_shot_upgrade_legendary_power",
	"retreat_shot_upgrade_epic_power", "snap_shot_upgrade_epic_power",
	"spark_shot_upgrade_epic_technique", "rivet_bolt_upgrade_epic_technique",
	"jab_upgrade_epic_technique", "shield_tap_upgrade_epic_technique",
	"shrapnel", "shrapnel_upgrade_rare_power", "piercing_burst_upgrade_rare_technique", "volley",
	"bash", "shield_ram", "shot", "split_shot", "meteor_seal", "event_horizon",
	"horizon_round_upgrade_rare_power", "horizon_round_upgrade_rare_technique",
	"horizon_round_upgrade_epic_power", "horizon_round_upgrade_epic_technique",
	"cinder_wave_upgrade_legendary_power", "cinder_wave_upgrade_legendary_technique",
	"triage_kit", "triage_kit_upgrade_legendary_technique",
	"sweep", "sweep_upgrade_uncommon_power", "sweep_upgrade_epic_technique", "sweep_upgrade_legendary_technique",
	"aegis_intercept", "aegis_intercept_upgrade_legendary_technique",
	"aegis_intercept_upgrade_rare_power", "aegis_intercept_upgrade_rare_technique",
	"jab", "shield_tap", "spark_shot", "rivet_bolt", "retreat_shot", "snap_shot",
	"shrapnel_upgrade_uncommon_technique", "shrapnel_upgrade_legendary_power",
	"guard_refrain", "guard_refrain_upgrade_rare_power", "guard_refrain_upgrade_rare_technique",
	"pull", "pull_upgrade_epic_technique", "gravity_hook", "gravity_hook_upgrade_epic_technique",
	"blink", "tonic_dart", "tonic_dart_upgrade_uncommon_power",
	"sear_upgrade_epic_power", "sear_upgrade_legendary_power",
]

var failures: Array[String] = []
var records: Array[Dictionary] = []
var popcounts := PackedByteArray()
var output := ""
var source_versions := {}
var exact_sequences := {}


class ReleaseCell extends Node2D:
	var tile: Dictionary
	var phase := 0.0
	var preparation := false
	func _draw() -> void:
		var start := Vector2(100, 215)
		var target := Vector2(265, 215)
		if preparation:
			AttackAnimation.draw_hero_anticipation(self, start, 1.0, 29.0, phase, tile.profile, tile.width)
			return
		AttackAnimation.draw_cast_back(self, tile.profile, start, target, Vector2(220, 215), phase, 29.0, true)
		AttackAnimation.draw_cast(self, tile.profile, start, target, Vector2(220, 215), phase, 29.0, true)


class ReleaseBatch extends Node2D:
	var tiles: Array[Dictionary] = []
	var preparation := false
	func _ready() -> void:
		rebuild()
	func rebuild() -> void:
		for child in get_children():
			remove_child(child)
			child.queue_free()
		for row in range(tiles.size()):
			for column in range(PHASES.size()):
				var clip := Control.new()
				clip.position = Vector2(column * CELL.x, row * CELL.y)
				clip.size = Vector2(CELL)
				clip.clip_contents = true
				add_child(clip)
				var cell := ReleaseCell.new()
				cell.tile = tiles[row]
				cell.phase = PHASES[column]
				cell.preparation = preparation
				clip.add_child(cell)


class LabeledGallery extends Node2D:
	var picture: Texture2D
	var labels: Array = []
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(0, 0, 2400, labels.size() * 168), Color("#17222d"))
		for row in range(labels.size()):
			draw_texture_rect_region(picture, Rect2(0, row * 168 + 28, 2400, 140), Rect2(0, row * 140, 2400, 140))
			for side in range(2):
				var id: String = labels[row]["left" if side == 0 else "right"]
				var text := "%s / %s" % [ArenaSim.TILES[id].label, id]
				draw_string(font, Vector2(side * 1200 + 10, row * 168 + 20), text, HORIZONTAL_ALIGNMENT_LEFT, 1180, 17, Color("#f4e5c5"))


class ContactGallery extends Node2D:
	var picture: Texture2D
	var labels: Array = []
	func _draw() -> void:
		draw_texture(picture, Vector2.ZERO)
		for row in range(labels.size()):
			for side in range(2):
				var id: String = labels[row][side]
				draw_string(ThemeDB.fallback_font, Vector2(side * 540 + 8, row * 210 + 22),
					ArenaSim.TILES[id].label, HORIZONTAL_ALIGNMENT_LEFT, 520, 17, Color("#f4e5c5"))


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: tile animation identity requires the GPU renderer; run without --headless.")
		quit()
		return
	call_deferred("_run")


func _run() -> void:
	output = OS.get_environment("TEMP").path_join("brass-tile-animation-audit")
	if "--focus" in OS.get_cmdline_user_args():
		output += "-focus"
	DirAccess.make_dir_recursive_absolute(output)
	for path: String in ["scripts/tile_animation.gd", "scripts/tile_animation_catalog.gd", "scripts/tile_animation_effects.gd",
		"scripts/attack_animation.gd", "scripts/sprite_fusion_vfx.gd", "scripts/combat_particles.gd",
		"assets/combat_particles/particles.png", "assets/combat_particles/manifest.json", "assets/sprite_fusion/vfx/manifest.json"]:
		source_versions[path] = FileAccess.get_sha256("res://" + path)
	for value in range(256):
		var count := 0
		for bit in range(8):
			count += (value >> bit) & 1
		popcounts.append(count)
	var ids := ArenaSim.TILES.keys()
	if "--focus" in OS.get_cmdline_user_args():
		ids = FOCUS_IDS.duplicate()
	ids.sort()
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var sample := ReleaseBatch.new()
	viewport.add_child(sample)
	for first in range(0, ids.size(), BATCH):
		sample.tiles.clear()
		for index in range(first, mini(first + BATCH, ids.size())):
			var id: String = ids[index]
			sample.tiles.append({"id": id, "profile": HeroChoreography.profile(id, ArenaSim.TILES[id])})
		viewport.size = Vector2i(CELL.x * PHASES.size(), CELL.y * sample.tiles.size())
		sample.rebuild()
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		var atlas_path := output.path_join("release-%03d.png" % first)
		image.save_png(atlas_path)
		for row in range(sample.tiles.size()):
			var frames: Array[Image] = []
			var visible := 0
			for column in range(PHASES.size()):
				var frame := image.get_region(Rect2i(Vector2i(column * CELL.x, row * CELL.y), CELL))
				frames.append(frame)
				visible += int(frame.get_used_rect().has_area())
			var id: String = sample.tiles[row].id
			_check(visible >= 3, "%s has a visible multi-frame release." % id)
			var hash_context := HashingContext.new()
			hash_context.start(HashingContext.HASH_SHA256)
			for frame: Image in frames:
				hash_context.update(frame.get_data())
			var sequence_hash := hash_context.finish().hex_encode()
			_check(not exact_sequences.has(sequence_hash), "%s and %s must not render exactly the same release sequence." % [id, exact_sequences.get(sequence_hash, "")])
			exact_sequences[sequence_hash] = id
			var record := _features(frames)
			var contacts: Array[Image] = []
			for frame: Image in frames:
				contacts.append(frame.get_region(Rect2i(195, 115, 140, 150)))
			var local := _features(contacts)
			record.merge({"contact_bits": local.bits, "contact_mirror": local.mirror,
				"contact_edges": local.edges, "contact_edges_mirror": local.edges_mirror,
				"contact_edge_energy": local.edge_energy})
			if first == 0 and row == 0:
				_check_normalization(frames)
				await _check_render_jitter(sample.tiles[row].profile, record)
				if "--controls-only" in OS.get_cmdline_user_args():
					for failure: String in failures:
						printerr(failure)
					quit(0 if failures.is_empty() else 1)
					return
			record.merge({"id": id, "label": ArenaSim.TILES[id].label, "atlas": atlas_path, "row": row,
				"nearest": "", "distance": 1.0, "global_distance": 1.0, "contact_distance": 1.0, "grayscale_distance": 1.0})
			records.append(record)
		if first % (BATCH * 10) == 0:
			print("Rendered %d/%d tile release sequences." % [records.size(), ids.size()])
	await _check_preparations(viewport, sample, ids)
	viewport.queue_free()
	print("Comparing all %d rendered sequences after grayscale/geometry normalization." % records.size())
	for first in range(records.size()):
		for second in range(first + 1, records.size()):
			var a: Dictionary = records[first]
			var b: Dictionary = records[second]
			var global_distance := _edge_distance(a, b)
			var local_distance := minf(_image_distance(a.contact_edges, b.contact_edges, a.contact_edge_energy, b.contact_edge_energy),
				_image_distance(a.contact_edges, b.contact_edges_mirror, a.contact_edge_energy, b.contact_edge_energy))
			var distance := maxf(global_distance, local_distance)
			if distance < float(a.distance):
				a.distance = distance
				a.nearest = b.id
				a.global_distance = global_distance
				a.contact_distance = local_distance
				a.grayscale_distance = _grayscale_distance(a.gray, b.gray)
			if distance < float(b.distance):
				b.distance = distance
				b.nearest = a.id
				b.global_distance = global_distance
				b.contact_distance = local_distance
				b.grayscale_distance = _grayscale_distance(a.gray, b.gray)
	var ranked := records.duplicate()
	ranked.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.distance) < float(b.distance))
	var report := []
	var reviews := 0
	for record: Dictionary in ranked:
		# Perceptual similarity is a review signal. Numeric uniqueness is not a
		# substitute for inspecting the actual nearest-pair render sequences.
		reviews += int(float(record.distance) < MIN_GEOMETRY_DISTANCE)
		report.append({"id": record.id, "label": record.label, "nearest": record.nearest,
			"geometry_distance": record.distance, "global_distance": record.global_distance,
			"contact_distance": record.contact_distance, "grayscale_distance": record.grayscale_distance})
	var file := FileAccess.open(output.path_join("nearest-pairs.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"count": records.size(), "phases": PHASES,
		"review_distance": MIN_GEOMETRY_DISTANCE, "source_versions": source_versions,
		"comparison": "Mirror-invariant cosine distance of pooled normalized grayscale gradients; whole sequence and local contact regions.", "records": report}, "  "))
	await _write_gallery(ranked)
	for index in range(mini(12, report.size())):
		print("Closest: %s / %s geometry %.3f" % [report[index].id, report[index].nearest, report[index].geometry_distance])
	for failure: String in failures.slice(0, 24):
		printerr(failure)
	print("%d tile IDs below the %.0f%% similarity review line; %d visibility/normalization/preparation failures. Audit artifacts: %s" % [reviews, MIN_GEOMETRY_DISTANCE * 100.0, failures.size(), output])
	quit(0 if failures.is_empty() else 1)


func _check_preparations(viewport: SubViewport, sample: ReleaseBatch, ids: Array) -> void:
	var wide := ids.filter(func(id: String): return int(ArenaSim.TILES[id].width) >= 4)
	sample.preparation = true
	for first in range(0, wide.size(), BATCH):
		sample.tiles.clear()
		for index in range(first, mini(first + BATCH, wide.size())):
			var id: String = wide[index]
			sample.tiles.append({"id": id, "width": ArenaSim.TILES[id].width,
				"profile": HeroChoreography.profile(id, ArenaSim.TILES[id])})
		viewport.size = Vector2i(CELL.x * PHASES.size(), CELL.y * sample.tiles.size())
		sample.rebuild()
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.save_png(output.path_join("preparation-%03d.png" % first))
		for row in range(sample.tiles.size()):
			var frames: Array[Image] = []
			var visible := 0
			for column in range(PHASES.size()):
				var frame := image.get_region(Rect2i(Vector2i(column * CELL.x, row * CELL.y), CELL))
				frame.convert(Image.FORMAT_RGBA8)
				frames.append(frame)
				visible += int(frame.get_used_rect().has_area())
			var features := _features(frames)
			var bytes_per_frame := GRID * GRID / 8
			var early: PackedByteArray = features.bits.slice(bytes_per_frame, bytes_per_frame * 2)
			var late: PackedByteArray = features.bits.slice(bytes_per_frame * 5, bytes_per_frame * 6)
			_check(visible >= 4 and _geometry_distance(early, late) >= 0.10,
				"%s: its long preparation visibly develops between early and final phases." % sample.tiles[row].id)
	print("Rendered full-width preparation phases for all %d wide tiles." % wide.size())


# Compare silhouette sequences rather than palette values. One union crop removes
# translation and uniform scale while retaining paths and changes between frames.
func _features(frames: Array[Image]) -> Dictionary:
	var bounds := _robust_bounds(frames)
	var bits := PackedByteArray()
	var mirror := PackedByteArray()
	var gray := PackedByteArray()
	var edge_data := PackedByteArray()
	for frame: Image in frames:
		var normalized := Image.create(NORMALIZED, NORMALIZED, false, Image.FORMAT_RGBA8)
		if bounds.has_area():
			var crop := frame.get_region(bounds)
			var scale := minf(float(NORMALIZED) / bounds.size.x, float(NORMALIZED) / bounds.size.y)
			crop.resize(maxi(1, roundi(bounds.size.x * scale)), maxi(1, roundi(bounds.size.y * scale)), Image.INTERPOLATE_LANCZOS)
			normalized.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), (Vector2i(NORMALIZED, NORMALIZED) - crop.get_size()) / 2)
		var data := normalized.get_data()
		var maximum := 0.001
		var levels := PackedFloat32Array()
		levels.resize(NORMALIZED * NORMALIZED)
		for pixel in range(NORMALIZED * NORMALIZED):
			var offset := pixel * 4
			levels[pixel] = maxi(data[offset], maxi(data[offset + 1], data[offset + 2])) * data[offset + 3] / 255.0
			maximum = maxf(maximum, levels[pixel])
		var visibility := minf(1.0, maximum / 51.0)
		var edges := PackedFloat32Array()
		edges.resize(levels.size())
		var edge_maximum := 0.001
		for y in range(1, NORMALIZED - 1):
			for x in range(1, NORMALIZED - 1):
				var pixel := y * NORMALIZED + x
				edges[pixel] = maxf(absf(levels[pixel + 1] - levels[pixel - 1]), absf(levels[pixel + NORMALIZED] - levels[pixel - NORMALIZED]))
				edge_maximum = maxf(edge_maximum, edges[pixel])
		for y in range(GRID):
			var row := 0
			var reflected := 0
			for x in range(GRID):
				var opacity := 0.0
				var luminance := 0.0
				var edge := 0.0
				for dy in range(4):
					for dx in range(4):
						var offset := ((y * 4 + dy) * NORMALIZED + x * 4 + dx) * 4
						var alpha := float(data[offset + 3]) / 255.0
						opacity += alpha
						luminance += levels[offset / 4] / maximum * visibility
						edge += edges[offset / 4] / edge_maximum * visibility
				if opacity / 16.0 >= 0.10:
					row |= 1 << x
					reflected |= 1 << (GRID - x - 1)
				gray.append(clampi(roundi(luminance / 16.0 * 255.0), 0, 255))
				edge_data.append(clampi(roundi(edge / 16.0 * 255.0), 0, 255))
			for byte in range(GRID / 8):
				bits.append((row >> (byte * 8)) & 255)
				mirror.append((reflected >> (byte * 8)) & 255)
	var edge_image := Image.create_from_data(GRID, GRID * frames.size(), false, Image.FORMAT_L8, edge_data)
	# Pool gradients after extraction so subpixel raster edges cannot dominate.
	edge_image.resize(GRID / 2, GRID / 2 * frames.size(), Image.INTERPOLATE_LANCZOS)
	var pooled_edges := edge_image.get_data()
	edge_image.convert(Image.FORMAT_RGBA8)
	var reflected_edges := edge_image.duplicate() as Image
	reflected_edges.flip_x()
	var energy := 0.0
	for value in pooled_edges:
		energy += pow(float(value) / 255.0, 2) / pooled_edges.size()
	return {"bits": bits, "mirror": mirror, "gray": gray,
		"edges": edge_image, "edges_mirror": reflected_edges, "edge_energy": energy}


func _robust_bounds(frames: Array[Image]) -> Rect2i:
	var raw := Rect2i()
	for image: Image in frames:
		var used := image.get_used_rect()
		if used.has_area():
			raw = raw.merge(used) if raw.has_area() else used
	if not raw.has_area():
		return Rect2i()
	var columns: Array[float] = []
	var rows: Array[float] = []
	columns.resize(raw.size.x)
	rows.resize(raw.size.y)
	columns.fill(0.0)
	rows.fill(0.0)
	for frame: Image in frames:
		var data := frame.get_region(raw).get_data()
		for y in range(raw.size.y):
			for x in range(raw.size.x):
				var alpha := float(data[(y * raw.size.x + x) * 4 + 3])
				columns[x] += alpha
				rows[y] += alpha
	var horizontal := _mass_interval(columns)
	var vertical := _mass_interval(rows)
	if horizontal.x < 0:
		return Rect2i()
	var start := raw.position + Vector2i(horizontal.x, vertical.x)
	var end := raw.position + Vector2i(horizontal.y + 1, vertical.y + 1)
	return Rect2i(start, end - start)


func _mass_interval(values: Array[float]) -> Vector2i:
	var total := 0.0
	for value in values:
		total += value
	if total <= 0.0:
		return Vector2i(-1, -1)
	var low := 0
	var high := values.size() - 1
	var trimmed := 0.0
	while low < high and trimmed + values[low] < total * 0.01:
		trimmed += values[low]
		low += 1
	trimmed = 0.0
	while high > low and trimmed + values[high] < total * 0.01:
		trimmed += values[high]
		high -= 1
	return Vector2i(low, high)


func _check_normalization(frames: Array[Image]) -> void:
	var original := _features(frames)
	for kind: String in ["color", "translation", "uniform_scale", "mirror", "single_pixel"]:
		var changed: Array[Image] = []
		for frame: Image in frames:
			var image := frame.duplicate() as Image
			if kind == "color":
				var data := image.get_data()
				for offset in range(0, data.size(), 4):
					var value := maxi(data[offset], maxi(data[offset + 1], data[offset + 2]))
					data[offset] = 0
					data[offset + 1] = value
					data[offset + 2] = 0
				image = Image.create_from_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, data)
			elif kind == "translation":
				var shifted := Image.create(image.get_width() + 16, image.get_height() + 16, false, Image.FORMAT_RGBA8)
				shifted.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(8, 8))
				image = shifted
			elif kind == "uniform_scale":
				image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
			elif kind == "mirror":
				image.flip_x()
			elif kind == "single_pixel":
				image.set_pixel(0, 0, Color.WHITE)
			changed.append(image)
		var transformed := _features(changed)
		var distance := _edge_distance(original, transformed)
		_check(distance < MIN_GEOMETRY_DISTANCE, "%s alone must not qualify as a unique tile animation (%.3f)." % [kind, distance])
		print("Normalization control %s: %.3f" % [kind, distance])


func _check_render_jitter(profile: Dictionary, original: Dictionary) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(CELL.x * PHASES.size(), CELL.y)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(viewport)
	var sample := ReleaseBatch.new()
	var changed := profile.duplicate(true)
	changed.scale = float(changed.scale) * 1.02
	changed.weight = float(changed.weight) * 1.02
	sample.tiles = [{"profile": changed}]
	viewport.add_child(sample)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	image.save_png(output.path_join("normalization-renderer-jitter.png"))
	var frames: Array[Image] = []
	var contacts: Array[Image] = []
	for phase in range(PHASES.size()):
		var frame := image.get_region(Rect2i(Vector2i(phase * CELL.x, 0), CELL))
		frames.append(frame)
		contacts.append(frame.get_region(Rect2i(195, 115, 140, 150)))
	var full := _features(frames)
	var local := _features(contacts)
	var distance := maxf(_edge_distance(original, full),
		_image_distance(original.contact_edges, local.edges, original.contact_edge_energy, local.edge_energy))
	_check(distance < MAX_RENDERER_JITTER, "Two-percent renderer scalar jitter stays within its calibrated raster-noise envelope (%.3f)." % distance)
	print("Normalization control actual renderer scalar jitter: %.3f" % distance)
	viewport.queue_free()


func _edge_distance(a: Dictionary, b: Dictionary) -> float:
	return minf(_image_distance(a.edges, b.edges, a.edge_energy, b.edge_energy),
		_image_distance(a.edges, b.edges_mirror, a.edge_energy, b.edge_energy))


func _image_distance(a: Image, b: Image, energy_a: float, energy_b: float) -> float:
	# Cosine distance preserves shape while removing uniform intensity changes.
	# The identical alpha channel occupies one quarter of Godot's RGBA mean.
	var squared_error := float(a.compute_image_metrics(b, false).mean_squared) * 4.0 / (3.0 * 255.0 * 255.0)
	if energy_a + energy_b < 0.000001:
		return 0.0
	var correlation := (energy_a + energy_b - squared_error) / (2.0 * sqrt(maxf(0.00000001, energy_a * energy_b)))
	return clampf(1.0 - correlation, 0.0, 1.0)


func _geometry_distance(a: PackedByteArray, b: PackedByteArray) -> float:
	return _tolerant_distance(a, b, _expanded(a), _expanded(b))


# A one-cell tolerance rejects raster edge aliasing and subpixel scalar jitter.
# Distinctness requires a meaningful region outside the other's nearby contour.
func _tolerant_distance(a: PackedByteArray, b: PackedByteArray, expanded_a: PackedByteArray, expanded_b: PackedByteArray) -> float:
	var changed := 0
	var occupied := 0
	for index in range(a.size()):
		changed += popcounts[(a[index] & ~expanded_b[index]) | (b[index] & ~expanded_a[index])]
		occupied += popcounts[a[index] | b[index]]
	return float(changed) / maxi(1, occupied)


func _expanded(bits: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(bits.size())
	var stride := GRID / 8
	var frame_size := GRID * stride
	for frame in range(bits.size() / frame_size):
		for y in range(GRID):
			var adjacent := 0
			for neighbor in range(maxi(0, y - 1), mini(GRID, y + 2)):
				var row := 0
				for byte in range(stride):
					row |= bits[frame * frame_size + neighbor * stride + byte] << (byte * 8)
				adjacent |= row
			adjacent = (adjacent | (adjacent << 1) | (adjacent >> 1)) & ((1 << GRID) - 1)
			for byte in range(stride):
				result[frame * frame_size + y * stride + byte] = (adjacent >> (byte * 8)) & 255
	return result


func _grayscale_distance(a: PackedByteArray, b: PackedByteArray) -> float:
	var changed := 0
	var energy := 0
	for index in range(a.size()):
		changed += absi(a[index] - b[index])
		energy += maxi(a[index], b[index])
	return float(changed) / maxi(1, energy)


func _write_gallery(ranked: Array) -> void:
	var pairs: Array = []
	var seen := {}
	for record: Dictionary in ranked:
		var key: String = record.id + "/" + record.nearest if record.id < record.nearest else record.nearest + "/" + record.id
		if seen.has(key):
			continue
		seen[key] = true
		pairs.append([record.id, record.nearest])
		if pairs.size() == 6:
			break
	await _save_pairs(pairs, "closest-pairs.png")
	_save_masks(pairs, "closest-masks.png")
	await _save_pairs([["bash", "shield_ram"], ["shot", "split_shot"], ["meteor_seal", "event_horizon"],
		["horizon_round_upgrade_rare_power", "horizon_round_upgrade_rare_technique"],
		["cinder_wave_upgrade_legendary_power", "cinder_wave_upgrade_legendary_technique"],
		["triage_kit", "triage_kit_upgrade_legendary_technique"]], "examples.png")
	await _save_pairs([["sweep", "sweep_upgrade_uncommon_power"],
		["sweep_upgrade_epic_technique", "sweep_upgrade_legendary_technique"],
		["horizon_round_upgrade_rare_power", "horizon_round_upgrade_epic_power"],
		["horizon_round_upgrade_rare_technique", "horizon_round_upgrade_epic_technique"],
		["aegis_intercept", "aegis_intercept_upgrade_legendary_technique"],
		["aegis_intercept_upgrade_rare_power", "aegis_intercept_upgrade_rare_technique"]], "tiers-and-branches.png")
	await _save_contact_pairs([
		["retreat_shot_upgrade_legendary_power", "snap_shot_upgrade_legendary_power"],
		["spark_shot_upgrade_epic_technique", "rivet_bolt_upgrade_epic_technique"],
		["jab_upgrade_epic_technique", "shield_tap_upgrade_epic_technique"],
		["volley", "piercing_burst_upgrade_rare_technique"],
		["guard_refrain_upgrade_rare_power", "guard_refrain_upgrade_rare_technique"],
		["tonic_dart", "tonic_dart_upgrade_uncommon_power"],
	], "critical-pairs-actual-size.png")


func _save_contact_pairs(pairs: Array, filename: String) -> void:
	# Native-resolution contacts avoid judging particle ink from half-size thumbnails.
	var proof := Image.create(1080, pairs.size() * 210, false, Image.FORMAT_RGBA8)
	proof.fill(Color("#17222d"))
	for row in range(pairs.size()):
		for side in range(2):
			var id: String = pairs[row][side]
			var index := records.find_custom(func(record: Dictionary): return record.id == id)
			if index < 0:
				continue
			var record: Dictionary = records[index]
			var atlas := Image.load_from_file(record.atlas)
			for column in range(3):
				var phase: int = [0, 2, 4][column]
				var source := Rect2i(phase * CELL.x + 190, record.row * CELL.y + 75, 180, 180)
				proof.blend_rect(atlas, source, Vector2i(side * 540 + column * 180, row * 210 + 30))
	var viewport := SubViewport.new()
	viewport.size = proof.get_size()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(viewport)
	var gallery := ContactGallery.new()
	gallery.picture = ImageTexture.create_from_image(proof)
	gallery.labels = pairs
	viewport.add_child(gallery)
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join(filename))
	viewport.queue_free()


func _save_pairs(pairs: Array, filename: String) -> void:
	var thumbnail := Vector2i(200, 140)
	var proof := Image.create(thumbnail.x * PHASES.size() * 2, thumbnail.y * pairs.size(), false, Image.FORMAT_RGBA8)
	proof.fill(Color("#17222d"))
	var labels := []
	for row in range(pairs.size()):
		for side in range(2):
			var id: String = pairs[row][side]
			var index := records.find_custom(func(record: Dictionary): return record.id == id)
			if index < 0:
				continue
			var record: Dictionary = records[index]
			var atlas := Image.load_from_file(record.atlas)
			for phase in range(PHASES.size()):
				var frame := atlas.get_region(Rect2i(Vector2i(phase * CELL.x, record.row * CELL.y), CELL))
				frame.resize(thumbnail.x, thumbnail.y, Image.INTERPOLATE_LANCZOS)
				proof.blend_rect(frame, Rect2i(Vector2i.ZERO, thumbnail), Vector2i((side * PHASES.size() + phase) * thumbnail.x, row * thumbnail.y))
		labels.append({"row": row + 1, "left": pairs[row][0], "right": pairs[row][1]})
	var viewport := SubViewport.new()
	viewport.size = Vector2i(proof.get_width(), pairs.size() * 168)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(viewport)
	var gallery := LabeledGallery.new()
	gallery.picture = ImageTexture.create_from_image(proof)
	gallery.labels = labels
	viewport.add_child(gallery)
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(output.path_join(filename))
	viewport.queue_free()
	var file := FileAccess.open(output.path_join(filename + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"phases": PHASES, "pairs": labels}, "  "))


func _save_masks(pairs: Array, filename: String) -> void:
	var cell := GRID * 6
	var image := Image.create(cell * PHASES.size() * 2, cell * pairs.size(), false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	for row in range(pairs.size()):
		for side in range(2):
			var id: String = pairs[row][side]
			var record: Dictionary = records[records.find_custom(func(value: Dictionary): return value.id == id)]
			for phase in range(PHASES.size()):
				for y in range(GRID):
					for x in range(GRID):
						var byte := phase * GRID * GRID / 8 + y * GRID / 8 + x / 8
						var value := float((record.bits[byte] >> (x % 8)) & 1)
						image.fill_rect(Rect2i((side * PHASES.size() + phase) * cell + x * 6, row * cell + y * 6, 6, 6), Color(value, value, value))
	image.save_png(output.path_join(filename))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
