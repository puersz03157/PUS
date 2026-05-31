extends Node2D
## 村莊場景：載入 New Village.tmx，玩家可自由走動，無敵人、無武器。
## ESC 開啟離開村莊選單。

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const HousePreviewAnimT := preload("res://scripts/ui/house_preview_anim.gd")
const PinballPatternPreviewT := preload("res://scripts/ui/pinball_pattern_preview.gd")
const RESCUE_NPC_TEXTURE := preload("res://assets/characters/GandalfHardcore/Save NPC.png")
const VILLAGE_NPC_ANIM_SCRIPT := preload("res://scripts/village_npc_anim.gd")
const VILLAGE_NPC_SPRITE_HEIGHT := 72.0
## 標記根節點相對 floor_y（愈小＝整體愈高）；原 -42，略抬高腳底接線
const VILLAGE_NPC_ROOT_Y_OFFSET := -54.0
## 腳底在標記根節點下的 local Y（與玩家 floor_y 對齊用）
const VILLAGE_NPC_FEET_ANCHOR_Y := 42.0
const VILLAGE_NPC_FEET_FINE_Y := -6.0
const VILLAGE_NPC_LABEL_Y := -62.0
const VILLAGE_NPC_TITLE_WITH_SUBTITLE_Y := -76.0
const VILLAGE_NPC_SUBTITLE_Y := -58.0
const VILLAGE_TALK_NPC_RADIUS := 90.0
const CAMERA_ZOOM := Vector2(2.0, 2.0)
const BLACKSMITH_INTERACT_RADIUS := 90.0
const MERCHANT_INTERACT_RADIUS := 90.0
const VILLAGE_FACILITY_INTERACT_RADIUS := 90.0
const P1_HOUSE_INTERACT_RADIUS := 100.0
const HOUSE_DIALOG_DIM_ALPHA := 0.58
const HOUSE_SUB_DIALOG_DIM_ALPHA := 0.78
const ENTRANCE_INTERACT_RADIUS := 96.0
const TAVERN_DOOR_INTERACT_RADIUS := 96.0
const TAVERN_EXIT_INTERACT_RADIUS := 88.0
const TAVERN_STAIR_INTERACT_RADIUS := 80.0
const TAVERN_STAIR_LAND_X_OFFSET := 40.0
const CROP_PLOT_INTERACT_RADIUS := 72.0
const WELL_INTERACT_RADIUS := 88.0
const FARMER_INTERACT_RADIUS := 90.0
const VILLAGE_TOUCH_BTN_SIZE := Vector2(78.0, 56.0)

# 時間流轉
const VILLAGE_TIME_DAY_DURATION := 240.0      # 4 分鐘白天
const VILLAGE_TIME_EVENING_DURATION := 120.0  # 2 分鐘傍晚
const VILLAGE_TIME_NIGHT_DURATION := 120.0    # 2 分鐘夜晚
const VILLAGE_TIME_CYCLE := 480.0             # 完整循環 8 分鐘

const Coop := preload("res://scripts/coop_pair_follow.gd")
const CoopPointerOverlay := preload("res://scripts/coop_pointer_overlay.gd")
const VillageSummonFollowerT := preload("res://scripts/village_summon_follower.gd")
const InputPrompt := preload("res://scripts/input_prompt.gd")
const BlockingNotice := preload("res://scripts/blocking_notice.gd")

@onready var camera: Camera2D = $Camera
@onready var hud: CanvasLayer = $HUD
@onready var background: DrawerNode2D = $Background
@onready var pause_panel: Panel = $HUD/PausePanel
@onready var pause_resume_btn: Button = $HUD/PausePanel/Resume
@onready var pause_leave_btn: Button = $HUD/PausePanel/Leave
@onready var pause_dim: ColorRect = $HUD/PauseDim
@onready var hint_label: Label = $HUD/Hint

var players: Array = []
var map_node: Node = null
var _map_size: Vector2 = GameData.village_map_pixel_size()
var _map_scale: float = GameData.VILLAGE_MAP_SCALE
var _current_location: String = "village"
var spawn_origin: Vector2 = Vector2.ZERO
var tile_size: int = 16
var blocked_tiles: Dictionary = {}
# 玩家「腳底」的世界 Y 座標；走出地圖時固定在這條線上
var floor_y: float = 0.0
# 左側 Obstacle 物件框右緣（可走區下限）
var _map_walk_min_x: float = 8.0
var _tavern_door_node = null
var _tavern_exit_node = null
var _tavern_stair_up_node = null
var _tavern_stair_down_node = null
var _tavern_floor: int = 1
var _tavern_floor_1_y: float = 0.0
var _tavern_floor_2_y: float = 0.0
var _tavern_permanent_npc_nodes: Dictionary = {}
var _tavern_social_npc_nodes: Dictionary = {}

var _pause_open: bool = false
var _transitioning: bool = false
var _coop_pointer_overlay: Control = null
var _blacksmith_node = null
var _merchant_node = null
var _blacksmith_dialog: CanvasLayer = null
var _smith_status_label: Label = null
var _smith_gold_label: RichTextLabel = null
var _smith_resource_tip: Label = null
var _smith_dialog_panel: PanelContainer = null
var _smith_suppress_craft_press: bool = false
const _BLACKSMITH_BTN_LABEL := "CraftLabel"
var _merchant_dialog: CanvasLayer = null
var _rune_master_node = null
var _rune_master_dialog: CanvasLayer = null
var _rune_master_status_label: Label = null
var _rune_master_dust_label: Label = null
var _entrance_node = null
var _p1_house_node = null
var _p2_house_node = null
var _expedition_dialog: CanvasLayer = null
var _p2_join_dialog: CanvasLayer = null
var _p2_leave_dialog: CanvasLayer = null
var _house_dialog: CanvasLayer = null
var _house_appearance_dialog: CanvasLayer = null
var _house_favorites_dialog: CanvasLayer = null
var _house_summons_dialog: CanvasLayer = null
var _house_pinball_bg_dialog: CanvasLayer = null
var _house_player_slot: String = "p1"
var _house_status_label: RichTextLabel = null
var _house_char_index: int = 0
var _house_weapon_index: int = 0
var _house_suppress_ui: bool = false
var _house_preview: HousePreviewAnimT = null
var _house_weapon_preview: HousePreviewAnimT = null
var _house_char_name_label: Label = null
var _house_weapon_name_label: Label = null
var _house_skin_option: OptionButton = null
var _house_weapon_skin_lbl: Label = null
var _house_bow_skin_option: OptionButton = null
var _house_weapon_visual_section: VBoxContainer = null
var _house_appearance_char_idle_preview: HousePreviewAnimT = null
var _house_appearance_char_walk_preview: HousePreviewAnimT = null
var _house_appearance_char_attack_preview: HousePreviewAnimT = null
var _house_appearance_weapon_hit_preview: HousePreviewAnimT = null
var _house_appearance_weapon_projectile_preview: HousePreviewAnimT = null
var _house_appearance_weapon_extra_preview: HousePreviewAnimT = null
var _house_appearance_char_name_label: Label = null
var _house_appearance_weapon_name_label: Label = null
var _house_fav_title: Label = null
var _house_fav_grid: GridContainer = null
var _house_favorite_option_buttons: Array[OptionButton] = []
var _house_summon_slot_ui: Array[Dictionary] = []
var _house_summon_desc_label: RichTextLabel = null
var _house_summon_feed_btn: Button = null
var _house_summon_focus_slot: int = 0
var _headman_starter_dialog: CanvasLayer = null
var _headman_starter_idx: int = 0
var _headman_starter_name_label: Label = null
var _headman_starter_desc_label: Label = null
var _headman_starter_preview: HousePreviewAnimT = null
var _house_pinball_bg_preview: Control = null
var _house_pinball_bg_name_label: Label = null
var _house_pinball_bg_status_label: Label = null
var _house_pinball_bg_category_label: Label = null
var _house_ui_bg_context_idx: int = 0
var _merchant_status_label: Label = null
var _merchant_gold_label: Label = null
var _merchant_inventory_label: RichTextLabel = null
var _facility_nodes: Dictionary = {}
var _facility_dialog: CanvasLayer = null
var _facility_dialog_id: String = ""
var _facility_status_label: Label = null
var _touch_controls_root: Control = null
var _touch_left_button: Button = null
var _touch_right_button: Button = null
var _touch_jump_button: Button = null
var _touch_interact_button: Button = null
var _touch_menu_button: Button = null
var _float_prompt_layer: Control = null
var _float_prompt_panel: PanelContainer = null
var _float_prompt_box: VBoxContainer = null
var _float_prompt_target = null
var _well_node = null
var _farmer_shop_node = null
var _crop_plot_nodes: Dictionary = {}
var _well_dialog: CanvasLayer = null
var _farmer_dialog: CanvasLayer = null
var _crop_dialog: CanvasLayer = null
var _crop_dialog_slot: int = 0
var _always_npc_nodes: Dictionary = {}
var _talk_dialog: CanvasLayer = null
var _quest_marker_layer: CanvasLayer = null
var _quest_marker_labels: Dictionary = {}
# 序列對話狀態
var _seq_pages: Array[String] = []
var _seq_page_idx: int = 0
var _seq_on_finish: Callable = Callable()
var _seq_text_label: Label = null
var _seq_next_btn: Button = null
var _village_time_sec: float = 0.0
var _village_time_phase: String = "day"
var _sky_overlay: ColorRect = null
var _time_label: Label = null
var _battle_summary_layer: CanvasLayer = null
var _summon_milestone_layer: CanvasLayer = null
# 所有「只在白天出現」的功能性 NPC 節點（傍晚/夜晚隱藏且無法互動）
var _timed_npc_nodes: Array = []
var _summon_followers: Array = []


func _ready() -> void:
	# 自身永遠處理（讓暫停時 ESC 仍能被偵測）；玩家會被個別設為 PAUSABLE
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 2P 僅在主選單進村時由 prepare_enter_village() 重置；出征返回村莊時保留
	camera.make_current()
	_setup_village_exterior()
	_spawn_players()
	_refresh_village_summon_followers()
	_spawn_quest_markers()
	_position_camera()
	if GameState.two_players and players.size() >= 2:
		_coop_pointer_overlay = CoopPointerOverlay.new()
		_coop_pointer_overlay.setup(self)
		hud.add_child(_coop_pointer_overlay)
	_draw_background()
	_setup_hud()
	_setup_village_clock()
	call_deferred("_try_show_pending_battle_summary")


func _try_show_pending_battle_summary() -> void:
	if SummonMilestoneOverlay.has_pending():
		call_deferred("_try_show_pending_summon_milestones")
		return
	if not BattleRunSummaryOverlay.has_pending():
		return
	if _battle_summary_layer != null and is_instance_valid(_battle_summary_layer):
		return
	_battle_summary_layer = BattleRunSummaryOverlay.present(get_tree(), true)


func _try_show_pending_summon_milestones() -> void:
	if not SummonMilestoneOverlay.has_pending():
		if BattleRunSummaryOverlay.has_pending():
			call_deferred("_try_show_pending_battle_summary")
		return
	if _summon_milestone_layer != null and is_instance_valid(_summon_milestone_layer):
		return
	_summon_milestone_layer = SummonMilestoneOverlay.present_next(get_tree())
	if _summon_milestone_layer == null:
		_refresh_village_summon_followers()
		call_deferred("_try_show_pending_summon_milestones")
		return
	_watch_summon_milestone_layer()


func _watch_summon_milestone_layer() -> void:
	while _summon_milestone_layer != null and is_instance_valid(_summon_milestone_layer):
		await get_tree().process_frame
	_summon_milestone_layer = null
	_refresh_village_summon_followers()
	call_deferred("_try_show_pending_summon_milestones")


func _dismiss_battle_summary() -> void:
	if _battle_summary_layer == null:
		return
	BattleRunSummaryOverlay.dismiss(_battle_summary_layer)
	_battle_summary_layer = null


func _setup_hud() -> void:
	# 暫停選單預設關閉，自身與背景遮罩都用 PROCESS_MODE_ALWAYS
	# 讓在暫停狀態下還能互動
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_dim.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_resume_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_leave_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_panel.visible = false
	pause_dim.visible = false
	pause_dim.color = Color(0, 0, 0, 0.55)
	pause_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_dim.anchor_right = 1.0
	pause_dim.anchor_bottom = 1.0
	pause_dim.offset_right = 0.0
	pause_dim.offset_bottom = 0.0
	var pause_sb := StyleBoxFlat.new()
	pause_sb.bg_color = Color(0.06, 0.08, 0.18, 0.08)
	pause_sb.border_color = Color(0.52, 0.6, 0.76, 0.88)
	pause_sb.border_width_left = 2
	pause_sb.border_width_right = 2
	pause_sb.border_width_top = 2
	pause_sb.border_width_bottom = 2
	pause_sb.corner_radius_top_left = 10
	pause_sb.corner_radius_top_right = 10
	pause_sb.corner_radius_bottom_left = 10
	pause_sb.corner_radius_bottom_right = 10
	pause_panel.add_theme_stylebox_override("panel", pause_sb)
	pause_panel.clip_contents = true
	GameData.attach_ui_pattern_to_panel(
		pause_panel, GameData.UI_PATTERN_STYLE_PANEL, GameData.UI_BG_CTX_PANEL)
	pause_resume_btn.pressed.connect(_close_pause)
	pause_leave_btn.pressed.connect(_leave_village)
	hint_label.text = tr("VILLAGE_HINT")
	_build_village_touch_controls()
	_build_float_interact_prompt()
	get_viewport().size_changed.connect(_layout_village_touch_controls)


func _input(event: InputEvent) -> void:
	InputPrompt.note_event(event)


func _process(_delta: float) -> void:
	if _transitioning:
		return
	if Input.is_action_just_pressed("ui_back"):
		if _battle_summary_layer != null and is_instance_valid(_battle_summary_layer):
			AudioManager.play_sfx("ui_back")
			_dismiss_battle_summary()
			return
		if _blacksmith_dialog != null:
			_close_blacksmith_dialog()
			return
		if _merchant_dialog != null:
			_close_merchant_dialog()
			return
		if _rune_master_dialog != null:
			_close_rune_master_dialog()
			return
		if _facility_dialog != null:
			_close_facility_dialog()
			return
		if _house_favorites_dialog != null:
			_close_house_favorites_dialog()
			return
		if _house_summons_dialog != null:
			_close_house_summons_dialog()
			return
		if _house_pinball_bg_dialog != null:
			_close_house_pinball_bg_dialog()
			return
		if _house_appearance_dialog != null:
			_close_house_appearance_dialog()
			return
		if _house_dialog != null:
			_close_house_dialog()
			return
		if _well_dialog != null:
			_close_well_dialog()
			return
		if _farmer_dialog != null:
			_close_farmer_dialog()
			return
		if _crop_dialog != null:
			_close_crop_dialog()
			return
		if _talk_dialog != null:
			_close_talk_dialog()
			return
		if _expedition_dialog != null:
			_close_expedition_dialog()
			return
		if _p2_join_dialog != null:
			_close_p2_join_dialog()
			return
		if _p2_leave_dialog != null:
			_close_p2_leave_dialog()
			return
		if _pause_open:
			_close_pause()
		else:
			_open_pause()
		return
	_update_npc_interactions()
	_refresh_village_touch_visibility()
	_position_camera()
	_position_float_interact_prompt()
	_update_village_time(_delta)
	_update_quest_marker_positions()


func _build_village_touch_controls() -> void:
	if _touch_controls_root != null:
		return
	_touch_controls_root = Control.new()
	_touch_controls_root.name = "VillageTouchControls"
	_touch_controls_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_touch_controls_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_touch_controls_root.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(_touch_controls_root)

	_touch_left_button = _make_village_touch_button(tr("VILLAGE_TOUCH_LEFT"))
	_touch_left_button.button_down.connect(func() -> void: Input.action_press("p1_left"))
	_touch_left_button.button_up.connect(func() -> void: Input.action_release("p1_left"))
	_touch_controls_root.add_child(_touch_left_button)

	_touch_right_button = _make_village_touch_button(tr("VILLAGE_TOUCH_RIGHT"))
	_touch_right_button.button_down.connect(func() -> void: Input.action_press("p1_right"))
	_touch_right_button.button_up.connect(func() -> void: Input.action_release("p1_right"))
	_touch_controls_root.add_child(_touch_right_button)

	_touch_jump_button = _make_village_touch_button(tr("VILLAGE_TOUCH_JUMP"))
	_touch_jump_button.button_down.connect(func() -> void: Input.action_press("p1_up"))
	_touch_jump_button.button_up.connect(func() -> void: Input.action_release("p1_up"))
	_touch_controls_root.add_child(_touch_jump_button)

	_touch_interact_button = _make_village_touch_button(tr("VILLAGE_TOUCH_INTERACT"))
	_touch_interact_button.pressed.connect(_on_touch_interact_pressed)
	_touch_controls_root.add_child(_touch_interact_button)

	_touch_menu_button = _make_village_touch_button(tr("VILLAGE_TOUCH_MENU"))
	_touch_menu_button.pressed.connect(_open_pause)
	_touch_controls_root.add_child(_touch_menu_button)
	_layout_village_touch_controls()
	_refresh_village_touch_visibility()


func _make_village_touch_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = VILLAGE_TOUCH_BTN_SIZE
	btn.size = VILLAGE_TOUCH_BTN_SIZE
	btn.focus_mode = Control.FOCUS_NONE
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.add_theme_font_size_override("font_size", 18)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.15, 0.72)
	sb.border_color = Color(0.95, 0.65, 0.18, 0.9)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", sb)
	return btn


func _layout_village_touch_controls() -> void:
	if _touch_controls_root == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var bottom_y: float = vp.y - VILLAGE_TOUCH_BTN_SIZE.y - 24.0
	_touch_left_button.position = Vector2(24.0, bottom_y)
	_touch_right_button.position = Vector2(24.0 + VILLAGE_TOUCH_BTN_SIZE.x + 12.0, bottom_y)
	_touch_interact_button.position = Vector2(vp.x - VILLAGE_TOUCH_BTN_SIZE.x - 24.0, bottom_y)
	_touch_jump_button.position = Vector2(vp.x - VILLAGE_TOUCH_BTN_SIZE.x * 2.0 - 36.0, bottom_y)
	_touch_menu_button.position = Vector2(vp.x - VILLAGE_TOUCH_BTN_SIZE.x - 24.0, bottom_y - VILLAGE_TOUCH_BTN_SIZE.y - 12.0)


func _build_float_interact_prompt() -> void:
	if _float_prompt_layer != null:
		return
	_float_prompt_layer = Control.new()
	_float_prompt_layer.name = "InteractFloatPrompt"
	_float_prompt_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_prompt_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(_float_prompt_layer)
	_float_prompt_panel = PanelContainer.new()
	_float_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.14, 0.88)
	sb.border_color = Color(1.0, 0.88, 0.42, 0.95)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_float_prompt_panel.add_theme_stylebox_override("panel", sb)
	_float_prompt_layer.add_child(_float_prompt_panel)
	_float_prompt_box = VBoxContainer.new()
	_float_prompt_box.add_theme_constant_override("separation", 4)
	_float_prompt_panel.add_child(_float_prompt_box)
	_float_prompt_layer.visible = false


func _refresh_village_touch_visibility() -> void:
	if _touch_controls_root == null:
		return
	var show: bool = bool(GameState.touch_controls_enabled) and not _transitioning \
		and not _pause_open and _blacksmith_dialog == null and _merchant_dialog == null \
		and _rune_master_dialog == null \
		and _facility_dialog == null and _house_dialog == null \
		and _well_dialog == null and _farmer_dialog == null and _crop_dialog == null \
		and _talk_dialog == null and _expedition_dialog == null \
		and _p2_join_dialog == null and _p2_leave_dialog == null
	if _touch_controls_root.visible != show and not show:
		_release_village_touch_actions()
	_touch_controls_root.visible = show


func _release_village_touch_actions() -> void:
	for action in ["p1_left", "p1_right", "p1_up"]:
		Input.action_release(action)


func _on_touch_interact_pressed() -> void:
	if _pause_open or _blacksmith_dialog != null or _merchant_dialog != null \
			or _rune_master_dialog != null \
			or _facility_dialog != null or _house_dialog != null \
			or _well_dialog != null or _farmer_dialog != null or _crop_dialog != null \
			or _talk_dialog != null or _expedition_dialog != null \
			or _p2_join_dialog != null or _p2_leave_dialog != null:
		return
	if _try_open_nearest_crop_dialog():
		pass
	elif _players_near_node(_well_node, WELL_INTERACT_RADIUS):
		_open_well_dialog()
	elif _players_near_node(_farmer_shop_node, FARMER_INTERACT_RADIUS):
		_open_farmer_dialog()
	elif _blacksmith_node != null and _blacksmith_node.visible and _players_near_node(_blacksmith_node, BLACKSMITH_INTERACT_RADIUS):
		_open_blacksmith_dialog()
	elif _merchant_node != null and _merchant_node.visible and _players_near_node(_merchant_node, MERCHANT_INTERACT_RADIUS):
		_open_merchant_dialog()
	elif _rune_master_node != null and _rune_master_node.visible \
			and _players_near_node(_rune_master_node, BLACKSMITH_INTERACT_RADIUS):
		_open_rune_master_dialog()
	elif _try_open_nearest_tavern_talk():
		pass
	elif _try_open_nearest_always_npc_talk():
		pass
	elif _try_open_nearest_facility_dialog():
		pass
	elif not _is_in_tavern() and _players_near_node(_tavern_door_node, TAVERN_DOOR_INTERACT_RADIUS):
		if GameData.is_tavern_open_for_entry(_village_time_phase):
			_enter_tavern()
		else:
			_show_tavern_closed_notice()
	elif not _is_in_tavern() and _players_near_node(_entrance_node, ENTRANCE_INTERACT_RADIUS):
		_open_expedition_dialog()
	elif _is_in_tavern() and _tavern_floor == 1 \
			and _players_near_node(_tavern_stair_up_node, TAVERN_STAIR_INTERACT_RADIUS):
		_tavern_go_upstairs()
	elif _is_in_tavern() and _tavern_floor == 2 \
			and _players_near_node(_tavern_stair_down_node, TAVERN_STAIR_INTERACT_RADIUS):
		_tavern_go_downstairs()
	elif _is_in_tavern() and _tavern_floor == 1 \
			and _players_near_node(_tavern_exit_node, TAVERN_EXIT_INTERACT_RADIUS):
		_exit_tavern()
	elif _player_near_node(_p1_house_node, P1_HOUSE_INTERACT_RADIUS, "p1"):
		_open_house_dialog("p1")
	elif _players_near_node(_p2_house_node, P1_HOUSE_INTERACT_RADIUS):
		_try_open_p2_house_site_interaction()


func _open_pause() -> void:
	_pause_open = true
	pause_dim.visible = true
	pause_panel.visible = true
	pause_resume_btn.grab_focus()
	get_tree().paused = true


func _close_pause() -> void:
	_pause_open = false
	pause_dim.visible = false
	pause_panel.visible = false
	get_tree().paused = false


func _refresh_meta() -> void:
	if _house_summons_dialog != null:
		_refresh_house_summons_panel("")
	_refresh_village_summon_followers()


func _leave_village() -> void:
	if _transitioning:
		return
	_transitioning = true
	get_tree().paused = false
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/Main.tscn")


# ---------------- 地圖 ----------------
func _is_in_tavern() -> bool:
	return _current_location == "tavern"


func _setup_village_exterior() -> void:
	_current_location = "village"
	_spawn_map(
		GameData.VILLAGE_MAP_PATH,
		GameData.VILLAGE_MAP_TILES,
		GameData.VILLAGE_MAP_TILE_PX,
		GameData.VILLAGE_MAP_SCALE,
		GameData.village_map_pixel_size(),
		true,
	)
	_spawn_blacksmith_if_rescued()
	_spawn_merchant_if_rescued()
	_spawn_village_always_npcs()
	_spawn_rescued_story_npcs()
	_spawn_village_facilities()
	_spawn_farm_and_well_nodes()
	_spawn_p1_house_marker()
	_spawn_p2_house_marker()
	_spawn_entrance_marker()
	_spawn_tavern_door_marker()
	_apply_village_npc_schedule()
	if hint_label:
		hint_label.text = tr("VILLAGE_HINT")
	_refresh_quest_markers()


func _setup_tavern_interior() -> void:
	_current_location = "tavern"
	_spawn_map(
		GameData.TAVERN_MAP_PATH,
		GameData.TAVERN_MAP_TILES,
		GameData.TAVERN_MAP_TILE_PX,
		GameData.TAVERN_MAP_SCALE,
		GameData.tavern_map_pixel_size(),
		false,
	)
	_cache_tavern_floor_heights()
	_tavern_floor = 1
	_apply_tavern_floor(1, false)
	_spawn_tavern_exit_marker()
	_spawn_tavern_stair_markers()
	_spawn_tavern_permanent_npcs()
	_refresh_tavern_social_npcs()
	_refresh_tavern_interior_npc_visibility()
	_refresh_tavern_hud_hint()
	_refresh_quest_markers()


func _unload_active_map() -> void:
	if map_node != null and is_instance_valid(map_node):
		remove_child(map_node)
		map_node.free()
	map_node = null
	blocked_tiles.clear()


func _clear_village_exterior_markers() -> void:
	_hide_float_interact_prompt()
	for n in _timed_npc_nodes:
		_release_node(n)
	_timed_npc_nodes.clear()
	for npc_id in _always_npc_nodes.keys():
		_release_node(_always_npc_nodes[npc_id])
	_always_npc_nodes.clear()
	for fid in _facility_nodes.keys():
		_release_node(_facility_nodes[fid])
	_facility_nodes.clear()
	for slot_key in _crop_plot_nodes.keys():
		_release_node(_crop_plot_nodes[slot_key])
	_crop_plot_nodes.clear()
	_release_node(_blacksmith_node)
	_release_node(_merchant_node)
	_release_node(_rune_master_node)
	_release_node(_entrance_node)
	_release_node(_p1_house_node)
	_release_node(_p2_house_node)
	_release_node(_tavern_door_node)
	_release_node(_well_node)
	_release_node(_farmer_shop_node)
	_blacksmith_node = null
	_merchant_node = null
	_rune_master_node = null
	_entrance_node = null
	_p1_house_node = null
	_p2_house_node = null
	_tavern_door_node = null
	_well_node = null
	_farmer_shop_node = null


