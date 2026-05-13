extends CharacterBody2D
## 玩家：移動、HP、經驗、升級、武器管理。
## P1 / P2 共用此腳本，由 input_prefix + slot_index 區分。

signal leveled_up(player: Node)
signal died(player: Node)

@export var input_prefix: String = "p1"
@export var character_id: String = "swordsman"
@export var slot_index: int = 0
# 村莊模式：純漫遊（不持武器、不發動技能、不受傷害）
@export var village_mode: bool = false

var max_hp: float = 100.0
var hp: float = 100.0
var atk: float = 10.0
var def_value: float = 0.0
var move_speed: float = 200.0
var color: Color = Color.WHITE

var hp_mult: float = 1.0
var speed_mult: float = 1.0
var damage_mult: float = 1.0
var rate_mult: float = 1.0
var pickup_mult: float = 1.0
var xp_mult: float = 1.0
var dmg_reduce: float = 0.0
var regen_per_sec: float = 0.0

# 共用等級系統 — 實際資料存在 Game.team_level / team_xp，這裡為了 HUD/_draw 同步暫存
var level: int = 1
var xp: float = 0.0
var xp_to_next: float = 5.0

# 被動 / 主動技能（角色選擇畫面挑選）
var passive_id: String = "none"
var skill_id: String = "none"
var armament_id: String = "none"
var skill_cooldown: float = 0.0

# 重裝防禦：剩餘格擋次數（每次受傷扣 1，傷害無視）
var block_charges: int = 0

# 靈敏戰技：彈珠台累積、戰鬥釋放時消耗
var ranger_arrows: int = 0
const RANGER_ARROW_HARD_CAP := 5

# 技能量表（被動充能）：0～100，滿則立刻完成主動技能冷卻並扣除 100
const SKILL_METER_MAX := 100.0
var skill_meter: float = 0.0
# 被動充能後 5 秒內不再因被動增加量表（兩個被動共用此計時）
var passive_meter_fill_cd: float = 0.0
# 鬥志高昂：擊殺計數（滿 5 且可充能時觸發）
var passive_kill_counter: int = 0
# 快射節奏：武器命中計數（滿 N 且可充能時觸發）
var passive_hit_counter: int = 0

var kills: int = 0
# 結算統計：造成傷害 / 承受傷害（實際扣血）/ 彈珠台累積分數 / 取得的局內加成清單
var damage_dealt: float = 0.0
var damage_taken: float = 0.0
var pinball_score: int = 0
var common_upgrade_log: Dictionary = {}   # upgrade_id -> count
var start_weapon_reward_log: Array[Dictionary] = []
var face_dir: Vector2 = Vector2.RIGHT
var iframe: float = 0.0

const WEAPON_SLOT_MAX := 5

# 武器：[{id, level, upgrades:{w_damage:n, ...}, node}]
var weapons: Array = []

const PICKUP_BASE_RADIUS := 210.0

# 村莊（橫向）模式參數
const VILLAGE_GRAVITY := 1800.0
const VILLAGE_JUMP_SPEED := 620.0
const VILLAGE_AIR_CONTROL := 0.85   # 空中橫向加速能力（相較地面）
var village_on_floor: bool = false

@onready var sprite: Polygon2D = $Sprite
@onready var char_sprite: Sprite2D = $CharSprite
@onready var body_shape: CollisionShape2D = $Body
@onready var pickup_shape: CollisionShape2D = $PickupArea/Shape
@onready var weapons_root: Node2D = $Weapons

var game_ref: Node = null
## 本體半徑：物理碰撞 + is_world_blocked_at／村莊落地（由角色表 body_radius 或預設 42）
var body_radius: float = 42.0

# 動畫狀態 — 待機 / 行走 / 攻擊可由角色定義覆寫；受擊與死亡一律為最後兩列（vframes-2、vframes-1）
var row_idle: int = 0
var row_walk: int = 1
var row_attack: int = 3
var row_hit: int = 4
var row_death: int = 5
const ANIM_FPS := 8.0
var anim_state: String = "idle"
var anim_time: float = 0.0
var anim_locked_for: float = 0.0
var frames_per_row: Array = []

# 條狀精靈（多張橫向動畫條，列數固定為 1）— 例：SwordMan idle/run/attack 各一張
var _use_sprite_strips: bool = false
var _sprite_strip_tex: Dictionary = {}
var _sprite_faces_left: bool = false
var _strip_hframes: int = 1
## 各條圖不同橫向格數（例：Mage IDLE/WALK 寬度不同）；空則全部用 strip_hframes
var _strip_hframes_by_strip: Dictionary = {}
var _strip_frames: Dictionary = {}
var _strip_fps: Dictionary = {}
var _start_transform_pending: bool = false
var _start_transform_done: bool = false
# 逐幀 PNG（每個動作一組獨立 PNG，例：NightLord / SalamanderWitch）
var _use_sprite_frames: bool = false
var _sprite_frame_anims: Dictionary = {}  # state(idle/walk/attack/hurt/death) -> Array[Texture2D]
# 動畫播放速率：sprite_frames 通常張數較多，可在角色表用 anim_fps 覆寫（預設 ANIM_FPS）
var _anim_fps: float = ANIM_FPS
## 方向鍵按住時走路動畫覆蓋攻擊演出（條狀精靈 + 角色表 walk_anim_over_attack）
var _walk_anim_over_attack: bool = false


