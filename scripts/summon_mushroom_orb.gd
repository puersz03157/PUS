extends Area2D
## 苔蘚蟲蘑菇：須碰觸拾取（紅／藍／綠）；紫菇僅敵人觸發爆炸。每種最多 3 個。

var owner_player: Node = null
var mushroom_kind: String = "red"
var combat_params: Dictionary = {}
var _expiring: bool = false
var _configured: bool = false


func setup(kind: String, player: Node, params: Dictionary, at: Vector2) -> void:
	mushroom_kind = kind
	owner_player = player
	combat_params = params
	global_position = at
	_configured = true


func is_expiring() -> bool:
	return _expiring


func begin_expire() -> void:
	if _expiring:
		return
	_expiring = true
	monitoring = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, GameData.SUMMON_MUSHROOM_EXPIRE_FADE_SEC)
	tw.tween_callback(queue_free)


func _ready() -> void:
	if not _configured:
		push_warning("[SummonMushroomOrb] setup() must run before add_child().")
	add_to_group("summon_mushroom_orbs")
	monitoring = true
	collision_layer = 64
	if mushroom_kind == "purple":
		collision_mask = GameData.ENEMY_PHYSICS_LAYER_MASK
	else:
		collision_mask = GameData.PLAYER_PHYSICS_LAYER_MASK
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	var icon: String = GameData.mushroom_icon_path(mushroom_kind)
	PickupOrbVisual.apply_icon(self, icon, 20.0)
	GameData.register_summon_mushroom(self, mushroom_kind)
	var life: float = GameData.SUMMON_MUSHROOM_LIFETIME_SEC
	get_tree().create_timer(life).timeout.connect(begin_expire)


func _on_body_entered(body: Node) -> void:
	if _expiring or body == null or not is_instance_valid(body):
		return
	if mushroom_kind == "purple":
		if body.is_in_group("enemies"):
			_trigger_purple_explosion()
		return
	if not body.is_in_group("players"):
		return
	if body != owner_player:
		return
	if body.has_method("collect_summon_mushroom"):
		body.collect_summon_mushroom(mushroom_kind, combat_params)
	queue_free()


func _trigger_purple_explosion() -> void:
	if _expiring:
		return
	_expiring = true
	monitoring = false
	var center: Vector2 = global_position
	var radius: float = GameData.SUMMON_MUSHROOM_PURPLE_RADIUS
	var base_dmg: float = maxf(1.0, float(combat_params.get("damage", 1)))
	var dmg: float = base_dmg * GameData.SUMMON_MUSHROOM_PURPLE_DMG_SCALE
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == null or not is_instance_valid(node) or not (node is Node2D):
			continue
		if node.get("hp") != null and float(node.hp) <= 0.0:
			continue
		if center.distance_to((node as Node2D).global_position) > radius:
			continue
		if node.has_method("take_damage"):
			node.take_damage(dmg, self)
		if node.has_method("apply_status_vulnerable"):
			node.apply_status_vulnerable(
				GameData.SUMMON_MUSHROOM_PURPLE_VULN_DURATION,
				GameData.SUMMON_MUSHROOM_PURPLE_VULN_STACKS)
	queue_free()
