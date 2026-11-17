class_name Building
extends Entity
## Town center, houses, barracks, depots, farms and towers.

var d: Dictionary = {}
var size_cells: int = 2
var cell: Vector2i = Vector2i.ZERO
var built: bool = false
var progress: float = 0.0
var build_time: float = 10.0
var queue: Array = []
var train_t: float = 0.0
var cooldown: float = 0.0
var half: float = 32.0
var waiting_pop: bool = false
var shot_to: Vector2 = Vector2.ZERO
var shot_t: float = 0.0


func setup(g: Node, k: String, t: int, top_left: Vector2i, already_built: bool) -> void:
	game = g
	kind = k
	team = t
	d = DB.BUILDINGS[k]
	size_cells = d["size"]
	cell = top_left
	half = size_cells * DB.CELL * 0.5
	position = Vector2(top_left) * DB.CELL + Vector2(half, half)
	max_hp = d["hp"]
	build_time = d["time"]
	radius = half
	built = already_built
	if built:
		hp = max_hp
		progress = build_time
	else:
		hp = maxf(1.0, max_hp * 0.1)
	z_index = 0 if k == "farm" else 1


func cls() -> String:
	return "building"


func display_name() -> String:
	return d["name"]


func rect() -> Rect2:
	return Rect2(position - Vector2(half, half), Vector2(half * 2.0, half * 2.0))


func edge_distance(p: Vector2) -> float:
	var r := rect()
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return sqrt(dx * dx + dy * dy)


func add_progress(dt: float) -> void:
	if built:
		return
	progress += dt
	hp = minf(max_hp, hp + max_hp * 0.9 * dt / build_time)
	if progress >= build_time:
		built = true
		progress = build_time
		if game:
			game.on_building_complete(self)
	queue_redraw()


func can_train(k: String) -> bool:
	return built and k in d["trains"]


func current_item() -> String:
	return queue[0] if queue.size() > 0 else ""


func item_time(item: String) -> float:
	if item == "epoch":
		var nxt: int = game.players[team]["epoch"] + 1
		return DB.EPOCHS[mini(nxt, DB.EPOCHS.size() - 1)]["time"]
	return DB.UNITS[item]["time"]


