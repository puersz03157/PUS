extends Control
class_name HousePreviewAnim
## 房屋／造型設定：角色 IDLE 循環、武器 Sprite Sheet 動畫（元素箭混色輪播）

const WEAPON_MIX_CYCLE_SEC := 2.8

var _strip_sprite: Sprite2D
var _anim_sprite: AnimatedSprite2D
var _use_strip: bool = false
var _strip_hframes: int = 1
var _strip_row: int = 0
var _strip_frame_count: int = 1
var _strip_fps: float = 8.0
var _strip_time: float = 0.0
var _display_scale_mul: float = 1.0
var _display_feet_fine_y: float = 0.0
var _display_flip_h: bool = false
var _src_w: float = 32.0
var _src_h: float = 32.0

var _weapon_mix_rows: Array[int] = []
var _weapon_mix_index: int = 0
var _weapon_mix_timer: float = 0.0
var _layout_min_fill: float = 0.86
var _layout_center_dx: float = 0.0
var _layout_center_dy: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_strip_sprite = Sprite2D.new()
	_strip_sprite.centered = true
	_strip_sprite.visible = false
	_strip_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_strip_sprite)
	_anim_sprite = AnimatedSprite2D.new()
	_anim_sprite.centered = true
	_anim_sprite.visible = false
	_anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_anim_sprite)
	resized.connect(_on_resized)


func _process(delta: float) -> void:
	if _use_strip and _strip_sprite.visible and _strip_sprite.texture != null:
		_strip_time += delta
		var col: int = int(_strip_time * _strip_fps) % maxi(1, _strip_frame_count)
		_strip_sprite.frame = _strip_row * _strip_hframes + col
	elif _weapon_mix_rows.size() > 1 and _anim_sprite.visible:
		_weapon_mix_timer += delta
		if _weapon_mix_timer >= WEAPON_MIX_CYCLE_SEC:
			_weapon_mix_timer = 0.0
			_weapon_mix_index = (_weapon_mix_index + 1) % _weapon_mix_rows.size()
			_play_element_arrow_row(_weapon_mix_rows[_weapon_mix_index])


func clear_preview() -> void:
	_use_strip = false
	_weapon_mix_rows.clear()
	_weapon_mix_index = 0
	_weapon_mix_timer = 0.0
	_layout_min_fill = 0.86
	_layout_center_dx = 0.0
	_layout_center_dy = 0.0
	_strip_sprite.visible = false
	_anim_sprite.visible = false
	_strip_sprite.texture = null
	_anim_sprite.sprite_frames = null


func setup_character(cdef: Dictionary) -> void:
	setup_character_anim(cdef, "idle")


func setup_character_anim(cdef: Dictionary, anim_key: String) -> void:
	clear_preview()
	if cdef.is_empty() or anim_key == "":
		return
	_layout_min_fill = 0.88
	_apply_character_display_props(cdef)
	var tint: Color = cdef.get("tint", Color.WHITE)

	if cdef.has("sprite_frames") and cdef["sprite_frames"] is Dictionary:
		var sf_dict: Dictionary = cdef["sprite_frames"]
		if not sf_dict.has(anim_key):
			return
		var frames: Array = GameData.collect_preview_frame_textures(sf_dict.get(anim_key))
		if frames.is_empty():
			return
		var fps: float = _character_anim_fps(cdef, anim_key)
		var sf: SpriteFrames = GameData.build_looping_sprite_frames(frames, fps, &"idle")
		_show_anim_sprite(sf, &"idle", frames[0] as Texture2D, tint)
		return

	if cdef.has("sprite_strips") and cdef["sprite_strips"] is Dictionary:
		var strips: Dictionary = cdef["sprite_strips"]
		var strip_key: String = anim_key
		if anim_key == "idle":
			strip_key = String(cdef.get("preview_strip", "idle"))
			if not strips.has(strip_key):
				strip_key = "idle"
		if not strips.has(strip_key) or String(strips[strip_key]) == "":
			return
		var atlas: Texture2D = load(String(strips[strip_key])) as Texture2D
		if atlas == null:
			return
		_setup_character_strip(cdef, atlas, strip_key, tint)
		return

	if cdef.has("sprite") and String(cdef["sprite"]) != "":
		var sheet: Texture2D = GameData.resolve_frame_texture(String(cdef["sprite"]))
		if sheet == null:
			return
		var hf2: int = maxi(1, int(cdef.get("hframes", 1)))
		var vf2: int = maxi(1, int(cdef.get("vframes", 1)))
		var row: int = _character_sheet_row(cdef, anim_key, vf2)
		if row < 0:
			return
		_strip_row = row
		_strip_hframes = hf2
		_strip_frame_count = hf2
		_strip_fps = _character_anim_fps(cdef, anim_key)
		_strip_sprite.texture = sheet
		_strip_sprite.hframes = hf2
		_strip_sprite.vframes = vf2
		_strip_sprite.modulate = tint
		_strip_sprite.flip_h = _display_flip_h
		_use_strip = hf2 > 1
		_strip_time = 0.0
		_strip_sprite.frame = _strip_row * hf2
		_strip_sprite.visible = true
		var fw2: int = maxi(1, sheet.get_width() / hf2)
		var fh2: int = maxi(1, sheet.get_height() / vf2)
		_apply_trim_layout_from_cell(
			sheet, Rect2(0.0, float(_strip_row * fh2), float(fw2), float(fh2)))
		call_deferred("_schedule_layout")
		return

	if anim_key != "idle":
		return
	var static_tex: Texture2D = GameData.resolve_character_preview_source_texture(cdef)
	if static_tex != null:
		var trimmed: Dictionary = GameData.trim_preview_texture(static_tex)
		var tex: Texture2D = trimmed["texture"]
		if tex != null:
			_src_w = float(trimmed["w"])
			_src_h = float(trimmed["h"])
			_layout_center_dx = 0.0
			_layout_center_dy = 0.0
			_strip_sprite.texture = tex
			_strip_sprite.hframes = 1
			_strip_sprite.vframes = 1
			_strip_sprite.frame = 0
			_strip_sprite.modulate = tint
			_strip_sprite.flip_h = _display_flip_h
			_strip_sprite.visible = true
			call_deferred("_schedule_layout")


