extends CanvasLayer
## 全域設定覆蓋層（autoload）：
## - 永遠在右上角顯示一顆齒輪按鈕
## - 點擊後彈出設定面板（背景變暗、SceneTree 暫停）
## - 目前設定項：觸控操作、全角色解鎖、武器解鎖、重置帳號

const PANEL_W := 480.0
const PANEL_H := 592.0
const ACHIEVEMENTS_PANEL_W := 620.0
const ACHIEVEMENTS_PANEL_H := 480.0
const ITEMS_PANEL_W := 640.0
const ITEMS_PANEL_H := 520.0
const CODEX_PANEL_W := 760.0
const CODEX_PANEL_H := 560.0
const QUESTS_PANEL_W := 620.0
const QUESTS_PANEL_H := 480.0
const CREDITS_PANEL_W := 560.0
const CREDITS_PANEL_H := 420.0
const CREDIT_ENTRY_KEYS: Array[String] = [
	"CREDITS_ENTRY_ELEMENTALS",
	"CREDITS_ENTRY_ELVES_PACK",
	"CREDITS_ENTRY_VILLAGE",
	"CREDITS_ENTRY_NPC_PACK",
	"CREDITS_ENTRY_MONSTERS",
	"CREDITS_ENTRY_MATTZ_ART",
	"CREDITS_ENTRY_OTSOGA",
	"CREDITS_ENTRY_CRAFTPIX",
	"CREDITS_ENTRY_FINALBOSSBLUES",
]
const GEAR_TEXT := "⚙"
const Z_LAYER := 100
## 右上角成就／物品／圖鑑按鈕可出現的場景
const FLOATING_META_SCENES: Array[String] = [
	"res://scenes/Main.tscn",
	"res://scenes/Village.tscn",
]

var _open: bool = false
var _achievements_open: bool = false
var _items_open: bool = false
var _codex_open: bool = false
var _quests_open: bool = false
var _credits_open: bool = false
var _was_paused: bool = false
var _codex_tab: String = "characters"

var gear_button: Button
var achievement_button: Button
var items_button: Button
var codex_button: Button
var quest_button: Button
var dim: ColorRect
var panel: Panel
var title_label: Label
var touch_check: CheckButton
var touch_label: Label
var touch_hint: Label
var account_label: Label
var unlock_all_button: Button
var unlock_weapons_button: Button
var unlock_armaments_button: Button
var unlock_monsters_button: Button
var unlock_village_button: Button
var add_gold_button: Button
var max_team_weapons_button: Button
var reset_account_button: Button
var credits_button: Button
var close_button: Button
var credits_panel: Panel
var credits_title_label: Label
var credits_list: RichTextLabel
var credits_close_button: Button
var achievements_panel: Panel
var achievements_title_label: Label
var achievements_list: RichTextLabel
var achievements_close_button: Button
var items_panel: Panel
var items_title_label: Label
var items_tabs: HBoxContainer
var items_list: RichTextLabel
var items_close_button: Button
var items_tab_buttons: Dictionary = {}
var _items_tab: String = GameData.ITEMS_TAB_CURRENCY
var codex_panel: Panel
var codex_title_label: Label
var codex_tabs: HBoxContainer
var codex_list: RichTextLabel
var codex_monsters_host: Control
var codex_monsters_summary: RichTextLabel
var codex_monsters_item_list: ItemList
var codex_close_button: Button
var codex_tab_buttons: Dictionary = {}
var codex_detail_dialog: AcceptDialog
var quests_panel: Panel
var quests_title_label: Label
var quests_list: RichTextLabel
var quests_close_button: Button
var _reset_confirm_armed: bool = false


func _ready() -> void:
	layer = Z_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_apply_layout()
	_set_open(false)
	_refresh_from_state()
	# 解析度 / 視窗尺寸改變時，重新對齊齒輪與面板位置。
	get_viewport().size_changed.connect(_apply_layout)


func _process(_delta: float) -> void:
	_refresh_floating_button_visibility()


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

	achievement_button = Button.new()
	achievement_button.text = tr("ACHIEVEMENTS_BUTTON")
	achievement_button.custom_minimum_size = Vector2(92, 40)
	achievement_button.add_theme_font_size_override("font_size", 16)
	achievement_button.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	achievement_button.process_mode = Node.PROCESS_MODE_ALWAYS
	achievement_button.focus_mode = Control.FOCUS_NONE
	achievement_button.pressed.connect(_open_achievements)
	var achievement_sb := StyleBoxFlat.new()
	achievement_sb.bg_color = Color(0.05, 0.07, 0.15, 0.7)
	achievement_sb.border_color = Color(0.95, 0.65, 0.18, 0.9)
	achievement_sb.border_width_left = 2
	achievement_sb.border_width_right = 2
	achievement_sb.border_width_top = 2
	achievement_sb.border_width_bottom = 2
	achievement_sb.corner_radius_top_left = 12
	achievement_sb.corner_radius_top_right = 12
	achievement_sb.corner_radius_bottom_left = 12
	achievement_sb.corner_radius_bottom_right = 12
	achievement_button.add_theme_stylebox_override("normal", achievement_sb)
	achievement_button.add_theme_stylebox_override("hover", achievement_sb)
	achievement_button.add_theme_stylebox_override("pressed", achievement_sb)
	achievement_button.add_theme_stylebox_override("focus", achievement_sb)
	add_child(achievement_button)

	items_button = Button.new()
	items_button.text = tr("ITEMS_BUTTON")
	items_button.custom_minimum_size = Vector2(92, 40)
	items_button.add_theme_font_size_override("font_size", 16)
	items_button.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	items_button.process_mode = Node.PROCESS_MODE_ALWAYS
	items_button.focus_mode = Control.FOCUS_NONE
	items_button.pressed.connect(_open_items)
	items_button.add_theme_stylebox_override("normal", achievement_sb)
	items_button.add_theme_stylebox_override("hover", achievement_sb)
	items_button.add_theme_stylebox_override("pressed", achievement_sb)
	items_button.add_theme_stylebox_override("focus", achievement_sb)
	add_child(items_button)

	codex_button = Button.new()
	codex_button.text = tr("CODEX_BUTTON")
	codex_button.custom_minimum_size = Vector2(92, 40)
	codex_button.add_theme_font_size_override("font_size", 16)
	codex_button.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	codex_button.process_mode = Node.PROCESS_MODE_ALWAYS
	codex_button.focus_mode = Control.FOCUS_NONE
	codex_button.pressed.connect(_open_codex)
	codex_button.add_theme_stylebox_override("normal", achievement_sb)
	codex_button.add_theme_stylebox_override("hover", achievement_sb)
	codex_button.add_theme_stylebox_override("pressed", achievement_sb)
	codex_button.add_theme_stylebox_override("focus", achievement_sb)
	add_child(codex_button)

	quest_button = Button.new()
	quest_button.text = tr("QUEST_BUTTON")
	quest_button.custom_minimum_size = Vector2(92, 40)
	quest_button.add_theme_font_size_override("font_size", 16)
	quest_button.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	quest_button.process_mode = Node.PROCESS_MODE_ALWAYS
	quest_button.focus_mode = Control.FOCUS_NONE
	quest_button.pressed.connect(_open_quests)
	quest_button.add_theme_stylebox_override("normal", achievement_sb)
	quest_button.add_theme_stylebox_override("hover", achievement_sb)
	quest_button.add_theme_stylebox_override("pressed", achievement_sb)
	quest_button.add_theme_stylebox_override("focus", achievement_sb)
	add_child(quest_button)

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
	touch_hint.size = Vector2(PANEL_W - 56, 60)
	touch_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	touch_hint.add_theme_font_size_override("font_size", 13)
	touch_hint.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	panel.add_child(touch_hint)

	# 帳號 / 開發測試操作 — 用 VBoxContainer 讓高度自動排，每列兩按鈕
	account_label = Label.new()
	account_label.text = tr("SETTINGS_ACCOUNT_TITLE")
	account_label.position = Vector2(28, 218)
	account_label.size = Vector2(PANEL_W - 56, 28)
	account_label.add_theme_font_size_override("font_size", 16)
	account_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	panel.add_child(account_label)

	var acct_vbox := VBoxContainer.new()
	acct_vbox.position = Vector2(28, 252)
	acct_vbox.size = Vector2(PANEL_W - 56, 0)
	acct_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	acct_vbox.add_theme_constant_override("separation", 8)
	panel.add_child(acct_vbox)

	# 列 1：全角色解鎖 / 解鎖武器與格子
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	acct_vbox.add_child(row1)

	unlock_all_button = Button.new()
	unlock_all_button.text = tr("SETTINGS_UNLOCK_ALL")
	unlock_all_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unlock_all_button.custom_minimum_size = Vector2(0, 40)
	unlock_all_button.add_theme_font_size_override("font_size", 14)
	unlock_all_button.process_mode = Node.PROCESS_MODE_ALWAYS
	unlock_all_button.pressed.connect(_on_unlock_all_pressed)
	row1.add_child(unlock_all_button)

	unlock_weapons_button = Button.new()
	unlock_weapons_button.text = tr("SETTINGS_UNLOCK_WEAPONS")
	unlock_weapons_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unlock_weapons_button.custom_minimum_size = Vector2(0, 40)
	unlock_weapons_button.add_theme_font_size_override("font_size", 14)
	unlock_weapons_button.process_mode = Node.PROCESS_MODE_ALWAYS
	unlock_weapons_button.pressed.connect(_on_unlock_weapons_pressed)
	row1.add_child(unlock_weapons_button)

	# 列 2：全武裝解鎖 / 怪物圖鑑解鎖
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	acct_vbox.add_child(row2)

	unlock_armaments_button = Button.new()
	unlock_armaments_button.text = tr("SETTINGS_UNLOCK_ARMAMENTS")
	unlock_armaments_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unlock_armaments_button.custom_minimum_size = Vector2(0, 40)
	unlock_armaments_button.add_theme_font_size_override("font_size", 14)
	unlock_armaments_button.add_theme_color_override("font_color", Color(0.75, 0.95, 0.75))
	unlock_armaments_button.process_mode = Node.PROCESS_MODE_ALWAYS
	unlock_armaments_button.pressed.connect(_on_unlock_armaments_pressed)
	row2.add_child(unlock_armaments_button)

	unlock_monsters_button = Button.new()
	unlock_monsters_button.text = tr("SETTINGS_UNLOCK_MONSTERS")
	unlock_monsters_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unlock_monsters_button.custom_minimum_size = Vector2(0, 40)
	unlock_monsters_button.add_theme_font_size_override("font_size", 14)
	unlock_monsters_button.add_theme_color_override("font_color", Color(0.85, 0.78, 1.0))
	unlock_monsters_button.process_mode = Node.PROCESS_MODE_ALWAYS
	unlock_monsters_button.pressed.connect(_on_unlock_monsters_pressed)
	row2.add_child(unlock_monsters_button)

	# 列 2b：村莊全 NPC 解救 + 全設施開啟
	var row2b := HBoxContainer.new()
	row2b.add_theme_constant_override("separation", 8)
	acct_vbox.add_child(row2b)

	unlock_village_button = Button.new()
	unlock_village_button.text = tr("SETTINGS_UNLOCK_VILLAGE")
	unlock_village_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unlock_village_button.custom_minimum_size = Vector2(0, 40)
	unlock_village_button.add_theme_font_size_override("font_size", 14)
	unlock_village_button.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0))
	unlock_village_button.process_mode = Node.PROCESS_MODE_ALWAYS
	unlock_village_button.pressed.connect(_on_unlock_village_pressed)
	row2b.add_child(unlock_village_button)

	# 列 3：+5000 金幣 / 升滿場上武器
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 8)
	acct_vbox.add_child(row3)

	add_gold_button = Button.new()
	add_gold_button.text = tr("SETTINGS_ADD_GOLD")
	add_gold_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_gold_button.custom_minimum_size = Vector2(0, 40)
	add_gold_button.add_theme_font_size_override("font_size", 14)
	add_gold_button.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	add_gold_button.process_mode = Node.PROCESS_MODE_ALWAYS
	add_gold_button.pressed.connect(_on_add_gold_pressed)
	row3.add_child(add_gold_button)

	max_team_weapons_button = Button.new()
	max_team_weapons_button.text = tr("SETTINGS_MAX_TEAM_WEAPONS")
	max_team_weapons_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	max_team_weapons_button.custom_minimum_size = Vector2(0, 40)
	max_team_weapons_button.add_theme_font_size_override("font_size", 14)
	max_team_weapons_button.add_theme_color_override("font_color", Color(0.65, 1.0, 0.72))
	max_team_weapons_button.process_mode = Node.PROCESS_MODE_ALWAYS
	max_team_weapons_button.pressed.connect(_on_max_team_weapons_pressed)
	row3.add_child(max_team_weapons_button)

	# 列 4：重置帳號（單獨一列，紅色警示）
	var row4 := HBoxContainer.new()
	acct_vbox.add_child(row4)

	reset_account_button = Button.new()
	reset_account_button.text = tr("SETTINGS_RESET_ACCOUNT")
	reset_account_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_account_button.custom_minimum_size = Vector2(0, 40)
	reset_account_button.add_theme_font_size_override("font_size", 14)
	reset_account_button.add_theme_color_override("font_color", Color(1.0, 0.62, 0.55))
	reset_account_button.process_mode = Node.PROCESS_MODE_ALWAYS
	reset_account_button.pressed.connect(_on_reset_account_pressed)
	row4.add_child(reset_account_button)

	credits_button = Button.new()
	credits_button.text = tr("SETTINGS_CREDITS_BUTTON")
	credits_button.size = Vector2(200, 40)
	credits_button.position = Vector2((PANEL_W - 200) * 0.5, PANEL_H - 112)
	credits_button.add_theme_font_size_override("font_size", 16)
	credits_button.add_theme_color_override("font_color", Color(0.82, 0.9, 1.0))
	credits_button.process_mode = Node.PROCESS_MODE_ALWAYS
	credits_button.pressed.connect(_open_credits)
	panel.add_child(credits_button)

	# 關閉按鈕
	close_button = Button.new()
	close_button.text = tr("SETTINGS_CLOSE")
	close_button.size = Vector2(180, 44)
	close_button.position = Vector2((PANEL_W - 180) * 0.5, PANEL_H - 60)
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.pressed.connect(_close)
	panel.add_child(close_button)

	_build_achievements_panel()
	_build_items_panel()
	_build_codex_panel()
	_build_quests_panel()
	_build_credits_panel()


