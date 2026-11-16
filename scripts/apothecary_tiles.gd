extends RefCounted


static func apply_tonic(sim, actor: Dictionary, tile_id: String, tile: Dictionary) -> void:
	var recipient := actor
	var most_missing := int(actor.max_hp) - int(actor.hp)
	for hero: Dictionary in sim.units:
		if hero.side != actor.side or hero.hp <= 0:
			continue
		var missing := int(hero.max_hp) - int(hero.hp)
		if missing > most_missing:
			recipient = hero
			most_missing = missing

	var before: int = recipient.hp
	sim._heal_from_tile(actor, recipient, tile_id, tile.heal)
	var restored := int(recipient.hp) - before
	var guard: int = tile.guard
	if restored > 0:
		guard += int(tile.heal) - restored
	sim._guard_from_tile(actor, recipient, guard, tile_id)
