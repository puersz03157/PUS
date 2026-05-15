extends Node2D
## 主遊戲場景：生成玩家、敵人、相機、HUD、處理升級觸發彈珠台。

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const PINBALL_SCENE := preload("res://scenes/Pinball.tscn")

# 預設地圖（YATI 匯入的 .tmx → PackedScene）— 若關卡未指定則用這個
const DEFAULT_MAP_PATH := "res://assets/Maps/TEST.tmx"
const MAP_RAW_SIZE := Vector2(1600.0, 1600.0)   # 原始：100 tiles * 16 px
const MAP_SCALE := 1.5                          # 地圖視覺放大倍率
const MAP_SIZE := Vector2(2400.0, 2400.0)       # = MAP_RAW_SIZE * MAP_SCALE
const MAP_CENTER := Vector2(1200.0, 1200.0)
const CAMERA_ZOOM := Vector2(2.0, 2.0)

const Coop := preload("res://scripts/coop_pair_follow.gd")
const CoopPointerOverlay := preload("res://scripts/coop_pointer_overlay.gd")
const BLACKSMITH_RESCUE_RADIUS := 72.0
const BLACKSMITH_EVENT_MIN_ENEMIES := 5
const BLACKSMITH_EVENT_MAX_ENEMIES := 10
const BLACKSMITH_EVENT_SPAWN_MIN_RADIUS := 160.0
const BLACKSMITH_EVENT_SPAWN_MAX_RADIUS := 260.0
const BLACKSMITH_DODGE_DURATION := 12.0
const BLACKSMITH_DODGE_HAZARD_INTERVAL := 1.15
const BLACKSMITH_DODGE_HAZARD_RADIUS := 78.0
const BLACKSMITH_DODGE_HAZARD_WINDUP := 0.95
const BLACKSMITH_DODGE_HAZARD_TTL := 1.28
const BLACKSMITH_RUNNER_DUST_MIN := 8
const BLACKSMITH_RUNNER_DUST_MAX := 14
## 事件完成後再生成偶發標記：與上一處／玩家／畫面保持距離
const REPEAT_EVENT_MIN_DIST_FROM_LAST := 480.0
const REPEAT_EVENT_MIN_DIST_FROM_LAST_RELAXED := 300.0
const REPEAT_EVENT_MIN_DIST_FROM_PLAYER := 400.0
const REPEAT_EVENT_MIN_DIST_FROM_PLAYER_RELAXED := 260.0
const REPEAT_EVENT_CAMERA_VIEW_MARGIN := 110.0
const REPEAT_EVENT_CAMERA_VIEW_MARGIN_RELAXED := 36.0

@onready var camera: Camera2D = $Camera
@onready var spawn_timer: Timer = $SpawnTimer
@onready var hud: CanvasLayer = $HUD
@onready var hud_p1_lv: Label = $HUD/P1Panel/Lv
@onready var hud_p1_hp: ProgressBar = $HUD/P1Panel/HP
@onready var hud_p1_xp: ProgressBar = $HUD/P1Panel/XP
@onready var hud_p1_kills: Label = $HUD/P1Panel/Kills
@onready var hud_p2_panel: Control = $HUD/P2Panel
@onready var hud_p2_lv: Label = $HUD/P2Panel/Lv
@onready var hud_p2_hp: ProgressBar = $HUD/P2Panel/HP
@onready var hud_p2_xp: ProgressBar = $HUD/P2Panel/XP
@onready var hud_p2_kills: Label = $HUD/P2Panel/Kills
@onready var time_label: Label = $HUD/TimeLabel
@onready var background: DrawerNode2D = $Background
@onready var gameover_panel: Control = $HUD/GameOverPanel
@onready var gameover_label: Label = $HUD/GameOverPanel/Label
@onready var gameover_title: Label = $HUD/GameOverPanel/Title
@onready var gameover_subtitle: Label = $HUD/GameOverPanel/Subtitle
@onready var gameover_stats: RichTextLabel = $HUD/GameOverPanel/Stats
@onready var gameover_hint: Label = $HUD/GameOverPanel/Hint
@onready var stage_banner: Label = $HUD/StageBanner
@onready var boss_warning: Label = $HUD/BossWarning
@onready var boss_hp_panel: Control = $HUD/BossHPPanel
@onready var boss_hp_bar: ProgressBar = $HUD/BossHPPanel/HP
@onready var boss_hp_name: Label = $HUD/BossHPPanel/Name

const SKILL_ICON_SCRIPT := preload("res://scripts/skill_icon.gd")
const TOUCH_HUD_SCRIPT := preload("res://scripts/touch_hud.gd")
var p1_skill_icon: Panel = null
var p2_skill_icon: Panel = null
var touch_hud: CanvasLayer = null
var _coop_pointer_overlay: Control = null

var players: Array = []
var run_time: float = 0.0
var pending_levelers: Array = []
var pinball_active: bool = false
var difficulty: float = 0.0
var paused_for_pinball: bool = false
var pinball_run_destroyed_reward_keys: Array[String] = []
var pinball_judgment_destroy_count: int = 0
const PINBALL_JUDGMENT_DESTROY_LIMIT := 3

# 共用（隊伍）等級系統 — P1 / P2 共享
var team_level: int = 1
var team_xp: float = 0.0
# 起跳值較高、成長較快，避免前期 30 秒升好幾級
var team_xp_to_next: float = 8.0

# 關卡 / Boss
var stage_def: Dictionary = {}
var boss_node: Node = null
var boss_warning_shown: bool = false
var boss_spawned: bool = false
var stage_completed: bool = false
var blacksmith_rescue_node: Node2D = null
var blacksmith_event_rescues_npc: bool = false
var blacksmith_rescue_kind: String = ""
var blacksmith_rescue_event_active: bool = false
var blacksmith_rescue_event_kind: String = ""
var blacksmith_rescue_event_enemy_ids: Array[int] = []
var blacksmith_dodge_timer: float = 0.0
var blacksmith_dodge_hazard_timer: float = 0.0
var blacksmith_dodge_hazards: Array[Node2D] = []

var map_node: Node = null
var spawn_origin: Vector2 = Vector2.ZERO
var map_bounds: Rect2 = Rect2()
var tile_size: int = 16
var blocked_tiles: Dictionary = {}    # Vector2i -> true 表示不可走


func _ready() -> void:
	GameState.reset_run()
	stage_def = GameData.get_stage_def(GameState.current_stage_id)
	GameState.last_result["stage_id"] = String(stage_def.get("id", ""))
	GameState.last_result["stage_name"] = String(stage_def.get("name", ""))
	gameover_panel.visible = false
	boss_warning.visible = false
	boss_hp_panel.visible = false
	camera.make_current()
	_spawn_map()
	_spawn_players()
	_spawn_blacksmith_rescue_if_needed()
	_position_camera()
	# 雙人模式：團隊 XP 門檻 + 50%（敵人多 60%、不該因此一直升級爆 HP）
	if GameState.two_players:
		team_xp_to_next = round(team_xp_to_next * 1.5)
	spawn_timer.timeout.connect(_on_spawn_tick)
	_draw_background()
	hud_p2_panel.visible = GameState.two_players
	_show_stage_banner()
	if not _present_start_weapon_notice():
		spawn_timer.start()


func _spawn_map() -> void:
	var path: String = String(stage_def.get("map_path", DEFAULT_MAP_PATH))
	if not ResourceLoader.exists(path):
		push_warning("[Game] 找不到地圖：%s，使用空白世界。" % path)
		spawn_origin = Vector2.ZERO
		map_bounds = Rect2(-2000, -2000, 4000, 4000)
		return
	var packed: PackedScene = load(path)
	if packed == null:
		push_warning("[Game] 地圖載入失敗：%s" % path)
		return
	map_node = packed.instantiate()
	add_child(map_node)
	move_child(map_node, 0)
	if map_node is Node2D:
		(map_node as Node2D).z_index = -10
		(map_node as Node2D).scale = Vector2(MAP_SCALE, MAP_SCALE)
	if background:
		background.visible = false
	spawn_origin = MAP_CENTER
	map_bounds = Rect2(Vector2.ZERO, MAP_SIZE)
	tile_size = int(round(16.0 * MAP_SCALE))
	camera.zoom = CAMERA_ZOOM
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(MAP_SIZE.x)
	camera.limit_bottom = int(MAP_SIZE.y)
	_build_blocked_grid()


