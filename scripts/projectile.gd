extends Area2D
## 投射物：直線/波浪移動，命中敵人扣血，可貫穿。

const BOW_ARROW_TEX: Texture2D = preload("res://assets/Effects/arrow/arrow_.png")
const ARROW_DISPLAY_LEN := 48.0
const ARROW_Z_INDEX := 55
const MAGIC_BULLET_Z_INDEX := 56

var velocity: Vector2 = Vector2.ZERO
var weapon: Node = null
var pierce_left: int = 0
var bounces_left: int = 0
var bullet_speed: float = 500.0
var explode_radius: float = 0.0
var hit_set: Dictionary = {}
var lifetime: float = 1.5
var elapsed: float = 0.0
var color: Color = Color.WHITE
var wave: bool = false
var wave_seed: float = 0.0
var origin: Vector2 = Vector2.ZERO
var max_distance: float = 800.0
var damage_mult: float = 1.0

@onready var sprite: Polygon2D = $Sprite
@onready var _collision_shape: CollisionShape2D = $Shape

var _arrow_sprite: Sprite2D = null
var _magic_sprite: AnimatedSprite2D = null
var _magic_cfg: Dictionary = {}
var _bow_element_cfg: Dictionary = {}
var _magic_manual_hit: bool = false
var _hit_variant: String = ""


func setup(w: Node, vel: Vector2, col: Color) -> void:
	weapon = w
	velocity = vel
	color = col
	bullet_speed = vel.length()
	var def: Dictionary = w.def
	pierce_left = int(def["params"].get("pierce", 0))
	bounces_left = 0
	explode_radius = float(def["params"].get("explode_radius", 0.0))
	if w is WeaponBase:
		var wb: WeaponBase = w as WeaponBase
		var wid: String = String(def.get("id", ""))
		if wb.weapon_upgrades_maxed() and wid == "bow":
			pierce_left += 2
		if wb.weapon_upgrades_maxed() and wid == "lightning":
			bounces_left = 2
		if wb.weapon_upgrades_maxed() and wid == "magic_bullet" and explode_radius > 0.0:
			var brng: Dictionary = GameData.get_weapon_def("magic_bullet")
			var base_range: float = float(brng.get("range", 500.0))
			if base_range > 1.0:
				explode_radius *= wb.eff_range / base_range
	if w.has_method("get_extra_pierce"):
		pierce_left += int(w.get_extra_pierce())
	if w.has_method("get_shot_damage_mult"):
		damage_mult = maxf(0.05, float(w.get_shot_damage_mult()))
	if w.has_method("get_spawn_range"):
		max_distance = maxf(40.0, float(w.get_spawn_range()))
	wave = bool(def["params"].get("wave", false))
	wave_seed = randf() * TAU
	if not w.has_method("get_spawn_range"):
		max_distance = float(w.eff_range)
	lifetime = clamp(max_distance / max(60.0, vel.length()) + 0.4, 0.4, 4.0)
	_bow_element_cfg = _resolve_bow_element_visual_cfg()
	if not _bow_element_cfg.is_empty():
		call_deferred("_apply_sheet_projectile_visual")
	elif _uses_arrow_sprite():
		call_deferred("_apply_arrow_visual")
	elif _uses_sheet_projectile():
		call_deferred("_apply_sheet_projectile_visual")


func set_hit_variant(variant: String) -> void:
	_hit_variant = variant


func _weapon_def() -> Dictionary:
	if weapon == null:
		return {}
	var raw: Variant = weapon.get("def")
	return raw if raw is Dictionary else {}


func _owner_player() -> Node:
	if weapon == null:
		return null
	var raw: Variant = weapon.get("owner_player")
	return raw if raw is Node else null


func _resolve_bow_element_visual_cfg() -> Dictionary:
	if String(_weapon_def().get("id", "")) != "bow":
		return {}
	return GameData.resolve_bow_projectile_visual(_owner_player())


func _uses_arrow_sprite() -> bool:
	if not _bow_element_cfg.is_empty():
		return false
	var def: Dictionary = _weapon_def()
	var prm: Dictionary = def.get("params", {})
	if bool(prm.get("arrow_sprite", false)):
		return true
	return String(def.get("id", "")) == "bow"


func _is_magic_bullet() -> bool:
	return String(_weapon_def().get("id", "")) == "magic_bullet"


func _uses_sheet_projectile() -> bool:
	return not _projectile_visual_cfg().is_empty()


func _projectile_visual_cfg() -> Dictionary:
	if not _bow_element_cfg.is_empty():
		return _bow_element_cfg
	var prm: Dictionary = _weapon_def().get("params", {})
	var raw: Variant = prm.get("projectile_visual", null)
	return raw if raw is Dictionary else {}


