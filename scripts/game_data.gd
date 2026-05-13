extends Node
## 全域資料表（武器、角色、能力升級）— 依據設計表 Excel
##
## 多語言：每張表都同時存在
##   "name" / "desc" / "rarity" / "max_effect" → zh_TW 預設值（沒翻譯時的後備）
##   "name_key" / "desc_key" / ...           → 翻譯系統的穩定 ID（如 WEAPON_SWORD_NAME）
## UI 端請呼叫底部的 tr_name(def) / tr_desc(def) / ...，不要直接讀 def["name"]，
## 這樣切換 locale 時才會自動跟著翻譯。
##
## WeaponDef:
##   id, name, kind, damage, rate, range, params(Dictionary), max_effect
## kind:
##   "melee_fan"     近戰扇形（前方扇形）
##   "projectile"    投射物（前方直線）
##   "orbit"         環繞玩家
##   "aura"          周圍光環/區域

const WEAPONS: Array[Dictionary] = [
	{
		"id": "sword",
		"name": "利劍", "name_key": "WEAPON_SWORD_NAME",
		"kind": "melee_fan",
		"damage": 27.0,
		"rate": 1.2,
		"range": 110.0,
		"params": {"angle_deg": 75.0, "color": Color(0.85, 0.85, 1.0)},
		"max_effect": "目標越少傷害提升", "max_effect_key": "WEAPON_SWORD_MAX",
	},
	{
		"id": "spear",
		"name": "長槍", "name_key": "WEAPON_SPEAR_NAME",
		"kind": "melee_fan",
		"damage": 34.0,
		"rate": 1.0,
		"range": 230.0,
		"params": {"angle_deg": 28.0, "color": Color(1.0, 0.95, 0.5)},
		"max_effect": "目標越多傷害提升", "max_effect_key": "WEAPON_SPEAR_MAX",
	},
	{
		"id": "axe",
		"name": "斧頭", "name_key": "WEAPON_AXE_NAME",
		"kind": "axe",
		"damage": 42.0,
		"rate": 0.75,
		"range": 86.0,
		"params": {
			"hit_radius": 54.0,
			"forward_offset": 70.0,
			"throw_speed": 520.0,
			"throw_distance": 360.0,
			"throw_hit_radius": 28.0,
			"throw_damage_mult": 0.75,
			"color": Color(1.0, 0.62, 0.28),
		},
		"max_effect": "攻擊後投出會返回的斧頭", "max_effect_key": "WEAPON_AXE_MAX",
	},
	{
		"id": "magic_bullet",
		"name": "魔彈", "name_key": "WEAPON_MAGIC_BULLET_NAME",
		"kind": "projectile",
		"damage": 18.0,
		"rate": 0.8,
		"range": 500.0,       # 20 米
		"params": {"speed": 520.0, "count": 1, "explode_radius": 50.0, "color": Color(0.9, 0.4, 1.0)},
		"max_effect": "爆炸範圍受到攻擊範圍影響", "max_effect_key": "WEAPON_MAGIC_BULLET_MAX",
	},
	{
		"id": "bow",
		"name": "弓箭", "name_key": "WEAPON_BOW_NAME",
		"kind": "projectile",
		"damage": 12.0,
		"rate": 1.5,
		"range": 380.0,       # 15 米
		"params": {"speed": 700.0, "count": 2, "spread_deg": 18.0, "pierce": 0, "color": Color(0.8, 1.0, 0.6)},
		"max_effect": "投射物附加貫穿", "max_effect_key": "WEAPON_BOW_MAX",
	},
	{
		"id": "melody",
		"name": "飛鏢", "name_key": "WEAPON_MELODY_NAME",
		"kind": "projectile",
		"damage": 10.0,
		"rate": 1.3,
		"range": 190.0,
		"params": {"speed": 280.0, "count": 3, "wave": true, "color": Color(0.6, 0.9, 1.0)},
		"max_effect": "擊中敵人附加易傷", "max_effect_key": "WEAPON_MELODY_MAX",
	},
	{
		"id": "claw",
		"name": "爪擊", "name_key": "WEAPON_CLAW_NAME",
		"kind": "melee_fan",
		"damage": 14.0,
		"rate": 1.8,
		"range": 110.0,
		"params": {"angle_deg": 180.0, "double_hit": true, "color": Color(1.0, 0.6, 0.4)},
		"max_effect": "擊中敵人附加流血", "max_effect_key": "WEAPON_CLAW_MAX",
	},
	{
		"id": "shard",
		"name": "碎刃", "name_key": "WEAPON_SHARD_NAME",
		"kind": "orbit",
		"damage": 6.0,
		"rate": 2.0,
		"range": 50.0,        # 半徑 2 米
		"params": {"count": 3, "spin_speed": 3.0, "color": Color(0.7, 0.95, 1.0)},
		"max_effect": "環繞速度增加", "max_effect_key": "WEAPON_SHARD_MAX",
	},
	{
		"id": "flame",
		"name": "火焰", "name_key": "WEAPON_FLAME_NAME",
		"kind": "aura",
		"damage": 10.0,
		"rate": 1.0,
		"range": 80.0,
		"params": {"color": Color(1.0, 0.55, 0.1), "burn": true},
		"max_effect": "燃燒傷害加倍", "max_effect_key": "WEAPON_FLAME_MAX",
	},
	{
		"id": "lightning",
		"name": "閃電", "name_key": "WEAPON_LIGHTNING_NAME",
		"kind": "projectile",
		"damage": 14.0,
		"rate": 1.2,
		"range": 190.0,
		"params": {"speed": 900.0, "count": 1, "chain": 1, "color": Color(0.6, 0.9, 1.0)},
		"max_effect": "反彈次數+2", "max_effect_key": "WEAPON_LIGHTNING_MAX",
	},
	{
		"id": "ice",
		"name": "寒冰", "name_key": "WEAPON_ICE_NAME",
		"kind": "projectile",
		"damage": 12.0,
		"rate": 1.1,
		"range": 380.0,
		"params": {"speed": 560.0, "count": 1, "slow": true, "color": Color(0.6, 0.95, 1.0)},
		"max_effect": "對緩速敵人增傷", "max_effect_key": "WEAPON_ICE_MAX",
	},
	{
		"id": "poison",
		"name": "毒素", "name_key": "WEAPON_POISON_NAME",
		"kind": "puddle",
		"damage": 14.0,
		"rate": 0.7,
		"range": 200.0,             # 投擲距離
		"params": {
			"color": Color(0.5, 1.0, 0.4),
			"puddle_radius": 80.0,  # 毒池半徑
			"lifetime": 3.5,        # 停留秒數
			"tick_interval": 0.5,   # 每次傷害間隔
			"count": 1,             # 一次丟幾灘（吃 w_count 升級）
		},
		"max_effect": "擊中敵人附加中毒", "max_effect_key": "WEAPON_POISON_MAX",
	},
	{
		"id": "holy",
		"name": "聖光", "name_key": "WEAPON_HOLY_NAME",
		"kind": "aura",
		"damage": 9.0,
		"rate": 1.0,
		"range": 75.0,
		"params": {"color": Color(1.0, 0.95, 0.6), "heal": 1.0},
		"max_effect": "回血效果支援隊友", "max_effect_key": "WEAPON_HOLY_MAX",
	},
]