func setup_from_character(cid: String) -> void:
	character_id = cid
	var c := GameData.get_character_def(cid)
	if c.is_empty():
		c = GameData.CHARACTERS[0]
	max_hp = c["hp"]
	hp = max_hp
	atk = c["atk"]
	def_value = c["def"]
	move_speed = c["spd"] * 36.0
	color = c["color"]
	if sprite:
		sprite.color = color
	var br: float = clampf(float(c.get("body_radius", 42.0)), 8.0, 160.0)
	body_radius = br
	if body_shape and body_shape.shape is CircleShape2D:
		(body_shape.shape as CircleShape2D).radius = body_radius
	# 套用角色貼圖（若有）
	var has_sprite: bool = false
	_use_sprite_strips = false
	_use_sprite_frames = false
	_walk_anim_over_attack = false
	_sprite_strip_tex.clear()
	_strip_hframes_by_strip.clear()
	_strip_fps.clear()
	_sprite_frame_anims.clear()
	_start_transform_pending = false
	_start_transform_done = false
	_anim_fps = float(c.get("anim_fps", ANIM_FPS))
	# 1) 逐幀 PNG（每動作一組獨立檔，可用 Array 或 {pattern, count, start} 兩種格式）
	if char_sprite and c.has("sprite_frames") and c["sprite_frames"] is Dictionary:
		var fdict: Dictionary = c["sprite_frames"]
		var need_f: Array[String] = ["idle", "walk", "attack"]
		var f_ok: bool = true
		for fkey in need_f:
			var arr_paths: Array = _resolve_frame_paths(fdict.get(fkey, null))
			if arr_paths.is_empty():
				f_ok = false
				break
			var tex_arr: Array = []
			for p in arr_paths:
				var t: Texture2D = load(String(p))
				if t == null:
					f_ok = false
					break
				tex_arr.append(t)
			if not f_ok:
				break
			_sprite_frame_anims[fkey] = tex_arr
		if f_ok:
			for opt_f in ["hurt", "death"]:
				var arr_opt: Array = _resolve_frame_paths(fdict.get(opt_f, null))
				if arr_opt.is_empty():
					continue
				var tex_arr2: Array = []
				for p2 in arr_opt:
					var t2: Texture2D = load(String(p2))
					if t2:
						tex_arr2.append(t2)
				if not tex_arr2.is_empty():
					_sprite_frame_anims[opt_f] = tex_arr2
		if f_ok and _sprite_frame_anims.size() >= 3:
			_use_sprite_frames = true
			char_sprite.texture = (_sprite_frame_anims["idle"] as Array)[0]
			char_sprite.hframes = 1
			char_sprite.vframes = 1
			char_sprite.frame = 0
			char_sprite.scale = Vector2.ONE * float(c.get("scale", 1.0))
			char_sprite.offset = Vector2(0, float(c.get("offset_y", 0)))
			char_sprite.modulate = c.get("tint", Color.WHITE)
			char_sprite.visible = true
			_sprite_faces_left = bool(c.get("sprite_faces_left", false))
			_walk_anim_over_attack = bool(c.get("walk_anim_over_attack", false))
			frames_per_row = []
			has_sprite = true
	if not has_sprite and char_sprite and c.has("sprite_strips") and c["sprite_strips"] is Dictionary:
		var strips: Dictionary = c["sprite_strips"]
		var need: Array[String] = ["idle", "walk", "attack"]
		var all_ok: bool = true
		for key in need:
			if not strips.has(key) or String(strips[key]).is_empty():
				all_ok = false
				break
		if all_ok:
			for key in need:
				var st: Texture2D = load(String(strips[key]))
				if st == null:
					all_ok = false
					break
				_sprite_strip_tex[key] = st
			for opt in ["hurt", "death", "human_idle", "transform"]:
				if strips.has(opt) and String(strips[opt]) != "":
					var st2: Texture2D = load(String(strips[opt]))
					if st2:
						_sprite_strip_tex[opt] = st2
		if all_ok and _sprite_strip_tex.size() >= 3:
			_use_sprite_strips = true
			char_sprite.texture = _sprite_strip_tex["idle"]
			_strip_hframes = maxi(1, int(c.get("strip_hframes", 8)))
			if c.has("strip_hframes_by_strip") and c["strip_hframes_by_strip"] is Dictionary:
				for hk in c["strip_hframes_by_strip"]:
					_strip_hframes_by_strip[String(hk)] = int(c["strip_hframes_by_strip"][hk])
			char_sprite.hframes = _hframes_for_strip_key("idle")
			char_sprite.vframes = 1
			char_sprite.scale = Vector2.ONE * float(c.get("scale", 1.8))
			char_sprite.offset = Vector2(0, float(c.get("offset_y", 0)))
			char_sprite.frame = 0
			char_sprite.modulate = c.get("tint", Color.WHITE)
			char_sprite.visible = true
			_sprite_faces_left = bool(c.get("sprite_faces_left", false))
			_strip_frames = {
				"idle": _strip_hframes, "walk": _strip_hframes, "attack": _strip_hframes,
				"hit": _strip_hframes, "death": _strip_hframes,
			}
			if c.has("strip_frames") and c["strip_frames"] is Dictionary:
				for k in c["strip_frames"]:
					_strip_frames[k] = int(c["strip_frames"][k])
			if c.has("strip_fps") and c["strip_fps"] is Dictionary:
				for k in c["strip_fps"]:
					_strip_fps[String(k)] = float(c["strip_fps"][k])
			_walk_anim_over_attack = bool(c.get("walk_anim_over_attack", false))
			_start_transform_pending = bool(c.get("start_transform", false)) \
				and not village_mode and _sprite_strip_tex.has("transform")
			if _start_transform_pending:
				_start_transform_done = false
				anim_state = "transform"
				anim_time = 0.0
				anim_locked_for = float(maxi(1, int(_strip_frames.get("transform", 1)))) / _anim_fps
				if _sprite_strip_tex.has("human_idle"):
					char_sprite.texture = _sprite_strip_tex["human_idle"]
					char_sprite.hframes = _hframes_for_strip_key("human_idle")
					char_sprite.frame = 0
			frames_per_row = []
			has_sprite = true
	if not has_sprite and char_sprite and c.has("sprite") and String(c["sprite"]) != "":
		var tex: Texture2D = load(c["sprite"])
		if tex:
			char_sprite.texture = tex
			char_sprite.hframes = int(c.get("hframes", 1))
			char_sprite.vframes = int(c.get("vframes", 1))
			char_sprite.scale = Vector2.ONE * float(c.get("scale", 1.8))
			char_sprite.offset = Vector2(0, float(c.get("offset_y", 0)))
			char_sprite.frame = 0
			char_sprite.modulate = c.get("tint", Color.WHITE)
			char_sprite.visible = true
			frames_per_row = c.get("frames_per_row", []).duplicate() if c.has("frames_per_row") else []
			row_idle = int(c.get("row_idle", 0))
			row_walk = int(c.get("row_walk", 1))
			row_attack = int(c.get("row_attack", 3))
			var vf: int = max(1, char_sprite.vframes)
			# 規則：無論幾列，倒數第二列 = 受擊、最後一列 = 死亡
			row_death = vf - 1
			row_hit = vf - 2
			if row_hit < 0:
				row_hit = 0
			if row_death < 0:
				row_death = 0
			has_sprite = true
	if has_sprite and sprite:
		sprite.visible = false
	elif sprite:
		sprite.visible = true
	# 被動／技能（從 GameState 讀；尚未實裝時都是 "none"）
	if input_prefix == "p1":
		passive_id = GameState.p1_passive
		skill_id = GameState.p1_skill
	else:
		passive_id = GameState.p2_passive
		skill_id = GameState.p2_skill
	_apply_passive()
	# 村莊模式不需要武器
	if not village_mode:
		start_weapon_reward_log.clear()
		_add_start_weapon(String(c["weapon"]), "character", "")
		_apply_start_armament()


