extends CanvasLayer
## 暫停選單：ESC 開關，顯示遊戲狀態，可繼續或中途回村莊（帶當前進度結算）。
## 在 Game.tscn 中作為 Game 的子節點。

const RESPONSE_KEYS := ["ui_back"]
const WEAPON_SLOT_MAX := 5
const PANEL_W := 900.0
const PANEL_H_SOLO := 640.0
const PANEL_H_DUO := 720.0
const PANEL_HEADER_H := 58.0
const PANEL_FOOTER_H := 84.0
const PANEL_PAD := 20.0

var open_state: bool = false
var game_ref: Node = null
var _transitioning: bool = false

var background: ColorRect
var panel: Panel
var title_label: Label
var content_scroll: ScrollContainer
var content_root: VBoxContainer
var resume_button: Button
var menu_button: Button
var _weapon_tip_wrap: PanelContainer
var _weapon_tip_label: Label


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	game_ref = get_parent()
	_build_ui()
	_set_open(false)


func _process(_delta: float) -> void:
	if _transitioning:
		return
	for k in RESPONSE_KEYS:
		if Input.is_action_just_pressed(k):
			# 彈珠台進行中時不處理（彈珠台自己會在升級流程結束時關閉）
			if game_ref and game_ref.get("pinball_active"):
				return
			toggle()
			return


func toggle() -> void:
	AudioManager.play_sfx("ui_back" if open_state else "ui_select")
	_set_open(not open_state)


func _set_open(v: bool) -> void:
	open_state = v
	visible = v
	get_tree().paused = v
	if not v:
		_hide_weapon_tip()
	if v:
		_layout_pause_panel(get_viewport().get_visible_rect().size)
		_refresh_stats()
		resume_button.grab_focus()


# ---------------- UI 建構 ----------------
func _build_ui() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size

	background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.6)
	background.size = vp
	background.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(background)

	panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.18, 1.0)
	sb.border_color = Color(0.95, 0.65, 0.18)
	sb.border_width_left = 4
	sb.border_width_right = 4
	sb.border_width_top = 4
	sb.border_width_bottom = 4
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	title_label = Label.new()
	title_label.text = tr("PAUSE_TITLE")
	title_label.position = Vector2(0, 14)
	title_label.size = Vector2(PANEL_W, 40)
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title_label)

	content_scroll = ScrollContainer.new()
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel.add_child(content_scroll)

	content_root = VBoxContainer.new()
	content_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_root.add_theme_constant_override("separation", 8)
	content_scroll.add_child(content_root)

	resume_button = Button.new()
	resume_button.text = tr("PAUSE_BTN_RESUME")
	resume_button.size = Vector2(240, 48)
	resume_button.add_theme_font_size_override("font_size", 18)
	resume_button.process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.pressed.connect(_on_resume)
	panel.add_child(resume_button)

	menu_button = Button.new()
	menu_button.text = tr("PAUSE_BTN_VILLAGE")
	menu_button.size = Vector2(240, 48)
	menu_button.add_theme_font_size_override("font_size", 18)
	menu_button.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_button.pressed.connect(_on_retreat_village)
	panel.add_child(menu_button)

	_build_weapon_tip_popup()

	_layout_pause_panel(vp)
	if not get_viewport().size_changed.is_connected(_layout_pause_panel):
		get_viewport().size_changed.connect(_layout_pause_panel)


func _pause_panel_height(vp: Vector2) -> float:
	var duo: bool = false
	if game_ref != null:
		var players: Array = game_ref.get("players")
		duo = players.size() >= 2
	var h: float = PANEL_H_DUO if duo else PANEL_H_SOLO
	return minf(h, maxf(PANEL_H_SOLO, vp.y - 48.0))


