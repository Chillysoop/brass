extends RefCounted

const ArenaSim = preload("res://scripts/arena_sim.gd")
const ArsenalTiles = preload("res://scripts/arsenal_tiles.gd")
const ClassDecks = preload("res://scripts/class_decks.gd")
const PilotFormations = preload("res://scripts/pilot_formations.gd")
const TileEnchantments = preload("res://scripts/tile_enchantments.gd")
const ClassMasteries = preload("res://scripts/class_masteries.gd")
const RecruitLoadouts = preload("res://scripts/recruit_loadouts.gd")
const ClassRelics = preload("res://scripts/class_relics.gd")
const TilePacking = preload("res://scripts/tile_packing.gd")
const UniversalTileUpgrades = preload("res://scripts/universal_tile_upgrades.gd")
const HEROES = ArenaSim.HERO_CLASSES
const STARTING_CLASSES := ["warden", "hexwright", "apothecary", "starshot", "duelist"]
const CLASS_UNLOCKS := {"bulwark": 6, "breaker": 6, "lancer": 8, "cantor": 8,
	"rune_smith": 10, "wayfarer": 10, "cinder_mage": 12}
const BASE_TILES := ["bash", "shot", "slam", "pull", "guard", "blink"]
const STARTER_RELICS := ["pocket_bell", "copper_compass", "quartermasters_coin"]
const BUILD_RELICS := ["towline_knot", "bridgeplate", "brass_metronome", "overflow_chalice", "stepped_gear", "mercy_seal"]
const ELITE_RELICS := ["afterimage", "barrage_rack", "siege_fuse", "switchback_lens", "longshot_prism", "twin_bell"]
const PARTY_ELITE_RELICS := ["twin_bell", "guard_relay", "flanking_standard"]
const BOSS_RELICS := {
	"tollkeeper": ["tollkeeper_signet", "bastion_medal", "guild_ledger", "tollkeeper_repair_kit"],
	"brass_bellmaker": ["bellmaker_clapper", "bellmaker_long_echo", "bellmaker_resonant_plate"],
}
const EARLY_BUILD_DIRECTIONS := {
	"warden": [
		{"label": "Guard and counter", "opening": "iron_arc", "followup": "iron_vow"},
		{"label": "Timed knockback", "opening": "bellows_strike", "followup": "shove"},
	],
	"hexwright": [
		{"label": "Cluster and splash", "opening": "shrapnel", "followup": "furnace_burst"},
		{"label": "Isolate and protect", "opening": "rake", "followup": "line_guard"},
	],
	"starshot": [
		{"label": "Long-range precision", "opening": "spark_shot", "followup": "signal_flare"},
		{"label": "Mobile fire", "opening": "retreat_shot", "followup": "tap_bolt"},
	],
}
const RELIC_STARTERS := {"towline_knot": "pull", "bridgeplate": "shield_ram"}
const FORGE_UNLOCKS := {"blink": "blink_artifice", "shot": "shot_artifice", "guard": "guard_artifice"}
const SHARED_RELICS := {
	"pocket_bell": {"label": "Pocket Bell", "description": "Gain guard at the start of each combat loop."},
	"copper_compass": {"label": "Copper Compass", "description": "Your first push each loop travels farther."},
	"quartermasters_coin": {"label": "Quartermaster's Coin", "description": "Gain 3 extra gold on the first skipped tile reward from each fight."},
	"trail_ration": {"label": "Trail Ration", "description": "Recover 5 HP after each victory."},
	"wayfarers_pin": {"label": "Wayfarer's Pin", "description": "Each hero gains 6 guard on their first successful teleport each loop."},
	"towline_knot": {"label": "Towline Knot", "description": "The first push or pull each loop marks its target. A separate tile that hits it within 2 beats deals 9 bonus damage."},
	"bridgeplate": {"label": "Bridgeplate", "description": "When a hero's Guard absorbs damage, their next tile hit that loop deals 8 bonus damage. Once per hero per loop."},
	"brass_metronome": {"label": "Brass Metronome", "description": "Leave an empty beat before a tile. Its hit deals 8 bonus damage. Once per loop."},
	"afterimage": {"label": "Afterimage", "description": "After a successful Blink, your next damaging tile without movement can strike from where you blinked away."},
	"barrage_rack": {"label": "Barrage Rack", "description": "Pair hits from separate tiles 2 beats wide or less. Hit the same enemy within 2 beats to strip up to 8 Guard before the second hit."},
	"siege_fuse": {"label": "Siege Fuse", "description": "Once per loop, your first landed attack at least 4 beats wide pulls nearby enemies toward its target before impact."},
	"overflow_chalice": {"label": "Overflow Chalice", "description": "When a tile would raise Guard above 28, the living hero missing the most HP heals for the excess. Up to 6 HP per loop."},
	"stepped_gear": {"label": "Stepped Gear", "description": "Put a 1–2 beat attack directly after a 3+ beat tile in the same loop. The first such hit deals +7 damage each loop."},
	"mercy_seal": {"label": "Mercy Seal", "description": "A direct tile hit on a foe already at 25% HP or less grants the attacker up to 6 Guard. Once per loop while below the Guard cap."},
	"switchback_lens": {"label": "Switchback Lens", "description": "Hit a different main target with your next landed attack tile for +10 damage. Once per hero per loop."},
	"longshot_prism": {"label": "Longshot Prism", "description": "The first direct tile hit from 180 units away or farther deals +11 damage each loop."},
	"twin_bell": {"label": "Twin Bell", "description": "Two heroes hit the same foe on the same beat. The second hit deals +12 damage once per loop."},
	"guard_relay": {"label": "Guard Relay", "description": "Once per loop, when a hero's tile gives an ally Guard, both gain 4 more."},
	"flanking_standard": {"label": "Flanking Standard", "description": "Two heroes hit the same foe from opposite sides within 2 beats. The second hit deals +10 damage once per loop."},
	"tollkeeper_signet": {"label": "Tollkeeper's Signet", "description": "Damage tiles that finish on beats 1–4 deal +3 damage."},
	"bastion_medal": {"label": "Bastion Medal", "description": "When a tile fires and grants Guard, it grants 3 extra Guard to each recipient."},
	"guild_ledger": {"label": "Guild Ledger", "description": "Shops stock one extra tile from each hero's class deck."},
	"tollkeeper_repair_kit": {"label": "Tollkeeper's Repair Kit", "description": "Once each loop, each hero heals 3 HP the first time they fully block an enemy hit."},
	"bellmaker_clapper": {"label": "Bellmaker's Clapper", "description": "Once per hero each loop, a support tile sends a shockwave for 8 damage to each enemy within 110."},
	"bellmaker_long_echo": {"label": "Long Echo", "description": "Each hero's first ranged hit per loop deals 4 extra damage."},
	"bellmaker_resonant_plate": {"label": "Resonant Plate", "description": "Each hero gains 4 Guard when their first tile at least 3 beats wide finishes each loop."},
}
static var RELICS: Dictionary = SHARED_RELICS.merged(ClassRelics.RELICS)
const META_NODES := {
	"stout_start": {"label": "Stout Start", "description": "Begin each run with 8% more maximum HP.", "cost": 5, "requires": []},
	"purse": {"label": "Well-stocked Purse", "description": "Begin each run with 8 extra gold.", "cost": 5, "requires": []},
	"curated_cache": {"label": "Gravity Hook", "description": "Permanently add Gravity Hook to normal drafts and shops.", "cost": 8, "requires": ["stout_start"]},
	"relic_archive": {"label": "Relic Archive", "description": "Permanently add Trail Ration to the starter relic draft.", "cost": 8, "requires": ["purse"]},
	"blink_artifice": {"label": "Blink Artifice", "description": "Upgrade a single Blink tile at camp and find Blink upgrades in rewards and shops.", "cost": 18, "requires": ["curated_cache"]},
	"wayfarers_pin": {"label": "Wayfarer's Pin", "description": "Add Wayfarer's Pin to future relic drafts, shops and elite rewards. Each hero gains 6 guard on their first successful teleport each loop.", "cost": 14, "requires": ["blink_artifice"]},
	"shot_artifice": {"label": "Marksman's Arsenal", "description": "Upgrade a single Shot tile at camp and find Shot upgrades in rewards and shops.", "cost": 14, "requires": ["purse"]},
	"guard_artifice": {"label": "Bastion Workshop", "description": "Upgrade a single Guard tile at camp and find Guard upgrades in rewards and shops.", "cost": 14, "requires": ["stout_start"]},
	"navigation": {"label": "Pathfinder's Chart", "description": "Find wagers, relic brokers, and optional elite bounties at mystery nodes.", "cost": 12, "requires": ["purse"]},
	"enchantments": {"label": "Tile Enchantments", "description": "Draft movable enchantments after the Brass Frontier opening and after recruitment.", "cost": 8, "requires": ["curated_cache"]},
}
const ENCHANTMENT_DRAFTS := ["opening", "recruit"]
const TILE_RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]
const NODE_LABELS := {
	"battle": ["Dust Patrol", "Gate Watch", "Scrap Brigade", "Piston Guard", "Wall Patrol", "Relay Duel"],
	"elite": ["Brass Vanguard", "The Tempered Guard"],
	"shop": ["Relay Market", "Roadside Quartermaster"],
	"event": ["Jammed Crane", "Loaded Beacon", "Relay Auction"],
	"rest": ["Lantern Camp", "Ember Post"],
}
const GLASS_NODE_LABELS := {
	"battle": ["Furnace Watch", "Cinder Alley", "Kiln Patrol", "Shard Pickets", "Soot Stalkers", "Glassway Ambush"],
	"elite": ["Crucible Guard", "Kiln Wardens"],
	"shop": ["Bellows Market", "Glasswright's Cart"],
	"event": ["Cracked Mold", "Smelter Relay", "Cinder Exchange"],
	"rest": ["Cooling Gallery", "Ash Shelter"],
}
const GLASS_UPPER_NODE_LABELS := {
	"battle": ["Annealing Walk", "Mirror Kiln", "Furnace Overlook", "Polished Barricade", "Silica Garrison"],
	"elite": ["Prism Sentinels", "Mirror Wardens"],
	"shop": ["Cutters' Bazaar", "Lenswright's Cart"],
	"event": ["Steam Infirmary", "Lenswright's Bench", "Prism Cache"],
	"rest": ["Tempering Refuge", "Coolant Cistern"],
}
const GLASS_TEMPERING_NODE_LABELS := {
	"battle": ["Fused Walkway", "Basalt Crucible", "Stress Gallery", "Quench Works", "Glaze Gantry"],
	"elite": ["Obsidian Wardens", "Temper Guard"],
	"shop": ["Frit Exchange", "Crucible Quartermaster"],
	"rest": ["Quench Chamber", "Blackglass Shelter"],
}
const CROWN_NODE_LABELS := {
	"battle": ["Signal Bridge", "Pennant Walk", "Bellspire Steps", "Skyward Patrol", "Relay Rampart", "Banner Watch"],
	"elite": ["Royal Signal Guard", "Spire Wardens"],
	"shop": ["Windlass Market", "Bannerwright's Stall"],
	"event": ["Beacon Intercept", "Signal Cache", "Signal Scriptorium"],
	"rest": ["Signalkeeper's Loft", "Cloudbreak Lookout"],
}
const CROWN_HIGH_RELAY_NODE_LABELS := {
	"battle": ["Spire Causeway", "Cable Gallery", "Stormline Walk", "Semaphore Terrace", "Crown Signal Array"],
	"elite": ["High Relay Watch", "The Royal Signal Corps"],
	"shop": ["Liftmaster's Supply", "Semaphore Exchange"],
	"event": ["Signalman's Infirmary", "Lost Dispatch", "Storm Cache"],
	"rest": ["Windbreak Station", "Upper Beacon Shelter"],
}
const CROWN_REGENT_NODE_LABELS := {
	"battle": ["Oathwalk", "Windcutter Span", "Crown Bastion", "Guardspire Steps", "Bell Tower Approach"],
	"elite": ["Regent's Honor Guard", "Crown Vanguard"],
	"shop": ["Standard-Bearer's Supply", "Aerie Exchange"],
	"rest": ["Lantern Eyrie", "Regent's Terrace"],
}
const MOONWRECK_NODE_LABELS := {
	"battle": ["Floodwalk", "Wreck Gantries", "Bilgeway", "Sunk Parade", "Crane Deck", "Riptide Crossing"],
	"elite": ["Tide Wardens", "Keelbreaker Crew"],
	"shop": ["Lantern Chandlery", "Salvager's Cart"],
	"event": ["Tethered Barge", "Rusted Foghorn", "Diver's Exchange"],
	"rest": ["Ropewalk Refuge", "Netmaker's Berth"],
}
const MOONWRECK_BREAKWATER_NODE_LABELS := {
	"battle": ["Outer Pylons", "Keel Channel", "Sea Wall Traverse", "Saltworks Pier", "Foghorn Deck"],
	"elite": ["Breakwater Sentinels", "Blackwake Crew"],
	"shop": ["Pilot's Supply", "Saltwater Exchange"],
	"event": ["Lifeboat Clinic", "Pearl Diver's Bench", "Storm-Tossed Crate"],
	"rest": ["Dry Berth", "Lantern Platform"],
}
const MOONWRECK_BLACKWATER_NODE_LABELS := {
	"battle": ["Deadlight Deck", "Bilge Locks", "Sundered Gunwale", "Blackwater Moorings", "Flooded Battery"],
	"elite": ["Admiral's Boarders", "Keelwatch"],
	"shop": ["Lantern Tender", "Wreckwright's Stores"],
	"rest": ["Bulkhead Shelter", "Stillwater Berth"],
}
const EVENT_KINDS := {
	"Jammed Crane": "salvage", "Loaded Beacon": "ambush", "Relay Auction": "trade",
	"Cracked Mold": "salvage", "Smelter Relay": "ambush", "Cinder Exchange": "trade",
	"Steam Infirmary": "infirmary", "Lenswright's Bench": "lenswright", "Prism Cache": "prism_cache",
	"Beacon Intercept": "ambush", "Signal Cache": "signal_cache", "Signal Scriptorium": "trade",
	"Signalman's Infirmary": "infirmary", "Lost Dispatch": "lenswright", "Storm Cache": "prism_cache",
	"Tethered Barge": "barge", "Rusted Foghorn": "ambush", "Diver's Exchange": "trade",
	"Lifeboat Clinic": "infirmary", "Pearl Diver's Bench": "lenswright", "Storm-Tossed Crate": "prism_cache",
	"Broker's Table": "wager", "Salvage Permit": "permit", "Bounty Board": "bounty",
}
const BUILD_MYSTERIES := {
	"Salvage Bench": "salvage_bench", "Traveling Smith": "traveling_smith", "Class Cache": "class_cache",
}
const CACHE_CATEGORIES := {
	"damage": {"label": "Damage", "description": "Strike or shoot an enemy."},
	"support": {"label": "Guard and healing", "description": "Grant Guard or restore HP."},
	"movement": {"label": "Movement", "description": "Move your hero or displace an enemy."},
}
const NAVIGATION_EVENTS := ["Broker's Table", "Salvage Permit", "Bounty Board"]
const LOCATION_LABELS := {"brass": "Brass Frontier", "glass": "Glass Foundry", "crown": "Crown Relay", "moonwreck": "Moonwreck Docks"}
const BOSS_LABELS := {
	"tollkeeper": "The Tollkeeper", "gilded_marshal": "The Gilded Marshal",
	"brass_bellmaker": "The Bellmaker", "brass_repairmaster": "The Repairmaster",
	"iron_regent": "The Iron Regent", "crucible_twins": "The Crucible Twins", "prism_warden": "The Prism Warden",
	"glass_refraction_engine": "The Refraction Engine",
	"tempered_colossus": "The Tempered Colossus",
	"relay_captain": "The Relay Captain", "relay_marshal": "The Relay Marshal", "crown_regent": "The Crown Regent",
	"wreckmaster": "The Wreckmaster", "tidekeeper": "The Tidekeeper", "drowned_admiral": "The Drowned Admiral",
}
const TOLLKEEPER_VARIANTS := {
	"solo": {"title": "The Tollkeeper", "description": "The Tollkeeper fights alone. Its strikes get stronger when it rallies at half health."},
	"repair_drone": {"title": "The Tollkeeper + Repair Drone", "description": "The drone repairs the Tollkeeper from nearby. Separate them, interrupt the drone during a repair, or destroy it."},
}
const BELLMAKER_SCOUT := "Alternates a close bell shockwave and a long shot at the marked spot. Push it away to escape the ring, move off the mark, or time Guard."
const GLASS_BOSS_SCOUTS := {
	"crucible_twins": "Two attackers fight together. Use concentrated fire to take one out early, or place area attacks to catch both.",
	"glass_refraction_engine": "The Engine locks a beam onto a marked line. Displace it during the windup, move off the line, or time Guard. Stay at range to avoid its close discharge.",
}
const BRASS_BOSSES := ["tollkeeper", "gilded_marshal", "iron_regent"]
const BRASS_ACT_TWO_BOSSES := ["gilded_marshal", "brass_repairmaster"]
const GLASS_BOSSES := ["crucible_twins", "prism_warden", "tempered_colossus"]
const CROWN_BOSSES := ["relay_captain", "relay_marshal", "crown_regent"]
const MOONWRECK_BOSSES := ["wreckmaster", "tidekeeper", "drowned_admiral"]
const SEGMENT_COUNTS := {"easy": 1, "medium": 2, "hard": 3}
const DEFAULT_PROFILE := {
	"timeline_intro_seen": false,
	"marks": 0, "medium_unlocked": false, "hard_unlocked": false, "glass_easy_unlocked": false,
	"brass_hard_cleared": false, "glass_medium_unlocked": false, "glass_hard_unlocked": false,
	"glass_hard_cleared": false, "crown_easy_unlocked": false, "crown_medium_unlocked": false,
	"crown_hard_unlocked": false, "crown_hard_cleared": false,
	"moonwreck_easy_unlocked": false, "moonwreck_medium_unlocked": false,
	"moonwreck_hard_unlocked": false, "moonwreck_hard_cleared": false, "meta": [], "mastered_classes": [],
}
const NODES_PER_SEGMENT := 7
const VERSION := 1
const SAVE_SLOT_COUNT := 3
const SLOT_INDEX_FILE := "frontier-slots.cfg"
const SAVE_PHASES := ["hero", "relic", "starter", "recruit", "recruit_starter", "map", "combat", "reward",
	"boss_relic", "enchantment", "shop", "event", "rest", "result"]