const ARMAMENTS: Array[Dictionary] = [
	{
		"id": "none",
		"name": "無", "name_key": "CSEL_NONE",
		"desc": "不裝備武裝。", "desc_key": "ARMAMENT_NONE_DESC",
		"weapon_id": "",
		"atk_add": 0.0,
		"spd_add": 0.0,
	},
	{
		"id": "iron_sword",
		"name": "鐵劍", "name_key": "ARMAMENT_IRON_SWORD_NAME",
		"desc": "進場利劍等級 +1，ATK +3。", "desc_key": "ARMAMENT_IRON_SWORD_DESC",
		"weapon_id": "sword",
		"atk_add": 3.0,
		"spd_add": 0.0,
	},
	{
		"id": "hunter_bow",
		"name": "獵弓", "name_key": "ARMAMENT_HUNTER_BOW_NAME",
		"desc": "進場弓箭等級 +1，SPD +1。", "desc_key": "ARMAMENT_HUNTER_BOW_DESC",
		"weapon_id": "bow",
		"atk_add": 0.0,
		"spd_add": 1.0,
	},
]

# 角色定義 — 依 Excel
# 動畫格式：32x32 sprite sheet，列 0=待機/1=行走/2=跳躍(未用)/3=攻擊/4=受擊/5=死亡
# rarity 改為穩定 ID（"common"/"rare"/"epic"/"legend"），UI 端用 tr_rarity 翻譯
# 可選 body_radius：玩家本體圓形碰撞／地圖阻擋判定半徑（px），預設 42（與 Player.tscn 一致）
const CHARACTERS: Array[Dictionary] = [
	{
		"id": "swordsman",
		"name": "劍士", "name_key": "CHAR_SWORDSMAN_NAME",
		"rarity": "common",
		"weapon": "sword", "hp": 120.0, "atk": 12.0, "def": 10.0, "spd": 5.5,
		"desc": "均衡型：近戰素質標準，血量稍高以支撐近距離戰鬥。",
		"desc_key": "CHAR_SWORDSMAN_DESC",
		"color": Color(0.95, 0.85, 0.55),
		"sprite": "",
		"sprite_faces_left": true,
		"sprite_strips": {
			"idle": "res://assets/characters/SwordMan/IDLE/idle_left.png",
			"walk": "res://assets/characters/SwordMan/RUN/run_left.png",
			"attack": "res://assets/characters/SwordMan/ATTACK 1/attack1_left.png",
		},
		"strip_hframes": 8,
		"strip_frames": {"idle": 8, "walk": 8, "attack": 8, "hit": 8, "death": 8},
		"walk_anim_over_attack": true,
		"scale": 1,
		"body_radius": 24,
		"offset_y": -7,
		"skill_options": ["none", "whirl_slash"],
		"passive_options": ["none", "fighting_spirit"],
	},
	{
		"id": "ranger",
		"name": "遊俠", "name_key": "CHAR_RANGER_NAME",
		"rarity": "common",
		"weapon": "bow", "hp": 90.0, "atk": 14.0, "def": 7.0, "spd": 6.5,
		"desc": "遠程拉打：較高的移動速度補足血量弱點，適合遠距離狙擊。",
		"desc_key": "CHAR_RANGER_DESC",
		"color": Color(0.6, 1.0, 0.7),
		"sprite": "",
		"sprite_faces_left": false,
		## 條狀圖：每格約 160×144（Idle 6 / Walk 8 / Atk 7 / Hurt 4 / Death 8）
		"sprite_strips": {
			"idle": "res://assets/characters/ArcherMan/Idle.png",
			"walk": "res://assets/characters/ArcherMan/Walk.png",
			"attack": "res://assets/characters/ArcherMan/Atk.png",
			"hurt": "res://assets/characters/ArcherMan/Hurt.png",
			"death": "res://assets/characters/ArcherMan/Death.png",
		},
		"strip_hframes": 8,
		"strip_hframes_by_strip": {
			"idle": 6, "walk": 8, "attack": 7, "hurt": 4, "death": 8,
		},
		"strip_frames": {"idle": 6, "walk": 8, "attack": 7, "hit": 4, "death": 8},
		"walk_anim_over_attack": true,
		"scale": 0.8,
		"body_radius": 25,
		"offset_y": -7,
		"skill_options": ["none", "agile_tactics"],
		"passive_options": ["none", "quick_step"],
	},
	{
		"id": "knight",
		"name": "騎士", "name_key": "CHAR_KNIGHT_NAME",
		"rarity": "rare",
		"weapon": "spear", "hp": 150.0, "atk": 10.0, "def": 15.0, "spd": 4.5,
		"skill_options": ["none", "heavy_armor"],
		"passive_options": ["none", "unyielding"],
		"desc": "坦克型：極高的生存能力，雖然移速較慢，但能承受大量傷害。",
		"desc_key": "CHAR_KNIGHT_DESC",
		"color": Color(0.7, 0.85, 1.0),
		"sprite": "",
		"sprite_faces_left": false,
		"sprite_strips": {
			"idle": "res://assets/characters/SpearMan/IDLE.png",
			"walk": "res://assets/characters/SpearMan/WALK.png",
			"attack": "res://assets/characters/SpearMan/ATTACK.png",
			"hurt": "res://assets/characters/SpearMan/HURT.png",
			"death": "res://assets/characters/SpearMan/DEATH.png",
		},
		"strip_hframes": 4,
		"strip_hframes_by_strip": {
			"idle": 4, "walk": 6, "attack": 6, "hurt": 3, "death": 9,
		},
		"strip_frames": {"idle": 4, "walk": 6, "attack": 6, "hit": 3, "death": 9},
		"walk_anim_over_attack": true,
		"scale": .8,
		"body_radius": 24,
		"offset_y": -7,
	},
	{
		"id": "warrior",
		"name": "戰士", "name_key": "CHAR_WARRIOR_NAME",
		"rarity": "rare",
		"weapon": "axe", "hp": 108.0, "atk": 14.0, "def": 9.0, "spd": 5.2,
		"desc": "猛攻型：較劍士更偏重輸出，以近戰壓制換取略低的生存能力。",
		"desc_key": "CHAR_WARRIOR_DESC",
		"color": Color(0.88, 0.52, 0.42),
		"sprite": "",
		"sprite_faces_left": false,
		"sprite_strips": {
			"idle": "res://assets/characters/Warrior/IDLE.png",
			"walk": "res://assets/characters/Warrior/WALK.png",
			"attack": "res://assets/characters/Warrior/ATTACK 1.png",
			"hurt": "res://assets/characters/Warrior/HURT.png",
			"death": "res://assets/characters/Warrior/DEATH.png",
		},
		"strip_hframes": 12,
		"strip_hframes_by_strip": {
			"idle": 12, "walk": 12, "attack": 11, "hurt": 6, "death": 11,
		},
		"strip_frames": {"idle": 12, "walk": 12, "attack": 11, "hit": 6, "death": 11},
		"strip_fps": {"attack": 14.0},
		"walk_anim_over_attack": true,
		"scale": 0.82,
		"body_radius": 24,
		"offset_y": -7,
		"skill_options": ["none", "whirl_slash"],
		"passive_options": ["none", "unyielding"],
	},
	{
		"id": "wizard",
		"name": "巫師", "name_key": "CHAR_WIZARD_NAME",
		"rarity": "rare",
		"weapon": "magic_bullet", "hp": 80.0, "atk": 20.0, "def": 5.0, "spd": 5.0,
		"desc": "玻璃大砲：生存能力極低，但擁有最高攻擊力。",
		"desc_key": "CHAR_WIZARD_DESC",
		"color": Color(0.85, 0.55, 1.0),
		"sprite": "",
		"sprite_faces_left": true,
		"sprite_strips": {
			"idle": "res://assets/characters/Mage/IDLE.png",
			"walk": "res://assets/characters/Mage/WALK.png",
			"attack": "res://assets/characters/Mage/RANGED ATTACK.png",
			"hurt": "res://assets/characters/Mage/HURT.png",
			"death": "res://assets/characters/Mage/DEATH.png",
		},
		"strip_hframes": 6,
		"strip_hframes_by_strip": {
			"idle": 6, "walk": 4, "attack": 10, "hurt": 4, "death": 6,
		},
		"strip_frames": {"idle": 6, "walk": 4, "attack": 10, "hit": 4, "death": 6},
		"walk_anim_over_attack": true,
		"scale": 0.6,
		"offset_y": -7,
		"body_radius": 24,
		"skill_options": ["none", "energy_wave"],
		"passive_options": ["none", "arcane_mastery"],
	},
	{
		"id": "bard",
		"name": "武士", "name_key": "CHAR_BARD_NAME",
		"rarity": "epic",
		"weapon": "melody", "hp": 100.0, "atk": 10.0, "def": 8.0, "spd": 6.0,
		"desc": "輔助/功能：素質平庸但靈活度高，依賴武器易傷特效輔助。",
		"desc_key": "CHAR_BARD_DESC",
		"color": Color(1.0, 0.7, 0.85),
		"sprite": "",
		"sprite_faces_left": false,
		"sprite_strips": {
			"idle": "res://assets/characters/Samurai/IDLE.png",
			"walk": "res://assets/characters/Samurai/RUN.png",
			"attack": "res://assets/characters/Samurai/ATTACK.png",
			"hurt": "res://assets/characters/Samurai/HURT.png",
			"death": "res://assets/characters/Samurai/DEATH.png",
		},
		"strip_hframes": 8,
		"strip_hframes_by_strip": {
			"idle": 5, "walk": 8, "attack": 7, "hurt": 4, "death": 10,
		},
		"strip_frames": {"idle": 5, "walk": 8, "attack": 7, "hit": 4, "death": 10},
		"walk_anim_over_attack": true,
		"scale": 0.95,
		"body_radius": 24,
		"offset_y": -7,
	},
	{
		"id": "werewolf",
		"name": "狼人", "name_key": "CHAR_WEREWOLF_NAME",
		"rarity": "epic",
		"weapon": "claw", "hp": 110.0, "atk": 16.0, "def": 7.0, "spd": 7.0,
		"desc": "敏捷近戰：高攻擊、極高移速，透過快速切入與流血造成威脅。",
		"desc_key": "CHAR_WEREWOLF_DESC",
		"color": Color(0.85, 0.55, 0.45),
		"sprite": "",
		"sprite_faces_left": false,
		"sprite_strips": {
			"human_idle": "res://assets/characters/Werewolf/IDLE HUMAN.png",
			"transform": "res://assets/characters/Werewolf/TRANSFORMATION.png",
			"idle": "res://assets/characters/Werewolf/IDLE.png",
			"walk": "res://assets/characters/Werewolf/RUN.png",
			"attack": "res://assets/characters/Werewolf/ATTACK.png",
			"hurt": "res://assets/characters/Werewolf/HURT.png",
			"death": "res://assets/characters/Werewolf/DEATH.png",
		},
		"preview_strip": "human_idle",
		"start_transform": true,
		"strip_hframes": 6,
		"strip_hframes_by_strip": {
			"human_idle": 6, "transform": 8, "idle": 6, "walk": 6, "attack": 7, "hurt": 6, "death": 10,
		},
		"strip_frames": {
			"human_idle": 6, "transform": 8, "idle": 6, "walk": 6, "attack": 7, "hit": 6, "death": 10,
		},
		"walk_anim_over_attack": true,
		"scale": 0.72,
		"body_radius": 28,
		"offset_y": -10,
	},
	{
		"id": "vampire_lord",
		"name": "吸血鬼領主", "name_key": "CHAR_VAMPIRE_LORD_NAME",
		"rarity": "legend",
		"weapon": "claw", "hp": 118.0, "atk": 17.0, "def": 9.0, "spd": 6.2,
		"desc": "傳說血族：爪擊與高機動兼顧，擅長貼身纏鬥與持續壓制。",
		"desc_key": "CHAR_VAMPIRE_LORD_DESC",
		"color": Color(0.55, 0.22, 0.32),
		## NightLord：每動作一組獨立 PNG（無 hurt，會落到 idle）
		"sprite_frames": {
			"idle":   {"pattern": "res://assets/characters/NightLord/Idle/Idle{i}.png",        "count": 14},
			"walk":   {"pattern": "res://assets/characters/NightLord/Run/Running{i}.png",      "count": 10},
			"attack": {"pattern": "res://assets/characters/NightLord/Attacks/LightAtk{i}.png", "count": 25},
			"death":  {"pattern": "res://assets/characters/NightLord/Death/Death{i}.png",      "count": 43},
		},
		"anim_fps": 18.0,
		"sprite_faces_left": false,
		"walk_anim_over_attack": true,
		"scale": 0.7,
		"body_radius": 28,
		"offset_y": -10,
		"skill_options": ["none", "whirl_slash"],
		"passive_options": ["none", "fighting_spirit"],
	},
	{
		"id": "flame_witch",
		"name": "烈焰靈女巫", "name_key": "CHAR_FLAME_WITCH_NAME",
		"rarity": "legend",
		"weapon": "flame", "hp": 88.0, "atk": 19.0, "def": 6.0, "spd": 5.3,
		"desc": "傳說術者：駕馭火焰範圍傷害，爆發與控場兼備。",
		"desc_key": "CHAR_FLAME_WITCH_DESC",
		"color": Color(1.0, 0.45, 0.25),
		## SalamanderWitch：每動作一組獨立 PNG
		"sprite_frames": {
			"idle":   {"pattern": "res://assets/characters/SalamanderWitch/Idle/Idle{i}.png",         "count": 9},
			"walk":   {"pattern": "res://assets/characters/SalamanderWitch/Move/Move{i}.png",         "count": 13},
			"attack": {"pattern": "res://assets/characters/SalamanderWitch/Attacks/ComboAtk{i}.png",  "count": 28},
			"hurt":   {"pattern": "res://assets/characters/SalamanderWitch/Hurt/Hurt{i}.png",         "count": 5},
			"death":  {"pattern": "res://assets/characters/SalamanderWitch/Death/Die{i}.png",         "count": 30},
		},
		"anim_fps": 18.0,
		"sprite_faces_left": false,
		"walk_anim_over_attack": true,
		"scale": .8,
		"body_radius": 28,
		"offset_y": -8,
		"skill_options": ["none", "energy_wave"],
		"passive_options": ["none", "arcane_mastery"],
	},
]