func _layout_pause_panel(vp: Vector2 = Vector2.ZERO) -> void:
	if panel == null or content_scroll == null:
		return
	if vp == Vector2.ZERO:
		vp = get_viewport().get_visible_rect().size
	background.size = vp
	var panel_w: float = minf(PANEL_W, vp.x - 32.0)
	var panel_h: float = _pause_panel_height(vp)
	panel.position = Vector2((vp.x - panel_w) * 0.5, (vp.y - panel_h) * 0.5)
	panel.size = Vector2(panel_w, panel_h)
	title_label.size.x = panel_w
	var content_h: float = maxf(120.0, panel_h - PANEL_HEADER_H - PANEL_FOOTER_H - 8.0)
	content_scroll.position = Vector2(PANEL_PAD, PANEL_HEADER_H)
	content_scroll.size = Vector2(panel_w - PANEL_PAD * 2.0, content_h)
	var btn_y: float = panel_h - PANEL_FOOTER_H + 18.0
	resume_button.position = Vector2(140.0, btn_y)
	menu_button.position = Vector2(panel_w - 240.0 - 140.0, btn_y)


func _on_resume() -> void:
	AudioManager.play_sfx("ui_confirm")
	_set_open(false)


func _on_retreat_village() -> void:
	if game_ref == null:
		return
	if bool(game_ref.get("pinball_active")):
		return
	if game_ref.has_method("_is_test_arena_stage") and game_ref._is_test_arena_stage():
		return
	_transitioning = true
	get_tree().paused = false
	AudioManager.play_sfx("ui_back")
	if is_inside_tree() and game_ref.has_method("retreat_to_village_with_summary"):
		game_ref.retreat_to_village_with_summary()
	elif is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/Village.tscn")


# ---------------- 重新整理顯示 ----------------
func _refresh_stats() -> void:
	if game_ref == null or content_root == null:
		return
	for c in content_root.get_children():
		c.queue_free()

	var run_time: float = float(game_ref.get("run_time"))
	var team_level: int = int(game_ref.get("team_level"))
	var team_xp: float = float(game_ref.get("team_xp"))
	var team_xp_to_next: float = float(game_ref.get("team_xp_to_next"))
	var players: Array = game_ref.get("players")

	var header := RichTextLabel.new()
	header.bbcode_enabled = true
	header.fit_content = true
	header.scroll_active = false
	header.custom_minimum_size = Vector2(0, 26)
	header.text = tr("PAUSE_HEADER_FMT") % [
		int(run_time / 60), int(run_time) % 60, team_level, int(team_xp), int(team_xp_to_next)]
	content_root.add_child(header)

	for p in players:
		if p == null:
			continue
		_build_player_section(p)
	var hide_village: bool = false
	if game_ref.has_method("_is_test_arena_stage"):
		hide_village = game_ref._is_test_arena_stage()
	menu_button.visible = not hide_village
	menu_button.disabled = bool(game_ref.get("pinball_active"))
	_layout_pause_panel()


