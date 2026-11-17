extends Node
## The computer opponent: gathers, builds, advances epochs, trains an army and attacks in waves.

var game: Node = null
var team: int = 1
var cfg: Dictionary = {}
var think_t: float = 2.0
var wave_size: int = 6
var next_attack: float = 300.0
var waves_sent: int = 0
var defend_t: float = -100.0
var attackers: Array = []


func setup(g: Node, difficulty: String) -> void:
	game = g
	cfg = DB.DIFFICULTY.get(difficulty, DB.DIFFICULTY["Normal"])
	wave_size = cfg["wave"]
	next_attack = cfg["first_attack"]


func _physics_process(delta: float) -> void:
	if game == null or game.game_over:
		return
	defend_t -= delta
	think_t -= delta
	if think_t <= 0.0:
		think_t = cfg["think"]
		_think()


func _tc() -> Building:
	return game.find_building(team, "town_center")


func _think() -> void:
	var tc := _tc()
	if tc == null:
		return
	var p: Dictionary = game.players[team]
	var vills: Array = game.units_of(team, true)
	var army: Array = game.units_of(team, false)
	var epoch: int = p["epoch"]

	# --- villagers to work
	var counts := {"food": 0, "wood": 0, "stone": 0, "gold": 0, "build": 0}
	for v in vills:
		if v.state == Unit.S.BUILD:
			counts["build"] += 1
		elif v.state in [Unit.S.GATHER, Unit.S.RETURN]:
			var r: String = v.carry_res if v.carry_res != "" else v._target_res()
			if counts.has(r):
				counts[r] += 1
	for v in vills:
		if v.is_idle():
			_assign(v, counts, vills.size(), epoch)

	# --- economy
	var researching := "epoch" in tc.queue
	if vills.size() + _queued(tc, "villager") < int(cfg["villagers"]) + 4 * epoch and tc.queue.size() < 2 and not researching:
		game.train(tc, "villager")
	if p["pop_cap"] < DB.POP_MAX and p["pop_cap"] - p["pop"] <= 4 and not _has_unfinished("house"):
		_build("house", tc.position)
	var barracks: int = game.count_buildings(team, "barracks")
	if barracks == 0 and vills.size() >= 6:
		_build("barracks", tc.position)
	elif barracks == 1 and epoch >= 1 and vills.size() >= 14 and DB.difficulty != "Facil":
		_build("barracks", tc.position)
	if game.count_buildings(team, "depot") == 0 and vills.size() >= 8:
		var tree: Entity = game.find_resource_near(tc.position, "tree", 2000.0, team)
		if tree and tree.position.distance_to(tc.position) > 260.0:
			_build("depot", tree.position)
	if epoch >= 1 and game.count_buildings(team, "tower") < (2 if DB.difficulty == "Dificil" else 1):
		_build("tower", tc.position)
	# --- epochs
	if epoch < DB.EPOCHS.size() - 1 and not researching and vills.size() >= 9 + epoch * 3:
		var cost: Dictionary = DB.EPOCHS[epoch + 1]["cost"]
		if game.can_afford(team, cost):
			game.queue_epoch(tc)
	# --- army
	for b in game.buildings:
		if b.team == team and b.kind == "barracks" and b.built and not b.dead and b.queue.size() < 2:
			var k := _pick_unit(epoch, army)
			if k != "" and _keep_reserve(DB.UNITS[k]["cost"], epoch, army.size(), vills.size()):
				game.train(b, k)
	# --- waves
	_cleanup_attackers()
	if game.time_elapsed >= next_attack:
		var home: Array = []
		for u in army:
			if not u in attackers:
				home.append(u)
		if home.size() >= wave_size:
			var target: Entity = game.find_building(0, "town_center", false)
			if target:
				for u in home:
					u.order_move(target.position, true)
					attackers.append(u)
				waves_sent += 1
				wave_size += int(cfg["wave_grow"])
				next_attack = game.time_elapsed + 150.0
				if game.hud:
					game.hud.message("Um exército inimigo está a caminho!", 4.0)


