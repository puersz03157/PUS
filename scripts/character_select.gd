extends Control
## 角色選擇：P1 鍵盤 WASD + Space / Q；P2 方向鍵 + Enter / RShift。
## 手把：1P = 裝置 0（左搖桿／十字鍵 + A 確認 + B 取消）；2P = 裝置 1。
##
## 操作：
##   左/右   切換目前焦點欄（角色 / 被動 / 技能）的選項
##   上/下   切換焦點欄
##   確認鍵  完成選擇
##   取消鍵  解除 Ready，或回到主選單

const FOCUS_CHARACTER := 0
const FOCUS_PASSIVE := 1
const FOCUS_SKILL := 2

@onready var p1_panel: Panel = $P1Panel
@onready var p2_panel: Panel = $P2Panel
@onready var p1_name: Label = $P1Panel/Name
@onready var p1_desc: Label = $P1Panel/Desc
@onready var p1_stats: Label = $P1Panel/Stats
@onready var p1_passive: Label = $P1Panel/Passive
@onready var p1_skill: Label = $P1Panel/Skill
@onready var p1_passive_icon: TextureRect = $P1Panel/PassiveIcon
@onready var p1_skill_icon: TextureRect = $P1Panel/SkillIcon
@onready var p1_color: ColorRect = $P1Panel/Color
@onready var p1_preview: TextureRect = $P1Panel/Color/Preview
@onready var p2_name: Label = $P2Panel/Name
@onready var p2_desc: Label = $P2Panel/Desc
@onready var p2_stats: Label = $P2Panel/Stats
@onready var p2_passive: Label = $P2Panel/Passive
@onready var p2_skill: Label = $P2Panel/Skill
@onready var p2_passive_icon: TextureRect = $P2Panel/PassiveIcon
@onready var p2_skill_icon: TextureRect = $P2Panel/SkillIcon
@onready var p2_color: ColorRect = $P2Panel/Color
@onready var p2_preview: TextureRect = $P2Panel/Color/Preview
@onready var hint_label: Label = $HintLabel
@onready var ready_label: Label = $ReadyLabel
@onready var title_label: Label = $Title

var p1_index: int = 0
var p1_passive_idx: int = 0
var p1_skill_idx: int = 0
var p1_focus: int = FOCUS_CHARACTER

var p2_index: int = 1
var p2_passive_idx: int = 0
var p2_skill_idx: int = 0
var p2_focus: int = FOCUS_CHARACTER

var p1_ready: bool = false
var p2_ready: bool = false
var input_cooldown: float = 0.0
var _transitioning: bool = false  # 已開始切場景，避免重入導致 get_tree() == null

const P1_PANEL_WIDTH := 400.0  # 與 CharacterSelect.tscn 中 P1Panel 寬度一致 (480 - 80)
const PANEL_OFFSET_TOP := -270.0
const PANEL_OFFSET_BOTTOM := 250.0

# ----- 觸控介面（手機 / 網頁版） -----
var _touch_p1: Control = null
var _touch_p2: Control = null
var _touch_focus_btns_p1: Array[Button] = []
var _touch_focus_btns_p2: Array[Button] = []
var _touch_ready_btn_p1: Button = null
var _touch_ready_btn_p2: Button = null
var _touch_back_btn: Button = null
var _last_touch_enabled: bool = false


func _ready() -> void:
	p2_panel.visible = GameState.two_players
	p1_index = 0
	p2_index = 1 % GameData.CHARACTERS.size()
	if title_label:
		title_label.text = tr("CSEL_TITLE_VILLAGE") if GameState.next_scene == "village" else tr("CSEL_TITLE_BATTLE")
	_apply_panel_layout()
	_build_touch_controls()
	_update_panels()
	_apply_touch_visibility()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_panel_layout()


