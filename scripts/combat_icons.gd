extends RefCounted

const PALETTE := {
	"attack": Color("#f4bc75"), "guard": Color("#85c6fa"), "health": Color("#ffa39a"),
	"heal": Color("#92e1aa"), "burn": Color("#ff9b59"), "range": Color("#8bdbce"),
	"beat": Color("#d5c4f6"), "gold": Color("#f4d287"), "mark": Color("#e4adff"),
	"slow": Color("#94b5ef"), "haste": Color("#ffe17c"), "stun": Color("#f4c79e"),
	"push": Color("#f7b990"), "pull": Color("#a9ddda"), "teleport": Color("#d5b0f5"),
	"splash": Color("#99daf5"), "windup": Color("#eead79"),
}
const LABELS := {
	"attack": "Attack damage", "guard": "Guard", "health": "Health", "heal": "Healing",
	"burn": "Burn", "range": "Reach", "beat": "Beats", "gold": "Gold", "mark": "Marked",
	"slow": "Slowed", "haste": "Haste", "stun": "Stunned", "push": "Push", "pull": "Pull",
	"teleport": "Teleport", "splash": "Splash", "windup": "Attack windup",
}
const INK := Color("#102232")
const VALUE := Color("#f0e5cf")
const HERO_COLORS := [Color("#72e5d2"), Color("#c9adff"), Color("#ffc873")]


static func hero_color(lane: int) -> Color:
	return HERO_COLORS[posmod(lane, HERO_COLORS.size())]


static func icon(id: String, extent := 18) -> Control:
	var glyph := Control.new()
	glyph.name = "%sIcon" % id.capitalize()
	glyph.custom_minimum_size = Vector2.ONE * extent
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.draw.connect(func():
		draw(glyph, id, glyph.size * 0.5, minf(extent, minf(glyph.size.x, glyph.size.y))))
	glyph.resized.connect(glyph.queue_redraw)
	return glyph


static func stat(id: String, value: String, extent := 17, detail := "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "%sStat" % id.capitalize()
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var label: String = LABELS.get(id, id.capitalize())
	row.tooltip_text = detail if not detail.is_empty() else "%s: %s" % [label, value]
	row.accessibility_name = row.tooltip_text
	row.add_theme_constant_override("separation", 3)
	row.add_child(icon(id, extent))
	var amount := Label.new()
	amount.text = value
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amount.add_theme_color_override("font_color", VALUE)
	amount.add_theme_font_size_override("font_size", maxi(12, extent - 1))
	row.add_child(amount)
	return row


static func tile_corner_stat(spec: Dictionary) -> Dictionary:
	var amounts := {"attack": int(spec.get("damage", 0)), "guard": _tile_guard(spec),
		"heal": int(spec.get("heal", 0)), "burn": int(spec.get("ember_burn_damage", 0))}
	for id: String in amounts:
		if amounts[id] > 0:
			return {"id": id, "amount": amounts[id]}
	return {}


static func add_tile_corner(button: Button, metric: Dictionary) -> void:
	if metric.is_empty():
		return
	var row := stat(metric.id, str(metric.amount), 12)
	row.name = "TileCornerStat"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 2)
	var amount := row.get_child(1) as Label
	amount.name = "TileDamage" if metric.id == "attack" else "Tile%s" % metric.id.capitalize()
	amount.add_theme_font_size_override("font_size", 11)
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 4)


static func _tile_guard(spec: Dictionary) -> int:
	for key: String in ["guard", "guard_on_hit", "guard_bonus", "bastion_party_guard", "ally_guard"]:
		if spec.has(key):
			return int(spec[key])
	return 0


static func tile_stats(spec: Dictionary, extent := 16) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "TileStats"
	row.add_theme_constant_override("separation", 8)
	row.add_child(stat("beat", str(int(spec.width)), extent, "Beats occupied: %d" % int(spec.width)))
	var damage := int(spec.get("damage", 0))
	if damage > 0:
		row.add_child(stat("attack", str(damage), extent, "Base attack damage: %d" % damage))
		var reach := float(spec.get("range", 0.0))
		if reach > 0.0:
			var value := str(roundi(reach)) if is_finite(reach) else "∞"
			row.add_child(stat("range", value, extent, "Reach in arena units: %s" % value))
	var guard := _tile_guard(spec)
	if guard > 0:
		var detail := "%d Guard on hit." % guard if spec.has("guard_on_hit") else "Guard: %d. See the tile description for recipients and conditions." % guard
		row.add_child(stat("guard", str(guard), extent, detail))
	var heal := int(spec.get("heal", 0))
	if heal > 0:
		row.add_child(stat("heal", str(heal), extent, "Restores up to %d health." % heal))
	var burn := int(spec.get("ember_burn_damage", 0))
	if burn > 0:
		var beats := int(spec.get("ember_burn_ticks", 0))
		row.add_child(stat("burn", "%d×%d" % [burn, beats], extent, "Burn: %d damage per beat for %d beats." % [burn, beats]))
	return row