func _prepare_arrow_display(tex: Texture2D) -> Dictionary:
	if tex == null:
		return {}
	var tw: float = float(maxi(1, tex.get_width()))
	var th: float = float(maxi(1, tex.get_height()))
	var trim: Dictionary = GameData.trim_preview_texture(tex)
	var use_tex: Texture2D = trim.get("texture")
	var w: float = float(trim.get("w", 1.0))
	var h: float = float(trim.get("h", 1.0))
	# 不透明大底圖時 trim 會含整張 → 改取中央橫帶再裁一次
	if w >= tw * 0.7 and h >= th * 0.7 and maxf(tw, th) > 64.0:
		var band_h: float = clampf(th * 0.25, 10.0, 72.0)
		var band := AtlasTexture.new()
		band.atlas = tex
		band.region = Rect2(0.0, (th - band_h) * 0.5, tw, band_h)
		trim = GameData.trim_preview_texture(band)
		use_tex = trim.get("texture")
		w = float(trim.get("w", 1.0))
		h = float(trim.get("h", 1.0))
	if use_tex == null or w < 1.0 or h < 1.0:
		return {}
	var sc: float = ARROW_DISPLAY_LEN / maxf(w, h)
	# 裁切失敗或底圖過大時，避免縮到幾乎看不見
	if sc < 0.35:
		sc = ARROW_DISPLAY_LEN / maxf(16.0, minf(tw, th) * 0.12)
	sc = clampf(sc, 0.75, 8.0)
	return {"texture": use_tex, "scale": Vector2(sc, sc)}


func _apply_arrow_visual() -> void:
	if _arrow_sprite != null and is_instance_valid(_arrow_sprite):
		return
	if not _uses_arrow_sprite():
		return
	var prepared: Dictionary = _prepare_arrow_display(BOW_ARROW_TEX)
	if prepared.is_empty():
		push_warning("[Projectile] 無法建立箭矢貼圖：%s" % GameData.BOW_ARROW_PROJECTILE_TEXTURE)
		if sprite:
			sprite.visible = true
			sprite.color = color
		return
	if sprite:
		sprite.visible = false
	_arrow_sprite = Sprite2D.new()
	_arrow_sprite.texture = prepared["texture"]
	_arrow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_arrow_sprite.centered = true
	_arrow_sprite.scale = prepared["scale"]
	_arrow_sprite.modulate = Color(
		minf(1.25, color.r * 1.15),
		minf(1.25, color.g * 1.15),
		minf(1.25, color.b * 1.15),
		1.0)
	add_child(_arrow_sprite)
	z_index = ARROW_Z_INDEX
	rotation = velocity.angle()


func _apply_sheet_projectile_visual() -> void:
	if _magic_sprite != null and is_instance_valid(_magic_sprite):
		return
	if not _uses_sheet_projectile():
		return
	_magic_cfg = _projectile_visual_cfg()
	var cfg: Dictionary = _magic_cfg
	var spr := MagicBulletVfx.create_projectile_sprite(cfg, color)
	if spr == null:
		if sprite:
			sprite.visible = true
			sprite.color = color
		return
	if sprite:
		sprite.visible = false
	_magic_sprite = spr
	add_child(_magic_sprite)
	z_index = int(cfg.get("z_index", MAGIC_BULLET_Z_INDEX))
	rotation = MagicBulletVfx.rotation_for_velocity(velocity, cfg)
	_magic_sprite.position = MagicBulletVfx.sprite_display_offset(cfg)
	if bool(cfg.get("manual_hit_probe", false)):
		_configure_magic_collision(cfg)
	_magic_manual_hit = bool(cfg.get("manual_hit_probe", false))
	if _magic_manual_hit:
		monitoring = false
	if _should_show_projectile_hit_debug():
		MagicBulletProjectileDebug.attach(self, cfg)


func _should_show_projectile_hit_debug() -> bool:
	var prm: Dictionary = _weapon_def().get("params", {})
	return bool(prm.get("show_projectile_hit_debug", false))


func _ready() -> void:
	add_to_group("projectiles")
	origin = global_position
	_apply_arrow_visual()
	_apply_sheet_projectile_visual()
	if _arrow_sprite == null and _magic_sprite == null and sprite:
		sprite.visible = true
		sprite.color = color
	elif _magic_sprite == null:
		rotation = velocity.angle()


func _physics_process(delta: float) -> void:
	elapsed += delta
	if wave:
		var perp: Vector2 = velocity.rotated(PI * 0.5).normalized()
		var move: Vector2 = velocity * delta
		var bob: Vector2 = perp * sin(elapsed * 8.0 + wave_seed) * 60.0 * delta
		global_position += move + bob
	else:
		global_position += velocity * delta
	if _magic_manual_hit:
		_try_magic_probe_hits()
	if origin.distance_to(global_position) > max_distance or elapsed > lifetime:
		_finish()


func _try_magic_probe_hits() -> void:
	if not _magic_manual_hit or weapon == null:
		return
	var probe: Vector2 = MagicBulletVfx.hit_probe_global(self, _magic_cfg)
	var hit_r: float = MagicBulletVfx.hit_radius(_magic_cfg)
	for e in get_tree().get_nodes_in_group("enemies"):
		if hit_set.has(e):
			continue
		if not (e is Node2D):
			continue
		if MagicBulletVfx.probe_hits_enemy(probe, hit_r, e as Node2D):
			_try_hit(e)


