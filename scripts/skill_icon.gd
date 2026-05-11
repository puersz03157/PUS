extends Panel
## 顯示一位玩家的技能圖示與冷卻狀態。
## 可放在彈珠台或戰鬥 HUD 中；自身管理視覺更新。
##
## 用法：
##   var icon = preload("res://scripts/skill_icon.gd").new()
##   icon.setup(player, "P1", "Q / X")
##   add_child(icon)

const ICON_PADDING := 8.0
const HEADER_H := 16.0
const NAME_H := 16.0
const KEY_H := 14.0

@export var icon_dim: float = 64.0
@export var show_header: bool = true
@export var show_name: bool = true
@export var show_key: bool = true
# 是否在圖示中顯示被動「skill_meter」累積數字。觸控版的大圖示通常關掉，避免干擾。
@export var show_meter: bool = true

var player: Node = null
var label_text: String = "P1"
var key_text: String = "Q / X"

var _icon_bg: ColorRect
var _icon: TextureRect
var _cd_lbl: Label
var _name_lbl: Label
var _player_lbl: Label
var _key_lbl: Label

var _built: bool = false


func _ready() -> void:
	# 暫停場景（彈珠台／暫停）也要持續刷新冷卻顯示
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _built:
		_build()
	_refresh_static()


func setup(p: Node, player_label: String = "", key_label: String = "") -> void:
	player = p
	if player_label != "":
		label_text = player_label
	if key_label != "":
		key_text = key_label
	if not _built:
		_build()
	_refresh_static()


func _build() -> void:
	_built = true
	var pw: float = icon_dim + ICON_PADDING * 2.0
	var cur_y: float = 4.0
	var total_h: float = 4.0 + icon_dim + 4.0
	if show_header:
		total_h += HEADER_H + 2.0
	if show_name:
		total_h += NAME_H + 2.0
	if show_key:
		total_h += KEY_H + 2.0
	custom_minimum_size = Vector2(pw, total_h)
	size = Vector2(pw, total_h)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.20, 0.92)
	sb.border_color = Color(0.95, 0.7, 0.3)
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", sb)

	if show_header:
		_player_lbl = Label.new()
		_player_lbl.position = Vector2(0, cur_y)
		_player_lbl.size = Vector2(pw, HEADER_H)
		_player_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_player_lbl.add_theme_font_size_override("font_size", 12)
		add_child(_player_lbl)
		cur_y += HEADER_H + 2.0

	_icon_bg = ColorRect.new()
	_icon_bg.color = Color(0.22, 0.18, 0.30)
	_icon_bg.position = Vector2(ICON_PADDING, cur_y)
	_icon_bg.size = Vector2(icon_dim, icon_dim)
	add_child(_icon_bg)

	_icon = TextureRect.new()
	_icon.position = Vector2.ZERO
	_icon.size = Vector2(icon_dim, icon_dim)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# 32x32 pixel art 圖示放大到 64+px 必須用最近鄰，避免糊成一團
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon_bg.add_child(_icon)

	_cd_lbl = Label.new()
	_cd_lbl.position = Vector2.ZERO
	_cd_lbl.size = Vector2(icon_dim, icon_dim)
	_cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cd_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cd_lbl.add_theme_color_override("font_color", Color(1, 1, 0.95))
	_cd_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_cd_lbl.add_theme_constant_override("outline_size", 3)
	_cd_lbl.add_theme_font_size_override("font_size", int(icon_dim * 0.36))
	_icon_bg.add_child(_cd_lbl)

	cur_y += icon_dim + 4.0

	if show_name:
		_name_lbl = Label.new()
		_name_lbl.position = Vector2(0, cur_y)
		_name_lbl.size = Vector2(pw, NAME_H)
		_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_lbl.add_theme_font_size_override("font_size", 12)
		_name_lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
		add_child(_name_lbl)
		cur_y += NAME_H + 2.0

	if show_key:
		_key_lbl = Label.new()
		_key_lbl.position = Vector2(0, cur_y)
		_key_lbl.size = Vector2(pw, KEY_H)
		_key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_key_lbl.add_theme_font_size_override("font_size", 10)
		_key_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
		add_child(_key_lbl)


