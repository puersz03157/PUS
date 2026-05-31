extends Node2D
## 村莊召喚獸跟隨：漂浮在主人身後，平滑追蹤並隨面向翻轉。

const DISPLAY_HEIGHT := 44.0
const FOLLOW_BASE_DIST := 36.0
const FOLLOW_SPREAD_X := 24.0
const FOLLOW_DEPTH_STEP := 12.0
const FLOAT_BASE_Y := -16.0
const BOB_AMPLITUDE := 5.0
const BOB_SPEED := 2.3
const FOLLOW_LERP_SPEED := 9.0

var _owner: Node2D = null
var _summon_id: String = ""
var _player_slot: String = "p1"
var _formation_index: int = 0
var _formation_count: int = 1
var _bob_time: float = 0.0

var _sprite: Sprite2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_ensure_sprite()


func _ensure_sprite() -> void:
	if _sprite != null:
		return
	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)


func setup(
		owner: Node2D,
		summon_id: String,
		player_slot: String,
		formation_index: int,
		formation_count: int,
) -> void:
	_owner = owner
	_summon_id = summon_id
	_player_slot = player_slot
	_formation_index = formation_index
	_formation_count = maxi(1, formation_count)
	_bob_time = randf() * TAU
	_ensure_sprite()
	_apply_visual()
	if _owner != null and is_instance_valid(_owner):
		global_position = _compute_target_position(0.0)


func _physics_process(delta: float) -> void:
	if _owner == null or not is_instance_valid(_owner):
		queue_free()
		return
	_bob_time += delta * BOB_SPEED
	var target: Vector2 = _compute_target_position(_bob_time)
	global_position = global_position.lerp(
		target, 1.0 - exp(-FOLLOW_LERP_SPEED * delta))
	z_index = int(global_position.y)
	_update_facing()


func _apply_visual() -> void:
	_ensure_sprite()
	var prog: Dictionary = GameState.get_summon_progress(_player_slot, _summon_id)
	var level: int = int(prog.get("level", GameData.SUMMON_MIN_LEVEL))
	var preview: Dictionary = GameData.resolve_summon_house_preview(_summon_id, level)
	if preview.is_empty():
		visible = false
		return
	var tex: Texture2D = preview.get("texture")
	if tex == null:
		visible = false
		return
	_sprite.texture = tex
	var layout: Dictionary = GameData.compute_centered_sprite_trim_layout(tex)
	var vis_h: float = float(layout.get("h", 32.0))
	var mul: float = float(preview.get("scale_mul", 1.0))
	var fit: float = DISPLAY_HEIGHT / maxf(1.0, vis_h) * mul
	_sprite.scale = Vector2(fit, fit)
	_sprite.position = Vector2(
		-float(layout.get("center_dx", 0.0)) * fit,
		-float(layout.get("center_dy", 0.0)) * fit,
	)
	visible = true


func refresh_visual() -> void:
	_apply_visual()


func _compute_target_position(bob_t: float) -> Vector2:
	var face: Vector2 = Vector2(_owner.get("face_dir"))
	if face.length_squared() < 0.001:
		face = Vector2.RIGHT
	face = face.normalized()
	var back: Vector2 = -face
	var lateral: Vector2 = Vector2(-face.y, face.x)
	var depth: float = FOLLOW_BASE_DIST + float(_formation_index) * FOLLOW_DEPTH_STEP * 0.4
	var lat: float = _formation_lateral_offset()
	var bob_y: float = sin(bob_t + float(_formation_index) * 0.85) * BOB_AMPLITUDE
	var off: Vector2 = back * depth + lateral * lat + Vector2(0.0, FLOAT_BASE_Y + bob_y)
	return _owner.global_position + off


func _formation_lateral_offset() -> float:
	if _formation_count <= 1:
		return 0.0
	if _formation_count == 2:
		return -FOLLOW_SPREAD_X * 0.55 if _formation_index == 0 else FOLLOW_SPREAD_X * 0.55
	match _formation_index:
		0:
			return 0.0
		1:
			return -FOLLOW_SPREAD_X
		2:
			return FOLLOW_SPREAD_X
		_:
			return (float(_formation_index) - 1.0) * FOLLOW_SPREAD_X


func _update_facing() -> void:
	_ensure_sprite()
	var face: Vector2 = Vector2(_owner.get("face_dir"))
	if face.x < -0.05:
		_sprite.flip_h = false
	elif face.x > 0.05:
		_sprite.flip_h = true
