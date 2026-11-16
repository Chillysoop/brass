extends SceneTree

# From the repository root:
# godot --headless --path . --script tools/class_build_audit.gd -- --output=class-audit.json
# Options: --difficulty=easy|medium|hard, --through-marshal, --as-recruit,
# --seeds=1,2,3, --classes=warden,hexwright, --upgrades
# Medium stops at the first boss by default. Hard continues to the final boss.
# Recruit audits consider natural class offers for the final party slot.
# Audits including a locked class buy the complete class roster in scratch saves.
# Drafts repack equipped tiles. --upgrades values duplicate copies, uses legal
# combines, forges at healthy camps, visits shops on even seeds, and weighs one
# paid reroll per act while keeping enough gold for an inexpensive shop tile.

const FrontierRun = preload("res://scripts/frontier_run.gd")
const ArenaSim = preload("res://scripts/arena_sim.gd")
const TilePacking = preload("res://scripts/tile_packing.gd")
const REST_FORGE_HEALTH := 0.70
const REROLL_GOLD_RESERVE := 15

const POLICIES := {
	"warden": ["guard", "knockback"],
	"hexwright": ["cluster", "isolate"],
	"duelist": ["quick", "finisher"],
	"apothecary": ["sustain", "tempo"],
	"starshot": ["mobile", "precision"],
	"bulwark": ["shelter", "heavy"],
	"breaker": ["knockback", "heavy"],
	"lancer": ["charge", "retreat"],
	"cantor": ["mark", "shelter"],
	"rune_smith": ["charged", "tempo"],
	"wayfarer": ["blink", "retreat"],
	"cinder_mage": ["cluster", "ember"],
}
const PARTNER_PRIORITY := ["warden", "hexwright", "apothecary", "starshot", "duelist"]
const ROUTE_PRIORITY := ["elite", "battle", "shop", "event", "rest", "boss"]
const ELITE_RELIC_PRIORITY := ["barrage_rack", "twin_bell", "longshot_prism", "siege_fuse", "switchback_lens", "afterimage"]
const BOSS_RELIC_PRIORITY := ["tollkeeper_signet", "bellmaker_long_echo", "bellmaker_resonant_plate"]
const SPECIALTIES := {
	"warden": ["iron_vow", "bellows_strike", "reversal_plate", "rampart_rush"],
	"hexwright": ["shrapnel", "tether_dart", "convergence_pulse", "severing_tether"],
	"duelist": ["finishing_cut", "slip_cut", "pinpoint_lunge", "vanishing_cut"],
	"apothecary": ["pilgrim_aid", "lantern_shot", "tonic_dart", "catalyst_flask"],
	"starshot": ["retreat_shot", "spark_shot", "backdraft_bolt", "parallax_shot"],
	"bulwark": ["iron_vow", "line_guard", "aegis_intercept", "shieldshock"],
	"breaker": ["bellows_strike", "rake", "domino_maul", "impact_driver"],
	"lancer": ["spur", "slip_cut", "phalanx_charge", "recoil_thrust"],
	"cantor": ["line_guard", "lantern_shot", "guard_refrain", "echo_chime"],
	"rune_smith": ["stave_crush", "tap_bolt", "hammer_stamp", "quick_etch"],
	"wayfarer": ["retreat_shot", "slip_cut", "mirror_dart", "veil_step"],
	"cinder_mage": ["furnace_burst", "bellows_strike", "cinder_brand", "wildfire_globe"],
}