func _apply_character_display_props(cdef: Dictionary) -> void:
	_display_scale_mul = float(cdef.get("preview_scale", cdef.get("scale", 1.0)))
	_display_feet_fine_y = float(cdef.get("preview_feet_fine_y", 0.0))
	_display_flip_h = bool(cdef.get("sprite_faces_left", false))


func _character_anim_fps(cdef: Dictionary, anim_key: String) -> float:
	var strip_fps_map: Variant = cdef.get("strip_fps", {})
	if strip_fps_map is Dictionary and (strip_fps_map as Dictionary).has(anim_key):
		return float((strip_fps_map as Dictionary)[anim_key])
	return float(cdef.get("anim_fps", 8.0))


func _character_sheet_row(cdef: Dictionary, anim_key: String, vframes: int) -> int:
	match anim_key:
		"idle":
			return clampi(int(cdef.get("row_idle", 0)), 0, vframes - 1)
		"walk":
			if not cdef.has("row_walk") and vframes <= 1:
				return -1
			var walk_r: int = int(cdef.get("row_walk", 1))
			if walk_r >= vframes:
				return -1
			return clampi(walk_r, 0, vframes - 1)
		"attack":
			var atk_r: int = int(cdef.get("row_attack", 3))
			if atk_r >= vframes:
				return -1
			return clampi(atk_r, 0, vframes - 1)
		_:
			return -1


func _setup_character_strip(cdef: Dictionary, atlas: Texture2D, strip_key: String, tint: Color) -> void:
	_strip_hframes = maxi(1, int(cdef.get("strip_hframes", 8)))
	if cdef.has("strip_hframes_by_strip") and cdef["strip_hframes_by_strip"] is Dictionary \
			and (cdef["strip_hframes_by_strip"] as Dictionary).has(strip_key):
		_strip_hframes = maxi(1, int((cdef["strip_hframes_by_strip"] as Dictionary)[strip_key]))
	var vf: int = maxi(1, int(cdef.get("vframes", 1)))
	_strip_row = 0
	_strip_frame_count = _strip_hframes
	if cdef.has("strip_frames") and cdef["strip_frames"] is Dictionary \
			and (cdef["strip_frames"] as Dictionary).has(strip_key):
		_strip_frame_count = maxi(1, int((cdef["strip_frames"] as Dictionary)[strip_key]))
	_strip_fps = _character_anim_fps(cdef, strip_key)
	_strip_sprite.texture = atlas
	_strip_sprite.hframes = _strip_hframes
	_strip_sprite.vframes = vf
	_strip_sprite.modulate = tint
	_strip_sprite.flip_h = _display_flip_h
	_use_strip = _strip_frame_count > 1
	_strip_time = 0.0
	_strip_sprite.frame = _strip_row * _strip_hframes
	_strip_sprite.visible = true
	var fw: int = maxi(1, atlas.get_width() / _strip_hframes)
	var fh: int = maxi(1, atlas.get_height() / vf)
	_apply_trim_layout_from_cell(
		atlas, Rect2(0.0, float(_strip_row * fh), float(fw), float(fh)))
	call_deferred("_schedule_layout")


func setup_weapon(weapon_id: String, player_slot: String) -> void:
	if weapon_id == "":
		clear_preview()
		return
	var skin_id: String = GameState.get_weapon_visual_skin(player_slot, weapon_id)
	var preview: Dictionary = GameData.resolve_weapon_house_preview(weapon_id, skin_id)
	setup_preview(preview)


func setup_summon(summon_id: String, player_slot: String = "p1") -> void:
	if summon_id == "" or summon_id == "none":
		clear_preview()
		return
	var prog: Dictionary = GameState.get_summon_progress(player_slot, summon_id)
	var level: int = int(prog.get("level", GameData.SUMMON_MIN_LEVEL))
	_layout_min_fill = 0.0
	setup_preview(GameData.resolve_summon_house_preview(summon_id, level))


