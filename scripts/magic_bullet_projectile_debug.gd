extends DrawerNode2D
class_name MagicBulletProjectileDebug
## 魔彈飛行命中探測除錯：青圈 = 實際判定點，灰線 = 本體到探測點。

static func attach(owner: Area2D, cfg: Dictionary) -> MagicBulletProjectileDebug:
	if owner == null:
		return null
	var node := MagicBulletProjectileDebug.new()
	node._cfg = cfg
	node.z_index = 61
	node.fn = node._draw_impl
	owner.add_child(node)
	return node


var _cfg: Dictionary = {}


func _process(_delta: float) -> void:
	position = MagicBulletVfx.hit_probe_local_offset(_cfg)
	queue_redraw()


func _draw_impl(node: Node2D) -> void:
	var hit_r: float = MagicBulletVfx.hit_radius(_cfg)
	node.draw_circle(Vector2.ZERO, hit_r, Color(0.2, 0.85, 1.0, 0.22))
	node.draw_arc(Vector2.ZERO, hit_r, 0.0, TAU, 32, Color(0.35, 0.95, 1.0, 0.92), 2.0)
	# 沿美術前緣方向延伸，方便對齊紅圈標的彈頭尖端
	var tip_mark: Vector2 = MagicBulletVfx.art_direction(_cfg) * 8.0
	node.draw_line(Vector2.ZERO, tip_mark, Color(1.0, 0.45, 0.35, 0.85), 2.0)
	node.draw_circle(tip_mark, 3.0, Color(1.0, 0.35, 0.2, 0.9))
	var back: Vector2 = -position
	if back.length_squared() > 1.0:
		node.draw_line(back, Vector2.ZERO, Color(0.75, 0.75, 0.85, 0.55), 1.5)
		node.draw_circle(back, 3.0, Color(0.85, 0.85, 0.95, 0.75))
