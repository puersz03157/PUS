extends "res://scripts/weapons/weapon_base.gd"
## 拳擊：外圓弧柱近戰；Combo 增傷（玩家共用 Combo），逾時中斷回血；滿級機率暈眩（5 秒 CD）。


func _exit_tree() -> void:
	if owner_player != null and is_instance_valid(owner_player) \
			and owner_player.has_method("_clear_boxing_combo"):
		owner_player._clear_boxing_combo()


func fire() -> bool:
	if owner_player == null or owner_player.hp <= 0:
		return false
	_swing()
	return true


func _swing() -> void:
	var angle_deg: float = float(def["params"].get("angle_deg", 100.0))
	var inner_mult: float = float(def["params"].get("inner_radius_mult", 0.52))
	var col: Color = def["params"].get("color", Color(1.0, 0.75, 0.55))
	var dir: Vector2 = _aim_dir()
	var center_angle: float = dir.angle()
	var half_rad: float = deg_to_rad(angle_deg) * 0.5
	var inner_r: float = eff_range * inner_mult
	var outer_r: float = eff_range
	var pillars: int = maxi(1, eff_count)

	_spawn_arc_visual(center_angle, half_rad, inner_r, outer_r, col, pillars)

	var origin: Vector2 = owner_player.global_position
	for e in owner_player.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e.get("hp") != null and float(e.hp) <= 0.0:
			continue
		if not _in_arc_pillars(origin, e.global_position, center_angle, inner_r, outer_r, half_rad, pillars):
			continue
		_hit_enemy(e)


func _hit_enemy(e: Node) -> void:
	var combo: int = 0
	if owner_player != null and owner_player.has_method("get_boxing_combo"):
		combo = int(owner_player.get_boxing_combo())
	var maxed: bool = owner_player != null and owner_player.has_method("is_boxing_weapon_maxed") \
		and owner_player.is_boxing_weapon_maxed()
	var dmg_mult: float = GameData.boxing_combo_hit_damage_mult(combo, maxed, "boxing")
	damage_enemy(e, dmg_mult)
	if owner_player != null and owner_player.has_method("try_boxing_stun"):
		owner_player.try_boxing_stun(e)


const PILLAR_SLOT_FILL := 0.48


func _pillar_half_angle(half_rad: float, pillars: int) -> float:
	return (half_rad * 2.0 / float(maxi(1, pillars))) * PILLAR_SLOT_FILL


func _pillar_dims(inner_r: float, outer_r: float, half_rad: float, pillars: int) -> Dictionary:
	var pillar_h: float = outer_r - inner_r
	var mid_r: float = (inner_r + outer_r) * 0.5
	var half_ang: float = _pillar_half_angle(half_rad, pillars)
	var pillar_w: float = 2.0 * mid_r * sin(half_ang)
	pillar_w = maxf(pillar_w, pillar_h * 0.55)
	return {"h": pillar_h, "w": pillar_w, "half_ang": half_ang, "mid_r": mid_r}


func _in_arc_pillars(
		origin: Vector2,
		target: Vector2,
		center_angle: float,
		inner_r: float,
		outer_r: float,
		half_rad: float,
		pillars: int) -> bool:
	var to_e: Vector2 = target - origin
	var dist: float = to_e.length()
	if dist < inner_r or dist > outer_r:
		return false
	var enemy_ang: float = to_e.angle()
	var dims: Dictionary = _pillar_dims(inner_r, outer_r, half_rad, pillars)
	var pillar_half_ang: float = dims["half_ang"]
	for i in pillars:
		var t: float = (float(i) + 0.5) / float(pillars)
		var a: float = center_angle - half_rad + half_rad * 2.0 * t
		if abs(wrapf(enemy_ang - a, -PI, PI)) <= pillar_half_ang:
			return true
	return false


func _spawn_arc_visual(
		center_angle: float,
		half_rad: float,
		inner_r: float,
		outer_r: float,
		col: Color,
		pillars: int) -> void:
	pillars = maxi(1, pillars)
	var dims: Dictionary = _pillar_dims(inner_r, outer_r, half_rad, pillars)
	var pillar_h: float = dims["h"]
	var pillar_w: float = dims["w"]
	var mid_r: float = dims["mid_r"]
	var half_w: float = pillar_w * 0.5
	var half_h: float = pillar_h * 0.5
	for i in pillars:
		var t: float = (float(i) + 0.5) / float(pillars)
		var a: float = center_angle - half_rad + half_rad * 2.0 * t
		var center: Vector2 = Vector2(cos(a), sin(a)) * mid_r
		var tangent: Vector2 = Vector2(-sin(a), cos(a))
		var radial: Vector2 = Vector2(cos(a), sin(a))
		var pillar := Polygon2D.new()
		pillar.color = Color(col.r, col.g, col.b, 0.78)
		pillar.z_index = 6
		pillar.polygon = PackedVector2Array([
			center - tangent * half_w - radial * half_h,
			center + tangent * half_w - radial * half_h,
			center + tangent * half_w + radial * half_h,
			center - tangent * half_w + radial * half_h,
		])
		owner_player.add_child(pillar)
		var tw_p := pillar.create_tween()
		tw_p.tween_property(pillar, "modulate:a", 0.0, 0.14)
		tw_p.tween_callback(pillar.queue_free)


func _aim_dir() -> Vector2:
	var origin: Vector2 = owner_player.global_position
	var max_d: float = eff_range * 1.35
	var best: Node = null
	var best_d: float = max_d * max_d
	for e in owner_player.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e.get("hp") != null and float(e.hp) <= 0.0:
			continue
		var d: float = origin.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best:
		return (best.global_position - origin).normalized()
	return owner_player.face_dir
