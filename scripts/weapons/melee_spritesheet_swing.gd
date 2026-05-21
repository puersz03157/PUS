extends Node2D
class_name MeleeSpritesheetSwing
## 近戰 spritesheet 攻擊特效：播完指定幀時以三角形範圍判定命中（每段揮擊每敵只傷一次）。

const DEFAULT_ART_DIR := Vector2(1.0, -1.0)  # 美術預設戳刺方向：右上（+X、-Y）

static var _sprite_frames_cache: Dictionary = {}

var _weapon: Node = null
var _dir: Vector2 = Vector2.RIGHT
var _hit_origin: Vector2 = Vector2.ZERO
var _reach: float = 100.0
var _thrust_length: float = 100.0
var _base_half_width: float = 42.0
var _hit_frames: Array[int] = []
var _hit_enemies: Dictionary = {}
var _sprite: AnimatedSprite2D = null
var _debug_nodes: Array[Node] = []


static func play(
		parent_scene: Node,
		weapon: Node,
		origin: Vector2,
		dir: Vector2,
		reach: float,
		base_range: float,
		effect_cfg: Dictionary) -> bool:
	if parent_scene == null or weapon == null or dir == Vector2.ZERO:
		return false
	var sheet_path: String = String(effect_cfg.get("sheet", ""))
	if sheet_path == "" or not ResourceLoader.exists(sheet_path, "Texture2D"):
		return false
	var swing := MeleeSpritesheetSwing.new()
	swing._weapon = weapon
	swing._dir = dir.normalized()
	swing._hit_origin = origin
	swing._reach = reach
	var scale_mul: float = reach / maxf(1.0, base_range)
	var base_half: float = float(effect_cfg.get("tip_half_width", 42.0))
	swing._base_half_width = base_half * scale_mul
	swing._thrust_length = reach
	swing.global_position = origin
	var raw_frames: Variant = effect_cfg.get("hit_frames", [3, 4])
	swing._hit_frames.clear()
	if raw_frames is Array:
		for f in raw_frames:
			swing._hit_frames.append(int(f))
	if swing._hit_frames.is_empty():
		swing._hit_frames = [3, 4]
	var fw: int = int(effect_cfg.get("frame_w", 64))
	var fh: int = int(effect_cfg.get("frame_h", 64))
	var frame_count: int = int(effect_cfg.get("frame_count", 8))
	var fps: float = float(effect_cfg.get("fps", 14.0))
	var art_dir: Vector2 = DEFAULT_ART_DIR
	var raw_art: Variant = effect_cfg.get("art_dir", DEFAULT_ART_DIR)
	if raw_art is Vector2:
		art_dir = raw_art
	elif raw_art is Array and raw_art.size() >= 2:
		art_dir = Vector2(float(raw_art[0]), float(raw_art[1]))
	if art_dir.length_squared() < 0.0001:
		art_dir = DEFAULT_ART_DIR
	else:
		art_dir = art_dir.normalized()
	var tex: Texture2D = load(sheet_path) as Texture2D
	if tex == null:
		return false
	var pivot_local: Vector2 = _frame_norm_point(effect_cfg.get("art_pivot", [-0.5, 0.5]), fw, fh)
	var tip_local: Vector2 = _frame_norm_point(effect_cfg.get("art_tip", [0.5, -0.5]), fw, fh)
	var default_extent: float = maxf(8.0, pivot_local.distance_to(tip_local))
	swing._sprite = AnimatedSprite2D.new()
	swing._sprite.centered = true
	swing._sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	swing._sprite.sprite_frames = _sprite_frames_for(sheet_path, tex, fw, fh, frame_count, fps)
	var visual_mul: float = float(effect_cfg.get("visual_scale_mult", 1.0))
	var sprite_scale: float = scale_mul * visual_mul
	if bool(effect_cfg.get("fit_visual_to_reach", false)):
		var art_extent: float = maxf(8.0, float(effect_cfg.get("art_extent", default_extent)))
		sprite_scale = (swing._thrust_length / art_extent) * visual_mul
	var rot: float = swing._dir.angle() - art_dir.angle()
	swing._sprite.scale = Vector2.ONE * sprite_scale
	swing._sprite.rotation = rot
	swing._sprite.position = -(pivot_local * sprite_scale).rotated(rot)
	swing._sprite.z_index = int(effect_cfg.get("z_index", 8))
	swing.add_child(swing._sprite)
	if bool(effect_cfg.get("show_hit_debug", false)):
		swing._spawn_hit_debug(effect_cfg)
	swing._sprite.animation_finished.connect(swing._on_animation_finished)
	swing._sprite.frame_changed.connect(swing._on_frame_changed)
	parent_scene.add_child(swing)
	swing._sprite.play("attack")
	return true


