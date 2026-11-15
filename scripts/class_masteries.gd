extends RefCounted

const SPLASH_REACH := 110.0
const CLOSE_REACH := 125.0
const LONG_REACH := 200.0

const OPTIONS := {
	"warden": [
		{"id": "brace_and_strike", "label": "Brace and Strike", "trigger": "guarded_hit", "effect": "damage", "amount": 5, "icon": "battle",
			"description": "Your first tile hit while you have Guard each loop deals 5 extra damage."},
		{"id": "shield_escort", "label": "Shield Escort", "trigger": "guard_tile", "effect": "ally_guard", "amount": 4, "icon": "guard",
			"description": "The first tile that grants Guard each loop gives 4 extra Guard to your lowest-HP living ally, or to you when alone."},
	],
	"bulwark": [
		{"id": "hold_the_line", "label": "Hold the Line", "trigger": "guard_tile", "effect": "party_guard", "amount": 3, "icon": "guard",
			"description": "The first tile that grants Guard each loop gives 3 extra Guard to every living hero."},
		{"id": "spearhead", "label": "Spearhead", "trigger": "close_hit", "effect": "damage", "amount": 5, "icon": "battle",
			"description": "Your first tile hit within 125 range each loop deals 5 extra damage."},
	],
	"breaker": [
		{"id": "second_impact", "label": "Second Impact", "trigger": "push", "effect": "splash", "amount": 6, "icon": "area",
			"description": "Your first push each loop hits the nearest other enemy within 110 of the pushed target for 6 damage, if one is there."},
		{"id": "steel_toed", "label": "Steel-Toed", "trigger": "displaced_hit", "effect": "damage", "amount": 6, "icon": "battle",
			"description": "Your first tile hit on an enemy recently pushed or pulled each loop deals 6 extra damage."},
	],
	"hexwright": [
		{"id": "anchor_ward", "label": "Anchor Ward", "trigger": "pull", "effect": "guard", "amount": 5, "icon": "guard",
			"description": "Gain 5 Guard on your first successful pull each loop."},
		{"id": "shrapnel_tether", "label": "Shrapnel Tether", "trigger": "pull", "effect": "splash", "amount": 6, "icon": "area",
			"description": "Your first pull each loop hits the nearest other enemy within 110 of the pulled target for 6 damage, if one is there."},
	],
	"wayfarer": [
		{"id": "ghost_step", "label": "Ghost Step", "trigger": "teleport", "effect": "guard", "amount": 6, "icon": "guard",
			"description": "Gain 6 Guard on your first successful teleport each loop."},
		{"id": "blink_strike", "label": "Blink Strike", "trigger": "teleport_hit", "effect": "damage", "amount": 6, "icon": "teleport",
			"description": "Your first hit from a tile that just teleported you each loop deals 6 extra damage."},
	],
	"lancer": [
		{"id": "running_start", "label": "Running Start", "trigger": "momentum_hit", "effect": "damage", "amount": 5, "icon": "battle",
			"description": "The first hit that spends your movement charge each loop deals 5 extra damage."},
		{"id": "point_guard", "label": "Point Guard", "trigger": "close_hit", "effect": "guard", "amount": 5, "icon": "guard",
			"description": "Your first tile hit within 125 range each loop gives you 5 Guard."},
	],
	"cantor": [
		{"id": "refrain", "label": "Refrain", "trigger": "guard_tile", "effect": "ally_heal", "amount": 3, "icon": "rest",
			"description": "Once per loop, after a tile grants Guard, restore 3 HP to the living hero missing the most health."},
		{"id": "battle_hymn", "label": "Battle Hymn", "trigger": "marked_hit", "effect": "damage", "amount": 6, "icon": "battle",
			"description": "Your first tile hit on a marked enemy each loop deals 6 extra damage."},
	],
	"apothecary": [
		{"id": "refill", "label": "Refill", "trigger": "hit", "effect": "heal", "amount": 3, "icon": "rest",
			"description": "Your first tile hit each loop restores 3 extra HP to you. Excess healing becomes Guard."},
		{"id": "protective_dose", "label": "Protective Dose", "trigger": "hit", "effect": "ally_guard", "amount": 5, "icon": "guard",
			"description": "Your first tile hit each loop gives 5 Guard to your lowest-HP living ally, or to you when alone."},
	],
	"rune_smith": [
		{"id": "inscribed_plate", "label": "Inscribed Plate", "trigger": "wide_tile", "effect": "guard", "amount": 5, "icon": "guard",
			"description": "Gain 5 Guard when your first tile at least 3 beats wide finishes each loop."},
		{"id": "quick_stamp", "label": "Quick Stamp", "trigger": "quick_rune_hit", "effect": "damage", "amount": 6, "icon": "forge",
			"description": "Once per loop, a hit from a tile up to 2 beats wide deals 6 extra damage when it spends your rune charge."},
	],
	"starshot": [
		{"id": "surveyor", "label": "Surveyor", "trigger": "ranged_reach", "effect": "reach", "amount": 80, "icon": "shot",
			"description": "All your ranged attack tiles gain 80 reach."},
		{"id": "cover_fire", "label": "Cover Fire", "trigger": "distant_hit", "effect": "ally_guard", "amount": 5, "icon": "guard",
			"description": "Your first tile hit at more than 200 range each loop gives 5 Guard to your lowest-HP living ally, or to you when alone."},
	],
	"cinder_mage": [
		{"id": "kiln_blast", "label": "Kiln Blast", "trigger": "wide_hit", "effect": "splash", "amount": 5, "icon": "area",
			"description": "Your first hit from a tile at least 3 beats wide each loop hits the nearest other enemy within 110 of the target for 5 damage, if one is there."},
		{"id": "furnace_coat", "label": "Furnace Coat", "trigger": "displaced_hit", "effect": "guard", "amount": 5, "icon": "guard",
			"description": "Your first tile hit on an enemy recently pushed or pulled each loop gives you 5 Guard."},
	],
	"duelist": [
		{"id": "opening_feint", "label": "Opening Feint", "trigger": "new_target_hit", "effect": "guard", "amount": 5, "icon": "guard",
			"description": "Gain 5 Guard on your first tile hit against a new target each loop."},
		{"id": "final_flourish", "label": "Final Flourish", "trigger": "low_hp_hit", "effect": "damage", "amount": 6, "icon": "battle",
			"description": "Your first tile hit on an enemy at half health or less each loop deals 6 extra damage."},
	],
}


static func options(hero_id: String) -> Array:
	return OPTIONS.get(hero_id, [])


static func for_class(hero_id: String, id: String) -> Dictionary:
	for option: Dictionary in options(hero_id):
		if option.id == id:
			return option
	return {}


static func belongs_to(hero_id: String, id: String) -> bool:
	return not for_class(hero_id, id).is_empty()


static func info(id: String) -> Dictionary:
	for hero_id: String in OPTIONS:
		var option := for_class(hero_id, id)
		if not option.is_empty():
			return option
	return {}
