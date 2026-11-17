extends Node2D
## The match: map, players, entities, pathfinding, combat rules and touch controls.

const BUCKET := 128.0
const LONG_PRESS := 0.4
const DRAG_START := 14.0
const ZOOM_MIN := 0.45
const ZOOM_MAX := 2.2
const DEFAULT_ZOOM := 1.25

var players: Array = []
var units: Array = []
var buildings: Array = []
var resources: Array = []
var selection: Array = []
var astar := AStarGrid2D.new()
var occ := PackedByteArray()
var grid_w: int = 0
var grid_h: int = 0
var world: Node2D
var fx: Node2D
var camera: Camera2D
var hud: Node = null
var ai: Node = null
var time_elapsed: float = 0.0
var game_over: bool = false
var winner: int = -1
var placing: String = ""
var ghost_cell: Vector2i = Vector2i.ZERO
var buckets: Dictionary = {}
var effects: Array = []
var rng := RandomNumberGenerator.new()
var alert_t: float = 0.0
var stats := {"killed": [0, 0], "lost": [0, 0], "gathered": [0.0, 0.0]}

# touch state
var touches: Dictionary = {}
var touch_mode: String = ""
var touch_start: Vector2 = Vector2.ZERO
var touch_start_time: float = 0.0
var box_a: Vector2 = Vector2.ZERO
var box_b: Vector2 = Vector2.ZERO
var pinch_d0: float = 1.0
var zoom0: float = 1.0
var pinch_mid: Vector2 = Vector2.ZERO
var last_tap_time: float = -10.0
var last_tap_kind: String = ""


func setup(difficulty: String, hud_node: Node) -> void:
	DB.difficulty = difficulty
	hud = hud_node
	rng.seed = 20261117
	seed(4242)
	for t in 2:
		players.append({"res": DB.START_RES.duplicate(), "pop": 0, "pop_cap": 0, "epoch": 0})
	grid_w = DB.MAP_W / DB.CELL
	grid_h = DB.MAP_H / DB.CELL
	occ.resize(grid_w * grid_h)
	occ.fill(0)
	astar.region = Rect2i(0, 0, grid_w, grid_h)
	astar.cell_size = Vector2(DB.CELL, DB.CELL)
	astar.offset = Vector2(DB.CELL * 0.5, DB.CELL * 0.5)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()

	var ground := Node2D.new()
	ground.set_script(load("res://scripts/ground.gd"))
	ground.z_index = -10
	add_child(ground)
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	fx = Node2D.new()
	fx.set_script(load("res://scripts/fx.gd"))
	fx.set("game", self)
	fx.z_index = 20
	add_child(fx)
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()

	_generate_map()
	var ai_script: GDScript = load("res://scripts/ai.gd")
	ai = ai_script.new()
	add_child(ai)
	ai.setup(self, difficulty)
	var tc: Building = find_building(0, "town_center")
	camera.position = tc.position + Vector2(140, -40)
	set_zoom(DEFAULT_ZOOM)


# ================================================================ map