func _ready() -> void:
	add_to_group("players")
	if sprite: sprite.color = color
	_update_pickup_radius()
	game_ref = get_parent()


func _physics_process(delta: float) -> void:
	# 已死亡：停在原地播死亡動畫，不再回血／動／釋放技能（避免雙人有 regen 時被自動復活）
	if hp <= 0:
		velocity = Vector2.ZERO
		modulate.a = 1.0
		_update_char_anim(delta)
		queue_redraw()
		return

	if iframe > 0:
		iframe -= delta
		modulate.a = 0.4 if int(iframe * 10) % 2 == 0 else 1.0
	else:
		modulate.a = 1.0

	if regen_per_sec > 0.0:
		_heal(regen_per_sec * delta)

	passive_meter_fill_cd = max(0.0, passive_meter_fill_cd - delta)
	_try_fighting_spirit_meter()
	_try_quick_step_meter()

	# 主動技能：在戰鬥場景按技能鍵觸發
	if skill_cooldown > 0.0:
		skill_cooldown = max(0.0, skill_cooldown - delta)
	if Input.is_action_just_pressed(input_prefix + "_skill"):
		use_skill()

	if village_mode:
		_village_physics(delta)
	else:
		_battle_physics(delta)
	_update_char_anim(delta)
	queue_redraw()


# 戰鬥（俯視）：八方向自由移動
func _battle_physics(delta: float) -> void:
	var dir: Vector2 = Vector2(
		Input.get_action_strength(input_prefix + "_right") - Input.get_action_strength(input_prefix + "_left"),
		Input.get_action_strength(input_prefix + "_down") - Input.get_action_strength(input_prefix + "_up")
	)
	if dir.length() > 0.05:
		face_dir = dir.normalized()
	# 程序圖案（後備）跟著朝向旋轉；CharSprite 用左右翻轉
	if sprite and sprite.visible:
		sprite.rotation = face_dir.angle()
	if dir.length() > 0:
		velocity = dir.normalized() * move_speed * speed_mult
	else:
		velocity = Vector2.ZERO

	# 地圖阻擋（水/高地）— 軸分離
	if game_ref and game_ref.has_method("is_world_blocked_at"):
		var step_x: float = velocity.x * delta
		var step_y: float = velocity.y * delta
		if abs(step_x) > 0.001:
			if game_ref.is_world_blocked_at(global_position + Vector2(step_x, 0), body_radius):
				velocity.x = 0
		if abs(step_y) > 0.001:
			if game_ref.is_world_blocked_at(global_position + Vector2(0, step_y), body_radius):
				velocity.y = 0

	move_and_slide()


# 村莊（橫向）：左右行走、上跳、重力下墜，地面由 game_ref.get_village_floor_y(x) 決定
func _village_physics(delta: float) -> void:
	var ix: float = Input.get_action_strength(input_prefix + "_right") - Input.get_action_strength(input_prefix + "_left")
	# 朝向：只看左右；保留 y=0
	if abs(ix) > 0.05:
		face_dir = Vector2(sign(ix), 0)
	# 取得地面 Y（世界座標）
	var floor_y: float = 1.0e9
	if game_ref and game_ref.has_method("get_village_floor_y"):
		floor_y = float(game_ref.call("get_village_floor_y", global_position.x))
	# 重力
	velocity.y += VILLAGE_GRAVITY * delta
	# 地面判定（角色「腳底」位於 global_position.y + body_radius）
	village_on_floor = (global_position.y + body_radius >= floor_y - 0.5)
	# 跳躍：踩地時按上鍵跳
	if village_on_floor and Input.is_action_just_pressed(input_prefix + "_up"):
		velocity.y = -VILLAGE_JUMP_SPEED
		village_on_floor = false
	# 橫向速度（地面 = 直接設定；空中 = 適度控制以避免空中急停）
	var target_vx: float = ix * move_speed * speed_mult
	if village_on_floor:
		velocity.x = target_vx
	else:
		velocity.x = lerp(velocity.x, target_vx, VILLAGE_AIR_CONTROL * delta * 8.0)

	var step: Vector2 = velocity * delta
	var new_pos: Vector2 = global_position + step

	# 軸分離 + 軟邊界
	if game_ref and game_ref.has_method("is_world_blocked_at"):
		if game_ref.is_world_blocked_at(global_position + Vector2(step.x, 0), body_radius):
			velocity.x = 0
			new_pos.x = global_position.x

	# 地面夾擠：腳底不可掉到 floor_y 之下
	if new_pos.y + body_radius >= floor_y:
		new_pos.y = floor_y - body_radius
		if velocity.y > 0:
			velocity.y = 0
		village_on_floor = true

	global_position = new_pos
	# 程序圖形朝向：村莊裡只看左右
	if sprite and sprite.visible:
		sprite.rotation = 0.0


func _update_char_anim(delta: float) -> void:
	if char_sprite == null or not char_sprite.visible:
		return
	if _use_sprite_frames:
		_update_char_anim_frames(delta)
		return
	if _use_sprite_strips:
		if char_sprite.texture == null:
			return
		_update_char_anim_strips(delta)
		return
	if char_sprite.texture == null:
		return
	anim_time += delta
	anim_locked_for = max(0.0, anim_locked_for - delta)

	# 狀態轉移
	if hp <= 0:
		if anim_state != "death":
			anim_state = "death"
			anim_time = 0.0
	elif anim_locked_for <= 0.0:
		var new_state: String = "walk" if velocity.length_squared() > 1.0 else "idle"
		if anim_state != new_state:
			anim_state = new_state
			anim_time = 0.0

	var row: int = row_idle
	match anim_state:
		"walk":
			row = row_walk
		"attack":
			row = row_attack
		"hit":
			row = row_hit
		"death":
			row = row_death

	var hf_max: int = char_sprite.hframes
	if hf_max < 1:
		hf_max = 1
	# 該列的實際幀數（避開尾段空白格）
	var fcount: int = hf_max
	if row < frames_per_row.size():
		fcount = max(1, int(frames_per_row[row]))
	var f_in_row: int = int(anim_time * _anim_fps) % fcount
	if anim_state == "death":
		var f: int = int(anim_time * _anim_fps)
		f_in_row = min(f, fcount - 1)
	char_sprite.frame = row * hf_max + f_in_row

	# 翻轉
	if face_dir.x < -0.05:
		char_sprite.flip_h = true
	elif face_dir.x > 0.05:
		char_sprite.flip_h = false


