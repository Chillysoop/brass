extends SceneTree

const ArenaSim = preload("res://scripts/arena_sim.gd")
const Choreography = preload("res://scripts/hero_attack_choreography.gd")
const Catalog = preload("res://scripts/tile_animation_catalog.gd")
const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]
const SHAPES := ["crescent", "chevron", "needle", "facet", "ring", "shield", "diamond", "petal",
	"flame", "rune", "bell", "hook", "hammer", "cross", "star", "flask"]
const PATHS := ["drive", "sweep", "split", "fan", "orbit", "recoil", "converge", "drop", "stitch",
	"relay", "spiral", "fold"]

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
		var details: Array = row.get("details", []).duplicate()
		details.sort()
		# Color, family, timing and small numeric differences cannot disguise repeated geometry.
		var signature := JSON.stringify([row.shape, row.path, row.count, details])
		_check(not signatures.has(signature), "%s repeats the primary visual gesture of %s." % [id, signatures.get(signature, "")])
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
		print("All %d runtime tile recipes, 129 authored motifs, forge branches, geometry, tempo and unknown fallbacks passed." % ArenaSim.TILES.size())
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
