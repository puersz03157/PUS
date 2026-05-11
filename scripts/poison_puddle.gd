extends Node2D
## 留在地上的毒池：每隔 tick_interval 對範圍內敵人造成傷害，到 lifetime 後消失。
## 使用方式：weapon_puddle.gd 在 fire() 時 instantiate 並 setup()。

var damage_per_tick: float = 1.0
var puddle_radius: float = 50.0
var lifetime: float = 3.0
var tick_interval: float = 0.5
var puddle_color: Color = Color(0.5, 1.0, 0.4, 0.4)
var owner_player: Node = null
var weapon: Node = null

var _life: float = 0.0
var _tick: float = 0.0
var _visual: Polygon2D


func setup(w: Node, p: Node, dmg: float, rad: float, life: float, tick: float, col: Color) -> void:
	weapon = w
	owner_player = p
	damage_per_tick = dmg
	puddle_radius = rad
	lifetime = life
	tick_interval = tick
	puddle_color = Color(col.r, col.g, col.b, 0.45)


func _ready() -> void:
	z_index = -1
	_build_visual()
	_tick = tick_interval * 0.5  # 第一次 tick 較快觸發


func _build_visual() -> void:
	_visual = Polygon2D.new()
	_visual.color = puddle_color
	var pts := PackedVector2Array()
	var seg := 24
	for i in seg:
		var a: float = TAU * i / seg
		# 不規則：半徑加一點隨機抖動，看起來像潑灑
		var r: float = puddle_radius * (0.85 + randf() * 0.25)
		pts.append(Vector2(cos(a), sin(a)) * r)
	_visual.polygon = pts
	add_child(_visual)
	# 內圈深色（更像水池）
	var inner := Polygon2D.new()
	inner.color = Color(puddle_color.r * 0.7, puddle_color.g * 0.85, puddle_color.b * 0.7, 0.55)
	var ipts := PackedVector2Array()
	for i in seg:
		var a: float = TAU * i / seg
		var r: float = puddle_radius * 0.55 * (0.85 + randf() * 0.2)
		ipts.append(Vector2(cos(a), sin(a)) * r)
	inner.polygon = ipts
	add_child(inner)


func _process(delta: float) -> void:
	_life += delta
	if _life >= lifetime:
		queue_free()
		return
	# 接近終點時淡出
	var fade_start: float = lifetime - 0.6
	if _life > fade_start:
		var a: float = clamp(1.0 - (_life - fade_start) / 0.6, 0.0, 1.0)
		modulate.a = a

	_tick -= delta
	if _tick <= 0.0:
		_tick = tick_interval
		_apply_tick()


func _apply_tick() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d <= puddle_radius:
			if e.has_method("take_damage"):
				e.take_damage(damage_per_tick, weapon)
