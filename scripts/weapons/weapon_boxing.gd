extends "res://scripts/weapons/weapon_base.gd"
## 拳擊：外圓弧柱近戰；Combo 增傷，逾時中斷依 Combo 回血；滿級機率暈眩（5 秒 CD）。

var _combo: int = 0
var _combo_timer: float = 0.0
var _stun_cd: float = 0.0


func _exit_tree() -> void:
	if owner_player != null and is_instance_valid(owner_player) \
			and owner_player.has_method("set_boxing_combo_display"):
		owner_player.set_boxing_combo_display(0)


func _process(delta: float) -> void:
	_stun_cd = maxf(0.0, _stun_cd - delta)
	if _combo > 0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_break_combo()
	_sync_combo_ui()
	super._process(delta)


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
	var dmg_mult: float = GameData.boxing_combo_damage_mult(_combo, weapon_upgrades_maxed())
	damage_enemy(e, dmg_mult)
	_combo = mini(_combo + 1, GameData.BOXING_COMBO_MAX)
	_combo_timer = GameData.BOXING_COMBO_WINDOW
	_try_stun(e)


func _break_combo() -> void:
	var lost: int = _combo
	_combo = 0
	_combo_timer = 0.0
	if lost <= 0 or owner_player == null or not is_instance_valid(owner_player):
		return
	if owner_player.has_method("_heal"):
		var heal: float = GameData.boxing_combo_break_heal(
			float(owner_player.max_hp), lost, weapon_upgrades_maxed())
		if heal > 0.0:
			owner_player._heal(heal)


func _try_stun(e: Node) -> void:
	if not weapon_upgrades_maxed() or _stun_cd > 0.0:
		return
	if randf() >= GameData.BOXING_STUN_CHANCE:
		return
	if e.has_method("apply_stun"):
		e.apply_stun(GameData.BOXING_STUN_DURATION)
		_stun_cd = GameData.BOXING_STUN_CD


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


func _sync_combo_ui() -> void:
	if owner_player != null and is_instance_valid(owner_player) \
			and owner_player.has_method("set_boxing_combo_display"):
		owner_player.set_boxing_combo_display(_combo)


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