func _update_char_anim_strips(delta: float) -> void:
	anim_time += delta
	anim_locked_for = max(0.0, anim_locked_for - delta)

	# 變身是開場一次性的最高優先動畫：不被走路、攻擊、受擊，甚至死亡狀態轉換打斷。
	if _is_transform_anim_active():
		var tf_frames: int = maxi(1, int(_strip_frames.get("transform", _hframes_for_strip_key("transform"))))
		if anim_time >= float(tf_frames) / _strip_fps_for_anim("transform"):
			_start_transform_pending = false
			_start_transform_done = true
			anim_state = "idle" if hp > 0 else "death"
			anim_time = 0.0
			anim_locked_for = 0.0
	elif hp <= 0:
		if anim_state != "death":
			anim_state = "death"
			anim_time = 0.0
	elif anim_locked_for <= 0.0:
		var new_state: String = "walk" if velocity.length_squared() > 1.0 else "idle"
		if anim_state != new_state:
			anim_state = new_state
			anim_time = 0.0

	# 顯示用狀態：有方向輸入時腳步優先，攻擊鎖定中仍播走路／待機（死亡、受擊除外）
	var display_anim: String = anim_state
	if _walk_anim_over_attack and hp > 0 and anim_state != "death" and anim_state != "hit" \
			and anim_state != "transform" \
			and _has_move_direction_input():
		display_anim = "walk" if velocity.length_squared() > 1.0 else "idle"

	var strip_key: String = "idle"
	match display_anim:
		"transform":
			strip_key = "transform"
		"walk":
			strip_key = "walk"
		"attack":
			strip_key = "attack"
		"hit":
			strip_key = "hurt" if _sprite_strip_tex.has("hurt") else "idle"
		"death":
			strip_key = "death" if _sprite_strip_tex.has("death") else "idle"

	char_sprite.texture = _sprite_strip_tex.get(strip_key, _sprite_strip_tex["idle"])
	char_sprite.hframes = _hframes_for_strip_key(strip_key)
	char_sprite.vframes = 1

	var hf_now: int = maxi(1, char_sprite.hframes)
	var fc: int = maxi(1, int(_strip_frames.get(display_anim, _strip_frames.get("idle", hf_now))))
	var anim_fps: float = _strip_fps_for_anim(display_anim)
	var f_in_row: int = int(anim_time * anim_fps) % fc
	if anim_state == "death" or _is_transform_anim_active():
		var f: int = int(anim_time * anim_fps)
		f_in_row = mini(f, fc - 1)
	char_sprite.frame = f_in_row

	if _sprite_faces_left:
		if face_dir.x < -0.05:
			char_sprite.flip_h = false
		elif face_dir.x > 0.05:
			char_sprite.flip_h = true
	else:
		if face_dir.x < -0.05:
			char_sprite.flip_h = true
		elif face_dir.x > 0.05:
			char_sprite.flip_h = false


func _hframes_for_strip_key(strip_key: String) -> int:
	if _strip_hframes_by_strip.has(strip_key):
		return maxi(1, int(_strip_hframes_by_strip[strip_key]))
	return maxi(1, _strip_hframes)


func _strip_fps_for_anim(anim: String) -> float:
	return maxf(1.0, float(_strip_fps.get(anim, _anim_fps)))


# 逐幀 PNG 模式：每張圖獨立替換，無 hframes 切割
func _update_char_anim_frames(delta: float) -> void:
	anim_time += delta
	anim_locked_for = max(0.0, anim_locked_for - delta)

	if hp <= 0:
		if anim_state != "death":
			anim_state = "death"
			anim_time = 0.0
	elif anim_locked_for <= 0.0:
		var new_state: String = "walk" if velocity.length_squared() > 1.0 else "idle"
		if anim_state != new_state:
			anim_state = new_state
			anim_time = 0.0

	var display_anim: String = anim_state
	if _walk_anim_over_attack and hp > 0 and anim_state != "death" and anim_state != "hit" \
			and _has_move_direction_input():
		display_anim = "walk" if velocity.length_squared() > 1.0 else "idle"

	var key: String = "idle"
	match display_anim:
		"walk":
			key = "walk"
		"attack":
			key = "attack"
		"hit":
			key = "hurt" if _sprite_frame_anims.has("hurt") else "idle"
		"death":
			key = "death" if _sprite_frame_anims.has("death") else "idle"

	var arr: Array = _sprite_frame_anims.get(key, _sprite_frame_anims["idle"])
	var fc: int = maxi(1, arr.size())
	var f_idx: int = int(anim_time * _anim_fps) % fc
	if anim_state == "death":
		var f: int = int(anim_time * _anim_fps)
		f_idx = mini(f, fc - 1)
	char_sprite.texture = arr[f_idx]
	char_sprite.hframes = 1
	char_sprite.vframes = 1
	char_sprite.frame = 0

	if _sprite_faces_left:
		if face_dir.x < -0.05:
			char_sprite.flip_h = false
		elif face_dir.x > 0.05:
			char_sprite.flip_h = true
	else:
		if face_dir.x < -0.05:
			char_sprite.flip_h = true
		elif face_dir.x > 0.05:
			char_sprite.flip_h = false


# 將 sprite_frames 內 entry 解析成檔案路徑 Array：
#   - Array：直接視為路徑清單
#   - Dictionary：用 {pattern, count, start=1} 展開（pattern 內 {i} 替換成數字）
func _resolve_frame_paths(entry: Variant) -> Array:
	if entry == null:
		return []
	if entry is Array:
		var out: Array = []
		for x in entry:
			out.append(String(x))
		return out
	if entry is Dictionary:
		var pat: String = String(entry.get("pattern", ""))
		var cnt: int = int(entry.get("count", 0))
		var start: int = int(entry.get("start", 1))
		if pat == "" or cnt <= 0:
			return []
		var out2: Array = []
		for i in range(cnt):
			out2.append(pat.replace("{i}", str(start + i)))
		return out2
	return []


func _has_move_direction_input() -> bool:
	if village_mode:
		var ix: float = Input.get_action_strength(input_prefix + "_right") \
				- Input.get_action_strength(input_prefix + "_left")
		return absf(ix) > 0.05
	var ix2: float = Input.get_action_strength(input_prefix + "_right") \
			- Input.get_action_strength(input_prefix + "_left")
	var iy2: float = Input.get_action_strength(input_prefix + "_down") \
			- Input.get_action_strength(input_prefix + "_up")
	return ix2 * ix2 + iy2 * iy2 > 0.0025


func _row_frame_count(row: int) -> int:
	if row < frames_per_row.size():
		return max(1, int(frames_per_row[row]))
	if char_sprite:
		return max(1, char_sprite.hframes)
	return 1


func _is_transform_anim_active() -> bool:
	return _start_transform_pending and not _start_transform_done and anim_state == "transform"


