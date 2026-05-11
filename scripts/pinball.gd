extends CanvasLayer
## 彈珠台升級小遊戲
## 每位升級的玩家獲得一個頂部發射口（左右來回移動），按發球鍵即往下發球。
## 球撞釘陣後落入底部某格 → 套用該格獎勵。
## 雙人時兩位玩家各自操作自己的發射口/球。

const PEG_RADIUS := 8.0
const BALL_RADIUS := 12.0
const SLOT_COUNT := 4
const GRAVITY := 980.0
const WALL_BOUNCE := 0.85
const PEG_BOUNCE := 0.92
const LAUNCHER_SPEED := 200.0
const LAUNCHER_HALF_W := 18.0
const LAUNCH_INITIAL_VY := 320.0


var board_rect: Rect2 = Rect2()
# 彈針：每筆 {"pos": Vector2, "heavy_hits": int, "alive": bool}
var pegs: Array = []
var player_balls: Array = []
var slots: Array = []
var slot_w: float = 0.0
var slot_h: float = 60.0
var levelers: Array = []
var done_count: int = 0

var background: ColorRect
var board_panel: Panel
var title_label: Label
var instructions_label: Label
var slot_labels: Array = []

# 計分板：每次彈珠（含能量彈）撞到彈針 +1 分，依球的擁有玩家結算。目前純裝飾。
var player_scores: Dictionary = {}   # Node(player) -> int
var scoreboard_label: Label

var pegs_node: DrawerNode2D
var balls_node: DrawerNode2D
var slots_node: DrawerNode2D

# 技能圖示面板 — 每位升級玩家一個（使用共用 SkillIcon widget）
const SKILL_ICON_SCRIPT := preload("res://scripts/skill_icon.gd")
var skill_icons: Array = []

# 觸控介面：每位玩家一顆「發球」按鈕（與 player_balls 對齊；未發射時顯示）
var touch_launch_buttons: Array = []

var _closing := false


func setup(_levelers: Array) -> void:
	levelers = _levelers


func _ready() -> void:
	layer = 100
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_ui()
	_build_pegs()
	_build_slots()
	_build_balls()
	_build_scoreboard()
	_build_skill_icons()
	_build_touch_launch_buttons()
	_update_instructions()


func _build_ui() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.65)
	background.size = vp
	background.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(background)

	var board_w: float = 720.0
	var board_h: float = 560.0
	var bx: float = (vp.x - board_w) * 0.5
	var by: float = (vp.y - board_h) * 0.5 + 30.0
	board_rect = Rect2(bx, by, board_w, board_h - slot_h)

	board_panel = Panel.new()
	board_panel.position = Vector2(bx, by)
	board_panel.size = Vector2(board_w, board_h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.18, 1.0)
	sb.border_color = Color(0.95, 0.65, 0.18)
	sb.border_width_left = 4
	sb.border_width_right = 4
	sb.border_width_top = 4
	sb.border_width_bottom = 4
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	board_panel.add_theme_stylebox_override("panel", sb)
	add_child(board_panel)

	title_label = Label.new()
	title_label.text = tr("PINBALL_TITLE")
	title_label.position = Vector2(bx, by - 64)
	title_label.size = Vector2(board_w, 32)
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title_label)

	instructions_label = Label.new()
	instructions_label.position = Vector2(bx, by - 28)
	instructions_label.size = Vector2(board_w, 24)
	instructions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions_label.add_theme_font_size_override("font_size", 16)
	instructions_label.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0))
	add_child(instructions_label)

	pegs_node = DrawerNode2D.new()
	pegs_node.fn = Callable(self, "_draw_pegs")
	add_child(pegs_node)
	balls_node = DrawerNode2D.new()
	balls_node.fn = Callable(self, "_draw_balls")
	add_child(balls_node)
	slots_node = DrawerNode2D.new()
	slots_node.fn = Callable(self, "_draw_slots")
	add_child(slots_node)


func _update_instructions() -> void:
	var lines: Array[String] = []
	var energy_flying: bool = false
	for b in player_balls:
		if b.get("is_energy_wave", false) and not b["finished"]:
			energy_flying = true
			break
	if energy_flying:
		lines.append(tr("PINBALL_ENERGY_FLYING"))
	for b in player_balls:
		if b.get("is_energy_wave", false):
			continue
		var p = b["player"]
		var pname: String = tr("PINBALL_PNAME_FMT") % (p.slot_index + 1)
		if b["finished"]:
			lines.append(tr("PINBALL_DECIDED_FMT") % pname)
		elif not b["launched"]:
			lines.append(tr("PINBALL_LAUNCH_HINT_FMT") %
				[pname, _action_label(b["action"])])
		else:
			lines.append(tr("PINBALL_FLYING_FMT") % pname)
	instructions_label.text = "  |  ".join(lines)


# ---------------- 計分板 ----------------
func _build_scoreboard() -> void:
	# 初始化每位升級玩家的分數
	for p in levelers:
		player_scores[p] = 0
	scoreboard_label = Label.new()
	scoreboard_label.position = Vector2(board_rect.position.x + 8.0,
		board_rect.position.y + 8.0)
	scoreboard_label.size = Vector2(board_rect.size.x - 16.0, 24.0)
	scoreboard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scoreboard_label.add_theme_font_size_override("font_size", 16)
	scoreboard_label.add_theme_color_override("font_color", Color(1, 0.95, 0.55))
	add_child(scoreboard_label)
	_refresh_scoreboard()


