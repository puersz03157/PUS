extends Node2D
class_name StatusEffectOverlay
## 頭頂／身上狀態圖示（Elthen spritesheet）。燃燒掛身上，其餘多數在頭頂橫排。

const ICON_SCALE := 0.82
const HEAD_SPACING := 15.0
const PLAYER_ICON_SCALE_MUL := 1.45
const PLAYER_HEAD_SPACING := 18.0
const ENEMY_ICON_SCALE_MIN := 1.28
const ENEMY_ICON_SCALE_MAX := 1.48
const ENEMY_HEAD_SPACING := 16.0
const Z_OVERLAY := 24

## 頭頂列顯示順序（左→右）
const HEAD_ORDER: Array[String] = [
	StatusEffectIcons.STATUS_STUN,
	StatusEffectIcons.STATUS_BLEED,
	StatusEffectIcons.STATUS_SLOW,
	StatusEffectIcons.STATUS_POISON,
	StatusEffectIcons.STATUS_VULN,
	StatusEffectIcons.STATUS_REGEN,
	StatusEffectIcons.STATUS_RAGE_BUFF,
]

var _on_player: bool = true
var _head_anchor: Vector2 = Vector2(0.0, -58.0)
var _body_anchor: Vector2 = Vector2(2.0, -14.0)
var _scale_mul: float = 1.0
var _head_spacing: float = HEAD_SPACING
var _head_root: Node2D = null
var _body_root: Node2D = null
var _icons: Dictionary = {}
var _sprite_frames: SpriteFrames = null


func configure(
		on_player: bool,
		head_anchor_y: float,
		body_anchor: Vector2 = Vector2(2.0, -14.0),
		scale_mul: float = 1.0) -> void:
	_on_player = on_player
	_head_anchor = Vector2(0.0, head_anchor_y)
	_body_anchor = body_anchor
	_scale_mul = maxf(0.35, scale_mul)
	if on_player:
		_head_spacing = PLAYER_HEAD_SPACING
	else:
		_head_spacing = ENEMY_HEAD_SPACING
	z_index = Z_OVERLAY
	_ensure_roots()
	position = Vector2.ZERO
	_rescale_all_icons()


func _ensure_roots() -> void:
	if _head_root == null:
		_head_root = Node2D.new()
		_head_root.name = "HeadIcons"
		_head_root.position = _head_anchor
		add_child(_head_root)
	if _body_root == null:
		_body_root = Node2D.new()
		_body_root.name = "BodyIcons"
		_body_root.position = _body_anchor
		add_child(_body_root)
	_head_root.position = _head_anchor
	_body_root.position = _body_anchor


func sync(active: Dictionary) -> void:
	if _sprite_frames == null:
		_sprite_frames = StatusEffectIcons.sprite_frames()
	_ensure_roots()
	var want_head: Array[String] = []
	for sid in HEAD_ORDER:
		if bool(active.get(sid, false)):
			want_head.append(sid)
	var want_body: bool = bool(active.get(StatusEffectIcons.STATUS_BURN, false))
	var head_set: Dictionary = {}
	for sid in want_head:
		head_set[sid] = true
	_update_slot(StatusEffectIcons.STATUS_BURN, want_body, _body_root)
	for sid in HEAD_ORDER:
		_update_slot(sid, head_set.has(sid), _head_root)
	for sid in _icons.keys():
		var k: String = String(sid)
		if k == StatusEffectIcons.STATUS_BURN:
			continue
		if not head_set.has(k):
			_update_slot(k, false, _head_root)
	_layout_head_row(want_head)
	visible = not _icons.is_empty()


func _update_slot(status_id: String, on: bool, parent: Node2D) -> void:
	if not on:
		if _icons.has(status_id):
			var node: Node = _icons[status_id]
			if is_instance_valid(node):
				node.queue_free()
			_icons.erase(status_id)
		return
	if _icons.has(status_id) and is_instance_valid(_icons[status_id]):
		var existing: AnimatedSprite2D = _icons[status_id]
		var sc0: float = ICON_SCALE * _scale_mul
		existing.scale = Vector2.ONE * sc0
		return
	var layer: String = StatusEffectIcons.layer_name_for(status_id, _on_player)
	if layer == "" or _sprite_frames == null or not _sprite_frames.has_animation(layer):
		return
	var spr := AnimatedSprite2D.new()
	spr.name = "Icon_%s" % status_id
	spr.sprite_frames = _sprite_frames
	spr.animation = layer
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sc: float = ICON_SCALE * _scale_mul
	spr.scale = Vector2.ONE * sc
	spr.z_index = 1
	parent.add_child(spr)
	spr.play()
	_icons[status_id] = spr


func _layout_head_row(order: Array[String]) -> void:
	if _head_root == null:
		return
	var n: int = order.size()
	if n == 0:
		return
	var total_w: float = float(n - 1) * _head_spacing
	var start_x: float = -total_w * 0.5
	for i in n:
		var sid: String = order[i]
		if not _icons.has(sid):
			continue
		var spr: AnimatedSprite2D = _icons[sid]
		if not is_instance_valid(spr) or spr.get_parent() != _head_root:
			continue
		spr.position = Vector2(start_x + float(i) * _head_spacing, 0.0)


func _rescale_all_icons() -> void:
	var sc: float = ICON_SCALE * _scale_mul
	for sid in _icons.keys():
		var spr: AnimatedSprite2D = _icons[sid]
		if is_instance_valid(spr):
			spr.scale = Vector2.ONE * sc
