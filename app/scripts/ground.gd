extends Node2D
## Static grass with patches, drawn once.

func _draw() -> void:
	var w := float(DB.MAP_W)
	var h := float(DB.MAP_H)
	draw_rect(Rect2(-2000, -2000, w + 4000, h + 4000), Color(0.07, 0.09, 0.07))
	draw_rect(Rect2(0, 0, w, h), Color(0.36, 0.55, 0.25))
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for i in 900:
		var p := Vector2(r.randf() * w, r.randf() * h)
		var c := Color(0.36, 0.55, 0.25).lerp(Color(0.3, 0.47, 0.2) if r.randf() < 0.5 else Color(0.45, 0.62, 0.3), r.randf_range(0.12, 0.4))
		draw_circle(p, r.randf_range(20, 70), c)
	for i in 120:
		var p := Vector2(r.randf() * w, r.randf() * h)
		draw_circle(p, r.randf_range(14, 40), Color(0.5, 0.45, 0.3, 0.25))
	for i in 2500:
		var p := Vector2(r.randf() * w, r.randf() * h)
		draw_line(p, p + Vector2(r.randf_range(-2, 2), -5), Color(0.25, 0.42, 0.18, 0.7), 1.0)
	# dirt around the two starting sites
	for c in [Vector2(512, 2048), Vector2(w - 512, h - 2048)]:
		for i in 26:
			draw_circle(c + Vector2(r.randf_range(-120, 120), r.randf_range(-110, 110)), r.randf_range(30, 60), Color(0.55, 0.48, 0.32, 0.3))
	draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.07, 0.05), false, 6.0)