func _build_credits_panel() -> void:
	credits_panel = Panel.new()
	credits_panel.size = Vector2(CREDITS_PANEL_W, CREDITS_PANEL_H)
	credits_panel.process_mode = Node.PROCESS_MODE_ALWAYS
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
	credits_panel.add_theme_stylebox_override("panel", sb)
	add_child(credits_panel)

	credits_title_label = Label.new()
	credits_title_label.position = Vector2(0, 18)
	credits_title_label.size = Vector2(CREDITS_PANEL_W, 38)
	credits_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_title_label.add_theme_font_size_override("font_size", 26)
	credits_title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	credits_panel.add_child(credits_title_label)

	credits_list = RichTextLabel.new()
	credits_list.position = Vector2(30, 74)
	credits_list.size = Vector2(CREDITS_PANEL_W - 60, CREDITS_PANEL_H - 148)
	credits_list.bbcode_enabled = true
	credits_list.scroll_active = true
	credits_list.fit_content = false
	credits_list.add_theme_font_size_override("normal_font_size", 15)
	credits_list.add_theme_color_override("default_color", Color(0.86, 0.9, 1.0))
	credits_panel.add_child(credits_list)

	credits_close_button = Button.new()
	credits_close_button.size = Vector2(180, 44)
	credits_close_button.position = Vector2((CREDITS_PANEL_W - 180) * 0.5, CREDITS_PANEL_H - 60)
	credits_close_button.add_theme_font_size_override("font_size", 18)
	credits_close_button.process_mode = Node.PROCESS_MODE_ALWAYS
	credits_close_button.pressed.connect(_close_credits)
	credits_panel.add_child(credits_close_button)


func _build_achievements_panel() -> void:
	achievements_panel = Panel.new()
	achievements_panel.size = Vector2(ACHIEVEMENTS_PANEL_W, ACHIEVEMENTS_PANEL_H)
	achievements_panel.process_mode = Node.PROCESS_MODE_ALWAYS
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
	achievements_panel.add_theme_stylebox_override("panel", sb)
	add_child(achievements_panel)

	achievements_title_label = Label.new()
	achievements_title_label.position = Vector2(0, 18)
	achievements_title_label.size = Vector2(ACHIEVEMENTS_PANEL_W, 38)
	achievements_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	achievements_title_label.add_theme_font_size_override("font_size", 26)
	achievements_title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	achievements_panel.add_child(achievements_title_label)

	achievements_list = RichTextLabel.new()
	achievements_list.position = Vector2(30, 74)
	achievements_list.size = Vector2(ACHIEVEMENTS_PANEL_W - 60, ACHIEVEMENTS_PANEL_H - 148)
	achievements_list.bbcode_enabled = true
	achievements_list.scroll_active = true
	achievements_list.fit_content = false
	achievements_list.add_theme_font_size_override("normal_font_size", 16)
	achievements_list.add_theme_color_override("default_color", Color(0.86, 0.9, 1.0))
	achievements_panel.add_child(achievements_list)

	achievements_close_button = Button.new()
	achievements_close_button.size = Vector2(180, 44)
	achievements_close_button.position = Vector2((ACHIEVEMENTS_PANEL_W - 180) * 0.5, ACHIEVEMENTS_PANEL_H - 60)
	achievements_close_button.add_theme_font_size_override("font_size", 18)
	achievements_close_button.process_mode = Node.PROCESS_MODE_ALWAYS
	achievements_close_button.pressed.connect(_close_achievements)
	achievements_panel.add_child(achievements_close_button)


func _build_quests_panel() -> void:
	quests_panel = Panel.new()
	quests_panel.size = Vector2(QUESTS_PANEL_W, QUESTS_PANEL_H)
	quests_panel.process_mode = Node.PROCESS_MODE_ALWAYS
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
	quests_panel.add_theme_stylebox_override("panel", sb)
	add_child(quests_panel)

	quests_title_label = Label.new()
	quests_title_label.position = Vector2(0, 18)
	quests_title_label.size = Vector2(QUESTS_PANEL_W, 38)
	quests_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quests_title_label.add_theme_font_size_override("font_size", 26)
	quests_title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	quests_panel.add_child(quests_title_label)

	quests_list = RichTextLabel.new()
	quests_list.position = Vector2(30, 74)
	quests_list.size = Vector2(QUESTS_PANEL_W - 60, QUESTS_PANEL_H - 148)
	quests_list.bbcode_enabled = true
	quests_list.scroll_active = true
	quests_list.fit_content = false
	quests_list.add_theme_font_size_override("normal_font_size", 16)
	quests_list.add_theme_color_override("default_color", Color(0.86, 0.9, 1.0))
	quests_panel.add_child(quests_list)

	quests_close_button = Button.new()
	quests_close_button.size = Vector2(180, 44)
	quests_close_button.position = Vector2((QUESTS_PANEL_W - 180) * 0.5, QUESTS_PANEL_H - 60)
	quests_close_button.add_theme_font_size_override("font_size", 18)
	quests_close_button.process_mode = Node.PROCESS_MODE_ALWAYS
	quests_close_button.pressed.connect(_close_quests)
	quests_panel.add_child(quests_close_button)