## 單人時將 P1 資訊卡水平置中；雙人維持左右並排。
func _apply_panel_layout() -> void:
	if p1_panel == null or p2_panel == null:
		return
	if GameState.two_players:
		p1_panel.anchor_left = 0.0
		p1_panel.anchor_right = 0.0
		p1_panel.anchor_top = 0.5
		p1_panel.anchor_bottom = 0.5
		p1_panel.offset_left = 80.0
		p1_panel.offset_right = 480.0
		p1_panel.offset_top = PANEL_OFFSET_TOP
		p1_panel.offset_bottom = PANEL_OFFSET_BOTTOM
		p2_panel.anchor_left = 0.0
		p2_panel.anchor_right = 0.0
		p2_panel.anchor_top = 0.5
		p2_panel.anchor_bottom = 0.5
		p2_panel.offset_left = 720.0
		p2_panel.offset_right = 1120.0
		p2_panel.offset_top = PANEL_OFFSET_TOP
		p2_panel.offset_bottom = PANEL_OFFSET_BOTTOM
	else:
		var half_w: float = P1_PANEL_WIDTH * 0.5
		p1_panel.anchor_left = 0.5
		p1_panel.anchor_right = 0.5
		p1_panel.anchor_top = 0.5
		p1_panel.anchor_bottom = 0.5
		p1_panel.offset_left = -half_w
		p1_panel.offset_right = half_w
		p1_panel.offset_top = PANEL_OFFSET_TOP
		p1_panel.offset_bottom = PANEL_OFFSET_BOTTOM


func _process(delta: float) -> void:
	if _transitioning:
		return
	# 設定面板切換觸控時，即時更新可見性
	if bool(GameState.touch_controls_enabled) != _last_touch_enabled:
		_apply_touch_visibility()
	input_cooldown = max(0.0, input_cooldown - delta)
	if input_cooldown > 0.0:
		return

	# P1
	if not p1_ready:
		_handle_player_input("p1")
		if Input.is_action_just_pressed("p1_action"):
			p1_ready = true
	else:
		if Input.is_action_just_pressed("p1_skill"):
			p1_ready = false

	# P2
	if GameState.two_players:
		if not p2_ready:
			_handle_player_input("p2")
			if Input.is_action_just_pressed("p2_action"):
				p2_ready = true
		else:
			if Input.is_action_just_pressed("p2_skill"):
				p2_ready = false

	_update_panels()

	# 全部 Ready 即進入遊戲 / 村莊
	var all_ready: bool = p1_ready and (not GameState.two_players or p2_ready)
	if all_ready:
		_save_selections()
		_transitioning = true
		await get_tree().create_timer(0.3).timeout
		# await 後節點可能已被切走，先確認還活著
		if not is_inside_tree():
			return
		var path: String = "res://scenes/Game.tscn"
		if GameState.next_scene == "village":
			path = "res://scenes/Village.tscn"
		get_tree().change_scene_to_file(path)
		return

	if Input.is_action_just_pressed("ui_back"):
		_transitioning = true
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
		return


func _handle_player_input(prefix: String) -> void:
	# 上下：切換焦點欄
	if Input.is_action_just_pressed(prefix + "_up"):
		_set_focus(prefix, _focus_for(prefix) - 1)
		input_cooldown = 0.15
		return
	if Input.is_action_just_pressed(prefix + "_down"):
		_set_focus(prefix, _focus_for(prefix) + 1)
		input_cooldown = 0.15
		return
	# 左右：根據焦點欄循環選項
	if Input.is_action_just_pressed(prefix + "_left"):
		_cycle_focus(prefix, -1)
		input_cooldown = 0.15
	elif Input.is_action_just_pressed(prefix + "_right"):
		_cycle_focus(prefix, +1)
		input_cooldown = 0.15


func _focus_for(prefix: String) -> int:
	return p1_focus if prefix == "p1" else p2_focus


func _set_focus(prefix: String, new_focus: int) -> void:
	new_focus = (new_focus + 3) % 3
	if prefix == "p1":
		p1_focus = new_focus
	else:
		p2_focus = new_focus


func _cycle_focus(prefix: String, dir: int) -> void:
	var focus: int = _focus_for(prefix)
	match focus:
		FOCUS_CHARACTER:
			var n: int = GameData.CHARACTERS.size()
			if prefix == "p1":
				p1_index = (p1_index + dir + n) % n
				_clamp_options("p1")
			else:
				p2_index = (p2_index + dir + n) % n
				_clamp_options("p2")
		FOCUS_PASSIVE:
			var opts: Array = GameData.character_passive_options(_current_char_id(prefix))
			if opts.size() > 0:
				if prefix == "p1":
					p1_passive_idx = (p1_passive_idx + dir + opts.size()) % opts.size()
				else:
					p2_passive_idx = (p2_passive_idx + dir + opts.size()) % opts.size()
		FOCUS_SKILL:
			var opts: Array = GameData.character_skill_options(_current_char_id(prefix))
			if opts.size() > 0:
				if prefix == "p1":
					p1_skill_idx = (p1_skill_idx + dir + opts.size()) % opts.size()
				else:
					p2_skill_idx = (p2_skill_idx + dir + opts.size()) % opts.size()