var data: Dictionary = {}
var loadout: Dictionary = {}
var profile: Dictionary = DEFAULT_PROFILE.duplicate(true)
var save_path := "user://frontier-save.json"
var save_error := ""
var recovered_starter := ""
var active_save_slot := 1
var _slot_directory := "user://"
var _slot_revisions: Array[int] = [0, 0, 0]


func load_active_save_slot(directory := "user://") -> bool:
	_slot_directory = directory
	active_save_slot = 1
	_slot_revisions.fill(0)
	var index_path := _slot_directory.path_join(SLOT_INDEX_FILE)
	for path: String in [index_path, index_path + ".bak"]:
		var settings := ConfigFile.new()
		if settings.load(path) != OK:
			continue
		var current: Variant = settings.get_value("slots", "active", 1)
		var revisions: Variant = settings.get_value("slots", "revisions", [])
		if not current is int or not _valid_slot(current) or not revisions is Array or revisions.size() != SAVE_SLOT_COUNT:
			continue
		if not revisions.all(func(value: Variant): return value is int and value >= 0):
			continue
		active_save_slot = current
		_slot_revisions.assign(revisions)
		break
	return load_save(_slot_path(active_save_slot, _slot_revisions[active_save_slot - 1]))


func save_slot_summary(slot: int) -> Dictionary:
	if not _valid_slot(slot):
		return {}
	var path := _slot_path(slot, _slot_revisions[slot - 1])
	var record := _read_save(path)
	if record.is_empty():
		record = _read_save(path + ".bak")
	if record.is_empty():
		return {"occupied": FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"), "readable": false}
	var saved_run: Dictionary = record.run
	var saved_profile: Dictionary = record.profile
	return {"occupied": true, "readable": true, "phase": saved_run.get("phase", ""),
		"location": saved_run.get("location", "brass"), "difficulty": saved_run.get("difficulty", "easy"),
		"hero": saved_run.get("hero", ""), "marks": int(saved_profile.get("marks", 0)),
		"unlock_count": saved_profile.get("meta", []).size()}


func select_save_slot(slot: int) -> bool:
	if not _valid_slot(slot):
		return false
	if slot == active_save_slot and save_path == _slot_path(slot, _slot_revisions[slot - 1]):
		return true
	if not _publish_slot_index(slot, _slot_revisions):
		return false
	active_save_slot = slot
	load_save(_slot_path(slot, _slot_revisions[slot - 1]))
	return true


func start_new_game_in_slot(slot: int, replace_existing := false, seed_value := 0) -> bool:
	if not _valid_slot(slot) or (save_slot_summary(slot).occupied and not replace_existing):
		return false
	var revisions := _slot_revisions.duplicate()
	var previous_slot_path := _slot_path(slot, revisions[slot - 1])
	# Stage the fresh run under a distinct revision so its backup can never restore the prior profile.
	revisions[slot - 1] += 1
	var previous_path := save_path
	var previous_run := data
	var previous_inventory := loadout
	var previous_profile := profile
	var previous_recovery := recovered_starter
	save_path = _slot_path(slot, revisions[slot - 1])
	data = {}
	loadout = {}
	profile = DEFAULT_PROFILE.duplicate(true)
	recovered_starter = ""
	var staged := start_run(seed_value)
	if not staged or not _publish_slot_index(slot, revisions, previous_slot_path):
		if staged:
			_remove_slot_revision(save_path)
		save_path = previous_path
		data = previous_run
		loadout = previous_inventory
		profile = previous_profile
		recovered_starter = previous_recovery
		return false
	_slot_revisions = revisions
	active_save_slot = slot
	return true


func _valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SAVE_SLOT_COUNT


func _slot_path(slot: int, revision: int) -> String:
	var stem := "frontier-save" if slot == 1 else "frontier-save-%d" % slot
	if revision > 0:
		stem += "-revision-%d" % revision
	return _slot_directory.path_join(stem + ".json")


func _publish_slot_index(slot: int, revisions: Array[int], obsolete_path := "") -> bool:
	var settings := ConfigFile.new()
	settings.set_value("slots", "active", slot)
	settings.set_value("slots", "revisions", revisions)
	var path := _slot_directory.path_join(SLOT_INDEX_FILE)
	if not _write_slot_index(settings, path):
		save_error = "Could not update the save slots."
		return false
	# Reclaim the prior revision once neither index points to it.
	if _write_slot_index(settings, path + ".bak") and not obsolete_path.is_empty():
		_remove_slot_revision(obsolete_path)
	return true


func _write_slot_index(settings: ConfigFile, path: String) -> bool:
	var staging := path + ".tmp"
	return settings.save(staging) == OK and DirAccess.rename_absolute(ProjectSettings.globalize_path(staging),
		ProjectSettings.globalize_path(path)) == OK


func _remove_slot_revision(path: String) -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func load_save(path := "user://frontier-save.json") -> bool:
	save_path = path
	save_error = ""
	recovered_starter = ""
	data = {}
	loadout = {}
	profile = DEFAULT_PROFILE.duplicate(true)
	for candidate in [save_path, save_path + ".bak"]:
		var parsed := _read_save(candidate)
		if parsed.is_empty():
			continue
		profile.merge(parsed.profile, true)
		data = parsed.run
		loadout = parsed.loadout
		_restore_integers()
		_restore_empty_run_loadout()
		_restore_brass_medium_unlocks(candidate == save_path)
		return true
	return false


func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var parsed: Variant = json.get_data()
	if not parsed is Dictionary or parsed.get("version") != VERSION:
		return {}
	if not parsed.get("profile") is Dictionary or not parsed.get("run") is Dictionary or not parsed.get("loadout") is Dictionary:
		return {}
	if not _valid_save_profile(parsed.profile) or not _valid_save_run(parsed.run, parsed.loadout):
		return {}
	return parsed


func _valid_save_profile(record: Dictionary) -> bool:
	for field: String in DEFAULT_PROFILE:
		if field == "marks":
			if not _save_integer(record.get(field, 0)):
				return false
		elif typeof(record.get(field, DEFAULT_PROFILE[field])) != typeof(DEFAULT_PROFILE[field]):
			return false
	return true


func _valid_save_run(record: Dictionary, inventory: Dictionary) -> bool:
	if record.is_empty():
		return true
	var phase: Variant = record.get("phase")
	if phase not in SAVE_PHASES or not record.get("hero") is String \
		or not record.get("midpoint_paid") is bool:
		return false
	match phase:
		"recruit_starter":
			if not HEROES.has(record.get("pending_recruit")):
				return false
			if record.has("recruit_kits"):
				var kits: Variant = record.recruit_kits
				if record.get("recruit_loadouts") != true or not _valid_id_list(kits, _recruit_kit_ids(record.pending_recruit), 2) \
						or kits.size() != 2:
					return false
		"shop":
			var stock: Variant = record.get("shop_stock", record.get("offers"))
			if not record.get("shop_healed") is bool or not stock is Array:
				return false
			if not stock.all(func(id: Variant) -> bool: return id is String and ArenaSim.TILES.has(id)):
				return false
			if record.has("shop_deck_offer") and record.shop_deck_offer not in stock:
				return false
		"result":
			if record.get("result") not in ["victory", "defeat"]:
				return false
	for field: String in ["seed", "hp", "max_hp", "gold", "marks_earned"]:
		if not _save_integer(record.get(field)):
			return false
	for field: String in ["layers", "visited", "relics", "offers"]:
		if not record.get(field) is Array:
			return false
	if not _valid_id_list(record.get("enchantments", []), TileEnchantments.IDS, 2) \
			or not _valid_id_list(record.get("enchantment_drafts", []), ENCHANTMENT_DRAFTS, 2):
		return false
	if phase == "enchantment" and not _valid_id_list(record.offers, TileEnchantments.IDS, 3):
		return false
	if record.layers.is_empty() or not _valid_save_node(record.get("node")):
		return false
	for layer: Variant in record.layers:
		if not layer is Array or layer.is_empty():
			return false
		for node: Variant in layer:
			if not _valid_save_node(node):
				return false
	var heroes: Variant = record.get("heroes", [])
	if not heroes is Array:
		return false
	for hero: Variant in heroes:
		if not hero is Dictionary or not HEROES.has(hero.get("id")) \
			or not _save_integer(hero.get("hp")) or not _save_integer(hero.get("max_hp")):
			return false
	return _valid_save_inventory(inventory)


func _valid_id_list(value: Variant, choices: Array, limit: int) -> bool:
	return value is Array and value.size() <= limit and value.all(func(id: Variant) -> bool:
		return id is String and id in choices and value.count(id) == 1)


func _valid_save_node(node: Variant) -> bool:
	if not node is Dictionary or not node.get("id") is String or not node.get("type") is String \
		or not node.get("label") is String or not node.get("next") is Array \
		or not _save_integer(node.get("row")) or not _save_integer(node.get("column")):
		return false
	var formation: Variant = node.get("pilot_formation", [])
	if not formation is Array:
		return false
	return formation.all(func(spawn: Variant) -> bool: return spawn is Dictionary and _save_integer(spawn.get("delay")))


func _valid_save_inventory(inventory: Dictionary) -> bool:
	if not inventory.get("lanes") is Array or inventory.lanes.is_empty() or not inventory.get("storage") is Array \
		or not inventory.get("defaults") is Array or not inventory.get("suppressed") is Dictionary:
		return false
	for row: Variant in inventory.lanes + inventory.storage:
		if not row is Array:
			return false
		for tile: Variant in row:
			if not tile is Dictionary or not ArenaSim.TILES.has(tile.get("id")) or not tile.get("target") is String \
				or not _save_integer(tile.get("start")):
				return false
	return true


func _save_integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floorf(value))


func _restore_brass_medium_unlocks(from_primary: bool) -> void:
	var completed := bool(profile.hard_unlocked or profile.glass_easy_unlocked or profile.brass_hard_cleared)
	completed = completed or _is_brass_medium_victory(data)
	if not completed and from_primary and data.is_empty():
		# Returning to title after a recap keeps that finished run in the previous snapshot.
		var previous := _read_save(save_path + ".bak")
		completed = _is_brass_medium_victory(previous.get("run", {}))
	if completed:
		profile.medium_unlocked = true
		profile.hard_unlocked = true
		profile.glass_easy_unlocked = true


func _is_brass_medium_victory(record: Dictionary) -> bool:
	if record.get("location") != "brass" or record.get("difficulty") != "medium" or record.get("result") != "victory":
		return false
	var node: Variant = record.get("node")
	var layers: Variant = record.get("layers")
	return (node is Dictionary and layers is Array and not layers.is_empty()
		and node.get("type") == "boss" and node.get("boss_id") in BRASS_ACT_TWO_BOSSES
		and node.get("row") == layers.size() - 1)


