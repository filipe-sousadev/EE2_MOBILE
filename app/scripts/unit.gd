class_name Unit
extends Entity
## Villagers and soldiers.

enum S { IDLE, MOVE, GATHER, RETURN, BUILD, ATTACK }

## how close a villager must stand to a tree, mine, drop site or building site (one grid step, diagonals included)
const REACH := 24.0

var state: int = S.IDLE
var d: Dictionary = {}
var speed: float = 70.0
var atk: float = 3.0
var rng: float = 12.0
var cd: float = 1.5
var sight: float = 200.0
var pop: int = 1

var cooldown: float = 0.0
var path: PackedVector2Array = PackedVector2Array()
var path_i: int = 0
var dest: Vector2 = Vector2.ZERO
var target: Entity = null
var attack_move: bool = false
var carry_res: String = ""
var carry: float = 0.0
var last_res_kind: String = ""
var last_res_pos: Vector2 = Vector2.ZERO
var scan_t: float = 0.0
var repath_t: float = 0.0
var anim: float = 0.0
var facing: float = 1.0
var moving: bool = false
var swing: float = 0.0
var guard_pos: Vector2 = Vector2.ZERO
var stuck_t: float = 0.0
var last_pos: Vector2 = Vector2.ZERO
var auto_target: bool = false


func setup(g: Node, k: String, t: int, pos: Vector2) -> void:
	game = g
	kind = k
	team = t
	position = pos
	d = DB.UNITS[k]
	var mult := 1.0
	if k != "villager":
		mult = game.epoch_mult(t)
	max_hp = d["hp"] * mult
	hp = max_hp
	speed = d["speed"]
	atk = d["atk"]
	rng = d["range"]
	cd = d["cd"]
	sight = d["sight"]
	radius = d["radius"]
	pop = d["pop"]
	scan_t = randf() * 0.5
	guard_pos = pos
	last_pos = pos
	z_index = 2


func cls() -> String:
	return d.get("cls", "infantry")


func display_name() -> String:
	return d["name"]


func is_villager() -> bool:
	return kind == "villager"


func is_military() -> bool:
	return kind != "villager"


func is_idle() -> bool:
	return state == S.IDLE


func state_text() -> String:
	match state:
		S.IDLE: return "Parado"
		S.MOVE: return "Andando"
		S.GATHER: return "Coletando " + DB.RES_NAMES.get(_target_res(), "")
		S.RETURN: return "Levando " + DB.RES_NAMES.get(carry_res, "")
		S.BUILD: return "Construindo"
		S.ATTACK: return "Atacando"
	return ""


# ---------------------------------------------------------------- orders

func order_move(p: Vector2, amove: bool = false) -> void:
	state = S.MOVE
	target = null
	attack_move = amove
	dest = p
	_set_path(p)


func order_attack(e: Entity) -> void:
	if e == null or not e.is_alive():
		return
	state = S.ATTACK
	target = e
	auto_target = false
	attack_move = false
	_set_path(e.position)
	repath_t = 0.6


func order_gather(r: Entity) -> void:
	if not is_villager():
		order_move(r.position)
		return
	state = S.GATHER
	target = r
	if r is ResourceNode:
		last_res_kind = r.kind
	else:
		last_res_kind = "farm"
	last_res_pos = r.position
	_set_path(r.position)


func order_build(b: Entity) -> void:
	if not is_villager():
		order_move(b.position)
		return
	state = S.BUILD
	target = b
	_set_path(b.position)


func stop() -> void:
	state = S.IDLE
	target = null
	path = PackedVector2Array()
	moving = false
	guard_pos = position


func _set_path(p: Vector2) -> void:
	path = game.find_path(position, p)
	path_i = 0
	stuck_t = 0.0


# ---------------------------------------------------------------- update

func _physics_process(delta: float) -> void:
	if dead or game == null or game.game_over:
		return
	cooldown -= delta
	swing = maxf(0.0, swing - delta)
	if flash > 0.0:
		flash -= delta
	moving = false
	match state:
		S.IDLE:
			_do_idle(delta)
		S.MOVE:
			if attack_move:
				scan_t -= delta
				if scan_t <= 0.0:
					scan_t = 0.4
					var e: Entity = game.nearest_enemy(position, team, sight)
					if e != null:
						state = S.ATTACK
						target = e
						auto_target = false
						_set_path(e.position)
						return
			if _follow(delta):
				stop()
				if attack_move:
					guard_pos = dest
		S.ATTACK:
			_do_attack(delta)
		S.GATHER:
			_do_gather(delta)
		S.RETURN:
			_do_return(delta)
		S.BUILD:
			_do_build(delta)
	if moving:
		anim += delta * 10.0
	queue_redraw()


func _do_idle(delta: float) -> void:
	if not is_military():
		return
	scan_t -= delta
	if scan_t > 0.0:
		return
	scan_t = 0.5
	var e: Entity = game.nearest_enemy(position, team, sight)
	if e != null:
		guard_pos = position
		state = S.ATTACK
		target = e
		attack_move = false
		auto_target = true
		_set_path(e.position)