func _build_items_panel() -> void:
	items_panel = Panel.new()
	items_panel.size = Vector2(ITEMS_PANEL_W, ITEMS_PANEL_H)
	items_panel.process_mode = Node.PROCESS_MODE_ALWAYS
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
	items_panel.add_theme_stylebox_override("panel", sb)
	add_child(items_panel)

	items_title_label = Label.new()
	items_title_label.position = Vector2(0, 18)
	items_title_label.size = Vector2(ITEMS_PANEL_W, 38)
	items_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	items_title_label.add_theme_font_size_override("font_size", 26)
	items_title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	items_panel.add_child(items_title_label)

	items_tabs = HBoxContainer.new()
	items_tabs.position = Vector2(20, 58)
	items_tabs.size = Vector2(ITEMS_PANEL_W - 40, 40)
	items_tabs.add_theme_constant_override("separation", 6)
	items_panel.add_child(items_tabs)
	for tab_def in GameData.ITEMS_TABS:
		var tab_id: String = String(tab_def.get("id", ""))
		var btn := Button.new()
		btn.name = "ItemsTab_" + tab_id
		btn.text = tr(String(tab_def.get("label_key", "")))
		btn.custom_minimum_size = Vector2(96, 36)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.process_mode = Node.PROCESS_MODE_ALWAYS
		btn.pressed.connect(_set_items_tab.bind(tab_id))
		items_tabs.add_child(btn)
		items_tab_buttons[tab_id] = btn

	items_list = RichTextLabel.new()
	items_list.position = Vector2(24, 108)
	items_list.size = Vector2(ITEMS_PANEL_W - 48, ITEMS_PANEL_H - 188)
	items_list.bbcode_enabled = true
	items_list.scroll_active = true
	items_list.fit_content = false
	items_list.add_theme_font_size_override("normal_font_size", 16)
	items_list.add_theme_color_override("default_color", Color(0.86, 0.9, 1.0))
	items_panel.add_child(items_list)

	items_close_button = Button.new()
	items_close_button.size = Vector2(180, 44)
	items_close_button.position = Vector2((ITEMS_PANEL_W - 180) * 0.5, ITEMS_PANEL_H - 56)
	items_close_button.add_theme_font_size_override("font_size", 18)
	items_close_button.process_mode = Node.PROCESS_MODE_ALWAYS
	items_close_button.pressed.connect(_close_items)
	items_panel.add_child(items_close_button)


func _build_codex_panel() -> void:
	codex_panel = Panel.new()
	codex_panel.size = Vector2(CODEX_PANEL_W, CODEX_PANEL_H)
	codex_panel.process_mode = Node.PROCESS_MODE_ALWAYS
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
	codex_panel.add_theme_stylebox_override("panel", sb)
	add_child(codex_panel)

	codex_title_label = Label.new()
	codex_title_label.position = Vector2(0, 16)
	codex_title_label.size = Vector2(CODEX_PANEL_W, 38)
	codex_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	codex_title_label.add_theme_font_size_override("font_size", 26)
	codex_title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	codex_panel.add_child(codex_title_label)

	codex_tabs = HBoxContainer.new()
	codex_tabs.position = Vector2(28, 66)
	codex_tabs.size = Vector2(CODEX_PANEL_W - 56, 42)
	codex_tabs.add_theme_constant_override("separation", 8)
	codex_panel.add_child(codex_tabs)
	_add_codex_tab_button("characters", "CODEX_TAB_CHARACTERS")
	_add_codex_tab_button("weapons", "CODEX_TAB_WEAPONS")
	_add_codex_tab_button("abilities", "CODEX_TAB_ABILITIES")
	_add_codex_tab_button("armaments", "CODEX_TAB_ARMAMENTS")
	_add_codex_tab_button("monsters", "CODEX_TAB_MONSTERS")

	codex_list = RichTextLabel.new()
	codex_list.position = Vector2(30, 124)
	codex_list.size = Vector2(CODEX_PANEL_W - 60, CODEX_PANEL_H - 198)
	codex_list.bbcode_enabled = true
	codex_list.scroll_active = true
	codex_list.fit_content = false
	codex_list.add_theme_font_size_override("normal_font_size", 15)
	codex_list.add_theme_color_override("default_color", Color(0.86, 0.9, 1.0))
	codex_list.meta_clicked.connect(_on_codex_meta_clicked)
	codex_panel.add_child(codex_list)

	codex_monsters_host = Control.new()
	codex_monsters_host.position = codex_list.position
	codex_monsters_host.size = codex_list.size
	codex_monsters_host.visible = false
	codex_monsters_host.mouse_filter = Control.MOUSE_FILTER_STOP
	codex_panel.add_child(codex_monsters_host)
	var mon_vbx := VBoxContainer.new()
	mon_vbx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mon_vbx.add_theme_constant_override("separation", 6)
	codex_monsters_host.add_child(mon_vbx)
	codex_monsters_summary = RichTextLabel.new()
	codex_monsters_summary.bbcode_enabled = true
	codex_monsters_summary.fit_content = true
	codex_monsters_summary.scroll_active = false
	codex_monsters_summary.custom_minimum_size = Vector2(CODEX_PANEL_W - 60, 0)
	codex_monsters_summary.add_theme_font_size_override("normal_font_size", 15)
	codex_monsters_summary.add_theme_color_override("default_color", Color(0.86, 0.9, 1.0))
	mon_vbx.add_child(codex_monsters_summary)
	codex_monsters_item_list = ItemList.new()
	codex_monsters_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	codex_monsters_item_list.max_columns = 3
	codex_monsters_item_list.same_column_width = true
	codex_monsters_item_list.fixed_column_width = 236
	codex_monsters_item_list.fixed_icon_size = Vector2i(48, 48)
	codex_monsters_item_list.icon_mode = ItemList.ICON_MODE_TOP
	codex_monsters_item_list.allow_reselect = true
	codex_monsters_item_list.select_mode = ItemList.SELECT_SINGLE
	codex_monsters_item_list.add_theme_font_size_override("font_size", 13)
	codex_monsters_item_list.item_clicked.connect(_on_codex_monster_item_clicked)
	mon_vbx.add_child(codex_monsters_item_list)

	codex_close_button = Button.new()
	codex_close_button.size = Vector2(180, 44)
	codex_close_button.position = Vector2((CODEX_PANEL_W - 180) * 0.5, CODEX_PANEL_H - 60)
	codex_close_button.add_theme_font_size_override("font_size", 18)
	codex_close_button.process_mode = Node.PROCESS_MODE_ALWAYS
	codex_close_button.pressed.connect(_close_codex)
	codex_panel.add_child(codex_close_button)

	codex_detail_dialog = AcceptDialog.new()
	codex_detail_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	codex_detail_dialog.min_size = Vector2(480, 320)
	add_child(codex_detail_dialog)


func _add_codex_tab_button(tab_id: String, label_key: String) -> void:
	var btn := Button.new()
	btn.name = "CodexTab_" + tab_id
	btn.text = tr(label_key)
	btn.custom_minimum_size = Vector2(130, 38)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.pressed.connect(_set_codex_tab.bind(tab_id))
	codex_tabs.add_child(btn)
	codex_tab_buttons[tab_id] = btn


func _apply_layout() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	gear_button.position = Vector2(vp.x - gear_button.custom_minimum_size.x - 12, 12)
	gear_button.size = gear_button.custom_minimum_size
	achievement_button.size = achievement_button.custom_minimum_size
	achievement_button.position = Vector2(
		vp.x - achievement_button.custom_minimum_size.x - 12,
		gear_button.position.y + gear_button.size.y + 8)
	items_button.size = items_button.custom_minimum_size
	items_button.position = Vector2(
		vp.x - items_button.custom_minimum_size.x - 12,
		achievement_button.position.y + achievement_button.size.y + 8)
	codex_button.size = codex_button.custom_minimum_size
	codex_button.position = Vector2(
		vp.x - codex_button.custom_minimum_size.x - 12,
		items_button.position.y + items_button.size.y + 8)
	quest_button.size = quest_button.custom_minimum_size
	quest_button.position = Vector2(
		vp.x - quest_button.custom_minimum_size.x - 12,
		codex_button.position.y + codex_button.size.y + 8)
	dim.size = vp
	panel.position = Vector2((vp.x - PANEL_W) * 0.5, (vp.y - PANEL_H) * 0.5)
	achievements_panel.position = Vector2(
		(vp.x - ACHIEVEMENTS_PANEL_W) * 0.5,
		(vp.y - ACHIEVEMENTS_PANEL_H) * 0.5)
	items_panel.position = Vector2((vp.x - ITEMS_PANEL_W) * 0.5, (vp.y - ITEMS_PANEL_H) * 0.5)
	codex_panel.position = Vector2((vp.x - CODEX_PANEL_W) * 0.5, (vp.y - CODEX_PANEL_H) * 0.5)
	quests_panel.position = Vector2((vp.x - QUESTS_PANEL_W) * 0.5, (vp.y - QUESTS_PANEL_H) * 0.5)
	credits_panel.position = Vector2((vp.x - CREDITS_PANEL_W) * 0.5, (vp.y - CREDITS_PANEL_H) * 0.5)
	_refresh_floating_button_visibility()