# 武器升級 (對單一武器)
const WEAPON_UPGRADES: Array[Dictionary] = [
	{"id": "w_damage",  "name": "傷害增加",   "name_key": "WUP_W_DAMAGE_NAME",  "max": 3, "value": 0.20, "field": "damage_mult"},
	{"id": "w_range",   "name": "範圍增加",   "name_key": "WUP_W_RANGE_NAME",   "max": 2, "value": 0.15, "field": "range_mult"},
	{"id": "w_rate",    "name": "攻擊頻率",   "name_key": "WUP_W_RATE_NAME",    "max": 2, "value": 0.15, "field": "rate_mult"},
	{"id": "w_count",   "name": "投射物增加", "name_key": "WUP_W_COUNT_NAME",   "max": 2, "value": 1,    "field": "count_add"},
]

## 敵人異常狀態（流血 / 燃燒 / 中毒 DOT、易傷、緩速）— 集中於此方便調平衡
const ENEMY_STATUS_TICK_SEC := 0.25
const ENEMY_STATUS_MELODY_VULN_DURATION := 4.0
const ENEMY_STATUS_MELODY_VULN_STACK_CAP_BASE := 3
const ENEMY_STATUS_MELODY_VULN_STACK_CAP_MAXED := 5
const ENEMY_STATUS_MELODY_VULN_PER_STACK := 0.07
const ENEMY_STATUS_CLAW_BLEED_DURATION := 4.0
const ENEMY_STATUS_CLAW_BLEED_DPS_RATIO := 0.22
const ENEMY_STATUS_CLAW_BLEED_LIFESTEAL_RATIO := 0.08
const ENEMY_STATUS_FLAME_BURN_DURATION := 3.0
const ENEMY_STATUS_FLAME_BURN_DPS_RATIO := 0.35
const ENEMY_STATUS_ICE_SLOW_DURATION := 2.2
const ENEMY_STATUS_ICE_SLOW_FACTOR := 0.55
const ENEMY_STATUS_ICE_VS_SLOW_DAMAGE_MULT := 1.35
const ENEMY_STATUS_POISON_DURATION := 3.0
const ENEMY_STATUS_POISON_PUDDLE_DPS_RATIO := 0.32
const ENEMY_STATUS_POISON_ATK_REDUCE := 0.15