func _on_body_entered(body: Node) -> void:
	if _magic_manual_hit:
		return
	_try_hit(body)


func _on_area_entered(area: Area2D) -> void:
	pass


func _try_hit(body: Node) -> void:
	if not body.is_in_group("enemies"):
		return
	if hit_set.has(body):
		return
	hit_set[body] = true
	if weapon:
		weapon.damage_enemy(body, damage_mult, {"variant": _hit_variant})
	if weapon and weapon.def["params"].get("slow", false) \
			and body.has_method("apply_status_slow"):
		body.apply_status_slow(
			GameData.ENEMY_STATUS_ICE_SLOW_DURATION,
			GameData.ENEMY_STATUS_ICE_SLOW_FACTOR)
		if weapon.has_method("_notify_owner_status_applied"):
			weapon._notify_owner_status_applied()
	if pierce_left > 0:
		pierce_left -= 1
		return
	if bounces_left > 0:
		var nxt: Node = _find_ricochet_target(body)
		if nxt != null:
			bounces_left -= 1
			velocity = (nxt.global_position - global_position).normalized() * bullet_speed
			_update_facing_rotation()
			max_distance += 260.0
			lifetime += 0.45
			return
	if explode_radius > 0.0 and String(_weapon_def().get("id", "")) == "magic_bullet":
		_trigger_magic_bullet_explosion(body as Node2D)
		return
	if explode_radius > 0.0:
		MagicBulletExplodeDebug.apply_aoe_damage(
			get_tree(), weapon, global_position, explode_radius, 0.8)
	_finish()


func _explosion_visual_cfg() -> Dictionary:
	var prm: Dictionary = _weapon_def().get("params", {})
	var raw: Variant = prm.get("explosion_visual", null)
	return raw if raw is Dictionary else {}


func _should_show_explode_debug() -> bool:
	var prm: Dictionary = _weapon_def().get("params", {})
	return bool(prm.get("show_explode_debug", false))


func _configure_magic_collision(cfg: Dictionary) -> void:
	if _collision_shape == null:
		return
	_collision_shape.position = MagicBulletVfx.hit_probe_local_offset(cfg)
	var cs: CircleShape2D = _collision_shape.shape as CircleShape2D
	if cs == null:
		cs = CircleShape2D.new()
		_collision_shape.shape = cs
	cs.radius = MagicBulletVfx.hit_radius(cfg)
	if _magic_manual_hit:
		_collision_shape.disabled = true


func _trigger_magic_bullet_explosion(primary: Node2D) -> void:
	var probe: Vector2 = MagicBulletVfx.hit_probe_global(self, _magic_cfg)
	var explode_cfg: Dictionary = _explosion_visual_cfg()
	var hit_pos: Vector2 = MagicBulletVfx.explosion_center_at_hit(probe, primary, explode_cfg)
	var w: Node = weapon
	var rad: float = explode_radius
	var mult: float = 0.8
	var tree: SceneTree = get_tree()
	var parent: Node = tree.current_scene if tree != null else null
	if parent != null:
		MagicBulletVfx.spawn_explosion(parent, hit_pos, rad, explode_cfg)
		MagicBulletExplodeDebug.spawn(
			parent, hit_pos, rad, explode_cfg, _should_show_explode_debug())
	var delay: float = MagicBulletExplodeDebug.damage_delay_sec(explode_cfg)
	if tree != null and w != null:
		tree.create_timer(delay).timeout.connect(
			func() -> void:
				MagicBulletExplodeDebug.apply_aoe_damage(tree, w, hit_pos, rad, mult),
			CONNECT_ONE_SHOT)
	_finish()


func _update_facing_rotation() -> void:
	if _magic_sprite != null and is_instance_valid(_magic_sprite):
		var cfg: Dictionary = _magic_cfg if not _magic_cfg.is_empty() else _projectile_visual_cfg()
		rotation = MagicBulletVfx.rotation_for_velocity(velocity, cfg)
		_magic_sprite.position = MagicBulletVfx.sprite_display_offset(cfg)
		if _magic_manual_hit:
			_configure_magic_collision(cfg)
	else:
		rotation = velocity.angle()


func _find_ricochet_target(last_hit: Node) -> Node:
	var best: Node = null
	var best_d: float = 1e12
	var max_d2: float = 420.0 * 420.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == last_hit or hit_set.has(e):
			continue
		if not is_instance_valid(e):
			continue
		if e.get("hp") != null and float(e.hp) <= 0.0:
			continue
		var d2: float = global_position.distance_squared_to(e.global_position)
		if d2 <= max_d2 and d2 < best_d:
			best_d = d2
			best = e
	return best


func _finish() -> void:
	queue_free()
