extends Node2D
## 村莊場景：載入 Village.tmx，玩家可自由走動，無敵人、無武器。
## ESC 開啟離開村莊選單。

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const MAP_PATH := "res://assets/Maps/Village.tmx"
# Village.tmx 是 200×20 tiles（16px）：3200×320。為了視覺與角色比例放大 1.5 倍。
const MAP_RAW_SIZE := Vector2(3200.0, 320.0)
const MAP_SCALE := 1.5
const MAP_SIZE := Vector2(4800.0, 480.0)
const CAMERA_ZOOM := Vector2(2.0, 2.0)
const BLACKSMITH_INTERACT_RADIUS := 90.0
const MERCHANT_INTERACT_RADIUS := 90.0
const P1_HOUSE_INTERACT_RADIUS := 100.0
const VILLAGE_TOUCH_BTN_SIZE := Vector2(78.0, 56.0)

const Coop := preload("res://scripts/coop_pair_follow.gd")
const CoopPointerOverlay := preload("res://scripts/coop_pointer_overlay.gd")

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
var _house_favorite_option_buttons: Array[OptionButton] = []
var _merchant_status_label: Label = null
var _merchant_gold_label: Label = null
var _merchant_inventory_label: RichTextLabel = null
var _touch_controls_root: Control = null
var _touch_left_button: Button = null
var _touch_right_button: Button = null
var _touch_jump_button: Button = null
var _touch_interact_button: Button = null
var _touch_menu_button: Button = null


func _ready() -> void:
	# 自身永遠處理（讓暫停時 ESC 仍能被偵測）；玩家會被個別設為 PAUSABLE
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera.make_current()
	_spawn_map()
	_spawn_blacksmith_if_rescued()
	_spawn_merchant_if_rescued()
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
	get_viewport().size_changed.connect(_layout_village_touch_controls)


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
		if _house_dialog != null:
			_close_house_dialog()
			return
		if _pause_open:
			_close_pause()
		else:
			_open_pause()
		return
	_update_npc_interactions()
	_refresh_village_touch_visibility()
	_position_camera()


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


func _refresh_village_touch_visibility() -> void:
	if _touch_controls_root == null:
		return
	var show: bool = bool(GameState.touch_controls_enabled) and not _transitioning \
		and not _pause_open and _blacksmith_dialog == null and _merchant_dialog == null \
		and _house_dialog == null
	if _touch_controls_root.visible != show and not show:
		_release_village_touch_actions()
	_touch_controls_root.visible = show


func _release_village_touch_actions() -> void:
	for action in ["p1_left", "p1_right", "p1_up"]:
		Input.action_release(action)


func _on_touch_interact_pressed() -> void:
	if _pause_open or _blacksmith_dialog != null or _merchant_dialog != null \
			or _house_dialog != null:
		return
	if _players_near_node(_blacksmith_node, BLACKSMITH_INTERACT_RADIUS):
		_open_blacksmith_dialog()
	elif _players_near_node(_merchant_node, MERCHANT_INTERACT_RADIUS):
		_open_merchant_dialog()
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
	var entrance: Node = _find_map_object_by_name([
		"Entrance", "entrance", "ENTRANCE"])
	if entrance is Node2D:
		spawn_origin = (entrance as Node2D).global_position
	# 地面 Y 採取下面優先順序：
	#   1) 物件層名稱為 Floor / Ground / floor / ground 的物件 Y
	#   2) Buildings 群組底下所有 Sprite2D 的視覺底部最大值（建築物腳）
	#   3) Entrance 自身 Y
	#   4) MAP_SIZE.y * 0.85（保險預設）
	var floor_obj: Node = _find_map_object_by_name([
		"Floor", "floor", "Ground", "ground"])
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
	if pos.x - radius < 8.0:
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
	var slot: Node = _find_map_object_by_name([
		"smith", "Smith", "blacksmith", "Blacksmith", "BlacksmithSlot", "blacksmith_slot"])
	var pos: Vector2 = Vector2(MAP_SIZE.x * 0.62, floor_y - 42.0)
	if slot is Node2D:
		pos.x = (slot as Node2D).global_position.x
		pos.y = floor_y - 42.0
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
	var slot: Node = _find_map_object_by_name([
		"merchant", "Merchant", "shopkeeper", "Shopkeeper", "MerchantSlot", "merchant_slot"])
	var pos: Vector2 = Vector2(MAP_SIZE.x * 0.74, floor_y - 42.0)
	if slot is Node2D:
		pos.x = (slot as Node2D).global_position.x
		pos.y = floor_y - 42.0
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


func _update_npc_interactions() -> void:
	if _pause_open or _blacksmith_dialog != null or _merchant_dialog != null \
			or _house_dialog != null:
		return
	if _update_blacksmith_interaction():
		return
	if _update_merchant_interaction():
		return
	if _update_p1_house_interaction():
		return
	if _update_p2_house_interaction():
		return
	hint_label.text = tr("VILLAGE_HINT")