func _current_char_id(prefix: String) -> String:
	var idx: int = p1_index if prefix == "p1" else p2_index
	return GameData.CHARACTERS[idx]["id"]


func _clamp_options(prefix: String) -> void:
	# 換角色時，若新角色的選項清單較短就退回 0
	var pop: Array = GameData.character_passive_options(_current_char_id(prefix))
	var sop: Array = GameData.character_skill_options(_current_char_id(prefix))
	if prefix == "p1":
		if p1_passive_idx >= pop.size():
			p1_passive_idx = 0
		if p1_skill_idx >= sop.size():
			p1_skill_idx = 0
	else:
		if p2_passive_idx >= pop.size():
			p2_passive_idx = 0
		if p2_skill_idx >= sop.size():
			p2_skill_idx = 0


func _save_selections() -> void:
	GameState.p1_character = GameData.CHARACTERS[p1_index]["id"]
	var p1_pop: Array = GameData.character_passive_options(_current_char_id("p1"))
	var p1_sop: Array = GameData.character_skill_options(_current_char_id("p1"))
	GameState.p1_passive = String(p1_pop[p1_passive_idx]) if p1_pop.size() > 0 else "none"
	GameState.p1_skill = String(p1_sop[p1_skill_idx]) if p1_sop.size() > 0 else "none"
	if GameState.two_players:
		GameState.p2_character = GameData.CHARACTERS[p2_index]["id"]
		var p2_pop: Array = GameData.character_passive_options(_current_char_id("p2"))
		var p2_sop: Array = GameData.character_skill_options(_current_char_id("p2"))
		GameState.p2_passive = String(p2_pop[p2_passive_idx]) if p2_pop.size() > 0 else "none"
		GameState.p2_skill = String(p2_sop[p2_skill_idx]) if p2_sop.size() > 0 else "none"


func _update_panels() -> void:
	_apply_panel(p1_index, p1_passive_idx, p1_skill_idx, p1_focus, p1_ready,
		p1_name, p1_desc, p1_stats, p1_passive, p1_skill,
		p1_passive_icon, p1_skill_icon,
		p1_color, p1_preview, p1_panel)
	if GameState.two_players:
		_apply_panel(p2_index, p2_passive_idx, p2_skill_idx, p2_focus, p2_ready,
			p2_name, p2_desc, p2_stats, p2_passive, p2_skill,
			p2_passive_icon, p2_skill_icon,
			p2_color, p2_preview, p2_panel)
	hint_label.text = _hint_text()
	if bool(GameState.touch_controls_enabled):
		_refresh_touch_buttons()
	# 副標題僅在「準備中／完成」時顯示，避免與 Title 重複同一句「選擇你的角色」
	if ready_label:
		if p1_ready and (not GameState.two_players or p2_ready):
			ready_label.visible = true
			ready_label.text = tr("CSEL_READY_DONE")
		elif p1_ready or p2_ready:
			ready_label.visible = true
			ready_label.text = tr("CSEL_READY_WAITING")
		else:
			ready_label.text = ""
			ready_label.visible = false


