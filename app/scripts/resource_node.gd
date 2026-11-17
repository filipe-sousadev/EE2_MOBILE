class_name ResourceNode
extends Entity
## A tree, berry bush, stone or gold deposit.

var res: String = "wood"
var amount: float = 100.0
var max_amount: float = 100.0
var shade: float = 0.0


func setup(g: Node, k: String, pos: Vector2) -> void:
	game = g
	kind = k
	team = -1
	position = pos
	var d: Dictionary = DB.RESOURCE_NODES[k]
	res = d["res"]
	amount = d["amount"]
	max_amount = amount
	radius = d["radius"]
	max_hp = 0.0
	hp = 1.0
	shade = randf_range(-0.08, 0.08)
	z_index = 1 if k == "tree" else 0


func cls() -> String:
	return "resource"


func display_name() -> String:
	match kind:
		"tree": return "Árvore"
		"berries": return "Arbustos de frutas"
		"stone": return "Jazida de pedra"
		"gold": return "Mina de ouro"
	return kind


## Takes up to `want`; returns what was taken.
func harvest(want: float) -> float:
	var got := minf(want, amount)
	amount -= got
	if amount <= 0.001 and not dead:
		dead = true
		if game:
			game.on_entity_died(self)
		queue_free()
	elif kind != "tree":
		queue_redraw()
	return got


func _draw() -> void:
	match kind:
		"tree":
			draw_circle(Vector2(3, 5), radius, Color(0, 0, 0, 0.25))
			draw_rect(Rect2(-2.5, 0, 5, 9), Color(0.4, 0.26, 0.12))
			draw_circle(Vector2(0, -3), radius, Color(0.12 + shade, 0.42 + shade, 0.16))
			draw_circle(Vector2(-4, -7), radius * 0.6, Color(0.18 + shade, 0.52 + shade, 0.2))
		"berries":
			draw_circle(Vector2(2, 3), radius, Color(0, 0, 0, 0.2))
			draw_circle(Vector2.ZERO, radius, Color(0.2, 0.5, 0.2))
			var n := int(ceil(6.0 * amount / max_amount))
			for i in n:
				var a := float(i) * 1.05
				draw_circle(Vector2(cos(a), sin(a)) * radius * 0.55, 3.0, Color(0.85, 0.15, 0.3))
		"stone", "gold":
			var base := Color(0.62, 0.62, 0.64) if kind == "stone" else Color(0.55, 0.48, 0.32)
			var hi := Color(0.82, 0.82, 0.85) if kind == "stone" else Color(1.0, 0.85, 0.25)
			var s := 0.55 + 0.45 * (amount / max_amount)
			var r := radius * s
			draw_circle(Vector2(3, 4), r, Color(0, 0, 0, 0.25))
			var pts := PackedVector2Array([Vector2(-r, r * 0.4), Vector2(-r * 0.6, -r * 0.7), Vector2(r * 0.2, -r),
				Vector2(r, -r * 0.2), Vector2(r * 0.8, r * 0.7), Vector2(-r * 0.2, r)])
			draw_colored_polygon(pts, base)
			draw_circle(Vector2(-r * 0.3, -r * 0.2), r * 0.28, hi)
			draw_circle(Vector2(r * 0.35, r * 0.25), r * 0.2, hi)
	if selected:
		draw_arc(Vector2.ZERO, radius + 4, 0, TAU, 24, Color(1, 1, 1, 0.9), 1.5)
