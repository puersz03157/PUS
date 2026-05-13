extends Node2D
class_name WeaponBase
## 武器基底：管理計時器、按 def + upgrades 重新計算數值，再呼叫 fire()。

var owner_player: Node = null
var entry: Dictionary = {}
var def: Dictionary = {}

# 計算後的有效數值
var eff_damage: float = 1.0
var eff_rate: float = 1.0
var eff_range: float = 100.0
var eff_count: int = 1

var _timer: float = 0.0


func setup(p: Node, e: Dictionary) -> void:
	owner_player = p
	entry = e
	def = GameData.get_weapon_def(entry["id"])
	refresh()
	_on_setup()


func _on_setup() -> void:
	pass


func weapon_upgrades_maxed() -> bool:
	return GameData.is_weapon_upgrades_maxed(entry.get("upgrades", {}))


func refresh() -> void:
	if def.is_empty():
		return
	var u: Dictionary = entry.get("upgrades", {})
	var dmg_lv: int = u.get("w_damage", 0)
	var rng_lv: int = u.get("w_range", 0)
	var rate_lv: int = u.get("w_rate", 0)
	var cnt_lv: int = u.get("w_count", 0)

	var atk_factor: float = (1.0 + 0.05 * owner_player.atk) * owner_player.damage_mult
	eff_damage = def["damage"] * (1.0 + 0.20 * dmg_lv) * atk_factor
	eff_rate = def["rate"] * (1.0 + 0.15 * rate_lv) * owner_player.rate_mult
	eff_range = def["range"] * (1.0 + 0.15 * rng_lv)
	var base_count: int = int(def["params"].get("count", 1))
	eff_count = base_count + cnt_lv


func _process(delta: float) -> void:
	if owner_player == null or owner_player.hp <= 0:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 1.0 / max(0.1, eff_rate)
		var fired: bool = fire()
		if fired and owner_player.has_method("play_attack_anim"):
			owner_player.play_attack_anim()


# 子類別實作；回傳 true 表示真的有攻擊發生（會觸發攻擊動畫）
func fire() -> bool:
	return false


# 子類別呼叫：對單一敵人造成傷害
func damage_enemy(e: Node, mult: float = 1.0) -> void:
	if not is_instance_valid(e):
		return
	var was_bleeding: bool = e.has_method("is_status_bleeding") and e.is_status_bleeding()
	var hit_mult: float = mult
	var wid0: String = String(def.get("id", ""))
	if wid0 == "ice" and weapon_upgrades_maxed() and e.has_method("is_status_slowed") \
			and e.is_status_slowed():
		hit_mult *= GameData.ENEMY_STATUS_ICE_VS_SLOW_DAMAGE_MULT
	if wid0 == "sword" and weapon_upgrades_maxed():
		var n_s: int = _count_alive_enemies_near(owner_player.global_position, eff_range * 1.2)
		hit_mult *= GameData.weapon_max_sword_damage_mult(n_s)
	if wid0 == "spear" and weapon_upgrades_maxed():
		var n_p: int = _count_alive_enemies_near(owner_player.global_position, eff_range * 1.2)
		hit_mult *= GameData.weapon_max_spear_damage_mult(n_p)
	var dealt: float = eff_damage * hit_mult
	if e.has_method("take_damage"):
		e.take_damage(dealt, self)
		# 通知玩家：武器命中事件（給「快射節奏」等被動使用）
		if owner_player and owner_player.has_method("on_weapon_hit"):
			owner_player.on_weapon_hit(e, self)
	if wid0 == "claw" and weapon_upgrades_maxed() and was_bleeding \
			and owner_player and owner_player.has_method("_heal"):
		owner_player._heal(dealt * GameData.ENEMY_STATUS_CLAW_BLEED_LIFESTEAL_RATIO)
	_apply_on_hit_status_effects(e, hit_mult)


func _count_alive_enemies_near(origin: Vector2, radius: float) -> int:
	if owner_player == null:
		return 0
	var n: int = 0
	for ee in owner_player.get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(ee):
			continue
		if ee.get("hp") != null and float(ee.hp) <= 0.0:
			continue
		if origin.distance_to(ee.global_position) <= radius:
			n += 1
	return n


func _apply_on_hit_status_effects(e: Node, mult: float) -> void:
	if not is_instance_valid(e):
		return
	var wid: String = String(def.get("id", ""))
	var hit_damage: float = eff_damage * mult
	if wid == "melody" and e.has_method("apply_status_vulnerable"):
		var cap: int = GameData.ENEMY_STATUS_MELODY_VULN_STACK_CAP_BASE
		if weapon_upgrades_maxed():
			cap = GameData.ENEMY_STATUS_MELODY_VULN_STACK_CAP_MAXED
		e.apply_status_vulnerable(GameData.ENEMY_STATUS_MELODY_VULN_DURATION, cap)
	if wid == "claw" and e.has_method("apply_status_bleed"):
		e.apply_status_bleed(
			hit_damage * GameData.ENEMY_STATUS_CLAW_BLEED_DPS_RATIO,
			GameData.ENEMY_STATUS_CLAW_BLEED_DURATION,
			self)
	if wid == "flame" and bool(def.get("params", {}).get("burn", false)) \
			and e.has_method("apply_status_burn"):
		var br: float = GameData.ENEMY_STATUS_FLAME_BURN_DPS_RATIO
		if weapon_upgrades_maxed():
			br *= 2.0
		e.apply_status_burn(
			hit_damage * br,
			GameData.ENEMY_STATUS_FLAME_BURN_DURATION,
			self)
