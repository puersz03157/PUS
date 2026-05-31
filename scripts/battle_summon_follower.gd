extends "res://scripts/village_summon_follower.gd"
## 戰鬥召喚獸：跟隨主人；Lv.1+ 近戰型追擊、遠距型定點射擊；苔蘚蟲輔助生菇；蛋僅跟隨

const PROJECTILE_SCENE := preload("res://scenes/Projectile.tscn")
const MUSHROOM_SCENE_PATH := "res://scenes/SummonMushroomOrb.tscn"

var _combat_enabled: bool = false
var _attack_cd: float = 0.0
var _ability_cd: float = 0.0
var _combat_params: Dictionary = {}
var _adapter: SummonCombatAdapter = null


func setup_battle(
		owner: Node2D,
		summon_id: String,
		player_slot: String,
		formation_index: int,
		formation_count: int,
) -> void:
	setup(owner, summon_id, player_slot, formation_index, formation_count)
	add_to_group("summon_followers")
	_combat_enabled = true
	_ability_cd = 0.0
	_refresh_combat_state()


func refresh_visual() -> void:
	_apply_visual()
	_refresh_combat_state()


func is_active_mossis_spawner() -> bool:
	return _combat_enabled \
		and not _combat_params.is_empty() \
		and _summon_id == "mossis" \
		and String(_combat_params.get("style", "")) == "support"


func get_enemy_target_position() -> Vector2:
	return global_position


func _refresh_combat_state() -> void:
	_combat_params = {}
	if not _combat_enabled or _summon_id == "" or _summon_id == "none":
		return
	var prog: Dictionary = GameState.get_summon_progress(_player_slot, _summon_id)
	var level: int = int(prog.get("level", GameData.SUMMON_MIN_LEVEL))
	_combat_params = GameData.compute_summon_combat_params(_summon_id, level)
	if _combat_params.is_empty():
		return
	_combat_params = GameData.apply_whip_owner_bonuses_to_summon_params(_combat_params, _owner)
	if _adapter == null:
		_adapter = SummonCombatAdapter.new()
		add_child(_adapter)
	_adapter.owner_player = _owner
	_adapter.summon_id = _summon_id
	_adapter.combat_params = _combat_params
	_adapter.eff_damage = float(_combat_params.get("damage", 1))
	_adapter.hit_vfx_id = String(_combat_params.get("hit_vfx", ""))
	_adapter.hit_vfx_scale = float(_combat_params.get("hit_vfx_scale", 1.0))


func _physics_process(delta: float) -> void:
	if _owner == null or not is_instance_valid(_owner):
		queue_free()
		return
	if "hp" in _owner and float(_owner.hp) <= 0.0:
		_combat_enabled = false
	if not _combat_enabled or _combat_params.is_empty():
		_follow_owner(delta)
		z_index = int(global_position.y)
		_update_facing()
		return
	var style: String = String(_combat_params.get("style", "ranged"))
	_ability_cd = maxf(0.0, _ability_cd - delta)
	if style == "support":
		_tick_support(delta)
		z_index = int(global_position.y)
		_update_facing()
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	var target: Node2D = _find_combat_target()
	if target != null and _attack_cd <= 0.0 and _can_attack_target(target):
		_perform_attack(target)
		_attack_cd = 1.0 / maxf(0.1, float(_combat_params.get("attack_rate", 0.6)))
	if style == "melee" and target != null:
		_move_melee(delta, target)
	else:
		_follow_owner(delta)
	z_index = int(global_position.y)
	_update_facing_toward(target)


func _tick_support(delta: float) -> void:
	_follow_owner(delta)
	var abilities: Dictionary = _combat_params.get("abilities", {})
	var interval: float = float(abilities.get("spawn_interval", 2.8))
	if _ability_cd > 0.0:
		return
	_ability_cd = interval
	var spawn_ch: float = float(abilities.get("spawn_chance", 0.28))
	if randf() >= spawn_ch:
		return
	_spawn_mushroom()


func _spawn_mushroom() -> void:
	if _owner == null:
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var packed: PackedScene = load(MUSHROOM_SCENE_PATH) as PackedScene
	if packed == null:
		return
	var kind: String = GameData.summon_mushroom_pick_kind()
	var scan_r: float = float(_combat_params.get("scan_radius", 205.0))
	var ang: float = randf() * TAU
	var dist: float = randf_range(18.0, scan_r * 0.82)
	var at: Vector2 = global_position + Vector2(cos(ang), sin(ang)) * dist
	var orb = packed.instantiate()
	if orb == null:
		return
	if orb.has_method("setup"):
		orb.setup(kind, _owner, _combat_params, at)
	scene_root.add_child(orb)


func _follow_owner(delta: float) -> void:
	_bob_time += delta * BOB_SPEED
	var target: Vector2 = _compute_target_position(_bob_time)
	global_position = global_position.lerp(
		target, 1.0 - exp(-FOLLOW_LERP_SPEED * delta))


