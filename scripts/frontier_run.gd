extends RefCounted

const ArenaSim = preload("res://scripts/arena_sim.gd")
const HEROES = ArenaSim.HERO_CLASSES
const BASE_TILES := ["bash", "shot", "slam", "pull", "guard", "blink"]
const STARTER_TILES := ["bash", "shot", "slam"]
const STARTER_RELICS := ["pocket_bell", "copper_compass", "quartermasters_coin"]
const ELITE_TILES := ["shield_ram", "hook_bash", "bulwark_charge", "rebound", "sunwall", "graviton"]
const BOSS_TILES := ["dawn_bastion", "event_horizon", "meteor_seal"]
const RELICS := {
	"pocket_bell": {"label": "Pocket Bell", "description": "Gain guard at the start of each combat loop."},
	"copper_compass": {"label": "Copper Compass", "description": "Your first push each loop travels farther."},
	"quartermasters_coin": {"label": "Quartermaster's Coin", "description": "Gain 3 extra gold when you skip a combat tile reward."},
	"trail_ration": {"label": "Trail Ration", "description": "Recover 5 HP after each victory."},
}
const META_NODES := {
	"stout_start": {"label": "Stout Start", "description": "Begin each run with 8% more maximum HP.", "cost": 5, "requires": []},
	"purse": {"label": "Well-stocked Purse", "description": "Begin each run with 8 extra gold.", "cost": 5, "requires": []},
	"curated_cache": {"label": "Gravity Hook", "description": "Permanently add Gravity Hook to normal drafts and shops.", "cost": 8, "requires": ["stout_start"]},
	"relic_archive": {"label": "Relic Archive", "description": "Permanently add Trail Ration to the starter relic draft.", "cost": 8, "requires": ["purse"]},
}
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
const EVENT_KINDS := {
	"Jammed Crane": "salvage", "Loaded Beacon": "ambush", "Relay Auction": "trade",
	"Cracked Mold": "salvage", "Smelter Relay": "ambush", "Cinder Exchange": "trade",
	"Steam Infirmary": "infirmary", "Lenswright's Bench": "lenswright", "Prism Cache": "prism_cache",
}
const LOCATION_LABELS := {"brass": "Brass Frontier", "glass": "Glass Foundry"}
const BOSS_LABELS := {
	"tollkeeper": "The Tollkeeper", "gilded_marshal": "The Gilded Marshal",
	"iron_regent": "The Iron Regent", "crucible_twins": "The Crucible Twins", "prism_warden": "The Prism Warden",
	"tempered_colossus": "The Tempered Colossus",
}
const BRASS_BOSSES := ["tollkeeper", "gilded_marshal", "iron_regent"]
const GLASS_BOSSES := ["crucible_twins", "prism_warden", "tempered_colossus"]
const SEGMENT_COUNTS := {"easy": 1, "medium": 2, "hard": 3}
const DEFAULT_PROFILE := {
	"marks": 0, "medium_unlocked": false, "hard_unlocked": false, "glass_easy_unlocked": false,
	"brass_hard_cleared": false, "glass_medium_unlocked": false, "glass_hard_unlocked": false,
	"glass_hard_cleared": false, "crown_easy_unlocked": false, "meta": [],
}
const NODES_PER_SEGMENT := 7
const VERSION := 1

var data: Dictionary = {}
var loadout: Dictionary = {}
var profile: Dictionary = DEFAULT_PROFILE.duplicate(true)
var save_path := "user://frontier-save.json"
var save_error := ""


func load_save(path := "user://frontier-save.json") -> bool:
	save_path = path
	save_error = ""
	data = {}
	loadout = {}
	profile = DEFAULT_PROFILE.duplicate(true)
	for candidate in [save_path, save_path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate))
		if not parsed is Dictionary or parsed.get("version") != VERSION:
			continue
		if not parsed.get("profile") is Dictionary or not parsed.get("run") is Dictionary or not parsed.get("loadout") is Dictionary:
			continue
		profile.merge(parsed.profile, true)
		data = parsed.run
		loadout = parsed.loadout
		_restore_integers()
		return true
	return false


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
	if FileAccess.file_exists(save_path):
		if DirAccess.rename_absolute(original, backup) != OK:
			save_error = "Could not back up the Frontier save."
			return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(pending), original) != OK:
		if FileAccess.file_exists(save_path + ".bak"):
			DirAccess.rename_absolute(backup, original)
		save_error = "Could not install the Frontier save."
		return false
	save_error = ""
	return true