func _clear_tavern_interior_markers() -> void:
	_hide_float_interact_prompt()
	_clear_tavern_social_npcs()
	_clear_tavern_permanent_npcs()
	_release_node(_tavern_exit_node)
	_release_node(_tavern_stair_up_node)
	_release_node(_tavern_stair_down_node)
	_tavern_exit_node = null
	_tavern_stair_up_node = null
	_tavern_stair_down_node = null
	_tavern_floor = 1


func _release_node(node) -> void:
	if node != null and is_instance_valid(node):
		node.free()


func _prune_invalid_tavern_social_nodes() -> void:
	for npc_id in _tavern_social_npc_nodes.keys():
		var n = _tavern_social_npc_nodes[npc_id]
		if n == null or not is_instance_valid(n):
			_tavern_social_npc_nodes.erase(npc_id)


func _spawn_map(
		map_path: String,
		tiles: Vector2i,
		tile_px: int,
		map_scale: float,
		map_size: Vector2,
		use_village_entrance: bool,
) -> void:
	_unload_active_map()
	_map_scale = map_scale
	_map_size = map_size
	_map_walk_min_x = 8.0
	camera.zoom = CAMERA_ZOOM
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(_map_size.x)
	camera.limit_bottom = int(_map_size.y)
	tile_size = int(round(float(tile_px) * _map_scale))
	floor_y = _map_size.y * 0.70
	spawn_origin = Vector2(_map_size.x * 0.10, floor_y)
	if not ResourceLoader.exists(map_path):
		push_warning("[Village] 找不到地圖：%s，使用空白世界。" % map_path)
		return
	var packed: PackedScene = load(map_path)
	if packed == null:
		push_warning("[Village] 地圖載入失敗：%s" % map_path)
		return
	map_node = packed.instantiate()
	add_child(map_node)
	move_child(map_node, 0)
	if map_node is Node2D:
		(map_node as Node2D).z_index = -10
		(map_node as Node2D).scale = Vector2(_map_scale, _map_scale)
	if background:
		background.visible = false
	var spawn_slot: Node = null
	if use_village_entrance:
		spawn_slot = _find_map_object_by_name(GameData.VILLAGE_MAP_ENTRANCE_SLOTS)
		if spawn_slot is Node2D:
			spawn_origin = (spawn_slot as Node2D).global_position
		var obstacle: Node = _find_map_object_by_name(["Obstacle", "obstacle"])
		if obstacle is Node2D:
			_map_walk_min_x = (obstacle as Node2D).global_position.x + 79.0 * _map_scale
	var floor_obj: Node = _find_map_object_by_name(GameData.VILLAGE_MAP_FLOOR_SLOTS)
	if floor_obj is Node2D:
		floor_y = (floor_obj as Node2D).global_position.y
	else:
		var auto_y: float = _detect_floor_y_from_group("Buildings")
		if auto_y > 0.0:
			floor_y = auto_y
		elif spawn_slot is Node2D:
			floor_y = (spawn_slot as Node2D).global_position.y
	_build_blocked_grid()


func _spawn_tavern_door_marker() -> void:
	var slot: Node = _find_map_object_by_name(GameData.VILLAGE_MAP_TAVERN_DOOR_SLOTS)
	var pos: Vector2 = _map_marker_position(slot, Vector2(_map_size.x * 0.36, floor_y - 42.0))
	if slot is Node2D:
		pos = (slot as Node2D).global_position
	_tavern_door_node = _make_door_interact_anchor("VillageTavernDoor", pos)


func _spawn_tavern_exit_marker() -> void:
	var slot: Node = _find_map_object_by_name(GameData.TAVERN_MAP_ENTER_SLOTS)
	var pos: Vector2 = _map_marker_position(slot, Vector2(_map_size.x * 0.64, _tavern_floor_1_y - 42.0))
	if slot is Node2D:
		pos = (slot as Node2D).global_position
	_tavern_exit_node = _make_door_interact_anchor("TavernExit", pos)


func _cache_tavern_floor_heights() -> void:
	var f1: Node = _find_map_object_by_name(GameData.TAVERN_MAP_FLOOR_1F_SLOTS)
	var f2: Node = _find_map_object_by_name(GameData.TAVERN_MAP_FLOOR_2F_SLOTS)
	_tavern_floor_1_y = floor_y
	_tavern_floor_2_y = floor_y * 0.45
	if f1 is Node2D:
		_tavern_floor_1_y = (f1 as Node2D).global_position.y
	if f2 is Node2D:
		_tavern_floor_2_y = (f2 as Node2D).global_position.y


func _apply_tavern_floor(floor_num: int, reposition_players: bool) -> void:
	_tavern_floor = clampi(floor_num, 1, 2)
	floor_y = _tavern_floor_1_y if _tavern_floor == 1 else _tavern_floor_2_y
	if _tavern_stair_up_node != null and is_instance_valid(_tavern_stair_up_node):
		_tavern_stair_up_node.visible = (_tavern_floor == 1)
	if _tavern_stair_down_node != null and is_instance_valid(_tavern_stair_down_node):
		_tavern_stair_down_node.visible = (_tavern_floor == 2)
	if _tavern_exit_node != null and is_instance_valid(_tavern_exit_node):
		_tavern_exit_node.visible = (_tavern_floor == 1)
	if reposition_players:
		_position_camera()


func _spawn_tavern_stair_markers() -> void:
	var up_slot: Node = _find_map_object_by_name(GameData.TAVERN_MAP_STAIR_UP_SLOTS)
	var up_pos: Vector2 = _map_marker_position(up_slot, Vector2(48.0, _tavern_floor_1_y - 42.0))
	if up_slot is Node2D:
		up_pos = (up_slot as Node2D).global_position
	_tavern_stair_up_node = _make_door_interact_anchor("TavernStairUp", up_pos)
	var down_slot: Node = _find_map_object_by_name(GameData.TAVERN_MAP_STAIR_DOWN_SLOTS)
	var down_pos: Vector2 = _map_marker_position(down_slot, Vector2(360.0, _tavern_floor_2_y - 42.0))
	if down_slot is Node2D:
		down_pos = (down_slot as Node2D).global_position
	_tavern_stair_down_node = _make_door_interact_anchor("TavernStairDown", down_pos)
	_apply_tavern_floor(_tavern_floor, false)


func _tavern_stair_land_feet_x(slots: Array) -> float:
	var slot: Node = _find_map_object_by_name(slots)
	if slot is Node2D:
		return (slot as Node2D).global_position.x + TAVERN_STAIR_LAND_X_OFFSET
	return spawn_origin.x


func _tavern_go_upstairs() -> void:
	if _transitioning or not _is_in_tavern() or _tavern_floor != 1:
		return
	AudioManager.play_sfx("ui_confirm")
	_transitioning = true
	_apply_tavern_floor(2, false)
	_teleport_players_to_feet_x(_tavern_stair_land_feet_x(GameData.TAVERN_MAP_STAIR_DOWN_SLOTS))
	_refresh_tavern_interior_npc_visibility()
	_refresh_tavern_hud_hint()
	_transitioning = false


func _tavern_go_downstairs() -> void:
	if _transitioning or not _is_in_tavern() or _tavern_floor != 2:
		return
	AudioManager.play_sfx("ui_confirm")
	_transitioning = true
	_apply_tavern_floor(1, false)
	_teleport_players_to_feet_x(_tavern_stair_land_feet_x(GameData.TAVERN_MAP_STAIR_UP_SLOTS))
	_refresh_tavern_interior_npc_visibility()
	_transitioning = false


func _refresh_tavern_interior_npc_visibility() -> void:
	_prune_invalid_tavern_social_nodes()
	for npc_id in _tavern_permanent_npc_nodes.keys():
		var n = _tavern_permanent_npc_nodes[npc_id]
		if n == null or not is_instance_valid(n):
			continue
		var npc_floor: int = int(n.get_meta("tavern_floor", 1))
		n.visible = npc_floor == _tavern_floor
	var social_active: bool = GameData.is_tavern_social_hours(_village_time_phase)
	for npc_id in _tavern_social_npc_nodes.keys():
		var n = _tavern_social_npc_nodes[npc_id]
		if n == null or not is_instance_valid(n):
			continue
		var npc_floor: int = int(n.get_meta("tavern_floor", 1))
		n.visible = social_active and npc_floor == _tavern_floor


func _refresh_tavern_hud_hint() -> void:
	if not hint_label or not _is_in_tavern():
		return
	if GameData.is_tavern_social_hours(_village_time_phase):
		hint_label.text = tr("TAVERN_HINT_EVENING")
	elif _village_time_phase == "day":
		hint_label.text = tr("TAVERN_HINT_DAY")
	else:
		hint_label.text = tr("TAVERN_HINT")


func _clear_tavern_social_npcs() -> void:
	for npc_id in _tavern_social_npc_nodes.keys():
		_release_node(_tavern_social_npc_nodes[npc_id])
	_tavern_social_npc_nodes.clear()


func _clear_tavern_permanent_npcs() -> void:
	for npc_id in _tavern_permanent_npc_nodes.keys():
		_release_node(_tavern_permanent_npc_nodes[npc_id])
	_tavern_permanent_npc_nodes.clear()


func _tavern_npc_label_color(strip_id: String) -> Color:
	if strip_id == "bard":
		return Color(0.85, 0.78, 1.0)
	if strip_id == "blacksmith" or strip_id == "blacksmith_tavern":
		return Color(1.0, 0.88, 0.48)
	if strip_id == "merchant":
		return Color(0.68, 0.92, 1.0)
	if strip_id == "miner":
		return Color(0.82, 0.9, 1.0)
	if strip_id == "farmer":
		return Color(0.75, 1.0, 0.65)
	if strip_id == "woodcutter":
		return Color(0.75, 1.0, 0.7)
	if strip_id.begins_with("traveler"):
		return Color(0.9, 0.82, 1.0)
	if strip_id == "chef":
		return Color(1.0, 0.82, 0.55)
	return Color(0.95, 0.88, 0.55)


func _spawn_tavern_npc_from_entry(entry: Dictionary, node_prefix: String) -> void:
	if not GameData.tavern_npc_available(entry):
		return
	var npc_id: String = String(entry.get("id", ""))
	if npc_id == "":
		return
	var slots: Array = []
	for s in entry.get("map_slots", []):
		slots.append(String(s))
	var slot: Node = _find_map_object_by_name(slots)
	var pos: Vector2 = _tavern_map_npc_position(
		slot, Vector2(_map_size.x * 0.5, _tavern_floor_1_y + VILLAGE_NPC_ROOT_Y_OFFSET))
	var slot_floor: int = 1
	if slot is Node2D:
		slot_floor = _tavern_npc_floor_from_slot_y((slot as Node2D).global_position.y)
	var strip_id: String = String(entry.get("strip_id", npc_id))
	var name_key: String = String(entry.get("name_key", ""))
	var subtitle_key: String = String(entry.get("subtitle_key", ""))
	var label_text: String = tr(name_key) if name_key != "" else ""
	var subtitle_text: String = tr(subtitle_key) if subtitle_key != "" else ""
	var marker := _make_village_npc_marker(
		strip_id,
		label_text,
		_tavern_npc_label_color(strip_id),
		"%s_%s" % [node_prefix, npc_id],
		7,
		int(entry.get("anim_row", -1)),
		subtitle_text,
	)
	marker.global_position = pos
	marker.set_meta("tavern_npc_id", npc_id)
	marker.set_meta("tavern_floor", slot_floor)
	add_child(marker)
	if node_prefix == "TavernPermanent":
		marker.set_meta("tavern_permanent", true)
		_tavern_permanent_npc_nodes[npc_id] = marker
	else:
		marker.set_meta("tavern_social", true)
		_tavern_social_npc_nodes[npc_id] = marker


func _spawn_tavern_permanent_npcs() -> void:
	_clear_tavern_permanent_npcs()
	if not GameState.is_npc_rescued("tavern_owner"):
		return
	for entry in GameData.TAVERN_PERMANENT_NPCS:
		_spawn_tavern_npc_from_entry(entry, "TavernPermanent")


func _refresh_tavern_social_npcs() -> void:
	_clear_tavern_social_npcs()
	if not _is_in_tavern() or not GameData.is_tavern_social_hours(_village_time_phase):
		return
	GameState.ensure_tavern_traveler_for_today()
	for entry in GameData.TAVERN_SOCIAL_NPCS:
		_spawn_tavern_npc_from_entry(entry, "TavernSocial")
	_refresh_tavern_interior_npc_visibility()


func _on_village_phase_changed() -> void:
	if _is_in_tavern():
		if not GameData.is_tavern_open_for_entry(_village_time_phase):
			_eject_tavern_at_closing()
			return
		_refresh_tavern_social_npcs()
		_refresh_tavern_hud_hint()


func _eject_tavern_at_closing() -> void:
	if not _is_in_tavern() or _transitioning:
		return
	var notice: String = tr("TAVERN_CLOSED_KICK_NOTICE")
	_exit_tavern()
	if is_inside_tree():
		BlockingNotice.present(
			get_tree(),
			tr("TAVERN_CLOSED_TITLE"),
			notice,
			"",
			tr("PINBALL_REWARD_OK"),
		)


func _show_tavern_closed_notice() -> void:
	if not is_inside_tree():
		return
	AudioManager.play_sfx("ui_back")
	BlockingNotice.present(
		get_tree(),
		tr("TAVERN_CLOSED_TITLE"),
		tr("TAVERN_CLOSED_NOTICE"),
		"",
		tr("PINBALL_REWARD_OK"),
	)


func _make_door_interact_anchor(node_name: String, pos: Vector2) -> Node2D:
	var anchor := Node2D.new()
	anchor.name = node_name
	anchor.global_position = pos
	anchor.set_meta("float_prompt_offset_y", -56.0)
	add_child(anchor)
	return anchor


func _teleport_players_to_feet_x(feet_x: float) -> void:
	var idx := 0
	for p in players:
		if p == null or not is_instance_valid(p):
			continue
		var offset_x: float = -30.0 if idx == 0 else 30.0
		if players.size() == 1:
			offset_x = 0.0
		p.position = Vector2(feet_x + offset_x, floor_y - p.body_radius)
		idx += 1
	_position_camera()


func _enter_tavern() -> void:
	if _transitioning or _is_in_tavern():
		return
	if not GameData.is_tavern_open_for_entry(_village_time_phase):
		_show_tavern_closed_notice()
		return
	AudioManager.play_sfx("ui_confirm")
	_transitioning = true
	var door_x: float = spawn_origin.x
	if _tavern_door_node != null and is_instance_valid(_tavern_door_node):
		door_x = _tavern_door_node.global_position.x
	_clear_village_exterior_markers()
	_setup_tavern_interior()
	var enter_slot: Node = _find_map_object_by_name(GameData.TAVERN_MAP_ENTER_SLOTS)
	var feet_x: float = door_x
	if enter_slot is Node2D:
		feet_x = (enter_slot as Node2D).global_position.x - 40.0
	_teleport_players_to_feet_x(feet_x)
	_transitioning = false


func _exit_tavern() -> void:
	if _transitioning or not _is_in_tavern():
		return
	AudioManager.play_sfx("ui_back")
	_transitioning = true
	var return_x: float = spawn_origin.x
	if _tavern_exit_node != null and is_instance_valid(_tavern_exit_node):
		return_x = _tavern_exit_node.global_position.x
	_clear_tavern_interior_markers()
	_setup_village_exterior()
	var door_slot: Node = _find_map_object_by_name(GameData.VILLAGE_MAP_TAVERN_DOOR_SLOTS)
	var feet_x: float = return_x
	if door_slot is Node2D:
		feet_x = (door_slot as Node2D).global_position.x
	_teleport_players_to_feet_x(feet_x)
	_transitioning = false


# 找一個群組節點底下所有 Sprite2D 視覺底部 Y 的最大值（=最低位置）
func _detect_floor_y_from_group(group_name: String) -> float:
	if map_node == null:
		return -1.0
	var grp: Node = map_node.find_child(group_name, true, false)
	if grp == null:
		return -1.0
	var max_bottom: float = -INF
	var found: bool = false
	for n in grp.find_children("*", "", true, false):
		if not (n is Node2D):
			continue
		var n2: Node2D = n
		var bottom: float = n2.global_position.y
		if n is Sprite2D and (n as Sprite2D).texture != null:
			var s: Sprite2D = n
			var rect: Rect2 = s.get_rect()
			bottom = s.to_global(rect.position + Vector2(0, rect.size.y)).y
		if bottom > max_bottom:
			max_bottom = bottom
			found = true
	if found:
		return max_bottom
	return -1.0


# Player.gd 在村莊模式下查詢腳底 Y。目前是平坦地面，未來可依 x 做高低差。
func get_village_floor_y(_x: float) -> float:
	return floor_y


# 在 map_node 底下遞迴搜尋名稱符合任一候選字串的子節點（不分大小寫）
func _find_map_object_by_name(candidates: Array) -> Node:
	if map_node == null:
		return null
	# 先試 find_child 比較快
	for nm in candidates:
		var n: Node = map_node.find_child(nm, true, false)
		if n != null:
			return n
	# 退而求其次：遍歷所有子節點，名稱小寫比對
	var lower_set: Dictionary = {}
	for nm in candidates:
		lower_set[String(nm).to_lower()] = true
	for n in map_node.find_children("*", "", true, false):
		if lower_set.has(String(n.name).to_lower()):
			return n
	return null


func _build_blocked_grid() -> void:
	blocked_tiles.clear()
	if map_node == null:
		return
	# 村莊地圖無水池/高地語意，這裡只用 tileset 路徑特徵（Water 等）阻擋
	var layers: Array = map_node.find_children("*", "TileMapLayer", true, false)
	for n in layers:
		var layer: TileMapLayer = n as TileMapLayer
		if layer == null:
			continue
		var ts: TileSet = layer.tile_set
		for cell in layer.get_used_cells():
			var src_id: int = layer.get_cell_source_id(cell)
			if src_id < 0:
				continue
			var blocked: bool = false
			if ts != null:
				var src: TileSetSource = ts.get_source(src_id)
				if src is TileSetAtlasSource:
					var atlas: TileSetAtlasSource = src
					if atlas.texture:
						var path: String = atlas.texture.resource_path
						if "Water" in path:
							blocked = true
			if blocked:
				blocked_tiles[cell] = true


# 給 Player 呼叫；村莊外圍也視為阻擋
func is_world_blocked_at(pos: Vector2, radius: float = 8.0) -> bool:
	# 軟邊界：不可走到地圖外
	if pos.x - radius < _map_walk_min_x:
		return true
	if pos.y - radius < 8.0:
		return true
	if pos.x + radius > _map_size.x - 8.0:
		return true
	if pos.y + radius > _map_size.y - 8.0:
		return true
	if blocked_tiles.is_empty():
		return false
	var samples := [
		pos + Vector2(radius, 0),
		pos + Vector2(-radius, 0),
		pos + Vector2(0, radius),
		pos + Vector2(0, -radius),
	]
	for s in samples:
		var tile := Vector2i(int(floor(s.x / tile_size)), int(floor(s.y / tile_size)))
		if blocked_tiles.has(tile):
			return true
	return false


# 玩家不會升級，但 add_team_xp 仍可能因 XP orb（村莊沒怪所以不會發生）被呼叫
func add_team_xp(_amount: float) -> void:
	pass


func _spawn_blacksmith_if_rescued() -> void:
	if not bool(GameState.blacksmith_rescued):
		return
	var slot: Node = _find_map_object_by_name(GameData.VILLAGE_MAP_BLACKSMITH_SLOTS)
	var pos: Vector2 = _village_npc_spawn_position(slot, Vector2(_map_size.x * 0.65, floor_y + VILLAGE_NPC_ROOT_Y_OFFSET))
	var smith := _make_village_npc_marker(
		"blacksmith",
		tr("VILLAGE_BLACKSMITH_NAME"),
		Color(1.0, 0.88, 0.48),
		"VillageBlacksmith",
		9,
		-1,
		GameData.tr_village_npc_subtitle("blacksmith"),
	)
	smith.global_position = pos
	add_child(smith)
	_blacksmith_node = smith
	_timed_npc_nodes.append(smith)


func _spawn_merchant_if_rescued() -> void:
	if not bool(GameState.merchant_rescued):
		return
	var slot: Node = _find_map_object_by_name(GameData.VILLAGE_MAP_MERCHANT_SLOTS)
	var pos: Vector2 = _village_npc_spawn_position(slot, Vector2(_map_size.x * 0.53, floor_y + VILLAGE_NPC_ROOT_Y_OFFSET))
	var merchant := _make_village_npc_marker(
		"merchant",
		tr("VILLAGE_MERCHANT_NAME"),
		Color(0.68, 0.92, 1.0),
		"VillageMerchant",
		9,
		-1,
		GameData.tr_village_npc_subtitle("merchant"),
	)
	merchant.global_position = pos
	add_child(merchant)
	_merchant_node = merchant
	_timed_npc_nodes.append(merchant)


func _make_village_npc_marker(
		strip_id: String,
		label_text: String,
		label_color: Color,
		node_name: String,
		z_index: int = 9,
		anim_row: int = -1,
		subtitle_text: String = "",
) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	root.z_index = z_index
	var strip_def: Dictionary = GameData.get_village_npc_strip_def(strip_id)
	if not strip_def.is_empty():
		var anim := Node2D.new()
		anim.name = "Anim"
		anim.set_script(VILLAGE_NPC_ANIM_SCRIPT)
		anim.strip_texture = GameData.resolve_frame_texture(strip_def.get("strip", ""))
		anim.hframes = maxi(1, int(strip_def.get("hframes", 1)))
		anim.vframes = maxi(1, int(strip_def.get("vframes", 1)))
		var row: int = anim_row if anim_row >= 0 else int(strip_def.get("anim_row", 0))
		anim.anim_row = clampi(row, 0, anim.vframes - 1)
		anim.anim_fps = maxf(1.0, float(strip_def.get("fps", 6.0)))
		anim.target_height = VILLAGE_NPC_SPRITE_HEIGHT
		anim.feet_anchor_y = VILLAGE_NPC_FEET_ANCHOR_Y
		anim.feet_fine_y = VILLAGE_NPC_FEET_FINE_Y
		root.add_child(anim)
	else:
		_add_village_npc_static_sprite(root, RESCUE_NPC_TEXTURE)
	if label_text != "":
		var title_y: float = VILLAGE_NPC_LABEL_Y
		if subtitle_text != "":
			title_y = VILLAGE_NPC_TITLE_WITH_SUBTITLE_Y
		var label := Label.new()
		label.name = "TitleLabel"
		label.text = label_text
		label.position = Vector2(-90, title_y)
		label.size = Vector2(180, 28)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", label_color)
		root.add_child(label)
	if subtitle_text != "":
		var sub := Label.new()
		sub.name = "SubtitleLabel"
		sub.text = subtitle_text
		sub.position = Vector2(-90, VILLAGE_NPC_SUBTITLE_Y)
		sub.size = Vector2(180, 22)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 12)
		sub.add_theme_color_override("font_color", label_color.lightened(0.12))
		root.add_child(sub)
	var prompt_y: float = VILLAGE_NPC_LABEL_Y - 8.0
	if subtitle_text != "":
		prompt_y = VILLAGE_NPC_TITLE_WITH_SUBTITLE_Y - 8.0
	root.set_meta("float_prompt_offset_y", prompt_y)
	return root


func _add_village_npc_static_sprite(root: Node2D, tex: Texture2D) -> void:
	var spr := Sprite2D.new()
	spr.name = "Sprite"
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if spr.texture:
		var ts: Vector2 = spr.texture.get_size()
		if ts.y > 0.0:
			spr.scale = Vector2.ONE * (VILLAGE_NPC_SPRITE_HEIGHT / ts.y)
		spr.position = Vector2(
			0.0,
			GameData.sprite_feet_offset_y(
				tex, VILLAGE_NPC_FEET_ANCHOR_Y, spr.scale.y, VILLAGE_NPC_FEET_FINE_Y),
		)
	root.add_child(spr)


func _village_npc_spawn_position(slot: Node, fallback: Vector2) -> Vector2:
	if slot is Node2D:
		return Vector2((slot as Node2D).global_position.x, floor_y + VILLAGE_NPC_ROOT_Y_OFFSET)
	return fallback


## 酒館內：X 取自 TMX 標記，Y 對齊該樓 Floor 地面線（與村莊外 NPC 相同）
func _tavern_map_npc_position(slot: Node, fallback: Vector2) -> Vector2:
	if slot is Node2D:
		var slot_pos: Vector2 = (slot as Node2D).global_position
		var fl: int = _tavern_npc_floor_from_slot_y(slot_pos.y)
		var walk_y: float = _tavern_floor_2_y if fl == 2 else _tavern_floor_1_y
		return Vector2(slot_pos.x, walk_y + VILLAGE_NPC_ROOT_Y_OFFSET)
	return fallback


func _tavern_npc_floor_from_slot_y(slot_y: float) -> int:
	var floor_mid_y: float = (_tavern_floor_1_y + _tavern_floor_2_y) * 0.5
	return 2 if slot_y < floor_mid_y else 1


func _apply_village_npc_schedule() -> void:
	_apply_time_visuals(false)


func _rescued_story_npc_strip_id(npc_id: String) -> String:
	if GameData.get_village_npc_strip_def(npc_id).is_empty():
		return ""
	return npc_id


func _map_marker_position(slot: Node, fallback: Vector2) -> Vector2:
	if slot is Node2D:
		return Vector2((slot as Node2D).global_position.x, floor_y - 42.0)
	return fallback


func _setup_village_clock() -> void:
	_sky_overlay = ColorRect.new()
	_sky_overlay.name = "SkyOverlay"
	_sky_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky_overlay.color = Color(0, 0, 0, 0)
	_sky_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(_sky_overlay)
	hud.move_child(_sky_overlay, 0)

	_time_label = Label.new()
	_time_label.name = "TimeLabel"
	_time_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_time_label.offset_left = -130.0
	_time_label.offset_right = -12.0
	_time_label.offset_top = 12.0
	_time_label.offset_bottom = 38.0
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_time_label.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(_time_label)

	_apply_time_visuals(false)