func _refresh_scoreboard() -> void:
	if scoreboard_label == null:
		return
	var parts: Array[String] = []
	for p in levelers:
		if p == null:
			continue
		var sc: int = int(player_scores.get(p, 0))
		parts.append(tr("PINBALL_SCOREBOARD_ITEM_FMT") % [int(p.slot_index) + 1, sc])
	scoreboard_label.text = tr("PINBALL_SCOREBOARD_PREFIX") + "　".join(parts)


# 給球的擁有玩家加分（每撞 1 次彈針 = +1）
func _grant_peg_score(b: Dictionary, amount: int = 1) -> void:
	var p: Node = b.get("player", null)
	if p == null:
		return
	player_scores[p] = int(player_scores.get(p, 0)) + amount
	_refresh_scoreboard()


func _action_label(a: String) -> String:
	match a:
		"p1_action":
			return "Space"
		"p2_action":
			return "Enter"
	return a


func _build_pegs() -> void:
	# 比起原本 8x9 = 72 顆，密度太高隨機性太大；改為 6x7 蜂巢狀，加大間距
	# 之間保留至少一顆球可以穿過的寬度，讓球路徑更可預測
	pegs.clear()
	var rows := 6
	var cols := 7
	var top := board_rect.position.y + 90.0
	var bottom := board_rect.end.y - 60.0
	var step_y: float = (bottom - top) / max(1.0, float(rows - 1))
	var step_x: float = board_rect.size.x / float(cols + 1)
	for r in rows:
		var y: float = top + r * step_y
		var offset: float = step_x * 0.5 if r % 2 == 1 else 0.0
		for c in cols:
			var x: float = board_rect.position.x + step_x * (c + 1) + offset
			if x < board_rect.position.x + 28.0 or x > board_rect.end.x - 28.0:
				continue
			pegs.append({
				"pos": Vector2(x, y),
				"heavy_hits": 0,
				"wave_hits": 0,
				"alive": true,
			})
	pegs_node.queue_redraw()


func _draw_pegs(node: Node2D) -> void:
	for p in pegs:
		if not p.get("alive", true):
			continue
		var pos: Vector2 = p["pos"]
		var hits: int = int(p.get("heavy_hits", 0))
		var wv: int = int(p.get("wave_hits", 0))
		# 能量炮彈撞擊：偏紫
		if wv > 0:
			node.draw_circle(pos, PEG_RADIUS + 1.0, Color(0.75, 0.45, 1.0, 0.45))
			node.draw_circle(pos, PEG_RADIUS, Color(0.55, 0.35, 0.95))
			node.draw_circle(pos, PEG_RADIUS - 2.0, Color(0.9, 0.75, 1.0))
		# 受過重裝彈珠撞擊：染上裂紋紅
		elif hits > 0:
			node.draw_circle(pos, PEG_RADIUS + 1.0, Color(0.95, 0.4, 0.35, 0.55))
			node.draw_circle(pos, PEG_RADIUS, Color(0.85, 0.6, 0.45))
			node.draw_circle(pos, PEG_RADIUS - 2.0, Color(1.0, 0.85, 0.65))
		else:
			node.draw_circle(pos, PEG_RADIUS, Color(0.35, 0.75, 1.0))
			node.draw_circle(pos, PEG_RADIUS - 2.0, Color(0.65, 0.9, 1.0))


func _build_slots() -> void:
	slots.clear()
	var pool: Array = _build_reward_pool()
	pool.shuffle()
	var picked: Array = []
	for r in pool:
		if picked.size() >= SLOT_COUNT:
			break
		var dup := false
		for q in picked:
			if q["name"] == r["name"]:
				dup = true; break
		if not dup:
			picked.append(r)
	while picked.size() < SLOT_COUNT:
		picked.append({"name": tr("PINBALL_SLOT_GOLD"), "desc": tr("PINBALL_SLOT_GOLD_DESC"),
			"color": Color(1, 0.85, 0.4), "reward": {"type": "noop"}})
	slots = picked

	slot_w = board_rect.size.x / SLOT_COUNT
	for i in SLOT_COUNT:
		var lbl := Label.new()
		lbl.position = Vector2(board_rect.position.x + slot_w * i,
			board_rect.end.y + 6.0)
		lbl.size = Vector2(slot_w, slot_h - 8.0)
		lbl.text = slots[i]["name"]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		add_child(lbl)
		slot_labels.append(lbl)
	slots_node.queue_redraw()


func _draw_slots(node: Node2D) -> void:
	for i in SLOT_COUNT:
		var col: Color = slots[i]["color"]
		var r := Rect2(board_rect.position.x + slot_w * i,
			board_rect.end.y, slot_w - 2.0, slot_h - 8.0)
		if slots[i].get("destroyed", false):
			# 摧毀格：暗背景 + 紅 X + 上方紅擋板
			node.draw_rect(r, Color(0.18, 0.10, 0.13, 0.92))
			node.draw_line(r.position,
				r.position + r.size,
				Color(0.95, 0.35, 0.35, 0.85), 2.5)
			node.draw_line(r.position + Vector2(r.size.x, 0),
				r.position + Vector2(0, r.size.y),
				Color(0.95, 0.35, 0.35, 0.85), 2.5)
			node.draw_line(r.position,
				r.position + Vector2(r.size.x, 0),
				Color(1, 0.45, 0.45, 1.0), 4.0)
		else:
			node.draw_rect(r, Color(col.r, col.g, col.b, 0.85))
			node.draw_line(r.position, r.position + Vector2(r.size.x, 0),
				Color(1, 1, 1, 0.6), 2.0)


