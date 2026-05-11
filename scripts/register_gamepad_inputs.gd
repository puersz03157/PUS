extends Node
## 在啟動時為 P1（手把 0）、P2（手把 1）註冊 Xbox / PlayStation 相容的按鍵與左類比搖桿。
## 不重複加入相同事件（可安全多次載入）。

var _did_register: bool = false


func _ready() -> void:
	if _did_register:
		return
	_did_register = true
	_register_pair("p1_", 0)
	_register_pair("p2_", 1)
	_register_ui_navigation()


func _register_pair(prefix: String, device: int) -> void:
	# 左類比：軸 0 = 左右，軸 1 = 上下（Godot 標準）
	_add_axis(prefix + "left", device, JOY_AXIS_LEFT_X, -1.0)
	_add_axis(prefix + "right", device, JOY_AXIS_LEFT_X, 1.0)
	_add_axis(prefix + "up", device, JOY_AXIS_LEFT_Y, -1.0)
	_add_axis(prefix + "down", device, JOY_AXIS_LEFT_Y, 1.0)
	# D-Pad（與搖桿並存）
	_add_btn(prefix + "left", device, JOY_BUTTON_DPAD_LEFT)
	_add_btn(prefix + "right", device, JOY_BUTTON_DPAD_RIGHT)
	_add_btn(prefix + "up", device, JOY_BUTTON_DPAD_UP)
	_add_btn(prefix + "down", device, JOY_BUTTON_DPAD_DOWN)
	# 確認：南鍵（Xbox A / PS ×）；技能：西鍵（Xbox X / PS □）
	# 註：B / Circle 留給 ui_back（暫停／返回），避免跟技能衝突
	_add_btn(prefix + "action", device, JOY_BUTTON_A)
	_add_btn(prefix + "skill", device, JOY_BUTTON_X)


func _register_ui_navigation() -> void:
	# 兩支手把都能用左搖桿 / 十字鍵在 UI 上下左右；A 確認、B 返回。
	# 這裡確保所有 UI 動作（包含 Godot 內建的 ui_accept / ui_up… 等）都明確綁好兩支手把，
	# 避免某些情境下 Godot 預設裝置綁定失效（例如標題畫面按 A 沒反應）。
	for dev in [0, 1]:
		# 確認鍵：A / Cross
		_add_btn("ui_accept", dev, JOY_BUTTON_A)
		_add_btn("ui_select", dev, JOY_BUTTON_A)
		# 取消 / 返回鍵：B / Circle
		_add_btn("ui_back", dev, JOY_BUTTON_B)
		_add_btn("ui_cancel", dev, JOY_BUTTON_B)
		# 上下左右：D-Pad
		_add_btn("ui_up", dev, JOY_BUTTON_DPAD_UP)
		_add_btn("ui_down", dev, JOY_BUTTON_DPAD_DOWN)
		_add_btn("ui_left", dev, JOY_BUTTON_DPAD_LEFT)
		_add_btn("ui_right", dev, JOY_BUTTON_DPAD_RIGHT)
		# 上下左右：左類比
		_add_axis("ui_up", dev, JOY_AXIS_LEFT_Y, -1.0)
		_add_axis("ui_down", dev, JOY_AXIS_LEFT_Y, 1.0)
		_add_axis("ui_left", dev, JOY_AXIS_LEFT_X, -1.0)
		_add_axis("ui_right", dev, JOY_AXIS_LEFT_X, 1.0)


func _has_joy_motion(action: String, device: int, axis: int, value: float) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadMotion:
			var j: InputEventJoypadMotion = ev
			if j.device == device and j.axis == axis and is_equal_approx(j.axis_value, value):
				return true
	return false


func _has_joy_btn(action: String, device: int, button: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton:
			var j: InputEventJoypadButton = ev
			if j.device == device and j.button_index == button:
				return true
	return false


func _add_axis(action: String, device: int, axis: int, axis_value: float) -> void:
	if not InputMap.has_action(action):
		return
	if _has_joy_motion(action, device, axis, axis_value):
		return
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = axis_value
	InputMap.action_add_event(action, ev)


func _add_btn(action: String, device: int, button: int) -> void:
	if not InputMap.has_action(action):
		return
	if _has_joy_btn(action, device, button):
		return
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	InputMap.action_add_event(action, ev)
