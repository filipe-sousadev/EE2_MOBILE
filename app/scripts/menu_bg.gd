extends Control
## Painted title background: sky, hills, a castle and a tower silhouette.

func _draw() -> void:
	var s := size
	var steps := 24
	for i in steps:
		var c := Color(0.95, 0.62, 0.32).lerp(Color(0.18, 0.12, 0.3), float(i) / steps)
		draw_rect(Rect2(0, s.y * (1.0 - float(i + 1) / steps), s.x, s.y / steps + 1), c)
	draw_circle(Vector2(s.x * 0.75, s.y * 0.62), 70, Color(1.0, 0.85, 0.5, 0.9))
	var hills := PackedVector2Array([Vector2(0, s.y)])
	for i in 21:
		var x := s.x * i / 20.0
		hills.append(Vector2(x, s.y * 0.72 + sin(i * 0.9) * 26.0))
	hills.append(Vector2(s.x, s.y))
	draw_colored_polygon(hills, Color(0.2, 0.25, 0.15))
	var dark := Color(0.1, 0.1, 0.12)
	var bx := s.x * 0.16
	var by := s.y * 0.73
	draw_rect(Rect2(bx, by - 90, 160, 90), dark)
	for i in 6:
		draw_rect(Rect2(bx + i * 28, by - 104, 16, 14), dark)
	draw_rect(Rect2(bx - 30, by - 150, 50, 150), dark)
	draw_rect(Rect2(bx + 150, by - 130, 46, 130), dark)
	draw_line(Vector2(bx - 5, by - 150), Vector2(bx - 5, by - 190), dark, 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(bx - 5, by - 190), Vector2(bx + 25, by - 180), Vector2(bx - 5, by - 170)]), Color(0.22, 0.5, 0.95))
	var tx := s.x * 0.86
	draw_rect(Rect2(tx, by - 120, 40, 120), dark)
	draw_rect(Rect2(tx - 6, by - 132, 52, 14), dark)
	for i in 8:
		var x := s.x * (0.36 + i * 0.045)
		draw_circle(Vector2(x, by + 10 - (i % 3) * 6), 18, Color(0.08, 0.14, 0.08))