func _build_reward_pool() -> Array:
	var pool: Array = []
	for u in GameData.COMMON_UPGRADES:
		pool.append({
			"name": GameData.tr_name(u),
			"desc": GameData.tr_desc(u),
			"color": Color(0.55, 0.85, 0.95),
			"reward": {"type": "common", "id": u["id"]},
		})
	# 統計：每位升級玩家擁有的武器、是否還有空格
	var weapon_cap: int = 5
	if levelers.size() > 0:
		weapon_cap = int(levelers[0].WEAPON_SLOT_MAX)
	var anyone_has_room: bool = false
	var owned: Dictionary = {}
	for p in levelers:
		if p.weapons.size() < weapon_cap:
			anyone_has_room = true
		for w in p.weapons:
			owned[w["id"]] = true
	for w in GameData.WEAPONS:
		var w_name: String = GameData.tr_name(w)
		if not owned.has(w["id"]):
			# 如果「全部升級玩家武器格都滿」→ 沒人能拿這把新武器，
			# 把它降級成「強化既有武器」，避免出現「拿到也用不到」的格子
			if not anyone_has_room:
				continue
			pool.append({
				"name": w_name,
				"desc": tr("PINBALL_SLOT_NEW_WEAPON_DESC"),
				"color": Color(0.95, 0.7, 0.5),
				"reward": {"type": "weapon", "id": w["id"]},
			})
		else:
			pool.append({
				"name": tr("PINBALL_SLOT_UPGRADE_NAME_FMT") % w_name,
				"desc": tr("PINBALL_SLOT_UPGRADE_DESC_FMT") % w_name,
				"color": Color(0.95, 0.85, 0.45),
				"reward": {"type": "weapon_up", "id": w["id"]},
			})
	pool.shuffle()
	return pool


func _build_balls() -> void:
	for i in levelers.size():
		var p = levelers[i]
		var from_left: bool = (p.slot_index == 0)
		# 兩位玩家發射口高度錯開避免重疊
		var launcher_y: float = board_rect.position.y + 22.0 + i * 22.0
		var launcher_x: float = board_rect.position.x + board_rect.size.x * (0.30 if from_left else 0.70)
		var data := {
			"player": p,
			"pos": Vector2(launcher_x, launcher_y + 18.0),
			"vel": Vector2.ZERO,
			"launched": false,
			"finished": false,
			"color": p.color,
			"from_left": from_left,
			"action": "p1_action" if p.slot_index == 0 else "p2_action",
			"reward_idx": -1,
			# 發射口狀態
			"launcher_x": launcher_x,
			"launcher_y": launcher_y,
			"launcher_dir": 1.0 if from_left else -1.0,
		}
		player_balls.append(data)


func _process(delta: float) -> void:
	for b in player_balls:
		if b["finished"]:
			continue
		if b.get("is_energy_wave", false):
			_step_energy_wave_ball(b, delta)
			continue
		if not b["launched"]:
			_step_launcher(b, delta)
			if Input.is_action_just_pressed(b["action"]):
				_launch_ball(b)
				b["launched"] = true
		# 技能鍵：玩家在彈珠台中也能發動技能（共用同一個冷卻）
		var p = b["player"]
		var skill_action: String = "p1_skill" if p.slot_index == 0 else "p2_skill"
		if Input.is_action_just_pressed(skill_action):
			if p.has_method("try_consume_skill"):
				var skd: Dictionary = p.call("try_consume_skill")
				if not skd.is_empty():
					if not _handle_pinball_skill(skd, b):
						# 技能未生效（目標格已摧毀／不能再降）→ 退還冷卻
						p.skill_cooldown = 0.0
		if b["launched"]:
			_step_ball(b, delta)
	_update_instructions()
	balls_node.queue_redraw()
	_refresh_touch_launch_visibility()
	if _all_main_balls_finished() and _all_energy_balls_finished():
		_close_in(0.7)


func _all_main_balls_finished() -> bool:
	return done_count >= levelers.size()


func _all_energy_balls_finished() -> bool:
	for b in player_balls:
		if b.get("is_energy_wave", false) and not b["finished"]:
			return false
	return true


# 彈珠台情境的技能派發
func _handle_pinball_skill(s: Dictionary, b: Dictionary) -> bool:
	match String(s.get("id", "none")):
		"whirl_slash":
			return destroy_slot_at_launcher(b)
		"heavy_armor":
			return _activate_heavy_ball(b, s)
		"energy_wave":
			return _spawn_energy_wave_ball(b["player"], s)
		"agile_tactics":
			return _activate_light_ball(b, s)
	return false


# 靈敏戰技（彈珠台）：自身彈珠變輕，每 3 次彈針撞擊給玩家 1 支箭矢
func _activate_light_ball(b: Dictionary, s: Dictionary) -> bool:
	if b.get("light", false):
		return false
	var prm: Dictionary = s.get("params", {})
	b["light"] = true
	b["gravity_mult"] = float(prm.get("pinball_gravity_mult", 0.65))
	b["peg_bounce_mult"] = float(prm.get("pinball_peg_bounce_mult", 1.05))
	b["hits_per_arrow"] = int(prm.get("pinball_hits_per_arrow", 3))
	b["arrow_max"] = int(prm.get("arrow_max", 5))
	b["light_peg_count"] = 0
	return true


