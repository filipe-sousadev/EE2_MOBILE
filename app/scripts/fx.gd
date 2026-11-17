extends Node2D
## Projectiles, order markers, deaths and the building ghost.

var game: Node = null


func _draw() -> void:
	if game == null:
		return
	for e in game.effects:
		var f: float = e["t"] / e["dur"]
		match e["type"]:
			"arrow":
				var p: Vector2 = e["from"].lerp(e["to"], f)
				var dir: Vector2 = (e["to"] - e["from"]).normalized()
				p.y -= sin(f * PI) * 20.0
				draw_line(p - dir * 9.0, p, Color(0.95, 0.9, 0.75), 2.0)
			"stone":
				var p2: Vector2 = e["from"].lerp(e["to"], f)
				p2.y -= sin(f * PI) * 60.0
				draw_circle(p2, 5.0, Color(0.35, 0.33, 0.3))
			"marker":
				draw_arc(e["from"], 6.0 + 14.0 * (1.0 - f), 0, TAU, 20, Color(0.5, 1.0, 0.5, 1.0 - f), 2.0)
			"target":
				draw_arc(e["from"], 8.0 + 18.0 * (1.0 - f), 0, TAU, 20, Color(1.0, 0.3, 0.3, 1.0 - f), 2.5)
			"puff":
				draw_circle(e["from"], 6.0 + 12.0 * f, Color(0.55, 0.1, 0.1, 0.6 * (1.0 - f)))
			"rubble":
				draw_circle(e["from"], 20.0 + 40.0 * f, Color(0.4, 0.35, 0.3, 0.7 * (1.0 - f)))
	if game.placing != "":
		var k: String = game.placing
		var s: int = DB.BUILDINGS[k]["size"]
		var ok: bool = game.can_place(k, game.ghost_cell)
		var r := Rect2(Vector2(game.ghost_cell) * DB.CELL, Vector2(s, s) * DB.CELL)
		var c := Color(0.3, 1.0, 0.3, 0.35) if ok else Color(1.0, 0.25, 0.25, 0.35)
		draw_rect(r, c)
		draw_rect(r, Color(c.r, c.g, c.b, 0.9), false, 2.0)
		draw_string(ThemeDB.fallback_font, r.position + Vector2(2, -6), DB.BUILDINGS[k]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
