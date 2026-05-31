extends CharacterBody2D
## 史萊姆敵人：朝最近的玩家移動，碰到玩家造成傷害；不能走進水池/高地。
## 使用 sprite sheet 第一列做循環動畫。

@export var max_hp: float = 8.0
@export var move_speed: float = 90.0
@export var damage: float = 6.0
@export var xp_value: float = 1.0
@export var radius: float = 12.0

var hp: float = 8.0
var hit_cooldowns: Dictionary = {}
var slime_def: Dictionary = {}
var hframes_count: int = 1
var vframes_count: int = 1
var frames_per_row: Array = []
var anim_time: float = 0.0
const ANIM_FPS := 6.0
const ROW_IDLE := 0
const ROW_WALK := 1
const ROW_DEATH := 6
const GOLD_ORB_SCENE: PackedScene = preload("res://scenes/GoldOrb.tscn")
const MATERIAL_ORB_SCENE: PackedScene = preload("res://scenes/MaterialOrb.tscn")
const ENEMY_HEALTH_BAR_SCRIPT := preload("res://scripts/enemy_health_bar.gd")
const STATUS_OVERLAY_SCRIPT := preload("res://scripts/status_effect_overlay.gd")
const GOLD_DROP_NORMAL_CHANCE := 0.08
const GOLD_DROP_ELITE_CHANCE := 0.18
const GOLD_DROP_BOSS_CHANCE := 0.60

var game_ref: Node = null
var _dying: bool = false
var special_ai_mode: String = ""
var flee_lifetime: float = 12.0
var rune_dust_drop: int = 0
var _special_age: float = 0.0
var ranged_params: Dictionary = {}
var _ranged_cooldown: float = 0.0
var _ranged_windup_left: float = 0.0
var _ranged_warning: Node2D = null
var _ranged_origin: Vector2 = Vector2.ZERO
var _ranged_dir: Vector2 = Vector2.RIGHT
var _ranged_length: float = 0.0
var melee_aoe_params: Dictionary = {}
var hit_effects: Dictionary = {}
var summon_params: Dictionary = {}
var _spawn_level_factor: float = 1.0
var _summon_cooldown: float = 0.0

# 緩速：對 _base_move_speed 乘算（寒冰等）
var _base_move_speed: float = 90.0
var _slow_time: float = 0.0
var _slow_speed_factor: float = 1.0
var _stun_time: float = 0.0
# 易傷（破綻）：匕首疊層，滿級提高層數上限（傷害乘算 1 + 層數×係數）
var _vuln_time: float = 0.0
var _vuln_stacks: int = 0
var _vuln_stack_cap: int = 0
# 流血 / 燃燒 / 中毒：各自 DPS 與剩餘時間
var _bleed_time: float = 0.0
var _bleed_dps: float = 0.0
var _bleed_source: Node = null
var _burn_time: float = 0.0
var _burn_dps: float = 0.0
var _burn_source: Node = null
var _poison_time: float = 0.0
var _poison_dps: float = 0.0
var _poison_source: Node = null
var _poison_atk_reduce: float = 0.0
var _dot_tick_carry: float = 0.0
var _health_bar: Node2D = null
var _status_overlay: StatusEffectOverlay = null

@onready var sprite: Sprite2D = $Sprite
@onready var body_shape: CollisionShape2D = $Body


func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	game_ref = get_parent()
	# 預設碰撞形狀
	if body_shape.shape == null:
		var cs := CircleShape2D.new()
		cs.radius = radius
		body_shape.shape = cs


func setup_with_slime(def: Dictionary, level_factor: float) -> void:
	slime_def = def
	# 套用 sprite
	if sprite and def.has("tex"):
		var tex: Texture2D = load(def["tex"])
		if tex:
			sprite.texture = tex
			sprite.hframes = int(def.get("hframes", 1))
			sprite.vframes = int(def.get("vframes", 1))
			var idle0: int = clampi(int(def.get("anim_row_idle", 0)), 0, maxi(0, sprite.vframes - 1))
			sprite.frame = idle0 * sprite.hframes
			sprite.scale = Vector2.ONE * float(def.get("scale", 1.0))
			sprite.offset = Vector2(0, float(def.get("offset_y", 0)))
			hframes_count = sprite.hframes
			vframes_count = sprite.vframes
	frames_per_row = def.get("frames_per_row", []).duplicate() if def.has("frames_per_row") else []
	# 套用半徑
	radius = float(def.get("radius", 10.0))
	if body_shape:
		var cs: CircleShape2D = body_shape.shape if body_shape.shape is CircleShape2D else CircleShape2D.new()
		cs.radius = radius
		body_shape.shape = cs
	# 套用屬性 — 與圖鑑共用 GameData.compute_enemy_combat_stats
	var st: Dictionary = GameData.compute_enemy_combat_stats(def, level_factor)
	max_hp = float(st["max_hp"])
	hp = max_hp
	move_speed = float(st["move_speed"])
	_base_move_speed = move_speed
	damage = float(st["damage"])
	xp_value = float(st["xp_value"])
	if def.has("ranged") and def["ranged"] is Dictionary:
		configure_ranged_attack(def["ranged"])
	if def.has("melee_aoe") and def["melee_aoe"] is Dictionary:
		melee_aoe_params = def["melee_aoe"].duplicate()
	else:
		melee_aoe_params = {}
	if def.has("hit_effects") and def["hit_effects"] is Dictionary:
		hit_effects = def["hit_effects"].duplicate(true)
	else:
		hit_effects = {}
	if def.has("summon_minions") and def["summon_minions"] is Dictionary:
		summon_params = def["summon_minions"].duplicate(true)
		_summon_cooldown = randf_range(2.0, float(summon_params.get("interval", 9.0)) * 0.6)
	else:
		summon_params = {}
	_spawn_level_factor = level_factor
	if sprite and def.has("sprite_modulate"):
		sprite.modulate = def["sprite_modulate"]
	_ensure_health_bar()
	_ensure_status_overlay()


# 舊介面：難度直接 setup（隨機選一隻）
func setup(level_factor: float) -> void:
	var def: Dictionary = GameData.pick_slime(level_factor)
	setup_with_slime(def, level_factor)


func setup_rescue_runner(level_factor: float, dust_amount: int) -> void:
	var def: Dictionary = GameData.get_slime_def("slime_lightblue")
	if def.is_empty():
		def = GameData.pick_slime(level_factor)
	setup_with_slime(def, level_factor)
	special_ai_mode = "flee"
	flee_lifetime = 13.0
	rune_dust_drop = dust_amount
	max_hp *= 1.8
	hp = max_hp
	move_speed *= 1.45
	_base_move_speed = move_speed
	xp_value *= 2.5
	damage = max(1.0, damage * 0.4)
	modulate = Color(1.25, 0.75, 1.8)
	if sprite:
		sprite.scale *= 1.2
	_update_health_bar()


func configure_ranged_attack(params: Dictionary) -> void:
	if params.is_empty() or not bool(params.get("enabled", true)):
		ranged_params.clear()
		_clear_ranged_warning()
		return
	ranged_params = params.duplicate()
	_ranged_cooldown = randf_range(0.8, max(0.9, float(ranged_params.get("cooldown", 4.0))))


func _process(delta: float) -> void:
	if _dying:
		_process_death_animation(delta)
		return
	if sprite == null or sprite.texture == null or hframes_count <= 1:
		return
	anim_time += delta
	# 待機 / 行走列：預設 row0 待機、row1 走；可選 anim_row_idle、anim_row_walk（例：殭屍第 0 列出土、第 1 列 IDLE）
	var moving: bool = velocity.length_squared() > 1.0
	var idle_r: int = clampi(int(slime_def.get("anim_row_idle", ROW_IDLE)), 0, maxi(0, vframes_count - 1))
	var walk_r: int = clampi(int(slime_def.get("anim_row_walk", ROW_WALK)), 0, maxi(0, vframes_count - 1))
	var row: int = idle_r
	if moving and vframes_count > 1:
		if walk_r != idle_r:
			row = walk_r
		else:
			if frames_per_row.size() > 1 and int(frames_per_row[1]) > 0:
				row = ROW_WALK
			elif frames_per_row.is_empty():
				row = mini(ROW_WALK, vframes_count - 1)
	var fcount: int = _frame_count_for_row(row)
	var f: int = int(anim_time * ANIM_FPS) % fcount
	sprite.frame = row * hframes_count + f


static func _player_target_pos(player: Node) -> Vector2:
	if player == null:
		return Vector2.ZERO
	if player.has_method("get_enemy_target_position"):
		return player.get_enemy_target_position()
	if player is Node2D:
		return (player as Node2D).global_position
	return Vector2.ZERO


func _physics_process(delta: float) -> void:
	if _dying or hp <= 0.0:
		return
	_special_age += delta
	if special_ai_mode == "flee" and _special_age >= flee_lifetime:
		queue_free()
		return
	_advance_enemy_status(delta)
	if _dying or hp <= 0.0:
		return
	_update_summon_minions(delta)
	if _dying or hp <= 0.0:
		return
	if _stun_time > 0.0:
		velocity = Vector2.ZERO
		_clear_ranged_warning()
		_update_hit_cooldowns(delta)
		move_and_slide()
		return
	var target: Node2D = null
	var best: float = 1e9
	for p in get_tree().get_nodes_in_group("players"):
		if p.hp <= 0:
			continue
		var pp: Node2D = p as Node2D
		if pp == null:
			continue
		var d: float = global_position.distance_to(_player_target_pos(pp))
		if d < best:
			best = d
			target = pp

	if target == null:
		velocity = Vector2.ZERO
		_update_ranged_attack(delta, null, 0.0)
	else:
		var dir: Vector2 = (_player_target_pos(target) - global_position).normalized()
		if special_ai_mode == "stationary":
			velocity = Vector2.ZERO
			_update_ranged_attack(delta, target, best)
			if sprite:
				if dir.x < -0.05:
					sprite.flip_h = true
				elif dir.x > 0.05:
					sprite.flip_h = false
			_update_hit_cooldowns(delta)
			move_and_slide()
			return
		if _update_ranged_attack(delta, target, best):
			velocity = Vector2.ZERO
			_update_hit_cooldowns(delta)
			move_and_slide()
			return
		var spd_mult: float = _slow_speed_factor if _slow_time > 0.0 else 1.0
		if special_ai_mode == "flee":
			var flee_dir: Vector2 = -dir
			velocity = flee_dir * _base_move_speed * spd_mult
			if best >= 620.0:
				queue_free()
				return
		else:
			velocity = dir * _base_move_speed * spd_mult
		if special_ai_mode != "flee" and best < radius + 30.0:
			var k: String = str(target.get_instance_id())
			if hit_cooldowns.get(k, 0.0) <= 0.0:
				var deal: float = damage * (1.0 - clampf(_poison_atk_reduce, 0.0, 0.75))
				target.take_damage(deal)
				_apply_player_hit_effects(target)
				hit_cooldowns[k] = 0.6
				if not melee_aoe_params.is_empty():
					_apply_melee_aoe_splash(target, deal)
		# 朝向：水平翻轉 sprite
		if sprite:
			if dir.x < -0.05:
				sprite.flip_h = true
			elif dir.x > 0.05:
				sprite.flip_h = false

	_update_hit_cooldowns(delta)

	# 地圖阻擋（水/高地）— 軸分離測試
	if game_ref and game_ref.has_method("is_world_blocked_at"):
		var step_x: float = velocity.x * delta
		var step_y: float = velocity.y * delta
		if abs(step_x) > 0.001:
			if game_ref.is_world_blocked_at(global_position + Vector2(step_x, 0), radius):
				velocity.x = 0
		if abs(step_y) > 0.001:
			if game_ref.is_world_blocked_at(global_position + Vector2(0, step_y), radius):
				velocity.y = 0

	move_and_slide()


func _update_hit_cooldowns(delta: float) -> void:
	for k in hit_cooldowns.keys():
		hit_cooldowns[k] = max(0.0, hit_cooldowns[k] - delta)


func _update_ranged_attack(delta: float, target: Node2D, distance: float) -> bool:
	if ranged_params.is_empty():
		return false
	if special_ai_mode != "" and special_ai_mode != "stationary":
		return false
	_ranged_cooldown = max(0.0, _ranged_cooldown - delta)
	if _ranged_warning != null and is_instance_valid(_ranged_warning):
		_ranged_windup_left = max(0.0, _ranged_windup_left - delta)
		_ranged_warning.set_meta("time_left", _ranged_windup_left)
		_ranged_warning.queue_redraw()
		if _ranged_windup_left <= 0.0:
			_fire_ranged_attack()
		return true
	var range: float = float(ranged_params.get("range", 280.0))
	var min_range: float = float(ranged_params.get("min_range", 80.0))
	if target == null or distance < min_range or distance > range or _ranged_cooldown > 0.0:
		return false
	_start_ranged_attack(target, range)
	return true


