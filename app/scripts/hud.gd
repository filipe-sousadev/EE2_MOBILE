extends CanvasLayer
## Touch HUD: resources on top, minimap bottom-left, selection and actions at the bottom, shortcuts on the right.

const EPOCH_SHORT := ["Pedra", "Bronze", "Ferro", "Medieval"]

var game: Node = null
var main: Node = null
var top_bar: Panel
var res_labels: Dictionary = {}
var pop_label: Label
var epoch_label: Label
var time_label: Label
var pause_btn: Button
var msg_label: Label
var msg_t: float = 0.0
var minimap: Control
var panel: Panel
var info_name: Label
var info_detail: Label
var info_status: Label
var action_grid: GridContainer
var side_box: VBoxContainer
var end_panel: Panel
var pause_panel: Panel
var box_panel: Panel
var refresh_t: float = 0.0
var font_big := 18
var buttons_dirty: bool = true


func setup(g: Node, m: Node) -> void:
	game = g
	main = m
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	refresh_selection()


# ---------------------------------------------------------------- construction

func _style(bg: Color, border: Color = Color(0.75, 0.6, 0.3), bw: int = 2, rad: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(rad)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


func _label(text: String, size: int = 16, color: Color = Color(0.96, 0.92, 0.82)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


func make_button(text: String, size: int = 15) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", _style(Color(0.24, 0.19, 0.12, 0.95)))
	b.add_theme_stylebox_override("hover", _style(Color(0.32, 0.25, 0.15, 0.95)))
	b.add_theme_stylebox_override("pressed", _style(Color(0.45, 0.35, 0.18, 0.95), Color(1, 0.85, 0.4)))
	b.add_theme_stylebox_override("disabled", _style(Color(0.15, 0.13, 0.11, 0.9), Color(0.4, 0.35, 0.28)))
	b.add_theme_color_override("font_color", Color(0.98, 0.93, 0.8))
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.5, 0.45))
	return b