func _is_any_dialog_open() -> bool:
	return _pause_open or _blacksmith_dialog != null or _merchant_dialog != null \
		or _rune_master_dialog != null \
		or _facility_dialog != null or _house_dialog != null \
		or _well_dialog != null or _farmer_dialog != null \
		or _crop_dialog != null or _talk_dialog != null \
		or _expedition_dialog != null or _p2_join_dialog != null or _p2_leave_dialog != null


func _update_village_time(delta: float) -> void:
	# 酒館內暫停村莊時段，避免探索時變傍晚／打烊被打斷
	if _is_in_tavern():
		return
	if _is_any_dialog_open():
		return
	_village_time_sec = fmod(_village_time_sec + delta, VILLAGE_TIME_CYCLE)
	var new_phase := _calc_time_phase()
	if new_phase != _village_time_phase:
		var old_phase: String = _village_time_phase
		_village_time_phase = new_phase
		if old_phase == "night" and new_phase == "day":
			GameState.on_village_new_day()
		_apply_time_visuals(true)
		_on_village_phase_changed()
	_update_time_label()


func _calc_time_phase() -> String:
	if _village_time_sec < VILLAGE_TIME_DAY_DURATION:
		return "day"
	if _village_time_sec < VILLAGE_TIME_DAY_DURATION + VILLAGE_TIME_EVENING_DURATION:
		return "evening"
	return "night"


func _apply_time_visuals(animated: bool) -> void:
	var target_sky: Color
	match _village_time_phase:
		"day":
			target_sky = Color(0, 0, 0, 0)
		"evening":
			target_sky = Color(0.72, 0.28, 0.05, 0.28)
		_:
			target_sky = Color(0.04, 0.06, 0.28, 0.52)
	if is_instance_valid(_sky_overlay):
		if animated:
			create_tween().tween_property(_sky_overlay, "color", target_sky, 5.0)
		else:
			_sky_overlay.color = target_sky
	for npc_id in _always_npc_nodes:
		var node = _always_npc_nodes.get(npc_id)
		if node == null or not is_instance_valid(node):
			continue
		var entry := GameData.get_village_always_npc(npc_id)
		var phases: Array = entry.get("active_phases", ["day"])
		node.visible = _village_time_phase in phases
	var is_day: bool = (_village_time_phase == "day")
	for tnode in _timed_npc_nodes:
		if is_instance_valid(tnode):
			tnode.visible = is_day
	_update_time_label()


func _update_time_label() -> void:
	if not is_instance_valid(_time_label):
		return
	match _village_time_phase:
		"day":
			_time_label.text = tr("VILLAGE_TIME_DAY")
			_time_label.modulate = Color(1.0, 0.95, 0.6)
		"evening":
			_time_label.text = tr("VILLAGE_TIME_EVENING")
			_time_label.modulate = Color(1.0, 0.65, 0.3)
		_:
			_time_label.text = tr("VILLAGE_TIME_NIGHT")
			_time_label.modulate = Color(0.6, 0.7, 1.0)


func _spawn_village_always_npcs() -> void:
	for entry in GameData.VILLAGE_ALWAYS_NPCS:
		var npc_id: String = String(entry.get("id", ""))
		if npc_id == "":
			continue
		var strip_id: String = String(entry.get("strip_id", npc_id))
		if GameData.get_village_npc_strip_def(strip_id).is_empty():
			continue
		var slots: Array = []
		for s in entry.get("map_slots", []):
			slots.append(String(s))
		var slot: Node = _find_map_object_by_name(slots)
		var pos: Vector2 = _village_npc_spawn_position(
			slot, Vector2(_map_size.x * 0.5, floor_y + VILLAGE_NPC_ROOT_Y_OFFSET))
		var name_key: String = String(entry.get("name_key", ""))
		var label_text: String = tr(name_key) if name_key != "" else ""
		var subtitle_key: String = String(entry.get("subtitle_key", ""))
		var subtitle_text: String = tr(subtitle_key) if subtitle_key != "" else ""
		var label_col: Color = Color(0.95, 0.88, 0.55)
		if strip_id == "bard":
			label_col = Color(0.85, 0.78, 1.0)
		var row: int = int(entry.get("anim_row", -1))
		var marker := _make_village_npc_marker(
			strip_id,
			label_text,
			label_col,
			"VillageNpc_%s" % npc_id,
			7,
			row,
			subtitle_text,
		)
		marker.global_position = pos
		marker.set_meta("always_npc_id", npc_id)
		add_child(marker)
		_always_npc_nodes[npc_id] = marker


func _spawn_rescued_story_npcs() -> void:
	for entry in GameData.VILLAGE_RESCUED_NPC_MARKERS:
		var npc_id: String = String(entry.get("npc_id", ""))
		if npc_id == "" or not GameState.is_npc_rescued(npc_id):
			continue
		if npc_id == "tavern_owner":
			continue
		if npc_id == "farmer" and GameState.is_village_facility_unlocked("farm"):
			continue
		var slots: Array = []
		for s in entry.get("map_slots", []):
			slots.append(String(s))
		var slot: Node = _find_map_object_by_name(slots)
		var pos: Vector2 = _village_npc_spawn_position(
			slot, Vector2(_map_size.x * 0.5, floor_y + VILLAGE_NPC_ROOT_Y_OFFSET))
		var marker := _make_rescued_npc_marker(
			npc_id,
			String(entry.get("name_key", "")),
			String(entry.get("subtitle_key", "")),
		)
		marker.global_position = pos
		add_child(marker)
		_timed_npc_nodes.append(marker)
		if npc_id == "rune_master":
			_rune_master_node = marker


func _make_rescued_npc_marker(
		npc_id: String,
		name_key: String,
		subtitle_key: String = "",
) -> Node2D:
	var label_text: String = tr(name_key) if name_key != "" else ""
	var subtitle_text: String = tr(subtitle_key) if subtitle_key != "" else ""
	return _make_village_npc_marker(
		_rescued_story_npc_strip_id(npc_id),
		label_text,
		Color(0.88, 0.95, 1.0),
		"VillageRescuedNpc_%s" % npc_id,
		7,
		-1,
		subtitle_text,
	)


func _spawn_village_facilities() -> void:
	_facility_nodes.clear()
	for fdef in GameData.VILLAGE_FACILITIES:
		var fid: String = String(fdef.get("id", ""))
		if fid == "" or fid == "well" or fid == "farm":
			continue
		if not GameState.is_village_facility_unlocked(fid):
			continue
		var slots: Array = fdef.get("map_slots", [])
		var candidates: Array = []
		for s in slots:
			candidates.append(String(s))
		var slot: Node = _find_map_object_by_name(candidates)
		var pos: Vector2 = _village_npc_spawn_position(slot, Vector2(
			_map_size.x * float(fdef.get("fallback_x_mult", 0.1)),
			floor_y + VILLAGE_NPC_ROOT_Y_OFFSET))
		var marker := _make_village_facility_marker(fid, fdef)
		marker.global_position = pos
		add_child(marker)
		_facility_nodes[fid] = marker
		if fdef.has("npc_strip"):
			_timed_npc_nodes.append(marker)


func _spawn_farm_and_well_nodes() -> void:
	_crop_plot_nodes.clear()
	if GameState.is_village_facility_unlocked("well"):
		var well_slot: Node = _find_map_object_by_name(["Water", "water", "well"])
		var wpos: Vector2 = _map_marker_position(well_slot, Vector2(_map_size.x * 0.11, floor_y - 42.0))
		_well_node = _make_well_interact_anchor()
		_well_node.global_position = wpos
		add_child(_well_node)
	if GameState.is_village_facility_unlocked("farm"):
		var farmer_slot: Node = _find_map_object_by_name(["Farmer", "farmer", "farm"])
		var fpos: Vector2 = _village_npc_spawn_position(
			farmer_slot, Vector2(_map_size.x * 0.16, floor_y + VILLAGE_NPC_ROOT_Y_OFFSET))
		_farmer_shop_node = _make_village_npc_marker(
			"farmer",
			tr("VILLAGE_FARMER_NAME"),
			Color(0.75, 1.0, 0.65),
			"VillageFarmerShop",
			9,
			-1,
			GameData.tr_village_npc_subtitle("farmer"),
		)
		_farmer_shop_node.global_position = fpos
		add_child(_farmer_shop_node)
		_timed_npc_nodes.append(_farmer_shop_node)
		for i in range(1, GameData.FARM_PLOT_COUNT + 1):
			var slot_name: String = GameData.farm_plot_map_slot_name(i)
			var crop_slot: Node = _find_map_object_by_name([slot_name])
			var cpos: Vector2 = _map_marker_position(
				crop_slot, Vector2(_map_size.x * 0.12 + float(i) * 18.0, floor_y - 36.0))
			var plot := _make_crop_plot_marker(i)
			plot.global_position = cpos
			add_child(plot)
			_crop_plot_nodes[i] = plot


func _make_well_interact_anchor() -> Node2D:
	var root := Node2D.new()
	root.name = "VillageWell"
	root.z_index = 8
	root.set_meta("float_prompt_offset_y", -56.0)
	return root


func _make_crop_plot_marker(slot_index: int) -> Node2D:
	var root := Node2D.new()
	root.name = "VillageCropPlot_%d" % slot_index
	root.z_index = 7
	root.set_meta("plot_slot", slot_index)
	var draw := DrawerNode2D.new()
	draw.set_meta("plot_slot", slot_index)
	draw.fn = Callable(self, "_draw_crop_plot_marker")
	root.add_child(draw)
	return root


func _draw_crop_plot_marker(node: Node2D) -> void:
	var slot: int = int(node.get_meta("plot_slot", 1))
	var col: Color = Color(0.45, 0.32, 0.18)
	if GameState.farm_plot_is_ready(slot):
		col = Color(0.55, 0.85, 0.35)
	elif not GameState.farm_plot_is_empty(slot):
		col = Color(0.42, 0.62, 0.28)
	node.draw_rect(Rect2(-20, 8, 40, 14), col.darkened(0.2))
	node.draw_rect(Rect2(-16, 4, 32, 10), col)
	var stage: int = GameState.farm_plot_stage(slot)
	if not GameState.farm_plot_is_empty(slot):
		node.draw_string(ThemeDB.fallback_font, Vector2(-6, 0), str(stage),
			HORIZONTAL_ALIGNMENT_CENTER, 12, 11, Color(1, 1, 1, 0.85))


func _nearest_crop_plot_slot() -> int:
	var best_slot: int = 0
	var best_dist: float = INF
	for slot_key in _crop_plot_nodes.keys():
		var node: Node = _crop_plot_nodes[slot_key]
		if node == null or not is_instance_valid(node):
			continue
		for p in players:
			if p == null or not is_instance_valid(p):
				continue
			var d: float = p.global_position.distance_to(node.global_position)
			if d <= CROP_PLOT_INTERACT_RADIUS and d < best_dist:
				best_dist = d
				best_slot = int(slot_key)
	return best_slot


func _update_crop_plot_interaction() -> bool:
	var slot: int = _nearest_crop_plot_slot()
	if slot <= 0:
		return false
	var node = _crop_plot_nodes.get(slot)
	if node == null or not is_instance_valid(node):
		return false
	var near: Array[String] = _players_in_range_prefixes(node, CROP_PLOT_INTERACT_RADIUS)
	if near.is_empty():
		return false
	var action_key: String = "VILLAGE_INTERACT_ACTION_CROP_PLOT"
	if GameState.farm_plot_is_ready(slot):
		action_key = "VILLAGE_INTERACT_ACTION_HARVEST"
	elif GameState.farm_plot_is_empty(slot):
		action_key = "VILLAGE_INTERACT_ACTION_PLANT"
	else:
		action_key = "VILLAGE_INTERACT_ACTION_WATER"
	_show_float_interact_prompt(node, near, tr(action_key))
	if _try_interact_prefixes(near):
		_open_crop_dialog(slot)
	return true


func _update_well_interaction() -> bool:
	if _well_node == null or not is_instance_valid(_well_node):
		return false
	var near: Array[String] = _players_in_range_prefixes(_well_node, WELL_INTERACT_RADIUS)
	if near.is_empty():
		return false
	_show_float_interact_prompt(_well_node, near, tr("VILLAGE_INTERACT_ACTION_WELL"))
	if _try_interact_prefixes(near):
		_open_well_dialog()
	return true


func _update_farmer_interaction() -> bool:
	if _farmer_shop_node == null or not is_instance_valid(_farmer_shop_node) or not _farmer_shop_node.visible:
		return false
	var near: Array[String] = _players_in_range_prefixes(_farmer_shop_node, FARMER_INTERACT_RADIUS)
	if near.is_empty():
		return false
	_show_float_interact_prompt(_farmer_shop_node, near, tr("VILLAGE_INTERACT_ACTION_FARMER"))
	if _try_interact_prefixes(near):
		_open_farmer_dialog()
	return true


func _try_open_nearest_crop_dialog() -> bool:
	var slot: int = _nearest_crop_plot_slot()
	if slot <= 0:
		return false
	_open_crop_dialog(slot)
	return true


func _open_simple_village_dialog(title: String, subtitle: String = "") -> Dictionary:
	var layer := CanvasLayer.new()
	layer.layer = 240
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(layer)
	get_tree().paused = true
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 24)
	root.add_theme_constant_override("margin_right", 24)
	root.add_theme_constant_override("margin_top", 24)
	root.add_theme_constant_override("margin_bottom", 24)
	layer.add_child(root)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(400, 300)
	root.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title_lbl)
	if subtitle != "":
		var sub_lbl := Label.new()
		sub_lbl.text = subtitle
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_lbl.add_theme_font_size_override("font_size", 14)
		sub_lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.88))
		vbox.add_child(sub_lbl)
	var status_lbl := Label.new()
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(status_lbl)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	vbox.add_child(actions)
	var close_btn := Button.new()
	close_btn.text = tr("DIALOG_CLOSE")
	vbox.add_child(close_btn)
	return {"layer": layer, "status": status_lbl, "actions": actions, "close": close_btn}


func _open_well_dialog() -> void:
	if _well_dialog != null:
		return
	var ui: Dictionary = _open_bottom_bar_dialog(tr("VILLAGE_WELL_NAME"), "")
	_well_dialog = ui["layer"] as CanvasLayer
	var status: Label = ui["status"] as Label
	var actions: HBoxContainer = ui["actions"] as HBoxContainer
	status.text = tr("VILLAGE_WELL_STATUS_FMT") % [
		GameState.water_charges, GameData.VILLAGE_WATER_MAX_CHARGES]
	var fill_btn := Button.new()
	fill_btn.text = tr("VILLAGE_WELL_FILL_BTN")
	fill_btn.pressed.connect(func() -> void:
		GameState.fill_water_at_well()
		status.text = tr("VILLAGE_WELL_FILLED_FMT") % GameData.VILLAGE_WATER_MAX_CHARGES)
	actions.add_child(fill_btn)
	fill_btn.grab_focus()
	(ui["close"] as Button).pressed.connect(_close_well_dialog)


func _close_well_dialog() -> void:
	if _well_dialog != null and is_instance_valid(_well_dialog):
		_well_dialog.queue_free()
	_well_dialog = null
	if not _any_modal_village_ui_open():
		get_tree().paused = false


func _open_farmer_dialog() -> void:
	if _farmer_dialog != null:
		return
	var ui: Dictionary = _open_bottom_bar_dialog(
		tr("VILLAGE_FARMER_NAME"),
		GameData.tr_village_npc_subtitle("farmer"),
		"farmer")
	_farmer_dialog = ui["layer"] as CanvasLayer
	var status: Label = ui["status"] as Label
	var actions: HBoxContainer = ui["actions"] as HBoxContainer
	status.text = tr("VILLAGE_FARMER_INTRO")
	for seed_id in GameData.FARMER_SEED_PRICES.keys():
		var sid: String = String(seed_id)
		var price: int = int(GameData.FARMER_SEED_PRICES[sid])
		var btn := Button.new()
		btn.text = tr("VILLAGE_FARMER_BUY_SEED_FMT") % [
			GameData.tr_material_name(sid), price]
		btn.pressed.connect(_farmer_buy_seed.bind(sid, status))
		actions.add_child(btn)
	var first_btn: Button = actions.get_child(0) as Button
	if first_btn:
		first_btn.grab_focus()
	(ui["close"] as Button).pressed.connect(_close_farmer_dialog)


func _farmer_buy_seed(seed_id: String, status: Label) -> void:
	if GameState.buy_farmer_seed(seed_id):
		status.text = tr("VILLAGE_FARMER_BOUGHT_FMT") % GameData.tr_material_name(seed_id)
	else:
		status.text = tr("VILLAGE_FARMER_BUY_FAIL")


func _close_farmer_dialog() -> void:
	if _farmer_dialog != null and is_instance_valid(_farmer_dialog):
		_farmer_dialog.queue_free()
	_farmer_dialog = null
	if not _any_modal_village_ui_open():
		get_tree().paused = false


func _open_crop_dialog(slot_index: int) -> void:
	if _crop_dialog != null:
		return
	_crop_dialog_slot = slot_index
	var ui: Dictionary = _open_bottom_bar_dialog(
		tr("VILLAGE_CROP_PLOT_TITLE_FMT") % slot_index, "", "farmer")
	_crop_dialog = ui["layer"] as CanvasLayer
	var status: Label = ui["status"] as Label
	var actions: HBoxContainer = ui["actions"] as HBoxContainer
	_refresh_crop_dialog_ui(status, actions)
	(ui["close"] as Button).pressed.connect(_close_crop_dialog)


func _refresh_crop_dialog_ui(status: Label, actions: HBoxContainer) -> void:
	for c in actions.get_children():
		c.queue_free()
	var slot: int = _crop_dialog_slot
	if GameState.farm_plot_is_empty(slot):
		status.text = tr(String(GameState.farm_plot_status_key(slot)))
		var seeds: Array[String] = GameState.owned_farm_seed_ids()
		if seeds.is_empty():
			status.text += "\n" + tr("VILLAGE_CROP_NO_SEEDS")
			return
		for seed_id in seeds:
			var btn := Button.new()
			btn.text = tr("VILLAGE_CROP_PLANT_FMT") % GameData.tr_material_name(seed_id)
			btn.pressed.connect(_crop_plant.bind(seed_id, status, actions))
			actions.add_child(btn)
		var first: Button = actions.get_child(0) as Button
		if first:
			first.grab_focus()
	elif GameState.farm_plot_is_ready(slot):
		status.text = tr("FARM_PLOT_STATUS_READY")
		var harvest_btn := Button.new()
		harvest_btn.text = tr("VILLAGE_CROP_HARVEST_BTN")
		harvest_btn.pressed.connect(_crop_harvest.bind(status, actions))
		actions.add_child(harvest_btn)
		harvest_btn.grab_focus()
	else:
		var crop_id: String = GameState.farm_plot_crop_id(slot)
		status.text = tr("VILLAGE_CROP_GROWING_FMT") % [
			GameData.tr_name(GameData.get_farm_crop_def(crop_id)),
			GameState.farm_plot_stage(slot),
			int(GameData.get_farm_crop_def(crop_id).get("stages_to_mature", 3)),
			GameState.water_charges,
		]
		var water_btn := Button.new()
		water_btn.text = tr("VILLAGE_CROP_WATER_BTN")
		water_btn.pressed.connect(_crop_water.bind(status, actions))
		actions.add_child(water_btn)
		water_btn.grab_focus()


func _crop_plant(seed_id: String, status: Label, actions: HBoxContainer) -> void:
	if GameState.plant_farm_plot(_crop_dialog_slot, seed_id):
		_redraw_crop_plot(_crop_dialog_slot)
		_refresh_crop_dialog_ui(status, actions)
	else:
		status.text = tr("VILLAGE_CROP_PLANT_FAIL")


func _crop_water(status: Label, actions: HBoxContainer) -> void:
	var result: Dictionary = GameState.water_farm_plot(_crop_dialog_slot)
	if not bool(result.get("ok", false)):
		var reason: String = String(result.get("reason", ""))
		if reason == "no_water":
			status.text = tr("VILLAGE_CROP_NO_WATER")
		else:
			status.text = tr("VILLAGE_CROP_WATER_FAIL")
		return
	_redraw_crop_plot(_crop_dialog_slot)
	if bool(result.get("ready", false)):
		status.text = tr("VILLAGE_CROP_WATER_READY")
	_refresh_crop_dialog_ui(status, actions)


func _crop_harvest(status: Label, actions: HBoxContainer) -> void:
	if GameState.harvest_farm_plot(_crop_dialog_slot):
		_redraw_crop_plot(_crop_dialog_slot)
		status.text = tr("VILLAGE_CROP_HARVESTED")
		_refresh_crop_dialog_ui(status, actions)
	else:
		status.text = tr("VILLAGE_CROP_HARVEST_FAIL")


func _redraw_crop_plot(slot_index: int) -> void:
	var node: Node = _crop_plot_nodes.get(slot_index)
	if node is Node2D:
		node.queue_redraw()


func _close_crop_dialog() -> void:
	if _crop_dialog != null and is_instance_valid(_crop_dialog):
		_crop_dialog.queue_free()
	_crop_dialog = null
	_crop_dialog_slot = 0
	if not _any_modal_village_ui_open():
		get_tree().paused = false


func _any_modal_village_ui_open() -> bool:
	return _blacksmith_dialog != null or _merchant_dialog != null \
		or _rune_master_dialog != null \
		or _facility_dialog != null or _house_dialog != null \
		or _well_dialog != null or _farmer_dialog != null or _crop_dialog != null \
		or _talk_dialog != null or _expedition_dialog != null \
		or _p2_join_dialog != null or _p2_leave_dialog != null


func _make_village_facility_marker(facility_id: String, fdef: Dictionary) -> Node2D:
	var strip_id: String = String(fdef.get("npc_strip", ""))
	var label_text: String = GameData.tr_field(fdef, "name", false)
	var label_col: Color = Color(0.88, 0.95, 1.0)
	if strip_id == "woodcutter":
		label_col = Color(0.75, 1.0, 0.7)
	elif strip_id == "miner":
		label_col = Color(0.82, 0.88, 0.95)
	var root: Node2D = _make_village_npc_marker(
		strip_id,
		label_text,
		label_col,
		"VillageFacility_%s" % facility_id,
		8,
	)
	root.set_meta("facility_id", facility_id)
	return root


func _update_npc_interactions() -> void:
	if _pause_open or _blacksmith_dialog != null or _merchant_dialog != null \
			or _rune_master_dialog != null \
			or _facility_dialog != null or _house_dialog != null \
			or _well_dialog != null or _farmer_dialog != null or _crop_dialog != null \
			or _talk_dialog != null or _expedition_dialog != null \
			or _p2_join_dialog != null or _p2_leave_dialog != null:
		_hide_float_interact_prompt()
		return
	if _is_in_tavern():
		if _update_tavern_talk_interaction():
			return
		if _update_tavern_stair_up_interaction():
			return
		if _update_tavern_stair_down_interaction():
			return
		if _update_tavern_exit_interaction():
			return
		_hide_float_interact_prompt()
		_refresh_tavern_hud_hint()
		return
	if _update_crop_plot_interaction():
		return
	if _update_well_interaction():
		return
	if _update_farmer_interaction():
		return
	if _update_blacksmith_interaction():
		return
	if _update_merchant_interaction():
		return
	if _update_rune_master_interaction():
		return
	if _update_facility_interaction():
		return
	if _update_tavern_door_interaction():
		return
	if _update_entrance_interaction():
		return
	if _update_p1_house_interaction():
		return
	if _update_p2_house_site_interaction():
		return
	if _update_always_npc_talk_interaction():
		return
	_hide_float_interact_prompt()
	hint_label.text = tr("VILLAGE_HINT")


func _players_in_range_prefixes(
		node, radius: float, only_prefix: String = "") -> Array[String]:
	if node == null or not is_instance_valid(node):
		return []
	var out: Array[String] = []
	for p in players:
		if p == null or not is_instance_valid(p):
			continue
		var pref: String = String(p.input_prefix)
		if only_prefix != "" and pref != only_prefix:
			continue
		if p.global_position.distance_to(node.global_position) <= radius:
			if not out.has(pref):
				out.append(pref)
	out.sort()
	return out


func _interact_line_text(prefix: String, action_text: String, show_player_tag: bool) -> String:
	var btn: String = InputPrompt.interact_button_label(prefix)
	if show_player_tag:
		var tag: String = tr("INPUT_PROMPT_PLAYER_P1") if prefix == "p1" \
				else tr("INPUT_PROMPT_PLAYER_P2")
		return tr("VILLAGE_INTERACT_FLOAT_2P_FMT") % [tag, btn, action_text]
	return tr("VILLAGE_INTERACT_FLOAT_FMT") % [btn, action_text]


func _show_float_interact_prompt(
		target, near_prefixes: Array[String], action_text: String) -> void:
	if _float_prompt_box == null or target == null or not is_instance_valid(target):
		return
	_float_prompt_target = target
	for child in _float_prompt_box.get_children():
		child.queue_free()
	var show_tags: bool = GameState.two_players and near_prefixes.size() > 1
	for prefix in near_prefixes:
		var lbl := Label.new()
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.text = _interact_line_text(prefix, action_text, show_tags)
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.72))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_float_prompt_box.add_child(lbl)
	_float_prompt_layer.visible = true
	_position_float_interact_prompt()


func _hide_float_interact_prompt() -> void:
	_float_prompt_target = null
	if _float_prompt_layer != null:
		_float_prompt_layer.visible = false


func _position_float_interact_prompt() -> void:
	if _float_prompt_layer == null or _float_prompt_target == null \
			or not is_instance_valid(_float_prompt_target) \
			or not _float_prompt_layer.visible:
		return
	var prompt_y: float = -78.0
	if _float_prompt_target.has_meta("float_prompt_offset_y"):
		prompt_y = float(_float_prompt_target.get_meta("float_prompt_offset_y"))
	var world_pos: Vector2 = _float_prompt_target.global_position + Vector2(0.0, prompt_y)
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * world_pos
	if _float_prompt_panel == null:
		return
	var panel_size: Vector2 = _float_prompt_panel.get_combined_minimum_size()
	_float_prompt_layer.position = screen_pos - Vector2(panel_size.x * 0.5, panel_size.y + 8.0)


