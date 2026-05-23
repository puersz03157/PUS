extends Area2D
## 金幣珠：被玩家拾取範圍偵測 -> 飛向玩家 -> 加入本局金幣。

var value: int = 1
var target: Node2D = null
var attract_speed: float = 380.0


func _ready() -> void:
	add_to_group("gold_orbs")
	PickupOrbVisual.apply_icon(self, GameData.gold_icon_path(), 22.0)


func attract_to(p: Node2D) -> void:
	target = p


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var dir: Vector2 = target.global_position - global_position
	var d: float = dir.length()
	if d < 12.0:
		AudioManager.play_sfx("pickup_gold", 0.06)
		if target.has_method("add_gold"):
			target.add_gold(value)
		queue_free()
		return
	attract_speed += 800.0 * delta
	global_position += dir.normalized() * attract_speed * delta
