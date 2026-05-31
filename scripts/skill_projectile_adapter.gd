extends Node
class_name SkillProjectileAdapter
## 模擬最小化武器介面，用來讓既有 Projectile.tscn 在「不走武器系統」的情況下能被直接生成。
## Projectile 只用到 weapon.damage_enemy / weapon.def["params"] / weapon.eff_range。

var eff_damage: float = 20.0
var eff_range: float = 380.0
var def: Dictionary = {"params": {}}
var owner_player: Node = null


func damage_enemy(e: Node, mult: float = 1.0, _hit_ctx: Dictionary = {}) -> void:
	if not is_instance_valid(e):
		return
	if e.has_method("take_damage"):
		e.take_damage(eff_damage * mult, self)