func _try_interact_prefixes(prefixes: Array[String]) -> bool:
	for prefix in prefixes:
		if Input.is_action_just_pressed(prefix + "_action"):
			return true
	if prefixes.has("p1") and Input.is_action_just_pressed("ui_accept"):
		return true
	return false


func _update_blacksmith_interaction() -> bool:
	if _blacksmith_node == null or not is_instance_valid(_blacksmith_node) or not _blacksmith_node.visible:
		return false
	var near: Array[String] = _players_in_range_prefixes(
		_blacksmith_node, BLACKSMITH_INTERACT_RADIUS)
	if near.is_empty():
		return false
	_show_float_interact_prompt(
		_blacksmith_node, near, tr("VILLAGE_INTERACT_ACTION_BLACKSMITH"))
	if _try_interact_prefixes(near):
		_open_blacksmith_dialog()
	return true


func _update_merchant_interaction() -> bool:
	if _merchant_node == null or not is_instance_valid(_merchant_node) or not _merchant_node.visible:
		return false
	var near: Array[String] = _players_in_range_prefixes(
		_merchant_node, MERCHANT_INTERACT_RADIUS)
	if near.is_empty():
		return false
	_show_float_interact_prompt(
		_merchant_node, near, tr("VILLAGE_INTERACT_ACTION_MERCHANT"))
	if _try_interact_prefixes(near):
		_open_merchant_dialog()
	return true


func _always_npc_has_talk(entry: Dictionary) -> bool:
	var keys: Array = entry.get("dialogue_keys", [])
	return not keys.is_empty()


func _nearest_always_npc_talk_id() -> String:
	var best_id: String = ""
	var best_dist: float = INF
	for p in players:
		if p == null or not is_instance_valid(p):
			continue
		for entry in GameData.VILLAGE_ALWAYS_NPCS:
			if not _always_npc_has_talk(entry):
				continue
			var npc_id: String = String(entry.get("id", ""))
			var node = _always_npc_nodes.get(npc_id)
			if node == null or not is_instance_valid(node) or not node.visible:
				continue
			var dist: float = p.global_position.distance_to(node.global_position)
			if dist <= VILLAGE_TALK_NPC_RADIUS and dist < best_dist:
				best_dist = dist
				best_id = npc_id
	return best_id


func _try_open_nearest_always_npc_talk() -> bool:
	var npc_id: String = _nearest_always_npc_talk_id()
	if npc_id == "":
		return false
	_open_always_npc_talk_dialog(npc_id)
	return true


func _update_always_npc_talk_interaction() -> bool:
	var npc_id: String = _nearest_always_npc_talk_id()
	if npc_id == "":
		return false
	var node = _always_npc_nodes.get(npc_id)
	if node == null or not is_instance_valid(node):
		return false
	var near: Array[String] = _players_in_range_prefixes(node, VILLAGE_TALK_NPC_RADIUS)
	if near.is_empty():
		return false
	_show_float_interact_prompt(node, near, tr("VILLAGE_INTERACT_ACTION_TALK"))
	if _try_interact_prefixes(near):
		_open_always_npc_talk_dialog(npc_id)
	return true


func _tavern_npc_has_talk(entry: Dictionary) -> bool:
	var keys: Array = entry.get("dialogue_keys", [])
	return not keys.is_empty()


func _tavern_talk_node_for_id(npc_id: String):
	if _tavern_permanent_npc_nodes.has(npc_id):
		return _tavern_permanent_npc_nodes[npc_id]
	return _tavern_social_npc_nodes.get(npc_id)


func _nearest_tavern_talk_id() -> String:
	if not _is_in_tavern():
		return ""
	var best_id: String = ""
	var best_dist: float = INF
	var social_hours: bool = GameData.is_tavern_social_hours(_village_time_phase)
	for p in players:
		if p == null or not is_instance_valid(p):
			continue
		for entry in GameData.TAVERN_PERMANENT_NPCS:
			if not GameData.tavern_npc_available(entry):
				continue
			if not _tavern_npc_has_talk(entry):
				continue
			var npc_id: String = String(entry.get("id", ""))
			var node = _tavern_talk_node_for_id(npc_id)
			if node == null or not is_instance_valid(node) or not node.visible:
				continue
			var dist: float = p.global_position.distance_to(node.global_position)
			if dist <= VILLAGE_TALK_NPC_RADIUS and dist < best_dist:
				best_dist = dist
				best_id = npc_id
		if not social_hours:
			return best_id
		for entry in GameData.TAVERN_SOCIAL_NPCS:
			if not GameData.tavern_social_npc_available(entry):
				continue
			if not _tavern_npc_has_talk(entry):
				continue
			var npc_id: String = String(entry.get("id", ""))
			var node = _tavern_talk_node_for_id(npc_id)
			if node == null or not is_instance_valid(node) or not node.visible:
				continue
			var dist: float = p.global_position.distance_to(node.global_position)
			if dist <= VILLAGE_TALK_NPC_RADIUS and dist < best_dist:
				best_dist = dist
				best_id = npc_id
	return best_id


func _try_open_nearest_tavern_talk() -> bool:
	var npc_id: String = _nearest_tavern_talk_id()
	if npc_id == "":
		return false
	_open_tavern_talk_dialog(npc_id)
	return true


func _update_tavern_talk_interaction() -> bool:
	var npc_id: String = _nearest_tavern_talk_id()
	if npc_id == "":
		return false
	var node = _tavern_talk_node_for_id(npc_id)
	if node == null or not is_instance_valid(node):
		return false
	var near: Array[String] = _players_in_range_prefixes(node, VILLAGE_TALK_NPC_RADIUS)
	if near.is_empty():
		return false
	_show_float_interact_prompt(node, near, tr("VILLAGE_INTERACT_ACTION_TALK"))
	if _try_interact_prefixes(near):
		_open_tavern_talk_dialog(npc_id)
	return true


func _open_tavern_talk_dialog(npc_id: String) -> void:
	if _talk_dialog != null:
		return
	var entry: Dictionary = GameData.get_tavern_permanent_npc(npc_id)
	if entry.is_empty():
		entry = GameData.get_tavern_social_npc(npc_id)
	if entry.is_empty() or not _tavern_npc_has_talk(entry):
		return
	if String(entry.get("talk_kind", "")) == "headman":
		var headman_entry: Dictionary = GameData.get_village_always_npc("headman")
		if headman_entry.is_empty():
			headman_entry = entry
		_open_headman_dialog(headman_entry)
	else:
		_open_npc_random_talk(entry)


func _random_always_npc_dialogue_line(entry: Dictionary) -> String:
	var keys: Array = entry.get("dialogue_keys", [])
	if keys.is_empty():
		return ""
	var key: String = String(keys.pick_random())
	return tr(key) if key != "" else ""


func _open_always_npc_talk_dialog(npc_id: String) -> void:
	if _talk_dialog != null:
		return
	var entry: Dictionary = GameData.get_village_always_npc(npc_id)
	if entry.is_empty() or not _always_npc_has_talk(entry):
		return
	if npc_id == "headman":
		_open_headman_dialog(entry)
	else:
		_open_npc_random_talk(entry)


func _open_npc_random_talk(entry: Dictionary) -> void:
	get_tree().paused = true
	_talk_dialog = CanvasLayer.new()
	_talk_dialog.layer = 240
	_talk_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_talk_dialog)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	_talk_dialog.add_child(root)

	var bar := _make_talk_dialog_bar(root)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	bar.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	margin.add_child(hbox)

	var portrait_frame := Panel.new()
	portrait_frame.custom_minimum_size = Vector2(88, 88)
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.1, 0.12, 0.22); psb.border_color = Color(0.7, 0.55, 0.2)
	psb.border_width_left = 2; psb.border_width_right = 2
	psb.border_width_top = 2; psb.border_width_bottom = 2
	psb.corner_radius_top_left = 6; psb.corner_radius_top_right = 6
	psb.corner_radius_bottom_left = 6; psb.corner_radius_bottom_right = 6
	portrait_frame.add_theme_stylebox_override("panel", psb)
	hbox.add_child(portrait_frame)
	_build_talk_portrait(portrait_frame, entry)

	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	text_vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(text_vbox)

	var name_lbl := Label.new()
	var npc_name: String = tr(String(entry.get("name_key", "")))
	var subtitle_key: String = String(entry.get("subtitle_key", ""))
	if subtitle_key != "":
		npc_name += "　%s" % tr(subtitle_key)
	name_lbl.text = npc_name
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4))
	text_vbox.add_child(name_lbl)

	var line_lbl := Label.new()
	line_lbl.text = _random_always_npc_dialogue_line(entry)
	line_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_lbl.add_theme_font_size_override("font_size", 16)
	text_vbox.add_child(line_lbl)

	var close_btn := Button.new()
	close_btn.text = tr("NPC_TALK_CLOSE")
	close_btn.custom_minimum_size = Vector2(88, 0)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_close_talk_dialog)
	hbox.add_child(close_btn)
	close_btn.grab_focus()


func _open_headman_dialog(entry: Dictionary) -> void:
	if not GameState.quest_headman_intro_done:
		var pages: Array[String] = [
			tr("QUEST_HEADMAN_INTRO_PAGE_1"),
			tr("QUEST_HEADMAN_INTRO_PAGE_2"),
			tr("QUEST_HEADMAN_INTRO_PAGE_3"),
			tr("QUEST_HEADMAN_INTRO_PAGE_4"),
		]
		_open_sequential_talk_dialog(entry, pages, func() -> void:
			GameState.quest_headman_intro_done = true
			GameState.save_to_disk()
			_refresh_quest_markers()
			SettingsOverlay._refresh_quest_button_label()
			call_deferred("_open_headman_starter_summon_dialog", entry))
	elif not GameState.quest_headman_starter_summon_done:
		_open_headman_starter_summon_dialog(entry)
	elif GameState.blacksmith_rescued and not GameState.quest_blacksmith_rewarded:
		var pages: Array[String] = [
			tr("QUEST_HEADMAN_REWARD_PAGE_1"),
			tr("QUEST_HEADMAN_REWARD_PAGE_2"),
		]
		_open_sequential_talk_dialog(entry, pages, func() -> void:
			GameState.gold += GameState.QUEST_BLACKSMITH_GOLD_REWARD
			GameState.grant_material("iron", GameState.QUEST_BLACKSMITH_IRON_REWARD)
			GameState.quest_blacksmith_rewarded = true
			GameState.complete_quest("rescue_blacksmith")
			GameState.save_to_disk()
			_refresh_quest_markers()
			SettingsOverlay._refresh_quest_button_label())
	else:
		_open_npc_random_talk(entry)


func _open_headman_starter_summon_dialog(_entry: Dictionary) -> void:
	if GameState.quest_headman_starter_summon_done or _headman_starter_dialog != null:
		return
	var ids: Array[String] = GameData.playable_summon_ids()
	if ids.is_empty():
		return
	get_tree().paused = true
	_headman_starter_idx = 0
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_headman_starter_dialog = CanvasLayer.new()
	_headman_starter_dialog.layer = 245
	_headman_starter_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_headman_starter_dialog)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	_headman_starter_dialog.add_child(root)
	_add_modal_dim_bg(root, HOUSE_DIALOG_DIM_ALPHA)

	var panel := PanelContainer.new()
	var panel_w: float = min(640.0, vp.x - 40.0)
	var panel_h: float = min(460.0, vp.y - 40.0)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	_style_house_modal_panel(panel)
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = tr("QUEST_HEADMAN_STARTER_SUMMON_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	vbox.add_child(title)

	var intro := Label.new()
	intro.text = tr("QUEST_HEADMAN_STARTER_SUMMON_INTRO")
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_font_size_override("font_size", 14)
	vbox.add_child(intro)

	var preview_panel := Panel.new()
	preview_panel.custom_minimum_size = Vector2(0, 160)
	vbox.add_child(preview_panel)
	_headman_starter_preview = _make_house_preview_anim(preview_panel, 12.0)

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 12)
	vbox.add_child(nav)

	var prev_btn := Button.new()
	prev_btn.custom_minimum_size = Vector2(44, 44)
	GameData.apply_icon_button(prev_btn, GameData.UI_ICON_ARROW_LEFT, "<")
	prev_btn.pressed.connect(_cycle_headman_starter_summon.bind(-1))
	nav.add_child(prev_btn)

	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_child(name_box)
	_headman_starter_name_label = Label.new()
	_headman_starter_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_headman_starter_name_label.add_theme_font_size_override("font_size", 20)
	_headman_starter_name_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
	name_box.add_child(_headman_starter_name_label)
	_headman_starter_desc_label = Label.new()
	_headman_starter_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_headman_starter_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_headman_starter_desc_label.add_theme_font_size_override("font_size", 13)
	name_box.add_child(_headman_starter_desc_label)

	var next_btn := Button.new()
	next_btn.custom_minimum_size = Vector2(44, 44)
	GameData.apply_icon_button(next_btn, GameData.UI_ICON_ARROW_RIGHT, ">")
	next_btn.pressed.connect(_cycle_headman_starter_summon.bind(1))
	nav.add_child(next_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = tr("QUEST_HEADMAN_STARTER_SUMMON_CONFIRM")
	confirm_btn.pressed.connect(_confirm_headman_starter_summon)
	vbox.add_child(confirm_btn)

	_refresh_headman_starter_summon_panel()


func _cycle_headman_starter_summon(direction: int) -> void:
	var ids: Array[String] = GameData.playable_summon_ids()
	if ids.is_empty():
		return
	_headman_starter_idx = (_headman_starter_idx + direction + ids.size()) % ids.size()
	_refresh_headman_starter_summon_panel()


func _refresh_headman_starter_summon_panel() -> void:
	var ids: Array[String] = GameData.playable_summon_ids()
	if ids.is_empty():
		return
	var sid: String = ids[_headman_starter_idx % ids.size()]
	if _headman_starter_name_label != null:
		_headman_starter_name_label.text = GameData.tr_summon_egg_name(sid)
	if _headman_starter_desc_label != null:
		var sdef: Dictionary = GameData.get_summon_def(sid)
		_headman_starter_desc_label.text = "%s｜%s" % [
			GameData.tr_summon_type(sdef), tr(sdef.get("desc_key", ""))]
	if _headman_starter_preview != null:
		_headman_starter_preview.setup_summon(sid, "p1")


func _confirm_headman_starter_summon() -> void:
	var ids: Array[String] = GameData.playable_summon_ids()
	if ids.is_empty():
		return
	var sid: String = ids[_headman_starter_idx % ids.size()]
	if not GameState.grant_summon_starter_egg(sid):
		return
	_close_headman_starter_summon_dialog()
	_refresh_quest_markers()
	_refresh_village_summon_followers()
	SettingsOverlay._refresh_quest_button_label()


func _close_headman_starter_summon_dialog() -> void:
	if _headman_starter_dialog != null and is_instance_valid(_headman_starter_dialog):
		_headman_starter_dialog.queue_free()
	_headman_starter_dialog = null
	_headman_starter_name_label = null
	_headman_starter_desc_label = null
	_headman_starter_preview = null
	get_tree().paused = false


## 序列分頁對話（底部條）
func _open_sequential_talk_dialog(
		entry: Dictionary, pages: Array[String],
		on_finish: Callable = Callable()) -> void:
	if _talk_dialog != null or pages.is_empty():
		return
	_seq_pages = pages
	_seq_page_idx = 0
	_seq_on_finish = on_finish

	get_tree().paused = true
	_talk_dialog = CanvasLayer.new()
	_talk_dialog.layer = 240
	_talk_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_talk_dialog)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	_talk_dialog.add_child(root)

	var bar := _make_talk_dialog_bar(root)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	bar.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	margin.add_child(hbox)

	var portrait_frame := Panel.new()
	portrait_frame.custom_minimum_size = Vector2(88, 88)
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.1, 0.12, 0.22); psb.border_color = Color(0.7, 0.55, 0.2)
	psb.border_width_left = 2; psb.border_width_right = 2
	psb.border_width_top = 2; psb.border_width_bottom = 2
	psb.corner_radius_top_left = 6; psb.corner_radius_top_right = 6
	psb.corner_radius_bottom_left = 6; psb.corner_radius_bottom_right = 6
	portrait_frame.add_theme_stylebox_override("panel", psb)
	hbox.add_child(portrait_frame)
	_build_talk_portrait(portrait_frame, entry)

	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	text_vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(text_vbox)

	var name_lbl := Label.new()
	var npc_name: String = tr(String(entry.get("name_key", "")))
	var subtitle_key: String = String(entry.get("subtitle_key", ""))
	if subtitle_key != "":
		npc_name += "　%s" % tr(subtitle_key)
	name_lbl.text = npc_name
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4))
	text_vbox.add_child(name_lbl)

	_seq_text_label = Label.new()
	_seq_text_label.text = pages[0]
	_seq_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_seq_text_label.add_theme_font_size_override("font_size", 16)
	_seq_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_vbox.add_child(_seq_text_label)

	_seq_next_btn = Button.new()
	_seq_next_btn.custom_minimum_size = Vector2(96, 0)
	_seq_next_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_seq_next_btn.pressed.connect(_seq_dialog_advance)
	hbox.add_child(_seq_next_btn)
	_seq_update_btn_text()
	_seq_next_btn.grab_focus()


func _seq_update_btn_text() -> void:
	if _seq_next_btn == null or not is_instance_valid(_seq_next_btn):
		return
	_seq_next_btn.text = tr("NPC_TALK_CLOSE") \
		if _seq_page_idx >= _seq_pages.size() - 1 \
		else tr("NPC_TALK_CONTINUE")


func _seq_dialog_advance() -> void:
	_seq_page_idx += 1
	if _seq_page_idx >= _seq_pages.size():
		if _seq_on_finish.is_valid():
			_seq_on_finish.call()
		_seq_text_label = null
		_seq_next_btn = null
		_close_talk_dialog()
		return
	if _seq_text_label != null and is_instance_valid(_seq_text_label):
		_seq_text_label.text = _seq_pages[_seq_page_idx]
	_seq_update_btn_text()


func _build_talk_portrait(parent: Panel, entry: Dictionary) -> void:
	_build_npc_strip_portrait(parent,
		String(entry.get("strip_id", "")),
		int(entry.get("anim_row", 0)))


func _build_npc_strip_portrait(parent: Panel, strip_id: String, anim_row: int = 0) -> void:
	var strip_def: Dictionary = GameData.get_village_npc_strip_def(strip_id)
	if strip_def.is_empty():
		return
	var strip_path: String = String(strip_def.get("strip", ""))
	if strip_path == "" or not ResourceLoader.exists(strip_path):
		return
	var tex: Texture2D = GameData.resolve_frame_texture(strip_path)
	if tex == null:
		return
	var hframes: int = int(strip_def.get("hframes", 1))
	var vframes: int = int(strip_def.get("vframes", 1))
	var frame_w: float = tex.get_width() / float(hframes)
	var frame_h: float = tex.get_height() / float(vframes)

	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(0.0, anim_row * frame_h, frame_w, frame_h)

	var tr_rect := TextureRect.new()
	tr_rect.texture = atlas
	tr_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tr_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(tr_rect)


## 共用底部對話條框架。返回 {layer, status, actions, close}
## actions 為 HBoxContainer（橫排按鈕）
func _open_bottom_bar_dialog(
		npc_name: String, npc_subtitle: String,
		strip_id: String = "", anim_row: int = 0,
		bar_h: float = 172.0) -> Dictionary:
	var layer := CanvasLayer.new()
	layer.layer = 240
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(layer)
	get_tree().paused = true

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(root)

	var bar := _make_talk_dialog_bar(root, bar_h)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	bar.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 18)
	margin.add_child(hbox)

	# 左：頭像
	var portrait_frame := Panel.new()
	portrait_frame.custom_minimum_size = Vector2(88, 88)
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.1, 0.12, 0.22)
	psb.border_color = Color(0.7, 0.55, 0.2)
	psb.border_width_left = 2
	psb.border_width_right = 2
	psb.border_width_top = 2
	psb.border_width_bottom = 2
	psb.corner_radius_top_left = 6
	psb.corner_radius_top_right = 6
	psb.corner_radius_bottom_left = 6
	psb.corner_radius_bottom_right = 6
	portrait_frame.add_theme_stylebox_override("panel", psb)
	hbox.add_child(portrait_frame)
	if strip_id != "":
		_build_npc_strip_portrait(portrait_frame, strip_id, anim_row)

	# 中：名稱 + 狀態文字 + 動作按鈕
	var center_vbox := VBoxContainer.new()
	center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(center_vbox)

	var name_lbl := Label.new()
	var full_name: String = npc_name
	if npc_subtitle != "":
		full_name += "　%s" % npc_subtitle
	name_lbl.text = full_name
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4))
	center_vbox.add_child(name_lbl)

	var status_lbl := Label.new()
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_lbl.add_theme_font_size_override("font_size", 14)
	status_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_vbox.add_child(status_lbl)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	center_vbox.add_child(actions)

	# 右：關閉鈕
	var close_btn := Button.new()
	close_btn.text = tr("NPC_TALK_CLOSE")
	close_btn.custom_minimum_size = Vector2(88, 0)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(close_btn)

	return {"layer": layer, "status": status_lbl, "actions": actions, "close": close_btn}


func _close_talk_dialog() -> void:
	if _talk_dialog != null and is_instance_valid(_talk_dialog):
		_talk_dialog.queue_free()
	_talk_dialog = null
	_seq_text_label = null
	_seq_next_btn = null
	if not _any_modal_village_ui_open():
		get_tree().paused = false


# ── 任務感嘆號標記 ─────────────────────────────────────
func _spawn_quest_markers() -> void:
	_quest_marker_layer = CanvasLayer.new()
	_quest_marker_layer.layer = 110
	_quest_marker_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_quest_marker_layer)

	var lbl := Label.new()
	lbl.text = "！"
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.1))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.visible = false
	_quest_marker_layer.add_child(lbl)
	_quest_marker_labels["headman"] = lbl
	_refresh_quest_markers()


func _refresh_quest_markers() -> void:
	var lbl: Label = _quest_marker_labels.get("headman") as Label
	if lbl == null:
		return
	if _is_in_tavern():
		lbl.visible = false
		return
	lbl.visible = (not GameState.quest_headman_intro_done) \
		or (not GameState.quest_headman_starter_summon_done) \
		or (GameState.blacksmith_rescued and not GameState.quest_blacksmith_rewarded)


func _update_quest_marker_positions() -> void:
	if _quest_marker_layer == null:
		return
	for npc_id in _quest_marker_labels:
		var lbl: Label = _quest_marker_labels[npc_id] as Label
		if lbl == null or not lbl.visible:
			continue
		var node = _always_npc_nodes.get(npc_id)
		if node == null or not is_instance_valid(node) or not node.visible:
			lbl.visible = false
			continue
		var screen_pos: Vector2 = get_viewport().get_canvas_transform() * node.global_position
		lbl.position = screen_pos - Vector2(lbl.size.x * 0.5 + 2.0, 72.0)


func _try_open_nearest_facility_dialog() -> bool:
	for fid in _facility_nodes.keys():
		var node: Node = _facility_nodes[fid]
		if node != null and is_instance_valid(node) \
				and _players_near_node(node, VILLAGE_FACILITY_INTERACT_RADIUS):
			_open_facility_dialog(String(fid))
			return true
	return false


func _update_facility_interaction() -> bool:
	for fid in _facility_nodes.keys():
		var node: Node = _facility_nodes[fid]
		if node == null or not is_instance_valid(node) or not node.visible:
			continue
		var near: Array[String] = _players_in_range_prefixes(
			node, VILLAGE_FACILITY_INTERACT_RADIUS)
		if near.is_empty():
			continue
		var fdef: Dictionary = GameData.get_village_facility_def(String(fid))
		var action_text: String = tr("VILLAGE_INTERACT_ACTION_COLLECT_FMT") % \
				GameData.tr_field(fdef, "name", false)
		_show_float_interact_prompt(node, near, action_text)
		if _try_interact_prefixes(near):
			_open_facility_dialog(String(fid))
		return true
	return false


func _open_facility_dialog(facility_id: String) -> void:
	if _facility_dialog != null:
		return
	var fdef: Dictionary = GameData.get_village_facility_def(facility_id)
	if fdef.is_empty():
		return
	_facility_dialog_id = facility_id
	var strip_id: String = String(fdef.get("npc_strip", ""))
	var ui: Dictionary = _open_bottom_bar_dialog(
		GameData.tr_field(fdef, "name", false), "", strip_id)
	_facility_dialog = ui["layer"] as CanvasLayer
	_facility_status_label = ui["status"] as Label
	var actions: HBoxContainer = ui["actions"] as HBoxContainer
	var collect_btn := Button.new()
	collect_btn.text = tr(String(fdef.get("collect_key", "VILLAGE_FACILITY_COLLECT")))
	collect_btn.pressed.connect(_on_facility_collect_pressed)
	actions.add_child(collect_btn)
	collect_btn.grab_focus()
	(ui["close"] as Button).pressed.connect(_close_facility_dialog)
	_refresh_facility_dialog()


func _refresh_facility_dialog(status: String = "") -> void:
	if _facility_status_label == null or _facility_dialog_id == "":
		return
	if status != "":
		_facility_status_label.text = status
		return
	var left: float = GameState.village_facility_collect_cooldown_left(_facility_dialog_id)
	var fdef: Dictionary = GameData.get_village_facility_def(_facility_dialog_id)
	var parts: Array[String] = []
	if bool(fdef.get("resource_collect", false)):
		parts.append(tr("VILLAGE_RESOURCE_COLLECT_HINT"))
		for line in GameData.village_facility_resource_odds_lines(
				_facility_dialog_id, GameState.completed_stage_ids):
			parts.append(line)
		parts.append("")
	if left > 0.0:
		parts.append(tr("VILLAGE_FACILITY_COOLDOWN_FMT") % int(ceil(left)))
	else:
		parts.append(tr("VILLAGE_FACILITY_READY"))
	_facility_status_label.text = "\n".join(parts)


func _on_facility_collect_pressed() -> void:
	if _facility_dialog_id == "":
		return
	var granted: Dictionary = GameState.try_collect_village_facility(_facility_dialog_id)
	if granted.is_empty():
		_refresh_facility_dialog()
		return
	var parts: Array[String] = []
	for mid in granted.keys():
		parts.append("%s x%d" % [GameData.tr_material_name(String(mid)), int(granted[mid])])
	_refresh_facility_dialog(tr("VILLAGE_FACILITY_COLLECT_DONE_FMT") % "、".join(parts))


