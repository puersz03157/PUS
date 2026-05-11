extends "res://scripts/weapons/weapon_base.gd"
## 周圍光環：以玩家為中心的圓形持續傷害（按頻率每段時間造成傷害）。

var visual: Polygon2D = null


func _on_setup() -> void:
	visual = Polygon2D.new()
	var col: Color = def["params"].get("color", Color.WHITE)
	visual.color = Color(col.r, col.g, col.b, 0.18)
	add_child(visual)
	_rebuild_visual()


func refresh() -> void:
	super.refresh()
	_rebuild_visual()


func _rebuild_visual() -> void:
	if visual == null:
		return
	var pts := PackedVector2Array()
	for i in 32:
		var a: float = TAU * i / 32.0
		pts.append(Vector2(cos(a), sin(a)) * eff_range)
	visual.polygon = pts


func fire() -> bool:
	if owner_player == null:
		return false
	# 光環特效（脈動）
	if visual:
		var t := visual.create_tween()
		t.tween_property(visual, "modulate:a", 1.0, 0.05)
		t.tween_property(visual, "modulate:a", 0.6, 0.18)
	for e in owner_player.get_tree().get_nodes_in_group("enemies"):
		if owner_player.global_position.distance_to(e.global_position) <= eff_range:
			damage_enemy(e)
	# 治療效果（聖光：滿級前僅自回；滿級後額外治療附近隊友）
	if def["params"].get("heal", 0.0) > 0.0:
		owner_player._heal(float(def["params"]["heal"]))
		if def["id"] == "holy" and weapon_upgrades_maxed():
			for p in owner_player.get_tree().get_nodes_in_group("players"):
				if p != owner_player and p.global_position.distance_to(owner_player.global_position) < 220.0:
					p._heal(float(def["params"]["heal"]) * 0.6)
	return false   # 光環是被動，不觸發攻擊動畫
