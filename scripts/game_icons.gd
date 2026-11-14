extends RefCounted

const FAMILY_ICONS := {"bash": "push", "blink": "teleport", "shot": "shot", "guard": "guard", "slam": "area"}
const RELIC_ICONS := {
	"towline_knot": "pull", "bridgeplate": "guard", "brass_metronome": "review",
	"afterimage": "teleport", "barrage_rack": "shot", "siege_fuse": "area",
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
const RARITY_COLORS := {
	"common": Color("#acbac0"), "uncommon": Color("#8dd6b2"), "rare": Color("#8fbbff"),
	"epic": Color("#d3a4f1"), "legendary": Color("#ecc482")
}
const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]


static func tile(id: String, spec: Dictionary) -> String:
	return TILE_ICONS.get(id, FAMILY_ICONS.get(spec.get("family", id), "battle"))


static func relic(id: String) -> String:
	return RELIC_ICONS.get(id, "relic")


static func icon(key: String) -> Texture2D:
	var path := "res://assets/icons/%s.png" % key
	return load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else null


static func decorate(button: Button, key: String, size: int) -> void:
	button.icon = icon(key)
	button.add_theme_constant_override("icon_max_width", size)
	button.add_theme_constant_override("h_separation", 7)


static func portrait(class_id: String) -> String:
	return HERO_ART.get(class_id, "warden")


static func rarity(spec: Dictionary) -> Color:
	return RARITY_COLORS.get(spec.get("rarity", "common"), RARITY_COLORS.common)


static func tile_stats(spec: Dictionary) -> String:
	var stats := PackedStringArray(["%d beats" % int(spec.width)])
	if int(spec.get("damage", 0)) > 0:
		stats.append("%d damage" % int(spec.damage))
	return " · ".join(stats)


static func rarity_pips(spec: Dictionary) -> String:
	return "•".repeat(maxi(1, RARITIES.find(spec.get("rarity", "common")) + 1))
