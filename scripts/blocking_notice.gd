extends RefCounted
class_name BlockingNotice
## 自訂全螢幕阻擋提示（非 AcceptDialog／Window），只靠「確認」按鈕的 pressed 關閉，
## 避免引擎對話框的 confirmed／canceled／焦點與 Space 殘留導致一閃即關。
##
## dismiss_target + dismiss_method：用 call() 呼叫，比 Callable(self, "fn") 在靜態／閉包裡穩定。
## dismiss_method 為空字串則不呼叫（僅關 UI）。

static func present(tree: SceneTree, title: String, main_text: String, hint_text: String, ok_label: String, dismiss_target: Object = null, dismiss_method: String = "") -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 250
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(layer)

	var vp_size: Vector2 = tree.get_root().get_viewport().get_visible_rect().size

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.color = Color(0, 0, 0, 0.55)
	root.add_child(dim)

	var panel_w: float = min(540.0, vp_size.x - 40.0)
	var panel_h: float = min(360.0, vp_size.y - 40.0)
	var panel := PanelContainer.new()
	panel.position = Vector2((vp_size.x - panel_w) * 0.5, (vp_size.y - panel_h) * 0.5)
	panel.custom_minimum_size = Vector2(panel_w, panel_h)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var ttl := Label.new()
	ttl.text = title
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ttl.add_theme_font_size_override("font_size", 22)
	vbox.add_child(ttl)

	var body := Label.new()
	body.text = "%s\n\n%s" % [main_text, hint_text]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 16)
	vbox.add_child(body)

	var btn := Button.new()
	btn.text = ok_label
	btn.disabled = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(220, 52)
	vbox.add_child(btn)

	btn.pressed.connect(func() -> void:
		if layer.get_meta("dismissed", false):
			return
		layer.set_meta("dismissed", true)
		if dismiss_target != null and dismiss_method != "":
			if is_instance_valid(dismiss_target) and dismiss_target.has_method(dismiss_method):
				dismiss_target.call(dismiss_method)
		if is_instance_valid(layer):
			layer.queue_free()
	, CONNECT_ONE_SHOT)

	var arm_timer := tree.create_timer(0.45, true, false, true)
	arm_timer.timeout.connect(func() -> void:
		if not is_instance_valid(layer) or layer.get_meta("dismissed", false):
			return
		if is_instance_valid(btn):
			btn.disabled = false
			btn.focus_mode = Control.FOCUS_ALL
			btn.grab_focus()
	, CONNECT_ONE_SHOT)

	return layer