func start_run(seed_value := 0, difficulty := "easy", location := "brass") -> bool:
	if not data.is_empty() or not can_start(difficulty, location):
		return false
	# JSON preserves these 32-bit seeds exactly.
	var run_seed := clampi(seed_value, 1, 4294967295) if seed_value != 0 else maxi(1, int(randi()))
	var layers := _make_map(run_seed, difficulty, location)
	var hp := 100 + (8 if "stout_start" in profile.meta else 0)
	var gold := 12 + (8 if "purse" in profile.meta else 0)
	data = {
		"phase": "hero", "seed": run_seed, "difficulty": difficulty, "location": location, "segment": 1,
		"hero": "", "heroes": [], "relics": [], "hp": hp, "max_hp": hp,
		"gold": gold, "layers": layers, "node": layers[0][0], "visited": [layers[0][0].id],
		"offers": _sample(HEROES.keys(), 3, run_seed, 11), "result": "", "marks_earned": 0,
		"midpoint_paid": false, "node_notice": "",
	}
	loadout = {"lanes": [[]], "storage": [[], [], []], "defaults": ["nearest"], "suppressed": {}}
	save()
	return true


func can_start(difficulty: String, location := "brass") -> bool:
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
	if not _is_offer("hero", id):
		return false
	data.hero = id
	data.heroes.append({"id": id, "hp": data.hp, "max_hp": data.max_hp})
	data.phase = "relic"
	var pool := STARTER_RELICS.duplicate()
	if "relic_archive" in profile.meta:
		pool.append("trail_ration")
	data.offers = _sample(pool, 3, int(data.seed), 21)
	save()
	return true


func choose_relic(id: String) -> bool:
	if not _is_offer("relic", id):
		return false
	data.relics.append(id)
	data.phase = "starter"
	data.offers = _sample(STARTER_TILES, 3, int(data.seed), 31)
	save()
	return true


func choose_starter(id: String) -> bool:
	if data.get("phase") == "recruit_starter":
		return choose_recruit_starter(id)
	if not _is_offer("starter", id):
		return false
	loadout.lanes = [_starter_lane(id)]
	data.phase = "combat"
	data.offers = []
	save()
	return true


func choose_recruit(id: String) -> bool:
	if not _is_offer("recruit", id):
		return false
	data.pending_recruit = id
	data.phase = "recruit_starter"
	data.offers = _sample(STARTER_TILES, 3, int(data.seed), _node_salt(93))
	save()
	return true


func choose_recruit_starter(id: String) -> bool:
	if not _is_offer("recruit_starter", id):
		return false
	var max_hp: int = data.max_hp
	var recruit: String = data.pending_recruit
	data.heroes.append({"id": recruit, "hp": max_hp, "max_hp": max_hp})
	data.erase("pending_recruit")
	loadout.lanes.append(_starter_lane(id))
	loadout.defaults.append("nearest")
	data.segment = data.heroes.size()
	data.phase = "map"
	data.offers = []
	data.node_notice = "%s joins the expedition." % HEROES[recruit].label
	save()
	return true


func _starter_lane(id: String) -> Array:
	return [{"id": id, "start": 0, "target": ArenaSim.TILES[id].targets[0]}]


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
	data.node = selected
	data.segment = 1 + floori(float(selected.row) / NODES_PER_SEGMENT)
	data.visited.append(id)
	data.node_notice = ""
	var midpoint := floori(float(data.layers.size() - 1) / 2.0)
	if not data.midpoint_paid and int(selected.row) >= midpoint:
		data.midpoint_paid = true
		_grant_marks(1)
	match selected.type:
		"shop":
			data.phase = "shop"
			data.offers = _sample(_normal_pool(), 3, int(data.seed), _node_salt(51))
			data.shop_healed = false
			var available := _available_relics()
			data.shop_relic = "" if available.is_empty() else _sample(available, 1, int(data.seed), _node_salt(52))[0]
		"rest", "event":
			data.phase = selected.type
		_:
			data.phase = "combat"
	save()
	return true


func encounter() -> Dictionary:
	if data.get("phase") != "combat":
		return {}
	var kind: String = data.node.get("encounter_override", data.node.type)
	var roster: Array = []
	for hero: Dictionary in data.heroes:
		roster.append({"id": hero.id, "hero": hero.id, "hp": int(hero.hp), "max_hp": int(hero.max_hp)})
	return {
		"encounter": kind, "kind": kind, "id": data.node.id,
		"seed": int(data.seed) ^ _node_salt(71), "hero": data.hero, "hp": int(data.hp),
		"max_hp": int(data.max_hp), "relic": data.relics.front() if not data.relics.is_empty() else "",
		"relics": data.relics.duplicate(), "heroes": roster, "segment": data.segment,
		"difficulty": data.difficulty, "location": data.location,
		"boss_id": data.node.get("boss_id", ""), "final_boss": is_final_boss(),
	}