func _refresh_static() -> void:
	if not _built:
		return
	if _player_lbl:
		_player_lbl.text = label_text
		if player:
			_player_lbl.add_theme_color_override("font_color", player.color)
	if _key_lbl:
		_key_lbl.text = "[%s]" % key_text
	# 邊框：跟玩家色
	var sb: StyleBoxFlat = get_theme_stylebox("panel") as StyleBoxFlat
	if sb and player:
		sb.border_color = player.color
	# 名稱與圖示
	if player == null:
		if _name_lbl:
			_name_lbl.text = ""
		if _icon:
			_icon.texture = null
		return
	var s_def: Dictionary = GameData.get_skill_def(String(player.skill_id))
	if _name_lbl:
		_name_lbl.text = GameData.tr_name(s_def)
	if _icon:
		_icon.texture = GameData.load_skill_icon(String(player.skill_id))


func _process(_delta: float) -> void:
	if not _built or player == null:
		return
	# 玩家可能換技能（升級、換裝等）— 偵測 skill_id 變更時重整圖示與名稱
	var s_def: Dictionary = GameData.get_skill_def(String(player.skill_id))
	if _name_lbl and _name_lbl.text != GameData.tr_name(s_def):
		_refresh_static()
	var has_skill: bool = String(player.skill_id) != "none"
	var has_image: bool = _icon.texture != null
	if not has_skill:
		# 無技能：暗紅 + ✕
		_icon_bg.color = Color(0.16, 0.10, 0.14, 1.0)
		_icon.modulate = Color(0.4, 0.4, 0.45, 0.7)
		_cd_lbl.add_theme_font_size_override("font_size", int(icon_dim * 0.5))
		_cd_lbl.text = "✕"
		_cd_lbl.modulate = Color(1, 0.45, 0.45)
		modulate = Color(0.7, 0.7, 0.75, 1.0)
	elif player.skill_cooldown > 0.0:
		# 充能中：暗化 + 倒數
		_icon_bg.color = Color(0.12, 0.10, 0.18, 1.0)
		_icon.modulate = Color(0.4, 0.4, 0.45, 0.85)
		_cd_lbl.add_theme_font_size_override("font_size", int(icon_dim * 0.36))
		var cd_txt: String = "%d" % int(ceil(player.skill_cooldown))
		if show_meter:
			var sm: float = float(player.skill_meter)
			if sm > 0.5:
				cd_txt += "\n%.0f" % sm
		_cd_lbl.text = cd_txt
		_cd_lbl.modulate = Color(1, 1, 0.85)
		modulate = Color(0.85, 0.85, 0.9, 1.0)
	else:
		# 可用：亮色 + 脈衝
		_icon_bg.color = Color(0.32, 0.22, 0.45, 1.0)
		_icon.modulate = Color(1, 1, 1, 1)
		var sm2: float = float(player.skill_meter)
		if has_image:
			if show_meter and sm2 > 0.5:
				_cd_lbl.add_theme_font_size_override("font_size", int(icon_dim * 0.28))
				_cd_lbl.text = "%.0f" % sm2
			else:
				_cd_lbl.text = ""
		else:
			_cd_lbl.add_theme_font_size_override("font_size", int(icon_dim * 0.18))
			var nm: String = GameData.tr_name(s_def)
			if show_meter and sm2 > 0.5:
				_cd_lbl.text = "%s\n%.0f" % [nm, sm2]
			else:
				_cd_lbl.text = nm
		_cd_lbl.modulate = Color(1, 1, 0.85)
		var pulse: float = 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.006)
		modulate = Color(pulse, pulse, pulse, 1.0)