# 重裝防禦（彈珠台）：把自己的球變重 — 重力上升 + 撞兩下會破壞彈針
# 已是重裝狀態時失敗（避免空轉冷卻）
func _activate_heavy_ball(b: Dictionary, s: Dictionary) -> bool:
	if b.get("heavy", false):
		return false
	var params: Dictionary = s.get("params", {})
	b["heavy"] = true
	b["gravity_mult"] = float(params.get("pinball_gravity_mult", 1.45))
	b["peg_break_threshold"] = int(params.get("pinball_peg_hits_to_break", 2))
	return true


# 摧毀「目前發射器正下方」那格獎勵；4 選 1 → 3 選 1
# 規則：最少保留 2 格、目標格已摧毀則直接失敗（避免空轉冷卻）
# 能量波動：發射額外能量炮彈珠（與自身彈珠分離）；同場最多一顆未落地的能量彈
func _spawn_energy_wave_ball(p: Node, s: Dictionary) -> bool:
	for bb in player_balls:
		if bb.get("is_energy_wave", false) and bb.get("player") == p and not bb["finished"]:
			return false
	var prm: Dictionary = s.get("params", {})
	var peg_need: int = max(1, int(prm.get("pinball_peg_hits_break", 3)))
	var cx: float = board_rect.position.x + board_rect.size.x * 0.5
	var top_y: float = board_rect.position.y + 40.0
	var data := {
		"is_energy_wave": true,
		"player": p,
		"pos": Vector2(cx + randf_range(-90.0, 90.0), top_y),
		"vel": Vector2(randf_range(-95.0, 95.0), LAUNCH_INITIAL_VY * 0.92),
		"launched": true,
		"finished": false,
		"color": Color(0.78, 0.48, 1.0),
		"peg_wave_break": peg_need,
	}
	player_balls.append(data)
	return true


func destroy_slot_at_launcher(b: Dictionary) -> bool:
	var idx: int = int(floor((b["launcher_x"] - board_rect.position.x) / slot_w))
	idx = clamp(idx, 0, SLOT_COUNT - 1)
	return _destroy_slot_at_index(idx, b["player"])


func _destroy_slot_at_index(idx: int, p: Node) -> bool:
	if slots[idx].get("destroyed", false):
		return false
	var alive_count: int = 0
	for i in SLOT_COUNT:
		if not slots[i].get("destroyed", false):
			alive_count += 1
	if alive_count <= 2:
		return false
	slots[idx]["destroyed"] = true
	var lbl: Label = slot_labels[idx]
	lbl.text = tr("PINBALL_SLOT_DESTROYED")
	lbl.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	var t := lbl.create_tween()
	lbl.modulate = Color(p.color.r * 1.4, p.color.g * 1.4, p.color.b * 1.4, 1.0)
	t.tween_property(lbl, "modulate", Color(1, 1, 1), 0.6)
	slots_node.queue_redraw()
	return true


func _step_launcher(b: Dictionary, delta: float) -> void:
	# 發射口在頂部來回移動，球跟著發射口
	b["launcher_x"] += b["launcher_dir"] * LAUNCHER_SPEED * delta
	var min_x: float = board_rect.position.x + LAUNCHER_HALF_W + 4.0
	var max_x: float = board_rect.end.x - LAUNCHER_HALF_W - 4.0
	if b["launcher_x"] <= min_x:
		b["launcher_x"] = min_x
		b["launcher_dir"] = 1.0
	elif b["launcher_x"] >= max_x:
		b["launcher_x"] = max_x
		b["launcher_dir"] = -1.0
	b["pos"] = Vector2(b["launcher_x"], b["launcher_y"] + 18.0)


func _launch_ball(b: Dictionary) -> void:
	# 發射時繼承發射口的橫向速度（讓玩家可以靠時機改變角度）
	var lateral: float = b["launcher_dir"] * LAUNCHER_SPEED * 0.6
	b["vel"] = Vector2(lateral, LAUNCH_INITIAL_VY)