func _close_facility_dialog() -> void:
	if _facility_dialog != null:
		_facility_dialog.queue_free()
	_facility_dialog = null
	_facility_dialog_id = ""
	_facility_status_label = null
	if not _any_modal_village_ui_open():
		get_tree().paused = false


func _spawn_p1_house_marker() -> void:
	var slot: Node = _find_map_object_by_name(GameData.VILLAGE_MAP_HOME_P1_SLOTS)
	var pos: Vector2 = _map_marker_position(slot, Vector2(_map_size.x * 0.47, floor_y - 42.0))
	if slot is Node2D:
		pos = (slot as Node2D).global_position
	_p1_house_node = _make_house_interact_anchor("VillageP1House", pos)


func _make_house_interact_anchor(node_name: String, pos: Vector2) -> Node2D:
	var home := Node2D.new()
	home.name = node_name
	home.global_position = pos
	home.set_meta("float_prompt_offset_y", -56.0)
	add_child(home)
	return home


func _player_near_node(node, radius: float, input_prefix: String) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	for p in players:
		if p == null or not is_instance_valid(p):
			continue
		if String(p.input_prefix) != input_prefix:
			continue
		if p.global_position.distance_to(node.global_position) <= radius:
			return true
	return false


func _update_p1_house_interaction() -> bool:
	if _p1_house_node == null or not is_instance_valid(_p1_house_node):
		return false
	var near: Array[String] = _players_in_range_prefixes(
		_p1_house_node, P1_HOUSE_INTERACT_RADIUS, "p1")
	if near.is_empty():
		return false
	_show_float_interact_prompt(
		_p1_house_node, near, tr("VILLAGE_INTERACT_ACTION_HOUSE"))
	if _try_interact_prefixes(near):
		_open_house_dialog("p1")
	return true


func _update_p2_house_interaction() -> bool:
	if not GameState.two_players:
		return false
	if _p2_house_node == null or not is_instance_valid(_p2_house_node):
		return false
	var near: Array[String] = _players_in_range_prefixes(
		_p2_house_node, P1_HOUSE_INTERACT_RADIUS, "p2")
	if near.is_empty():
		return false
	_show_float_interact_prompt(
		_p2_house_node, near, tr("VILLAGE_INTERACT_ACTION_HOUSE"))
	if _try_interact_prefixes(near):
		_open_house_dialog("p2")
	return true


func _update_tavern_door_interaction() -> bool:
	if _tavern_door_node == null or not is_instance_valid(_tavern_door_node):
		return false
	var near: Array[String] = _players_in_range_prefixes(_tavern_door_node, TAVERN_DOOR_INTERACT_RADIUS)
	if near.is_empty():
		return false
	var open: bool = GameData.is_tavern_open_for_entry(_village_time_phase)
	var action: String = tr("VILLAGE_INTERACT_ACTION_TAVERN_ENTER") if open \
		else tr("VILLAGE_INTERACT_ACTION_TAVERN_CLOSED")
	_show_float_interact_prompt(_tavern_door_node, near, action)
	if _try_interact_prefixes(near):
		if open:
			_enter_tavern()
		else:
			_show_tavern_closed_notice()
	return true


func _update_tavern_stair_up_interaction() -> bool:
	if _tavern_floor != 1:
		return false
	if _tavern_stair_up_node == null or not is_instance_valid(_tavern_stair_up_node):
		return false
	var near: Array[String] = _players_in_range_prefixes(_tavern_stair_up_node, TAVERN_STAIR_INTERACT_RADIUS)
	if near.is_empty():
		return false
	_show_float_interact_prompt(_tavern_stair_up_node, near, tr("VILLAGE_INTERACT_ACTION_TAVERN_STAIR_UP"))
	if _try_interact_prefixes(near):
		_tavern_go_upstairs()
	return true


func _update_tavern_stair_down_interaction() -> bool:
	if _tavern_floor != 2:
		return false
	if _tavern_stair_down_node == null or not is_instance_valid(_tavern_stair_down_node):
		return false
	var near: Array[String] = _players_in_range_prefixes(_tavern_stair_down_node, TAVERN_STAIR_INTERACT_RADIUS)
	if near.is_empty():
		return false
	_show_float_interact_prompt(_tavern_stair_down_node, near, tr("VILLAGE_INTERACT_ACTION_TAVERN_STAIR_DOWN"))
	if _try_interact_prefixes(near):
		_tavern_go_downstairs()
	return true


func _update_tavern_exit_interaction() -> bool:
	if _tavern_floor != 1:
		return false
	if _tavern_exit_node == null or not is_instance_valid(_tavern_exit_node):
		return false
	var near: Array[String] = _players_in_range_prefixes(_tavern_exit_node, TAVERN_EXIT_INTERACT_RADIUS)
	if near.is_empty():
		return false
	_show_float_interact_prompt(_tavern_exit_node, near, tr("VILLAGE_INTERACT_ACTION_TAVERN_EXIT"))
	if _try_interact_prefixes(near):
		_exit_tavern()
	return true


func _update_entrance_interaction() -> bool:
	if _entrance_node == null or not is_instance_valid(_entrance_node):
		return false
	var near: Array[String] = _players_in_range_prefixes(_entrance_node, ENTRANCE_INTERACT_RADIUS)
	if near.is_empty():
		return false
	_show_float_interact_prompt(_entrance_node, near, tr("VILLAGE_INTERACT_ACTION_ENTRANCE"))
	if _try_interact_prefixes(near):
		_open_expedition_dialog()
	return true


func _open_expedition_dialog() -> void:
	if _expedition_dialog != null:
		return
	get_tree().paused = true
	var ui: Dictionary = _open_simple_village_dialog(
		tr("VILLAGE_EXPEDITION_TITLE"), tr("VILLAGE_EXPEDITION_DESC"))
	_expedition_dialog = ui["layer"] as CanvasLayer
	var start_btn := Button.new()
	start_btn.text = tr("VILLAGE_EXPEDITION_START")
	start_btn.pressed.connect(_start_expedition)
	(ui["actions"] as VBoxContainer).add_child(start_btn)
	start_btn.grab_focus()
	(ui["close"] as Button).pressed.connect(_close_expedition_dialog)


func _close_expedition_dialog() -> void:
	if _expedition_dialog != null and is_instance_valid(_expedition_dialog):
		_expedition_dialog.queue_free()
	_expedition_dialog = null
	if not _any_modal_village_ui_open():
		get_tree().paused = false


func _start_expedition() -> void:
	if _transitioning:
		return
	AudioManager.play_sfx("ui_confirm")
	_transitioning = true
	get_tree().paused = false
	if _expedition_dialog != null and is_instance_valid(_expedition_dialog):
		_expedition_dialog.queue_free()
	_expedition_dialog = null
	if is_inside_tree():
		GameState.next_scene = "battle"
		GameState.character_select_return_scene = "village"
		get_tree().change_scene_to_file("res://scenes/CharacterSelect.tscn")


func _update_p2_house_site_interaction() -> bool:
	if _p2_house_node == null or not is_instance_valid(_p2_house_node):
		return false
	var near: Array[String] = _players_in_range_prefixes(_p2_house_node, P1_HOUSE_INTERACT_RADIUS)
	if near.is_empty():
		return false
	var p2_near: bool = GameState.two_players and near.has("p2")
	var p1_near: bool = near.has("p1")
	# P2 靠近：顯示一般小屋提示，P2 按確認開啟自己的小屋
	if p2_near:
		_show_float_interact_prompt(_p2_house_node, ["p2"], tr("VILLAGE_INTERACT_ACTION_HOUSE"))
		if _try_interact_prefixes(["p2"]):
			_open_house_dialog("p2")
			return true
	# P1 靠近：顯示加入／離隊提示，P1 按確認執行
	if p1_near:
		if GameState.two_players:
			_show_float_interact_prompt(_p2_house_node, ["p1"], tr("VILLAGE_INTERACT_ACTION_P2_LEAVE"))
			if _try_interact_prefixes(["p1"]):
				_open_p2_leave_dialog()
		else:
			_show_float_interact_prompt(_p2_house_node, ["p1"], tr("VILLAGE_INTERACT_ACTION_P2_JOIN"))
			if _try_interact_prefixes(["p1"]):
				_open_p2_join_dialog()
	return true


func _try_open_p2_house_site_interaction() -> void:
	# 觸控互動固定由 P1 觸發
	if GameState.two_players:
		_open_p2_leave_dialog()
	else:
		_open_p2_join_dialog()


func _open_p2_join_dialog() -> void:
	if _p2_join_dialog != null:
		return
	get_tree().paused = true
	var ui: Dictionary = _open_simple_village_dialog(
		tr("VILLAGE_P2_JOIN_TITLE"), tr("VILLAGE_P2_JOIN_DESC"))
	_p2_join_dialog = ui["layer"] as CanvasLayer
	var join_btn := Button.new()
	join_btn.text = tr("VILLAGE_P2_JOIN_CONFIRM")
	join_btn.pressed.connect(_confirm_p2_join)
	(ui["actions"] as VBoxContainer).add_child(join_btn)
	join_btn.grab_focus()
	(ui["close"] as Button).pressed.connect(_close_p2_join_dialog)


func _confirm_p2_join() -> void:
	GameState.two_players = true
	_close_p2_join_dialog()
	_spawn_p2_only()


func _spawn_p2_only() -> void:
	var feet_x: float = spawn_origin.x
	var p2 = PLAYER_SCENE.instantiate()
	p2.input_prefix = "p2"
	p2.slot_index = 1
	p2.village_mode = true
	p2.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(p2)
	p2.setup_from_character(GameState.p2_character)
	# 站在 P1 旁邊；若 P1 存在則以其位置為基準
	var ref_x: float = feet_x
	if players.size() > 0 and players[0] != null and is_instance_valid(players[0]):
		ref_x = players[0].position.x
	p2.position = Vector2(ref_x + 60.0, floor_y - p2.body_radius)
	players.append(p2)
	_refresh_village_summon_followers()


func _close_p2_join_dialog() -> void:
	if _p2_join_dialog != null and is_instance_valid(_p2_join_dialog):
		_p2_join_dialog.queue_free()
	_p2_join_dialog = null
	if not _any_modal_village_ui_open():
		get_tree().paused = false


func _open_p2_leave_dialog() -> void:
	if _p2_leave_dialog != null:
		return
	get_tree().paused = true
	var ui: Dictionary = _open_simple_village_dialog(
		tr("VILLAGE_P2_LEAVE_TITLE"), tr("VILLAGE_P2_LEAVE_DESC"))
	_p2_leave_dialog = ui["layer"] as CanvasLayer
	var leave_btn := Button.new()
	leave_btn.text = tr("VILLAGE_P2_LEAVE_CONFIRM")
	leave_btn.pressed.connect(_confirm_p2_leave)
	(ui["actions"] as VBoxContainer).add_child(leave_btn)
	leave_btn.grab_focus()
	(ui["close"] as Button).pressed.connect(_close_p2_leave_dialog)


func _confirm_p2_leave() -> void:
	GameState.two_players = false
	for p in players:
		if p != null and is_instance_valid(p) and String(p.get("input_prefix")) == "p2":
			p.queue_free()
	players = players.filter(func(p): return p != null and is_instance_valid(p) \
		and String(p.get("input_prefix")) != "p2")
	_refresh_village_summon_followers()
	_close_p2_leave_dialog()


func _close_p2_leave_dialog() -> void:
	if _p2_leave_dialog != null and is_instance_valid(_p2_leave_dialog):
		_p2_leave_dialog.queue_free()
	_p2_leave_dialog = null
	if not _any_modal_village_ui_open():
		get_tree().paused = false


func _spawn_entrance_marker() -> void:
	var slot: Node = _find_map_object_by_name(GameData.VILLAGE_MAP_ENTRANCE_SLOTS)
	var pos: Vector2 = _map_marker_position(slot, Vector2(_map_size.x * 0.88, floor_y - 42.0))
	if slot is Node2D:
		pos = (slot as Node2D).global_position
	_entrance_node = Node2D.new()
	_entrance_node.name = "VillageEntrance"
	_entrance_node.global_position = pos
	_entrance_node.set_meta("float_prompt_offset_y", -56.0)
	add_child(_entrance_node)


func _spawn_p2_house_marker() -> void:
	var slot: Node = _find_map_object_by_name(GameData.VILLAGE_MAP_HOME_P2_SLOTS)
	var pos: Vector2 = _map_marker_position(slot, Vector2(_map_size.x * 0.53, floor_y - 42.0))
	if slot is Node2D:
		pos = (slot as Node2D).global_position
	_p2_house_node = _make_house_interact_anchor("VillageP2House", pos)


func _style_house_modal_panel(panel: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.15, 0.06)
	sb.border_color = Color(0.52, 0.6, 0.76, 0.88)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", sb)
	panel.clip_contents = true
	GameData.attach_ui_pattern_to_panel(
		panel, GameData.UI_PATTERN_STYLE_PANEL, GameData.UI_BG_CTX_PANEL)


func _add_modal_dim_bg(root: Control, alpha: float = HOUSE_DIALOG_DIM_ALPHA) -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, alpha)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)


func _make_talk_dialog_bar(root: Control, bar_h: float = 128.0) -> PanelContainer:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var bar_size := Vector2(vp.x, bar_h)

	var shell := Control.new()
	shell.anchor_left = 0.0
	shell.anchor_right = 1.0
	shell.anchor_top = 1.0
	shell.anchor_bottom = 1.0
	shell.offset_top = -bar_h
	shell.offset_bottom = 0.0
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	shell.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(shell)

	var pattern_bg := GameData.attach_ui_pattern_bg(
		shell, GameData.UI_PATTERN_STYLE_DIALOG, GameData.UI_BG_CTX_DIALOG, 0)
	GameData.finalize_pattern_bg_size(pattern_bg, bar_size)

	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.clip_contents = true
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(0.7, 0.55, 0.2)
	sb.border_width_top = 2
	bar.add_theme_stylebox_override("panel", sb)
	shell.add_child(bar)

	if not shell.resized.is_connected(_on_talk_bar_shell_resized):
		shell.resized.connect(_on_talk_bar_shell_resized.bind(pattern_bg))
	return bar


func _on_talk_bar_shell_resized(pattern_bg: Control) -> void:
	if not is_instance_valid(pattern_bg):
		return
	if pattern_bg.has_method("sync_to_parent_size"):
		pattern_bg.sync_to_parent_size()


func _make_house_preview_anim(panel: Panel, margin: float = 8.0) -> HousePreviewAnimT:
	var anim := HousePreviewAnimT.new()
	anim.set_anchors_preset(Control.PRESET_FULL_RECT)
	anim.offset_left = margin
	anim.offset_top = margin
	anim.offset_right = -margin
	anim.offset_bottom = -margin
	panel.add_child(anim)
	return anim


func _add_house_preview_column(
		parent_row: HBoxContainer,
		title_text: String,
		title_color: Color,
		name_color: Color) -> Dictionary:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	parent_row.add_child(col)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", title_color)
	col.add_child(title)
	var preview_panel := Panel.new()
	preview_panel.custom_minimum_size = Vector2(120, 120)
	col.add_child(preview_panel)
	var anim := _make_house_preview_anim(preview_panel)
	var name_lbl := Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", name_color)
	col.add_child(name_lbl)
	return {"anim": anim, "name": name_lbl}


func _add_house_char_tri_preview(parent_col: VBoxContainer) -> Dictionary:
	var title := Label.new()
	title.text = tr("P1_HOUSE_PREVIEW_CHAR")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.65))
	parent_col.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	parent_col.add_child(row)
	var idle_slot := _add_house_weapon_effect_slot(
		row, tr("P1_HOUSE_CHAR_PREVIEW_IDLE"), Color(1.0, 0.88, 0.65), Vector2(112, 112))
	var walk_slot := _add_house_weapon_effect_slot(
		row, tr("P1_HOUSE_CHAR_PREVIEW_WALK"), Color(1.0, 0.92, 0.7), Vector2(112, 112))
	var attack_slot := _add_house_weapon_effect_slot(
		row, tr("P1_HOUSE_CHAR_PREVIEW_ATTACK"), Color(0.95, 0.78, 0.62), Vector2(112, 112))
	var name_lbl := Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	parent_col.add_child(name_lbl)
	return {
		"idle": idle_slot["anim"],
		"walk": walk_slot["anim"],
		"attack": attack_slot["anim"],
		"name": name_lbl,
	}


func _add_house_weapon_tri_preview(parent_col: VBoxContainer) -> Dictionary:
	var title := Label.new()
	title.text = tr("P1_HOUSE_PREVIEW_WEAPON")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.72, 0.88, 1.0))
	parent_col.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	parent_col.add_child(row)
	var hit_slot := _add_house_weapon_effect_slot(
		row, tr("P1_HOUSE_WEAPON_PREVIEW_HIT"), Color(0.95, 0.75, 0.55))
	var proj_slot := _add_house_weapon_effect_slot(
		row, tr("P1_HOUSE_WEAPON_PREVIEW_PROJECTILE"), Color(0.72, 0.88, 1.0))
	var extra_slot := _add_house_weapon_effect_slot(
		row, tr("P1_HOUSE_WEAPON_PREVIEW_EXTRA"), Color(0.78, 0.92, 0.72))
	var name_lbl := Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0))
	parent_col.add_child(name_lbl)
	return {
		"hit": hit_slot["anim"],
		"projectile": proj_slot["anim"],
		"extra": extra_slot["anim"],
		"name": name_lbl,
	}


func _add_house_weapon_effect_slot(
		parent_row: HBoxContainer,
		title_text: String,
		title_color: Color,
		panel_size: Vector2 = Vector2(88, 88)) -> Dictionary:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	parent_row.add_child(col)
	var lbl := Label.new()
	lbl.text = title_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", title_color)
	col.add_child(lbl)
	var preview_panel := Panel.new()
	preview_panel.custom_minimum_size = panel_size
	col.add_child(preview_panel)
	var anim := _make_house_preview_anim(preview_panel, 6.0)
	return {"anim": anim}


func _open_house_dialog(player_slot: String) -> void:
	if _house_dialog != null:
		return
	if player_slot != "p1" and player_slot != "p2":
		return
	if player_slot == "p2" and not GameState.two_players:
		return
	_house_player_slot = player_slot
	_house_char_index = _house_dialog_start_char_index()
	_house_weapon_index = _house_dialog_start_weapon_index()
	get_tree().paused = true
	_house_dialog = CanvasLayer.new()
	_house_dialog.layer = 240
	_house_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_house_dialog)

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_house_dialog.add_child(root)

	_add_modal_dim_bg(root)

	var panel := PanelContainer.new()
	var panel_w: float = min(680.0, vp.x - 32.0)
	var panel_h: float = min(460.0, vp.y - 32.0)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	_style_house_modal_panel(panel)
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = tr("P2_HOUSE_TITLE") if _house_player_slot == "p2" else tr("P1_HOUSE_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	vbox.add_child(title)

	var intro := Label.new()
	intro.text = tr("P2_HOUSE_INTRO") if _house_player_slot == "p2" else tr("P1_HOUSE_INTRO")
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 13)
	vbox.add_child(intro)

	# 雙欄預覽：左角色、右武器
	var preview_row := HBoxContainer.new()
	preview_row.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_row.add_theme_constant_override("separation", 20)
	vbox.add_child(preview_row)

	var char_col := VBoxContainer.new()
	char_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_col.add_theme_constant_override("separation", 6)
	preview_row.add_child(char_col)

	var char_title := Label.new()
	char_title.text = tr("P1_HOUSE_PREVIEW_CHAR")
	char_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	char_title.add_theme_font_size_override("font_size", 15)
	char_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.65))
	char_col.add_child(char_title)

	var char_nav := HBoxContainer.new()
	char_nav.alignment = BoxContainer.ALIGNMENT_CENTER
	char_nav.add_theme_constant_override("separation", 8)
	char_col.add_child(char_nav)

	var char_prev_btn := Button.new()
	char_prev_btn.custom_minimum_size = Vector2(44, 44)
	GameData.apply_icon_button(char_prev_btn, GameData.UI_ICON_ARROW_LEFT, tr("P1_HOUSE_CHAR_PREV_FALLBACK"))
	char_prev_btn.pressed.connect(_on_p1_house_char_prev)
	char_nav.add_child(char_prev_btn)

	var char_preview_panel := Panel.new()
	char_preview_panel.custom_minimum_size = Vector2(140, 140)
	char_nav.add_child(char_preview_panel)

	_house_preview = _make_house_preview_anim(char_preview_panel, 8.0)

	var char_next_btn := Button.new()
	char_next_btn.custom_minimum_size = Vector2(44, 44)
	GameData.apply_icon_button(char_next_btn, GameData.UI_ICON_ARROW_RIGHT, tr("P1_HOUSE_CHAR_NEXT_FALLBACK"))
	char_next_btn.pressed.connect(_on_p1_house_char_next)
	char_nav.add_child(char_next_btn)

	_house_char_name_label = Label.new()
	_house_char_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_house_char_name_label.add_theme_font_size_override("font_size", 17)
	_house_char_name_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	char_col.add_child(_house_char_name_label)

	var weapon_col := VBoxContainer.new()
	weapon_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_col.add_theme_constant_override("separation", 6)
	preview_row.add_child(weapon_col)

	var weapon_title := Label.new()
	weapon_title.text = tr("P1_HOUSE_PREVIEW_WEAPON")
	weapon_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_title.add_theme_font_size_override("font_size", 15)
	weapon_title.add_theme_color_override("font_color", Color(0.72, 0.88, 1.0))
	weapon_col.add_child(weapon_title)

	var weapon_nav := HBoxContainer.new()
	weapon_nav.alignment = BoxContainer.ALIGNMENT_CENTER
	weapon_nav.add_theme_constant_override("separation", 8)
	weapon_col.add_child(weapon_nav)

	var weapon_prev_btn := Button.new()
	weapon_prev_btn.custom_minimum_size = Vector2(44, 44)
	GameData.apply_icon_button(weapon_prev_btn, GameData.UI_ICON_ARROW_LEFT, tr("P1_HOUSE_WEAPON_PREV_FALLBACK"))
	weapon_prev_btn.pressed.connect(_on_house_weapon_prev)
	weapon_nav.add_child(weapon_prev_btn)

	var weapon_preview_panel := Panel.new()
	weapon_preview_panel.custom_minimum_size = Vector2(140, 140)
	weapon_nav.add_child(weapon_preview_panel)

	_house_weapon_preview = _make_house_preview_anim(weapon_preview_panel, 16.0)

	var weapon_next_btn := Button.new()
	weapon_next_btn.custom_minimum_size = Vector2(44, 44)
	GameData.apply_icon_button(weapon_next_btn, GameData.UI_ICON_ARROW_RIGHT, tr("P1_HOUSE_WEAPON_NEXT_FALLBACK"))
	weapon_next_btn.pressed.connect(_on_house_weapon_next)
	weapon_nav.add_child(weapon_next_btn)

	_house_weapon_name_label = Label.new()
	_house_weapon_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_house_weapon_name_label.add_theme_font_size_override("font_size", 17)
	_house_weapon_name_label.add_theme_color_override("font_color", Color(0.82, 0.94, 1.0))
	weapon_col.add_child(_house_weapon_name_label)

	var nav_hint := Label.new()
	nav_hint.text = tr("P1_HOUSE_MAIN_NAV_HINT")
	nav_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav_hint.add_theme_font_size_override("font_size", 12)
	nav_hint.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	vbox.add_child(nav_hint)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	vbox.add_child(action_row)

	var appearance_btn := Button.new()
	appearance_btn.text = tr("P1_HOUSE_APPEARANCE_BTN")
	appearance_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	appearance_btn.custom_minimum_size = Vector2(0, 42)
	appearance_btn.pressed.connect(_open_house_appearance_dialog)
	action_row.add_child(appearance_btn)

	var favorites_btn := Button.new()
	favorites_btn.text = tr("P1_HOUSE_FAVORITES_BTN")
	favorites_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	favorites_btn.custom_minimum_size = Vector2(0, 42)
	favorites_btn.pressed.connect(_open_house_favorites_dialog)
	action_row.add_child(favorites_btn)

	var summons_btn := Button.new()
	summons_btn.text = tr("P1_HOUSE_SUMMONS_BTN")
	summons_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summons_btn.custom_minimum_size = Vector2(0, 42)
	summons_btn.pressed.connect(_open_house_summons_dialog)
	action_row.add_child(summons_btn)

	if player_slot == "p1":
		var pinball_bg_btn := Button.new()
		pinball_bg_btn.text = tr("P1_HOUSE_PINBALL_BG_BTN")
		pinball_bg_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pinball_bg_btn.custom_minimum_size = Vector2(0, 42)
		pinball_bg_btn.pressed.connect(_open_house_pinball_bg_dialog)
		action_row.add_child(pinball_bg_btn)

	if player_slot == "p1":
		var sep := HSeparator.new()
		vbox.add_child(sep)

		var rest_lbl := Label.new()
		rest_lbl.text = tr("P1_HOUSE_REST_TITLE")
		rest_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rest_lbl.add_theme_font_size_override("font_size", 14)
		rest_lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
		vbox.add_child(rest_lbl)

		var rest_row := HBoxContainer.new()
		rest_row.alignment = BoxContainer.ALIGNMENT_CENTER
		rest_row.add_theme_constant_override("separation", 10)
		vbox.add_child(rest_row)

		for phase_data in [
			["day",     "P1_HOUSE_REST_DAY"],
			["evening", "P1_HOUSE_REST_EVENING"],
			["night",   "P1_HOUSE_REST_NIGHT"],
		]:
			var phase: String = phase_data[0]
			var key: String = phase_data[1]
			var btn := Button.new()
			btn.text = tr(key)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.disabled = (_village_time_phase == phase)
			btn.pressed.connect(_on_rest_until.bind(phase))
			rest_row.add_child(btn)

	var close_btn := Button.new()
	close_btn.text = tr("P1_HOUSE_CLOSE")
	close_btn.pressed.connect(_close_house_dialog)
	vbox.add_child(close_btn)

	_refresh_house_main_panel()
	_apply_house_skins_to_village_players()


