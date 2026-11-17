extends Node
## --self-test: plays the core loop with scripted taps and button presses, measures the game state, writes JSON.

var main: Node = null
var game: Node = null
var hud: Node = null
var out_path: String = ""
var steps: Array = []


var finished: bool = false
var started_ms: int = 0
const WATCHDOG_MS := 150000


func run(m: Node, path: String) -> void:
	main = m
	out_path = path
	process_mode = Node.PROCESS_MODE_ALWAYS
	started_ms = Time.get_ticks_msec()
	_go.call_deferred()


## Writes whatever was measured if the run takes far too long, so a report always exists.
func _process(_delta: float) -> void:
	if not finished and Time.get_ticks_msec() - started_ms > WATCHDOG_MS:
		_step("watchdog", false, "self-test did not finish within %d s of real time" % (WATCHDOG_MS / 1000))
		_finish()


func _finish() -> void:
	if finished:
		return
	finished = true
	var all_ok := true
	for s in steps:
		all_ok = all_ok and s["passed"]
	var data := {"version": 1, "passed": all_ok, "steps": steps}
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))
		f.close()
		print("[self-test] report written to ", out_path)
	else:
		push_error("could not write self-test file %s: %s" % [out_path, error_string(FileAccess.get_open_error())])
	Engine.time_scale = 1.0
	get_tree().quit(0 if all_ok else 1)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, false).timeout


func _step(name: String, ok: bool, detail: String) -> void:
	steps.append({"step": name, "passed": ok, "detail": detail})
	print("[self-test] %s: %s - %s" % [name, "PASS" if ok else "FAIL", detail])


func _button(title_prefix: String) -> Button:
	for b in hud.action_grid.get_children():
		if b is Button and (b.text.begins_with(title_prefix) or (b.has_meta("title") and String(b.get_meta("title")).begins_with(title_prefix))):
			return b
	return null


func _free_spot(near: Vector2) -> Vector2:
	for r in range(4, 20):
		for a in 12:
			var p := near + Vector2(cos(a * TAU / 12.0), sin(a * TAU / 12.0)) * r * 20.0
			if not game.is_solid_at(p) and game.pick_entity(p) == null:
				return p
	return near


