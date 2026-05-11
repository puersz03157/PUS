extends CanvasLayer
## 戰鬥場景的觸控 HUD：
## - 左側「浮動虛擬搖桿」：手指 / 滑鼠在空白區域按下處出現底盤 + 旋鈕，拖動轉換成 p1_left/right/up/down 強度
## - 右下角「技能按鈕」：沿用 SkillIcon 視覺，按下時觸發 p1_skill
## - 左上「暫停按鈕」：呼叫 ui_back，由 PauseMenu 自行 toggle
##
## 動作以 Input.action_press / action_release 注入既有的 InputMap，玩家邏輯不需修改。
## 與 GameState.touch_controls_enabled 連動，可隨時在右上角設定面板開關。

const SKILL_ICON_SCRIPT := preload("res://scripts/skill_icon.gd")

const JOY_BASE_RADIUS := 90.0
const JOY_KNOB_RADIUS := 36.0
const ACTION_THRESHOLD := 0.18

const SKILL_DIM := 110.0
const SKILL_PADDING := 24.0
const PAUSE_BTN_SIZE := 56.0


# --- 浮動搖桿視覺：透明 Control，自繪一個圓形底盤 + 旋鈕 ---
class JoystickVisual extends Control:
	var base_pos: Vector2 = Vector2.ZERO
	var knob_pos: Vector2 = Vector2.ZERO
	var base_r: float = 90.0
	var knob_r: float = 36.0
	var on: bool = false

	func _draw() -> void:
		if not on:
			return
		draw_circle(base_pos, base_r, Color(0, 0, 0, 0.32))
		draw_arc(base_pos, base_r, 0, TAU, 64, Color(1, 1, 1, 0.55), 3.0, true)
		draw_circle(knob_pos, knob_r, Color(1, 1, 1, 0.55))
		draw_arc(knob_pos, knob_r, 0, TAU, 32, Color(1, 1, 1, 0.92), 2.0, true)


var player: Node = null

var joy_visual: JoystickVisual = null
var skill_widget: Panel = null
var skill_button: Button = null
var pause_button: Button = null

var _joy_active: bool = false
var _joy_touch_idx: int = -1
var _joy_origin: Vector2 = Vector2.ZERO
var _joy_vec: Vector2 = Vector2.ZERO

# action_name -> 目前注入的強度（>0 表示 currently 按住）
var _action_pressed: Dictionary = {}

var _last_touch_enabled: bool = false
var _last_paused: bool = false


func setup(p1: Node) -> void:
	player = p1
	if skill_widget:
		skill_widget.setup(p1, "P1", "")


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_apply_layout()
	_refresh_visibility()
	get_viewport().size_changed.connect(_apply_layout)


func _exit_tree() -> void:
	_release_all_actions()


func _process(_delta: float) -> void:
	var on: bool = bool(GameState.touch_controls_enabled)
	if on != _last_touch_enabled:
		_refresh_visibility()
		return
	# 樹被暫停時（彈珠台 / 暫停選單 / 設定面板）整批隱藏，
	# 避免和那些情境自帶的按鈕互踩，也不會讓搖桿在停格時還亮著。
	if on:
		var paused: bool = get_tree().paused if is_inside_tree() else false
		if paused != _last_paused:
			_last_paused = paused
			_apply_paused_visibility(paused)


func _apply_paused_visibility(paused: bool) -> void:
	if joy_visual:
		joy_visual.visible = not paused
		if paused:
			_end_joystick()
	if skill_widget:
		skill_widget.visible = not paused
	if skill_button:
		skill_button.visible = not paused
	if pause_button:
		pause_button.visible = not paused