func _cleanup_attackers() -> void:
	for i in range(attackers.size() - 1, -1, -1):
		if not is_instance_valid(attackers[i]) or attackers[i].dead:
			attackers.remove_at(i)
		elif attackers[i].is_idle():
			# reached the target area with nothing left: keep pushing toward any player building
			var b: Entity = _any_player_building(attackers[i].position)
			if b:
				attackers[i].order_move(b.position, true)


func _any_player_building(from: Vector2) -> Entity:
	var best: Entity = null
	var bd := 1e9
	for b in game.buildings:
		if b.team == 0 and not b.dead:
			var dd: float = b.position.distance_to(from)
			if dd < bd:
				bd = dd
				best = b
	return best


func _keep_reserve(cost: Dictionary, epoch: int, army_size: int, vills: int) -> bool:
	# once there is a small guard and a working economy, save for the next epoch first
	if epoch >= DB.EPOCHS.size() - 1 or "epoch" in _tc().queue:
		return game.can_afford(team, cost)
	var nxt: Dictionary = DB.EPOCHS[epoch + 1]["cost"]
	var share := 0.0
	if vills >= 10 and army_size >= 3 + 3 * epoch:
		share = 1.0
	elif game.time_elapsed > 150.0:
		share = 0.4
	if defend_t > -20.0 and army_size < wave_size:
		share = 0.0 # recently attacked: soldiers first
	var res: Dictionary = game.players[team]["res"]
	for k in cost:
		if res[k] - cost[k] < float(nxt.get(k, 0)) * share:
			return false
	return true


func _queued(b: Building, k: String) -> int:
	var n := 0
	for q in b.queue:
		if q == k:
			n += 1
	return n


func _has_unfinished(k: String) -> bool:
	for b in game.buildings:
		if b.team == team and b.kind == k and not b.built and not b.dead:
			return true
	return false


func _assign(v: Unit, counts: Dictionary, total: int, epoch: int) -> void:
	var want := {"food": 0.5, "wood": 0.34, "gold": 0.1, "stone": 0.06}
	if epoch >= 1:
		want = {"food": 0.38, "wood": 0.3, "gold": 0.22, "stone": 0.1}
	if epoch >= 2:
		want = {"food": 0.36, "wood": 0.26, "gold": 0.26, "stone": 0.12}
	var best := "food"
	var bv := -1e9
	for r in want:
		var deficit: float = want[r] * total - counts[r]
		if deficit > bv:
			bv = deficit
			best = r
	var tc := _tc()
	var target: Entity = null
	match best:
		"food":
			target = game.find_resource_near(tc.position, "berries", 650.0, team)
			if target == null:
				target = game.find_resource_near(tc.position, "farm", 900.0, team)
			if target == null:
				if not _has_unfinished("farm"):
					var f := _build("farm", tc.position, v)
					if f:
						counts["build"] += 1
						return
				var uf: Entity = game.unfinished_near(tc.position, team, 700.0)
				if uf:
					v.order_build(uf)
					return
				best = "wood"
		"gold":
			target = game.find_resource_near(tc.position, "gold", 1600.0, team)
		"stone":
			target = game.find_resource_near(tc.position, "stone", 1600.0, team)
	if target == null:
		var kind := "tree"
		if best == "gold" or best == "stone":
			kind = best
		target = game.find_resource_near(_drop_anchor(), kind, 3000.0, team)
		if target == null:
			target = game.find_resource_near(tc.position, "tree", 4000.0, team)
		best = "wood" if kind == "tree" else best
	if target:
		v.order_gather(target)
		counts[best] = counts.get(best, 0) + 1


func _drop_anchor() -> Vector2:
	for b in game.buildings:
		if b.team == team and b.kind == "depot" and b.built and not b.dead:
			return b.position
	return _tc().position


