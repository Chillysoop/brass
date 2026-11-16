extends RefCounted

const ArenaSim = preload("res://scripts/arena_sim.gd")
const ClassDecks = preload("res://scripts/class_decks.gd")
const TileEnchantments = preload("res://scripts/tile_enchantments.gd")

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
const BRASS_VARIETY_ART := {
	"brass_runner": Rect2i(49, 38, 282, 291),
	"brass_riveter": Rect2i(400, 69, 259, 252),
	"brass_shieldwright": Rect2i(745, 22, 297, 312),
	"brass_linksmith": Rect2i(1110, 21, 303, 309),
	"brass_springjack": Rect2i(23, 383, 333, 287),
	"brass_rivet_hound": Rect2i(379, 426, 327, 228),
	"brass_manifold": Rect2i(737, 375, 333, 305),
	"brass_sparkbow": Rect2i(1110, 375, 315, 321),
	"brass_magnetar": Rect2i(26, 738, 328, 307),
	"brass_grounder": Rect2i(397, 733, 310, 324),
	"brass_flywheel": Rect2i(747, 756, 321, 298),
	"brass_pressure_sentinel": Rect2i(1114, 723, 304, 339),
}
const CROWN_VARIETY_ART := {
	"crown_page": Rect2i(38, 39, 263, 294),
	"crown_slinger": Rect2i(362, 75, 312, 258),
	"crown_glaiveguard": Rect2i(685, 16, 386, 318),
	"crown_spotter": Rect2i(1128, 5, 306, 330),
	"crown_war_drummer": Rect2i(36, 354, 282, 309),
	"crown_feintblade": Rect2i(355, 369, 348, 292),
	"crown_twinspur": Rect2i(735, 397, 342, 264),
	"crown_ballista": Rect2i(1093, 386, 343, 265),
	"crown_storm_templar": Rect2i(13, 697, 330, 356),
	"crown_banneret": Rect2i(408, 684, 316, 371),
	"crown_galvanist": Rect2i(755, 739, 283, 316),
	"crown_beacon_sentry": Rect2i(1092, 684, 322, 373),
}
const EARLY_VARIETY_ART := {
	"glass_cullet_slinger": Rect2i(12, 144, 280, 266),
	"glass_kiln_porter": Rect2i(335, 14, 340, 396),
	"glass_facet_hound": Rect2i(682, 146, 377, 262),
	"glass_lacquerer": Rect2i(1093, 57, 288, 354),
	"glass_crucible_binder": Rect2i(1381, 54, 387, 355),
	"dock_saltblade": Rect2i(6, 554, 319, 293),
	"dock_torchbearer": Rect2i(359, 508, 293, 338),
	"dock_bilge_sapper": Rect2i(675, 529, 300, 317),
	"dock_shellback": Rect2i(1004, 506, 376, 341),
	"dock_hull_harrier": Rect2i(1380, 498, 383, 351),
}
const ENEMY_SHEETS := {
	"res://assets/brass-gate-guardians.png": {
		"brass_recruit": Rect2i(193, 179, 223, 261),
		"brass_bruiser": Rect2i(767, 179, 338, 266),
		"brass_captain": Rect2i(155, 773, 273, 307),
		"brass_tollkeeper": Rect2i(739, 772, 368, 306),
	},
	"res://assets/glass-pilot-enemies.png": GLASS_PILOT_ART,
	"res://assets/moon-pilot-enemies.png": MOON_PILOT_ART,
	"res://assets/brass-variety-enemies.png": BRASS_VARIETY_ART,
	"res://assets/crown-variety-enemies.png": CROWN_VARIETY_ART,
	"res://assets/early-variety-enemies.png": EARLY_VARIETY_ART,
	"res://assets/crown-specialists.png": {
		"crown_oathbreaker": Rect2i(145, 46, 589, 689),
		"crown_chorister": Rect2i(1274, 51, 421, 703),
	},
}
const FAMILY_ICONS := {"bash": "push", "blink": "teleport", "shot": "shot", "guard": "guard", "slam": "area"}
const RELIC_ICONS := {
	"towline_knot": "pull", "bridgeplate": "guard", "brass_metronome": "review",
	"afterimage": "teleport", "barrage_rack": "shot", "siege_fuse": "area",
	"overflow_chalice": "rest", "stepped_gear": "forge", "mercy_seal": "guard",
	"twin_bell": "relic", "switchback_lens": "route", "longshot_prism": "shot",
	"tollkeeper_signet": "boss", "bastion_medal": "guard", "guild_ledger": "shop",
	"tollkeeper_repair_kit": "rest", "bellmaker_clapper": "area", "bellmaker_long_echo": "shot",
	"bellmaker_resonant_plate": "guard",
}
const TILE_ICONS := {"pull": "pull", "gravity_hook": "pull", "slam": "area", "meteor_seal": "area",
	"hook_bash": "pull", "graviton": "pull", "event_horizon": "pull",
	"split_shot": "area", "volley": "area", "flak_burst": "area", "meteor_volley": "area",
	"riposte": "battle", "counterwall": "battle", "iron_rebuke": "battle", "last_stand": "battle"}
