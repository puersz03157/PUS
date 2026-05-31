extends Control
## 主選單。

@onready var btn_start: Button = $Center/VBox/StartButton
@onready var btn_quit: Button = $Center/VBox/QuitButton
@onready var gold_label: Label = $GoldLabel

var _transitioning: bool = false


func _ready() -> void:
	btn_start.pressed.connect(_on_start)
	btn_quit.pressed.connect(_on_quit)
	btn_start.grab_focus()
	_setup_ui_pattern_background()
	_refresh_meta()


func _setup_ui_pattern_background() -> void:
	var solid_bg: ColorRect = $Background
	solid_bg.color = Color(0.05, 0.07, 0.13, 0.0)
	var bg: Control = GameData.attach_ui_pattern_bg(
		self, GameData.UI_PATTERN_STYLE_FULL, GameData.UI_BG_CTX_MAIN, 0)
	if size.x > 1.0 and size.y > 1.0:
		GameData.finalize_pattern_bg_size(bg, size)


func _refresh_meta() -> void:
	if gold_label:
		gold_label.visible = false
	GameData.refresh_ui_pattern_backgrounds(self)


func _on_start() -> void:
	if _transitioning:
		return
	AudioManager.play_sfx("ui_confirm")
	_transitioning = true
	GameState.prepare_enter_village()
	get_tree().change_scene_to_file("res://scenes/Village.tscn")


func _on_quit() -> void:
	AudioManager.play_sfx("ui_confirm")
	get_tree().quit()