func _apply_panel(idx: int, passive_idx: int, skill_idx: int, focus: int, ready: bool,
		n: Label, d: Label, s: Label, p_lbl: Label, sk_lbl: Label,
		p_icon: TextureRect, sk_icon: TextureRect,
		col: ColorRect, prev: TextureRect, pnl: Panel) -> void:
	var c: Dictionary = GameData.CHARACTERS[idx]
	# 角色名（focus 在角色欄時加 ◀ ▶ 提示）
	var name_text: String = tr("CSEL_NAME_FMT") % [
		GameData.tr_name(c), GameData.tr_rarity(String(c["rarity"]))]
	if not ready and focus == FOCUS_CHARACTER:
		name_text = tr("CSEL_NAME_FOCUS_FMT") % name_text
	n.text = name_text
	s.text = (tr("CSEL_STATS_FMT").replace("\\n", "\n")) % [
		c["hp"], c["atk"], c["def"], c["spd"],
		GameData.tr_weapon_name(String(c["weapon"]))]
	col.color = c["color"]

	# 被動 / 技能：標題行 + 描述同時顯示在同一個 Label 內（多行 + autowrap）
	var pop: Array = GameData.character_passive_options(c["id"])
	var sop: Array = GameData.character_skill_options(c["id"])
	var p_id: String = String(pop[passive_idx]) if pop.size() > 0 else "none"
	var s_id: String = String(sop[skill_idx]) if sop.size() > 0 else "none"
	var p_def: Dictionary = GameData.get_passive_def(p_id)
	var s_def: Dictionary = GameData.get_skill_def(s_id)

	var p_title: String = _row_text(tr("CSEL_PASSIVE_LBL"), GameData.tr_name(p_def),
		pop.size() > 1, focus == FOCUS_PASSIVE and not ready)
	var p_desc_text: String = GameData.tr_desc(p_def)
	p_lbl.text = "%s\n%s" % [p_title, p_desc_text]
	p_lbl.modulate = Color(1, 1, 1) if (focus == FOCUS_PASSIVE and not ready) else Color(0.7, 0.78, 0.92)

	var s_title: String = _row_text(tr("CSEL_SKILL_LBL"), GameData.tr_name(s_def),
		sop.size() > 1, focus == FOCUS_SKILL and not ready)
	var s_desc_text: String = ""
	if String(s_id) == "none":
		s_desc_text = GameData.tr_desc(s_def)
	else:
		var cd_s: int = int(round(float(s_def.get("cooldown", 0.0))))
		s_desc_text = tr("CSEL_SKILL_CD_DESC_FMT") % [cd_s, GameData.tr_desc(s_def)]
	sk_lbl.text = "%s\n%s" % [s_title, s_desc_text]
	sk_lbl.modulate = Color(1, 1, 1) if (focus == FOCUS_SKILL and not ready) else Color(0.7, 0.78, 0.92)

	# 被動 / 技能小圖示（id=none 或檔案缺失時自動隱藏）
	if p_icon:
		var p_tex: Texture2D = GameData.load_passive_icon(p_id)
		p_icon.texture = p_tex
		p_icon.visible = p_tex != null
	if sk_icon:
		var sk_tex: Texture2D = GameData.load_skill_icon(s_id)
		sk_icon.texture = sk_tex
		sk_icon.visible = sk_tex != null

	# 角色介紹：固定顯示在最下方（不再隨焦點切換成被動／技能描述）
	d.text = GameData.tr_desc(c)
	d.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

	# 角色貼圖預覽 — 32x32 美術用最近鄰 + 整數倍縮放，避免上採樣糊掉
	if prev:
		if c.has("sprite") and String(c["sprite"]) != "":
			var atlas: Texture2D = load(c["sprite"])
			if atlas:
				var hf: int = max(1, int(c.get("hframes", 1)))
				var vf: int = max(1, int(c.get("vframes", 1)))
				var fw: int = atlas.get_width() / hf
				var fh: int = atlas.get_height() / vf
				var prow: int = clamp(int(c.get("preview_row", c.get("row_idle", 0))), 0, vf - 1)
				var pcol: int = clamp(int(c.get("preview_col", 0)), 0, hf - 1)
				var trim_t: int = clamp(int(c.get("preview_trim_top", 14)), 0, fh - 4)
				var trim_b: int = clamp(int(c.get("preview_trim_bottom", 1)), 0, fh - trim_t - 4)
				var trim_l: int = clamp(int(c.get("preview_trim_left", 4)), 0, fw - 4)
				var trim_r: int = clamp(int(c.get("preview_trim_right", 4)), 0, fw - trim_l - 4)
				var rx: float = pcol * fw + trim_l
				var ry: float = prow * fh + trim_t
				var rw: float = max(1.0, fw - trim_l - trim_r)
				var rh: float = max(1.0, fh - trim_t - trim_b)
				var at := AtlasTexture.new()
				at.atlas = atlas
				at.region = Rect2(rx, ry, rw, rh)
				prev.texture = at
				prev.modulate = c.get("tint", Color.WHITE)
				prev.visible = true
				prev.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				_apply_integer_scale_preview(prev, rw, rh)
		else:
			prev.texture = null
			prev.visible = false

	var sb := pnl.get_theme_stylebox("panel") as StyleBoxFlat
	if sb == null:
		sb = StyleBoxFlat.new()
		pnl.add_theme_stylebox_override("panel", sb)
	sb.bg_color = Color(0.06, 0.08, 0.18, 1.0)
	sb.border_color = Color(0.2, 0.95, 0.5) if ready else Color(0.95, 0.7, 0.3)
	sb.border_width_left = 4
	sb.border_width_right = 4
	sb.border_width_top = 4
	sb.border_width_bottom = 4
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10