func _step_ball(b: Dictionary, delta: float) -> void:
	if b["finished"]:
		return
	# 重裝彈珠重力上升 / 輕盈彈珠重力下降
	var g: float = GRAVITY
	if b.get("heavy", false) or b.get("light", false):
		g *= float(b.get("gravity_mult", 1.0))
	b["vel"].y += g * delta
	b["vel"] = b["vel"].limit_length(900.0)
	var new_pos: Vector2 = b["pos"] + b["vel"] * delta

	if new_pos.x < board_rect.position.x + BALL_RADIUS:
		new_pos.x = board_rect.position.x + BALL_RADIUS
		b["vel"].x = -b["vel"].x * WALL_BOUNCE
	elif new_pos.x > board_rect.end.x - BALL_RADIUS:
		new_pos.x = board_rect.end.x - BALL_RADIUS
		b["vel"].x = -b["vel"].x * WALL_BOUNCE
	if new_pos.y < board_rect.position.y + BALL_RADIUS:
		new_pos.y = board_rect.position.y + BALL_RADIUS
		b["vel"].y = -b["vel"].y * WALL_BOUNCE

	var pegs_changed: bool = false
	for peg in pegs:
		if not peg.get("alive", true):
			continue
		var ppos: Vector2 = peg["pos"]
		var diff: Vector2 = new_pos - ppos
		var d: float = diff.length()
		var min_d: float = PEG_RADIUS + BALL_RADIUS
		if d < min_d and d > 0.001:
			var n: Vector2 = diff / d
			new_pos = ppos + n * min_d
			var dot: float = b["vel"].dot(n)
			if dot < 0:
				var bounce_k: float = PEG_BOUNCE
				if b.get("light", false):
					bounce_k *= float(b.get("peg_bounce_mult", 1.0))
				b["vel"] -= n * dot * (1.0 + bounce_k)
			# 計分：每撞 1 次彈針 = +1（純裝飾）
			_grant_peg_score(b, 1)
			# 重裝彈珠：撞擊累計，達門檻直接破壞
			if b.get("heavy", false):
				peg["heavy_hits"] = int(peg.get("heavy_hits", 0)) + 1
				var threshold: int = int(b.get("peg_break_threshold", 2))
				if peg["heavy_hits"] >= threshold:
					peg["alive"] = false
				pegs_changed = true
			# 輕盈彈珠：撞擊計數 → 每 N 次給玩家箭矢
			elif b.get("light", false):
				b["light_peg_count"] = int(b.get("light_peg_count", 0)) + 1
				var per: int = int(b.get("hits_per_arrow", 3))
				if per > 0 and b["light_peg_count"] >= per:
					b["light_peg_count"] -= per
					var p_owner: Node = b.get("player", null)
					if p_owner and p_owner.has_method("ranger_grant_arrow_from_pinball"):
						p_owner.call("ranger_grant_arrow_from_pinball",
							1, int(b.get("arrow_max", 5)))

	if pegs_changed:
		pegs_node.queue_redraw()

	b["pos"] = new_pos

	if b["pos"].y >= board_rect.end.y - BALL_RADIUS:
		var slot_idx: int = int(floor((b["pos"].x - board_rect.position.x) / slot_w))
		slot_idx = clamp(slot_idx, 0, SLOT_COUNT - 1)
		if slots[slot_idx].get("destroyed", false):
			# 摧毀格相當於頂端有擋板：球反彈往上 + 推往最近的可用格
			b["pos"].y = board_rect.end.y - BALL_RADIUS - 1.0
			b["vel"].y = -abs(b["vel"].y) * WALL_BOUNCE
			var nearest: int = -1
			var best_d: int = SLOT_COUNT + 1
			for i in SLOT_COUNT:
				if slots[i].get("destroyed", false):
					continue
				var di: int = absi(i - slot_idx)
				if di < best_d:
					best_d = di
					nearest = i
			if nearest >= 0:
				var slot_cx: float = board_rect.position.x + (nearest + 0.5) * slot_w
				var dx: float = slot_cx - b["pos"].x
				if dx != 0.0:
					var nudge: float = max(120.0, abs(b["vel"].y) * 0.4)
					b["vel"].x += sign(dx) * nudge
		else:
			_apply_reward(b, slot_idx)
			b["finished"] = true
			done_count += 1


func _step_energy_wave_ball(b: Dictionary, delta: float) -> void:
	if b["finished"]:
		return
	var g: float = GRAVITY
	b["vel"].y += g * delta
	b["vel"] = b["vel"].limit_length(900.0)
	var new_pos: Vector2 = b["pos"] + b["vel"] * delta

	if new_pos.x < board_rect.position.x + BALL_RADIUS:
		new_pos.x = board_rect.position.x + BALL_RADIUS
		b["vel"].x = -b["vel"].x * WALL_BOUNCE
	elif new_pos.x > board_rect.end.x - BALL_RADIUS:
		new_pos.x = board_rect.end.x - BALL_RADIUS
		b["vel"].x = -b["vel"].x * WALL_BOUNCE
	if new_pos.y < board_rect.position.y + BALL_RADIUS:
		new_pos.y = board_rect.position.y + BALL_RADIUS
		b["vel"].y = -b["vel"].y * WALL_BOUNCE

	var pegs_changed: bool = false
	var wave_need: int = int(b.get("peg_wave_break", 3))
	var owner_p: Node = b.get("player", null)
	for peg in pegs:
		if not peg.get("alive", true):
			continue
		var ppos: Vector2 = peg["pos"]
		var diff: Vector2 = new_pos - ppos
		var d: float = diff.length()
		var min_d: float = PEG_RADIUS + BALL_RADIUS
		if d < min_d and d > 0.001:
			var n: Vector2 = diff / d
			new_pos = ppos + n * min_d
			var dot: float = b["vel"].dot(n)
			if dot < 0:
				b["vel"] -= n * dot * (1.0 + PEG_BOUNCE)
			# 計分（能量彈也算）
			_grant_peg_score(b, 1)
			peg["wave_hits"] = int(peg.get("wave_hits", 0)) + 1
			if peg["wave_hits"] >= wave_need:
				peg["alive"] = false
			pegs_changed = true
			# 「奧術精通」：能量彈撞針視為技能命中
			if owner_p and owner_p.has_method("passive_arcane_mastery_on_skill_hit"):
				owner_p.call("passive_arcane_mastery_on_skill_hit")

	if pegs_changed:
		pegs_node.queue_redraw()

	b["pos"] = new_pos

	if b["pos"].y >= board_rect.end.y - BALL_RADIUS:
		var slot_idx: int = int(floor((b["pos"].x - board_rect.position.x) / slot_w))
		slot_idx = clamp(slot_idx, 0, SLOT_COUNT - 1)
		if slots[slot_idx].get("destroyed", false):
			b["pos"].y = board_rect.end.y - BALL_RADIUS - 1.0
			b["vel"].y = -abs(b["vel"].y) * WALL_BOUNCE
			var nearest2: int = -1
			var best_d2: int = SLOT_COUNT + 1
			for i in SLOT_COUNT:
				if slots[i].get("destroyed", false):
					continue
				var di2: int = absi(i - slot_idx)
				if di2 < best_d2:
					best_d2 = di2
					nearest2 = i
			if nearest2 >= 0:
				var slot_cx2: float = board_rect.position.x + (nearest2 + 0.5) * slot_w
				var dx2: float = slot_cx2 - b["pos"].x
				if dx2 != 0.0:
					var nudge2: float = max(120.0, abs(b["vel"].y) * 0.4)
					b["vel"].x += sign(dx2) * nudge2
		else:
			_resolve_energy_wave_slot(b, slot_idx)
			b["finished"] = true