func _go() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	game = main.game
	hud = main.hud
	Engine.time_scale = 4.0
	var p: Dictionary = game.players[0]
	var vills: Array = game.units_of(0, true)
	var tc: Building = game.find_building(0, "town_center")

	# ---------- MOVE: tap a villager, tap the ground
	var v: Unit = vills[0]
	game.handle_tap(v.position + Vector2(0, -6))
	var picked: bool = game.selection.size() == 1 and game.selection[0] == v
	var start := v.position
	var goal := _free_spot(start + Vector2(170, -110))
	game.handle_tap(goal)
	await _wait(4.0)
	var moved := v.position.distance_to(start)
	_step("move", picked and moved > 80.0, "villager selected by tap: %s; walked %.0f px (%.1f m at 32 px = 1 m) toward the tapped spot" % [picked, moved, moved / 32.0])

	# ---------- ACT: gather, train, build (at the same time)
	var wood0: float = p["res"]["wood"]
	var gatherers: Array = [vills[1], vills[2]]
	var tree: Entity = game.find_resource_near(tc.position, "tree", 1500.0, 0)
	game.select(gatherers)
	game.handle_tap(tree.position)
	var gather_cmd: bool = gatherers[0].state == Unit.S.GATHER
	# train a villager from the town center button
	game.handle_tap(tc.position)
	var tc_selected: bool = game.selection.size() == 1 and game.selection[0] == tc
	var pop0: int = p["pop"]
	var tb := _button("Aldeão")
	if tb:
		tb.emit_signal("pressed")
	var queued: bool = tc.queue.size() > 0
	# build a house with the last villager
	var builder: Unit = vills[3]
	game.handle_tap(builder.position + Vector2(0, -6))
	var cap0: int = p["pop_cap"]
	var hb := _button("Casa")
	if hb:
		hb.emit_signal("pressed")
	var spot := tc.position + Vector2(-40, -180)
	game.handle_tap(spot)
	var cb := _button("Construir")
	if cb:
		cb.emit_signal("pressed")
	var house: Building = null
	for b in game.buildings:
		if b.team == 0 and b.kind == "house":
			house = b
	await _wait(24.0)
	var wood1: float = p["res"]["wood"]
	var house_cost: float = 40.0
	var gathered := wood1 - wood0 + house_cost
	var built: bool = house != null and is_instance_valid(house) and house.built and p["pop_cap"] > cap0
	var pop1: int = p["pop"]
	var trained: bool = pop1 > pop0

	# ---------- fight: two spearmen meet in the middle of the map
	var mid := Vector2(DB.MAP_W, DB.MAP_H) * 0.5
	mid = _free_spot(mid)
	var mine: Unit = game.spawn_unit("spear", 0, mid)
	var foe: Unit = game.spawn_unit("archer", 1, _free_spot(mid + Vector2(200, 0)))
	var foe_hp0: float = foe.hp
	game.select([mine])
	game.handle_tap(foe.position + Vector2(0, -6))
	var attack_cmd: bool = mine.state == Unit.S.ATTACK
	await _wait(14.0)
	var foe_dead: bool = not is_instance_valid(foe) or foe.dead
	var dealt: float = foe_hp0 if foe_dead else foe_hp0 - foe.hp
	var fought: bool = attack_cmd and dealt > 0.0
	_step("act", gather_cmd and gathered > 5.0 and queued and trained and fought,
		"gather order %s queued %s; 2 villagers gathered %.0f wood; town center trained a villager by its button (pop %d -> %d); spearman ordered by tap dealt %.0f damage to an enemy archer (killed: %s)" % [gather_cmd, queued, gathered, pop0, pop1, dealt, foe_dead])
	_step("build", built, "house placed with the build button and a tap, finished by a villager: population cap %d -> %d" % [cap0, p["pop_cap"]])

	# ---------- epoch: advance from the town center button
	for r in DB.RES:
		p["res"][r] += 1000
	game.select([tc])
	await get_tree().process_frame
	var eb := _button("Avançar")
	if eb:
		eb.emit_signal("pressed")
	var ep0: int = p["epoch"]
	await _wait(32.0)
	_step("epoch", p["epoch"] == ep0 + 1, "advance button pressed: %s -> %s; archers and towers unlocked: %s" % [DB.EPOCHS[ep0]["name"], DB.EPOCHS[p["epoch"]]["name"], p["epoch"] >= 1])

	# ---------- computer opponent
	var ai_p: Dictionary = game.players[1]
	var ai_ok: bool = game.stats["gathered"][1] > 20.0 and ai_p["pop"] > DB.START_VILLAGERS
	_step("ai", ai_ok, "computer gathered %.0f resources and has %d population after %.0f s" % [game.stats["gathered"][1], ai_p["pop"], game.time_elapsed])

	# ---------- HUD
	game.select(game.units_of(0, true))
	await get_tree().process_frame
	hud.refresh_t = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	var res_ok := true
	for r in DB.RES:
		if hud.res_labels[r].text != str(int(p["res"][r])):
			res_ok = false
	var pop_ok: bool = hud.pop_label.text == "Pop %d/%d" % [p["pop"], p["pop_cap"]]
	var ep_ok: bool = hud.epoch_label.text == DB.EPOCHS[p["epoch"]]["name"]
	var mm_ok: bool = hud.minimap.visible and hud.minimap.size.x > 50.0
	var sel_ok: bool = hud.info_name.text != "" and hud.action_grid.get_child_count() >= 5
	_step("hud", res_ok and pop_ok and ep_ok and mm_ok and sel_ok,
		"resources %s, population '%s', epoch '%s', minimap %s, selection panel '%s' with %d buttons" % [res_ok, hud.pop_label.text, hud.epoch_label.text, mm_ok, hud.info_name.text, hud.action_grid.get_child_count()])

	_finish()