func _open_house_appearance_dialog() -> void:
	if _house_dialog == null or _house_appearance_dialog != null \
			or _house_favorites_dialog != null or _house_summons_dialog != null \
			or _house_pinball_bg_dialog != null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_house_appearance_dialog = CanvasLayer.new()
	_house_appearance_dialog.layer = 241
	_house_appearance_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_house_appearance_dialog)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_house_appearance_dialog.add_child(root)

	_add_modal_dim_bg(root, HOUSE_SUB_DIALOG_DIM_ALPHA)

	var panel := PanelContainer.new()
	var panel_w: float = min(680.0, vp.x - 32.0)
	var panel_h: float = min(520.0, vp.y - 32.0)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	_style_house_modal_panel(panel)
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = tr("P1_HOUSE_APPEARANCE_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	vbox.add_child(title)

	var appearance_intro := Label.new()
	appearance_intro.text = tr("P1_HOUSE_APPEARANCE_INTRO")
	appearance_intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	appearance_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	appearance_intro.add_theme_font_size_override("font_size", 13)
	vbox.add_child(appearance_intro)

	var preview_row := HBoxContainer.new()
	preview_row.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_row.add_theme_constant_override("separation", 16)
	vbox.add_child(preview_row)

	var char_col := VBoxContainer.new()
	char_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_col.add_theme_constant_override("separation", 6)
	preview_row.add_child(char_col)
	var char_tri := _add_house_char_tri_preview(char_col)
	_house_appearance_char_idle_preview = char_tri["idle"] as HousePreviewAnimT
	_house_appearance_char_walk_preview = char_tri["walk"] as HousePreviewAnimT
	_house_appearance_char_attack_preview = char_tri["attack"] as HousePreviewAnimT
	_house_appearance_char_name_label = char_tri["name"] as Label

	var weapon_col := VBoxContainer.new()
	weapon_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_col.add_theme_constant_override("separation", 6)
	preview_row.add_child(weapon_col)
	var weapon_tri := _add_house_weapon_tri_preview(weapon_col)
	_house_appearance_weapon_hit_preview = weapon_tri["hit"] as HousePreviewAnimT
	_house_appearance_weapon_projectile_preview = weapon_tri["projectile"] as HousePreviewAnimT
	_house_appearance_weapon_extra_preview = weapon_tri["extra"] as HousePreviewAnimT
	_house_appearance_weapon_name_label = weapon_tri["name"] as Label

	var preview_sep := HSeparator.new()
	vbox.add_child(preview_sep)

	var char_section := Label.new()
	char_section.text = tr("P1_HOUSE_APPEARANCE_CHAR_SECTION")
	char_section.add_theme_font_size_override("font_size", 15)
	char_section.add_theme_color_override("font_color", Color(1.0, 0.88, 0.65))
	vbox.add_child(char_section)

	var skin_row := HBoxContainer.new()
	skin_row.add_theme_constant_override("separation", 10)
	vbox.add_child(skin_row)
	var skin_lbl := Label.new()
	skin_lbl.text = tr("P1_HOUSE_SKIN_LBL")
	skin_lbl.custom_minimum_size = Vector2(88, 0)
	skin_row.add_child(skin_lbl)
	_house_skin_option = OptionButton.new()
	_house_skin_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_house_skin_option.item_selected.connect(_on_p1_house_skin_selected)
	skin_row.add_child(_house_skin_option)

	_house_weapon_visual_section = VBoxContainer.new()
	_house_weapon_visual_section.add_theme_constant_override("separation", 8)
	vbox.add_child(_house_weapon_visual_section)

	var weapon_section := Label.new()
	weapon_section.text = tr("P1_HOUSE_APPEARANCE_WEAPON_SECTION")
	weapon_section.add_theme_font_size_override("font_size", 15)
	weapon_section.add_theme_color_override("font_color", Color(0.72, 0.88, 1.0))
	_house_weapon_visual_section.add_child(weapon_section)

	var bow_skin_row := HBoxContainer.new()
	bow_skin_row.add_theme_constant_override("separation", 10)
	_house_weapon_visual_section.add_child(bow_skin_row)
	_house_weapon_skin_lbl = Label.new()
	_house_weapon_skin_lbl.custom_minimum_size = Vector2(88, 0)
	bow_skin_row.add_child(_house_weapon_skin_lbl)
	_house_bow_skin_option = OptionButton.new()
	_house_bow_skin_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_house_bow_skin_option.item_selected.connect(_on_house_weapon_skin_selected)
	bow_skin_row.add_child(_house_bow_skin_option)

	_house_status_label = RichTextLabel.new()
	_house_status_label.bbcode_enabled = true
	_house_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_house_status_label.fit_content = true
	_house_status_label.scroll_active = false
	_house_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_house_status_label.add_theme_color_override("default_color", Color(0.7, 0.9, 1.0))
	vbox.add_child(_house_status_label)

	var back_btn := Button.new()
	back_btn.text = tr("P1_HOUSE_APPEARANCE_BACK")
	back_btn.pressed.connect(_close_house_appearance_dialog)
	vbox.add_child(back_btn)

	_refresh_house_appearance_panel("")


func _open_house_favorites_dialog() -> void:
	if _house_dialog == null or _house_favorites_dialog != null \
			or _house_appearance_dialog != null or _house_summons_dialog != null \
			or _house_pinball_bg_dialog != null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_house_favorites_dialog = CanvasLayer.new()
	_house_favorites_dialog.layer = 241
	_house_favorites_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_house_favorites_dialog)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_house_favorites_dialog.add_child(root)

	_add_modal_dim_bg(root, HOUSE_SUB_DIALOG_DIM_ALPHA)

	var panel := PanelContainer.new()
	var panel_w: float = min(720.0, vp.x - 32.0)
	var panel_h: float = min(520.0, vp.y - 32.0)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	_style_house_modal_panel(panel)
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = tr("P1_HOUSE_FAVORITES_DIALOG_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	vbox.add_child(title)

	_house_fav_title = Label.new()
	_house_fav_title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_house_fav_title)

	var fav_hint := Label.new()
	fav_hint.text = tr("HOUSE_FAVORITES_SHARED_HINT")
	fav_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fav_hint.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	fav_hint.add_theme_font_size_override("font_size", 12)
	vbox.add_child(fav_hint)

	_house_favorite_option_buttons.clear()
	_house_fav_grid = GridContainer.new()
	_house_fav_grid.columns = 2
	_house_fav_grid.add_theme_constant_override("h_separation", 10)
	_house_fav_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(_house_fav_grid)
	var n_fav: int = GameState.get_house_favorite_unlocked_slot_count()
	for i in n_fav:
		_house_fav_grid.add_child(_make_p1_house_favorite_row(i))

	_house_status_label = RichTextLabel.new()
	_house_status_label.bbcode_enabled = true
	_house_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_house_status_label.fit_content = true
	_house_status_label.scroll_active = false
	_house_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_house_status_label.add_theme_color_override("default_color", Color(0.7, 0.9, 1.0))
	vbox.add_child(_house_status_label)

	var back_btn := Button.new()
	back_btn.text = tr("P1_HOUSE_FAVORITES_BACK")
	back_btn.pressed.connect(_close_house_favorites_dialog)
	vbox.add_child(back_btn)

	_refresh_house_favorites_panel("")


func _close_house_appearance_dialog() -> void:
	if _house_appearance_dialog != null and is_instance_valid(_house_appearance_dialog):
		_house_appearance_dialog.queue_free()
	_house_appearance_dialog = null
	_house_status_label = null
	_house_skin_option = null
	_house_weapon_skin_lbl = null
	_house_bow_skin_option = null
	_house_weapon_visual_section = null
	_house_appearance_char_idle_preview = null
	_house_appearance_char_walk_preview = null
	_house_appearance_char_attack_preview = null
	_house_appearance_weapon_hit_preview = null
	_house_appearance_weapon_projectile_preview = null
	_house_appearance_weapon_extra_preview = null
	_house_appearance_char_name_label = null
	_house_appearance_weapon_name_label = null
	_house_suppress_ui = false
	if _house_dialog != null:
		_refresh_house_main_panel()


func _close_house_favorites_dialog() -> void:
	if _house_favorites_dialog != null and is_instance_valid(_house_favorites_dialog):
		_house_favorites_dialog.queue_free()
	_house_favorites_dialog = null
	_house_status_label = null
	_house_fav_title = null
	_house_fav_grid = null
	_house_favorite_option_buttons.clear()
	_house_suppress_ui = false


func _open_house_summons_dialog() -> void:
	if _house_dialog == null or _house_summons_dialog != null \
			or _house_appearance_dialog != null or _house_favorites_dialog != null \
			or _house_pinball_bg_dialog != null:
		return
	_house_summon_focus_slot = 0
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_house_summons_dialog = CanvasLayer.new()
	_house_summons_dialog.layer = 241
	_house_summons_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_house_summons_dialog)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_house_summons_dialog.add_child(root)

	_add_modal_dim_bg(root, HOUSE_SUB_DIALOG_DIM_ALPHA)

	var panel := PanelContainer.new()
	var panel_w: float = min(720.0, vp.x - 32.0)
	var panel_h: float = min(620.0, vp.y - 32.0)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	_style_house_modal_panel(panel)
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = tr("P1_HOUSE_SUMMONS_DIALOG_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	vbox.add_child(title)

	var intro := Label.new()
	intro.text = tr("P1_HOUSE_SUMMONS_INTRO")
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 13)
	vbox.add_child(intro)

	var hint := Label.new()
	hint.text = tr("P1_HOUSE_SUMMONS_HINT")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	hint.add_theme_font_size_override("font_size", 12)
	vbox.add_child(hint)

	_house_summon_slot_ui.clear()
	var slots_row := HBoxContainer.new()
	slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_row.add_theme_constant_override("separation", 12)
	vbox.add_child(slots_row)
	for i in GameData.P1_HOUSE_SUMMON_SLOTS:
		_house_summon_slot_ui.append(_make_house_summon_slot_column(slots_row, i))

	_house_summon_desc_label = RichTextLabel.new()
	_house_summon_desc_label.bbcode_enabled = true
	_house_summon_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_house_summon_desc_label.custom_minimum_size = Vector2(0, 96)
	_house_summon_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_house_summon_desc_label.scroll_active = true
	_house_summon_desc_label.add_theme_color_override("default_color", Color(0.82, 0.92, 0.88))
	vbox.add_child(_house_summon_desc_label)

	_house_summon_feed_btn = Button.new()
	_house_summon_feed_btn.pressed.connect(_on_house_use_pet_feed)
	vbox.add_child(_house_summon_feed_btn)

	_house_status_label = RichTextLabel.new()
	_house_status_label.bbcode_enabled = true
	_house_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_house_status_label.fit_content = true
	_house_status_label.scroll_active = false
	_house_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_house_status_label.add_theme_color_override("default_color", Color(0.7, 0.9, 1.0))
	vbox.add_child(_house_status_label)

	var back_btn := Button.new()
	back_btn.text = tr("P1_HOUSE_SUMMONS_BACK")
	back_btn.pressed.connect(_close_house_summons_dialog)
	vbox.add_child(back_btn)

	_refresh_house_summons_panel("")


func _make_house_summon_slot_column(parent_row: HBoxContainer, slot_index: int) -> Dictionary:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	parent_row.add_child(col)

	var slot_lbl := Label.new()
	slot_lbl.text = tr("P1_HOUSE_SUMMON_SLOT_FMT") % (slot_index + 1)
	slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_lbl.add_theme_font_size_override("font_size", 14)
	slot_lbl.add_theme_color_override("font_color", Color(0.78, 0.92, 0.72))
	col.add_child(slot_lbl)

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 6)
	col.add_child(nav)

	var prev_btn := Button.new()
	prev_btn.custom_minimum_size = Vector2(40, 40)
	GameData.apply_icon_button(prev_btn, GameData.UI_ICON_ARROW_LEFT, tr("P1_HOUSE_CHAR_PREV_FALLBACK"))
	prev_btn.pressed.connect(func() -> void:
		_on_house_summon_prev(slot_index))
	nav.add_child(prev_btn)

	var preview_panel := Panel.new()
	preview_panel.custom_minimum_size = Vector2(112, 112)
	nav.add_child(preview_panel)
	var preview_anim := _make_house_preview_anim(preview_panel, 8.0)

	var next_btn := Button.new()
	next_btn.custom_minimum_size = Vector2(40, 40)
	GameData.apply_icon_button(next_btn, GameData.UI_ICON_ARROW_RIGHT, tr("P1_HOUSE_CHAR_NEXT_FALLBACK"))
	next_btn.pressed.connect(func() -> void:
		_on_house_summon_next(slot_index))
	nav.add_child(next_btn)

	var name_lbl := Label.new()
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.82, 0.96, 0.82))
	col.add_child(name_lbl)

	var level_lbl := Label.new()
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.add_theme_font_size_override("font_size", 11)
	level_lbl.add_theme_color_override("font_color", Color(0.72, 0.88, 0.78))
	col.add_child(level_lbl)

	var exp_lbl := Label.new()
	exp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exp_lbl.add_theme_font_size_override("font_size", 11)
	exp_lbl.add_theme_color_override("font_color", Color(0.68, 0.82, 0.9))
	col.add_child(exp_lbl)

	var stats_lbl := Label.new()
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_lbl.add_theme_font_size_override("font_size", 10)
	stats_lbl.add_theme_color_override("font_color", Color(0.78, 0.86, 0.74))
	col.add_child(stats_lbl)

	return {
		"preview": preview_anim,
		"name": name_lbl,
		"level": level_lbl,
		"exp": exp_lbl,
		"stats": stats_lbl,
		"slot_index": slot_index,
	}


func _close_house_summons_dialog() -> void:
	if _house_summons_dialog != null and is_instance_valid(_house_summons_dialog):
		_house_summons_dialog.queue_free()
	_house_summons_dialog = null
	_house_status_label = null
	_house_summon_desc_label = null
	_house_summon_slot_ui.clear()
	_house_suppress_ui = false


func _open_house_pinball_bg_dialog() -> void:
	if _house_dialog == null or _house_pinball_bg_dialog != null \
			or _house_appearance_dialog != null or _house_favorites_dialog != null \
			or _house_summons_dialog != null:
		return
	if _house_player_slot != "p1":
		return
	_house_ui_bg_context_idx = 0
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_house_pinball_bg_dialog = CanvasLayer.new()
	_house_pinball_bg_dialog.layer = 241
	_house_pinball_bg_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_house_pinball_bg_dialog)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_house_pinball_bg_dialog.add_child(root)

	_add_modal_dim_bg(root, HOUSE_SUB_DIALOG_DIM_ALPHA)

	var panel := PanelContainer.new()
	var panel_w: float = min(560.0, vp.x - 32.0)
	var panel_h: float = min(520.0, vp.y - 32.0)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	_style_house_modal_panel(panel)
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = tr("P1_HOUSE_PINBALL_BG_DIALOG_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	vbox.add_child(title)

	var intro := Label.new()
	intro.text = tr("P1_HOUSE_PINBALL_BG_INTRO")
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 13)
	vbox.add_child(intro)

	var hint := Label.new()
	hint.text = tr("P1_HOUSE_PINBALL_BG_HINT")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	hint.add_theme_font_size_override("font_size", 12)
	vbox.add_child(hint)

	var cat_nav := HBoxContainer.new()
	cat_nav.alignment = BoxContainer.ALIGNMENT_CENTER
	cat_nav.add_theme_constant_override("separation", 10)
	vbox.add_child(cat_nav)

	var cat_prev := Button.new()
	cat_prev.custom_minimum_size = Vector2(36, 36)
	GameData.apply_icon_button(cat_prev, GameData.UI_ICON_ARROW_LEFT, "<")
	cat_prev.pressed.connect(_on_house_ui_bg_category_prev)
	cat_nav.add_child(cat_prev)

	_house_pinball_bg_category_label = Label.new()
	_house_pinball_bg_category_label.custom_minimum_size = Vector2(240, 0)
	_house_pinball_bg_category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_house_pinball_bg_category_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_house_pinball_bg_category_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_house_pinball_bg_category_label.add_theme_font_size_override("font_size", 15)
	_house_pinball_bg_category_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.62))
	cat_nav.add_child(_house_pinball_bg_category_label)

	var cat_next := Button.new()
	cat_next.custom_minimum_size = Vector2(36, 36)
	GameData.apply_icon_button(cat_next, GameData.UI_ICON_ARROW_RIGHT, ">")
	cat_next.pressed.connect(_on_house_ui_bg_category_next)
	cat_nav.add_child(cat_next)

	var preview_frame := Panel.new()
	preview_frame.custom_minimum_size = Vector2(0, 220)
	var preview_sb := StyleBoxFlat.new()
	preview_sb.bg_color = Color(0.04, 0.05, 0.12, 1.0)
	preview_sb.border_color = Color(0.95, 0.65, 0.18, 0.95)
	preview_sb.border_width_left = 3
	preview_sb.border_width_right = 3
	preview_sb.border_width_top = 3
	preview_sb.border_width_bottom = 3
	preview_sb.corner_radius_top_left = 8
	preview_sb.corner_radius_top_right = 8
	preview_sb.corner_radius_bottom_left = 8
	preview_sb.corner_radius_bottom_right = 8
	preview_frame.add_theme_stylebox_override("panel", preview_sb)
	vbox.add_child(preview_frame)

	var preview_margin := MarginContainer.new()
	preview_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_margin.add_theme_constant_override("margin_left", 14)
	preview_margin.add_theme_constant_override("margin_right", 14)
	preview_margin.add_theme_constant_override("margin_top", 14)
	preview_margin.add_theme_constant_override("margin_bottom", 14)
	preview_frame.add_child(preview_margin)

	var preview_center := CenterContainer.new()
	preview_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_margin.add_child(preview_center)

	_house_pinball_bg_preview = PinballPatternPreviewT.new()
	_house_pinball_bg_preview.custom_minimum_size = Vector2(180, 180)
	_house_pinball_bg_preview.size = Vector2(180, 180)
	preview_center.add_child(_house_pinball_bg_preview)

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 12)
	vbox.add_child(nav)

	var prev_btn := Button.new()
	prev_btn.custom_minimum_size = Vector2(44, 44)
	GameData.apply_icon_button(prev_btn, GameData.UI_ICON_ARROW_LEFT, tr("P1_HOUSE_CHAR_PREV_FALLBACK"))
	prev_btn.pressed.connect(_on_house_pinball_bg_prev)
	nav.add_child(prev_btn)

	_house_pinball_bg_name_label = Label.new()
	_house_pinball_bg_name_label.custom_minimum_size = Vector2(220, 0)
	_house_pinball_bg_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_house_pinball_bg_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_house_pinball_bg_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_house_pinball_bg_name_label.add_theme_font_size_override("font_size", 16)
	_house_pinball_bg_name_label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	nav.add_child(_house_pinball_bg_name_label)

	var next_btn := Button.new()
	next_btn.custom_minimum_size = Vector2(44, 44)
	GameData.apply_icon_button(next_btn, GameData.UI_ICON_ARROW_RIGHT, tr("P1_HOUSE_CHAR_NEXT_FALLBACK"))
	next_btn.pressed.connect(_on_house_pinball_bg_next)
	nav.add_child(next_btn)

	_house_pinball_bg_status_label = Label.new()
	_house_pinball_bg_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_house_pinball_bg_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_house_pinball_bg_status_label.add_theme_font_size_override("font_size", 13)
	_house_pinball_bg_status_label.add_theme_color_override("font_color", Color(0.78, 0.92, 0.72))
	vbox.add_child(_house_pinball_bg_status_label)

	var back_btn := Button.new()
	back_btn.text = tr("P1_HOUSE_PINBALL_BG_BACK")
	back_btn.pressed.connect(_close_house_pinball_bg_dialog)
	vbox.add_child(back_btn)

	_refresh_house_pinball_bg_panel("")


func _house_ui_bg_context() -> String:
	var order: Array[String] = GameData.UI_BG_CONTEXT_ORDER
	if order.is_empty():
		return GameData.UI_BG_CTX_PANEL
	return order[_house_ui_bg_context_idx % order.size()]


func _refresh_house_pinball_bg_panel(status: String) -> void:
	var context: String = _house_ui_bg_context()
	var pattern_id: String = GameState.get_ui_bg_pattern(context)
	if _house_pinball_bg_category_label != null:
		_house_pinball_bg_category_label.text = tr("P1_HOUSE_UI_BG_CATEGORY_FMT") % \
			GameData.tr_ui_bg_context_name(context)
	if _house_pinball_bg_preview != null:
		_house_pinball_bg_preview.setup(pattern_id, 3)
	if _house_pinball_bg_name_label != null:
		_house_pinball_bg_name_label.text = GameData.tr_pinball_bg_pattern_name(pattern_id)
	if _house_pinball_bg_status_label != null:
		if status != "":
			_house_pinball_bg_status_label.text = status
		else:
			_house_pinball_bg_status_label.text = tr("P1_HOUSE_UI_BG_CURRENT_FMT") % [
				GameData.tr_ui_bg_context_name(context),
				GameData.tr_pinball_bg_pattern_name(pattern_id),
			]


func _cycle_house_ui_bg_category(direction: int) -> void:
	var n: int = GameData.UI_BG_CONTEXT_ORDER.size()
	if n <= 0:
		return
	_house_ui_bg_context_idx = (_house_ui_bg_context_idx + direction + n) % n
	_refresh_house_pinball_bg_panel("")


func _cycle_house_pinball_bg(direction: int) -> void:
	var ids: Array[String] = GameData.pinball_bg_pattern_ids()
	if ids.is_empty():
		return
	var context: String = _house_ui_bg_context()
	var current: String = GameState.get_ui_bg_pattern(context)
	var idx: int = ids.find(current)
	if idx < 0:
		idx = 0
	var next_idx: int = (idx + direction + ids.size()) % ids.size()
	if not GameState.set_ui_bg_pattern(context, "p1", ids[next_idx]):
		return
	_refresh_house_pinball_bg_panel(tr("P1_HOUSE_PINBALL_BG_SAVED"))
	SettingsOverlay._notify_current_scene_account_changed()


func _on_house_ui_bg_category_prev() -> void:
	_cycle_house_ui_bg_category(-1)


func _on_house_ui_bg_category_next() -> void:
	_cycle_house_ui_bg_category(1)


func _on_house_pinball_bg_prev() -> void:
	_cycle_house_pinball_bg(-1)


func _on_house_pinball_bg_next() -> void:
	_cycle_house_pinball_bg(1)


func _close_house_pinball_bg_dialog() -> void:
	if _house_pinball_bg_dialog != null and is_instance_valid(_house_pinball_bg_dialog):
		_house_pinball_bg_dialog.queue_free()
	_house_pinball_bg_dialog = null
	_house_pinball_bg_preview = null
	_house_pinball_bg_name_label = null
	_house_pinball_bg_status_label = null
	_house_pinball_bg_category_label = null
	_house_ui_bg_context_idx = 0


func _refresh_house_summons_panel(status: String) -> void:
	var char_id: String = _house_dialog_current_char_id()
	for slot_ui in _house_summon_slot_ui:
		var slot_index: int = int(slot_ui.get("slot_index", 0))
		_refresh_house_summon_slot_ui(slot_ui, char_id, slot_index)
	_update_house_summon_desc_label(char_id)
	if _house_summon_feed_btn != null:
		_house_summon_feed_btn.text = tr("P1_HOUSE_SUMMON_USE_FEED_FMT") % GameState.pet_feed
		var slot_index: int = clampi(_house_summon_focus_slot, 0, GameData.P1_HOUSE_SUMMON_SLOTS - 1)
		var slots: Array[String] = GameState.get_house_summons(_house_player_slot, char_id)
		var summon_id: String = "none"
		if slot_index >= 0 and slot_index < slots.size():
			summon_id = slots[slot_index]
		var can_feed: bool = GameState.pet_feed > 0 \
			and summon_id != "" and summon_id != "none" \
			and GameState.is_summon_unlocked(summon_id)
		if can_feed:
			var prog: Dictionary = GameState.get_summon_progress(_house_player_slot, summon_id)
			can_feed = int(prog.get("level", GameData.SUMMON_MIN_LEVEL)) >= 1
		_house_summon_feed_btn.disabled = not can_feed
	if _house_status_label != null:
		_house_status_label.text = status


func _refresh_house_summon_slot_ui(slot_ui: Dictionary, char_id: String, slot_index: int) -> void:
	var preview: HousePreviewAnimT = slot_ui.get("preview") as HousePreviewAnimT
	var name_lbl: Label = slot_ui.get("name") as Label
	var level_lbl: Label = slot_ui.get("level") as Label
	var exp_lbl: Label = slot_ui.get("exp") as Label
	var stats_lbl: Label = slot_ui.get("stats") as Label
	var slots: Array[String] = GameState.get_house_summons(_house_player_slot, char_id)
	var summon_id: String = "none"
	if slot_index >= 0 and slot_index < slots.size():
		summon_id = slots[slot_index]
	if preview != null:
		preview.setup_summon(summon_id, _house_player_slot)
	var level: int = GameData.SUMMON_MIN_LEVEL
	var exp: int = 0
	if summon_id != "" and summon_id != "none":
		var prog: Dictionary = GameState.get_summon_progress(_house_player_slot, summon_id)
		level = int(prog.get("level", GameData.SUMMON_MIN_LEVEL))
		exp = int(prog.get("exp", 0))
	if name_lbl != null:
		if summon_id == "" or summon_id == "none":
			name_lbl.text = tr("CSEL_NONE")
		else:
			var sdef: Dictionary = GameData.get_summon_def(summon_id)
			name_lbl.text = "%s\n(%s)" % [
				GameData.tr_summon_display_name(summon_id, level),
				GameData.tr_summon_type(sdef)]
	if summon_id == "" or summon_id == "none":
		if level_lbl != null:
			level_lbl.text = tr("SUMMON_SLOT_EMPTY_STAT")
		if exp_lbl != null:
			exp_lbl.text = ""
		if stats_lbl != null:
			stats_lbl.text = ""
		return
	if level_lbl != null:
		level_lbl.text = GameData.format_summon_level_text(level)
	if exp_lbl != null:
		exp_lbl.text = GameData.format_summon_exp_text(level, exp)
	if stats_lbl != null:
		stats_lbl.text = GameData.format_summon_stats_text(summon_id, level) \
			+ "\n" + GameData.format_summon_evolve_text(level)