func _resolve_energy_wave_slot(b: Dictionary, slot_idx: int) -> void:
	var p: Node = b["player"]
	var base_name: String = String(slots[slot_idx].get("name", ""))
	if randf() < 0.5:
		_apply_reward_to_player(p, slot_idx)
		_apply_reward_to_player(p, slot_idx)
		var lbl: Label = slot_labels[slot_idx]
		lbl.text = tr("PINBALL_DOUBLE_FMT") % base_name
		lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
		var t2 := lbl.create_tween()
		lbl.modulate = Color(1.5, 1.3, 0.7)
		t2.tween_property(lbl, "modulate", Color(1, 1, 1), 0.55)
	else:
		if not _destroy_slot_at_index(slot_idx, p):
			_apply_reward_to_player(p, slot_idx)
			_apply_reward_to_player(p, slot_idx)
			var lbl2: Label = slot_labels[slot_idx]
			lbl2.text = tr("PINBALL_DOUBLE_FMT") % base_name
			lbl2.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))


func _apply_reward(b: Dictionary, slot_idx: int) -> void:
	_apply_reward_to_player(b["player"], slot_idx)


func _apply_reward_to_player(p: Node, slot_idx: int) -> void:
	var slot: Dictionary = slots[slot_idx]
	if slot.get("destroyed", false):
		return
	var reward: Dictionary = slot["reward"]
	match reward.get("type", "noop"):
		"weapon", "weapon_up":
			# 既有武器就升級；沒有的話，看武器格是否還有空位：
			#   有空 → 加入新武器
			#   滿格 → 把獎勵轉成「強化等級最低的武器」並提示玩家
			var wid: String = String(reward["id"])
			var has_it: bool = false
			for w in p.weapons:
				if String(w["id"]) == wid:
					has_it = true
					break
			var cap: int = int(p.WEAPON_SLOT_MAX)
			if not has_it and p.weapons.size() >= cap:
				_substitute_weapon_full(p, wid)
			else:
				p.add_weapon(wid)
		"common":
			p.apply_common_upgrade(reward["id"])
		_:
			pass
	var lbl: Label = slot_labels[slot_idx]
	lbl.modulate = Color(1.6, 1.4, 0.8)
	var t := lbl.create_tween()
	t.tween_property(lbl, "modulate", Color(1, 1, 1), 0.6)


# 滿格玩家落到「新武器」格 → 自動把該武器轉成「強化等級最低的武器」，並彈跳提示
func _substitute_weapon_full(p: Node, _new_weapon_id: String) -> void:
	if p.weapons.is_empty():
		return
	# 找等級最低的武器，與 player.add_weapon 滿格時的處理一致
	var lowest: Dictionary = p.weapons[0]
	for w in p.weapons:
		if int(w["level"]) < int(lowest["level"]):
			lowest = w
	var sub_id: String = String(lowest["id"])
	p.add_weapon(sub_id)   # 同 id → 走 _apply_random_weapon_upgrade
	var wname: String = GameData.tr_weapon_name(sub_id)
	_show_pinball_notice(tr("PINBALL_NOTICE_FULL_FMT") % [
		int(p.slot_index) + 1, wname], Color(1.0, 0.7, 0.4))


