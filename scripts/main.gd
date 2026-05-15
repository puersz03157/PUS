extends Control
## 主選單。

@onready var btn_solo: Button = $Center/VBox/SoloButton
@onready var btn_duo: Button = $Center/VBox/DuoButton
@onready var btn_village: Button = $Center/VBox/VillageButton
@onready var btn_quit: Button = $Center/VBox/QuitButton
@onready var gold_label: Label = $GoldLabel

@onready var village_picker: Control = $VillagePicker
@onready var btn_village_solo: Button = $VillagePicker/Box/Margin/VBox/VillageSoloButton
@onready var btn_village_duo: Button = $VillagePicker/Box/Margin/VBox/VillageDuoButton
@onready var btn_village_cancel: Button = $VillagePicker/Box/Margin/VBox/VillageCancelButton

var _transitioning: bool = false


func _ready() -> void:
	btn_solo.pressed.connect(_on_solo)
	btn_duo.pressed.connect(_on_duo)
	btn_village.pressed.connect(_on_village)
	btn_quit.pressed.connect(_on_quit)
	btn_village_solo.pressed.connect(_on_village_solo)
	btn_village_duo.pressed.connect(_on_village_duo)
	btn_village_cancel.pressed.connect(_close_village_picker)
	btn_solo.grab_focus()
	village_picker.visible = false
	_refresh_meta()


func _process(_delta: float) -> void:
	if village_picker.visible and Input.is_action_just_pressed("ui_cancel"):
		_close_village_picker()


func _refresh_meta() -> void:
	if gold_label:
		gold_label.visible = false


func _on_solo() -> void:
	_go_select(false, "battle")


func _on_duo() -> void:
	_go_select(true, "battle")


func _on_village() -> void:
	_open_village_picker()


func _open_village_picker() -> void:
	AudioManager.play_sfx("ui_select")
	village_picker.visible = true
	btn_village_solo.grab_focus()


func _close_village_picker() -> void:
	AudioManager.play_sfx("ui_back")
	village_picker.visible = false
	btn_village.grab_focus()


func _on_village_solo() -> void:
	_go_select(false, "village")


func _on_village_duo() -> void:
	_go_select(true, "village")


func _go_select(two_players: bool, target: String) -> void:
	if _transitioning:
		return
	AudioManager.play_sfx("ui_confirm")
	_transitioning = true
	GameState.two_players = two_players
	GameState.next_scene = target
	get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn")


func _on_quit() -> void:
	AudioManager.play_sfx("ui_confirm")
	get_tree().quit()
