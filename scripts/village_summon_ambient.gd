extends Node2D
## 村莊空曠處：已解鎖但未跟隨的召喚獸閒逛展示。

const DISPLAY_HEIGHT := 44.0
const BOB_AMPLITUDE := 4.5
const BOB_SPEED := 2.1
const WANDER_RADIUS := 56.0
const WANDER_SPEED := 28.0
const WANDER_WAIT_MIN := 2.8
const WANDER_WAIT_MAX := 5.5

var _village: Node = null
var _summon_id: String = ""
var _home: Vector2 = Vector2.ZERO
var _wander_target: Vector2 = Vector2.ZERO
var _bob_time: float = 0.0
var _wander_cd: float = 0.0

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


func setup(village: Node, summon_id: String, spawn_pos: Vector2) -> void:
	_village = village
	_summon_id = summon_id
	_home = spawn_pos
	_wander_target = spawn_pos
	_bob_time = randf() * TAU
	_wander_cd = randf_range(0.4, 1.2)
	_ensure_sprite()
	_apply_visual()
	global_position = spawn_pos
	_pick_wander_target()


func refresh_visual() -> void:
	_apply_visual()


func _apply_visual() -> void:
	_ensure_sprite()
	if _summon_id == "":
		visible = false
		return
	var prog: Dictionary = GameState.get_best_summon_progress(_summon_id)
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


func _physics_process(delta: float) -> void:
	if not visible:
		return
	_bob_time += delta * BOB_SPEED
	_wander_cd -= delta
	if _wander_cd <= 0.0:
		_wander_cd = randf_range(WANDER_WAIT_MIN, WANDER_WAIT_MAX)
		_pick_wander_target()
	var bob_y: float = sin(_bob_time) * BOB_AMPLITUDE
	var target_x: float = _wander_target.x
	var next_x: float = lerpf(global_position.x, target_x, 1.0 - exp(-WANDER_SPEED * delta * 0.035))
	var next_pos: Vector2 = Vector2(next_x, _home.y + bob_y)
	if _village != null and _village.has_method("is_world_blocked_at") \
			and _village.is_world_blocked_at(next_pos, 14.0):
		next_pos.x = global_position.x
	_pick_facing(next_x - global_position.x)
	global_position = next_pos
	z_index = int(global_position.y)


func _pick_wander_target() -> void:
	var ang: float = randf() * TAU
	_wander_target = _home + Vector2(cos(ang), 0.0) * randf_range(18.0, WANDER_RADIUS)
	if _village != null and _village.has_method("is_world_blocked_at") \
			and _village.is_world_blocked_at(_wander_target, 14.0):
		_wander_target = _home


func _pick_facing(dx: float) -> void:
	_ensure_sprite()
	if dx < -0.4:
		_sprite.flip_h = false
	elif dx > 0.4:
		_sprite.flip_h = true