# 通用能力升級
const COMMON_UPGRADES: Array[Dictionary] = [
	{"id": "c_hp",       "name": "強健體魄", "name_key": "CUP_C_HP_NAME",       "desc": "血量上限 +20%", "desc_key": "CUP_C_HP_DESC",       "max": 5, "value": 0.20, "field": "hp_mult"},
	{"id": "c_speed",    "name": "疾風步",   "name_key": "CUP_C_SPEED_NAME",    "desc": "移動速度 +10%", "desc_key": "CUP_C_SPEED_DESC",    "max": 3, "value": 0.10, "field": "speed_mult"},
	{"id": "c_cooldown", "name": "急速冷卻", "name_key": "CUP_C_COOLDOWN_NAME", "desc": "全武器攻速 +10%","desc_key": "CUP_C_COOLDOWN_DESC", "max": 3, "value": 0.10, "field": "rate_mult"},
	{"id": "c_pickup",   "name": "吸取範圍", "name_key": "CUP_C_PICKUP_NAME",   "desc": "拾取範圍 +25%", "desc_key": "CUP_C_PICKUP_DESC",   "max": 5, "value": 0.25, "field": "pickup_mult"},
	{"id": "c_xp",       "name": "智慧之心", "name_key": "CUP_C_XP_NAME",       "desc": "經驗值 +15%",   "desc_key": "CUP_C_XP_DESC",       "max": 5, "value": 0.15, "field": "xp_mult"},
	{"id": "c_armor",    "name": "鋼鐵肌膚", "name_key": "CUP_C_ARMOR_NAME",    "desc": "受傷減少 10%",  "desc_key": "CUP_C_ARMOR_DESC",    "max": 3, "value": 0.10, "field": "dmg_reduce"},
	{"id": "c_regen",    "name": "回復術",   "name_key": "CUP_C_REGEN_NAME",    "desc": "每秒回復 +0.5", "desc_key": "CUP_C_REGEN_DESC",    "max": 3, "value": 0.5,  "field": "regen_add"},
	{"id": "c_atk",      "name": "力量強化", "name_key": "CUP_C_ATK_NAME",      "desc": "全武器傷害 +10%","desc_key": "CUP_C_ATK_DESC",      "max": 5, "value": 0.10, "field": "damage_mult"},
]