func setup_preview(preview: Dictionary) -> void:
	clear_preview()
	if preview.is_empty():
		return
	var kind: String = String(preview.get("kind", ""))
	match kind:
		"element_arrow_mix":
			_weapon_mix_rows = GameData.bow_element_arrow_preview_rows()
			if _weapon_mix_rows.is_empty():
				_weapon_mix_rows = [1]
			_weapon_mix_index = 0
			_weapon_mix_timer = 0.0
			_play_element_arrow_row(_weapon_mix_rows[0])
		"element_arrow":
			_play_element_arrow_row(int(preview.get("row", 1)))
		"static_tex":
			var tex: Texture2D = preview.get("texture")
			if tex != null:
				_display_scale_mul = float(preview.get("scale_mul", 1.65))
				_layout_min_fill = float(preview.get("min_fill", 0.86))
				var layout: Dictionary = GameData.compute_centered_sprite_trim_layout(tex)
				_src_w = float(layout.get("w", preview.get("w", 32.0)))
				_src_h = float(layout.get("h", preview.get("h", 32.0)))
				_layout_center_dx = float(layout.get("center_dx", 0.0))
				_layout_center_dy = float(layout.get("center_dy", 0.0))
				_strip_sprite.texture = tex
				_strip_sprite.hframes = 1
				_strip_sprite.vframes = 1
				_strip_sprite.frame = 0
				_strip_sprite.modulate = Color.WHITE
				_strip_sprite.visible = true
				call_deferred("_schedule_layout")
				return
		"sheet_anim":
			var cfg: Dictionary = preview.get("cfg", {})
			var anim: StringName = preview.get("anim", &"fly")
			_display_scale_mul = float(preview.get("scale_mul", 1.65))
			var sf: SpriteFrames = GameData.get_sheet_row_preview_sprite_frames(cfg, anim)
			if sf != null:
				_src_w = float(maxi(1, int(cfg.get("frame_w", 32))))
				_src_h = float(maxi(1, int(cfg.get("frame_h", 32))))
				_show_anim_sprite(sf, anim, null, Color.WHITE)
				return
		"icon":
			_show_weapon_icon(String(preview.get("weapon_id", "")))


func _show_weapon_icon(weapon_id: String) -> void:
	var icon_path: String = GameData.weapon_icon_path(weapon_id)
	if icon_path == "" or not ResourceLoader.exists(icon_path, "Texture2D"):
		return
	var icon_tex: Texture2D = load(icon_path) as Texture2D
	if icon_tex == null:
		return
	_display_scale_mul = 1.35
	_src_w = float(maxi(1, icon_tex.get_width()))
	_src_h = float(maxi(1, icon_tex.get_height()))
	_strip_sprite.texture = icon_tex
	_strip_sprite.hframes = 1
	_strip_sprite.vframes = 1
	_strip_sprite.frame = 0
	_strip_sprite.modulate = Color.WHITE
	_strip_sprite.visible = true
	call_deferred("_schedule_layout")


func _play_element_arrow_row(sheet_row: int) -> void:
	var sf: SpriteFrames = GameData.get_element_arrow_preview_sprite_frames(sheet_row)
	if sf == null:
		return
	_display_scale_mul = 2.2
	_src_w = float(GameData.ELEMENT_ARROW_FRAME_W)
	_src_h = float(GameData.ELEMENT_ARROW_FRAME_H)
	_show_anim_sprite(sf, &"fly", null, Color.WHITE)


func _show_anim_sprite(sf: SpriteFrames, anim: StringName, ref_tex: Texture2D, tint: Color) -> void:
	_use_strip = false
	_anim_sprite.sprite_frames = sf
	_anim_sprite.modulate = tint
	_anim_sprite.flip_h = _display_flip_h
	_anim_sprite.visible = true
	_anim_sprite.play(anim)
	if ref_tex != null:
		_apply_trim_layout_from_texture(ref_tex)
	call_deferred("_schedule_layout")


func _apply_trim_layout_from_texture(tex: Texture2D) -> void:
	var layout: Dictionary = GameData.compute_centered_sprite_trim_layout(tex)
	_src_w = float(layout["w"])
	_src_h = float(layout["h"])
	_layout_center_dx = float(layout["center_dx"])
	_layout_center_dy = float(layout["center_dy"])


func _apply_trim_layout_from_cell(tex: Texture2D, cell: Rect2) -> void:
	var layout: Dictionary = GameData.compute_centered_sprite_trim_layout_rect(tex, cell)
	_src_w = float(layout["w"])
	_src_h = float(layout["h"])
	_layout_center_dx = float(layout["center_dx"])
	_layout_center_dy = float(layout["center_dy"])


func _schedule_layout() -> void:
	call_deferred("_on_resized")


func _on_resized() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		call_deferred("_schedule_layout")
		return
	var node: Node2D = _active_sprite()
	if node == null:
		return
	GameData.layout_house_preview_sprite2d(
		node, self, _src_w, _src_h, _display_scale_mul, _display_feet_fine_y,
		_layout_min_fill, _layout_center_dx, _layout_center_dy)


func _active_sprite() -> Node2D:
	if _anim_sprite.visible:
		return _anim_sprite
	if _strip_sprite.visible:
		return _strip_sprite
	return null
