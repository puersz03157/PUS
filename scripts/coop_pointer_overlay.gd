extends Control
## 雙人：在螢幕邊緣畫指向另一名玩家的箭頭（由 host 提供 camera / players）

const Coop := preload("res://scripts/coop_pair_follow.gd")

var _host: Node2D = null


func setup(host: Node2D) -> void:
	_host = host
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 80
	show_behind_parent = false


func _process(_delta: float) -> void:
	if not is_instance_valid(_host) or not GameState.two_players:
		visible = false
		return
	if _host.get_tree().paused:
		visible = false
		return
	visible = true
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(_host) or not GameState.two_players:
		return
	var cam: Camera2D = _host.get("camera") as Camera2D
	var players: Array = _host.get("players") as Array
	if cam == null or players.size() < 2:
		return
	var p1: Node2D = players[0] as Node2D
	var p2: Node2D = players[1] as Node2D
	if p1 == null or p2 == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var zoom: Vector2 = cam.zoom
	var c: Vector2 = cam.global_position

	var show_p2: bool = not Coop.is_on_screen(c, zoom, vp, p2.global_position, 36.0)
	var show_p1: bool = not Coop.is_on_screen(c, zoom, vp, p1.global_position, 36.0)

	if show_p2:
		var pos: Vector2 = Coop.pointer_screen_pos(c, vp, p2.global_position)
		var ang: float = (p2.global_position - c).angle()
		_draw_arrow(pos, ang, Color(0.35, 0.95, 1.0, 0.92))
	if show_p1:
		var pos2: Vector2 = Coop.pointer_screen_pos(c, vp, p1.global_position)
		var ang2: float = (p1.global_position - c).angle()
		_draw_arrow(pos2, ang2, Color(1.0, 0.55, 0.35, 0.92))


func _draw_arrow(screen_pos: Vector2, angle_rad: float, col: Color) -> void:
	var r: float = 14.0
	var tip := screen_pos + Vector2.RIGHT.rotated(angle_rad) * r
	var base := screen_pos - Vector2.RIGHT.rotated(angle_rad) * (r * 0.35)
	var wing := Vector2.RIGHT.rotated(angle_rad + PI * 0.5) * (r * 0.55)
	var pts := PackedVector2Array([tip, base + wing, base - wing])
	draw_colored_polygon(pts, col)
	var outline := PackedVector2Array([tip, base + wing, base - wing, tip])
	draw_polyline(outline, Color(0, 0, 0, 0.45), 2.0, true)
