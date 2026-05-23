extends Area2D
## 素材珠：拾取後加入背包（與金幣／經驗珠相同流程）。

var material_id: String = ""
var amount: int = 1
var target: Node2D = null
var attract_speed: float = 380.0


func setup(mat_id: String, qty: int) -> void:
	material_id = mat_id
	amount = maxi(1, qty)


func _ready() -> void:
	add_to_group("material_orbs")
	var path: String = GameData.material_icon_path(material_id)
	PickupOrbVisual.apply_icon(self, path, 20.0)


func attract_to(p: Node2D) -> void:
	target = p


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var dir: Vector2 = target.global_position - global_position
	var d: float = dir.length()
	if d < 12.0:
		_collect()
		return
	attract_speed += 800.0 * delta
	global_position += dir.normalized() * attract_speed * delta


func _collect() -> void:
	if material_id != "" and is_instance_valid(GameState):
		GameState.grant_run_material(material_id, amount)
	queue_free()