# ============================================================================
# UI
# ============================================================================
func _build_ui() -> void:
	joy_visual = JoystickVisual.new()
	joy_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_visual.set_anchors_preset(Control.PRESET_FULL_RECT)
	joy_visual.base_r = JOY_BASE_RADIUS
	joy_visual.knob_r = JOY_KNOB_RADIUS
	add_child(joy_visual)

	# 技能視覺：沿用既有的 SkillIcon widget，純展示
	# show_meter 關掉 — 觸控大圖示上不再疊被動充能數字（會看起來像是壞掉的累積數字）。
	# 玩家若想看 skill_meter，左上 HUD 的小圖示仍保留顯示。
	skill_widget = SKILL_ICON_SCRIPT.new()
	skill_widget.icon_dim = SKILL_DIM
	skill_widget.show_header = false
	skill_widget.show_name = false
	skill_widget.show_key = false
	skill_widget.show_meter = false
	skill_widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(skill_widget)

	# 透明的覆蓋按鈕，蓋在 SkillIcon 上接收觸控
	skill_button = _make_invisible_button()
	skill_button.button_down.connect(_on_skill_down)
	skill_button.button_up.connect(_on_skill_up)
	add_child(skill_button)

	# 暫停按鈕（左上角；觸發 ui_back 由 PauseMenu 自行開合）
	pause_button = Button.new()
	pause_button.text = "❚❚"
	pause_button.add_theme_font_size_override("font_size", 22)
	pause_button.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
	var pause_sb := StyleBoxFlat.new()
	pause_sb.bg_color = Color(0.05, 0.07, 0.15, 0.78)
	pause_sb.border_color = Color(0.95, 0.65, 0.18, 0.9)
	pause_sb.border_width_left = 2
	pause_sb.border_width_right = 2
	pause_sb.border_width_top = 2
	pause_sb.border_width_bottom = 2
	pause_sb.corner_radius_top_left = 12
	pause_sb.corner_radius_top_right = 12
	pause_sb.corner_radius_bottom_left = 12
	pause_sb.corner_radius_bottom_right = 12
	pause_button.add_theme_stylebox_override("normal", pause_sb)
	pause_button.add_theme_stylebox_override("hover", pause_sb)
	pause_button.add_theme_stylebox_override("pressed", pause_sb)
	pause_button.add_theme_stylebox_override("focus", pause_sb)
	pause_button.pressed.connect(_on_pause_pressed)
	add_child(pause_button)


func _make_invisible_button() -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	var transp := StyleBoxFlat.new()
	transp.bg_color = Color(1, 1, 1, 0)
	b.add_theme_stylebox_override("normal", transp)
	b.add_theme_stylebox_override("hover", transp)
	b.add_theme_stylebox_override("pressed", transp)
	b.add_theme_stylebox_override("focus", transp)
	return b


func _apply_layout() -> void:
	if joy_visual == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	joy_visual.size = vp

	# 技能 widget 包含 padding，size 約為 icon_dim + 16
	var sw: Vector2 = skill_widget.size
	if sw.x < 8:
		sw = Vector2(SKILL_DIM + 16.0, SKILL_DIM + 8.0)
	skill_widget.position = Vector2(vp.x - sw.x - SKILL_PADDING, vp.y - sw.y - SKILL_PADDING)

	skill_button.size = sw
	skill_button.position = skill_widget.position

	# 暫停按鈕：左上、避開 P1Panel 上方資訊（HUD P1Panel 約 100 高）
	pause_button.size = Vector2(PAUSE_BTN_SIZE, PAUSE_BTN_SIZE)
	pause_button.position = Vector2(16, 116)


func _refresh_visibility() -> void:
	var on: bool = bool(GameState.touch_controls_enabled)
	_last_touch_enabled = on
	var paused: bool = get_tree().paused if is_inside_tree() else false
	_last_paused = paused
	var should_show: bool = on and not paused
	if joy_visual:
		joy_visual.visible = should_show
		if not should_show:
			joy_visual.on = false
			joy_visual.queue_redraw()
	if skill_widget:
		skill_widget.visible = should_show
	if skill_button:
		skill_button.visible = should_show
	if pause_button:
		pause_button.visible = should_show
	if not on:
		_end_joystick()
		_release_all_actions()


