extends Control
## 關卡選擇：在 CharacterSelect 完成後出現，玩家挑選要打的關卡再進入戰鬥。
## - 鍵盤 / 手把：← → 切換關卡，Enter / Space / p1_action 確認，ESC / ui_back 返回
## - 觸控：◀ ▶ 切換、出發 / 返回大按鈕
## 關卡資料來自 GameData.STAGES，UI 會依資料自動支援多關切換。

const STAGE_PANEL_W := 720.0
const STAGE_PANEL_H := 400.0

var _stages: Array = []
var _index: int = 0
var _transitioning: bool = false
var _input_cooldown: float = 0.0

# UI 節點
var title_label: Label
var gold_label: Label
var stage_panel: Panel
var stage_name_label: Label
var stage_boss_label: Label
var stage_reward_label: Label
var hint_label: Label
var prev_button: Button
var next_button: Button
var depart_button: Button
var back_button: Button


func _ready() -> void:
	_stages = GameData.STAGES.duplicate()
	# 預設聚焦在 GameState.current_stage_id 對應的關卡
	for i in range(_stages.size()):
		if String(_stages[i]["id"]) == String(GameState.current_stage_id):
			_index = i
			break
	_build_ui()
	_apply_layout()
	_refresh()


func _process(delta: float) -> void:
	if _transitioning:
		return
	_input_cooldown = max(0.0, _input_cooldown - delta)

	if Input.is_action_just_pressed("ui_back"):
		_on_back()
		return
	if _input_cooldown > 0.0:
		return

	# 雙人時兩位玩家都能切換 / 確認
	if Input.is_action_just_pressed("p1_left") or Input.is_action_just_pressed("p2_left") or Input.is_action_just_pressed("ui_left"):
		_cycle(-1)
		_input_cooldown = 0.15
		return
	if Input.is_action_just_pressed("p1_right") or Input.is_action_just_pressed("p2_right") or Input.is_action_just_pressed("ui_right"):
		_cycle(1)
		_input_cooldown = 0.15
		return
	if Input.is_action_just_pressed("p1_action") or Input.is_action_just_pressed("p2_action") or Input.is_action_just_pressed("ui_accept"):
		_on_depart()


func _notification(what: int) -> void:
	# NOTIFICATION_RESIZED 會在 _ready() 前先觸發一次（剛加入場景樹被撐到 viewport 大小），
	# 這時 _build_ui() 尚未執行，UI 節點都還是 null；先過濾掉。
	if what == NOTIFICATION_RESIZED and title_label != null:
		_apply_layout()


# ============================================================================
# 建構 UI
# ============================================================================
func _build_ui() -> void:
	title_label = Label.new()
	title_label.text = tr("STAGE_SELECT_TITLE")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	add_child(title_label)

	gold_label = Label.new()
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.add_theme_font_size_override("font_size", 18)
	gold_label.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	add_child(gold_label)

	stage_panel = Panel.new()
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
	stage_panel.add_theme_stylebox_override("panel", sb)
	add_child(stage_panel)

	stage_name_label = Label.new()
	stage_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stage_name_label.add_theme_font_size_override("font_size", 30)
	stage_name_label.add_theme_color_override("font_color", Color(1, 1, 0.85))
	stage_panel.add_child(stage_name_label)

	stage_boss_label = Label.new()
	stage_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_boss_label.add_theme_font_size_override("font_size", 18)
	stage_boss_label.add_theme_color_override("font_color", Color(1, 0.7, 0.7))
	stage_panel.add_child(stage_boss_label)

	stage_reward_label = Label.new()
	stage_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_reward_label.add_theme_font_size_override("font_size", 18)
	stage_reward_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	stage_panel.add_child(stage_reward_label)

	prev_button = Button.new()
	GameData.apply_icon_button(prev_button, GameData.UI_ICON_ARROW_LEFT, "<")
	prev_button.focus_mode = Control.FOCUS_NONE
	prev_button.pressed.connect(_cycle.bind(-1))
	add_child(prev_button)

	next_button = Button.new()
	GameData.apply_icon_button(next_button, GameData.UI_ICON_ARROW_RIGHT, ">")
	next_button.focus_mode = Control.FOCUS_NONE
	next_button.pressed.connect(_cycle.bind(1))
	add_child(next_button)

	depart_button = Button.new()
	depart_button.text = tr("STAGE_SELECT_DEPART")
	depart_button.add_theme_font_size_override("font_size", 22)
	depart_button.pressed.connect(_on_depart)
	add_child(depart_button)

	back_button = Button.new()
	back_button.text = tr("STAGE_SELECT_BACK")
	back_button.add_theme_font_size_override("font_size", 16)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.pressed.connect(_on_back)
	add_child(back_button)

	hint_label = Label.new()
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.text = tr("STAGE_SELECT_HINT")
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.95))
	add_child(hint_label)

	depart_button.grab_focus()