func _refresh_from_state() -> void:
	if is_instance_valid(GameState):
		touch_check.set_pressed_no_signal(bool(GameState.touch_controls_enabled))
	# 場景切換後再翻一次（語系若中途改變也會反映）
	title_label.text = tr("SETTINGS_TITLE")
	touch_label.text = tr("SETTINGS_TOUCH_CONTROLS")
	touch_hint.text = tr("SETTINGS_TOUCH_HINT")
	account_label.text = tr("SETTINGS_ACCOUNT_TITLE")
	unlock_all_button.text = tr("SETTINGS_UNLOCK_ALL")
	unlock_weapons_button.text = tr("SETTINGS_UNLOCK_WEAPONS")
	if unlock_armaments_button != null:
		unlock_armaments_button.text = tr("SETTINGS_UNLOCK_ARMAMENTS")
	if unlock_monsters_button != null:
		unlock_monsters_button.text = tr("SETTINGS_UNLOCK_MONSTERS")
	if unlock_village_button != null:
		unlock_village_button.text = tr("SETTINGS_UNLOCK_VILLAGE")
	add_gold_button.text = tr("SETTINGS_ADD_GOLD")
	max_team_weapons_button.text = tr("SETTINGS_MAX_TEAM_WEAPONS")
	reset_account_button.text = tr("SETTINGS_RESET_ACCOUNT_CONFIRM") \
		if _reset_confirm_armed else tr("SETTINGS_RESET_ACCOUNT")
	close_button.text = tr("SETTINGS_CLOSE")
	if credits_button != null:
		credits_button.text = tr("SETTINGS_CREDITS_BUTTON")
	achievement_button.text = tr("ACHIEVEMENTS_BUTTON")
	items_button.text = tr("ITEMS_BUTTON")
	codex_button.text = tr("CODEX_BUTTON")
	quest_button.text = tr("QUEST_BUTTON")
	_refresh_achievements_panel()
	_refresh_items_panel()
	_refresh_codex_panel()
	_refresh_quests_panel()
	_refresh_credits_panel()


func _toggle() -> void:
	_set_open(not _open)


func _close() -> void:
	_set_open(false)


func _set_open(v: bool) -> void:
	_open = v
	if v:
		_achievements_open = false
		_items_open = false
		_codex_open = false
		_quests_open = false
		_credits_open = false
		achievements_panel.visible = false
		items_panel.visible = false
		codex_panel.visible = false
		quests_panel.visible = false
		credits_panel.visible = false
	dim.visible = v
	panel.visible = v
	if v:
		_reset_confirm_armed = false
		_refresh_from_state()
		_was_paused = get_tree().paused
		get_tree().paused = true
		close_button.grab_focus()
	else:
		achievements_panel.visible = false
		items_panel.visible = false
		codex_panel.visible = false
		quests_panel.visible = false
		credits_panel.visible = false
		# 還原原本的暫停狀態（避免和 PauseMenu / Pinball 互踩）
		get_tree().paused = _was_paused
	_refresh_floating_button_visibility()


func _open_credits() -> void:
	_set_credits_open(true)


func _close_credits() -> void:
	_set_credits_open(false)


func _set_credits_open(v: bool) -> void:
	_credits_open = v
	if v:
		_open = false
		_achievements_open = false
		_items_open = false
		_codex_open = false
		_quests_open = false
		panel.visible = false
		achievements_panel.visible = false
		items_panel.visible = false
		codex_panel.visible = false
		quests_panel.visible = false
		_reset_confirm_armed = false
		_refresh_credits_panel()
		_was_paused = get_tree().paused
		get_tree().paused = true
		credits_close_button.grab_focus()
	else:
		get_tree().paused = _was_paused
	dim.visible = v
	credits_panel.visible = v
	_refresh_floating_button_visibility()


func _refresh_credits_panel() -> void:
	if credits_panel == null or credits_list == null:
		return
	credits_title_label.text = tr("CREDITS_TITLE")
	credits_close_button.text = tr("CREDITS_CLOSE")
	var lines: Array[String] = [
		"[color=#b8c8e8]%s[/color]" % tr("CREDITS_INTRO"),
		"",
	]
	for key in CREDIT_ENTRY_KEYS:
		lines.append("• %s" % tr(key))
	credits_list.text = "\n".join(lines)


func _open_achievements() -> void:
	_set_achievements_open(true)


func _close_achievements() -> void:
	_set_achievements_open(false)


func _set_achievements_open(v: bool) -> void:
	_achievements_open = v
	if v:
		_open = false
		_items_open = false
		_codex_open = false
		_quests_open = false
		_credits_open = false
		panel.visible = false
		items_panel.visible = false
		codex_panel.visible = false
		quests_panel.visible = false
		credits_panel.visible = false
		_reset_confirm_armed = false
		_refresh_achievements_panel()
		_was_paused = get_tree().paused
		get_tree().paused = true
		achievements_close_button.grab_focus()
	else:
		get_tree().paused = _was_paused
	dim.visible = v
	achievements_panel.visible = v
	_refresh_floating_button_visibility()


func _open_items() -> void:
	_set_items_open(true)


func _close_items() -> void:
	_set_items_open(false)


func _set_items_open(v: bool) -> void:
	_items_open = v
	if v:
		_open = false
		_achievements_open = false
		_codex_open = false
		_quests_open = false
		_credits_open = false
		panel.visible = false
		achievements_panel.visible = false
		codex_panel.visible = false
		quests_panel.visible = false
		credits_panel.visible = false
		_reset_confirm_armed = false
		_refresh_items_panel()
		_was_paused = get_tree().paused
		get_tree().paused = true
		items_close_button.grab_focus()
	else:
		get_tree().paused = _was_paused
	dim.visible = v
	items_panel.visible = v
	_refresh_floating_button_visibility()


func _open_codex() -> void:
	_set_codex_open(true)


func _close_codex() -> void:
	_set_codex_open(false)


func _set_codex_open(v: bool) -> void:
	_codex_open = v
	if v:
		_open = false
		_achievements_open = false
		_items_open = false
		_quests_open = false
		_credits_open = false
		panel.visible = false
		achievements_panel.visible = false
		items_panel.visible = false
		quests_panel.visible = false
		credits_panel.visible = false
		_reset_confirm_armed = false
		_refresh_codex_panel()
		_was_paused = get_tree().paused
		get_tree().paused = true
		codex_close_button.grab_focus()
	else:
		get_tree().paused = _was_paused
	dim.visible = v
	codex_panel.visible = v
	_refresh_floating_button_visibility()


func _open_quests() -> void:
	_set_quests_open(true)


func _close_quests() -> void:
	_set_quests_open(false)


func _set_quests_open(v: bool) -> void:
	_quests_open = v
	if v:
		_open = false
		_achievements_open = false
		_items_open = false
		_codex_open = false
		_credits_open = false
		panel.visible = false
		achievements_panel.visible = false
		items_panel.visible = false
		codex_panel.visible = false
		credits_panel.visible = false
		_reset_confirm_armed = false
		_refresh_quests_panel()
		_was_paused = get_tree().paused
		get_tree().paused = true
		quests_close_button.grab_focus()
	else:
		get_tree().paused = _was_paused
	dim.visible = v
	quests_panel.visible = v
	_refresh_floating_button_visibility()


func _set_codex_tab(tab_id: String) -> void:
	_codex_tab = tab_id
	_refresh_codex_panel()


func _scene_allows_floating_meta_buttons() -> bool:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return false
	return FLOATING_META_SCENES.has(scene.scene_file_path)


func _refresh_floating_button_visibility() -> void:
	if achievement_button == null or items_button == null or codex_button == null \
			or quest_button == null:
		return
	var show_buttons: bool = _scene_allows_floating_meta_buttons() \
		and not _open and not _achievements_open and not _items_open \
		and not _codex_open and not _quests_open and not _credits_open
	achievement_button.visible = show_buttons
	items_button.visible = show_buttons
	codex_button.visible = show_buttons
	quest_button.visible = show_buttons
	_refresh_quest_button_label()


func _refresh_quests_panel() -> void:
	if quests_panel == null or quests_list == null:
		return
	quests_title_label.text = tr("QUESTS_TITLE")
	quests_close_button.text = tr("QUESTS_CLOSE")

	var lines: Array[String] = []

	# ── 進行中 ──
	var active_ids: Array[String] = _active_quest_ids()
	if active_ids.is_empty():
		pass
	else:
		lines.append("[color=#ffd24d][b]▸ %s[/b][/color]" % tr("QUEST_LOG_ACTIVE_SECTION"))
		for qid in active_ids:
			var name_str: String = tr("QUEST_%s_NAME" % qid.to_upper())
			var obj_str: String = tr("QUEST_%s_OBJECTIVE" % qid.to_upper())
			lines.append("[b]%s[/b]" % name_str)
			lines.append(obj_str)
			lines.append("")

	# ── 已完成 ──
	var completed: Array[String] = GameState.completed_quests
	if completed.is_empty():
		pass
	else:
		lines.append("[color=#7dff9d][b]▸ %s[/b][/color]" % tr("QUEST_LOG_COMPLETED_SECTION"))
		for qid in completed:
			var name_str: String = tr("QUEST_%s_NAME" % qid.to_upper())
			var log_str: String = tr("QUEST_%s_LOG" % qid.to_upper())
			lines.append("[color=#aaffaa][b]✔ %s[/b][/color]" % name_str)
			lines.append(log_str)
			lines.append("")

	if lines.is_empty():
		quests_list.text = tr("QUEST_LOG_EMPTY")
	else:
		quests_list.text = "\n".join(lines)

	# 更新按鈕感嘆號
	_refresh_quest_button_label()