func _build_player_section(p: Node) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.2, 0.7)
	sb.border_color = Color(0.32, 0.42, 0.6)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6

	var wrap := PanelContainer.new()
	wrap.add_theme_stylebox_override("panel", sb)
	content_root.add_child(wrap)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	wrap.add_child(inner)

	var c_def: Dictionary = GameData.get_character_def(p.character_id)
	var passive_def: Dictionary = GameData.get_passive_def(String(p.passive_id))
	var skill_def: Dictionary = GameData.get_skill_def(String(p.skill_id))

	# 頭部：P1 角色名 / HP / 擊殺
	var header := RichTextLabel.new()
	header.bbcode_enabled = true
	header.fit_content = true
	header.scroll_active = false
	header.custom_minimum_size = Vector2(0, 28)
	header.text = tr("PAUSE_PLAYER_HEADER_FMT") % [
		p.slot_index + 1,
		c_def["color"].to_html(false),
		GameData.tr_name(c_def),
		int(p.hp), int(_effective_max_hp(p)), p.kills]
	inner.add_child(header)

	_build_live_stat_section(inner, p, c_def)

	# 技能 / 被動：兩個有 label 的格子
	var sk_pa_row := HBoxContainer.new()
	sk_pa_row.add_theme_constant_override("separation", 12)
	inner.add_child(sk_pa_row)

	sk_pa_row.add_child(_make_caption(tr("CSEL_SKILL_LBL"), 50))
	var has_skill: bool = String(p.skill_id) != "none" and not skill_def.is_empty()
	var skill_text: String = GameData.tr_name(skill_def) if has_skill else "—"
	var sk_tex: Texture2D = GameData.load_skill_icon(String(p.skill_id))
	sk_pa_row.add_child(_make_slot_with_icon(skill_text, has_skill,
		Color(0.85, 0.55, 1.0), 220, 36, 14, sk_tex))

	sk_pa_row.add_child(_make_caption(tr("CSEL_PASSIVE_LBL"), 50))
	var has_passive: bool = String(p.passive_id) != "none" and not passive_def.is_empty()
	var passive_text: String = GameData.tr_name(passive_def) if has_passive else "—"
	var pa_tex: Texture2D = GameData.load_passive_icon(String(p.passive_id))
	sk_pa_row.add_child(_make_slot_with_icon(passive_text, has_passive,
		Color(1.0, 0.7, 0.4), 220, 36, 14, pa_tex))

	# 武器格 — 標題 + 8 格陣列
	var weapon_count: int = p.weapons.size()
	var weapon_cap: int = p.get_weapon_slot_max() if p.has_method("get_weapon_slot_max") else WEAPON_SLOT_MAX
	var w_caption := Label.new()
	var cap_color: Color = Color(0.95, 0.85, 0.5)
	if weapon_count >= weapon_cap:
		cap_color = Color(1.0, 0.6, 0.5)
	w_caption.text = tr("PAUSE_WEAPON_CAP_FMT") % [
		weapon_count, weapon_cap,
		tr("PAUSE_WEAPON_FULL_NOTE") if weapon_count >= weapon_cap else ""]
	w_caption.add_theme_font_size_override("font_size", 14)
	w_caption.add_theme_color_override("font_color", cap_color)
	inner.add_child(w_caption)

	var w_row := HBoxContainer.new()
	w_row.add_theme_constant_override("separation", 4)
	inner.add_child(w_row)
	for i in weapon_cap:
		if i < weapon_count:
			var w: Dictionary = p.weapons[i]
			var wid: String = String(w.get("id", ""))
			var wdef: Dictionary = GameData.get_weapon_def(wid)
			var name_str: String = (tr("PAUSE_WEAPON_NAME_LV_FMT").replace("\\n", "\n")) % [
				GameData.tr_name(wdef), int(w["level"])]
			var w_tex: Texture2D = GameData.load_weapon_icon(wid)
			var w_slot: Panel = _make_slot_with_icon(name_str, true,
				Color(0.55, 0.95, 0.6), 96, 44, 11, w_tex)
			var tip_text: String = GameData.format_weapon_upgrades_tooltip(w)
			if tip_text != "":
				_wire_weapon_slot_tip(w_slot, tip_text)
			w_row.add_child(w_slot)
		else:
			w_row.add_child(_make_slot(tr("PAUSE_SLOT_EMPTY"), false,
				Color(0.4, 0.4, 0.5), 96, 44, 12))

	_build_common_upgrade_slots(inner, p)


func _build_live_stat_section(inner: VBoxContainer, p: Node, c_def: Dictionary) -> void:
	var stat := RichTextLabel.new()
	stat.bbcode_enabled = true
	stat.fit_content = true
	stat.scroll_active = false
	stat.custom_minimum_size = Vector2(0, 28)
	stat.add_theme_font_size_override("normal_font_size", 13)
	stat.text = _live_stat_text(p, c_def)
	inner.add_child(stat)


func _live_stat_text(p: Node, _c_def: Dictionary) -> String:
	var effective_hp: float = _effective_max_hp(p)
	var effective_atk: float = _call_float(p, "get_effective_atk_power", p.atk * p.damage_mult)
	var dmg_mult_pct: int = int(round(
		_call_float(p, "get_effective_damage_mult", p.damage_mult) * 100.0))
	var effective_def: float = _call_float(p, "get_effective_def", p.def_value)
	var effective_rate: float = _call_float(p, "get_effective_rate_mult", p.rate_mult)
	var effective_move: float = _call_float(p, "get_effective_move_speed", p.move_speed * p.speed_mult)
	var parts: Array[String] = []
	parts.append(GameData.format_live_stat_bbcode(
		"hp", "%d/%d" % [int(p.hp), int(effective_hp)]))
	parts.append(GameData.format_live_stat_bbcode(
		"atk", "%.1f (%s)" % [effective_atk, tr("PAUSE_LIVE_DAMAGE_MULT_FMT") % dmg_mult_pct]))
	parts.append(GameData.format_live_stat_bbcode("def", "%.1f" % effective_def))
	parts.append(GameData.format_live_stat_bbcode("rate", "%.2fx" % effective_rate))
	parts.append(GameData.format_live_stat_bbcode("move", "%.0f" % effective_move))
	parts.append(GameData.format_live_stat_bbcode(
		"dmg_reduce", "%.0f%%" % int(round(float(p.dmg_reduce) * 100.0))))
	var crit_rate: float = GameData.player_live_crit_chance(p)
	parts.append(GameData.format_live_stat_bbcode(
		"crit_chance", "%d%%" % int(round(crit_rate * 100.0))))
	var crit_dmg_mult: float = GameData.player_live_crit_damage_mult(p)
	parts.append(GameData.format_live_stat_bbcode(
		"crit_damage", "%d%%" % int(round(crit_dmg_mult * 100.0))))
	return "[color=#ffd24d]%s[/color]  %s" % [tr("PAUSE_LIVE_STATS_LABEL"), "    ".join(parts)]


