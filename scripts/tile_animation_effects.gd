extends RefCounted

# Sprite Fusion contact art plus original textured particle emitters. Simulation owns
# release time and real contacts. Every emission below is a local visual aftereffect.
const SpriteFusionVfx = preload("res://scripts/sprite_fusion_vfx.gd")
const Particles = preload("res://scripts/combat_particles.gd")
const GOLDEN_ANGLE := 2.39996323
const MAX_PARTICLES := 38
const BACK_MATERIALS := ["smoke", "dust"]
const SOURCE_SOCKETS := {"shot": "muzzle", "bolt": "cast", "ward": "cast", "heal": "cast", "mark": "cast",
	"guard": "cast", "slash": "blade", "spin": "blade", "thrust": "blade", "heavy": "blade"}
const ACCENT_PRIORITY := ["burn", "overflow", "echo", "harmony", "intercept", "pull", "chain", "rune", "heal", "guard",
	"pierce", "charge", "return", "mark", "crit", "finish", "repeat", "block", "windup", "travel", "ally", "splash", "push", "blink"]


static func draw_release(canvas: CanvasItem, recipe: Dictionary, start: Vector2, target: Vector2,
		arrival: Vector2, progress: float, size: float, hit: bool, footprint: Vector2, layer: String) -> void:
	if recipe.is_empty() or progress < 0.0 or progress >= 1.0:
		return
	var p := clampf(progress, 0.0, 0.999)
	var unit := clampf(size, 13.0, 55.0)
	var profile := _profile(recipe)
	if hit:
		SpriteFusionVfx.draw_release(canvas, profile, start, target, arrival, p, unit, true, footprint, layer)
	else:
		# Failed casts fizzle beside their actor, without an enormous local blast/vortex.
		var whiff := {"style": "thrust", "sprite_fusion": "impact", "color": profile.color}
		SpriteFusionVfx.draw_release(canvas, whiff, start, target, arrival, p,
			minf(25.0, unit * 0.65), false, Vector2.ZERO, layer)
	var prescription: Dictionary = recipe.get("particles", recipe.get("motif", {}).get("particles", {}))
	if prescription.is_empty():
		return
	var direction := start.direction_to(target) if start.distance_squared_to(target) > 0.01 else Vector2.RIGHT
	var family: String = recipe.get("family", "")
	var socket_name: String = SOURCE_SOCKETS.get(family, "hand")
	var source := _socket(recipe, socket_name, start - Vector2(0, unit * 0.9))
	var at := target - Vector2(0, unit * 0.8) if hit else source + direction * unit * 0.75
	if family in ["heal", "guard", "ward"]:
		at = target - Vector2(0, unit * 0.55) if hit else source
	var landing := arrival - Vector2(0, unit * 0.7)
	var rank := clampi(int(recipe.get("rank", 0)), 0, 4)
	var branch: String = recipe.get("branch", "base")
	var color: Color = recipe.get("color", Color.WHITE)
	if layer == "front":
		# At age zero, contact is already present at the actual simulation target.
		# No projectile is made to arrive after its damage has occurred.
		_contact(canvas, prescription, at, direction, p, unit, color, hit)
	_emit(canvas, prescription, source, at, landing, direction, p, unit, rank, branch, color, layer, 1.0, not hit)
	if not hit:
		return
	var layers := _accents(recipe.get("particle_layers", []))
	# Mechanics accent the base material instead of building a second giant effect.
	for index in range(mini(3, layers.size())):
		var response: Dictionary = layers[index]
		var local_size := unit * (0.57 + index * 0.045)
		_emit(canvas, response, at, at, at, direction, p, local_size, 0, "base", color, layer, 0.52)


static func _profile(recipe: Dictionary) -> Dictionary:
	return {"style": recipe.get("family", "thrust"),
		"sprite_fusion": recipe.get("sprite_fusion", "impact"),
		"color": recipe.get("color", Color.WHITE),
		"emission_sockets": recipe.get("emission_sockets", {}), "actor_origin": recipe.get("actor_origin", Vector2.ZERO)}


static func _socket(recipe: Dictionary, name: String, fallback: Vector2) -> Vector2:
	var point: Variant = recipe.get("emission_sockets", {}).get(name)
	return point if point is Vector2 else fallback