func is_final_boss() -> bool:
	return data.get("node", {}).get("type") == "boss" and int(data.node.row) == data.layers.size() - 1


func finish_combat(victory: bool, hp: Variant) -> bool:
	if data.get("phase") != "combat":
		return false
	var remaining: Array = hp if hp is Array else [hp]
	if remaining.size() != data.heroes.size():
		return false
	for index in range(remaining.size()):
		var hero: Dictionary = data.heroes[index]
		hero.hp = clampi(int(remaining[index]), 0, int(hero.max_hp))
	_sync_lead_hero()
	if not victory:
		data.result = "defeat"
		data.phase = "result"
		save()
		return true
	if "trail_ration" in data.relics:
		_heal(5, false)
	data.phase = "reward"
	match data.node.type:
		"boss":
			data.offers = _sample(BOSS_TILES, 3, int(data.seed), _node_salt(81))
			_resolve_boss()
		"elite":
			data.gold += 20
			_grant_marks(2)
			data.offers = _sample(ELITE_TILES, 3, int(data.seed), _node_salt(81))
			var relic_pool := _available_relics()
			if not relic_pool.is_empty():
				var found: String = _sample(relic_pool, 1, int(data.seed), _node_salt(82))[0]
				data.relics.append(found)
				data.node_notice = "Relic acquired: " + RELICS[found].label
		_:
			data.gold += 12
			data.offers = _standard_rewards()
	save()
	return true


func _resolve_boss() -> void:
	_grant_marks(4)
	if not is_final_boss():
		var rank := "second" if data.heroes.size() == 1 else "third"
		data.node_notice = "%s fell. Choose a Legendary and draft a %s hero." % [data.node.label, rank]
		return
	data.result = "victory"
	if data.location == "glass" and data.difficulty == "hard":
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


func reward(id: String) -> bool:
	if data.get("phase") != "reward" or (id != "skip" and id not in data.offers):
		return false
	if is_final_boss():
		data.trophy = "" if id == "skip" else id
		data.phase = "result"
	elif data.node.type == "boss":
		var classes := HEROES.keys()
		for hero: Dictionary in data.heroes:
			classes.erase(hero.id)
		data.phase = "recruit"
		data.offers = _sample(classes, 3, int(data.seed), _node_salt(94))
		save()
		return true
	else:
		if id == "skip":
			data.gold += 6 + (3 if "quartermasters_coin" in data.relics else 0)
		data.phase = "map"
	data.offers = []
	save()
	return true


func shop_price(id: String) -> int:
	if not ArenaSim.TILES.has(id):
		return 0
	var tile: Dictionary = ArenaSim.TILES[id]
	var rarity_price: int = {"uncommon": 7, "rare": 13, "epic": 20}.get(tile.get("rarity", "common"), 0)
	return 18 + 3 * (int(tile.width) - 2) + rarity_price


func shop_buy(id: String) -> bool:
	if not _is_offer("shop", id) or int(data.gold) < shop_price(id):
		return false
	data.gold -= shop_price(id)
	data.offers.erase(id)
	save()
	return true


func shop_heal() -> bool:
	if data.get("phase") != "shop" or data.shop_healed or int(data.gold) < 12 or not party_needs_healing():
		return false
	data.gold -= 12
	data.shop_healed = true
	_heal(15)
	save()
	return true


func shop_buy_relic() -> bool:
	if data.get("phase") != "shop" or data.get("shop_relic", "").is_empty() or int(data.gold) < 30:
		return false
	data.gold -= 30
	data.relics.append(data.shop_relic)
	data.shop_relic = ""
	save()
	return true


func leave_node() -> bool:
	if data.get("phase") not in ["shop", "rest"]:
		return false
	data.phase = "map"
	data.offers = []
	save()
	return true


func rest(action: String) -> bool:
	if data.get("phase") != "rest" or action not in ["heal", "forge"]:
		return false
	if action == "heal":
		for hero: Dictionary in data.heroes:
			hero.hp = mini(int(hero.max_hp), int(hero.hp) + ceili(float(hero.max_hp) * 0.30))
		_sync_lead_hero()
	return leave_node()


