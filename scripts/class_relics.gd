extends RefCounted

const WARDEN_GUARD := 4
const BULWARK_GUARD := 5
const BREAKER_COLLISION_DAMAGE := 3
const HEXWRIGHT_PULL_DAMAGE := 4
const WAYFARER_HIT_DAMAGE := 5
const LANCER_HIT_DAMAGE := 3
const LANCER_WAVE_DAMAGE := 5
const LANCER_WAVE_RADIUS := 96.0
const MOBILITY_BEATS := 3
const CANTOR_GUARD := 5
const APOTHECARY_HIT_DAMAGE := 5
const RUNE_SMITH_GUARD := 5
const STARSHOT_CRIT_DAMAGE := 6
const CINDER_BURN_DAMAGE := 2
const CINDER_SPARK_DAMAGE := 3
const CINDER_SPARK_RADIUS := 115.0
const DUELIST_HIT_DAMAGE := 5

const RELICS := {
	"warden_shield_rivet": {"hero": "warden", "label": "Shield Rivet", "icon": "guard",
		"description": "The first time your Guard absorbs enemy damage each loop, regain %d Guard." % WARDEN_GUARD},
	"bulwark_watch_badge": {"hero": "bulwark", "label": "Watch Badge", "icon": "guard-relay",
		"description": "The first time each loop you give an ally Guard with a tile or intercept an attack for them, give that ally %d extra Guard." % BULWARK_GUARD},
	"breaker_impact_pin": {"hero": "breaker", "label": "Impact Pin", "icon": "push",
		"description": "Your first tile push that moves an enemy each loop deals %d damage. If it knocks that foe into another enemy, the second enemy takes %d extra damage." % [BREAKER_COLLISION_DAMAGE, BREAKER_COLLISION_DAMAGE]},
	"hexwright_tow_hook": {"hero": "hexwright", "label": "Tow Hook", "icon": "pull",
		"description": "Your first pull that moves an enemy each loop deals %d extra damage to it." % HEXWRIGHT_PULL_DAMAGE},
	"wayfarer_glass_compass": {"hero": "wayfarer", "label": "Glass Compass", "icon": "teleport",
		"description": "Your first hit within %d beats of a successful teleport deals %d extra damage each loop." % [MOBILITY_BEATS, WAYFARER_HIT_DAMAGE]},
	"lancer_trail_spur": {"hero": "lancer", "label": "Trail Spur", "icon": "route",
		"description": "Your first hit within %d beats of a dash deals %d extra damage and %d damage to other enemies within %d, once each loop." % [MOBILITY_BEATS, LANCER_HIT_DAMAGE, LANCER_WAVE_DAMAGE, int(LANCER_WAVE_RADIUS)]},
	"cantor_echo_clasp": {"hero": "cantor", "label": "Echo Clasp", "icon": "review",
		"description": "The first ally to trigger your mark or echo each loop gains %d Guard." % CANTOR_GUARD},
	"apothecary_tonic_charm": {"hero": "apothecary", "label": "Tonic Charm", "icon": "rest",
		"description": "The first tile heal that restores HP each loop gives its recipient %d extra damage on their next hit." % APOTHECARY_HIT_DAMAGE},
	"rune_smith_seal": {"hero": "rune_smith", "label": "Etcher's Seal", "icon": "forge",
		"description": "Your first hit powered by your rune charge each loop gives you %d Guard." % RUNE_SMITH_GUARD},
	"starshot_sight_glass": {"hero": "starshot", "label": "Sight Glass", "icon": "shot",
		"description": "Your first ranged critical hit each loop deals %d extra damage." % STARSHOT_CRIT_DAMAGE},
	"cinder_mage_ember_locket": {"hero": "cinder_mage", "label": "Ember Locket", "icon": "area",
		"description": "Your first Burn tick each loop deals %d extra damage and sparks for %d damage to the nearest other enemy within %d." % [CINDER_BURN_DAMAGE, CINDER_SPARK_DAMAGE, int(CINDER_SPARK_RADIUS)]},
	"duelist_second_point": {"hero": "duelist", "label": "Second Point", "icon": "battle",
		"description": "Your first hit on the same target as your last landed tile each loop deals %d extra damage." % DUELIST_HIT_DAMAGE},
}


static func definition(id: String) -> Dictionary:
	return RELICS.get(id, {})


static func owner(id: String) -> String:
	return definition(id).get("hero", "")


static func id_for(hero_id: String) -> String:
	for id: String in RELICS:
		if RELICS[id].hero == hero_id:
			return id
	return ""
