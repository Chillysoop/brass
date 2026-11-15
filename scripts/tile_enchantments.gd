extends RefCounted

const IDS := ["guarded", "longshot", "splash"]
const GUARD_AMOUNT := 5
const RANGE_BONUS := 100.0
const SPLASH_RADIUS := 85.0
const SPLASH_RATIO := 0.35

const ENCHANTMENTS := {
	"guarded": {"id": "guarded", "label": "Guarded", "icon": "guard",
		"description": "Gain %d Guard when this tile fires." % GUARD_AMOUNT},
	"longshot": {"id": "longshot", "label": "Longshot", "icon": "shot",
		"description": "Add %d reach to a ranged attack." % int(RANGE_BONUS)},
	"splash": {"id": "splash", "label": "Splash", "icon": "area",
		"description": "When a single-target attack hits, deal %d%% of its base damage to one enemy within %d of the target." % [int(SPLASH_RATIO * 100), int(SPLASH_RADIUS)]},
}


static func info(id: String) -> Dictionary:
	return ENCHANTMENTS.get(id, {})


static func is_eligible(id: String, spec: Dictionary, tile_id := "") -> bool:
	if spec.is_empty():
		return false
	if id == "guarded":
		return true
	if spec.get("damage", 0) <= 0:
		return false
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