func play_attack_anim() -> void:
	if hp <= 0:
		return
	if _is_transform_anim_active():
		return
	AudioManager.play_sfx("player_attack", 0.03)
	if char_sprite == null or not char_sprite.visible:
		return
	anim_state = "attack"
	anim_time = 0.0
	# 播完一輪攻擊動畫所需時間
	if _use_sprite_frames:
		var ac_arr: Array = _sprite_frame_anims.get("attack", _sprite_frame_anims.get("idle", []))
		var ac_f: int = maxi(1, ac_arr.size())
		anim_locked_for = max(anim_locked_for, float(ac_f) / _anim_fps)
	elif _use_sprite_strips:
		var ac: int = maxi(1, int(_strip_frames.get("attack", _hframes_for_strip_key("attack"))))
		anim_locked_for = max(anim_locked_for, float(ac) / _strip_fps_for_anim("attack"))
	else:
		anim_locked_for = max(anim_locked_for, _row_frame_count(row_attack) / _anim_fps)


func _play_hit_anim() -> void:
	if char_sprite == null or not char_sprite.visible:
		return
	if _is_transform_anim_active():
		return
	anim_state = "hit"
	anim_time = 0.0
	if _use_sprite_frames:
		var hk_arr: Array = _sprite_frame_anims.get("hurt", _sprite_frame_anims.get("idle", []))
		var hc_f: int = maxi(1, hk_arr.size())
		anim_locked_for = max(anim_locked_for, float(hc_f) / _anim_fps)
	elif _use_sprite_strips:
		var hk: String = "hurt" if _sprite_strip_tex.has("hurt") else "idle"
		var hc: int = maxi(1, int(_strip_frames.get("hit", _strip_frames.get("idle", _hframes_for_strip_key(hk)))))
		anim_locked_for = max(anim_locked_for, float(hc) / _strip_fps_for_anim("hit"))
	else:
		anim_locked_for = max(anim_locked_for, _row_frame_count(row_hit) / _anim_fps)


func _draw() -> void:
	var w: float = 36.0
	var h: float = 4.0
	var top := Vector2(-w * 0.5, -28.0)
	draw_rect(Rect2(top, Vector2(w, h)), Color(0.1, 0.05, 0.05))
	var pct: float = clamp(hp / max(1.0, max_hp * hp_mult), 0.0, 1.0)
	draw_rect(Rect2(top, Vector2(w * pct, h)), Color(0.95, 0.3, 0.3))
	var top2 := top + Vector2(0, h + 1.0)
	draw_rect(Rect2(top2, Vector2(w, 2.0)), Color(0.05, 0.15, 0.25))
	var xp_pct: float = clamp(xp / max(1.0, xp_to_next), 0.0, 1.0)
	draw_rect(Rect2(top2, Vector2(w * xp_pct, 2.0)), Color(0.4, 0.85, 1.0))
	# 技能冷卻條（只在有選技能時顯示）
	if skill_id != "none":
		var s_def: Dictionary = GameData.get_skill_def(skill_id)
		var s_cd_max: float = max(0.001, float(s_def.get("cooldown", 1.0)))
		var ready_pct: float = clamp(1.0 - skill_cooldown / s_cd_max, 0.0, 1.0)
		var top3 := top2 + Vector2(0, 3.0)
		draw_rect(Rect2(top3, Vector2(w, 2.0)), Color(0.1, 0.08, 0.0))
		var col := Color(1.0, 0.85, 0.35) if skill_cooldown <= 0.0 else Color(0.55, 0.55, 0.6)
		draw_rect(Rect2(top3, Vector2(w * ready_pct, 2.0)), col)
		# 技能量表（被動充能）
		var top4 := top3 + Vector2(0, 3.0)
		draw_rect(Rect2(top4, Vector2(w, 2.0)), Color(0.05, 0.12, 0.08))
		var m_pct: float = clamp(skill_meter / SKILL_METER_MAX, 0.0, 1.0)
		draw_rect(Rect2(top4, Vector2(w * m_pct, 2.0)), Color(0.35, 1.0, 0.55))
	var s: String = "Lv%d %s" % [level, GameData.get_character_def(character_id).get("name", "")]
	var fnt := ThemeDB.fallback_font
	draw_string(fnt, top2 + Vector2(-4, -16), s,
		HORIZONTAL_ALIGNMENT_LEFT, w + 8.0, 12, Color.WHITE)
	# 程序圖案後備時，畫朝向指引
	if sprite and sprite.visible:
		draw_line(Vector2.ZERO, face_dir * 18.0, Color(1, 1, 1, 0.4), 2.0)

	# 靈敏戰技：箭矢持有數
	if ranger_arrows > 0:
		var fnta := ThemeDB.fallback_font
		var arrow_lbl: String = "↑x%d" % ranger_arrows
		draw_string(fnta, Vector2(-14, -52), arrow_lbl,
			HORIZONTAL_ALIGNMENT_CENTER, 28, 12,
			Color(0.7, 1.0, 0.6))

	# 重裝防禦護盾：脈衝光環 + 層數
	if block_charges > 0:
		var t: float = Time.get_ticks_msec() * 0.005
		var pulse: float = 0.55 + 0.45 * sin(t)
		var col := Color(0.45, 0.85, 1.0, 0.35 + pulse * 0.30)
		draw_arc(Vector2.ZERO, body_radius + 10.0, 0.0, TAU, 32, col, 3.0, true)
		draw_arc(Vector2.ZERO, body_radius + 14.0, 0.0, TAU, 32,
			Color(0.85, 0.95, 1.0, 0.18 + pulse * 0.18), 1.5, true)
		var fnt2 := ThemeDB.fallback_font
		var lbl: String = "x%d" % block_charges
		draw_string(fnt2, Vector2(-12, -42), lbl,
			HORIZONTAL_ALIGNMENT_CENTER, 24, 12, Color(0.85, 0.95, 1.0))


func _update_pickup_radius() -> void:
	if pickup_shape and pickup_shape.shape is CircleShape2D:
		(pickup_shape.shape as CircleShape2D).radius = PICKUP_BASE_RADIUS * pickup_mult


func take_damage(d: float) -> void:
	if village_mode:
		return
	if iframe > 0 or hp <= 0:
		return
	# 重裝防禦：吃掉一個格擋層、給短暫無敵讓玩家有反應時間
	if block_charges > 0:
		block_charges -= 1
		iframe = 0.6
		# 視覺：藍色閃光提示已格擋
		modulate = Color(0.7, 0.95, 1.4)
		create_tween().tween_property(self, "modulate", Color(1, 1, 1), 0.25)
		_passive_unyielding_try_meter()
		return
	var actual: float = max(1.0, d * (1.0 - dmg_reduce) - def_value * 0.5)
	var taken_now: float = min(actual, hp)
	hp -= actual
	damage_taken += taken_now
	iframe = 0.6
	if hp <= 0:
		hp = 0
		AudioManager.play_sfx("player_death", 0.02)
		died.emit(self)
	else:
		AudioManager.play_sfx("player_hurt", 0.04)
		_play_hit_anim()
	_passive_unyielding_try_meter()


