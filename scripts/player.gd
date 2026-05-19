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
var crit_chance: float = 0.0
var crit_damage_mult: float = GameData.CRIT_DAMAGE_MULT_BASE
var pickup_mult: float = 1.0
var xp_mult: float = 1.0
var dmg_reduce: float = 0.0
var regen_per_sec: float = 0.0

const LEVEL_HP_MULT_PER_LEVEL := 0.02
const LEVEL_DAMAGE_MULT_PER_LEVEL := 0.02
const LEVEL_DEF_BONUS_PER_LEVEL := 0.5
const LEVEL_SPEED_MULT_PER_LEVEL := 0.003

# 共用等級系統 — 實際資料存在 Game.team_level / team_xp，這裡為了 HUD/_draw 同步暫存
var level: int = 1
var xp: float = 0.0
var xp_to_next: float = 5.0

# 被動 / 主動技能（角色選擇畫面挑選）
var passive_id: String = "none"
var skill_id: String = "none"
var armament_id: String = "none"
var skill_cooldown: float = 0.0
var heavenly_judgment_active: bool = false
var heavenly_judgment_phase: String = ""
var heavenly_judgment_origin: Vector2 = Vector2.ZERO
var heavenly_judgment_target: Vector2 = Vector2.ZERO
var heavenly_judgment_air_pos: Vector2 = Vector2.ZERO
var heavenly_judgment_time_left: float = 0.0
var heavenly_judgment_params: Dictionary = {}
var heavenly_judgment_confirm_guard: float = 0.0
var heavenly_judgment_marker: Node2D = null
var _heavenly_judgment_tween: Tween = null

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
# 刃氣充盈：碎刃命中計數
var passive_blade_aura_counter: int = 0
var breakthrough_same_enemy_hits: Dictionary = {}
var breakthrough_attack_hits: Dictionary = {}
## 野性衝動：付費施放後 5 秒內可再免費衝刺的剩餘次數
var wild_impulse_window: float = 0.0
var wild_impulse_charges_left: int = 0
# 無我：戰鬥技能持續計時
var mushin_active: bool = false
var mushin_timer: float = 0.0
# 嗜血衝動：各層獨立倒計時（最多 5 層）
var blood_frenzy_stack_timers: Array[float] = []
# 血包系統（吸血鬼彈珠台）
var blood_packs: int = 0
var has_revival_charge: bool = false
# 焰氣系統（烈焰靈女巫彈珠台）
var flame_charges: int = 0
var has_skill_boost: bool = false
# 血霧籠罩：技能持續狀態
var blood_shroud_active: bool = false
var blood_shroud_timer: float = 0.0
var blood_shroud_tick_timer: float = 0.0
# 引爆本能：各敵人的爆炸 CD 與計數
var _ignition_enemy_cds: Dictionary = {}
var _ignition_explosion_counter: int = 0

var kills: int = 0
# 結算統計：造成傷害 / 承受傷害（實際扣血）/ 彈珠台累積分數 / 取得的局內加成清單
var damage_dealt: float = 0.0
var damage_taken: float = 0.0
var pinball_score: int = 0
var common_upgrade_log: Dictionary = {}   # upgrade_id -> count
var start_weapon_reward_log: Array[Dictionary] = []
var face_dir: Vector2 = Vector2.RIGHT
var iframe: float = 0.0
var _enemy_slow_time: float = 0.0
var _enemy_slow_factor: float = 1.0
var _enemy_stun_time: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO
var _player_bleed_time: float = 0.0
var _player_bleed_dps: float = 0.0

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
var _sprite_feet_fine_offset_y: float = 0.0
var _village_feet_extra_y: float = 0.0
## 戰鬥 HUD 血條／名牌基準 Y（愈小愈高；原 -28）
const BATTLE_HUD_TOP_Y := -40.0


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
	if village_mode:
		br = GameData.village_scaled_body_radius(br)
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
	_sprite_feet_fine_offset_y = 0.0
	_village_feet_extra_y = 0.0
	_start_transform_pending = false
	_start_transform_done = false
	var skin_id: String = "default"
	if input_prefix == "p1":
		skin_id = GameState.get_p1_house_character_skin(cid)
	elif input_prefix == "p2":
		skin_id = GameState.get_p2_house_character_skin(cid)
	var visual: Dictionary = GameData.resolve_character_visual_def(cid, skin_id)
	if visual.is_empty():
		visual = c
	if village_mode:
		_village_feet_extra_y = float(visual.get("village_sprite_feet_fine", 0))
	_anim_fps = float(visual.get("anim_fps", ANIM_FPS))
	# 1) 逐幀 PNG（每動作一組獨立檔，可用 Array 或 {pattern, count, start} 兩種格式）
	if char_sprite and visual.has("sprite_frames") and visual["sprite_frames"] is Dictionary:
		var fdict: Dictionary = visual["sprite_frames"]
		var need_f: Array[String] = ["idle", "walk", "attack"]
		var f_ok: bool = true
		for fkey in need_f:
			var arr_paths: Array = _resolve_frame_paths(fdict.get(fkey, null))
			if arr_paths.is_empty():
				f_ok = false
				break
			var tex_arr: Array = []
			for p in arr_paths:
				var t: Texture2D = GameData.resolve_frame_texture(p)
				if t == null:
					f_ok = false
					break
				tex_arr.append(t)
			if not f_ok:
				break
			_sprite_frame_anims[fkey] = tex_arr
		if f_ok:
			for opt_f in ["hurt", "death", "skill"]:
				var arr_opt: Array = _resolve_frame_paths(fdict.get(opt_f, null))
				if arr_opt.is_empty():
					continue
				var tex_arr2: Array = []
				for p2 in arr_opt:
					var t2: Texture2D = GameData.resolve_frame_texture(p2)
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
			char_sprite.scale = Vector2.ONE * float(visual.get("scale", 1.0))
			_sprite_feet_fine_offset_y = float(visual.get("sprite_feet_fine", 0))
			char_sprite.modulate = c.get("tint", visual.get("tint", Color.WHITE))
			char_sprite.visible = true
			_sprite_faces_left = bool(visual.get("sprite_faces_left", false))
			_walk_anim_over_attack = bool(visual.get("walk_anim_over_attack", false))
			if visual.has("strip_fps") and visual["strip_fps"] is Dictionary:
				for k in visual["strip_fps"]:
					_strip_fps[String(k)] = float(visual["strip_fps"][k])
			frames_per_row = []
			has_sprite = true
			_sync_char_sprite_feet_offset()
	if not has_sprite and char_sprite and visual.has("sprite_strips") and visual["sprite_strips"] is Dictionary:
		var strips: Dictionary = visual["sprite_strips"]
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
			_strip_hframes = maxi(1, int(visual.get("strip_hframes", 8)))
			if visual.has("strip_hframes_by_strip") and visual["strip_hframes_by_strip"] is Dictionary:
				for hk in visual["strip_hframes_by_strip"]:
					_strip_hframes_by_strip[String(hk)] = int(visual["strip_hframes_by_strip"][hk])
			char_sprite.hframes = _hframes_for_strip_key("idle")
			char_sprite.vframes = 1
			char_sprite.scale = Vector2.ONE * float(visual.get("scale", 1.8))
			char_sprite.offset = Vector2(0, float(visual.get("offset_y", 0)))
			char_sprite.frame = 0
			char_sprite.modulate = c.get("tint", visual.get("tint", Color.WHITE))
			char_sprite.visible = true
			_sprite_faces_left = bool(visual.get("sprite_faces_left", false))
			_strip_frames = {
				"idle": _strip_hframes, "walk": _strip_hframes, "attack": _strip_hframes,
				"hit": _strip_hframes, "death": _strip_hframes,
			}
			if visual.has("strip_frames") and visual["strip_frames"] is Dictionary:
				for k in visual["strip_frames"]:
					_strip_frames[k] = int(visual["strip_frames"][k])
			if visual.has("strip_fps") and visual["strip_fps"] is Dictionary:
				for k in visual["strip_fps"]:
					_strip_fps[String(k)] = float(visual["strip_fps"][k])
			_walk_anim_over_attack = bool(visual.get("walk_anim_over_attack", false))
			_start_transform_pending = bool(visual.get("start_transform", false)) \
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
	if not has_sprite and char_sprite and visual.has("sprite") and String(visual["sprite"]) != "":
		var tex: Texture2D = GameData.resolve_frame_texture(visual["sprite"])
		if tex:
			char_sprite.texture = tex
			char_sprite.hframes = int(visual.get("hframes", 1))
			char_sprite.vframes = int(visual.get("vframes", 1))
			char_sprite.scale = Vector2.ONE * float(visual.get("scale", 1.8))
			char_sprite.offset = Vector2(0, float(visual.get("offset_y", 0)))
			char_sprite.frame = 0
			char_sprite.modulate = c.get("tint", visual.get("tint", Color.WHITE))
			char_sprite.visible = true
			frames_per_row = visual.get("frames_per_row", []).duplicate() if visual.has("frames_per_row") else []
			row_idle = int(visual.get("row_idle", 0))
			row_walk = int(visual.get("row_walk", 1))
			row_attack = int(visual.get("row_attack", 3))
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
	if village_mode:
		_apply_village_character_visual_scale()
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
		_apply_house_favorite_bonuses()


