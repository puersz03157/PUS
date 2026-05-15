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
##   id, name, kind, damage, rate, range, crit_chance, crit_damage_mult, params, max_effect
## Armament flat stats (favorites / equipped): hp_add, def_add, atk_add, spd_add,
##   rate_add (攻速→rate_mult), crit_rate_add, crit_dmg_add (加在爆傷倍率上)
## kind:
##   "melee_fan"     近戰扇形（前方扇形）
##   "projectile"    投射物（前方直線）
##   "orbit"         環繞玩家
##   "aura"          周圍光環/區域

const CRIT_DAMAGE_MULT_BASE := 2.0

const WEAPONS: Array[Dictionary] = [
	{
		"id": "sword",
		"name": "利劍", "name_key": "WEAPON_SWORD_NAME",
		"kind": "melee_fan",
		"damage": 27.0,
		"rate": 1.2,
		"crit_chance": 0.05,
		"crit_damage_mult": 2.0,
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
		"crit_chance": 0.06,
		"crit_damage_mult": 2.2,
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
		"crit_chance": 0.04,
		"crit_damage_mult": 2.6,
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
		"craft_gold": 90,
		"craft_materials": {"wood": 5, "stone": 4},
	},
	{
		"id": "magic_bullet",
		"name": "魔彈", "name_key": "WEAPON_MAGIC_BULLET_NAME",
		"kind": "projectile",
		"damage": 18.0,
		"rate": 0.8,
		"crit_chance": 0.07,
		"crit_damage_mult": 1.9,
		"range": 500.0,       # 20 米
		"params": {"speed": 520.0, "count": 1, "explode_radius": 50.0, "color": Color(0.9, 0.4, 1.0)},
		"max_effect": "爆炸範圍受到攻擊範圍影響", "max_effect_key": "WEAPON_MAGIC_BULLET_MAX",
		"craft_gold": 120,
		"craft_materials": {"copper": 4, "stone": 3},
	},
	{
		"id": "bow",
		"name": "弓箭", "name_key": "WEAPON_BOW_NAME",
		"kind": "projectile",
		"damage": 12.0,
		"rate": 1.5,
		"crit_chance": 0.08,
		"crit_damage_mult": 1.75,
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
		"crit_chance": 0.09,
		"crit_damage_mult": 1.7,
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
		"crit_chance": 0.10,
		"crit_damage_mult": 1.65,
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
		"crit_chance": 0.06,
		"crit_damage_mult": 1.8,
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
		"crit_chance": 0.05,
		"crit_damage_mult": 2.0,
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
		"crit_chance": 0.07,
		"crit_damage_mult": 2.1,
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
		"crit_chance": 0.06,
		"crit_damage_mult": 2.0,
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
		"crit_chance": 0.03,
		"crit_damage_mult": 2.3,
		"range": 200.0,             # 投擲距離
		"params": {
			"color": Color(0.5, 1.0, 0.4),
			"puddle_radius": 80.0,  # 毒池半徑
			"lifetime": 3.5,        # 停留秒數
			"tick_interval": 0.5,   # 每次傷害間隔
			"count": 1,             # 一次丟幾灘（吃 w_count 升級）
		},
		"max_effect": "中毒敵人降低攻擊力", "max_effect_key": "WEAPON_POISON_MAX",
	},
	{
		"id": "holy",
		"name": "聖光", "name_key": "WEAPON_HOLY_NAME",
		"kind": "aura",
		"damage": 9.0,
		"rate": 1.0,
		"crit_chance": 0.02,
		"crit_damage_mult": 1.6,
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
		"hp_add": 0.0, "def_add": 0.0,
		"atk_add": 0.0, "spd_add": 0.0,
		"rate_add": 0.0, "crit_rate_add": 0.0, "crit_dmg_add": 0.0,
	},
	{
		"id": "iron_sword",
		"name": "鐵劍", "name_key": "ARMAMENT_IRON_SWORD_NAME",
		"desc": "進場利劍 +1。均衡近戰：攻擊、血量與爆率。", "desc_key": "ARMAMENT_IRON_SWORD_DESC",
		"weapon_id": "sword",
		"hp_add": 6.0, "def_add": 2.0,
		"atk_add": 3.0, "spd_add": 0.0,
		"rate_add": 0.0, "crit_rate_add": 0.02, "crit_dmg_add": 0.0,
		"craft_gold": 120,
		"craft_materials": {"iron": 5, "stone": 3},
	},
	{
		"id": "hunter_bow",
		"name": "獵弓", "name_key": "ARMAMENT_HUNTER_BOW_NAME",
		"desc": "進場弓箭 +1。機動射手：移速、攻速與爆率。", "desc_key": "ARMAMENT_HUNTER_BOW_DESC",
		"weapon_id": "bow",
		"hp_add": 0.0, "def_add": 0.0,
		"atk_add": 1.0, "spd_add": 1.0,
		"rate_add": 0.03, "crit_rate_add": 0.04, "crit_dmg_add": 0.0,
		"craft_gold": 100,
		"craft_materials": {"wood": 8, "stone": 4},
	},
	{
		"id": "copper_axe",
		"name": "銅斧", "name_key": "ARMAMENT_COPPER_AXE_NAME",
		"desc": "進場斧頭 +1。重擊型：攻擊、防禦與爆傷。", "desc_key": "ARMAMENT_COPPER_AXE_DESC",
		"weapon_id": "axe",
		"hp_add": 4.0, "def_add": 3.0,
		"atk_add": 2.0, "spd_add": 0.0,
		"rate_add": 0.0, "crit_rate_add": 0.0, "crit_dmg_add": 0.15,
		"requires_craft_book": true,
		"craft_gold": 140,
		"craft_materials": {"copper": 6, "iron": 4},
	},
	{
		"id": "bone_staff",
		"name": "骨魔杖", "name_key": "ARMAMENT_BONE_STAFF_NAME",
		"desc": "進場魔彈 +1。術者型：攻擊、攻速與小量爆率。", "desc_key": "ARMAMENT_BONE_STAFF_DESC",
		"weapon_id": "magic_bullet",
		"hp_add": 0.0, "def_add": 0.0,
		"atk_add": 2.0, "spd_add": 0.0,
		"rate_add": 0.05, "crit_rate_add": 0.02, "crit_dmg_add": 0.05,
		"requires_craft_book": true,
		"craft_gold": 150,
		"craft_materials": {"bone": 5, "copper": 3},
	},
	{
		"id": "stone_spear",
		"name": "石矛", "name_key": "ARMAMENT_STONE_SPEAR_NAME",
		"desc": "進場長槍 +1。長柄型：攻擊、生存與爆傷。", "desc_key": "ARMAMENT_STONE_SPEAR_DESC",
		"weapon_id": "spear",
		"hp_add": 8.0, "def_add": 4.0,
		"atk_add": 2.0, "spd_add": 0.0,
		"rate_add": 0.0, "crit_rate_add": 0.0, "crit_dmg_add": 0.08,
		"requires_craft_book": true,
		"craft_gold": 110,
		"craft_materials": {"stone": 7, "wood": 5},
	},
	{
		"id": "cloth_armor",
		"name": "布甲", "name_key": "ARMAMENT_CLOTH_ARMOR_NAME",
		"desc": "進場「鋼鐵肌膚」+1。防禦型：血量、防禦與少量移速。", "desc_key": "ARMAMENT_CLOTH_ARMOR_DESC",
		"weapon_id": "",
		"common_upgrade_id": "c_armor",
		"hp_add": 14.0,
		"def_add": 8.0,
		"atk_add": 0.0, "spd_add": 0.5,
		"rate_add": 0.0, "crit_rate_add": 0.0, "crit_dmg_add": 0.0,
		"requires_craft_book": true,
		"craft_gold": 130,
		"craft_materials": {"rag": 6, "bone": 4},
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
		"skill_options": ["none", "heavenly_judgment"],
		"passive_options": ["none", "breakthrough"],
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
		"skill_options": ["none", "mirror_moon"],
		"passive_options": ["none", "sword_aura_resonance"],
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
		"skill_options": ["none", "wild_impulse"],
		"passive_options": ["none", "bloodlust"],
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
			var d: Dictionary = w.duplicate(true)
			if not d.has("crit_chance"):
				d["crit_chance"] = 0.05
			if not d.has("crit_damage_mult"):
				d["crit_damage_mult"] = CRIT_DAMAGE_MULT_BASE
			return d
	return {}


func get_armament_def(id: String) -> Dictionary:
	for a in ARMAMENTS:
		if a["id"] == id:
			return a
	return {}


const P1_HOUSE_FAVORITE_ARMAMENT_SLOTS := 5
## 喜愛武裝格可累加之基礎屬性（不含進場武器／共通升級）
const ARMAMENT_FAVORITE_STAT_FIELDS: Array[String] = [
	"hp_add", "def_add", "atk_add", "spd_add",
	"rate_add", "crit_rate_add", "crit_dmg_add",
]


## 房屋可選造型（預設、狼人人形、已解鎖角色的外觀借用）
func character_house_skin_options(char_id: String, unlocked_character_ids: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({"id": "default", "label": tr("HOUSE_SKIN_DEFAULT")})
	if char_id == "werewolf":
		out.append({"id": "human", "label": tr("HOUSE_SKIN_WEREWOLF_HUMAN")})
	for raw in unlocked_character_ids:
		var uid: String = String(raw)
		if uid == "" or uid == char_id:
			continue
		if get_character_def(uid).is_empty():
			continue
		out.append({
			"id": "look_%s" % uid,
			"label": tr("HOUSE_SKIN_LOOK_FMT") % tr_character_name(uid),
		})
	return out


func resolve_character_visual_def(char_id: String, skin_id: String) -> Dictionary:
	var base: Dictionary = get_character_def(char_id)
	if base.is_empty():
		return {}
	if skin_id == "" or skin_id == "default":
		return base
	if skin_id == "human" and char_id == "werewolf":
		var d: Dictionary = base.duplicate(true)
		d["start_transform"] = false
		if d.get("sprite_strips") is Dictionary:
			var strips: Dictionary = (d["sprite_strips"] as Dictionary).duplicate()
			if strips.has("human_idle"):
				strips["idle"] = strips["human_idle"]
			d["sprite_strips"] = strips
		return d
	if skin_id.begins_with("look_"):
		var look_id: String = skin_id.substr(5)
		var look_def: Dictionary = get_character_def(look_id)
		if not look_def.is_empty():
			return look_def
	return base


## 喜愛武裝格：加總各武裝基礎屬性（不含進場武器或共通升級）
func sum_armament_flat_stats(armament_ids: Array) -> Dictionary:
	var totals: Dictionary = {}
	for field in ARMAMENT_FAVORITE_STAT_FIELDS:
		totals[field] = 0.0
	for raw in armament_ids:
		var aid: String = String(raw)
		if aid == "" or aid == "none":
			continue
		var adef: Dictionary = get_armament_def(aid)
		if adef.is_empty():
			continue
		for field in ARMAMENT_FAVORITE_STAT_FIELDS:
			totals[field] = float(totals.get(field, 0.0)) + float(adef.get(field, 0.0))
	return totals


func _format_favorite_stat_value(value: float, decimals: int = 0) -> String:
	if decimals <= 0:
		return str(int(round(value)))
	return ("%0." + str(decimals) + "f") % value


func armament_stat_line(label_key: String, value: float, decimals: int = 0) -> String:
	return "%s +%s" % [tr(label_key), _format_favorite_stat_value(value, decimals)]


func _append_armament_flat_stat_parts(parts: Array[String], stats: Dictionary) -> void:
	var hp_add: float = float(stats.get("hp_add", 0.0))
	var def_add: float = float(stats.get("def_add", 0.0))
	var atk_add: float = float(stats.get("atk_add", 0.0))
	var spd_add: float = float(stats.get("spd_add", 0.0))
	var rate_add: float = float(stats.get("rate_add", 0.0))
	var crit_rate_add: float = float(stats.get("crit_rate_add", 0.0))
	var crit_dmg_add: float = float(stats.get("crit_dmg_add", 0.0))
	if hp_add > 0.0:
		parts.append(armament_stat_line("ARMAMENT_FAV_STAT_HP", hp_add, 0))
	if def_add > 0.0:
		parts.append(armament_stat_line("ARMAMENT_FAV_STAT_DEF", def_add, 0))
	if atk_add > 0.0:
		parts.append(armament_stat_line("ARMAMENT_FAV_STAT_ATK", atk_add, 1))
	if spd_add > 0.0:
		parts.append(armament_stat_line("ARMAMENT_FAV_STAT_SPD", spd_add, 1))
	if rate_add > 0.0:
		parts.append("%s +%d%%" % [tr("ARMAMENT_FAV_STAT_RATE"), int(round(rate_add * 100.0))])
	if crit_rate_add > 0.0:
		parts.append("%s +%d%%" % [tr("ARMAMENT_FAV_STAT_CRIT_RATE"), int(round(crit_rate_add * 100.0))])
	if crit_dmg_add > 0.0:
		parts.append("%s +%d%%" % [tr("ARMAMENT_FAV_STAT_CRIT_DMG"), int(round(crit_dmg_add * 100.0))])


func armament_flat_stat_parts_from_def(adef: Dictionary) -> Array[String]:
	var parts: Array[String] = []
	if adef.is_empty():
		return parts
	_append_armament_flat_stat_parts(parts, adef)
	return parts


func format_armament_flat_stats_from_def(adef: Dictionary) -> String:
	var parts: Array[String] = armament_flat_stat_parts_from_def(adef)
	if parts.is_empty():
		return ""
	return " / ".join(parts)


func format_armament_favorite_bonus_text(stats: Dictionary) -> String:
	var parts: Array[String] = []
	_append_armament_flat_stat_parts(parts, stats)
	if parts.is_empty():
		return tr("ARMAMENT_FAV_STAT_NONE")
	return " / ".join(parts)


func tr_armament_desc_with_flat_stats(armament_id: String) -> String:
	var adef: Dictionary = get_armament_def(armament_id)
	if adef.is_empty():
		return ""
	var text: String = tr_desc(adef)
	var flat: String = format_armament_flat_stats_from_def(adef)
	if flat != "":
		text += "\n" + tr("ARMAMENT_FLAT_STATS_PREFIX") + flat
	return text


func apply_armament_flat_stats_to_player(p: Node, stats: Dictionary) -> void:
	if p == null:
		return
	var hp_add: float = float(stats.get("hp_add", 0.0))
	var def_add: float = float(stats.get("def_add", 0.0))
	var atk_add: float = float(stats.get("atk_add", 0.0))
	var spd_add: float = float(stats.get("spd_add", 0.0))
	var rate_add: float = float(stats.get("rate_add", 0.0))
	var crit_rate_add: float = float(stats.get("crit_rate_add", 0.0))
	var crit_dmg_add: float = float(stats.get("crit_dmg_add", 0.0))
	if hp_add > 0.0 and p.get("max_hp") != null:
		p.max_hp += hp_add
		if p.get("hp") != null:
			p.hp += hp_add
	if def_add > 0.0 and p.get("def_value") != null:
		p.def_value += def_add
	if atk_add > 0.0 and p.get("atk") != null:
		p.atk += atk_add
	if spd_add > 0.0 and p.get("move_speed") != null:
		p.move_speed += spd_add * 36.0
	if rate_add > 0.0 and p.get("rate_mult") != null:
		p.rate_mult += rate_add
	if crit_rate_add > 0.0 and p.get("crit_chance") != null:
		p.crit_chance += crit_rate_add
	if crit_dmg_add > 0.0 and p.get("crit_damage_mult") != null:
		p.crit_damage_mult += crit_dmg_add


func apply_armament_favorite_stats_to_player(p: Node, stats: Dictionary) -> void:
	apply_armament_flat_stats_to_player(p, stats)


func weapon_crit_effect_parts(wdef: Dictionary) -> Array[String]:
	var parts: Array[String] = []
	if wdef.is_empty():
		return parts
	var cc: float = float(wdef.get("crit_chance", 0.0))
	var cd: float = float(wdef.get("crit_damage_mult", CRIT_DAMAGE_MULT_BASE))
	if cc > 0.0:
		parts.append("%s %d%%" % [tr("ARMAMENT_FAV_STAT_CRIT_RATE"), int(round(cc * 100.0))])
	if cc > 0.0 or cd > CRIT_DAMAGE_MULT_BASE + 0.001:
		parts.append("%s %.0f%%" % [tr("ARMAMENT_FAV_STAT_CRIT_DMG"), cd * 100.0])
	return parts


func format_weapon_crit_text(wdef: Dictionary) -> String:
	var parts: Array[String] = weapon_crit_effect_parts(wdef)
	if parts.is_empty():
		return ""
	return " / ".join(parts)


func armament_requires_craft_book(id: String) -> bool:
	return bool(get_armament_def(id).get("requires_craft_book", false))


func blacksmith_armament_ids() -> Array[String]:
	var out: Array[String] = []
	for a in ARMAMENTS:
		var aid: String = String(a.get("id", ""))
		if aid == "none" or not a.has("craft_gold"):
			continue
		out.append(aid)
	return out


func stage_event_armament_book_ids(stage_id: String) -> Array[String]:
	var stage: Dictionary = get_stage_def(stage_id)
	var raw: Variant = stage.get("event_armament_books", [])
	var out: Array[String] = []
	if not (raw is Array):
		return out
	for item in raw:
		var aid: String = String(item)
		if aid != "" and get_armament_def(aid).has("craft_gold"):
			out.append(aid)
	return out


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
	{
		"id": "breakthrough",
		"name": "突破重圍", "name_key": "PASSIVE_BREAKTHROUGH_NAME",
		"desc": "自身一次攻擊命中 3 名以上敵人，或 5 秒內攻擊同一敵人 3 次時，為自身技能量表填充一段；觸發後 5 秒內不會再次因本被動充能。",
		"desc_key": "PASSIVE_BREAKTHROUGH_DESC",
		"icon": "res://assets/icons/passives/breakthrough.png",
		"params": {
			"multi_hit_count": 3,
			"same_enemy_hits": 3,
			"same_enemy_window": 5.0,
			"meter_fill": 35.0,
			"passive_fill_cd": 5.0,
		},
	},
	{
		"id": "sword_aura_resonance",
		"name": "劍氣共鳴", "name_key": "PASSIVE_SWORD_AURA_RESONANCE_NAME",
		"desc": "自身給予敵人異常狀態時，為自身技能量表填充一段；觸發後 5 秒內不會再次因本被動充能。",
		"desc_key": "PASSIVE_SWORD_AURA_RESONANCE_DESC",
		"icon": "res://assets/icons/passives/sword_aura_resonance.png",
		"params": {
			"meter_fill": 32.0,
			"passive_fill_cd": 5.0,
		},
	},
	{
		"id": "bloodlust",
		"name": "嗜血慾望", "name_key": "PASSIVE_BLOODLUST_NAME",
		"desc": "武器命中處於流血狀態的敵人時，為自身技能量表填充一段；觸發後 5 秒內不會再次因本被動充能。",
		"desc_key": "PASSIVE_BLOODLUST_DESC",
		"icon": "res://assets/icons/passives/bloodlust.png",
		"params": {
			"meter_fill": 30.0,
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
	{
		"id": "heavenly_judgment",
		"name": "天降重罰", "name_key": "SKILL_HEAVENLY_JUDGMENT_NAME",
		"desc": "戰鬥：跳躍至空中最多 3 秒，可選擇周圍一定距離地點落下，造成範圍傷害並暈眩；未選擇時原地落下。\n彈珠台：賦予自身超重破壞，發射後垂直落下破壞路徑上所有彈針，並使落入的獎勵在本場戰鬥不再出現；本回合不獲得獎勵（單場最多 3 次）。",
		"desc_key": "SKILL_HEAVENLY_JUDGMENT_DESC",
		"cooldown": 16.0,
		"icon": "res://assets/icons/skills/heavenly_judgment.png",
		"params": {
			"combat_select_time": 3.0,
			"combat_target_range": 420.0,
			"combat_radius": 150.0,
			"combat_damage_mult": 5.2,
			"combat_min_damage": 70.0,
			"combat_stun": 1.4,
			"combat_cursor_speed": 320.0,
			"pinball_gravity_mult": 3.0,
			"pinball_destroy_limit": 3,
		},
	},
	{
		"id": "mirror_moon",
		"name": "鏡花水月", "name_key": "SKILL_MIRROR_MOON_NAME",
		"desc": "戰鬥：向前方衝刺瞬斬造成傷害，並在原地製造一個能攻擊的分身，持續 3 秒。\n彈珠台：將目前未摧毀的獎勵區間重抽，優先抽換目前獎勵區沒有的獎勵，並保留倍率。",
		"desc_key": "SKILL_MIRROR_MOON_DESC",
		"cooldown": 13.0,
		"icon": "res://assets/icons/skills/mirror_moon.png",
		"params": {
			"combat_dash_distance": 320.0,
			"combat_dash_width": 74.0,
			"combat_damage_mult": 2.8,
			"combat_min_damage": 36.0,
			"clone_duration": 3.0,
			"clone_interval": 0.55,
			"clone_radius": 150.0,
			"clone_damage_mult": 1.15,
			"clone_min_damage": 18.0,
		},
	},
	{
		"id": "wild_impulse",
		"name": "野性衝動", "name_key": "SKILL_WILD_IMPULSE_NAME",
		"desc": "戰鬥：向前方衝刺抓擊造成傷害並將路徑上的敵人向前推開；施放後 5 秒內可再免費施放 2 次。\n彈珠台：以準星選定彈針並摧毀該處與鄰近彈針；此技能造成的彈針分數最多 20 點。",
		"desc_key": "SKILL_WILD_IMPULSE_DESC",
		"cooldown": 14.0,
		"icon": "res://assets/icons/skills/wild_impulse.png",
		"params": {
			"combat_dash_distance": 300.0,
			"combat_dash_width": 80.0,
			"combat_damage_mult": 2.4,
			"combat_min_damage": 32.0,
			"combat_push_distance": 56.0,
			"pinball_blast_radius": 72.0,
			"pinball_score_cap": 20,
			"pinball_cursor_speed": 340.0,
			"pinball_confirm_delay_ms": 280,
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


func tr_material_name(id: String) -> String:
	return tr_name(get_material_def(id))


func tr_character_name(id: String) -> String:
	return tr_name(get_character_def(id))


func tr_skill_name(id: String) -> String:
	return tr_name(get_skill_def(id))


func tr_passive_name(id: String) -> String:
	return tr_name(get_passive_def(id))


func tr_enemy_name(id: String) -> String:
	return tr_name(get_enemy_def(id))


func tr_slime_name(id: String) -> String:
	return tr_enemy_name(id)


func tr_stage_name(id: String) -> String:
	return tr_name(get_stage_def(id))


# ====================================================
# 鍛造素材資料
# ====================================================
const MATERIALS: Array[Dictionary] = [
	{"id": "wood", "name": "木頭", "name_key": "MAT_WOOD_NAME"},
	{"id": "stone", "name": "石頭", "name_key": "MAT_STONE_NAME"},
	{"id": "iron", "name": "鐵", "name_key": "MAT_IRON_NAME"},
	{"id": "copper", "name": "銅", "name_key": "MAT_COPPER_NAME"},
	{"id": "bone", "name": "骨頭", "name_key": "MAT_BONE_NAME"},
	{"id": "rag", "name": "破布", "name_key": "MAT_RAG_NAME"},
]


func get_material_def(id: String) -> Dictionary:
	for m in MATERIALS:
		if m["id"] == id:
			return m
	return {}


## 關卡／敵人掉落表擲一次（多筆同時過機率，再從中過關者隨機擇一）
func roll_material_drop_table(drops: Array) -> Dictionary:
	if drops.is_empty():
		return {}
	var candidates: Array[Dictionary] = []
	for drop in drops:
		if not (drop is Dictionary):
			continue
		if randf() <= float(drop.get("chance", 0.0)):
			candidates.append(drop)
	if candidates.is_empty():
		return {}
	var picked: Dictionary = candidates.pick_random()
	var min_amount: int = maxi(1, int(picked.get("min", 1)))
	var max_amount: int = maxi(min_amount, int(picked.get("max", min_amount)))
	return {
		"id": String(picked.get("id", "")),
		"amount": randi_range(min_amount, max_amount),
	}


## 圖鑑詳情用：列出該敵 material_drops 的機率與數量區間
func codex_monster_drop_lines(def: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var drops_raw: Variant = def.get("material_drops", [])
	if not (drops_raw is Array) or drops_raw.is_empty():
		return out
	for drop in drops_raw:
		if not (drop is Dictionary):
			continue
		var mid: String = String(drop.get("id", ""))
		if mid == "":
			continue
		var pch: int = int(round(clampf(float(drop.get("chance", 0.0)), 0.0, 1.0) * 100.0))
		var mn: int = maxi(1, int(drop.get("min", 1)))
		var mx: int = maxi(mn, int(drop.get("max", mn)))
		out.append(tr("CODEX_MONSTER_DROP_LINE_FMT") % [tr_material_name(mid), pch, mn, mx])
	return out


# ====================================================
# 敵人戰鬥數值（與 Enemy.setup_with_slime 共用）
# ====================================================
const ENEMY_STAT_BASE_HP := 6.0
const ENEMY_STAT_HP_PER_LEVEL := 4.0
const ENEMY_STAT_BASE_SPEED := 70.0
const ENEMY_STAT_SPEED_PER_LEVEL := 6.0
const ENEMY_STAT_BASE_DAMAGE := 5.0
const ENEMY_STAT_DAMAGE_PER_LEVEL := 1.5
const ENEMY_STAT_BASE_XP := 1.0
const ENEMY_STAT_XP_PER_LEVEL := 0.15


## 圖鑑顯示用難度係數（實戰會隨關卡時間再提高）
func enemy_codex_reference_level(def: Dictionary) -> float:
	if def.has("codex_ref_level"):
		return maxf(0.0, float(def["codex_ref_level"]))
	if def.get("stage_boss", false):
		return 12.0
	if def.get("boss", false):
		return 10.0
	return 1.0 + float(def.get("tier", 0)) * 2.0


func compute_enemy_combat_stats(def: Dictionary, level_factor: float) -> Dictionary:
	var lf: float = maxf(0.0, level_factor)
	var base_hp: float = float(def["base_hp"]) if def.has("base_hp") \
		else ENEMY_STAT_BASE_HP + lf * ENEMY_STAT_HP_PER_LEVEL
	var base_speed: float = float(def["base_speed"]) if def.has("base_speed") \
		else ENEMY_STAT_BASE_SPEED + lf * ENEMY_STAT_SPEED_PER_LEVEL
	var base_dmg: float = float(def["base_damage"]) if def.has("base_damage") \
		else ENEMY_STAT_BASE_DAMAGE + lf * ENEMY_STAT_DAMAGE_PER_LEVEL
	var base_xp: float = float(def["base_xp"]) if def.has("base_xp") \
		else ENEMY_STAT_BASE_XP + lf * ENEMY_STAT_XP_PER_LEVEL
	return {
		"max_hp": base_hp * float(def.get("hp_mult", 1.0)),
		"damage": base_dmg * float(def.get("dmg_mult", 1.0)),
		"move_speed": base_speed * float(def.get("speed_mult", 1.0)),
		"xp_value": base_xp * float(def.get("xp_mult", 1.0)),
		"defense": float(def.get("defense", 0.0)),
		"level_factor": lf,
	}


func format_enemy_codex_stats_block(def: Dictionary) -> String:
	var lf: float = enemy_codex_reference_level(def)
	var st: Dictionary = compute_enemy_combat_stats(def, lf)
	var lines: Array[String] = []
	lines.append(tr("CODEX_MONSTER_STAT_REF_FMT") % _format_favorite_stat_value(lf, 1))
	lines.append("%s %d　%s %d　%s %d　%s %s" % [
		tr("CODEX_MONSTER_STAT_HP"), int(round(float(st["max_hp"]))),
		tr("CODEX_MONSTER_STAT_DMG"), int(round(float(st["damage"]))),
		tr("CODEX_MONSTER_STAT_SPD"), int(round(float(st["move_speed"]))),
		tr("CODEX_MONSTER_STAT_XP"), _format_favorite_stat_value(float(st["xp_value"]), 1),
	])
	lines.append(tr("CODEX_MONSTER_STAT_SCALE_NOTE"))
	return "\n".join(lines)


# ====================================================
# 敵人池（分關卡：史萊姆 / 獸人 / 不死）
# ====================================================
# 第一關池：5 種小怪 + 關底 Boss（圖檔與 Orcs/Undead 相同規則：`assets/enemy/Slimes/<id>.png`）
const ENEMY_POOL_SLIME: Array[Dictionary] = [
	# 一般史萊姆 (32x32 sprite, 5x4 sheet) — 各列實際幀數: [3,5,2,5]
	{"id":"slime_green",     "name_key": "ENEMY_SLIME_GREEN_NAME",
		"tex":"res://assets/enemy/Slimes/slime_green.png",
		"tier":0, "elite":false, "boss":false, "hframes":5, "vframes":4,
		"frames_per_row":[3,5,2,5],
		"scale":1.5, "radius":24.0, "offset_y":-11,
		"hp_mult":1.0, "dmg_mult":1.0, "speed_mult":1.0, "xp_mult":1.0, "defense": 0.0,
		"material_drops": [
			{"id": "wood", "chance": 0.14, "min": 1, "max": 1},
		]},
	{"id":"slime_blue",      "name_key": "ENEMY_SLIME_BLUE_NAME",
		"tex":"res://assets/enemy/Slimes/slime_blue.png",
		"tier":1, "elite":false, "boss":false, "hframes":5, "vframes":4,
		"frames_per_row":[3,5,2,5],
		"scale":1.5, "radius":24.0, "offset_y":-11,
		"hp_mult":1.25, "dmg_mult":1.05, "speed_mult":1.0, "xp_mult":1.1, "defense": 0.0,
		"material_drops": [
			{"id": "wood", "chance": 0.10, "min": 1, "max": 1},
			{"id": "stone", "chance": 0.08, "min": 1, "max": 1},
		]},
	{"id":"slime_lightblue", "name_key": "ENEMY_SLIME_LIGHTBLUE_NAME",
		"tex":"res://assets/enemy/Slimes/slime_lightblue.png",
		"tier":2, "elite":false, "boss":false, "hframes":5, "vframes":4,
		"frames_per_row":[3,5,2,5],
		"scale":1.5, "radius":24.0, "offset_y":-11,
		"hp_mult":1.5, "dmg_mult":1.1, "speed_mult":1.05, "xp_mult":1.25, "defense": 0.0,
		"material_drops": [
			{"id": "stone", "chance": 0.14, "min": 1, "max": 1},
		]},
	{"id":"slime_dark",      "name_key": "ENEMY_SLIME_DARK_NAME",
		"tex":"res://assets/enemy/Slimes/slime_dark.png",
		"tier":3, "elite":false, "boss":false, "hframes":5, "vframes":4,
		"frames_per_row":[3,5,2,5],
		"scale":1.5, "radius":24.0, "offset_y":-11,
		"hp_mult":1.8, "dmg_mult":1.2, "speed_mult":1.1, "xp_mult":1.5, "defense": 0.02,
		"material_drops": [
			{"id": "stone", "chance": 0.13, "min": 1, "max": 2},
			{"id": "wood", "chance": 0.06, "min": 1, "max": 1},
		]},

	# 刺刺（菁英感）— 第五種小怪
	{"id":"spike_green",     "name_key": "ENEMY_SLIME_SPIKE_GREEN_NAME",
		"tex":"res://assets/enemy/Slimes/spike_green.png",
		"tier":1, "elite":true, "boss":false, "hframes":5, "vframes":5,
		"frames_per_row":[3,5,5,2,5],
		"scale":1.5, "radius":27.0, "offset_y":-11,
		"hp_mult":1.7, "dmg_mult":1.4, "speed_mult":1.0, "xp_mult":1.6, "defense": 0.04,
		"material_drops": [
			{"id": "wood", "chance": 0.10, "min": 1, "max": 2},
			{"id": "stone", "chance": 0.12, "min": 1, "max": 2},
		]},

	# 關卡 Boss — 史萊姆王（隨機池不含 stage_boss）
	{"id":"slime_king",
		"name":"史萊姆王", "name_key": "SLIME_KING_NAME",
		"tex":"res://assets/enemy/Slimes/slime_king.png",
		"tier":99, "elite":true, "boss":true, "stage_boss":true,
		"hframes":10, "vframes":7,
		"frames_per_row":[4,6,8,10,7,2,7],
		"scale":3.25, "radius":80.0, "offset_y":-12,
		"hp_mult":22.0, "dmg_mult":3.2, "speed_mult":0.55, "xp_mult":18.0,
		"defense": 0.08,
		"material_drops": [
			{"id": "wood", "chance": 0.20, "min": 2, "max": 4},
			{"id": "stone", "chance": 0.20, "min": 2, "max": 4},
			{"id": "iron", "chance": 0.10, "min": 1, "max": 2},
		]},
]

# 第二關池：獸人（32px 格線圖集；圖鑑裁 IDLE1 = 左上第一格）
const ENEMY_POOL_ORC: Array[Dictionary] = [
	{"id": "orc_scout", "name_key": "ENEMY_ORC_SCOUT_NAME",
		"tex": "res://assets/enemy/Orcs/orc_scout.png",
		"tier": 0, "elite": false, "boss": false, "hframes": 6, "vframes": 6,
		"frames_per_row": [4, 6, 3, 4, 2, 4], "scale": 1.55, "radius": 24.0, "offset_y": -11,
		"hp_mult": 0.95, "dmg_mult": 0.95, "speed_mult": 1.18, "xp_mult": 1.05, "defense": 0.0,
		"material_drops": [
			{"id": "copper", "chance": 0.14, "min": 1, "max": 1},
		]},
	{"id": "orc_warrior", "name_key": "ENEMY_ORC_WARRIOR_NAME",
		"tex": "res://assets/enemy/Orcs/orc_warrior.png",
		"tier": 1, "elite": false, "boss": false, "hframes": 6, "vframes": 6,
		"frames_per_row": [4, 6, 3, 4, 2, 4], "scale": 1.58, "radius": 26.0, "offset_y": -11,
		"hp_mult": 1.2, "dmg_mult": 1.12, "speed_mult": 1.0, "xp_mult": 1.12, "defense": 0.03,
		"material_drops": [
			{"id": "iron", "chance": 0.13, "min": 1, "max": 1},
		]},
	{"id": "orc_warrior_f", "name_key": "ENEMY_ORC_WARRIOR_F_NAME",
		"tex": "res://assets/enemy/Orcs/orc_warrior_f.png",
		"tier": 2, "elite": true, "boss": false, "hframes": 6, "vframes": 7,
		"frames_per_row": [4, 6, 3, 4, 2, 4, 6], "scale": 1.52, "radius": 27.0, "offset_y": -11,
		"hp_mult": 1.35, "dmg_mult": 1.22, "speed_mult": 1.08, "xp_mult": 1.22, "defense": 0.04,
		"material_drops": [
			{"id": "iron", "chance": 0.10, "min": 1, "max": 2},
			{"id": "copper", "chance": 0.10, "min": 1, "max": 2},
		]},
	{"id": "orc_rogue", "name_key": "ENEMY_ORC_ROGUE_NAME",
		"tex": "res://assets/enemy/Orcs/orc_rogue.png",
		"tier": 2, "elite": false, "boss": false, "hframes": 6, "vframes": 7,
		"frames_per_row": [4, 6, 3, 4, 2, 4, 6], "scale": 1.48, "radius": 22.0, "offset_y": -11,
		"hp_mult": 0.9, "dmg_mult": 1.25, "speed_mult": 1.2, "xp_mult": 1.1, "defense": 0.0,
		"material_drops": [
			{"id": "copper", "chance": 0.16, "min": 1, "max": 2},
		]},
	{"id": "orc_guard", "name_key": "ENEMY_ORC_GUARD_NAME",
		"tex": "res://assets/enemy/Orcs/orc_guard.png",
		"tier": 3, "elite": true, "boss": false, "hframes": 6, "vframes": 7,
		"frames_per_row": [4, 6, 3, 4, 2, 4, 6], "scale": 1.62, "radius": 30.0, "offset_y": -11,
		"hp_mult": 1.85, "dmg_mult": 1.15, "speed_mult": 0.88, "xp_mult": 1.35, "defense": 0.1,
		"material_drops": [
			{"id": "iron", "chance": 0.15, "min": 1, "max": 2},
			{"id": "copper", "chance": 0.09, "min": 1, "max": 2},
		]},
	{"id": "boss_orc_dual_axe", "name_key": "ENEMY_BOSS_ORC_DUAL_AXE_NAME",
		"tex": "res://assets/enemy/Orcs/boss_orc_dual_axe.png",
		"tier": 99, "elite": true, "boss": true, "stage_boss": true,
		"hframes": 6, "vframes": 9, "frames_per_row": [4, 6, 3, 4, 2, 4, 6, 6, 6],
		"scale": 3.15, "radius": 82.0, "offset_y": -12,
		"hp_mult": 26.0, "dmg_mult": 3.85, "speed_mult": 0.58, "xp_mult": 22.0, "defense": 0.12,
		"material_drops": [
			{"id": "iron", "chance": 0.22, "min": 2, "max": 4},
			{"id": "copper", "chance": 0.20, "min": 2, "max": 4},
		]},
]

# 第三關池：不死生物（32px 格線；遠程：骷髏弓手、Boss 骷髏法師）
const ENEMY_POOL_UNDEAD: Array[Dictionary] = [
	{"id": "undead_sk_sword", "name_key": "ENEMY_UNDEAD_SK_SWORD_NAME",
		"tex": "res://assets/enemy/Undead/undead_sk_sword.png",
		"tier": 0, "elite": false, "boss": false, "hframes": 6, "vframes": 6,
		"frames_per_row": [4, 6, 3, 4, 2, 4], "scale": 1.5, "radius": 24.0, "offset_y": -11,
		"hp_mult": 1.0, "dmg_mult": 1.05, "speed_mult": 1.02, "xp_mult": 1.05, "defense": 0.02,
		"material_drops": [
			{"id": "bone", "chance": 0.14, "min": 1, "max": 1},
		]},
	{"id": "undead_zombie", "name_key": "ENEMY_UNDEAD_ZOMBIE_NAME",
		"tex": "res://assets/enemy/Undead/undead_zombie.png",
		"tier": 1, "elite": false, "boss": false, "hframes": 9, "vframes": 9,
		"frames_per_row": [], "scale": 1.62, "radius": 28.0, "offset_y": -10,
		"hp_mult": 1.55, "dmg_mult": 1.08, "speed_mult": 0.72, "xp_mult": 1.15, "defense": 0.06,
		"anim_row_idle": 1, "anim_row_walk": 2, "codex_portrait_row": 1,
		"material_drops": [
			{"id": "rag", "chance": 0.16, "min": 1, "max": 2},
			{"id": "bone", "chance": 0.07, "min": 1, "max": 1},
		]},
	{"id": "undead_sk_archer", "name_key": "ENEMY_UNDEAD_SK_ARCHER_NAME",
		"tex": "res://assets/enemy/Undead/undead_sk_archer.png",
		"tier": 2, "elite": false, "boss": false, "hframes": 10, "vframes": 7,
		"frames_per_row": [], "scale": 1.52, "radius": 24.0, "offset_y": -11,
		"hp_mult": 1.05, "dmg_mult": 0.95, "speed_mult": 0.95, "xp_mult": 1.12, "defense": 0.0,
		"ranged": {"range": 300.0, "min_range": 90.0, "width": 46.0, "windup": 0.95, "cooldown": 4.8, "damage_mult": 0.78},
		"material_drops": [
			{"id": "bone", "chance": 0.12, "min": 1, "max": 2},
			{"id": "rag", "chance": 0.06, "min": 1, "max": 1},
		]},
	{"id": "undead_warrior", "name_key": "ENEMY_UNDEAD_WARRIOR_NAME",
		"tex": "res://assets/enemy/Undead/undead_warrior.png",
		"tier": 3, "elite": false, "boss": false, "hframes": 8, "vframes": 7,
		"frames_per_row": [], "scale": 1.58, "radius": 28.0, "offset_y": -11,
		"hp_mult": 1.75, "dmg_mult": 1.28, "speed_mult": 0.92, "xp_mult": 1.4, "defense": 0.08,
		"material_drops": [
			{"id": "bone", "chance": 0.10, "min": 1, "max": 2},
			{"id": "rag", "chance": 0.12, "min": 1, "max": 2},
		]},
	{"id": "undead_wraith", "name_key": "ENEMY_UNDEAD_WRAITH_NAME",
		"tex": "res://assets/enemy/Undead/undead_wraith.png",
		"tier": 4, "elite": true, "boss": false, "hframes": 8, "vframes": 5,
		"frames_per_row": [], "scale": 1.42, "radius": 20.0, "offset_y": -12,
		"hp_mult": 0.85, "dmg_mult": 1.35, "speed_mult": 1.25, "xp_mult": 1.5, "defense": 0.0,
		"material_drops": [
			{"id": "rag", "chance": 0.14, "min": 1, "max": 2},
			{"id": "bone", "chance": 0.09, "min": 1, "max": 2},
		]},
	{"id": "boss_sk_mage", "name_key": "ENEMY_BOSS_SK_MAGE_NAME",
		"tex": "res://assets/enemy/Undead/boss_sk_mage.png",
		"tier": 99, "elite": true, "boss": true, "stage_boss": true,
		"hframes": 8, "vframes": 7, "frames_per_row": [],
		"scale": 3.25, "radius": 84.0, "offset_y": -12,
		"hp_mult": 32.0, "dmg_mult": 4.5, "speed_mult": 0.64, "xp_mult": 26.0, "defense": 0.1,
		"ranged": {"range": 520.0, "min_range": 110.0, "width": 88.0, "windup": 1.15, "cooldown": 3.9, "damage_mult": 1.15},
		"material_drops": [
			{"id": "bone", "chance": 0.24, "min": 2, "max": 5},
			{"id": "rag", "chance": 0.22, "min": 2, "max": 5},
		]},
]


# 關卡定義 — 由 GameState.current_stage_id 指向其中一筆
const STAGES: Array[Dictionary] = [
	{
		"id": "slime_forest",
		"name": "第一關 — 史萊姆平原",
		"name_key": "STAGE_SLIME_FOREST_NAME",
		"map_path": "res://assets/Maps/TEST.tmx",
		"boss_id": "slime_king",
		"boss_time": 300.0,        # 5 分鐘
		"boss_warning_time": 30.0, # Boss 出現前 30 秒提示
		"difficulty_base": 0.0,
		"difficulty_seconds_per_tier": 44.0,
		"difficulty_scale": 1.0,
		"boss_level_factor": 12.0,
		"enemy_pool": "slime",
		"material_drops": [
			{"id": "wood", "chance": 0.12, "min": 1, "max": 2},
			{"id": "stone", "chance": 0.10, "min": 1, "max": 2},
		],
		"victory_gold": 250,
		"rescue_blacksmith": true,
		"event_armament_books": ["stone_spear"],
	},
	{
		"id": "crimson_marsh",
		"name": "第二關 — 赤紅沼澤",
		"name_key": "STAGE_CRIMSON_MARSH_NAME",
		"map_path": "res://assets/Maps/TEST.tmx",
		"boss_id": "boss_orc_dual_axe",
		"boss_time": 300.0,        # 5 分鐘
		"boss_warning_time": 30.0,
		"difficulty_base": 1.35,
		"difficulty_seconds_per_tier": 40.0,
		"difficulty_scale": 1.1,
		"spawn_batch_mult": 1.15,
		"spawn_rate_mult": 1.08,
		"event_difficulty_bonus": 1.8,
		"boss_level_factor": 15.0,
		"enemy_pool": "orc",
		"material_drops": [
			{"id": "iron", "chance": 0.11, "min": 1, "max": 2},
			{"id": "copper", "chance": 0.13, "min": 1, "max": 2},
		],
		"victory_gold": 400,
		"random_event": true,
		"event_armament_books": ["copper_axe", "bone_staff"],
	},
	{
		"id": "bone_cavern",
		"name": "第三關 — 骸骨洞窟",
		"name_key": "STAGE_BONE_CAVERN_NAME",
		"map_path": "res://assets/Maps/TEST.tmx",
		"boss_id": "boss_sk_mage",
		"boss_time": 600.0,        # 10 分鐘
		"boss_warning_time": 45.0,
		"difficulty_base": 2.8,
		"difficulty_seconds_per_tier": 38.0,
		"difficulty_scale": 1.2,
		"spawn_batch_mult": 1.28,
		"spawn_rate_mult": 1.15,
		"event_difficulty_bonus": 2.4,
		"boss_level_factor": 20.0,
		"enemy_pool": "undead",
		"material_drops": [
			{"id": "bone", "chance": 0.12, "min": 1, "max": 2},
			{"id": "rag", "chance": 0.10, "min": 1, "max": 2},
		],
		"victory_gold": 650,
		"rescue_merchant": true,
		"random_event": true,
		"event_armament_books": ["cloth_armor"],
	},
]


func _enemy_pool_source(pool_id: String) -> Array[Dictionary]:
	match pool_id:
		"orc":
			return ENEMY_POOL_ORC
		"undead":
			return ENEMY_POOL_UNDEAD
		_:
			return ENEMY_POOL_SLIME


func get_enemy_def(id: String) -> Dictionary:
	for s in ENEMY_POOL_SLIME:
		if s["id"] == id:
			return s
	for s in ENEMY_POOL_ORC:
		if s["id"] == id:
			return s
	for s in ENEMY_POOL_UNDEAD:
		if s["id"] == id:
			return s
	return {}


## 依難度從指定池挑小怪（不含 stage_boss；邏輯同舊 pick_slime）
func pick_enemy_from_pool(pool_id: String, difficulty: float) -> Dictionary:
	var src: Array[Dictionary] = _enemy_pool_source(pool_id)
	var tier: int = clampi(int(floor(difficulty)), 0, 6)
	var candidates: Array[Dictionary] = []
	for s in src:
		var t: int = int(s["tier"])
		if t > tier or t < tier - 1:
			continue
		if s.get("boss", false) and tier < 4:
			continue
		if s.get("stage_boss", false):
			continue
		candidates.append(s)
	if candidates.is_empty():
		for s in src:
			if s.get("stage_boss", false) or s.get("boss", false):
				continue
			return s
		return src[0] if not src.is_empty() else {}
	var pool: Array[Dictionary] = []
	for s in candidates:
		var w: int = 6
		if s.get("elite", false):
			w = 2
		if s.get("boss", false):
			w = 1
		for i in w:
			pool.append(s)
	return pool.pick_random()


func get_slime_def(id: String) -> Dictionary:
	return get_enemy_def(id)


func get_stage_def(id: String) -> Dictionary:
	for s in STAGES:
		if s["id"] == id:
			return s
	return STAGES[0]


## 相容舊呼叫：等同第一關史萊姆池
func pick_slime(difficulty: float) -> Dictionary:
	return pick_enemy_from_pool("slime", difficulty)


## 圖鑑：三池合併（池順序 + 去重 id）
func all_enemy_defs_for_codex() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for pool in [ENEMY_POOL_SLIME, ENEMY_POOL_ORC, ENEMY_POOL_UNDEAD]:
		for d in pool:
			var eid: String = String(d.get("id", ""))
			if eid.is_empty() or seen.has(eid):
				continue
			seen[eid] = true
			out.append(d)
	return out