func _follow(delta: float) -> bool:
	if path_i >= path.size():
		return true
	var nxt: Vector2 = path[path_i]
	var to := nxt - position
	var dist := to.length()
	var step := speed * delta
	if dist <= maxf(step, 4.0):
		position = nxt
		path_i += 1
		return path_i >= path.size()
	var dir := to / dist
	position += dir * step
	moving = true
	if absf(dir.x) > 0.2:
		facing = signf(dir.x)
	# stuck detection: recompute path if we hardly moved
	stuck_t += delta
	if stuck_t > 1.2:
		if position.distance_to(last_pos) < speed * 0.25:
			var goal: Vector2 = path[path.size() - 1]
			_set_path(goal)
		stuck_t = 0.0
		last_pos = position
	return false


func _move_towards_entity(e: Entity, delta: float) -> void:
	repath_t -= delta
	if repath_t <= 0.0 or path_i >= path.size():
		repath_t = 0.8 if e is Unit else 3.0
		_set_path(e.position)
	if path_i >= path.size():
		# no path: walk straight
		var dir := (e.position - position).normalized()
		var np := position + dir * speed * delta
		if not game.is_solid_at(np):
			position = np
			moving = true
		return
	_follow(delta)


func _do_attack(delta: float) -> void:
	if target == null or not is_instance_valid(target) or not target.is_alive():
		target = null
		if attack_move:
			order_move(dest, true)
		else:
			var e: Entity = game.nearest_enemy(position, team, sight) if is_military() else null
			if e != null:
				target = e
				_set_path(e.position)
			else:
				stop()
		return
	# give up chasing far from where we guarded (only for auto-acquired targets)
	if auto_target and target is Unit and position.distance_to(guard_pos) > sight * 2.5:
		order_move(guard_pos)
		return
	var gap: float = game.gap_between(self, target)
	if gap <= rng + 4.0:
		path = PackedVector2Array()
		path_i = 0
		var dx := target.position.x - position.x
		if absf(dx) > 1.0:
			facing = signf(dx)
		if cooldown <= 0.0:
			cooldown = cd
			swing = 0.25
			game.deal_damage(self, target)
	else:
		_move_towards_entity(target, delta)


func _target_res() -> String:
	if target != null and is_instance_valid(target):
		if target is ResourceNode:
			return target.res
		return "food"
	return carry_res


func _do_gather(delta: float) -> void:
	if target == null or not is_instance_valid(target) or not target.is_alive():
		target = game.find_resource_near(last_res_pos, last_res_kind, 420.0, team)
		if target == null:
			if carry > 0.0:
				target = null
				_go_return()
			else:
				stop()
			return
		last_res_pos = target.position
		_set_path(target.position)
		return
	var res: String = _target_res()
	if carry > 0.0 and carry_res != res:
		carry = 0.0 # dropped what it carried of another kind
	if carry >= DB.CARRY_CAP:
		_go_return()
		return
	var gap: float = game.gap_between(self, target)
	var reach := REACH
	if target is Building:
		reach = 2.0
	if gap <= reach:
		path = PackedVector2Array()
		path_i = 0
		carry_res = res
		var rate: float = DB.GATHER_RATE["farm"] if target is Building else DB.GATHER_RATE[res]
		rate *= game.gather_mult(team)
		var want := rate * delta
		var got := want
		if target is ResourceNode:
			got = target.harvest(want)
		carry += got
		swing = 0.2 if fmod(anim, 1.0) < 0.5 else 0.0
		anim += delta * 3.0
		var dx := target.position.x - position.x
		if absf(dx) > 1.0:
			facing = signf(dx)
		if carry >= DB.CARRY_CAP:
			_go_return()
	else:
		_move_towards_entity(target, delta)


func _go_return() -> void:
	var drop: Entity = game.nearest_drop(position, team, carry_res)
	if drop == null:
		stop()
		return
	state = S.RETURN
	_set_path(drop.position)
	repath_t = 3.0


func _do_return(delta: float) -> void:
	var drop: Entity = game.nearest_drop(position, team, carry_res)
	if drop == null:
		stop()
		return
	var gap: float = game.gap_between(self, drop)
	if gap <= REACH:
		game.add_res(team, carry_res, carry)
		carry = 0.0
		path = PackedVector2Array()
		path_i = 0
		# back to work
		var back: Entity = target
		if back == null or not is_instance_valid(back) or not back.is_alive():
			back = game.find_resource_near(last_res_pos, last_res_kind, 420.0, team)
		if back != null:
			state = S.GATHER
			target = back
			last_res_pos = back.position
			_set_path(back.position)
		else:
			stop()
	else:
		_move_towards_entity(drop, delta)


func _do_build(delta: float) -> void:
	if target == null or not is_instance_valid(target) or not target.is_alive():
		stop()
		return
	var b: Building = target
	if b.built:
		if b.kind == "farm" and not game.farm_taken(b, self):
			order_gather(b)
		else:
			# help with another unfinished building nearby, else rest
			var other: Entity = game.unfinished_near(position, team, 300.0)
			if other != null:
				order_build(other)
			else:
				stop()
		return
	var gap: float = game.gap_between(self, b)
	if gap <= REACH:
		path = PackedVector2Array()
		path_i = 0
		b.add_progress(delta)
		anim += delta * 3.0
		swing = 0.2 if fmod(anim, 1.0) < 0.5 else 0.0
	else:
		_move_towards_entity(b, delta)


