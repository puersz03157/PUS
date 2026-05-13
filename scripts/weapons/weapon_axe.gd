extends "res://scripts/weapons/weapon_base.gd"
## 斧頭：自身前方小圓形範圍，高傷害慢攻速。滿級後額外投出返回斧頭。

const RETURNING_AXE_SCRIPT := preload("res://scripts/weapons/returning_axe.gd")


func fire() -> bool:
	if owner_player == null or owner_player.hp <= 0:
		return false
	var dir: Vector2 = _aim_dir()
	if dir == Vector2.ZERO:
		return false
	_swing(dir)
	if weapon_upgrades_maxed():
		_throw_returning_axe(dir)
	return true


func _swing(dir: Vector2) -> void:
	var p: Dictionary = def.get("params", {})
	var hit_radius: float = float(p.get("hit_radius", 54.0))
	var forward_offset: float = float(p.get("forward_offset", eff_range * 0.8))
	var col: Color = p.get("color", Color(1.0, 0.62, 0.28))
	var center: Vector2 = owner_player.global_position + dir.normalized() * forward_offset

	var visual := _AxeCircleVisual.new()
	visual.z_index = 8
	visual.global_position = center
	visual.setup(hit_radius, col)
	owner_player.get_tree().current_scene.add_child(visual)

	for e in owner_player.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e.get("hp") != null and float(e.hp) <= 0.0:
			continue
		if center.distance_to(e.global_position) <= hit_radius:
			damage_enemy(e)


func _throw_returning_axe(dir: Vector2) -> void:
	var p: Dictionary = def.get("params", {})
	var col: Color = p.get("color", Color(1.0, 0.62, 0.28))
	var axe: Node2D = RETURNING_AXE_SCRIPT.new()
	axe.setup(
		self,
		owner_player,
		owner_player.global_position + dir.normalized() * 24.0,
		dir,
		float(p.get("throw_speed", 520.0)),
		float(p.get("throw_distance", 360.0)) * (eff_range / max(1.0, float(def.get("range", eff_range)))),
		float(p.get("throw_hit_radius", 28.0)),
		float(p.get("throw_damage_mult", 0.75)),
		col,
	)
	owner_player.get_tree().current_scene.add_child(axe)


func _aim_dir() -> Vector2:
	var origin: Vector2 = owner_player.global_position
	var best: Node = null
	var best_d: float = pow(eff_range + float(def.get("params", {}).get("forward_offset", 70.0)), 2.0)
	var facing: Vector2 = owner_player.face_dir.normalized()
	if facing == Vector2.ZERO:
		facing = Vector2.RIGHT
	for e in owner_player.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e.get("hp") != null and float(e.hp) <= 0.0:
			continue
		var to_e: Vector2 = e.global_position - origin
		if to_e.length_squared() > best_d:
			continue
		if to_e.normalized().dot(facing) < 0.15:
			continue
		best = e
		best_d = to_e.length_squared()
	if best != null:
		return (best.global_position - origin).normalized()
	return facing


class _AxeCircleVisual:
	extends Node2D

	var radius: float = 54.0
	var color: Color = Color(1.0, 0.62, 0.28)

	func setup(r: float, c: Color) -> void:
		radius = r
		color = c
		queue_redraw()
		var tw := create_tween()
		scale = Vector2(0.45, 0.45)
		modulate.a = 0.8
		tw.tween_property(self, "scale", Vector2.ONE, 0.07)
		tw.parallel().tween_property(self, "modulate:a", 0.0, 0.20)
		tw.tween_callback(queue_free)

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, 0.24))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(color.r, color.g, color.b, 0.8), 3.0)
