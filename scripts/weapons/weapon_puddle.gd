extends "res://scripts/weapons/weapon_base.gd"
## 毒池：每次 fire 在玩家附近隨機位置丟下一灘毒池，停留地面持續傷害敵人（類吸血鬼倖存者聖水）。

const PUDDLE_SCRIPT := preload("res://scripts/poison_puddle.gd")


func fire() -> bool:
	if owner_player == null:
		return false
	var p: Dictionary = def["params"]
	var col: Color = p.get("color", Color(0.5, 1.0, 0.4))
	var puddle_radius: float = float(p.get("puddle_radius", 60.0))
	var lifetime: float = float(p.get("lifetime", 3.5))
	var tick_interval: float = float(p.get("tick_interval", 0.5))
	# eff_damage 為一輪「總傷害」基礎，分配到 ticks 個 tick
	var ticks: int = max(1, int(round(lifetime / tick_interval)))
	var damage_per_tick: float = max(1.0, eff_damage / float(ticks))

	var count: int = max(1, eff_count)
	var origin: Vector2 = owner_player.global_position
	for i in count:
		var ang: float = randf() * TAU
		# 投擲距離：玩家附近的隨機落點，最遠 = eff_range
		var dist: float = eff_range * (0.4 + randf() * 0.6)
		var pos: Vector2 = origin + Vector2(cos(ang), sin(ang)) * dist
		# 若會落在阻擋格上，往玩家方向拉回一點
		var game = owner_player.get_parent()
		if game and game.has_method("is_world_blocked_at"):
			for tries in 4:
				if not game.is_world_blocked_at(pos, 6.0):
					break
				pos = origin + (pos - origin) * 0.6
		var puddle: Node2D = Node2D.new()
		puddle.set_script(PUDDLE_SCRIPT)
		puddle.setup(self, owner_player, damage_per_tick, puddle_radius, lifetime, tick_interval, col)
		puddle.global_position = pos
		owner_player.get_parent().add_child(puddle)
	return true
