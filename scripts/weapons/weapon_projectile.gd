extends "res://scripts/weapons/weapon_base.gd"
## 投射物：往最近敵人或面向方向發射 N 個投射物。

const PROJECTILE_SCENE := preload("res://scenes/Projectile.tscn")


func fire() -> bool:
	if owner_player == null or owner_player.hp <= 0:
		return false
	var spread: float = float(def["params"].get("spread_deg", 8.0))
	var speed: float = float(def["params"].get("speed", 500.0))
	var col: Color = def["params"].get("color", Color.WHITE)
	var aim_dir: Vector2 = _find_aim_dir()
	# 鎖敵範圍內無敵人 → 不開火（避免遠程跨地圖點射）
	if aim_dir == Vector2.ZERO:
		return false
	var n: int = max(1, eff_count)
	var total_spread: float = deg_to_rad(spread) * (n - 1)
	for i in n:
		var t: float = 0.0 if n == 1 else float(i) / (n - 1)
		var ang: float = aim_dir.angle() - total_spread * 0.5 + total_spread * t
		var p := PROJECTILE_SCENE.instantiate()
		p.global_position = owner_player.global_position
		p.setup(self, Vector2(cos(ang), sin(ang)) * speed, col)
		owner_player.get_tree().current_scene.add_child(p)
	return true


# 只鎖定 eff_range × 1.2 內的敵人；無敵人回 ZERO 表示不開火
func _find_aim_dir() -> Vector2:
	var origin: Vector2 = owner_player.global_position
	var max_d_sq: float = eff_range * eff_range * 1.44   # ×1.2 平方
	var best: Node = null
	var best_d: float = max_d_sq
	for e in owner_player.get_tree().get_nodes_in_group("enemies"):
		var d: float = origin.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best:
		return (best.global_position - origin).normalized()
	return Vector2.ZERO
