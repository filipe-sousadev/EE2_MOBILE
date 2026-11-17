extends Node
## Entry point: main menu, starting/restarting matches, --screenshot and --self-test.

var game: Node2D = null
var hud: CanvasLayer = null
var menu: CanvasLayer = null
var difficulty: String = "Normal"
var shot_path: String = ""
var test_path: String = ""
var frames: int = 0
var shooting: bool = false
var soak: float = 0.0
var soak_log: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args: Array = []
	args.append_array(OS.get_cmdline_args())
	args.append_array(OS.get_cmdline_user_args())
	for i in args.size():
		var a: String = args[i]
		if a == "--screenshot" and i + 1 < args.size():
			shot_path = args[i + 1]
		elif a.begins_with("--screenshot="):
			shot_path = a.substr(13)
		elif a == "--self-test" and i + 1 < args.size():
			test_path = args[i + 1]
		elif a.begins_with("--self-test="):
			test_path = a.substr(12)
		elif a == "--soak" and i + 1 < args.size():
			soak = float(args[i + 1])
	shot_path = _absolute(shot_path)
	test_path = _absolute(test_path)
	if soak > 0.0:
		start_game("Normal")
		Engine.time_scale = 10.0
		return
	if shot_path != "" or test_path != "":
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		# keep running even when the window is covered (vsync can block a hidden window on Wayland)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 60
		print("[checks] screenshot=%s self-test=%s" % [shot_path, test_path])
		start_game("Normal")
		if test_path != "":
			var t: Node = load("res://scripts/selftest.gd").new()
			add_child(t)
			t.run(self, test_path)
		elif shot_path != "":
			_stage_screenshot()
	else:
		show_menu()


func _absolute(p: String) -> String:
	if p == "" or p.is_absolute_path() or p.begins_with("res://") or p.begins_with("user://"):
		return p
	# the process's real working folder (not the shell's PWD variable, which a launcher may leave stale)
	var here := DirAccess.open(".")
	var cwd := here.get_current_dir() if here else ""
	if cwd == "" or cwd.begins_with("res://"):
		cwd = OS.get_environment("PWD")
	if cwd == "":
		cwd = ProjectSettings.globalize_path("res://")
	return cwd.path_join(p)


func _process(_delta: float) -> void:
	if soak > 0.0 and game:
		_soak_tick()
		return
	if shot_path == "" or test_path != "" or shooting:
		return
	frames += 1
	if frames >= 120:
		shooting = true
		_capture()


## --soak <seconds>: lets a match run fast with an idle player and prints the opponent's progress (developer check).
func _soak_tick() -> void:
	if game.time_elapsed >= soak_log:
		soak_log += 30.0
		var ap: Dictionary = game.players[1]
		print("t=%4.0f ai epoch=%d pop=%d/%d army=%d vills=%d res=%s waves=%d | player pop=%d bld=%d over=%s" % [game.time_elapsed, ap["epoch"], ap["pop"], ap["pop_cap"], game.units_of(1, false).size(), game.units_of(1, true).size(), str(ap["res"]).replace(" ", ""), game.ai.waves_sent, game.players[0]["pop"], game.count_buildings(0, "town_center"), game.game_over])
	if game.time_elapsed >= soak or game.game_over:
		print("soak end t=%.0f over=%s winner=%d" % [game.time_elapsed, game.game_over, game.winner])
		if shot_path != "" and not shooting:
			shooting = true
			Engine.time_scale = 1.0
			var tc: Building = game.find_building(1, "town_center")
			if tc:
				game.center_on(tc.position + Vector2(-150, 120))
				game.select([tc])
			await get_tree().create_timer(0.5).timeout
			_capture()
		elif shot_path == "":
			get_tree().quit()


func _stage_screenshot() -> void:
	# a lively first view: villagers at work, the player's town selected
	Engine.time_scale = 3.0
	var vills: Array = game.units_of(0, true)
	var tree: Entity = game.find_resource_near(vills[0].position, "tree", 900.0, 0)
	var berries: Entity = game.find_resource_near(vills[0].position, "berries", 900.0, 0)
	if berries:
		game.command_gather(vills.slice(0, 2), berries)
	if tree:
		game.command_gather(vills.slice(2, 4), tree)
	game.select(vills)


func _capture() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(shot_path.get_base_dir())
	var err := img.save_png(shot_path)
	if err != OK:
		push_error("could not save screenshot: %s" % error_string(err))
	get_tree().quit()


func _clear() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0 if test_path == "" and shot_path == "" else Engine.time_scale
	for n in [game, hud, menu]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	game = null
	hud = null
	menu = null


func start_game(diff: String) -> void:
	_clear()
	difficulty = diff
	game = Node2D.new()
	game.set_script(load("res://scripts/game.gd"))
	add_child(game)
	game.setup(diff, null)
	hud = CanvasLayer.new()
	hud.set_script(load("res://scripts/hud.gd"))
	add_child(hud)
	hud.setup(game, self)
	game.hud = hud
	hud.message("Destrua o Centro da Cidade inimigo!", 4.0)


func restart() -> void:
	start_game(difficulty)


func show_menu() -> void:
	_clear()
	menu = CanvasLayer.new()
	menu.set_script(load("res://scripts/menu.gd"))
	add_child(menu)
	menu.setup(self)