static func draw_weapon_trace(canvas: CanvasItem, profile: Dictionary, progress: float, size: float) -> void:
	if progress < 0.0 or progress >= 0.42 or profile.get("style", "") not in ["slash", "spin", "thrust", "heavy"]:
		return
	var sockets: Dictionary = profile.get("emission_sockets", {})
	var blade: Variant = sockets.get("blade")
	var hand: Variant = sockets.get("hand")
	if not blade is Vector2 or not hand is Vector2:
		return
	var phase := progress / 0.42
	var material := "spark" if profile.style == "thrust" else "slash"
	var direction: Vector2 = hand.direction_to(blade)
	var diameter := clampf(size * 1.3, 18.0, 48.0)
	var aspect := Vector2(1.65, 0.7) if material == "spark" else Vector2.ONE
	Particles.stamp(canvas, material, blade, phase * 0.85, diameter, direction.angle(),
		Particles.tint(profile.get("accent", Color.WHITE), 1.0 - phase, material), aspect)


static func _contact(canvas: CanvasItem, prescription: Dictionary, at: Vector2, direction: Vector2,
		p: float, size: float, color: Color, hit: bool) -> void:
	if p > 0.27:
		return
	var material: String = prescription.get("material", "spark")
	var fade := 1.0 - smoothstep(0.04, 0.27, p)
	# A small hot core is meaningful even for dark wisps, smoke and metallic debris.
	var core: String = "aether" if material in ["phase", "shield", "crystal", "aether", "arc"] else "spark"
	if material == "heal":
		core = "heal"
	var factor := 0.85 if hit else 0.45
	Particles.stamp(canvas, core, at, p * 2.6, size * factor, direction.angle(), Particles.tint(color, fade, core))


