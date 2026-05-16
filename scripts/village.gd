extends Node2D
## 村莊場景：載入 New Village.tmx，玩家可自由走動，無敵人、無武器。
## ESC 開啟離開村莊選單。

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const RESCUE_NPC_TEXTURE := preload("res://assets/characters/Save NPC.png")
const MAP_PATH := GameData.VILLAGE_MAP_PATH
# New Village.tmx：200×15 tiles（16px）→ 3200×240，場景內再放大 1.5 倍 → 4800×360。
const MAP_SCALE := GameData.VILLAGE_MAP_SCALE
const MAP_SIZE: Vector2 = Vector2(
	float(GameData.VILLAGE_MAP_TILES.x * GameData.VILLAGE_MAP_TILE_PX) * MAP_SCALE,
	float(GameData.VILLAGE_MAP_TILES.y * GameData.VILLAGE_MAP_TILE_PX) * MAP_SCALE,
)
const CAMERA_ZOOM := Vector2(2.0, 2.0)
const BLACKSMITH_INTERACT_RADIUS := 90.0
const MERCHANT_INTERACT_RADIUS := 90.0
const VILLAGE_FACILITY_INTERACT_RADIUS := 90.0
const P1_HOUSE_INTERACT_RADIUS := 100.0
const CROP_PLOT_INTERACT_RADIUS := 72.0
const WELL_INTERACT_RADIUS := 88.0
const FARMER_INTERACT_RADIUS := 90.0
const VILLAGE_TOUCH_BTN_SIZE := Vector2(78.0, 56.0)

const Coop := preload("res://scripts/coop_pair_follow.gd")
const CoopPointerOverlay := preload("res://scripts/coop_pointer_overlay.gd")
const InputPrompt := preload("res://scripts/input_prompt.gd")

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
var spawn_origin: Vector2 = Vector2.ZERO
var tile_size: int = 16
var blocked_tiles: Dictionary = {}
# 玩家「腳底」的世界 Y 座標；走出地圖時固定在這條線上
var floor_y: float = 0.0
# 左側 Obstacle 物件框右緣（可走區下限）
var _map_walk_min_x: float = 8.0

var _pause_open: bool = false
var _transitioning: bool = false
var _coop_pointer_overlay: Control = null
var _blacksmith_node: Node2D = null
var _merchant_node: Node2D = null
var _blacksmith_dialog: CanvasLayer = null
var _smith_status_label: Label = null
var _smith_gold_label: Label = null
var _merchant_dialog: CanvasLayer = null
var _p1_house_node: Node2D = null
var _p2_house_node: Node2D = null
var _house_dialog: CanvasLayer = null
var _house_player_slot: String = "p1"
var _house_status_label: Label = null
var _house_char_index: int = 0
var _house_suppress_ui: bool = false
var _house_preview: TextureRect = null
var _house_char_name_label: Label = null
var _house_skin_option: OptionButton = null
var _house_fav_title: Label = null
var _house_fav_grid: GridContainer = null
var _house_favorite_option_buttons: Array[OptionButton] = []
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
var _float_prompt_target: Node2D = null
var _well_node: Node2D = null
var _farmer_shop_node: Node2D = null
var _crop_plot_nodes: Dictionary = {}
var _well_dialog: CanvasLayer = null
var _farmer_dialog: CanvasLayer = null
var _crop_dialog: CanvasLayer = null
var _crop_dialog_slot: int = 0


func _ready() -> void:
	# 自身永遠處理（讓暫停時 ESC 仍能被偵測）；玩家會被個別設為 PAUSABLE
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera.make_current()
	_spawn_map()
	_spawn_blacksmith_if_rescued()
	_spawn_merchant_if_rescued()
	_spawn_rescued_story_npcs()
	_spawn_village_facilities()
	_spawn_farm_and_well_nodes()
	_spawn_p1_house_marker()
	_spawn_p2_house_marker()
	_spawn_players()
	_position_camera()
	if GameState.two_players and players.size() >= 2:
		_coop_pointer_overlay = CoopPointerOverlay.new()
		_coop_pointer_overlay.setup(self)
		hud.add_child(_coop_pointer_overlay)
	_draw_background()
	_setup_hud()


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
		if _blacksmith_dialog != null:
			_close_blacksmith_dialog()
			return
		if _merchant_dialog != null:
			_close_merchant_dialog()
			return
		if _facility_dialog != null:
			_close_facility_dialog()
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
		if _pause_open:
			_close_pause()
		else:
			_open_pause()
		return
	_update_npc_interactions()
	_refresh_village_touch_visibility()
	_position_camera()
	_position_float_interact_prompt()


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
		and _facility_dialog == null and _house_dialog == null \
		and _well_dialog == null and _farmer_dialog == null and _crop_dialog == null
	if _touch_controls_root.visible != show and not show:
		_release_village_touch_actions()
	_touch_controls_root.visible = show


func _release_village_touch_actions() -> void:
	for action in ["p1_left", "p1_right", "p1_up"]:
		Input.action_release(action)


