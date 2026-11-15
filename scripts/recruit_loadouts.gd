extends RefCounted

const ClassDecks = preload("res://scripts/class_decks.gd")

const OPTIONS := {
	"warden": {
		"assault": {"label": "Shield Strike", "description": "Build Guard, then knock the target back.", "companion": "bash"},
		"support": {"label": "Shield Escort", "description": "Cover the most injured hero and keep your own shield up.", "companion": "cover"},
	},
	"bulwark": {
		"assault": {"label": "Heavy Weapons", "description": "Reach with the pike and crush Guard with the maul.", "companion": "breaker_maul"},
		"support": {"label": "Shield Line", "description": "Give the party Guard before the pike strike.", "companion": "line_guard"},
	},
	"breaker": {
		"assault": {"label": "Battering Crew", "description": "Follow a heavy blow with a quick push.", "companion": "shove"},
		"support": {"label": "Shield and Maul", "description": "Strike to gain Guard before the heavy swing.", "companion": "shield_tap"},
	},
	"hexwright": {
		"assault": {"label": "Grapple and Blast", "description": "Pull an enemy into reach and fire into the cluster.", "companion": "shrapnel"},
		"support": {"label": "Guard the Line", "description": "Shield the party, then pull a target into reach.", "companion": "line_guard"},
	},
	"wayfarer": {
		"assault": {"label": "Backstab", "description": "Teleport into close range and finish wounded targets.", "companion": "finishing_cut"},
		"support": {"label": "Cover and Blink", "description": "Protect the most injured hero before teleporting.", "companion": "cover"},
	},
	"lancer": {
		"assault": {"label": "Countercharge", "description": "Fire on the retreat, then charge back into reach.", "companion": "spur"},
		"support": {"label": "Fighting Retreat", "description": "Gain Guard before firing and backing away.", "companion": "brace"},
	},
	"cantor": {
		"assault": {"label": "Signal and Volley", "description": "Mark a target and follow up with a ranged hit.", "companion": "shot"},
		"support": {"label": "Rallying Call", "description": "Share Guard and mark an enemy for the party.", "companion": "cover"},
	},
	"apothecary": {
		"assault": {"label": "Quick Cuts", "description": "Open with a quick shot and finish wounded enemies.", "companion": "finishing_cut"},
		"support": {"label": "Field Medic", "description": "Tend the most injured hero and keep firing.", "companion": "pilgrim_aid"},
	},
	"rune_smith": {
		"assault": {"label": "Charged Shot", "description": "Charge the follow-up shot with a wide slam.", "companion": "snap_shot"},
		"support": {"label": "Guard and Hammer", "description": "Build Guard before swinging at nearby enemies.", "companion": "guard"},
	},
	"starshot": {
		"assault": {"label": "Firing Line", "description": "Take two shots at range and punish enemy windups.", "companion": "shot"},
		"support": {"label": "Covering Fire", "description": "Protect the most injured hero, then fire at range.", "companion": "cover"},
	},
	"cinder_mage": {
		"assault": {"label": "Powder Kegs", "description": "Use two blasts to hit several enemies at once.", "companion": "furnace_burst"},
		"support": {"label": "Signal Fire", "description": "Mark a target so the next hit deals extra damage.", "companion": "signal_flare"},
	},
	"duelist": {
		"assault": {"label": "Quick Finish", "description": "Pressure one enemy with a jab and a finishing blow.", "companion": "finishing_cut"},
		"support": {"label": "Blade and Shield", "description": "Gain Guard on a hit, then follow with a quick jab.", "companion": "shield_tap"},
	},
}


static func choices(hero_id: String) -> Array:
	if not OPTIONS.has(hero_id):
		return []
	var options: Dictionary = OPTIONS[hero_id]
	var starter := ClassDecks.starter(hero_id)
	return [
		{"id": "assault", "label": options.assault.label, "description": options.assault.description,
			"tiles": [starter, options.assault.companion]},
		{"id": "support", "label": options.support.label, "description": options.support.description,
			"tiles": [options.support.companion, starter]},
	]