static func _emit(canvas: CanvasItem, spec: Dictionary, source: Vector2, at: Vector2, landing: Vector2,
		direction: Vector2, p: float, size: float, rank: int, branch: String, color: Color,
		layer: String, opacity: float, local_whiff := false) -> void:
	var gesture: String = spec.get("gesture", "pulse")
	var material: String = spec.get("material", "spark")
	var secondary: String = spec.get("secondary", material)
	var streams := clampi(int(spec.get("streams", 1)), 1, 5)
	var pulses := clampi(int(spec.get("pulses", 1)), 1, 4)
	var scatter: String = spec.get("scatter", "tight")
	var finish: String = spec.get("finish", "fall")
	var technique := branch == "technique"
	var power := branch == "power"
	var per_stream := 4 + rank
	var count := mini(MAX_PARTICLES, streams * per_stream + pulses * 2)
	var side := direction.orthogonal()
	for index in range(count):
		var secondary_particle := index % 3 == 2
		var kind := secondary if secondary_particle else material
		if (kind in BACK_MATERIALS) != (layer == "back"):
			continue
		var stream := index % streams
		var lane := float(stream) - float(streams - 1) * 0.5
		var group := int(index / streams)
		# Microvariation is shared across materials, never an identity hash or marker.
		var seed := float(index) * GOLDEN_ANGLE
		var fraction := fposmod(float(index) * 0.6180339, 1.0)
		var delay := float(group % pulses) * (0.035 + 0.015 * rank) + fraction * 0.035
		if index == 0:
			delay = 0.0
		var life := 0.64 + fraction * 0.26
		if technique:
			delay += float(group % (rank + 1)) * 0.022
			life = minf(0.96, life + 0.08)
		var q := (p - delay) / life
		if q < 0.0 or q >= 1.0:
			continue
		var travel := 1.0 - pow(1.0 - q, 2.0)
		var force := size * (0.65 + fraction * 0.8) * (1.0 + (0.09 * rank if power else 0.025 * rank))
		var across := lane / maxf(1.0, streams - 1.0)
		var spread := _scatter(scatter, seed, across)
		var pos := at
		var angle := direction.angle()
		var aspect := Vector2.ONE
		match gesture:
			"lance":
				pos += direction * force * travel * (1.5 + 0.18 * rank) + side * spread * size * 0.26
				aspect = Vector2(1.25 + fraction * 0.6, 0.75)
			"cleave":
				var sweep := angle - 1.5 + travel * (2.4 + float(pulses) * 0.18) + across * 0.55
				pos += Vector2.RIGHT.rotated(sweep) * Vector2(1.0, 0.65) * force * (0.38 + fraction * 0.55)
				angle = sweep + PI * 0.5
			"scatter":
				var ray := Vector2.RIGHT.rotated(seed + travel * across * 0.4)
				pos += ray * Vector2(1.0, 0.7) * force * travel * 1.8
				angle = ray.angle() + q * (1.8 if kind == "brass" else 0.3)
			"fan":
				var ray := direction.rotated(across * 1.3 + (fraction - 0.5) * 0.32)
				pos += ray * force * travel * (1.0 + group * 0.12)
				angle = ray.angle()
				aspect = Vector2(1.5, 0.65)
			"recoil":
				pos -= direction * force * travel * 1.5
				pos += side * (sin(q * PI) * (0.4 + fraction * 0.65) + across * 0.4) * size
				angle += PI + travel * (fraction - 0.5)
			"arc":
				pos += direction * force * travel + side * size * sin(q * PI) * (0.6 + across * 0.7)
				angle += cos(q * PI) * 0.6
			"spiral":
				var theta := seed + q * TAU * (0.7 + pulses * 0.2)
				pos += Vector2.RIGHT.rotated(theta) * Vector2(1.0, 0.64) * force * (0.15 + travel)
				angle = theta + PI * 0.5
			"tether":
				var t := fposmod(fraction + travel * 0.75, 1.0)
				pos = at.lerp(source, t) + side * sin(t * PI) * size * (0.18 + across * 0.35)
				angle = direction.angle() + PI
				aspect = Vector2(1.3, 0.7)
			"collapse":
				var theta := seed - q * TAU * 0.5
				pos += Vector2.RIGHT.rotated(theta) * Vector2(1.0, 0.62) * force * (1.5 - travel * 1.3)
				angle = theta + PI
			"drop":
				# The contact is already on screen; these are upward ejected molten fragments.
				pos += Vector2(-0.45, -1.0) * force * travel * 1.9 + side * spread * size * 0.38
				angle = -1.95 + q * fraction
				aspect = Vector2(0.7, 1.4)
			"orbit":
				var theta := seed + q * TAU * (0.35 + pulses * 0.16)
				pos += Vector2.RIGHT.rotated(theta) * Vector2(1.0, 0.58) * force * (0.6 + travel * 0.35)
				angle = theta + PI * 0.5
			"blink":
				var anchor := source if index % 2 == 0 else landing
				pos = anchor + Vector2(spread * size * 0.7, -travel * force * 1.25)
				angle += q * 0.5
			"dash":
				pos = source.lerp(landing, fraction) - direction * force * travel * 0.5 + side * spread * size * 0.36
				angle = direction.angle()
				aspect = Vector2(1.8, 0.65)
			"dome":
				var theta := -PI + fraction * PI + across * 0.22
				pos += Vector2(cos(theta), sin(theta)) * size * (0.65 + travel * 0.65)
				angle = theta + PI * 0.5
			"fountain":
				pos += Vector2(spread * size * (0.5 + travel * 0.35), -force * travel * 1.7)
				pos.x += sin(q * 4.0 + seed) * size * 0.18
				angle = sin(seed + q * 5.0) * 0.5
			_:
				var ray := Vector2.RIGHT.rotated(seed)
				pos += ray * Vector2(1.0, 0.65) * force * travel
				angle = seed + q * 0.5
		# Distinct forge routes reshape matter: Power accelerates a pressure spray;
		# Technique folds the existing stream into returning, counter-rotating wakes.
		if technique:
			match rank:
				1:
					pos += side * sin(q * PI) * size * (0.35 + fraction * 0.3)
				2:
					# Opposing strands braid through the base trajectory.
					pos += side * sin(q * TAU + stream * PI) * size * 0.52
					pos -= direction * size * q * 0.3
				3:
					# A counter-rotating wake curls around, without an outlined ring.
					pos += Vector2.RIGHT.rotated(seed - q * 5.8) * size * sin(q * PI) * 0.85
				4:
					# Matter divides and rejoins as fading wisps, never another impact.
					pos += side * sin(q * PI) * size * (0.85 if index % 2 == 0 else -0.85)
					pos = pos.lerp(at, smoothstep(0.30, 1.0, q) * 0.78)
		elif power:
			match rank:
				1:
					# The first forge tier splits a single wake into two splayed material fans.
					pos += side * (1.0 if index % 2 == 0 else -1.0) * size * (0.22 + q * 0.55)
				2:
					# Paired pressure jets peel away from the physical contact.
					pos += side * (1.0 if index % 2 == 0 else -1.0) * size * sin(q * PI) * 0.62
				3:
					# A broad ejecta fan replaces the second tier's two jets.
					pos += Vector2.RIGHT.rotated(seed) * Vector2(1.0, 0.60) * size * travel * 0.8
				4:
					# A penetrating wake has long, outward-forking textured tails.
					pos += direction * size * q * 1.1 + side * (1.0 if index % 2 == 0 else -1.0) * size * q * (0.3 + fraction * 0.6)
		pos += _finish(finish, q, size, fraction, side)
		var actual_movement: bool = gesture in ["dash", "blink"] and source.distance_to(landing) > size
		if local_whiff and not actual_movement:
			# A missed strike cannot spray long, Legendary-tier particles onto a distant victim.
			pos = source + (pos - source).limit_length(minf(36.0, size * 0.9))
		var fade := (1.0 - smoothstep(0.72, 1.0, q)) * opacity
		var diameter := size * (0.88 + fraction * 0.43) * (1.05 if kind in BACK_MATERIALS else 1.0)
		if local_whiff:
			diameter *= 0.65
		if kind in ["smoke", "dust"]:
			diameter *= 1.0 + q * 0.6
			fade *= 0.6
		Particles.stamp(canvas, kind, pos, q * 0.82, diameter, angle, Particles.tint(color, fade, kind), aspect)