func _build_blocked_grid() -> void:
	blocked_tiles.clear()
	if map_node == null:
		return
	var layers: Array = map_node.find_children("*", "TileMapLayer", true, false)
	for n in layers:
		var layer: TileMapLayer = n as TileMapLayer
		if layer == null:
			continue
		var lname_upper: String = String(layer.name).to_upper()
		var ts: TileSet = layer.tile_set
		for cell in layer.get_used_cells():
			var src_id: int = layer.get_cell_source_id(cell)
			if src_id < 0:
				continue
			var blocked: bool = false
			# 規則 A：WATER 整層都阻擋
			if lname_upper == "WATER":
				blocked = true
			# 規則 B：依 tileset 紋理路徑判斷（水池 / 高地）
			if not blocked and ts != null:
				var src: TileSetSource = ts.get_source(src_id)
				if src is TileSetAtlasSource:
					var atlas: TileSetAtlasSource = src
					if atlas.texture:
						var path: String = atlas.texture.resource_path
						if "RockSlope" in path or "Water" in path:
							blocked = true
			if blocked:
				blocked_tiles[cell] = true
	if blocked_tiles.size() > 0:
		print("[Game] 偵測到 %d 個阻擋格 (水池/高地)" % blocked_tiles.size())


# 給 Player / Enemy 呼叫
func is_world_blocked_at(pos: Vector2, radius: float = 8.0) -> bool:
	if blocked_tiles.is_empty():
		return false
	# 取四個角的 tile，任一阻擋就視為阻擋
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


func _spawn_players() -> void:
	var p1 = PLAYER_SCENE.instantiate()
	p1.input_prefix = "p1"
	p1.slot_index = 0
	p1.position = spawn_origin + Vector2(-60, 0)
	add_child(p1)
	p1.setup_from_character(GameState.p1_character)
	p1.died.connect(_on_player_died)
	players.append(p1)

	if GameState.two_players:
		var p2 = PLAYER_SCENE.instantiate()
		p2.input_prefix = "p2"
		p2.slot_index = 1
		p2.position = spawn_origin + Vector2(60, 0)
		add_child(p2)
		p2.setup_from_character(GameState.p2_character)
		p2.died.connect(_on_player_died)
		players.append(p2)

	_sync_team_progress_to_players()
	_build_hud_skill_icons()
	_build_touch_hud()
	if GameState.two_players and players.size() >= 2:
		_coop_pointer_overlay = CoopPointerOverlay.new()
		_coop_pointer_overlay.setup(self)
		hud.add_child(_coop_pointer_overlay)


# 建立浮動搖桿 / 技能 / 暫停的觸控 HUD —— 連接到 P1
func _build_touch_hud() -> void:
	if touch_hud != null or players.is_empty():
		return
	touch_hud = TOUCH_HUD_SCRIPT.new()
	add_child(touch_hud)
	touch_hud.setup(players[0])


func _build_hud_skill_icons() -> void:
	# HUD 緊湊版：不顯示玩家標籤（位置已表明歸屬）與按鍵提示
	var p1_panel_node: Panel = $HUD/P1Panel
	p1_skill_icon = SKILL_ICON_SCRIPT.new()
	p1_skill_icon.icon_dim = 56.0
	p1_skill_icon.show_header = false
	p1_skill_icon.show_name = true
	p1_skill_icon.show_key = false
	p1_skill_icon.setup(players[0])
	hud.add_child(p1_skill_icon)
	# 放在 P1Panel 右邊
	p1_skill_icon.position = Vector2(
		p1_panel_node.offset_right + 8.0,
		p1_panel_node.offset_top)

	if GameState.two_players and players.size() >= 2:
		var p2_panel_node: Panel = $HUD/P2Panel
		p2_skill_icon = SKILL_ICON_SCRIPT.new()
		p2_skill_icon.icon_dim = 56.0
		p2_skill_icon.show_header = false
		p2_skill_icon.show_name = true
		p2_skill_icon.show_key = false
		p2_skill_icon.setup(players[1])
		hud.add_child(p2_skill_icon)
		# 放在 P2Panel 左邊
		p2_skill_icon.position = Vector2(
			p2_panel_node.offset_left - p2_skill_icon.size.x - 8.0,
			p2_panel_node.offset_top)


func _present_start_weapon_notice() -> bool:
	var lines: Array[String] = []
	for p in players:
		if p == null:
			continue
		for info in p.start_weapon_reward_log:
			lines.append(_format_start_weapon_line(p, info))
	if lines.is_empty():
		return false
	get_tree().paused = true
	BlockingNotice.present(
		get_tree(),
		tr("START_REWARD_TITLE"),
		"\n".join(lines),
		tr("START_REWARD_HINT"),
		tr("PINBALL_REWARD_OK"),
		self,
		"_start_weapon_notice_dismissed",
	)
	return true


func _start_weapon_notice_dismissed() -> void:
	get_tree().paused = false
	if not stage_completed:
		spawn_timer.start()


func _format_start_weapon_line(p: Node, info: Dictionary) -> String:
	var pname: String = tr("PINBALL_PNAME_FMT") % (int(p.slot_index) + 1)
	var source: String = tr("START_REWARD_SOURCE_CHARACTER")
	if String(info.get("source_kind", "")) == "armament":
		source = GameData.tr_armament_name(String(info.get("source_id", "")))
	elif String(info.get("source_kind", "")) == "house":
		source = tr("START_REWARD_SOURCE_HOUSE")
	match String(info.get("kind", "")):
		"house_favorites":
			var hstats: Dictionary = info.get("stats", {})
			if hstats is Dictionary and not (hstats as Dictionary).is_empty():
				return tr("START_REWARD_HOUSE_FAVORITES_FMT") % [
					pname, source, GameData.format_armament_favorite_bonus_text(hstats)]
			return tr("START_REWARD_HOUSE_FAVORITES_NONE_FMT") % [pname, source]
		"common_upgrade":
			var cid: String = String(info.get("upgrade_id", ""))
			var cdef: Dictionary = GameData.get_common_upgrade_def(cid)
			return tr("START_REWARD_COMMON_FMT") % [
				pname, source, GameData.tr_name(cdef),
				int(info.get("current", 0)), int(info.get("max", 0))]
		"weapon_new":
			var wid0: String = String(info.get("weapon_id", ""))
			var weapon_name0: String = GameData.tr_weapon_name(wid0)
			return tr("START_REWARD_WEAPON_NEW_FMT") % [pname, source, weapon_name0]
		"weapon_upgrade":
			var wid1: String = String(info.get("weapon_id", ""))
			var weapon_name1: String = GameData.tr_weapon_name(wid1)
			var udef: Dictionary = GameData.get_weapon_upgrade_def(String(info.get("upgrade_id", "")))
			return tr("START_REWARD_WEAPON_UP_FMT") % [
				pname, source, weapon_name1, GameData.tr_name(udef),
				int(info.get("current", 0)), int(info.get("max", 0))]
		"weapon_upgrade_max":
			var wid2: String = String(info.get("weapon_id", ""))
			var weapon_name2: String = GameData.tr_weapon_name(wid2)
			return tr("START_REWARD_WEAPON_MAX_FMT") % [pname, source, weapon_name2]
		_:
			return tr("START_REWARD_NOOP_FMT") % [pname, source]


func _process(delta: float) -> void:
	if stage_completed:
		_position_camera()
		return
	run_time += delta
	difficulty = _current_stage_difficulty()
	_position_camera()
	_update_blacksmith_rescue(delta)
	_update_hud()
	_update_stage_progress()
	# ESC 由 PauseMenu (PROCESS_MODE_ALWAYS) 處理


func _current_stage_difficulty() -> float:
	var seconds_per_tier: float = max(1.0, float(stage_def.get("difficulty_seconds_per_tier", 44.0)))
	var base: float = float(stage_def.get("difficulty_base", 0.0))
	var scale: float = float(stage_def.get("difficulty_scale", 1.0))
	return max(0.0, base + run_time / seconds_per_tier * scale)