func take_damage(amount: float, attacker: Node) -> void:
	super.take_damage(amount, attacker)
	if dead:
		return
	if is_military() and state == S.IDLE and attacker is Entity and attacker.is_alive():
		guard_pos = position
		order_attack(attacker)
		auto_target = true
	if game:
		game.on_attacked(self, attacker)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var tc: Color = DB.TEAM_COLORS[team]
	if flash > 0.0:
		tc = tc.lerp(Color.WHITE, 0.6)
	var bob := sin(anim) * 1.5 if moving else 0.0
	var f := facing
	# shadow
	draw_set_transform(Vector2(0, radius * 0.6), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, radius, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if selected:
		draw_set_transform(Vector2(0, radius * 0.6), 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, radius + 4.0, 0, TAU, 28, Color(0.4, 1.0, 0.4), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var skin := Color(0.95, 0.78, 0.6)
	var sw := swing * 4.0
	match kind:
		"villager":
			draw_circle(Vector2(0, -2 + bob), 6.5, tc)
			draw_rect(Rect2(-5, -2 + bob, 10, 6), tc.darkened(0.25))
			draw_circle(Vector2(0, -10 + bob), 4.0, skin)
			draw_line(Vector2(3 * f, -3 + bob), Vector2((8 + sw) * f, -10 + bob + sw), Color(0.45, 0.3, 0.15), 2.0)
			if carry > 0.5:
				draw_rect(Rect2(-9 * f - 3, -6 + bob, 6, 6), DB.RES_COLORS.get(carry_res, Color.WHITE))
		"spear":
			draw_circle(Vector2(0, -2 + bob), 7.5, tc)
			draw_circle(Vector2(0, -11 + bob), 4.0, skin)
			draw_arc(Vector2(0, -12 + bob), 4.5, PI, TAU, 8, Color(0.5, 0.5, 0.55), 2.5)
			var tip := Vector2((12 + sw * 2.0) * f, -16 + bob + sw)
			draw_line(Vector2(5 * f, 2 + bob), tip, Color(0.5, 0.33, 0.15), 2.0)
			draw_line(tip, tip + Vector2(3 * f, -3), Color(0.85, 0.85, 0.9), 2.5)
			draw_circle(Vector2(-6 * f, -2 + bob), 4.5, tc.darkened(0.4))
		"archer":
			draw_circle(Vector2(0, -2 + bob), 6.5, tc)
			draw_circle(Vector2(0, -10 + bob), 4.0, skin)
			draw_arc(Vector2(5 * f, -4 + bob), 7.0, -PI * 0.5 * f - (0.0 if f > 0 else PI), PI * 0.5 * f - (0.0 if f > 0 else PI), 10, Color(0.55, 0.35, 0.15), 2.0)
			draw_line(Vector2(5 * f, -11 + bob), Vector2(5 * f, 3 + bob), Color(0.9, 0.9, 0.9, 0.7), 1.0)
			draw_rect(Rect2(-7 * f - 2, -6 + bob, 4, 8), Color(0.45, 0.28, 0.12))
		"cavalry":
			var hc := Color(0.45, 0.3, 0.18)
			draw_set_transform(Vector2(0, 2 + bob * 0.5), 0.0, Vector2(1.5, 0.8))
			draw_circle(Vector2.ZERO, 8.0, hc)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_circle(Vector2(12 * f, -4 + bob * 0.5), 4.5, hc)
			draw_line(Vector2(-8, 8), Vector2(-8, 12), hc.darkened(0.3), 2.0)
			draw_line(Vector2(8, 8), Vector2(8, 12), hc.darkened(0.3), 2.0)
			draw_circle(Vector2(0, -8 + bob), 5.5, tc)
			draw_circle(Vector2(0, -15 + bob), 3.5, skin)
			draw_line(Vector2(2 * f, -8 + bob), Vector2((16 + sw * 2.0) * f, -14 + bob + sw), Color(0.8, 0.8, 0.85), 2.0)
		"catapult":
			var wc := Color(0.5, 0.33, 0.16)
			draw_rect(Rect2(-13, -4, 26, 9), wc)
			draw_circle(Vector2(-9, 6), 4.0, wc.darkened(0.4))
			draw_circle(Vector2(9, 6), 4.0, wc.darkened(0.4))
			var arm_a := -1.1 + swing * 4.0
			var arm_end := Vector2(cos(arm_a) * 18.0 * -f, sin(arm_a) * 18.0)
			draw_line(Vector2(4 * f, -2), Vector2(4 * f, -2) + arm_end, wc.lightened(0.1), 3.0)
			draw_circle(Vector2(4 * f, -2) + arm_end, 3.5, Color(0.4, 0.4, 0.42))
			draw_rect(Rect2(-13, -6, 26, 3), tc)
	draw_hp_bar(-radius - 14.0, radius * 2.2)
