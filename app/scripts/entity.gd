class_name Entity
extends Node2D
## Base for units, buildings and resource nodes.

var game: Node = null
var team: int = -1 # 0 = player, 1 = computer, -1 = nature
var kind: String = ""
var hp: float = 1.0
var max_hp: float = 1.0
var radius: float = 10.0
var selected: bool = false
var dead: bool = false
var flash: float = 0.0


func is_alive() -> bool:
	return not dead and is_instance_valid(self)


func cls() -> String:
	return "none"


func display_name() -> String:
	return kind


func set_selected(v: bool) -> void:
	selected = v
	queue_redraw()


func take_damage(amount: float, _attacker: Node) -> void:
	if dead:
		return
	hp -= amount
	flash = 0.15
	queue_redraw()
	if hp <= 0.0:
		hp = 0.0
		die()


func die() -> void:
	if dead:
		return
	dead = true
	if game:
		game.on_entity_died(self)
	queue_free()


func draw_hp_bar(y: float, w: float) -> void:
	if max_hp <= 0.0:
		return
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	if frac >= 0.999 and not selected:
		return
	draw_rect(Rect2(-w * 0.5, y, w, 4), Color(0, 0, 0, 0.7))
	var c := Color(0.3, 0.9, 0.3) if frac > 0.5 else (Color(0.95, 0.8, 0.2) if frac > 0.25 else Color(0.95, 0.25, 0.2))
	draw_rect(Rect2(-w * 0.5, y, w * frac, 4), c)
