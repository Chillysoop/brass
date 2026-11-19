extends SceneTree

const SpriteSheet = preload("res://scripts/combat_sprite_sheet.gd")
const ArenaView = preload("res://scripts/arena_view.gd")
const ArenaSim = preload("res://scripts/arena_sim.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var path := "res://assets/warden.png"
	var texture := load(path) as Texture2D
	var dimensions := texture.get_size()
	var frame := {"rect": [0, 0, dimensions.x, dimensions.y], "pivot": [dimensions.x * 0.4, dimensions.y * 0.9]}
	var record := {"height": dimensions.y, "facing": 1,
		"animations": {
			"idle": {"texture": path, "frames": [frame], "fps": 8, "loop": true},
			"run": {"texture": path, "frames": [frame, frame, frame, frame], "fps": 8, "loop": true},
			"attack": {"texture": path, "frames": [frame, frame, frame, frame, frame, frame],
				"fps": 12, "loop": false, "contact_frame": 2},
			"hit": {"texture": path, "frames": [frame, frame], "fps": 12, "loop": false},
			"death": {"texture": path, "frames": [frame, frame, frame, frame], "fps": 8, "loop": false},
		}}
	var sheet := SpriteSheet.new(record)
	_expect(sheet.idle_texture().get_image() != null, "The nearest-sampled still can be analyzed by the fallback mesh.")
	_expect(sheet.is_animated("attack") and not sheet.is_animated("idle"), "Sheet clips choose real frame animation or articulated still fallback.")
	_expect(sheet.frame_at("run", 0.50) == 0 and sheet.frame_at("death", 5.0) == 3,
		"Looping and one-shot clips have separate end behavior.")
	_expect(sheet.attack_frame(0.99, false) == 1 and sheet.attack_frame(0.0, true) == 2,
		"Preparation cannot reach the contact frame before the real combat cue.")
	_expect(sheet.attack_frame(1.0, true) == 5, "The released attack completes its remaining frames.")
	var layout := sheet.fallback_layout(100)
	_expect(is_equal_approx(float(layout.height), 100.0) and layout.offset.is_equal_approx(Vector2(
		dimensions.x / dimensions.y * 10.0, 10.0)), "Static mesh fallback keeps the sheet's explicit feet pivot.")

	var old_catalog := SpriteSheet._catalog
	var old_loaded := SpriteSheet._catalog_loaded
	var old_sheets := SpriteSheet._sheets
	SpriteSheet._catalog = {"version": 1, "heroes": {"warden": record}}
	SpriteSheet._catalog_loaded = true
	SpriteSheet._sheets = {}
	var view := ArenaView.new()
	root.add_child(view)
	view.size = Vector2(850, 357)
	view.set_process(false)
	var lanes := [[{"id": "slam", "start": 2, "target": "nearest"}]]
	var sim := ArenaSim.new()
	sim.start(lanes, "solo")
	view.reset_view(sim.units, lanes)
	var hero: Dictionary = sim.units.front()
	var ready := 2 * ArenaSim.TICKS_PER_BEAT
	while sim.tick < ready:
		var events := sim.step()
		view.present(sim.units, events, sim.tick, sim.visual_cues, 3)
	var preparing: Dictionary = view._windup_details(hero)
	_expect(not preparing.is_empty() and preparing.beats == ArenaSim.TILES.slam.width,
		"Wide-tile preparation starts at the full tile's left edge.")
	_expect(view._sheet_frame(sheet, hero, preparing, {}, 0.0).frame < 2,
		"A wide tile stays in the sheet's preparation frames.")
	_expect(view._sheet_frame(sheet, hero, preparing, {}, 1.0).state == "run",
		"Early anticipation leaves visible room for locomotion while the full tile charges.")
	var finishing := preparing.duplicate()
	finishing.charge = 0.90
	_expect(view._sheet_frame(sheet, hero, finishing, {}, 1.0).state == "attack",
		"The final preparation segment brings up the weapon even while closing range.")
	var previous_release := {"age": 0.10, "lifetime": 0.30, "tick": ready}
	_expect(view._sheet_frame(sheet, hero, preparing, previous_release, 1.0).state == "run",
		"A lingering release effect leaves locomotion available during the next occupied tile.")
	previous_release.age = 0.0
	_expect(view._sheet_frame(sheet, hero, preparing, previous_release, 1.0).state == "attack",
		"The real contact frame remains visible before the body resumes locomotion.")
	var release := (2 + int(ArenaSim.TILES.slam.width)) * ArenaSim.TICKS_PER_BEAT
	while sim.tick < release:
		var events := sim.step()
		view.present(sim.units, events, sim.tick, sim.visual_cues, 3)
	var cast: Dictionary = view._actor_casts[hero.id]
	_expect(view._sheet_frame(sheet, hero, {}, cast, 0.0).frame == 2,
		"The actual right-edge cue selects the sheet contact frame.")
	view._sprite_hits[hero.id] = 0.05
	_expect(view._sheet_frame(sheet, hero, preparing, cast, 1.0).state == "attack",
		"A hit reaction cannot replace the actual strike contact frame.")
	_expect(view._sheet_frame(sheet, hero, preparing, {}, 1.0).state == "run",
		"Layered recoil leaves early preparation locomotion intact.")
	_expect(view._sheet_frame(sheet, hero, {}, {}, 0.0).state == "hit",
		"An idle actor can play its authored hit clip without replacing an active action.")
	hero.hp = 0
	view.present(sim.units, [{"kind": "defeat_unit", "actor": sim.units.back().id,
		"target": hero.id, "tile": "enemy_attack", "from": sim.units.back().pos, "to": hero.pos}], sim.tick, [], 3)
	_expect(view._sprite_deaths.has(hero.id), "Defeat retains a cosmetic playback snapshot.")
	view.playback_paused = true
	view._process(0.15)
	_expect(view._sprite_deaths[hero.id].age == 0.0, "Pause freezes sprite playback as well as effects.")
	view.playback_paused = false
	view._process(0.15)
	_expect(view._sprite_deaths[hero.id].age > 0.0, "A death snapshot advances while playing.")
	view.reset_view(sim.units, lanes)
	_expect(view._sprite_deaths.is_empty() and view._sprite_hits.is_empty(), "Retry clears sprite reactions and death snapshots.")
	view.queue_free()
	SpriteSheet._catalog = old_catalog
	SpriteSheet._catalog_loaded = old_loaded
	SpriteSheet._sheets = old_sheets
	_check_authored_clips()
	for failure: String in _failures:
		printerr(failure)
	if _failures.is_empty():
		print("Sprite sheet frame clocks, contact sync, pivot, pause, death lifecycle, and all authored clips passed.")
	quit(0 if _failures.is_empty() else 1)


func _check_authored_clips() -> void:
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(SpriteSheet.MANIFEST))
	if not catalog is Dictionary:
		_expect(false, "The shipping sprite manifest is readable.")
		return
	for id: String in ArenaSim.HERO_CLASSES:
		_check_authored_record(catalog.get("heroes", {}).get(id, {}), id, ["idle", "run", "attack"])
	for id: String in ["brass_tollkeeper", "marshal", "tempered_colossus", "drowned_admiral"]:
		_check_authored_record(catalog.get("enemies", {}).get(id, {}), id, ["idle", "attack"])


func _check_authored_record(record: Dictionary, id: String, states: Array) -> void:
	var sheet := SpriteSheet.new(record)
	for state: String in states:
		var frames: Array = record.get("animations", {}).get(state, {}).get("frames", [])
		_expect(sheet.frame_count(state) == frames.size() and not frames.is_empty(),
			"%s imports every authored %s frame with valid bounds." % [id, state])
		if state != "idle":
			_expect(sheet.is_animated(state), "%s has actual animated %s artwork." % [id, state])
	if not sheet.has_animation("attack"):
		return
	var contact: int = sheet._clips.attack.contact
	_expect(contact > 0 and contact < sheet.frame_count("attack"), "%s has distinct preparation and contact frames." % id)
	_expect(sheet.attack_frame(0.999, false) < contact and sheet.attack_frame(0.0, true) == contact,
		"%s preserves its reviewed contact frame until the actual release." % id)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
