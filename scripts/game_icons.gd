extends RefCounted

const ArenaSim = preload("res://scripts/arena_sim.gd")
const ClassDecks = preload("res://scripts/class_decks.gd")

const GLASS_PILOT_ART := {
	"glass_mirrorback": Rect2i(11, 22, 386, 373),
	"glass_annealer": Rect2i(464, 18, 376, 379),
	"glass_lens_arbalist": Rect2i(906, 21, 392, 384),
	"glass_kiln_ram": Rect2i(1342, 89, 425, 286),
	"glass_shard_conductor": Rect2i(74, 435, 321, 425),
	"glass_ash_siphon": Rect2i(467, 477, 368, 381),
	"glass_quench_sentinel": Rect2i(881, 445, 426, 405),
	"glass_furnace_knight": Rect2i(1353, 450, 404, 411),
}
const MOON_PILOT_ART := {
	"powder_runner": Rect2i(83, 54, 289, 359),
	"tar_pitcher": Rect2i(465, 27, 376, 384),
	"deck_ram": Rect2i(918, 25, 397, 391),
	"patch_rigger": Rect2i(1400, 31, 321, 389),
	"reef_diver": Rect2i(18, 471, 374, 385),
	"signal_gunner": Rect2i(454, 471, 382, 385),
	"chain_warden": Rect2i(888, 476, 433, 380),
	"wreck_bell": Rect2i(1387, 466, 364, 388),
}
const FAMILY_ICONS := {"bash": "push", "blink": "teleport", "shot": "shot", "guard": "guard", "slam": "area"}
const RELIC_ICONS := {
	"towline_knot": "pull", "bridgeplate": "guard", "brass_metronome": "review",
	"afterimage": "teleport", "barrage_rack": "shot", "siege_fuse": "area",
	"overflow_chalice": "rest", "stepped_gear": "forge", "mercy_seal": "guard",
	"twin_bell": "relic", "switchback_lens": "route", "longshot_prism": "shot",
}
const TILE_ICONS := {"pull": "pull", "gravity_hook": "pull", "slam": "area", "meteor_seal": "area",
	"hook_bash": "pull", "graviton": "pull", "event_horizon": "pull",
	"split_shot": "area", "volley": "area", "flak_burst": "area", "meteor_volley": "area",
	"riposte": "battle", "counterwall": "battle", "iron_rebuke": "battle", "last_stand": "battle"}
const HERO_ART := {
	"warden": "warden", "bulwark": "warden", "hexwright": "hexwright", "wayfarer": "hexwright",
	"breaker": "runesmith", "rune_smith": "runesmith", "cinder_mage": "runesmith",
	"duelist": "duelist", "lancer": "duelist", "starshot": "marksman",
	"cantor": "apothecary", "apothecary": "apothecary"
}
const HERO_CODES := {
	"warden": "WD", "bulwark": "BW", "breaker": "BR", "hexwright": "HX",
	"wayfarer": "WF", "lancer": "LN", "cantor": "CT", "apothecary": "AP",
	"rune_smith": "RS", "starshot": "ST", "cinder_mage": "CM", "duelist": "DL",
}
const RARITY_COLORS := {
	"common": Color("#b4bdc5"), "uncommon": Color("#78d992"), "rare": Color("#77b8ff"),
	"epic": Color("#cf9dff"), "legendary": Color("#ffc86d")
}
const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]


static func tile(id: String, spec: Dictionary) -> String:
	return spec.get("icon", TILE_ICONS.get(id, FAMILY_ICONS.get(spec.get("family", id), "battle")))


static func relic(id: String) -> String:
	return RELIC_ICONS.get(id, "relic")


static func pilot_enemy_art(id: String) -> Texture2D:
	var sheet := "res://assets/glass-pilot-enemies.png"
	var frame: Rect2i = GLASS_PILOT_ART.get(id, Rect2i())
	if not frame.has_area():
		sheet = "res://assets/moon-pilot-enemies.png"
		frame = MOON_PILOT_ART.get(id, Rect2i())
	if not frame.has_area() or not ResourceLoader.exists(sheet, "Texture2D"):
		return null
	var sprite := AtlasTexture.new()
	sprite.atlas = load(sheet) as Texture2D
	sprite.region = Rect2(frame)
	sprite.filter_clip = true
	return sprite


static func icon(key: String) -> Texture2D:
	var path := "res://assets/icons/%s.png" % key
	return load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else null


static func decorate(button: Button, key: String, size: int) -> void:
	button.icon = icon(key)
	button.add_theme_constant_override("icon_max_width", size)
	button.add_theme_constant_override("h_separation", 7)


static func portrait(class_id: String) -> String:
	return HERO_ART.get(class_id, "warden")


static func hero_label(class_id: String) -> String:
	return ArenaSim.HERO_CLASSES.get(class_id, {}).get("label", "")


static func hero_class_for_label(label: String) -> String:
	for class_id: String in ArenaSim.HERO_CLASSES:
		if hero_label(class_id) == label:
			return class_id
	return ""


static func tile_origin(id: String, spec: Dictionary) -> String:
	var base: String = spec.get("base_tile", id)
	for class_id: String in ClassDecks.DECKS:
		if ClassDecks.signature(class_id) == base:
			return class_id
	return ""


static func hero_badge(class_id: String, compact := true) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.name = "TileHeroBadge"
	badge.set_meta("hero_class", class_id)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.tooltip_text = hero_label(class_id)
	badge.visible = HERO_CODES.has(class_id)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("#172229")
	frame.border_color = Color("#6d8189")
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(3)
	frame.content_margin_left = 4 if compact else 6
	frame.content_margin_right = frame.content_margin_left
	frame.content_margin_top = 0 if compact else 2
	frame.content_margin_bottom = frame.content_margin_top
	badge.add_theme_stylebox_override("panel", frame)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	badge.add_child(row)
	if not compact and badge.visible:
		var face := TextureRect.new()
		face.texture = load("res://assets/%s.png" % portrait(class_id)) as Texture2D
		face.custom_minimum_size = Vector2(18, 18)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(face)
	var label := Label.new()
	label.text = HERO_CODES.get(class_id, "") if compact else hero_label(class_id)
	label.add_theme_font_size_override("font_size", 10 if compact else 13)
	label.add_theme_color_override("font_color", Color("#eef0ed"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return badge


static func rarity(spec: Dictionary) -> Color:
	return RARITY_COLORS.get(spec.get("rarity", "common"), RARITY_COLORS.common)


static func rarity_name(spec: Dictionary) -> String:
	var value: String = spec.get("rarity", "common")
	return value.capitalize() if value in RARITIES else "Common"


static func rarity_badge(spec: Dictionary, compact := false) -> Label:
	var label := Label.new()
	label.name = "TileRarityBadge"
	label.set_meta("rarity", rarity_name(spec).to_lower())
	label.text = rarity_pips(spec) if compact else rarity_name(spec)
	label.tooltip_text = rarity_name(spec)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 11 if compact else 13)
	label.add_theme_color_override("font_color", rarity(spec))
	return label


static func tile_stats(spec: Dictionary) -> String:
	var width := int(spec.width)
	var stats := PackedStringArray(["1 beat" if width == 1 else "%d beats" % width])
	if int(spec.get("damage", 0)) > 0:
		stats.append("%d damage" % int(spec.damage))
	return " · ".join(stats)


static func rarity_pips(spec: Dictionary) -> String:
	return "•".repeat(maxi(1, RARITIES.find(spec.get("rarity", "common")) + 1))