# ---------------- 關卡 / Boss 流程 ----------------
func _show_stage_banner() -> void:
	var sname: String = GameData.tr_name(stage_def)
	if sname.is_empty():
		return
	stage_banner.text = sname
	stage_banner.visible = true
	stage_banner.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(stage_banner, "modulate", Color(1, 1, 1, 1), 0.6)
	tw.tween_interval(2.4)
	tw.tween_property(stage_banner, "modulate", Color(1, 1, 1, 0), 0.8)
	tw.tween_callback(func(): stage_banner.visible = false)


func _show_center_notice(text: String) -> void:
	stage_banner.text = text
	stage_banner.visible = true
	stage_banner.modulate = Color(1, 1, 1, 0)
	var tw := create_tween()
	tw.tween_property(stage_banner, "modulate", Color(1, 1, 1, 1), 0.25)
	tw.tween_interval(2.0)
	tw.tween_property(stage_banner, "modulate", Color(1, 1, 1, 0), 0.45)
	tw.tween_callback(func(): stage_banner.visible = false)


func _spawn_blacksmith_rescue_if_needed() -> void:
	var has_blacksmith_rescue: bool = bool(stage_def.get("rescue_blacksmith", false)) \
		and not bool(GameState.blacksmith_rescued)
	var has_merchant_rescue: bool = bool(stage_def.get("rescue_merchant", false)) \
		and not bool(GameState.merchant_rescued)
	var has_rescue_event: bool = bool(stage_def.get("rescue_blacksmith", false)) \
		or bool(stage_def.get("rescue_merchant", false))
	var has_random_event: bool = bool(stage_def.get("random_event", false))
	if not has_rescue_event and not has_random_event:
		return
	blacksmith_event_rescues_npc = has_blacksmith_rescue or has_merchant_rescue
	if has_blacksmith_rescue:
		blacksmith_rescue_kind = "blacksmith"
	elif has_merchant_rescue:
		blacksmith_rescue_kind = "merchant"
	else:
		blacksmith_rescue_kind = ""
	blacksmith_rescue_node = _make_blacksmith_marker(
		_blacksmith_event_title(),
		_blacksmith_event_idle_hint())
	blacksmith_rescue_node.set_meta("rescues_npc", blacksmith_event_rescues_npc)
	blacksmith_rescue_node.set_meta("rescue_kind", blacksmith_rescue_kind)
	blacksmith_rescue_node.global_position = _pick_blacksmith_rescue_position()
	add_child(blacksmith_rescue_node)


func _pick_blacksmith_rescue_position() -> Vector2:
	var center: Vector2 = spawn_origin
	var fallback: Vector2 = center + Vector2(520.0, -220.0)
	for _attempt in range(60):
		var ang: float = randf() * TAU
		var dist: float = randf_range(420.0, 920.0)
		var pos: Vector2 = center + Vector2(cos(ang), sin(ang)) * dist
		if map_bounds.size != Vector2.ZERO:
			pos.x = clamp(pos.x, map_bounds.position.x + 160.0, map_bounds.end.x - 160.0)
			pos.y = clamp(pos.y, map_bounds.position.y + 160.0, map_bounds.end.y - 160.0)
		if _is_open_rescue_position(pos):
			return pos
	return fallback


func _camera_world_view_rect() -> Rect2:
	if camera == null:
		return Rect2()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var half := Vector2(
		(vp_size.x * 0.5) / maxf(0.001, camera.zoom.x),
		(vp_size.y * 0.5) / maxf(0.001, camera.zoom.y),
	)
	return Rect2(camera.global_position - half, half * 2.0)


func _is_pos_inside_camera_view_grow(p: Vector2, grow_px: float) -> bool:
	return _camera_world_view_rect().grow(grow_px).has_point(p)


func _pick_repeat_world_event_position(exclude: Vector2) -> Vector2:
	var center: Vector2 = spawn_origin
	if map_bounds.size != Vector2.ZERO:
		center = map_bounds.get_center()
	var fallback: Vector2 = _pick_blacksmith_rescue_position()
	for phase in range(3):
		var min_from_last: float = REPEAT_EVENT_MIN_DIST_FROM_LAST
		var min_from_player: float = REPEAT_EVENT_MIN_DIST_FROM_PLAYER
		var view_margin: float = REPEAT_EVENT_CAMERA_VIEW_MARGIN
		if phase == 1:
			min_from_last = REPEAT_EVENT_MIN_DIST_FROM_LAST_RELAXED
			min_from_player = REPEAT_EVENT_MIN_DIST_FROM_PLAYER_RELAXED
			view_margin = REPEAT_EVENT_CAMERA_VIEW_MARGIN_RELAXED
		elif phase == 2:
			min_from_last = 0.0
			min_from_player = 180.0
			view_margin = 0.0
		for _attempt in range(56):
			var ang: float = randf() * TAU
			var dist: float = randf_range(420.0, 1180.0)
			var pos: Vector2 = center + Vector2(cos(ang), sin(ang)) * dist
			if map_bounds.size != Vector2.ZERO:
				pos.x = clamp(pos.x, map_bounds.position.x + 160.0, map_bounds.end.x - 160.0)
				pos.y = clamp(pos.y, map_bounds.position.y + 160.0, map_bounds.end.y - 160.0)
			if exclude != Vector2.ZERO and pos.distance_to(exclude) < min_from_last:
				continue
			if view_margin > 0.0 and _is_pos_inside_camera_view_grow(pos, view_margin):
				continue
			var too_close_player: bool = false
			for pl in players:
				if pl == null or not is_instance_valid(pl) or pl.hp <= 0:
					continue
				if pos.distance_to(pl.global_position) < min_from_player:
					too_close_player = true
					break
			if too_close_player:
				continue
			if pos.distance_to(spawn_origin) < 220.0:
				continue
			if _is_open_rescue_position(pos):
				return pos
	return fallback


func _maybe_spawn_next_world_event_marker(last_completed_pos: Vector2) -> void:
	if stage_completed:
		return
	var has_stage_events: bool = bool(stage_def.get("random_event", false)) \
		or bool(stage_def.get("rescue_blacksmith", false)) \
		or bool(stage_def.get("rescue_merchant", false))
	if not has_stage_events:
		return
	if blacksmith_rescue_node != null and is_instance_valid(blacksmith_rescue_node):
		return
	blacksmith_event_rescues_npc = false
	blacksmith_rescue_kind = ""
	blacksmith_rescue_node = _make_blacksmith_marker(
		_blacksmith_event_title(),
		_blacksmith_event_idle_hint())
	blacksmith_rescue_node.set_meta("rescues_npc", false)
	blacksmith_rescue_node.set_meta("rescue_kind", "")
	blacksmith_rescue_node.global_position = _pick_repeat_world_event_position(last_completed_pos)
	add_child(blacksmith_rescue_node)


func _is_open_rescue_position(pos: Vector2) -> bool:
	if pos.distance_to(spawn_origin) < 360.0:
		return false
	var samples := [
		Vector2.ZERO,
		Vector2(96, 0), Vector2(-96, 0), Vector2(0, 96), Vector2(0, -96),
		Vector2(72, 72), Vector2(-72, 72), Vector2(72, -72), Vector2(-72, -72),
	]
	for off in samples:
		if is_world_blocked_at(pos + off, 28.0):
			return false
	return true


func _update_blacksmith_rescue(delta: float) -> void:
	if blacksmith_rescue_node == null or not is_instance_valid(blacksmith_rescue_node):
		return
	if blacksmith_rescue_event_active:
		match blacksmith_rescue_event_kind:
			"dodge":
				_update_blacksmith_dodge_event(delta)
			_:
				_prune_blacksmith_rescue_enemies()
				if blacksmith_rescue_event_enemy_ids.is_empty():
					_complete_blacksmith_rescue_event()
		return
	for p in players:
		if p == null or not is_instance_valid(p):
			continue
		if p.hp <= 0:
			continue
		if p.global_position.distance_to(blacksmith_rescue_node.global_position) <= BLACKSMITH_RESCUE_RADIUS:
			_start_blacksmith_rescue_event()
			return


