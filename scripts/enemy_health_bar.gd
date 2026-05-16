extends Node2D
## 怪物頭頂血條（世界座標，跟隨敵人）

const BAR_W := 40.0
const BAR_H := 5.0
const BG_COLOR := Color(0.08, 0.06, 0.1, 0.85)
const FILL_COLOR := Color(0.22, 0.88, 0.38, 1.0)
const FILL_LOW_COLOR := Color(0.95, 0.32, 0.22, 1.0)
const BORDER_COLOR := Color(0.0, 0.0, 0.0, 0.55)

var _ratio: float = 1.0
var _offset: Vector2 = Vector2(0.0, -22.0)
var _fade: float = 0.0
var _enemy: Node = null


func bind_enemy(enemy: Node) -> void:
	_enemy = enemy
	z_index = 20
	_recompute_offset()


func set_hp_ratio(ratio: float) -> void:
	_ratio = clampf(ratio, 0.0, 1.0)
	if _ratio >= 0.999:
		_fade = maxf(_fade, 0.35)
	else:
		_fade = 1.0
	queue_redraw()


func pulse_hit() -> void:
	_fade = 1.0
	scale = Vector2(1.12, 1.12)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK)
	queue_redraw()


func _process(delta: float) -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		queue_free()
		return
	global_position = _enemy.global_position + _offset
	if _ratio >= 0.999:
		_fade = move_toward(_fade, 0.0, delta * 1.8)
	else:
		_fade = move_toward(_fade, 1.0, delta * 6.0)
	if _fade <= 0.02:
		visible = false
	else:
		visible = true
		modulate.a = _fade
	queue_redraw()


func _recompute_offset() -> void:
	_offset = Vector2(0.0, -22.0)
	if _enemy == null:
		return
	var rad: float = 12.0
	var rn: Variant = _enemy.get("radius")
	if rn != null:
		rad = float(rn)
	_offset.y = -(rad + 16.0)
	var spr: Sprite2D = _enemy.get_node_or_null("Sprite") as Sprite2D
	if spr and spr.texture:
		var frame_h: float = float(spr.texture.get_height()) / maxf(1.0, float(spr.vframes))
		_offset.y -= frame_h * absf(spr.scale.y) * 0.42


func _draw() -> void:
	if _fade <= 0.02:
		return
	var origin := Vector2(-BAR_W * 0.5, -BAR_H * 0.5)
	draw_rect(Rect2(origin - Vector2(1, 1), Vector2(BAR_W + 2, BAR_H + 2)), BORDER_COLOR)
	draw_rect(Rect2(origin, Vector2(BAR_W, BAR_H)), BG_COLOR)
	var fill_col: Color = FILL_COLOR if _ratio > 0.28 else FILL_LOW_COLOR
	draw_rect(Rect2(origin, Vector2(BAR_W * _ratio, BAR_H)), fill_col)