func event_text() -> String:
	match data.get("node", {}).get("label"):
		"Jammed Crane": return "A jammed lift holds a salvage crate above the roadway. The crew offers a cut if you walk away."
		"Loaded Beacon": return "A beacon is drawing a nearby clockwork patrol. Its keeper can disarm it for a fee."
		"Relay Auction": return "A relay broker will exchange your first relic for a choice of Rare tiles."
		"Cracked Mold": return "A chipped casting mold holds a salvageable tile. A glasswright offers to buy the mold intact."
		"Smelter Relay": return "A live smelter relay is calling a Foundry patrol. Its operator can shut it off for a fee."
		"Cinder Exchange": return "A Foundry broker offers a choice of Rare tiles in exchange for your first relic."
		"Steam Infirmary": return "An attendant can treat the whole expedition with the Foundry's last clean vapor tank."
		"Lenswright's Bench": return "A lenswright offers to cut a Rare tile from one of two slabs on the workbench."
		"Prism Cache": return "Heat bleeds from a half-buried cache. A scavenger will pay for its location, or you can try to open it."
	return ""


func event_options() -> Array:
	match EVENT_KINDS.get(data.get("node", {}).get("label", "")):
		"salvage":
			var attempt := "Free the casting" if data.location == "glass" else "Free the crate"
			return ["Take 8 gold", attempt + " · 60% Uncommon reward, 40% lose 10% max HP"]
		"ambush": return ["Disarm it · pay 6 gold", "Fight the patrol · win a tile and 12 gold"] if int(data.gold) >= 6 else ["Walk away", "Fight the patrol · win a tile and 12 gold"]
		"trade": return ["Walk away", "Trade first relic · choose a Rare tile" if not data.relics.is_empty() else "No relic to trade"]
		"infirmary": return ["Walk away", "Treat the party · pay 10 gold for 20 HP each" if int(data.gold) >= 10 else "Treatment costs 10 gold"]
		"lenswright": return ["Walk away", "Pay 14 gold · choose a Rare tile" if int(data.gold) >= 14 else "Cutting costs 14 gold"]
		"prism_cache": return ["Sell the location · gain 12 gold", "Open the cache · lose 15% max HP for an Epic tile"]
	return []


func event_option_available(index: int) -> bool:
	if data.get("phase") != "event" or index not in [0, 1]:
		return false
	if index == 0:
		return true
	var kind: String = EVENT_KINDS.get(data.node.label, "")
	match kind:
		"trade": return not data.relics.is_empty()
		"infirmary": return int(data.gold) >= 10
		"lenswright": return int(data.gold) >= 14
	return true


func event_choice(index: int) -> bool:
	if not event_option_available(index):
		return false
	var kind: String = EVENT_KINDS.get(data.node.label, "")
	data.phase = "map"
	match kind:
		"salvage":
			if index == 0:
				data.gold += 8
			elif _rng(int(data.seed), _node_salt(91)).randf() < 0.6:
				data.phase = "reward"
				data.offers = _sample(ELITE_TILES.slice(0, 2), 2, int(data.seed), _node_salt(92))
			else:
				_apply_event_damage(0.10)
				data.node_notice = "The mold shattered. Lost 10% of maximum HP." if data.location == "glass" else "The crane collapsed. Lost 10% of maximum HP."
		"ambush":
			if index == 1:
				data.phase = "combat"
				data.node["encounter_override"] = "battle"
			elif int(data.gold) >= 6:
				data.gold -= 6
		"trade":
			if index == 1 and not data.relics.is_empty():
				data.relics.pop_front()
				data.phase = "reward"
				data.offers = _sample(ELITE_TILES.slice(2, 4), 2, int(data.seed), _node_salt(92))
		"infirmary":
			if index == 1:
				data.gold -= 10
				_heal(20)
				data.node_notice = "The party recovered up to 20 HP each."
		"lenswright":
			if index == 1:
				data.gold -= 14
				data.phase = "reward"
				data.offers = _sample(ELITE_TILES.slice(2, 4), 2, int(data.seed), _node_salt(92))
		"prism_cache":
			if index == 0:
				data.gold += 12
			else:
				_apply_event_damage(0.15)
				data.phase = "reward"
				data.offers = _sample(ELITE_TILES.slice(4, 6), 1, int(data.seed), _node_salt(92))
				data.node_notice = "Opening the cache cost 15% of maximum HP."
	save()
	return true


func finish_run() -> bool:
	if data.get("phase") != "result":
		return false
	return abandon_run()


func abandon_run() -> bool:
	if data.is_empty():
		return false
	data = {}
	loadout = {}
	save()
	return true