func _active_quest_ids() -> Array[String]:
	var active: Array[String] = []
	if GameState.quest_headman_intro_done \
			and not GameState.is_quest_completed("rescue_blacksmith"):
		active.append("rescue_blacksmith")
	return active


func _refresh_quest_button_label() -> void:
	if quest_button == null or not is_instance_valid(quest_button):
		return
	var has_active: bool = not _active_quest_ids().is_empty()
	quest_button.text = ("！ " if has_active else "") + tr("QUEST_BUTTON")


func _refresh_achievements_panel() -> void:
	if achievements_panel == null or achievements_list == null:
		return
	var done_count: int = 0
	for ach in GameState.ACHIEVEMENTS:
		if GameState.is_achievement_unlocked(String(ach.get("id", ""))):
			done_count += 1
	achievements_title_label.text = tr("ACHIEVEMENTS_TITLE_FMT") % [
		done_count, GameState.ACHIEVEMENTS.size()]
	achievements_close_button.text = tr("ACHIEVEMENTS_CLOSE")

	var lines: Array[String] = [tr("ACHIEVEMENTS_HINT"), ""]
	for ach in GameState.ACHIEVEMENTS:
		var ach_id: String = String(ach.get("id", ""))
		var stat: String = String(ach.get("stat", ""))
		var threshold: int = int(ach.get("threshold", 0))
		var current: int = int(floor(GameState.achievement_progress(stat)))
		var capped: int = mini(current, threshold)
		var unlocked: bool = GameState.is_achievement_unlocked(ach_id)
		var status: String = tr("ACHIEVEMENTS_DONE") if unlocked \
			else tr("ACHIEVEMENTS_PROGRESS_FMT") % [capped, threshold]
		var character_id: String = String(ach.get("character_id", ""))
		var title: String = tr(String(ach.get("title_key", "")))
		var desc: String = tr(String(ach.get("desc_key", ""))) % [
			threshold, GameData.tr_character_name(character_id)]
		var title_color: String = "#7dff9d" if unlocked else "#ffd24d"
		lines.append("[color=%s][b]%s[/b][/color]  %s" % [title_color, title, status])
		lines.append(desc)
		lines.append("")
	achievements_list.text = "\n".join(lines)


func _set_items_tab(tab_id: String) -> void:
	_items_tab = tab_id
	_refresh_items_panel()


func _refresh_items_tab_buttons() -> void:
	for tab_id in items_tab_buttons.keys():
		var btn: Button = items_tab_buttons[tab_id] as Button
		if btn == null:
			continue
		var on: bool = tab_id == _items_tab
		btn.modulate = Color(1.15, 1.12, 0.9) if on else Color(0.72, 0.76, 0.88)


func _items_lines_for_material_category(category: String, include_zero: bool) -> Array[String]:
	var lines: Array[String] = []
	for m in GameData.materials_in_category(category):
		var id: String = String(m.get("id", ""))
		var amt: int = GameState.get_material_amount(id)
		if not include_zero and amt <= 0:
			continue
		lines.append(tr("ITEMS_MATERIAL_FMT") % [GameData.tr_material_name(id), amt])
	if lines.is_empty():
		lines.append(tr("ITEMS_TAB_EMPTY"))
	return lines


func _refresh_items_panel() -> void:
	if items_panel == null or items_list == null:
		return
	items_title_label.text = tr("ITEMS_TITLE")
	items_close_button.text = tr("ITEMS_CLOSE")
	_refresh_items_tab_buttons()
	var lines: Array[String] = []
	match _items_tab:
		GameData.ITEMS_TAB_CURRENCY:
			lines.append(tr("ITEMS_GOLD_FMT") % GameState.gold)
			if GameState.is_village_facility_unlocked("farm") \
					or GameState.is_village_facility_unlocked("well"):
				lines.append("")
				lines.append(tr("ITEMS_WATER_CHARGES_FMT") % [
					GameState.water_charges, GameData.VILLAGE_WATER_MAX_CHARGES])
		GameData.ITEMS_TAB_CROPS:
			lines.append("[color=#9ddf7a][b]%s[/b][/color]" % tr("ITEMS_SECTION_HARVEST"))
			lines.append_array(_items_lines_for_material_category(
				GameData.MAT_CATEGORY_CROP, false))
			lines.append("")
			lines.append("[color=#c9e87a][b]%s[/b][/color]" % tr("ITEMS_SECTION_SEEDS"))
			lines.append_array(_items_lines_for_material_category(
				GameData.MAT_CATEGORY_SEED, false))
		GameData.ITEMS_TAB_RESOURCES:
			lines.append("[color=#9ec8ff]%s[/color]" % tr("ITEMS_RESOURCES_SOURCE_HINT"))
			lines.append("")
			lines.append_array(_items_lines_for_material_category(
				GameData.MAT_CATEGORY_RESOURCE, true))
		GameData.ITEMS_TAB_FORGING:
			lines.append_array(_items_lines_for_material_category(
				GameData.MAT_CATEGORY_FORGING, true))
		GameData.ITEMS_TAB_ARMAMENTS:
			for aid in GameState.unlocked_armaments:
				var adef: Dictionary = GameData.get_armament_def(String(aid))
				if adef.is_empty():
					continue
				lines.append(tr("ITEMS_ARMAMENT_LINE_FMT") % GameData.tr_name(adef))
			if lines.is_empty():
				lines.append(tr("ITEMS_TAB_EMPTY"))
		GameData.ITEMS_TAB_RUNES:
			lines.append(tr("ITEMS_RUNE_DUST_FMT") % GameState.rune_dust)
		_:
			lines.append(tr("ITEMS_TAB_EMPTY"))
	items_list.text = "\n".join(lines)


func _refresh_codex_panel() -> void:
	if codex_panel == null or codex_list == null:
		return
	codex_title_label.text = tr("CODEX_TITLE")
	codex_close_button.text = tr("CODEX_CLOSE")
	codex_detail_dialog.ok_button_text = tr("CODEX_DETAIL_CLOSE")
	_refresh_codex_tab_buttons()
	match _codex_tab:
		"characters":
			if codex_monsters_host:
				codex_monsters_host.visible = false
			codex_list.visible = true
			codex_list.text = _codex_characters_text()
		"weapons":
			if codex_monsters_host:
				codex_monsters_host.visible = false
			codex_list.visible = true
			codex_list.text = _codex_weapons_text()
		"abilities":
			if codex_monsters_host:
				codex_monsters_host.visible = false
			codex_list.visible = true
			codex_list.text = _codex_abilities_text()
		"armaments":
			if codex_monsters_host:
				codex_monsters_host.visible = false
			codex_list.visible = true
			codex_list.text = _codex_armaments_text()
		"monsters":
			codex_list.visible = false
			if codex_monsters_host:
				codex_monsters_host.visible = true
			_populate_codex_monsters_ui()
		_:
			_codex_tab = "characters"
			if codex_monsters_host:
				codex_monsters_host.visible = false
			codex_list.visible = true
			codex_list.text = _codex_characters_text()


func _refresh_codex_tab_buttons() -> void:
	var tab_keys: Dictionary = {
		"characters": "CODEX_TAB_CHARACTERS",
		"weapons": "CODEX_TAB_WEAPONS",
		"abilities": "CODEX_TAB_ABILITIES",
		"armaments": "CODEX_TAB_ARMAMENTS",
		"monsters": "CODEX_TAB_MONSTERS",
	}
	for tab_id in tab_keys.keys():
		var btn: Button = codex_tab_buttons.get(tab_id, null)
		if btn == null:
			continue
		btn.text = tr(String(tab_keys[tab_id]))
		btn.disabled = String(tab_id) == _codex_tab


func _codex_characters_text() -> String:
	var unlocked_count: int = 0
	for c in GameData.CHARACTERS:
		if GameState.is_character_unlocked(String(c.get("id", ""))):
			unlocked_count += 1
	var lines: Array[String] = [
		tr("CODEX_CHARACTERS_SUMMARY_FMT") % [unlocked_count, GameData.CHARACTERS.size()],
		tr("CODEX_FIRST_VERSION_NOTE"),
		"",
	]
	for c in GameData.CHARACTERS:
		var cid: String = String(c.get("id", ""))
		var unlocked: bool = GameState.is_character_unlocked(cid)
		var title_color: String = "#7dff9d" if unlocked else "#8f96aa"
		var status: String = tr("CODEX_STATUS_UNLOCKED") if unlocked else tr("CODEX_STATUS_LOCKED")
		lines.append("[color=%s][b]%s[/b][/color]  %s" % [
			title_color, GameData.tr_name(c), status])
		if unlocked:
			lines.append(tr("CODEX_CHARACTER_STATS_FMT") % [
				int(c.get("hp", 0)), int(c.get("atk", 0)), int(c.get("def", 0)),
				float(c.get("spd", 0.0))])
			lines.append(tr("CODEX_CHARACTER_START_WEAPON_FMT") % [
				GameData.tr_weapon_name(String(c.get("weapon", "")))])
			lines.append(tr("CODEX_CHARACTER_PASSIVES_FMT") % _codex_option_links(
				GameData.character_passive_options(cid), "passive"))
			lines.append(tr("CODEX_CHARACTER_SKILLS_FMT") % _codex_option_links(
				GameData.character_skill_options(cid), "skill"))
			lines.append(tr("CODEX_CHARACTER_SKIN_FMT") % _character_skin_summary(c))
			lines.append(GameData.tr_desc(c))
		else:
			lines.append(tr("CODEX_LOCKED_CHARACTER_HINT"))
		lines.append("")
	return "\n".join(lines)