func _on_touch_interact_pressed() -> void:
	if _pause_open or _blacksmith_dialog != null or _merchant_dialog != null \
			or _facility_dialog != null or _house_dialog != null \
			or _well_dialog != null or _farmer_dialog != null or _crop_dialog != null:
		return
	if _try_open_nearest_crop_dialog():
		pass
	elif _players_near_node(_well_node, WELL_INTERACT_RADIUS):
		_open_well_dialog()
	elif _players_near_node(_farmer_shop_node, FARMER_INTERACT_RADIUS):
		_open_farmer_dialog()
	elif _players_near_node(_blacksmith_node, BLACKSMITH_INTERACT_RADIUS):
		_open_blacksmith_dialog()
	elif _players_near_node(_merchant_node, MERCHANT_INTERACT_RADIUS):
		_open_merchant_dialog()
	elif _try_open_nearest_facility_dialog():
		pass
	elif _player_near_node(_p1_house_node, P1_HOUSE_INTERACT_RADIUS, "p1"):
		_open_house_dialog("p1")
	elif GameState.two_players and _player_near_node(_p2_house_node, P1_HOUSE_INTERACT_RADIUS, "p2"):
		_open_house_dialog("p2")


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


func _leave_village() -> void:
	if _transitioning:
		return
	_transitioning = true
	get_tree().paused = false
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/Main.tscn")


# ---------------- 地圖 ----------------
func _spawn_map() -> void:
	# 不論成功/失敗，先給一組預設攝影機設定（沒地圖時也能走）
	camera.zoom = CAMERA_ZOOM
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(MAP_SIZE.x)
	camera.limit_bottom = int(MAP_SIZE.y)
	tile_size = int(round(16.0 * MAP_SCALE))
	# 預設地面：地圖偏下，玩家腳踩於此
	floor_y = MAP_SIZE.y * 0.70
	spawn_origin = Vector2(MAP_SIZE.x * 0.10, floor_y)
	if not ResourceLoader.exists(MAP_PATH):
		push_warning("[Village] 找不到地圖：%s，使用空白世界。" % MAP_PATH)
		return
	var packed: PackedScene = load(MAP_PATH)
	if packed == null:
		push_warning("[Village] 地圖載入失敗：%s" % MAP_PATH)
		return
	map_node = packed.instantiate()
	add_child(map_node)
	move_child(map_node, 0)
	if map_node is Node2D:
		(map_node as Node2D).z_index = -10
		(map_node as Node2D).scale = Vector2(MAP_SCALE, MAP_SCALE)
	if background:
		background.visible = false
	# 物件層：若有 Entrance/entrance 採用該座標當「出生 X」
	var entrance: Node = _find_map_object_by_name(GameData.VILLAGE_MAP_ENTRANCE_SLOTS)
	if entrance is Node2D:
		spawn_origin = (entrance as Node2D).global_position
	var obstacle: Node = _find_map_object_by_name(["Obstacle", "obstacle"])
	if obstacle is Node2D:
		# TMX 中 Obstacle 寬約 78.67 tile 單位，與地圖同乘 MAP_SCALE
		_map_walk_min_x = (obstacle as Node2D).global_position.x + 79.0 * MAP_SCALE
	# 地面 Y 採取下面優先順序：
	#   1) 物件層名稱為 Floor / Ground / floor / ground 的物件 Y
	#   2) Buildings 群組底下所有 Sprite2D 的視覺底部最大值（建築物腳）
	#   3) Entrance 自身 Y
	#   4) MAP_SIZE.y * 0.85（保險預設）
	var floor_obj: Node = _find_map_object_by_name(GameData.VILLAGE_MAP_FLOOR_SLOTS)
	if floor_obj is Node2D:
		floor_y = (floor_obj as Node2D).global_position.y
	else:
		var auto_y: float = _detect_floor_y_from_group("Buildings")
		if auto_y > 0.0:
			floor_y = auto_y
		elif entrance is Node2D:
			floor_y = (entrance as Node2D).global_position.y
	_build_blocked_grid()


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
	if pos.x + radius > MAP_SIZE.x - 8.0:
		return true
	if pos.y + radius > MAP_SIZE.y - 8.0:
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
	var pos: Vector2 = _map_marker_position(slot, Vector2(MAP_SIZE.x * 0.65, floor_y - 42.0))
	var smith := _make_blacksmith_village_marker()
	smith.global_position = pos
	add_child(smith)
	_blacksmith_node = smith


func _make_blacksmith_village_marker() -> Node2D:
	var root := Node2D.new()
	root.name = "VillageBlacksmith"
	root.z_index = 9
	var draw := DrawerNode2D.new()
	draw.fn = Callable(self, "_draw_village_blacksmith")
	root.add_child(draw)
	var label := Label.new()
	label.text = tr("VILLAGE_BLACKSMITH_NAME")
	label.position = Vector2(-80, -86)
	label.size = Vector2(160, 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
	root.add_child(label)
	return root


func _draw_village_blacksmith(node: Node2D) -> void:
	node.draw_circle(Vector2(0, 34), 34.0, Color(0, 0, 0, 0.22))
	node.draw_circle(Vector2(0, -20), 15.0, Color(0.95, 0.72, 0.48))
	node.draw_rect(Rect2(-17, -5, 34, 40), Color(0.28, 0.30, 0.36))
	node.draw_rect(Rect2(-25, -2, 50, 10), Color(0.72, 0.62, 0.44))
	node.draw_line(Vector2(18, 2), Vector2(46, -26), Color(0.74, 0.52, 0.32), 5.0)
	node.draw_rect(Rect2(40, -36, 24, 12), Color(0.70, 0.72, 0.76))


func _spawn_merchant_if_rescued() -> void:
	if not bool(GameState.merchant_rescued):
		return
	var slot: Node = _find_map_object_by_name(GameData.VILLAGE_MAP_MERCHANT_SLOTS)
	var pos: Vector2 = _map_marker_position(slot, Vector2(MAP_SIZE.x * 0.53, floor_y - 42.0))
	var merchant := _make_merchant_village_marker()
	merchant.global_position = pos
	add_child(merchant)
	_merchant_node = merchant


func _make_merchant_village_marker() -> Node2D:
	var root := Node2D.new()
	root.name = "VillageMerchant"
	root.z_index = 9
	var draw := DrawerNode2D.new()
	draw.fn = Callable(self, "_draw_village_merchant")
	root.add_child(draw)
	var label := Label.new()
	label.text = tr("VILLAGE_MERCHANT_NAME")
	label.position = Vector2(-90, -86)
	label.size = Vector2(180, 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.68, 0.92, 1.0))
	root.add_child(label)
	return root