func buy_meta(id: String) -> bool:
	if not data.is_empty() or not META_NODES.has(id) or id in profile.meta:
		return false
	var node: Dictionary = META_NODES[id]
	if int(profile.marks) < int(node.cost):
		return false
	for prerequisite: String in node.requires:
		if prerequisite not in profile.meta:
			return false
	profile.marks -= node.cost
	profile.meta.append(id)
	save()
	return true


func _make_map(seed_value: int, difficulty := "easy", location := "brass") -> Array:
	var glass := location == "glass"
	var rng := _rng(seed_value, 101 if glass else 1)
	var labels := GLASS_NODE_LABELS if glass else NODE_LABELS
	var layers: Array = [[_node("opening", "Cooling Gate Trial" if glass else "Gate Trial", 0, 1)]]
	var used_events: Array[String] = []
	var first_leg := [
		["battle", "event", "battle"], ["shop", "battle", "battle"],
		["battle", "elite", "event"], ["battle", "shop", "battle"], ["rest", "rest", "rest"],
	]
	if glass:
		first_leg = [
			["battle", "battle", "event"], ["battle", "elite", "battle"],
			["event", "shop", "battle"], ["battle", "shop", "battle"], ["rest", "rest", "rest"],
		]
	_append_layers(layers, first_leg, labels, rng, used_events)
	var bosses := GLASS_BOSSES if glass else BRASS_BOSSES
	_append_boss(layers, bosses[0])
	var segments: int = SEGMENT_COUNTS[difficulty]
	for segment in range(1, segments):
		var gate := "Upper Gate Patrol" if segment == 1 else "Regent's Outer Guard"
		if glass:
			gate = "Annealing Hall" if segment == 1 else "Tempering Causeway"
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
		_append_layers(layers, leg, leg_labels, rng, used_events)
		_append_boss(layers, bosses[segment])
	for row in range(layers.size() - 1):
		for node: Dictionary in layers[row]:
			for target: Dictionary in layers[row + 1]:
				if absi(int(node.column) - int(target.column)) <= 1:
					node.next.append(target.id)
	return layers


func _append_boss(layers: Array, id: String) -> void:
	var boss := _node("boss", BOSS_LABELS[id], layers.size(), 1)
	boss.boss_id = id
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


func _standard_rewards() -> Array:
	var rewards: Array = []
	var candidates: Array = []
	var available := _normal_pool() + ELITE_TILES.slice(0, 4)
	for items: Array in loadout.lanes + loadout.storage:
		for tile: Dictionary in items:
			if tile.id in available and tile.id not in candidates:
				candidates.append(tile.id)
	if not candidates.is_empty():
		rewards.append(_sample(candidates, 1, int(data.seed), _node_salt(83))[0])
	var rng := _rng(int(data.seed), _node_salt(84))
	while rewards.size() < 3:
		var roll := rng.randi_range(1, 100)
		var pool := _normal_pool()
		if roll > 97:
			pool = ELITE_TILES.slice(2, 4)
		elif roll > 80:
			pool = ELITE_TILES.slice(0, 2)
		for tile: String in rewards:
			pool.erase(tile)
		if pool.is_empty():
			pool = _normal_pool()
			for tile: String in rewards:
				pool.erase(tile)
		rewards.append(pool[rng.randi_range(0, pool.size() - 1)])
	return _sample(rewards, 3, int(data.seed), _node_salt(85))


func _normal_pool() -> Array:
	var pool := BASE_TILES.duplicate()
	if "curated_cache" in profile.meta:
		pool.append("gravity_hook")
	return pool


func _available_relics() -> Array:
	var pool := STARTER_RELICS.duplicate()
	if "relic_archive" in profile.meta:
		pool.append("trail_ration")
	for held: String in data.relics:
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


func _apply_event_damage(fraction: float) -> void:
	for hero: Dictionary in data.heroes:
		if hero.hp > 0:
			hero.hp = maxi(1, int(hero.hp) - ceili(float(hero.max_hp) * fraction))
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
	for items: Array in loadout.lanes + loadout.storage:
		for tile: Dictionary in items:
			tile.start = int(tile.start)


func _restore_node(node: Dictionary) -> void:
	node.row = int(node.row)
	node.column = int(node.column)
	if node.type == "boss" and not node.has("boss_id"):
		node.boss_id = BOSS_LABELS.find_key(node.label)


func _node_salt(salt: int) -> int:
	return salt + int(data.node.row) * 1009 + int(data.node.column) * 89


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
