extends RefCounted
class_name BattleRunSummaryOverlay
## 戰鬥結算全螢幕面板：戰鬥結束時先顯示於 Game；按 ESC 進村莊後再顯示一次直至關閉。

const LAYER_Z := 80


static func store_pending(title: String, title_color: Color, subtitle: String, stats_bbcode: String, exit_hint: String, dismiss_hint: String) -> void:
	GameState.pending_battle_summary = {
		"title": title,
		"title_color": title_color,
		"subtitle": subtitle,
		"stats_bbcode": stats_bbcode,
		"exit_hint": exit_hint,
		"dismiss_hint": dismiss_hint,
	}


static func has_pending() -> bool:
	return not GameState.pending_battle_summary.is_empty()


static func clear_pending() -> void:
	GameState.pending_battle_summary = {}


static func present(tree: SceneTree, use_dismiss_hint: bool = false) -> CanvasLayer:
	var data: Dictionary = GameState.pending_battle_summary
	if data.is_empty():
		return null
	var layer := CanvasLayer.new()
	layer.layer = LAYER_Z
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
	dim.color = Color(0, 0, 0, 0.72)
	root.add_child(dim)

	var panel_w: float = minf(960.0, vp_size.x - 32.0)
	var panel_h: float = minf(620.0, vp_size.y - 48.0)
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.18, 0.98)
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
	panel.position = Vector2((vp_size.x - panel_w) * 0.5, (vp_size.y - panel_h) * 0.5)
	panel.size = Vector2(panel_w, panel_h)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)

	var title := Label.new()
	title.text = String(data.get("title", ""))
	title.position = Vector2(12, 18)
	title.size = Vector2(panel_w - 24, 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", data.get("title_color", Color.WHITE))
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = String(data.get("subtitle", ""))
	subtitle.position = Vector2(12, 76)
	subtitle.size = Vector2(panel_w - 24, 28)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	panel.add_child(subtitle)

	var stats := RichTextLabel.new()
	stats.bbcode_enabled = true
	stats.text = String(data.get("stats_bbcode", ""))
	stats.position = Vector2(12, 112)
	stats.size = Vector2(panel_w - 24, panel_h - 168)
	stats.scroll_active = true
	stats.add_theme_font_size_override("normal_font_size", 15)
	panel.add_child(stats)

	var hint_key: String = "dismiss_hint" if use_dismiss_hint else "exit_hint"
	var hint := Label.new()
	hint.text = String(data.get(hint_key, ""))
	hint.position = Vector2(12, panel_h - 44)
	hint.size = Vector2(panel_w - 24, 32)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	panel.add_child(hint)

	layer.set_meta("summary_panel", panel)
	return layer


static func dismiss(layer: CanvasLayer) -> void:
	if layer != null and is_instance_valid(layer):
		layer.queue_free()
	clear_pending()