const HERO_ART := {
	"warden": "warden", "bulwark": "bulwark", "hexwright": "hexwright", "wayfarer": "wayfarer",
	"breaker": "breaker", "rune_smith": "runesmith", "cinder_mage": "cinder_mage",
	"duelist": "duelist", "lancer": "lancer", "starshot": "marksman",
	"cantor": "cantor", "apothecary": "apothecary"
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
const ENCHANTMENT_COLORS := {"guarded": Color("#7de4cf"), "longshot": Color("#f0ce90"), "splash": Color("#f0a48c")}

static var _enemy_textures: Dictionary = {}
static var _hero_textures: Dictionary = {}


static func tile(id: String, spec: Dictionary) -> String:
	return spec.get("icon", TILE_ICONS.get(id, FAMILY_ICONS.get(spec.get("family", id), "battle")))


static func relic(id: String) -> String:
	return RELIC_ICONS.get(id, "relic")


static func pilot_enemy_art(id: String) -> Texture2D:
	for sheet: String in ENEMY_SHEETS:
		var frame: Rect2i = ENEMY_SHEETS[sheet].get(id, Rect2i())
		if frame.has_area() and ResourceLoader.exists(sheet, "Texture2D"):
			var sprite := AtlasTexture.new()
			sprite.atlas = load(sheet) as Texture2D
			sprite.region = Rect2(frame)
			sprite.filter_clip = true
			return sprite
	return null


static func enemy_art(id: String) -> Texture2D:
	if _enemy_textures.has(id):
		return _enemy_textures[id]
	var path := "res://assets/combatants/%s.png" % id
	var texture: Texture2D
	if ResourceLoader.exists(path, "Texture2D"):
		texture = load(path) as Texture2D
	else:
		texture = pilot_enemy_art(id)
		if texture == null:
			var asset := "tollkeeper-repair-drone" if id == "tollkeeper_drone" else id
			path = "res://assets/%s.png" % asset
			if ResourceLoader.exists(path, "Texture2D"):
				texture = load(path) as Texture2D
	if texture != null:
		_enemy_textures[id] = texture
	return texture


static func icon(key: String) -> Texture2D:
	var path := "res://assets/icons/%s.png" % key
	return load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else null


static func decorate(button: Button, key: String, size: int) -> void:
	button.icon = icon(key)
	button.add_theme_constant_override("icon_max_width", size)
	button.add_theme_constant_override("h_separation", 7)


static func lock_badge(parent: Control, extent: float) -> Control:
	var badge := Control.new()
	badge.name = "LockBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.draw.connect(func(): draw_lock(badge, badge.size * 0.5, minf(extent, minf(badge.size.x, badge.size.y))))
	badge.resized.connect(badge.queue_redraw)
	parent.add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return badge


static func draw_lock(canvas: Control, center: Vector2, extent: float, framed := true) -> void:
	if extent <= 0.0:
		return
	var scale := extent / 56.0
	var ink := Color("#14212b")
	var bronze := Color("#c68f51")
	var brass := Color("#f1ce8e")
	if framed:
		canvas.draw_circle(center + Vector2(0, 2) * scale, 28 * scale, Color("#0b121bdb"), true, -1, true)
		canvas.draw_circle(center, 26 * scale, ink, true, -1, true)
		canvas.draw_circle(center, 26 * scale, bronze, false, 1.5 * scale, true)
	var shackle := center + Vector2(0, -5) * scale
	canvas.draw_arc(shackle, 9.0 * scale, PI, TAU, 24, brass, 4.5 * scale, true)
	for side: float in [-9.0, 9.0]:
		canvas.draw_line(shackle + Vector2(side, 0) * scale, shackle + Vector2(side, 7) * scale, brass, 4.5 * scale, true)
	var body := Rect2(center + Vector2(-15, -3) * scale, Vector2(30, 21) * scale)
	canvas.draw_rect(body.grow(scale), ink)
	canvas.draw_rect(body, bronze)
	canvas.draw_rect(Rect2(body.position, Vector2(body.size.x, 15 * scale)), brass)
	canvas.draw_circle(center + Vector2(0, 5) * scale, 3.2 * scale, ink, true, -1, true)
	canvas.draw_rect(Rect2(center + Vector2(-1.6, 6) * scale, Vector2(3.2, 5.2) * scale), ink)


static func portrait(class_id: String) -> String:
	return HERO_ART.get(class_id, "warden")


static func hero_art(class_id: String) -> Texture2D:
	var id := portrait(class_id)
	if not _hero_textures.has(id):
		var path := "res://assets/combatants/%s.png" % id
		if not ResourceLoader.exists(path, "Texture2D"):
			path = "res://assets/%s.png" % id
		if ResourceLoader.exists(path, "Texture2D"):
			_hero_textures[id] = load(path) as Texture2D
	return _hero_textures.get(id)


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
		face.texture = hero_art(class_id)
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


static func critical_tooltip(tile_id: String, hero_id := "") -> String:
	var near := roundi(ArenaSim.critical_chance(hero_id, tile_id, 0.0) * 100.0)
	if near == 0:
		return ""
	var multiplier := str(ArenaSim.CRITICAL_DAMAGE_MULTIPLIER)
	var far := roundi(ArenaSim.critical_chance(hero_id, tile_id, INF) * 100.0)
	if near != far:
		return "%d%% critical chance, rising to %d%% beyond %d range. Critical hits deal %s× damage before defenses." % [
			near, far, int(ArenaSim.PRECISION_BONUS_RANGE), multiplier]
	return "Direct hits have a %d%% chance to deal %s× damage before defenses." % [near, multiplier]


static func rarity_pips(spec: Dictionary) -> String:
	return "•".repeat(maxi(1, RARITIES.find(spec.get("rarity", "common")) + 1))


static func enchantment_color(id: String) -> Color:
	return ENCHANTMENT_COLORS.get(id, Color("#9ddbd1"))


static func enchantment_badge(id: String, extent := 18) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.name = "TileEnchantmentBadge"
	badge.set_meta("enchantment", id)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2.ONE * extent
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var spec := TileEnchantments.info(id)
	badge.visible = not spec.is_empty()
	if spec.is_empty():
		return badge
	badge.tooltip_text = "%s · %s" % [spec.label, spec.description]
	var accent := enchantment_color(id)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("#101e29")
	frame.border_color = accent.darkened(0.20)
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(4)
	badge.add_theme_stylebox_override("panel", frame)
	var glyph := Control.new()
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.draw.connect(func(): _draw_enchantment_glyph(glyph, id, accent))
	glyph.resized.connect(glyph.queue_redraw)
	badge.add_child(glyph)
	return badge


static func _draw_enchantment_glyph(glyph: Control, id: String, color: Color) -> void:
	var center := glyph.size * 0.5
	var scale_factor := minf(glyph.size.x, glyph.size.y) / 14.0
	var stroke := maxf(1.0, 1.5 * scale_factor)
	match id:
		"guarded":
			var points := PackedVector2Array()
			for offset: Vector2 in [Vector2(-4, -3), Vector2(0, -5), Vector2(4, -3), Vector2(4, 1), Vector2(0, 5), Vector2(-4, 1), Vector2(-4, -3)]:
				points.append(center + offset * scale_factor)
			glyph.draw_polyline(points, color, stroke, true)
		"longshot":
			var tip := center + Vector2(5, 0) * scale_factor
			glyph.draw_line(center + Vector2(-5, 0) * scale_factor, tip, color, stroke, true)
			glyph.draw_line(center + Vector2(1, -4) * scale_factor, tip, color, stroke, true)
			glyph.draw_line(center + Vector2(1, 4) * scale_factor, tip, color, stroke, true)
		"splash":
			glyph.draw_circle(center + Vector2(-3, 1) * scale_factor, 2.4 * scale_factor, color, true, -1, true)
			glyph.draw_circle(center + Vector2(2, -4) * scale_factor, 1.6 * scale_factor, color, true, -1, true)
			glyph.draw_circle(center + Vector2(4, 2) * scale_factor, 1.5 * scale_factor, color, true, -1, true)
