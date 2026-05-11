extends Node2D
## 迴旋斬視覺效果：環形閃光 + 旋轉刀光，於 0.5 秒內擴散後淡出。

var radius: float = 240.0
var color: Color = Color(1, 0.9, 0.5)
var lifetime: float = 0.5
var _t: float = 0.0


func setup(r: float, c: Color = Color(1, 0.9, 0.5), life: float = 0.5) -> void:
	radius = r
	color = c
	lifetime = life


func _ready() -> void:
	z_index = 5
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _t >= lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var p: float = clamp(_t / lifetime, 0.0, 1.0)
	# 主環：由小擴張到滿
	var grow: float = ease(p, 0.4)            # 前段較快擴張
	var ring_r: float = radius * grow
	var alpha: float = 1.0 - p
	var ring_col := Color(color.r, color.g, color.b, alpha * 0.85)
	# 內外兩道環，產生光感
	draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 64, ring_col, 6.0, true)
	draw_arc(Vector2.ZERO, ring_r * 0.78, 0.0, TAU,
		48, Color(1, 1, 1, alpha * 0.55), 3.0, true)
	# 4 道交叉刀光
	var rot: float = p * TAU * 0.9
	var blade_r: float = ring_r * 0.95
	var blade_w: float = max(2.0, 8.0 * (1.0 - p))
	for i in 4:
		var ang: float = rot + i * (TAU * 0.25)
		var a := Vector2(cos(ang), sin(ang)) * blade_r * 0.15
		var b := Vector2(cos(ang), sin(ang)) * blade_r
		draw_line(a, b, Color(1, 1, 0.85, alpha), blade_w)
	# 中央閃光
	var center_alpha: float = (1.0 - p) * 0.6
	if center_alpha > 0.0:
		draw_circle(Vector2.ZERO, 24.0 * (1.0 - p),
			Color(1, 1, 0.85, center_alpha))
