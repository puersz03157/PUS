extends "res://scripts/weapons/weapon_base.gd"
## 近戰扇形：根據玩家朝向劃出扇形，掃到的敵人受傷害。

func fire() -> bool:
	_swing()
	# 第二刀延遲 0.12 秒（爪擊的 double_hit），用 Timer 避免 await
	if def["params"].get("double_hit", false):
		var t: SceneTreeTimer = get_tree().create_timer(0.12)
		t.timeout.connect(_swing)
	return true


func _swing() -> void:
	if owner_player == null or owner_player.hp <= 0:
		return
	var angle_deg: float = float(def["params"].get("angle_deg", 45.0))
	var col: Color = def["params"].get("color", Color.WHITE)
	var dir: Vector2 = _aim_dir()
	var center_angle: float = dir.angle()

	var poly := Polygon2D.new()
	poly.color = Color(col.r, col.g, col.b, 0.55)
	poly.z_index = 5
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var seg: int = 14
	var rad: float = deg_to_rad(angle_deg)
	for i in seg + 1:
		var t: float = float(i) / seg
		var a: float = center_angle - rad * 0.5 + rad * t
		pts.append(Vector2(cos(a), sin(a)) * eff_range)
	poly.polygon = pts
	owner_player.add_child(poly)
	var tw := poly.create_tween()
	tw.tween_property(poly, "modulate:a", 0.0, 0.18)
	tw.tween_callback(poly.queue_free)

	var origin: Vector2 = owner_player.global_position
	for e in owner_player.get_tree().get_nodes_in_group("enemies"):
		var to_e: Vector2 = e.global_position - origin
		var dist: float = to_e.length()
		if dist > eff_range:
			continue
		var ang: float = abs(wrapf(to_e.angle() - center_angle, -PI, PI))
		if ang <= rad * 0.5:
			damage_enemy(e)


# 近戰自動瞄準：朝最近敵人；若範圍內沒敵人則保留 face_dir
func _aim_dir() -> Vector2:
	var origin: Vector2 = owner_player.global_position
	var max_d: float = eff_range * 1.5
	var best: Node = null
	var best_d: float = max_d * max_d
	for e in owner_player.get_tree().get_nodes_in_group("enemies"):
		var d: float = origin.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best:
		return (best.global_position - origin).normalized()
	return owner_player.face_dir