func _sync_char_sprite_feet_offset() -> void:
	if char_sprite == null or not char_sprite.visible or char_sprite.texture == null:
		return
	if not _use_sprite_frames:
		return
	var sc: float = char_sprite.scale.y
	var fine_y: float = _sprite_feet_fine_offset_y
	if village_mode:
		fine_y += _village_feet_extra_y
	char_sprite.offset.y = GameData.sprite_feet_offset_y(
		char_sprite.texture, body_radius, sc, fine_y)


func _apply_village_character_visual_scale() -> void:
	if not village_mode:
		return
	var sm: float = GameData.VILLAGE_CHARACTER_SCALE_MULT
	if char_sprite and char_sprite.visible:
		if not is_equal_approx(sm, 1.0):
			char_sprite.scale *= sm
		_sync_char_sprite_feet_offset()


func _apply_house_favorite_bonuses() -> void:
	if village_mode:
		return
	var fav_ids: Array[String] = []
	if input_prefix == "p1":
		fav_ids = GameState.p1_house_favorite_armament_ids_for_battle(character_id)
	elif input_prefix == "p2":
		fav_ids = GameState.p2_house_favorite_armament_ids_for_battle(character_id)
	else:
		return
	if fav_ids.is_empty():
		return
	var stats: Dictionary = GameData.sum_armament_flat_stats(fav_ids)
	var has_bonus: bool = false
	for field in GameData.ARMAMENT_FAVORITE_STAT_FIELDS:
		if float(stats.get(field, 0.0)) > 0.0:
			has_bonus = true
			break
	if not has_bonus:
		return
	GameData.apply_armament_favorite_stats_to_player(self, stats)
	var log_entry: Dictionary = {
		"kind": "house_favorites",
		"stats": stats.duplicate(),
		"source_kind": "house",
		"source_id": input_prefix,
	}
	start_weapon_reward_log.append(log_entry)


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
		if not heavenly_judgment_active:
			modulate.a = 0.4 if int(iframe * 10) % 2 == 0 else 1.0
	elif not heavenly_judgment_active:
		modulate.a = 1.0

	if regen_per_sec > 0.0:
		_heal(regen_per_sec * delta)

	passive_meter_fill_cd = max(0.0, passive_meter_fill_cd - delta)
	_update_breakthrough_trackers(delta)
	_try_fighting_spirit_meter()
	_try_quick_step_meter()
	if wild_impulse_window > 0.0:
		wild_impulse_window -= delta
		if wild_impulse_window <= 0.0:
			wild_impulse_window = 0.0
			wild_impulse_charges_left = 0
	if mushin_active:
		mushin_timer -= delta
		if mushin_timer <= 0.0:
			mushin_active = false
			mushin_timer = 0.0
	if blood_frenzy_stack_timers.size() > 0:
		for i in range(blood_frenzy_stack_timers.size() - 1, -1, -1):
			blood_frenzy_stack_timers[i] -= delta
			if blood_frenzy_stack_timers[i] <= 0.0:
				blood_frenzy_stack_timers.remove_at(i)
	if blood_shroud_active:
		blood_shroud_timer -= delta
		blood_shroud_tick_timer -= delta
		if blood_shroud_tick_timer <= 0.0:
			_blood_shroud_tick()
			blood_shroud_tick_timer += 0.5
		if blood_shroud_timer <= 0.0:
			blood_shroud_active = false
	if not _ignition_enemy_cds.is_empty():
		var to_erase: Array = []
		for eid in _ignition_enemy_cds.keys():
			_ignition_enemy_cds[eid] = float(_ignition_enemy_cds[eid]) - delta
			if float(_ignition_enemy_cds[eid]) <= 0.0:
				to_erase.append(eid)
		for eid in to_erase:
			_ignition_enemy_cds.erase(eid)

	# 主動技能：在戰鬥場景按技能鍵觸發
	if skill_cooldown > 0.0:
		skill_cooldown = max(0.0, skill_cooldown - delta)
	if heavenly_judgment_active:
		_update_heavenly_judgment(delta)
		_update_char_anim(delta)
		queue_redraw()
		return
	if Input.is_action_just_pressed(input_prefix + "_skill"):
		use_skill()

	if village_mode:
		_village_physics(delta)
	else:
		_battle_physics(delta)
	_update_char_anim(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not heavenly_judgment_active or heavenly_judgment_confirm_guard > 0.0:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_confirm_heavenly_judgment_fall(get_global_mouse_position())
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			var world_pos: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * touch.position
			_confirm_heavenly_judgment_fall(world_pos)


## 攝影機／敵人索敵：天罰全程以起跳地面位置為準，不吸引怪物追空中角色。
func get_camera_anchor_position() -> Vector2:
	if heavenly_judgment_active:
		return heavenly_judgment_origin
	return global_position


func get_enemy_target_position() -> Vector2:
	return get_camera_anchor_position()


func get_level_growth_steps() -> int:
	return maxi(0, level - 1)


func get_level_hp_mult() -> float:
	return 1.0 + LEVEL_HP_MULT_PER_LEVEL * float(get_level_growth_steps())


func get_level_damage_mult() -> float:
	return 1.0 + LEVEL_DAMAGE_MULT_PER_LEVEL * float(get_level_growth_steps())


func get_level_def_bonus() -> float:
	return LEVEL_DEF_BONUS_PER_LEVEL * float(get_level_growth_steps())


func get_level_speed_mult() -> float:
	return 1.0 + LEVEL_SPEED_MULT_PER_LEVEL * float(get_level_growth_steps())


func get_effective_max_hp() -> float:
	return max_hp * hp_mult * get_level_hp_mult()


func get_effective_damage_mult() -> float:
	var d: float = damage_mult * get_level_damage_mult()
	if flame_charges > 0:
		d *= 1.0 + float(flame_charges) * 0.05
	return d


func get_effective_atk_power() -> float:
	return atk * get_effective_damage_mult()


func get_effective_def() -> float:
	return def_value + get_level_def_bonus()


func get_effective_rate_mult() -> float:
	var r: float = rate_mult
	if mushin_active:
		var s: Dictionary = GameData.get_skill_def("mushin")
		r *= float(s.get("params", {}).get("combat_rate_mult", 1.4))
	if passive_id == "blood_frenzy" and blood_frenzy_stack_timers.size() > 0:
		var pdef: Dictionary = GameData.get_passive_def("blood_frenzy")
		r *= 1.0 + float(pdef.get("params", {}).get("rate_per_stack", 0.08)) * float(blood_frenzy_stack_timers.size())
	return r


func get_effective_move_speed() -> float:
	var spd: float = move_speed * speed_mult * get_level_speed_mult()
	if _enemy_slow_time > 0.0:
		spd *= _enemy_slow_factor
	if blood_shroud_active:
		spd *= 0.5
	return spd


func apply_enemy_status_effects(effects: Dictionary, source_pos: Vector2 = Vector2.ZERO) -> void:
	if village_mode or hp <= 0.0 or effects.is_empty():
		return
	if effects.get("slow") is Dictionary:
		var sl: Dictionary = effects["slow"]
		_enemy_slow_time = maxf(_enemy_slow_time, float(sl.get("duration", 1.0)))
		_enemy_slow_factor = minf(_enemy_slow_factor, clampf(float(sl.get("factor", 0.55)), 0.15, 1.0))
	if effects.has("stun"):
		_enemy_stun_time = maxf(_enemy_stun_time, float(effects["stun"]))
	if effects.get("bleed") is Dictionary:
		var bl: Dictionary = effects["bleed"]
		_player_bleed_time = maxf(_player_bleed_time, float(bl.get("duration", 2.0)))
		_player_bleed_dps = maxf(_player_bleed_dps, float(bl.get("dps", 2.0)))
	var kb: float = float(effects.get("knockback", 0.0))
	if kb > 0.0:
		var push_dir: Vector2 = Vector2.RIGHT
		if source_pos != Vector2.ZERO:
			push_dir = global_position - source_pos
		if push_dir.length_squared() > 0.001:
			push_dir = push_dir.normalized()
		_knockback_velocity += push_dir * kb


func _tick_enemy_status(delta: float) -> void:
	_enemy_slow_time = maxf(0.0, _enemy_slow_time - delta)
	if _enemy_slow_time <= 0.0:
		_enemy_slow_factor = 1.0
	_enemy_stun_time = maxf(0.0, _enemy_stun_time - delta)
	_tick_player_bleed(delta)


func _tick_player_bleed(delta: float) -> void:
	if _player_bleed_time <= 0.0 or hp <= 0.0 or village_mode:
		_player_bleed_time = 0.0
		_player_bleed_dps = 0.0
		return
	_player_bleed_time = maxf(0.0, _player_bleed_time - delta)
	var dmg: float = _player_bleed_dps * delta
	if dmg > 0.0:
		var taken: float = minf(dmg, hp)
		hp = maxf(0.0, hp - dmg)
		damage_taken += taken
		if hp <= 0.0:
			hp = 0.0
			AudioManager.play_sfx("player_death", 0.02)
			died.emit(self)
		elif iframe <= 0.0:
			AudioManager.play_sfx("player_hurt", 0.02)
	if _player_bleed_time <= 0.0:
		_player_bleed_dps = 0.0


func _apply_knockback_displacement(delta: float) -> void:
	if _knockback_velocity.length_squared() < 4.0:
		return
	var step: Vector2 = _knockback_velocity * delta
	if game_ref and game_ref.has_method("is_world_blocked_at"):
		if abs(step.x) > 0.001 and not game_ref.is_world_blocked_at(
				global_position + Vector2(step.x, 0), body_radius):
			global_position.x += step.x
		if abs(step.y) > 0.001 and not game_ref.is_world_blocked_at(
				global_position + Vector2(0, step.y), body_radius):
			global_position.y += step.y
	else:
		global_position += step
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 780.0 * delta)


