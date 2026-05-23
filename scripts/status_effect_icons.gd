extends RefCounted
class_name StatusEffectIcons
## Elthen 狀態圖示：對照 gameplay 狀態 → spritesheet 列名。
## 素材：res://assets/Effects/Status Effects Sprite Sheet.png + .json

const SHEET_PATH := "res://assets/Effects/Status Effects Sprite Sheet.png"
const JSON_PATH := "res://assets/Effects/Status Effects Sprite Sheet.json"
const FRAME_W := 32
const FRAME_H := 32
const FRAMES_PER_ANIM := 8
const ANIM_FPS := 10.0  # JSON duration 100 ms

## spritesheet 列名（與 Aseprite meta.layers 順序一致，row = 索引 × 32px）
const LAYER_STUN_1 := "Stun 1"
const LAYER_STUN_2 := "Stun 2"
const LAYER_POISONED_1 := "Poisoned 1"
const LAYER_POISONED_2 := "Poisoned 2"
const LAYER_BURN := "Burn"
const LAYER_FREEZE := "Freeze"  # 保留：真・冰凍硬控；不用於「僅降移速」
const LAYER_CURSED := "Cursed"
const LAYER_REGEN := "Regeneration"
const LAYER_BLEEDING := "Bleeding"
const LAYER_WET := "Wet"
const LAYER_RAGE := "Rage"

const LAYER_ROW_INDEX: Dictionary = {
	LAYER_STUN_1: 0,
	LAYER_STUN_2: 1,
	LAYER_POISONED_1: 2,
	LAYER_POISONED_2: 3,
	LAYER_BURN: 6,
	LAYER_FREEZE: 7,
	LAYER_CURSED: 14,
	LAYER_REGEN: 17,
	LAYER_BLEEDING: 18,
	LAYER_WET: 19,
	LAYER_RAGE: 5,
}

## 遊戲內狀態 id（與 player / enemy 變數、hit_effects 鍵名對齊）
const STATUS_SLOW := "slow"
const STATUS_STUN := "stun"
const STATUS_BLEED := "bleed"
const STATUS_BURN := "burn"
const STATUS_POISON := "poison"
const STATUS_VULN := "vulnerable"
const STATUS_KNOCKBACK := "knockback"
const STATUS_REGEN := "regen"
const STATUS_RAGE_BUFF := "rage_buff"

static var _sprite_frames_cache: SpriteFrames = null


## @param status_id 見 STATUS_* 常數
## @param on_player true=套在玩家身上的 debuff/buff；false=套在敵人身上
static func layer_name_for(status_id: String, on_player: bool) -> String:
	match status_id:
		STATUS_SLOW:
			return LAYER_WET
		STATUS_STUN:
			return LAYER_STUN_1
		STATUS_BLEED:
			return LAYER_BLEEDING
		STATUS_BURN:
			return LAYER_BURN
		STATUS_POISON:
			return LAYER_POISONED_2 if on_player else LAYER_POISONED_1
		STATUS_VULN:
			return LAYER_CURSED
		STATUS_REGEN:
			return LAYER_REGEN
		STATUS_RAGE_BUFF:
			return LAYER_RAGE
		_:
			return ""


static func row_index_for_layer(layer_name: String) -> int:
	return int(LAYER_ROW_INDEX.get(layer_name, -1))


static func sprite_frames() -> SpriteFrames:
	if _sprite_frames_cache != null:
		return _sprite_frames_cache
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var tex: Texture2D = load(SHEET_PATH) as Texture2D
	if tex == null:
		push_warning("[StatusEffectIcons] 找不到圖集：%s" % SHEET_PATH)
		_sprite_frames_cache = sf
		return sf
	for layer_name in LAYER_ROW_INDEX.keys():
		var row: int = int(LAYER_ROW_INDEX[layer_name])
		var anim := String(layer_name)
		if sf.has_animation(anim):
			continue
		sf.add_animation(anim)
		sf.set_animation_speed(anim, ANIM_FPS)
		sf.set_animation_loop(anim, true)
		for f in FRAMES_PER_ANIM:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(f * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H)
			sf.add_frame(anim, at)
	_sprite_frames_cache = sf
	return sf