func _codex_weapons_text() -> String:
	var unlocked_count: int = 0
	for w in GameData.WEAPONS:
		if GameState.is_weapon_unlocked(String(w.get("id", ""))):
			unlocked_count += 1
	var lines: Array[String] = [
		tr("CODEX_WEAPONS_SUMMARY_FMT") % [unlocked_count, GameData.WEAPONS.size()],
		tr("CODEX_WEAPON_UPGRADE_HINT"),
		"",
	]
	for w in GameData.WEAPONS:
		var wid: String = String(w.get("id", ""))
		var wdef: Dictionary = GameData.get_weapon_def(wid)
		var unlocked: bool = GameState.is_weapon_unlocked(wid)
		var title_color: String = "#7dff9d" if unlocked else "#8f96aa"
		var status: String = tr("CODEX_STATUS_UNLOCKED") if unlocked else tr("CODEX_STATUS_LOCKED")
		lines.append("%s [color=%s][b]%s[/b][/color]  %s" % [
			_codex_weapon_icon_bbcode(wdef), title_color, GameData.tr_name(wdef), status])
		if unlocked:
			lines.append(tr("CODEX_WEAPON_STATS_FMT") % [
				_codex_weapon_kind_name(String(w.get("kind", ""))),
				float(w.get("damage", 0.0)), float(w.get("rate", 0.0)),
				float(w.get("range", 0.0))])
			var crit_text: String = GameData.format_weapon_crit_text(w)
			if crit_text != "":
				lines.append(tr("CODEX_WEAPON_CRIT_PREFIX") + crit_text)
			lines.append(tr("CODEX_WEAPON_ATTACK_DETAIL_FMT") % _codex_weapon_detail_text(w))
			lines.append(tr("CODEX_WEAPON_MAX_EFFECT_FMT") % GameData.tr_max_effect(w))
			lines.append(tr("CODEX_WEAPON_UPGRADES_PREFIX"))
			for upgrade in GameData.WEAPON_UPGRADES:
				lines.append("  - %s" % _codex_weapon_upgrade_line(upgrade))
		else:
			lines.append(tr("CODEX_LOCKED_WEAPON_HINT"))
		lines.append("")
	return "\n".join(lines)


func _codex_abilities_text() -> String:
	var lines: Array[String] = [
		tr("CODEX_ABILITIES_SUMMARY_FMT") % GameData.COMMON_UPGRADES.size(),
		tr("CODEX_ICON_PLACEHOLDER_NOTE"),
		"",
	]
	for upgrade in GameData.COMMON_UPGRADES:
		lines.append("%s [color=#ffd24d][b]%s[/b][/color]" % [
			_codex_common_upgrade_icon_bbcode(upgrade), GameData.tr_name(upgrade)])
		lines.append(GameData.tr_desc(upgrade))
		lines.append(tr("CODEX_ABILITY_FIELD_FMT") % _codex_ability_field_name(
			String(upgrade.get("field", ""))))
		lines.append(tr("CODEX_ABILITY_STAGES_PREFIX"))
		for level in range(1, int(upgrade.get("max", 0)) + 1):
			lines.append("  - %s" % _codex_ability_stage_line(upgrade, level))
		lines.append("")
	return "\n".join(lines)


func _codex_armaments_text() -> String:
	var unlocked_count: int = 0
	for a in GameData.ARMAMENTS:
		var aid: String = String(a.get("id", ""))
		if aid != "none" and GameState.is_armament_unlocked(aid):
			unlocked_count += 1
	var total: int = maxi(0, GameData.ARMAMENTS.size() - 1)
	var lines: Array[String] = [
		tr("CODEX_ARMAMENTS_SUMMARY_FMT") % [unlocked_count, total],
		tr("CODEX_ICON_PLACEHOLDER_NOTE"),
		"",
		GameData.format_all_stages_armament_books_hint(),
		"",
	]
	for a in GameData.ARMAMENTS:
		var aid: String = String(a.get("id", ""))
		if aid == "none":
			continue
		var unlocked: bool = GameState.is_armament_unlocked(aid)
		var title_color: String = "#7dff9d" if unlocked else "#8f96aa"
		var status: String = tr("CODEX_STATUS_UNLOCKED") if unlocked else tr("CODEX_STATUS_LOCKED")
		lines.append("%s [color=%s][b]%s[/b][/color]  %s" % [
			_codex_icon_placeholder(), title_color, GameData.tr_name(a), status])
		if unlocked:
			lines.append(GameData.tr_desc(a))
			lines.append(_codex_armament_effect_text(a))
			lines.append(_codex_armament_cost_text(aid))
		else:
			if GameData.armament_requires_craft_book(aid) and not GameState.has_armament_recipe(aid):
				lines.append(GameData.format_armament_recipe_source_hint(aid))
			else:
				lines.append(tr("CODEX_LOCKED_ARMAMENT_HINT"))
			lines.append(_codex_armament_cost_text(aid))
		lines.append("")
	return "\n".join(lines)


func _populate_codex_monsters_ui() -> void:
	if codex_monsters_item_list == null or codex_monsters_summary == null:
		return
	codex_monsters_item_list.clear()
	codex_monsters_summary.clear()
	var defs: Array[Dictionary] = GameData.all_enemy_defs_for_codex()
	var unlocked_n: int = 0
	for d in defs:
		if GameState.is_codex_monster_unlocked(String(d.get("id", ""))):
			unlocked_n += 1
	codex_monsters_summary.append_text("[b]%s[/b]\n" % (tr("CODEX_MONSTERS_SUMMARY_FMT") % [unlocked_n, defs.size()]))
	codex_monsters_summary.append_text("%s" % tr("CODEX_MONSTERS_HINT"))
	for d in defs:
		var eid: String = String(d.get("id", ""))
		var unlocked: bool = GameState.is_codex_monster_unlocked(eid)
		var portrait: Texture2D = _codex_monster_portrait_texture(d)
		var title: String = GameData.tr_name(d)
		if not unlocked:
			title = "%s  [%s]" % [title, tr("CODEX_STATUS_LOCKED")]
		var line2: String = tr("CODEX_MONSTER_LINE_FMT") % [int(d.get("tier", 0)), _codex_monster_tags(d)]
		var idx: int = codex_monsters_item_list.add_item("%s\n%s" % [title, line2], portrait)
		codex_monsters_item_list.set_item_metadata(idx, eid)
		if not unlocked:
			codex_monsters_item_list.set_item_icon_modulate(idx, Color(0.42, 0.45, 0.52, 1.0))


func _codex_monster_portrait_texture(def: Dictionary) -> Texture2D:
	var tex_path: String = String(def.get("tex", ""))
	if tex_path == "" or not ResourceLoader.exists(tex_path):
		return null
	var tex: Texture2D = load(tex_path) as Texture2D
	if tex == null:
		return null
	var hf: int = maxi(1, int(def.get("hframes", 1)))
	var vf: int = maxi(1, int(def.get("vframes", 1)))
	var tw: int = tex.get_width()
	var th: int = tex.get_height()
	var cw: int = tw / hf
	var ch: int = th / vf
	if cw <= 0 or ch <= 0:
		return null
	var idle_fallback: int = int(def.get("anim_row_idle", 0))
	var prow: int = clampi(int(def.get("codex_portrait_row", idle_fallback)), 0, maxi(0, vf - 1))
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(0, prow * ch, cw, ch)
	at.filter_clip = true
	return at


