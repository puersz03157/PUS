extends "res://scripts/weapons/weapon_base.gd"
## 近戰扇形：根據玩家朝向劃出扇形，掃到的敵人受傷害。
## 若 params.attack_effect 有設定 spritesheet，改播特效並用三角形（等）命中。
## eff_count（含 w_count 升級）決定一次開火連續揮砍／戳刺次數。

const MELEE_SPRITESHEET_SWING := preload("res://scripts/weapons/melee_spritesheet_swing.gd")
const DEFAULT_MULTI_SWING_DELAY := 0.12


func fire() -> bool:
	_queue_swings(_swing_count())
	return true


func _swing_count() -> int:
	var n: int = maxi(1, eff_count)
	if bool(def["params"].get("double_hit", false)):
		n = maxi(n, 2)
	return n


func _multi_swing_delay() -> float:
	return maxf(0.04, float(def["params"].get("multi_swing_delay", DEFAULT_MULTI_SWING_DELAY)))


func _queue_swings(n: int) -> void:
	if owner_player == null or not is_instance_valid(owner_player):
		return
	for i in n:
		if i == 0:
			_swing(false)
			continue
		var delay: float = _multi_swing_delay() * float(i)
		var t: SceneTreeTimer = owner_player.get_tree().create_timer(delay)
		t.timeout.connect(_swing.bind(true))


func _swing(play_anim: bool = false) -> void:
	if owner_player == null or owner_player.hp <= 0 or not is_instance_valid(self):
		return
	if play_anim and owner_player.has_method("play_attack_anim"):
		owner_player.play_attack_anim()
	var effect_cfg: Variant = def["params"].get("attack_effect", null)
	if effect_cfg is Dictionary and not effect_cfg.is_empty() and _swing_spritesheet_effect(effect_cfg):
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


func _swing_spritesheet_effect(effect_cfg: Dictionary) -> bool:
	var dir: Vector2 = _aim_dir()
	if dir == Vector2.ZERO:
		return false
	var sheet_path: String = String(effect_cfg.get("sheet", ""))
	if sheet_path == "" or not ResourceLoader.exists(sheet_path, "Texture2D"):
		return false
	var base_range: float = float(def.get("range", eff_range))
	var scene_root: Node = owner_player.get_tree().current_scene
	MELEE_SPRITESHEET_SWING.play(
		scene_root,
		self,
		owner_player.global_position,
		dir,
		eff_range,
		base_range,
		effect_cfg)
	return true


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