static func draw(canvas: CanvasItem, id: String, center: Vector2, extent: float, tint := Color.TRANSPARENT) -> void:
	if extent <= 0.0 or not PALETTE.has(id):
		return
	var unit := extent / 18.0
	var color: Color = PALETTE[id] if tint == Color.TRANSPARENT else tint
	var shade := Color(INK, color.a)
	match id:
		"attack":
			_fill(canvas, center, unit, [Vector2(-5, 3), Vector2(3, -6), Vector2(7, -7),
				Vector2(6, -2), Vector2(-2, 6)], color)
			_line(canvas, center, unit, [Vector2(-7, 7), Vector2(-3, 3)], color, 2.6)
			_line(canvas, center, unit, [Vector2(-7, 1), Vector2(-1, 7)], color, 2.0)
		"guard":
			_fill(canvas, center, unit, [Vector2(-7, -5), Vector2(0, -8), Vector2(7, -5),
				Vector2(6, 2), Vector2(3, 6), Vector2(0, 8), Vector2(-3, 6), Vector2(-6, 2)], color)
			_line(canvas, center, unit, [Vector2(0, -5), Vector2(0, 5)], shade, 1.7)
		"health":
			_fill(canvas, center, unit, [Vector2(-8, -1), Vector2(-8, -4), Vector2(-6, -6),
				Vector2(-3, -6), Vector2(0, -3), Vector2(3, -6), Vector2(6, -6),
				Vector2(8, -4), Vector2(8, -1), Vector2(0, 7)], color)
		"heal":
			_line(canvas, center, unit, [Vector2(0, -6), Vector2(0, 6)], color, 4.7)
			_line(canvas, center, unit, [Vector2(-6, 0), Vector2(6, 0)], color, 4.7)
		"burn":
			_fill(canvas, center, unit, [Vector2(0, -8), Vector2(4, -5), Vector2(4, -2),
				Vector2(6, -4), Vector2(8, 0), Vector2(6, 5), Vector2(2, 8), Vector2(-3, 7),
				Vector2(-7, 3), Vector2(-7, -1), Vector2(-4, -5), Vector2(-3, -1)], color)
			_fill(canvas, center, unit, [Vector2(1, -1), Vector2(4, 4), Vector2(0, 7), Vector2(-3, 4)], shade)
		"range":
			_line(canvas, center, unit, [Vector2(-7, 0), Vector2(7, 0)], color)
			_line(canvas, center, unit, [Vector2(-3, -4), Vector2(-7, 0), Vector2(-3, 4)], color)
			_line(canvas, center, unit, [Vector2(3, -4), Vector2(7, 0), Vector2(3, 4)], color)
		"beat", "windup":
			canvas.draw_circle(center, 6.5 * unit, color, false, 1.85 * unit, true)
			_line(canvas, center, unit, [Vector2(0, -4), Vector2(0, 0), Vector2(3, 2)], color)
			if id == "windup":
				_line(canvas, center, unit, [Vector2(0, -8), Vector2(0, -6)], color, 2.6)
		"gold":
			canvas.draw_circle(center, 7.0 * unit, color, true, -1.0, true)
			canvas.draw_circle(center, 4.7 * unit, shade, false, 1.25 * unit, true)
			_line(canvas, center, unit, [Vector2(0, -2), Vector2(0, 2)], shade, 1.25)
		"mark":
			canvas.draw_circle(center, 5.0 * unit, color, false, 1.5 * unit, true)
			for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				_line(canvas, center, unit, [direction * 4, direction * 8], color)
			canvas.draw_circle(center, 1.7 * unit, color, true, -1.0, true)
		"slow":
			_line(canvas, center, unit, [Vector2(-6, -7), Vector2(6, -7), Vector2(4, -4),
				Vector2(0, 0), Vector2(4, 4), Vector2(6, 7), Vector2(-6, 7),
				Vector2(-4, 4), Vector2(0, 0), Vector2(-4, -4), Vector2(-6, -7)], color)
		"haste":
			_fill(canvas, center, unit, [Vector2(1, -8), Vector2(-6, 1), Vector2(-1, 1), Vector2(-3, 8),
				Vector2(6, -2), Vector2(1, -2), Vector2(4, -8)], color)
		"stun":
			_line(canvas, center, unit, [Vector2(-7, 0), Vector2(7, 0)], color)
			_line(canvas, center, unit, [Vector2(0, -7), Vector2(0, 7)], color)
			_line(canvas, center, unit, [Vector2(-4, -4), Vector2(4, 4)], color)
			_line(canvas, center, unit, [Vector2(-4, 4), Vector2(4, -4)], color)
		"push", "pull":
			var direction := 1.0 if id == "push" else -1.0
			_line(canvas, center, unit, [Vector2(-5, -5), Vector2(-5, 5)], color)
			var tip := Vector2(7, 0) if id == "push" else Vector2(-2, 0)
			_line(canvas, center, unit, [tip - Vector2(8 * direction, 0), tip], color)
			_line(canvas, center, unit, [tip - Vector2(4 * direction, 4), tip,
				tip - Vector2(4 * direction, -4)], color)
		"teleport":
			canvas.draw_arc(center, 6.4 * unit, 0.30, 5.55, 18, color, 1.9 * unit, true)
			_line(canvas, center, unit, [Vector2(-2, 3), Vector2(3, -2), Vector2(0, -2)], color)
		"splash":
			for point: Vector2 in [Vector2(-4, 3), Vector2(3, 4), Vector2(1, -4)]:
				canvas.draw_circle(center + point * unit, (2.7 if point.y < 0 else 2.1) * unit, color, true, -1.0, true)


static func _line(canvas: CanvasItem, center: Vector2, unit: float, offsets: Array, color: Color, width := 1.7) -> void:
	canvas.draw_polyline(_points(center, unit, offsets), color, width * unit, true)


static func _fill(canvas: CanvasItem, center: Vector2, unit: float, offsets: Array, color: Color) -> void:
	canvas.draw_colored_polygon(_points(center, unit, offsets), color)


static func _points(center: Vector2, unit: float, offsets: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for offset: Vector2 in offsets:
		points.append(center + offset * unit)
	return points