func _spawn_hit_debug(cfg: Dictionary) -> void:
	var verts: Array = _triangle_local_verts()
	var tip: Vector2 = verts[0]
	var base_l: Vector2 = verts[1]
	var base_r: Vector2 = verts[2]
	var dbg_color: Color = Color(1.0, 0.25, 0.35, 0.38)
	var raw_col: Variant = cfg.get("hit_debug_color", null)
	if raw_col is Color:
		dbg_color = raw_col
	var fill := Polygon2D.new()
	fill.polygon = PackedVector2Array([tip, base_l, base_r])
	fill.color = dbg_color
	fill.z_index = int(cfg.get("z_index", 8)) - 1
	add_child(fill)
	_debug_nodes.append(fill)
	var outline := Line2D.new()
	outline.points = PackedVector2Array([tip, base_l, base_r, tip])
	outline.default_color = Color(dbg_color.r, dbg_color.g, dbg_color.b, 0.92)
	outline.width = 2.0
	outline.z_index = fill.z_index + 1
	add_child(outline)
	_debug_nodes.append(outline)
	var tip_mark := _make_debug_dot(tip, Color(1.0, 0.9, 0.2, 0.95))
	var base_mark := _make_debug_dot(Vector2.ZERO, Color(0.35, 1.0, 0.5, 0.95))
	add_child(tip_mark)
	add_child(base_mark)
	_debug_nodes.append(tip_mark)
	_debug_nodes.append(base_mark)


func _make_debug_dot(local_pos: Vector2, col: Color) -> Node2D:
	var n := Node2D.new()
	n.position = local_pos
	n.z_index = 20
	var d := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 8:
		var a: float = TAU * float(i) / 8.0
		pts.append(Vector2(cos(a), sin(a)) * 5.0)
	d.polygon = pts
	d.color = col
	n.add_child(d)
	return n


static func _frame_norm_point(raw: Variant, fw: int, fh: int) -> Vector2:
	var n := Vector2.ZERO
	if raw is Vector2:
		n = raw
	elif raw is Array and raw.size() >= 2:
		n = Vector2(float(raw[0]), float(raw[1]))
	return Vector2(n.x * float(fw), n.y * float(fh))


static func _sprite_frames_for(
		sheet_path: String,
		tex: Texture2D,
		fw: int,
		fh: int,
		frame_count: int,
		fps: float) -> SpriteFrames:
	var key: String = "%s|%d|%d|%d" % [sheet_path, fw, fh, frame_count]
	if _sprite_frames_cache.has(key):
		return _sprite_frames_cache[key]
	var sf := SpriteFrames.new()
	sf.add_animation(&"attack")
	sf.set_animation_speed(&"attack", fps)
	sf.set_animation_loop(&"attack", false)
	for i in frame_count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, fh)
		sf.add_frame(&"attack", at)
	_sprite_frames_cache[key] = sf
	return sf


func _on_frame_changed() -> void:
	if _sprite == null:
		return
	if _sprite.frame in _hit_frames:
		_apply_triangle_hit()


func _on_animation_finished() -> void:
	if _debug_nodes.is_empty():
		queue_free()
		return
	var tw := create_tween()
	tw.set_parallel(true)
	for n in _debug_nodes:
		if is_instance_valid(n):
			tw.tween_property(n, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(queue_free)


func _apply_triangle_hit() -> void:
	if _weapon == null or not is_instance_valid(_weapon):
		return
	var owner_player: Node = _weapon.owner_player
	if owner_player == null:
		return
	var tip: Vector2 = _hit_origin + _dir * _reach
	var base_c: Vector2 = global_position
	var perp: Vector2 = Vector2(-_dir.y, _dir.x)
	var half_w: float = _base_half_width
	var base_l: Vector2 = base_c + perp * half_w
	var base_r: Vector2 = base_c - perp * half_w
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if _hit_enemies.has(e.get_instance_id()):
			continue
		if e.get("hp") != null and float(e.hp) <= 0.0:
			continue
		var p: Vector2 = e.global_position
		if not _point_in_triangle(p, tip, base_l, base_r):
			continue
		_hit_enemies[e.get_instance_id()] = true
		if _weapon.has_method("damage_enemy"):
			_weapon.damage_enemy(e)


func _triangle_local_verts() -> Array:
	var perp: Vector2 = Vector2(-_dir.y, _dir.x)
	var half_w: float = _base_half_width
	var tip: Vector2 = _dir * _thrust_length
	var base_l: Vector2 = perp * half_w
	var base_r: Vector2 = -perp * half_w
	return [tip, base_l, base_r]


static func _point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1: float = _tri_sign(p, a, b)
	var d2: float = _tri_sign(p, b, c)
	var d3: float = _tri_sign(p, c, a)
	var has_neg: bool = (d1 < 0.0) or (d2 < 0.0) or (d3 < 0.0)
	var has_pos: bool = (d1 > 0.0) or (d2 > 0.0) or (d3 > 0.0)
	return not (has_neg and has_pos)


static func _tri_sign(p1: Vector2, p2: Vector2, p3: Vector2) -> float:
	return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)
