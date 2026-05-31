extends RefCounted
class_name SummonMilestoneOverlay
## 召喚獸孵化／進化全螢幕提示（簡易光效 + 系統對話）

const LAYER_Z := 110


static func queue_milestones(milestones: Array) -> void:
	for raw in milestones:
		if raw is Dictionary:
			var m: Dictionary = raw as Dictionary
			if m.is_empty():
				continue
			GameState.pending_summon_milestones.append(m.duplicate())


static func has_pending() -> bool:
	return not GameState.pending_summon_milestones.is_empty()


static func present_next(tree: SceneTree) -> CanvasLayer:
	if GameState.pending_summon_milestones.is_empty():
		return null
	var milestone: Dictionary = GameState.pending_summon_milestones.pop_front()
	return _build_overlay(tree, milestone)


static func present_and_wait(host: Node, milestone: Dictionary) -> void:
	if host == null or not is_instance_valid(host) or milestone.is_empty():
		return
	var tree: SceneTree = host.get_tree()
	if tree == null:
		return
	var layer: CanvasLayer = _build_overlay(tree, milestone)
	if layer == null:
		return
	await host.get_tree().process_frame
	while is_instance_valid(layer):
		await host.get_tree().process_frame


static func _build_overlay(tree: SceneTree, milestone: Dictionary) -> CanvasLayer:
	var kind: String = String(milestone.get("kind", ""))
	var sid: String = String(milestone.get("summon_id", ""))
	if kind == "" or sid == "":
		return null
	var player_slot: String = String(milestone.get("player_slot", "p1"))
	var level: int = int(milestone.get("level", GameData.SUMMON_MIN_LEVEL))
	if level < GameData.SUMMON_MIN_LEVEL:
		var prog: Dictionary = GameState.get_summon_progress(player_slot, sid)
		level = int(prog.get("level", GameData.SUMMON_MIN_LEVEL))

	var layer := CanvasLayer.new()
	layer.layer = LAYER_Z
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(layer)

	var vp_size: Vector2 = tree.root.get_viewport().get_visible_rect().size
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.04, 0.08, 0.78)
	root.add_child(dim)

	var panel_w: float = minf(520.0, vp_size.x - 48.0)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(panel_w, 0)
	panel.position = Vector2((vp_size.x - panel_w) * 0.5, vp_size.y * 0.22)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.12, 0.16, 0.96)
	panel_style.border_color = Color(1.0, 0.86, 0.42, 0.85)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 26)
	if kind == "hatch":
		title.text = TranslationServer.translate("SUMMON_MILESTONE_HATCH_TITLE")
		title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
	else:
		title.text = TranslationServer.translate("SUMMON_MILESTONE_EVOLVE_TITLE")
		title.add_theme_color_override("font_color", Color(0.55, 0.95, 0.82))
	vbox.add_child(title)

	var preview_box := Control.new()
	preview_box.custom_minimum_size = Vector2(0, 168)
	vbox.add_child(preview_box)

	var glow := ColorRect.new()
	glow.custom_minimum_size = Vector2(140, 140)
	glow.size = glow.custom_minimum_size
	glow.position = Vector2((panel_w - 44.0 - 140.0) * 0.5, 14.0)
	glow.color = Color(1.0, 0.92, 0.45, 0.18) if kind == "hatch" \
		else Color(0.45, 0.95, 0.72, 0.2)
	preview_box.add_child(glow)

	var sprite := Sprite2D.new()
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var preview: Dictionary = GameData.resolve_summon_house_preview(sid, level)
	var tex: Texture2D = preview.get("texture")
	if tex != null:
		sprite.texture = tex
		var layout: Dictionary = GameData.compute_centered_sprite_trim_layout(tex)
		var vis_h: float = float(layout.get("h", 32.0))
		var mul: float = float(preview.get("scale_mul", 1.0))
		var fit: float = 96.0 / maxf(1.0, vis_h) * mul
		sprite.scale = Vector2(fit, fit)
		sprite.position = glow.position + glow.size * 0.5 \
			+ Vector2(-float(layout.get("center_dx", 0.0)) * fit, -float(layout.get("center_dy", 0.0)) * fit)
	preview_box.add_child(sprite)

	var burst := CPUParticles2D.new()
	burst.emitting = true
	burst.one_shot = true
	burst.amount = 28 if kind == "hatch" else 36
	burst.lifetime = 0.85
	burst.explosiveness = 0.92
	burst.direction = Vector2(0, -1)
	burst.spread = 180.0
	burst.gravity = Vector2(0, 120)
	burst.initial_velocity_min = 40.0
	burst.initial_velocity_max = 130.0
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 5.0
	burst.color = Color(1.0, 0.92, 0.45, 0.95) if kind == "hatch" \
		else Color(0.55, 1.0, 0.78, 0.95)
	burst.position = sprite.position
	preview_box.add_child(burst)

	var body := Label.new()
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", Color(0.88, 0.94, 0.98))
	if kind == "hatch":
		body.text = TranslationServer.translate("SUMMON_MILESTONE_HATCH_MSG_FMT") \
			% GameData.tr_summon_display_name(sid, level)
	else:
		body.text = TranslationServer.translate("SUMMON_MILESTONE_EVOLVE_MSG_FMT") \
			% GameData.tr_summon_display_name(sid, level)
	vbox.add_child(body)

	var hint := Label.new()
	hint.text = TranslationServer.translate("SUMMON_MILESTONE_CONFIRM")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.65, 0.72, 0.78))
	vbox.add_child(hint)

	var dismiss := func() -> void:
		if is_instance_valid(layer):
			layer.queue_free()
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			dismiss.call())
	root.gui_input.connect(func(ev: InputEvent) -> void:
		if ev.is_action_pressed("ui_accept") or ev.is_action_pressed("ui_cancel"):
			dismiss.call())

	var target_scale: Vector2 = sprite.scale
	sprite.scale = target_scale * 0.2
	sprite.modulate.a = 0.0
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.92, 0.92)
	var tw := layer.create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.22)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "modulate:a", 1.0, 0.18)
	tw.tween_property(sprite, "scale", target_scale * 1.08, 0.34)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(sprite, "scale", target_scale, 0.12)
	var pulse := layer.create_tween().set_loops(3)
	pulse.tween_property(glow, "modulate:a", 0.35, 0.22)
	pulse.tween_property(glow, "modulate:a", 0.85, 0.22)

	AudioManager.play_sfx("reward", 0.03, -2.0)
	return layer