func _draw_village_merchant(node: Node2D) -> void:
	node.draw_circle(Vector2(0, 34), 34.0, Color(0, 0, 0, 0.22))
	node.draw_circle(Vector2(0, -20), 14.0, Color(0.95, 0.76, 0.55))
	node.draw_rect(Rect2(-18, -5, 36, 40), Color(0.24, 0.38, 0.45))
	node.draw_rect(Rect2(-30, 10, 60, 24), Color(0.52, 0.31, 0.16))
	node.draw_rect(Rect2(-24, 0, 48, 10), Color(0.86, 0.62, 0.24))
	node.draw_string(ThemeDB.fallback_font, Vector2(-7, 8), "$",
		HORIZONTAL_ALIGNMENT_CENTER, 14, 22, Color(1.0, 0.92, 0.45))


func _map_marker_position(slot: Node, fallback: Vector2) -> Vector2:
	if slot is Node2D:
		return Vector2((slot as Node2D).global_position.x, floor_y - 42.0)
	return fallback


func _spawn_rescued_story_npcs() -> void:
	for entry in GameData.VILLAGE_RESCUED_NPC_MARKERS:
		var npc_id: String = String(entry.get("npc_id", ""))
		if npc_id == "" or not GameState.is_npc_rescued(npc_id):
			continue
		if npc_id == "farmer" and GameState.is_village_facility_unlocked("farm"):
			continue
		var slots: Array = []
		for s in entry.get("map_slots", []):
			slots.append(String(s))
		var slot: Node = _find_map_object_by_name(slots)
		var pos: Vector2 = _map_marker_position(
			slot, Vector2(MAP_SIZE.x * 0.5, floor_y - 42.0))
		var marker := _make_rescued_npc_marker(String(entry.get("name_key", "")))
		marker.global_position = pos
		add_child(marker)


func _make_rescued_npc_marker(name_key: String) -> Node2D:
	var root := Node2D.new()
	root.name = "VillageRescuedNpc"
	root.z_index = 7
	var spr := Sprite2D.new()
	spr.texture = RESCUE_NPC_TEXTURE
	if spr.texture:
		var ts: Vector2 = spr.texture.get_size()
		var target_h: float = 72.0
		if ts.y > 0.0:
			spr.scale = Vector2.ONE * (target_h / ts.y)
		spr.position = Vector2(0, -target_h * 0.5 + 34.0)
	root.add_child(spr)
	var label := Label.new()
	label.text = tr(name_key) if name_key != "" else ""
	label.position = Vector2(-80, -86)
	label.size = Vector2(160, 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.88, 0.95, 1.0))
	root.add_child(label)
	return root


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
		var pos: Vector2 = _map_marker_position(slot, Vector2(
			MAP_SIZE.x * float(fdef.get("fallback_x_mult", 0.1)),
			floor_y - 42.0))
		var marker := _make_village_facility_marker(fid, fdef)
		marker.global_position = pos
		add_child(marker)
		_facility_nodes[fid] = marker


func _spawn_farm_and_well_nodes() -> void:
	_crop_plot_nodes.clear()
	if GameState.is_village_facility_unlocked("well"):
		var well_slot: Node = _find_map_object_by_name(["Water", "water", "well"])
		var wpos: Vector2 = _map_marker_position(well_slot, Vector2(MAP_SIZE.x * 0.11, floor_y - 42.0))
		_well_node = _make_well_marker()
		_well_node.global_position = wpos
		add_child(_well_node)
	if GameState.is_village_facility_unlocked("farm"):
		var farmer_slot: Node = _find_map_object_by_name(["Farmer", "farmer", "farm"])
		var fpos: Vector2 = _map_marker_position(farmer_slot, Vector2(MAP_SIZE.x * 0.16, floor_y - 42.0))
		_farmer_shop_node = _make_farmer_shop_marker()
		_farmer_shop_node.global_position = fpos
		add_child(_farmer_shop_node)
		for i in range(1, GameData.FARM_PLOT_COUNT + 1):
			var slot_name: String = GameData.farm_plot_map_slot_name(i)
			var crop_slot: Node = _find_map_object_by_name([slot_name])
			var cpos: Vector2 = _map_marker_position(
				crop_slot, Vector2(MAP_SIZE.x * 0.12 + float(i) * 18.0, floor_y - 36.0))
			var plot := _make_crop_plot_marker(i)
			plot.global_position = cpos
			add_child(plot)
			_crop_plot_nodes[i] = plot


func _make_well_marker() -> Node2D:
	var root := Node2D.new()
	root.name = "VillageWell"
	root.z_index = 8
	var draw := DrawerNode2D.new()
	draw.fn = Callable(self, "_draw_well_marker")
	root.add_child(draw)
	var label := Label.new()
	label.text = tr("VILLAGE_WELL_NAME")
	label.position = Vector2(-70, -80)
	label.size = Vector2(140, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.55, 0.82, 1.0))
	root.add_child(label)
	return root


