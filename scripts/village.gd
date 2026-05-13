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
var _blacksmith_dialog: CanvasLayer = null
var _smith_status_label: Label = null
var _smith_gold_label: Label = null


func _ready() -> void:
	# 自身永遠處理（讓暫停時 ESC 仍能被偵測）；玩家會被個別設為 PAUSABLE
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera.make_current()
	_spawn_map()
	_spawn_blacksmith_if_rescued()
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


func _process(_delta: float) -> void:
	if _transitioning:
		return
	if Input.is_action_just_pressed("ui_back"):
		if _blacksmith_dialog != null:
			_close_blacksmith_dialog()
			return
		if _pause_open:
			_close_pause()
		else:
			_open_pause()
		return
	_update_blacksmith_interaction()
	_position_camera()


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


func _update_blacksmith_interaction() -> void:
	if _pause_open or _blacksmith_dialog != null or _blacksmith_node == null or not is_instance_valid(_blacksmith_node):
		return
	var near: bool = false
	for p in players:
		if p != null and is_instance_valid(p) \
				and p.global_position.distance_to(_blacksmith_node.global_position) <= BLACKSMITH_INTERACT_RADIUS:
			near = true
			break
	if near:
		hint_label.text = tr("VILLAGE_BLACKSMITH_INTERACT_HINT")
		if Input.is_action_just_pressed("p1_action") or Input.is_action_just_pressed("p2_action") \
				or Input.is_action_just_pressed("ui_accept"):
			_open_blacksmith_dialog()
	else:
		hint_label.text = tr("VILLAGE_HINT")


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
	for arm_id in ["iron_sword", "hunter_bow"]:
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
				if String(btn.name).begins_with("Armament_"):
					var arm_id: String = String(btn.name).replace("Armament_", "")
					var adef: Dictionary = GameData.get_armament_def(arm_id)
					var owned: bool = GameState.is_armament_unlocked(arm_id)
					btn.disabled = owned or GameState.gold < GameState.BLACKSMITH_ARMAMENT_COST
					btn.text = tr("BLACKSMITH_CRAFT_ARMAMENT_DONE_FMT") % GameData.tr_name(adef) if owned \
						else tr("BLACKSMITH_CRAFT_ARMAMENT_FMT") % [
							GameData.tr_name(adef), GameState.BLACKSMITH_ARMAMENT_COST,
							GameData.tr_desc(adef)]


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


func _buy_blacksmith_armament(arm_id: String) -> void:
	var adef: Dictionary = GameData.get_armament_def(arm_id)
	if GameState.buy_armament(arm_id):
		_refresh_blacksmith_dialog(tr("BLACKSMITH_CRAFTED_ARMAMENT_FMT") % GameData.tr_name(adef))
	else:
		_refresh_blacksmith_dialog(tr("BLACKSMITH_NOT_ENOUGH_GOLD"))


func _close_blacksmith_dialog() -> void:
	if _blacksmith_dialog != null and is_instance_valid(_blacksmith_dialog):
		_blacksmith_dialog.queue_free()
	_blacksmith_dialog = null
	_smith_status_label = null
	_smith_gold_label = null
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