func _call_float(target: Node, method: String, fallback: float) -> float:
	if target != null and target.has_method(method):
		return float(target.call(method))
	return fallback


func _effective_max_hp(p: Node) -> float:
	return _call_float(p, "get_effective_max_hp", p.max_hp * p.hp_mult)


func _build_common_upgrade_slots(inner: VBoxContainer, p: Node) -> void:
	var cap: int = p.get_common_upgrade_slot_max() if p.has_method("get_common_upgrade_slot_max") \
		else GameData.COMMON_UPGRADE_SLOT_INITIAL
	var filled: int = p.get_common_upgrade_filled_count() if p.has_method("get_common_upgrade_filled_count") \
		else p.common_upgrade_log.size()
	var c_caption := Label.new()
	var cap_color: Color = Color(0.7, 0.9, 1.0)
	if filled >= cap:
		cap_color = Color(1.0, 0.6, 0.5)
	c_caption.text = tr("PAUSE_COMMON_CAP_FMT") % [filled, cap]
	c_caption.add_theme_font_size_override("font_size", 14)
	c_caption.add_theme_color_override("font_color", cap_color)
	inner.add_child(c_caption)

	var ids: Array[String] = []
	for raw_id in p.common_upgrade_log.keys():
		ids.append(String(raw_id))
	ids.sort()
	var c_row := HBoxContainer.new()
	c_row.add_theme_constant_override("separation", 4)
	inner.add_child(c_row)
	const SLOT_W := 80.0
	const SLOT_H := 44.0
	for i in cap:
		if i < ids.size():
			var cid: String = ids[i]
			var lv: int = int(p.common_upgrade_log.get(cid, 0))
			var cdef: Dictionary = GameData.get_common_upgrade_def(cid)
			var slot_text: String = tr("PAUSE_COMMON_SLOT_LV_FMT") % lv
			var c_tex: Texture2D = GameData.load_common_upgrade_icon(cid)
			var cup_slot: Panel = _make_slot_with_icon(
				slot_text, true, Color(0.55, 0.85, 0.95), SLOT_W, SLOT_H, 10, c_tex)
			if not cdef.is_empty():
				cup_slot.tooltip_text = "%s\n%s" % [GameData.tr_name(cdef), GameData.tr_desc(cdef)]
			c_row.add_child(cup_slot)
		else:
			c_row.add_child(_make_slot(
				tr("PAUSE_SLOT_EMPTY"), false, Color(0.4, 0.4, 0.5), SLOT_W, SLOT_H, 11))


func _build_stack_lines(p: Node) -> Array[String]:
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


func _build_weapon_tip_popup() -> void:
	_weapon_tip_wrap = PanelContainer.new()
	_weapon_tip_wrap.visible = false
	_weapon_tip_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon_tip_wrap.z_index = 30
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.14, 0.96)
	sb.border_color = Color(0.55, 0.75, 0.95)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_weapon_tip_wrap.add_theme_stylebox_override("panel", sb)
	_weapon_tip_wrap.custom_minimum_size = Vector2(180, 0)
	panel.add_child(_weapon_tip_wrap)
	_weapon_tip_label = Label.new()
	_weapon_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_weapon_tip_label.add_theme_font_size_override("font_size", 13)
	_weapon_tip_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	_weapon_tip_wrap.add_child(_weapon_tip_label)