func get_weapon_upgrade_def(id: String) -> Dictionary:
	for u in WEAPON_UPGRADES:
		if u["id"] == id:
			return u
	return {}


func get_common_upgrade_def(id: String) -> Dictionary:
	for u in COMMON_UPGRADES:
		if u["id"] == id:
			return u
	return {}


## 四項武器升級（w_damage / w_range / w_rate / w_count）皆達上限
func is_weapon_upgrades_maxed(upgrades: Dictionary) -> bool:
	for u in WEAPON_UPGRADES:
		var have: int = int(upgrades.get(u["id"], 0))
		if have < int(u["max"]):
			return false
	return true


## 利劍滿級：周圍敵人數越少傷害越高（enemy_count 為 eff_range 內存活數）
func weapon_max_sword_damage_mult(enemy_count: int) -> float:
	var n: int = maxi(1, enemy_count)
	if n <= 1:
		return 1.34
	if n == 2:
		return 1.14
	return 1.0


## 長槍滿級：周圍敵人數越多傷害越高（有上限）
func weapon_max_spear_damage_mult(enemy_count: int) -> float:
	var n: int = maxi(1, enemy_count)
	return min(1.38, 1.0 + 0.072 * float(maxi(0, n - 2)))


## 已實裝「滿級額外效果」的武器 id（其餘武器全滿時不彈解鎖視窗，直到實裝為止）
const WEAPON_MAX_BONUS_IMPLEMENTED: Array[String] = [
	"sword", "spear", "axe", "magic_bullet", "bow", "melody", "claw", "shard", "flame",
	"lightning", "ice", "poison", "holy",
]


func weapon_max_bonus_is_implemented(weapon_id: String) -> bool:
	return weapon_id in WEAPON_MAX_BONUS_IMPLEMENTED


func get_weapon_def(id: String) -> Dictionary:
	for w in WEAPONS:
		if w["id"] == id:
			return w
	return {}


func get_armament_def(id: String) -> Dictionary:
	for a in ARMAMENTS:
		if a["id"] == id:
			return a
	return {}


func get_character_def(id: String) -> Dictionary:
	for c in CHARACTERS:
		if c["id"] == id:
			return c
	return {}