# 由 Enemy.take_damage 反向呼叫，記錄這位玩家本場造成的「實際扣血量」
func register_damage_dealt(amount: float) -> void:
	if amount <= 0.0:
		return
	damage_dealt += amount


# 由 Pinball 在關閉前呼叫，把該局玩家於彈珠台撞針得到的分數累計到這位玩家
func add_pinball_score(amount: int) -> void:
	if amount <= 0:
		return
	pinball_score += amount


func _heal(amount: float) -> void:
	# 死亡狀態鎖死，任何來源（regen / level-up / 技能）都不能讓 hp 從 0 回升
	if hp <= 0:
		return
	hp = min(max_hp * hp_mult, hp + amount)


# 經驗：共用等級制 — 把 XP 投入 Game 的隊伍進度（含 xp_mult 倍率）
func add_xp(v: float) -> void:
	if game_ref and game_ref.has_method("add_team_xp"):
		game_ref.add_team_xp(v * xp_mult)
	else:
		# 保險：若沒有 game_ref（例如獨立測試）就退回個人計算
		xp += v * xp_mult
		while xp >= xp_to_next:
			xp -= xp_to_next
			_self_level_up()


func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	if game_ref and game_ref.has_method("add_run_gold"):
		game_ref.add_run_gold(amount)
	else:
		GameState.grant_run_gold(amount)


func _self_level_up() -> void:
	level += 1
	xp_to_next = round(xp_to_next * 1.25 + 2.0)
	# 升級回血：以最大 HP 5% 為主（之前固定 +10 在 2P 連升時等於無敵）
	_heal(max_hp * hp_mult * 0.05)
	AudioManager.play_sfx("level_up", 0.02)
	leveled_up.emit(self)


# Game.gd 在隊伍升級時為每位存活玩家呼叫
func on_team_level_up(new_level: int) -> void:
	level = new_level
	# 升級回血上限以最大 HP 5%（避免雙人快速升級被當無敵）
	_heal(max_hp * hp_mult * 0.05)
	AudioManager.play_sfx("level_up", 0.02)


# Game.gd 同步隊伍 XP 進度給 HUD/_draw
func sync_team_progress(team_xp: float, team_to_next: float) -> void:
	xp = team_xp
	xp_to_next = team_to_next


func on_enemy_killed(_e: Node) -> void:
	kills += 1
	if passive_id == "fighting_spirit" and skill_id != "none":
		passive_kill_counter += 1
		_try_fighting_spirit_meter()


# ===== 被動 / 主動技能 =====
func _apply_passive() -> void:
	passive_kill_counter = 0
	passive_hit_counter = 0
	skill_meter = 0.0
	passive_meter_fill_cd = 0.0


# 被動充能量表：兩個被動共用 passive_meter_fill_cd，避免短時間內連續灌滿技能
func _try_grant_passive_skill_meter(amount: float) -> bool:
	if skill_id == "none":
		return false
	if passive_meter_fill_cd > 0.0:
		return false
	var pdef: Dictionary = GameData.get_passive_def(passive_id)
	var cd: float = float(pdef.get("params", {}).get("passive_fill_cd", 5.0))
	passive_meter_fill_cd = cd
	skill_meter += amount
	while skill_meter >= SKILL_METER_MAX:
		skill_meter -= SKILL_METER_MAX
		skill_cooldown = 0.0
	return true


func _try_fighting_spirit_meter() -> void:
	if passive_id != "fighting_spirit" or skill_id == "none":
		return
	var pdef: Dictionary = GameData.get_passive_def("fighting_spirit")
	var need: int = max(1, int(pdef.get("params", {}).get("kills_per_fill", 5)))
	var fill: float = float(pdef.get("params", {}).get("meter_fill", 22.0))
	while passive_kill_counter >= need:
		if not _try_grant_passive_skill_meter(fill):
			break
		passive_kill_counter -= need


func _passive_unyielding_try_meter() -> void:
	if passive_id != "unyielding" or skill_id == "none":
		return
	var pdef: Dictionary = GameData.get_passive_def("unyielding")
	var fill: float = float(pdef.get("params", {}).get("meter_fill", 40.0))
	_try_grant_passive_skill_meter(fill)


# 靈敏戰技（戰鬥）：3 + 持有箭矢 道擴散箭；釋放後清空持有箭矢
func _skill_agile_tactics_combat(s: Dictionary) -> void:
	var prm: Dictionary = s.get("params", {})
	var base_n: int = int(prm.get("combat_base_arrows", 3))
	var spread_d: float = float(prm.get("combat_spread_deg", 14.0))
	var speed: float = float(prm.get("combat_speed", 720.0))
	var rng: float = float(prm.get("combat_range", 520.0))
	var dmg_mul: float = float(prm.get("combat_damage_mult", 1.6))
	var min_dmg: float = float(prm.get("combat_min_damage", 18.0))
	var n: int = base_n + ranger_arrows
	ranger_arrows = 0
	var dmg: float = max(min_dmg, atk * damage_mult * dmg_mul)
	var aim: Vector2 = face_dir if face_dir.length_squared() > 0.001 else Vector2.RIGHT
	var center_ang: float = aim.angle()
	var total_spread: float = deg_to_rad(spread_d) * (n - 1)
	var proj_scene: PackedScene = preload("res://scenes/Projectile.tscn")
	var adapter := SkillProjectileAdapter.new()
	adapter.eff_damage = dmg
	adapter.eff_range = rng
	adapter.def = {
		"params": {
			"speed": speed,
			"pierce": 1,
			"color": Color(0.7, 1.0, 0.55),
		},
	}
	adapter.owner_player = self
	get_parent().add_child(adapter)
	for i in n:
		var t: float = 0.0 if n == 1 else float(i) / (n - 1)
		var ang: float = center_ang - total_spread * 0.5 + total_spread * t
		var p := proj_scene.instantiate()
		p.global_position = global_position
		p.setup(adapter, Vector2(cos(ang), sin(ang)) * speed,
			Color(0.75, 1.0, 0.6))
		get_parent().add_child(p)
	# adapter 的存活時間需略長於箭矢以避免命中時被釋放
	var freer := get_tree().create_timer(4.5, false)
	freer.timeout.connect(func():
		if is_instance_valid(adapter):
			adapter.queue_free()
	)
	play_attack_anim()