func _hide_weapon_tip() -> void:
	if _weapon_tip_wrap != null:
		_weapon_tip_wrap.visible = false


func _show_weapon_tip(text: String, global_anchor: Vector2) -> void:
	if _weapon_tip_wrap == null or _weapon_tip_label == null or panel == null or text == "":
		return
	_weapon_tip_label.text = text
	_weapon_tip_wrap.visible = true
	_weapon_tip_wrap.reset_size()
	var local_pos: Vector2 = panel.get_global_transform().affine_inverse() * global_anchor
	_weapon_tip_wrap.position = local_pos - Vector2(
		_weapon_tip_wrap.size.x * 0.5, _weapon_tip_wrap.size.y + 8.0)
	_weapon_tip_wrap.position.x = clampf(
		_weapon_tip_wrap.position.x, 8.0, panel.size.x - _weapon_tip_wrap.size.x - 8.0)
	_weapon_tip_wrap.position.y = clampf(
		_weapon_tip_wrap.position.y, 8.0, panel.size.y - _weapon_tip_wrap.size.y - 8.0)


func _wire_weapon_slot_tip(slot: Panel, tip_text: String) -> void:
	if slot == null or tip_text == "":
		return
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	for child in slot.get_children():
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not slot.mouse_entered.is_connected(_on_weapon_slot_mouse_entered):
		slot.mouse_entered.connect(_on_weapon_slot_mouse_entered.bind(slot, tip_text))
		slot.mouse_exited.connect(_on_weapon_slot_mouse_exited)
		slot.gui_input.connect(_on_weapon_slot_gui_input.bind(slot, tip_text))


func _on_weapon_slot_mouse_entered(slot: Panel, tip_text: String) -> void:
	if tip_text == "" or not open_state or slot == null:
		return
	_show_weapon_tip(tip_text, slot.global_position + Vector2(slot.size.x * 0.5, 0.0))


func _on_weapon_slot_mouse_exited() -> void:
	_hide_weapon_tip()


func _on_weapon_slot_gui_input(event: InputEvent, slot: Panel, tip_text: String) -> void:
	if tip_text == "" or not open_state or slot == null:
		return
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			_show_weapon_tip(tip_text, slot.global_position + Vector2(slot.size.x * 0.5, 0.0))
		else:
			_hide_weapon_tip()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_show_weapon_tip(tip_text, slot.global_position + Vector2(slot.size.x * 0.5, 0.0))
			else:
				_hide_weapon_tip()


# 帶圖示的格子（左邊小圖、右邊文字）
func _make_slot_with_icon(text: String, filled: bool, accent: Color,
		w: float, h: float, font_size: int, tex: Texture2D) -> Panel:
	var slot: Panel = _make_slot(text, filled, accent, w, h, font_size)
	if tex != null:
		var icon_size: float = h - 6.0
		# 文字 Label 已在 slot 中（pos 0,0 size w,h）— 我們疊一張圖示在左側並把文字移右
		var lbl: Label = slot.get_child(0) as Label
		if lbl:
			lbl.position = Vector2(icon_size + 8.0, 0)
			lbl.size = Vector2(w - icon_size - 12.0, h)
		var ic := TextureRect.new()
		ic.texture = tex
		ic.position = Vector2(4.0, 3.0)
		ic.size = Vector2(icon_size, icon_size)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.modulate = Color(1, 1, 1) if filled else Color(0.55, 0.55, 0.65)
		slot.add_child(ic)
	return slot


# 顯示一個帶外框的格子；filled 控制亮 / 暗外觀
func _make_slot(text: String, filled: bool, accent: Color,
		w: float, h: float, font_size: int = 12) -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(w, h)
	var sb := StyleBoxFlat.new()
	if filled:
		sb.bg_color = Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.35, 0.95)
		sb.border_color = accent
	else:
		sb.bg_color = Color(0.08, 0.1, 0.15, 0.85)
		sb.border_color = Color(0.25, 0.3, 0.4)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	slot.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.text = text
	lbl.size = Vector2(w, h)
	lbl.position = Vector2(0, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color",
		Color(1, 1, 1) if filled else Color(0.45, 0.5, 0.6))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot.add_child(lbl)
	return slot


# 標題小字（"技能" / "被動" 之類）
func _make_caption(text: String, w: float) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(w, 0)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl
