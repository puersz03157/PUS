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
const GOLD_DROP_NORMAL_CHANCE := 0.08
const GOLD_DROP_ELITE_CHANCE := 0.18
const GOLD_DROP_BOSS_CHANCE := 0.60

var game_ref: Node = null
var _dying: bool = false
var special_ai_mode: String = ""
var flee_lifetime: float = 12.0
var rune_dust_drop: int = 0
var _special_age: float = 0.0

# 緩速：對 _base_move_speed 乘算（寒冰等）
var _base_move_speed: float = 90.0
var _slow_time: float = 0.0
var _slow_speed_factor: float = 1.0
# 易傷：飛鏢疊層，滿級提高層數上限（傷害乘算 1 + 層數×係數）
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
			sprite.frame = 0
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
	# 套用屬性 — 基底數值依 level_factor 提升，再乘上各 slime 倍率
	var base_hp: float = 6.0 + level_factor * 4.0
	var base_speed: float = 70.0 + level_factor * 6.0
	var base_dmg: float = 5.0 + level_factor * 1.5
	var base_xp: float = 1.0 + level_factor * 0.15
	max_hp = base_hp * float(def.get("hp_mult", 1.0))
	hp = max_hp
	move_speed = base_speed * float(def.get("speed_mult", 1.0))
	_base_move_speed = move_speed
	damage = base_dmg * float(def.get("dmg_mult", 1.0))
	xp_value = base_xp * float(def.get("xp_mult", 1.0))


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


func _process(delta: float) -> void:
	if _dying:
		_process_death_animation(delta)
		return
	if sprite == null or sprite.texture == null or hframes_count <= 1:
		return
	anim_time += delta
	# 移動時走 row 1（行走），靜止時 row 0（待機）；若沒有 row 1 則只用 row 0
	var moving: bool = velocity.length_squared() > 1.0
	var row: int = ROW_IDLE
	if moving and vframes_count > 1 and frames_per_row.size() > 1 and frames_per_row[1] > 0:
		row = ROW_WALK
	elif moving and vframes_count > 1 and frames_per_row.size() <= 1:
		row = ROW_WALK
	var fcount: int = _frame_count_for_row(row)
	var f: int = int(anim_time * ANIM_FPS) % fcount
	sprite.frame = row * hframes_count + f


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
	var target: Node2D = null
	var best: float = 1e9
	for p in get_tree().get_nodes_in_group("players"):
		if p.hp <= 0:
			continue
		var pp: Node2D = p as Node2D
		if pp == null:
			continue
		var d: float = global_position.distance_to(pp.global_position)
		if d < best:
			best = d
			target = pp

	if target == null:
		velocity = Vector2.ZERO
	else:
		var dir: Vector2 = (target.global_position - global_position).normalized()
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
				hit_cooldowns[k] = 0.6
		# 朝向：水平翻轉 sprite
		if sprite:
			if dir.x < -0.05:
				sprite.flip_h = true
			elif dir.x > 0.05:
				sprite.flip_h = false

	for k in hit_cooldowns.keys():
		hit_cooldowns[k] = max(0.0, hit_cooldowns[k] - delta)

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


func take_damage(d: float, source: Node = null, opts: Dictionary = {}) -> void:
	if _dying or hp <= 0.0:
		return
	var dmg: float = d
	if _vuln_time > 0.0 and _vuln_stacks > 0:
		dmg *= 1.0 + float(_vuln_stacks) * GameData.ENEMY_STATUS_MELODY_VULN_PER_STACK
	# 先計算實際扣血（不能超過剩餘 hp，避免超殺把統計灌爆）
	var taken: float = clamp(dmg, 0.0, max(0.0, hp))
	hp -= dmg
	# 通知造傷玩家：把實際扣血量加入該玩家的造成傷害統計
	var p: Node = _resolve_player_from_source(source)
	if p and p.has_method("register_damage_dealt"):
		p.register_damage_dealt(taken)
	if not opts.get("from_dot", false):
		AudioManager.play_sfx("enemy_hit", 0.05)
		modulate = Color(2.0, 2.0, 2.0)
		create_tween().tween_property(self, "modulate", Color(1, 1, 1), 0.12)
	if hp <= 0:
		_die(source)


func is_status_slowed() -> bool:
	return _slow_time > 0.0


func is_status_bleeding() -> bool:
	return _bleed_time > 0.0 and _bleed_dps > 0.0


func apply_status_slow(duration: float, speed_factor: float = 0.55) -> void:
	_slow_time = max(_slow_time, duration)
	_slow_speed_factor = min(_slow_speed_factor, clamp(speed_factor, 0.15, 1.0))


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


func _has_death_animation() -> bool:
	return sprite != null and sprite.texture != null and hframes_count > 1 and vframes_count > ROW_DEATH


func _begin_death_animation() -> void:
	_dying = true
	velocity = Vector2.ZERO
	hit_cooldowns.clear()
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	if body_shape:
		body_shape.set_deferred("disabled", true)
	anim_time = 0.0
	modulate = Color(1, 1, 1, 1)
	sprite.frame = ROW_DEATH * hframes_count


func _process_death_animation(delta: float) -> void:
	if not _has_death_animation():
		queue_free()
		return
	anim_time += delta
	var fcount: int = _frame_count_for_row(ROW_DEATH)
	var f: int = min(fcount - 1, int(anim_time * ANIM_FPS))
	sprite.frame = ROW_DEATH * hframes_count + f
	if anim_time >= float(fcount) / ANIM_FPS:
		queue_free()