func _pick_unit(epoch: int, army: Array) -> String:
	var options := []
	for k in ["spear", "archer", "cavalry", "catapult"]:
		if int(DB.UNITS[k]["epoch"]) <= epoch:
			options.append(k)
	if options.is_empty():
		return ""
	# counter what the player fields most
	var seen := {"infantry": 0, "archer": 0, "cavalry": 0, "siege": 0}
	for u in game.units_of(0, false):
		seen[u.cls()] = seen.get(u.cls(), 0) + 1
	var top := ""
	var tv := 2
	for c in seen:
		if seen[c] > tv:
			tv = seen[c]
			top = c
	var counter := {"cavalry": "spear", "infantry": "archer", "archer": "cavalry", "siege": "cavalry"}
	if top != "" and randf() < 0.6:
		var k: String = counter[top]
		if k in options:
			return k
	var cats := 0
	for u in army:
		if u.kind == "catapult":
			cats += 1
	var roll := randf()
	if "catapult" in options and cats < 2 and roll < 0.15:
		return "catapult"
	if "cavalry" in options and roll < 0.4:
		return "cavalry"
	if "archer" in options and roll < 0.7:
		return "archer"
	return "spear"


func _build(k: String, anchor: Vector2, builder: Unit = null) -> Building:
	if not game.can_afford(team, DB.BUILDINGS[k]["cost"]):
		return null
	var spot := _find_spot(k, anchor)
	if spot.x < 0:
		return null
	game.pay(team, DB.BUILDINGS[k]["cost"])
	var b: Building = game.place_building(k, team, spot, false)
	var helpers := []
	if builder:
		helpers.append(builder)
	var vills: Array = game.units_of(team, true)
	vills.sort_custom(func(a, c): return a.position.distance_to(b.position) < c.position.distance_to(b.position))
	var need := 1 if k in ["house", "farm"] else 2
	for v in vills:
		if helpers.size() >= need:
			break
		if v in helpers or v.state == Unit.S.BUILD:
			continue
		helpers.append(v)
	for v in helpers:
		v.order_build(b)
	return b


func _find_spot(k: String, anchor: Vector2) -> Vector2i:
	var s: int = DB.BUILDINGS[k]["size"]
	var ac: Vector2i = game.cell_of(anchor) - Vector2i(s / 2, s / 2)
	var start_r := 3 if k == "farm" else 4
	var pad := 0 if k == "farm" else 1
	var off := randi() % 8
	for r in range(start_r, 22):
		var ring := []
		for y in range(ac.y - r, ac.y + r + 1):
			for x in range(ac.x - r, ac.x + r + 1):
				if absi(x - ac.x) == r or absi(y - ac.y) == r:
					ring.append(Vector2i(x, y))
		if ring.is_empty():
			continue
		for i in ring.size():
			var c: Vector2i = ring[(i + off * ring.size() / 8) % ring.size()]
			if game.can_place(k, c, pad):
				return c
	return Vector2i(-1, -1)


func on_unit_trained(u: Unit) -> void:
	if u.is_military():
		var tc := _tc()
		if tc:
			u.order_move(tc.position + Vector2(-180, 160) + Vector2(randf_range(-60, 60), randf_range(-60, 60)))


func on_building_complete(_b: Building) -> void:
	pass


func on_attacked(victim: Entity, attacker: Node) -> void:
	if defend_t > 0.0 or not (attacker is Entity) or not attacker.is_alive():
		return
	var tc := _tc()
	if tc == null or attacker.position.distance_to(tc.position) > 800.0:
		return
	defend_t = 2.0
	for u in game.units_of(team, false):
		if u in attackers:
			continue
		if u.state != Unit.S.ATTACK:
			u.order_attack(attacker)
	# villagers under attack by soldiers run to the town center
	if victim is Unit and victim.is_villager() and attacker is Unit and attacker.is_military():
		victim.order_move(tc.position + (victim.position - tc.position).normalized() * (tc.half + 20.0))