# 把 TextureRect 改用「整數倍」尺寸並置中於父容器，避免非整數倍縮放造成像素寬窄不一
func _apply_integer_scale_preview(prev: TextureRect, src_w: float, src_h: float) -> void:
	var parent: Control = prev.get_parent() as Control
	if parent == null:
		return
	var pw: float = parent.size.x
	var ph: float = parent.size.y
	if pw <= 0.0 or ph <= 0.0:
		# 父尺寸還沒就緒就用 .tscn 設的尺寸 (P1Panel/Color = 130x130)
		pw = 130.0
		ph = 130.0
	# 預留邊框留白：取父尺寸的 92%
	var avail_w: float = pw * 0.92
	var avail_h: float = ph * 0.92
	var max_int_scale: int = max(1, min(int(avail_w / src_w), int(avail_h / src_h)))
	var disp_w: float = src_w * max_int_scale
	var disp_h: float = src_h * max_int_scale
	# 解掉錨點（.tscn 預設 anchors_preset=15 會撐滿父層），改用絕對 size + position
	prev.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	prev.size = Vector2(disp_w, disp_h)
	prev.position = Vector2((pw - disp_w) * 0.5, (ph - disp_h) * 0.5)
	# 因為 rect 是「source × N」整數倍 + NEAREST，用 STRETCH_SCALE 讓貼圖填滿 rect
	# 等於每個 source pixel 變成 N×N 顯示像素（pixel-perfect）
	prev.stretch_mode = TextureRect.STRETCH_SCALE
	prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE


func _row_text(label: String, value: String, multi: bool, focused: bool) -> String:
	# 焦點且有多選時顯示箭頭，否則只顯示文字
	if focused and multi:
		return tr("CSEL_ROW_FOCUS_MULTI_FMT") % [label, value]
	if focused:
		return tr("CSEL_ROW_FOCUS_FMT") % [label, value]
	return tr("CSEL_ROW_FMT") % [label, value]


func _hint_text() -> String:
	var line1: String = tr("CSEL_HINT_LR")
	if GameState.two_players:
		return line1 + "\n" + tr("CSEL_HINT_DUO")
	return line1 + "\n" + tr("CSEL_HINT_SOLO")


# ============================================================================
# 觸控介面（手機 / 網頁版）
# - 每個面板下方一條觸控列：[角色][被動][技能] tab + ◀ ▶ 循環 + 出發 / 解除
# - 左上角一顆「← 主選單」按鈕
# - 與 GameState.touch_controls_enabled 連動，可在執行時開關
# ============================================================================
func _build_touch_controls() -> void:
	if p1_panel:
		_touch_p1 = _make_panel_touch_bar("p1")
		p1_panel.add_child(_touch_p1)
	if p2_panel:
		_touch_p2 = _make_panel_touch_bar("p2")
		p2_panel.add_child(_touch_p2)

	_touch_back_btn = Button.new()
	_touch_back_btn.text = tr("CSEL_TOUCH_BACK")
	_touch_back_btn.size = Vector2(160, 44)
	_touch_back_btn.position = Vector2(16, 16)
	_touch_back_btn.add_theme_font_size_override("font_size", 16)
	_touch_back_btn.focus_mode = Control.FOCUS_NONE
	_touch_back_btn.pressed.connect(_on_touch_back)
	add_child(_touch_back_btn)


