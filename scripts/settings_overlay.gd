extends CanvasLayer
## 全域設定覆蓋層（autoload）：
## - 永遠在右上角顯示一顆齒輪按鈕
## - 點擊後彈出設定面板（背景變暗、SceneTree 暫停）
## - 目前設定項：觸控操作（為手機 / 網頁版預留）

const PANEL_W := 480.0
const PANEL_H := 320.0
const GEAR_TEXT := "⚙"
const Z_LAYER := 100

var _open: bool = false
var _was_paused: bool = false

var gear_button: Button
var dim: ColorRect
var panel: Panel
var title_label: Label
var touch_check: CheckButton
var touch_label: Label
var touch_hint: Label
var close_button: Button


func _ready() -> void:
	layer = Z_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_apply_layout()
	_set_open(false)
	_refresh_from_state()
	# 解析度 / 視窗尺寸改變時，重新對齊齒輪與面板位置。
	get_viewport().size_changed.connect(_apply_layout)


func _build_ui() -> void:
	# 右上角齒輪按鈕
	gear_button = Button.new()
	gear_button.text = GEAR_TEXT
	gear_button.custom_minimum_size = Vector2(44, 44)
	gear_button.add_theme_font_size_override("font_size", 22)
	gear_button.add_theme_color_override("font_color", Color(1, 0.92, 0.55))
	gear_button.process_mode = Node.PROCESS_MODE_ALWAYS
	gear_button.focus_mode = Control.FOCUS_NONE
	gear_button.pressed.connect(_toggle)
	# 半透明背景，避免在亮色畫面上看不清楚
	var gear_sb := StyleBoxFlat.new()
	gear_sb.bg_color = Color(0.05, 0.07, 0.15, 0.7)
	gear_sb.border_color = Color(0.95, 0.65, 0.18, 0.9)
	gear_sb.border_width_left = 2
	gear_sb.border_width_right = 2
	gear_sb.border_width_top = 2
	gear_sb.border_width_bottom = 2
	gear_sb.corner_radius_top_left = 22
	gear_sb.corner_radius_top_right = 22
	gear_sb.corner_radius_bottom_left = 22
	gear_sb.corner_radius_bottom_right = 22
	gear_button.add_theme_stylebox_override("normal", gear_sb)
	gear_button.add_theme_stylebox_override("hover", gear_sb)
	gear_button.add_theme_stylebox_override("pressed", gear_sb)
	gear_button.add_theme_stylebox_override("focus", gear_sb)
	add_child(gear_button)

	# 暗化背景
	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	# 設定面板
	panel = Panel.new()
	panel.size = Vector2(PANEL_W, PANEL_H)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.18, 1.0)
	sb.border_color = Color(0.95, 0.65, 0.18)
	sb.border_width_left = 4
	sb.border_width_right = 4
	sb.border_width_top = 4
	sb.border_width_bottom = 4
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	# 標題
	title_label = Label.new()
	title_label.text = tr("SETTINGS_TITLE")
	title_label.position = Vector2(0, 18)
	title_label.size = Vector2(PANEL_W, 36)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	panel.add_child(title_label)

	# 觸控操作 一行：左 Label + 右 CheckButton
	var row := HBoxContainer.new()
	row.position = Vector2(28, 90)
	row.size = Vector2(PANEL_W - 56, 40)
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	touch_label = Label.new()
	touch_label.text = tr("SETTINGS_TOUCH_CONTROLS")
	touch_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	touch_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	touch_label.add_theme_font_size_override("font_size", 18)
	touch_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1))
	row.add_child(touch_label)

	touch_check = CheckButton.new()
	touch_check.process_mode = Node.PROCESS_MODE_ALWAYS
	touch_check.toggled.connect(_on_touch_toggled)
	row.add_child(touch_check)

	# 說明文字
	touch_hint = Label.new()
	touch_hint.text = tr("SETTINGS_TOUCH_HINT")
	touch_hint.position = Vector2(28, 140)
	touch_hint.size = Vector2(PANEL_W - 56, 90)
	touch_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	touch_hint.add_theme_font_size_override("font_size", 13)
	touch_hint.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	panel.add_child(touch_hint)

	# 關閉按鈕
	close_button = Button.new()
	close_button.text = tr("SETTINGS_CLOSE")
	close_button.size = Vector2(180, 44)
	close_button.position = Vector2((PANEL_W - 180) * 0.5, PANEL_H - 60)
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.pressed.connect(_close)
	panel.add_child(close_button)


func _apply_layout() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	gear_button.position = Vector2(vp.x - gear_button.custom_minimum_size.x - 12, 12)
	gear_button.size = gear_button.custom_minimum_size
	dim.size = vp
	panel.position = Vector2((vp.x - PANEL_W) * 0.5, (vp.y - PANEL_H) * 0.5)


func _refresh_from_state() -> void:
	if is_instance_valid(GameState):
		touch_check.set_pressed_no_signal(bool(GameState.touch_controls_enabled))
	# 場景切換後再翻一次（語系若中途改變也會反映）
	title_label.text = tr("SETTINGS_TITLE")
	touch_label.text = tr("SETTINGS_TOUCH_CONTROLS")
	touch_hint.text = tr("SETTINGS_TOUCH_HINT")
	close_button.text = tr("SETTINGS_CLOSE")


func _toggle() -> void:
	_set_open(not _open)


func _close() -> void:
	_set_open(false)


func _set_open(v: bool) -> void:
	_open = v
	dim.visible = v
	panel.visible = v
	if v:
		_refresh_from_state()
		_was_paused = get_tree().paused
		get_tree().paused = true
		close_button.grab_focus()
	else:
		# 還原原本的暫停狀態（避免和 PauseMenu / Pinball 互踩）
		get_tree().paused = _was_paused


func _on_touch_toggled(pressed: bool) -> void:
	if is_instance_valid(GameState):
		GameState.set_touch_controls_enabled(pressed)