func _draw_well_marker(node: Node2D) -> void:
	node.draw_circle(Vector2(0, 30), 28.0, Color(0, 0, 0, 0.2))
	node.draw_rect(Rect2(-22, -6, 44, 36), Color(0.35, 0.42, 0.55))
	node.draw_circle(Vector2(0, -8), 14.0, Color(0.42, 0.72, 0.95))


func _make_farmer_shop_marker() -> Node2D:
	var root := Node2D.new()
	root.name = "VillageFarmerShop"
	root.z_index = 9
	var draw := DrawerNode2D.new()
	draw.fn = Callable(self, "_draw_farmer_shop_marker")
	root.add_child(draw)
	var label := Label.new()
	label.text = tr("VILLAGE_FARMER_NAME")
	label.position = Vector2(-80, -86)
	label.size = Vector2(160, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.65))
	root.add_child(label)
	return root


func _draw_farmer_shop_marker(node: Node2D) -> void:
	node.draw_circle(Vector2(0, 34), 32.0, Color(0, 0, 0, 0.2))
	node.draw_circle(Vector2(0, -18), 14.0, Color(0.95, 0.76, 0.55))
	node.draw_rect(Rect2(-16, -4, 32, 36), Color(0.35, 0.55, 0.32))
	node.draw_rect(Rect2(-20, 12, 40, 18), Color(0.62, 0.45, 0.22))


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
	var node: Node2D = _crop_plot_nodes.get(slot) as Node2D
	if node == null:
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
	if _farmer_shop_node == null or not is_instance_valid(_farmer_shop_node):
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


func _open_simple_village_dialog(title: String) -> Dictionary:
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
	var status_lbl := Label.new()
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(status_lbl)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	vbox.add_child(actions)
	var close_btn := Button.new()
	close_btn.text = tr("BLACKSMITH_CLOSE")
	vbox.add_child(close_btn)
	return {"layer": layer, "status": status_lbl, "actions": actions, "close": close_btn}


func _open_well_dialog() -> void:
	if _well_dialog != null:
		return
	var ui: Dictionary = _open_simple_village_dialog(tr("VILLAGE_WELL_NAME"))
	_well_dialog = ui["layer"] as CanvasLayer
	var status: Label = ui["status"] as Label
	var actions: VBoxContainer = ui["actions"] as VBoxContainer
	status.text = tr("VILLAGE_WELL_STATUS_FMT") % [
		GameState.water_charges, GameData.VILLAGE_WATER_MAX_CHARGES]
	var fill_btn := Button.new()
	fill_btn.text = tr("VILLAGE_WELL_FILL_BTN")
	fill_btn.pressed.connect(func() -> void:
		GameState.fill_water_at_well()
		status.text = tr("VILLAGE_WELL_FILLED_FMT") % GameData.VILLAGE_WATER_MAX_CHARGES)
	actions.add_child(fill_btn)
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
	var ui: Dictionary = _open_simple_village_dialog(tr("VILLAGE_FARMER_NAME"))
	_farmer_dialog = ui["layer"] as CanvasLayer
	var status: Label = ui["status"] as Label
	var actions: VBoxContainer = ui["actions"] as VBoxContainer
	status.text = tr("VILLAGE_FARMER_INTRO")
	for seed_id in GameData.FARMER_SEED_PRICES.keys():
		var sid: String = String(seed_id)
		var price: int = int(GameData.FARMER_SEED_PRICES[sid])
		var btn := Button.new()
		btn.text = tr("VILLAGE_FARMER_BUY_SEED_FMT") % [
			GameData.tr_material_name(sid), price]
		btn.pressed.connect(_farmer_buy_seed.bind(sid, status))
		actions.add_child(btn)
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
	var ui: Dictionary = _open_simple_village_dialog(
		tr("VILLAGE_CROP_PLOT_TITLE_FMT") % slot_index)
	_crop_dialog = ui["layer"] as CanvasLayer
	var status: Label = ui["status"] as Label
	var actions: VBoxContainer = ui["actions"] as VBoxContainer
	_refresh_crop_dialog_ui(status, actions)
	(ui["close"] as Button).pressed.connect(_close_crop_dialog)


func _refresh_crop_dialog_ui(status: Label, actions: VBoxContainer) -> void:
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
	elif GameState.farm_plot_is_ready(slot):
		status.text = tr("FARM_PLOT_STATUS_READY")
		var harvest_btn := Button.new()
		harvest_btn.text = tr("VILLAGE_CROP_HARVEST_BTN")
		harvest_btn.pressed.connect(_crop_harvest.bind(status, actions))
		actions.add_child(harvest_btn)
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


func _crop_plant(seed_id: String, status: Label, actions: VBoxContainer) -> void:
	if GameState.plant_farm_plot(_crop_dialog_slot, seed_id):
		_redraw_crop_plot(_crop_dialog_slot)
		_refresh_crop_dialog_ui(status, actions)
	else:
		status.text = tr("VILLAGE_CROP_PLANT_FAIL")


func _crop_water(status: Label, actions: VBoxContainer) -> void:
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


func _crop_harvest(status: Label, actions: VBoxContainer) -> void:
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
		or _facility_dialog != null or _house_dialog != null \
		or _well_dialog != null or _farmer_dialog != null or _crop_dialog != null


