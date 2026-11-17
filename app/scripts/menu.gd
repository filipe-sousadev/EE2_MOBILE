extends CanvasLayer
## Title screen with difficulty choice.

var main: Node = null
var chosen: String = "Normal"
var diff_buttons: Dictionary = {}
var helper: Node = null


func setup(m: Node) -> void:
	main = m
	var bg := Control.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.set_script(load("res://scripts/menu_bg.gd"))
	add_child(bg)
	var hud_like: GDScript = load("res://scripts/hud.gd")
	helper = hud_like.new()
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.offset_left = -240
	v.offset_right = 240
	v.offset_top = -200
	v.offset_bottom = 220
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	var title := Label.new()
	title.text = "Eras de Conquista"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	v.add_child(title)
	var sub := Label.new()
	sub.text = "Colete, construa, avance de época e conquiste."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	v.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	v.add_child(gap)
	var dl := Label.new()
	dl.text = "Dificuldade do adversário"
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dl.add_theme_font_size_override("font_size", 17)
	v.add_child(dl)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 10)
	v.add_child(hb)
	var labels := {"Facil": "Fácil", "Normal": "Normal", "Dificil": "Difícil"}
	for k in ["Facil", "Normal", "Dificil"]:
		var b: Button = helper.make_button(labels[k], 20)
		b.custom_minimum_size = Vector2(140, 54)
		b.toggle_mode = true
		b.button_pressed = k == chosen
		b.pressed.connect(_choose.bind(k))
		hb.add_child(b)
		diff_buttons[k] = b
	var play: Button = helper.make_button("Jogar", 26)
	play.custom_minimum_size = Vector2(0, 66)
	play.pressed.connect(func(): main.start_game(chosen))
	v.add_child(play)
	var tip := Label.new()
	tip.text = "Toque para selecionar e dar ordens. Arraste para mover a câmera.\nSegure e arraste para selecionar vários. Use a pinça para zoom."
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 14)
	tip.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	v.add_child(tip)


func _choose(k: String) -> void:
	chosen = k
	for d in diff_buttons:
		diff_buttons[d].button_pressed = d == k


func _exit_tree() -> void:
	if helper:
		helper.free()