# 戰鬥（俯視）：八方向自由移動
func _battle_physics(delta: float) -> void:
	_tick_enemy_status(delta)
	var dir: Vector2 = Vector2(
		Input.get_action_strength(input_prefix + "_right") - Input.get_action_strength(input_prefix + "_left"),
		Input.get_action_strength(input_prefix + "_down") - Input.get_action_strength(input_prefix + "_up")
	)
	if _enemy_stun_time > 0.0:
		dir = Vector2.ZERO
	if dir.length() > 0.05:
		face_dir = dir.normalized()
	# 程序圖案（後備）跟著朝向旋轉；CharSprite 用左右翻轉
	if sprite and sprite.visible:
		sprite.rotation = face_dir.angle()
	if dir.length() > 0:
		velocity = dir.normalized() * get_effective_move_speed()
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
	_apply_knockback_displacement(delta)


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
	var target_vx: float = ix * get_effective_move_speed()
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
		"skill":
			key = "skill" if _sprite_frame_anims.has("skill") else "attack"
		"hit":
			key = "hurt" if _sprite_frame_anims.has("hurt") else "idle"
		"death":
			key = "death" if _sprite_frame_anims.has("death") else "idle"

	var arr: Array = _sprite_frame_anims.get(key, _sprite_frame_anims["idle"])
	var fc: int = maxi(1, arr.size())
	var anim_fps_use: float = _strip_fps_for_anim(key) if key == "skill" or key == "attack" else _anim_fps
	var f_idx: int = int(anim_time * anim_fps_use) % fc
	if anim_state == "death" or anim_state == "skill":
		var f: int = int(anim_time * anim_fps_use)
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
		return (entry as Array).duplicate()
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