func _build() -> void:
	# top bar
	top_bar = Panel.new()
	top_bar.add_theme_stylebox_override("panel", _style(Color(0.12, 0.09, 0.06, 0.88), Color(0.7, 0.55, 0.28), 2, 0))
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 36
	add_child(top_bar)
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 10
	hb.offset_right = -60
	hb.add_theme_constant_override("separation", 14)
	top_bar.add_child(hb)
	for r in DB.RES:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 5)
		var icon := ColorRect.new()
		icon.color = DB.RES_COLORS[r]
		icon.custom_minimum_size = Vector2(16, 16)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(icon)
		var l := _label("0", font_big)
		l.custom_minimum_size = Vector2(62, 0)
		l.tooltip_text = DB.RES_NAMES[r]
		box.add_child(l)
		res_labels[r] = l
		hb.add_child(box)
	pop_label = _label("Pop 0/0", font_big)
	hb.add_child(pop_label)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	epoch_label = _label("", font_big, Color(1.0, 0.85, 0.45))
	hb.add_child(epoch_label)
	time_label = _label("00:00", font_big)
	time_label.custom_minimum_size = Vector2(60, 0)
	hb.add_child(time_label)
	pause_btn = make_button("II", 18)
	pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.offset_left = -52
	pause_btn.offset_right = -4
	pause_btn.offset_top = 2
	pause_btn.offset_bottom = 34
	pause_btn.pressed.connect(_on_pause)
	top_bar.add_child(pause_btn)

	# message line
	msg_label = _label("", 20, Color(1, 0.95, 0.7))
	msg_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	msg_label.offset_top = 44
	msg_label.offset_bottom = 74
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(msg_label)

	# minimap
	minimap = Control.new()
	minimap.set_script(load("res://scripts/minimap.gd"))
	minimap.set("game", game)
	minimap.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	minimap.offset_left = 6
	minimap.offset_right = 6 + 186
	minimap.offset_top = -130
	minimap.offset_bottom = -6
	add_child(minimap)

	# selection panel
	panel = Panel.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.12, 0.09, 0.06, 0.9)))
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 198
	panel.offset_right = -132
	panel.offset_top = -124
	panel.offset_bottom = -4
	add_child(panel)
	var phb := HBoxContainer.new()
	phb.set_anchors_preset(Control.PRESET_FULL_RECT)
	phb.offset_left = 8
	phb.offset_right = -8
	phb.offset_top = 6
	phb.offset_bottom = -6
	phb.add_theme_constant_override("separation", 10)
	panel.add_child(phb)
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(250, 0)
	info.add_theme_constant_override("separation", 2)
	phb.add_child(info)
	info_name = _label("", 19, Color(1.0, 0.86, 0.5))
	info.add_child(info_name)
	info_detail = _label("", 15)
	info_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_detail.custom_minimum_size = Vector2(250, 0)
	info.add_child(info_detail)
	info_status = _label("", 14, Color(0.75, 0.9, 1.0))
	info_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_status.custom_minimum_size = Vector2(250, 0)
	info.add_child(info_status)
	action_grid = GridContainer.new()
	action_grid.columns = 4
	action_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_grid.add_theme_constant_override("h_separation", 6)
	action_grid.add_theme_constant_override("v_separation", 6)
	phb.add_child(action_grid)

	# side shortcuts
	side_box = VBoxContainer.new()
	side_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	side_box.offset_left = -126
	side_box.offset_right = -4
	side_box.offset_top = -170
	side_box.offset_bottom = -4
	side_box.add_theme_constant_override("separation", 6)
	add_child(side_box)
	var b1 := make_button("Exército", 16)
	b1.custom_minimum_size = Vector2(120, 50)
	b1.pressed.connect(func(): game.select_army())
	side_box.add_child(b1)
	var b2 := make_button("Ocioso", 16)
	b2.custom_minimum_size = Vector2(120, 50)
	b2.pressed.connect(func(): game.select_idle_villager())
	side_box.add_child(b2)
	var b3 := make_button("Base", 16)
	b3.custom_minimum_size = Vector2(120, 50)
	b3.pressed.connect(func(): game.center_base())
	side_box.add_child(b3)

	# drag-select box
	box_panel = Panel.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.4, 1.0, 0.4, 0.12)
	bs.border_color = Color(0.5, 1.0, 0.5, 0.9)
	bs.set_border_width_all(2)
	box_panel.add_theme_stylebox_override("panel", bs)
	box_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_panel.visible = false
	add_child(box_panel)

	# pause
	pause_panel = _center_panel(Vector2(360, 280))
	var pv: VBoxContainer = pause_panel.get_child(0)
	pv.add_child(_center_label(_label("Pausado", 28, Color(1, 0.86, 0.5))))
	var help := _label("Toque: selecionar / dar ordem\nArrastar: mover a câmera\nSegurar e arrastar: selecionar vários\nDois toques: todos do mesmo tipo\nPinça: zoom", 14)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(help)
	var c1 := make_button("Continuar", 18)
	c1.custom_minimum_size = Vector2(0, 44)
	c1.pressed.connect(_on_pause)
	pv.add_child(c1)
	var c2 := make_button("Menu principal", 18)
	c2.custom_minimum_size = Vector2(0, 44)
	c2.pressed.connect(_to_menu)
	pv.add_child(c2)
	pause_panel.visible = false

	end_panel = _center_panel(Vector2(400, 260))
	end_panel.visible = false


func _center_panel(sz: Vector2) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _style(Color(0.1, 0.08, 0.05, 0.95), Color(0.85, 0.68, 0.3), 3, 10))
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.offset_left = -sz.x * 0.5
	p.offset_right = sz.x * 0.5
	p.offset_top = -sz.y * 0.5
	p.offset_bottom = sz.y * 0.5
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_right = -16
	v.offset_top = 12
	v.offset_bottom = -12
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	add_child(p)
	return p


