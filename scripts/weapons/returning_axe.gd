extends Node2D
## 斧頭滿級效果：向前飛出一段距離後折返玩家，沿途命中敵人一次。

var weapon: Node = null
var owner_player: Node2D = null
var dir: Vector2 = Vector2.RIGHT
var speed: float = 520.0
var max_distance: float = 360.0
var hit_radius: float = 28.0
var damage_mult: float = 0.75
var color: Color = Color(1.0, 0.62, 0.28)

var _origin: Vector2 = Vector2.ZERO
var _returning: bool = false
var _elapsed: float = 0.0
var _hit_set: Dictionary = {}


func setup(
		w: Node,
		p: Node2D,
		start_pos: Vector2,
		fly_dir: Vector2,
		axe_speed: float,
		axe_distance: float,
		axe_hit_radius: float,
		axe_damage_mult: float,
		axe_color: Color) -> void:
	weapon = w
	owner_player = p
	global_position = start_pos
	_origin = start_pos
	dir = fly_dir.normalized() if fly_dir.length_squared() > 0.001 else Vector2.RIGHT
	speed = axe_speed
	max_distance = axe_distance
	hit_radius = axe_hit_radius
	damage_mult = axe_damage_mult
	color = axe_color


func _ready() -> void:
	z_index = 12
	queue_redraw()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if owner_player == null or not is_instance_valid(owner_player) or weapon == null:
		queue_free()
		return
	if _returning:
		var to_owner: Vector2 = owner_player.global_position - global_position
		if to_owner.length() <= 22.0:
			queue_free()
			return
		dir = to_owner.normalized()
	else:
		if _origin.distance_to(global_position) >= max_distance:
			_returning = true
	if _elapsed > 2.4:
		queue_free()
		return
	global_position += dir * speed * delta
	rotation += TAU * 2.6 * delta
	_hit_enemies()


func _hit_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if _hit_set.has(e):
			continue
		if e.get("hp") != null and float(e.hp) <= 0.0:
			continue
		if global_position.distance_to(e.global_position) <= hit_radius:
			_hit_set[e] = true
			if weapon.has_method("damage_enemy"):
				weapon.damage_enemy(e, damage_mult)


func _draw() -> void:
	draw_circle(Vector2.ZERO, hit_radius * 0.35, Color(color.r, color.g, color.b, 0.9))
	draw_line(Vector2(-hit_radius, 0), Vector2(hit_radius, 0), color, 5.0)
	draw_line(Vector2(0, -hit_radius * 0.45), Vector2(0, hit_radius * 0.45), Color(0.85, 0.9, 1.0), 3.0)