func progress_frac() -> float:
	if queue.is_empty():
		return 0.0
	return clampf(train_t / item_time(queue[0]), 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if dead or game == null or game.game_over:
		return
	if flash > 0.0:
		flash -= delta
		if flash <= 0.0:
			queue_redraw()
	if shot_t > 0.0:
		shot_t -= delta
		queue_redraw()
	if not built:
		return
	# training / research
	if not queue.is_empty():
		var item: String = queue[0]
		waiting_pop = false
		if item != "epoch":
			var p: Dictionary = game.players[team]
			if p["pop"] + int(DB.UNITS[item]["pop"]) > p["pop_cap"]:
				waiting_pop = true
		if not waiting_pop:
			train_t += delta
			if train_t >= item_time(item):
				train_t = 0.0
				queue.pop_front()
				if item == "epoch":
					game.advance_epoch(team)
				else:
					game.spawn_trained(self, item)
	# defence fire
	if d.has("atk"):
		cooldown -= delta
		if cooldown <= 0.0:
			var e: Entity = game.nearest_enemy(position, team, d["range"] + half)
			if e != null:
				cooldown = d["cd"]
				game.building_shoot(self, e)
				shot_to = e.position - position
				shot_t = 0.2
			else:
				cooldown = 0.3


func take_damage(amount: float, attacker: Node) -> void:
	super.take_damage(amount, attacker)
	if not dead and game:
		game.on_attacked(self, attacker)


func _draw() -> void:
	var tc: Color = DB.TEAM_COLORS[team]
	var ep: int = game.players[team]["epoch"] if game else 0
	var wall := Color(0.55, 0.4, 0.25).lerp(Color(0.62, 0.6, 0.58), float(ep) / 3.0)
	var roof := tc.darkened(0.15)
	if flash > 0.0:
		wall = wall.lerp(Color.WHITE, 0.5)
	var h := half
	var alpha := 1.0 if built else 0.55
	wall.a = alpha
	roof.a = alpha
	if kind != "farm":
		draw_rect(Rect2(-h + 5, -h + 7, h * 2.0, h * 2.0), Color(0, 0, 0, 0.25))
	match kind:
		"town_center":
			draw_rect(Rect2(-h + 4, -h + 10, h * 2 - 8, h * 2 - 14), wall)
			draw_rect(Rect2(-h + 4, -h + 10, h * 2 - 8, h * 2 - 14), wall.darkened(0.4), false, 2.0)
			var pts := PackedVector2Array([Vector2(-h + 0, -h + 22), Vector2(0, -h - 4), Vector2(h, -h + 22)])
			draw_colored_polygon(pts, roof)
			draw_rect(Rect2(-14, h - 30, 28, 26), wall.darkened(0.5))
			for i in 4:
				draw_rect(Rect2(-h + 14 + i * (h * 2 - 36) / 3.0, -h + 32, 8, 10), Color(0.15, 0.12, 0.1, alpha))
			draw_line(Vector2(0, -h - 4), Vector2(0, -h - 26), Color(0.3, 0.2, 0.1, alpha), 2.0)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -h - 26), Vector2(16, -h - 21), Vector2(0, -h - 16)]), tc)
		"house":
			draw_rect(Rect2(-h + 6, -h + 12, h * 2 - 12, h * 2 - 16), wall)
			draw_colored_polygon(PackedVector2Array([Vector2(-h + 2, -h + 16), Vector2(0, -h - 2), Vector2(h - 2, -h + 16)]), roof)
			draw_rect(Rect2(-5, h - 16, 10, 12), wall.darkened(0.5))
		"barracks":
			draw_rect(Rect2(-h + 4, -h + 8, h * 2 - 8, h * 2 - 12), wall)
			draw_rect(Rect2(-h + 4, -h + 8, h * 2 - 8, 12), roof)
			draw_rect(Rect2(-h + 4, -h + 8, h * 2 - 8, h * 2 - 12), wall.darkened(0.4), false, 2.0)
			draw_line(Vector2(-18, 18), Vector2(18, -10), Color(0.85, 0.85, 0.9, alpha), 3.0)
			draw_line(Vector2(18, 18), Vector2(-18, -10), Color(0.85, 0.85, 0.9, alpha), 3.0)
			draw_rect(Rect2(-8, -h - 6, 16, 14), tc)
		"depot":
			draw_rect(Rect2(-h + 4, -h + 6, h * 2 - 8, h * 2 - 8), wall.darkened(0.1))
			draw_rect(Rect2(-h + 4, -h + 6, h * 2 - 8, 8), roof)
			draw_rect(Rect2(-14, 0, 12, 12), Color(0.55, 0.38, 0.2, alpha))
			draw_rect(Rect2(2, 2, 12, 10), Color(0.6, 0.6, 0.62, alpha))
			draw_rect(Rect2(-6, -10, 10, 9), Color(0.95, 0.8, 0.25, alpha))
		"farm":
			draw_rect(Rect2(-h + 2, -h + 2, h * 2 - 4, h * 2 - 4), Color(0.45, 0.32, 0.18, alpha))
			var crop := Color(0.45, 0.7, 0.2, alpha).lerp(Color(0.9, 0.8, 0.3, alpha), 0.5 + 0.5 * sin(float(cell.x)))
			if built:
				var rows := 7
				for i in rows:
					var y := -h + 8 + i * (h * 2 - 16) / float(rows - 1)
					draw_line(Vector2(-h + 8, y), Vector2(h - 8, y), crop, 4.0)
			draw_rect(Rect2(-h + 2, -h + 2, h * 2 - 4, h * 2 - 4), tc, false, 2.0)
		"tower":
			draw_rect(Rect2(-h + 10, -h + 4, h * 2 - 20, h * 2 - 6), wall)
			draw_rect(Rect2(-h + 6, -h, h * 2 - 12, 10), wall.darkened(0.2))
			for i in 3:
				draw_rect(Rect2(-h + 6 + i * (h * 2 - 20) / 2.0, -h - 6, 8, 6), wall.darkened(0.2))
			draw_rect(Rect2(-4, -h + 18, 8, 10), Color(0.1, 0.1, 0.1, alpha))
			draw_rect(Rect2(-h + 10, h - 12, h * 2 - 20, 6), tc)
	if not built:
		# scaffolding and progress
		draw_rect(Rect2(-h + 2, -h + 2, h * 2 - 4, h * 2 - 4), Color(0.75, 0.6, 0.35), false, 2.0)
		draw_line(Vector2(-h + 2, -h + 2), Vector2(h - 2, h - 2), Color(0.75, 0.6, 0.35, 0.6), 1.5)
		draw_line(Vector2(h - 2, -h + 2), Vector2(-h + 2, h - 2), Color(0.75, 0.6, 0.35, 0.6), 1.5)
		var frac := progress / build_time
		draw_rect(Rect2(-h, h + 4, h * 2, 5), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-h, h + 4, h * 2 * frac, 5), Color(0.95, 0.85, 0.3))
	if selected:
		draw_rect(Rect2(-h - 2, -h - 2, h * 2 + 4, h * 2 + 4), Color(0.4, 1.0, 0.4), false, 2.0)
	if built:
		draw_hp_bar(-h - 12, h * 1.6)
	if not queue.is_empty() and built:
		draw_rect(Rect2(-h, h + 4, h * 2, 4), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-h, h + 4, h * 2 * progress_frac(), 4), Color(0.4, 0.8, 1.0))
	if shot_t > 0.0:
		draw_line(Vector2(0, -h * 0.5), shot_to, Color(1, 0.95, 0.6, 0.8), 2.0)