func _apply_layout() -> void:
	if title_label == null:
		return
	var vp: Vector2 = get_viewport_rect().size

	title_label.position = Vector2((vp.x - 600) * 0.5, 28)
	title_label.size = Vector2(600, 50)

	gold_label.position = Vector2((vp.x - 400) * 0.5, 84)
	gold_label.size = Vector2(400, 28)

	stage_panel.position = Vector2((vp.x - STAGE_PANEL_W) * 0.5, (vp.y - STAGE_PANEL_H) * 0.5)
	stage_panel.size = Vector2(STAGE_PANEL_W, STAGE_PANEL_H)

	stage_name_label.position = Vector2(0, 70)
	stage_name_label.size = Vector2(STAGE_PANEL_W, 60)
	stage_boss_label.position = Vector2(0, 160)
	stage_boss_label.size = Vector2(STAGE_PANEL_W, 30)
	stage_reward_label.position = Vector2(0, 195)
	stage_reward_label.size = Vector2(STAGE_PANEL_W, 150)

	# 切換箭頭緊貼面板兩側
	var arrow_w: float = 64.0
	var arrow_h: float = 80.0
	var arrow_y: float = stage_panel.position.y + (STAGE_PANEL_H - arrow_h) * 0.5
	prev_button.size = Vector2(arrow_w, arrow_h)
	prev_button.position = Vector2(stage_panel.position.x - arrow_w - 12, arrow_y)
	next_button.size = Vector2(arrow_w, arrow_h)
	next_button.position = Vector2(stage_panel.position.x + STAGE_PANEL_W + 12, arrow_y)

	# 出發鈕：面板下方置中
	depart_button.size = Vector2(280, 56)
	depart_button.position = Vector2(
		(vp.x - 280) * 0.5,
		stage_panel.position.y + STAGE_PANEL_H + 28)

	# 返回鈕：左上角（避開右上角的齒輪 / 設定）
	back_button.size = Vector2(160, 44)
	back_button.position = Vector2(16, 16)

	hint_label.position = Vector2((vp.x - 800) * 0.5, vp.y - 56)
	hint_label.size = Vector2(800, 36)


# ============================================================================
# 內容刷新
# ============================================================================
func _refresh() -> void:
	if _stages.is_empty():
		stage_name_label.text = "—"
		return
	var stage: Dictionary = _stages[_index]
	stage_name_label.text = GameData.tr_name(stage)

	# 頭目資訊（若有）
	var boss_id: String = String(stage.get("boss_id", ""))
	if boss_id != "":
		var boss_name: String = GameData.tr_enemy_name(boss_id)
		if boss_name == "":
			boss_name = tr("GAME_BOSS_NAME_FALLBACK")
		stage_boss_label.text = tr("STAGE_SELECT_BOSS_FMT") % boss_name
	else:
		stage_boss_label.text = ""

	# 關卡獎勵
	var rewards: Array[String] = []
	var reward: int = int(stage.get("victory_gold", 0))
	if reward > 0:
		rewards.append(tr("STAGE_SELECT_REWARD_FMT") % reward)
	var rescue_npc_id: String = GameData.stage_rescue_npc_id(stage)
	if rescue_npc_id != "":
		if GameState.is_npc_rescued(rescue_npc_id):
			rewards.append(tr("STAGE_SELECT_RESCUE_NPC_DONE_FMT") % GameData.tr_rescue_npc_name(rescue_npc_id))
		else:
			rewards.append(tr("STAGE_SELECT_RESCUE_NPC_FMT") % GameData.tr_rescue_npc_name(rescue_npc_id))
	for facility_id in GameData.stage_victory_unlock_facility_ids(stage):
		var fdef: Dictionary = GameData.get_village_facility_def(facility_id)
		var fname: String = GameData.tr_field(fdef, "name", false) if not fdef.is_empty() else facility_id
		if GameState.is_village_facility_unlocked(facility_id):
			rewards.append(tr("STAGE_SELECT_FACILITY_UNLOCKED_FMT") % fname)
		else:
			rewards.append(tr("STAGE_SELECT_FACILITY_UNLOCK_FMT") % fname)
	var books_block: String = GameData.format_stage_event_armament_books_block(String(stage.get("id", "")))
	if books_block != "":
		rewards.append(books_block)
	for note_key in stage.get("victory_notes", []):
		rewards.append(tr(String(note_key)))
	if bool(stage.get("victory_blacksmith_tier2", false)):
		if GameState.blacksmith_tier2_unlocked:
			rewards.append(tr("STAGE_SELECT_BLACKSMITH_TIER2_DONE"))
		else:
			rewards.append(tr("STAGE_SELECT_BLACKSMITH_TIER2"))
	stage_reward_label.text = "\n".join(rewards)

	# 金幣與切換鈕可見性
	gold_label.text = tr("MAIN_GOLD_FMT") % GameState.gold
	var multi: bool = _stages.size() > 1
	prev_button.visible = multi
	next_button.visible = multi


func _cycle(dir: int) -> void:
	if _stages.size() <= 1:
		return
	AudioManager.play_sfx("ui_select")
	_index = (_index + dir + _stages.size()) % _stages.size()
	_refresh()


func _on_depart() -> void:
	if _transitioning or _stages.is_empty():
		return
	AudioManager.play_sfx("ui_confirm")
	GameState.current_stage_id = String(_stages[_index]["id"])
	GameState.save_to_disk()
	_transitioning = true
	get_tree().change_scene_to_file("res://scenes/Game.tscn")


func _on_back() -> void:
	if _transitioning:
		return
	AudioManager.play_sfx("ui_back")
	_transitioning = true
	get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn")
