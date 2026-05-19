extends PanelContainer
class_name ResourceIconChip
## 資源／貨幣圖示格：桌面 tooltip_text；觸控點一下由 owner 顯示名稱浮層。

signal tip_show(text: String, global_anchor: Vector2)
signal tip_hide()

var _tip_name: String = ""


func configure(tip_name: String, texture: Texture2D, amount: int = -1, icon_size: int = 36) -> void:
	_tip_name = tip_name
	tooltip_text = tip_name
	for c in get_children():
		c.queue_free()
	custom_minimum_size = Vector2(icon_size + 8, icon_size + 8 if amount < 0 else icon_size + 22)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	add_child(box)
	var icon_wrap := CenterContainer.new()
	icon_wrap.custom_minimum_size = Vector2(icon_size, icon_size)
	box.add_child(icon_wrap)
	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(icon_size, icon_size)
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.texture = texture
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_wrap.add_child(tex_rect)
	if amount >= 0:
		var amt_lbl := Label.new()
		amt_lbl.text = str(amount)
		amt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		amt_lbl.add_theme_font_size_override("font_size", 12)
		amt_lbl.add_theme_color_override("font_color", Color(0.9, 0.94, 1.0))
		amt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(amt_lbl)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.1, 0.18, 0.85)
	sb.border_color = Color(0.35, 0.42, 0.55, 0.9)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", sb)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
		gui_input.connect(_on_gui_input)


func _on_mouse_entered() -> void:
	if _tip_name != "":
		tip_show.emit(_tip_name, global_position + Vector2(size.x * 0.5, 0.0))


func _on_mouse_exited() -> void:
	tip_hide.emit()


func _on_gui_input(event: InputEvent) -> void:
	if _tip_name == "":
		return
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			tip_show.emit(_tip_name, global_position + Vector2(size.x * 0.5, 0.0))
		else:
			tip_hide.emit()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			tip_show.emit(_tip_name, global_position + Vector2(size.x * 0.5, 0.0))