func _start_ranged_attack(target: Node2D, range: float) -> void:
	if String(ranged_params.get("kind", "line")) == "bomb":
		_start_bomb_ranged_attack(target)
		return
	_ranged_origin = global_position
	var tgt_pos: Vector2 = _player_target_pos(target)
	_ranged_dir = (tgt_pos - _ranged_origin).normalized()
	if _ranged_dir.length_squared() <= 0.001:
		_ranged_dir = Vector2.RIGHT
	_ranged_length = min(range, _ranged_origin.distance_to(tgt_pos) + 44.0)
	_ranged_windup_left = max(0.15, float(ranged_params.get("windup", 0.9)))
	_ranged_warning = DrawerNode2D.new()
	_ranged_warning.z_index = 11
	_ranged_warning.fn = Callable(self, "_draw_ranged_warning")
	_ranged_warning.global_position = _ranged_origin
	_ranged_warning.rotation = _ranged_dir.angle()
	_ranged_warning.set_meta("length", _ranged_length)
	_ranged_warning.set_meta("width", float(ranged_params.get("width", 42.0)))
	_ranged_warning.set_meta("windup", _ranged_windup_left)
	_ranged_warning.set_meta("time_left", _ranged_windup_left)
	get_tree().current_scene.add_child(_ranged_warning)


func _draw_ranged_warning(node: Node2D) -> void:
	var length: float = float(node.get_meta("length", 260.0))
	var width: float = float(node.get_meta("width", 42.0))
	var windup: float = max(0.01, float(node.get_meta("windup", 1.0)))
	var time_left: float = float(node.get_meta("time_left", 0.0))
	var ready: float = clampf(1.0 - time_left / windup, 0.0, 1.0)
	var rect := Rect2(0.0, -width * 0.5, length, width)
	node.draw_rect(rect, Color(1.0, 0.12, 0.08, 0.16 + ready * 0.22))
	node.draw_rect(Rect2(0.0, -width * 0.5, length * ready, width), Color(1.0, 0.82, 0.18, 0.18))
	node.draw_line(Vector2.ZERO, Vector2(length, 0.0), Color(1.0, 0.35, 0.16, 0.95), 3.0)
	node.draw_arc(Vector2(length, 0.0), width * 0.5, 0.0, TAU, 32, Color(1.0, 0.35, 0.16, 0.9), 2.0)


func _start_bomb_ranged_attack(target: Node2D) -> void:
	_ranged_origin = _player_target_pos(target)
	_ranged_windup_left = max(0.2, float(ranged_params.get("windup", 1.0)))
	_ranged_warning = DrawerNode2D.new()
	_ranged_warning.z_index = 11
	_ranged_warning.fn = Callable(self, "_draw_bomb_warning")
	_ranged_warning.global_position = _ranged_origin
	_ranged_warning.set_meta("radius", float(ranged_params.get("aoe_radius", 80.0)))
	_ranged_warning.set_meta("windup", _ranged_windup_left)
	_ranged_warning.set_meta("time_left", _ranged_windup_left)
	get_tree().current_scene.add_child(_ranged_warning)


func _draw_bomb_warning(node: Node2D) -> void:
	var rad: float = float(node.get_meta("radius", 80.0))
	var windup: float = max(0.01, float(node.get_meta("windup", 1.0)))
	var time_left: float = float(node.get_meta("time_left", 0.0))
	var ready: float = clampf(1.0 - time_left / windup, 0.0, 1.0)
	node.draw_circle(Vector2.ZERO, rad, Color(1.0, 0.35, 0.08, 0.14 + ready * 0.24))
	node.draw_arc(Vector2.ZERO, rad, 0.0, TAU, 48, Color(1.0, 0.55, 0.12, 0.9), 3.0)
	node.draw_arc(Vector2.ZERO, rad * ready, 0.0, TAU, 48, Color(1.0, 0.9, 0.25, 0.75), 2.0)