var scratch := ""
var difficulty := "medium"
var through_marshal := false
var as_recruit := false
var unlock_roster := false
var audit_upgrades := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var seeds: Array = range(1, 9)
	var classes: Array = POLICIES.keys()
	var output := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
		elif arg.begins_with("--seeds="):
			seeds = Array(arg.trim_prefix("--seeds=").split(",")).map(func(value: String): return int(value))
		elif arg.begins_with("--classes="):
			classes = Array(arg.trim_prefix("--classes=").split(","))
		elif arg.begins_with("--difficulty="):
			difficulty = arg.trim_prefix("--difficulty=")
		elif arg == "--through-marshal":
			through_marshal = true
		elif arg == "--as-recruit":
			as_recruit = true
			through_marshal = true
		elif arg == "--upgrades":
			audit_upgrades = true
		else:
			printerr("Unknown audit argument: ", arg)
			quit(2)
			return
	var valid_seeds := not seeds.is_empty() and seeds.all(func(seed_value: int): return seed_value > 0)
	var valid_classes := not classes.is_empty() and classes.all(func(class_id: String): return class_id in POLICIES)
	var valid_scope := difficulty in ["easy", "medium", "hard"] and (not through_marshal or difficulty != "easy")
	if not valid_seeds or not valid_classes or not valid_scope:
		printerr("Expected positive seeds, supported classes, and a valid difficulty and recruit scope.")
		quit(2)
		return
	unlock_roster = classes.any(func(class_id: String): return class_id in FrontierRun.CLASS_UNLOCKS)
	var temp := OS.get_environment("TEMP")
	if temp.is_empty():
		temp = OS.get_environment("TMPDIR")
	if temp.is_empty():
		temp = OS.get_user_data_dir()
	scratch = temp.path_join("brass-class-audit-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	if DirAccess.make_dir_recursive_absolute(scratch) != OK:
		printerr("Cannot create scratch saves at ", scratch)
		quit(2)
		return
	var rows: Array = []
	var summary := {}
	for class_id: String in classes:
		var eligible := seeds.filter(func(seed_value: int): return not as_recruit or _natural_recruit_offer(class_id, seed_value))
		if eligible.is_empty():
			printerr("No eligible seeds for ", class_id)
			quit(2)
			return
		var class_runs := []
		for seed_value: int in eligible:
			for policy: String in POLICIES[class_id]:
				var row := _expedition(class_id, seed_value, policy)
				class_runs.append(row)
				var ending: Array = [] if row.fights.is_empty() else row.fights.back().hp
				print("%-11s %3d %-10s %-10s %s | %s" % [class_id, seed_value, policy, row.result, ending, ", ".join(row.final)])
		rows.append_array(class_runs)
		summary[class_id] = _summarize(class_id, class_runs)
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file == null:
			printerr("Cannot write audit output: ", output)
			quit(2)
			return
		file.store_string(JSON.stringify({"difficulty": difficulty, "through_marshal": through_marshal, "as_recruit": as_recruit,
			"unlocked_roster": unlock_roster, "upgrades": audit_upgrades, "seeds": seeds, "specialties": SPECIALTIES,
			"summary": summary, "runs": rows}, "\t"))
	quit(1 if rows.any(func(row: Dictionary): return row.result == "incomplete") else 0)


func _summarize(class_id: String, rows: Array) -> Dictionary:
	var early := []
	for index in range(3):
		early.append({"drafts": 0, "specialty_offered": 0, "specialty_picked": 0})
	var wins := 0
	var final_overlap := 0.0
	var paired_builds := 0
	var different_families := 0
	var reached := 0
	var upgrade_methods := {}
	var upgrade_tiers := {}
	var upgrade_branches := {}
	var paired_branch_overlap := 0.0
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		wins += int(row.result == "victory")
		reached += int(not row.final.is_empty())
		for upgrade: Dictionary in row.upgrades:
			if upgrade.lane == row.lane:
				_count(upgrade_methods, upgrade.method)
				_count(upgrade_tiers, upgrade.tier)
				_count(upgrade_branches, upgrade.branch)
		var draft_index := 0
		for draft: Dictionary in row.drafts:
			if draft.kind != "reward" or draft.lane != row.lane or draft.encounter not in ["opening", "battle"]:
				continue
			var counts: Dictionary = early[draft_index]
			counts.drafts += 1
			counts.specialty_offered += int(draft.offers.any(func(id: String): return _family(id) in SPECIALTIES[class_id]))
			counts.specialty_picked += int(_family(draft.pick) in SPECIALTIES[class_id])
			draft_index += 1
			if draft_index >= early.size():
				break
		if index % 2 != 0 or row.final.is_empty() or rows[index + 1].final.is_empty():
			continue
		var first := _families(row.final)
		var second := _families(rows[index + 1].final)
		var shared := first.keys().filter(func(id: String): return second.has(id)).size()
		var union := first.size() + second.size() - shared
		final_overlap += float(shared) / union
		var old_branches := _branched_families(row.final)
		var other_branches := _branched_families(rows[index + 1].final)
		var shared_branches := old_branches.keys().filter(func(key: String): return other_branches.has(key)).size()
		paired_branch_overlap += float(shared_branches) / (old_branches.size() + other_branches.size() - shared_branches)
		paired_builds += 1
		different_families += int(shared < union)
	var overlap := final_overlap / maxi(1, paired_builds)
	print("%s summary: %d/%d wins, early specialty drafts %s, mean final family overlap %.3f across %d paired seeds" % [
		class_id, wins, rows.size(), early, overlap, paired_builds])
	var branch_overlap := paired_branch_overlap / maxi(1, paired_builds)
	if audit_upgrades:
		print("  upgrades %s, tiers %s, branches %s, paired family and branch overlap %.3f" % [
			upgrade_methods, upgrade_tiers, upgrade_branches, branch_overlap])
	return {"wins": wins, "total": rows.size(), "reached_class": reached, "early_drafts": early, "paired_final_builds": paired_builds,
		"paired_final_family_overlap": overlap, "different_final_families": different_families,
		"paired_final_branch_overlap": branch_overlap, "upgrade_methods": upgrade_methods, "upgrade_tiers": upgrade_tiers,
		"upgrade_branches": upgrade_branches}


func _families(ids: Array) -> Dictionary:
	var result := {}
	for id: String in ids:
		result[_family(id)] = true
	return result


func _family(id: String) -> String:
	return ArenaSim.TILES.get(id, {}).get("family", id)


func _branched_families(ids: Array) -> Dictionary:
	var result := {}
	for id: String in ids:
		result["%s:%s" % [_family(id), _upgrade_branch(id)]] = true
	return result


func _upgrade_branch(id: String) -> String:
	for tier: Array in TilePacking.forge_tiers(id):
		if tier.size() == 2 and id in tier:
			return "power" if tier[0] == id else "technique"
	return "base"


func _count(counts: Dictionary, key: String, amount := 1) -> void:
	counts[key] = int(counts.get(key, 0)) + amount


func _lead_for(class_id: String) -> String:
	if not as_recruit:
		return class_id
	return "warden" if class_id == "starshot" else "starshot"


func _setup_profile(run: FrontierRun) -> bool:
	run.profile.medium_unlocked = true
	run.profile.hard_unlocked = difficulty == "hard"
	if unlock_roster:
		for id: String in FrontierRun.CLASS_UNLOCKS:
			run.profile.marks += run.class_unlock_cost(id)
		for id: String in FrontierRun.CLASS_UNLOCKS:
			if not run.buy_class(id):
				return false
	return true


func _hero_lane() -> int:
	return int(FrontierRun.SEGMENT_COUNTS[difficulty]) - 1 if as_recruit else 0


func _pick_recruit(offers: Array, class_id: String, lane: int) -> String:
	if not as_recruit:
		return _priority_pick(offers, PARTNER_PRIORITY)
	if lane == _hero_lane():
		return class_id
	return _priority_pick(offers.filter(func(id: String): return id != class_id), PARTNER_PRIORITY)


func _natural_recruit_offer(class_id: String, seed_value: int) -> bool:
	var probe := FrontierRun.new()
	probe.save_path = scratch.path_join("offer-%s-%d.json" % [class_id, seed_value])
	if not _setup_profile(probe) or not probe.start_run(seed_value, difficulty) or not probe.choose_preferred_hero(_lead_for(class_id)):
		return false
	# Use the live recruitment roll at each deterministic boss node in a scratch run.
	for lane in range(1, _hero_lane() + 1):
		probe.data.node = probe.data.layers[lane * FrontierRun.NODES_PER_SEGMENT - 1][0]
		probe._start_recruitment()
		if lane < _hero_lane():
			probe.data.heroes.append({"id": _pick_recruit(probe.data.offers, class_id, lane)})
	return class_id in probe.data.offers


func _expedition(class_id: String, seed_value: int, policy: String) -> Dictionary:
	var run := FrontierRun.new()
	run.save_path = scratch.path_join("%s-%d-%s.json" % [class_id, seed_value, policy])
	var lead := _lead_for(class_id)
	var hero_lane := _hero_lane()
	var lead_policy: String = POLICIES[lead][0] if as_recruit else policy
	var row := {"class": class_id, "seed": seed_value, "policy": policy, "lane": hero_lane, "result": "incomplete", "phase": "",
		"drafts": [], "fights": [], "route": [], "starter_trials": [], "final": [], "partner": "", "relics": [],
		"upgrades": [], "rests": [], "shops": [], "rerolls": [], "first_boss": {}}
	if not _setup_profile(run) or not run.start_run(seed_value, difficulty) \
			or not run.choose_preferred_hero(lead) or not run.choose_relic("pocket_bell"):
		return row
	var starters: Array = run.data.offers.duplicate()
	var starter: String = _best_tile(starters, lead_policy, lead, true)
	row.drafts.append({"node": "Start", "kind": "starter", "lane": 0, "hero": lead, "offers": starters, "pick": starter})
	if not run.choose_starter(starter):
		return row
	if not as_recruit and policy == POLICIES[class_id][0]:
		row.starter_trials = _starter_trials(run.encounter(), starters)
	for step in range(110):
		match run.data.phase:
			"combat":
				var encounter := run.encounter()
				if audit_upgrades and encounter.segment == 1 and encounter.encounter == "boss":
					_record_first_boss(run, row)
				var fight := _fight(run.loadout.lanes, encounter)
				fight.node = run.data.node.label
				fight.row = run.data.node.row
				row.fights.append(fight)
				if fight.result.is_empty() or not run.finish_combat(fight.result == "victory", fight.hp):
					break
				if encounter.encounter == "boss" and not through_marshal and difficulty != "hard":
					row.result = fight.result
					break
			"reward":
				var relics := run.elite_relic_offers().map(func(offer: Dictionary): return offer.id)
				if not relics.is_empty() and not run.choose_elite_relic(_priority_pick(relics, ELITE_RELIC_PRIORITY)):
					break
				var lane := maxi(0, run.reward_lane())
				var draft_policy := policy if lane == hero_lane else lead_policy if lane == 0 else "partner"
				if audit_upgrades and not _maybe_reroll(run, lane, row):
					break
				if not _claim_tile(run, lane, draft_policy, row):
					break
			"map":
				var options := run.available_nodes()
				if options.is_empty():
					break
				var node := _choose_node(options, row, run.data.segment)
				row.route.append(node.id)
				if not run.choose_node(node.id):
					break
			"boss_relic":
				if not run.choose_boss_relic(_priority_pick(run.data.offers, BOSS_RELIC_PRIORITY)):
					break
			"recruit":
				var recruit := _pick_recruit(run.data.offers, class_id, run.data.heroes.size())
				row.partner = lead if as_recruit else recruit
				if not run.choose_recruit(recruit):
					break
			"recruit_starter":
				var lane: int = run.data.heroes.size()
				var loadout := _recruit_loadout(run.recruit_loadout_offers(), policy, class_id) if lane == hero_lane else "assault"
				if not run.choose_recruit_loadout(loadout):
					break
				row.drafts.append({"node": "Recruit", "kind": "loadout", "lane": lane, "pick": loadout, "tiles": _ids(run.loadout.lanes[lane])})
			"shop":
				if not _visit_shop(run, row, policy, lead_policy):
					break
			"rest":
				if not _rest(run, row, policy, lead_policy):
					break
			"event":
				if run.mystery_kind() == "class_cache":
					if not run.mystery_choose_cache_category("damage"):
						break
				elif not run.leave_node():
					break
			"result":
				row.result = run.data.result
				break
			_:
				break
	row.phase = run.data.phase
	if hero_lane < run.loadout.lanes.size():
		row.final = _ids(run.loadout.lanes[hero_lane])
	row.relics = run.data.relics.duplicate()
	return row


func _record_first_boss(run: FrontierRun, row: Dictionary) -> void:
	var ids := _ids(run.loadout.lanes[0])
	var class_id: String = run.data.heroes[0].id
	var specialty := ids.filter(func(id: String): return _is_specialty(id, class_id) and _upgrade_branch(id) != "base")
	var stored := []
	for items: Array in run.loadout.storage:
		stored.append_array(_ids(items).filter(func(id: String): return _is_specialty(id, class_id) and _upgrade_branch(id) != "base"))
	var owned := stored.duplicate()
	for lane: Array in run.loadout.lanes:
		owned.append_array(_ids(lane).filter(func(id: String): return _is_specialty(id, class_id) and _upgrade_branch(id) != "base"))
	row.first_boss = {"node": run.data.node.label, "hero": class_id, "hp": run.data.hp, "gold": run.data.gold,
		"tiles": ids, "equipped_upgraded_specialties": specialty, "stored_upgraded_specialties": stored,
		"owned_upgraded_specialties": owned}


func _recruit_loadout(options: Array, policy: String, class_id: String) -> String:
	if not as_recruit:
		return "assault"
	var top := -INF
	var selected: String = options.front().id
	for option: Dictionary in options:
		var score := _build_score(option.tiles, policy, class_id)
		if score > top:
			top = score
			selected = option.id
	return selected


func _choose_node(options: Array, row: Dictionary, segment: int) -> Dictionary:
	if audit_upgrades and int(row.seed) % 2 == 0 and not row.shops.any(func(shop: Dictionary): return shop.segment == segment):
		for node: Dictionary in options:
			if node.type == "shop":
				return node
	for kind: String in ROUTE_PRIORITY:
		for node: Dictionary in options:
			if node.type == kind:
				return node
	return options.front()


func _is_specialty(id: String, class_id: String) -> bool:
	return _family(id) in SPECIALTIES[class_id]


func _maybe_reroll(run: FrontierRun, lane: int, row: Dictionary) -> bool:
	var segment: int = run.data.segment
	if run.data.node.type != "battle" or row.rerolls.any(func(entry: Dictionary): return entry.segment == segment):
		return true
	var price := run.reward_reroll_price()
	if price <= 0 or int(run.data.gold) < price + REROLL_GOLD_RESERVE:
		return true
	var class_id: String = run.data.heroes[lane].id
	var copies := _owned_specialties(run, lane, class_id)
	if copies.is_empty():
		return true
	var before: Array = run.data.offers.duplicate()
	if before.any(func(id: String):
		return copies.has(id) or (_is_specialty(id, class_id) and ArenaSim.TILES[id].rarity != "common")):
		return true
	var prefers_copy: bool = run.call("reward_reroll_prefers_copy") if run.has_method("reward_reroll_prefers_copy") else false
	if not run.reroll_reward():
		return run.save_error.is_empty()
	var after: Array = run.data.offers.duplicate()
	row.rerolls.append({"node": run.data.node.label, "row": run.data.node.row, "segment": segment, "lane": lane,
		"hero": class_id, "cost": price, "owned": copies, "before": before, "offers": after, "prefers_copy": prefers_copy,
		"matching": after.filter(func(id: String): return copies.has(id)),
		"upgraded_specialties": after.filter(func(id: String): return _is_specialty(id, class_id) and ArenaSim.TILES[id].rarity != "common")})
	return true


func _owned_specialties(run: FrontierRun, lane: int, class_id: String) -> Dictionary:
	var counts := {}
	for items: Array in run._reward_inventory(lane):
		for item: Dictionary in items:
			if _is_specialty(item.id, class_id) and not TilePacking.next_options(item.id).is_empty():
				_count(counts, item.id)
	return counts


func _visit_shop(run: FrontierRun, row: Dictionary, policy: String, lead_policy: String) -> bool:
	var visit := {"node": run.data.node.label, "row": run.data.node.row, "segment": run.data.segment, "stock": [], "purchase": {}}
	if audit_upgrades:
		var featured: String = run.call("shop_deck_offer_id") if run.has_method("shop_deck_offer_id") else ""
		for id: String in run.shop_stock():
			visit.stock.append({"tile": id, "owner": run.shop_class_offer_owner(id), "price": run.shop_price(id), "featured": id == featured})
		row.shops.append(visit)
	if run.data.heroes.any(func(hero: Dictionary): return hero.hp <= hero.max_hp - 15):
		if run.shop_heal() and audit_upgrades:
			visit.healed = true
	if audit_upgrades and not _shop_for_specialty(run, row, visit, policy, lead_policy):
		return false
	return run.leave_node()


func _shop_for_specialty(run: FrontierRun, row: Dictionary, visit: Dictionary, policy: String, lead_policy: String) -> bool:
	var choice := {}
	var best_gain := 5.0
	for offer: Dictionary in visit.stock:
		var id: String = offer.tile
		if int(run.data.gold) < offer.price or _storage_placement(run.loadout.storage, id).is_empty():
			continue
		for lane in range(run.data.heroes.size()):
			var class_id: String = run.data.heroes[lane].id
			if not _is_specialty(id, class_id) or (not offer.owner.is_empty() and offer.owner != class_id):
				continue
			var copies := TilePacking.find_copies(run.loadout.lanes, run.loadout.storage, id, [lane]).size()
			var lane_policy := policy if lane == row.lane else lead_policy if lane == 0 else "partner"
			var current := _ids(run.loadout.lanes[lane])
			var candidate := _best_build(current + [id], lane_policy, class_id)
			var gain := _build_score(candidate, lane_policy, class_id) - _build_score(current, lane_policy, class_id)
			gain += 5.0 * mini(copies, 2) - float(offer.price) * 0.10
			if gain > best_gain:
				best_gain = gain
				choice = offer.merged({"lane": lane, "hero": class_id, "owned_copies": copies,
					"policy": lane_policy, "equip": candidate}, true)
	if choice.is_empty():
		return true
	return _buy_specialty(run, row, visit, choice)


func _buy_specialty(run: FrontierRun, row: Dictionary, visit: Dictionary, choice: Dictionary) -> bool:
	var id: String = choice.tile
	var lane: int = choice.lane
	var before := run.loadout.duplicate(true)
	var placement := _stow(run.loadout.storage, id)
	if placement.is_empty() or not run.shop_buy(id, placement):
		run.loadout = before
		return false
	visit.purchase = {"tile": id, "rarity": ArenaSim.TILES[id].rarity, "price": choice.price, "owner": choice.owner,
		"featured": choice.featured, "lane": lane, "hero": choice.hero, "owned_copies": choice.owned_copies}
	var copies := TilePacking.find_copies(run.loadout.lanes, run.loadout.storage, id, [lane], placement)
	var merge := _merge_choice(run, lane, id, copies, 3, choice.policy, choice.hero) if copies.size() >= 3 else {}
	if not merge.is_empty():
		var draft := {"pick": id, "lane": lane, "node": visit.node}
		if not _commit_merge(run, row, draft, merge, "inventory_combine"):
			return false
		visit.purchase.upgrade = merge.tile
		return true
	# The purchase already exists in storage. Move it to the timeline only if
	# every removed tile can be stored and the chosen build actually improves it.
	var current := _ids(run.loadout.lanes[lane])
	if _build_score(choice.equip, choice.policy, choice.hero) <= _build_score(current, choice.policy, choice.hero):
		return true
	return _equip_purchase(run, lane, id, placement, choice.equip)


func _equip_purchase(run: FrontierRun, lane: int, id: String, placement: Dictionary, build: Array) -> bool:
	var before := run.loadout.duplicate(true)
	var contents: Array = run.loadout.storage[placement.row]
	var position := contents.find_custom(func(item: Dictionary): return item.start == placement.start and item.id == id)
	if position < 0:
		return false
	contents.remove_at(position)
	var displaced := _ids(run.loadout.lanes[lane]) + [id]
	for tile: String in build:
		displaced.erase(tile)
	for tile: String in displaced:
		if _stow(run.loadout.storage, tile).is_empty():
			run.loadout = before
			return true
	var entries := []
	var beat := 0
	for tile: String in build:
		entries.append(_entry(tile, beat))
		beat += int(ArenaSim.TILES[tile].width)
	run.loadout.lanes[lane] = entries
	if run.save():
		return true
	run.loadout = before
	return false


func _starter_trials(encounter: Dictionary, starters: Array) -> Array:
	var trials := []
	for id: String in starters:
		var fight := _fight([[_entry(id, 0)]], encounter)
		trials.append({"id": id, "result": fight.result, "hp": fight.hp[0], "ticks": fight.ticks,
			"misses": fight.actors[0].misses})
	return trials


func _fight(lanes: Array, encounter: Dictionary) -> Dictionary:
	var sim := ArenaSim.new()
	sim.start(lanes, "solo", encounter)
	while sim.outcome.is_empty() and sim.tick < 12000:
		sim.step()
	var actors := []
	var hp := []
	for lane in range(lanes.size()):
		var actor: Dictionary = sim.units[lane]
		hp.append(int(actor.hp))
		var stats := {"tiles": lanes[lane].duplicate(true), "damage": 0, "activation": 0, "damaging": 0, "misses": 0,
			"first_damage_tick": -1, "guard": 0, "healing": 0, "criticals": 0, "parallax_criticals": 0,
			"backdraft_hits": 0, "pushes": 0, "pulls": 0, "retreats": 0, "duel_kill_followups": 0,
			"damage_by_tile": {}, "healing_by_tile": {}, "activations_by_tile": {}, "landed_by_tile": {}, "effect_events_by_tile": {}}
		if audit_upgrades:
			stats.legendary_equipped = _ids(lanes[lane]).filter(func(id: String): return ArenaSim.TILES[id].rarity == "legendary")
		for activation: Dictionary in sim.activations:
			if int(activation.lane) != lane or activation.status == "unavailable":
				continue
			stats.activation += 1
			_count(stats.activations_by_tile, activation.tile)
			if activation.status == "landed":
				_count(stats.landed_by_tile, activation.tile)
			stats.damaging += int(activation.damage > 0)
			stats.misses += int(activation.status == "miss")
		for event: Dictionary in sim.trace:
			if event.actor != actor.id:
				continue
			var source: String = event.get("source_tile", event.tile) if audit_upgrades else event.tile
			if audit_upgrades and ArenaSim.TILES.has(source):
				_record_effect(stats.effect_events_by_tile, source, event)
			match event.kind:
				"hit":
					if int(event.amount) <= 0:
						continue
					stats.damage += int(event.amount)
					_count(stats.damage_by_tile, source, int(event.amount))
					if stats.first_damage_tick < 0:
						stats.first_damage_tick = event.tick
					stats.backdraft_hits += int(event.get("dash_followup", false))
					if event.get("critical", false):
						stats.criticals += 1
						var spec: Dictionary = ArenaSim.TILES.get(event.tile, {})
						if spec.has("long_critical_bonus") and event.from.distance_to(event.to) > ArenaSim.PRECISION_BONUS_RANGE:
							stats.parallax_criticals += 1
				"guard":
					stats.guard += int(event.amount)
				"heal":
					stats.healing += int(event.amount)
					_count(stats.healing_by_tile, source, int(event.amount))
				"push":
					stats.pushes += 1
				"pull":
					stats.pulls += 1
				"retreat":
					stats.retreats += 1
				"duel_kill_spent":
					stats.duel_kill_followups += 1
		actors.append(stats)
	return {"result": sim.outcome, "hp": hp, "ticks": sim.tick, "kind": encounter.encounter,
		"segment": encounter.segment, "boss": encounter.boss_id, "actors": actors}


func _record_effect(effects: Dictionary, source: String, event: Dictionary) -> void:
	var kind: String = event.kind
	if kind == "hit":
		if event.get("dash_followup", false):
			_count(effects.get_or_add(source, {}), "dash_followup_hit")
		if event.get("critical", false):
			_count(effects.get_or_add(source, {}), "critical_hit")
		if event.get("veil_echo", false):
			_count(effects.get_or_add(source, {}), "veil_echo_hit")
		if event.get("chorus_echo", false):
			_count(effects.get_or_add(source, {}), "chorus_echo_hit")
	elif kind not in ["miss", "intent", "movement", "death"]:
		_count(effects.get_or_add(source, {}), kind)
		if kind == "hammer_collision" and event.has("collision_depth"):
			_count(effects.get_or_add(source, {}), "hammer_collision_depth_%d" % int(event.collision_depth))


func _claim_tile(run: FrontierRun, lane: int, policy: String, row: Dictionary) -> bool:
	var offers: Array = run.data.offers.duplicate()
	var class_id: String = run.data.heroes[lane].id
	var inventory := []
	for items: Array in run._reward_inventory(lane):
		inventory.append_array(_ids(items))
	var hints := {}
	for id: String in offers:
		if not run.reward_hint(id).is_empty():
			hints[id] = run.reward_hint(id)
	var draft := {"node": run.data.node.label, "kind": "reward", "encounter": run.data.node.type,
		"segment": run.data.segment, "lane": lane, "hero": class_id, "offers": offers, "hints": hints, "owned": inventory, "pick": "skip"}
	row.drafts.append(draft)
	if run.is_final_boss():
		draft.pick = offers.front()
		draft.trophy = true
		draft.rarity = ArenaSim.TILES[draft.pick].rarity
		return run.reward(draft.pick)
	var current := _ids(run.loadout.lanes[lane])
	var current_score := _build_score(current, policy, class_id)
	var best_gain := 0.1
	var best_build := []
	var alternate := {}
	for id: String in offers:
		var candidate := _best_build(current + [id], policy, class_id)
		var gain := _build_score(candidate, policy, class_id) - current_score
		if gain > best_gain:
			best_gain = gain
			best_build = candidate
			draft.pick = id
			alternate = {}
		if audit_upgrades:
			var progression := _reward_progression(run, lane, id, policy, class_id)
			if not progression.is_empty() and progression.gain > best_gain:
				best_gain = progression.gain
				draft.pick = id
				alternate = progression
	if draft.pick == "skip":
		return run.reward("skip")
	draft.rarity = ArenaSim.TILES[draft.pick].rarity
	if alternate.has("plan"):
		return _claim_reward_merge(run, draft, row, alternate, policy, class_id)
	if alternate.has("stash"):
		var before := run.loadout.duplicate(true)
		var placement := _stow(run.loadout.storage, draft.pick)
		if not placement.is_empty() and run.reward(draft.pick, placement):
			draft.stored = placement
			return true
		run.loadout = before
		return false
	var displaced := current + [draft.pick]
	for id: String in best_build:
		displaced.erase(id)
	for id: String in displaced:
		_stow(run.loadout.storage, id)
	var entries := []
	var beat := 0
	var slot := -1
	for id: String in best_build:
		if slot < 0 and id == draft.pick:
			slot = beat
		entries.append(_entry(id, beat))
		beat += int(ArenaSim.TILES[id].width)
	run.loadout.lanes[lane] = entries
	draft.equipped = best_build
	return slot >= 0 and run.reward(draft.pick, {"lane": lane, "start": slot, "id": draft.pick})


func _reward_progression(run: FrontierRun, lane: int, id: String, policy: String, class_id: String) -> Dictionary:
	var copies := TilePacking.find_copies(run.loadout.lanes, run.loadout.storage, id, [lane])
	if copies.size() >= 2:
		return _merge_choice(run, lane, id, copies, 2, policy, class_id)
	if copies.size() == 1 and not _storage_placement(run.loadout.storage, id).is_empty():
		var spec: Dictionary = ArenaSim.TILES[id]
		# Store a matching second copy when there is no stronger immediate improvement.
		return {"stash": true, "gain": 3.5 + float(spec.width) * 0.75}
	return {}


func _merge_choice(run: FrontierRun, lane: int, id: String, copies: Array, count: int, policy: String, class_id: String) -> Dictionary:
	var current: Array = run.loadout.lanes[lane]
	var before := _build_score(_ids(current), policy, class_id)
	var best := {}
	var fitting := []
	for upgrade: String in TilePacking.next_options(id):
		var plan := TilePacking.combine_plan(run.loadout.lanes, run.loadout.storage, copies, count, upgrade, [lane], count == 3)
		if plan.is_empty():
			continue
		fitting.append(upgrade)
		var build := _ids(current)
		for copy: Dictionary in plan.copies:
			if not copy.has("row"):
				build.erase(id)
		if not plan.destination.has("row"):
			build.append(upgrade)
		var freed := float(3 * int(ArenaSim.TILES[id].width) - int(ArenaSim.TILES[upgrade].width))
		var gain := _build_score(build, policy, class_id) - before + 4.0 + maxf(0, freed)
		if best.is_empty() or gain > best.gain:
			best = {"tile": upgrade, "plan": plan, "gain": gain}
	if not best.is_empty():
		best.fitting = fitting
	return best


func _claim_reward_merge(run: FrontierRun, draft: Dictionary, row: Dictionary, chosen: Dictionary, policy: String, class_id: String) -> bool:
	var source: String = draft.pick
	var lane: int = draft.lane
	var checkpoint := run.loadout.duplicate(true)
	# Alternate equivalent entry paths across seeds. Keep the third reward as a tile
	# only if it fits and the resulting inventory still has a legal three-copy plan.
	if int(row.seed) % 2 == 0:
		var stored := _stow(run.loadout.storage, source)
		if not stored.is_empty():
			var copies := TilePacking.find_copies(run.loadout.lanes, run.loadout.storage, source, [lane], stored)
			var inventory_choice := _merge_choice(run, lane, source, copies, 3, policy, class_id)
			if not inventory_choice.is_empty() and inventory_choice.tile == chosen.tile:
				if not run.reward(source, stored):
					run.loadout = checkpoint
					return false
				return _commit_merge(run, row, draft, inventory_choice, "inventory_combine")
		run.loadout = checkpoint
	return _commit_merge(run, row, draft, chosen, "reward_combine")


func _commit_merge(run: FrontierRun, row: Dictionary, draft: Dictionary, choice: Dictionary, method: String) -> bool:
	var checkpoint := run.loadout.duplicate(true)
	var upgrade: String = choice.tile
	var plan: Dictionary = choice.plan
	if not TilePacking.apply_combination(run.loadout.lanes, run.loadout.storage, plan.copies, plan.destination,
			upgrade, ArenaSim.TILES[upgrade].targets[0]):
		return false
	var placement: Dictionary = plan.destination.duplicate()
	placement.id = upgrade
	if placement.has("row"):
		placement.erase("lane")
	var committed := run.reward(draft.pick, placement) if method == "reward_combine" else run.save()
	if not committed:
		run.loadout = checkpoint
		return false
	draft.upgrade = upgrade
	_record_upgrade(row, method, draft.pick, upgrade, draft.lane, draft.node, choice.fitting, placement)
	return true


func _rest(run: FrontierRun, row: Dictionary, policy: String, lead_policy: String) -> bool:
	var healthy: bool = run.data.heroes.all(func(hero: Dictionary): return float(hero.hp) >= float(hero.max_hp) * REST_FORGE_HEALTH)
	var forge := _camp_choice(run, int(row.lane), policy, lead_policy) if audit_upgrades and healthy else {}
	var node: String = run.data.node.label
	if forge.is_empty():
		row.rests.append({"node": node, "action": "heal"})
		return run.rest("heal")
	var checkpoint := run.loadout.duplicate(true)
	var item: Dictionary = run.loadout.lanes[forge.lane][forge.index]
	var source: String = item.id
	var upgrade: String = forge.tile
	item.id = upgrade
	if item.target not in ArenaSim.TILES[upgrade].targets:
		item.target = ArenaSim.TILES[upgrade].targets[0]
	if not run.rest("forge", "%s upgraded to %s." % [ArenaSim.TILES[source].label, ArenaSim.TILES[upgrade].label]):
		run.loadout = checkpoint
		return false
	row.rests.append({"node": node, "action": "forge"})
	_record_upgrade(row, "camp_forge", source, upgrade, forge.lane, node, forge.fitting,
		{"id": upgrade, "lane": forge.lane, "start": item.start})
	return true


func _camp_choice(run: FrontierRun, target_lane: int, policy: String, lead_policy: String) -> Dictionary:
	var best := {}
	var best_gain := 0.1
	for lane in range(run.loadout.lanes.size()):
		var items: Array = run.loadout.lanes[lane]
		var class_id: String = run.data.heroes[lane].id
		var lane_policy := policy if lane == target_lane else lead_policy if lane == 0 else "partner"
		var current := _ids(items)
		var before := _build_score(current, lane_policy, class_id)
		for index in range(items.size()):
			var item: Dictionary = items[index]
			if not run.forge_family_available(_family(item.id)):
				continue
			var fitting := TilePacking.next_options(item.id).filter(func(id: String):
				return TilePacking.can_place(items, id, item.start, ArenaSim.BEATS, item.start))
			for upgrade: String in fitting:
				var candidate := current.duplicate()
				candidate[index] = upgrade
				var gain := _build_score(candidate, lane_policy, class_id) - before
				if gain > best_gain:
					best_gain = gain
					best = {"lane": lane, "index": index, "tile": upgrade, "fitting": fitting}
	return best


func _record_upgrade(row: Dictionary, method: String, source: String, upgrade: String, lane: int, node: String,
		fitting: Array, placement: Dictionary) -> void:
	row.upgrades.append({"method": method, "source": source, "tile": upgrade, "family": _family(upgrade),
		"from_tier": ArenaSim.TILES[source].rarity, "tier": ArenaSim.TILES[upgrade].rarity, "branch": _upgrade_branch(upgrade),
		"path": ArenaSim.TILES[upgrade].get("upgrade_path", ""), "lane": lane, "node": node,
		"fitting": fitting, "placement": placement})


func _entry(id: String, start: int) -> Dictionary:
	return {"id": id, "start": start, "target": ArenaSim.TILES[id].targets[0]}


func _storage_placement(storage: Array, id: String) -> Dictionary:
	for row in range(storage.size()):
		for start in range(TilePacking.STORAGE_COLUMNS):
			if TilePacking.can_place(storage[row], id, start, TilePacking.STORAGE_COLUMNS):
				return {"row": row, "start": start, "id": id}
	return {}


func _stow(storage: Array, id: String) -> Dictionary:
	var placement := _storage_placement(storage, id)
	if not placement.is_empty():
		storage[placement.row].append(_entry(id, placement.start))
	return placement


func _ids(row: Array) -> Array:
	return row.map(func(item: Dictionary): return item.id)


func _priority_pick(offers: Array, priorities: Array) -> String:
	for id: String in priorities:
		if id in offers:
			return id
	return offers.front()


func _best_tile(offers: Array, policy: String, class_id: String, damaging: bool) -> String:
	var top := -INF
	var pick: String = offers.front()
	for id: String in offers:
		if damaging and int(ArenaSim.TILES[id].damage) <= 0:
			continue
		var width: int = ArenaSim.TILES[id].width
		var score := _tile_score(id, policy, class_id) / sqrt(float(width))
		if score > top:
			pick = id
			top = score
	return pick


func _best_build(pool: Array, policy: String, class_id: String) -> Array:
	var best_score := -INF
	var best := []
	# The last entry is the candidate reward. A rearrangement alone cannot claim it.
	var candidate_bit := 1 << (pool.size() - 1)
	for mask in range(candidate_bit, candidate_bit << 1):
		var candidate := []
		var width := 0
		for index in range(pool.size()):
			if (mask & (1 << index)) == 0:
				continue
			var id: String = pool[index]
			candidate.append(id)
			width += int(ArenaSim.TILES[id].width)
			if width > ArenaSim.BEATS:
				break
		if width > ArenaSim.BEATS:
			continue
		_order_tiles(candidate, policy)
		var score := _build_score(candidate, policy, class_id)
		if score > best_score:
			best_score = score
			best = candidate
	return best


func _order_tiles(ids: Array, policy: String) -> void:
	var lanes := ["mobile", "cluster", "guard", "sustain", "tempo", "charged", "ember", "blink"]
	if policy not in lanes:
		return
	# Place a setup tile immediately before each matching payoff when both fit.
	for payoff in ids.duplicate():
		var spec: Dictionary = ArenaSim.TILES[payoff]
		var setup := &""
		match policy:
			"mobile":
				if spec.has("dash_followup_damage"):
					setup = &"retreat"
			"cluster":
				if spec.has("displaced_bonus"):
					setup = &"pull"
			"guard":
				if spec.has("guard_bonus"):
					setup = &"guard"
			"sustain", "tempo":
				if spec.has("healing_damage_bonus"):
					setup = &"heal"
			"ember":
				if spec.has("displaced_bonus") or spec.has("ember_burn_damage"):
					setup = &"pull"
			"blink":
				if spec.has("teleport_followup_damage"):
					setup = &"blink_on_hit_retreat"
		if policy == "charged" and int(spec.width) <= 2 and int(spec.damage) > 0:
			var heavy := ids.find_custom(func(id: String): return int(ArenaSim.TILES[id].width) >= 3)
			if heavy >= 0:
				var id: String = ids.pop_at(heavy)
				ids.insert(ids.find(payoff), id)
		if setup.is_empty():
			continue
		var producer := ids.find_custom(func(id: String): return id != payoff and float(ArenaSim.TILES[id].get(setup, 0)) > 0)
		if producer < 0:
			continue
		var id: String = ids.pop_at(producer)
		ids.insert(ids.find(payoff), id)


func _build_score(ids: Array, policy: String, class_id: String) -> float:
	var score := 0.0
	var prior: String = ""
	for id: String in ids:
		score += _tile_score(id, policy, class_id)
		if not prior.is_empty():
			var setup: Dictionary = ArenaSim.TILES[prior]
			var payoff: Dictionary = ArenaSim.TILES[id]
			if payoff.has("dash_followup_damage") and int(payoff.width) <= int(payoff.dash_followup_beats):
				var chance := 0.0
				if setup.has("retreat") or setup.get("charge", false):
					chance = 0.80
				elif ArenaSim.is_ranged_tile(prior):
					chance = 0.60 * ArenaSim.critical_chance(class_id, prior, ArenaSim.PRECISION_BONUS_RANGE + 1.0)
				score += chance * float(payoff.dash_followup_damage)
			if payoff.has("displaced_bonus") and int(payoff.width) <= 3 \
					and (setup.has("pull") or setup.has("push") or setup.has("isolation_pull_force")):
				score += float(payoff.displaced_bonus) * 0.65
			if payoff.has("guard_bonus") and float(setup.get("guard", 0)) > 0:
				score += float(payoff.guard_bonus) * 0.55
			if payoff.has("healing_damage_bonus") and float(setup.get("heal", 0)) > 0:
				score += float(payoff.healing_damage_bonus) * 0.50
			if class_id == "rune_smith" and int(setup.width) >= 3 and int(payoff.width) <= 2 and int(payoff.damage) > 0:
				score += 5.0 if policy == "charged" else 2.5
			if payoff.get("charge", false) and int(payoff.width) <= int(setup.get("lance_return_beats", 0)):
				score += float(setup.get("lance_return_bonus", 0)) * 0.65
			if payoff.has("teleport_followup_damage") and _teleports(prior, setup):
				score += float(payoff.teleport_followup_damage) * 0.72
			if int(payoff.damage) > 0 and int(payoff.width) >= 3:
				score += float(setup.get("rune_heavy_bonus", 0)) * 0.65
			elif int(payoff.damage) > 0:
				score += float(setup.get("rune_quick_bonus", 0)) * 0.84
		prior = id
	return score


func _teleports(id: String, tile: Dictionary) -> bool:
	return _family(id) == "blink" or tile.get("blink_strike", false) or tile.has("blink_on_hit_retreat")


func _tile_score(id: String, policy: String, class_id: String) -> float:
	var tile: Dictionary = ArenaSim.TILES[id]
	var damage := float(tile.damage)
	var ranged := ArenaSim.is_ranged_tile(id)
	var guard := float(tile.get("guard", 0)) + 0.9 * float(tile.get("ally_guard", 0))
	var heal := float(tile.get("heal", 0))
	var low_target := float(tile.get("low_hp_bonus", 0))
	var splash := float(tile.get("splash_damage", 0))
	var displaced := float(tile.get("displaced_bonus", 0))
	var pulling := float(tile.get("pull", tile.get("isolation_pull_force", 0)))
	var pushing := float(tile.get("push", 0)) + 0.3 * float(tile.get("sweep_push_force", 0))
	var displacement := pulling + pushing
	var mark := float(tile.get("mark_bonus", 0))
	var movement_attack: bool = tile.get("charge", false) or tile.get("blink_strike", false)
	var hit_factor := 1.0 if ranged else 0.88 if movement_attack else 0.74
	var score := damage * hit_factor + guard * 0.63 + heal * 0.8 + low_target * 0.35
	score += splash * 0.43 + mark * 0.68 + float(tile.get("windup_bonus", 0)) * 0.55
	score += float(tile.get("recent_block_damage", 0)) * (0.75 if policy == "guard" else 0.45)
	score += float(tile.get("convergence_damage_per_pull", 0)) * (1.5 if policy == "cluster" else 0.65)
	score += float(tile.get("isolation_damage", 0)) * (0.72 if policy == "isolate" else 0.35)
	score += float(tile.get("repeat_target_damage", 0)) * (0.76 if policy == "quick" else 0.55)
	score += float(tile.get("duel_kill_bonus", 0)) * (0.80 if policy == "finisher" else 0.30)
	score += float(tile.get("block_wave_damage", 0)) * 0.20 + float(tile.get("charge_path_damage", 0)) * 0.40
	score += float(tile.get("chorus_mark_bonus", 0)) * 0.48 + float(tile.get("collision_bonus", 0)) * 0.28
	score += float(tile.get("distance_bonus", 0)) * (1.18 if policy == "precision" else 0.66)
	score += (2.0 if ranged and damage > 0.0 else 0.0) + minf(2.5, displacement / 180.0)
	if tile.has("long_critical_bonus"):
		var long_range_frequency := 0.8 if policy == "precision" else 0.4
		score += (damage + 5.0) * (ArenaSim.CRITICAL_DAMAGE_MULTIPLIER - 1.0) * float(tile.long_critical_bonus) * long_range_frequency
	match policy:
		"guard":
			score += guard * 0.9 + float(tile.get("guard_bonus", 0)) * 0.78
		"knockback":
			score += minf(10.0, pushing / 50.0) + displaced * 0.48
		"cluster":
			score += splash * 0.88 + displaced * 0.38 + (2.0 if tile.has("ember_burn_radius") else 0.0)
		"isolate":
			score += minf(10.0, pulling / 46.0) + displaced * 0.68 + guard * 0.32
		"quick", "tempo":
			if damage > 0.0:
				score += (5.0 if int(tile.width) == 1 else 2.5 if int(tile.width) == 2 else 0.0) + mark * 0.22
		"finisher":
			score += low_target * 1.1 + damage * 0.18
		"sustain":
			score += guard * 0.75 + heal * 1.0 + (3.0 if ranged and damage > 0.0 else 0.0)
		"mobile":
			if tile.has("retreat") or tile.get("charge", false) or tile.get("blink_strike", false) or tile.get("family") == "blink":
				score += 9.0
		"precision":
			if not tile.has("long_critical_bonus") and ("critical" in str(tile.description).to_lower() or "long-range" in str(tile.description).to_lower()):
				score += 7.0
		"partner":
			score += guard * 0.7 + minf(6.0, displacement / 60.0)
		"shelter":
			score += guard * (1.5 if tile.get("support") == "party" else 0.8) + heal * 0.4
			score += float(tile.get("intercept_guard", 0)) * 0.8 + float(tile.get("harmony_guard", 0)) * 0.6
		"heavy":
			var wide_hit := damage > 0.0 and int(tile.width) >= 3
			score += (damage * 0.21 if wide_hit else 0.0) + float(tile.get("guard_break", 0)) * 0.65
		"charge":
			score += (8.0 if tile.get("charge", false) else 0.0) + float(tile.get("lance_travel_bonus", 0)) * 0.62
		"retreat":
			var retreat := float(tile.get("retreat", tile.get("blink_on_hit_retreat", 0)))
			score += minf(9.0, retreat * 0.072) + float(tile.get("ranged_followup_bonus", 0)) * 0.7
		"mark":
			score += (mark + float(tile.get("chorus_mark_bonus", 0))) * 0.85 + float(tile.get("ally_guard", 0)) * 0.45
		"charged":
			score += 2.5 if damage > 0.0 and int(tile.width) >= 3 else 0.0
		"blink":
			score += 9.0 if _teleports(id, tile) else 0.0
		"ember":
			score += displaced * 0.82 + float(tile.get("ember_burn_damage", 0)) * 0.80 + minf(6.0, displacement / 130.0)
	if class_id == "apothecary" and damage > 0.0:
		score += 1.5
	return score