func _center_label(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


# ---------------------------------------------------------------- queries from the game

func is_over_ui(pos: Vector2) -> bool:
	for c in [top_bar, panel, minimap, side_box, pause_panel, end_panel]:
		if c.visible and c.get_global_rect().has_point(pos):
			return true
	if side_box.visible:
		for b in side_box.get_children():
			if b.get_global_rect().has_point(pos):
				return true
	return false


func set_box(r: Rect2, show: bool) -> void:
	box_panel.visible = show
	if show:
		box_panel.position = r.position
		box_panel.size = r.size


func message(text: String, dur: float = 2.5) -> void:
	msg_label.text = text
	msg_t = dur


func ping(world_pos: Vector2) -> void:
	minimap.ping(world_pos)


func show_end(won: bool) -> void:
	var v: VBoxContainer = end_panel.get_child(0)
	for c in v.get_children():
		c.queue_free()
	v.add_child(_center_label(_label("Vitória!" if won else "Derrota", 34, Color(1, 0.86, 0.4) if won else Color(1, 0.45, 0.4))))
	var st: Dictionary = game.stats
	var t := int(game.time_elapsed)
	v.add_child(_center_label(_label("Tempo: %02d:%02d\nInimigos derrotados: %d\nUnidades perdidas: %d\nRecursos coletados: %d" % [t / 60, t % 60, st["killed"][0], st["lost"][0], int(st["gathered"][0])], 16)))
	var again := make_button("Jogar de novo", 18)
	again.custom_minimum_size = Vector2(0, 46)
	again.pressed.connect(func(): main.restart())
	v.add_child(again)
	var menu := make_button("Menu principal", 18)
	menu.custom_minimum_size = Vector2(0, 46)
	menu.pressed.connect(func(): main.show_menu())
	v.add_child(menu)
	end_panel.visible = true


func _to_menu() -> void:
	get_tree().paused = false
	main.show_menu()


func _train(bld: Building, k: String) -> void:
	game.train(bld, k)
	_update_buttons()
	_update_info()


func _epoch(bld: Building) -> void:
	game.queue_epoch(bld)
	_update_buttons()
	_update_info()


func _cancel(bld: Building) -> void:
	game.cancel_last(bld)
	_update_buttons()
	_update_info()


func _on_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	pause_panel.visible = p


# ---------------------------------------------------------------- selection & actions

func refresh_selection() -> void:
	buttons_dirty = true
	refresh_actions()


func refresh_actions() -> void:
	for c in action_grid.get_children():
		action_grid.remove_child(c)
		c.queue_free()
	if game == null:
		return
	var sel: Array = game.selection
	var ep: int = game.players[0]["epoch"]
	if game.placing != "":
		var bc := make_button("Construir", 17)
		bc.custom_minimum_size = Vector2(120, 50)
		bc.pressed.connect(func(): game.confirm_place())
		action_grid.add_child(bc)
		var bx := make_button("Cancelar", 17)
		bx.custom_minimum_size = Vector2(120, 50)
		bx.pressed.connect(func(): game.cancel_place())
		action_grid.add_child(bx)
		_update_info()
		return
	var vills: Array = game.selected_villagers()
	var mine: Array = game.own_selected_units()
	if vills.size() > 0:
		for k in DB.BUILD_MENU:
			var d: Dictionary = DB.BUILDINGS[k]
			var b := _action_button(d["name"], d["cost"], int(d["epoch"]))
			b.pressed.connect(func(): game.start_place(k))
			action_grid.add_child(b)
	if mine.size() > 0:
		var st := make_button("Parar", 15)
		st.custom_minimum_size = Vector2(96, 46)
		st.pressed.connect(func(): game.command_stop())
		action_grid.add_child(st)
	elif sel.size() == 1 and sel[0] is Building and sel[0].team == 0 and sel[0].built:
		var bld: Building = sel[0]
		for k in bld.d["trains"]:
			var ud: Dictionary = DB.UNITS[k]
			var b := _action_button(ud["name"], ud["cost"], int(ud["epoch"]))
			b.pressed.connect(_train.bind(bld, k))
			action_grid.add_child(b)
		if bld.kind == "town_center" and ep < DB.EPOCHS.size() - 1:
			var nd: Dictionary = DB.EPOCHS[ep + 1]
			var eb := _action_button("Avançar: " + EPOCH_SHORT[ep + 1], nd["cost"], 0)
			eb.set_meta("epoch_btn", true)
			eb.custom_minimum_size = Vector2(150, 46)
			eb.pressed.connect(_epoch.bind(bld))
			action_grid.add_child(eb)
		if bld.d["trains"].size() > 0:
			var cb := make_button("Cancelar", 15)
			cb.custom_minimum_size = Vector2(96, 46)
			cb.set_meta("cancel_btn", true)
			cb.pressed.connect(_cancel.bind(bld))
			action_grid.add_child(cb)
	_update_buttons()
	_update_info()


func _action_button(title: String, cost: Dictionary, need_epoch: int) -> Button:
	var b := make_button(title + "\n" + DB.cost_text(cost), 14)
	b.custom_minimum_size = Vector2(96, 46)
	b.set_meta("cost", cost)
	b.set_meta("epoch", need_epoch)
	b.set_meta("title", title)
	return b


func _update_buttons() -> void:
	var ep: int = game.players[0]["epoch"]
	for b in action_grid.get_children():
		if b.has_meta("cost"):
			var need: int = b.get_meta("epoch")
			if ep < need:
				b.disabled = true
				b.text = "%s\n(%s)" % [b.get_meta("title"), EPOCH_SHORT[need]]
			else:
				b.text = "%s\n%s" % [b.get_meta("title"), DB.cost_text(b.get_meta("cost"))]
				b.disabled = not game.can_afford(0, b.get_meta("cost"))
			if b.has_meta("epoch_btn"):
				for o in game.buildings:
					if o.team == 0 and "epoch" in o.queue:
						b.disabled = true


func _update_info() -> void:
	var sel: Array = game.selection
	info_status.text = ""
	if game.placing != "":
		var d: Dictionary = DB.BUILDINGS[game.placing]
		info_name.text = "Construir: " + d["name"]
		info_detail.text = "Custo: " + DB.cost_text(d["cost"])
		info_status.text = "Toque no mapa para escolher o lugar"
		return
	if sel.is_empty():
		info_name.text = DB.EPOCHS[game.players[0]["epoch"]]["name"]
		info_detail.text = "Objetivo: destrua o Centro da Cidade inimigo."
		info_status.text = "Toque para selecionar. Segure e arraste para selecionar vários."
		return
	if sel.size() == 1:
		var e: Entity = sel[0]
		info_name.text = e.display_name() + ("" if e.team != 1 else " (inimigo)")
		if e is Unit:
			info_detail.text = "Vida %d/%d   Ataque %.0f" % [ceil(e.hp), ceil(e.max_hp), e.atk * game.epoch_mult(e.team)]
			var s: String = e.state_text()
			if e.carry > 0.5:
				s += "  (carrega %d %s)" % [int(e.carry), DB.RES_NAMES.get(e.carry_res, "")]
			info_status.text = s
		elif e is Building:
			info_detail.text = "Vida %d/%d" % [ceil(e.hp), ceil(e.max_hp)]
			if not e.built:
				info_status.text = "Em construção: %d%%" % int(100.0 * e.progress / e.build_time)
			elif not e.queue.is_empty():
				var item: String = e.queue[0]
				var nm: String = "Nova época" if item == "epoch" else DB.UNITS[item]["name"]
				info_status.text = "%s %d%%" % [nm, int(e.progress_frac() * 100.0)]
				if e.queue.size() > 1:
					info_status.text += "  (+%d na fila)" % (e.queue.size() - 1)
				if e.waiting_pop:
					info_status.text = "Sem população! Construa casas."
			elif e.d["drop"]:
				info_status.text = "Recebe recursos dos aldeões"
			elif e.kind == "house":
				info_status.text = "+5 de população"
			elif e.kind == "farm":
				info_status.text = "Comida sem fim para 1 aldeão"
		elif e is ResourceNode:
			info_detail.text = "Restante: %d %s" % [int(e.amount), DB.RES_NAMES[e.res]]
	else:
		var counts := {}
		for e in sel:
			var n: String = e.display_name()
			counts[n] = counts.get(n, 0) + 1
		info_name.text = "%d unidades" % sel.size()
		var parts := []
		for n in counts:
			parts.append("%d %s" % [counts[n], n])
		info_detail.text = ", ".join(parts)


func _process(delta: float) -> void:
	if game == null:
		return
	if msg_t > 0.0:
		msg_t -= delta
		msg_label.modulate.a = clampf(msg_t, 0.0, 1.0)
	refresh_t -= delta
	if refresh_t > 0.0:
		return
	refresh_t = 0.25
	var p: Dictionary = game.players[0]
	for r in DB.RES:
		res_labels[r].text = str(int(p["res"][r]))
	pop_label.text = "Pop %d/%d" % [p["pop"], p["pop_cap"]]
	epoch_label.text = DB.EPOCHS[p["epoch"]]["name"]
	var t := int(game.time_elapsed)
	time_label.text = "%02d:%02d" % [t / 60, t % 60]
	_update_buttons()
	_update_info()
	minimap.queue_redraw()
