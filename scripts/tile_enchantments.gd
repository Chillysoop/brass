extends RefCounted

const LEGACY_IDS := ["guarded", "longshot", "splash"]
const IDS := LEGACY_IDS + ["piercing", "embered", "mending"]
const GUARD_AMOUNT := 5
const RANGE_BONUS := 100.0
const SPLASH_RADIUS := 85.0
const SPLASH_RATIO := 0.35
const PIERCING_RATIO := 0.25
const EMBER_DAMAGE := 2
const EMBER_BEATS := 2
const MENDING_AMOUNT := 4

const ENCHANTMENTS := {
	"guarded": {"id": "guarded", "label": "Guarded",
		"description": "Gain %d Guard when this tile fires." % GUARD_AMOUNT},
	"longshot": {"id": "longshot", "label": "Longshot",
		"description": "Add %d reach to a ranged attack." % int(RANGE_BONUS)},
	"splash": {"id": "splash", "label": "Splash",
		"description": "When a single-target attack hits, deal %d%% of its base damage to one enemy within %d of the target." % [int(SPLASH_RATIO * 100), int(SPLASH_RADIUS)]},
	"piercing": {"id": "piercing", "label": "Piercing",
		"description": "%d%% of damage blocked by Guard also reaches the target's HP." % int(PIERCING_RATIO * 100)},
	"embered": {"id": "embered", "label": "Embered",
		"description": "The main hit applies Burn for %d damage each beat for %d beats." % [EMBER_DAMAGE, EMBER_BEATS]},
	"mending": {"id": "mending", "label": "Mending",
		"description": "Once per fight, when this tile restores HP, heal a different living hero for up to %d HP." % MENDING_AMOUNT},
}


static func info(id: String) -> Dictionary:
	return ENCHANTMENTS.get(id, {})


static func is_eligible(id: String, spec: Dictionary, tile_id := "") -> bool:
	if spec.is_empty():
		return false
	if id == "guarded":
		return true
	if id == "mending":
		return int(spec.get("heal", 0)) > 0
	if spec.get("damage", 0) <= 0:
		return false
	if id in ["piercing", "embered"]:
		return "nearest" in spec.get("targets", []) and (id != "embered" or not spec.has("ember_burn_damage"))
	if id == "longshot":
		return spec.get("ranged", false) or spec.get("family") == "shot" or tile_id in [
			"pull", "gravity_hook", "hook_bash", "graviton", "event_horizon", "meteor_seal",
			"ward_step", "mirror_step", "prism_stride", "sanctuary_gate",
		]
	if id == "splash":
		return not spec.has("radius") and not spec.has("splash") and not spec.has("ember_burn_radius") \
			and tile_id not in ["sunwall", "graviton", "dawn_bastion", "event_horizon", "meteor_seal"]
	return false


static func keep_if_eligible(item: Dictionary, spec: Dictionary) -> void:
	if item.has("enchantment") and not is_eligible(item.enchantment, spec, item.id):
		item.erase("enchantment")