func _fire_ranged_attack() -> void:
	if String(ranged_params.get("kind", "line")) == "bomb":
		var rad: float = float(ranged_params.get("aoe_radius", 80.0))
		var dmg: float = damage * float(ranged_params.get("damage_mult", 0.85))
		for p in get_tree().get_nodes_in_group("players"):
			if p == null or not is_instance_valid(p) or p.hp <= 0:
				continue
			if _ranged_origin.distance_to(_player_target_pos(p)) <= rad + 18.0:
				p.take_damage(dmg)
				_apply_player_hit_effects(p)
		_clear_ranged_warning()
		_ranged_cooldown = max(0.3, float(ranged_params.get("cooldown", 4.0)))
		return
	var width: float = float(ranged_params.get("width", 42.0))
	var dmg: float = damage * float(ranged_params.get("damage_mult", 0.75))
	for p in get_tree().get_nodes_in_group("players"):
		if p == null or not is_instance_valid(p) or p.hp <= 0:
			continue
		var rel: Vector2 = _player_target_pos(p) - _ranged_origin
		var along: float = rel.dot(_ranged_dir)
		if along < 0.0 or along > _ranged_length:
			continue
		var perp: float = abs(rel.cross(_ranged_dir))
		if perp <= width * 0.5 + 18.0:
			p.take_damage(dmg)
			_apply_player_hit_effects(p)
	_clear_ranged_warning()
	_ranged_cooldown = max(0.3, float(ranged_params.get("cooldown", 4.0)))


func _clear_ranged_warning() -> void:
	if _ranged_warning != null and is_instance_valid(_ranged_warning):
		_ranged_warning.queue_free()
	_ranged_warning = null
	_ranged_windup_left = 0.0


func _update_summon_minions(delta: float) -> void:
	if summon_params.is_empty() or special_ai_mode != "":
		return
	_summon_cooldown -= delta
	if _summon_cooldown > 0.0:
		return
	_summon_cooldown = maxf(3.0, float(summon_params.get("interval", 9.0)))
	var count: int = clampi(int(summon_params.get("count", 2)), 1, 5)
	var ids_raw: Variant = summon_params.get("enemy_ids", [])
	var level_mult: float = float(summon_params.get("level_mult", 0.88))
	if game_ref == null or not game_ref.has_method("spawn_enemy_from_def"):
		return
	for _i in range(count):
		var minion_def: Dictionary = {}
		if ids_raw is Array and not ids_raw.is_empty():
			var pick_id: String = String(ids_raw[randi() % ids_raw.size()])
			minion_def = GameData.get_enemy_def(pick_id)
		elif summon_params.has("pool_id"):
			minion_def = GameData.pick_enemy_from_pool(
				String(summon_params["pool_id"]), _spawn_level_factor * level_mult)
		if minion_def.is_empty() or minion_def.get("stage_boss", false):
			continue
		var ang: float = randf() * TAU
		var dist: float = randf_range(72.0, 140.0)
		var pos: Vector2 = global_position + Vector2(cos(ang), sin(ang)) * dist
		game_ref.spawn_enemy_from_def(minion_def, pos, _spawn_level_factor * level_mult)


func _resolve_hit_effects() -> Dictionary:
	if not hit_effects.is_empty():
		return hit_effects
	if ranged_params.has("hit_effects") and ranged_params["hit_effects"] is Dictionary:
		return ranged_params["hit_effects"]
	return {}


func _apply_player_hit_effects(player: Node) -> void:
	var effects: Dictionary = _resolve_hit_effects()
	if effects.is_empty() or player == null:
		return
	if player.has_method("apply_enemy_status_effects"):
		player.apply_enemy_status_effects(effects, global_position)


func _apply_melee_aoe_splash(primary: Node, base_damage: float) -> void:
	var splash_radius: float = float(melee_aoe_params.get("radius", 64.0))
	var splash_mult: float = float(melee_aoe_params.get("damage_mult", 0.65))
	var splash_dmg: float = base_damage * splash_mult
	for p in get_tree().get_nodes_in_group("players"):
		if p == null or not is_instance_valid(p) or p == primary or p.hp <= 0:
			continue
		if global_position.distance_to(_player_target_pos(p)) <= splash_radius + radius:
			p.take_damage(splash_dmg)
			_apply_player_hit_effects(p)