func _make_panel_touch_bar(prefix: String) -> Control:
	# 面板寬 400、高 520（offset_top -270 ~ offset_bottom 250）；
	# 我們把觸控列放在面板「正下方」(local y >= 525) — Panel 不裁切，子物件可超出。
	var bar := Control.new()
	bar.name = "TouchBar_" + prefix
	bar.size = Vector2(P1_PANEL_WIDTH, 96)
	bar.position = Vector2(0, 525)
	bar.mouse_filter = Control.MOUSE_FILTER_PASS

	# Row 1：角色 / 被動 / 技能 tab
	var tab_row := HBoxContainer.new()
	tab_row.position = Vector2(8, 0)
	tab_row.size = Vector2(P1_PANEL_WIDTH - 16, 38)
	tab_row.add_theme_constant_override("separation", 6)
	bar.add_child(tab_row)

	var labels: Array = [
		tr("CSEL_TOUCH_FOCUS_CHAR"),
		tr("CSEL_TOUCH_FOCUS_PASSIVE"),
		tr("CSEL_TOUCH_FOCUS_SKILL"),
	]
	var btns: Array[Button] = []
	for i in range(3):
		var b := Button.new()
		b.text = String(labels[i])
		b.custom_minimum_size = Vector2((P1_PANEL_WIDTH - 28) / 3.0, 38)
		b.add_theme_font_size_override("font_size", 14)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_touch_focus.bind(prefix, i))
		tab_row.add_child(b)
		btns.append(b)
	if prefix == "p1":
		_touch_focus_btns_p1 = btns
	else:
		_touch_focus_btns_p2 = btns

	# Row 2：◀ ▶ 與 出發
	var op_row := HBoxContainer.new()
	op_row.position = Vector2(8, 46)
	op_row.size = Vector2(P1_PANEL_WIDTH - 16, 46)
	op_row.add_theme_constant_override("separation", 8)
	bar.add_child(op_row)

	var btn_left := Button.new()
	btn_left.text = "◀"
	btn_left.custom_minimum_size = Vector2(72, 46)
	btn_left.add_theme_font_size_override("font_size", 22)
	btn_left.focus_mode = Control.FOCUS_NONE
	btn_left.pressed.connect(_on_touch_cycle.bind(prefix, -1))
	op_row.add_child(btn_left)

	var btn_right := Button.new()
	btn_right.text = "▶"
	btn_right.custom_minimum_size = Vector2(72, 46)
	btn_right.add_theme_font_size_override("font_size", 22)
	btn_right.focus_mode = Control.FOCUS_NONE
	btn_right.pressed.connect(_on_touch_cycle.bind(prefix, 1))
	op_row.add_child(btn_right)

	var ready_btn := Button.new()
	ready_btn.text = tr("CSEL_TOUCH_READY")
	ready_btn.custom_minimum_size = Vector2(P1_PANEL_WIDTH - 16 - 72 - 72 - 16, 46)
	ready_btn.add_theme_font_size_override("font_size", 18)
	ready_btn.focus_mode = Control.FOCUS_NONE
	ready_btn.pressed.connect(_on_touch_ready.bind(prefix))
	op_row.add_child(ready_btn)
	if prefix == "p1":
		_touch_ready_btn_p1 = ready_btn
	else:
		_touch_ready_btn_p2 = ready_btn

	return bar


func _apply_touch_visibility() -> void:
	var on: bool = bool(GameState.touch_controls_enabled)
	_last_touch_enabled = on
	if _touch_p1:
		_touch_p1.visible = on
	if _touch_p2:
		_touch_p2.visible = on and GameState.two_players
	if _touch_back_btn:
		_touch_back_btn.visible = on
	if hint_label:
		hint_label.visible = not on
	if on:
		_refresh_touch_buttons()


func _refresh_touch_buttons() -> void:
	_refresh_focus_btns(_touch_focus_btns_p1, p1_focus, p1_ready)
	if _touch_ready_btn_p1:
		_touch_ready_btn_p1.text = tr("CSEL_TOUCH_UNREADY") if p1_ready else tr("CSEL_TOUCH_READY")
		_touch_ready_btn_p1.modulate = Color(0.85, 1.0, 0.85) if not p1_ready else Color(1.0, 0.85, 0.85)
	if GameState.two_players:
		_refresh_focus_btns(_touch_focus_btns_p2, p2_focus, p2_ready)
		if _touch_ready_btn_p2:
			_touch_ready_btn_p2.text = tr("CSEL_TOUCH_UNREADY") if p2_ready else tr("CSEL_TOUCH_READY")
			_touch_ready_btn_p2.modulate = Color(0.85, 1.0, 0.85) if not p2_ready else Color(1.0, 0.85, 0.85)


func _refresh_focus_btns(btns: Array[Button], focus: int, ready: bool) -> void:
	for i in range(btns.size()):
		var b: Button = btns[i]
		if b == null:
			continue
		b.disabled = ready
		b.modulate = Color(1, 0.92, 0.5) if (i == focus and not ready) else Color(0.85, 0.88, 0.95)


func _on_touch_focus(prefix: String, idx: int) -> void:
	if (prefix == "p1" and p1_ready) or (prefix == "p2" and p2_ready):
		return
	_set_focus(prefix, idx)
	_update_panels()


func _on_touch_cycle(prefix: String, dir: int) -> void:
	if (prefix == "p1" and p1_ready) or (prefix == "p2" and p2_ready):
		return
	_cycle_focus(prefix, dir)
	_update_panels()


func _on_touch_ready(prefix: String) -> void:
	if prefix == "p1":
		p1_ready = not p1_ready
	else:
		p2_ready = not p2_ready
	_update_panels()


func _on_touch_back() -> void:
	if _transitioning:
		return
	_transitioning = true
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