func play_skill_cast_anim() -> void:
	if hp <= 0:
		return
	if _is_transform_anim_active():
		return
	if char_sprite == null or not char_sprite.visible:
		return
	if _use_sprite_frames and _sprite_frame_anims.has("skill"):
		anim_state = "skill"
		anim_time = 0.0
		var sk_arr: Array = _sprite_frame_anims["skill"]
		var sk_f: int = maxi(1, sk_arr.size())
		anim_locked_for = max(anim_locked_for, float(sk_f) / _strip_fps_for_anim("skill"))
	else:
		play_attack_anim()


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
	if village_mode:
		_draw_village_overhead_label()
		if sprite and sprite.visible:
			draw_line(Vector2.ZERO, face_dir * 18.0, Color(1, 1, 1, 0.4), 2.0)
		return
	var w: float = 36.0
	var h: float = 4.0
	var top := Vector2(-w * 0.5, BATTLE_HUD_TOP_Y)
	draw_rect(Rect2(top, Vector2(w, h)), Color(0.1, 0.05, 0.05))
	var pct: float = clamp(hp / max(1.0, get_effective_max_hp()), 0.0, 1.0)
	draw_rect(Rect2(top, Vector2(w * pct, h)), Color(0.95, 0.3, 0.3))
	if skill_id != "none":
		var top_skill := top + Vector2(0, h + 2.0)
		draw_rect(Rect2(top_skill, Vector2(w, 3.0)), Color(0.12, 0.10, 0.0))
		var m_pct: float = clamp(skill_meter / SKILL_METER_MAX, 0.0, 1.0)
		draw_rect(Rect2(top_skill, Vector2(w * m_pct, 3.0)), Color(1.0, 0.88, 0.32))
	var s: String = "Lv%d %s" % [level, GameData.get_character_def(character_id).get("name", "")]
	var fnt := ThemeDB.fallback_font
	draw_string(fnt, top + Vector2(-4, -6), s,
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

	# 血物壟罩：AOE 範圍脈衝光環
	if blood_shroud_active:
		var t_bs: float = Time.get_ticks_msec() * 0.004
		var pulse_bs: float = 0.5 + 0.5 * sin(t_bs)
		var bs_r: float = float(GameData.get_skill_def("blood_shroud").get("params", {}).get("combat_radius", 200.0))
		draw_circle(Vector2.ZERO, bs_r, Color(0.75, 0.05, 0.12, 0.06 + pulse_bs * 0.04))
		draw_arc(Vector2.ZERO, bs_r, 0.0, TAU, 64, Color(0.9, 0.15, 0.22, 0.28 + pulse_bs * 0.18), 2.0, true)
		draw_arc(Vector2.ZERO, bs_r - 4.0, 0.0, TAU, 64, Color(1.0, 0.35, 0.42, 0.10 + pulse_bs * 0.08), 1.0, true)

	# 血包點陣（最多5顆，y=-62）
	if blood_packs > 0 or has_revival_charge:
		var dot_r: float = 3.0
		var gap: float = 3.0
		var total_w: float = 5.0 * (dot_r * 2.0) + 4.0 * gap
		var sx: float = -total_w * 0.5 + dot_r
		var sy: float = -62.0
		for i in 5:
			var cx: float = sx + float(i) * (dot_r * 2.0 + gap)
			var filled: bool = i < blood_packs
			var c: Color = Color(0.9, 0.15, 0.2) if filled else Color(0.28, 0.06, 0.08)
			draw_circle(Vector2(cx, sy), dot_r, c)
		if has_revival_charge:
			var fnt_bp := ThemeDB.fallback_font
			draw_string(fnt_bp, Vector2(-5, sy - 6.0), "♥",
				HORIZONTAL_ALIGNMENT_CENTER, 12, 11, Color(1.0, 0.55, 0.7))

	# 焰氣點陣（最多5顆，y=-74）
	if flame_charges > 0 or has_skill_boost:
		var dot_r: float = 3.0
		var gap: float = 3.0
		var total_w: float = 5.0 * (dot_r * 2.0) + 4.0 * gap
		var sx: float = -total_w * 0.5 + dot_r
		var sy: float = -74.0
		for i in 5:
			var cx: float = sx + float(i) * (dot_r * 2.0 + gap)
			var filled: bool = i < flame_charges
			var c: Color = Color(1.0, 0.48, 0.06) if filled else Color(0.3, 0.13, 0.02)
			draw_circle(Vector2(cx, sy), dot_r, c)
		if has_skill_boost:
			var fnt_fc := ThemeDB.fallback_font
			draw_string(fnt_fc, Vector2(-5, sy - 6.0), "★",
				HORIZONTAL_ALIGNMENT_CENTER, 12, 11, Color(1.0, 0.9, 0.2))


func _village_overhead_label_y() -> float:
	var y_off: float = -body_radius - 18.0
	if char_sprite and char_sprite.visible and char_sprite.texture:
		var tex: Texture2D = char_sprite.texture
		var vis: Rect2 = GameData.visible_texture_region(tex)
		var tex_h: float = float(maxi(1, tex.get_height()))
		var top_from_center: float = vis.position.y - tex_h * 0.5
		var sprite_top_y: float = char_sprite.offset.y + top_from_center * char_sprite.scale.y
		y_off = minf(y_off, sprite_top_y - 14.0)
	return y_off


func _draw_village_overhead_label() -> void:
	var slot_lbl: String = tr("INPUT_PROMPT_PLAYER_P2") if input_prefix == "p2" \
			else tr("INPUT_PROMPT_PLAYER_P1")
	var cname: String = GameData.tr_character_name(character_id)
	var text: String = "%s  %s" % [slot_lbl, cname]
	var fnt: Font = ThemeDB.fallback_font
	var font_size: int = 14
	var y_off: float = _village_overhead_label_y()
	var col: Color = Color(0.65, 0.88, 1.0) if input_prefix == "p2" \
			else Color(1.0, 0.95, 0.72)
	draw_string(fnt, Vector2(-56, y_off), text,
		HORIZONTAL_ALIGNMENT_CENTER, 112, font_size, col)


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
	var eff_reduce: float = clampf(dmg_reduce + float(blood_packs) * 0.05, 0.0, 0.75)
	var actual: float = max(1.0, d * (1.0 - eff_reduce) - get_effective_def() * 0.5)
	var taken_now: float = min(actual, hp)
	hp -= actual
	damage_taken += taken_now
	iframe = 0.6
	if hp <= 0:
		hp = 0
		if has_revival_charge:
			has_revival_charge = false
			_heal(get_effective_max_hp() * 0.2)
			modulate = Color(1.5, 0.3, 0.3)
			create_tween().tween_property(self, "modulate", Color(1, 1, 1), 0.5)
			AudioManager.play_sfx("player_hurt", 0.06)
			return
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
	hp = min(get_effective_max_hp(), hp + amount)


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
	_refresh_weapon_stats()
	_heal(get_effective_max_hp() * 0.05)
	AudioManager.play_sfx("level_up", 0.02)
	leveled_up.emit(self)


# Game.gd 在隊伍升級時為每位存活玩家呼叫
func on_team_level_up(new_level: int) -> void:
	level = new_level
	# 升級回血上限以最大 HP 5%（避免雙人快速升級被當無敵）
	_refresh_weapon_stats()
	_heal(get_effective_max_hp() * 0.05)
	AudioManager.play_sfx("level_up", 0.02)


# Game.gd 同步隊伍 XP 進度給 HUD/_draw
func sync_team_progress(team_xp: float, team_to_next: float) -> void:
	xp = team_xp
	xp_to_next = team_to_next


func _refresh_weapon_stats() -> void:
	for ww in weapons:
		if ww["node"]:
			ww["node"].refresh()


func on_enemy_killed(_e: Node) -> void:
	kills += 1
	if _e != null and _e.get("slime_def") is Dictionary:
		var eid: String = String(_e.slime_def.get("id", ""))
		if eid != "":
			GameState.unlock_codex_monster_on_defeat(eid)
	if passive_id == "fighting_spirit" and skill_id != "none":
		passive_kill_counter += 1
		_try_fighting_spirit_meter()
	if passive_id == "blood_frenzy":
		var pdef: Dictionary = GameData.get_passive_def("blood_frenzy")
		var max_s: int = int(pdef.get("params", {}).get("max_stacks", 5))
		var dur: float = float(pdef.get("params", {}).get("stack_duration", 3.0))
		if blood_frenzy_stack_timers.size() < max_s:
			blood_frenzy_stack_timers.append(dur)


# ===== 被動 / 主動技能 =====
func _apply_passive() -> void:
	passive_kill_counter = 0
	passive_hit_counter = 0
	passive_blade_aura_counter = 0
	blood_frenzy_stack_timers.clear()
	_ignition_enemy_cds.clear()
	_ignition_explosion_counter = 0
	breakthrough_same_enemy_hits.clear()
	breakthrough_attack_hits.clear()
	wild_impulse_window = 0.0
	wild_impulse_charges_left = 0
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
	var dmg: float = max(min_dmg, get_effective_atk_power() * dmg_mul)
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
			"arrow_sprite": true,
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
	play_skill_cast_anim()


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


func passive_sword_aura_resonance_on_status() -> void:
	if passive_id != "sword_aura_resonance" or skill_id == "none":
		return
	var pdef: Dictionary = GameData.get_passive_def("sword_aura_resonance")
	var fill: float = float(pdef.get("params", {}).get("meter_fill", 32.0))
	_try_grant_passive_skill_meter(fill)


func reset_wild_impulse_chain() -> void:
	wild_impulse_window = 0.0
	wild_impulse_charges_left = 0


# 武器命中事件（由 WeaponBase.damage_enemy 呼叫）
func on_weapon_hit(_e: Node, _weapon: Node) -> void:
	if passive_id == "quick_step" and skill_id != "none":
		passive_hit_counter += 1
		_try_quick_step_meter()
	if passive_id == "breakthrough" and skill_id != "none":
		_breakthrough_on_weapon_hit(_e, _weapon)
	if passive_id == "bloodlust" and skill_id != "none" and _e != null \
			and is_instance_valid(_e) and _e.has_method("is_status_bleeding"):
		if _e.is_status_bleeding():
			var pdef2: Dictionary = GameData.get_passive_def("bloodlust")
			var fill2: float = float(pdef2.get("params", {}).get("meter_fill", 30.0))
			_try_grant_passive_skill_meter(fill2)
	if passive_id == "blade_aura" and skill_id != "none":
		var wid: String = String(_weapon.def.get("id", "")) if _weapon != null else ""
		if wid == "shard":
			passive_blade_aura_counter += 1
			_try_blade_aura_meter()
	if passive_id == "ignition" and _weapon != null and _e != null and is_instance_valid(_e):
		var wid2: String = String(_weapon.def.get("id", ""))
		if wid2 == "flame" and _e.has_method("apply_status_burn"):
			var eid: int = _e.get_instance_id()
			if not _ignition_enemy_cds.has(eid) or float(_ignition_enemy_cds[eid]) <= 0.0:
				var pdef: Dictionary = GameData.get_passive_def("ignition")
				var prm: Dictionary = pdef.get("params", {})
				var dmg: float = get_effective_atk_power() * float(prm.get("explosion_damage_mult", 0.6))
				var radius: float = float(prm.get("explosion_radius", 72.0))
				_ignition_explode(_e.global_position, dmg, radius)
				_ignition_enemy_cds[eid] = float(prm.get("enemy_cd", 3.0))
				_ignition_explosion_counter += 1
				_ignition_try_meter()


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


func grant_blood_pack() -> void:
	blood_packs = mini(blood_packs + 1, 5)
	if blood_packs >= 5:
		blood_packs = 0
		has_revival_charge = true
		modulate = Color(1.4, 0.3, 0.3)
		create_tween().tween_property(self, "modulate", Color(1, 1, 1), 0.4)


func grant_flame_charge() -> void:
	flame_charges = mini(flame_charges + 1, 5)
	if flame_charges >= 5:
		flame_charges = 0
		has_skill_boost = true
		modulate = Color(1.5, 0.6, 0.1)
		create_tween().tween_property(self, "modulate", Color(1, 1, 1), 0.4)


func _ignition_explode(center: Vector2, dmg: float, radius: float) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var ee := e as Node2D
		if ee == null:
			continue
		if ee.global_position.distance_to(center) <= radius:
			if e.has_method("take_damage"):
				e.take_damage(dmg, self)


func _ignition_try_meter() -> void:
	var pdef: Dictionary = GameData.get_passive_def("ignition")
	var prm: Dictionary = pdef.get("params", {})
	var need: int = int(prm.get("explosions_per_fill", 5))
	var fill: float = float(prm.get("meter_fill", 25.0))
	if _ignition_explosion_counter >= need:
		_ignition_explosion_counter -= need
		_try_grant_passive_skill_meter(fill)


func _try_blade_aura_meter() -> void:
	if passive_id != "blade_aura" or skill_id == "none":
		return
	var pdef: Dictionary = GameData.get_passive_def("blade_aura")
	var need: int = max(1, int(pdef.get("params", {}).get("hits_per_fill", 10)))
	var fill: float = float(pdef.get("params", {}).get("meter_fill", 28.0))
	while passive_blade_aura_counter >= need:
		if not _try_grant_passive_skill_meter(fill):
			break
		passive_blade_aura_counter -= need


func _update_breakthrough_trackers(delta: float) -> void:
	for key in breakthrough_same_enemy_hits.keys():
		var data: Dictionary = breakthrough_same_enemy_hits[key]
		data["time"] = float(data.get("time", 0.0)) - delta
		if float(data["time"]) <= 0.0:
			breakthrough_same_enemy_hits.erase(key)
	for key in breakthrough_attack_hits.keys():
		var data2: Dictionary = breakthrough_attack_hits[key]
		data2["time"] = float(data2.get("time", 0.0)) - delta
		if float(data2["time"]) <= 0.0:
			breakthrough_attack_hits.erase(key)


func _breakthrough_on_weapon_hit(e: Node, weapon: Node) -> void:
	if e == null or not is_instance_valid(e):
		return
	var pdef: Dictionary = GameData.get_passive_def("breakthrough")
	var params: Dictionary = pdef.get("params", {})
	var window: float = float(params.get("same_enemy_window", 5.0))
	var same_need: int = max(1, int(params.get("same_enemy_hits", 3)))
	var multi_need: int = max(1, int(params.get("multi_hit_count", 3)))
	var eid: String = str(e.get_instance_id())
	var same_data: Dictionary = breakthrough_same_enemy_hits.get(eid, {"count": 0, "time": 0.0})
	if float(same_data.get("time", 0.0)) <= 0.0:
		same_data["count"] = 0
	same_data["count"] = int(same_data.get("count", 0)) + 1
	same_data["time"] = window
	breakthrough_same_enemy_hits[eid] = same_data
	if int(same_data["count"]) >= same_need:
		breakthrough_same_enemy_hits.erase(eid)
		_breakthrough_try_meter_fill()

	var token: String = "none"
	if weapon != null:
		token = str(weapon.get_instance_id())
	if weapon != null and weapon.has_method("get_attack_token"):
		token = String(weapon.call("get_attack_token"))
	var attack_data: Dictionary = breakthrough_attack_hits.get(token, {
		"seen": {},
		"time": 0.24,
		"triggered": false,
	})
	var seen: Dictionary = attack_data.get("seen", {})
	seen[eid] = true
	attack_data["seen"] = seen
	attack_data["time"] = 0.24
	if not bool(attack_data.get("triggered", false)) and seen.size() >= multi_need:
		attack_data["triggered"] = true
		_breakthrough_try_meter_fill()
	breakthrough_attack_hits[token] = attack_data


func _breakthrough_try_meter_fill() -> void:
	var pdef: Dictionary = GameData.get_passive_def("breakthrough")
	var fill: float = float(pdef.get("params", {}).get("meter_fill", 35.0))
	if _try_grant_passive_skill_meter(fill):
		modulate = Color(1.35, 1.18, 0.65)
		create_tween().tween_property(self, "modulate", Color(1, 1, 1), 0.22)


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
	var from_wi_followup: bool = skill_id == "wild_impulse" \
			and wild_impulse_charges_left > 0 and wild_impulse_window > 0.0
	var s: Dictionary
	if from_wi_followup:
		s = GameData.get_skill_def(skill_id)
	else:
		s = try_consume_skill()
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
		"heavenly_judgment":
			_skill_heavenly_judgment_combat(s)
		"mirror_moon":
			_skill_mirror_moon_combat(s)
		"wild_impulse":
			_skill_wild_impulse_combat(s)
			if from_wi_followup:
				wild_impulse_charges_left = max(0, wild_impulse_charges_left - 1)
			else:
				wild_impulse_window = 5.0
				wild_impulse_charges_left = 2
		"mushin":
			_skill_mushin_combat(s)
		"blood_shroud":
			_skill_blood_shroud_combat(s)
		"flame_burst":
			_skill_flame_burst_combat(s)
	return true


# --- 個別技能：戰鬥版實作 ---
func _skill_whirl_slash_combat(s: Dictionary) -> void:
	var params: Dictionary = s.get("params", {})
	var radius: float = float(params.get("combat_radius", 360.0))
	var dmg_mult: float = float(params.get("combat_damage_mult", 6.0))
	var min_damage: float = float(params.get("combat_min_damage", 80.0))
	var dmg: float = max(min_damage, get_effective_atk_power() * dmg_mult)
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
	play_skill_cast_anim()


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
	var dmg: float = max(min_dmg, get_effective_atk_power() * dmg_mul)
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
	play_skill_cast_anim()


func _skill_heavenly_judgment_combat(s: Dictionary) -> void:
	_kill_heavenly_judgment_tween()
	heavenly_judgment_params = s.get("params", {})
	heavenly_judgment_active = true
	heavenly_judgment_phase = "rise"
	heavenly_judgment_origin = global_position
	heavenly_judgment_target = global_position
	heavenly_judgment_air_pos = _compute_heavenly_judgment_air_pos()
	heavenly_judgment_time_left = float(heavenly_judgment_params.get("combat_select_time", 3.0))
	heavenly_judgment_confirm_guard = 0.16
	velocity = Vector2.ZERO
	modulate.a = 1.0
	iframe = 0.25
	_start_heavenly_judgment_rise()


func _kill_heavenly_judgment_tween() -> void:
	if _heavenly_judgment_tween != null and is_instance_valid(_heavenly_judgment_tween):
		_heavenly_judgment_tween.kill()
	_heavenly_judgment_tween = null


func _compute_heavenly_judgment_air_pos() -> Vector2:
	var air_y: float = global_position.y - 480.0
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam != null:
		var half_h: float = get_viewport().get_visible_rect().size.y * 0.5 / maxf(0.001, cam.zoom.y)
		var extra: float = float(heavenly_judgment_params.get("combat_air_offset_y", 180.0))
		air_y = cam.global_position.y - half_h - extra
	return Vector2(global_position.x, air_y)


func _start_heavenly_judgment_rise() -> void:
	var rise_t: float = maxf(0.12, float(heavenly_judgment_params.get("combat_rise_time", 0.45)))
	_heavenly_judgment_tween = create_tween()
	_heavenly_judgment_tween.tween_property(
		self, "global_position", heavenly_judgment_air_pos, rise_t,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_heavenly_judgment_tween.tween_callback(_begin_heavenly_judgment_select)


func _begin_heavenly_judgment_select() -> void:
	if not heavenly_judgment_active or heavenly_judgment_phase != "rise":
		return
	heavenly_judgment_phase = "select"
	global_position = heavenly_judgment_air_pos
	modulate.a = 0.35
	_ensure_heavenly_judgment_marker()


func _update_heavenly_judgment(delta: float) -> void:
	velocity = Vector2.ZERO
	iframe = maxf(iframe, 0.12)
	if heavenly_judgment_phase == "rise" or heavenly_judgment_phase == "fall":
		return
	if heavenly_judgment_phase != "select":
		return
	heavenly_judgment_confirm_guard = max(0.0, heavenly_judgment_confirm_guard - delta)
	heavenly_judgment_time_left -= delta
	var dir := Vector2(
		Input.get_action_strength(input_prefix + "_right") - Input.get_action_strength(input_prefix + "_left"),
		Input.get_action_strength(input_prefix + "_down") - Input.get_action_strength(input_prefix + "_up")
	)
	if dir.length() > 0.05:
		var speed: float = float(heavenly_judgment_params.get("combat_cursor_speed", 320.0))
		heavenly_judgment_target += dir.normalized() * speed * delta
		heavenly_judgment_target = _clamp_heavenly_judgment_target(heavenly_judgment_target)
	if heavenly_judgment_marker != null and is_instance_valid(heavenly_judgment_marker):
		heavenly_judgment_marker.global_position = heavenly_judgment_target
		heavenly_judgment_marker.set_meta("time_left", heavenly_judgment_time_left)
		heavenly_judgment_marker.queue_redraw()
	if heavenly_judgment_confirm_guard <= 0.0 and (
			Input.is_action_just_pressed(input_prefix + "_skill")
			or Input.is_action_just_pressed(input_prefix + "_action")
			or Input.is_action_just_pressed("ui_accept")):
		_confirm_heavenly_judgment_fall(heavenly_judgment_target)
		return
	if heavenly_judgment_time_left <= 0.0:
		_confirm_heavenly_judgment_fall(heavenly_judgment_origin)


func _confirm_heavenly_judgment_fall(pos: Vector2) -> void:
	if not heavenly_judgment_active or heavenly_judgment_phase != "select":
		return
	heavenly_judgment_target = _clamp_heavenly_judgment_target(pos)
	_begin_heavenly_judgment_fall(heavenly_judgment_target)


func _begin_heavenly_judgment_fall(ground_pos: Vector2) -> void:
	_kill_heavenly_judgment_tween()
	heavenly_judgment_phase = "fall"
	_clear_heavenly_judgment_marker()
	modulate.a = 1.0
	var fall_t: float = maxf(0.1, float(heavenly_judgment_params.get("combat_fall_time", 0.32)))
	_heavenly_judgment_tween = create_tween()
	_heavenly_judgment_tween.tween_property(
		self, "global_position", ground_pos, fall_t,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_heavenly_judgment_tween.tween_callback(_land_heavenly_judgment.bind(ground_pos))


func _clamp_heavenly_judgment_target(pos: Vector2) -> Vector2:
	var max_range: float = float(heavenly_judgment_params.get("combat_target_range", 420.0))
	var offset: Vector2 = pos - heavenly_judgment_origin
	if offset.length() > max_range:
		pos = heavenly_judgment_origin + offset.normalized() * max_range
	var game = get_parent()
	if game and game.has_method("is_world_blocked_at"):
		if game.is_world_blocked_at(pos, body_radius):
			return heavenly_judgment_target
	return pos


func _land_heavenly_judgment(pos: Vector2) -> void:
	if not heavenly_judgment_active:
		return
	_kill_heavenly_judgment_tween()
	heavenly_judgment_active = false
	heavenly_judgment_phase = ""
	global_position = _clamp_heavenly_judgment_target(pos)
	modulate.a = 1.0
	iframe = float(heavenly_judgment_params.get("combat_landing_iframe", 0.35))
	_clear_heavenly_judgment_marker()
	var radius: float = float(heavenly_judgment_params.get("combat_radius", 150.0))
	var dmg_mul: float = float(heavenly_judgment_params.get("combat_damage_mult", 5.2))
	var min_damage: float = float(heavenly_judgment_params.get("combat_min_damage", 70.0))
	var stun_time: float = float(heavenly_judgment_params.get("combat_stun", 1.4))
	var dmg: float = max(min_damage, get_effective_atk_power() * dmg_mul)
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
		if ee.global_position.distance_to(global_position) <= radius + er:
			if e.has_method("take_damage"):
				e.take_damage(dmg, self)
				any_hit = true
			if e.has_method("apply_stun"):
				e.apply_stun(stun_time)
	if any_hit:
		AudioManager.play_sfx("skill_cast", 0.04)
	_spawn_heavenly_judgment_impact(radius)
	play_skill_cast_anim()


func _ensure_heavenly_judgment_marker() -> void:
	_clear_heavenly_judgment_marker()
	var marker := DrawerNode2D.new()
	marker.fn = Callable(self, "_draw_heavenly_judgment_marker")
	marker.z_index = 80
	marker.global_position = heavenly_judgment_target
	marker.set_meta("radius", float(heavenly_judgment_params.get("combat_radius", 150.0)))
	marker.set_meta("max_time", float(heavenly_judgment_params.get("combat_select_time", 3.0)))
	marker.set_meta("time_left", heavenly_judgment_time_left)
	get_tree().current_scene.add_child(marker)
	heavenly_judgment_marker = marker


func _clear_heavenly_judgment_marker() -> void:
	if heavenly_judgment_marker != null and is_instance_valid(heavenly_judgment_marker):
		heavenly_judgment_marker.queue_free()
	heavenly_judgment_marker = null


func _draw_heavenly_judgment_marker(node: Node2D) -> void:
	var radius: float = float(node.get_meta("radius", 150.0))
	var max_time: float = max(0.01, float(node.get_meta("max_time", 3.0)))
	var time_left: float = float(node.get_meta("time_left", 0.0))
	var ready: float = clampf(1.0 - time_left / max_time, 0.0, 1.0)
	node.draw_circle(Vector2.ZERO, radius, Color(1.0, 0.72, 0.18, 0.16 + ready * 0.10))
	node.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1.0, 0.88, 0.34, 0.92), 3.0)
	node.draw_line(Vector2(-14, 0), Vector2(14, 0), Color(1.0, 0.95, 0.55), 2.0)
	node.draw_line(Vector2(0, -14), Vector2(0, 14), Color(1.0, 0.95, 0.55), 2.0)


func _spawn_heavenly_judgment_impact(radius: float) -> void:
	var impact := DrawerNode2D.new()
	impact.fn = Callable(self, "_draw_heavenly_judgment_impact")
	impact.z_index = 90
	impact.global_position = global_position
	impact.set_meta("radius", radius)
	get_tree().current_scene.add_child(impact)
	var tw := impact.create_tween()
	impact.scale = Vector2(0.2, 0.2)
	impact.modulate.a = 0.92
	tw.tween_property(impact, "scale", Vector2.ONE, 0.12)
	tw.parallel().tween_property(impact, "modulate:a", 0.0, 0.34)
	tw.tween_callback(impact.queue_free)


func _draw_heavenly_judgment_impact(node: Node2D) -> void:
	var radius: float = float(node.get_meta("radius", 150.0))
	node.draw_circle(Vector2.ZERO, radius, Color(1.0, 0.55, 0.12, 0.24))
	node.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1.0, 0.86, 0.28, 0.95), 5.0)


