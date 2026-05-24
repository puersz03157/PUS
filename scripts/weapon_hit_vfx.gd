extends RefCounted
class_name WeaponHitVfx
## sagak-art-pururu 擊中特效：橫向 spritesheet，於敵人中心播放一次。

const EFFECTS_ROOT := "res://assets/Effects/"
const DEFAULT_FPS := 14.0
const DEFAULT_Z_INDEX := 57

## weapon_id → 設定；variants 為 R1/R2 隨機；modes 為槍械滿級散射／貫穿
const DEFS: Dictionary = {
	"sword": {
		"file_prefix": "Sword",
		"variants": ["R1", "R2"],
		"frame_w": 79,
		"frame_h": 79,
		"frame_count": 4,
		"fps": 14.0,
	},
	"spear": {
		"file_prefix": "Spear",
		"variants": ["R1", "R2"],
		"frame_w": 79,
		"frame_h": 79,
		"frame_count": 4,
		"fps": 14.0,
	},
	"boxing": {
		"file_prefix": "boxing",
		"variants": ["R1", "R2"],
		"frame_w": 59,
		"frame_h": 64,
		"frame_count": 4,
		"fps": 14.0,
	},
	"firearm": {
		"file_prefix": "firearm",
		"modes": {
			"": "",
			"scatter": "_Spread",
			"pierce": "_Penetration",
		},
		"mode_frames": {
			"": {"frame_w": 39, "frame_h": 39, "frame_count": 4},
			"scatter": {"frame_w": 55, "frame_h": 41, "frame_count": 4},
			"pierce": {"frame_w": 48, "frame_h": 36, "frame_count": 4},
		},
		"fps": 14.0,
	},
	"ice": {
		"file_prefix": "ice",
		"frame_w": 35,
		"frame_h": 33,
		"frame_count": 4,
		"fps": 14.0,
	},
	"flame": {
		"file_prefix": "flame",
		"frame_w": 40,
		"frame_h": 35,
		"frame_count": 4,
		"fps": 14.0,
	},
	"holy": {
		"file_prefix": "holy",
		"frame_w": 79,
		"frame_h": 79,
		"frame_count": 4,
		"fps": 14.0,
	},
	"shard": {
		"file_prefix": "shard",
		"frame_w": 29,
		"frame_h": 22,
		"frame_count": 4,
		"fps": 14.0,
	},
}

## 環繞武器每幀判定命中，特效需冷卻避免洗版
const ORBIT_HIT_VFX_INTERVAL := 0.38

static var _sprite_frames_cache: Dictionary = {}
static var _spawn_cooldown_until: Dictionary = {}


static func has_effect(weapon_id: String) -> bool:
	return DEFS.has(weapon_id)


static func spawn_on_enemy(
		enemy: Node2D,
		weapon_id: String,
		variant: String = "",
		weapon_kind: String = "") -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if weapon_kind == "orbit":
		if not _try_acquire_spawn_slot(enemy, weapon_id, ORBIT_HIT_VFX_INTERVAL):
			return
	var cfg: Dictionary = resolve_sheet(weapon_id, variant)
	if cfg.is_empty():
		return
	var tree: SceneTree = enemy.get_tree()
	if tree == null:
		return
	var parent: Node = tree.current_scene
	if parent == null:
		return
	spawn_at(parent, enemy.global_position, cfg)


static func resolve_sheet(weapon_id: String, variant: String = "") -> Dictionary:
	if not DEFS.has(weapon_id):
		return {}
	var def: Dictionary = DEFS[weapon_id]
	var prefix: String = String(def.get("file_prefix", weapon_id))
	var suffix: String = ""
	var frame_w: int = int(def.get("frame_w", 32))
	var frame_h: int = int(def.get("frame_h", 32))
	var frame_count: int = int(def.get("frame_count", 4))
	var fps: float = float(def.get("fps", DEFAULT_FPS))

	if def.has("variants"):
		var variants: Array = def["variants"]
		if variants.is_empty():
			return {}
		var pick: String = String(variants[randi() % variants.size()])
		suffix = pick
	elif def.has("modes"):
		var modes: Dictionary = def["modes"]
		var mode_key: String = variant if modes.has(variant) else ""
		suffix = String(modes.get(mode_key, ""))
		var mode_frames: Dictionary = def.get("mode_frames", {})
		if mode_frames.has(mode_key):
			var mf: Dictionary = mode_frames[mode_key]
			frame_w = int(mf.get("frame_w", frame_w))
			frame_h = int(mf.get("frame_h", frame_h))
			frame_count = int(mf.get("frame_count", frame_count))

	var sheet_path: String = EFFECTS_ROOT + "%s_Hit(fx)%s.png" % [prefix, suffix]
	if not ResourceLoader.exists(sheet_path, "Texture2D"):
		return {}
	return {
		"sheet": sheet_path,
		"frame_w": frame_w,
		"frame_h": frame_h,
		"frame_count": frame_count,
		"fps": fps,
	}


static func spawn_at(parent: Node, world_pos: Vector2, cfg: Dictionary) -> Node2D:
	if parent == null or cfg.is_empty():
		return null
	var sheet_path: String = String(cfg.get("sheet", ""))
	if sheet_path == "" or not ResourceLoader.exists(sheet_path, "Texture2D"):
		return null
	var tex: Texture2D = load(sheet_path) as Texture2D
	if tex == null:
		return null
	var fw: int = maxi(1, int(cfg.get("frame_w", 32)))
	var fh: int = maxi(1, int(cfg.get("frame_h", 32)))
	var frame_count: int = maxi(1, int(cfg.get("frame_count", 4)))
	var fps: float = maxf(1.0, float(cfg.get("fps", DEFAULT_FPS)))

	var root := Node2D.new()
	root.global_position = world_pos
	root.z_index = int(cfg.get("z_index", DEFAULT_Z_INDEX))
	var spr := AnimatedSprite2D.new()
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.sprite_frames = _sprite_frames_for(sheet_path, tex, fw, fh, frame_count, fps)
	root.add_child(spr)
	parent.add_child(root)
	spr.play(&"hit")
	spr.animation_finished.connect(root.queue_free, CONNECT_ONE_SHOT)
	return root


static func _sprite_frames_for(
		sheet_path: String,
		tex: Texture2D,
		fw: int,
		fh: int,
		frame_count: int,
		fps: float) -> SpriteFrames:
	var key: String = "%s|%d|%d|%d" % [sheet_path, fw, fh, frame_count]
	if _sprite_frames_cache.has(key):
		return _sprite_frames_cache[key]
	var sf := SpriteFrames.new()
	sf.add_animation(&"hit")
	sf.set_animation_speed(&"hit", fps)
	sf.set_animation_loop(&"hit", false)
	for i in frame_count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, fh)
		sf.add_frame(&"hit", at)
	_sprite_frames_cache[key] = sf
	return sf


static func _try_acquire_spawn_slot(enemy: Node2D, weapon_id: String, interval: float) -> bool:
	var key: String = "%s|%d" % [weapon_id, enemy.get_instance_id()]
	var now: float = Time.get_ticks_msec() * 0.001
	if float(_spawn_cooldown_until.get(key, 0.0)) > now:
		return false
	_spawn_cooldown_until[key] = now + interval
	return true
