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

var game_ref: Node = null

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
	damage = base_dmg * float(def.get("dmg_mult", 1.0))
	xp_value = base_xp * float(def.get("xp_mult", 1.0))


# 舊介面：難度直接 setup（隨機選一隻）
func setup(level_factor: float) -> void:
	var def: Dictionary = GameData.pick_slime(level_factor)
	setup_with_slime(def, level_factor)


func _process(delta: float) -> void:
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
	var fcount: int = hframes_count
	if row < frames_per_row.size():
		fcount = max(1, int(frames_per_row[row]))
	var f: int = int(anim_time * ANIM_FPS) % fcount
	sprite.frame = row * hframes_count + f


func _physics_process(delta: float) -> void:
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
		velocity = dir * move_speed
		if best < radius + 30.0:
			var k: String = str(target.get_instance_id())
			if hit_cooldowns.get(k, 0.0) <= 0.0:
				target.take_damage(damage)
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


func take_damage(d: float, source: Node = null) -> void:
	# 先計算實際扣血（不能超過剩餘 hp，避免超殺把統計灌爆）
	var taken: float = clamp(d, 0.0, max(0.0, hp))
	hp -= d
	# 通知造傷玩家：把實際扣血量加入該玩家的造成傷害統計
	var p: Node = _resolve_player_from_source(source)
	if p and p.has_method("register_damage_dealt"):
		p.register_damage_dealt(taken)
	modulate = Color(2.0, 2.0, 2.0)
	create_tween().tween_property(self, "modulate", Color(1, 1, 1), 0.12)
	if hp <= 0:
		_die(source)


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
	queue_free()