func save() -> bool:
	var pending := save_path + ".tmp"
	var file := FileAccess.open(pending, FileAccess.WRITE)
	if file == null:
		save_error = "Could not write the Frontier save."
		return false
	file.store_string(JSON.stringify({"version": VERSION, "profile": profile, "run": data, "loadout": loadout}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		save_error = "Could not finish writing the Frontier save."
		return false
	var original := ProjectSettings.globalize_path(save_path)
	var backup := original + ".bak"
	# A broken primary must never replace the checkpoint we recovered from.
	var rotate_primary := not _read_save(save_path).is_empty()
	if rotate_primary:
		if DirAccess.rename_absolute(original, backup) != OK:
			save_error = "Could not back up the Frontier save."
			return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(pending), original) != OK:
		if rotate_primary:
			DirAccess.copy_absolute(backup, original)
		save_error = "Could not install the Frontier save."
		return false
	save_error = ""
	recovered_starter = ""
	return true


func start_run(seed_value := 0, difficulty := "easy", location := "brass") -> bool:
	if not data.is_empty() or not can_start(difficulty, location):
		return false
	var before := data
	var before_loadout := loadout
	# JSON preserves these 32-bit seeds exactly.
	var run_seed := clampi(seed_value, 1, 4294967295) if seed_value != 0 else maxi(1, int(randi()))
	var layers := _make_map(run_seed, difficulty, location)
	var hp := 100 + (8 if "stout_start" in profile.meta else 0)
	var gold := 12 + (8 if "purse" in profile.meta else 0)
	data = {
		"phase": "hero", "seed": run_seed, "difficulty": difficulty, "location": location, "segment": 1,
		"hero": "", "heroes": [], "relics": [], "hp": hp, "max_hp": hp,
		"gold": gold, "layers": layers, "node": layers[0][0], "visited": [layers[0][0].id],
		"offers": _sample(available_classes(), 3, run_seed, 11), "result": "", "marks_earned": 0,
		"midpoint_paid": false, "elite_relic_drafted": false, "node_notice": "",
		"pilot_fights": [], "encounter_roster_version": PilotFormations.CURRENT_VERSION,
	}
	loadout = {"lanes": [[]], "storage": [[], [], []], "defaults": ["nearest"], "suppressed": {}}
	return _save_run_change(before, {}, before_loadout)


func can_start(difficulty: String, location := "brass") -> bool:
	if location == "moonwreck":
		match difficulty:
			"easy": return profile.moonwreck_easy_unlocked
			"medium": return profile.moonwreck_medium_unlocked
			"hard": return profile.moonwreck_hard_unlocked
		return false
	if location == "crown":
		match difficulty:
			"easy": return profile.crown_easy_unlocked
			"medium": return profile.crown_medium_unlocked
			"hard": return profile.crown_hard_unlocked
		return false
	if location == "glass":
		match difficulty:
			"easy": return profile.glass_easy_unlocked
			"medium": return profile.glass_medium_unlocked
			"hard": return profile.glass_hard_unlocked
		return false
	if location != "brass":
		return false
	match difficulty:
		"easy": return true
		"medium": return profile.medium_unlocked
		"hard": return profile.hard_unlocked
	return false


func choose_hero(id: String) -> bool:
	if data.get("phase") == "recruit":
		return choose_recruit(id)
	if not _is_offer("hero", id) or not HEROES.has(id):
		return false
	return _choose_starting_class(id)


func can_choose_starter() -> bool:
	return profile.medium_unlocked


func choose_preferred_hero(id: String) -> bool:
	if data.get("phase") != "hero" or not can_choose_starter() or id not in available_classes():
		return false
	return _choose_starting_class(id)


func _choose_starting_class(id: String) -> bool:
	var before := data.duplicate(true)
	data.hero = id
	data.heroes.append({"id": id, "hp": data.hp, "max_hp": data.max_hp})
	data.phase = "relic"
	var pool := _classic_relics()
	var offer_pin := pool.has("wayfarers_pin")
	pool.erase("wayfarers_pin")
	data.offers = _sample(pool, 3, int(data.seed), 21)
	if offer_pin:
		data.offers.append("wayfarers_pin")
	var combat_classics := ["pocket_bell", "copper_compass"]
	if offer_pin:
		combat_classics.append("wayfarers_pin")
	var combat_draft := _sample(BUILD_RELICS, 2, int(data.seed), 22) + _sample(combat_classics, 1, int(data.seed), 23)
	data.build_relic_offers = _sample(combat_draft, 3, int(data.seed), 24)
	return _save_run_change(before)


func build_relic_offers() -> Array:
	return data.get("build_relic_offers", []) if data.get("phase") == "relic" else []


func mastery_offers() -> Array:
	var phase: String = data.get("phase", "")
	if phase not in ["relic", "starter", "recruit_starter"]:
		return []
	var class_id: String = data.get("pending_recruit", "") if phase == "recruit_starter" else data.hero
	return ClassMasteries.options(class_id) if class_id in profile.mastered_classes else []


func selected_mastery() -> String:
	if data.get("phase") == "recruit_starter":
		return data.get("pending_recruit_mastery", "")
	var heroes: Array = data.get("heroes", [])
	return "" if heroes.is_empty() else heroes[0].get("mastery", "")


func choose_mastery(id: String) -> bool:
	var offers := mastery_offers()
	if offers.is_empty() or (not id.is_empty() and not offers.any(func(offer: Dictionary): return offer.id == id)):
		return false
	var before := data.duplicate(true)
	if data.phase == "recruit_starter":
		data.pending_recruit_mastery = id
	else:
		data.heroes[0].mastery = id
	return _save_run_change(before)


func choose_relic(id: String) -> bool:
	if not _is_offer("relic", id) and id not in build_relic_offers():
		return false
	var before := data.duplicate(true)
	data.relics.append(id)
	data.phase = "starter"
	data.erase("build_relic_offers")
	data.offers = _starter_offers(data.hero, 31, RELIC_STARTERS.get(id, "shot"))
	return _save_run_change(before)


func choose_starter(id: String) -> bool:
	if data.get("phase") == "recruit_starter":
		return choose_recruit_starter(id)
	if not _is_offer("starter", id):
		return false
	var before := data.duplicate(true)
	var before_loadout := loadout.duplicate(true)
	loadout.lanes = [_starter_lane(id)]
	if data.location == "brass" and data.difficulty in ["medium", "hard"] and id in ClassDecks.alternate_starters(data.hero):
		data["rotating_lead_start"] = true
	if "brass_metronome" in data.relics:
		loadout.lanes[0][0].start = 1
	data.phase = "combat"
	_lock_pilot_formation()
	data.offers = []
	return _save_run_change(before, {}, before_loadout)


func choose_recruit(id: String) -> bool:
	if not _is_offer("recruit", id):
		return false
	var before := data.duplicate(true)
	data.pending_recruit = id
	data.phase = "recruit_starter"
	data.recruit_loadouts = true
	data.recruit_kits = _sample(_recruit_kit_ids(id), 2, int(data.seed), _node_salt(211 + HEROES.keys().find(id)))
	data.offers = _starter_offers(id, _node_salt(93))
	return _save_run_change(before)


func choose_recruit_starter(id: String) -> bool:
	if not _is_offer("recruit_starter", id):
		return false
	return _equip_recruit([id])


func recruit_loadout_offers() -> Array:
	if data.get("phase") != "recruit_starter" or not data.get("recruit_loadouts", false):
		return []
	var kits := {}
	for kit: Dictionary in RecruitLoadouts.choices(data.pending_recruit):
		kits[kit.id] = kit
	var ids: Array = data.get("recruit_kits", ["assault", "support"])
	return ids.map(func(id: String): return kits[id])


func _recruit_kit_ids(hero_id: String) -> Array:
	return RecruitLoadouts.choices(hero_id).map(func(kit: Dictionary): return kit.id)


func choose_recruit_loadout(id: String) -> bool:
	for offer: Dictionary in recruit_loadout_offers():
		if offer.id == id:
			return _equip_recruit(offer.tiles)
	return false


func _equip_recruit(tiles: Array) -> bool:
	var max_hp: int = data.max_hp
	var recruit: String = data.pending_recruit
	var before := data.duplicate(true)
	var before_loadout := loadout.duplicate(true)
	var member := {"id": recruit, "hp": max_hp, "max_hp": max_hp}
	if not str(data.get("pending_recruit_mastery", "")).is_empty():
		member.mastery = data.pending_recruit_mastery
	data.heroes.append(member)
	data.erase("pending_recruit")
	data.erase("pending_recruit_mastery")
	data.erase("recruit_loadouts")
	data.erase("recruit_kits")
	var lane := []
	var beat := 0
	for id: String in tiles:
		var spec: Dictionary = ArenaSim.TILES[id]
		lane.append({"id": id, "start": beat, "target": spec.targets[0]})
		beat += int(spec.width)
	loadout.lanes.append(lane)
	loadout.defaults.append("nearest")
	data.segment = data.heroes.size()
	data.phase = "map"
	data.offers = []
	data.node_notice = "%s joins the expedition." % HEROES[recruit].label
	return _save_run_change(before, {}, before_loadout)


func _starter_lane(id: String) -> Array:
	return [{"id": id, "start": 0, "target": ArenaSim.TILES[id].targets[0]}]


func _starter_offers(hero_id: String, salt: int, shared := "shot") -> Array:
	var offers := ["bash", shared]
	if data.phase == "starter" and data.location == "brass" and data.difficulty in ["medium", "hard"]:
		var alternates := ClassDecks.alternate_starters(hero_id)
		offers[0] = _sample(alternates, 1, int(data.seed), salt + 41).front()
	elif _is_brass_easy():
		var specialties := ClassDecks.specialties(hero_id).filter(func(id: String): return ArenaSim.TILES[id].damage > 0)
		var relic: String = data.relics.front()
		if not specialties.is_empty() and (hero_id == "starshot" \
				or (shared == "shot" and relic not in BUILD_RELICS and not forge_family_available("shot"))):
			var slot := 0 if hero_id == "starshot" else 1
			offers[slot] = _sample(specialties, 1, int(data.seed), salt + 41)[0]
	var signature: String = ClassDecks.starter(hero_id)
	if signature not in offers:
		offers.append(signature)
	else:
		offers.append("slam" if shared == "shot" else "shot")
	return _sample(offers, 3, int(data.seed), salt)


func _is_brass_easy() -> bool:
	return data.get("location") == "brass" and data.get("difficulty") == "easy"


func available_nodes() -> Array:
	if data.get("phase") != "map":
		return []
	var next_row := int(data.node.row) + 1
	if next_row >= data.layers.size():
		return []
	var nodes: Array = []
	for node: Dictionary in data.layers[next_row]:
		if node.id in data.node.next:
			nodes.append(node)
	return nodes


func choose_node(id: String) -> bool:
	var selected: Dictionary = {}
	for node: Dictionary in available_nodes():
		if node.id == id:
			selected = node
			break
	if selected.is_empty():
		return false
	var before := data.duplicate(true)
	var before_profile := profile.duplicate(true)
	data.node = selected
	data.segment = 1 + floori(float(selected.row) / NODES_PER_SEGMENT)
	data.visited.append(id)
	data.node_notice = ""
	data.erase("enchantment_notice")
	data.erase("combat_stats")
	data.erase("reward_placement")
	data.erase("reward_hints")
	data.erase("shop_class_offers")
	data.erase("shop_deck_offer")
	data.erase("shop_stock")
	var midpoint := floori(float(data.layers.size() - 1) / 2.0)
	if not data.midpoint_paid and int(selected.row) >= midpoint:
		data.midpoint_paid = true
		_grant_marks(1)
	match selected.type:
		"shop":
			data.phase = "shop"
			data.offers = _shop_tiles()
			_add_shop_deck_offer()
			if "guild_ledger" in data.relics:
				_add_class_shop_offers()
			data.shop_stock = data.offers.duplicate()
			data.shop_healed = false
			var available := _available_relics()
			data.shop_relic = "" if available.is_empty() else _sample(available, 1, int(data.seed), _node_salt(52))[0]
		"rest", "event":
			data.phase = selected.type
		_:
			data.phase = "combat"
			_lock_pilot_formation()
	return _save_run_change(before, before_profile)


func encounter() -> Dictionary:
	if data.get("phase") != "combat":
		return {}
	return _encounter_for(data.node, int(data.segment))


func tollkeeper_preview() -> Dictionary:
	var layers: Array = data.get("layers", [])
	if layers.is_empty() or layers.back().is_empty():
		return {}
	var boss: Dictionary = layers.back()[0]
	if not _is_easy_tollkeeper(boss):
		return {}
	var variant := _tollkeeper_variant(boss)
	var preview: Dictionary = TOLLKEEPER_VARIANTS[variant].duplicate()
	preview.variant = variant
	return preview


func first_boss_preview() -> Dictionary:
	var layers: Array = data.get("layers", [])
	if int(data.get("segment", 0)) != 1 or layers.size() < NODES_PER_SEGMENT:
		return {}
	var boss: Dictionary = layers[NODES_PER_SEGMENT - 1][0]
	var id: String = boss.get("boss_id", "")
	if id == "brass_bellmaker":
		return {"id": boss.id, "title": boss.label, "description": BELLMAKER_SCOUT}
	if GLASS_BOSS_SCOUTS.has(id):
		return {"id": boss.id, "title": boss.label, "description": GLASS_BOSS_SCOUTS[id]}
	if id != "tollkeeper":
		return {}
	var variant := _tollkeeper_variant(boss)
	var preview: Dictionary = TOLLKEEPER_VARIANTS[variant].duplicate()
	preview.id = boss.id
	return preview


func _is_easy_tollkeeper(node: Dictionary) -> bool:
	return data.get("location") == "brass" and data.get("difficulty") == "easy" and node.get("boss_id") == "tollkeeper"


func _tollkeeper_variant(node: Dictionary) -> String:
	var variant: String = node.get("boss_variant", "solo")
	return variant if TOLLKEEPER_VARIANTS.has(variant) else "solo"


func _encounter_for(node: Dictionary, segment: int) -> Dictionary:
	var kind: String = node.get("encounter_override", node.type)
	var roster: Array = []
	for hero: Dictionary in data.heroes:
		var member := {"id": hero.id, "hero": hero.id, "hp": int(hero.hp), "max_hp": int(hero.max_hp)}
		if hero.has("mastery"):
			member.mastery = hero.mastery
		var class_relic := ClassRelics.id_for(hero.id)
		if class_relic in data.relics:
			member.class_relic = class_relic
		roster.append(member)
	var options := {
		"encounter": kind, "kind": kind, "id": node.id,
		"seed": int(data.seed) ^ _node_salt(71, node), "hero": data.hero, "hp": int(data.hp),
		"max_hp": int(data.max_hp), "relic": data.relics.front() if not data.relics.is_empty() else "",
		"relics": data.relics.duplicate(), "heroes": roster, "segment": segment,
		"difficulty": data.difficulty, "location": data.location,
		"boss_id": node.get("boss_id", ""), "final_boss": node.type == "boss" and int(node.row) == data.layers.size() - 1,
	}
	if _is_easy_tollkeeper(node):
		options["boss_variant"] = _tollkeeper_variant(node)
	var formation := _pilot_formation_for(node, segment, kind)
	var arrival := int(node.get("reinforcement_beat", 0))
	if kind == "battle" and arrival > 0 and formation.size() > 1:
		options["reinforcement_beat"] = arrival
		options["reinforcements"] = [formation.pop_back()]
	if not formation.is_empty():
		options["formation"] = formation
	return options


func _pilot_formation_for(node: Dictionary, segment: int, kind: String) -> Array:
	if node.has("pilot_formation"):
		return node.pilot_formation.duplicate(true)
	if not data.has("pilot_fights"):
		return []
	var minimum_enemies := 2 if kind == "battle" and node.has("reinforcement_beat") else 1
	return PilotFormations.choose(data.location, segment, kind, int(data.seed) ^ _node_salt(187, node),
		data.pilot_fights, int(data.get("encounter_roster_version", 1)), minimum_enemies)


func _lock_pilot_formation() -> void:
	var node: Dictionary = data.node
	var formation := _pilot_formation_for(node, int(data.segment), node.get("encounter_override", node.type))
	if not formation.is_empty():
		node["pilot_formation"] = formation


func _record_pilot_fight(kind: String) -> void:
	if not data.has("pilot_fights"):
		return
	var enemies: Array[String] = []
	var formation: Array = data.node.get("pilot_formation", [])
	if not formation.is_empty():
		for spawn: Dictionary in formation:
			enemies.append(spawn.id)
	else:
		var fight := ArenaSim.new()
		fight.start([], "solo", encounter())
		for unit: Dictionary in fight.units:
			if unit.side == "enemy":
				enemies.append(unit.id.rsplit("_", true, 1)[0])
	data.pilot_fights.append({"kind": kind, "enemies": enemies})


func elite_preview(node: Dictionary) -> Dictionary:
	if node.get("type") != "elite" or not available_nodes().any(func(option: Dictionary): return option.id == node.id):
		return {}
	var tile := _elite_preview_tile(node)
	var segment := 1 + floori(float(node.row) / NODES_PER_SEGMENT)
	return {
		"encounter": _encounter_for(node, segment), "tile": tile, "reward_family": ArenaSim.TILES[tile].get("family", ""),
		"relic_draft": not _has_earned_elite_relic() or _can_draft_party_elite_relic(),
	}


func _elite_preview_tile(node: Dictionary) -> String:
	if not _has_earned_elite_relic():
		return ClassDecks.signature(data.hero)
	return _class_elite_preview_tile(node)


func _class_elite_preview_tile(node: Dictionary) -> String:
	# The advertised offer is stable even if the player edits their inventory before the fight.
	var baseline: Array = ClassDecks.core_uncommon(data.hero)
	for tier in range(1, 4):
		baseline.append_array(_class_forge_tier(ClassDecks.forge_families(data.hero), tier))
	return _sample(baseline, 1, int(data.seed), _node_salt(81, node))[0]


func will_draft_elite_relic() -> bool:
	if data.get("phase") != "combat":
		return false
	return data.node.get("encounter_override", data.node.type) == "elite" \
		and (not _has_earned_elite_relic() or _can_draft_party_elite_relic())


func _can_draft_party_elite_relic() -> bool:
	return not data.get("party_elite_relic_drafted", false) and _living_heroes().size() >= 2 \
		and (int(data.get("segment", 1)) == 2 or _has_earned_elite_relic())


func _living_heroes() -> Array:
	return data.get("heroes", []).filter(func(hero: Dictionary): return int(hero.hp) > 0)


func _has_earned_elite_relic() -> bool:
	if data.has("elite_relic_drafted"):
		return bool(data.elite_relic_drafted)
	# Older saves record completed nodes, rather than whether an elite paid out.
	var current: Dictionary = data.get("node", {})
	if data.get("phase") in ["map", "reward"] and current.get("encounter_override", current.get("type")) == "elite":
		return true
	var completed: Array = data.get("visited", [])
	for layer: Array in data.get("layers", []):
		for saved_node: Dictionary in layer:
			if saved_node.id not in completed:
				continue
			var node := saved_node
			if saved_node.id == current.get("id"):
				if data.get("phase") not in ["map", "reward"]:
					continue
				node = current
			if node.get("encounter_override", node.type) == "elite":
				return true
	return false


func elite_relic_offers() -> Array:
	return data.get("elite_relic_offers", []) if data.get("phase") == "reward" else []


func party_elite_relic_draft() -> bool:
	return not elite_relic_offers().is_empty() and bool(data.get("party_elite_relic_pending", false))


func choose_elite_relic(id: String) -> bool:
	for offer: Dictionary in elite_relic_offers():
		if offer.id != id or id in data.relics:
			continue
		var owner := ClassRelics.owner(id)
		if not owner.is_empty() and (offer.get("owner") != owner \
				or not _living_heroes().any(func(hero: Dictionary): return hero.id == owner)):
			return false
		var before := data.duplicate(true)
		if party_elite_relic_draft():
			data.party_elite_relic_drafted = true
			data.erase("party_elite_relic_pending")
		var guaranteed: String = data.get("elite_guaranteed_tile", "")
		data.relics.append(id)
		data.elite_relic_drafted = true
		data.erase("elite_relic_offers")
		data.erase("elite_guaranteed_tile")
		var tile: String = offer.companion
		if not tile.is_empty():
			if guaranteed.is_empty() and data.node.type == "elite":
				guaranteed = _class_elite_preview_tile(data.node) if reward_lane() >= 0 else _legacy_elite_preview_tile()
			if tile not in data.offers:
				for index in range(data.offers.size() - 1, -1, -1):
					var replaced: String = data.offers[index]
					if replaced == guaranteed or not reward_hint(replaced).is_empty():
						continue
					data.offers[index] = tile
					break
			var hints: Dictionary = data.get("reward_hints", {})
			hints[tile] = "Pairs with " + RELICS[id].label
			data.reward_hints = hints
		data.node_notice = "Relic acquired: " + RELICS[id].label
		return _save_run_change(before)
	return false


func _legacy_elite_preview_tile() -> String:
	var baseline: Array = ArenaSim.BASH_TIERS[1] + ArenaSim.BASH_TIERS[2] + ArenaSim.BASH_TIERS[3]
	for tier in range(1, 4):
		baseline.append_array(_specialist_pool(tier))
	return _sample(baseline, 1, int(data.seed), _node_salt(81))[0]


func _build_elite_relic_offers() -> Array:
	var salt := _node_salt(181)
	var pool := _available_elite_relics()
	var order := _sample(pool, pool.size(), int(data.seed), salt)
	var equipped: Array = []
	for lane_index in range(loadout.lanes.size()):
		if lane_index < data.heroes.size() and int(data.heroes[lane_index].hp) > 0:
			equipped.append(loadout.lanes[lane_index])
	var offers: Array[Dictionary] = []
	for id: String in order:
		offers.append(_elite_relic_offer(id, equipped))
	if offers.size() < 3:
		for offer: Dictionary in offers:
			offer.role = "Elite relic"
			offer.erase("fit")
		return offers
	var fit := 0
	for index in range(1, offers.size()):
		if offers[index].fit > offers[fit].fit:
			fit = index
	var first: Dictionary = offers.pop_at(fit)
	first.role = "Fits your build" if first.fit >= 2 else "Closest fit"
	var pivot := 0
	for index in range(offers.size()):
		if offers[index].fit == 1:
			pivot = index
			break
		if offers[pivot].fit == 0 and offers[index].fit > 0:
			pivot = index
	var second: Dictionary = offers.pop_at(pivot)
	second.role = "Pivot" if second.fit > 0 else "Long-term pivot"
	var wildcard: Dictionary = offers.front()
	wildcard.role = "Wildcard"
	var draft := [first, second, wildcard]
	for offer: Dictionary in draft:
		offer.erase("fit")
	return draft


func _build_party_elite_relic_offers() -> Array:
	var class_offer := _class_elite_relic_offer()
	if not _has_earned_elite_relic() and not class_offer.is_empty():
		var first_offers := _build_elite_relic_offers().slice(0, 2)
		first_offers.append(class_offer)
		return first_offers
	var shared_count := 3 if class_offer.is_empty() else 2
	var picks := PARTY_ELITE_RELICS.filter(func(id: String): return id not in data.relics)
	if picks.size() < shared_count:
		var alternatives := _available_relics().filter(func(id: String): return id not in picks)
		picks.append_array(_sample(alternatives, shared_count - picks.size(), int(data.seed), _node_salt(187)))
	var offers := _sample(picks, shared_count, int(data.seed), _node_salt(188)).map(func(id: String) -> Dictionary:
		return {"id": id, "role": "", "companion": ""})
	if not class_offer.is_empty():
		offers.append(class_offer)
	return offers


func _class_elite_relic_offer() -> Dictionary:
	if int(data.get("segment", 1)) != 2:
		return {}
	var candidates := _living_heroes().map(func(hero: Dictionary): return ClassRelics.id_for(hero.id))
	candidates = candidates.filter(func(id: String): return not id.is_empty() and id not in data.relics)
	if candidates.is_empty():
		return {}
	var id: String = _sample(candidates, 1, int(data.seed), _node_salt(191))[0]
	return {"id": id, "owner": ClassRelics.owner(id), "role": "", "companion": ""}


func _elite_relic_offer(id: String, equipped := []) -> Dictionary:
	var owned: Array = loadout.lanes + loadout.storage
	var fit := 0
	var candidates: Array = []
	match id:
		"afterimage":
			var blink := func(tile: String): return ArenaSim.is_blink_tile(tile)
			var follow_up := func(tile: String): return ArenaSim.can_trigger_afterimage(tile)
			var has_blink := _count_matching_tiles(owned, blink) > 0
			var has_follow_up := _count_matching_tiles(owned, follow_up) > 0
			if has_blink and has_follow_up:
				fit = 2
				for lane: Array in equipped:
					if _count_matching_tiles([lane], blink) > 0 and _count_matching_tiles([lane], follow_up) > 0:
						fit = 3
						break
			else:
				fit = int(has_blink or has_follow_up)
				candidates = ["shield_ram", "hook_bash"] if has_blink else ["phase_cut", "ward_step"]
		"barrage_rack":
			var short_hit := func(tile: String): return ArenaSim.TILES[tile].damage > 0 and ArenaSim.TILES[tile].width <= 2
			var count := _count_matching_tiles(owned, short_hit)
			if count >= 2:
				fit = 3 if _count_matching_tiles(equipped, short_hit) >= 2 else 2
			else:
				fit = count
				candidates = ["hook_bash", "shield_ram"]
		"siege_fuse":
			var heavy := func(tile: String): return ArenaSim.TILES[tile].damage > 0 and ArenaSim.TILES[tile].width >= 4
			if _count_matching_tiles(owned, heavy) > 0:
				fit = 3 if _count_matching_tiles(equipped, heavy) > 0 else 2
			else:
				fit = 1
				candidates = ["shockwave", "sundering_slam"]
		"switchback_lens":
			for lane: Array in equipped:
				var attacks := lane.filter(func(tile: Dictionary): return ArenaSim.TILES[tile.id].damage > 0)
				if attacks.size() >= 2:
					fit = 1
					if attacks.any(func(tile: Dictionary): return tile.target != attacks.front().target):
						fit = 3
						break
		"longshot_prism":
			var ranged := func(tile: String):
				return ArenaSim.is_ranged_tile(tile) and ArenaSim.TILES[tile].damage > 0 \
					and ArenaSim.TILES[tile].range >= ArenaSim.LONGSHOT_PRISM_RANGE
			var equipped_count := _count_matching_tiles(equipped, ranged)
			if equipped_count > 1:
				fit = 3
			elif equipped_count == 1:
				fit = 2
			elif _count_matching_tiles(owned, ranged) > 0:
				fit = 1
		"twin_bell":
			var finishing_beats := {}
			fit = 1
			for lane: Array in equipped:
				var attack_beats: Array[int] = []
				for tile: Dictionary in lane:
					var spec: Dictionary = ArenaSim.TILES[tile.id]
					if spec.damage > 0:
						attack_beats.append(int(tile.start) + int(spec.width))
				if attack_beats.any(func(beat: int): return finishing_beats.has(beat)):
					fit = 3
					break
				for beat: int in attack_beats:
					finishing_beats[beat] = true
	var tile: String = "" if candidates.is_empty() else _sample(candidates, 1, int(data.seed), _node_salt(182 + ELITE_RELICS.find(id)))[0]
	return {"id": id, "fit": fit, "companion": tile}


func _count_matching_tiles(rows: Array, matches: Callable) -> int:
	var count := 0
	for row: Array in rows:
		for tile: Dictionary in row:
			if matches.call(tile.id):
				count += 1
	return count


func is_final_boss() -> bool:
	return data.get("node", {}).get("type") == "boss" and int(data.node.row) == data.layers.size() - 1


func boss_relic_offers() -> Array:
	var offers: Array = []
	if data.get("phase") == "boss_relic":
		for id: String in data.offers:
			offers.append({"id": id, "label": RELICS[id].label, "description": RELICS[id].description})
	return offers


func choose_boss_relic(id: String) -> bool:
	if data.get("phase") != "boss_relic" or (id != "skip" and (id not in data.offers or id in data.relics)):
		return false
	var before := data.duplicate(true)
	if id != "skip":
		data.relics.append(id)
	_start_recruitment()
	return _save_run_change(before)


func _start_recruitment() -> void:
	var classes := available_classes()
	for hero: Dictionary in data.heroes:
		classes.erase(hero.id)
	data.phase = "recruit"
	data.offers = _sample(classes, 3, int(data.seed), _node_salt(94))


func should_teach_timeline() -> bool:
	return data.get("phase") == "combat" and data.get("location") == "brass" and data.get("difficulty") == "easy" \
		and data.get("node", {}).get("type") == "opening" and not profile.get("timeline_intro_seen", false) and not profile.medium_unlocked


func finish_combat(victory: bool, hp: Variant, combat_stats := {}) -> bool:
	if data.get("phase") != "combat":
		return false
	var remaining: Array = hp if hp is Array else [hp]
	if remaining.size() != data.heroes.size():
		return false
	var before := data.duplicate(true)
	var before_profile := profile.duplicate(true)
	if not combat_stats.is_empty():
		data.combat_stats = combat_stats.duplicate(true)
	if should_teach_timeline():
		profile.timeline_intro_seen = true
	for index in range(remaining.size()):
		var hero: Dictionary = data.heroes[index]
		hero.hp = clampi(int(remaining[index]), 0, int(hero.max_hp))
	_sync_lead_hero()
	if not victory:
		data.result = "defeat"
		data.phase = "result"
		return _save_run_change(before, before_profile)
	if "trail_ration" in data.relics:
		_heal(5, false)
	var draft_relic := will_draft_elite_relic()
	var party_relic := draft_relic and _can_draft_party_elite_relic()
	var kind: String = data.node.get("encounter_override", data.node.type)
	_record_pilot_fight(kind)
	data.phase = "reward"
	match kind:
		"boss":
			_resolve_boss()
		"elite":
			data.gold += 20
			_grant_marks(2)
			if party_relic:
				data.elite_relic_offers = _build_party_elite_relic_offers()
				data.party_elite_relic_pending = true
				if not _has_earned_elite_relic():
					data.elite_guaranteed_tile = ClassDecks.signature(data.hero)
			elif draft_relic:
				data.elite_relic_offers = _build_elite_relic_offers()
				data.elite_guaranteed_tile = ClassDecks.signature(data.hero)
			else:
				# Later elites favor elite relics and can still award metaprogression unlocks.
				var elite_pool := _available_elite_relics()
				var relic_pool := _available_relics() + elite_pool + elite_pool
				if not relic_pool.is_empty():
					var found: String = _sample(relic_pool, 1, int(data.seed), _node_salt(82))[0]
					data.relics.append(found)
					data.node_notice = "Relic acquired: " + RELICS[found].label
		_:
			data.gold += 12
	_prepare_party_rewards(kind)
	return _save_run_change(before, before_profile)


func _resolve_boss() -> void:
	_grant_marks(4)
	if not is_final_boss():
		if _has_boss_relic_draft():
			data.node_notice = "%s fell. Choose a Legendary, then claim a boss relic and recruit a second hero." % data.node.label
			return
		var rank := "second" if data.heroes.size() == 1 else "third"
		var reward_copy := "a Legendary" if data.heroes.size() == 1 else "your Legendaries"
		data.node_notice = "%s fell. Choose %s and draft a %s hero." % [data.node.label, reward_copy, rank]
		return
	data.result = "victory"
	var new_masteries := []
	for hero: Dictionary in data.heroes:
		if hero.id not in profile.mastered_classes:
			profile.mastered_classes.append(hero.id)
			new_masteries.append(hero.id)
	data.new_masteries = new_masteries
	if data.location == "moonwreck" and data.difficulty == "hard":
		var first_clear := not bool(profile.moonwreck_hard_cleared)
		_grant_marks(50 if first_clear else 35)
		profile.moonwreck_hard_cleared = true
		data.node_notice = "Moonwreck Docks Hard mastered." if first_clear else "Moonwreck Docks Hard cleared."
	elif data.location == "moonwreck" and data.difficulty == "medium":
		var first_clear := not bool(profile.moonwreck_hard_unlocked)
		_grant_marks(30 if first_clear else 20)
		profile.moonwreck_hard_unlocked = true
		data.node_notice = "Moonwreck Docks Medium cleared. Moonwreck Docks Hard unlocked." if first_clear else "Moonwreck Docks Medium cleared."
	elif data.location == "moonwreck":
		var first_clear := not bool(profile.moonwreck_medium_unlocked)
		_grant_marks(15 if first_clear else 10)
		profile.moonwreck_medium_unlocked = true
		data.node_notice = "Moonwreck Docks Easy cleared. Moonwreck Docks Medium unlocked." if first_clear else "Moonwreck Docks Easy cleared."
	elif data.location == "crown" and data.difficulty == "hard":
		var first_clear := not bool(profile.crown_hard_cleared)
		_grant_marks(50 if first_clear else 35)
		profile.crown_hard_cleared = true
		data.node_notice = "Crown Relay Hard mastered." if first_clear else "Crown Relay Hard cleared."
	elif data.location == "crown" and data.difficulty == "medium":
		var first_clear := not bool(profile.crown_hard_unlocked)
		_grant_marks(30 if first_clear else 20)
		profile.crown_hard_unlocked = true
		profile.moonwreck_easy_unlocked = true
		data.node_notice = "Crown Relay Medium cleared. Hard and Moonwreck Docks Easy unlocked." if first_clear else "Crown Relay Medium cleared."
	elif data.location == "crown":
		var first_clear := not bool(profile.crown_medium_unlocked)
		_grant_marks(15 if first_clear else 10)
		profile.crown_medium_unlocked = true
		data.node_notice = "Crown Relay Easy cleared. Crown Relay Medium unlocked." if first_clear else "Crown Relay Easy cleared."
	elif data.location == "glass" and data.difficulty == "hard":
		var first_clear := not bool(profile.glass_hard_cleared)
		_grant_marks(50 if first_clear else 35)
		profile.glass_hard_cleared = true
		data.node_notice = "Glass Foundry Hard mastered." if first_clear else "Glass Foundry Hard cleared."
	elif data.location == "glass" and data.difficulty == "medium":
		var first_clear := not bool(profile.glass_hard_unlocked)
		_grant_marks(30 if first_clear else 20)
		profile.glass_hard_unlocked = true
		profile.crown_easy_unlocked = true
		data.node_notice = "Glass Foundry Medium cleared. Hard and Crown Relay Easy unlocked." if first_clear else "Glass Foundry Medium cleared."
	elif data.location == "glass":
		var first_clear := not bool(profile.glass_medium_unlocked)
		_grant_marks(15 if first_clear else 10)
		profile.glass_medium_unlocked = true
		data.node_notice = "Glass Foundry Easy cleared. Glass Foundry Medium unlocked." if first_clear else "Glass Foundry Easy cleared."
	elif data.difficulty == "hard":
		var first_clear := not bool(profile.brass_hard_cleared)
		_grant_marks(50 if first_clear else 35)
		profile.brass_hard_cleared = true
		data.node_notice = "Brass Frontier Hard mastered." if first_clear else "Brass Frontier Hard cleared."
	elif data.difficulty == "medium":
		var first_clear := not bool(profile.hard_unlocked)
		_grant_marks(30 if first_clear else 20)
		profile.hard_unlocked = true
		profile.glass_easy_unlocked = true
		data.node_notice = "Brass Frontier Medium cleared. Hard and Glass Foundry Easy unlocked." if first_clear else "Brass Frontier Medium cleared."
	else:
		var first_clear := not bool(profile.medium_unlocked)
		_grant_marks(15 if first_clear else 10)
		profile.medium_unlocked = true
		data.node_notice = "Brass Frontier cleared. Medium unlocked." if first_clear else "Brass Frontier cleared."


func _has_boss_relic_draft() -> bool:
	return data.location == "brass" and data.difficulty in ["medium", "hard"] and data.segment == 1 \
		and BOSS_RELICS.has(data.node.get("boss_id", ""))


func reward_lane() -> int:
	return int(data.get("reward_lane", -1)) if data.get("phase") == "reward" else -1


func reward_count() -> int:
	if data.get("phase") != "reward":
		return 0
	return 1 if reward_lane() < 0 else reward_lane() + 1 + data.get("reward_remaining", []).size()


func reward_position() -> int:
	return maxi(0, reward_lane()) if data.get("phase") == "reward" else -1


func reward_skip_gold() -> int:
	if data.get("phase") != "reward" or is_final_boss() or not mystery_kind().is_empty() or data.get("reward_gold_paid", false):
		return 0
	return 6 + (3 if "quartermasters_coin" in data.relics else 0)


func has_combat_reward() -> bool:
	if data.get("phase") != "reward":
		return false
	var node: Dictionary = data.node
	return node.get("encounter_override", node.type) in ["opening", "battle", "elite", "boss"]


func reward_reroll_price() -> int:
	if not has_combat_reward() or not elite_relic_offers().is_empty() or data.has("reward_combine") \
		or data.offers.size() != 3:
		return 0
	var count := _act_rerolls()
	return 5 << mini(count, 50)


func reward_reroll_prefers_copy() -> bool:
	return reward_reroll_price() > 0 and _act_rerolls() == 0 and data.offers.any(func(id: String):
		return ArenaSim.TILES[id].rarity != "legendary")


func _act_rerolls() -> int:
	return int(data.get("reward_rerolls", 0)) if int(data.get("reroll_act", 0)) == int(data.segment) else 0


func reroll_reward() -> bool:
	var price := reward_reroll_price()
	if price == 0 or int(data.gold) < price:
		return false
	var lane := maxi(0, reward_lane())
	var hero: String = data.heroes[lane].id
	var rows := _reward_inventory(lane)
	var count := _act_rerolls()
	var salt := 421 + lane * 1069 + count * 719
	var pools := {}
	for id: String in data.offers:
		var tier := TILE_RARITIES.find(ArenaSim.TILES[id].rarity)
		if not pools.has(tier):
			pools[tier] = _class_reward_pool(hero, tier, rows)
	var copy := _first_reroll_copy(hero, rows, pools, salt + 1) if count == 0 else ""
	var signatures := _boss_signature_legendaries(hero)
	var replacements := _reroll_tiles(pools, salt, copy, signatures)
	if replacements.is_empty() and not copy.is_empty():
		replacements = _reroll_tiles(pools, salt, "", signatures)
	if replacements.is_empty():
		return false
	var hints := {}
	for replacement: String in replacements:
		var hint := _copy_reward_hint(replacement, rows)
		if not hint.is_empty():
			hints[replacement] = hint
	var before := data.duplicate(true)
	data.gold -= price
	data.reroll_act = data.segment
	data.reward_rerolls = count + 1
	_activate_reward_draft({"offers": replacements, "hints": hints})
	return _save_run_change(before)


func _first_reroll_copy(hero_id: String, rows: Array, pools: Dictionary, salt: int) -> String:
	var eligible := _forge_copy_pool(hero_id, rows).filter(func(id: String):
		var tier := TILE_RARITIES.find(ArenaSim.TILES[id].rarity)
		return id in pools.get(tier, []))
	var new_to_draft := eligible.filter(func(id: String): return id not in data.offers)
	return _owned_reward(eligible if new_to_draft.is_empty() else new_to_draft, salt, false, rows)


func _reroll_tiles(pools: Dictionary, salt: int, copy := "", signatures: Array = []) -> Array[String]:
	var rng := _rng(int(data.seed), _node_salt(salt))
	var replacements: Array[String] = []
	var signature_slot: int = data.offers.find_custom(func(id: String): return id in signatures)
	var copy_slot: int = data.offers.find(copy)
	if copy_slot < 0 and not copy.is_empty():
		var copy_rarity: String = ArenaSim.TILES[copy].rarity
		copy_slot = data.offers.find_custom(func(id: String): return ArenaSim.TILES[id].rarity == copy_rarity)
	for index in range(data.offers.size()):
		var id: String = data.offers[index]
		if index == signature_slot:
			replacements.append(signatures[1] if id == signatures[0] else signatures[0])
			continue
		if index == copy_slot:
			replacements.append(copy)
			continue
		var tier := TILE_RARITIES.find(ArenaSim.TILES[id].rarity)
		var pool: Array = pools[tier]
		var unclaimed := pool.filter(func(tile: String):
			return tile != copy and tile not in replacements and (signature_slot < 0 or tile not in signatures))
		var fresh := unclaimed.filter(func(tile: String): return tile not in data.offers)
		if fresh.is_empty():
			fresh = unclaimed.filter(func(tile: String): return tile != id)
		if fresh.is_empty():
			return []
		replacements.append(fresh[rng.randi_range(0, fresh.size() - 1)])
	return replacements


func current_reward_placement() -> Dictionary:
	var placement: Dictionary = data.get("reward_placement", {})
	if placement.is_empty():
		return {}
	var stored := placement.has("row")
	var rows: Array = loadout.get("storage" if stored else "lanes", [])
	var row := int(placement.get("row" if stored else "lane", -1))
	if row < 0 or row >= rows.size():
		return {}
	for tile: Dictionary in rows[row]:
		if tile.id == placement.id and int(tile.start) == int(placement.start):
			return placement
	return {}


func reward(id: String, placement := {}) -> bool:
	if data.get("phase") != "reward" or (id != "skip" and id not in data.offers):
		return false
	if not elite_relic_offers().is_empty() or data.has("reward_combine"):
		return false
	var before := data.duplicate(true)
	var lane := reward_lane()
	if is_final_boss():
		data.erase("reward_placement")
		var trophy := "" if id == "skip" else id
		var owner: String = data.heroes[maxi(lane, 0)].id
		var trophies: Dictionary = data.get("trophies", {})
		if not trophy.is_empty():
			trophies[owner] = trophy
		data.trophies = trophies
		if lane <= 0:
			data.trophy = trophy
	elif id == "skip":
		var gold := reward_skip_gold()
		if gold > 0:
			data.gold += gold
			data.reward_gold_paid = true
	elif not placement.is_empty():
		data.reward_placement = placement
	if lane >= 0 and not data.reward_remaining.is_empty():
		data.reward_lane = lane + 1
		_activate_reward_draft(data.reward_remaining.pop_front())
		return _save_run_change(before)
	data.erase("reward_lane")
	data.erase("reward_remaining")
	data.erase("reward_gold_paid")
	data.erase("reward_hints")
	if is_final_boss():
		data.phase = "result"
		data.offers = []
	elif data.node.type == "boss":
		if _has_boss_relic_draft():
			data.phase = "boss_relic"
			var relics: Array = BOSS_RELICS[data.node.boss_id]
			data.offers = _sample(relics, relics.size(), int(data.seed), _node_salt(193))
			data.node_notice = ""
		else:
			_start_recruitment()
	else:
		data.offers = _draft_enchantments()
		data.phase = "map" if data.offers.is_empty() else "enchantment"
	return _save_run_change(before)


func _completed_enchantment_drafts() -> Array:
	return data.get("enchantment_drafts", ["opening"] if data.has("enchantment") else [])


func _draft_enchantments() -> Array:
	if data.location != "brass" or "enchantments" not in profile.meta:
		return []
	var opening: bool = data.node.type == "opening"
	var recruitment: bool = data.node.type == "battle" and int(data.segment) >= 2 and data.heroes.size() >= 2
	var stage := "opening" if opening else "recruit"
	var held := enchantments()
	if (not opening and not recruitment) or stage in _completed_enchantment_drafts() or held.size() >= 2:
		return []
	var pool := TileEnchantments.IDS.filter(func(id: String): return id not in held and (recruitment or id != "mending"))
	var rows: Array = loadout.lanes + loadout.storage
	var fitting := pool.filter(func(id: String):
		return rows.any(func(row: Array): return row.any(func(item: Dictionary):
			return TileEnchantments.is_eligible(id, ArenaSim.TILES[item.id], item.id))))
	var pick := _sample(fitting, 3, int(data.seed), _node_salt(141))
	var other := pool.filter(func(id: String): return id not in fitting)
	pick.append_array(_sample(other, 3 - pick.size(), int(data.seed), _node_salt(142)))
	return pick


func _pending_enchantment_ids() -> Array:
	return data.offers if not data.offers.is_empty() else TileEnchantments.LEGACY_IDS


func enchantment_offers() -> Array:
	if data.get("phase") != "enchantment":
		return []
	return _pending_enchantment_ids().map(func(id: String): return TileEnchantments.info(id).duplicate())


func choose_enchantment(id: String, destination := {}) -> bool:
	if data.get("phase") != "enchantment" or (id != "skip" and id not in _pending_enchantment_ids()):
		return false
	var stage := "opening" if data.node.type == "opening" else "recruit"
	var completed := _completed_enchantment_drafts()
	var held := enchantments()
	if stage in completed or (id != "skip" and (id in held or held.size() >= 2)):
		return false
	var before_loadout: Variant = null
	var equipped_tile := ""
	if not destination.is_empty():
		var rows: Array = loadout.storage if destination.has("row") else loadout.lanes
		var row := int(destination.get("row", destination.get("lane", -1)))
		if id == "skip" or row < 0 or row >= rows.size():
			return false
		var item_index: int = rows[row].find_custom(func(item: Dictionary):
			return item.start == destination.get("start", -1) and item.id == destination.get("id", "")
		)
		if item_index < 0:
			return false
		var item: Dictionary = rows[row][item_index]
		if not TileEnchantments.is_eligible(id, ArenaSim.TILES.get(item.id, {}), item.id):
			return false
		before_loadout = loadout.duplicate(true)
		item.enchantment = id
		equipped_tile = ArenaSim.TILES[item.id].label
	var before := data.duplicate(true)
	if id != "skip":
		held.append(id)
		var label: String = TileEnchantments.info(id).label
		data.enchantment_notice = "%s kept for later." % label if equipped_tile.is_empty() \
			else "%s equipped on %s." % [label, equipped_tile]
	data.enchantments = held
	data.enchantment_drafts = completed + [stage]
	data.erase("enchantment")
	data.offers = []
	data.phase = "map"
	return _save_run_change(before, {}, before_loadout)


func enchantments() -> Array:
	if data.has("enchantments"):
		return data.enchantments.duplicate()
	var legacy: String = data.get("enchantment", "")
	return [legacy] if legacy in TileEnchantments.LEGACY_IDS else []


func _save_run_change(before: Dictionary, before_profile := {}, before_loadout: Variant = null) -> bool:
	if save():
		return true
	data = before
	if not before_profile.is_empty():
		profile = before_profile
	if before_loadout != null:
		loadout = before_loadout
	return false


func shop_price(id: String) -> int:
	if not ArenaSim.TILES.has(id):
		return 0
	var tile: Dictionary = ArenaSim.TILES[id]
	var rarity_price: int = {"uncommon": 7, "rare": 13, "epic": 20}.get(tile.get("rarity", "common"), 0)
	return 18 + 3 * (int(tile.width) - 2) + rarity_price


func shop_stock() -> Array:
	if data.get("phase") != "shop":
		return []
	return data.get("shop_stock", data.offers)


func shop_tile_purchased(id: String) -> bool:
	return id in shop_stock() and not _is_offer("shop", id)


func shop_deck_offer_id() -> String:
	return data.get("shop_deck_offer", "") if data.get("phase") == "shop" else ""


func shop_class_offer_owner(id: String) -> String:
	if id not in shop_stock():
		return ""
	return data.get("shop_class_offers", {}).get(id, "")


func shop_class_offer_lane(id: String) -> int:
	if not _is_offer("shop", id):
		return -1
	var owner := shop_class_offer_owner(id)
	if owner.is_empty():
		return -1
	return data.heroes.find_custom(func(hero: Dictionary): return hero.id == owner)


func shop_buy(id: String, placement := {}) -> bool:
	if not _is_offer("shop", id) or int(data.gold) < shop_price(id):
		return false
	var before := data.duplicate(true)
	if not data.has("shop_stock"):
		data.shop_stock = data.offers.duplicate()
	data.gold -= shop_price(id)
	data.offers.erase(id)
	if not placement.is_empty():
		data.reward_placement = placement
	return _save_run_change(before)


func shop_heal() -> bool:
	if data.get("phase") != "shop" or data.shop_healed or int(data.gold) < 12 or not party_needs_healing():
		return false
	var before := data.duplicate(true)
	data.gold -= 12
	data.shop_healed = true
	_heal(15)
	return _save_run_change(before)


func shop_buy_relic() -> bool:
	if data.get("phase") != "shop" or data.get("shop_relic", "").is_empty() or int(data.gold) < 30:
		return false
	var before := data.duplicate(true)
	data.gold -= 30
	data.relics.append(data.shop_relic)
	data.shop_relic = ""
	return _save_run_change(before)


func leave_node() -> bool:
	if data.get("phase") not in ["shop", "rest", "event"]:
		return false
	return _return_to_map(data.duplicate(true))


func rest(action: String, forge_notice := "") -> bool:
	if data.get("phase") != "rest" or action not in ["heal", "forge"]:
		return false
	var before := data.duplicate(true)
	if action == "heal":
		for hero: Dictionary in data.heroes:
			hero.hp = mini(int(hero.max_hp), int(hero.hp) + ceili(float(hero.max_hp) * 0.30))
		_sync_lead_hero()
	elif not forge_notice.is_empty():
		data.node_notice = forge_notice
	return _return_to_map(before)


func _return_to_map(before: Dictionary) -> bool:
	data.phase = "map"
	data.offers = []
	return _save_run_change(before)


func mystery_kind() -> String:
	var node: Dictionary = data.get("node", {})
	var row := int(node.get("row", -1))
	if data.get("location") != "brass" or node.get("type") != "event" or row < 1 or row >= NODES_PER_SEGMENT - 1:
		return ""
	return BUILD_MYSTERIES.get(node.get("label", ""), "")


func mystery_salvage_tiles() -> Array:
	var offers: Array[String] = []
	if data.get("phase") != "event" or mystery_kind() != "salvage_bench":
		return offers
	for row: Array in _reward_inventory(0):
		for tile: Dictionary in row:
			if ArenaSim.TILES[tile.id].rarity == "common" and tile.id not in offers:
				offers.append(tile.id)
	offers.sort_custom(func(a: String, b: String): return ArenaSim.TILES[a].label < ArenaSim.TILES[b].label)
	return offers


func mystery_begin_salvage() -> bool:
	return _begin_mystery_reward(mystery_salvage_tiles())


func mystery_cache_categories() -> Array:
	var categories: Array[Dictionary] = []
	if data.get("phase") != "event" or mystery_kind() != "class_cache":
		return categories
	for id: String in CACHE_CATEGORIES:
		if not _mystery_cache_pool(id).is_empty():
			var info: Dictionary = CACHE_CATEGORIES[id]
			categories.append({"id": id, "label": info.label, "description": info.description})
	return categories


func mystery_choose_cache_category(id: String) -> bool:
	if data.get("phase") != "event" or mystery_kind() != "class_cache" or not CACHE_CATEGORIES.has(id):
		return false
	var pool := _mystery_cache_pool(id)
	var salt := 196 + CACHE_CATEGORIES.keys().find(id)
	return _begin_mystery_reward(_sample(pool, mini(pool.size(), 3), int(data.seed), _node_salt(salt)))


func _mystery_cache_pool(category: String) -> Array:
	return ClassDecks.uncommon(data.hero).filter(func(id: String): return _cache_tile_matches(id, category))


func _cache_tile_matches(id: String, category: String) -> bool:
	var tile: Dictionary = ArenaSim.TILES[id]
	match category:
		"damage":
			return int(tile.damage) > 0
		"support":
			return tile.has("guard") or tile.has("ally_guard") or tile.has("bastion_party_guard") or tile.has("heal")
		"movement":
			return tile.has("push") or tile.has("pull") or tile.has("retreat") or tile.has("sweep_push_radius") \
				or tile.get("charge", false) or ArenaSim.is_blink_tile(id)
	return false


func _begin_mystery_reward(offers: Array) -> bool:
	if offers.is_empty():
		return false
	var before := data.duplicate(true)
	var inventory := _reward_inventory(0)
	var hints := {}
	for id: String in offers:
		if _count_matching_tiles(inventory, func(tile_id: String): return tile_id == id) > 0:
			hints[id] = _copy_reward_hint(id, inventory)
	data.phase = "reward"
	data.reward_lane = 0
	data.reward_remaining = []
	data.reward_gold_paid = false
	_activate_reward_draft({"offers": offers, "hints": hints})
	return _save_run_change(before)


func mystery_smith_options(id: String) -> Array:
	if data.get("phase") != "event" or mystery_kind() != "traveling_smith":
		return []
	var family: String = ArenaSim.TILES.get(id, {}).get("family", "")
	return TilePacking.next_options(id) if forge_family_available(family) else []


func choose_mystery_upgrade(source: Dictionary, upgrade: String) -> bool:
	var source_id: String = source.get("id", "")
	if upgrade not in mystery_smith_options(source_id):
		return false
	var stored := source.has("row")
	var rows: Array = loadout.storage if stored else loadout.lanes
	var row := int(source.get("row" if stored else "lane", -1))
	if row < 0 or row >= rows.size():
		return false
	var items: Array = rows[row]
	var capacity := TilePacking.STORAGE_COLUMNS if stored else ArenaSim.BEATS
	var start := int(source.get("start", -1))
	if not TilePacking.can_place(items, upgrade, start, capacity, start):
		return false
	for item: Dictionary in items:
		if item.id != source_id or item.start != start:
			continue
		var before := data.duplicate(true)
		var target: String = item.target
		var enchantment: String = item.get("enchantment", "")
		var targets: Array = ArenaSim.TILES[upgrade].targets
		item.id = upgrade
		TileEnchantments.keep_if_eligible(item, ArenaSim.TILES[upgrade])
		if target not in targets and (target not in ArenaSim.CROWN_TARGET_RULES or "nearest" not in targets):
			item.target = targets[0]
		var was_suppressed: bool = loadout.suppressed.erase(upgrade)
		data.phase = "map"
		data.offers = []
		data.node_notice = "%s upgraded to %s." % [ArenaSim.TILES[source_id].label, ArenaSim.TILES[upgrade].label]
		if not enchantment.is_empty() and not item.has("enchantment"):
			data.node_notice += "\n%s returned to storage." % TileEnchantments.info(enchantment).label
		if _save_run_change(before):
			return true
		item.id = source_id
		item.target = target
		if not enchantment.is_empty():
			item.enchantment = enchantment
		if was_suppressed:
			loadout.suppressed[upgrade] = true
		return false
	return false


func event_text() -> String:
	match data.get("node", {}).get("label"):
		"Salvage Bench": return "Copy a Common tile from your timeline or storage."
		"Traveling Smith": return "Upgrade one eligible tile to the next rarity for free."
		"Class Cache": return "Pick a category, then choose an Uncommon from your hero's deck."
		"Jammed Crane": return "A jammed lift holds a salvage crate above the roadway. The crew offers a cut if you walk away."
		"Loaded Beacon": return "A beacon is drawing a nearby clockwork patrol. Its keeper can disarm it for a fee."
		"Relay Auction": return "A relay broker offers Rare tiles in exchange for a relic."
		"Cracked Mold": return "A chipped casting mold holds a salvageable tile. A glasswright offers to buy the mold intact."
		"Smelter Relay": return "A live smelter relay is calling a Foundry patrol. Its operator can shut it off for a fee."
		"Cinder Exchange": return "A Foundry broker offers Rare tiles in exchange for a relic."
		"Steam Infirmary": return "An attendant can treat the whole expedition with the Foundry's last clean vapor tank."
		"Lenswright's Bench": return "A lenswright offers to cut a Rare tile from one of two slabs on the workbench."
		"Prism Cache": return "Heat bleeds from a half-buried cache. A scavenger will pay for its location, or you can try to open it."
		"Beacon Intercept": return "A loose banner is relaying your position to a Crown patrol. The keeper offers to jam the signal for a fee."
		"Signal Cache": return "A runner offers to buy the coordinates of a dropped signal case. Opening it yourself would trigger a ward."
		"Signal Scriptorium": return "A signalwright offers Rare tiles in exchange for a relic."
		"Signalman's Infirmary": return "The upper relay's medic can patch up both heroes for a fee."
		"Lost Dispatch": return "A courier offers two Rare tiles in exchange for the fare to recover a lost dispatch."
		"Storm Cache": return "A salvager will pay for a storm-lashed cache's location. Its contents are valuable, but the lightning ward is still live."
		"Tethered Barge": return "You pull a stranded barge back to the dock. Its crew offers you a share of the salvage, or you can leave it with them and rest aboard."
		"Rusted Foghorn": return "A rusted foghorn calls a nearby wreck patrol. The keeper can muffle it for a fee."
		"Diver's Exchange": return "A wreck diver offers Rare tiles in exchange for a relic."
		"Lifeboat Clinic": return "A lifeboat medic offers to patch up both heroes before you head out past the sea wall."
		"Pearl Diver's Bench": return "A pearl diver has two Rare tiles for sale, fresh from a wreck caught on the breakwater."
		"Storm-Tossed Crate": return "A crate keeps slamming against the pier. A deckhand offers to buy the location, or you can climb down and pry it open."
		"Broker's Table": return "A broker offers a cash wager."
		"Salvage Permit": return "The permit buys a relic you don't already carry."
		"Bounty Board": return "An elite crew has a price on its head."
	return ""


func event_options() -> Array:
	if not mystery_kind().is_empty():
		return ["Leave encounter"]
	match EVENT_KINDS.get(data.get("node", {}).get("label", "")):
		"salvage":
			var attempt := "Free the casting" if data.location == "glass" else "Free the crate"
			return ["Take 8 gold", "%s · 60%% Uncommon reward, 40%% take %s" % [attempt, _event_damage_label(0.10)]]
		"ambush": return ["Disarm it · pay 6 gold", "Fight the patrol · win a tile and 12 gold"] if int(data.gold) >= 6 else ["Walk away", "Fight the patrol · win a tile and 12 gold"]
		"trade":
			var relic: String = data.relics.front() if not data.relics.is_empty() else ""
			var label: String = RELICS.get(relic, {}).get("label", relic.capitalize())
			return ["Walk away", "Trade %s · choose a Rare tile" % label if not relic.is_empty() else "No relic to trade"]
		"infirmary": return ["Walk away", "Treat the party · pay 10 gold for 20 HP each" if int(data.gold) >= 10 else "Treatment costs 10 gold"]
		"lenswright": return ["Walk away", "Pay 14 gold · choose a Rare tile" if int(data.gold) >= 14 else "Cutting costs 14 gold"]
		"prism_cache": return ["Sell the location · gain 12 gold", "Open the cache · take %s for an Epic tile" % _event_damage_label(0.15)]
		"signal_cache": return ["Sell the coordinates · gain 14 gold", "Open the case · take %s and choose a Rare tile" % _event_damage_label(0.12)]
		"barge": return ["Take your share · gain 12 gold", "Rest aboard · recover up to 24 HP"]
		"wager": return ["Take 4 gold", "Stake 10 gold · 60% win 24 gold"]
		"permit": return ["Walk away", "Pay 24 gold · gain a random relic" if not _available_relics().is_empty() else "No relics available"]
		"bounty": return ["Walk away", "Fight an elite · tile, relic and Marks"]
	return []


func event_option_available(index: int) -> bool:
	if data.get("phase") != "event" or index not in [0, 1]:
		return false
	if index == 0:
		return true
	if not mystery_kind().is_empty():
		return false
	var kind: String = EVENT_KINDS.get(data.node.label, "")
	match kind:
		"trade": return not data.relics.is_empty()
		"infirmary": return int(data.gold) >= 10
		"lenswright": return int(data.gold) >= 14
		"wager": return int(data.gold) >= 10
		"permit": return int(data.gold) >= 24 and not _available_relics().is_empty()
	return true


func event_choice(index: int) -> bool:
	if not event_option_available(index):
		return false
	if not mystery_kind().is_empty():
		return leave_node()
	var before := data.duplicate(true)
	var kind: String = EVENT_KINDS.get(data.node.label, "")
	data.phase = "map"
	match kind:
		"salvage":
			if index == 0:
				data.gold += 8
			elif _rng(int(data.seed), _node_salt(91)).randf() < 0.6:
				data.phase = "reward"
				data.offers = _tier_rewards(_tier_pool(1), 2, 92)
			else:
				var failure := "The mold shattered." if data.location == "glass" else "The crane collapsed."
				data.node_notice = "%s Took %s." % [failure, _event_damage_label(0.10)]
				_apply_event_damage(0.10)
		"ambush":
			if index == 1:
				data.phase = "combat"
				data.node["encounter_override"] = "battle"
			elif int(data.gold) >= 6:
				data.gold -= 6
		"trade":
			if index == 1 and not data.relics.is_empty():
				var relic: String = data.relics.pop_front()
				data.node_notice = "Traded %s." % RELICS.get(relic, {}).get("label", relic.capitalize())
				data.phase = "reward"
				data.offers = _tier_rewards(_tier_pool(2), 2, 92)
		"infirmary":
			if index == 1:
				data.gold -= 10
				_heal(20)
				data.node_notice = "The party recovered up to 20 HP each."
		"lenswright":
			if index == 1:
				data.gold -= 14
				data.phase = "reward"
				data.offers = _tier_rewards(_tier_pool(2), 2, 92)
		"prism_cache":
			if index == 0:
				data.gold += 12
			else:
				data.node_notice = "The cache triggered a ward. Took %s." % _event_damage_label(0.15)
				_apply_event_damage(0.15)
				data.phase = "reward"
				data.offers = _sample(_tier_pool(3), 1, int(data.seed), _node_salt(92))
		"signal_cache":
			if index == 0:
				data.gold += 14
			else:
				data.node_notice = "The signal ward struck. Took %s." % _event_damage_label(0.12)
				_apply_event_damage(0.12)
				data.phase = "reward"
				data.offers = _tier_rewards(_tier_pool(2), 2, 92)
		"barge":
			if index == 0:
				data.gold += 12
			else:
				_heal(24)
				data.node_notice = "Resting aboard the barge restored up to 24 HP."
		"wager":
			if index == 0:
				data.gold += 4
			else:
				data.gold -= 10
				if _rng(int(data.seed), _node_salt(95)).randf() < 0.6:
					data.gold += 24
					data.node_notice = "Wager won · received 24 gold."
				else:
					data.node_notice = "Wager lost · paid 10 gold."
		"permit":
			if index == 1:
				data.gold -= 24
				var found: String = _sample(_available_relics(), 1, int(data.seed), _node_salt(96))[0]
				data.relics.append(found)
				data.node_notice = "Relic acquired: " + RELICS[found].label
		"bounty":
			if index == 1:
				data.phase = "combat"
				data.node["encounter_override"] = "elite"
	if data.phase == "combat":
		_lock_pilot_formation()
	return _save_run_change(before)


func finish_run() -> bool:
	if data.get("phase") != "result":
		return false
	return abandon_run()


func abandon_run() -> bool:
	if data.is_empty():
		return false
	var before := data
	var before_loadout := loadout
	data = {}
	loadout = {}
	return _save_run_change(before, {}, before_loadout)


func buy_meta(id: String) -> bool:
	if not META_NODES.has(id):
		return false
	var node: Dictionary = META_NODES[id]
	for prerequisite: String in node.requires:
		if prerequisite not in profile.meta:
			return false
	return _buy_unlock(id, node.cost)


func available_classes() -> Array:
	return HEROES.keys().filter(func(id: String) -> bool:
		return id in STARTING_CLASSES or _class_unlock_id(id) in profile.meta
	)


func class_unlock_cost(id: String) -> int:
	return 0 if id in STARTING_CLASSES else int(CLASS_UNLOCKS.get(id, -1))


func buy_class(id: String) -> bool:
	var cost := class_unlock_cost(id)
	return cost > 0 and _buy_unlock(_class_unlock_id(id), cost)


func _class_unlock_id(id: String) -> String:
	return "class_unlock_" + id


func _buy_unlock(id: String, cost: int) -> bool:
	if not data.is_empty() or id in profile.meta or int(profile.marks) < cost:
		return false
	profile.marks -= cost
	profile.meta.append(id)
	if save():
		return true
	profile.meta.pop_back()
	profile.marks += cost
	return false


func _make_map(seed_value: int, difficulty := "easy", location := "brass") -> Array:
	var glass := location == "glass"
	var crown := location == "crown"
	var moonwreck := location == "moonwreck"
	var seed_salt := 1
	var labels := NODE_LABELS
	var bosses := BRASS_BOSSES
	var opening := "Gate Trial"
	var first_leg := [
		["battle", "event", "battle"], ["shop", "battle", "battle"],
		["battle", "elite", "event"], ["battle", "shop", "battle"], ["rest", "rest", "rest"],
	]
	if glass:
		seed_salt = 101
		labels = GLASS_NODE_LABELS
		bosses = GLASS_BOSSES
		opening = "Cooling Gate Trial"
		first_leg = [
			["battle", "battle", "event"], ["battle", "elite", "battle"],
			["event", "shop", "battle"], ["battle", "shop", "battle"], ["rest", "rest", "rest"],
		]
	elif crown:
		seed_salt = 201
		labels = CROWN_NODE_LABELS
		bosses = CROWN_BOSSES
		opening = "Skybridge Trial"
		first_leg = [
			["battle", "shop", "event"], ["battle", "battle", "battle"],
			["battle", "elite", "shop"], ["event", "battle", "battle"], ["rest", "rest", "rest"],
		]
	elif moonwreck:
		seed_salt = 301
		labels = MOONWRECK_NODE_LABELS
		bosses = MOONWRECK_BOSSES
		opening = "Drowned Gate Trial"
		first_leg = [
			["event", "battle", "battle"], ["shop", "battle", "elite"],
			["battle", "event", "battle"], ["battle", "shop", "elite"], ["rest", "rest", "rest"],
		]
	var rng := _rng(seed_value, seed_salt)
	var layers: Array = [[_node("opening", opening, 0, 1)]]
	var used_events: Array[String] = []
	_append_layers(layers, first_leg, labels, rng, used_events)
	_mark_reinforcement_fight(layers, seed_value, seed_salt)
	var first_boss: String = bosses[0]
	var tollkeeper_variant := ""
	if location == "brass":
		_add_build_mystery(layers, seed_value)
		if _rng(seed_value, 487).randi_range(0, 3) == 0:
			first_boss = "brass_bellmaker"
		elif difficulty == "easy":
			tollkeeper_variant = "repair_drone" if _rng(seed_value, 421).randi_range(0, 1) == 1 else "solo"
	elif glass and _rng(seed_value, 587).randi_range(0, 3) == 0:
		first_boss = "glass_refraction_engine"
	_append_boss(layers, first_boss, tollkeeper_variant)
	var segments: int = SEGMENT_COUNTS[difficulty]
	for segment in range(1, segments):
		var gate := "Upper Gate Patrol" if segment == 1 else "Regent's Outer Guard"
		if glass:
			gate = "Annealing Hall" if segment == 1 else "Tempering Causeway"
		elif crown:
			gate = "High Relay Gate" if segment == 1 else "Crown Causeway"
		elif moonwreck:
			gate = "Breakwater Gate" if segment == 1 else "Blackwater Gate"
		layers.append([_node("battle", gate, layers.size(), 1)])
		var leg := [
			["battle", "event" if segment == 1 else "battle", "battle"],
			["battle", "shop", "battle"],
			["elite", "battle", "battle"],
			["shop", "battle", "battle"],
			["rest", "rest", "rest"],
		]
		var leg_labels := labels
		if glass:
			if segment == 1:
				leg = [
					["battle", "event", "shop"], ["battle", "elite", "battle"],
					["event", "shop", "battle"], ["battle", "battle", "battle"], ["rest", "rest", "rest"],
				]
				leg_labels = GLASS_UPPER_NODE_LABELS
			else:
				leg_labels = GLASS_TEMPERING_NODE_LABELS
		elif crown:
			if segment == 1:
				leg = [
					["battle", "shop", "battle"], ["elite", "battle", "event"],
					["battle", "event", "battle"], ["shop", "battle", "elite"], ["rest", "rest", "rest"],
				]
				leg_labels = CROWN_HIGH_RELAY_NODE_LABELS
			else:
				leg_labels = CROWN_REGENT_NODE_LABELS
		elif moonwreck:
			if segment == 1:
				leg = [
					["battle", "event", "battle"], ["elite", "battle", "shop"],
					["battle", "event", "elite"], ["shop", "battle", "battle"], ["rest", "rest", "rest"],
				]
				leg_labels = MOONWRECK_BREAKWATER_NODE_LABELS
			else:
				leg_labels = MOONWRECK_BLACKWATER_NODE_LABELS
		_append_layers(layers, leg, leg_labels, rng, used_events)
		var boss_id: String = bosses[segment]
		if location == "brass" and segment == 1:
			boss_id = BRASS_ACT_TWO_BOSSES[_rng(seed_value, 689).randi_range(0, BRASS_ACT_TWO_BOSSES.size() - 1)]
		_append_boss(layers, boss_id)
	if "navigation" in profile.meta:
		_add_navigation_events(layers, seed_value, seed_salt)
	for row in range(layers.size() - 1):
		for node: Dictionary in layers[row]:
			for target: Dictionary in layers[row + 1]:
				if absi(int(node.column) - int(target.column)) <= 1:
					node.next.append(target.id)
	return layers


func _add_navigation_events(layers: Array, seed_value: int, seed_salt: int) -> void:
	var sites: Array = []
	for layer: Array in layers:
		for node: Dictionary in layer:
			if node.type == "event" and not BUILD_MYSTERIES.has(node.label):
				sites.append(node)
	if sites.is_empty():
		return
	var rng := _rng(seed_value, seed_salt + 401)
	var count := rng.randi_range(1, mini(sites.size(), NAVIGATION_EVENTS.size()))
	_shuffle(sites, rng)
	var labels := _sample(NAVIGATION_EVENTS, count, seed_value, seed_salt + 402)
	for index in range(count):
		sites[index].label = labels[index]


func _add_build_mystery(first_leg: Array, seed_value: int) -> void:
	var sites: Array[Dictionary] = []
	for layer: Array in first_leg:
		for node: Dictionary in layer:
			if node.type == "event":
				sites.append(node)
	var rng := _rng(seed_value, 419)
	var variants := BUILD_MYSTERIES.keys()
	var node := sites[rng.randi_range(0, sites.size() - 1)]
	node.label = variants[rng.randi_range(0, variants.size() - 1)]


func _mark_reinforcement_fight(first_leg: Array, seed_value: int, seed_salt: int) -> void:
	var options: Array[Dictionary] = []
	for layer: Array in first_leg.slice(3, 5):
		for node: Dictionary in layer:
			if node.type == "battle":
				options.append(node)
	var rng := _rng(seed_value, seed_salt + 614)
	var fight := options[rng.randi_range(0, options.size() - 1)]
	fight.reinforcement_beat = 7 if rng.randi_range(0, 1) == 0 else 9


func _append_boss(layers: Array, id: String, variant := "") -> void:
	var boss := _node("boss", BOSS_LABELS[id], layers.size(), 1)
	boss.boss_id = id
	if not variant.is_empty():
		boss.boss_variant = variant
	layers.append([boss])


func _append_layers(layers: Array, specifications: Array, node_labels: Dictionary, rng: RandomNumberGenerator, used_events: Array[String]) -> void:
	for specification: Array in specifications:
		var kinds: Array = specification.duplicate()
		_shuffle(kinds, rng)
		var layer: Array = []
		for column in range(kinds.size()):
			var kind: String = kinds[column]
			var labels: Array = node_labels[kind].duplicate()
			if kind == "event":
				for old: String in used_events:
					labels.erase(old)
			var label: String = labels[rng.randi_range(0, labels.size() - 1)]
			if kind == "event":
				used_events.append(label)
			layer.append(_node(kind, label, layers.size(), column))
		layers.append(layer)


func _node(kind: String, label: String, row: int, column: int) -> Dictionary:
	return {"id": "%d-%d" % [row, column], "type": kind, "label": label, "row": row, "column": column, "next": []}


func _prepare_party_rewards(kind: String) -> void:
	var drafts: Array = []
	for lane in range(data.heroes.size()):
		var draft := _combat_reward_draft(kind, lane)
		drafts.append(draft)
	data.reward_lane = 0
	data.reward_remaining = drafts.slice(1)
	data.reward_gold_paid = false
	_activate_reward_draft(drafts[0])


func _combat_reward_draft(kind: String, lane: int) -> Dictionary:
	var rows := _reward_inventory(lane)
	var hero_id: String = data.heroes[lane].id
	var salt := lane * 1069
	if kind == "boss":
		var legendary := _class_reward_pool(hero_id, 4, rows)
		var signatures := _boss_signature_legendaries(hero_id)
		var ordinary := legendary.filter(func(id: String): return id not in signatures)
		var offers := _sample(ordinary, 3 if signatures.is_empty() else 2, int(data.seed), _node_salt(81 + salt))
		if not signatures.is_empty():
			offers.append(_sample(signatures, 1, int(data.seed), _node_salt(203 + salt))[0])
		return {"offers": offers, "hints": {}}
	if kind == "elite":
		var pool := _class_reward_pool(hero_id, 1, rows) + _class_reward_pool(hero_id, 2, rows) + _class_reward_pool(hero_id, 3, rows)
		var fixed: Array = []
		var first_elite := not elite_relic_offers().is_empty() and (not party_elite_relic_draft() or data.has("elite_guaranteed_tile"))
		if first_elite:
			fixed.append(ClassDecks.signature(hero_id))
		elif lane == 0 and data.node.type == "elite":
			fixed.append(_class_elite_preview_tile(data.node))
		var owned := _owned_reward(pool, 181 + salt, false, rows)
		var hints := {}
		if not owned.is_empty():
			if owned not in fixed:
				fixed.append(owned)
			hints[owned] = _copy_reward_hint(owned, rows)
		if not first_elite:
			var signature_offer := _elite_signature_offer(hero_id, lane, salt)
			if not signature_offer.is_empty() and signature_offer not in fixed:
				fixed.append(signature_offer)
		var remaining := pool.filter(func(id: String): return id not in fixed)
		fixed.append_array(_sample(remaining, 3 - fixed.size(), int(data.seed), _node_salt(81 + salt)))
		return {"offers": _sample(fixed, 3, int(data.seed), _node_salt(85 + salt)), "hints": hints}
	var signature_offer := _signature_milestone_offer(kind, lane, hero_id, salt)
	return _normal_reward_draft(lane, rows, signature_offer)


func _boss_signature_legendaries(hero_id: String) -> Array:
	if data.location != "brass" or data.difficulty != "hard" or data.segment not in [1, 2] \
			or data.node.type != "boss" or is_final_boss():
		return []
	var tiers := TilePacking.forge_tiers(ClassDecks.signature(hero_id))
	return [] if tiers.is_empty() else tiers.back()


func _elite_signature_offer(hero_id: String, lane: int, salt: int) -> String:
	var signature := ClassDecks.signature(hero_id)
	if not UniversalTileUpgrades.AUTHORED_SIGNATURES.has(signature):
		return ""
	var tiers := TilePacking.forge_tiers(signature)
	var owned_tier := _owned_signature_tier(signature, lane)
	if owned_tier >= 3:
		return ""
	return _sample(tiers[owned_tier + 1], 1, int(data.seed), _node_salt(185 + salt))[0]


func _signature_milestone_offer(kind: String, lane: int, hero_id: String, salt: int) -> String:
	if kind != "battle":
		return ""
	var signature := ClassDecks.signature(hero_id)
	var tiers := TilePacking.forge_tiers(signature)
	var owned_tier := _owned_signature_tier(signature, lane)
	if tiers.is_empty() or owned_tier >= 2:
		return ""
	var row: int = data.node.row
	if lane == 0:
		if data.get("lead_signature_offered", false):
			return ""
		var leg_one_followup := row < NODES_PER_SEGMENT and owned_tier == 1
		if not leg_one_followup and row != NODES_PER_SEGMENT:
			return ""
		data.lead_signature_offered = true
	elif row != lane * NODES_PER_SEGMENT:
		return ""
	return _sample(tiers[2], 1, int(data.seed), _node_salt(185 + salt))[0]


func _owned_signature_tier(signature: String, lane: int) -> int:
	var owned_tier := 0
	for items: Array in [loadout.lanes[lane]] + loadout.storage:
		for item: Dictionary in items:
			if ArenaSim.TILES[item.id].get("family") == signature:
				owned_tier = maxi(owned_tier, TILE_RARITIES.find(ArenaSim.TILES[item.id].rarity))
	return owned_tier


func _activate_reward_draft(draft: Dictionary) -> void:
	data.offers = draft.offers
	data.reward_hints = draft.hints


func _reward_inventory(lane: int) -> Array:
	if loadout.lanes.size() <= 1:
		return loadout.lanes + loadout.storage
	var equipped: Array = loadout.lanes[lane]
	var equipped_ids := equipped.map(func(tile: Dictionary): return tile.id)
	var shared_counts := {}
	for row: Array in loadout.storage:
		for tile: Dictionary in row:
			shared_counts[tile.id] = int(shared_counts.get(tile.id, 0)) + 1
	var rows: Array = [equipped]
	for row: Array in loadout.storage:
		rows.append(row.filter(func(tile: Dictionary): return tile.id in equipped_ids or shared_counts[tile.id] >= 2))
	return rows


func _class_forge_tier(families: Array, tier: int) -> Array:
	var pool := []
	for family: String in families:
		if forge_family_available(family):
			pool.append_array(ArenaSim.FORGE_FAMILIES[family][tier])
	return pool


func _class_reward_pool(hero_id: String, tier: int, rows: Array) -> Array:
	if tier == 0:
		var common: Array = ClassDecks.common(hero_id)
		if "curated_cache" in profile.meta and ("pull" in common or "grapple" in common):
			common.append("gravity_hook")
		return common
	var families: Array = ClassDecks.forge_families(hero_id)
	var mobility := ClassDecks.mobility_specialty(hero_id)
	if tier <= 2 and not mobility.is_empty():
		families.append(mobility)
	for items: Array in rows:
		for tile: Dictionary in items:
			var family: String = ArenaSim.TILES[tile.id].get("family", "")
			if family not in families and forge_family_available(family) and _can_draft_owned_tile(tile.id, hero_id):
				families.append(family)
	var pool := _class_forge_tier(families, tier)
	if tier == 1:
		pool.append_array(ClassDecks.uncommon(hero_id))
	if tier == 4:
		pool.append("meteor_seal")
	return pool


func _can_draft_owned_tile(id: String, hero_id: String) -> bool:
	var root: String = ArenaSim.TILES[id].get("base_tile", id)
	return not ClassDecks.is_signature(root) or root == ClassDecks.signature(hero_id)


func _standard_rewards() -> Array:
	var draft := _normal_reward_draft(0, _reward_inventory(0))
	data.reward_hints = draft.hints
	return draft.offers


func _normal_reward_draft(lane: int, rows: Array, signature_offer := "") -> Dictionary:
	var rewards: Array = []
	var hints := {}
	var hero_id: String = data.heroes[lane].id
	var directions := _early_build_directions(lane, hero_id)
	var salt := lane * 1069
	var common := _class_reward_pool(hero_id, 0, rows)
	var uncommon := _class_reward_pool(hero_id, 1, rows)
	var rare := _class_reward_pool(hero_id, 2, rows)
	var repeat_pool := common + uncommon + rare
	var held := {}
	for items: Array in rows:
		for tile: Dictionary in items:
			held[tile.id] = int(held.get(tile.id, 0)) + 1
			var rarity: String = ArenaSim.TILES[tile.id].get("rarity", "common")
			if not _can_draft_owned_tile(tile.id, hero_id):
				continue
			if rarity != "legendary" and tile.id not in repeat_pool:
				repeat_pool.append(tile.id)
	var owned := _owned_reward(repeat_pool, 83 + salt, false, rows)
	var opening_pilot: bool = not directions.is_empty() and data.node.type == "opening"
	var specialties := ClassDecks.specialties(hero_id)
	var specialty_start := _is_brass_easy() and not specialties.is_empty()
	var specialty_opening: bool = specialty_start and data.node.type == "opening"
	var starshot_opening := specialty_opening and hero_id == "starshot"
	var fresh_battle_draft: bool = specialty_start and hero_id == "starshot" and data.node.type == "battle" \
		and _rng(int(data.seed), _node_salt(87 + salt)).randi_range(0, 1) == 0
	var act := int(data.get("segment", 1))
	var party_draft := _party_battle_index()
	var established := lane + 1 < act
	var early_recruit := not established and party_draft in [0, 1]
	var recruit_draft := party_draft if early_recruit and data.get("location") == "brass" else -1
	var specialty_act: int = data.get("act_specialty_offers", {}).get(hero_id, 0)
	var offer_act_specialty: bool = party_draft >= 0 and (established or early_recruit) and specialty_act != act
	var rotating_opening: bool = lane == 0 and data.node.type == "opening" and data.get("rotating_lead_start", false)
	var prefer_new_tiles := opening_pilot or starshot_opening or fresh_battle_draft or recruit_draft == 1 or rotating_opening
	var owned_hint := _copy_reward_hint(owned, rows) if not owned.is_empty() else ""
	if not owned.is_empty() and (not prefer_new_tiles or owned_hint == "Third copy"):
		rewards.append(owned)
		hints[owned] = owned_hint
	if not directions.is_empty():
		if not signature_offer.is_empty() and signature_offer not in rewards:
			rewards.append(signature_offer)
		_add_early_build_offers(directions, held, opening_pilot, rewards, hints)
	if lane == 0 and rewards.size() < 3 and (directions.is_empty() or opening_pilot or rewards.size() < 2):
		var exclusions := rewards + held.keys() if starshot_opening or rotating_opening else rewards
		var bridge := _relic_bridge(exclusions)
		if not bridge.is_empty():
			rewards.append(bridge.tile)
			hints[bridge.tile] = bridge.hint
	if not signature_offer.is_empty() and signature_offer not in rewards:
		rewards.append(signature_offer)
	if opening_pilot and rewards.size() < 3 and not owned.is_empty() and owned not in rewards:
		rewards.append(owned)
		hints[owned] = owned_hint
	if specialty_opening and rewards.size() < 3:
		var candidates := specialties.filter(func(id: String): return not held.has(id) and id not in rewards)
		rewards.append_array(_sample(candidates, 1, int(data.seed), _node_salt(86 + salt)))
	if recruit_draft >= 0 and not offer_act_specialty and rewards.size() < 3:
		_reserve_recruit_specialty(lane, specialties, held, rewards)
	var first_roll := rewards.size()
	var rng := _rng(int(data.seed), _node_salt(84 + salt))
	while rewards.size() < 3:
		var roll := rng.randi_range(1, 100)
		var pool := common.duplicate()
		if roll > 97:
			pool = rare.duplicate()
		elif roll > 80:
			pool = uncommon.duplicate()
		for tile: String in rewards:
			pool.erase(tile)
		if pool.is_empty():
			pool = common.duplicate()
			for tile: String in rewards:
				pool.erase(tile)
		if not directions.is_empty() or starshot_opening or rotating_opening:
			var new_tiles := pool.filter(func(id: String):
				return not held.has(id) and (not starshot_opening or not held.has(ArenaSim.TILES[id].get("base_tile", id))))
			if new_tiles.is_empty() and not rotating_opening:
				new_tiles = common.filter(func(id: String): return not held.has(id) and id not in rewards)
			if not new_tiles.is_empty():
				pool = new_tiles
		rewards.append(pool[rng.randi_range(0, pool.size() - 1)])
	if lane == 0 and data.node.type == "opening" and data.get("location") == "brass" \
		and data.get("difficulty") in ["medium", "hard"]:
		_reserve_gate_specialty(specialties, held, rewards, hints, first_roll)
	if offer_act_specialty:
		var previous := _previous_recruit_specialty(lane, hero_id) if recruit_draft >= 0 else ""
		var family := _reserve_act_specialty(lane, specialties, held, rewards, hints, first_roll, established, previous)
		if not family.is_empty():
			var history: Dictionary = data.get_or_add("act_specialty_offers", {})
			history[hero_id] = act
			if recruit_draft >= 0:
				_record_recruit_specialty(hero_id, family)
	if lane == 0 and act == 1 and data.location == "brass" and data.difficulty == "hard" \
			and data.node.type == "battle" and _prior_regular_battles(1, int(data.node.row)) < 2:
		_reserve_early_class_tile(rewards, held, hints, first_roll, [common, uncommon, rare])
	return {"offers": _sample(rewards, 3, int(data.seed), _node_salt(85 + salt)), "hints": hints}


func _reserve_early_class_tile(rewards: Array, held: Dictionary, hints: Dictionary, first_roll: int, pools: Array) -> void:
	var slot := rewards.find_custom(func(id: String): return hints.get(id) == "Owned copy" and int(held.get(id, 0)) == 1)
	if slot < 0:
		slot = _replaceable_reward_roll(rewards, held, first_roll, false, true)
	if slot < 0:
		return
	var original: String = rewards[slot]
	var rarity: String = ArenaSim.TILES[original].rarity
	var tier := TILE_RARITIES.find(rarity)
	if tier < 0 or tier >= pools.size():
		return
	var other_families := rewards.map(_reward_family)
	other_families.remove_at(slot)
	var unavailable := held.keys().map(_reward_family) + other_families
	var equipped: Array = loadout.lanes[0].map(func(tile: Dictionary): return _tile_reward_traits(tile.id))
	var best: Array[String] = []
	var best_distance := 0
	for id: String in pools[tier]:
		if _reward_family(id) in unavailable or ArenaSim.TILES[id].rarity != rarity or ArenaSim.TILES[id].damage <= 0:
			continue
		var traits := _tile_reward_traits(id)
		var distance := traits.size()
		for other: Array in equipped:
			var differences := 0
			for index in range(traits.size()):
				differences += int(traits[index] != other[index])
			distance = mini(distance, differences)
		if distance > best_distance:
			best_distance = distance
			best.clear()
		if distance > 0 and distance == best_distance:
			best.append(id)
	if not best.is_empty() and original not in best:
		hints.erase(original)
		rewards[slot] = _sample(best, 1, int(data.seed), _node_salt(137))[0]


func _tile_reward_traits(id: String) -> Array[bool]:
	var spec: Dictionary = ArenaSim.TILES[id]
	var family := _reward_family(id)
	var moves := ArenaSim.is_blink_tile(id) or bool(spec.get("charge", false)) or spec.has("retreat")
	var area := family == "slam" or spec.has("radius") or spec.has("splash") or spec.has("charge_path_damage")
	var support := spec.has("guard") or spec.has("ally_guard") or spec.has("heal")
	var displaces := family == "bash" or id in ["pull", "gravity_hook"] or spec.has("push") \
		or spec.has("pull") or spec.has("isolation_pull_force") or spec.has("convergence_radius")
	return [int(spec.width) >= 3, ArenaSim.is_ranged_tile(id), moves, area, support, displaces]


func _replaceable_reward_roll(rewards: Array, held: Dictionary, first_roll: int, prefer_high := false,
		protect_signatures := false) -> int:
	var slot := -1
	var best_priority := -1
	for index in range(rewards.size() - 1, first_roll - 1, -1):
		var id: String = rewards[index]
		if int(held.get(id, 0)) >= 2 and not TilePacking.next_options(id).is_empty():
			continue
		if protect_signatures and ClassDecks.is_signature(_reward_family(id)):
			continue
		var tier := TILE_RARITIES.find(ArenaSim.TILES[id].rarity)
		var priority := tier if prefer_high else TILE_RARITIES.size() - tier
		if priority > best_priority:
			slot = index
			best_priority = priority
	return slot


func _reserve_gate_specialty(specialties: Array, held: Dictionary, rewards: Array, hints: Dictionary, first_roll: int) -> void:
	var slot := _replaceable_reward_roll(rewards, held, first_roll)
	if slot < 0:
		slot = rewards.find_custom(func(id: String): return hints.get(id) == "Owned copy")
	if slot < 0:
		return
	var tier := TILE_RARITIES.find(ArenaSim.TILES[rewards[slot]].rarity)
	var held_families := held.keys().map(_reward_family)
	var families := specialties.filter(func(family: String):
		return family not in held_families and (tier == 0 or forge_family_available(family)))
	var choice := _sample(families, 1, int(data.seed), _node_salt(86))
	if choice.is_empty():
		return
	var family: String = choice[0]
	if family in rewards.map(_reward_family):
		return
	# The Gate can introduce a specialty's forge variant at the rolled rarity.
	var pick := _sample_specialty_tile(family, tier, 88)
	if not pick.is_empty():
		hints.erase(rewards[slot])
		rewards[slot] = pick


func _reserve_act_specialty(lane: int, specialties: Array, held: Dictionary, rewards: Array, hints: Dictionary,
		first_roll: int, established: bool, previous: String) -> String:
	var slot := _replaceable_reward_roll(rewards, held, first_roll, true, true)
	if established and (slot < 0 or ArenaSim.TILES[rewards[slot]].rarity == "common"):
		var owned_upgrade := rewards.find_custom(func(id: String):
			return hints.get(id) == "Owned copy" and int(held.get(id, 0)) == 1 \
				and ArenaSim.TILES[id].rarity in ["uncommon", "rare"] and not ClassDecks.is_signature(_reward_family(id)))
		if owned_upgrade >= 0:
			slot = owned_upgrade
		else:
			return ""
	if slot < 0:
		return ""
	var tier := TILE_RARITIES.find(ArenaSim.TILES[rewards[slot]].rarity)
	var lane_items: Array = loadout.lanes[lane]
	var equipped := lane_items.map(func(item: Dictionary): return _reward_family(item.id))
	var eligible := specialties.filter(func(family: String):
		return family != previous and family not in equipped and (tier == 0 or forge_family_available(family)))
	var party_families := {}
	for items: Array in loadout.lanes + loadout.storage:
		for item: Dictionary in items:
			party_families[_reward_family(item.id)] = true
	var fresh := eligible.filter(func(family: String): return not party_families.has(family))
	var families := fresh if not fresh.is_empty() else eligible
	var offered := rewards.map(_reward_family)
	var novel := families.filter(func(family: String): return family not in offered)
	if established and novel.is_empty():
		families = families.filter(func(family: String): return rewards.any(func(id: String):
			return _reward_family(id) == family and ArenaSim.TILES[id].rarity in ["uncommon", "rare"]))
	var salt := lane * 1069
	var choice := _sample(novel if not novel.is_empty() else families, 1, int(data.seed), _node_salt(86 + salt))
	if choice.is_empty():
		return ""
	var family: String = choice[0]
	if family not in offered:
		var pick := _sample_specialty_tile(family, tier, 88 + salt)
		if pick.is_empty():
			return ""
		hints.erase(rewards[slot])
		rewards[slot] = pick
	return family


func _reward_family(id: String) -> String:
	return ArenaSim.TILES[id].get("family", id)


func _sample_specialty_tile(family: String, tier: int, salt: int) -> String:
	var options := [family] if tier == 0 else _class_forge_tier([family], tier)
	var pick := _sample(options, 1, int(data.seed), _node_salt(salt))
	return "" if pick.is_empty() else pick[0]


func _party_battle_index() -> int:
	var act := int(data.get("segment", 1))
	if act < 2 or data.get("difficulty") not in ["medium", "hard"] or data.node.type != "battle":
		return -1
	var first_row := (act - 1) * NODES_PER_SEGMENT
	var row := int(data.node.row)
	if row < first_row or row >= first_row + NODES_PER_SEGMENT:
		return -1
	return _prior_regular_battles(first_row, row)


func _prior_regular_battles(first_row: int, row: int) -> int:
	var prior_battles := 0
	for layer: Array in data.layers.slice(first_row, row):
		if layer.any(func(node: Dictionary): return node.type == "battle" and node.id in data.visited):
			prior_battles += 1
	return prior_battles


func _reserve_recruit_specialty(lane: int, specialties: Array, held: Dictionary, rewards: Array) -> void:
	var held_families := held.keys().map(_reward_family)
	var hero_id: String = data.heroes[lane].id
	var previous := _previous_recruit_specialty(lane, hero_id)
	var options := specialties.filter(func(id: String):
		return id != previous and not held_families.has(id) and id not in rewards)
	var choice := _sample(options, 1, int(data.seed), _node_salt(86 + lane * 1069))
	if not choice.is_empty():
		rewards.append(choice[0])
		_record_recruit_specialty(hero_id, choice[0])


func _previous_recruit_specialty(lane: int, hero_id: String) -> String:
	var legacy := str(data.get("recruit_specialty", data.get("starshot_recruit_specialty", ""))) if lane == 1 else ""
	return str(data.get("recruit_specialties", {}).get(hero_id, legacy))


func _record_recruit_specialty(hero_id: String, family: String) -> void:
	var history: Dictionary = data.get_or_add("recruit_specialties", {})
	history[hero_id] = family


func _early_build_directions(lane: int, hero_id: String) -> Array:
	if lane != 0 or data.get("location") != "brass" or data.get("difficulty") != "medium" \
		or data.get("segment", 1) != 1 or data.node.type not in ["opening", "battle"]:
		return []
	return EARLY_BUILD_DIRECTIONS.get(hero_id, [])


func _add_early_build_offers(directions: Array, held: Dictionary, opening: bool, rewards: Array, hints: Dictionary) -> void:
	for direction: Dictionary in directions:
		if rewards.size() == 3:
			break
		if not opening and not held.has(direction.opening):
			continue
		var tile_id: String = direction.opening if opening else direction.followup
		if held.has(tile_id) or tile_id in rewards:
			continue
		rewards.append(tile_id)
		hints[tile_id] = direction.label
		if not opening:
			break


func _copy_reward_hint(id: String, rows: Array) -> String:
	var copies := _count_matching_tiles(rows, func(tile_id: String): return tile_id == id)
	if copies == 0:
		return ""
	if copies == 2 and not TilePacking.next_options(id).is_empty():
		return "Third copy"
	return "Owned copy"


func reward_hint(id: String) -> String:
	if data.get("phase") != "reward":
		return ""
	return data.get("reward_hints", {}).get(id, "")


func _relic_bridge(excluded: Array) -> Dictionary:
	var elite := _elite_relic_bridge(excluded)
	if not elite.is_empty():
		return elite
	if data.node.type != "opening":
		return {}
	var starter: String = data.relics.front() if not data.relics.is_empty() else ""
	var candidates: Array
	var hint: String
	match starter:
		"towline_knot":
			var has_displacement := _has_build_tile(func(id: String, spec: Dictionary):
				return id in ["pull", "gravity_hook"] or spec.get("family") == "bash" or spec.has("push"))
			candidates = ["shot", "blink"] if has_displacement else ["pull", "bash"]
			hint = "Follow a push or pull" if has_displacement else "Sets up Towline Knot"
		"bridgeplate":
			var has_guard := _has_build_tile(func(id: String, spec: Dictionary):
				return spec.has("guard") or id in ["shield_ram", "bulwark_charge", "sunwall", "dawn_bastion"])
			candidates = ["shot", "bash", "slam"] if has_guard else ["guard"]
			hint = "Follow absorbed Guard" if has_guard else "Sets up Bridgeplate"
		"brass_metronome":
			candidates = ["slam", "shot", "blink"]
			hint = "Leave one beat empty before it"
		_:
			return {}
	var eligible := candidates.filter(func(id: String): return id not in excluded)
	if eligible.is_empty():
		return {}
	var id: String = eligible[0]
	return {"tile": id, "hint": hint}


func _elite_relic_bridge(excluded: Array) -> Dictionary:
	for id: String in data.relics:
		if id not in ELITE_RELICS:
			continue
		var companion: String = _elite_relic_offer(id).companion
		if companion.is_empty():
			continue
		var candidates: Array
		match id:
			"afterimage":
				candidates = ["blink"] if ArenaSim.is_blink_tile(companion) else ["bash", "shot"]
			"barrage_rack":
				candidates = ["shot", "bash"]
			"siege_fuse":
				candidates = ["slam"]
		var eligible := candidates.filter(func(tile: String): return tile not in excluded)
		if not eligible.is_empty():
			return {"tile": _sample(eligible, 1, int(data.seed), _node_salt(186))[0], "hint": "Pairs with " + RELICS[id].label}
	return {}


func _has_build_tile(matches: Callable) -> bool:
	for items: Array in loadout.lanes + loadout.storage:
		for tile: Dictionary in items:
			if matches.call(tile.id, ArenaSim.TILES[tile.id]):
				return true
	return false


func _tier_pool(tier: int) -> Array:
	var pool: Array = ArenaSim.BASH_TIERS[tier].duplicate()
	if tier == 1:
		pool.append_array(ArsenalTiles.UNCOMMON_IDS)
	if tier == 4:
		pool.append("meteor_seal")
	if _owns_slam_family():
		pool.append_array(ArenaSim.SLAM_TIERS[tier])
	pool.append_array(_specialist_pool(tier))
	return pool


func _owns_slam_family() -> bool:
	for items: Array in loadout.get("lanes", []) + loadout.get("storage", []):
		for tile: Dictionary in items:
			if ArenaSim.TILES.get(tile.id, {}).get("family") == "slam":
				return true
	return false


func forge_family_available(family: String) -> bool:
	return ArenaSim.FORGE_FAMILIES.has(family) and (not FORGE_UNLOCKS.has(family) or FORGE_UNLOCKS[family] in profile.meta)


func _specialist_pool(tier: int) -> Array:
	var pool := []
	for family: String in FORGE_UNLOCKS:
		if forge_family_available(family):
			pool.append_array(ArenaSim.FORGE_FAMILIES[family][tier])
	return pool


func _tier_rewards(pool: Array, count: int, salt: int) -> Array:
	var usual := pool.filter(func(id: String): return not FORGE_UNLOCKS.has(ArenaSim.TILES[id].get("family", "")))
	if usual.size() == pool.size():
		return _sample(pool, count, int(data.seed), _node_salt(salt))
	# Keep one original pick and leave one slot open to the full expanded pool.
	var rewards := _sample(usual, mini(usual.size(), count - 1), int(data.seed), _node_salt(salt))
	var owned := _owned_reward(pool, salt + 100)
	if rewards.size() > 1 and not owned.is_empty() and owned not in rewards:
		rewards[-1] = owned
	var remaining := pool.filter(func(id: String): return id not in rewards)
	rewards.append_array(_sample(remaining, count - rewards.size(), int(data.seed), _node_salt(salt + 101)))
	return rewards


func _shop_tiles() -> Array:
	var stock := _sample(_normal_pool(), 2, int(data.seed), _node_salt(51))
	stock.append(_sample(ArsenalTiles.UNCOMMON_IDS, 1, int(data.seed), _node_salt(55))[0])
	var upgrades := _specialist_pool(int(data.segment))
	if upgrades.is_empty():
		return stock
	var favor_owned_family := upgrades.size() <= 2 or _rng(int(data.seed), _node_salt(54)).randi_range(1, 3) != 1
	var owned := _owned_reward(upgrades, 153, favor_owned_family)
	stock.append(owned if not owned.is_empty() else _sample(upgrades, 1, int(data.seed), _node_salt(53))[0])
	return stock


func _add_shop_deck_offer() -> void:
	var prior_shops := 0
	for layer: Array in data.layers.slice(0, int(data.node.row)):
		if layer.any(func(node: Dictionary): return node.type == "shop" and node.id in data.visited):
			prior_shops += 1
	var hero_count: int = data.heroes.size()
	var offset := _rng(int(data.seed), 195).randi_range(0, hero_count - 1)
	var lane := (offset + prior_shops) % hero_count
	var hero_id: String = data.heroes[lane].id
	var rows := _reward_inventory(lane)
	var deck := _class_shop_deck(hero_id)
	var copies := _forge_copy_pool(hero_id, rows).filter(func(id: String):
		return id not in data.offers and ArenaSim.TILES[id].get("family", id) in deck)
	var copy := _owned_reward(copies, 196 + lane, false, rows)
	var unstocked := deck.filter(func(id: String): return id not in data.offers)
	var fresh := unstocked.filter(func(id: String): return _copy_reward_hint(id, rows).is_empty())
	var use_copy := not copy.is_empty() and (fresh.is_empty() or _copy_reward_hint(copy, rows) == "Third copy" \
		or _rng(int(data.seed), _node_salt(197 + lane)).randi_range(0, 1) == 0)
	var offers := [copy] if use_copy else _sample(fresh if not fresh.is_empty() else unstocked, 1,
		int(data.seed), _node_salt(198 + lane))
	if not offers.is_empty():
		var id: String = offers[0]
		data.offers.append(id)
		data.shop_deck_offer = id
		data.shop_class_offers = {id: hero_id}


func _add_class_shop_offers() -> void:
	var owners: Dictionary = data.get("shop_class_offers", {})
	for lane in range(data.heroes.size()):
		var hero_id: String = data.heroes[lane].id
		var pool := _class_shop_deck(hero_id)
		var fresh := pool.filter(func(id: String): return id not in data.offers)
		if fresh.is_empty():
			continue
		var id: String = _sample(fresh, 1, int(data.seed), _node_salt(194 + lane))[0]
		data.offers.append(id)
		owners[id] = hero_id
	data.shop_class_offers = owners


func _class_shop_deck(hero_id: String) -> Array:
	var deck := ClassDecks.common(hero_id) + ClassDecks.uncommon(hero_id)
	var mobility := ClassDecks.mobility_specialty(hero_id)
	if not mobility.is_empty():
		deck.append_array(_class_forge_tier([mobility], mini(2, int(data.segment))))
	return deck


func _forge_copy_pool(hero_id: String, rows: Array) -> Array:
	var quantities := {}
	for row: Array in rows:
		for tile: Dictionary in row:
			quantities[tile.id] = int(quantities.get(tile.id, 0)) + 1
	return quantities.keys().filter(func(id: String):
		var tile: Dictionary = ArenaSim.TILES[id]
		var tier_available: bool = tile.rarity == "common" or forge_family_available(tile.get("family", ""))
		return quantities[id] < 3 and tier_available and _can_draft_owned_tile(id, hero_id) \
			and not TilePacking.next_options(id).is_empty())


func _owned_reward(pool: Array, salt: int, favor_owned_family := true, inventory: Variant = null) -> String:
	var counts := {}
	var family_tiers := {}
	var rows: Array = loadout.lanes + loadout.storage if inventory == null else inventory
	for items: Array in rows:
		for tile: Dictionary in items:
			counts[tile.id] = int(counts.get(tile.id, 0)) + 1
			var spec: Dictionary = ArenaSim.TILES[tile.id]
			if forge_family_available(spec.get("family", "")):
				var tier := TILE_RARITIES.find(spec.rarity)
				family_tiers[spec.family] = maxi(tier, int(family_tiers.get(spec.family, -1)))
	var focused: bool = profile.meta.any(func(id: String): return id in FORGE_UNLOCKS.values())
	var prioritize_forge: bool = focused or data.get("relics", []).any(func(id: String): return id in BUILD_RELICS)
	var candidates: Array = []
	var best_priority := -1
	for id: String in counts:
		if id not in pool:
			continue
		var priority := 0
		var spec: Dictionary = ArenaSim.TILES[id]
		var established_family: bool = ArenaSim.CORE_FORGE_FAMILIES.has(spec.get("family", "")) and forge_family_available(spec.family)
		if (counts[id] == 2 or (prioritize_forge and established_family)) and counts[id] < 3 \
				and not TilePacking.next_options(id).is_empty():
			# Complete pairs first, then prefer useful copies at higher rarities.
			priority = int(counts[id]) * TILE_RARITIES.size() + TILE_RARITIES.find(spec.rarity)
		if priority > best_priority:
			candidates.clear()
			best_priority = priority
		if priority == best_priority:
			candidates.append(id)
	if best_priority <= 0 and focused and favor_owned_family:
		var family_options: Array = []
		var closest_tier := TILE_RARITIES.size() * 2
		for id: String in pool:
			var spec: Dictionary = ArenaSim.TILES[id]
			var family: String = spec.get("family", "")
			if not family_tiers.has(family) or counts.has(id):
				continue
			var offset := TILE_RARITIES.find(spec.rarity) - int(family_tiers[family])
			var distance := absi(offset) * 2 + int(offset < 0)
			if distance < closest_tier:
				family_options.clear()
				closest_tier = distance
			if distance == closest_tier:
				family_options.append(id)
		if not family_options.is_empty():
			candidates = family_options
	return "" if candidates.is_empty() else _sample(candidates, 1, int(data.seed), _node_salt(salt))[0]


func _normal_pool() -> Array:
	var pool := BASE_TILES.duplicate()
	pool.append_array(ArsenalTiles.COMMON_IDS)
	if "curated_cache" in profile.meta:
		pool.append("gravity_hook")
	return pool


func _classic_relics() -> Array:
	var pool := STARTER_RELICS.duplicate()
	if "relic_archive" in profile.meta:
		pool.append("trail_ration")
	if "wayfarers_pin" in profile.meta:
		pool.append("wayfarers_pin")
	return pool


func _available_relics() -> Array:
	var pool := _classic_relics() + BUILD_RELICS
	if _has_earned_elite_relic():
		pool.append_array(_available_elite_relics())
	for held: String in data.get("relics", []):
		pool.erase(held)
	return pool


func _available_elite_relics() -> Array:
	var pool := ELITE_RELICS.duplicate()
	if _living_heroes().size() < 2:
		pool.erase("twin_bell")
	for held: String in data.get("relics", []):
		pool.erase(held)
	return pool


func _is_offer(phase: String, id: String) -> bool:
	return data.get("phase") == phase and id in data.offers


func _grant_marks(amount: int) -> void:
	profile.marks += amount
	data.marks_earned += amount


func party_needs_healing() -> bool:
	for hero: Dictionary in data.get("heroes", []):
		if hero.hp < hero.max_hp:
			return true
	return false


func _heal(amount: int, revive := true) -> void:
	for hero: Dictionary in data.heroes:
		if revive or hero.hp > 0:
			hero.hp = mini(int(hero.max_hp), int(hero.hp) + amount)
	_sync_lead_hero()


func _event_damage(hero: Dictionary, fraction: float) -> int:
	return clampi(int(hero.hp) - 1, 0, ceili(float(hero.max_hp) * fraction))


func _event_damage_label(fraction: float) -> String:
	var hits: Array[int] = []
	var party_cost := PackedStringArray()
	for hero: Dictionary in data.heroes:
		if int(hero.hp) > 0:
			var damage := _event_damage(hero, fraction)
			hits.append(damage)
			party_cost.append("%d on %s" % [damage, HEROES[hero.id].label])
	if hits.is_empty():
		return "0 damage"
	if hits.size() == 1:
		return "%d damage" % hits[0]
	if hits.count(hits[0]) == hits.size():
		return "%d damage per living hero" % hits[0]
	return "damage (%s)" % ", ".join(party_cost)


func _apply_event_damage(fraction: float) -> void:
	for hero: Dictionary in data.heroes:
		hero.hp = int(hero.hp) - _event_damage(hero, fraction)
	_sync_lead_hero()


func _sync_lead_hero() -> void:
	data.hp = data.heroes[0].hp
	data.max_hp = data.heroes[0].max_hp


func _restore_integers() -> void:
	profile.marks = int(profile.marks)
	if data.is_empty():
		return
	for field in ["seed", "hp", "max_hp", "gold", "marks_earned"]:
		data[field] = int(data[field])
	data.difficulty = data.get("difficulty", "easy")
	data.location = data.get("location", "brass")
	data.segment = int(data.get("segment", 1))
	if not data.has("heroes"):
		data.heroes = [] if data.hero.is_empty() else [{"id": data.hero, "hp": data.hp, "max_hp": data.max_hp}]
	for hero: Dictionary in data.heroes:
		hero.hp = int(hero.hp)
		hero.max_hp = int(hero.max_hp)
	for layer: Array in data.layers:
		for node: Dictionary in layer:
			_restore_node(node)
	_restore_node(data.node)
	if not data.has("elite_relic_drafted"):
		data.elite_relic_drafted = _has_earned_elite_relic()
	if data.has("enchantment"):
		data.enchantment_drafts = _completed_enchantment_drafts()
		data.enchantments = enchantments()
		data.erase("enchantment")
	for items: Array in loadout.lanes + loadout.storage:
		for tile: Dictionary in items:
			tile.start = int(tile.start)


func _restore_empty_run_loadout() -> void:
	if data.is_empty() or data.phase in ["hero", "relic", "starter", "result"]:
		return
	for items: Array in loadout.lanes + loadout.storage:
		if not items.is_empty():
			return
	for index in mini(data.heroes.size(), loadout.lanes.size()):
		var hero: Dictionary = data.heroes[index]
		if hero.hp <= 0:
			continue
		recovered_starter = ClassDecks.starter(hero.id)
		loadout.lanes[index] = _starter_lane(recovered_starter)
		if "brass_metronome" in data.relics:
			loadout.lanes[index][0].start = 1
		return


func _restore_node(node: Dictionary) -> void:
	node.row = int(node.row)
	node.column = int(node.column)
	if node.has("reinforcement_beat"):
		node.reinforcement_beat = int(node.reinforcement_beat)
	for spawn: Dictionary in node.get("pilot_formation", []):
		spawn.delay = int(spawn.delay)
	if node.type == "boss" and not node.has("boss_id"):
		node.boss_id = BOSS_LABELS.find_key(node.label)


func _node_salt(salt: int, node := {}) -> int:
	var position: Dictionary = data.node if node.is_empty() else node
	return salt + int(position.row) * 1009 + int(position.column) * 89


func _rng(seed_value: int, salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 1000003 + salt
	return rng


func _sample(items: Array, count: int, seed_value: int, salt: int) -> Array:
	var pool := items.duplicate()
	_shuffle(pool, _rng(seed_value, salt))
	return pool.slice(0, count)


func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var item: Variant = items[i]
		items[i] = items[j]
		items[j] = item