func _skill_mirror_moon_combat(s: Dictionary) -> void:
	var params: Dictionary = s.get("params", {})
	var origin: Vector2 = global_position
	var dir: Vector2 = face_dir.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var dash_distance: float = float(params.get("combat_dash_distance", 320.0))
	var dash_width: float = float(params.get("combat_dash_width", 74.0))
	var end_pos: Vector2 = _mirror_moon_dash_end(origin, dir, dash_distance)
	var dmg: float = max(
		float(params.get("combat_min_damage", 36.0)),
		get_effective_atk_power() * float(params.get("combat_damage_mult", 2.8)))
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var ee := e as Node2D
		if ee == null:
			continue
		var er: float = float(e.get("radius")) if e.get("radius") != null else 28.0
		if _point_segment_distance_sq(ee.global_position, origin, end_pos) <= pow(dash_width + er, 2.0):
			if e.has_method("take_damage"):
				e.take_damage(dmg, self)
	global_position = end_pos
	_spawn_mirror_moon_dash_vfx(origin, end_pos, dash_width)
	_spawn_mirror_moon_clone(origin, dir, params)
	play_skill_cast_anim()


func _mirror_moon_dash_end(origin: Vector2, dir: Vector2, distance: float) -> Vector2:
	var end_pos: Vector2 = origin + dir * distance
	var game = get_parent()
	if game and game.has_method("is_world_blocked_at"):
		var steps: int = 8
		for i in range(1, steps + 1):
			var p: Vector2 = origin.lerp(end_pos, float(i) / float(steps))
			if game.is_world_blocked_at(p, body_radius):
				return origin.lerp(end_pos, float(i - 1) / float(steps))
	return end_pos