func take_damage(d: float, source: Node = null, opts: Dictionary = {}) -> void:
	if _dying or hp <= 0.0:
		return
	var dmg: float = d
	if _vuln_time > 0.0 and _vuln_stacks > 0:
		dmg *= 1.0 + float(_vuln_stacks) * GameData.ENEMY_STATUS_MELODY_VULN_PER_STACK
	var def_def: float = float(slime_def.get("defense", 0.0))
	dmg *= 1.0 - clampf(def_def, 0.0, 0.35)
	# 先計算實際扣血（不能超過剩餘 hp，避免超殺把統計灌爆）
	var taken: float = clamp(dmg, 0.0, max(0.0, hp))
	hp -= dmg
	_update_health_bar()
	if not opts.get("suppress_popup", false) and taken >= 0.5:
		var from_dot: bool = bool(opts.get("from_dot", false))
		if from_dot:
			if randf() < 0.35:
				DamagePopup.spawn_at(self, taken, false, true)
		else:
			DamagePopup.spawn_at(self, taken, bool(opts.get("is_crit", false)), false)
	# 通知造傷玩家：把實際扣血量加入該玩家的造成傷害統計
	var p: Node = _resolve_player_from_source(source)
	if p and p.has_method("register_damage_dealt"):
		p.register_damage_dealt(taken)
	if not opts.get("from_dot", false):
		AudioManager.play_sfx("enemy_hit", 0.05)
		modulate = Color(2.0, 2.0, 2.0)
		create_tween().tween_property(self, "modulate", Color(1, 1, 1), 0.12)
		if _health_bar and _health_bar.has_method("pulse_hit"):
			_health_bar.pulse_hit()
	if hp <= 0:
		_die(source)


func get_damage_popup_position() -> Vector2:
	var off := Vector2(randf_range(-14.0, 14.0), -(radius + 18.0))
	if sprite and sprite.texture:
		var frame_h: float = float(sprite.texture.get_height()) / maxf(1.0, float(sprite.vframes))
		off.y -= frame_h * absf(sprite.scale.y) * 0.38
	return global_position + off


func _ensure_health_bar() -> void:
	if _health_bar != null and is_instance_valid(_health_bar):
		_update_health_bar()
		return
	_health_bar = ENEMY_HEALTH_BAR_SCRIPT.new()
	add_child(_health_bar)
	if _health_bar.has_method("bind_enemy"):
		_health_bar.bind_enemy(self)
	_update_health_bar()


func _update_health_bar() -> void:
	if _health_bar == null or not is_instance_valid(_health_bar):
		return
	if max_hp <= 0.0:
		return
	if _health_bar.has_method("set_hp_ratio"):
		_health_bar.set_hp_ratio(hp / max_hp)


func is_status_slowed() -> bool:
	return _slow_time > 0.0


func is_status_bleeding() -> bool:
	return _bleed_time > 0.0 and _bleed_dps > 0.0


## 被技能等效果沿某方向平推（會檢查地形阻擋）
func apply_position_push(offset: Vector2) -> void:
	if offset.length_squared() < 1.0:
		return
	var dest: Vector2 = global_position + offset
	if game_ref != null and game_ref.has_method("is_world_blocked_at"):
		if game_ref.is_world_blocked_at(dest, radius):
			var half: Vector2 = offset * 0.5
			dest = global_position + half
			if game_ref.is_world_blocked_at(dest, radius):
				return
	global_position = dest


func apply_status_slow(duration: float, speed_factor: float = 0.55) -> void:
	_slow_time = max(_slow_time, duration)
	_slow_speed_factor = min(_slow_speed_factor, clamp(speed_factor, 0.15, 1.0))


func apply_stun(duration: float) -> void:
	_stun_time = max(_stun_time, duration)
	_clear_ranged_warning()


func apply_status_vulnerable(duration: float, stack_cap: int) -> void:
	_vuln_time = max(_vuln_time, duration)
	var cap: int = max(1, stack_cap)
	_vuln_stack_cap = max(_vuln_stack_cap, cap)
	_vuln_stacks = min(_vuln_stack_cap, _vuln_stacks + 1)


func apply_status_bleed(dps: float, duration: float, source: Node = null) -> void:
	if dps <= 0.0 or duration <= 0.0:
		return
	_bleed_time = max(_bleed_time, duration)
	_bleed_dps = max(_bleed_dps, dps)
	if source != null:
		_bleed_source = source


func apply_status_burn(dps: float, duration: float, source: Node = null) -> void:
	if dps <= 0.0 or duration <= 0.0:
		return
	_burn_time = max(_burn_time, duration)
	_burn_dps = max(_burn_dps, dps)
	if source != null:
		_burn_source = source


func apply_status_poison(
		dps: float, duration: float, source: Node = null, weaken_attack: bool = false) -> void:
	if dps <= 0.0 or duration <= 0.0:
		return
	_poison_time = max(_poison_time, duration)
	_poison_dps = max(_poison_dps, dps)
	if source != null:
		_poison_source = source
	if weaken_attack:
		_poison_atk_reduce = max(
			_poison_atk_reduce, GameData.ENEMY_STATUS_POISON_ATK_REDUCE)