# 「靈敏戰技」彈珠台：每 3 次彈針撞擊得 1 箭矢（外部呼叫）
func ranger_grant_arrow_from_pinball(amount: int = 1, hard_cap: int = RANGER_ARROW_HARD_CAP) -> void:
	if skill_id != "agile_tactics":
		return
	ranger_arrows = min(hard_cap, ranger_arrows + amount)


# 「奧術精通」：技能命中敵人 / 彈針時觸發。pinball 等外部場景也可呼叫。
func passive_arcane_mastery_on_skill_hit() -> void:
	if passive_id != "arcane_mastery" or skill_id == "none":
		return
	var pdef: Dictionary = GameData.get_passive_def("arcane_mastery")
	var fill: float = float(pdef.get("params", {}).get("meter_fill", 30.0))
	_try_grant_passive_skill_meter(fill)


# 武器命中事件（由 WeaponBase.damage_enemy 呼叫）
func on_weapon_hit(_e: Node, _weapon: Node) -> void:
	if passive_id == "quick_step" and skill_id != "none":
		passive_hit_counter += 1
		_try_quick_step_meter()


# 結算：在被動 CD 結束時把累計的命中數兌換成量表（與鬥志高昂相同模式）
func _try_quick_step_meter() -> void:
	if passive_id != "quick_step" or skill_id == "none":
		return
	var pdef: Dictionary = GameData.get_passive_def("quick_step")
	var need: int = max(1, int(pdef.get("params", {}).get("hits_per_fill", 8)))
	var fill: float = float(pdef.get("params", {}).get("meter_fill", 25.0))
	while passive_hit_counter >= need:
		if not _try_grant_passive_skill_meter(fill):
			break
		passive_hit_counter -= need


# 通用：嘗試消耗技能 (檢查冷卻 + skill_id 是否有效)
# 成功時把 cooldown 重置並回傳 skill 定義；失敗時回傳 {}。
# 主要供「不在 Player 自己處理的情境」(如彈珠台) 呼叫。
func try_consume_skill() -> Dictionary:
	if skill_cooldown > 0.0:
		return {}
	var s: Dictionary = GameData.get_skill_def(skill_id)
	if s.is_empty() or String(s.get("id", "none")) == "none":
		return {}
	skill_cooldown = float(s.get("cooldown", 5.0))
	return s


# 戰鬥場景中按技能鍵：依 skill_id 派發效果
func use_skill(context: String = "combat") -> bool:
	if village_mode:
		return false
	if context != "combat":
		# 其他 context (例：彈珠台) 由各場景自行呼叫 try_consume_skill 處理
		return false
	var s: Dictionary = try_consume_skill()
	if s.is_empty():
		return false
	AudioManager.play_sfx("skill_cast", 0.03)
	match String(s.get("id", "none")):
		"whirl_slash":
			_skill_whirl_slash_combat(s)
		"heavy_armor":
			_skill_heavy_armor_combat(s)
		"energy_wave":
			_skill_energy_wave_combat(s)
		"agile_tactics":
			_skill_agile_tactics_combat(s)
	return true


# --- 個別技能：戰鬥版實作 ---
func _skill_whirl_slash_combat(s: Dictionary) -> void:
	var params: Dictionary = s.get("params", {})
	var radius: float = float(params.get("combat_radius", 360.0))
	var dmg_mult: float = float(params.get("combat_damage_mult", 6.0))
	var min_damage: float = float(params.get("combat_min_damage", 80.0))
	var dmg: float = max(min_damage, atk * damage_mult * dmg_mult)
	# 命中範圍內所有敵人
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var ee := e as Node2D
		if ee == null:
			continue
		if ee.global_position.distance_to(global_position) <= radius:
			if ee.has_method("take_damage"):
				ee.take_damage(dmg, self)
	# 視覺
	var vfx = preload("res://scripts/whirl_slash_vfx.gd").new()
	vfx.global_position = global_position
	get_parent().add_child(vfx)
	vfx.setup(radius, color, 0.55)
	# 玩家自身播放攻擊動畫
	play_attack_anim()


# 重裝防禦（戰鬥）：賦予自身 N 層格擋（取較大者，避免覆寫剩餘層數）
func _skill_heavy_armor_combat(s: Dictionary) -> void:
	var params: Dictionary = s.get("params", {})
	var n: int = int(params.get("combat_block_count", 2))
	block_charges = max(block_charges, n)
	# 啟動視覺：以玩家位置短暫地閃藍光
	modulate = Color(0.7, 0.95, 1.6)
	create_tween().tween_property(self, "modulate", Color(1, 1, 1), 0.4)