func _generate_map() -> void:
	var p_tl := Vector2i(14, 62)
	var feats: Array = [] # [kind, Vector2 pos]
	var pc := Vector2(p_tl) * DB.CELL + Vector2(64, 64)
	# berries
	for i in 6:
		feats.append(["berries", pc + Vector2(230 + (i % 3) * 34, -70 + (i / 3) * 34)])
	# gold and stone near base
	for i in 3:
		feats.append(["gold", pc + Vector2(-70 + i * 36, -270)])
	for i in 3:
		feats.append(["stone", pc + Vector2(300, 170 + i * 36)])
	# forests near base
	_forest(feats, pc + Vector2(-60, 360), 110.0, 26)
	_forest(feats, pc + Vector2(430, -330), 120.0, 28)
	_forest(feats, pc + Vector2(-330, -120), 120.0, 22)
	# outer resources
	for i in 3:
		feats.append(["gold", pc + Vector2(980 + i * 36, -420)])
	for i in 3:
		feats.append(["stone", pc + Vector2(760, 230 + i * 36)])
	for i in 5:
		feats.append(["berries", pc + Vector2(620 + (i % 3) * 34, -620 + (i / 3) * 34)])
	# random forests on the left half (mirrored later)
	var tries := 0
	var made := 0
	while made < 9 and tries < 200:
		tries += 1
		var c := Vector2(rng.randf_range(150, DB.MAP_W * 0.5 - 120), rng.randf_range(150, DB.MAP_H - 150))
		if c.distance_to(pc) < 620:
			continue
		var mirror_c := Vector2(DB.MAP_W, DB.MAP_H) - c
		if c.distance_to(mirror_c) < 400:
			continue
		if mirror_c.distance_to(pc) < 620:
			continue
		_forest(feats, c, rng.randf_range(80, 150), rng.randi_range(14, 30))
		made += 1
	# place player side, then point-mirror for the computer side
	var e_tl := Vector2i(grid_w - p_tl.x - 4, grid_h - p_tl.y - 4)
	place_building("town_center", 0, p_tl, true)
	place_building("town_center", 1, e_tl, true)
	for f in feats:
		_place_resource(f[0], f[1], pc)
		_place_resource(f[0], Vector2(DB.MAP_W, DB.MAP_H) - f[1], Vector2(DB.MAP_W, DB.MAP_H) - pc)
	for t in 2:
		var tc: Building = find_building(t, "town_center")
		var dir := 1.0 if t == 0 else -1.0
		for i in DB.START_VILLAGERS:
			var off := Vector2((i - 1.5) * 30.0 * dir, 90.0 * -dir)
			spawn_unit("villager", t, tc.position + off)


func _forest(feats: Array, center: Vector2, rad: float, n: int) -> void:
	for i in n:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * rad
		feats.append(["tree", center + Vector2(cos(a), sin(a)) * r * Vector2(1.3, 1.0)])


func _place_resource(k: String, pos: Vector2, base_center: Vector2) -> void:
	var c := cell_of(pos)
	if c.x < 1 or c.y < 1 or c.x >= grid_w - 1 or c.y >= grid_h - 1:
		return
	if occ[c.y * grid_w + c.x] != 0:
		return
	if k == "tree" and pos.distance_to(base_center) < 200:
		return
	var r := ResourceNode.new()
	r.setup(self, k, cell_center(c) + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)))
	world.add_child(r)
	resources.append(r)
	occ[c.y * grid_w + c.x] = 1
	astar.set_point_solid(c, true)


# ================================================================ grid helpers

func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / DB.CELL), 0, grid_w - 1), clampi(int(p.y / DB.CELL), 0, grid_h - 1))


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c) * DB.CELL + Vector2(DB.CELL * 0.5, DB.CELL * 0.5)


func is_solid_at(p: Vector2) -> bool:
	if p.x < 4 or p.y < 4 or p.x > DB.MAP_W - 4 or p.y > DB.MAP_H - 4:
		return true
	return astar.is_point_solid(cell_of(p))


func can_place(kind: String, c: Vector2i, pad: int = 0) -> bool:
	var s: int = DB.BUILDINGS[kind]["size"]
	if c.x < 1 or c.y < 1 or c.x + s >= grid_w - 1 or c.y + s >= grid_h - 1:
		return false
	for y in range(c.y - pad, c.y + s + pad):
		for x in range(c.x - pad, c.x + s + pad):
			if x < 0 or y < 0 or x >= grid_w or y >= grid_h:
				return false
			if occ[y * grid_w + x] != 0:
				return false
	return true


func _nearest_free(c: Vector2i, toward: Vector2i) -> Vector2i:
	if not astar.is_point_solid(c):
		return c
	for r in range(1, 10):
		var best := Vector2i(-1, -1)
		var bd := 1e9
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				if absi(x - c.x) != r and absi(y - c.y) != r:
					continue
				if x < 0 or y < 0 or x >= grid_w or y >= grid_h:
					continue
				var p := Vector2i(x, y)
				if astar.is_point_solid(p):
					continue
				var dd := Vector2(p - toward).length_squared()
				if dd < bd:
					bd = dd
					best = p
		if best.x >= 0:
			return best
	return c


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := cell_of(from)
	var b := cell_of(to)
	if astar.is_point_solid(a):
		a = _nearest_free(a, b)
	var exact := true
	if astar.is_point_solid(b) or to.x < 4 or to.y < 4 or to.x > DB.MAP_W - 4 or to.y > DB.MAP_H - 4:
		b = _nearest_free(b, a)
		exact = false
	if a == b:
		return PackedVector2Array([to if exact else cell_center(b)])
	var pts := astar.get_point_path(a, b, true)
	if pts.size() <= 1:
		return PackedVector2Array([to if exact else cell_center(b)])
	pts.remove_at(0)
	if exact:
		pts[pts.size() - 1] = to
	return _smooth(from, pts)


