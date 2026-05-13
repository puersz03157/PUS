extends Area2D
## 投射物：直線/波浪移動，命中敵人扣血，可貫穿。

var velocity: Vector2 = Vector2.ZERO
var weapon: Node = null
var pierce_left: int = 0
var bounces_left: int = 0
var bullet_speed: float = 500.0
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
	bullet_speed = vel.length()
	var def: Dictionary = w.def
	pierce_left = int(def["params"].get("pierce", 0))
	bounces_left = 0
	explode_radius = float(def["params"].get("explode_radius", 0.0))
	if w is WeaponBase:
		var wb: WeaponBase = w as WeaponBase
		var wid: String = String(def.get("id", ""))
		if wb.weapon_upgrades_maxed() and wid == "bow":
			pierce_left += 2
		if wb.weapon_upgrades_maxed() and wid == "lightning":
			bounces_left = 2
		if wb.weapon_upgrades_maxed() and wid == "magic_bullet" and explode_radius > 0.0:
			var brng: Dictionary = GameData.get_weapon_def("magic_bullet")
			var base_range: float = float(brng.get("range", 500.0))
			if base_range > 1.0:
				explode_radius *= wb.eff_range / base_range
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
	if weapon and weapon.def["params"].get("slow", false) \
			and body.has_method("apply_status_slow"):
		body.apply_status_slow(
			GameData.ENEMY_STATUS_ICE_SLOW_DURATION,
			GameData.ENEMY_STATUS_ICE_SLOW_FACTOR)
	if pierce_left > 0:
		pierce_left -= 1
		return
	if bounces_left > 0:
		var nxt: Node = _find_ricochet_target(body)
		if nxt != null:
			bounces_left -= 1
			velocity = (nxt.global_position - global_position).normalized() * bullet_speed
			rotation = velocity.angle()
			max_distance += 260.0
			lifetime += 0.45
			return
	if explode_radius > 0.0:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e == body:
				continue
			if global_position.distance_to(e.global_position) <= explode_radius:
				weapon.damage_enemy(e, 0.8)
	_finish()


func _find_ricochet_target(last_hit: Node) -> Node:
	var best: Node = null
	var best_d: float = 1e12
	var max_d2: float = 420.0 * 420.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == last_hit or hit_set.has(e):
			continue
		if not is_instance_valid(e):
			continue
		if e.get("hp") != null and float(e.hp) <= 0.0:
			continue
		var d2: float = global_position.distance_squared_to(e.global_position)
		if d2 <= max_d2 and d2 < best_d:
			best_d = d2
			best = e
	return best


func _finish() -> void:
	queue_free()