func _advance_enemy_status(delta: float) -> void:
	_dot_tick_carry += delta
	var step: float = GameData.ENEMY_STATUS_TICK_SEC
	while _dot_tick_carry >= step:
		_dot_tick_carry -= step
		_pulse_dot_sources(step)
	_slow_time = max(0.0, _slow_time - delta)
	if _slow_time <= 0.0:
		_slow_speed_factor = 1.0
	_stun_time = max(0.0, _stun_time - delta)
	_vuln_time = max(0.0, _vuln_time - delta)
	if _vuln_time <= 0.0:
		_vuln_stacks = 0
		_vuln_stack_cap = 0
	_bleed_time = max(0.0, _bleed_time - delta)
	if _bleed_time <= 0.0:
		_bleed_dps = 0.0
	_burn_time = max(0.0, _burn_time - delta)
	if _burn_time <= 0.0:
		_burn_dps = 0.0
	_poison_time = max(0.0, _poison_time - delta)
	if _poison_time <= 0.0:
		_poison_dps = 0.0
		_poison_atk_reduce = 0.0
	_sync_status_effect_icons()


func _enemy_status_icon_head_y() -> float:
	var head_y: float = -(radius + 4.0)
	var off_y: float = float(slime_def.get("offset_y", 0))
	if sprite != null and sprite.texture:
		var frame_h: float = float(sprite.texture.get_height()) / maxf(1.0, float(sprite.vframes))
		head_y -= frame_h * absf(sprite.scale.y) * 0.18
	head_y += off_y * 0.22 + 8.0
	return head_y


func _enemy_status_icon_scale() -> float:
	return clampf(radius / 17.0, StatusEffectOverlay.ENEMY_ICON_SCALE_MIN,
		StatusEffectOverlay.ENEMY_ICON_SCALE_MAX)


func _ensure_status_overlay() -> void:
	var head_y: float = _enemy_status_icon_head_y()
	var off_y: float = float(slime_def.get("offset_y", 0))
	var body_y: float = off_y * 0.38 - radius * 0.18
	var icon_scale: float = _enemy_status_icon_scale()
	if _status_overlay != null and is_instance_valid(_status_overlay):
		_status_overlay.configure(false, head_y, Vector2(0.0, body_y), icon_scale)
		return
	_status_overlay = STATUS_OVERLAY_SCRIPT.new()
	add_child(_status_overlay)
	_status_overlay.configure(false, head_y, Vector2(0.0, body_y), icon_scale)


func _sync_status_effect_icons() -> void:
	if _dying or hp <= 0.0:
		if _status_overlay != null and is_instance_valid(_status_overlay):
			_status_overlay.sync({})
		return
	_ensure_status_overlay()
	if _status_overlay == null:
		return
	var active: Dictionary = {}
	if _slow_time > 0.0:
		active[StatusEffectIcons.STATUS_SLOW] = true
	if _stun_time > 0.0:
		active[StatusEffectIcons.STATUS_STUN] = true
	if _bleed_time > 0.0 and _bleed_dps > 0.0:
		active[StatusEffectIcons.STATUS_BLEED] = true
	if _burn_time > 0.0 and _burn_dps > 0.0:
		active[StatusEffectIcons.STATUS_BURN] = true
	if _poison_time > 0.0 and _poison_dps > 0.0:
		active[StatusEffectIcons.STATUS_POISON] = true
	if _vuln_time > 0.0 and _vuln_stacks > 0:
		active[StatusEffectIcons.STATUS_VULN] = true
	_status_overlay.sync(active)


func _pulse_dot_sources(step: float) -> void:
	var dot_opts := {"from_dot": true}
	if _bleed_time > 0.0 and _bleed_dps > 0.0:
		take_damage(_bleed_dps * step, _bleed_source, dot_opts)
	if _burn_time > 0.0 and _burn_dps > 0.0:
		take_damage(_burn_dps * step, _burn_source, dot_opts)
	if _poison_time > 0.0 and _poison_dps > 0.0:
		take_damage(_poison_dps * step, _poison_source, dot_opts)


func _resolve_player_from_source(source: Node) -> Node:
	if source == null:
		return null
	if source.is_in_group("players"):
		return source
	var op: Variant = source.get("owner_player")
	if op != null and op is Node:
		return op
	return null