static func _accents(layers: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for kind: String in ACCENT_PRIORITY:
		for response: Dictionary in layers:
			if response.get("kind", "") == kind:
				result.append(response)
				break
		if result.size() >= 3:
			break
	return result


static func _scatter(kind: String, seed: float, lane: float) -> float:
	match kind:
		"fan": return lane * 1.5
		"radial": return sin(seed) * 1.35
		"paired": return (0.65 if sin(seed) > 0.0 else -0.65) + lane * 0.25
		"column": return sin(seed) * 0.25
		_: return sin(seed) * 0.42


static func _finish(kind: String, q: float, size: float, fraction: float, side: Vector2) -> Vector2:
	match kind:
		"fall": return Vector2(0, q * q * size * (0.5 + fraction))
		"rise": return Vector2(0, -q * size * 0.9)
		"curl": return side * sin(q * TAU + fraction * PI) * size * 0.24
		"implode": return -side * sin(q * PI) * size * fraction * 0.3
		"spray": return side * (fraction - 0.5) * q * size * 0.7
		_: return Vector2.ZERO


static func draw_anticipation(canvas: CanvasItem, recipe: Dictionary, at: Vector2, facing: float,
		size: float, progress: float, _profile_color: Color, beats: float) -> void:
	if recipe.is_empty():
		return
	var p := clampf(progress, 0.0, 0.999)
	SpriteFusionVfx.draw_anticipation(canvas, at, facing, size, p, _profile(recipe), beats)
	var spec: Dictionary = recipe.get("particles", recipe.get("motif", {}).get("particles", {}))
	if spec.is_empty():
		return
	var tempo: Array = recipe.get("motif", {}).get("tempo", [0.18, 0.64, 0.9])
	var gather := smoothstep(0.0, float(tempo[0]), p)
	var focus := smoothstep(float(tempo[0]), float(tempo[1]), p)
	var ready := smoothstep(float(tempo[1]), float(tempo[2]), p)
	var long_cast := clampf((beats - 1.0) / 4.0, 0.0, 1.0)
	var hand := _socket(recipe, "cast" if recipe.get("family", "") in ["bolt", "ward", "heal", "mark", "guard"] else "hand", at + Vector2(facing * size * 0.26, -size * 0.55))
	var material: String = spec.get("material", "spark")
	var color: Color = recipe.get("color", Color.WHITE)
	var streams := clampi(int(spec.get("streams", 1)), 1, 5)
	var count := 3 + streams + int(long_cast * 6.0)
	for index in range(count):
		var fraction := float(index + 1) / (count + 1)
		var theta := index * GOLDEN_ANGLE + p * (1.3 if spec.gesture in ["orbit", "spiral", "collapse"] else 0.4)
		var distance := size * (0.18 + (1.0 - focus) * 0.45) * (0.45 + fraction * 0.55)
		var mote := hand + Vector2.RIGHT.rotated(theta) * Vector2(1.0, 0.7) * distance
		mote.y -= long_cast * ready * size * fraction * 0.12
		var alpha := (0.18 + gather * 0.18 + focus * 0.25 + ready * 0.23) * (0.5 + fraction * 0.5)
		Particles.stamp(canvas, material, mote, fposmod(p * (0.7 + fraction * 0.4) + fraction, 0.83),
			size * (0.11 + focus * 0.07 + ready * 0.05), theta, Particles.tint(color, alpha, material))


static func draw_secondary_contact(canvas: CanvasItem, profile: Dictionary, at: Vector2,
		progress: float, size: float) -> void:
	var color: Color = profile.get("color", Color.WHITE)
	var material := "heal" if profile.get("style", "") == "heal" else "spark"
	for index in range(5):
		var theta := index * GOLDEN_ANGLE
		var pos := at + Vector2.RIGHT.rotated(theta) * Vector2(1.0, 0.65) * size * progress * 0.7
		Particles.stamp(canvas, material, pos, progress, size * 0.6, theta,
			Particles.tint(color, 1.0 - progress, material))


static func draw_support_link(canvas: CanvasItem, start: Vector2, end: Vector2,
		color: Color, icon: String, phase: float) -> void:
	var material := "heal" if icon == "heal" else "aether"
	for index in range(6):
		var t := fposmod(phase + float(index) / 6.0, 1.0)
		var at := start.lerp(end, t) - Vector2(0, sin(t * PI) * 10.0)
		Particles.stamp(canvas, material, at, t * 0.65, 15.0, 0.0,
			Particles.tint(color, color.a * sin(t * PI) * 0.7, material))