func _start_blacksmith_rescue_event() -> void:
	if blacksmith_rescue_node == null or not is_instance_valid(blacksmith_rescue_node):
		return
	blacksmith_rescue_event_active = true
	blacksmith_rescue_event_kind = _pick_blacksmith_rescue_event_kind()
	blacksmith_rescue_event_enemy_ids.clear()
	_clear_blacksmith_dodge_hazards()
	match blacksmith_rescue_event_kind:
		"dodge":
			_start_blacksmith_dodge_event()
		"runner":
			_start_blacksmith_runner_event()
		_:
			_start_blacksmith_ambush_event()


func _pick_blacksmith_rescue_event_kind() -> String:
	var kinds := ["ambush", "dodge", "runner"]
	return String(kinds[randi() % kinds.size()])


func _start_blacksmith_ambush_event() -> void:
	_set_blacksmith_marker_text(
		_blacksmith_event_title(),
		_tr_text("BLACKSMITH_AMBUSH_HINT", "擊退包圍的怪群"))
	_show_center_notice(_event_notice_text(
		"BLACKSMITH_AMBUSH_NOTICE",
		"BLACKSMITH_INCIDENT_AMBUSH_NOTICE",
		"鐵匠被怪群包圍！擊退敵人才能解救。",
		"附近出現怪群騷動！擊退敵人完成偶發事件。"))
	var center: Vector2 = blacksmith_rescue_node.global_position
	var alive_count: int = 0
	for p in players:
		if p != null and is_instance_valid(p) and p.hp > 0:
			alive_count += 1
	var count: int = clampi(
		BLACKSMITH_EVENT_MIN_ENEMIES + maxi(0, alive_count - 1) * 2 + int(floor(difficulty * 0.35)),
		BLACKSMITH_EVENT_MIN_ENEMIES,
		BLACKSMITH_EVENT_MAX_ENEMIES)
	var event_bonus: float = float(stage_def.get("event_difficulty_bonus", 1.0))
	var event_difficulty: float = max(1.0, difficulty + event_bonus)
	for i in range(count):
		_spawn_blacksmith_event_enemy(center, i, count, event_difficulty)
	_update_blacksmith_event_progress()


func _start_blacksmith_runner_event() -> void:
	var dust_amount: int = randi_range(BLACKSMITH_RUNNER_DUST_MIN, BLACKSMITH_RUNNER_DUST_MAX)
	_set_blacksmith_marker_text(
		_blacksmith_event_title(),
		_tr_text("BLACKSMITH_RUNNER_HINT", "追擊逃跑的稀有怪"))
	_show_center_notice(_tr_text("BLACKSMITH_RUNNER_NOTICE", "稀有怪趁亂逃跑！擊敗牠可取得符文粉塵。"))
	var e = ENEMY_SCENE.instantiate()
	e.global_position = _pick_blacksmith_event_spawn_position(blacksmith_rescue_node.global_position, 0, 1)
	add_child(e)
	var event_bonus: float = float(stage_def.get("event_difficulty_bonus", 1.0))
	var event_difficulty: float = max(1.0, difficulty + event_bonus)
	if e.has_method("setup_rescue_runner"):
		e.setup_rescue_runner(event_difficulty, dust_amount)
	else:
		e.setup(event_difficulty)
	var eid: int = e.get_instance_id()
	blacksmith_rescue_event_enemy_ids.append(eid)
	e.tree_exited.connect(_on_blacksmith_rescue_enemy_removed.bind(eid))
	_update_blacksmith_event_progress()


func _start_blacksmith_dodge_event() -> void:
	blacksmith_dodge_timer = BLACKSMITH_DODGE_DURATION
	blacksmith_dodge_hazard_timer = 0.25
	_set_blacksmith_marker_text(
		_blacksmith_event_title(),
		_tr_text("BLACKSMITH_DODGE_HINT", "撐過危險區域"))
	_show_center_notice(_event_notice_text(
		"BLACKSMITH_DODGE_NOTICE",
		"BLACKSMITH_INCIDENT_DODGE_NOTICE",
		"地面開始崩裂！閃避危險區域直到鐵匠脫困。",
		"地面開始崩裂！閃避危險區域完成偶發事件。"))
	_update_blacksmith_dodge_progress()


func _spawn_blacksmith_event_enemy(center: Vector2, index: int, count: int, event_difficulty: float) -> void:
	var pool_id: String = String(stage_def.get("enemy_pool", "slime"))
	var def: Dictionary = GameData.pick_enemy_from_pool(pool_id, event_difficulty)
	var e = ENEMY_SCENE.instantiate()
	e.global_position = _pick_blacksmith_event_spawn_position(center, index, count)
	add_child(e)
	e.setup_with_slime(def, event_difficulty)
	_configure_stage_ranged_enemy(e)
	var eid: int = e.get_instance_id()
	blacksmith_rescue_event_enemy_ids.append(eid)
	e.tree_exited.connect(_on_blacksmith_rescue_enemy_removed.bind(eid))


func _pick_blacksmith_event_spawn_position(center: Vector2, index: int, count: int) -> Vector2:
	for attempt in range(10):
		var spread: float = TAU * float(index) / max(1.0, float(count))
		var ang: float = spread + randf_range(-0.32, 0.32) + float(attempt) * 0.37
		var dist: float = randf_range(BLACKSMITH_EVENT_SPAWN_MIN_RADIUS, BLACKSMITH_EVENT_SPAWN_MAX_RADIUS)
		var pos: Vector2 = center + Vector2(cos(ang), sin(ang)) * dist
		if map_bounds.size != Vector2.ZERO:
			pos.x = clamp(pos.x, map_bounds.position.x + 40.0, map_bounds.end.x - 40.0)
			pos.y = clamp(pos.y, map_bounds.position.y + 40.0, map_bounds.end.y - 40.0)
		if not is_world_blocked_at(pos, 28.0):
			return pos
	return _random_spawn_position(center)


func _on_blacksmith_rescue_enemy_removed(enemy_id: int) -> void:
	blacksmith_rescue_event_enemy_ids.erase(enemy_id)
	if blacksmith_rescue_event_active:
		_update_blacksmith_event_progress()
		if blacksmith_rescue_event_enemy_ids.is_empty():
			_complete_blacksmith_rescue_event()


func _prune_blacksmith_rescue_enemies() -> void:
	for i in range(blacksmith_rescue_event_enemy_ids.size() - 1, -1, -1):
		if instance_from_id(blacksmith_rescue_event_enemy_ids[i]) == null:
			blacksmith_rescue_event_enemy_ids.remove_at(i)


func _update_blacksmith_event_progress() -> void:
	if not blacksmith_rescue_event_active:
		return
	var left: int = blacksmith_rescue_event_enemy_ids.size()
	var progress_key: String = "BLACKSMITH_EVENT_PROGRESS_FMT"
	var fallback: String = "救援中：剩餘 %d 隻怪物"
	if not blacksmith_event_rescues_npc:
		progress_key = "RANDOM_EVENT_PROGRESS_FMT"
		fallback = "事件中：剩餘 %d 隻怪物"
	if blacksmith_rescue_event_kind == "runner":
		progress_key = "BLACKSMITH_RUNNER_PROGRESS_FMT"
		fallback = "追擊中：稀有怪剩餘 %d 隻"
	_set_blacksmith_marker_text(
		_blacksmith_event_title(),
		_tr_text(progress_key, fallback) % left)


func _update_blacksmith_dodge_event(delta: float) -> void:
	blacksmith_dodge_timer = max(0.0, blacksmith_dodge_timer - delta)
	blacksmith_dodge_hazard_timer -= delta
	if blacksmith_dodge_hazard_timer <= 0.0:
		blacksmith_dodge_hazard_timer = BLACKSMITH_DODGE_HAZARD_INTERVAL
		_spawn_blacksmith_dodge_hazard()
	_update_blacksmith_dodge_hazards(delta)
	_update_blacksmith_dodge_progress()
	if blacksmith_dodge_timer <= 0.0:
		_complete_blacksmith_rescue_event()


