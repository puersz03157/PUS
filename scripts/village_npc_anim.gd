extends Node2D
## 村莊 NPC：sprite strip 待機循環（橫向 hframes；可選 vframes 多列）

@export var strip_texture: Texture2D
@export var hframes: int = 10
@export var vframes: int = 1
@export var anim_row: int = 0
@export var anim_fps: float = 6.0
@export var target_height: float = 72.0
## 標記根節點處的腳底錨點（local Y）；配合 visible 像素對齊。
@export var feet_anchor_y: float = 42.0
@export var feet_fine_y: float = 0.0

var _sprite: Sprite2D
var _anim_time: float = 0.0


func _ready() -> void:
	_sprite = get_node_or_null("Sprite") as Sprite2D
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		add_child(_sprite)
	_apply_strip()


func _apply_strip() -> void:
	if _sprite == null:
		return
	_sprite.texture = strip_texture
	_sprite.hframes = maxi(1, hframes)
	_sprite.vframes = maxi(1, vframes)
	var row: int = clampi(anim_row, 0, _sprite.vframes - 1)
	_sprite.frame = row * _sprite.hframes
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if strip_texture:
		var vf: int = maxi(1, vframes)
		var frame_h: float = float(maxi(1, strip_texture.get_height())) / float(vf)
		if frame_h > 0.0:
			_sprite.scale = Vector2.ONE * (target_height / frame_h)
		_sprite.position = Vector2(
			0.0,
			GameData.sprite_strip_feet_offset_y(
				strip_texture,
				hframes,
				target_height,
				feet_anchor_y,
				0,
				feet_fine_y,
				vframes,
				row,
			),
		)


func _process(delta: float) -> void:
	if _sprite == null or _sprite.texture == null:
		return
	var hf: int = maxi(1, hframes)
	if hf <= 1:
		return
	_anim_time += delta
	var col: int = int(_anim_time * anim_fps) % hf
	var row: int = clampi(anim_row, 0, maxi(1, vframes) - 1)
	_sprite.frame = row * hf + col
