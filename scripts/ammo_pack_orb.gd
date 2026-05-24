extends Area2D
## 槍械彈藥包：須碰觸拾取（不遠距離吸取）；拾取後八向齊射。
## 場上最多保留最新 10 個，較早掉落的會淡出消失。

var owner_player: Node = null
var _expiring: bool = false


func setup(p: Node) -> void:
	owner_player = p


func is_expiring() -> bool:
	return _expiring


func begin_expire() -> void:
	if _expiring:
		return
	_expiring = true
	monitoring = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, GameData.FIREARM_AMMO_PACK_EXPIRE_SEC)
	tw.tween_callback(queue_free)


func _ready() -> void:
	add_to_group("ammo_pack_orbs")
	monitoring = true
	# 僅偵測玩家本體（layer 2），不用 PickupArea 大範圍吸取
	collision_mask = 2
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	PickupOrbVisual.apply_icon(self, GameData.ammo_pack_icon_path(), 22.0)
	GameData.register_firearm_ammo_pack(self)


func _on_body_entered(body: Node) -> void:
	if _expiring:
		return
	if body == null or not is_instance_valid(body):
		return
	if not body.is_in_group("players"):
		return
	if body.has_method("collect_firearm_ammo_pack"):
		body.collect_firearm_ammo_pack()
	queue_free()