func _die(source: Node) -> void:
	if _dying:
		return
	_sync_status_effect_icons()
	_clear_ranged_warning()
	if source and source.has_method("on_enemy_killed"):
		source.on_enemy_killed(self)
	elif source and source is Node and source.get("owner_player"):
		var p = source.owner_player
		if p and p.has_method("on_enemy_killed"):
			p.on_enemy_killed(self)
	var orb_scene: PackedScene = preload("res://scenes/XpOrb.tscn")
	var orb = orb_scene.instantiate()
	orb.global_position = global_position
	orb.value = xp_value
	get_tree().current_scene.add_child(orb)
	_try_drop_gold()
	_try_drop_material()
	_try_drop_summon_egg()
	_try_grant_rune_dust()
	if _has_death_animation():
		_begin_death_animation()
	else:
		queue_free()


func _try_grant_rune_dust() -> void:
	if rune_dust_drop <= 0:
		return
	if is_instance_valid(GameState) and GameState.has_method("grant_rune_dust"):
		GameState.grant_rune_dust(rune_dust_drop)
	if game_ref != null and game_ref.has_method("notify_rune_dust_drop"):
		game_ref.notify_rune_dust_drop(rune_dust_drop)


func _try_drop_gold() -> void:
	var amount: int = _roll_gold_drop_amount()
	if amount <= 0:
		return
	var gold = GOLD_ORB_SCENE.instantiate()
	gold.global_position = global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0))
	gold.value = amount
	get_tree().current_scene.add_child(gold)


func _try_drop_material() -> void:
	if bool(slime_def.get("boss", false)):
		return
	if special_ai_mode != "":
		return
	if game_ref == null or not game_ref.has_method("roll_enemy_material_drop"):
		return
	var drop: Dictionary = game_ref.roll_enemy_material_drop(slime_def)
	var id: String = String(drop.get("id", ""))
	var amount: int = int(drop.get("amount", 0))
	if id == "" or amount <= 0:
		return
	var orb = MATERIAL_ORB_SCENE.instantiate()
	orb.setup(id, amount)
	orb.global_position = global_position + Vector2(randf_range(-12.0, 12.0), randf_range(-10.0, 10.0))
	get_tree().current_scene.add_child(orb)


func _try_drop_summon_egg() -> void:
	if bool(slime_def.get("boss", false)):
		return
	if special_ai_mode != "":
		return
	if game_ref == null or not game_ref.has_method("try_enemy_summon_egg_drop"):
		return
	game_ref.try_enemy_summon_egg_drop()


func _roll_gold_drop_amount() -> int:
	if bool(slime_def.get("stage_boss", false)):
		return randi_range(25, 40)
	if bool(slime_def.get("boss", false)):
		if randf() <= GOLD_DROP_BOSS_CHANCE:
			return randi_range(8, 14)
		return 0
	if bool(slime_def.get("elite", false)):
		if randf() <= GOLD_DROP_ELITE_CHANCE:
			return randi_range(2, 4)
		return 0
	if randf() <= GOLD_DROP_NORMAL_CHANCE:
		return randi_range(1, 2)
	return 0


func _frame_count_for_row(row: int) -> int:
	if row < frames_per_row.size():
		return max(1, int(frames_per_row[row]))
	return max(1, hframes_count)


func _death_row() -> int:
	return clampi(int(slime_def.get("anim_row_death", ROW_DEATH)), 0, maxi(0, vframes_count - 1))


func _has_death_animation() -> bool:
	if sprite == null or sprite.texture == null or hframes_count <= 1:
		return false
	return vframes_count > _death_row()


func _begin_death_animation() -> void:
	_dying = true
	if _health_bar and is_instance_valid(_health_bar):
		_health_bar.queue_free()
		_health_bar = null
	velocity = Vector2.ZERO
	hit_cooldowns.clear()
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	if body_shape:
		body_shape.set_deferred("disabled", true)
	anim_time = 0.0
	modulate = Color(1, 1, 1, 1)
	var dr: int = _death_row()
	sprite.frame = dr * hframes_count


func _process_death_animation(delta: float) -> void:
	if not _has_death_animation():
		queue_free()
		return
	anim_time += delta
	var dr: int = _death_row()
	var fcount: int = _frame_count_for_row(dr)
	var f: int = min(fcount - 1, int(anim_time * ANIM_FPS))
	sprite.frame = dr * hframes_count + f
	if anim_time >= float(fcount) / ANIM_FPS:
		queue_free()