func _point_segment_distance_sq(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq < 1e-6:
		return p.distance_squared_to(a)
	var t: float = clamp(ab.dot(p - a) / len_sq, 0.0, 1.0)
	var proj: Vector2 = a + ab * t
	return p.distance_squared_to(proj)


# 能量波動（戰鬥）：前方直線 30m × 寬 5m 光束砲擊
func _skill_energy_wave_combat(s: Dictionary) -> void:
	var prm: Dictionary = s.get("params", {})
	var beam_len: float = float(prm.get("combat_length", 720.0))
	var half_w: float = float(prm.get("combat_half_width", 60.0))
	var start_off: float = float(prm.get("combat_start_offset", 72.0))
	var dmg_mul: float = float(prm.get("combat_damage_mult", 5.5))
	var min_dmg: float = float(prm.get("combat_min_damage", 60.0))
	var start: Vector2 = global_position + face_dir * start_off
	var end: Vector2 = start + face_dir * beam_len
	var dmg: float = max(min_dmg, atk * damage_mult * dmg_mul)
	var any_hit: bool = false
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var ee := e as Node2D
		if ee == null:
			continue
		var er: float = 28.0
		var rn: Variant = e.get("radius")
		if rn != null:
			er = float(rn)
		var thresh: float = half_w + er
		var dsq: float = _point_segment_distance_sq(ee.global_position, start, end)
		if dsq <= thresh * thresh and e.has_method("take_damage"):
			e.take_damage(dmg, self)
			any_hit = true
	if any_hit:
		passive_arcane_mastery_on_skill_hit()
	var vfx = preload("res://scripts/energy_beam_vfx.gd").new()
	get_parent().add_child(vfx)
	vfx.global_position = start
	vfx.setup(face_dir, beam_len, half_w, Color(0.78, 0.42, 1.0, 0.62), 0.34)
	play_attack_anim()


func add_weapon(weapon_id: String) -> Dictionary:
	for w in weapons:
		if w["id"] == weapon_id:
			var ur: Dictionary = _apply_random_weapon_upgrade(w)
			return _weapon_reward_result(String(w["id"]), ur)
	# 武器格滿了 → 改強化等級最低的一把（總是有點益處），不再悄悄落空
	if weapons.size() >= get_weapon_slot_max():
		var lowest: Dictionary = weapons[0]
		for w in weapons:
			if int(w["level"]) < int(lowest["level"]):
				lowest = w
		var ur2: Dictionary = _apply_random_weapon_upgrade(lowest)
		return _weapon_reward_result(String(lowest["id"]), ur2)
	var entry := {
		"id": weapon_id,
		"level": 1,
		"upgrades": {},
		"node": null,
	}
	weapons.append(entry)
	var node := _spawn_weapon_node(weapon_id)
	if node:
		entry["node"] = node
		weapons_root.add_child(node)
		node.setup(self, entry)
	return {"kind": "weapon_new", "weapon_id": weapon_id}


func _add_start_weapon(weapon_id: String, source_kind: String, source_id: String) -> void:
	if weapon_id == "":
		return
	var info: Dictionary = add_weapon(weapon_id)
	info["source_kind"] = source_kind
	info["source_id"] = source_id
	start_weapon_reward_log.append(info)


func _apply_start_armament() -> void:
	armament_id = GameState.p1_armament if input_prefix == "p1" else GameState.p2_armament
	if armament_id == "" or not GameState.is_armament_unlocked(armament_id):
		armament_id = "none"
	var adef: Dictionary = GameData.get_armament_def(armament_id)
	if adef.is_empty() or armament_id == "none":
		return
	atk += float(adef.get("atk_add", 0.0))
	move_speed += float(adef.get("spd_add", 0.0)) * 36.0
	_add_start_weapon(String(adef.get("weapon_id", "")), "armament", armament_id)


func get_weapon_slot_max() -> int:
	if is_instance_valid(GameState):
		return GameState.get_unlocked_weapon_slot_count()
	return WEAPON_SLOT_MAX


func _weapon_reward_result(weapon_id: String, ur: Dictionary) -> Dictionary:
	if ur.get("ok", false):
		return {
			"kind": "weapon_upgrade",
			"weapon_id": weapon_id,
			"upgrade_id": ur["upgrade_id"],
			"current": ur["current"],
			"max": ur["max"],
		}
	return {"kind": "weapon_upgrade_max", "weapon_id": weapon_id}


func _apply_random_weapon_upgrade(entry: Dictionary) -> Dictionary:
	var picks: Array = []
	for u in GameData.WEAPON_UPGRADES:
		var have: int = entry["upgrades"].get(u["id"], 0)
		if have < u["max"]:
			picks.append(u["id"])
	if picks.is_empty():
		return {"ok": false}
	var ups_before: Dictionary = entry["upgrades"].duplicate()
	var pick: String = picks.pick_random()
	entry["upgrades"][pick] = entry["upgrades"].get(pick, 0) + 1
	entry["level"] += 1
	if entry["node"]:
		entry["node"].refresh()
	if GameData.is_weapon_upgrades_maxed(entry["upgrades"]) \
			and not GameData.is_weapon_upgrades_maxed(ups_before):
		_try_show_weapon_max_bonus_unlock(String(entry["id"]))
	var max_lv: int = 0
	for u in GameData.WEAPON_UPGRADES:
		if u["id"] == pick:
			max_lv = int(u["max"])
			break
	return {"ok": true, "upgrade_id": pick, "current": int(entry["upgrades"][pick]), "max": max_lv}


func _try_show_weapon_max_bonus_unlock(weapon_id: String) -> void:
	if village_mode:
		return
	if not GameData.weapon_max_bonus_is_implemented(weapon_id):
		return
	call_deferred("_show_weapon_max_bonus_unlock_impl", weapon_id)


func _show_weapon_max_bonus_unlock_impl(weapon_id: String) -> void:
	var wdef: Dictionary = GameData.get_weapon_def(weapon_id)
	if wdef.is_empty():
		return
	var pname: String = tr("PINBALL_PNAME_FMT") % (int(slot_index) + 1)
	var wn: String = GameData.tr_weapon_name(weapon_id)
	var mx: String = GameData.tr_max_effect(wdef)
	var body: String = tr("WEAPON_MAX_UNLOCK_BODY_FMT") % [pname, wn, mx]
	BlockingNotice.present(
		get_tree(),
		tr("WEAPON_MAX_UNLOCK_TITLE"),
		body,
		tr("PINBALL_REWARD_HINT"),
		tr("PINBALL_REWARD_OK"),
		null,
		"",
	)


func _spawn_weapon_node(weapon_id: String) -> Node:
	var w := GameData.get_weapon_def(weapon_id)
	if w.is_empty():
		return null
	match w["kind"]:
		"axe":
			return preload("res://scripts/weapons/weapon_axe.gd").new()
		"melee_fan":
			return preload("res://scripts/weapons/weapon_melee_fan.gd").new()
		"projectile":
			return preload("res://scripts/weapons/weapon_projectile.gd").new()
		"orbit":
			return preload("res://scripts/weapons/weapon_orbit.gd").new()
		"aura":
			return preload("res://scripts/weapons/weapon_aura.gd").new()
		"puddle":
			return preload("res://scripts/weapons/weapon_puddle.gd").new()
	return null


func apply_common_upgrade(id: String) -> Dictionary:
	common_upgrade_log[id] = int(common_upgrade_log.get(id, 0)) + 1
	var cur: int = int(common_upgrade_log.get(id, 0))
	for u in GameData.COMMON_UPGRADES:
		if u["id"] != id:
			continue
		var f: String = u["field"]
		var v: float = float(u["value"])
		match f:
			"hp_mult":
				hp_mult += v
				_heal(max_hp * v)
			"speed_mult":
				speed_mult += v
			"rate_mult":
				rate_mult += v
				for ww in weapons:
					if ww["node"]: ww["node"].refresh()
			"pickup_mult":
				pickup_mult += v
				_update_pickup_radius()
			"xp_mult":
				xp_mult += v
			"dmg_reduce":
				dmg_reduce = min(0.6, dmg_reduce + v)
			"regen_add":
				regen_per_sec += v
			"damage_mult":
				damage_mult += v
				for ww in weapons:
					if ww["node"]: ww["node"].refresh()
		return {"kind": "common_upgrade", "upgrade_id": id, "current": cur, "max": int(u["max"])}
	var u0: Dictionary = GameData.get_common_upgrade_def(id)
	return {"kind": "common_upgrade", "upgrade_id": id, "current": cur, "max": int(u0.get("max", 0))}


func _on_pickup_area_body_entered(_body: Node) -> void:
	pass


func _on_pickup_area_area_entered(area: Area2D) -> void:
	if area.is_in_group("xp_orbs") or area.is_in_group("gold_orbs"):
		area.attract_to(self)