func _move_melee(delta: float, target: Node2D) -> void:
	var melee_range: float = float(_combat_params.get("melee_range", 24.0))
	var dist: float = global_position.distance_to(target.global_position)
	if dist <= melee_range:
		_follow_owner(delta)
		return
	var dir: Vector2 = (target.global_position - global_position).normalized()
	var step: float = float(_combat_params.get("move_speed", 40.0)) * delta
	var next: Vector2 = global_position + dir * step
	var leash: float = float(_combat_params.get("leash_radius", 185.0))
	var owner_pos: Vector2 = _owner.global_position
	if next.distance_to(owner_pos) > leash:
		next = owner_pos + (next - owner_pos).normalized() * leash
	global_position = next
	_bob_time += delta * BOB_SPEED


func _find_combat_target() -> Node2D:
	if _owner == null:
		return null
	var scan_r: float = float(_combat_params.get("scan_radius", 205.0))
	var scan_r2: float = scan_r * scan_r
	var origin: Vector2 = _owner.global_position
	var best: Node2D = null
	var best_d: float = scan_r2
	var best_unslowed: Node2D = null
	var best_unslowed_d: float = scan_r2
	var prefer_unslowed: bool = _summon_id == "frcloudy"
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not (e is Node2D):
			continue
		if e.get("hp") != null and float(e.hp) <= 0.0:
			continue
		var d2: float = origin.distance_squared_to((e as Node2D).global_position)
		if d2 >= scan_r2:
			continue
		if d2 < best_d:
			best_d = d2
			best = e as Node2D
		if prefer_unslowed and e.has_method("is_status_slowed") \
				and not e.is_status_slowed() and d2 < best_unslowed_d:
			best_unslowed_d = d2
			best_unslowed = e as Node2D
	if prefer_unslowed and best_unslowed != null:
		return best_unslowed
	return best


func _can_attack_target(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var dist: float = global_position.distance_to(target.global_position)
	var style: String = String(_combat_params.get("style", "ranged"))
	if style == "melee":
		return dist <= float(_combat_params.get("melee_range", 24.0)) * 1.15
	return dist <= float(_combat_params.get("ranged_range", 108.0))


func _perform_attack(target: Node2D) -> void:
	if _adapter == null or target == null:
		return
	var style: String = String(_combat_params.get("style", "ranged"))
	if style == "melee":
		var variant: String = "R1" if randf() < 0.5 else "R2"
		_adapter.damage_enemy(target, 1.0, {"variant": variant})
		if _summon_id == "herbarmor":
			_try_herbarmor_taunt()
	else:
		_fire_projectile(target)


func _try_herbarmor_taunt() -> void:
	if _ability_cd > 0.0:
		return
	var abilities: Dictionary = _combat_params.get("abilities", {})
	var taunt_ch: float = float(abilities.get("taunt_chance", 0.0))
	if taunt_ch <= 0.001 or randf() >= taunt_ch:
		return
	var duration: float = float(abilities.get("taunt_duration", 2.0))
	var scan_r: float = float(_combat_params.get("scan_radius", 205.0))
	var origin: Vector2 = _owner.global_position if _owner != null else global_position
	var taunted: bool = false
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not (e is Node2D):
			continue
		if e.get("hp") != null and float(e.hp) <= 0.0:
			continue
		if origin.distance_to((e as Node2D).global_position) > scan_r:
			continue
		if e.has_method("apply_summon_taunt"):
			e.apply_summon_taunt(self, duration)
			taunted = true
	if taunted:
		_ability_cd = float(abilities.get("taunt_cd", 8.0))


func _fire_projectile(target: Node2D) -> void:
	if _adapter == null or target == null:
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var dir: Vector2 = (target.global_position - global_position)
	if dir.length_squared() < 1.0:
		dir = Vector2.RIGHT
	else:
		dir = dir.normalized()
	var speed: float = float(_combat_params.get("projectile_speed", 360.0))
	var col: Color = _combat_params.get("projectile_color", Color.WHITE)
	var vis_cfg: Dictionary = _combat_params.get("projectile_visual", {})
	_adapter.eff_range = float(_combat_params.get("ranged_range", 108.0))
	_adapter.def = {
		"params": {
			"projectile_visual": vis_cfg,
			"speed": speed,
			"pierce": 0,
		},
	}
	var proj = PROJECTILE_SCENE.instantiate()
	proj.global_position = global_position
	proj.setup(_adapter, dir * speed, col)
	var vis_scale: float = float(_combat_params.get("projectile_visual_scale", 0.68))
	if vis_scale != 1.0:
		proj.scale = Vector2.ONE * vis_scale
	scene_root.add_child(proj)


func _update_facing_toward(target: Node2D) -> void:
	_ensure_sprite()
	if target != null and is_instance_valid(target):
		var face: Vector2 = target.global_position - global_position
		if face.x < -0.05:
			_sprite.flip_h = false
		elif face.x > 0.05:
			_sprite.flip_h = true
		return
	_update_facing()