func _make_village_facility_marker(facility_id: String, fdef: Dictionary) -> Node2D:
	var root := Node2D.new()
	root.name = "VillageFacility_%s" % facility_id
	root.z_index = 8
	root.set_meta("facility_id", facility_id)
	var draw := DrawerNode2D.new()
	draw.set_meta("facility_id", facility_id)
	draw.fn = Callable(self, "_draw_village_facility_marker")
	root.add_child(draw)
	var label := Label.new()
	label.text = GameData.tr_field(fdef, "name", false)
	label.position = Vector2(-100, -86)
	label.size = Vector2(200, 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.7))
	root.add_child(label)
	return root


func _draw_village_facility_marker(node: Node2D) -> void:
	_draw_village_facility(node, String(node.get_meta("facility_id", "")))


func _draw_village_facility(node: Node2D, facility_id: String) -> void:
	var col: Color = Color(0.55, 0.82, 0.45)
	match facility_id:
		"quarry":
			col = Color(0.65, 0.62, 0.58)
		"lumberyard":
			col = Color(0.45, 0.72, 0.38)
		"well":
			col = Color(0.42, 0.72, 0.95)
		"farm":
			col = Color(0.72, 0.85, 0.42)
	node.draw_circle(Vector2(0, 34), 34.0, Color(0, 0, 0, 0.22))
	node.draw_rect(Rect2(-28, -8, 56, 44), col.darkened(0.25))
	node.draw_rect(Rect2(-22, -2, 44, 32), col)
	node.draw_circle(Vector2(0, -18), 12.0, col.lightened(0.2))


func _update_npc_interactions() -> void:
	if _pause_open or _blacksmith_dialog != null or _merchant_dialog != null \
			or _facility_dialog != null or _house_dialog != null \
			or _well_dialog != null or _farmer_dialog != null or _crop_dialog != null:
		_hide_float_interact_prompt()
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
	if _update_facility_interaction():
		return
	if _update_p1_house_interaction():
		return
	if _update_p2_house_interaction():
		return
	_hide_float_interact_prompt()
	hint_label.text = tr("VILLAGE_HINT")


func _players_in_range_prefixes(
		node: Node2D, radius: float, only_prefix: String = "") -> Array[String]:
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
		target: Node2D, near_prefixes: Array[String], action_text: String) -> void:
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
	var world_pos: Vector2 = _float_prompt_target.global_position + Vector2(0.0, -78.0)
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
	if _blacksmith_node == null or not is_instance_valid(_blacksmith_node):
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
	if _merchant_node == null or not is_instance_valid(_merchant_node):
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
		if node == null or not is_instance_valid(node):
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
	_facility_dialog = CanvasLayer.new()
	_facility_dialog.layer = 240
	_facility_dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_facility_dialog)
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 24)
	root.add_theme_constant_override("margin_right", 24)
	root.add_theme_constant_override("margin_top", 24)
	root.add_theme_constant_override("margin_bottom", 24)
	_facility_dialog.add_child(root)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 280)
	root.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = GameData.tr_field(fdef, "name", false)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)
	_facility_status_label = Label.new()
	_facility_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_facility_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_facility_status_label)
	var collect_btn := Button.new()
	collect_btn.text = tr(String(fdef.get("collect_key", "VILLAGE_FACILITY_COLLECT")))
	collect_btn.pressed.connect(_on_facility_collect_pressed)
	vbox.add_child(collect_btn)
	var close_btn := Button.new()
	close_btn.text = tr("BLACKSMITH_CLOSE")
	close_btn.pressed.connect(_close_facility_dialog)
	vbox.add_child(close_btn)
	_refresh_facility_dialog()


func _refresh_facility_dialog(status: String = "") -> void:
	if _facility_status_label == null or _facility_dialog_id == "":
		return
	if status != "":
		_facility_status_label.text = status
		return
	var left: float = GameState.village_facility_collect_cooldown_left(_facility_dialog_id)
	if left > 0.0:
		_facility_status_label.text = tr("VILLAGE_FACILITY_COOLDOWN_FMT") % int(ceil(left))
	else:
		_facility_status_label.text = tr("VILLAGE_FACILITY_READY")


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


func _spawn_p1_house_marker() -> void:
	var slot: Node = _find_map_object_by_name(GameData.VILLAGE_MAP_HOME_P1_SLOTS)
	var pos: Vector2 = _map_marker_position(slot, Vector2(MAP_SIZE.x * 0.47, floor_y - 42.0))
	if slot is Node2D:
		pos = (slot as Node2D).global_position + Vector2(0.0, -36.0)
	var home := Node2D.new()
	home.name = "VillageP1House"
	home.z_index = 8
	home.global_position = pos
	var draw := DrawerNode2D.new()
	draw.fn = Callable(self, "_draw_p1_house_marker")
	home.add_child(draw)
	var label := Label.new()
	label.text = tr("VILLAGE_P1_HOUSE_NAME")
	label.position = Vector2(-72, -78)
	label.size = Vector2(144, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65))
	home.add_child(label)
	add_child(home)
	_p1_house_node = home


func _draw_p1_house_marker(node: Node2D) -> void:
	node.draw_circle(Vector2(0, 28), 30.0, Color(0, 0, 0, 0.2))
	node.draw_rect(Rect2(-28, -8, 56, 44), Color(0.55, 0.42, 0.28))
	node.draw_rect(Rect2(-20, -28, 40, 22), Color(0.72, 0.55, 0.35))
	node.draw_rect(Rect2(-8, -18, 16, 18), Color(0.35, 0.25, 0.15))


func _player_near_node(node: Node2D, radius: float, input_prefix: String) -> bool:
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
	if Input.is_action_just_pressed("p2_action") or Input.is_action_just_pressed("ui_accept"):
		_open_house_dialog("p2")
	return true


