extends Node2D
class_name DamagePopup
## 浮動傷害數字：一般白字、爆擊金黃大字＋彈跳

const POPUP_SCENE := preload("res://scenes/DamagePopup.tscn")

const COLOR_NORMAL := Color(1.0, 0.96, 0.88, 1.0)
const COLOR_CRIT := Color(1.0, 0.82, 0.18, 1.0)
const COLOR_DOT := Color(0.75, 0.9, 1.0, 0.92)


static func spawn_at(
		enemy: Node2D,
		amount: float,
		is_crit: bool = false,
		from_dot: bool = false) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if amount < 0.5:
		return
	var parent: Node = enemy.get_tree().current_scene
	if parent == null:
		parent = enemy.get_parent()
	if parent == null:
		return
	var popup: DamagePopup = POPUP_SCENE.instantiate() as DamagePopup
	if popup == null:
		return
	parent.add_child(popup)
	var anchor: Vector2 = enemy.global_position
	if enemy.has_method("get_damage_popup_position"):
		anchor = enemy.get_damage_popup_position()
	else:
		anchor += Vector2(randf_range(-12.0, 12.0), -28.0)
	popup.global_position = anchor
	popup.setup(int(round(amount)), is_crit, from_dot)


func setup(amount: int, is_crit: bool, from_dot: bool) -> void:
	var label: Label = $Label
	var outline: Label = $Outline
	var text := str(amount)
	if is_crit:
		text = str(amount) + "!"
	label.text = text
	outline.text = text
	var font_size: int = 15
	if from_dot:
		font_size = 12
		label.modulate = COLOR_DOT
		outline.modulate = Color(0.1, 0.15, 0.2, 0.7)
	elif is_crit:
		font_size = 26
		label.modulate = COLOR_CRIT
		outline.modulate = Color(0.35, 0.12, 0.02, 0.85)
	else:
		font_size = 17
		label.modulate = COLOR_NORMAL
		outline.modulate = Color(0.05, 0.05, 0.08, 0.75)
	label.add_theme_font_size_override("font_size", font_size)
	outline.add_theme_font_size_override("font_size", font_size)
	_play_float(is_crit)


func _play_float(is_crit: bool) -> void:
	var rise: float = 42.0 if is_crit else 30.0
	var drift_x: float = randf_range(-14.0, 14.0)
	var dur: float = 0.72 if is_crit else 0.58
	scale = Vector2(0.35, 0.35) if is_crit else Vector2(0.5, 0.5)
	modulate.a = 1.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", position + Vector2(drift_x, -rise), dur)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if is_crit:
		tw.tween_property(self, "scale", Vector2(1.35, 1.35), 0.12)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(self, "scale", Vector2.ONE, 0.18)
	else:
		tw.tween_property(self, "scale", Vector2.ONE, 0.1)
	tw.tween_property(self, "modulate:a", 0.0, dur * 0.45).set_delay(dur * 0.48)
	tw.chain().tween_callback(queue_free)
