extends RefCounted
class_name MagicBulletVfx
## 魔彈飛行／爆炸 spritesheet 特效。

const DEFAULT_PROJECTILE_SHEET := "res://assets/Effects/magic_bullet/Projectile.png"
const DEFAULT_EXPLOSION_SHEET := "res://assets/Effects/magic_bullet/Explosion.png"
const DEFAULT_ART_TILT_DEG := 25.0
## 爆炸第 4～5 幀不透明外圈半徑（像素，約 18～22，依美術調）
const DEFAULT_VISUAL_PEAK_RADIUS := 18.0

static var _sprite_frames_cache: Dictionary = {}


static func art_direction(cfg: Dictionary) -> Vector2:
	var deg: float = float(cfg.get("art_tilt_deg", DEFAULT_ART_TILT_DEG))
	return Vector2(cos(deg_to_rad(deg)), -sin(deg_to_rad(deg))).normalized()


static func rotation_for_velocity(vel: Vector2, cfg: Dictionary) -> float:
	if vel == Vector2.ZERO:
		return 0.0
	return vel.angle() - art_direction(cfg).angle()


static func hit_probe_local_offset(cfg: Dictionary) -> Vector2:
	var fw: float = float(cfg.get("frame_w", 64))
	var tip_forward: float = float(cfg.get("hit_forward_offset", fw * 0.52))
	return art_direction(cfg) * tip_forward


## 貼圖中心 → 美術彈頭尖端距離；用於把 sprite 前移，尖端對齊青圈（hit probe）
static func visual_tip_offset(cfg: Dictionary) -> float:
	var fw: float = float(cfg.get("frame_w", 64))
	return float(cfg.get("visual_tip_offset", fw * 0.44))


static func sprite_display_offset(cfg: Dictionary) -> Vector2:
	var art: Vector2 = art_direction(cfg)
	if cfg.has("sprite_forward_offset"):
		return art * float(cfg.get("sprite_forward_offset"))
	if not bool(cfg.get("align_sprite_to_hit_probe", true)):
		return Vector2.ZERO
	var probe_d: float = hit_probe_local_offset(cfg).length()
	# 光點在貼圖中心「後方」（拖尾在飛行反方向）時，要把 sprite 再往前推
	var trail_back: float = float(cfg.get("visual_trail_back_offset", 0.0))
	if trail_back > 0.0:
		return art * (probe_d + trail_back)
	var tip_d: float = visual_tip_offset(cfg)
	return art * maxf(0.0, probe_d - tip_d)


static func hit_radius(cfg: Dictionary) -> float:
	return float(cfg.get("hit_radius", 5.0))


static func hit_probe_global(owner: Node2D, cfg: Dictionary) -> Vector2:
	if owner == null:
		return Vector2.ZERO
	return owner.global_position + hit_probe_local_offset(cfg).rotated(owner.rotation)


static func enemy_collision_radius(enemy: Node2D) -> float:
	if enemy == null:
		return 12.0
	if enemy.get("radius") != null:
		return float(enemy.radius)
	return 12.0


static func probe_hits_enemy(probe: Vector2, hit_r: float, enemy: Node2D) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if enemy.get("hp") != null and float(enemy.hp) <= 0.0:
		return false
	return probe.distance_to(enemy.global_position) <= enemy_collision_radius(enemy) + hit_r


static func impact_point_at_probe(probe: Vector2, enemy: Node2D) -> Vector2:
	if enemy == null or not is_instance_valid(enemy):
		return probe
	var enemy_pos: Vector2 = enemy.global_position
	var to_enemy: Vector2 = enemy_pos - probe
	if to_enemy.length_squared() < 4.0:
		return enemy_pos
	var dir: Vector2 = to_enemy.normalized()
	return enemy_pos - dir * enemy_collision_radius(enemy)


## 爆炸／引爆點：由外緣接觸點往敵人中心插值，blend 越大越貼目標
static func explosion_center_at_hit(probe: Vector2, enemy: Node2D, cfg: Dictionary) -> Vector2:
	var surface: Vector2 = impact_point_at_probe(probe, enemy)
	if enemy == null or not is_instance_valid(enemy):
		return surface
	var blend: float = clampf(float(cfg.get("explosion_center_blend", 0.68)), 0.0, 1.0)
	return surface.lerp(enemy.global_position, blend)