## Drops path points that can be skipped in a straight line.
func _smooth(from: Vector2, pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array()
	var cur := from
	var i := 0
	while i < pts.size():
		var j := mini(pts.size() - 1, i + 6)
		while j > i and not _line_free(cur, pts[j]):
			j -= 1
		out.append(pts[j])
		cur = pts[j]
		i = j + 1
	return out


func _line_free(a: Vector2, b: Vector2) -> bool:
	var dist := a.distance_to(b)
	var steps := int(dist / 12.0) + 1
	for s in range(1, steps + 1):
		var p := a.lerp(b, float(s) / steps)
		if is_solid_at(p):
			return false
		# keep away from corners
		if is_solid_at(p + Vector2(8, 8)) or is_solid_at(p + Vector2(-8, -8)) or is_solid_at(p + Vector2(8, -8)) or is_solid_at(p + Vector2(-8, 8)):
			return false
	return true


# ================================================================ entities

func spawn_unit(k: String, t: int, pos: Vector2) -> Unit:
	var u := Unit.new()
	if is_solid_at(pos):
		pos = cell_center(_nearest_free(cell_of(pos), cell_of(pos)))
	u.setup(self, k, t, pos)
	world.add_child(u)
	units.append(u)
	players[t]["pop"] += u.pop
	return u


func spawn_trained(b: Building, k: String) -> void:
	var toward := Vector2(DB.MAP_W, DB.MAP_H) * 0.5 - b.position
	var side := toward.normalized() * (b.half + 18.0)
	var pos := b.position + side + Vector2(rng.randf_range(-20, 20), rng.randf_range(-20, 20))
	var u := spawn_unit(k, b.team, pos)
	u.order_move(pos + toward.normalized() * 40.0 + Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30)))
	if b.team == 1 and ai:
		ai.on_unit_trained(u)
	if b.team == 0 and hud:
		hud.refresh_actions()


func place_building(k: String, t: int, c: Vector2i, already_built: bool) -> Building:
	var b := Building.new()
	b.setup(self, k, t, c, already_built)
	world.add_child(b)
	buildings.append(b)
	var s: int = b.size_cells
	var solid: bool = DB.BUILDINGS[k]["solid"]
	for y in range(c.y, c.y + s):
		for x in range(c.x, c.x + s):
			occ[y * grid_w + x] = 2 if solid else 3
			if solid:
				astar.set_point_solid(Vector2i(x, y), true)
	if solid:
		# push units out of the footprint
		var r := b.rect().grow(4.0)
		for u in units:
			if not u.dead and r.has_point(u.position):
				u.position = cell_center(_nearest_free(cell_of(u.position), cell_of(u.position)))
	if already_built:
		on_building_complete(b)
	return b


func on_building_complete(b: Building) -> void:
	recompute_pop_cap(b.team)
	if b.team == 1 and ai:
		ai.on_building_complete(b)
	if b.team == 0 and hud:
		hud.refresh_actions()
		if time_elapsed > 1.0:
			hud.message("%s concluída" % b.display_name())


func recompute_pop_cap(t: int) -> void:
	var cap := 0
	for b in buildings:
		if b.team == t and b.built and not b.dead:
			cap += int(b.d["pop"])
	players[t]["pop_cap"] = mini(cap, DB.POP_MAX)


