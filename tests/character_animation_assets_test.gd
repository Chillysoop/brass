extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const Formations = preload("res://scripts/campaign_formations.gd")
const SpriteSheet = preload("res://scripts/combat_sprite_sheet.gd")
var failures: Array[String] = []


func _initialize() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SpriteSheet.MANIFEST))
	var first_act := {}
	# Act means the leg number, not the complete three-leg Brass Frontier region.
	for kind: String in ["opening", "battle", "elite"]:
		for team: Array in Formations.BRASS[1][kind]:
			for enemy: String in team:
				var definition: Dictionary = ArenaSim.CAMPAIGN_ENEMIES.get(enemy, {})
				if definition.is_empty():
					definition = ArenaSim.PILOT_ENEMY_SCRIPTS.brass.ENEMIES.get(enemy, {})
				_check(not definition.is_empty(), "%s has an actual Act I enemy definition." % enemy)
				first_act[definition.get("art", enemy)] = true
	for boss_id: String in ["tollkeeper", "brass_bellmaker"]:
		for difficulty: String in ["easy", "medium", "hard"]:
			var sim := ArenaSim.new()
			sim.start([[{"id": "jab", "start": 0, "target": "nearest"}]], "solo", {
				"seed": 10, "location": "brass", "encounter": "boss", "boss_id": boss_id,
				"difficulty": difficulty, "segment": 1, "boss_variant": "repair_drone"})
			for unit: Dictionary in sim.units:
				if unit.side == "enemy":
					first_act[unit.sprite] = true
	_check(first_act.size() == 12, "The actual Act I formation/boss/support roster has twelve physical sprite identities.")
	for identity: String in first_act:
		var record: Dictionary = catalog.enemies.get(identity, {})
		for state: String in ["run", "attack"]:
			_check_clip(record, identity, state)
	for identity: String in ArenaSim.HERO_CLASSES:
		var record: Dictionary = catalog.heroes.get(identity, {})
		for state: String in ["run", "attack", "hit", "death"]:
			_check_clip(record, identity, state)
		var actions := 0
		for state: String in record.animations:
			if state == "attack" or state.begins_with("attack_"):
				_check_clip(record, identity, state)
				actions += 1
		_check(actions >= 2, "%s has its original native action plus an additional native action family." % identity)
		_check(record.get("action_families", {}).size() >= 2, "%s can select distinct native action families." % identity)
	# The original quick spear sheet clipped its tip at full extension. Keep the
	# complete replacement weapon inside every authored frame as this evolves.
	_check_weapon_margin(catalog.heroes.lancer.animations.attack)
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("All twelve hero action/reaction sets and the actual twelve-enemy Act I roster have native clips with attachment and foot landmarks.")
	quit(0 if failures.is_empty() else 1)


func _check_clip(record: Dictionary, identity: String, state: String) -> void:
	var clip: Dictionary = record.get("animations", {}).get(state, {})
	if not _check(clip.get("frames", []).size() > 1, "%s/%s has real multiframe artwork." % [identity, state]):
		return
	_check(ResourceLoader.exists(clip.texture, "Texture2D"), "%s/%s texture imports into the game." % [identity, state])
	_check(float(clip.get("reference_height", record.height)) > 0.0, "%s/%s has a positive body scale reference." % [identity, state])
	_check(int(clip.contact_frame) >= 0 and int(clip.contact_frame) < clip.frames.size(), "%s/%s has a valid release frame." % [identity, state])
	for frame: Dictionary in clip.frames:
		var rect: Array = frame.rect
		var sockets: Dictionary = frame.get("sockets", {})
		for kind: String in ["hand", "blade", "muzzle", "cast", "feet"]:
			var point: Array = sockets.get(kind, [])
			_check(point.size() == 2 and is_finite(float(point[0])) and is_finite(float(point[1]))
				and float(point[0]) >= 0.0 and float(point[0]) <= float(rect[2])
				and float(point[1]) >= 0.0 and float(point[1]) <= float(rect[3]),
				"%s/%s keeps its %s socket inside the real animation frame." % [identity, state, kind])
		_check(frame.pivot == sockets.get("feet"), "%s/%s shares the authored ground and rendering pivot." % [identity, state])


func _check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
	return condition


func _check_weapon_margin(clip: Dictionary) -> void:
	var texture := load(clip.texture) as Texture2D
	if not _check(texture != null, "Lancer's quick spear artwork imports for its clipping regression."):
		return
	var sheet := texture.get_image()
	for index: int in clip.frames.size():
		var rect: Array = clip.frames[index].rect
		var x := int(rect[0])
		var y := int(rect[1])
		var width := int(rect[2])
		var height := int(rect[3])
		var clear := true
		for row: int in height:
			if sheet.get_pixel(x, y + row).a >= 0.5 or sheet.get_pixel(x + width - 1, y + row).a >= 0.5:
				clear = false
		_check(clear, "Lancer quick frame %d keeps the full spear away from the frame's cropped edges." % index)