func _spawn_blacksmith_dodge_hazard() -> void:
	var pos: Vector2 = blacksmith_rescue_node.global_position
	var candidates: Array[Node2D] = []
	for p in players:
		if p != null and is_instance_valid(p) and p.hp > 0:
			candidates.append(p as Node2D)
	if not candidates.is_empty() and randf() < 0.75:
		var target: Node2D = candidates[randi() % candidates.size()]
		pos = target.global_position + Vector2(randf_range(-55.0, 55.0), randf_range(-55.0, 55.0))
	else:
		var ang: float = randf() * TAU
		pos += Vector2(cos(ang), sin(ang)) * randf_range(80.0, 220.0)
	if map_bounds.size != Vector2.ZERO:
		pos.x = clamp(pos.x, map_bounds.position.x + 40.0, map_bounds.end.x - 40.0)
		pos.y = clamp(pos.y, map_bounds.position.y + 40.0, map_bounds.end.y - 40.0)
	var hazard := DrawerNode2D.new()
	hazard.z_index = 9
	hazard.fn = Callable(self, "_draw_blacksmith_dodge_hazard")
	hazard.global_position = pos
	hazard.set_meta("radius", BLACKSMITH_DODGE_HAZARD_RADIUS)
	hazard.set_meta("age", 0.0)
	hazard.set_meta("hit_done", false)
	add_child(hazard)
	blacksmith_dodge_hazards.append(hazard)


func _update_blacksmith_dodge_hazards(delta: float) -> void:
	for i in range(blacksmith_dodge_hazards.size() - 1, -1, -1):
		var hazard: Node2D = blacksmith_dodge_hazards[i]
		if hazard == null or not is_instance_valid(hazard):
			blacksmith_dodge_hazards.remove_at(i)
			continue
		var age: float = float(hazard.get_meta("age", 0.0)) + delta
		hazard.set_meta("age", age)
		if age >= BLACKSMITH_DODGE_HAZARD_WINDUP and not bool(hazard.get_meta("hit_done", false)):
			hazard.set_meta("hit_done", true)
			_trigger_blacksmith_dodge_hazard(hazard)
		if age >= BLACKSMITH_DODGE_HAZARD_TTL:
			hazard.queue_free()
			blacksmith_dodge_hazards.remove_at(i)
		else:
			hazard.queue_redraw()


func _trigger_blacksmith_dodge_hazard(hazard: Node2D) -> void:
	var radius: float = float(hazard.get_meta("radius", BLACKSMITH_DODGE_HAZARD_RADIUS))
	var dmg: float = 12.0 + difficulty * 1.4
	for p in players:
		if p == null or not is_instance_valid(p) or p.hp <= 0:
			continue
		if p.global_position.distance_to(hazard.global_position) <= radius:
			p.take_damage(dmg)


func _update_blacksmith_dodge_progress() -> void:
	_set_blacksmith_marker_text(
		_blacksmith_event_title(),
		_tr_text("BLACKSMITH_DODGE_PROGRESS_FMT", "閃避中：剩餘 %d 秒") % int(ceil(blacksmith_dodge_timer)))


func _draw_blacksmith_dodge_hazard(node: Node2D) -> void:
	var radius: float = float(node.get_meta("radius", BLACKSMITH_DODGE_HAZARD_RADIUS))
	var age: float = float(node.get_meta("age", 0.0))
	var ready_pct: float = clampf(age / BLACKSMITH_DODGE_HAZARD_WINDUP, 0.0, 1.0)
	var col := Color(1.0, 0.25, 0.12, 0.18 + ready_pct * 0.28)
	if bool(node.get_meta("hit_done", false)):
		col = Color(1.0, 0.55, 0.1, 0.28)
	node.draw_circle(Vector2.ZERO, radius, col)
	node.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1.0, 0.3, 0.15, 0.85), 3.0)
	node.draw_arc(Vector2.ZERO, radius * ready_pct, 0.0, TAU, 48, Color(1.0, 0.9, 0.35, 0.8), 2.0)


func _clear_blacksmith_dodge_hazards() -> void:
	for hazard in blacksmith_dodge_hazards:
		if hazard != null and is_instance_valid(hazard):
			hazard.queue_free()
	blacksmith_dodge_hazards.clear()


func _complete_blacksmith_rescue_event() -> void:
	if not blacksmith_rescue_event_active:
		return
	var last_marker_pos: Vector2 = Vector2.ZERO
	if blacksmith_rescue_node != null and is_instance_valid(blacksmith_rescue_node):
		last_marker_pos = blacksmith_rescue_node.global_position
	var completed_event_kind: String = blacksmith_rescue_event_kind
	blacksmith_rescue_event_active = false
	blacksmith_rescue_event_kind = ""
	blacksmith_rescue_event_enemy_ids.clear()
	_clear_blacksmith_dodge_hazards()
	if blacksmith_event_rescues_npc:
		if blacksmith_rescue_kind == "merchant":
			_rescue_merchant()
		else:
			_rescue_blacksmith()
	else:
		_complete_incident_event()
	if completed_event_kind != "runner":
		_grant_event_material_pack()
	_maybe_spawn_next_world_event_marker(last_marker_pos)


func _rescue_blacksmith() -> void:
	GameState.rescue_blacksmith()
	if blacksmith_rescue_node != null and is_instance_valid(blacksmith_rescue_node):
		blacksmith_rescue_node.queue_free()
	blacksmith_rescue_node = null
	_show_center_notice(_tr_text("BLACKSMITH_RESCUED_NOTICE", "鐵匠已獲救！回村莊看看吧。"))


func _rescue_merchant() -> void:
	GameState.rescue_merchant()
	if blacksmith_rescue_node != null and is_instance_valid(blacksmith_rescue_node):
		blacksmith_rescue_node.queue_free()
	blacksmith_rescue_node = null
	_show_center_notice(_tr_text("MERCHANT_RESCUED_NOTICE", "雜貨商已獲救！回村莊看看吧。"))


func _complete_incident_event() -> void:
	if blacksmith_rescue_node != null and is_instance_valid(blacksmith_rescue_node):
		blacksmith_rescue_node.queue_free()
	blacksmith_rescue_node = null
	_grant_stage_event_armament_book()
	_show_center_notice(_tr_text("BLACKSMITH_INCIDENT_DONE_NOTICE", "偶發事件已完成！"))


func _grant_stage_event_armament_book() -> void:
	var stage_id: String = String(stage_def.get("id", ""))
	var pool: Array[String] = GameData.stage_event_armament_book_ids(stage_id)
	if pool.is_empty():
		return
	var candidates: Array[String] = []
	for aid in pool:
		if not GameState.has_armament_recipe(aid):
			candidates.append(aid)
	if candidates.is_empty():
		return
	var picked: String = candidates.pick_random()
	if GameState.unlock_armament_recipe(picked):
		_show_center_notice(tr("EVENT_ARMAMENT_BOOK_NOTICE_FMT") % GameData.tr_armament_name(picked))


func _grant_event_material_pack() -> void:
	var drops: Array = stage_def.get("material_drops", [])
	if drops.is_empty():
		return
	var valid_drops: Array[Dictionary] = []
	for drop in drops:
		if not (drop is Dictionary):
			continue
		var id: String = String(drop.get("id", ""))
		if id != "" and not GameData.get_material_def(id).is_empty():
			valid_drops.append(drop)
	if valid_drops.is_empty():
		return
	var picked: Dictionary = valid_drops.pick_random()
	var material_id: String = String(picked.get("id", ""))
	var amount: int = randi_range(3, 6)
	if GameState.grant_material(material_id, amount):
		_show_center_notice(tr("EVENT_MATERIAL_PACK_NOTICE_FMT") % [
			GameData.tr_material_name(material_id), amount])


func _make_blacksmith_marker(title: String, hint: String) -> Node2D:
	var root := Node2D.new()
	root.name = "BlacksmithRescue"
	root.z_index = 8
	var draw := DrawerNode2D.new()
	draw.fn = Callable(self, "_draw_blacksmith_marker")
	root.add_child(draw)
	var label := Label.new()
	label.name = "InfoLabel"
	label.text = "%s\n%s" % [title, hint]
	label.position = Vector2(-120, -88)
	label.size = Vector2(240, 48)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	root.add_child(label)
	return root