func on_entity_died(e: Entity) -> void:
	if e is Unit:
		units.erase(e)
		players[e.team]["pop"] -= e.pop
		stats["lost"][e.team] += 1
		stats["killed"][1 - e.team] += 1
		add_effect("puff", e.position, e.position, 0.6)
	elif e is Building:
		buildings.erase(e)
		var s: int = e.size_cells
		for y in range(e.cell.y, e.cell.y + s):
			for x in range(e.cell.x, e.cell.x + s):
				occ[y * grid_w + x] = 0
				astar.set_point_solid(Vector2i(x, y), false)
		recompute_pop_cap(e.team)
		add_effect("rubble", e.position, e.position, 1.2)
		if e.kind == "town_center":
			_check_victory()
	elif e is ResourceNode:
		resources.erase(e)
		var c := cell_of(e.position)
		occ[c.y * grid_w + c.x] = 0
		astar.set_point_solid(c, false)
	if e in selection:
		selection.erase(e)
		if hud:
			hud.refresh_selection()


func _check_victory() -> void:
	for t in 2:
		if find_building(t, "town_center") == null:
			# also allow an unfinished replacement to keep the team alive? no: town center lost = defeat
			game_over = true
			winner = 1 - t
			if hud:
				hud.show_end(winner == 0)
			return


func find_building(t: int, k: String, only_built: bool = true) -> Building:
	for b in buildings:
		if b.team == t and b.kind == k and not b.dead and (b.built or not only_built):
			return b
	return null


func count_buildings(t: int, k: String) -> int:
	var n := 0
	for b in buildings:
		if b.team == t and b.kind == k and not b.dead:
			n += 1
	return n


func units_of(t: int, villagers: bool) -> Array:
	var out := []
	for u in units:
		if u.team == t and not u.dead and (u.kind == "villager") == villagers:
			out.append(u)
	return out


func epoch_mult(t: int) -> float:
	return 1.0 + DB.EPOCH_BONUS * float(players[t]["epoch"])


func gather_mult(t: int) -> float:
	if t == 1 and ai:
		return ai.cfg["gather_mult"]
	return 1.0


func advance_epoch(t: int) -> void:
	var old := epoch_mult(t)
	players[t]["epoch"] = mini(players[t]["epoch"] + 1, DB.EPOCHS.size() - 1)
	var ratio := epoch_mult(t) / old
	for u in units:
		if u.team == t and u.is_military():
			u.max_hp *= ratio
			u.hp *= ratio
	for b in buildings:
		if b.team == t:
			b.queue_redraw()
	if hud:
		if t == 0:
			hud.message("Você avançou para a %s!" % DB.EPOCHS[players[t]["epoch"]]["name"], 4.0)
		else:
			hud.message("O inimigo avançou para a %s" % DB.EPOCHS[players[t]["epoch"]]["name"], 3.0)
		hud.refresh_actions()


func can_afford(t: int, cost: Dictionary) -> bool:
	var r: Dictionary = players[t]["res"]
	for k in cost:
		if r[k] < cost[k]:
			return false
	return true


func pay(t: int, cost: Dictionary) -> bool:
	if not can_afford(t, cost):
		return false
	for k in cost:
		players[t]["res"][k] -= cost[k]
	return true


func refund(t: int, cost: Dictionary) -> void:
	for k in cost:
		players[t]["res"][k] += cost[k]


func add_res(t: int, res: String, amt: float) -> void:
	if res == "":
		return
	players[t]["res"][res] += amt
	stats["gathered"][t] += amt


# ================================================================ queries

func gap_between(a: Entity, b: Entity) -> float:
	if b is Building:
		return b.edge_distance(a.position) - a.radius
	if a is Building:
		return a.edge_distance(b.position) - b.radius
	return a.position.distance_to(b.position) - a.radius - b.radius


func _rebuild_buckets() -> void:
	buckets.clear()
	for u in units:
		if u.dead:
			continue
		var k := Vector2i(int(u.position.x / BUCKET), int(u.position.y / BUCKET))
		if buckets.has(k):
			buckets[k].append(u)
		else:
			buckets[k] = [u]


func nearest_enemy(pos: Vector2, t: int, r: float) -> Entity:
	var best: Entity = null
	var bd := r
	var x0 := int((pos.x - r) / BUCKET)
	var x1 := int((pos.x + r) / BUCKET)
	var y0 := int((pos.y - r) / BUCKET)
	var y1 := int((pos.y + r) / BUCKET)
	for by in range(y0, y1 + 1):
		for bx in range(x0, x1 + 1):
			var k := Vector2i(bx, by)
			if not buckets.has(k):
				continue
			for u in buckets[k]:
				if u.team == t or u.dead:
					continue
				var dd: float = pos.distance_to(u.position) - u.radius
				if dd < bd:
					bd = dd
					best = u
	if best != null:
		return best
	for b in buildings:
		if b.team == t or b.dead:
			continue
		var dd: float = b.edge_distance(pos)
		if dd < bd:
			bd = dd
			best = b
	return best


