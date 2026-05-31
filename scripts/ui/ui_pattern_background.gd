extends Control
## PatternMix 平鋪背景（TextureRect 網格；PROCESS_MODE_ALWAYS 以在暫停對話中仍會更新）。

var _pattern_id: String = GameData.PINBALL_BG_PATTERN_DEFAULT
var _style: int = GameData.UI_PATTERN_STYLE_FULL
var _context: String = GameData.UI_BG_CTX_PANEL

var _base: ColorRect
var _grid: GridContainer
var _overlay: ColorRect
var _cells: Array[TextureRect] = []
var _built: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_build_nodes()


func _enter_tree() -> void:
	var parent_ctrl := get_parent() as Control
	if parent_ctrl != null and not parent_ctrl.resized.is_connected(_on_parent_resized):
		parent_ctrl.resized.connect(_on_parent_resized)
	call_deferred("sync_to_parent_size")


func _on_parent_resized() -> void:
	sync_to_parent_size()


func fit_viewport() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	sync_to_size(vp)


func setup(style: int, context: String, pattern_id: String = "") -> void:
	_style = style
	_context = context
	if pattern_id != "":
		_pattern_id = pattern_id
	else:
		_pattern_id = GameState.get_ui_bg_pattern(context)
	_sync_visual()


func refresh_pattern() -> void:
	setup(_style, _context, GameState.get_ui_bg_pattern(_context))


func sync_to_size(target_size: Vector2) -> void:
	if target_size.x <= 1.0 or target_size.y <= 1.0:
		return
	_apply_fill_rect()
	var parent_ctrl := get_parent() as Control
	if parent_ctrl != null and (parent_ctrl.size.x <= 1.0 or parent_ctrl.size.y <= 1.0):
		size = target_size
	_sync_visual()


func sync_to_parent_size() -> void:
	var parent_ctrl := get_parent() as Control
	if parent_ctrl == null:
		return
	var target := parent_ctrl.size
	if target.x <= 1.0 or target.y <= 1.0:
		if parent_ctrl.custom_minimum_size.x > 1.0:
			target = parent_ctrl.custom_minimum_size
	if target.x <= 1.0:
		return
	_apply_fill_rect()
	if parent_ctrl.size.x <= 1.0:
		size = target
	_sync_visual()


func _apply_fill_rect() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_sync_visual")


func _build_nodes() -> void:
	if _built:
		return
	_built = true
	_base = ColorRect.new()
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_base)

	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 0)
	_grid.add_theme_constant_override("v_separation", 0)
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid)

	_overlay = ColorRect.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


func _layout_children(area: Vector2) -> void:
	for node in [_base, _grid, _overlay]:
		node.set_anchors_preset(Control.PRESET_TOP_LEFT)
		node.position = Vector2.ZERO
		node.size = area


func _effective_size() -> Vector2:
	if size.x > 1.0 and size.y > 1.0:
		return size
	var rect := get_rect()
	if rect.size.x > 1.0 and rect.size.y > 1.0:
		return rect.size
	var parent_ctrl := get_parent() as Control
	if parent_ctrl != null:
		if parent_ctrl.size.x > 1.0 and parent_ctrl.size.y > 1.0:
			return parent_ctrl.size
		if parent_ctrl.custom_minimum_size.x > 1.0 and parent_ctrl.custom_minimum_size.y > 1.0:
			return parent_ctrl.custom_minimum_size
	return Vector2.ZERO


func _overlay_color() -> Color:
	if _context == GameData.UI_BG_CTX_PINBALL:
		return Color(0, 0, 0, 0)
	return GameData.ui_pattern_overlay_for_style(_style)


func _sync_visual() -> void:
	_build_nodes()
	var area: Vector2 = _effective_size()
	_layout_children(area)
	_base.color = GameData.PINBALL_BG_DEFAULT_COLOR
	_overlay.color = _overlay_color()
	_overlay.visible = _overlay.color.a > 0.01

	if area.x <= 1.0 or area.y <= 1.0:
		_grid.visible = false
		return

	var effective_id: String = GameData.ui_pattern_effective_id(_pattern_id, _context)
	if effective_id == GameData.PINBALL_BG_PATTERN_DEFAULT:
		_grid.visible = false
		return

	var tex: Texture2D = GameData.resolve_pinball_bg_texture(effective_id)
	if tex == null:
		_grid.visible = false
		return

	var tile_size: Vector2 = tex.get_size()
	if tile_size.x <= 0.0 or tile_size.y <= 0.0:
		_grid.visible = false
		return

	var cols: int = maxi(1, int(ceil(area.x / tile_size.x)))
	var rows: int = maxi(1, int(ceil(area.y / tile_size.y)))
	var needed: int = cols * rows

	while _cells.size() < needed:
		var cell := TextureRect.new()
		cell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cell.stretch_mode = TextureRect.STRETCH_SCALE
		cell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cell.custom_minimum_size = tile_size
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid.add_child(cell)
		_cells.append(cell)

	while _cells.size() > needed:
		var extra: TextureRect = _cells.pop_back()
		if is_instance_valid(extra):
			extra.queue_free()

	_grid.columns = cols
	_grid.visible = true
	for cell in _cells:
		cell.texture = tex
		cell.custom_minimum_size = tile_size