func _update_blacksmith_interaction() -> bool:
	if _players_near_node(_blacksmith_node, BLACKSMITH_INTERACT_RADIUS):
		hint_label.text = tr("VILLAGE_BLACKSMITH_INTERACT_HINT")
		if Input.is_action_just_pressed("p1_action") or Input.is_action_just_pressed("p2_action") \
				or Input.is_action_just_pressed("ui_accept"):
			_open_blacksmith_dialog()
		return true
	return false


func _update_merchant_interaction() -> bool:
	if _players_near_node(_merchant_node, MERCHANT_INTERACT_RADIUS):
		hint_label.text = tr("VILLAGE_MERCHANT_INTERACT_HINT")
		if Input.is_action_just_pressed("p1_action") or Input.is_action_just_pressed("p2_action") \
				or Input.is_action_just_pressed("ui_accept"):
			_open_merchant_dialog()
		return true
	return false


func _spawn_p1_house_marker() -> void:
	var slot: Node = _find_map_object_by_name(["Home1", "home1", "HouseSlot1"])
	var pos: Vector2 = Vector2(MAP_SIZE.x * 0.32, floor_y - 42.0)
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
	if not _player_near_node(_p1_house_node, P1_HOUSE_INTERACT_RADIUS, "p1"):
		return false
	hint_label.text = tr("VILLAGE_P1_HOUSE_INTERACT_HINT")
	if Input.is_action_just_pressed("p1_action") or Input.is_action_just_pressed("ui_accept"):
		_open_house_dialog("p1")
	return true


func _update_p2_house_interaction() -> bool:
	if not GameState.two_players:
		return false
	if _p2_house_node == null or not is_instance_valid(_p2_house_node):
		return false
	if not _player_near_node(_p2_house_node, P1_HOUSE_INTERACT_RADIUS, "p2"):
		return false
	hint_label.text = tr("VILLAGE_P2_HOUSE_INTERACT_HINT")
	if Input.is_action_just_pressed("p2_action"):
		_open_house_dialog("p2")
	return true


func _spawn_p2_house_marker() -> void:
	var slot: Node = _find_map_object_by_name(["Home2", "home2", "HouseSlot2"])
	var pos: Vector2 = Vector2(MAP_SIZE.x * 0.68, floor_y - 42.0)
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

	# 喜愛武裝（五格，兩欄）
	var fav_title := Label.new()
	fav_title.text = tr("P1_HOUSE_FAVORITES_TITLE")
	fav_title.add_theme_font_size_override("font_size", 15)
	vbox.add_child(fav_title)

	var fav_hint := Label.new()
	fav_hint.text = tr("HOUSE_FAVORITES_SHARED_HINT")
	fav_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fav_hint.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	fav_hint.add_theme_font_size_override("font_size", 12)
	vbox.add_child(fav_hint)

	_house_favorite_option_buttons.clear()
	var fav_grid := GridContainer.new()
	fav_grid.columns = 2
	fav_grid.add_theme_constant_override("h_separation", 10)
	fav_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(fav_grid)
	for i in GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS:
		fav_grid.add_child(_make_p1_house_favorite_row(i))

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
	_apply_house_skins_to_village_players()


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
	for i in _house_favorite_option_buttons.size():
		if i < GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS:
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
	if slot_index < 0 or slot_index >= GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS:
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
	for i in _house_favorite_option_buttons.size():
		if i != slot_index and i < GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS:
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
	# 玩家中心放在地面 body_radius 上方，腳剛好踩在 floor_y（半徑見 GameData 角色 body_radius）
	var def1: Dictionary = GameData.get_character_def(GameState.p1_character)
	if def1.is_empty():
		def1 = GameData.CHARACTERS[0]
	var body_r1: float = clampf(float(def1.get("body_radius", 42.0)), 8.0, 160.0)
	var feet_x: float = spawn_origin.x

	var p1 = PLAYER_SCENE.instantiate()
	p1.input_prefix = "p1"
	p1.slot_index = 0
	p1.village_mode = true
	p1.process_mode = Node.PROCESS_MODE_PAUSABLE
	p1.position = Vector2(feet_x - 30.0, floor_y - body_r1)
	add_child(p1)
	p1.setup_from_character(GameState.p1_character)
	players.append(p1)

	if GameState.two_players:
		var def2: Dictionary = GameData.get_character_def(GameState.p2_character)
		if def2.is_empty():
			def2 = GameData.CHARACTERS[0]
		var body_r2: float = clampf(float(def2.get("body_radius", 42.0)), 8.0, 160.0)
		var p2 = PLAYER_SCENE.instantiate()
		p2.input_prefix = "p2"
		p2.slot_index = 1
		p2.village_mode = true
		p2.process_mode = Node.PROCESS_MODE_PAUSABLE
		p2.position = Vector2(feet_x + 30.0, floor_y - body_r2)
		add_child(p2)
		p2.setup_from_character(GameState.p2_character)
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
