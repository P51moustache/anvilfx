extends Node2D
## Every effect in the pack on a dark isometric floor, each an AnvilFXEffect node as a game would use it.
## Click an effect to replay it, Space replays all, mouse wheel or arrow keys scroll.
## Effects are drawn at their in-game size; a few large ones are shrunk to fit their tile (the label says so).

const Effect = preload("res://addons/anvilfx/effect.gd")
const PACK = "res://effects/anvilfx-starter"
const COLUMNS = 4
const TILE = Vector2(390, 300)
const MARGIN = Vector2(20, 96)
const PAUSE_MS = 700.0         # bare floor between replays, so each effect's end reads

var _floor: Color
var _grid: Color
var _ink := Color("e2ecf2")
var _muted := Color("8ba2b2")
var _font: Font = ThemeDB.fallback_font
var _entries: Array = []       # {effect, rect, title, note, wait}
var _camera := Camera2D.new()
var _title := ""


func _ready() -> void:
	var index: Dictionary = load(PACK.path_join("index.json")).data
	_title = index["title"]
	_floor = Color(index["ground"])
	_grid = Color(index["grid"])
	RenderingServer.set_default_clear_color(_floor)
	_camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(_camera)
	var i := 0
	for id in index["effects"]:
		var rect := Rect2(MARGIN + Vector2(i % COLUMNS, i / COLUMNS) * TILE, TILE - Vector2(16, 16))
		var node := Effect.new()
		node.effect = load(PACK.path_join(id).path_join("effect.json"))
		add_child(node)
		var box: Rect2 = node.bounds()
		var fit := _fit_scale(box, rect)
		node.scale = Vector2.ONE * fit
		node.position = rect.get_center() + Vector2(0, 8) - box.get_center() * fit
		var data: Dictionary = node.effect.data
		var note := "%d px  ·  %.2f s" % [int(data["onScreenPx"]), float(data["durationMs"]) / 1000.0]
		if fit < 0.999:
			note += "  ·  shown at %d%%" % int(round(fit * 100.0))
		_entries.append({"effect": node, "rect": rect, "title": data["title"], "note": note, "wait": 0.0})
		node.finished.connect(_on_finished.bind(_entries.size() - 1))
		i += 1
	queue_redraw()


## Game size (1), or smaller when the effect would overflow its tile.
func _fit_scale(box: Rect2, rect: Rect2) -> float:
	var room := Vector2(rect.size.x - 16.0, rect.size.y - 64.0)
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return 1.0
	return minf(1.0, minf(room.x / box.size.x, room.y / box.size.y))


func _on_finished(i: int) -> void:
	_entries[i]["wait"] = PAUSE_MS


func _process(delta: float) -> void:
	for entry in _entries:
		if entry["wait"] > 0.0:
			entry["wait"] -= delta * 1000.0
			if entry["wait"] <= 0.0:
				entry["effect"].play()
	var scroll := Input.get_axis("ui_up", "ui_down") * 900.0 * delta
	if scroll != 0.0:
		_scroll(scroll)


func _scroll(amount: float) -> void:
	var rows := ceili(_entries.size() / float(COLUMNS))
	var bottom := MARGIN.y + rows * TILE.y + 40.0 - get_viewport_rect().size.y
	_camera.position.y = clampf(_camera.position.y + amount, 0.0, maxf(0.0, bottom))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll(60.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll(-60.0)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			for entry in _entries:
				if entry["rect"].has_point(get_global_mouse_position()):
					entry["wait"] = 0.0
					entry["effect"].play()
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		for entry in _entries:
			entry["wait"] = 0.0
			entry["effect"].play()


func _draw() -> void:
	var rows := ceili(_entries.size() / float(COLUMNS))
	var area := Rect2(Vector2.ZERO, Vector2(MARGIN.x * 2 + COLUMNS * TILE.x, MARGIN.y + rows * TILE.y + 40))
	_draw_iso_floor(area)
	draw_string(_font, Vector2(28, 44), _title, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, _ink)
	draw_string(_font, Vector2(28, 72), "%d effects  ·  click one to replay  ·  Space replays all  ·  wheel / arrows scroll" % _entries.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, _muted)
	for entry in _entries:
		var rect: Rect2 = entry["rect"]
		draw_rect(rect, Color(_grid, 0.9), false, 1.0)
		draw_string(_font, rect.position + Vector2(10, 22), String(entry["title"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, _ink)
		draw_string(_font, rect.position + Vector2(10, rect.size.y - 10), entry["note"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, _muted)


## Diamond tiles squashed to the game's 0.42 ground view.
func _draw_iso_floor(area: Rect2) -> void:
	var w := 64.0
	var h := w * 0.42
	var line := Color(_grid, 0.45)
	var reach := area.size.x + area.size.y / h * w
	var x := -area.size.y / h * w
	while x < reach:
		draw_line(Vector2(x, 0), Vector2(x + area.size.y / h * w, area.size.y), line, 1.0)
		draw_line(Vector2(x, area.size.y), Vector2(x + area.size.y / h * w, 0), line, 1.0)
		x += w