func _on_codex_monster_item_clicked(index: int, _at_pos: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	if codex_monsters_item_list == null:
		return
	var eid: String = String(codex_monsters_item_list.get_item_metadata(index))
	_show_codex_monster_detail(GameData.get_enemy_def(eid))


func _codex_monster_tags(def: Dictionary) -> String:
	var parts: Array[String] = []
	if def.get("stage_boss", false):
		parts.append(tr("CODEX_MONSTER_TAG_STAGE_BOSS"))
	elif def.get("boss", false):
		parts.append(tr("CODEX_MONSTER_TAG_BOSS"))
	if def.get("elite", false):
		parts.append(tr("CODEX_MONSTER_TAG_ELITE"))
	if parts.is_empty():
		parts.append(tr("CODEX_MONSTER_TAG_NORMAL"))
	return " · ".join(parts)


func _show_codex_monster_detail(def: Dictionary) -> void:
	if def.is_empty() or codex_detail_dialog == null:
		return
	var eid: String = String(def.get("id", ""))
	if not GameState.is_codex_monster_unlocked(eid):
		codex_detail_dialog.title = tr("CODEX_TAB_MONSTERS")
		codex_detail_dialog.dialog_text = tr("CODEX_LOCKED_MONSTER_HINT")
		codex_detail_dialog.popup_centered()
		return
	codex_detail_dialog.title = "%s：%s" % [tr("CODEX_TAB_MONSTERS"), GameData.tr_name(def)]
	var lines: Array[String] = []
	var ddesc: String = GameData.tr_desc(def)
	if ddesc != "":
		lines.append(ddesc)
		lines.append("")
	lines.append(tr("CODEX_MONSTER_DETAIL_TIER_FMT") % int(def.get("tier", 0)))
	lines.append(tr("CODEX_MONSTER_DETAIL_TAGS_FMT") % _codex_monster_tags(def))
	lines.append(GameData.format_enemy_codex_stats_block(def))
	var ref_lv: float = GameData.enemy_codex_reference_level(def)
	var ref_st: Dictionary = GameData.compute_enemy_combat_stats(def, ref_lv)
	var defn: float = float(ref_st.get("defense", 0.0))
	if defn > 0.0001:
		lines.append(tr("CODEX_MONSTER_DETAIL_DEF_FMT") % int(round(defn * 100.0)))
	if def.get("ranged", null) is Dictionary:
		var rg: Dictionary = def["ranged"]
		var ranged_dmg: float = float(ref_st["damage"]) * float(rg.get("damage_mult", 0.75))
		if String(rg.get("kind", "line")) == "bomb":
			lines.append(tr("CODEX_MONSTER_DETAIL_BOMB_FMT") % [
				float(rg.get("range", 0.0)), float(rg.get("aoe_radius", 0.0))])
		else:
			lines.append(tr("CODEX_MONSTER_DETAIL_RANGED_FMT") % [
				float(rg.get("range", 0.0)), float(rg.get("min_range", 0.0)),
				float(rg.get("width", 0.0))])
		lines.append("%s %d" % [
			tr("CODEX_MONSTER_STAT_RANGED_DMG"), int(round(ranged_dmg))])
	if def.get("melee_aoe", null) is Dictionary:
		var ma: Dictionary = def["melee_aoe"]
		lines.append(tr("CODEX_MONSTER_DETAIL_MELEE_AOE_FMT") % [
			float(ma.get("radius", 0.0)),
			int(round(float(ma.get("damage_mult", 0.65)) * 100.0))])
	var hit_eff: Dictionary = def.get("hit_effects", {})
	if hit_eff.is_empty() and def.get("ranged", null) is Dictionary:
		var rg_eff: Variant = (def["ranged"] as Dictionary).get("hit_effects", {})
		if rg_eff is Dictionary:
			hit_eff = rg_eff
	if hit_eff.get("slow") is Dictionary:
		var sl: Dictionary = hit_eff["slow"]
		lines.append(tr("CODEX_MONSTER_HIT_SLOW_FMT") % [
			int(round(clampf(float(sl.get("factor", 0.55)), 0.15, 1.0) * 100.0)),
			float(sl.get("duration", 1.0))])
	if hit_eff.has("stun"):
		lines.append(tr("CODEX_MONSTER_HIT_STUN_FMT") % float(hit_eff["stun"]))
	if float(hit_eff.get("knockback", 0.0)) > 0.0:
		lines.append(tr("CODEX_MONSTER_HIT_KNOCKBACK_FMT"))
	if hit_eff.get("bleed") is Dictionary:
		var bl: Dictionary = hit_eff["bleed"]
		lines.append(tr("CODEX_MONSTER_HIT_BLEED_FMT") % [
			float(bl.get("dps", 2.0)), float(bl.get("duration", 2.0))])
	if def.get("summon_minions", null) is Dictionary:
		var sm: Dictionary = def["summon_minions"]
		lines.append(tr("CODEX_MONSTER_SUMMON_FMT") % [
			float(sm.get("interval", 9.0)), int(sm.get("count", 2))])
	var drop_lines: Array[String] = GameData.codex_monster_drop_lines(def)
	if not drop_lines.is_empty():
		lines.append("")
		lines.append(tr("CODEX_MONSTER_DETAIL_DROPS_TITLE"))
		for dl in drop_lines:
			lines.append(dl)
	codex_detail_dialog.dialog_text = "\n".join(lines)
	codex_detail_dialog.popup_centered()


func _codex_placeholder_text(tab_key: String) -> String:
	return "[color=#ffd24d][b]%s[/b][/color]\n%s" % [
		tr(tab_key), tr("CODEX_COMING_SOON")]


func _codex_option_links(ids: Array, kind: String) -> String:
	var names: Array[String] = []
	for raw_id in ids:
		var id: String = String(raw_id)
		names.append(_codex_option_link(id, kind))
	return " / ".join(names)


func _codex_option_link(id: String, kind: String) -> String:
	var def: Dictionary = GameData.get_passive_def(id) if kind == "passive" else GameData.get_skill_def(id)
	var icon_path: String = String(def.get("icon", ""))
	var label: String = GameData.tr_name(def)
	var icon_text: String = "[%s]" % label.substr(0, 1)
	if icon_path != "":
		icon_text = "[img]%s[/img]" % icon_path
	return "[url=%s:%s]%s %s[/url]" % [kind, id, icon_text, label]


func _codex_weapon_icon_bbcode(wdef: Dictionary) -> String:
	var path: String = String(wdef.get("icon", ""))
	if path == "":
		path = GameData.weapon_icon_path(String(wdef.get("id", "")))
	if path == "" or not ResourceLoader.exists(path):
		return _codex_icon_placeholder()
	# RichTextLabel 需指定尺寸，否則小圖可能不顯示
	return "[img=28x28]%s[/img]" % path


func _codex_common_upgrade_icon_bbcode(upgrade: Dictionary) -> String:
	var id: String = String(upgrade.get("id", ""))
	var path: String = String(GameData.get_common_upgrade_def(id).get("icon", ""))
	if path == "":
		path = GameData.common_upgrade_icon_path(id)
	if path == "" or not ResourceLoader.exists(path):
		return _codex_icon_placeholder()
	return "[img=28x28]%s[/img]" % path


func _codex_icon_placeholder() -> String:
	return "[color=#8f96aa][%s][/color]" % tr("CODEX_ICON_PLACEHOLDER")


func _codex_ability_stage_line(upgrade: Dictionary, level: int) -> String:
	var value: float = float(upgrade.get("value", 0.0)) * float(level)
	var id: String = String(upgrade.get("id", ""))
	if id == "c_regen":
		return tr("CODEX_ABILITY_STAGE_FLAT_DECIMAL_FMT") % [level, value]
	return tr("CODEX_ABILITY_STAGE_PERCENT_FMT") % [level, int(round(value * 100.0))]


func _codex_ability_field_name(field: String) -> String:
	match field:
		"hp_mult":
			return tr("CODEX_ABILITY_FIELD_HP")
		"speed_mult":
			return tr("CODEX_ABILITY_FIELD_SPEED")
		"rate_mult":
			return tr("CODEX_ABILITY_FIELD_RATE")
		"pickup_mult":
			return tr("CODEX_ABILITY_FIELD_PICKUP")
		"xp_mult":
			return tr("CODEX_ABILITY_FIELD_XP")
		"dmg_reduce":
			return tr("CODEX_ABILITY_FIELD_ARMOR")
		"regen_add":
			return tr("CODEX_ABILITY_FIELD_REGEN")
		"damage_mult":
			return tr("CODEX_ABILITY_FIELD_DAMAGE")
		"crit_chance":
			return tr("CODEX_ABILITY_FIELD_CRIT_CHANCE")
		"crit_damage_mult":
			return tr("CODEX_ABILITY_FIELD_CRIT_DAMAGE")
		_:
			return field


func _codex_armament_effect_text(a: Dictionary) -> String:
	var parts: Array[String] = []
	var weapon_id: String = String(a.get("weapon_id", ""))
	if weapon_id != "":
		parts.append(tr("CODEX_ARMAMENT_EFFECT_WEAPON_FMT") % GameData.tr_weapon_name(weapon_id))
	var cu: String = String(a.get("common_upgrade_id", ""))
	if cu != "":
		var cdef: Dictionary = GameData.get_common_upgrade_def(cu)
		if not cdef.is_empty():
			parts.append(tr("CODEX_ARMAMENT_EFFECT_COMMON_FMT") % GameData.tr_name(cdef))
	for stat_line in GameData.armament_flat_stat_parts_from_def(a):
		parts.append(stat_line)
	if parts.is_empty():
		parts.append(tr("CODEX_ARMAMENT_EFFECT_NONE"))
	return tr("CODEX_ARMAMENT_EFFECT_FMT") % " / ".join(parts)


func _codex_armament_cost_text(arm_id: String) -> String:
	var parts: Array[String] = []
	var gold_cost: int = GameState.armament_gold_cost(arm_id)
	if gold_cost > 0:
		parts.append(tr("BLACKSMITH_COST_GOLD_FMT") % gold_cost)
	for material_id in GameState.armament_material_costs(arm_id).keys():
		var mid: String = String(material_id)
		var need: int = int(GameState.armament_material_costs(arm_id)[material_id])
		parts.append(tr("CODEX_ARMAMENT_COST_MATERIAL_FMT") % [
			GameData.tr_material_name(mid), need])
	return tr("CODEX_ARMAMENT_COST_FMT") % " + ".join(parts)


func _on_codex_meta_clicked(meta: Variant) -> void:
	var raw: String = String(meta)
	var parts: PackedStringArray = raw.split(":", false, 1)
	if parts.size() != 2:
		return
	var kind: String = String(parts[0])
	var id: String = String(parts[1])
	if kind == "passive":
		_show_codex_detail(GameData.get_passive_def(id), tr("CODEX_DETAIL_PASSIVE_TITLE"))
	elif kind == "skill":
		_show_codex_detail(GameData.get_skill_def(id), tr("CODEX_DETAIL_SKILL_TITLE"))
	elif kind == "monster":
		_show_codex_monster_detail(GameData.get_enemy_def(id))


func _show_codex_detail(def: Dictionary, prefix: String) -> void:
	if def.is_empty() or codex_detail_dialog == null:
		return
	codex_detail_dialog.title = "%s：%s" % [prefix, GameData.tr_name(def)]
	var lines: Array[String] = [GameData.tr_desc(def)]
	if def.has("cooldown"):
		var cooldown: float = float(def.get("cooldown", 0.0))
		if cooldown > 0.0:
			lines.append("")
			lines.append(tr("CODEX_DETAIL_COOLDOWN_FMT") % cooldown)
	var params: Dictionary = def.get("params", {})
	if not params.is_empty():
		lines.append("")
		lines.append(tr("CODEX_DETAIL_PARAMS_TITLE"))
		for key in params.keys():
			lines.append("%s: %s" % [String(key), str(params[key])])
	codex_detail_dialog.dialog_text = "\n".join(lines)
	codex_detail_dialog.popup_centered()


func _character_skin_summary(c: Dictionary) -> String:
	if c.has("sprite_frames"):
		return tr("CODEX_SKIN_FRAME_ANIM")
	if c.has("sprite_strips") and c["sprite_strips"] is Dictionary:
		var strips: Dictionary = c["sprite_strips"]
		if strips.has("human_idle") or bool(c.get("start_transform", false)):
			return tr("CODEX_SKIN_TRANSFORM")
	return tr("CODEX_SKIN_DEFAULT")


func _codex_weapon_kind_name(kind: String) -> String:
	match kind:
		"melee_fan":
			return tr("CODEX_WEAPON_KIND_MELEE")
		"projectile":
			return tr("CODEX_WEAPON_KIND_PROJECTILE")
		"orbit":
			return tr("CODEX_WEAPON_KIND_ORBIT")
		"aura":
			return tr("CODEX_WEAPON_KIND_AURA")
		"puddle":
			return tr("CODEX_WEAPON_KIND_PUDDLE")
		"axe":
			return tr("CODEX_WEAPON_KIND_AXE")
		_:
			return kind


func _codex_weapon_detail_text(w: Dictionary) -> String:
	var wid: String = String(w.get("id", ""))
	var kind: String = String(w.get("kind", ""))
	var params: Dictionary = w.get("params", {})
	match wid:
		"sword":
			return tr("CODEX_WEAPON_DETAIL_SWORD_FMT") % [
				float(params.get("angle_deg", 0.0)), float(w.get("range", 0.0))]
		"spear":
			return tr("CODEX_WEAPON_DETAIL_SPEAR_FMT") % [
				float(params.get("angle_deg", 0.0)), float(w.get("range", 0.0))]
		"axe":
			return tr("CODEX_WEAPON_DETAIL_AXE_FMT") % [
				float(params.get("hit_radius", 0.0)), float(params.get("throw_distance", 0.0))]
		"magic_bullet":
			return tr("CODEX_WEAPON_DETAIL_MAGIC_BULLET_FMT") % [
				int(params.get("count", 1)), float(params.get("explode_radius", 0.0))]
		"bow":
			return tr("CODEX_WEAPON_DETAIL_BOW_FMT") % [
				int(params.get("count", 1)), float(params.get("spread_deg", 0.0))]
		"melody":
			return tr("CODEX_WEAPON_DETAIL_MELODY_FMT") % int(params.get("count", 1))
		"claw":
			return tr("CODEX_WEAPON_DETAIL_CLAW_FMT") % float(params.get("angle_deg", 0.0))
		"shard":
			return tr("CODEX_WEAPON_DETAIL_SHARD_FMT") % [
				int(params.get("count", 1)), float(params.get("spin_speed", 0.0))]
		"flame":
			return tr("CODEX_WEAPON_DETAIL_FLAME")
		"lightning":
			return tr("CODEX_WEAPON_DETAIL_LIGHTNING_FMT") % int(params.get("chain", 0))
		"ice":
			return tr("CODEX_WEAPON_DETAIL_ICE")
		"poison":
			return tr("CODEX_WEAPON_DETAIL_POISON_FMT") % [
				float(params.get("puddle_radius", 0.0)), float(params.get("lifetime", 0.0)),
				int(round(GameData.ENEMY_STATUS_POISON_ATK_REDUCE * 100.0))]
		"holy":
			return tr("CODEX_WEAPON_DETAIL_HOLY")
	match kind:
		"projectile":
			return tr("CODEX_WEAPON_DETAIL_PROJECTILE")
		"aura":
			return tr("CODEX_WEAPON_DETAIL_AURA")
		"puddle":
			return tr("CODEX_WEAPON_DETAIL_PUDDLE")
		_:
			return tr("CODEX_WEAPON_DETAIL_GENERIC")


func _codex_weapon_upgrade_line(upgrade: Dictionary) -> String:
	return tr("CODEX_WEAPON_UPGRADE_LINE_FMT") % [
		GameData.tr_name(upgrade), int(upgrade.get("max", 0)),
		_codex_upgrade_value_text(upgrade)]


func _codex_upgrade_value_text(upgrade: Dictionary) -> String:
	var id: String = String(upgrade.get("id", ""))
	var value: float = float(upgrade.get("value", 0.0))
	if id == "w_count":
		return tr("CODEX_UPGRADE_VALUE_FLAT_FMT") % int(value)
	return tr("CODEX_UPGRADE_VALUE_PERCENT_FMT") % int(round(value * 100.0))


func _on_touch_toggled(pressed: bool) -> void:
	if is_instance_valid(GameState):
		GameState.set_touch_controls_enabled(pressed)


func _reset_all_debug_button_texts() -> void:
	unlock_all_button.text = tr("SETTINGS_UNLOCK_ALL")
	unlock_weapons_button.text = tr("SETTINGS_UNLOCK_WEAPONS")
	if unlock_armaments_button != null:
		unlock_armaments_button.text = tr("SETTINGS_UNLOCK_ARMAMENTS")
	if unlock_monsters_button != null:
		unlock_monsters_button.text = tr("SETTINGS_UNLOCK_MONSTERS")
	if unlock_village_button != null:
		unlock_village_button.text = tr("SETTINGS_UNLOCK_VILLAGE")
	add_gold_button.text = tr("SETTINGS_ADD_GOLD")
	max_team_weapons_button.text = tr("SETTINGS_MAX_TEAM_WEAPONS")
	reset_account_button.text = tr("SETTINGS_RESET_ACCOUNT")


func _on_unlock_village_pressed() -> void:
	if not is_instance_valid(GameState):
		return
	GameState.unlock_all_village_npcs_and_facilities()
	_reset_confirm_armed = false
	_reset_all_debug_button_texts()
	if unlock_village_button != null:
		unlock_village_button.text = tr("SETTINGS_UNLOCK_VILLAGE_DONE")
	_notify_current_scene_account_changed()


func _on_unlock_all_pressed() -> void:
	if not is_instance_valid(GameState):
		return
	GameState.unlock_all_characters()
	_reset_confirm_armed = false
	_reset_all_debug_button_texts()
	unlock_all_button.text = tr("SETTINGS_UNLOCK_ALL_DONE")
	_notify_current_scene_account_changed()


func _on_unlock_weapons_pressed() -> void:
	if not is_instance_valid(GameState):
		return
	GameState.unlock_all_weapons_and_slots()
	_reset_confirm_armed = false
	_reset_all_debug_button_texts()
	unlock_weapons_button.text = tr("SETTINGS_UNLOCK_WEAPONS_DONE")
	_notify_current_scene_account_changed()


func _on_unlock_armaments_pressed() -> void:
	if not is_instance_valid(GameState):
		return
	GameState.unlock_all_armaments()
	_reset_confirm_armed = false
	_reset_all_debug_button_texts()
	if unlock_armaments_button != null:
		unlock_armaments_button.text = tr("SETTINGS_UNLOCK_ARMAMENTS_DONE")
	_notify_current_scene_account_changed()


func _on_unlock_monsters_pressed() -> void:
	if not is_instance_valid(GameState):
		return
	GameState.unlock_all_codex_monsters()
	_reset_confirm_armed = false
	_reset_all_debug_button_texts()
	if unlock_monsters_button != null:
		unlock_monsters_button.text = tr("SETTINGS_UNLOCK_MONSTERS_DONE")
	_notify_current_scene_account_changed()
	if _codex_open and _codex_tab == "monsters":
		_refresh_codex_panel()


func _on_add_gold_pressed() -> void:
	if not is_instance_valid(GameState):
		return
	GameState.gold += 5000
	GameState.save_to_disk()
	_reset_confirm_armed = false
	_reset_all_debug_button_texts()
	_refresh_from_state()
	_notify_current_scene_account_changed()


func _on_max_team_weapons_pressed() -> void:
	var changed: bool = false
	for p in get_tree().get_nodes_in_group("players"):
		if p == null or not is_instance_valid(p):
			continue
		var weapons: Array = p.get("weapons")
		for w in weapons:
			if not (w is Dictionary):
				continue
			for u in GameData.WEAPON_UPGRADES:
				w["upgrades"][String(u["id"])] = int(u["max"])
			w["level"] = 1 + _weapon_upgrade_total(w["upgrades"])
			if w.get("node", null) != null:
				w["node"].refresh()
			changed = true
	_reset_confirm_armed = false
	_reset_all_debug_button_texts()
	max_team_weapons_button.text = tr("SETTINGS_MAX_TEAM_WEAPONS_DONE") if changed \
		else tr("SETTINGS_MAX_TEAM_WEAPONS_NONE")
	_notify_current_scene_account_changed()


func _weapon_upgrade_total(upgrades: Dictionary) -> int:
	var total: int = 0
	for u in GameData.WEAPON_UPGRADES:
		total += int(upgrades.get(String(u["id"]), 0))
	return total


func _on_reset_account_pressed() -> void:
	if not _reset_confirm_armed:
		_reset_confirm_armed = true
		_refresh_from_state()
		return
	if not is_instance_valid(GameState):
		return
	GameState.reset_account()
	_reset_confirm_armed = false
	_refresh_from_state()
	_notify_current_scene_account_changed()


func _notify_current_scene_account_changed() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	if scene.has_method("_refresh_meta"):
		scene.call("_refresh_meta")
	if scene.has_method("_update_panels"):
		scene.call("_update_panels")