func _spawn_p2_house_marker() -> void:
	var slot: Node = _find_map_object_by_name(GameData.VILLAGE_MAP_HOME_P2_SLOTS)
	var pos: Vector2 = _map_marker_position(slot, Vector2(MAP_SIZE.x * 0.53, floor_y - 42.0))
	if slot is Node2D:
		pos = (slot as Node2D).global_position + Vector2(0.0, -36.0)
	var home := Node2D.new()
	home.name = "VillageP2House"
	home.z_index = 8
	home.global_position = pos
	var draw := DrawerNode2D.new()
	draw.fn = Callable(self, "_draw_p2_house_marker")
	home.add_child(draw)
	var label := Label.new()
	label.text = tr("VILLAGE_P2_HOUSE_NAME")
	label.position = Vector2(-72, -78)
	label.size = Vector2(144, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.65, 0.88, 0.98))
	home.add_child(label)
	add_child(home)
	_p2_house_node = home


func _draw_p2_house_marker(node: Node2D) -> void:
	node.draw_circle(Vector2(0, 28), 30.0, Color(0, 0, 0, 0.2))
	node.draw_rect(Rect2(-28, -8, 56, 44), Color(0.38, 0.48, 0.62))
	node.draw_rect(Rect2(-20, -28, 40, 22), Color(0.52, 0.65, 0.82))
	node.draw_rect(Rect2(-8, -18, 16, 18), Color(0.28, 0.38, 0.52))


func _open_house_dialog(player_slot: String) -> void:
	if _house_dialog != null:
		return
	if player_slot != "p1" and player_slot != "p2":
		return
	if player_slot == "p2" and not GameState.two_players:
		return
	_house_player_slot = player_slot
	_house_char_index = _house_dialog_start_char_index()
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

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.58)
	root.add_child(dim)

	var panel := PanelContainer.new()
	var panel_w: float = min(720.0, vp.x - 32.0)
	var panel_h: float = min(580.0, vp.y - 32.0)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
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

	# 角色切換列：◀ 預覽 ▶
	var char_row := HBoxContainer.new()
	char_row.alignment = BoxContainer.ALIGNMENT_CENTER
	char_row.add_theme_constant_override("separation", 12)
	vbox.add_child(char_row)

	var prev_btn := Button.new()
	prev_btn.text = tr("P1_HOUSE_CHAR_PREV")
	prev_btn.custom_minimum_size = Vector2(52, 52)
	prev_btn.pressed.connect(_on_p1_house_char_prev)
	char_row.add_child(prev_btn)

	var preview_panel := Panel.new()
	preview_panel.custom_minimum_size = Vector2(160, 160)
	char_row.add_child(preview_panel)

	_house_preview = TextureRect.new()
	_house_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	_house_preview.offset_left = 8.0
	_house_preview.offset_top = 8.0
	_house_preview.offset_right = -8.0
	_house_preview.offset_bottom = -8.0
	_house_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_house_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_house_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_panel.add_child(_house_preview)

	var next_btn := Button.new()
	next_btn.text = tr("P1_HOUSE_CHAR_NEXT")
	next_btn.custom_minimum_size = Vector2(52, 52)
	next_btn.pressed.connect(_on_p1_house_char_next)
	char_row.add_child(next_btn)

	_house_char_name_label = Label.new()
	_house_char_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_house_char_name_label.add_theme_font_size_override("font_size", 20)
	_house_char_name_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	vbox.add_child(_house_char_name_label)

	var nav_hint := Label.new()
	nav_hint.text = tr("P1_HOUSE_CHAR_NAV_HINT")
	nav_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav_hint.add_theme_font_size_override("font_size", 12)
	nav_hint.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	vbox.add_child(nav_hint)

	# 造型
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

	# 喜愛武裝（格數依鐵匠擴充）
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

	_house_status_label = Label.new()
	_house_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_house_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_house_status_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	vbox.add_child(_house_status_label)

	var close_btn := Button.new()
	close_btn.text = tr("P1_HOUSE_CLOSE")
	close_btn.pressed.connect(_close_house_dialog)
	vbox.add_child(close_btn)

	_refresh_house_character_panel("")
	_refresh_house_favorite_title()
	_apply_house_skins_to_village_players()


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
	_refresh_house_character_panel("")


func _on_p1_house_char_next() -> void:
	var ids: Array[String] = _house_dialog_char_ids()
	if ids.size() <= 1:
		return
	_house_char_index = (_house_char_index + 1) % ids.size()
	_refresh_house_character_panel("")


func _refresh_house_character_panel(status: String) -> void:
	_refresh_house_favorite_title()
	var char_id: String = _house_dialog_current_char_id()
	var cdef: Dictionary = GameData.get_character_def(char_id)
	if _house_char_name_label != null:
		_house_char_name_label.text = GameData.tr_name(cdef) if not cdef.is_empty() else char_id
	_house_update_character_preview(char_id)
	_house_suppress_ui = true
	if _house_skin_option != null:
		_house_skin_option.set_block_signals(true)
		_populate_house_skin_option(char_id)
		_house_skin_option.set_block_signals(false)
	var cap: int = GameState.get_house_favorite_unlocked_slot_count()
	for i in _house_favorite_option_buttons.size():
		if i < cap:
			var opt: OptionButton = _house_favorite_option_buttons[i]
			opt.set_block_signals(true)
			_populate_house_favorite_option(opt, char_id, i)
			opt.set_block_signals(false)
	_house_suppress_ui = false
	_update_house_status_label(status, char_id)


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
	_update_house_status_label(tr("P1_HOUSE_SKIN_SAVED_FMT") % GameData.tr_character_name(char_id), char_id)
	_apply_house_skins_to_village_players()


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