func find_resource_near(pos: Vector2, k: String, r: float, t: int) -> Entity:
	var best: Entity = null
	var bd := r
	if k == "farm":
		for b in buildings:
			if b.team == t and b.kind == "farm" and b.built and not b.dead and not farm_taken(b, null):
				var dd := pos.distance_to(b.position)
				if dd < bd:
					bd = dd
					best = b
		return best
	for n in resources:
		if n.kind != k or n.dead:
			continue
		var dd := pos.distance_to(n.position)
		if dd < bd:
			bd = dd
			best = n
	return best


func farm_taken(f: Building, except: Node) -> bool:
	for u in units:
		if u != except and not u.dead and u.team == f.team and u.target == f and u.state in [Unit.S.GATHER, Unit.S.RETURN]:
			return true
	return false


func nearest_drop(pos: Vector2, t: int, _res: String) -> Entity:
	var best: Entity = null
	var bd := 1e9
	for b in buildings:
		if b.team == t and b.built and not b.dead and b.d["drop"]:
			var dd: float = b.edge_distance(pos)
			if dd < bd:
				bd = dd
				best = b
	return best


func unfinished_near(pos: Vector2, t: int, r: float) -> Entity:
	for b in buildings:
		if b.team == t and not b.built and not b.dead and b.position.distance_to(pos) < r:
			return b
	return null


# ================================================================ combat

func deal_damage(att: Unit, target: Entity) -> void:
	var dmg: float = att.atk * epoch_mult(att.team)
	var bonus: Dictionary = DB.BONUS.get(att.kind, {})
	dmg *= float(bonus.get(target.cls(), 1.0))
	if target is Building and att.kind != "catapult":
		dmg *= DB.VS_BUILDING
	if att.rng > 40.0:
		add_effect("stone" if att.kind == "catapult" else "arrow", att.position + Vector2(0, -8), target.position, 0.3)
	target.take_damage(dmg, att)


func building_shoot(b: Building, target: Entity) -> void:
	var dmg: float = float(b.d["atk"]) * epoch_mult(b.team)
	add_effect("arrow", b.position + Vector2(0, -b.half * 0.5), target.position, 0.25)
	target.take_damage(dmg, b)


func on_attacked(victim: Entity, attacker: Node) -> void:
	if victim.team == 1 and ai:
		ai.on_attacked(victim, attacker)
	elif victim.team == 0 and hud and alert_t <= 0.0:
		alert_t = 20.0
		hud.message("Você está sob ataque!", 3.0)
		hud.ping(victim.position)


func add_effect(type: String, from: Vector2, to: Vector2, dur: float) -> void:
	effects.append({"type": type, "from": from, "to": to, "t": 0.0, "dur": dur})


# ================================================================ frame

func _physics_process(delta: float) -> void:
	if game_over:
		return
	time_elapsed += delta
	alert_t -= delta
	_rebuild_buckets()
	_separate()


func _separate() -> void:
	for u in units:
		if u.dead:
			continue
		var k := Vector2i(int(u.position.x / BUCKET), int(u.position.y / BUCKET))
		var push := Vector2.ZERO
		for by in range(k.y - 1, k.y + 2):
			for bx in range(k.x - 1, k.x + 2):
				var kk := Vector2i(bx, by)
				if not buckets.has(kk):
					continue
				for o in buckets[kk]:
					if o == u:
						continue
					var diff: Vector2 = u.position - o.position
					var dist := diff.length()
					var mn: float = (u.radius + o.radius) * 0.85
					if dist < mn:
						if dist < 0.01:
							push += Vector2(randf() - 0.5, randf() - 0.5)
						else:
							push += diff / dist * (mn - dist) * 0.5
		if push != Vector2.ZERO:
			var np: Vector2 = u.position + push.limit_length(2.5)
			if not is_solid_at(np):
				u.position = np