func _set_blacksmith_marker_text(title: String, hint: String) -> void:
	if blacksmith_rescue_node == null or not is_instance_valid(blacksmith_rescue_node):
		return
	var label := blacksmith_rescue_node.get_node_or_null("InfoLabel") as Label
	if label != null:
		label.text = "%s\n%s" % [title, hint]


func _blacksmith_event_title() -> String:
	if blacksmith_event_rescues_npc:
		if blacksmith_rescue_kind == "merchant":
			return _tr_text("MERCHANT_RESCUE_NAME", "被困的雜貨商")
		return _tr_text("BLACKSMITH_RESCUE_NAME", "被困的鐵匠")
	return _tr_text("RANDOM_EVENT_NAME", "偶發事件")


func _blacksmith_event_idle_hint() -> String:
	if blacksmith_event_rescues_npc:
		if blacksmith_rescue_kind == "merchant":
			return _tr_text("MERCHANT_RESCUE_HINT", "靠近觸發救援事件")
		return _tr_text("BLACKSMITH_RESCUE_HINT", "靠近觸發救援事件")
	return _tr_text("RANDOM_EVENT_HINT", "靠近觸發偶發事件")


func _event_notice_text(
		rescue_key: String, incident_key: String, rescue_fallback: String, incident_fallback: String) -> String:
	if blacksmith_event_rescues_npc:
		return _tr_text(rescue_key, rescue_fallback)
	return _tr_text(incident_key, incident_fallback)


func _tr_text(key: String, fallback: String) -> String:
	var text: String = tr(key)
	return fallback if text == key or text == "" else text


func _draw_blacksmith_marker(node: Node2D) -> void:
	if not bool(node.get_meta("rescues_npc", true)):
		node.draw_circle(Vector2.ZERO, BLACKSMITH_RESCUE_RADIUS, Color(0.55, 0.35, 1.0, 0.12))
		node.draw_arc(Vector2.ZERO, BLACKSMITH_RESCUE_RADIUS, 0.0, TAU, 48, Color(0.75, 0.55, 1.0, 0.70), 2.0)
		node.draw_circle(Vector2.ZERO, 24.0, Color(0.25, 0.18, 0.42, 0.95))
		node.draw_arc(Vector2.ZERO, 32.0, -0.4, TAU - 0.4, 36, Color(1.0, 0.9, 0.45, 0.9), 3.0)
		node.draw_string(ThemeDB.fallback_font, Vector2(-5, 9), "!",
			HORIZONTAL_ALIGNMENT_CENTER, 10, 26, Color(1.0, 0.9, 0.45))
		return
	if String(node.get_meta("rescue_kind", "blacksmith")) == "merchant":
		node.draw_circle(Vector2.ZERO, BLACKSMITH_RESCUE_RADIUS, Color(0.35, 0.85, 1.0, 0.12))
		node.draw_arc(Vector2.ZERO, BLACKSMITH_RESCUE_RADIUS, 0.0, TAU, 48, Color(0.45, 0.9, 1.0, 0.70), 2.0)
		node.draw_circle(Vector2(0, -20), 14.0, Color(0.95, 0.76, 0.55))
		node.draw_rect(Rect2(-18, -5, 36, 38), Color(0.25, 0.36, 0.42))
		node.draw_rect(Rect2(-28, 8, 56, 24), Color(0.55, 0.32, 0.16))
		node.draw_string(ThemeDB.fallback_font, Vector2(-7, 8), "$",
			HORIZONTAL_ALIGNMENT_CENTER, 14, 22, Color(1.0, 0.92, 0.45))
		return
	node.draw_circle(Vector2.ZERO, BLACKSMITH_RESCUE_RADIUS, Color(1.0, 0.82, 0.22, 0.12))
	node.draw_arc(Vector2.ZERO, BLACKSMITH_RESCUE_RADIUS, 0.0, TAU, 48, Color(1.0, 0.82, 0.22, 0.65), 2.0)
	node.draw_circle(Vector2(0, -20), 15.0, Color(0.95, 0.72, 0.48))
	node.draw_rect(Rect2(-16, -5, 32, 38), Color(0.28, 0.30, 0.36))
	node.draw_rect(Rect2(-24, -2, 48, 10), Color(0.72, 0.62, 0.44))
	node.draw_line(Vector2(18, 0), Vector2(44, -24), Color(0.74, 0.52, 0.32), 5.0)
	node.draw_rect(Rect2(38, -34, 22, 12), Color(0.70, 0.72, 0.76))


func _update_stage_progress() -> void:
	if stage_def.is_empty() or stage_completed:
		return
	var boss_time: float = float(stage_def.get("boss_time", 600.0))
	var warn_time: float = max(0.0, boss_time - float(stage_def.get("boss_warning_time", 30.0)))

	if not boss_warning_shown and run_time >= warn_time and run_time < boss_time:
		boss_warning_shown = true
		_show_boss_warning()

	if not boss_spawned and run_time >= boss_time:
		boss_spawned = true
		_spawn_stage_boss()

	if is_instance_valid(boss_node) and boss_hp_panel.visible:
		boss_hp_bar.max_value = boss_node.max_hp
		boss_hp_bar.value = max(0.0, boss_node.hp)


func _show_boss_warning() -> void:
	var bid: String = String(stage_def.get("boss_id", ""))
	var bname: String = GameData.tr_enemy_name(bid)
	if bname.is_empty():
		bname = tr("GAME_BOSS_NAME_FALLBACK")
	boss_warning.text = tr("GAME_BOSS_WARN_FMT") % bname
	boss_warning.visible = true
	boss_warning.modulate = Color(1, 0.4, 0.4, 0)
	var tw := create_tween()
	tw.tween_property(boss_warning, "modulate", Color(1, 0.4, 0.4, 1), 0.4)
	tw.tween_interval(2.0)
	tw.tween_property(boss_warning, "modulate", Color(1, 0.4, 0.4, 0), 0.6)
	tw.tween_callback(func(): boss_warning.visible = false)


func _spawn_stage_boss() -> void:
	var boss_id: String = String(stage_def.get("boss_id", ""))
	if boss_id.is_empty():
		return
	var def: Dictionary = GameData.get_enemy_def(boss_id)
	if def.is_empty():
		push_warning("[Game] 找不到 Boss 定義：%s" % boss_id)
		return
	var pos: Vector2 = _random_spawn_position(camera.global_position)
	var e = ENEMY_SCENE.instantiate()
	e.global_position = pos
	add_child(e)
	var boss_level: float = max(difficulty, float(stage_def.get("boss_level_factor", 12.0)))
	e.setup_with_slime(def, boss_level)
	boss_node = e
	e.tree_exited.connect(_on_boss_tree_exited)
	# Boss HP UI
	var bname: String = GameData.tr_name(def)
	if bname.is_empty():
		bname = tr("GAME_BOSS_NAME_FALLBACK")
	boss_hp_name.text = bname
	boss_hp_bar.max_value = e.max_hp
	boss_hp_bar.value = e.hp
	boss_hp_panel.visible = true
	# 進入 Boss 戰：警告閃一下
	_show_boss_appeared_text(boss_hp_name.text)


func _show_boss_appeared_text(name_text: String) -> void:
	boss_warning.text = tr("GAME_BOSS_APPEAR_FMT") % name_text
	boss_warning.visible = true
	boss_warning.modulate = Color(1, 0.3, 0.3, 0)
	var tw := create_tween()
	tw.tween_property(boss_warning, "modulate", Color(1, 0.3, 0.3, 1), 0.3)
	tw.tween_interval(1.5)
	tw.tween_property(boss_warning, "modulate", Color(1, 0.3, 0.3, 0), 0.5)
	tw.tween_callback(func(): boss_warning.visible = false)


func _on_boss_tree_exited() -> void:
	# Boss 被擊敗 (queue_free) → 勝利
	if stage_completed:
		return
	# 仍要確認玩家還有人活著（避免同歸於盡時誤判勝利）
	var anyone_alive: bool = false
	for pl in players:
		if pl.hp > 0:
			anyone_alive = true
			break
	if anyone_alive:
		_game_over(true)


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


