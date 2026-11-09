@tool
extends RefCounted
## The GDScript the dock's Copy code button puts on the clipboard: the AnvilFX.spawn() line for the chosen effect,
## sheet, speed and any piece/layer customizations, plus the options people reach for next, commented. Pure, so it is
## tested headless.

const Library = preload("library.gd")


## The spawn() name for an entry and sheet: "id", or "id/sheet" for one sheet of a multi-sheet effect.
static func spawn_name(entry: Dictionary, sheet: String) -> String:
	if sheet == "" or entry["sheet_scenes"].is_empty():
		return String(entry["id"])
	return "%s/%s" % [entry["id"], Library._file_id(sheet)]


static func spawn_code(entry: Dictionary, sheet: String, speed: float = 1.0, custom: Dictionary = {}) -> String:
	var pairs := PackedStringArray()
	if not is_equal_approx(speed, 1.0):
		pairs.append("\"speed\": %s" % _num(speed))
	var holdout := float(custom.get("holdout", 1.0))
	if not is_equal_approx(holdout, 1.0):
		pairs.append("\"holdout\": %s" % _num(holdout))
	var light := float(custom.get("light", 1.0))
	if not is_equal_approx(light, 1.0):
		pairs.append("\"light\": %s" % _num(light))
	var sustain := float(custom.get("sustain", 0.0))
	if sustain > 0.001:
		pairs.append("\"sustain\": %s" % _num(sustain))
	var trim_start := float(custom.get("trim_start", 0.0))
	if trim_start > 0.001:
		pairs.append("\"trim_start\": %s" % _num(trim_start))
	var trim_end := float(custom.get("trim_end", 0.0))
	if trim_end > 0.001:
		pairs.append("\"trim_end\": %s" % _num(trim_end))
	var pieces: Dictionary = custom.get("pieces", {})
	if not pieces.is_empty():
		var p_str := _pieces_literal(pieces)
		if p_str != "":
			pairs.append("\"pieces\": %s" % p_str)
	if bool(custom.get("split_pieces", false)) and sheet == "" and entry.get("sheets", []).size() > 1:
		pairs.append("\"split_pieces\": true")
	var options := "" if pairs.is_empty() else ", {%s}" % ", ".join(pairs)
	var plays := "loops until you free it" if bool(entry.get("loops", false)) and sheet == "" else \
			"plays once, then frees itself"
	return "\n".join([
		"# %s%s: %s." % [entry["title"], " (%s)" % sheet if sheet != "" else "", plays],
		"AnvilFX.spawn(\"%s\", global_position%s)" % [spawn_name(entry, sheet), options],
		"# More options: {\"direction\": velocity, \"facing\": -1, \"attach\": $Muzzle, \"sustain\": 1.5, \"unscaled\": true,",
		"#     \"holdout\": 0.6, \"pieces\": {\"<sheet>\": {\"scale\": 1.25}}, \"hit_stop\": 0.06, \"shake\": 6.0}",
		""])


static func _pieces_literal(pieces: Dictionary) -> String:
	var sheets := PackedStringArray()
	for sname in pieces:
		var cfg = pieces[sname]
		if cfg is bool:
			if not cfg:
				sheets.append("\"%s\": false" % sname)
			continue
		if not cfg is Dictionary or cfg.is_empty():
			continue
		var fields := PackedStringArray()
		if cfg.has("enabled") and not bool(cfg["enabled"]):
			fields.append("\"enabled\": false")
		if cfg.has("offset") and not (cfg["offset"] as Vector2).is_equal_approx(Vector2.ZERO):
			var v := cfg["offset"] as Vector2
			fields.append("\"offset\": Vector2(%s, %s)" % [_num(v.x), _num(v.y)])
		if cfg.has("scale") and not is_equal_approx(float(cfg["scale"]), 1.0):
			fields.append("\"scale\": %s" % _num(float(cfg["scale"])))
		if cfg.has("speed") and not is_equal_approx(float(cfg["speed"]), 1.0):
			fields.append("\"speed\": %s" % _num(float(cfg["speed"])))
		if cfg.has("delay_ms") and not is_zero_approx(float(cfg["delay_ms"])):
			fields.append("\"delay_ms\": %s" % _num(float(cfg["delay_ms"])))
		if cfg.has("opacity") and not is_equal_approx(float(cfg["opacity"]), 1.0):
			fields.append("\"opacity\": %s" % _num(float(cfg["opacity"])))
		if cfg.has("modulate") and not (cfg["modulate"] as Color).is_equal_approx(Color.WHITE):
			fields.append("\"modulate\": Color(\"%s\")" % (cfg["modulate"] as Color).to_html())
		if not fields.is_empty():
			sheets.append("\"%s\": {%s}" % [sname, ", ".join(fields)])
	return "{%s}" % ", ".join(sheets) if not sheets.is_empty() else ""


static func _num(value: float) -> String:
	return str(snappedf(value, 0.01)).trim_suffix(".0")