func _update_house_summon_desc_label(char_id: String) -> void:
	if _house_summon_desc_label == null:
		return
	var slot_index: int = clampi(_house_summon_focus_slot, 0, GameData.P1_HOUSE_SUMMON_SLOTS - 1)
	var slots: Array[String] = GameState.get_house_summons(_house_player_slot, char_id)
	var summon_id: String = "none"
	if slot_index >= 0 and slot_index < slots.size():
		summon_id = slots[slot_index]
	var slot_title: String = tr("P1_HOUSE_SUMMON_SLOT_FMT") % (slot_index + 1)
	if summon_id == "" or summon_id == "none":
		_house_summon_desc_label.text = "[b]%s[/b]\n%s" % [
			slot_title, tr("SUMMON_NONE_DETAIL")]
		return
	var prog: Dictionary = GameState.get_summon_progress(_house_player_slot, summon_id)
	var level: int = int(prog.get("level", GameData.SUMMON_MIN_LEVEL))
	var exp: int = int(prog.get("exp", 0))
	var lines: Array[String] = [
		"[b]%s[/b]" % slot_title,
		GameData.format_summon_house_detail_text(summon_id, level, exp),
	]
	if not GameState.is_summon_unlocked(summon_id):
		var shards: int = GameState.get_summon_shard_count(summon_id)
		if shards > 0:
			lines.append(tr("P1_HOUSE_SUMMON_SHARD_FMT") % [
				GameData.tr_summon_egg_name(summon_id), shards, GameData.SUMMON_SHARDS_PER_EGG])
	if GameState.pet_feed > 0:
		lines.append(tr("P1_HOUSE_SUMMON_FEED_STOCK_FMT") % GameState.pet_feed)
	_house_summon_desc_label.text = "\n".join(lines)


func _on_house_use_pet_feed() -> void:
	var char_id: String = _house_dialog_current_char_id()
	var slot_index: int = clampi(_house_summon_focus_slot, 0, GameData.P1_HOUSE_SUMMON_SLOTS - 1)
	var slots: Array[String] = GameState.get_house_summons(_house_player_slot, char_id)
	var summon_id: String = "none"
	if slot_index >= 0 and slot_index < slots.size():
		summon_id = slots[slot_index]
	if GameState.use_pet_feed_on_summon(_house_player_slot, summon_id):
		_refresh_house_summons_panel(tr("P1_HOUSE_SUMMON_FEED_USED"))
	else:
		_refresh_house_summons_panel(tr("P1_HOUSE_SUMMON_FEED_FAIL"))


func _on_house_summon_prev(slot_index: int) -> void:
	_cycle_house_summon_slot(slot_index, -1)


func _on_house_summon_next(slot_index: int) -> void:
	_cycle_house_summon_slot(slot_index, 1)


func _cycle_house_summon_slot(slot_index: int, direction: int) -> void:
	if slot_index < 0 or slot_index >= GameData.P1_HOUSE_SUMMON_SLOTS:
		return
	var char_id: String = _house_dialog_current_char_id()
	var choices: Array[String] = GameState.house_summon_choices(
		_house_player_slot, char_id, slot_index)
	if choices.size() <= 1:
		return
	var slots: Array[String] = GameState.get_house_summons(_house_player_slot, char_id)
	var current: String = slots[slot_index] if slot_index < slots.size() else "none"
	var cur_idx: int = choices.find(current)
	if cur_idx < 0:
		cur_idx = 0
	var next_idx: int = (cur_idx + direction + choices.size()) % choices.size()
	var next_id: String = choices[next_idx]
	if not GameState.set_house_summon_slot(_house_player_slot, char_id, slot_index, next_id):
		_refresh_house_summons_panel(tr("P1_HOUSE_SUMMON_DUPLICATE"))
		return
	_house_summon_focus_slot = slot_index
	_refresh_house_summons_panel(tr("P1_HOUSE_SUMMON_SAVED"))
	_refresh_village_summon_followers()


func _house_weapon_preview_label(weapon_id: String, wdef: Dictionary) -> String:
	var skin_id: String = GameState.get_weapon_visual_skin(_house_player_slot, weapon_id)
	if skin_id != "default":
		return GameData.get_weapon_visual_skin_label(weapon_id, skin_id)
	if weapon_id == "bow":
		return GameData.get_weapon_visual_skin_label(weapon_id, "default")
	if not wdef.is_empty():
		return GameData.tr_weapon_name(weapon_id)
	return weapon_id


func _house_dialog_weapon_ids() -> Array[String]:
	return GameData.house_weapon_visual_skin_weapon_ids()


func _house_dialog_start_weapon_index() -> int:
	var ids: Array[String] = _house_dialog_weapon_ids()
	if ids.is_empty():
		return 0
	return 0


func _house_dialog_current_weapon_id() -> String:
	var ids: Array[String] = _house_dialog_weapon_ids()
	if ids.is_empty():
		return "bow"
	return ids[clampi(_house_weapon_index, 0, ids.size() - 1)]


func _on_house_weapon_prev() -> void:
	var ids: Array[String] = _house_dialog_weapon_ids()
	if ids.size() <= 1:
		return
	_house_weapon_index = (_house_weapon_index - 1 + ids.size()) % ids.size()
	_refresh_house_main_panel()


func _on_house_weapon_next() -> void:
	var ids: Array[String] = _house_dialog_weapon_ids()
	if ids.size() <= 1:
		return
	_house_weapon_index = (_house_weapon_index + 1) % ids.size()
	_refresh_house_main_panel()


func _refresh_house_main_panel() -> void:
	var char_id: String = _house_dialog_current_char_id()
	var cdef: Dictionary = GameData.get_character_def(char_id)
	if _house_char_name_label != null:
		_house_char_name_label.text = GameData.tr_name(cdef) if not cdef.is_empty() else char_id
	_house_update_character_preview(char_id)
	var weapon_id: String = _house_dialog_current_weapon_id()
	var wdef: Dictionary = GameData.get_weapon_def(weapon_id)
	if _house_weapon_name_label != null:
		_house_weapon_name_label.text = _house_weapon_preview_label(weapon_id, wdef)
	if _house_weapon_preview != null:
		_house_weapon_preview.setup_weapon(weapon_id, _house_player_slot)


func _refresh_house_appearance_previews() -> void:
	var char_id: String = _house_dialog_current_char_id()
	var cdef: Dictionary = GameData.get_character_def(char_id)
	if _house_appearance_char_name_label != null:
		_house_appearance_char_name_label.text = GameData.tr_name(cdef) if not cdef.is_empty() else char_id
	var skin_id: String = GameState.get_house_character_skin(_house_player_slot, char_id)
	var visual: Dictionary = GameData.resolve_character_visual_def(char_id, skin_id)
	if visual.is_empty():
		visual = cdef
	if _house_appearance_char_idle_preview != null:
		_house_appearance_char_idle_preview.setup_character_anim(visual, "idle")
	if _house_appearance_char_walk_preview != null:
		_house_appearance_char_walk_preview.setup_character_anim(visual, "walk")
	if _house_appearance_char_attack_preview != null:
		_house_appearance_char_attack_preview.setup_character_anim(visual, "attack")
	var weapon_id: String = _house_dialog_current_weapon_id()
	var wdef: Dictionary = GameData.get_weapon_def(weapon_id)
	if _house_appearance_weapon_name_label != null:
		_house_appearance_weapon_name_label.text = _house_weapon_preview_label(weapon_id, wdef)
	var weapon_skin_id: String = GameState.get_weapon_visual_skin(_house_player_slot, weapon_id)
	var slots: Dictionary = GameData.resolve_weapon_house_preview_slots(weapon_id, weapon_skin_id)
	if _house_appearance_weapon_hit_preview != null:
		_house_appearance_weapon_hit_preview.setup_preview(slots.get("hit", {}))
	if _house_appearance_weapon_projectile_preview != null:
		_house_appearance_weapon_projectile_preview.setup_preview(slots.get("projectile", {}))
	if _house_appearance_weapon_extra_preview != null:
		_house_appearance_weapon_extra_preview.setup_preview(slots.get("extra", {}))


func _refresh_house_appearance_panel(status: String) -> void:
	var char_id: String = _house_dialog_current_char_id()
	_house_suppress_ui = true
	if _house_skin_option != null:
		_house_skin_option.set_block_signals(true)
		_populate_house_skin_option(char_id)
		_house_skin_option.set_block_signals(false)
	_refresh_house_weapon_visual_section()
	_refresh_house_appearance_previews()
	_house_suppress_ui = false
	_update_house_status_label(status, char_id, false)


func _refresh_house_favorites_panel(status: String) -> void:
	_refresh_house_favorite_title()
	var char_id: String = _house_dialog_current_char_id()
	_house_suppress_ui = true
	var cap: int = GameState.get_house_favorite_unlocked_slot_count()
	for i in _house_favorite_option_buttons.size():
		if i < cap:
			var opt: OptionButton = _house_favorite_option_buttons[i]
			opt.set_block_signals(true)
			_populate_house_favorite_option(opt, char_id, i)
			opt.set_block_signals(false)
	_house_suppress_ui = false
	_update_house_status_label(status, char_id, true)


func _refresh_house_weapon_visual_section() -> void:
	if _house_weapon_visual_section == null:
		return
	var weapon_id: String = _house_dialog_current_weapon_id()
	var show: bool = GameData.weapon_supports_house_visual_preview(weapon_id)
	_house_weapon_visual_section.visible = show
	if not show:
		return
	if _house_weapon_skin_lbl != null:
		_house_weapon_skin_lbl.text = tr("P1_HOUSE_WEAPON_SKIN_LBL") % GameData.tr_weapon_name(weapon_id)
	_refresh_house_weapon_skin_options()


func _refresh_house_favorite_title() -> void:
	if _house_fav_title == null:
		return
	var u: int = GameState.get_house_favorite_unlocked_slot_count()
	var m: int = GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS
	_house_fav_title.text = tr("HOUSE_FAVORITES_TITLE_FMT") % [u, m]


func _house_dialog_char_ids() -> Array[String]:
	var out: Array[String] = []
	for raw in GameState.unlocked_characters:
		var cid: String = String(raw)
		if cid != "" and GameData.get_character_def(cid).size() > 0:
			out.append(cid)
	return out


func _house_dialog_start_char_index() -> int:
	var ids: Array[String] = _house_dialog_char_ids()
	if ids.is_empty():
		return 0
	var prefer: String = String(GameState.p2_character if _house_player_slot == "p2" else GameState.p1_character)
	for i in ids.size():
		if ids[i] == prefer:
			return i
	return 0


func _house_dialog_current_char_id() -> String:
	var ids: Array[String] = _house_dialog_char_ids()
	if ids.is_empty():
		return "swordsman"
	return ids[clampi(_house_char_index, 0, ids.size() - 1)]


func _on_p1_house_char_prev() -> void:
	var ids: Array[String] = _house_dialog_char_ids()
	if ids.size() <= 1:
		return
	_house_char_index = (_house_char_index - 1 + ids.size()) % ids.size()
	_refresh_house_main_panel()
	if _house_appearance_dialog != null:
		_refresh_house_appearance_panel("")
	if _house_favorites_dialog != null:
		_refresh_house_favorites_panel("")
	if _house_summons_dialog != null:
		_refresh_house_summons_panel("")
	_apply_house_char_to_village_player()


func _on_p1_house_char_next() -> void:
	var ids: Array[String] = _house_dialog_char_ids()
	if ids.size() <= 1:
		return
	_house_char_index = (_house_char_index + 1) % ids.size()
	_refresh_house_main_panel()
	if _house_appearance_dialog != null:
		_refresh_house_appearance_panel("")
	if _house_favorites_dialog != null:
		_refresh_house_favorites_panel("")
	if _house_summons_dialog != null:
		_refresh_house_summons_panel("")
	_apply_house_char_to_village_player()


func _apply_house_char_to_village_player() -> void:
	var char_id: String = _house_dialog_current_char_id()
	if char_id == "":
		return
	if _house_player_slot == "p1":
		GameState.set_p1_village_character(char_id)
		for p in players:
			if p != null and is_instance_valid(p) and String(p.input_prefix) == "p1":
				p.setup_from_character(char_id)
				break
	elif _house_player_slot == "p2":
		GameState.p2_character = char_id
		for p in players:
			if p != null and is_instance_valid(p) and String(p.input_prefix) == "p2":
				p.setup_from_character(char_id)
				break
	_refresh_village_summon_followers()


func _populate_house_skin_option(char_id: String) -> void:
	if _house_skin_option == null:
		return
	_house_skin_option.clear()
	var skin_opts: Array = GameData.character_house_skin_options(char_id, GameState.unlocked_characters)
	var current_skin: String = GameState.get_house_character_skin(_house_player_slot, char_id)
	var pick_idx: int = 0
	for i in skin_opts.size():
		var sid: String = String(skin_opts[i].get("id", ""))
		_house_skin_option.add_item(String(skin_opts[i].get("label", sid)), i)
		if sid == current_skin:
			pick_idx = i
	_house_skin_option.select(pick_idx)


func _on_p1_house_skin_selected(index: int) -> void:
	if _house_suppress_ui:
		return
	var char_id: String = _house_dialog_current_char_id()
	var skin_opts: Array = GameData.character_house_skin_options(char_id, GameState.unlocked_characters)
	if index < 0 or index >= skin_opts.size():
		return
	var sid: String = String(skin_opts[index].get("id", "default"))
	GameState.set_house_character_skin(_house_player_slot, char_id, sid)
	_house_update_character_preview(char_id)
	_refresh_house_appearance_previews()
	_update_house_status_label(tr("P1_HOUSE_SKIN_SAVED_FMT") % GameData.tr_character_name(char_id), char_id, false)
	_apply_house_skins_to_village_players()
	_refresh_house_main_panel()


func _refresh_house_weapon_skin_options() -> void:
	if _house_bow_skin_option == null:
		return
	var weapon_id: String = _house_dialog_current_weapon_id()
	_house_bow_skin_option.set_block_signals(true)
	_house_bow_skin_option.clear()
	var skin_opts: Array = GameData.weapon_visual_skin_options(weapon_id)
	var current_skin: String = GameState.get_weapon_visual_skin(_house_player_slot, weapon_id)
	var pick_skin: int = 0
	for i in skin_opts.size():
		var sid: String = String(skin_opts[i].get("id", ""))
		_house_bow_skin_option.add_item(String(skin_opts[i].get("label", sid)), i)
		if sid == current_skin:
			pick_skin = i
	_house_bow_skin_option.select(pick_skin)
	_house_bow_skin_option.set_block_signals(false)


func _on_house_weapon_skin_selected(index: int) -> void:
	if _house_suppress_ui:
		return
	var weapon_id: String = _house_dialog_current_weapon_id()
	var skin_opts: Array = GameData.weapon_visual_skin_options(weapon_id)
	if index < 0 or index >= skin_opts.size():
		return
	var sid: String = String(skin_opts[index].get("id", "default"))
	GameState.set_weapon_visual_skin(_house_player_slot, weapon_id, sid)
	_update_house_status_label(
		tr("P1_HOUSE_WEAPON_SKIN_SAVED") % GameData.tr_weapon_name(weapon_id),
		_house_dialog_current_char_id(),
		false)
	_refresh_house_main_panel()
	_refresh_house_appearance_previews()


func _make_p1_house_favorite_row(slot_index: int) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lbl := Label.new()
	lbl.text = tr("P1_HOUSE_FAVORITE_SLOT_FMT") % (slot_index + 1)
	lbl.custom_minimum_size = Vector2(40, 0)
	row.add_child(lbl)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fav_slot: int = slot_index
	opt.item_selected.connect(func(item_index: int) -> void:
		_on_house_favorite_selected(fav_slot, item_index))
	row.add_child(opt)
	_house_favorite_option_buttons.append(opt)
	return row


func _populate_house_favorite_option(opt: OptionButton, char_id: String, slot_index: int) -> void:
	if slot_index < 0 or slot_index >= GameState.get_house_favorite_unlocked_slot_count():
		return
	if slot_index >= GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS:
		return
	opt.clear()
	var choices: Array[String] = GameState.house_favorite_armament_choices(
		_house_player_slot, char_id, slot_index)
	var fav_slots: Array[String] = GameState.get_house_favorite_armaments(_house_player_slot, char_id)
	var current: String = fav_slots[slot_index] if slot_index < fav_slots.size() else "none"
	var pick: int = 0
	for i in choices.size():
		var aid: String = choices[i]
		var label: String = tr("CSEL_NONE") if aid == "none" else GameData.tr_armament_name(aid)
		opt.add_item(label, i)
		if aid == current:
			pick = i
	opt.set_block_signals(true)
	opt.select(pick)
	opt.set_block_signals(false)


func _on_house_favorite_selected(slot_index: int, index: int) -> void:
	if _house_suppress_ui:
		return
	if slot_index < 0 or slot_index >= _house_favorite_option_buttons.size():
		return
	var char_id: String = _house_dialog_current_char_id()
	var choices: Array[String] = GameState.house_favorite_armament_choices(
		_house_player_slot, char_id, slot_index)
	if index < 0 or index >= choices.size():
		return
	var aid: String = choices[index]
	if not GameState.set_house_favorite_slot(_house_player_slot, char_id, slot_index, aid):
		_house_suppress_ui = true
		var opt: OptionButton = _house_favorite_option_buttons[slot_index]
		opt.set_block_signals(true)
		_populate_house_favorite_option(opt, char_id, slot_index)
		opt.set_block_signals(false)
		_house_suppress_ui = false
		_update_house_status_label(tr("P1_HOUSE_FAVORITE_DUPLICATE"), char_id)
		return
	_update_house_status_label(tr("P1_HOUSE_FAVORITE_SAVED"), char_id)
	# 其他格若曾選同一武裝，刷新選單（排除已佔用；含另一位玩家）
	_house_suppress_ui = true
	var cap2: int = GameState.get_house_favorite_unlocked_slot_count()
	for i in _house_favorite_option_buttons.size():
		if i != slot_index and i < cap2:
			var opt2: OptionButton = _house_favorite_option_buttons[i]
			opt2.set_block_signals(true)
			_populate_house_favorite_option(opt2, char_id, i)
			opt2.set_block_signals(false)
	_house_suppress_ui = false


func _update_house_status_label(status: String, char_id: String, show_bonus: bool = true) -> void:
	if _house_status_label == null or not is_instance_valid(_house_status_label):
		return
	if not show_bonus:
		_house_status_label.text = status
		return
	var stats: Dictionary = GameData.sum_armament_flat_stats(
		GameState.house_favorite_armament_ids_for_battle(_house_player_slot, char_id))
	var bonus_line: String = tr("P1_HOUSE_BONUS_PREVIEW_PREFIX") \
		+ GameData.format_armament_favorite_bonus_text(stats, true)
	if status != "":
		_house_status_label.text = status + "\n" + bonus_line
	else:
		_house_status_label.text = bonus_line


func _house_update_character_preview(char_id: String) -> void:
	if _house_preview == null:
		return
	var skin_id: String = GameState.get_house_character_skin(_house_player_slot, char_id)
	var visual: Dictionary = GameData.resolve_character_visual_def(char_id, skin_id)
	if visual.is_empty():
		visual = GameData.get_character_def(char_id)
	_house_preview.setup_character(visual)


func _house_first_frame_path(entry) -> String:
	if entry is String:
		return String(entry)
	if entry is Array and (entry as Array).size() > 0:
		return String((entry as Array)[0])
	if entry is Dictionary:
		var pat: String = String(entry.get("pattern", ""))
		var count: int = int(entry.get("count", 0))
		var start: int = int(entry.get("start", 1))
		if pat != "" and count > 0:
			return pat.replace("{i}", str(start))
	return ""


func _apply_house_skins_to_village_players() -> void:
	for p in players:
		if p == null or not is_instance_valid(p):
			continue
		var prefix: String = String(p.input_prefix)
		if prefix != "p1" and prefix != "p2":
			continue
		var cid: String = String(p.character_id)
		if cid == "":
			continue
		p.setup_from_character(cid)


func _on_rest_until(phase: String) -> void:
	match phase:
		"day":
			_village_time_sec = 0.0
		"evening":
			_village_time_sec = VILLAGE_TIME_DAY_DURATION
		"night":
			_village_time_sec = VILLAGE_TIME_DAY_DURATION + VILLAGE_TIME_EVENING_DURATION
	_village_time_phase = phase
	_apply_time_visuals(true)
	_close_house_dialog()


func _close_house_dialog() -> void:
	_close_house_favorites_dialog()
	_close_house_appearance_dialog()
	_close_house_summons_dialog()
	_close_house_pinball_bg_dialog()
	if _house_dialog != null and is_instance_valid(_house_dialog):
		_house_dialog.queue_free()
	_house_dialog = null
	_house_status_label = null
	_house_preview = null
	_house_weapon_preview = null
	_house_char_name_label = null
	_house_weapon_name_label = null
	_house_skin_option = null
	_house_weapon_skin_lbl = null
	_house_bow_skin_option = null
	_house_weapon_visual_section = null
	_house_fav_title = null
	_house_fav_grid = null
	_house_favorite_option_buttons.clear()
	_house_summon_slot_ui.clear()
	_house_summon_desc_label = null
	_house_suppress_ui = false
	get_tree().paused = false


func _players_near_node(node, radius: float) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	for p in players:
		if p != null and is_instance_valid(p) \
				and p.global_position.distance_to(node.global_position) <= radius:
			return true
	return false


func _open_blacksmith_dialog() -> void:
	if _blacksmith_dialog != null:
		return
	get_tree().paused = true
	_blacksmith_dialog = CanvasLayer.new()
	_blacksmith_dialog.layer = 240
	_blacksmith_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_blacksmith_dialog)

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_blacksmith_dialog.add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.58)
	root.add_child(dim)

	var panel := PanelContainer.new()
	_smith_dialog_panel = panel
	var panel_w: float = min(760.0, vp.x - 40.0)
	var panel_h: float = min(520.0, vp.y - 40.0)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	_style_house_modal_panel(panel)
	root.add_child(panel)
	_smith_resource_tip = _make_resource_tip_label()
	panel.add_child(_smith_resource_tip)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	vbox.add_child(header)

	var portrait := Panel.new()
	portrait.custom_minimum_size = Vector2(96, 96)
	header.add_child(portrait)
	var portrait_box := VBoxContainer.new()
	portrait_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_box.alignment = BoxContainer.ALIGNMENT_CENTER
	portrait.add_child(portrait_box)
	var portrait_title := Label.new()
	portrait_title.text = tr("VILLAGE_BLACKSMITH_NAME")
	portrait_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_title.add_theme_font_size_override("font_size", 16)
	portrait_box.add_child(portrait_title)
	var portrait_sub := Label.new()
	portrait_sub.text = GameData.tr_village_npc_subtitle("blacksmith")
	portrait_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_sub.add_theme_font_size_override("font_size", 12)
	portrait_sub.add_theme_color_override("font_color", Color(0.82, 0.82, 0.9))
	portrait_box.add_child(portrait_sub)

	var talk_box := VBoxContainer.new()
	talk_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(talk_box)
	var title := Label.new()
	title.text = tr("BLACKSMITH_SHOP_TITLE")
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	talk_box.add_child(title)
	var line := Label.new()
	line.text = _random_blacksmith_line()
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size", 15)
	talk_box.add_child(line)
	_smith_gold_label = RichTextLabel.new()
	_smith_gold_label.bbcode_enabled = true
	_smith_gold_label.fit_content = true
	_smith_gold_label.scroll_active = false
	_smith_gold_label.add_theme_color_override("default_color", Color(1.0, 0.86, 0.35))
	talk_box.add_child(_smith_gold_label)

	_smith_status_label = Label.new()
	_smith_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_smith_status_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	vbox.add_child(_smith_status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var goods := VBoxContainer.new()
	goods.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goods.add_theme_constant_override("separation", 6)
	scroll.add_child(goods)
	_add_blacksmith_goods(goods)

	var close_btn := Button.new()
	close_btn.text = tr("BLACKSMITH_CLOSE")
	close_btn.custom_minimum_size = Vector2(220, 46)
	close_btn.pressed.connect(_close_blacksmith_dialog)
	vbox.add_child(close_btn)
	close_btn.grab_focus()
	_smith_suppress_craft_press = false
	_refresh_blacksmith_dialog("")


func _make_blacksmith_shop_button() -> Button:
	var btn := Button.new()
	btn.custom_minimum_size.y = 44
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var rtl := RichTextLabel.new()
	rtl.name = _BLACKSMITH_BTN_LABEL
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.mouse_filter = Control.MOUSE_FILTER_STOP
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rtl.set_anchors_preset(Control.PRESET_FULL_RECT)
	rtl.offset_left = 10
	rtl.offset_top = 4
	rtl.offset_right = -10
	rtl.offset_bottom = -4
	if not rtl.meta_hover_started.is_connected(_on_smith_resource_meta_hover):
		rtl.meta_hover_started.connect(_on_smith_resource_meta_hover)
		rtl.meta_hover_ended.connect(_on_smith_resource_meta_hide)
		rtl.meta_clicked.connect(_on_smith_resource_meta_click)
	rtl.gui_input.connect(_on_smith_craft_label_gui_input.bind(btn))
	btn.add_child(rtl)
	return btn


func _make_resource_tip_label() -> Label:
	var lbl := Label.new()
	lbl.visible = false
	lbl.z_index = 30
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.98, 0.88))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	var tip_sb := StyleBoxFlat.new()
	tip_sb.bg_color = Color(0.05, 0.07, 0.14, 0.94)
	tip_sb.border_color = Color(0.95, 0.65, 0.18, 0.9)
	tip_sb.border_width_left = 1
	tip_sb.border_width_right = 1
	tip_sb.border_width_top = 1
	tip_sb.border_width_bottom = 1
	tip_sb.content_margin_left = 8
	tip_sb.content_margin_right = 8
	tip_sb.content_margin_top = 4
	tip_sb.content_margin_bottom = 4
	tip_sb.corner_radius_top_left = 4
	tip_sb.corner_radius_top_right = 4
	tip_sb.corner_radius_bottom_left = 4
	tip_sb.corner_radius_bottom_right = 4
	lbl.add_theme_stylebox_override("normal", tip_sb)
	return lbl


