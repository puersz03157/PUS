extends Control
## 彈珠台背景預覽／鋪排：preview_grid > 0 為 3×3 循環預覽，0 僅供外部 Drawer 平鋪。

const PREVIEW_GRID := 3

var _pattern_id: String = GameData.PINBALL_BG_PATTERN_DEFAULT
var _preview_grid: int = 3
var _bg: ColorRect
var _grid: GridContainer
var _cells: Array[TextureRect] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_build_nodes()


func _build_nodes() -> void:
	if _grid != null:
		return
	_bg = ColorRect.new()
	_bg.color = GameData.PINBALL_BG_DEFAULT_COLOR
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_grid = GridContainer.new()
	_grid.columns = PREVIEW_GRID
	_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grid.add_theme_constant_override("h_separation", 0)
	_grid.add_theme_constant_override("v_separation", 0)
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid)

	for _i in PREVIEW_GRID * PREVIEW_GRID:
		var cell := TextureRect.new()
		cell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cell.stretch_mode = TextureRect.STRETCH_SCALE
		cell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid.add_child(cell)
		_cells.append(cell)


func setup(pattern_id: String, preview_grid: int = 3) -> void:
	_pattern_id = pattern_id
	_preview_grid = preview_grid
	if is_inside_tree():
		_apply_visual()
	else:
		call_deferred("_apply_visual")


func _apply_visual() -> void:
	_build_nodes()
	var tex: Texture2D = GameData.resolve_pinball_bg_texture(_pattern_id)
	var has_tex: bool = tex != null \
		and _pattern_id != GameData.PINBALL_BG_PATTERN_DEFAULT
	_bg.visible = true
	_bg.color = GameData.PINBALL_BG_DEFAULT_COLOR

	if _preview_grid <= 0:
		_grid.visible = false
		return

	_grid.visible = true
	for cell in _cells:
		cell.texture = tex if has_tex else null
		cell.visible = has_tex
