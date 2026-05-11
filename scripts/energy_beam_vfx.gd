extends Node2D
## 能量波動戰鬥光束：沿本地 +X 延伸的矩形，短暫淡出。

var beam_length: float = 720.0
var half_width: float = 60.0
var beam_color: Color = Color(0.75, 0.45, 1.0, 0.65)
var lifetime: float = 0.32
var _t: float = 0.0


func setup(dir: Vector2, length: float, hw: float, col: Color = Color(0.75, 0.45, 1.0), life: float = 0.32) -> void:
	var d: Vector2 = dir.normalized()
	rotation = d.angle()
	beam_length = length
	half_width = hw
	beam_color = col
	lifetime = life


func _ready() -> void:
	z_index = 4
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _t >= lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var a: float = clamp(1.0 - _t / lifetime, 0.0, 1.0)
	var c := Color(beam_color.r, beam_color.g, beam_color.b, beam_color.a * a)
	draw_rect(Rect2(0.0, -half_width, beam_length, half_width * 2.0), c)
	draw_rect(Rect2(0.0, -half_width * 0.35, beam_length, half_width * 0.7),
		Color(1.0, 0.95, 1.0, a * 0.55))
