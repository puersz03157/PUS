extends "res://scripts/weapons/weapon_projectile.gd"
## 槍械：中距離高攻速投射物；滿級機率散射／貫穿；彈藥包觸發八向齊射。

const MODE_SCATTER := "scatter"
const MODE_PIERCE := "pierce"

var shot_mode: String = ""
var _shot_damage_mult: float = 1.0
var _spawn_range: float = 0.0
var _max_mode_cd: float = 0.0


func _process(delta: float) -> void:
	_max_mode_cd = maxf(0.0, _max_mode_cd - delta)
	super._process(delta)


func fire() -> bool:
	if owner_player == null or owner_player.hp <= 0:
		return false
	shot_mode = _roll_max_mode()
	var aim_dir: Vector2 = _find_aim_dir()
	if aim_dir == Vector2.ZERO:
		shot_mode = ""
		return false
	_commit_max_mode_cd()
	_notify_mode()
	_shot_damage_mult = 1.0
	_spawn_range = eff_range
	var ok: bool = _fire_fan(aim_dir, maxi(1, eff_count))
	shot_mode = ""
	return ok


func fire_radial_volley(mode: String = "") -> void:
	if owner_player == null or not is_instance_valid(owner_player):
		return
	shot_mode = mode if mode != "" else _roll_max_mode()
	_commit_max_mode_cd()
	_notify_mode()
	_shot_damage_mult = float(def["params"].get("volley_damage_mult", 0.92))
	_spawn_range = GameData.FIREARM_VOLLEY_RANGE
	var col: Color = def["params"].get("color", Color(0.85, 0.88, 0.95))
	var speed: float = float(def["params"].get("speed", 720.0))
	var n_dirs: int = GameData.FIREARM_VOLLEY_DIRS
	for i in n_dirs:
		var ang: float = float(i) / float(n_dirs) * TAU
		var dir: Vector2 = Vector2(cos(ang), sin(ang))
		_spawn_bullet(dir, speed, col)
	shot_mode = ""
	_shot_damage_mult = 1.0
	_spawn_range = 0.0


func get_extra_pierce() -> int:
	if shot_mode == MODE_PIERCE:
		return GameData.FIREARM_PIERCE_BONUS
	return 0


func get_shot_damage_mult() -> float:
	return _shot_damage_mult


func get_spawn_range() -> float:
	if _spawn_range > 0.0:
		return _spawn_range
	return eff_range


func _roll_max_mode() -> String:
	if not weapon_upgrades_maxed():
		return ""
	if _max_mode_cd > 0.0:
		return ""
	if randf() >= GameData.FIREARM_MAX_MODE_CHANCE:
		return ""
	return MODE_SCATTER if randf() < 0.5 else MODE_PIERCE


func _commit_max_mode_cd() -> void:
	if shot_mode != "":
		_max_mode_cd = GameData.FIREARM_MAX_MODE_CD


func _notify_mode() -> void:
	if shot_mode == "" or owner_player == null:
		return
	if owner_player.has_method("show_firearm_mode_indicator"):
		owner_player.show_firearm_mode_indicator(shot_mode)


func _effective_spread_deg(n: int) -> float:
	var base: float = float(def["params"].get("spread_deg", 5.0))
	if shot_mode == MODE_SCATTER:
		return GameData.FIREARM_SCATTER_SPREAD_DEG
	return base


func _fire_fan(aim_dir: Vector2, n: int) -> bool:
	var spread: float = _effective_spread_deg(n)
	var speed: float = float(def["params"].get("speed", 720.0))
	var col: Color = def["params"].get("color", Color(0.85, 0.88, 0.95))
	var total_spread: float = deg_to_rad(spread) * float(n - 1)
	for i in n:
		var t: float = 0.0 if n == 1 else float(i) / float(n - 1)
		var ang: float = aim_dir.angle() - total_spread * 0.5 + total_spread * t
		var dir: Vector2 = Vector2(cos(ang), sin(ang))
		_spawn_bullet(dir, speed, col)
	return true


func _spawn_bullet(dir: Vector2, speed: float, col: Color) -> void:
	var p := PROJECTILE_SCENE.instantiate()
	var spawn_off: float = _spawn_forward_offset(dir)
	p.global_position = owner_player.global_position + dir * spawn_off
	p.setup(self, dir * speed, col)
	if shot_mode != "" and p.has_method("set_hit_variant"):
		p.set_hit_variant(shot_mode)
	owner_player.get_tree().current_scene.add_child(p)
