extends RefCounted
## 雙人本機：最遠距離、動態縮放、攝影機邊界、螢幕邊緣箭頭（戰鬥／村莊共用）
##
## Camera2D.zoom：數值愈「大」愈拉近（看得較少）；拉遠時把 zoom 往 ZOOM_MIN 降。

const MAX_PAIR_SEPARATION := 900.0
## 超過此距離開始把鏡頭往外拉（與 MAX 之間平滑插值）
const ZOOM_OUT_START_DIST := 280.0
## 雙人拉最遠時的 zoom 下限（1280×720 下約可同時看到 ~1180 世界寬，包住 900 距離）
const ZOOM_MIN := 1.08
const POINTER_MARGIN := 56.0
const POINTER_RADIUS_FRAC := 0.92


static func clamp_player_pair_separation(players: Array) -> void:
	if players.size() < 2:
		return
	var p1: Node2D = players[0] as Node2D
	var p2: Node2D = players[1] as Node2D
	if p1 == null or p2 == null:
		return
	if "hp" in p1 and float(p1.hp) <= 0.0:
		return
	if "hp" in p2 and float(p2.hp) <= 0.0:
		return
	var d: Vector2 = p2.global_position - p1.global_position
	var L: float = d.length()
	if L <= MAX_PAIR_SEPARATION or L < 0.001:
		return
	var n: Vector2 = d / L
	var mid: Vector2 = (p1.global_position + p2.global_position) * 0.5
	var half_len: float = MAX_PAIR_SEPARATION * 0.5
	p1.global_position = mid - n * half_len
	p2.global_position = mid + n * half_len


static func camera_center_alive(players: Array) -> Vector2:
	var c := Vector2.ZERO
	var n: int = 0
	for p in players:
		if p == null:
			continue
		if "hp" in p and float(p.hp) > 0.0:
			c += (p as Node2D).global_position
			n += 1
	if n > 0:
		return c / float(n)
	if not players.is_empty() and players[0] != null:
		return (players[0] as Node2D).global_position
	return Vector2.ZERO


static func pair_distance(players: Array) -> float:
	if players.size() < 2:
		return 0.0
	var a: Node2D = players[0] as Node2D
	var b: Node2D = players[1] as Node2D
	if a == null or b == null:
		return 0.0
	return a.global_position.distance_to(b.global_position)


static func dynamic_zoom(dist: float, base_zoom: Vector2) -> Vector2:
	var span: float = MAX_PAIR_SEPARATION - ZOOM_OUT_START_DIST
	var t: float = 0.0 if span <= 0.0 else clampf((dist - ZOOM_OUT_START_DIST) / span, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	var z: float = lerpf(base_zoom.x, ZOOM_MIN, t)
	return Vector2(z, z)


static func clamp_camera_position(camera: Camera2D, map_size: Vector2, vp_size: Vector2) -> void:
	if camera == null:
		return
	var half: Vector2 = vp_size / (2.0 * camera.zoom)
	var c: Vector2 = camera.global_position
	c.x = clampf(c.x, half.x, max(half.x, map_size.x - half.x))
	c.y = clampf(c.y, half.y, max(half.y, map_size.y - half.y))
	camera.global_position = c


## 假設 Camera2D 無旋轉、offset 預設：螢幕座標（viewport 像素，左上 0,0）
static func world_to_screen_viewport(
		cam_center_world: Vector2, zoom: Vector2, vp_size: Vector2, world_pt: Vector2) -> Vector2:
	var ctr: Vector2 = vp_size * 0.5
	return ctr + (world_pt - cam_center_world) * zoom


static func is_on_screen(
		cam_center_world: Vector2, zoom: Vector2, vp_size: Vector2, world_pt: Vector2, margin_px: float) -> bool:
	var s: Vector2 = world_to_screen_viewport(cam_center_world, zoom, vp_size, world_pt)
	var m: float = margin_px
	return s.x >= m and s.y >= m and s.x <= vp_size.x - m and s.y <= vp_size.y - m


## 從螢幕中心沿「世界方向」把箭頭放在內側邊緣（俯視無鏡頭旋轉時與螢幕方向一致）
static func pointer_screen_pos(cam_center_world: Vector2, vp_size: Vector2, world_target: Vector2) -> Vector2:
	var scr_c: Vector2 = vp_size * 0.5
	var wdir: Vector2 = world_target - cam_center_world
	if wdir.length_squared() < 1.0:
		return scr_c
	var ang: float = wdir.angle()
	var r: float = minf(vp_size.x * 0.5 - POINTER_MARGIN, vp_size.y * 0.5 - POINTER_MARGIN) * POINTER_RADIUS_FRAC
	return scr_c + Vector2.RIGHT.rotated(ang) * r