func _update_house_status_label(status: String, char_id: String) -> void:
	if _house_status_label == null or not is_instance_valid(_house_status_label):
		return
	var stats: Dictionary = GameData.sum_armament_flat_stats(
		GameState.house_favorite_armament_ids_for_battle(_house_player_slot, char_id))
	var bonus_line: String = tr("P1_HOUSE_BONUS_PREVIEW_PREFIX") + GameData.format_armament_favorite_bonus_text(stats)
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
	if visual.is_empty():
		_house_preview.texture = null
		_house_preview.visible = false
		return
	# 逐幀 PNG
	if visual.has("sprite_frames") and visual["sprite_frames"] is Dictionary:
		var fdict: Dictionary = visual["sprite_frames"]
		var path: String = _house_first_frame_path(fdict.get("idle", null))
		if path != "":
			var tex: Texture2D = load(path) as Texture2D
			if tex:
				_house_set_preview_texture(tex, visual)
				return
	# 條狀圖
	if visual.has("sprite_strips") and visual["sprite_strips"] is Dictionary:
		var strips: Dictionary = visual["sprite_strips"]
		var strip_key: String = String(visual.get("preview_strip", "idle"))
		if not strips.has(strip_key):
			strip_key = "idle"
		if strips.has(strip_key):
			var atlas: Texture2D = load(String(strips[strip_key])) as Texture2D
			if atlas:
				var hf: int = maxi(1, int(visual.get("strip_hframes", 8)))
				if visual.has("strip_hframes_by_strip") and visual["strip_hframes_by_strip"] is Dictionary \
						and (visual["strip_hframes_by_strip"] as Dictionary).has(strip_key):
					hf = maxi(1, int((visual["strip_hframes_by_strip"] as Dictionary)[strip_key]))
				var fw: int = maxi(1, atlas.get_width() / hf)
				var fh: int = maxi(1, atlas.get_height())
				var at := AtlasTexture.new()
				at.atlas = atlas
				at.region = Rect2(0, 0, fw, fh)
				_house_set_preview_texture(at, visual)
				return
	_house_preview.texture = null
	_house_preview.visible = false


func _house_set_preview_texture(tex: Texture2D, cdef: Dictionary) -> void:
	_house_preview.texture = tex
	_house_preview.modulate = cdef.get("tint", Color.WHITE)
	_house_preview.flip_h = bool(cdef.get("sprite_faces_left", false))
	_house_preview.visible = true


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


func _close_house_dialog() -> void:
	if _house_dialog != null and is_instance_valid(_house_dialog):
		_house_dialog.queue_free()
	_house_dialog = null
	_house_status_label = null
	_house_preview = null
	_house_char_name_label = null
	_house_skin_option = null
	_house_fav_title = null
	_house_fav_grid = null
	_house_favorite_option_buttons.clear()
	_house_suppress_ui = false
	get_tree().paused = false


func _players_near_node(node: Node2D, radius: float) -> bool:
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
	var panel_w: float = min(760.0, vp.x - 40.0)
	var panel_h: float = min(520.0, vp.y - 40.0)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
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

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	vbox.add_child(header)

	var portrait := Panel.new()
	portrait.custom_minimum_size = Vector2(96, 96)
	header.add_child(portrait)
	var portrait_label := Label.new()
	portrait_label.text = tr("VILLAGE_BLACKSMITH_NAME")
	portrait_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait_label.add_theme_font_size_override("font_size", 18)
	portrait.add_child(portrait_label)

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
	_smith_gold_label = Label.new()
	_smith_gold_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	talk_box.add_child(_smith_gold_label)

	_smith_status_label = Label.new()
	_smith_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_smith_status_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	vbox.add_child(_smith_status_label)

	var goods := VBoxContainer.new()
	goods.add_theme_constant_override("separation", 8)
	vbox.add_child(goods)
	_add_blacksmith_goods(goods)

	var close_btn := Button.new()
	close_btn.text = tr("BLACKSMITH_CLOSE")
	close_btn.custom_minimum_size = Vector2(220, 46)
	close_btn.pressed.connect(_close_blacksmith_dialog)
	vbox.add_child(close_btn)
	close_btn.grab_focus()
	_refresh_blacksmith_dialog("")


func _add_blacksmith_goods(goods: VBoxContainer) -> void:
	var slot_btn := Button.new()
	slot_btn.name = "SlotButton"
	slot_btn.pressed.connect(_buy_blacksmith_slot)
	goods.add_child(slot_btn)
	var fav_slot_btn := Button.new()
	fav_slot_btn.name = "FavoriteSlotButton"
	fav_slot_btn.pressed.connect(_buy_blacksmith_favorite_slot)
	goods.add_child(fav_slot_btn)
	var weapon_btn := Button.new()
	weapon_btn.name = "WeaponKindButton"
	weapon_btn.pressed.connect(_buy_blacksmith_weapon_kind)
	goods.add_child(weapon_btn)
	for weapon_id in GameState.BLACKSMITH_CRAFT_WEAPON_IDS:
		var weapon_craft_btn := Button.new()
		weapon_craft_btn.name = "WeaponCraft_" + weapon_id
		weapon_craft_btn.pressed.connect(_craft_blacksmith_weapon_kind.bind(weapon_id))
		goods.add_child(weapon_craft_btn)
	for arm_id in GameData.blacksmith_armament_ids():
		var btn := Button.new()
		btn.name = "Armament_" + arm_id
		btn.pressed.connect(_buy_blacksmith_armament.bind(arm_id))
		goods.add_child(btn)


