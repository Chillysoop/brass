extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const Choreography = preload("res://scripts/hero_attack_choreography.gd")
const Catalog = preload("res://scripts/tile_animation_catalog.gd")
const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]
const SHAPES := ["crescent", "chevron", "needle", "facet", "ring", "shield", "diamond", "petal",
	"flame", "rune", "bell", "hook", "hammer", "cross", "star", "flask"]
const PATHS := ["drive", "sweep", "split", "fan", "orbit", "recoil", "converge", "drop", "stitch",
	"relay", "spiral", "fold"]
const GESTURES := ["lance", "cleave", "scatter", "fan", "recoil", "arc", "spiral", "tether",
	"collapse", "drop", "orbit", "blink", "dash", "dome", "fountain", "pulse"]
const MATERIALS := ["spark", "ember", "smoke", "brass", "aether", "shield", "heal", "phase", "crystal", "slash", "dust", "arc"]
const SCATTERS := ["tight", "fan", "radial", "paired", "column"]
const FINISHES := ["spray", "fall", "rise", "curl", "implode", "linger"]

var failures: Array[String] = []


func _initialize() -> void:
	var used := {}
	var branches := _forge_branches()
	for id: String in ArenaSim.TILES:
		var tile: Dictionary = ArenaSim.TILES[id]
		var base: String = tile.get("base_tile", id)
		used[base] = true
		if not _check(Catalog.MOTIFS.has(base), "%s resolves to an authored catalog entry." % id):
			continue
		var profile: Dictionary = Choreography.profile(id, tile)
		var recipe: Dictionary = profile.get("tile_animation", {})
		if not _check(not recipe.is_empty(), "%s has a recipe through the normal choreography path." % id):
			continue
		_check(recipe.get("motif") == Catalog.MOTIFS[base], "%s uses its exact authored base motif." % id)
		_check(recipe.get("beats") == tile.width, "%s prepares for its complete tile width." % id)
		_check(recipe.get("rank") == RARITIES.find(tile.rarity), "%s uses its actual rarity rank." % id)
		_check(recipe.get("branch") == branches.get(id, "base"), "%s follows its real forge choice." % id)
		_check(recipe.get("family") == profile.style, "%s retains the resolved choreography family." % id)
		_check(recipe.get("particles") == Catalog.MOTIFS[base].get("particles"), "%s exposes its exact textured emitter prescription." % id)
		_check(recipe.get("sprite_fusion") == profile.get("sprite_fusion", "")
			and recipe.get("signature_effect") == profile.get("signature_effect", ""), "%s retains its Sprite Fusion and signature foundation." % id)
		for layer: Dictionary in recipe.get("particle_layers", []):
			_check(layer.get("kind") in recipe.features.map(func(feature: Dictionary): return feature.kind),
				"%s only emits secondary responses for its real mechanics." % id)
			_check(layer.get("material") in MATERIALS and layer.get("secondary") in MATERIALS
				and layer.get("gesture") in GESTURES and layer.get("streams", 0) in range(1, 6)
				and layer.get("pulses", 0) in range(1, 5), "%s has supported bounded mechanic particles." % id)

	var signatures := {}
	_check(Catalog.MOTIFS.size() == 129 and used.size() == 129, "All 129 authored identities are present and used.")
	for id: String in Catalog.MOTIFS:
		var row: Dictionary = Catalog.MOTIFS[id]
		_check(used.has(id), "%s is reachable from a real tile." % id)
		_check(row.get("shape") in SHAPES and row.get("path") in PATHS, "%s uses supported visible geometry." % id)
		_check(row.get("count") is int and row.count >= 1 and row.count <= 5, "%s has a bounded integer shape count." % id)
		_check(is_finite(row.turn) and absf(row.turn) <= 1.0
			and is_finite(row.spread) and row.spread >= 0.0 and row.spread <= 1.0
			and is_finite(row.reach) and row.reach >= 0.5 and row.reach <= 1.8,
			"%s keeps its motion parameters within the renderer contract." % id)
		var tempo: Array = row.get("tempo", [])
		_check(tempo.size() == 3 and tempo[0] > 0.0 and tempo[0] < tempo[1]
			and tempo[1] < tempo[2] and tempo[2] < 1.0, "%s has ordered full-block preparation phases." % id)
		var particles: Dictionary = row.get("particles", {})
		_check(particles.get("gesture") in GESTURES and particles.get("material") in MATERIALS
			and particles.get("secondary") in MATERIALS and particles.get("material") != particles.get("secondary"),
			"%s uses an authored trajectory and two supported textured materials." % id)
		_check(particles.get("streams", 0) in range(1, 6) and particles.get("pulses", 0) in range(1, 5)
			and particles.get("scatter") in SCATTERS and particles.get("finish") in FINISHES,
			"%s has bounded emission groups and a supported spatial/cadence finish." % id)
		# Color, scale, old polygon shapes and opaque IDs cannot disguise repeated emitters.
		var signature := JSON.stringify([particles.get("gesture"), particles.get("material"), particles.get("secondary"),
			particles.get("streams"), particles.get("pulses"), particles.get("scatter"), particles.get("finish")])
		_check(not signatures.has(signature), "%s repeats the authored particle prescription of %s." % [id, signatures.get(signature, "")])
		signatures[signature] = id

	var unknown := Choreography.profile("unlisted_animation_tile", {"damage": 1, "width": 2, "rarity": "common"})
	_check(unknown.get("tile_animation", {}).is_empty(), "Unknown tile IDs retain the empty recipe fallback.")
	var unknown_base: Dictionary = ArenaSim.TILES.jab.duplicate()
	unknown_base.base_tile = "unlisted_animation_family"
	_check(Choreography.profile("jab", unknown_base).get("tile_animation", {}).is_empty(),
		"An unknown base family does not borrow another tile's motif.")
	for failure: String in failures:
		printerr(failure)
	if failures.is_empty():
		print("All %d runtime tile recipes, 129 textured particle prescriptions, actual mechanic layers, forge branches, full-block tempo and unknown fallbacks passed." % ArenaSim.TILES.size())
	quit(0 if failures.is_empty() else 1)


func _forge_branches() -> Dictionary:
	var result := {}
	for tiers: Array in ArenaSim.FORGE_FAMILIES.values():
		for choices: Array in tiers:
			if choices.size() == 1:
				result[choices[0]] = "base"
			elif choices.size() == 2:
				result[choices[0]] = "power"
				result[choices[1]] = "technique"
	return result


func _check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
	return condition
