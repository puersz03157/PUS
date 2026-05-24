extends "res://scripts/weapons/weapon_base.gd"
## 環繞武器：在玩家周圍放數個環繞球體，碰到敵人造成傷害。

var orbiters: Array[Node2D] = []
var spin: float = 0.0


func _on_setup() -> void:
	_rebuild()


func refresh() -> void:
	super.refresh()
	if has_method("_rebuild") and orbiters.size() != _target_count():
		_rebuild()


func _target_count() -> int:
	var base: int = int(def["params"].get("count", 3))
	return base + int(entry.get("upgrades", {}).get("w_count", 0))


func _rebuild() -> void:
	for o in orbiters:
		o.queue_free()
	orbiters.clear()
	var col: Color = def["params"].get("color", Color.WHITE)
	var vis_cfg: Variant = def["params"].get("projectile_visual", null)
	var use_sheet: bool = vis_cfg is Dictionary and not (vis_cfg as Dictionary).is_empty()
	for i in _target_count():
		var n := Node2D.new()
		if use_sheet:
			var spr := MagicBulletVfx.create_projectile_sprite(vis_cfg as Dictionary, col)
			if spr != null:
				n.add_child(spr)
				n.set_meta("orbit_sheet", true)
			else:
				_add_orbit_fallback_polygon(n, col)
		else:
			_add_orbit_fallback_polygon(n, col)
		add_child(n)
		orbiters.append(n)


func _add_orbit_fallback_polygon(n: Node2D, col: Color) -> void:
	var spr := Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 8:
		var a: float = TAU * k / 8.0
		pts.append(Vector2(cos(a), sin(a)) * 8.0)
	spr.polygon = pts
	spr.color = col
	n.add_child(spr)


func fire() -> bool:
	# 環繞武器無需個別 fire — 主要由 _process 驅動移動 & 命中判斷
	return false


func _process(delta: float) -> void:
	super._process(delta)
	if owner_player == null:
		return
	var spin_speed: float = float(def["params"].get("spin_speed", 3.0))
	spin_speed *= (1.0 + 0.15 * int(entry.get("upgrades", {}).get("w_rate", 0)))
	if weapon_upgrades_maxed() and String(def.get("id", "")) == "shard":
		spin_speed *= 1.45
	if owner_player and owner_player.get("mushin_active") == true:
		var sk: Dictionary = GameData.get_skill_def("mushin")
		spin_speed *= float(sk.get("params", {}).get("combat_spin_mult", 2.0))
	spin += spin_speed * delta
	var n: int = orbiters.size()
	if n == 0:
		return
	var radius: float = eff_range
	for i in n:
		var a: float = spin + TAU * i / n
		var orbiter: Node2D = orbiters[i]
		orbiter.position = Vector2(cos(a), sin(a)) * radius
		if orbiter.get_meta("orbit_sheet", false):
			var tangent: Vector2 = Vector2(-sin(a), cos(a))
			orbiter.rotation = tangent.angle()
		# 命中判定（簡易）
		var p: Vector2 = owner_player.global_position + orbiter.position
		for e in owner_player.get_tree().get_nodes_in_group("enemies"):
			if p.distance_to(e.global_position) < 14.0:
				damage_enemy(e, delta * 6.0)