func _process(delta: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		effects[i]["t"] += delta
		if effects[i]["t"] >= effects[i]["dur"]:
			effects.remove_at(i)
	fx.queue_redraw()
	if touch_mode == "pending" and placing == "" and Time.get_ticks_msec() / 1000.0 - touch_start_time > LONG_PRESS:
		touch_mode = "box"
		box_a = touch_start
		box_b = touch_start
		if hud:
			hud.set_box(Rect2(box_a, Vector2.ZERO), true)


# ================================================================ camera & input

func screen_to_world(p: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * p


func world_to_screen(p: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * p


func _clamp_camera() -> void:
	var vs := get_viewport_rect().size / camera.zoom
	var hw := vs.x * 0.5
	var hh := vs.y * 0.5
	var top_pad := 40.0 / camera.zoom.y
	var bottom_pad := 130.0 / camera.zoom.y
	if hw * 2.0 >= DB.MAP_W:
		camera.position.x = DB.MAP_W * 0.5
	else:
		camera.position.x = clampf(camera.position.x, hw, DB.MAP_W - hw)
	camera.position.y = clampf(camera.position.y, hh - top_pad, DB.MAP_H - hh + bottom_pad)


func set_zoom(z: float) -> void:
	z = clampf(z, ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2(z, z)
	_clamp_camera()


func center_on(p: Vector2) -> void:
	camera.position = p
	_clamp_camera()


func _unhandled_input(ev: InputEvent) -> void:
	if game_over or get_tree().paused:
		return
	if ev is InputEventScreenTouch:
		if ev.pressed:
			if hud and hud.is_over_ui(ev.position):
				return
			touches[ev.index] = ev.position
			if touches.size() == 1:
				touch_mode = "pending"
				touch_start = ev.position
				touch_start_time = Time.get_ticks_msec() / 1000.0
			elif touches.size() == 2:
				if touch_mode == "box" and hud:
					hud.set_box(Rect2(), false)
				touch_mode = "pinch"
				var ps: Array = touches.values()
				pinch_d0 = maxf(10.0, (ps[0] as Vector2).distance_to(ps[1]))
				pinch_mid = ((ps[0] as Vector2) + (ps[1] as Vector2)) * 0.5
				zoom0 = camera.zoom.x
		else:
			if not touches.has(ev.index):
				return
			if touch_mode == "pending" and touches.size() == 1:
				handle_tap(screen_to_world(ev.position))
			elif touch_mode == "box" and touches.size() == 1:
				_finish_box()
			touches.erase(ev.index)
			if touches.is_empty():
				touch_mode = ""
			elif touch_mode == "pinch":
				touch_mode = "pan"
		get_viewport().set_input_as_handled()
	elif ev is InputEventScreenDrag:
		if not touches.has(ev.index):
			return
		touches[ev.index] = ev.position
		match touch_mode:
			"pending":
				if ev.position.distance_to(touch_start) > DRAG_START:
					touch_mode = "pan"
			"pan":
				camera.position -= ev.relative / camera.zoom.x
				_clamp_camera()
			"box":
				box_b = ev.position
				if hud:
					hud.set_box(Rect2(box_a, Vector2.ZERO).expand(box_b), true)
			"pinch":
				if touches.size() >= 2:
					var ps: Array = touches.values()
					var dd := maxf(10.0, (ps[0] as Vector2).distance_to(ps[1]))
					var mid: Vector2 = ((ps[0] as Vector2) + (ps[1] as Vector2)) * 0.5
					set_zoom(zoom0 * dd / pinch_d0)
					camera.position -= (mid - pinch_mid) / camera.zoom.x
					pinch_mid = mid
					_clamp_camera()
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(camera.zoom.x * 1.1)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(camera.zoom.x / 1.1)
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			if hud and hud.is_over_ui(ev.position):
				return
			handle_tap(screen_to_world(ev.position), true)


func _finish_box() -> void:
	if hud:
		hud.set_box(Rect2(), false)
	var a := screen_to_world(box_a)
	var b := screen_to_world(box_b)
	var r := Rect2(a, Vector2.ZERO).expand(b).grow(6.0)
	var picked := []
	for u in units:
		if u.team == 0 and not u.dead and r.has_point(u.position):
			picked.append(u)
	if picked.size() > 0:
		select(picked)


# ================================================================ commands

func pick_entity(wp: Vector2) -> Entity:
	var tol := 14.0 / camera.zoom.x
	var best: Entity = null
	var bd := 1e9
	for u in units:
		if u.dead:
			continue
		var dd: float = wp.distance_to(u.position + Vector2(0, -6))
		if dd <= u.radius + tol and dd < bd:
			bd = dd
			best = u
	if best != null:
		return best
	for b in buildings:
		if not b.dead and b.edge_distance(wp) <= 2.0:
			return b
	for n in resources:
		if n.dead:
			continue
		var dd: float = wp.distance_to(n.position)
		if dd <= n.radius + tol * 0.6 and dd < bd:
			bd = dd
			best = n
	return best


func own_selected_units() -> Array:
	var out := []
	for e in selection:
		if e is Unit and e.team == 0 and not e.dead:
			out.append(e)
	return out


func selected_villagers() -> Array:
	var out := []
	for e in own_selected_units():
		if e.is_villager():
			out.append(e)
	return out


func handle_tap(wp: Vector2, command_only: bool = false) -> void:
	if placing != "":
		var s: int = DB.BUILDINGS[placing]["size"]
		ghost_cell = cell_of(wp - Vector2(s * DB.CELL * 0.5, s * DB.CELL * 0.5) + Vector2(DB.CELL * 0.5, DB.CELL * 0.5))
		return
	var e := pick_entity(wp)
	var mine := own_selected_units()
	var now := Time.get_ticks_msec() / 1000.0
	if mine.size() > 0:
		if e == null:
			command_move(mine, wp)
			return
		if e.team == 0:
			var vills := selected_villagers()
			if e is Building and not e.built and vills.size() > 0:
				command_build(vills, e)
				return
			if e is Building and e.kind == "farm" and vills.size() > 0:
				vills[0].order_gather(e)
				add_effect("marker", e.position, e.position, 0.5)
				return
			if command_only:
				command_move(mine, wp)
				return
			_select_tap(e, now)
			return
		if e.team == 1:
			command_attack(mine, e)
			return
		if e is ResourceNode:
			command_gather(mine, e)
			return
	if command_only:
		return
	if e != null:
		_select_tap(e, now)
	else:
		select([])


func _select_tap(e: Entity, now: float) -> void:
	if e is Unit and e.team == 0 and now - last_tap_time < 0.45 and last_tap_kind == e.kind:
		# double tap: every unit of this kind on screen
		var vr := Rect2(screen_to_world(Vector2.ZERO), get_viewport_rect().size / camera.zoom)
		var same := []
		for u in units:
			if u.team == 0 and u.kind == e.kind and not u.dead and vr.has_point(u.position):
				same.append(u)
		select(same)
	else:
		select([e])
	last_tap_time = now
	last_tap_kind = e.kind if e is Unit else ""


func select(list: Array) -> void:
	for e in selection:
		if is_instance_valid(e):
			e.set_selected(false)
	selection = []
	for e in list:
		if is_instance_valid(e) and not e.dead:
			selection.append(e)
			e.set_selected(true)
	if hud:
		hud.refresh_selection()


func command_move(list: Array, wp: Vector2) -> void:
	var n := list.size()
	var cols := int(ceil(sqrt(float(n))))
	var sp := 26.0
	for i in n:
		var off := Vector2((i % cols) - (cols - 1) * 0.5, (i / cols) - (ceil(float(n) / cols) - 1) * 0.5) * sp
		var p := wp + off
		if is_solid_at(p):
			p = wp
		list[i].order_move(p)
	add_effect("marker", wp, wp, 0.6)


func command_attack(list: Array, e: Entity) -> void:
	for u in list:
		u.order_attack(e)
	add_effect("target", e.position, e.position, 0.6)


func command_gather(list: Array, r: ResourceNode) -> void:
	var vills := []
	var others := []
	for u in list:
		if u.is_villager():
			vills.append(u)
		else:
			others.append(u)
	# spread villagers over nearby nodes of the same kind
	var nodes := []
	for n in resources:
		if n.kind == r.kind and not n.dead and n.position.distance_to(r.position) < 160.0:
			nodes.append(n)
	nodes.sort_custom(func(a, b): return a.position.distance_to(r.position) < b.position.distance_to(r.position))
	if nodes.is_empty():
		nodes = [r]
	var per := 2 if r.kind == "tree" else 4
	for i in vills.size():
		var idx := mini(i / per, nodes.size() - 1)
		vills[i].order_gather(nodes[idx])
	if others.size() > 0:
		command_move(others, r.position)
	add_effect("marker", r.position, r.position, 0.5)


func command_build(list: Array, b: Building) -> void:
	for u in list:
		u.order_build(b)
	add_effect("marker", b.position, b.position, 0.5)


func command_stop() -> void:
	for u in own_selected_units():
		u.stop()


func select_army() -> void:
	select(units_of(0, false))
	_center_selection()


var _idle_cycle: int = 0


func select_idle_villager() -> bool:
	var idle := []
	for u in units_of(0, true):
		if u.is_idle():
			idle.append(u)
	if idle.is_empty():
		if hud:
			hud.message("Nenhum aldeão ocioso")
		return false
	_idle_cycle = (_idle_cycle + 1) % idle.size()
	select([idle[_idle_cycle]])
	center_on(idle[_idle_cycle].position)
	return true


func _center_selection() -> void:
	if selection.is_empty():
		return
	var c := Vector2.ZERO
	for e in selection:
		c += e.position
	center_on(c / selection.size())


func center_base() -> void:
	var tc := find_building(0, "town_center", false)
	if tc:
		select([tc])
		center_on(tc.position)


func train(b: Building, k: String) -> bool:
	if not b.can_train(k):
		return false
	if players[b.team]["epoch"] < int(DB.UNITS[k]["epoch"]):
		return false
	if b.queue.size() >= 5:
		if hud and b.team == 0:
			hud.message("Fila cheia")
		return false
	if not pay(b.team, DB.UNITS[k]["cost"]):
		if hud and b.team == 0:
			hud.message("Recursos insuficientes")
		return false
	b.queue.append(k)
	return true


func queue_epoch(b: Building) -> bool:
	var t := b.team
	var nxt: int = players[t]["epoch"] + 1
	if b.kind != "town_center" or not b.built or nxt >= DB.EPOCHS.size():
		return false
	for o in buildings:
		if o.team == t and "epoch" in o.queue:
			return false
	if not pay(t, DB.EPOCHS[nxt]["cost"]):
		if hud and t == 0:
			hud.message("Recursos insuficientes")
		return false
	b.queue.append("epoch")
	return true


func cancel_last(b: Building) -> void:
	if b.queue.is_empty():
		return
	var item: String = b.queue.pop_back()
	if b.queue.is_empty():
		b.train_t = 0.0
	if item == "epoch":
		refund(b.team, DB.EPOCHS[players[b.team]["epoch"] + 1]["cost"])
	else:
		refund(b.team, DB.UNITS[item]["cost"])


func start_place(k: String) -> bool:
	if players[0]["epoch"] < int(DB.BUILDINGS[k]["epoch"]):
		return false
	if not can_afford(0, DB.BUILDINGS[k]["cost"]):
		if hud:
			hud.message("Recursos insuficientes")
		return false
	placing = k
	var s: int = DB.BUILDINGS[k]["size"]
	var center := camera.position
	ghost_cell = cell_of(center - Vector2(s * DB.CELL * 0.5, s * DB.CELL * 0.5) + Vector2(DB.CELL * 0.5, DB.CELL * 0.5))
	if hud:
		hud.refresh_actions()
		hud.message("Toque no mapa para posicionar e depois em Construir", 3.0)
	return true


func confirm_place() -> Building:
	if placing == "":
		return null
	var k := placing
	if not can_place(k, ghost_cell):
		if hud:
			hud.message("Não é possível construir aqui")
		return null
	if not pay(0, DB.BUILDINGS[k]["cost"]):
		if hud:
			hud.message("Recursos insuficientes")
		return null
	var b := place_building(k, 0, ghost_cell, false)
	placing = ""
	command_build(selected_villagers(), b)
	if hud:
		hud.refresh_actions()
	return b


func cancel_place() -> void:
	placing = ""
	if hud:
		hud.refresh_actions()