# 在彈珠台板的上方顯示一段短暫提示文字（約 2 秒淡出）
func _show_pinball_notice(text: String, c: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", c)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(board_rect.size.x, 28.0)
	# 從現有所有提示往下排，讓多筆通知不會疊在一起
	var stack_idx: int = 0
	for ch in get_children():
		if ch is Label and ch.has_meta("pb_notice"):
			stack_idx += 1
	lbl.position = Vector2(board_rect.position.x,
		board_rect.position.y - 40.0 - stack_idx * 26.0)
	lbl.set_meta("pb_notice", true)
	lbl.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(lbl, "modulate", Color(1, 1, 1, 0), 0.45)
	tw.tween_callback(func():
		if is_instance_valid(lbl):
			lbl.queue_free()
	)


func _draw_balls(node: Node2D) -> void:
	for b in player_balls:
		# 發射口（未發球前）：繪製軌道與發射器
		if not b.get("is_energy_wave", false) and not b["launched"] and not b["finished"]:
			_draw_launcher(node, b)
		_draw_one_ball(node, b)


func _draw_launcher(node: Node2D, b: Dictionary) -> void:
	var c: Color = b["color"]
	var ly: float = b["launcher_y"]
	# 軌道
	var rail_y: float = ly
	node.draw_line(
		Vector2(board_rect.position.x + 4.0, rail_y),
		Vector2(board_rect.end.x - 4.0, rail_y),
		Color(c.r, c.g, c.b, 0.25), 2.0)
	# 彈道預測線（短）— 只算重力＋牆壁，碰到彈釘後續彈跳保留隨機性
	_draw_aim_prediction(node, b)
	# 發射器主體 (矩形)
	var rect := Rect2(b["launcher_x"] - LAUNCHER_HALF_W, ly - 8.0,
		LAUNCHER_HALF_W * 2.0, 14.0)
	node.draw_rect(rect, Color(c.r, c.g, c.b, 0.85))
	node.draw_rect(rect, Color(1, 1, 1, 0.6), false, 1.5)
	# 朝下方向指引（三角箭頭）
	var tri := PackedVector2Array([
		Vector2(b["launcher_x"] - 9.0, ly + 7.0),
		Vector2(b["launcher_x"] + 9.0, ly + 7.0),
		Vector2(b["launcher_x"], ly + 17.0),
	])
	node.draw_colored_polygon(tri, Color(c.r, c.g, c.b, 0.95))


# 預測未發射時，發出去後在「第一列彈釘前」會去到哪：
# 只模擬重力與左右牆壁反彈，刻意不算彈釘碰撞（彈釘陣列就是隨機性主要來源）。
# 渲染為一串漸淡的小圓點（虛線感），長度大約到第一列彈釘前緣為止。
func _draw_aim_prediction(node: Node2D, b: Dictionary) -> void:
	var c: Color = b["color"]
	var pos: Vector2 = Vector2(b["launcher_x"], b["launcher_y"] + 18.0)
	# 與 _launch_ball 中相同的初速計算
	var vel: Vector2 = Vector2(b["launcher_dir"] * LAUNCHER_SPEED * 0.6,
		LAUNCH_INITIAL_VY)
	var dt: float = 0.018
	var max_steps: int = 16   # ~0.29s 預測時間
	# 第一列彈釘 y（與 _build_pegs 中 top 對齊）；預測線到此就停
	var first_peg_y: float = board_rect.position.y + 90.0
	var stop_y: float = first_peg_y - PEG_RADIUS - 2.0
	var dot_col := Color(1, 1, 1, 0.65).lerp(Color(c.r, c.g, c.b, 0.85), 0.4)
	var pts: Array = []
	for _i in max_steps:
		vel.y += GRAVITY * dt
		pos += vel * dt
		# 牆壁反彈（球半徑 = BALL_RADIUS）
		if pos.x < board_rect.position.x + BALL_RADIUS:
			pos.x = board_rect.position.x + BALL_RADIUS
			vel.x = -vel.x * WALL_BOUNCE
		elif pos.x > board_rect.end.x - BALL_RADIUS:
			pos.x = board_rect.end.x - BALL_RADIUS
			vel.x = -vel.x * WALL_BOUNCE
		if pos.y > stop_y:
			break
		pts.append(pos)
	# 用「跳格」的方式畫成虛線感：只取偶數 index、半徑漸小 / alpha 漸淡
	for i in pts.size():
		if i % 2 == 1:
			continue
		var t: float = float(i) / max(1.0, float(pts.size() - 1))
		var a: float = lerp(0.85, 0.18, t)
		var r: float = lerp(2.6, 1.6, t)
		var pcol := Color(dot_col.r, dot_col.g, dot_col.b, a)
		node.draw_circle(pts[i], r, pcol)


func _draw_one_ball(node: Node2D, b: Dictionary, alpha: float = 1.0) -> void:
	var c: Color = b["color"]
	if b.get("is_energy_wave", false):
		node.draw_circle(b["pos"], BALL_RADIUS + 10.0,
			Color(0.75, 0.45, 1.0, alpha * 0.5))
		node.draw_circle(b["pos"], BALL_RADIUS + 3.0,
			Color(0.35, 0.15, 0.55, alpha))
		node.draw_circle(b["pos"], BALL_RADIUS,
			Color(0.85, 0.55, 1.0, alpha))
		node.draw_circle(b["pos"], BALL_RADIUS - 5.0,
			Color(1.0, 0.95, 1.0, alpha * 0.9))
	elif b.get("light", false):
		# 輕盈彈珠：羽毛綠光環 + 上箭頭點綴
		node.draw_circle(b["pos"], BALL_RADIUS + 9.0,
			Color(0.55, 1.0, 0.55, alpha * 0.45))
		node.draw_circle(b["pos"], BALL_RADIUS + 5.0,
			Color(0.7, 1.0, 0.65, alpha * 0.35))
		node.draw_circle(b["pos"], BALL_RADIUS,
			Color(c.r, c.g, c.b, alpha))
		node.draw_circle(b["pos"], BALL_RADIUS - 4.0,
			Color(min(1.0, c.r + 0.4),
				min(1.0, c.g + 0.4),
				min(1.0, c.b + 0.4), alpha))
		var tri_top: Vector2 = b["pos"] + Vector2(0, -BALL_RADIUS - 2.0)
		var tri := PackedVector2Array([
			tri_top,
			tri_top + Vector2(-4, 6),
			tri_top + Vector2(4, 6),
		])
		node.draw_colored_polygon(tri, Color(1, 1, 1, alpha * 0.85))
	elif b.get("heavy", false):
		# 重裝彈珠：金屬質感 + 玩家色內芯
		node.draw_circle(b["pos"], BALL_RADIUS + 8.0,
			Color(0.55, 0.6, 0.7, alpha * 0.40))
		node.draw_circle(b["pos"], BALL_RADIUS + 2.0,
			Color(0.22, 0.24, 0.30, alpha))
		node.draw_circle(b["pos"], BALL_RADIUS,
			Color(0.55, 0.60, 0.70, alpha))
		node.draw_circle(b["pos"], BALL_RADIUS - 4.0,
			Color(c.r * 0.95, c.g * 0.95, c.b * 0.95, alpha))
		# 鉚釘亮點
		node.draw_circle(b["pos"] + Vector2(-3, -4),
			2.0, Color(1, 1, 1, alpha * 0.85))
	else:
		node.draw_circle(b["pos"], BALL_RADIUS + 6.0,
			Color(c.r, c.g, c.b, alpha * 0.35))
		node.draw_circle(b["pos"], BALL_RADIUS, Color(c.r, c.g, c.b, alpha))
		node.draw_circle(b["pos"], BALL_RADIUS - 4.0,
			Color(min(1.0, c.r + 0.4),
				min(1.0, c.g + 0.4),
				min(1.0, c.b + 0.4), alpha))


# ---------------- 技能圖示 UI ----------------
func _build_skill_icons() -> void:
	for i in levelers.size():
		var p = levelers[i]
		var icon: Panel = SKILL_ICON_SCRIPT.new()
		icon.icon_dim = 76.0
		icon.show_header = true
		icon.show_name = true
		icon.show_key = true
		var key_str: String = ("Q" if p.slot_index == 0 else "RShift") + " / X"
		icon.setup(p, "P%d" % (p.slot_index + 1), key_str)
		add_child(icon)
		# 板的左右兩側對稱放置：1P 在板左、2P 在板右
		var center_y: float = board_rect.position.y + (board_rect.end.y - board_rect.position.y) * 0.5 - icon.size.y * 0.5
		if p.slot_index == 0:
			icon.position = Vector2(board_rect.position.x - icon.size.x - 18.0, center_y)
		else:
			icon.position = Vector2(board_rect.end.x + 18.0, center_y)
		skill_icons.append(icon)


# ---------------- 觸控發球按鈕 ----------------
# 每位玩家一顆大按鈕，未發射 / 未結束時顯示，按下注入 b["action"]（p1_action / p2_action）。
# Buttons 都掛 PROCESS_MODE_ALWAYS，因為彈珠台會把整棵 Tree paused。
func _build_touch_launch_buttons() -> void:
	for i in player_balls.size():
		var b: Dictionary = player_balls[i]
		var btn := Button.new()
		btn.text = tr("PINBALL_TOUCH_LAUNCH_FMT") % (int(b["player"].slot_index) + 1)
		btn.add_theme_font_size_override("font_size", 22)
		btn.size = Vector2(260.0, 56.0)
		btn.process_mode = Node.PROCESS_MODE_ALWAYS
		btn.focus_mode = Control.FOCUS_NONE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.16, 0.28, 0.92)
		sb.border_color = Color(0.95, 0.7, 0.3)
		sb.border_width_left = 3
		sb.border_width_right = 3
		sb.border_width_top = 3
		sb.border_width_bottom = 3
		sb.corner_radius_top_left = 10
		sb.corner_radius_top_right = 10
		sb.corner_radius_bottom_left = 10
		sb.corner_radius_bottom_right = 10
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		# 排版：solo 在板下方置中；雙人左右並排
		var center_x: float = board_rect.position.x + board_rect.size.x * 0.5
		var below_y: float = board_rect.end.y + slot_h + 24.0
		if player_balls.size() <= 1:
			btn.position = Vector2(center_x - btn.size.x * 0.5, below_y)
		else:
			var off: float = (float(i) - 0.5) * (btn.size.x + 24.0)
			btn.position = Vector2(center_x - btn.size.x * 0.5 + off, below_y)
		var captured: int = i
		btn.pressed.connect(func() -> void: _on_touch_launch(captured))
		add_child(btn)
		touch_launch_buttons.append(btn)
	_refresh_touch_launch_visibility()


