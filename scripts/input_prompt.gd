extends RefCounted
## 依玩家槽位與最近輸入，產生互動按鍵提示文字（鍵鼠／手把／觸控）。

enum Kind { KEYBOARD_MOUSE, GAMEPAD, TOUCH }

const _PREFIXES: Array[String] = ["p1", "p2"]
const _TRACK_ACTION_SUFFIXES: Array[String] = [
	"_action", "_left", "_right", "_up", "_down", "_skill",
]

static var _kind_by_prefix: Dictionary = {
	"p1": Kind.KEYBOARD_MOUSE,
	"p2": Kind.KEYBOARD_MOUSE,
}


static func note_event(event: InputEvent) -> void:
	if event == null:
		return
	if event is InputEventJoypadButton:
		var jb: InputEventJoypadButton = event
		if jb.pressed:
			_set_kind_for_joy_device(jb.device, Kind.GAMEPAD)
	elif event is InputEventJoypadMotion:
		var jm: InputEventJoypadMotion = event
		if absf(jm.axis_value) >= 0.35:
			_set_kind_for_joy_device(jm.device, Kind.GAMEPAD)
	elif event is InputEventKey:
		var ke: InputEventKey = event
		if ke.pressed and not ke.echo:
			_note_keyboard_event(ke)
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		_kind_by_prefix["p1"] = Kind.KEYBOARD_MOUSE


static func kind_for_prefix(prefix: String) -> Kind:
	if bool(GameState.touch_controls_enabled):
		return Kind.TOUCH
	return int(_kind_by_prefix.get(prefix, Kind.KEYBOARD_MOUSE))


static func interact_button_label(prefix: String) -> String:
	match kind_for_prefix(prefix):
		Kind.TOUCH:
			return TranslationServer.translate("INPUT_PROMPT_TOUCH_INTERACT")
		Kind.GAMEPAD:
			return TranslationServer.translate("INPUT_PROMPT_GAMEPAD_SOUTH")
		_:
			return keyboard_label_for_action(prefix + "_action")


static func keyboard_label_for_action(action: String) -> String:
	if not InputMap.has_action(action):
		return "?"
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var ke: InputEventKey = ev
			var code: int = ke.physical_keycode if ke.physical_keycode != 0 else ke.keycode
			if code == 0:
				continue
			var label: String = OS.get_keycode_string(code)
			if label.is_empty():
				label = ke.as_text().trim_suffix("(Physical)")
			return label
	return "?"


static func _set_kind_for_joy_device(device: int, kind: Kind) -> void:
	if device == 0:
		_kind_by_prefix["p1"] = kind
	elif device == 1:
		_kind_by_prefix["p2"] = kind


static func _note_keyboard_event(event: InputEventKey) -> void:
	for prefix in _PREFIXES:
		for suffix in _TRACK_ACTION_SUFFIXES:
			var action: String = prefix + suffix
			if _key_event_matches_action(event, action):
				_kind_by_prefix[prefix] = Kind.KEYBOARD_MOUSE
				return


static func _key_event_matches_action(event: InputEventKey, action: String) -> bool:
	if not InputMap.has_action(action):
		return false
	var event_code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var ke: InputEventKey = ev
			var code: int = ke.physical_keycode if ke.physical_keycode != 0 else ke.keycode
			if code == event_code:
				return true
	return false
