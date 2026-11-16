extends RefCounted

const HINT_COLOR := Color("#9ddbd1")
const DEFINITIONS := {
	"guard": "Takes incoming damage before your HP does.",
	"strip": "Removes existing Guard before dealing damage.",
	"mark": "Sets up a bonus for a follow-up hit before the mark expires.",
	"push": "Knocks the target away from the attacker.",
	"pull": "Drags the target toward the attacker.",
	"displaced": "Moved by a push or pull.",
	"teleport": "Instantly moves to another point in the arena.",
	"retreat": "Moves the attacker away from the target.",
	"splash": "Deals damage to other enemies near the target.",
	"burn": "Deals damage over the following beats.",
	"critical hit": "The direct hit on the chosen target deals 1.5× damage before defenses. Most heroes have a 5% chance.",
	"interrupt": "Cancels the target's current windup.",
	"windup": "The time an attack spends preparing before it hits.",
	"reach": "How far a tile can hit when it fires.",
	"range": "Distance measured in arena units.",
	"beat": "One space on the timeline. A tile fires at the end of its last beat.",
	"loop": "One pass through the 12-beat timeline.",
}
const VARIANTS := {
	"strips": "strip", "guard break": "strip",
	"marks": "mark", "marked": "mark",
	"pushes": "push", "pushed": "push", "knockback": "push",
	"pulls": "pull", "pulled": "pull", "displace": "displaced", "displacement": "displaced",
	"teleports": "teleport", "teleportation": "teleport",
	"retreats": "retreat", "back away": "retreat",
	"burns": "burn", "interrupts": "interrupt", "windups": "windup",
	"critical chance": "critical hit", "critical hits": "critical hit", "crit": "critical hit", "crits": "critical hit",
	"beats": "beat", "loops": "loop",
}

static var _matcher := _create_matcher()


static func description(value: String, font_size: int, color: Color) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.focus_mode = Control.FOCUS_NONE
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", color)
	set_description(label, value)
	return label


static func set_description(label: RichTextLabel, value: String) -> void:
	label.clear()
	var offset := 0
	for keyword: RegExMatch in _matcher.search_all(value):
		label.add_text(value.substr(offset, keyword.get_start() - offset))
		label.push_color(HINT_COLOR)
		label.push_hint(DEFINITIONS[_term(keyword)])
		label.add_text(keyword.get_string())
		label.pop()
		label.pop()
		offset = keyword.get_end()
	label.add_text(value.substr(offset))


static func with_definitions(tooltip: String, copy: String) -> String:
	var terms := PackedStringArray()
	var seen := {}
	for keyword: RegExMatch in _matcher.search_all(copy):
		var term := _term(keyword)
		if not seen.has(term):
			terms.append("%s · %s" % [term.capitalize(), DEFINITIONS[term]])
			seen[term] = true
	return tooltip if terms.is_empty() else tooltip + "\n\n" + "\n".join(terms)


static func _term(keyword: RegExMatch) -> String:
	var word := keyword.get_string().to_lower()
	return VARIANTS.get(word, word)


static func _create_matcher() -> RegEx:
	# Match phrases before their individual words.
	var words := PackedStringArray(VARIANTS.keys() + DEFINITIONS.keys())
	return RegEx.create_from_string("(?i)\\b(?:%s)\\b" % "|".join(words))