func _on_touch_launch(idx: int) -> void:
	if idx < 0 or idx >= player_balls.size():
		return
	var b: Dictionary = player_balls[idx]
	if b["launched"] or b["finished"]:
		return
	# 注入一幀的按下訊號，由 _process 內既有的 just_pressed 偵測接手 _launch_ball
	Input.action_press(b["action"])
	await get_tree().process_frame
	Input.action_release(b["action"])


func _refresh_touch_launch_visibility() -> void:
	if touch_launch_buttons.is_empty():
		return
	var on: bool = bool(GameState.touch_controls_enabled)
	for i in touch_launch_buttons.size():
		if i >= player_balls.size():
			continue
		var btn: Button = touch_launch_buttons[i]
		if btn == null:
			continue
		var b: Dictionary = player_balls[i]
		var show: bool = on and not b["launched"] and not b["finished"]
		if btn.visible != show:
			btn.visible = show


func _close_in(seconds: float) -> void:
	if _closing: return
	_closing = true
	# 把這場彈珠台的撞針分數結轉到對應玩家（用於戰鬥結算）
	for p in levelers:
		if p == null:
			continue
		var sc: int = int(player_scores.get(p, 0))
		if sc > 0 and p.has_method("add_pinball_score"):
			p.call("add_pinball_score", sc)
	await get_tree().create_timer(seconds, true, false, true).timeout
	get_tree().paused = false
	queue_free()
