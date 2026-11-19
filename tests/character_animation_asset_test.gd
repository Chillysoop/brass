extends SceneTree

const Sheet = preload("res://scripts/combat_sprite_sheet.gd")
const Sim = preload("res://scripts/arena_sim.gd")
const Choreography = preload("res://scripts/hero_attack_choreography.gd")
const Decks = preload("res://scripts/class_decks.gd")
const Formations = preload("res://scripts/campaign_formations.gd")
var failures: Array[String] = []
var native_clips := 0


func _initialize() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Sheet.MANIFEST))
	for id: String in Sim.HERO_CLASSES:
		var record: Dictionary = catalog.heroes[id]
		var sheet: RefCounted = Sheet.for_identity("hero", id)
		var actions := []
		for state: String in record.animations:
			if state == "attack" or state.begins_with("attack_"):
				actions.append(state)
		_check(actions.size() >= 2, "%s has multiple genuinely authored action clips." % id)
		for state: String in ["run", "hit", "death"] + actions:
			_check_clip(sheet, record, id, state)
		var selected := {}
		for tile: String in Decks.common(id) + Decks.uncommon(id):
			if Sim.TILES.has(tile):
				selected[sheet.action_for(Choreography.profile(tile, Sim.TILES[tile]), id)] = true
		_check(selected.size() >= 2, "%s's own actual deck selects multiple native actions." % id)
	var first_act := {}
	for pools: Array in Formations.BRASS[1].values():
		for lineup: Array in pools:
			for id: String in lineup:
				var source: Dictionary = Sim.CAMPAIGN_ENEMIES.get(id, Sim.PILOT_ENEMY_SCRIPTS.brass.ENEMIES.get(id, {}))
				first_act[source.art] = true
	for id: String in ["brass_tollkeeper", "brass_bellmaker", "tollkeeper_drone"]:
		first_act[id] = true
	_check(first_act.size() == 12, "Coverage uses the actual twelve-identity Act I encounter roster.")
	for id: String in first_act:
		var sheet: RefCounted = Sheet.for_identity("enemy", id)
		for state: String in ["run", "attack"]:
			_check_clip(sheet, catalog.enemies[id], id, state)
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("All 12 heroes' real action families/reactions and all 12 Act I enemy run/attack clips passed native pixels, sockets, scale and contact checks (%d clips)." % native_clips)
	quit(0 if failures.is_empty() else 1)


func _check_clip(sheet: RefCounted, record: Dictionary, identity: String, state: String) -> void:
	if not _check(sheet != null and sheet.is_animated(state), "%s has an imported animated %s clip." % [identity, state]):
		return
	var clip: Dictionary = record.animations[state]
	_check(sheet.frame_count(state) == clip.frames.size(), "%s imports every %s frame." % [identity, state])
	var image := Image.new()
	var decode := image.load_png_from_buffer(FileAccess.get_file_as_bytes(clip.texture))
	if not _check(decode == OK, "%s/%s source pixels are readable." % [identity, state]):
		return
	var fingerprints := {}
	for index in range(clip.frames.size()):
		var frame: Dictionary = clip.frames[index]
		var extent := Vector2(frame.rect[2], frame.rect[3])
		_check(is_finite(float(clip.reference_height)) and float(clip.reference_height) > 0.0,
			"%s/%s uses body height independent of padded canvas size." % [identity, state])
		for name: String in Sheet.SOCKETS:
			_check(sheet.has_socket(state, index, name), "%s/%s frame %d has an authored %s socket." % [identity, state, index, name])
			var point: Vector2 = sheet.socket_pixel(state, index, name)
			_check(point.is_finite() and point.x >= 0.0 and point.y >= 0.0 and point.x <= extent.x and point.y <= extent.y,
				"%s/%s %s socket stays in the frame's source coordinate system." % [identity, state, name])
		_check(sheet.socket_pixel(state, index, "feet").is_equal_approx(Vector2(frame.pivot[0], frame.pivot[1])),
			"%s/%s feet anchor matches its actual drawing pivot." % [identity, state])
		var region := Rect2i(int(frame.rect[0]), int(frame.rect[1]), int(frame.rect[2]), int(frame.rect[3]))
		var pixels := image.get_region(region)
		_check(pixels.get_used_rect().has_area(), "%s/%s frame %d contains visible character art." % [identity, state, index])
		fingerprints[pixels.get_data().hex_encode()] = true
	_check(fingerprints.size() >= 2, "%s/%s has different actual sprite poses." % [identity, state])
	if state == "attack" or state.begins_with("attack_"):
		var contact := int(clip.contact_frame)
		_check(contact > 0 and contact < clip.frames.size() and sheet.attack_frame(0.999, false, state) < contact
			and sheet.attack_frame(0.0, true, state) == contact, "%s/%s contacts exactly on its release cue." % [identity, state])
	native_clips += 1


func _check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
	return condition
