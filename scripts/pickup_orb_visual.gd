extends RefCounted
class_name PickupOrbVisual
## 地上拾取物：以圖示取代 Polygon2D 占位。


static func apply_icon(parent: Node2D, icon_path: String, display_size: float = 22.0) -> void:
	if parent == null:
		return
	for child in parent.get_children():
		if child is Polygon2D:
			child.queue_free()
	if icon_path == "" or not ResourceLoader.exists(icon_path, "Texture2D"):
		return
	var tex: Texture2D = load(icon_path) as Texture2D
	if tex == null:
		return
	var spr := Sprite2D.new()
	spr.name = "Icon"
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = true
	var tw: float = float(maxi(1, tex.get_width()))
	var th: float = float(maxi(1, tex.get_height()))
	var sc: float = display_size / maxf(tw, th)
	spr.scale = Vector2.ONE * clampf(sc, 0.35, 4.0)
	parent.add_child(spr)
