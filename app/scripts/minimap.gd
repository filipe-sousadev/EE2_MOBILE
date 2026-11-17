extends Control
## Small overview map; touch or drag on it to move the camera.

var game: Node = null
var pings: Array = []
var dragging: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func ping(world_pos: Vector2) -> void:
	pings.append({"p": world_pos, "t": 3.0})


func _scale() -> Vector2:
	return size / Vector2(DB.MAP_W, DB.MAP_H)


func _gui_input(ev: InputEvent) -> void:
	if game == null:
		return
	var pos := Vector2(-1, -1)
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		dragging = ev.pressed
		if ev.pressed:
			pos = ev.position
	elif ev is InputEventMouseMotion and dragging:
		pos = ev.position
	elif ev is InputEventScreenTouch and ev.pressed:
		pos = ev.position - global_position
	elif ev is InputEventScreenDrag:
		pos = ev.position - global_position
	if pos.x >= 0.0:
		game.center_on(pos / _scale())
		accept_event()


func _process(delta: float) -> void:
	for i in range(pings.size() - 1, -1, -1):
		pings[i]["t"] -= delta
		if pings[i]["t"] <= 0.0:
			pings.remove_at(i)


func _draw() -> void:
	if game == null:
		return
	var sc := _scale()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.22, 0.36, 0.16))
	for n in game.resources:
		if n.dead:
			continue
		var c: Color = Color(0.1, 0.3, 0.1) if n.kind == "tree" else DB.RES_COLORS[n.res]
		draw_rect(Rect2(n.position * sc - Vector2(1, 1), Vector2(2, 2)), c)
	for b in game.buildings:
		if b.dead:
			continue
		var r := Rect2(b.rect().position * sc, b.rect().size * sc)
		r.size = r.size.max(Vector2(3, 3))
		draw_rect(r, DB.TEAM_COLORS[b.team].lightened(0.2))
	for u in game.units:
		if u.dead:
			continue
		draw_rect(Rect2(u.position * sc - Vector2(1.5, 1.5), Vector2(3, 3)), DB.TEAM_COLORS[u.team].lightened(0.35))
	for p in pings:
		var a: float = p["t"] / 3.0
		draw_arc(p["p"] * sc, 4.0 + 10.0 * (1.0 - fmod(p["t"], 1.0)), 0, TAU, 16, Color(1, 0.3, 0.2, a), 2.0)
	# camera view
	var vp := get_viewport().get_visible_rect().size
	if game.camera:
		var vs: Vector2 = vp / game.camera.zoom
		var tl: Vector2 = game.camera.position - vs * 0.5
		draw_rect(Rect2(tl * sc, vs * sc), Color(1, 1, 1, 0.9), false, 1.5)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.75, 0.6, 0.3), false, 2.0)