func _update_hud() -> void:
	var time_str: String = tr("HUD_TIME_FMT") % [team_level, int(run_time / 60), int(run_time) % 60]
	if not boss_spawned and not stage_def.is_empty():
		var boss_time: float = float(stage_def.get("boss_time", 600.0))
		var remain: float = max(0.0, boss_time - run_time)
		if remain <= 60.0:
			time_str += tr("HUD_BOSS_TIMER_FMT") % int(ceil(remain))
	time_label.text = time_str
	if players.size() >= 1:
		var p = players[0]
		hud_p1_lv.text = tr("HUD_PLAYER_LV_FMT") % [1, GameData.tr_character_name(p.character_id)]
		hud_p1_hp.max_value = p.get_effective_max_hp() if p.has_method("get_effective_max_hp") else p.max_hp * p.hp_mult
		hud_p1_hp.value = p.hp
		hud_p1_xp.max_value = team_xp_to_next
		hud_p1_xp.value = team_xp
		hud_p1_kills.text = tr("HUD_KILLS_FMT") % p.kills
	if GameState.two_players and players.size() >= 2:
		var p = players[1]
		hud_p2_lv.text = tr("HUD_PLAYER_LV_FMT") % [2, GameData.tr_character_name(p.character_id)]
		hud_p2_hp.max_value = p.get_effective_max_hp() if p.has_method("get_effective_max_hp") else p.max_hp * p.hp_mult
		hud_p2_hp.value = p.hp
		hud_p2_xp.max_value = team_xp_to_next
		hud_p2_xp.value = team_xp
		hud_p2_kills.text = tr("HUD_KILLS_FMT") % p.kills


# ---------------- 敵人生成 ----------------
func _on_spawn_tick() -> void:
	if stage_completed:
		return
	if blacksmith_rescue_event_active:
		spawn_timer.wait_time = max(spawn_timer.wait_time, 1.4)
		return
	# 玩家數量縮放：2P 多湧 40%（之前 60% 太硬，純近戰雙人 3 分鐘就翻車）
	var alive_count: int = 0
	for p in players:
		if p.hp > 0:
			alive_count += 1
	var p_scale: float = 1.0 + 0.4 * max(0, alive_count - 1)
	# Boss 出現後降低小怪生成量，讓玩家專注打 Boss
	var boss_active: bool = boss_spawned and is_instance_valid(boss_node)
	# 0.45 → 0.40：每階難度增加的怪量更少，加上 /44 的曲線可以放慢前期壓力
	var batch_f: float = (1.0 + difficulty * 0.40) * p_scale * float(stage_def.get("spawn_batch_mult", 1.0))
	var batch: int = clamp(int(round(batch_f)), 1, 10)
	if boss_active:
		batch = max(1, batch / 2)
	for i in batch:
		_spawn_one_enemy()
	# 隨難度加快生成；Boss 戰拉長間隔；2P 也稍微加速
	var wt: float = max(0.55, 1.6 - difficulty * 0.08)
	if alive_count >= 2:
		wt = max(0.45, wt * 0.9)
	wt /= max(0.1, float(stage_def.get("spawn_rate_mult", 1.0)))
	if boss_active:
		wt = max(wt, 2.0)
	spawn_timer.wait_time = wt


func _spawn_one_enemy() -> void:
	if players.is_empty(): return
	var center: Vector2 = camera.global_position
	var pos: Vector2 = _random_spawn_position(center)
	var pool_id: String = String(stage_def.get("enemy_pool", "slime"))
	var def: Dictionary = GameData.pick_enemy_from_pool(pool_id, difficulty)
	var e = ENEMY_SCENE.instantiate()
	e.global_position = pos
	add_child(e)
	# 雙人時敵人有效等級 +6%（之前 +12% 配上量多就過硬，純近戰會崩）
	var alive_count: int = 0
	for p in players:
		if p.hp > 0:
			alive_count += 1
	var eff_diff: float = difficulty * (1.06 if alive_count >= 2 else 1.0)
	e.setup_with_slime(def, eff_diff)
	_configure_stage_ranged_enemy(e)


func _configure_stage_ranged_enemy(e: Node) -> void:
	if not e.has_method("configure_ranged_attack"):
		return
	if "slime_def" in e:
		var sdf: Dictionary = e.slime_def
		if sdf.get("ranged", null) is Dictionary:
			return
	var ranged: Dictionary = stage_def.get("enemy_ranged", {})
	if ranged.is_empty():
		return
	e.configure_ranged_attack(ranged)


func _random_spawn_position(center: Vector2) -> Vector2:
	var pos: Vector2 = center
	for attempt in 8:
		var ang: float = randf() * TAU
		var dist: float = 480.0 + randf() * 80.0
		pos = center + Vector2(cos(ang), sin(ang)) * dist
		if map_bounds.size != Vector2.ZERO:
			pos.x = clamp(pos.x, map_bounds.position.x + 30.0, map_bounds.end.x - 30.0)
			pos.y = clamp(pos.y, map_bounds.position.y + 30.0, map_bounds.end.y - 30.0)
		if not is_world_blocked_at(pos, 28.0):
			return pos
	return pos


# ---------------- 共用等級 ----------------
# Player.add_xp 會呼叫這裡。所有 XP 進入隊伍進度池，雙人共享。
func add_team_xp(amount: float) -> void:
	team_xp += amount
	while team_xp >= team_xp_to_next:
		team_xp -= team_xp_to_next
		_team_level_up()
	_sync_team_progress_to_players()


func add_run_gold(amount: int) -> void:
	GameState.grant_run_gold(amount)


func notify_rune_dust_drop(amount: int) -> void:
	if amount <= 0:
		return
	_show_center_notice(_tr_text("BLACKSMITH_RUNNER_DUST_NOTICE_FMT", "取得符文粉塵 +%d") % amount)


func notify_material_drop(id: String, amount: int) -> void:
	if amount <= 0:
		return
	_show_center_notice(tr("MATERIAL_DROP_NOTICE_FMT") % [GameData.tr_material_name(id), amount])


func roll_enemy_material_drop(slime_def: Dictionary) -> Dictionary:
	var enemy_drops: Variant = slime_def.get("material_drops", [])
	var table: Array = stage_def.get("material_drops", [])
	if enemy_drops is Array and not enemy_drops.is_empty():
		table = enemy_drops
	return GameData.roll_material_drop_table(table)


func _team_level_up() -> void:
	team_level += 1
	# 1.32 倍 + 3：每升一級的需求成長更快（之前 1.25 + 2 太溫和）
	team_xp_to_next = round(team_xp_to_next * 1.32 + 3.0)
	# 所有存活玩家一起升級 → 一起進入彈珠台
	var leveled: Array = []
	for p in players:
		if p.hp > 0:
			p.on_team_level_up(team_level)
			leveled.append(p)
	if leveled.is_empty():
		return
	pending_levelers.append_array(leveled)
	if not pinball_active:
		_start_pinball_round()


func _sync_team_progress_to_players() -> void:
	for p in players:
		if p == null:
			continue
		p.level = team_level
		p.sync_team_progress(team_xp, team_xp_to_next)


# ---------------- 升級 -> 彈珠台 ----------------
func _start_pinball_round() -> void:
	if pending_levelers.is_empty(): return
	pinball_active = true
	# 一次處理所有當前等待升級的玩家（若兩位同時升級會一起進）
	var batch: Array = pending_levelers.duplicate()
	pending_levelers.clear()
	var pb = PINBALL_SCENE.instantiate()
	pb.setup(batch, pinball_run_destroyed_reward_keys, pinball_judgment_destroy_count,
		PINBALL_JUDGMENT_DESTROY_LIMIT)
	add_child(pb)
	pb.tree_exited.connect(_on_pinball_closed)


func _on_pinball_closed() -> void:
	pinball_active = false
	if not pending_levelers.is_empty():
		# 玩過程中又升級的留到下一波
		_start_pinball_round()


func pinball_can_judgment_destroy_reward(key: String) -> bool:
	if key == "" or pinball_run_destroyed_reward_keys.has(key):
		return false
	return pinball_judgment_destroy_count < PINBALL_JUDGMENT_DESTROY_LIMIT


func pinball_register_judgment_destroyed_reward(key: String) -> bool:
	if not pinball_can_judgment_destroy_reward(key):
		return false
	pinball_run_destroyed_reward_keys.append(key)
	pinball_judgment_destroy_count += 1
	return true