# ====================================================
# 被動與技能 — 目前只有占位「無」，留好框架供日後擴充
# ====================================================
# 被動：戰鬥時生效的常駐效果（如：每秒回血、對 Boss 增傷…）
# 之後丟 res://assets/icons/passives/<id>.png 進去就會自動顯示，無圖則自動 fallback
const PASSIVES: Array[Dictionary] = [
	{"id": "none",
		"name": "無", "name_key": "PASSIVE_NONE_NAME",
		"desc": "尚未選擇被動。", "desc_key": "PASSIVE_NONE_DESC",
		"params": {}, "icon": ""},
	{
		"id": "fighting_spirit",
		"name": "鬥志高昂", "name_key": "PASSIVE_FIGHTING_SPIRIT_NAME",
		"desc": "每擊殺 5 名敵人，為自身技能量表填充一小段；觸發後 5 秒內不會再次因本被動充能。",
		"desc_key": "PASSIVE_FIGHTING_SPIRIT_DESC",
		"icon": "res://assets/icons/passives/fighting_spirit.png",
		"params": {
			"kills_per_fill": 5,
			"meter_fill": 22.0,
			"passive_fill_cd": 5.0,
		},
	},
	{
		"id": "unyielding",
		"name": "堅忍不屈", "name_key": "PASSIVE_UNYIELDING_NAME",
		"desc": "受到傷害時（含格擋擋下的攻擊）為自身技能量表填充一段；觸發後 5 秒內不會再次因本被動充能。",
		"desc_key": "PASSIVE_UNYIELDING_DESC",
		"icon": "res://assets/icons/passives/unyielding.png",
		"params": {
			"meter_fill": 40.0,
			"passive_fill_cd": 5.0,
		},
	},
	{
		"id": "arcane_mastery",
		"name": "奧術精通", "name_key": "PASSIVE_ARCANE_MASTERY_NAME",
		"desc": "技能命中敵人或彈針時，為自身技能量表填充一段；觸發後 5 秒內不會再次因本被動充能。",
		"desc_key": "PASSIVE_ARCANE_MASTERY_DESC",
		"icon": "res://assets/icons/passives/arcane_mastery.png",
		"params": {
			"meter_fill": 30.0,
			"passive_fill_cd": 5.0,
		},
	},
	{
		"id": "quick_step",
		"name": "快射節奏", "name_key": "PASSIVE_QUICK_STEP_NAME",
		"desc": "每累積 8 次武器命中為自身技能量表填充一段；觸發後 5 秒內不會再次因本被動充能。",
		"desc_key": "PASSIVE_QUICK_STEP_DESC",
		"icon": "res://assets/icons/passives/quick_step.png",
		"params": {
			"hits_per_fill": 8,
			"meter_fill": 25.0,
			"passive_fill_cd": 5.0,
		},
	},
]

# 技能：玩家按技能鍵（Q／RShift／手把 X）發動，可在戰鬥與彈珠台中使用
const SKILLS: Array[Dictionary] = [
	{"id": "none",
		"name": "無", "name_key": "SKILL_NONE_NAME",
		"desc": "尚未選擇技能。", "desc_key": "SKILL_NONE_DESC",
		"cooldown": 0.0, "icon": ""},
	{
		"id": "whirl_slash",
		"name": "迴旋斬", "name_key": "SKILL_WHIRL_SLASH_NAME",
		"desc": "戰鬥：對自身周圍 15 米範圍造成大威力傷害。\n彈珠台：摧毀 1 格獎勵（變成 3 選 1）。",
		"desc_key": "SKILL_WHIRL_SLASH_DESC",
		"cooldown": 12.0,
		"icon": "res://assets/icons/skills/whirl_slash.png",
		"params": {
			"combat_radius": 360.0,        # 約 15 個 tile（1 tile ≈ 1 米）
			"combat_damage_mult": 6.0,     # 玩家 ATK × damage_mult × 6
			"combat_min_damage": 80.0,     # 即使 ATK 很低也能達到的最小傷害
		},
	},
	{
		"id": "heavy_armor",
		"name": "重裝防禦", "name_key": "SKILL_HEAVY_ARMOR_NAME",
		"desc": "戰鬥：賦予自身 2 次格擋（無視該次傷害）。\n彈珠台：彈珠變重（重力上升），碰 2 次會破壞彈針。",
		"desc_key": "SKILL_HEAVY_ARMOR_DESC",
		"cooldown": 15.0,
		"icon": "res://assets/icons/skills/heavy_armor.png",
		"params": {
			"combat_block_count": 2,
			"pinball_gravity_mult": 1.45,
			"pinball_peg_hits_to_break": 2,
		},
	},
	{
		"id": "agile_tactics",
		"name": "靈敏戰技", "name_key": "SKILL_AGILE_TACTICS_NAME",
		"desc": "戰鬥：朝前方發射 3 道擴散箭，每持有一支箭矢額外多 1 道；釋放後清空箭矢。\n彈珠台：使自身彈珠變輕盈；每撞 3 次彈針，獲得 1 支箭矢（最多 5）。",
		"desc_key": "SKILL_AGILE_TACTICS_DESC",
		"cooldown": 10.0,
		"icon": "res://assets/icons/skills/agile_tactics.png",
		"params": {
			"combat_base_arrows": 3,
			"combat_spread_deg": 14.0,
			"combat_speed": 720.0,
			"combat_range": 520.0,
			"combat_damage_mult": 1.6,
			"combat_min_damage": 18.0,
			"arrow_max": 5,
			"arrows_per_3_pegs": 1,
			"pinball_gravity_mult": 0.65,
			"pinball_peg_bounce_mult": 1.05,
			"pinball_hits_per_arrow": 3,
		},
	},
	{
		"id": "energy_wave",
		"name": "能量波動", "name_key": "SKILL_ENERGY_WAVE_NAME",
		"desc": "戰鬥：朝前方發射寬 5 米、長 30 米的直線光束砲擊。\n彈珠台：額外發射一顆能量炮彈珠（非自身彈珠），同一彈針被其碰撞 3 次會破壞；落進獎勵區時 50% 雙倍獎勵、50% 摧毀該格獎勵。",
		"desc_key": "SKILL_ENERGY_WAVE_DESC",
		"cooldown": 14.0,
		"icon": "res://assets/icons/skills/energy_wave.png",
		"params": {
			"combat_length": 720.0,
			"combat_half_width": 60.0,
			"combat_start_offset": 72.0,
			"combat_damage_mult": 5.5,
			"combat_min_damage": 60.0,
			"pinball_peg_hits_break": 3,
		},
	},
]


func get_passive_def(id: String) -> Dictionary:
	for p in PASSIVES:
		if p["id"] == id:
			return p
	return PASSIVES[0]


func get_skill_def(id: String) -> Dictionary:
	for s in SKILLS:
		if s["id"] == id:
			return s
	return SKILLS[0]


