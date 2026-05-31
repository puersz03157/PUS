extends Node
class_name SummonCombatAdapter
## 召喚獸戰鬥：供 Projectile 或近戰命中使用，傷害計入主人統計。

var eff_damage: float = 1.0
var eff_range: float = 120.0
var def: Dictionary = {"params": {}}
var owner_player: Node = null
var hit_vfx_id: String = ""
var hit_vfx_scale: float = 1.0
var summon_id: String = ""
var combat_params: Dictionary = {}


func damage_enemy(e: Node, mult: float = 1.0, hit_ctx: Dictionary = {}) -> void:
	if not is_instance_valid(e):
		return
	if bool(hit_ctx.get("splash_only", false)):
		var splash_dealt: float = eff_damage * mult
		if e.has_method("take_damage"):
			e.take_damage(splash_dealt, self)
		_spawn_hit_vfx(e, hit_ctx)
		return
	var mult_final: float = mult
	var is_crit: bool = bool(hit_ctx.get("is_crit", false))
	var abilities: Dictionary = combat_params.get("abilities", {})
	if summon_id == "brawno" and not is_crit:
		var crit_ch: float = float(abilities.get("crit_chance", 0.0))
		if crit_ch > 0.001 and randf() < crit_ch:
			is_crit = true
			mult_final *= float(abilities.get("crit_mult", 2.0))
	var dealt: float = eff_damage * mult_final
	if e.has_method("take_damage"):
		e.take_damage(dealt, self, {"is_crit": is_crit})
	_spawn_hit_vfx(e, hit_ctx)
	_apply_summon_on_hit_effects(e, dealt, abilities)
	if summon_id == "brawno":
		var aoe_ch: float = float(abilities.get("aoe_chance", 0.0))
		if aoe_ch > 0.001 and randf() < aoe_ch:
			_apply_brawno_aoe_splash(e, abilities)


func _apply_summon_on_hit_effects(enemy: Node, dealt: float, abilities: Dictionary) -> void:
	if not is_instance_valid(enemy):
		return
	match summon_id:
		"frcloudy":
			if enemy.has_method("apply_status_slow"):
				enemy.apply_status_slow(
					float(abilities.get("slow_duration", GameData.ENEMY_STATUS_ICE_SLOW_DURATION)),
					float(abilities.get("slow_factor", GameData.ENEMY_STATUS_ICE_SLOW_FACTOR)))
		"scarfner":
			var burn_ch: float = float(abilities.get("burn_chance", 0.0))
			if burn_ch > 0.001 and randf() < burn_ch and enemy.has_method("apply_status_burn"):
				var br: float = float(abilities.get("burn_dps_ratio", GameData.ENEMY_STATUS_FLAME_BURN_DPS_RATIO))
				enemy.apply_status_burn(
					dealt * br,
					float(abilities.get("burn_duration", GameData.ENEMY_STATUS_FLAME_BURN_DURATION)),
					self)


func _apply_brawno_aoe_splash(primary: Node, abilities: Dictionary) -> void:
	if not (primary is Node2D):
		return
	var center: Vector2 = (primary as Node2D).global_position
	var splash_radius: float = float(abilities.get("aoe_radius", 54.0))
	var splash_mult: float = float(abilities.get("aoe_damage_mult", 0.58))
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == null or not is_instance_valid(node) or node == primary:
			continue
		if not (node is Node2D):
			continue
		if node.get("hp") != null and float(node.hp) <= 0.0:
			continue
		if center.distance_to((node as Node2D).global_position) > splash_radius:
			continue
		damage_enemy(node, splash_mult, {"splash_only": true})


func _spawn_hit_vfx(enemy: Node, hit_ctx: Dictionary) -> void:
	if hit_vfx_id == "" or not (enemy is Node2D):
		return
	if not WeaponHitVfx.has_effect(hit_vfx_id):
		return
	var variant: String = String(hit_ctx.get("variant", ""))
	if variant == "" and hit_vfx_id == "boxing":
		variant = "R1" if randf() < 0.5 else "R2"
	WeaponHitVfx.spawn_on_enemy(
		enemy as Node2D, hit_vfx_id, variant, "", hit_vfx_scale)
