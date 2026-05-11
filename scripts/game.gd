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

var players: Array = []
var run_time: float = 0.0
var pending_levelers: Array = []
var pinball_active: bool = false
var difficulty: float = 0.0
var paused_for_pinball: bool = false

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
	_position_camera()
	# 雙人模式：團隊 XP 門檻 + 50%（敵人多 60%、不該因此一直升級爆 HP）
	if GameState.two_players:
		team_xp_to_next = round(team_xp_to_next * 1.5)
	spawn_timer.timeout.connect(_on_spawn_tick)
	spawn_timer.start()
	_draw_background()
	hud_p2_panel.visible = GameState.two_players
	_show_stage_banner()


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


func _process(delta: float) -> void:
	if stage_completed:
		_position_camera()
		return
	run_time += delta
	# 第一關曲線：每 44 秒提升一階（再放慢一點，雙人純近戰前 5 分鐘也撐得住）
	difficulty = run_time / 44.0
	_position_camera()
	_update_hud()
	_update_stage_progress()
	# ESC 由 PauseMenu (PROCESS_MODE_ALWAYS) 處理


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
	var bname: String = GameData.tr_slime_name(bid)
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
	var def: Dictionary = GameData.get_slime_def(boss_id)
	if def.is_empty():
		push_warning("[Game] 找不到 Boss 定義：%s" % boss_id)
		return
	var pos: Vector2 = _random_spawn_position(camera.global_position)
	var e = ENEMY_SCENE.instantiate()
	e.global_position = pos
	add_child(e)
	# Boss 用「最高難度」推算數值，避免靠 difficulty 而變弱
	e.setup_with_slime(def, max(difficulty, 12.0))
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
	var center := Vector2.ZERO
	var alive := 0
	for p in players:
		if p.hp > 0:
			center += p.global_position
			alive += 1
	if alive > 0:
		center /= alive
	camera.global_position = center


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
		hud_p1_hp.max_value = p.max_hp * p.hp_mult
		hud_p1_hp.value = p.hp
		hud_p1_xp.max_value = team_xp_to_next
		hud_p1_xp.value = team_xp
		hud_p1_kills.text = tr("HUD_KILLS_FMT") % p.kills
	if GameState.two_players and players.size() >= 2:
		var p = players[1]
		hud_p2_lv.text = tr("HUD_PLAYER_LV_FMT") % [2, GameData.tr_character_name(p.character_id)]
		hud_p2_hp.max_value = p.max_hp * p.hp_mult
		hud_p2_hp.value = p.hp
		hud_p2_xp.max_value = team_xp_to_next
		hud_p2_xp.value = team_xp
		hud_p2_kills.text = tr("HUD_KILLS_FMT") % p.kills


# ---------------- 敵人生成 ----------------
func _on_spawn_tick() -> void:
	if stage_completed:
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
	var batch_f: float = (1.0 + difficulty * 0.40) * p_scale
	var batch: int = clamp(int(round(batch_f)), 1, 10)
	if boss_active:
		batch = max(1, batch / 2)
	for i in batch:
		_spawn_one_enemy()
	# 隨難度加快生成；Boss 戰拉長間隔；2P 也稍微加速
	var wt: float = max(0.55, 1.6 - difficulty * 0.08)
	if alive_count >= 2:
		wt = max(0.45, wt * 0.9)
	if boss_active:
		wt = max(wt, 2.0)
	spawn_timer.wait_time = wt


func _spawn_one_enemy() -> void:
	if players.is_empty(): return
	var center: Vector2 = camera.global_position
	var pos: Vector2 = _random_spawn_position(center)
	var def: Dictionary = GameData.pick_slime(difficulty)
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
	pb.setup(batch)
	add_child(pb)
	pb.tree_exited.connect(_on_pinball_closed)


func _on_pinball_closed() -> void:
	pinball_active = false
	if not pending_levelers.is_empty():
		# 玩過程中又升級的留到下一波
		_start_pinball_round()


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
	spawn_timer.stop()
	boss_hp_panel.visible = false

	var reward: int = 0
	if won:
		reward = int(stage_def.get("victory_gold", 0))
		GameState.grant_run_gold(reward)
		_clear_remaining_enemies()
	gameover_panel.visible = true
	_populate_summary(won, reward)


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