func _spawn_mirror_moon_clone(pos: Vector2, dir: Vector2, params: Dictionary) -> void:
	var clone := _MirrorMoonClone.new()
	clone.setup(
		self,
		dir,
		float(params.get("clone_duration", 3.0)),
		float(params.get("clone_interval", 0.55)),
		float(params.get("clone_radius", 150.0)),
		max(float(params.get("clone_min_damage", 18.0)),
			get_effective_atk_power() * float(params.get("clone_damage_mult", 1.15))),
		color)
	clone.global_position = pos
	get_tree().current_scene.add_child(clone)


func _spawn_mirror_moon_dash_vfx(start: Vector2, end: Vector2, width: float) -> void:
	var vfx := DrawerNode2D.new()
	vfx.fn = Callable(self, "_draw_mirror_moon_dash_vfx")
	vfx.z_index = 92
	vfx.global_position = start
	vfx.set_meta("end_local", end - start)
	vfx.set_meta("width", width)
	get_tree().current_scene.add_child(vfx)
	var tw := vfx.create_tween()
	vfx.modulate.a = 0.9
	tw.tween_property(vfx, "modulate:a", 0.0, 0.28)
	tw.tween_callback(vfx.queue_free)


func _draw_mirror_moon_dash_vfx(node: Node2D) -> void:
	var end_local: Vector2 = node.get_meta("end_local", Vector2.RIGHT * 260.0)
	var width: float = float(node.get_meta("width", 70.0))
	node.draw_line(Vector2.ZERO, end_local, Color(0.78, 0.95, 1.0, 0.88), width * 0.35)
	node.draw_line(Vector2.ZERO, end_local, Color(1.0, 1.0, 1.0, 0.95), 3.0)