static func create_projectile_sprite(cfg: Dictionary, tint: Color) -> AnimatedSprite2D:
	var sheet_path: String = String(cfg.get("sheet", DEFAULT_PROJECTILE_SHEET))
	if sheet_path == "" or not ResourceLoader.exists(sheet_path, "Texture2D"):
		return null
	var tex: Texture2D = load(sheet_path) as Texture2D
	if tex == null:
		return null
	var fw: int = int(cfg.get("frame_w", 64))
	var fh: int = int(cfg.get("frame_h", 64))
	var frame_count: int = maxi(1, int(cfg.get("frame_count", 4)))
	var fps: float = float(cfg.get("fps", 14.0))
	var hold_frame: int = clampi(int(cfg.get("hold_frame", frame_count - 1)), 0, frame_count - 1)

	var spr := AnimatedSprite2D.new()
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.sprite_frames = _sprite_frames_for(sheet_path, tex, fw, fh, frame_count, fps, &"fly")
	spr.modulate = Color(
		minf(1.2, tint.r * 1.08),
		minf(1.2, tint.g * 1.08),
		minf(1.2, tint.b * 1.08),
		1.0)
	spr.z_index = int(cfg.get("z_index", 56))
	spr.position = sprite_display_offset(cfg)
	spr.play(&"fly")
	spr.animation_finished.connect(
		func() -> void:
			if is_instance_valid(spr):
				spr.stop()
				spr.frame = hold_frame,
		CONNECT_ONE_SHOT)
	return spr


static func spawn_explosion(
		parent: Node,
		world_pos: Vector2,
		explode_radius: float,
		cfg: Dictionary) -> Node2D:
	if parent == null:
		return null
	var sheet_path: String = String(cfg.get("sheet", DEFAULT_EXPLOSION_SHEET))
	if sheet_path == "" or not ResourceLoader.exists(sheet_path, "Texture2D"):
		return null
	var tex: Texture2D = load(sheet_path) as Texture2D
	if tex == null:
		return null
	var fw: int = int(cfg.get("frame_w", 64))
	var fh: int = int(cfg.get("frame_h", 64))
	var frame_count: int = maxi(1, int(cfg.get("frame_count", 8)))
	var fps: float = float(cfg.get("fps", 16.0))
	var scale_mul: float = float(cfg.get("visual_scale_mult", 1.0))
	var scale_to_radius: bool = bool(cfg.get("scale_to_radius", true))
	var peak_r: float = maxf(
		8.0, float(cfg.get("visual_peak_radius", DEFAULT_VISUAL_PEAK_RADIUS)))
	var sc: float = (explode_radius / peak_r) * scale_mul if scale_to_radius else scale_mul

	var root := Node2D.new()
	root.global_position = world_pos
	root.z_index = int(cfg.get("z_index", 58))
	var spr := AnimatedSprite2D.new()
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.sprite_frames = _sprite_frames_for(sheet_path, tex, fw, fh, frame_count, fps, &"explode")
	spr.scale = Vector2.ONE * sc
	var raw_tint: Variant = cfg.get("tint", null)
	if raw_tint is Color:
		spr.modulate = raw_tint
	root.add_child(spr)
	parent.add_child(root)
	spr.play(&"explode")
	spr.animation_finished.connect(root.queue_free, CONNECT_ONE_SHOT)
	return root


static func _sprite_frames_for(
		sheet_path: String,
		tex: Texture2D,
		fw: int,
		fh: int,
		frame_count: int,
		fps: float,
		anim_name: StringName) -> SpriteFrames:
	var key: String = "%s|%s|%d|%d|%d" % [sheet_path, anim_name, fw, fh, frame_count]
	if _sprite_frames_cache.has(key):
		return _sprite_frames_cache[key]
	var sf := SpriteFrames.new()
	sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, fps)
	sf.set_animation_loop(anim_name, false)
	for i in frame_count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, fh)
		sf.add_frame(anim_name, at)
	_sprite_frames_cache[key] = sf
	return sf