func _hide_smith_resource_tip() -> void:
	if _smith_resource_tip:
		_smith_resource_tip.visible = false


func _show_smith_resource_tip(text: String, at_global: Vector2) -> void:
	if _smith_resource_tip == null or _smith_dialog_panel == null or text == "":
		return
	_smith_resource_tip.text = text
	_smith_resource_tip.visible = true
	_smith_resource_tip.reset_size()
	var local_pos: Vector2 = _smith_dialog_panel.get_global_transform().affine_inverse() * at_global
	_smith_resource_tip.position = local_pos - Vector2(_smith_resource_tip.size.x * 0.5, _smith_resource_tip.size.y + 8.0)
	_smith_resource_tip.position.x = clampf(
		_smith_resource_tip.position.x, 8.0,
		_smith_dialog_panel.size.x - _smith_resource_tip.size.x - 8.0)
	_smith_resource_tip.position.y = maxf(8.0, _smith_resource_tip.position.y)


func _on_smith_resource_meta_hover(meta: Variant) -> void:
	var tip: String = GameData.resource_meta_tooltip(meta)
	if tip == "":
		return
	var mp: Vector2 = get_viewport().get_mouse_position()
	_show_smith_resource_tip(tip, mp)


func _on_smith_resource_meta_hide(_meta: Variant) -> void:
	_hide_smith_resource_tip()


func _on_smith_resource_meta_click(meta: Variant) -> void:
	var tip: String = GameData.resource_meta_tooltip(meta)
	if tip != "":
		var mp: Vector2 = get_viewport().get_mouse_position()
		_show_smith_resource_tip(tip, mp)
	# 點圖示只顯示名稱，不觸發購買（Godot 4.6 無 get_meta_at_position）
	_smith_suppress_craft_press = true


func _on_smith_craft_label_gui_input(event: InputEvent, btn: Button) -> void:
	if btn == null or btn.disabled:
		return
	var is_press: bool = false
	if event is InputEventScreenTouch:
		is_press = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		is_press = mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed
	if not is_press:
		return
	if _smith_suppress_craft_press:
		_smith_suppress_craft_press = false
		return
	btn.emit_signal("pressed")


func _set_blacksmith_button_bbcode(btn: Button, bbcode: String) -> void:
	var rtl: RichTextLabel = btn.get_node_or_null(_BLACKSMITH_BTN_LABEL) as RichTextLabel
	if rtl:
		rtl.text = bbcode
	else:
		btn.text = bbcode


func _add_blacksmith_goods(goods: VBoxContainer) -> void:
	# ── 格數升級 ──
	goods.add_child(_make_blacksmith_section_label(tr("BLACKSMITH_SECTION_SLOTS")))
	var slot_btn := _make_blacksmith_shop_button()
	slot_btn.name = "SlotButton"
	slot_btn.pressed.connect(_buy_blacksmith_slot)
	goods.add_child(slot_btn)
	var fav_slot_btn := _make_blacksmith_shop_button()
	fav_slot_btn.name = "FavoriteSlotButton"
	fav_slot_btn.pressed.connect(_buy_blacksmith_favorite_slot)
	goods.add_child(fav_slot_btn)
	var weapon_btn := _make_blacksmith_shop_button()
	weapon_btn.name = "WeaponKindButton"
	weapon_btn.pressed.connect(_buy_blacksmith_weapon_kind)
	goods.add_child(weapon_btn)
	# ── 武器製作 ──
	goods.add_child(_make_blacksmith_section_label(tr("BLACKSMITH_SECTION_WEAPONS")))
	for weapon_id in GameState.BLACKSMITH_CRAFT_WEAPON_IDS:
		var weapon_craft_btn := _make_blacksmith_shop_button()
		weapon_craft_btn.name = "WeaponCraft_" + weapon_id
		weapon_craft_btn.pressed.connect(_craft_blacksmith_weapon_kind.bind(weapon_id))
		goods.add_child(weapon_craft_btn)
	# ── 武裝製作 ──
	goods.add_child(_make_blacksmith_section_label(tr("BLACKSMITH_SECTION_ARMAMENTS")))
	for arm_id in GameData.blacksmith_armament_ids():
		var btn := _make_blacksmith_shop_button()
		btn.name = "Armament_" + arm_id
		btn.pressed.connect(_buy_blacksmith_armament.bind(arm_id))
		goods.add_child(btn)


func _make_blacksmith_section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.3))
	lbl.add_theme_constant_override("margin_top", 6)
	return lbl


func _refresh_blacksmith_dialog(status: String) -> void:
	if _blacksmith_dialog == null:
		return
	if _smith_gold_label:
		_smith_gold_label.text = tr("BLACKSMITH_GOLD_FMT") % GameData.format_gold_amount_bbcode(GameState.gold)
	if _smith_status_label:
		_smith_status_label.text = status
	var goods: Array = _blacksmith_dialog.find_children("*", "Button", true, false)
	for n in goods:
		var btn: Button = n as Button
		if btn == null:
			continue
		match String(btn.name):
			"SlotButton":
				if GameState.is_blacksmith_slot_tier2_locked():
					btn.disabled = true
					_set_blacksmith_button_bbcode(btn, tr("BLACKSMITH_TIER2_LOCKED"))
				else:
					var cost: int = GameState.next_weapon_slot_unlock_cost()
					btn.disabled = cost < 0 or GameState.gold < cost
					_set_blacksmith_button_bbcode(btn,
						tr("BLACKSMITH_BUY_SLOT_DONE") if cost < 0 \
						else tr("BLACKSMITH_BUY_SLOT_FMT") % [
							GameState.get_unlocked_weapon_slot_count() + 1,
							GameData.format_gold_cost_bbcode(cost)])
			"FavoriteSlotButton":
				if GameState.is_blacksmith_house_slot_tier2_locked():
					btn.disabled = true
					_set_blacksmith_button_bbcode(btn, tr("BLACKSMITH_TIER2_LOCKED"))
				else:
					var fc: int = GameState.next_house_favorite_slot_unlock_cost()
					var nxt: int = GameState.get_house_favorite_unlocked_slot_count() + 1
					btn.disabled = fc < 0 or GameState.gold < fc
					_set_blacksmith_button_bbcode(btn,
						tr("BLACKSMITH_BUY_FAVORITE_SLOT_DONE") if fc < 0 \
						else tr("BLACKSMITH_BUY_FAVORITE_SLOT_FMT") % [
							nxt, GameData.format_gold_cost_bbcode(fc)])
			"WeaponKindButton":
				var wid: String = GameState.next_locked_weapon_id()
				var tier2_wid: String = GameState.next_locked_weapon_id_tier2()
				if wid == "" and tier2_wid != "":
					btn.disabled = true
					_set_blacksmith_button_bbcode(btn, tr("BLACKSMITH_TIER2_LOCKED"))
				else:
					btn.disabled = wid == "" or GameState.gold < GameState.BLACKSMITH_WEAPON_KIND_COST
					_set_blacksmith_button_bbcode(btn,
						tr("BLACKSMITH_BUY_WEAPON_DONE") if wid == "" \
						else tr("BLACKSMITH_BUY_WEAPON_FMT") % [
							GameData.tr_weapon_name(wid),
							GameData.format_gold_cost_bbcode(GameState.BLACKSMITH_WEAPON_KIND_COST)])
			_:
				if String(btn.name).begins_with("WeaponCraft_"):
					var craft_weapon_id: String = String(btn.name).replace("WeaponCraft_", "")
					var wdef: Dictionary = GameData.get_weapon_def(craft_weapon_id)
					var weapon_owned: bool = GameState.is_weapon_unlocked(craft_weapon_id)
					# 已製作：隱藏
					btn.visible = not weapon_owned
					if not weapon_owned:
						var weapon_cost_text: String = _format_weapon_craft_cost(craft_weapon_id)
						btn.disabled = not GameState.can_craft_weapon_kind(craft_weapon_id)
						_set_blacksmith_button_bbcode(btn, tr("BLACKSMITH_CRAFT_WEAPON_FMT") % [
							GameData.tr_name(wdef), weapon_cost_text])
				elif String(btn.name).begins_with("Armament_"):
					var arm_id: String = String(btn.name).replace("Armament_", "")
					var adef: Dictionary = GameData.get_armament_def(arm_id)
					var owned: bool = GameState.is_armament_unlocked(arm_id)
					var has_recipe: bool = GameState.has_armament_recipe(arm_id)
					# 已製作或書籍未取得：隱藏
					var needs_book: bool = GameData.armament_requires_craft_book(arm_id)
					btn.visible = not owned and (not needs_book or has_recipe)
					if btn.visible:
						var cost_text: String = _format_armament_craft_cost(arm_id)
						btn.disabled = not GameState.can_craft_armament(arm_id)
						_set_blacksmith_button_bbcode(btn, tr("BLACKSMITH_CRAFT_ARMAMENT_FMT") % [
							GameData.format_armament_name_bbcode(arm_id), cost_text,
							GameData.tr_armament_desc_with_flat_stats(arm_id, true)])


func _format_weapon_craft_cost(weapon_id: String) -> String:
	var parts: Array[String] = []
	var gold_cost: int = GameState.weapon_gold_cost(weapon_id)
	if gold_cost > 0:
		parts.append(GameData.format_gold_cost_bbcode(gold_cost))
	for material_id in GameState.weapon_material_costs(weapon_id).keys():
		var mid: String = String(material_id)
		var need: int = int(GameState.weapon_material_costs(weapon_id)[material_id])
		var have: int = GameState.get_material_amount(mid)
		parts.append(GameData.format_material_cost_bbcode(mid, have, need))
	return " + ".join(parts)


func _format_armament_craft_cost(arm_id: String) -> String:
	var parts: Array[String] = []
	var gold_cost: int = GameState.armament_gold_cost(arm_id)
	if gold_cost > 0:
		parts.append(GameData.format_gold_cost_bbcode(gold_cost))
	for material_id in GameState.armament_material_costs(arm_id).keys():
		var mid: String = String(material_id)
		var need: int = int(GameState.armament_material_costs(arm_id)[material_id])
		var have: int = GameState.get_material_amount(mid)
		parts.append(GameData.format_material_cost_bbcode(mid, have, need))
	return " + ".join(parts)


func _buy_blacksmith_slot() -> void:
	var before: int = GameState.get_unlocked_weapon_slot_count()
	if GameState.buy_next_weapon_slot():
		_refresh_blacksmith_dialog(tr("BLACKSMITH_BOUGHT_SLOT_FMT") % (before + 1))
	else:
		_refresh_blacksmith_dialog(tr("BLACKSMITH_NOT_ENOUGH_GOLD"))


func _buy_blacksmith_favorite_slot() -> void:
	var before: int = GameState.get_house_favorite_unlocked_slot_count()
	if GameState.buy_next_house_favorite_slot():
		_refresh_blacksmith_dialog(tr("BLACKSMITH_BOUGHT_FAVORITE_SLOT_FMT") % (before + 1))
	else:
		_refresh_blacksmith_dialog(tr("BLACKSMITH_NOT_ENOUGH_GOLD"))


func _buy_blacksmith_weapon_kind() -> void:
	var wid: String = GameState.buy_next_weapon_kind()
	if wid != "":
		_refresh_blacksmith_dialog(tr("BLACKSMITH_BOUGHT_WEAPON_FMT") % GameData.tr_weapon_name(wid))
	else:
		_refresh_blacksmith_dialog(tr("BLACKSMITH_NOT_ENOUGH_GOLD"))


func _craft_blacksmith_weapon_kind(weapon_id: String) -> void:
	if GameState.craft_weapon_kind(weapon_id):
		_refresh_blacksmith_dialog(tr("BLACKSMITH_CRAFTED_WEAPON_FMT") % GameData.tr_weapon_name(weapon_id))
	else:
		_refresh_blacksmith_dialog(tr("BLACKSMITH_NOT_ENOUGH_RESOURCES"))


func _buy_blacksmith_armament(arm_id: String) -> void:
	var adef: Dictionary = GameData.get_armament_def(arm_id)
	if GameState.buy_armament(arm_id):
		_refresh_blacksmith_dialog(tr("BLACKSMITH_CRAFTED_ARMAMENT_FMT") % GameData.tr_name(adef))
	else:
		_refresh_blacksmith_dialog(tr("BLACKSMITH_NOT_ENOUGH_RESOURCES"))


func _close_blacksmith_dialog() -> void:
	if _blacksmith_dialog != null and is_instance_valid(_blacksmith_dialog):
		_blacksmith_dialog.queue_free()
	_blacksmith_dialog = null
	_smith_status_label = null
	_smith_gold_label = null
	_smith_resource_tip = null
	_smith_dialog_panel = null
	_smith_suppress_craft_press = false
	get_tree().paused = false


func _open_merchant_dialog() -> void:
	if _merchant_dialog != null:
		return
	get_tree().paused = true
	_merchant_dialog = CanvasLayer.new()
	_merchant_dialog.layer = 240
	_merchant_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_merchant_dialog)

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_merchant_dialog.add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.58)
	root.add_child(dim)

	var panel := PanelContainer.new()
	var panel_w: float = min(820.0, vp.x - 40.0)
	var panel_h: float = min(560.0, vp.y - 40.0)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	_style_house_modal_panel(panel)
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = tr("MERCHANT_SHOP_TITLE")
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.68, 0.92, 1.0))
	vbox.add_child(title)
	var merchant_who := Label.new()
	merchant_who.text = "%s　%s" % [
		tr("VILLAGE_MERCHANT_NAME"),
		GameData.tr_village_npc_subtitle("merchant"),
	]
	merchant_who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	merchant_who.add_theme_font_size_override("font_size", 14)
	merchant_who.add_theme_color_override("font_color", Color(0.78, 0.88, 0.95))
	vbox.add_child(merchant_who)

	var line := Label.new()
	line.text = tr("MERCHANT_DIALOG_1")
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size", 15)
	vbox.add_child(line)

	_merchant_gold_label = Label.new()
	_merchant_gold_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	vbox.add_child(_merchant_gold_label)

	_merchant_inventory_label = RichTextLabel.new()
	_merchant_inventory_label.bbcode_enabled = true
	_merchant_inventory_label.custom_minimum_size = Vector2(panel_w - 40, 72)
	_merchant_inventory_label.fit_content = false
	_merchant_inventory_label.scroll_active = false
	vbox.add_child(_merchant_inventory_label)

	_merchant_status_label = Label.new()
	_merchant_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_merchant_status_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	vbox.add_child(_merchant_status_label)

	var goods := VBoxContainer.new()
	goods.name = "MerchantGoods"
	goods.add_theme_constant_override("separation", 6)
	vbox.add_child(goods)
	_add_merchant_goods(goods)

	var close_btn := Button.new()
	close_btn.text = tr("MERCHANT_CLOSE")
	close_btn.custom_minimum_size = Vector2(220, 46)
	close_btn.pressed.connect(_close_merchant_dialog)
	vbox.add_child(close_btn)
	close_btn.grab_focus()
	_refresh_merchant_dialog("")


func _add_merchant_goods(goods: VBoxContainer) -> void:
	var ids: Array[String] = GameState.get_merchant_material_ids()
	if ids.is_empty():
		var empty := Label.new()
		empty.name = "MerchantEmpty"
		empty.text = tr("MERCHANT_NO_GOODS")
		empty.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
		goods.add_child(empty)
		return
	for id in ids:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		goods.add_child(row)
		var buy_btn := Button.new()
		buy_btn.name = "MerchantBuy_" + id
		buy_btn.custom_minimum_size = Vector2(350, 42)
		buy_btn.pressed.connect(_merchant_buy_material.bind(id))
		row.add_child(buy_btn)
		var sell_btn := Button.new()
		sell_btn.name = "MerchantSell_" + id
		sell_btn.custom_minimum_size = Vector2(350, 42)
		sell_btn.pressed.connect(_merchant_sell_material.bind(id))
		row.add_child(sell_btn)


func _refresh_merchant_dialog(status: String) -> void:
	if _merchant_dialog == null:
		return
	if _merchant_gold_label:
		_merchant_gold_label.text = tr("MERCHANT_GOLD_FMT") % GameState.gold
	if _merchant_status_label:
		_merchant_status_label.text = status
	if _merchant_inventory_label:
		var parts: Array[String] = []
		for id in GameState.get_merchant_material_ids():
			parts.append(tr("MERCHANT_INVENTORY_ITEM_FMT") % [
				GameData.tr_material_name(id), GameState.get_material_amount(id)])
		_merchant_inventory_label.text = tr("MERCHANT_INVENTORY_PREFIX") + "  ".join(parts)
	var buttons: Array = _merchant_dialog.find_children("*", "Button", true, false)
	for n in buttons:
		var btn: Button = n as Button
		if btn == null:
			continue
		var bname: String = String(btn.name)
		if bname.begins_with("MerchantBuy_"):
			var id: String = bname.replace("MerchantBuy_", "")
			btn.disabled = GameState.gold < GameState.MERCHANT_MATERIAL_BUY_PRICE
			btn.text = tr("MERCHANT_BUY_MATERIAL_FMT") % [
				GameData.tr_material_name(id), GameState.MERCHANT_MATERIAL_BUY_PRICE]
		elif bname.begins_with("MerchantSell_"):
			var id2: String = bname.replace("MerchantSell_", "")
			btn.disabled = GameState.get_material_amount(id2) <= 0
			btn.text = tr("MERCHANT_SELL_MATERIAL_FMT") % [
				GameData.tr_material_name(id2), GameState.MERCHANT_MATERIAL_SELL_PRICE]


func _merchant_buy_material(id: String) -> void:
	if GameState.buy_merchant_material(id):
		_refresh_merchant_dialog(tr("MERCHANT_BOUGHT_MATERIAL_FMT") % GameData.tr_material_name(id))
	else:
		_refresh_merchant_dialog(tr("MERCHANT_NOT_ENOUGH_GOLD"))


func _merchant_sell_material(id: String) -> void:
	if GameState.sell_merchant_material(id):
		_refresh_merchant_dialog(tr("MERCHANT_SOLD_MATERIAL_FMT") % GameData.tr_material_name(id))
	else:
		_refresh_merchant_dialog(tr("MERCHANT_NO_MATERIAL"))


func _close_merchant_dialog() -> void:
	if _merchant_dialog != null and is_instance_valid(_merchant_dialog):
		_merchant_dialog.queue_free()
	_merchant_dialog = null
	_merchant_status_label = null
	_merchant_gold_label = null
	_merchant_inventory_label = null
	get_tree().paused = false


func _update_rune_master_interaction() -> bool:
	if _rune_master_node == null or not is_instance_valid(_rune_master_node) \
			or not _rune_master_node.visible:
		return false
	var near: Array[String] = _players_in_range_prefixes(
		_rune_master_node, BLACKSMITH_INTERACT_RADIUS)
	if near.is_empty():
		return false
	_show_float_interact_prompt(
		_rune_master_node, near, tr("VILLAGE_INTERACT_ACTION_RUNE_MASTER"))
	if _try_interact_prefixes(near):
		_open_rune_master_dialog()
	return true


func _open_rune_master_dialog() -> void:
	if _rune_master_dialog != null:
		return
	get_tree().paused = true
	_rune_master_dialog = CanvasLayer.new()
	_rune_master_dialog.layer = 240
	_rune_master_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_rune_master_dialog)

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_rune_master_dialog.add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.58)
	root.add_child(dim)

	var panel := PanelContainer.new()
	var panel_w: float = min(560.0, vp.x - 40.0)
	var panel_h: float = min(420.0, vp.y - 40.0)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	_style_house_modal_panel(panel)
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = tr("RUNE_MASTER_SHOP_TITLE")
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.78, 0.62, 1.0))
	vbox.add_child(title)

	var who := Label.new()
	who.text = "%s　%s" % [
		tr("VILLAGE_RUNE_MASTER_NAME"),
		GameData.tr_village_npc_subtitle("rune_master"),
	]
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.add_theme_font_size_override("font_size", 14)
	who.add_theme_color_override("font_color", Color(0.78, 0.88, 0.95))
	vbox.add_child(who)

	var line := Label.new()
	line.text = tr("RUNE_MASTER_DIALOG_INTRO")
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size", 15)
	vbox.add_child(line)

	_rune_master_dust_label = Label.new()
	_rune_master_dust_label.add_theme_color_override("font_color", Color(0.78, 0.62, 1.0))
	vbox.add_child(_rune_master_dust_label)

	_rune_master_status_label = Label.new()
	_rune_master_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rune_master_status_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	vbox.add_child(_rune_master_status_label)

	var goods := VBoxContainer.new()
	goods.name = "RuneMasterGoods"
	goods.add_theme_constant_override("separation", 6)
	vbox.add_child(goods)

	var slot_btn := Button.new()
	slot_btn.name = "RuneMasterCommonSlotBtn"
	slot_btn.custom_minimum_size = Vector2(0, 44)
	slot_btn.pressed.connect(_buy_rune_master_common_slot)
	goods.add_child(slot_btn)

	var close_btn := Button.new()
	close_btn.text = tr("MERCHANT_CLOSE")
	close_btn.custom_minimum_size = Vector2(220, 46)
	close_btn.pressed.connect(_close_rune_master_dialog)
	vbox.add_child(close_btn)

	_refresh_rune_master_dialog("")


func _refresh_rune_master_dialog(status: String) -> void:
	if _rune_master_dialog == null:
		return
	if _rune_master_dust_label:
		_rune_master_dust_label.text = tr("RUNE_MASTER_DUST_FMT") % GameState.rune_dust
	if _rune_master_status_label:
		_rune_master_status_label.text = status
	var btn: Button = _rune_master_dialog.find_child("RuneMasterCommonSlotBtn", true, false) as Button
	if btn == null:
		return
	var cost: int = GameState.next_common_upgrade_slot_unlock_cost()
	if cost < 0:
		btn.disabled = true
		btn.text = tr("RUNE_MASTER_BUY_COMMON_SLOT_DONE")
	else:
		btn.disabled = false
		btn.text = tr("RUNE_MASTER_BUY_COMMON_SLOT_FMT") % [
			GameState.get_unlocked_common_upgrade_slot_count() + 1, cost]


func _buy_rune_master_common_slot() -> void:
	var before: int = GameState.get_unlocked_common_upgrade_slot_count()
	if GameState.buy_next_common_upgrade_slot():
		_refresh_rune_master_dialog(tr("RUNE_MASTER_BOUGHT_COMMON_SLOT_FMT") % (before + 1))
	else:
		_refresh_rune_master_dialog(tr("RUNE_MASTER_NOT_ENOUGH_DUST"))


func _close_rune_master_dialog() -> void:
	if _rune_master_dialog != null and is_instance_valid(_rune_master_dialog):
		_rune_master_dialog.queue_free()
	_rune_master_dialog = null
	_rune_master_status_label = null
	_rune_master_dust_label = null
	get_tree().paused = false
	get_tree().paused = false


func _random_blacksmith_line() -> String:
	var keys := ["BLACKSMITH_DIALOG_1", "BLACKSMITH_DIALOG_2", "BLACKSMITH_DIALOG_3"]
	return tr(keys.pick_random())


# ---------------- 玩家 ----------------
func _spawn_players() -> void:
	# 玩家中心放在地面 body_radius 上方，腳剛好踩在 floor_y（村莊會再乘 VILLAGE_BODY_RADIUS_MULT）
	var feet_x: float = spawn_origin.x

	var p1 = PLAYER_SCENE.instantiate()
	p1.input_prefix = "p1"
	p1.slot_index = 0
	p1.village_mode = true
	p1.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(p1)
	p1.setup_from_character(GameState.p1_character)
	p1.position = Vector2(feet_x - 30.0, floor_y - p1.body_radius)
	players.append(p1)

	if GameState.two_players:
		var p2 = PLAYER_SCENE.instantiate()
		p2.input_prefix = "p2"
		p2.slot_index = 1
		p2.village_mode = true
		p2.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(p2)
		p2.setup_from_character(GameState.p2_character)
		p2.position = Vector2(feet_x + 30.0, floor_y - p2.body_radius)
		players.append(p2)


func _clear_village_summon_followers() -> void:
	for f in _summon_followers:
		if f != null and is_instance_valid(f):
			f.queue_free()
	_summon_followers.clear()


func _refresh_village_summon_followers() -> void:
	_clear_village_summon_followers()
	for p in players:
		if p == null or not is_instance_valid(p):
			continue
		var prefix: String = String(p.input_prefix)
		var char_id: String = String(p.character_id)
		if char_id == "":
			continue
		var summon_ids: Array[String] = GameState.village_summon_ids_for_follow(prefix, char_id)
		var count: int = summon_ids.size()
		for i in count:
			var follower = VillageSummonFollowerT.new()
			add_child(follower)
			follower.setup(p, summon_ids[i], prefix, i, count)
			_summon_followers.append(follower)


func _position_camera() -> void:
	if players.is_empty():
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	if GameState.two_players and players.size() >= 2:
		Coop.clamp_player_pair_separation(players)
	var center: Vector2 = Coop.camera_center_alive(players)
	camera.global_position = center
	if GameState.two_players and players.size() >= 2:
		var p1 = players[0]
		var p2 = players[1]
		var both_alive: bool = p1 != null and p2 != null and p1.hp > 0.0 and p2.hp > 0.0
		if both_alive:
			camera.zoom = Coop.dynamic_zoom(Coop.pair_distance(players), CAMERA_ZOOM)
		else:
			camera.zoom = CAMERA_ZOOM
	else:
		camera.zoom = CAMERA_ZOOM
	Coop.clamp_camera_position(camera, _map_size, vp_size)


# ---------------- 後備背景（無地圖時的網格）----------------
func _draw_background() -> void:
	if not background:
		return
	background.fn = Callable(self, "_draw_grid")
	background.queue_redraw()


func _draw_grid(node: Node2D) -> void:
	var step := 80
	var size := 4000
	var col := Color(0.18, 0.22, 0.32, 0.6)
	for i in range(-size / step, size / step + 1):
		node.draw_line(Vector2(i * step, -size), Vector2(i * step, size), col)
		node.draw_line(Vector2(-size, i * step), Vector2(size, i * step), col)