func _skill_wild_impulse_combat(s: Dictionary) -> void:
	var params: Dictionary = s.get("params", {})
	var origin: Vector2 = global_position
	var dir: Vector2 = face_dir.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var dash_distance: float = float(params.get("combat_dash_distance", 300.0))
	var dash_width: float = float(params.get("combat_dash_width", 80.0))
	var push_dist: float = float(params.get("combat_push_distance", 56.0))
	var end_pos: Vector2 = _mirror_moon_dash_end(origin, dir, dash_distance)
	var dmg: float = max(
		float(params.get("combat_min_damage", 32.0)),
		get_effective_atk_power() * float(params.get("combat_damage_mult", 2.4)))
	var push_vec: Vector2 = dir * push_dist
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var ee := e as Node2D
		if ee == null:
			continue
		var er: float = float(e.get("radius")) if e.get("radius") != null else 28.0
		if _point_segment_distance_sq(ee.global_position, origin, end_pos) <= pow(dash_width + er, 2.0):
			if e.has_method("take_damage"):
				e.take_damage(dmg, self)
			if e.has_method("apply_position_push"):
				e.apply_position_push(push_vec)
	global_position = end_pos
	_spawn_mirror_moon_dash_vfx(origin, end_pos, dash_width * 0.85)
	play_skill_cast_anim()


func _skill_mushin_combat(s: Dictionary) -> void:
	var params: Dictionary = s.get("params", {})
	mushin_active = true
	mushin_timer = float(params.get("combat_duration", 5.0))
	modulate = Color(0.82, 0.88, 1.6)
	create_tween().tween_property(self, "modulate", Color(1, 1, 1), 0.4)
	play_skill_cast_anim()


func _skill_blood_shroud_combat(s: Dictionary) -> void:
	var params: Dictionary = s.get("params", {})
	blood_shroud_active = true
	blood_shroud_timer = float(params.get("combat_duration", 5.0))
	blood_shroud_tick_timer = 0.0
	modulate = Color(1.4, 0.2, 0.3)
	create_tween().tween_property(self, "modulate", Color(1, 1, 1), 0.5)
	play_skill_cast_anim()


func _blood_shroud_tick() -> void:
	var s: Dictionary = GameData.get_skill_def("blood_shroud")
	var params: Dictionary = s.get("params", {})
	var radius: float = float(params.get("combat_radius", 200.0))
	var dmg: float = get_effective_atk_power() * float(params.get("combat_damage_mult", 0.8))
	var heal_ratio: float = float(params.get("combat_heal_ratio", 0.3))
	var bleed_dps_r: float = float(params.get("combat_bleed_dps_ratio", 0.15))
	var total_heal: float = 0.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var ee := e as Node2D
		if ee == null:
			continue
		if ee.global_position.distance_to(global_position) <= radius:
			if e.has_method("take_damage"):
				e.take_damage(dmg, self)
				total_heal += dmg * heal_ratio
			if e.has_method("apply_status_bleed"):
				e.apply_status_bleed(dmg * bleed_dps_r,
					GameData.ENEMY_STATUS_CLAW_BLEED_DURATION, self)
	if total_heal > 0.0:
		_heal(total_heal)


func _skill_flame_burst_combat(s: Dictionary) -> void:
	var params: Dictionary = s.get("params", {})
	var boosted: bool = has_skill_boost
	if boosted:
		has_skill_boost = false
	var aim: Vector2 = face_dir.normalized()
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT
	var land: Vector2 = global_position + aim * float(params.get("combat_range", 280.0))
	var inner_r: float = float(params.get("combat_inner_radius", 96.0))
	var outer_r: float = float(params.get("combat_outer_radius", 192.0))
	var dmg: float = max(float(params.get("combat_min_damage", 60.0)),
		get_effective_atk_power() * float(params.get("combat_damage_mult", 5.0)))
	if boosted:
		dmg *= float(params.get("combat_boost_crit_mult", 2.0))
	var push_dist: float = float(params.get("combat_push", 80.0))
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var ee := e as Node2D
		if ee == null:
			continue
		var d: float = ee.global_position.distance_to(land)
		if d <= inner_r:
			if e.has_method("take_damage"):
				e.take_damage(dmg, self)
			if e.has_method("apply_position_push"):
				var push_dir: Vector2 = (ee.global_position - land).normalized()
				if push_dir == Vector2.ZERO:
					push_dir = aim
				e.apply_position_push(push_dir * push_dist)
		if d <= outer_r and e.has_method("apply_status_burn"):
			e.apply_status_burn(
				GameData.ENEMY_STATUS_FLAME_BURN_DPS_RATIO * get_effective_atk_power(),
				GameData.ENEMY_STATUS_FLAME_BURN_DURATION, self)
	modulate = Color(1.6, 0.55, 0.1)
	create_tween().tween_property(self, "modulate", Color(1, 1, 1), 0.4)
	play_skill_cast_anim()
	_spawn_flame_burst_vfx(land, inner_r, outer_r, boosted)