# ============================================================================
# 浮動搖桿輸入
# ============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if not bool(GameState.touch_controls_enabled):
		return
	# 觸控
	if event is InputEventScreenTouch:
		var tev := event as InputEventScreenTouch
		if tev.pressed:
			if not _joy_active and _is_on_joystick_zone(tev.position):
				_begin_joystick(tev.index, tev.position)
		else:
			if _joy_active and tev.index == _joy_touch_idx:
				_end_joystick()
		return
	if event is InputEventScreenDrag:
		var dev := event as InputEventScreenDrag
		if _joy_active and dev.index == _joy_touch_idx:
			_drag_joystick(dev.position)
		return
	# 桌機 / 滑鼠（用於開發測試）：左鍵作為單點觸控
	if event is InputEventMouseButton:
		var mev := event as InputEventMouseButton
		if mev.button_index == MOUSE_BUTTON_LEFT:
			if mev.pressed:
				if not _joy_active and _is_on_joystick_zone(mev.position):
					_begin_joystick(-100, mev.position)
			else:
				if _joy_active and _joy_touch_idx == -100:
					_end_joystick()
		return
	if event is InputEventMouseMotion:
		if _joy_active and _joy_touch_idx == -100:
			_drag_joystick((event as InputEventMouseMotion).position)


func _is_on_joystick_zone(pos: Vector2) -> bool:
	# 不能落在按鈕區域
	if pause_button and Rect2(pause_button.position, pause_button.size).has_point(pos):
		return false
	if skill_button and Rect2(skill_button.position, skill_button.size).has_point(pos):
		return false
	# 也避開右上角的設定齒輪（SettingsOverlay 內部處理；這裡保守地讓出 60x60 角落）
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var gear_rect := Rect2(vp.x - 64, 0, 64, 64)
	if gear_rect.has_point(pos):
		return false
	return true


func _begin_joystick(idx: int, pos: Vector2) -> void:
	_joy_active = true
	_joy_touch_idx = idx
	_joy_origin = pos
	_joy_vec = Vector2.ZERO
	joy_visual.base_pos = pos
	joy_visual.knob_pos = pos
	joy_visual.on = true
	joy_visual.queue_redraw()


func _drag_joystick(pos: Vector2) -> void:
	var diff: Vector2 = pos - _joy_origin
	var clamped: Vector2 = diff
	var dist: float = clamped.length()
	if dist > JOY_BASE_RADIUS:
		clamped = clamped / dist * JOY_BASE_RADIUS
	joy_visual.knob_pos = _joy_origin + clamped
	joy_visual.queue_redraw()
	_joy_vec = clamped / JOY_BASE_RADIUS
	_set_joy_actions(_joy_vec)


func _end_joystick() -> void:
	if not _joy_active:
		return
	_joy_active = false
	_joy_touch_idx = -1
	if joy_visual:
		joy_visual.on = false
		joy_visual.queue_redraw()
	_joy_vec = Vector2.ZERO
	_set_joy_actions(Vector2.ZERO)


# ============================================================================
# 動作注入
# ============================================================================
func _set_joy_actions(v: Vector2) -> void:
	_set_action_strength("p1_right", v.x if v.x > ACTION_THRESHOLD else 0.0)
	_set_action_strength("p1_left", -v.x if v.x < -ACTION_THRESHOLD else 0.0)
	_set_action_strength("p1_down", v.y if v.y > ACTION_THRESHOLD else 0.0)
	_set_action_strength("p1_up", -v.y if v.y < -ACTION_THRESHOLD else 0.0)


func _set_action_strength(action: String, strength: float) -> void:
	var cur: float = float(_action_pressed.get(action, 0.0))
	if strength > 0.001:
		# 變更才送 event；同強度連續送會觸發多次 just_pressed
		if cur <= 0.001 or absf(cur - strength) > 0.05:
			Input.action_press(action, clamp(strength, 0.0, 1.0))
			_action_pressed[action] = strength
	else:
		if cur > 0.001:
			Input.action_release(action)
			_action_pressed[action] = 0.0


func _release_all_actions() -> void:
	for a in _action_pressed.keys():
		if float(_action_pressed[a]) > 0.001:
			Input.action_release(a)
		_action_pressed[a] = 0.0


# ============================================================================
# 技能 / 暫停按鈕
# ============================================================================
func _on_skill_down() -> void:
	Input.action_press("p1_skill")
	_action_pressed["p1_skill"] = 1.0


func _on_skill_up() -> void:
	if float(_action_pressed.get("p1_skill", 0.0)) > 0.001:
		Input.action_release("p1_skill")
		_action_pressed["p1_skill"] = 0.0


func _on_pause_pressed() -> void:
	Input.action_press("ui_back")
	await get_tree().process_frame
	Input.action_release("ui_back")