# ---------------- 玩家死亡 ----------------
func _on_player_died(p: Node) -> void:
	# 若雙人，存活者繼續；都死才結束
	var anyone_alive := false
	for pl in players:
		if pl.hp > 0:
			anyone_alive = true
			break
	if not anyone_alive:
		_game_over(false)


func _game_over(won: bool) -> void:
	if stage_completed:
		return
	stage_completed = true
	GameState.last_result["won"] = won
	GameState.last_result["time"] = run_time
	GameState.last_result["kills_p1"] = players[0].kills if players.size() > 0 else 0
	GameState.last_result["kills_p2"] = players[1].kills if players.size() > 1 else 0
	var achievement_unlocks: Array[String] = _record_achievement_progress()
	GameState.last_result["achievement_unlocks"] = achievement_unlocks
	spawn_timer.stop()
	boss_hp_panel.visible = false

	var reward: int = 0
	if won:
		reward = int(stage_def.get("victory_gold", 0))
		GameState.mark_stage_completed(String(stage_def.get("id", "")))
		GameState.grant_run_gold(reward)
		_clear_remaining_enemies()
		AudioManager.play_sfx("reward", 0.02)
	reward = int(GameState.last_result.get("gold_reward", reward))
	gameover_panel.visible = true
	_populate_summary(won, reward)


func _record_achievement_progress() -> Array[String]:
	var run_stats: Dictionary = {
		"damage_taken": 0.0,
		"damage_dealt": 0.0,
		"kills": 0,
		"pinball_score": 0,
	}
	for p in players:
		if p == null:
			continue
		run_stats["damage_taken"] = float(run_stats["damage_taken"]) + float(p.damage_taken)
		run_stats["damage_dealt"] = float(run_stats["damage_dealt"]) + float(p.damage_dealt)
		run_stats["kills"] = int(run_stats["kills"]) + int(p.kills)
		run_stats["pinball_score"] = int(run_stats["pinball_score"]) + int(p.pinball_score)
	return GameState.record_achievement_progress(run_stats)


func _clear_remaining_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.queue_free()


# ---------------- 戰鬥結算畫面 ----------------
func _populate_summary(won: bool, reward: int) -> void:
	# 標題 / 副標
	if won:
		gameover_title.text = tr("GAME_VICTORY")
		gameover_title.add_theme_color_override("font_color", Color(1, 0.95, 0.55))
	else:
		gameover_title.text = tr("GAME_DEFEAT")
		gameover_title.add_theme_color_override("font_color", Color(1, 0.6, 0.5))
	var stage_name: String = GameData.tr_name(stage_def)
	gameover_subtitle.text = tr("GAME_SUBTITLE_FMT") % [
		stage_name, int(run_time / 60), int(run_time) % 60]

	var lines: Array[String] = []
	# 隊伍 / 局外總結
	lines.append(tr("GAME_TEAM_LINE_FMT") % [team_level, reward, GameState.gold])
	var achievement_unlocks: Array = GameState.last_result.get("achievement_unlocks", [])
	if not achievement_unlocks.is_empty():
		var names: Array[String] = []
		for cid in achievement_unlocks:
			names.append(GameData.tr_character_name(String(cid)))
		lines.append(tr("GAME_ACHIEVEMENT_UNLOCK_FMT") % "、".join(names))
	lines.append("")

	for p in players:
		if p == null:
			continue
		var c_def: Dictionary = GameData.get_character_def(p.character_id)
		var passive_def: Dictionary = GameData.get_passive_def(String(p.passive_id))
		var skill_def: Dictionary = GameData.get_skill_def(String(p.skill_id))
		var c_color: String = c_def["color"].to_html(false)
		var status: String = tr("GAME_STATUS_ALIVE") if p.hp > 0 else tr("GAME_STATUS_DEAD")
		lines.append(tr("GAME_PLAYER_HEADER_FMT") % [
			c_color, p.slot_index + 1,
			GameData.tr_name(c_def),
			status,
			GameData.tr_name(passive_def),
			GameData.tr_name(skill_def)])
		lines.append(tr("GAME_PLAYER_STATS_FMT") % [
			p.kills,
			int(round(p.damage_dealt)),
			int(round(p.damage_taken)),
			int(p.pinball_score)])
		# 武器
		if p.weapons.size() > 0:
			var wparts: Array[String] = []
			for w in p.weapons:
				wparts.append(tr("GAME_WEAPON_ITEM_FMT") % [
					GameData.tr_weapon_name(String(w["id"])), w["level"]])
			lines.append(tr("GAME_WEAPONS_PREFIX") + "  ".join(wparts))
		# 加成（局內取得的 common upgrade）— 顯示名稱與層數
		var upgrade_log: Dictionary = p.common_upgrade_log
		if upgrade_log.size() > 0:
			var uparts: Array[String] = []
			for uid in upgrade_log.keys():
				var uname: String = String(uid)
				for u in GameData.COMMON_UPGRADES:
					if u["id"] == uid:
						uname = GameData.tr_name(u)
						break
				uparts.append(tr("GAME_ABILITY_ITEM_FMT") % [uname, int(upgrade_log[uid])])
			lines.append(tr("GAME_ABILITIES_PREFIX") + "  ".join(uparts))
		else:
			lines.append(tr("GAME_ABILITIES_PREFIX") + tr("GAME_ABILITIES_NONE"))
		# 屬性堆疊
		var stacks: Array[String] = _build_stat_stacks(p)
		if not stacks.is_empty():
			lines.append(tr("GAME_STACKS_PREFIX") + "  ".join(stacks) + "[/color]")
		lines.append("")

	gameover_stats.text = "\n".join(lines)
	gameover_hint.text = tr("GAME_HINT_BACK")


# 將玩家當前 buff 堆疊轉成顯示文字（HP +20% 等），給結算與暫停選單共用
func _build_stat_stacks(p: Node) -> Array[String]:
	var stacks: Array[String] = []
	if p.hp_mult > 1.001:
		stacks.append(tr("STAT_HP_FMT") % int((p.hp_mult - 1.0) * 100))
	if p.speed_mult > 1.001:
		stacks.append(tr("STAT_SPD_FMT") % int((p.speed_mult - 1.0) * 100))
	if p.damage_mult > 1.001:
		stacks.append(tr("STAT_ATK_FMT") % int((p.damage_mult - 1.0) * 100))
	if p.rate_mult > 1.001:
		stacks.append(tr("STAT_RATE_FMT") % int((p.rate_mult - 1.0) * 100))
	if p.get("crit_chance") != null and float(p.crit_chance) > 0.001:
		stacks.append(tr("STAT_CRIT_RATE_FMT") % int(float(p.crit_chance) * 100))
	if p.get("crit_damage_mult") != null \
			and float(p.crit_damage_mult) > GameData.CRIT_DAMAGE_MULT_BASE + 0.001:
		stacks.append(tr("STAT_CRIT_DMG_FMT") % int((float(p.crit_damage_mult) - 1.0) * 100))
	if p.pickup_mult > 1.001:
		stacks.append(tr("STAT_PICKUP_FMT") % int((p.pickup_mult - 1.0) * 100))
	if p.xp_mult > 1.001:
		stacks.append(tr("STAT_XP_FMT") % int((p.xp_mult - 1.0) * 100))
	if p.dmg_reduce > 0.001:
		stacks.append(tr("STAT_DR_FMT") % int(p.dmg_reduce * 100))
	if p.regen_per_sec > 0.001:
		stacks.append(tr("STAT_REGEN_FMT") % p.regen_per_sec)
	return stacks


# ---------------- 背景網格 ----------------
func _draw_background() -> void:
	background.fn = Callable(self, "_draw_grid")
	background.queue_redraw()


func _draw_grid(node: Node2D) -> void:
	var step := 80
	var size := 4000
	var col := Color(0.18, 0.22, 0.32, 0.6)
	for i in range(-size / step, size / step + 1):
		node.draw_line(Vector2(i * step, -size), Vector2(i * step, size), col)
		node.draw_line(Vector2(-size, i * step), Vector2(size, i * step), col)