func _spawn_flame_burst_vfx(center: Vector2, inner_r: float, outer_r: float, boosted: bool) -> void:
	var vfx := _FlameBurstVFX.new()
	vfx.inner_r = inner_r
	vfx.outer_r = outer_r
	vfx.boosted = boosted
	get_parent().add_child(vfx)
	vfx.global_position = center


func add_weapon(weapon_id: String, allow_unaccounted_upgrade: bool = true) -> Dictionary:
	for w in weapons:
		if w["id"] == weapon_id:
			if not allow_unaccounted_upgrade and not GameState.is_weapon_unlocked(weapon_id):
				return {"kind": "weapon_upgrade_max", "weapon_id": weapon_id}
			var ur: Dictionary = _apply_random_weapon_upgrade(w)
			return _weapon_reward_result(String(w["id"]), ur)
	# 武器格滿了 → 改強化等級最低的一把（總是有點益處），不再悄悄落空
	if weapons.size() >= get_weapon_slot_max():
		var lowest: Dictionary = {}
		var lowest_level: int = 999999
		for w in weapons:
			var wid: String = String(w.get("id", ""))
			if not allow_unaccounted_upgrade and not GameState.is_weapon_unlocked(wid):
				continue
			var lv: int = int(w.get("level", 1))
			if lowest.is_empty() or lv < lowest_level:
				lowest = w
				lowest_level = lv
		if lowest.is_empty():
			return {"kind": "weapon_upgrade_max", "weapon_id": weapon_id}
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
	GameData.apply_armament_flat_stats_to_player(self, adef)
	var common_id: String = String(adef.get("common_upgrade_id", ""))
	if common_id != "":
		var cdef: Dictionary = GameData.get_common_upgrade_def(common_id)
		if not cdef.is_empty() and can_acquire_common_upgrade(common_id):
			var cinfo: Dictionary = apply_common_upgrade(common_id)
			cinfo["source_kind"] = "armament"
			cinfo["source_id"] = armament_id
			start_weapon_reward_log.append(cinfo)
	var wfrom: String = String(adef.get("weapon_id", ""))
	if wfrom != "":
		_add_start_weapon(wfrom, "armament", armament_id)


func get_weapon_slot_max() -> int:
	if is_instance_valid(GameState):
		return GameState.get_unlocked_weapon_slot_count()
	return WEAPON_SLOT_MAX


func get_common_upgrade_slot_max() -> int:
	if is_instance_valid(GameState):
		return GameState.get_unlocked_common_upgrade_slot_count()
	return GameData.COMMON_UPGRADE_SLOT_INITIAL


func get_common_upgrade_filled_count() -> int:
	return common_upgrade_log.size()


func can_acquire_common_upgrade(common_id: String) -> bool:
	var def: Dictionary = GameData.get_common_upgrade_def(common_id)
	if def.is_empty():
		return false
	var have: int = int(common_upgrade_log.get(common_id, 0))
	if have >= int(def.get("max", 0)):
		return false
	if have > 0:
		return true
	return get_common_upgrade_filled_count() < get_common_upgrade_slot_max()


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
				_heal(max_hp * get_level_hp_mult() * v)
			"speed_mult":
				speed_mult += v
			"rate_mult":
				rate_mult += v
				_refresh_weapon_stats()
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
				_refresh_weapon_stats()
			"crit_chance":
				crit_chance = min(0.95, crit_chance + v)
			"crit_damage_mult":
				crit_damage_mult += v
		return {"kind": "common_upgrade", "upgrade_id": id, "current": cur, "max": int(u["max"])}
	var u0: Dictionary = GameData.get_common_upgrade_def(id)
	return {"kind": "common_upgrade", "upgrade_id": id, "current": cur, "max": int(u0.get("max", 0))}


func _on_pickup_area_body_entered(_body: Node) -> void:
	pass


func _on_pickup_area_area_entered(area: Area2D) -> void:
	if area.is_in_group("xp_orbs") or area.is_in_group("gold_orbs"):
		area.attract_to(self)


class _MirrorMoonClone:
	extends Node2D

	var owner_player: Node = null
	var face_dir: Vector2 = Vector2.RIGHT
	var life_left: float = 3.0
	var slash_interval: float = 0.55
	var slash_timer: float = 0.0
	var slash_radius: float = 150.0
	var slash_damage: float = 18.0
	var slash_color: Color = Color(0.9, 0.9, 1.0)
	var slash_flash: float = 0.0

	func setup(
			p: Node,
			dir: Vector2,
			duration: float,
			interval: float,
			radius: float,
			damage: float,
			col: Color) -> void:
		owner_player = p
		face_dir = dir.normalized() if dir.length_squared() > 0.001 else Vector2.RIGHT
		life_left = duration
		slash_interval = max(0.1, interval)
		slash_timer = 0.05
		slash_radius = radius
		slash_damage = damage
		slash_color = col
		z_index = 50
		modulate.a = 0.68

	func _process(delta: float) -> void:
		if owner_player == null or not is_instance_valid(owner_player):
			queue_free()
			return
		life_left -= delta
		slash_timer -= delta
		slash_flash = max(0.0, slash_flash - delta)
		if slash_timer <= 0.0:
			slash_timer = slash_interval
			_slash()
		queue_redraw()
		if life_left <= 0.0:
			queue_free()

	func _slash() -> void:
		slash_flash = 0.16
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e):
				continue
			var ee := e as Node2D
			if ee == null:
				continue
			var er: float = float(e.get("radius")) if e.get("radius") != null else 28.0
			if global_position.distance_to(ee.global_position) <= slash_radius + er:
				if e.has_method("take_damage"):
					e.take_damage(slash_damage, owner_player)

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 18.0, Color(slash_color.r, slash_color.g, slash_color.b, 0.32))
		draw_line(Vector2.ZERO, face_dir * 34.0, Color(1.0, 1.0, 1.0, 0.7), 3.0)
		if slash_flash > 0.0:
			var a: float = clampf(slash_flash / 0.16, 0.0, 1.0)
			draw_arc(Vector2.ZERO, slash_radius, -PI * 0.1, PI * 1.1, 32,
				Color(0.8, 0.95, 1.0, 0.65 * a), 4.0)


class _FlameBurstVFX:
	extends Node2D

	var inner_r: float = 96.0
	var outer_r: float = 192.0
	var boosted: bool = false
	var life: float = 0.55
	var age: float = 0.0

	func _process(delta: float) -> void:
		age += delta
		queue_redraw()
		if age >= life:
			queue_free()

	func _draw() -> void:
		var t: float = clampf(age / life, 0.0, 1.0)
		# 外圈（燃燒範圍）：橘紅，快速消散
		var outer_a: float = (1.0 - t) * 0.55
		draw_circle(Vector2.ZERO, outer_r, Color(1.0, 0.35, 0.04, outer_a * 0.25))
		draw_arc(Vector2.ZERO, outer_r, 0.0, TAU, 64,
			Color(1.0, 0.5, 0.08, outer_a), 2.5, true)
		# 內圈（爆炸傷害核心）：先膨脹再消散
		var burst_t: float = clampf(age / (life * 0.45), 0.0, 1.0)
		var core_r: float = inner_r * (0.2 + 0.8 * burst_t)
		var core_a: float = (1.0 - burst_t) * 0.85
		draw_circle(Vector2.ZERO, core_r, Color(1.0, 0.7, 0.1, core_a * 0.55))
		draw_arc(Vector2.ZERO, core_r, 0.0, TAU, 48,
			Color(1.0, 0.9, 0.3, core_a), 3.5, true)
		# 強化時：中央白核閃光
		if boosted and burst_t < 0.5:
			var wh_a: float = (1.0 - burst_t * 2.0) * 0.9
			draw_circle(Vector2.ZERO, core_r * 0.45, Color(1.0, 1.0, 0.85, wh_a))
