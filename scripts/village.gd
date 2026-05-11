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


func _ready() -> void:
	# 自身永遠處理（讓暫停時 ESC 仍能被偵測）；玩家會被個別設為 PAUSABLE
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera.make_current()
	_spawn_map()
	_spawn_players()
	_position_camera()
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
		if _pause_open:
			_close_pause()
		else:
			_open_pause()
		return
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


# ---------------- 玩家 ----------------
func _spawn_players() -> void:
	# 玩家中心放在地面 BODY_RADIUS 上方，腳剛好踩在 floor_y
	var body_r: float = 30.0   # 跟 Player.BODY_RADIUS 對齊
	var feet_x: float = spawn_origin.x
	var center_y: float = floor_y - body_r

	var p1 = PLAYER_SCENE.instantiate()
	p1.input_prefix = "p1"
	p1.slot_index = 0
	p1.village_mode = true
	p1.process_mode = Node.PROCESS_MODE_PAUSABLE
	p1.position = Vector2(feet_x - 30.0, center_y)
	add_child(p1)
	p1.setup_from_character(GameState.p1_character)
	players.append(p1)

	if GameState.two_players:
		var p2 = PLAYER_SCENE.instantiate()
		p2.input_prefix = "p2"
		p2.slot_index = 1
		p2.village_mode = true
		p2.process_mode = Node.PROCESS_MODE_PAUSABLE
		p2.position = Vector2(feet_x + 30.0, center_y)
		add_child(p2)
		p2.setup_from_character(GameState.p2_character)
		players.append(p2)


func _position_camera() -> void:
	if players.is_empty():
		return
	var center := Vector2.ZERO
	var alive: int = 0
	for p in players:
		if p.hp > 0:
			center += p.global_position
			alive += 1
	if alive > 0:
		center /= alive
	camera.global_position = center


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
