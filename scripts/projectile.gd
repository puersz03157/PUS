extends Area2D
## 投射物：直線/波浪移動，命中敵人扣血，可貫穿。

var velocity: Vector2 = Vector2.ZERO
var weapon: Node = null
var pierce_left: int = 0
var explode_radius: float = 0.0
var hit_set: Dictionary = {}
var lifetime: float = 1.5
var elapsed: float = 0.0
var color: Color = Color.WHITE
var wave: bool = false
var wave_seed: float = 0.0
var origin: Vector2 = Vector2.ZERO
var max_distance: float = 800.0

@onready var sprite: Polygon2D = $Sprite


func setup(w: Node, vel: Vector2, col: Color) -> void:
	weapon = w
	velocity = vel
	color = col
	var def: Dictionary = w.def
	pierce_left = int(def["params"].get("pierce", 0))
	explode_radius = float(def["params"].get("explode_radius", 0.0))
	wave = bool(def["params"].get("wave", false))
	wave_seed = randf() * TAU
	max_distance = float(w.eff_range)
	lifetime = clamp(max_distance / max(60.0, vel.length()) + 0.4, 0.4, 4.0)


func _ready() -> void:
	add_to_group("projectiles")
	origin = global_position
	$Sprite.color = color
	rotation = velocity.angle()


func _physics_process(delta: float) -> void:
	elapsed += delta
	if wave:
		var perp: Vector2 = velocity.rotated(PI * 0.5).normalized()
		var move: Vector2 = velocity * delta
		var bob: Vector2 = perp * sin(elapsed * 8.0 + wave_seed) * 60.0 * delta
		global_position += move + bob
	else:
		global_position += velocity * delta
	if origin.distance_to(global_position) > max_distance or elapsed > lifetime:
		_finish()


func _on_body_entered(body: Node) -> void:
	_try_hit(body)


func _on_area_entered(area: Area2D) -> void:
	pass


func _try_hit(body: Node) -> void:
	if not body.is_in_group("enemies"):
		return
	if hit_set.has(body):
		return
	hit_set[body] = true
	if weapon:
		weapon.damage_enemy(body)
	# 緩速
	if weapon and weapon.def["params"].get("slow", false):
		if "move_speed" in body:
			body.move_speed = max(20.0, body.move_speed * 0.6)
	if pierce_left > 0:
		pierce_left -= 1
	else:
		# 爆炸（魔彈）
		if explode_radius > 0.0:
			for e in get_tree().get_nodes_in_group("enemies"):
				if e == body: continue
				if global_position.distance_to(e.global_position) <= explode_radius:
					weapon.damage_enemy(e, 0.7)
		_finish()


func _finish() -> void:
	queue_free()