# 安全載入技能 / 被動圖示：路徑空 / 檔案不存在 → 直接回 null，不會在 console 噴錯
func load_skill_icon(skill_id: String) -> Texture2D:
	var s: Dictionary = get_skill_def(skill_id)
	return _load_icon_safe(String(s.get("icon", "")))


func load_passive_icon(passive_id: String) -> Texture2D:
	var p: Dictionary = get_passive_def(passive_id)
	return _load_icon_safe(String(p.get("icon", "")))


func _load_icon_safe(path: String) -> Texture2D:
	if path == "":
		return null
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	return load(path) as Texture2D


# 取得角色可用的被動／技能 ID 清單；未指定時預設只有「無」，由各角色顯式列出可選項
func character_passive_options(cid: String) -> Array:
	var c: Dictionary = get_character_def(cid)
	return c.get("passive_options", ["none"])


func character_skill_options(cid: String) -> Array:
	var c: Dictionary = get_character_def(cid)
	return c.get("skill_options", ["none"])


# ====================================================
# 多語言 helpers — UI 端統一透過這些函式取「顯示用文字」
# ====================================================
# 共通邏輯：
#   1) 若 def 有 <field>_key 就走 TranslationServer，未命中時退回 <field>。
#   2) 對 desc 等多行欄位處理 CSV 內的字面 "\n" → 真正換行。
func tr_field(def: Dictionary, field: String, multiline: bool = false) -> String:
	var key: String = String(def.get(field + "_key", ""))
	var fallback: String = String(def.get(field, ""))
	var out: String = fallback
	if key != "":
		var translated: String = tr(key)
		if translated != key and translated != "":
			out = translated
	if multiline:
		out = out.replace("\\n", "\n")
	return out


func tr_name(def: Dictionary) -> String:
	if def == null or def.is_empty():
		return ""
	return tr_field(def, "name", false)


func tr_desc(def: Dictionary) -> String:
	if def == null or def.is_empty():
		return ""
	return tr_field(def, "desc", true)


func tr_max_effect(def: Dictionary) -> String:
	return tr_field(def, "max_effect", false)


# rarity 欄位現在存 ID（"common"/"rare"/"epic"/"legend"），翻成顯示文字
const RARITY_KEYS: Dictionary = {
	"common": "RARITY_COMMON",
	"rare":   "RARITY_RARE",
	"epic":   "RARITY_EPIC",
	"legend": "RARITY_LEGEND",
}


func tr_rarity(rarity_id: String) -> String:
	if RARITY_KEYS.has(rarity_id):
		var key: String = String(RARITY_KEYS[rarity_id])
		var t: String = tr(key)
		if t != key and t != "":
			return t
	return rarity_id


# 給 ID 直接拿名稱（讓 caller 不用先呼叫 get_*_def）
func tr_weapon_name(id: String) -> String:
	return tr_name(get_weapon_def(id))


func tr_armament_name(id: String) -> String:
	return tr_name(get_armament_def(id))


func tr_character_name(id: String) -> String:
	return tr_name(get_character_def(id))


func tr_skill_name(id: String) -> String:
	return tr_name(get_skill_def(id))


func tr_passive_name(id: String) -> String:
	return tr_name(get_passive_def(id))


func tr_slime_name(id: String) -> String:
	return tr_name(get_slime_def(id))


func tr_stage_name(id: String) -> String:
	return tr_name(get_stage_def(id))


