extends DrawerNode2D
class_name MagicBulletExplodeDebug
## 魔彈爆炸範圍除錯：風圈對齊爆炸第 4～5 幀的範圍傷害時機。

const DEFAULT_FPS := 16.0
const DEFAULT_FRAME_COUNT := 8
const DEFAULT_DAMAGE_FRAMES: Array[int] = [3, 4]


static func damage_delay_sec(explosion_cfg: Dictionary) -> float:
	var fps: float = maxf(1.0, float(explosion_cfg.get("fps", DEFAULT_FPS)))
	var frames: Array = explosion_cfg.get("damage_frames", DEFAULT_DAMAGE_FRAMES)
	if frames.is_empty():
		return 0.0
	var start_idx: int = int(frames[0])
	return maxf(0.0, float(start_idx) / fps)


static func damage_window_sec(explosion_cfg: Dictionary) -> float:
	var fps: float = maxf(1.0, float(explosion_cfg.get("fps", DEFAULT_FPS)))
	var frames: Array = explosion_cfg.get("damage_frames", DEFAULT_DAMAGE_FRAMES)
	if frames.is_empty():
		return 1.0 / fps
	var first: int = int(frames[0])
	var last: int = int(frames[frames.size() - 1])
	return maxf(1.0 / fps, float(last - first + 1) / fps)


static func display_duration_sec(explosion_cfg: Dictionary) -> float:
	var fps: float = maxf(1.0, float(explosion_cfg.get("fps", DEFAULT_FPS)))
	var count: int = maxi(1, int(explosion_cfg.get("frame_count", DEFAULT_FRAME_COUNT)))
	return float(count) / fps + 0.35


static func spawn(
		parent: Node,
		world_pos: Vector2,
		radius: float,
		explosion_cfg: Dictionary,
		enabled: bool = true) -> MagicBulletExplodeDebug:
	if not enabled or parent == null:
		return null
	var node := MagicBulletExplodeDebug.new()
	node.z_index = 62
	node.global_position = world_pos
	node._radius = radius
	node._explosion_cfg = explosion_cfg
	node._damage_delay = damage_delay_sec(explosion_cfg)
	node._damage_window = damage_window_sec(explosion_cfg)
	node._ttl = display_duration_sec(explosion_cfg)
	node.fn = node._draw_impl
	parent.add_child(node)
	return node


static func apply_aoe_damage(
		tree: SceneTree,
		weapon: Node,
		center: Vector2,
		radius: float,
		mult: float) -> void:
	if tree == null or weapon == null or not is_instance_valid(weapon):
		return
	for e in tree.get_nodes_in_group("enemies"):
		if e == null or not is_instance_valid(e):
			continue
		if e.get("hp") != null and float(e.hp) <= 0.0:
			continue
		if center.distance_to(e.global_position) <= radius:
			weapon.damage_enemy(e, mult)


var _radius: float = 50.0
var _explosion_cfg: Dictionary = {}
var _damage_delay: float = 0.0
var _damage_window: float = 0.0
var _ttl: float = 0.85
var _elapsed: float = 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= _ttl:
		queue_free()


func _draw_impl(node: Node2D) -> void:
	var rad: float = _radius
	var windup: float = maxf(0.001, _damage_delay)
	var ready: float = clampf(_elapsed / windup, 0.0, 1.0)
	var in_damage: bool = _elapsed >= _damage_delay \
			and _elapsed < _damage_delay + _damage_window
	var after_damage: bool = _elapsed >= _damage_delay + _damage_window
	var fade: float = clampf((_ttl - _elapsed) / 0.35, 0.0, 1.0)

	var fill_col: Color
	var ring_col: Color
	if in_damage:
		fill_col = Color(0.95, 0.35, 1.0, 0.42 * fade)
		ring_col = Color(1.0, 0.75, 1.0, 0.98 * fade)
	elif after_damage:
		fill_col = Color(0.55, 0.25, 0.85, 0.12 * fade)
		ring_col = Color(0.75, 0.45, 1.0, 0.45 * fade)
	else:
		fill_col = Color(0.55, 0.28, 0.95, 0.10 + ready * 0.18)
		ring_col = Color(0.7, 0.4, 1.0, 0.55 + ready * 0.35)

	node.draw_circle(Vector2.ZERO, rad, fill_col)
	node.draw_arc(Vector2.ZERO, rad, 0.0, TAU, 56, ring_col, 3.0 if in_damage else 2.0)
	node.draw_arc(Vector2.ZERO, rad * ready, 0.0, TAU, 48, Color(0.85, 0.55, 1.0, 0.7 * fade), 2.0)

	if in_damage:
		node.draw_arc(Vector2.ZERO, rad, 0.0, TAU, 56, Color(1.0, 1.0, 1.0, 0.35 * fade), 6.0)

	# 圓心 + 半徑端點，方便對齊實際 explode_radius
	node.draw_line(Vector2(-10, 0), Vector2(10, 0), Color(0.9, 0.85, 1.0, 0.85 * fade), 2.0)
	node.draw_line(Vector2(0, -10), Vector2(0, 10), Color(0.9, 0.85, 1.0, 0.85 * fade), 2.0)
	var edge := Vector2(rad, 0.0)
	node.draw_line(Vector2.ZERO, edge, Color(1.0, 0.9, 0.45, 0.9 * fade), 2.0)
	node.draw_circle(edge, 4.0, Color(1.0, 0.9, 0.35, 0.95 * fade))