func _refresh_blacksmith_dialog(status: String) -> void:
	if _blacksmith_dialog == null:
		return
	if _smith_gold_label:
		_smith_gold_label.text = tr("BLACKSMITH_GOLD_FMT") % GameState.gold
	if _smith_status_label:
		_smith_status_label.text = status
	var goods: Array = _blacksmith_dialog.find_children("*", "Button", true, false)
	for n in goods:
		var btn: Button = n as Button
		if btn == null:
			continue
		match String(btn.name):
			"SlotButton":
				var cost: int = GameState.next_weapon_slot_unlock_cost()
				btn.disabled = cost < 0 or GameState.gold < cost
				btn.text = tr("BLACKSMITH_BUY_SLOT_DONE") if cost < 0 \
					else tr("BLACKSMITH_BUY_SLOT_FMT") % [GameState.get_unlocked_weapon_slot_count() + 1, cost]
			"FavoriteSlotButton":
				var fc: int = GameState.next_house_favorite_slot_unlock_cost()
				var nxt: int = GameState.get_house_favorite_unlocked_slot_count() + 1
				btn.disabled = fc < 0 or GameState.gold < fc
				btn.text = tr("BLACKSMITH_BUY_FAVORITE_SLOT_DONE") if fc < 0 \
					else tr("BLACKSMITH_BUY_FAVORITE_SLOT_FMT") % [nxt, fc]
			"WeaponKindButton":
				var wid: String = GameState.next_locked_weapon_id()
				btn.disabled = wid == "" or GameState.gold < GameState.BLACKSMITH_WEAPON_KIND_COST
				btn.text = tr("BLACKSMITH_BUY_WEAPON_DONE") if wid == "" \
					else tr("BLACKSMITH_BUY_WEAPON_FMT") % [
						GameData.tr_weapon_name(wid), GameState.BLACKSMITH_WEAPON_KIND_COST]
			_:
				if String(btn.name).begins_with("WeaponCraft_"):
					var craft_weapon_id: String = String(btn.name).replace("WeaponCraft_", "")
					var wdef: Dictionary = GameData.get_weapon_def(craft_weapon_id)
					var weapon_owned: bool = GameState.is_weapon_unlocked(craft_weapon_id)
					var weapon_cost_text: String = _format_weapon_craft_cost(craft_weapon_id)
					btn.disabled = weapon_owned or not GameState.can_craft_weapon_kind(craft_weapon_id)
					btn.text = tr("BLACKSMITH_CRAFT_WEAPON_DONE_FMT") % GameData.tr_name(wdef) if weapon_owned \
						else tr("BLACKSMITH_CRAFT_WEAPON_FMT") % [
							GameData.tr_name(wdef), weapon_cost_text]
				elif String(btn.name).begins_with("Armament_"):
					var arm_id: String = String(btn.name).replace("Armament_", "")
					var adef: Dictionary = GameData.get_armament_def(arm_id)
					var owned: bool = GameState.is_armament_unlocked(arm_id)
					var has_recipe: bool = GameState.has_armament_recipe(arm_id)
					var cost_text: String = _format_armament_craft_cost(arm_id)
					btn.visible = not GameData.armament_requires_craft_book(arm_id) or has_recipe or owned
					if GameData.armament_requires_craft_book(arm_id) and not has_recipe and not owned:
						btn.disabled = true
						btn.text = tr("BLACKSMITH_CRAFT_ARMAMENT_LOCKED_FMT") % GameData.tr_name(adef)
					else:
						btn.disabled = owned or not GameState.can_craft_armament(arm_id)
						btn.text = tr("BLACKSMITH_CRAFT_ARMAMENT_DONE_FMT") % GameData.tr_name(adef) if owned \
							else tr("BLACKSMITH_CRAFT_ARMAMENT_FMT") % [
								GameData.tr_name(adef), cost_text,
								GameData.tr_armament_desc_with_flat_stats(arm_id)]


func _format_weapon_craft_cost(weapon_id: String) -> String:
	var parts: Array[String] = []
	var gold_cost: int = GameState.weapon_gold_cost(weapon_id)
	if gold_cost > 0:
		parts.append(tr("BLACKSMITH_COST_GOLD_FMT") % gold_cost)
	for material_id in GameState.weapon_material_costs(weapon_id).keys():
		var mid: String = String(material_id)
		var need: int = int(GameState.weapon_material_costs(weapon_id)[material_id])
		var have: int = GameState.get_material_amount(mid)
		parts.append(tr("BLACKSMITH_COST_MATERIAL_FMT") % [
			GameData.tr_material_name(mid), have, need])
	return " + ".join(parts)


func _format_armament_craft_cost(arm_id: String) -> String:
	var parts: Array[String] = []
	var gold_cost: int = GameState.armament_gold_cost(arm_id)
	if gold_cost > 0:
		parts.append(tr("BLACKSMITH_COST_GOLD_FMT") % gold_cost)
	for material_id in GameState.armament_material_costs(arm_id).keys():
		var mid: String = String(material_id)
		var need: int = int(GameState.armament_material_costs(arm_id)[material_id])
		var have: int = GameState.get_material_amount(mid)
		parts.append(tr("BLACKSMITH_COST_MATERIAL_FMT") % [
			GameData.tr_material_name(mid), have, need])
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
	Coop.clamp_camera_position(camera, MAP_SIZE, vp_size)


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