# ====================================================
# 史萊姆敵人資料
# ====================================================
# 顏色由弱到強：Green → Blue → Light Blue → Dark → Orange → Red
# 變體：普通 / 刺刺 (Spiked, 菁英) / 大型 (Boss)
const SLIMES: Array[Dictionary] = [
	# 一般史萊姆 (32x32 sprite, 5x4 sheet) — 各列實際幀數: [3,5,2,5]
	{"id":"slime_green",     "tex":"res://assets/enemy/Slime/Green/MiniSlime.png",
		"tier":0, "elite":false, "boss":false, "hframes":5, "vframes":4,
		"frames_per_row":[3,5,2,5],
		"scale":1.5, "radius":24.0, "offset_y":-11,
		"hp_mult":1.0, "dmg_mult":1.0, "speed_mult":1.0, "xp_mult":1.0},
	{"id":"slime_blue",      "tex":"res://assets/enemy/Slime/Blue/MiniSlimeB.png",
		"tier":1, "elite":false, "boss":false, "hframes":5, "vframes":4,
		"frames_per_row":[3,5,2,5],
		"scale":1.5, "radius":24.0, "offset_y":-11,
		"hp_mult":1.25, "dmg_mult":1.05, "speed_mult":1.0, "xp_mult":1.1},
	{"id":"slime_lightblue", "tex":"res://assets/enemy/Slime/Light Blue/MiniSlimeLB.png",
		"tier":2, "elite":false, "boss":false, "hframes":5, "vframes":4,
		"frames_per_row":[3,5,2,5],
		"scale":1.5, "radius":24.0, "offset_y":-11,
		"hp_mult":1.5, "dmg_mult":1.1, "speed_mult":1.05, "xp_mult":1.25},
	{"id":"slime_dark",      "tex":"res://assets/enemy/Slime/Dark/MiniSlimeD.png",
		"tier":3, "elite":false, "boss":false, "hframes":5, "vframes":4,
		"frames_per_row":[3,5,2,5],
		"scale":1.5, "radius":24.0, "offset_y":-11,
		"hp_mult":1.8, "dmg_mult":1.2, "speed_mult":1.1, "xp_mult":1.5},

	# 刺刺史萊姆 (32x32 sprite, 5x5 sheet) — 各列實際幀數: [3,5,5,2,5]
	{"id":"spike_green",     "tex":"res://assets/enemy/Slime/Green/MiniSpikedSlime.png",
		"tier":1, "elite":true, "boss":false, "hframes":5, "vframes":5,
		"frames_per_row":[3,5,5,2,5],
		"scale":1.5, "radius":27.0, "offset_y":-11,
		"hp_mult":1.7, "dmg_mult":1.4, "speed_mult":1.0, "xp_mult":1.6},
	{"id":"spike_blue",      "tex":"res://assets/enemy/Slime/Blue/MiniSpikedSlimeB.png",
		"tier":2, "elite":true, "boss":false, "hframes":5, "vframes":5,
		"frames_per_row":[3,5,5,2,5],
		"scale":1.5, "radius":27.0, "offset_y":-11,
		"hp_mult":2.0, "dmg_mult":1.5, "speed_mult":1.0, "xp_mult":1.8},
	{"id":"spike_lightblue", "tex":"res://assets/enemy/Slime/Light Blue/MiniSpikedSlimeLB.png",
		"tier":3, "elite":true, "boss":false, "hframes":5, "vframes":5,
		"frames_per_row":[3,5,5,2,5],
		"scale":1.5, "radius":27.0, "offset_y":-11,
		"hp_mult":2.4, "dmg_mult":1.7, "speed_mult":1.05, "xp_mult":2.0},
	{"id":"spike_dark",      "tex":"res://assets/enemy/Slime/Dark/MiniSpikedSlimeD.png",
		"tier":4, "elite":true, "boss":false, "hframes":5, "vframes":5,
		"frames_per_row":[3,5,5,2,5],
		"scale":1.5, "radius":27.0, "offset_y":-11,
		"hp_mult":2.8, "dmg_mult":1.9, "speed_mult":1.1, "xp_mult":2.5},
	{"id":"spike_orange",    "tex":"res://assets/enemy/Slime/Orange/MiniSpikedSlimeO.png",
		"tier":5, "elite":true, "boss":false, "hframes":5, "vframes":5,
		"frames_per_row":[3,5,5,2,5],
		"scale":1.5, "radius":27.0, "offset_y":-11,
		"hp_mult":3.2, "dmg_mult":2.1, "speed_mult":1.1, "xp_mult":3.0},
	{"id":"spike_red",       "tex":"res://assets/enemy/Slime/Red/MiniSpikedSlimeR.png",
		"tier":6, "elite":true, "boss":false, "hframes":5, "vframes":5,
		"frames_per_row":[3,5,5,2,5],
		"scale":1.5, "radius":27.0, "offset_y":-11,
		"hp_mult":3.6, "dmg_mult":2.4, "speed_mult":1.15, "xp_mult":3.5},

	# 大型史萊姆 (40x40 sprite, 10x7 sheet) — Boss
	# 列順序：idle / walk / jump(未用) / attack / skill(未用) / hurt / death
	{"id":"boss_orange", "tex":"res://assets/enemy/Slime/Orange/MiniSlimeMonsterO.png",
		"tier":4, "elite":true, "boss":true, "hframes":10, "vframes":7,
		"frames_per_row":[4,6,8,10,7,2,7],
		"scale":2.25, "radius":54.0, "offset_y":-9,
		"hp_mult":5.0, "dmg_mult":2.8, "speed_mult":0.8, "xp_mult":6.0},
	{"id":"boss_red",    "tex":"res://assets/enemy/Slime/Red/MiniSlimeMonsterR.png",
		"tier":5, "elite":true, "boss":true, "hframes":10, "vframes":7,
		"frames_per_row":[4,6,8,10,7,2,7],
		"scale":2.25, "radius":54.0, "offset_y":-9,
		"hp_mult":7.0, "dmg_mult":3.5, "speed_mult":0.8, "xp_mult":9.0},

	# 關卡 Boss — 史萊姆王（取自橙色大型史萊姆紋理，更大、更慢、極厚血）
	{"id":"slime_king",
		"name":"史萊姆王", "name_key": "SLIME_KING_NAME",
		"tex":"res://assets/enemy/Slime/Orange/MiniSlimeMonsterO.png",
		"tier":99, "elite":true, "boss":true, "stage_boss":true,
		"hframes":10, "vframes":7,
		"frames_per_row":[4,6,8,10,7,2,7],
		"scale":3.25, "radius":80.0, "offset_y":-12,
		"hp_mult":22.0, "dmg_mult":3.2, "speed_mult":0.55, "xp_mult":18.0},
]


# 關卡定義 — 由 GameState.current_stage_id 指向其中一筆
const STAGES: Array[Dictionary] = [
	{
		"id": "slime_forest",
		"name": "第一關 — 史萊姆平原",
		"name_key": "STAGE_SLIME_FOREST_NAME",
		"map_path": "res://assets/Maps/TEST.tmx",
		"boss_id": "slime_king",
		"boss_time": 600.0,        # 10 分鐘
		"boss_warning_time": 30.0, # Boss 出現前 30 秒提示
		"victory_gold": 250,
		"rescue_blacksmith": true,
	},
]


func get_slime_def(id: String) -> Dictionary:
	for s in SLIMES:
		if s["id"] == id:
			return s
	return {}


func get_stage_def(id: String) -> Dictionary:
	for s in STAGES:
		if s["id"] == id:
			return s
	return STAGES[0]


# 依難度挑選史萊姆（菁英較稀有，Boss 更稀有）
func pick_slime(difficulty: float) -> Dictionary:
	var tier: int = clamp(int(floor(difficulty)), 0, 6)
	var candidates: Array = []
	for s in SLIMES:
		var t: int = int(s["tier"])
		# 只取「等於或低 1 階」的 tier，營造漸進感
		if t > tier or t < tier - 1:
			continue
		if s.get("boss", false) and tier < 4:
			continue
		candidates.append(s)
	if candidates.is_empty():
		return SLIMES[0]
	# 加權：普通 6, 菁英 2, Boss 1
	var pool: Array = []
	for s in candidates:
		var w: int = 6
		if s.get("elite", false):
			w = 2
		if s.get("boss", false):
			w = 1
		for i in w:
			pool.append(s)
	return pool.pick_random()
