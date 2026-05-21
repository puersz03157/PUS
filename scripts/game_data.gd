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

## 角色美術依作者分類（資料夾名稱與 assets/characters/ 一致）
const DREAMIR_CHAR_ROOT := "res://assets/characters/dreamir/"
## 網頁匯出：角色逐幀圖由 ResourceLoader.list_directory 掃描（勿依賴 DirAccess 讀 res://）
const CHIERIT_CHAR_ROOT := "res://assets/characters/chierit/"
const MATTZ_CHAR_ROOT := "res://assets/characters/Mattz Art/"
const OTSOGA_CHAR_ROOT := "res://assets/characters/Otsoga/"
const GANDALF_CHAR_ROOT := "res://assets/characters/GandalfHardcore/"
const GANDALF_NPC_ROOT := GANDALF_CHAR_ROOT + "NPC/"
const SAVE_NPC_TEXTURE := GANDALF_CHAR_ROOT + "Save NPC.png"
## 遊戲角色 id → dreamir 資料夾與子目錄（逐幀 PNG，執行時掃描排序）
const DREAMIR_CHARACTER_ANIMS: Dictionary = {
	"swordsman": {
		"folder": "Swordsman",
		"anims": {"idle": "IDLE", "walk": "RUN", "attack": "Attack", "hurt": "Hit", "death": "Death"},
	},
	"knight": {
		"folder": "Spearman",
		"anims": {"idle": "IDLE", "walk": "RUN", "attack": "Attack", "hurt": "Hit", "death": "Death"},
	},
	"ranger": {
		"folder": "Archer",
		"anims": {"idle": "Idle", "walk": "Run", "attack": "Attack", "hurt": "Hit", "death": "Death"},
	},
	"wizard": {
		"folder": "Mage",
		"anims": {"idle": "IDLE", "walk": "RUN", "attack": "Attack", "hurt": "Hit", "death": "Death"},
	},
	"bard": {
		"folder": "Assassin",
		"anims": {"idle": "Idle", "walk": "RUN", "attack": "ATTACK", "hurt": "Hit", "death": "Death"},
	},
}
var _dreamir_sprite_frames_cache: Dictionary = {}
var _chierit_sprite_frames_cache: Dictionary = {}
var _sprite_sheet_row_bands_cache: Dictionary = {}
var _sprite_sheet_anim_frames_cache: Dictionary = {}

const FIRE_KNIGHT_ROOT := CHIERIT_CHAR_ROOT + "fire_knight/"
## chierit 逐幀素材（單幀約 288×128）— 戰鬥顯示倍率（相對 CHARACTERS 預設 scale=1）
const CHIERIT_CHARACTER_SCALE := 1
## chierit 造型在房屋／選角預覽的顯示倍率（可與戰鬥分開調）
const CHIERIT_PREVIEW_SCALE := 0.88
## chierit 村莊腳底微調（正值＝角色往下，加在角色 village_sprite_feet_fine 上）
const CHIERIT_VILLAGE_FEET_FINE_Y := 10.0
## chierit 房屋預覽框內略下沉（TextureRect position.y）
const CHIERIT_PREVIEW_FEET_FINE_Y := 8.0
## 使用 chierit 資產的房屋造型 id（新增造型時加入此表）
const CHIERIT_HOUSE_SKIN_IDS: Array[String] = ["fire_knight", "leaf_ranger"]
## 劍士專屬造型 fire_knight（chierit）— 08_sp_atk 為技能施放
const FIRE_KNIGHT_ANIM_FOLDERS: Dictionary = {
	"idle": "01_idle",
	"walk": "02_run",
	"attack": "05_1_atk",
	"skill": "08_sp_atk",
	"hurt": "10_take_hit",
	"death": "11_death",
}
const LEAF_RANGER_ROOT := CHIERIT_CHAR_ROOT + "Leaf_Ranger/"
## 遊俠專屬造型 leaf_ranger（chierit）— sp_atk 為技能施放
const LEAF_RANGER_ANIM_FOLDERS: Dictionary = {
	"idle": "idle",
	"walk": "run",
	"attack": "atk",
	"skill": "sp_atk",
	"hurt": "take_hit",
	"death": "death",
}
const BOW_ARROW_PROJECTILE_TEXTURE := "res://assets/Effects/arrow/arrow_.png"
## 武器 HUD／圖鑑圖示：res://assets/icons/weapons/<weapon_id>.png（無圖則 fallback）
const WEAPON_ICON_ROOT := "res://assets/icons/weapons/"
## 武裝圖示：res://assets/icons/armaments/<armament_id>.png（id 同 ARMAMENTS；none 無圖）
const ARMAMENT_ICON_ROOT := "res://assets/icons/armaments/"
## 通用能力升級圖示：res://assets/icons/common/<upgrade_id>.png（id 同 COMMON_UPGRADES）
const COMMON_ICON_ROOT := "res://assets/icons/common/"
## 介面圖示（避免 Unicode 箭頭／齒輪在自訂字型下變亂碼，網頁版尤其明顯）
const UI_ICON_ROOT := "res://assets/Maps/2D/UI/Icons/"
const UI_ICON_ARROW_LEFT := UI_ICON_ROOT + "Arrow_left.png"
const UI_ICON_ARROW_RIGHT := UI_ICON_ROOT + "Arrow_right.png"
const UI_ICON_GEAR := UI_ICON_ROOT + "Gear.png"
const UI_ICON_PAUSE := UI_ICON_ROOT + "Pause.png"
## 金幣圖示：將 gold.png 放在此路徑（可替換）；無檔時 fallback 至 UI 包的 Currency.png
const CURRENCY_ICON_ROOT := "res://assets/icons/currency/"
const GOLD_ICON_PATH := CURRENCY_ICON_ROOT + "gold.png"
const GOLD_ICON_FALLBACK_PATH := UI_ICON_ROOT + "Currency.png"
const RUNE_DUST_ICON_PATH := CURRENCY_ICON_ROOT + "rune_dust.png"
## 素材圖示：res://assets/icons/materials/<material_id>.png
const MATERIAL_ICON_ROOT := "res://assets/icons/materials/"
const RESOURCE_ICON_CHIP_SCRIPT := preload("res://scripts/resource_icon_chip.gd")
const RESOURCE_ICON_CHIP_SIZE := 36
## 局內共通強化「種類」格數：初始 5，符文大師可擴至 7（每種強化佔一格，同種可疊層）
const COMMON_UPGRADE_SLOT_INITIAL := 5
const COMMON_UPGRADE_SLOT_MAX := 7
const COMMON_UPGRADE_SLOT_DUST_COSTS: Dictionary = {6: 12, 7: 20}

## 戰士 dreamir 大圖（Mattz Art/Warrior 為備用 strip，戰鬥以本表為準）
const WARRIOR_SPRITE_SHEET: Dictionary = {
	"sheet": DREAMIR_CHAR_ROOT + "Warrior.png",
	"frame_w": 115,
	"frame_h": 84,
	"anims": {
		"idle": {"rows": [1], "frames": [8]},
		"walk": {"rows": [3], "frames": [8]},
		"hurt": {"rows": [4], "frames": [4]},
		"death": {"rows": [5], "frames": [11]},
		"attack": {"rows": [9, 10], "frames": [4, 4]},
	},
}

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
		"params": {
			"angle_deg": 75.0,
			"color": Color(0.85, 0.85, 1.0),
			"attack_effect": {
				"sheet": "res://assets/Effects/sword.png",
				"frame_w": 64,
				"frame_h": 64,
				"frame_count": 1,
				"fps": 12.0,
				"hit_mode": "fan",
				"angle_deg": 75.0,
				"hit_angle_deg": 62.0,
				"hit_reach_mult": 0.92,
				"art_dir": [0.0, -1.0],
				"art_pivot": [0.0, 0.5],
				"art_tip": [0.0, -0.5],
				"swing_start_deg": -30.0,
				"swing_sweep_deg": 60.0,
				"swing_duration": 0.2,
				"fit_visual_to_reach": true,
				"art_extent": 44.0,
				"visual_reach_mult": 1.08,
				"visual_scale_mult": 1.0,
				"sprite_offset_aim": [-4.0, 5.0],
				"show_hit_debug": false,
				"z_index": 8,
			},
		},
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
		"params": {
			"angle_deg": 28.0,
			"color": Color(1.0, 0.95, 0.5),
			"attack_effect": {
				"sheet": "res://assets/Effects/spear.png",
				"frame_w": 64,
				"frame_h": 64,
				"frame_count": 8,
				"fps": 14.0,
				"hit_frames": [3, 4],
				"art_dir": [1.0, -1.0],
				"art_pivot": [-0.5, 0.5],
				"art_tip": [0.5, -0.5],
				"tip_half_width": 22.0,
				"fit_visual_to_reach": true,
				"art_extent": 88.0,
				"visual_scale_mult": 1.0,
				"z_index": 8,
			},
		},
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
		"params": {
			"speed": 700.0, "count": 2, "spread_deg": 18.0, "pierce": 0,
			"color": Color(0.8, 1.0, 0.6), "arrow_sprite": true,
		},
		"max_effect": "投射物附加貫穿", "max_effect_key": "WEAPON_BOW_MAX",
	},
	{
		"id": "melody",
		"name": "匕首", "name_key": "WEAPON_MELODY_NAME",
		"kind": "projectile",
		"damage": 10.0,
		"rate": 1.3,
		"crit_chance": 0.09,
		"crit_damage_mult": 1.7,
		"range": 190.0,
		"params": {"speed": 280.0, "count": 3, "wave": true, "color": Color(0.6, 0.9, 1.0)},
		"max_effect": "命中附加破綻", "max_effect_key": "WEAPON_MELODY_MAX",
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
	{
		"id": "frost_amulet",
		"name": "霜晶護符", "name_key": "ARMAMENT_FROST_AMULET_NAME",
		"desc": "進場寒冰 +1。緩速獵手：攻速、移速與小量爆率。", "desc_key": "ARMAMENT_FROST_AMULET_DESC",
		"weapon_id": "ice",
		"hp_add": 4.0, "def_add": 0.0,
		"atk_add": 1.0, "spd_add": 0.5,
		"rate_add": 0.04, "crit_rate_add": 0.02, "crit_dmg_add": 0.0,
		"requires_craft_book": true,
		"craft_gold": 110,
		"craft_materials": {"stone": 5, "wood": 4},
	},
	{
		"id": "shadow_blade",
		"name": "影刃", "name_key": "ARMAMENT_SHADOW_BLADE_NAME",
		"desc": "進場匕首 +1。機動刺殺：爆率、攻速與移速。", "desc_key": "ARMAMENT_SHADOW_BLADE_DESC",
		"weapon_id": "melody",
		"hp_add": 0.0, "def_add": 0.0,
		"atk_add": 2.0, "spd_add": 0.5,
		"rate_add": 0.03, "crit_rate_add": 0.05, "crit_dmg_add": 0.0,
		"requires_craft_book": true,
		"craft_gold": 120,
		"craft_materials": {"rag": 5, "iron": 3},
	},
	{
		"id": "crystal_bracelet",
		"name": "魔晶臂環", "name_key": "ARMAMENT_CRYSTAL_BRACELET_NAME",
		"desc": "進場碎刃 +1。環繞轟炸：攻速、防禦與爆傷。", "desc_key": "ARMAMENT_CRYSTAL_BRACELET_DESC",
		"weapon_id": "shard",
		"hp_add": 0.0, "def_add": 2.0,
		"atk_add": 1.0, "spd_add": 0.0,
		"rate_add": 0.05, "crit_rate_add": 0.0, "crit_dmg_add": 0.10,
		"requires_craft_book": true,
		"craft_gold": 120,
		"craft_materials": {"copper": 5, "stone": 4},
	},
	{
		"id": "beast_bracer",
		"name": "獸爪護臂", "name_key": "ARMAMENT_BEAST_BRACER_NAME",
		"desc": "進場爪擊 +1。貼身猛攻：攻擊、移速與爆率。", "desc_key": "ARMAMENT_BEAST_BRACER_DESC",
		"weapon_id": "claw",
		"hp_add": 4.0, "def_add": 0.0,
		"atk_add": 2.0, "spd_add": 0.5,
		"rate_add": 0.0, "crit_rate_add": 0.03, "crit_dmg_add": 0.0,
		"requires_craft_book": true,
		"craft_gold": 100,
		"craft_materials": {"bone": 5, "rag": 3},
	},
	{
		"id": "flame_sigil",
		"name": "炎符頭環", "name_key": "ARMAMENT_FLAME_SIGIL_NAME",
		"desc": "進場火焰 +1。燃燒術者：攻擊、攻速與小量爆率。", "desc_key": "ARMAMENT_FLAME_SIGIL_DESC",
		"weapon_id": "flame",
		"hp_add": 0.0, "def_add": 0.0,
		"atk_add": 3.0, "spd_add": 0.0,
		"rate_add": 0.03, "crit_rate_add": 0.02, "crit_dmg_add": 0.0,
		"requires_craft_book": true,
		"craft_gold": 130,
		"craft_materials": {"bone": 4, "copper": 3},
	},
	{
		"id": "venom_belt",
		"name": "毒牙腰帶", "name_key": "ARMAMENT_VENOM_BELT_NAME",
		"desc": "進場毒素 +1。毒池持久：血量、防禦與爆傷。", "desc_key": "ARMAMENT_VENOM_BELT_DESC",
		"weapon_id": "poison",
		"hp_add": 6.0, "def_add": 4.0,
		"atk_add": 1.0, "spd_add": 0.0,
		"rate_add": 0.0, "crit_rate_add": 0.0, "crit_dmg_add": 0.12,
		"requires_craft_book": true,
		"craft_gold": 120,
		"craft_materials": {"bone": 5, "wood": 4},
	},
	{
		"id": "thunder_cape",
		"name": "雷紋披風", "name_key": "ARMAMENT_THUNDER_CAPE_NAME",
		"desc": "進場閃電 +1。連鎖轟炸：攻擊、防禦與爆傷。", "desc_key": "ARMAMENT_THUNDER_CAPE_DESC",
		"weapon_id": "lightning",
		"hp_add": 0.0, "def_add": 2.0,
		"atk_add": 2.0, "spd_add": 0.0,
		"rate_add": 0.0, "crit_rate_add": 0.0, "crit_dmg_add": 0.12,
		"requires_craft_book": true,
		"craft_gold": 130,
		"craft_materials": {"iron": 4, "copper": 3},
	},
	{
		"id": "holy_shield",
		"name": "聖徽護盾", "name_key": "ARMAMENT_HOLY_SHIELD_NAME",
		"desc": "進場聖光 +1。生存支援：血量、防禦與少量攻速。", "desc_key": "ARMAMENT_HOLY_SHIELD_DESC",
		"weapon_id": "holy",
		"hp_add": 12.0, "def_add": 6.0,
		"atk_add": 0.0, "spd_add": 0.0,
		"rate_add": 0.02, "crit_rate_add": 0.0, "crit_dmg_add": 0.0,
		"requires_craft_book": true,
		"craft_gold": 130,
		"craft_materials": {"rag": 5, "stone": 4},
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
		"sprite_faces_left": false,
		"anim_fps": 14.0,
		"walk_anim_over_attack": true,
		"scale": 1,
		"sprite_feet_fine": 3,
		"body_radius": 16,
		"offset_y": -7,
		"skill_options": ["none", "whirl_slash"],
		"passive_options": ["none", "fighting_spirit"],
	},
	{
		"id": "ranger",
		"name": "遊俠", "name_key": "CHAR_RANGER_NAME",
		"rarity": "common",
		"weapon": "bow", "hp": 95.0, "atk": 14.0, "def": 7.0, "spd": 6.5,
		"desc": "遠程拉打：較高的移動速度補足血量弱點，適合遠距離狙擊。",
		"desc_key": "CHAR_RANGER_DESC",
		"color": Color(0.6, 1.0, 0.7),
		"sprite": "",
		"sprite_faces_left": false,
		"anim_fps": 14.0,
		"walk_anim_over_attack": true,
		"scale": 1,
		"body_radius": 16,
		"offset_y": -7,
		"skill_options": ["none", "agile_tactics"],
		"passive_options": ["none", "quick_step"],
	},
	{
		"id": "knight",
		"name": "騎士", "name_key": "CHAR_KNIGHT_NAME",
		"rarity": "rare",
		"weapon": "spear", "hp": 170.0, "atk": 10.0, "def": 18.0, "spd": 4.5,
		"skill_options": ["none", "heavy_armor"],
		"passive_options": ["none", "unyielding"],
		"desc": "坦克型：極高的生存能力，雖然移速較慢，但能承受大量傷害。",
		"desc_key": "CHAR_KNIGHT_DESC",
		"color": Color(0.7, 0.85, 1.0),
		"sprite": "",
		"sprite_faces_left": false,
		"anim_fps": 14.0,
		"walk_anim_over_attack": true,
		"scale": 1,
		"body_radius": 16,
		"offset_y": -7,
	},
	{
		"id": "warrior",
		"name": "戰士", "name_key": "CHAR_WARRIOR_NAME",
		"rarity": "rare",
		"weapon": "axe", "hp": 118.0, "atk": 16.0, "def": 10.0, "spd": 5.2,
		"desc": "猛攻型：較劍士更偏重輸出，以近戰壓制換取略低的生存能力。",
		"desc_key": "CHAR_WARRIOR_DESC",
		"color": Color(0.88, 0.52, 0.42),
		"sprite": "",
		"sprite_faces_left": false,
		"sprite_sheet": "warrior",
		"anim_fps": 14.0,
		"strip_fps": {"attack": 14.0},
		"walk_anim_over_attack": true,
		"scale": 1,
		"body_radius": 16,
		"offset_y": -7,
		"village_sprite_feet_fine": 2,
		"skill_options": ["none", "heavenly_judgment"],
		"passive_options": ["none", "breakthrough"],
	},
	{
		"id": "wizard",
		"name": "巫師", "name_key": "CHAR_WIZARD_NAME",
		"rarity": "rare",
		"weapon": "magic_bullet", "hp": 85.0, "atk": 23.0, "def": 6.0, "spd": 5.2,
		"desc": "玻璃大砲：生存能力極低，但擁有最高攻擊力。",
		"desc_key": "CHAR_WIZARD_DESC",
		"color": Color(0.85, 0.55, 1.0),
		"sprite": "",
		"sprite_faces_left": false,
		"anim_fps": 14.0,
		"walk_anim_over_attack": true,
		"scale": 1,
		"offset_y": -7,
		"body_radius": 16,
		"skill_options": ["none", "energy_wave"],
		"passive_options": ["none", "arcane_mastery"],
	},
	{
		"id": "bard",
		"name": "刺客", "name_key": "CHAR_BARD_NAME",
		"rarity": "rare",
		"weapon": "melody", "hp": 108.0, "atk": 12.0, "def": 9.0, "spd": 6.2,
		"desc": "機敏刺殺：高機動貼身作戰，以匕首連擊與破綻標記放大輸出。",
		"desc_key": "CHAR_BARD_DESC",
		"color": Color(1.0, 0.7, 0.85),
		"sprite": "",
		"sprite_faces_left": false,
		"anim_fps": 14.0,
		"walk_anim_over_attack": true,
		"scale": 1,
		"body_radius": 16,
		"offset_y": -7,
		"skill_options": ["none", "mirror_moon"],
		"passive_options": ["none", "sword_aura_resonance"],
	},
	{
		"id": "werewolf",
		"name": "狼人", "name_key": "CHAR_WEREWOLF_NAME",
		"rarity": "epic",
		"weapon": "claw", "hp": 122.0, "atk": 18.0, "def": 9.0, "spd": 7.2,
		"desc": "敏捷近戰：高攻擊、極高移速，透過快速切入與流血造成威脅。",
		"desc_key": "CHAR_WEREWOLF_DESC",
		"color": Color(0.85, 0.55, 0.45),
		"sprite": "",
		"sprite_faces_left": false,
		"sprite_strips": {
			"human_idle": MATTZ_CHAR_ROOT + "Werewolf/IDLE HUMAN.png",
			"transform": MATTZ_CHAR_ROOT + "Werewolf/TRANSFORMATION.png",
			"idle": MATTZ_CHAR_ROOT + "Werewolf/IDLE.png",
			"walk": MATTZ_CHAR_ROOT + "Werewolf/RUN.png",
			"attack": MATTZ_CHAR_ROOT + "Werewolf/ATTACK.png",
			"hurt": MATTZ_CHAR_ROOT + "Werewolf/HURT.png",
			"death": MATTZ_CHAR_ROOT + "Werewolf/DEATH.png",
		},
		"preview_strip": "idle",
		"preview_trim_top": 8,
		"preview_trim_bottom": 4,
		"start_transform": true,
		"strip_frame_w": 158,
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
		"id": "samurai",
		"name": "武士", "name_key": "CHAR_SAMURAI_NAME",
		"rarity": "epic",
		"weapon": "shard", "hp": 120.0, "atk": 20.0, "def": 12.0, "spd": 6.4,
		"desc": "刃氣護體：碎刃常駐旋護身周，越身陷重圍刀氣越盛，無我之境中爆發最強攻勢。",
		"desc_key": "CHAR_SAMURAI_DESC",
		"color": Color(0.72, 0.78, 0.98),
		"sprite": "",
		"sprite_faces_left": false,
		"sprite_strips": {
			"idle": MATTZ_CHAR_ROOT + "Samurai/IDLE.png",
			"walk": MATTZ_CHAR_ROOT + "Samurai/RUN.png",
			"attack": MATTZ_CHAR_ROOT + "Samurai/ATTACK.png",
			"hurt": MATTZ_CHAR_ROOT + "Samurai/HURT.png",
			"death": MATTZ_CHAR_ROOT + "Samurai/DEATH.png",
		},
		"strip_frame_w": 106,
		"strip_hframes": 14,
		"strip_hframes_by_strip": {
			"idle": 14, "walk": 8, "attack": 5, "hurt": 4, "death": 10,
		},
		"strip_frames": {
			"idle": 14, "walk": 8, "attack": 5, "hit": 4, "death": 10,
		},
		"anim_fps": 14.0,
		"walk_anim_over_attack": true,
		"scale": 1,
		"body_radius": 16,
		"offset_y": -7,
		"skill_options": ["none", "mushin"],
		"passive_options": ["none", "blade_aura"],
	},
	{
		"id": "vampire_lord",
		"name": "吸血鬼領主", "name_key": "CHAR_VAMPIRE_LORD_NAME",
		"rarity": "legend",
		"weapon": "claw", "hp": 135.0, "atk": 21.0, "def": 13.0, "spd": 6.5,
		"desc": "傳說血族：爪擊與高機動兼顧，擅長貼身纏鬥與持續壓制。",
		"desc_key": "CHAR_VAMPIRE_LORD_DESC",
		"color": Color(0.55, 0.22, 0.32),
		## Otsoga / NightLord：每動作一組獨立 PNG（無 hurt，會落到 idle）
		"sprite_frames": {
			"idle":   {"pattern": OTSOGA_CHAR_ROOT + "NightLord/Idle/Idle{i}.png",        "count": 14},
			"walk":   {"pattern": OTSOGA_CHAR_ROOT + "NightLord/Run/Running{i}.png",      "count": 10},
			"attack": {"pattern": OTSOGA_CHAR_ROOT + "NightLord/Attacks/LightAtk{i}.png", "count": 25},
			"death":  {"pattern": OTSOGA_CHAR_ROOT + "NightLord/Death/Death{i}.png",      "count": 43},
		},
		"anim_fps": 18.0,
		"sprite_faces_left": false,
		"walk_anim_over_attack": true,
		"scale": 0.7,
		"body_radius": 28,
		"offset_y": -10,
		"skill_options": ["none", "blood_shroud"],
		"passive_options": ["none", "blood_frenzy"],
	},
	{
		"id": "flame_witch",
		"name": "烈焰靈女巫", "name_key": "CHAR_FLAME_WITCH_NAME",
		"rarity": "legend",
		"weapon": "flame", "hp": 102.0, "atk": 23.0, "def": 9.0, "spd": 5.5,
		"desc": "傳說術者：駕馭火焰範圍傷害，爆發與控場兼備。",
		"desc_key": "CHAR_FLAME_WITCH_DESC",
		"color": Color(1.0, 0.45, 0.25),
		## Otsoga / SalamanderWitch：每動作一組獨立 PNG
		"sprite_frames": {
			"idle":   {"pattern": OTSOGA_CHAR_ROOT + "SalamanderWitch/Idle/Idle{i}.png",         "count": 9},
			"walk":   {"pattern": OTSOGA_CHAR_ROOT + "SalamanderWitch/Move/Move{i}.png",         "count": 13},
			"attack": {"pattern": OTSOGA_CHAR_ROOT + "SalamanderWitch/Attacks/ComboAtk{i}.png",  "count": 28},
			"hurt":   {"pattern": OTSOGA_CHAR_ROOT + "SalamanderWitch/Hurt/Hurt{i}.png",         "count": 5},
			"death":  {"pattern": OTSOGA_CHAR_ROOT + "SalamanderWitch/Death/Die{i}.png",         "count": 30},
		},
		"anim_fps": 18.0,
		"sprite_faces_left": false,
		"walk_anim_over_attack": true,
		"scale": .8,
		"body_radius": 28,
		"offset_y": -8,
		"skill_options": ["none", "flame_burst"],
		"passive_options": ["none", "ignition"],
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
	{"id": "c_crit_chance", "name": "精準打擊", "name_key": "CUP_C_CRIT_CHANCE_NAME", "desc": "爆擊率 +3%",   "desc_key": "CUP_C_CRIT_CHANCE_DESC", "max": 5, "value": 0.03, "field": "crit_chance"},
	{"id": "c_crit_damage", "name": "殘忍打擊", "name_key": "CUP_C_CRIT_DAMAGE_NAME", "desc": "爆擊傷害 +15%","desc_key": "CUP_C_CRIT_DAMAGE_DESC", "max": 5, "value": 0.15, "field": "crit_damage_mult"},
]


func get_weapon_upgrade_def(id: String) -> Dictionary:
	for u in WEAPON_UPGRADES:
		if u["id"] == id:
			return u
	return {}


func get_common_upgrade_def(id: String) -> Dictionary:
	for u in COMMON_UPGRADES:
		if u["id"] == id:
			var d: Dictionary = u.duplicate(true)
			if not d.has("icon") or String(d.get("icon", "")) == "":
				var icon_path: String = common_upgrade_icon_path(id)
				if icon_path != "":
					d["icon"] = icon_path
			return d
	return {}


## 四項武器升級（w_damage / w_range / w_rate / w_count）皆達上限
func is_weapon_upgrades_maxed(upgrades: Dictionary) -> bool:
	for u in WEAPON_UPGRADES:
		var have: int = int(upgrades.get(u["id"], 0))
		if have < int(u["max"]):
			return false
	return true


func weapon_entry_has_upgrades(weapon_entry: Dictionary) -> bool:
	var upgrades: Variant = weapon_entry.get("upgrades", {})
	if upgrades is not Dictionary:
		return false
	for u in WEAPON_UPGRADES:
		if int(upgrades.get(String(u["id"]), 0)) > 0:
			return true
	return false


func weapon_upgrade_stacked_bonus_text(upgrade_def: Dictionary, level: int) -> String:
	if level <= 0:
		return ""
	var id: String = String(upgrade_def.get("id", ""))
	var value: float = float(upgrade_def.get("value", 0.0))
	if id == "w_count":
		return tr("CODEX_UPGRADE_VALUE_FLAT_FMT") % int(value * float(level))
	return tr("CODEX_UPGRADE_VALUE_PERCENT_FMT") % int(round(value * float(level) * 100.0))


## 暫停選單／懸停提示：已取得的單把武器升級列表（無升級則回空字串）
func format_weapon_upgrades_tooltip(weapon_entry: Dictionary) -> String:
	if not weapon_entry_has_upgrades(weapon_entry):
		return ""
	var wid: String = String(weapon_entry.get("id", ""))
	var wdef: Dictionary = get_weapon_def(wid)
	if wdef.is_empty():
		return ""
	var upgrades: Dictionary = weapon_entry.get("upgrades", {})
	var lines: Array[String] = [tr_name(wdef), tr("PAUSE_WEAPON_UPGRADES_HEADER")]
	for u in WEAPON_UPGRADES:
		var lv: int = int(upgrades.get(String(u["id"]), 0))
		if lv <= 0:
			continue
		lines.append(tr("PAUSE_WEAPON_UPGRADE_LINE_FMT") % [
			tr_name(u), lv, int(u.get("max", 0)),
			weapon_upgrade_stacked_bonus_text(u, lv)])
	if is_weapon_upgrades_maxed(upgrades):
		var max_fx: String = tr_max_effect(wdef)
		if max_fx != "":
			lines.append(tr("PAUSE_WEAPON_MAX_EFFECT_FMT") % max_fx)
	return "\n".join(lines)


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
			if not d.has("icon") or String(d.get("icon", "")) == "":
				var icon_path: String = WEAPON_ICON_ROOT + id + ".png"
				if ResourceLoader.exists(icon_path, "Texture2D"):
					d["icon"] = icon_path
			return d
	return {}


func get_armament_def(id: String) -> Dictionary:
	for a in ARMAMENTS:
		if a["id"] == id:
			var d: Dictionary = a.duplicate(true)
			if id != "none" and (not d.has("icon") or String(d.get("icon", "")) == ""):
				var icon_path: String = ARMAMENT_ICON_ROOT + id + ".png"
				if ResourceLoader.exists(icon_path, "Texture2D"):
					d["icon"] = icon_path
			return d
	return {}


const P1_HOUSE_FAVORITE_ARMAMENT_SLOTS := 5
## 新帳號／重置後喜愛武裝可用格數（最終 5 格須向鐵匠擴充）
const HOUSE_FAVORITE_ARMAMENT_SLOTS_INITIAL := 2
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
	if char_id == "swordsman":
		out.append({"id": "fire_knight", "label": tr("HOUSE_SKIN_FIRE_KNIGHT")})
	if char_id == "ranger":
		out.append({"id": "leaf_ranger", "label": tr("HOUSE_SKIN_LEAF_RANGER")})
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


func is_chierit_house_skin(skin_id: String) -> bool:
	return skin_id in CHIERIT_HOUSE_SKIN_IDS


func get_chierit_sprite_frames(root: String, folder_map: Dictionary, cache_key: String) -> Dictionary:
	if _chierit_sprite_frames_cache.has(cache_key):
		return _chierit_sprite_frames_cache[cache_key]
	var out: Dictionary = {}
	for anim_key in folder_map:
		var subdir: String = root.path_join(String(folder_map[anim_key]))
		var frames: Array = _list_dreamir_png_paths(subdir)
		if not frames.is_empty():
			out[anim_key] = frames
	_chierit_sprite_frames_cache[cache_key] = out
	return out


func _build_chierit_house_skin_visual(
		base: Dictionary, frames: Dictionary, feet_fine: float = 4.0) -> Dictionary:
	var vis: Dictionary = base.duplicate(true)
	if not frames.is_empty():
		vis["sprite_frames"] = frames
		vis.erase("sprite_sheet")
	apply_chierit_visual_scale(vis, base)
	vis["sprite_feet_fine"] = feet_fine
	vis["walk_anim_over_attack"] = false
	vis["anim_fps"] = 14.0
	vis["strip_fps"] = {"skill": 16.0, "attack": 15.0}
	return vis


func _resolve_chierit_house_skin(char_id: String, skin_id: String, base: Dictionary) -> Dictionary:
	if skin_id == "fire_knight" and char_id == "swordsman":
		return _build_chierit_house_skin_visual(
			base,
			get_chierit_sprite_frames(FIRE_KNIGHT_ROOT, FIRE_KNIGHT_ANIM_FOLDERS, "fire_knight"))
	if skin_id == "leaf_ranger" and char_id == "ranger":
		return _build_chierit_house_skin_visual(
			base,
			get_chierit_sprite_frames(LEAF_RANGER_ROOT, LEAF_RANGER_ANIM_FOLDERS, "leaf_ranger"))
	return {}


func apply_chierit_visual_scale(visual: Dictionary, base: Dictionary) -> void:
	var base_scale: float = float(base.get("scale", 1.0))
	visual["scale"] = base_scale * CHIERIT_CHARACTER_SCALE
	visual["visual_pack"] = "chierit"
	visual["preview_scale"] = CHIERIT_PREVIEW_SCALE
	visual["village_sprite_feet_fine"] = float(base.get("village_sprite_feet_fine", 0)) \
		+ CHIERIT_VILLAGE_FEET_FINE_Y
	visual["preview_feet_fine_y"] = CHIERIT_PREVIEW_FEET_FINE_Y


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
	if is_chierit_house_skin(skin_id):
		var chierit_vis: Dictionary = _resolve_chierit_house_skin(char_id, skin_id, base)
		if not chierit_vis.is_empty():
			return chierit_vis
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


const ARMAMENT_STAT_ICON_SIZE := 18
const PAUSE_LIVE_STAT_ICON_SIZE := 16


func gold_icon_path() -> String:
	if ResourceLoader.exists(GOLD_ICON_PATH, "Texture2D"):
		return GOLD_ICON_PATH
	if ResourceLoader.exists(GOLD_ICON_FALLBACK_PATH, "Texture2D"):
		return GOLD_ICON_FALLBACK_PATH
	return ""


func gold_icon_bbcode(size: int = ARMAMENT_STAT_ICON_SIZE, link_meta: bool = true) -> String:
	var path: String = gold_icon_path()
	if path == "":
		return ""
	var img: String = "[img=%dx%d]%s[/img]" % [size, size, path]
	if link_meta:
		return "[url=gold]%s[/url]" % img
	return img


func rune_dust_icon_path() -> String:
	if ResourceLoader.exists(RUNE_DUST_ICON_PATH, "Texture2D"):
		return RUNE_DUST_ICON_PATH
	return ""


func rune_dust_icon_bbcode(size: int = ARMAMENT_STAT_ICON_SIZE, link_meta: bool = true) -> String:
	var path: String = rune_dust_icon_path()
	if path == "":
		return ""
	var img: String = "[img=%dx%d]%s[/img]" % [size, size, path]
	if link_meta:
		return "[url=rune_dust]%s[/url]" % img
	return img


func material_icon_path(material_id: String) -> String:
	if material_id == "":
		return ""
	var path: String = MATERIAL_ICON_ROOT + material_id + ".png"
	if ResourceLoader.exists(path, "Texture2D"):
		return path
	return ""


func material_icon_bbcode(
		material_id: String,
		size: int = ARMAMENT_STAT_ICON_SIZE,
		link_meta: bool = true) -> String:
	var path: String = material_icon_path(material_id)
	if path == "":
		return tr_material_name(material_id)
	var img: String = "[img=%dx%d]%s[/img]" % [size, size, path]
	if link_meta:
		return "[url=material:%s]%s[/url]" % [material_id, img]
	return img


func resource_meta_tooltip(meta: Variant) -> String:
	var key: String = String(meta)
	if key.begins_with("material:"):
		return tr_material_name(key.substr(9))
	if key == "gold":
		return tr("CURRENCY_GOLD_NAME")
	if key == "rune_dust":
		return tr("CURRENCY_RUNE_DUST_NAME")
	if key.begins_with("armament:"):
		return tr_armament_name(key.substr(10))
	return ""


func format_gold_amount_bbcode(amount: int, size: int = ARMAMENT_STAT_ICON_SIZE) -> String:
	var icon: String = gold_icon_bbcode(size)
	if icon != "":
		return "%s %d" % [icon, amount]
	return str(amount)


func format_gold_cost_bbcode(amount: int, size: int = ARMAMENT_STAT_ICON_SIZE) -> String:
	var icon: String = gold_icon_bbcode(size)
	if icon != "":
		return "%s %d" % [icon, amount]
	return tr("BLACKSMITH_COST_GOLD_FMT") % amount


func format_material_cost_bbcode(
		material_id: String,
		have: int,
		need: int,
		size: int = ARMAMENT_STAT_ICON_SIZE) -> String:
	var icon: String = material_icon_bbcode(material_id, size)
	return "%s %d/%d" % [icon, have, need]


func make_material_icon_chip(material_id: String, amount: int = -1, icon_size: int = RESOURCE_ICON_CHIP_SIZE) -> ResourceIconChip:
	var chip: ResourceIconChip = RESOURCE_ICON_CHIP_SCRIPT.new()
	var tex: Texture2D = null
	var path: String = material_icon_path(material_id)
	if path != "":
		tex = ResourceLoader.load(path, "Texture2D") as Texture2D
	chip.configure(tr_material_name(material_id), tex, amount, icon_size)
	return chip


func make_gold_icon_chip(amount: int = -1, icon_size: int = RESOURCE_ICON_CHIP_SIZE) -> ResourceIconChip:
	var chip: ResourceIconChip = RESOURCE_ICON_CHIP_SCRIPT.new()
	var tex: Texture2D = null
	var path: String = gold_icon_path()
	if path != "":
		tex = ResourceLoader.load(path, "Texture2D") as Texture2D
	chip.configure(tr("CURRENCY_GOLD_NAME"), tex, amount, icon_size)
	return chip


func make_rune_dust_icon_chip(amount: int = -1, icon_size: int = RESOURCE_ICON_CHIP_SIZE) -> ResourceIconChip:
	var chip: ResourceIconChip = RESOURCE_ICON_CHIP_SCRIPT.new()
	var tex: Texture2D = null
	var path: String = rune_dust_icon_path()
	if path != "":
		tex = ResourceLoader.load(path, "Texture2D") as Texture2D
	chip.configure(tr("CURRENCY_RUNE_DUST_NAME"), tex, amount, icon_size)
	return chip


## 暫停選單「即時素質」列 → 通用能力圖示 id
func live_stat_common_icon_id(stat_key: String) -> String:
	match stat_key:
		"hp":
			return "c_regen"
		"atk":
			return "c_atk"
		"def":
			return "c_armor"
		"rate":
			return "c_cooldown"
		"move":
			return "c_speed"
		"dmg_reduce":
			return "c_armor"
		"crit_chance":
			return "c_crit_chance"
		"crit_damage":
			return "c_crit_damage"
		_:
			return ""


func format_live_stat_bbcode(stat_key: String, value_text: String, size: int = PAUSE_LIVE_STAT_ICON_SIZE) -> String:
	var icon: String = common_upgrade_icon_bbcode(live_stat_common_icon_id(stat_key), size)
	if icon != "":
		return "%s %s" % [icon, value_text]
	return value_text


## 暫停選單即時素質：爆擊率／爆傷（玩家 + 已裝備武器取較高，與命中爆擊時一致）
func player_live_crit_chance(p: Node) -> float:
	if p == null:
		return 0.0
	var total: float = float(p.crit_chance) if p.get("crit_chance") != null else 0.0
	if not (p.get("weapons") is Array):
		return total
	for w in p.weapons:
		var wdef: Dictionary = get_weapon_def(String(w.get("id", "")))
		if not wdef.is_empty():
			total = maxf(total, float(wdef.get("crit_chance", 0.0)))
	return total


func player_live_crit_damage_mult(p: Node) -> float:
	if p == null:
		return CRIT_DAMAGE_MULT_BASE
	var total: float = float(p.crit_damage_mult) if p.get("crit_damage_mult") != null \
		else CRIT_DAMAGE_MULT_BASE
	if not (p.get("weapons") is Array):
		return total
	for w in p.weapons:
		var wdef: Dictionary = get_weapon_def(String(w.get("id", "")))
		if not wdef.is_empty():
			total = maxf(total, float(wdef.get("crit_damage_mult", CRIT_DAMAGE_MULT_BASE)))
	return total

## 武裝平面屬性 → 通用能力圖示 id（無圖則改顯示文字）
func armament_stat_common_icon_id(stat_field: String) -> String:
	match stat_field:
		"hp_add":
			return "c_regen"
		"def_add":
			return "c_armor"
		"atk_add":
			return "c_atk"
		"spd_add":
			return "c_speed"
		"rate_add":
			return "c_cooldown"
		"crit_rate_add":
			return "c_crit_chance"
		"crit_dmg_add":
			return "c_crit_damage"
		_:
			return ""


func common_upgrade_icon_bbcode(upgrade_id: String, size: int = ARMAMENT_STAT_ICON_SIZE) -> String:
	if upgrade_id == "":
		return ""
	var path: String = common_upgrade_icon_path(upgrade_id)
	if path == "" or not ResourceLoader.exists(path):
		return ""
	return "[img=%dx%d]%s[/img]" % [size, size, path]


func _armament_stat_label_key(stat_field: String) -> String:
	match stat_field:
		"hp_add":
			return "ARMAMENT_FAV_STAT_HP"
		"def_add":
			return "ARMAMENT_FAV_STAT_DEF"
		"atk_add":
			return "ARMAMENT_FAV_STAT_ATK"
		"spd_add":
			return "ARMAMENT_FAV_STAT_SPD"
		"rate_add":
			return "ARMAMENT_FAV_STAT_RATE"
		"crit_rate_add":
			return "ARMAMENT_FAV_STAT_CRIT_RATE"
		"crit_dmg_add":
			return "ARMAMENT_FAV_STAT_CRIT_DMG"
		_:
			return ""


func armament_stat_line(label_key: String, value: float, decimals: int = 0) -> String:
	return "%s +%s" % [tr(label_key), _format_favorite_stat_value(value, decimals)]


func format_armament_stat_part(stat_field: String, value: float, as_bbcode: bool = true, decimals: int = 0) -> String:
	var label_key: String = _armament_stat_label_key(stat_field)
	if label_key == "":
		return ""
	if stat_field in ["rate_add", "crit_rate_add", "crit_dmg_add"]:
		var pct: int = int(round(value * 100.0))
		if as_bbcode:
			var icon_pct: String = common_upgrade_icon_bbcode(armament_stat_common_icon_id(stat_field))
			if icon_pct != "":
				return "%s +%d%%" % [icon_pct, pct]
		return "%s +%d%%" % [tr(label_key), pct]
	var val_s: String = "+%s" % _format_favorite_stat_value(value, decimals)
	if as_bbcode:
		var icon: String = common_upgrade_icon_bbcode(armament_stat_common_icon_id(stat_field))
		if icon != "":
			return "%s %s" % [icon, val_s]
	return armament_stat_line(label_key, value, decimals)


func _append_armament_flat_stat_parts(parts: Array[String], stats: Dictionary, as_bbcode: bool = true) -> void:
	var hp_add: float = float(stats.get("hp_add", 0.0))
	var def_add: float = float(stats.get("def_add", 0.0))
	var atk_add: float = float(stats.get("atk_add", 0.0))
	var spd_add: float = float(stats.get("spd_add", 0.0))
	var rate_add: float = float(stats.get("rate_add", 0.0))
	var crit_rate_add: float = float(stats.get("crit_rate_add", 0.0))
	var crit_dmg_add: float = float(stats.get("crit_dmg_add", 0.0))
	if hp_add > 0.0:
		parts.append(format_armament_stat_part("hp_add", hp_add, as_bbcode, 0))
	if def_add > 0.0:
		parts.append(format_armament_stat_part("def_add", def_add, as_bbcode, 0))
	if atk_add > 0.0:
		parts.append(format_armament_stat_part("atk_add", atk_add, as_bbcode, 1))
	if spd_add > 0.0:
		parts.append(format_armament_stat_part("spd_add", spd_add, as_bbcode, 1))
	if rate_add > 0.0:
		parts.append(format_armament_stat_part("rate_add", rate_add, as_bbcode))
	if crit_rate_add > 0.0:
		parts.append(format_armament_stat_part("crit_rate_add", crit_rate_add, as_bbcode))
	if crit_dmg_add > 0.0:
		parts.append(format_armament_stat_part("crit_dmg_add", crit_dmg_add, as_bbcode))


func armament_flat_stat_parts_from_def(adef: Dictionary, as_bbcode: bool = true) -> Array[String]:
	var parts: Array[String] = []
	if adef.is_empty():
		return parts
	_append_armament_flat_stat_parts(parts, adef, as_bbcode)
	return parts


func format_armament_flat_stats_from_def(adef: Dictionary, as_bbcode: bool = true) -> String:
	var parts: Array[String] = armament_flat_stat_parts_from_def(adef, as_bbcode)
	if parts.is_empty():
		return ""
	return " / ".join(parts)


func format_armament_favorite_bonus_text(stats: Dictionary, as_bbcode: bool = true) -> String:
	var parts: Array[String] = []
	_append_armament_flat_stat_parts(parts, stats, as_bbcode)
	if parts.is_empty():
		return tr("ARMAMENT_FAV_STAT_NONE")
	return " / ".join(parts)


func tr_armament_desc_with_flat_stats(armament_id: String, as_bbcode: bool = true) -> String:
	var adef: Dictionary = get_armament_def(armament_id)
	if adef.is_empty():
		return ""
	var text: String = tr_desc(adef)
	var flat: String = format_armament_flat_stats_from_def(adef, as_bbcode)
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


# 關卡解救 NPC（戰鬥內事件）與村莊設施（通關後開啟）
const RESCUE_NPCS: Dictionary = {
	"blacksmith": {
		"name_key": "BLACKSMITH_RESCUE_NAME",
		"hint_key": "BLACKSMITH_RESCUE_HINT",
		"rescued_notice_key": "BLACKSMITH_RESCUED_NOTICE",
	},
	"merchant": {
		"name_key": "MERCHANT_RESCUE_NAME",
		"hint_key": "MERCHANT_RESCUE_HINT",
		"rescued_notice_key": "MERCHANT_RESCUED_NOTICE",
	},
	"tavern_owner": {
		"name_key": "TAVERN_OWNER_RESCUE_NAME",
		"hint_key": "TAVERN_OWNER_RESCUE_HINT",
		"rescued_notice_key": "TAVERN_OWNER_RESCUED_NOTICE",
	},
	"rune_master": {
		"name_key": "RUNE_MASTER_RESCUE_NAME",
		"hint_key": "RUNE_MASTER_RESCUE_HINT",
		"rescued_notice_key": "RUNE_MASTER_RESCUED_NOTICE",
	},
	"farmer": {
		"name_key": "FARMER_RESCUE_NAME",
		"hint_key": "FARMER_RESCUE_HINT",
		"rescued_notice_key": "FARMER_RESCUED_NOTICE",
	},
}

const VILLAGE_FACILITIES: Array[Dictionary] = [
	{
		"id": "quarry",
		"name_key": "VILLAGE_QUARRY_NAME",
		"hint_key": "VILLAGE_QUARRY_INTERACT_HINT",
		"collect_key": "VILLAGE_FACILITY_COLLECT",
		"cooldown_key": "VILLAGE_FACILITY_COOLDOWN_FMT",
		"collect_done_key": "VILLAGE_FACILITY_COLLECT_DONE_FMT",
		"map_slots": ["Quarry", "quarry"],
		"fallback_x_mult": 0.66,
		"npc_strip": "miner",
		"collect_cooldown_sec": 50.0,
		"resource_collect": true,
	},
	{
		"id": "lumberyard",
		"name_key": "VILLAGE_LUMBERYARD_NAME",
		"hint_key": "VILLAGE_LUMBERYARD_INTERACT_HINT",
		"collect_key": "VILLAGE_FACILITY_COLLECT",
		"cooldown_key": "VILLAGE_FACILITY_COOLDOWN_FMT",
		"collect_done_key": "VILLAGE_FACILITY_COLLECT_DONE_FMT",
		"map_slots": ["lumberyard", "Lumberyard"],
		"fallback_x_mult": 0.63,
		"npc_strip": "woodcutter",
		"collect_cooldown_sec": 50.0,
		"resource_collect": true,
	},
	{
		"id": "well",
		"name_key": "VILLAGE_WELL_NAME",
		"hint_key": "VILLAGE_WELL_INTERACT_HINT",
		"map_slots": ["Water", "water", "well"],
		"fallback_x_mult": 0.11,
		"village_interact": "well",
	},
	{
		"id": "farm",
		"name_key": "VILLAGE_FARM_NAME",
		"hint_key": "VILLAGE_FARM_INTERACT_HINT",
		"map_slots": ["Farmer", "farmer", "farm"],
		"fallback_x_mult": 0.16,
		"village_interact": "farmer",
	},
]

## 新村莊地圖（New Village.tmx）— 200×15 tiles × 16px，場景內再 ×1.5
const VILLAGE_MAP_PATH := "res://assets/Maps/New Village.tmx"
const VILLAGE_MAP_TILES := Vector2i(200, 15)
const VILLAGE_MAP_TILE_PX := 16
const VILLAGE_MAP_SCALE := 1.5
## 村莊內角色貼圖額外放大（乘在角色表／造型 scale 上；不影響戰鬥）
const VILLAGE_CHARACTER_SCALE_MULT := 1.4
## 村莊內碰撞與地圖阻擋半徑倍率（乘在角色表 body_radius 上）
const VILLAGE_BODY_RADIUS_MULT := 1.25

## 村莊常駐 NPC 物件名（解救後於地圖標記點生成）
const VILLAGE_MAP_BLACKSMITH_SLOTS: Array[String] = [
	"Blacksmith", "blacksmith", "smith",
]
const VILLAGE_MAP_MERCHANT_SLOTS: Array[String] = [
	"Grocer", "grocer", "item", "merchant", "Merchant",
]
const VILLAGE_MAP_HOME_P1_SLOTS: Array[String] = ["Home1", "home1", "HouseSlot1"]
const VILLAGE_MAP_HOME_P2_SLOTS: Array[String] = ["Home2", "home2", "HouseSlot2"]
const VILLAGE_MAP_ENTRANCE_SLOTS: Array[String] = ["entrance", "Entrance", "ENTRANCE"]
const VILLAGE_MAP_TAVERN_DOOR_SLOTS: Array[String] = ["Tavern Door", "TavernDoor", "tavern_door"]
const VILLAGE_MAP_FLOOR_SLOTS: Array[String] = ["Floor", "floor", "Ground", "ground"]

## 酒館室內地圖（Tavern.tmx）— 50×25 tiles × 16px，場景內再 ×1.5
const TAVERN_MAP_PATH := "res://assets/Maps/Tavern.tmx"
const TAVERN_MAP_TILES := Vector2i(50, 25)
const TAVERN_MAP_TILE_PX := 16
const TAVERN_MAP_SCALE := 1.5
const TAVERN_MAP_ENTER_SLOTS: Array[String] = ["Enter", "enter", "Exit", "exit"]
const TAVERN_MAP_STAIR_UP_SLOTS: Array[String] = ["UP", "up"]
const TAVERN_MAP_STAIR_DOWN_SLOTS: Array[String] = ["DOWN", "down"]
const TAVERN_MAP_FLOOR_1F_SLOTS: Array[String] = ["Floor", "floor"]
const TAVERN_MAP_FLOOR_2F_SLOTS: Array[String] = ["2F Floor", "2F_Floor", "2f floor", "2f_floor"]

## 酒館常駐 NPC（解救酒館老闆後常駐；廚師同步開放）
const TAVERN_PERMANENT_NPCS: Array[Dictionary] = [
	{
		"id": "tavern_owner",
		"strip_id": "tavern_keeper",
		"name_key": "VILLAGE_TAVERN_OWNER_NAME",
		"map_slots": ["Tavern Keeper", "TavernKeeper", "tavern_keeper"],
		"requires_rescued": "tavern_owner",
	},
	{
		"id": "chef",
		"strip_id": "chef",
		"name_key": "VILLAGE_TAVERN_CHEF_NAME",
		"subtitle_key": "VILLAGE_TAVERN_CHEF_PERSONAL_NAME",
		"map_slots": ["Chef", "chef"],
		"requires_rescued": "tavern_owner",
		"dialogue_keys": [
			"TAVERN_CHEF_DIALOG_1",
			"TAVERN_CHEF_DIALOG_2",
		],
	},
]

## 傍晚來酒館社交的 NPC（對應 Tavern.tmx 物件名）
const TAVERN_SOCIAL_NPCS: Array[Dictionary] = [
	{
		"id": "headman",
		"strip_id": "headman",
		"name_key": "VILLAGE_HEADMAN_NAME",
		"subtitle_key": "VILLAGE_HEADMAN_PERSONAL_NAME",
		"map_slots": ["Village Head", "VillageHead", "village_head"],
		"dialogue_keys": [
			"VILLAGE_HEADMAN_DIALOG_1",
			"VILLAGE_HEADMAN_DIALOG_2",
			"VILLAGE_HEADMAN_DIALOG_3",
		],
		"talk_kind": "headman",
	},
	{
		"id": "merchant",
		"strip_id": "merchant",
		"name_key": "VILLAGE_MERCHANT_NAME",
		"subtitle_key": "VILLAGE_MERCHANT_PERSONAL_NAME",
		"map_slots": ["Shopkeeper", "shopkeeper"],
		"requires_rescued": "merchant",
		"dialogue_keys": [
			"TAVERN_SOCIAL_MERCHANT_DIALOG_1",
			"TAVERN_SOCIAL_MERCHANT_DIALOG_2",
		],
	},
	{
		"id": "miner",
		"strip_id": "miner",
		"name_key": "VILLAGE_QUARRY_NAME",
		"map_slots": ["Miner", "miner"],
		"requires_facility": "quarry",
		"dialogue_keys": [
			"TAVERN_SOCIAL_MINER_DIALOG_1",
			"TAVERN_SOCIAL_MINER_DIALOG_2",
		],
	},
	{
		"id": "blacksmith",
		"strip_id": "blacksmith_tavern",
		"name_key": "VILLAGE_BLACKSMITH_NAME",
		"subtitle_key": "VILLAGE_BLACKSMITH_PERSONAL_NAME",
		"map_slots": ["Smith", "smith"],
		"requires_rescued": "blacksmith",
		"dialogue_keys": [
			"BLACKSMITH_DIALOG_1",
			"BLACKSMITH_DIALOG_2",
			"BLACKSMITH_DIALOG_3",
		],
	},
	{
		"id": "bard_1",
		"strip_id": "bard",
		"anim_row": 0,
		"name_key": "VILLAGE_BARD_NAME",
		"subtitle_key": "VILLAGE_BARD1_PERSONAL_NAME",
		"map_slots": ["Bard1", "bard1"],
		"dialogue_keys": [
			"VILLAGE_BARD1_DIALOG_1",
			"VILLAGE_BARD1_DIALOG_2",
			"VILLAGE_BARD1_DIALOG_3",
		],
	},
	{
		"id": "bard_2",
		"strip_id": "bard",
		"anim_row": 1,
		"name_key": "VILLAGE_BARD_NAME",
		"subtitle_key": "VILLAGE_BARD2_PERSONAL_NAME",
		"map_slots": ["Bard2", "bard2"],
		"dialogue_keys": [
			"VILLAGE_BARD2_DIALOG_1",
			"VILLAGE_BARD2_DIALOG_2",
			"VILLAGE_BARD2_DIALOG_3",
		],
	},
	{
		"id": "farmer",
		"strip_id": "farmer",
		"name_key": "VILLAGE_FARMER_NAME",
		"subtitle_key": "VILLAGE_FARMER_PERSONAL_NAME",
		"map_slots": ["Farmer", "farmer"],
		"requires_facility": "farm",
		"dialogue_keys": [
			"TAVERN_SOCIAL_FARMER_DIALOG_1",
			"TAVERN_SOCIAL_FARMER_DIALOG_2",
		],
	},
	{
		"id": "woodcutter",
		"strip_id": "woodcutter",
		"name_key": "VILLAGE_LUMBERYARD_NAME",
		"map_slots": ["Woodcutter", "woodcutter"],
		"requires_facility": "lumberyard",
		"dialogue_keys": [
			"TAVERN_SOCIAL_WOODCUTTER_DIALOG_1",
			"TAVERN_SOCIAL_WOODCUTTER_DIALOG_2",
		],
	},
	{
		"id": "traveler_1",
		"strip_id": "traveler_1",
		"name_key": "VILLAGE_TRAVELER_1_NAME",
		"subtitle_key": "VILLAGE_TRAVELER_1_PERSONAL_NAME",
		"map_slots": ["Traveler", "Traveler1", "traveler", "traveler1"],
		"requires_traveler_today": 1,
		"dialogue_keys": [
			"TAVERN_TRAVELER_1_DIALOG_1",
			"TAVERN_TRAVELER_1_DIALOG_2",
		],
	},
	{
		"id": "traveler_2",
		"strip_id": "traveler_2",
		"name_key": "VILLAGE_TRAVELER_2_NAME",
		"subtitle_key": "VILLAGE_TRAVELER_2_PERSONAL_NAME",
		"map_slots": ["Traveler", "Traveler2", "traveler", "traveler2"],
		"requires_traveler_today": 2,
		"dialogue_keys": [
			"TAVERN_TRAVELER_2_DIALOG_1",
			"TAVERN_TRAVELER_2_DIALOG_2",
		],
	},
	{
		"id": "traveler_3",
		"strip_id": "traveler_3",
		"name_key": "VILLAGE_TRAVELER_3_NAME",
		"subtitle_key": "VILLAGE_TRAVELER_3_PERSONAL_NAME",
		"map_slots": ["Traveler", "Traveler3", "traveler", "traveler3"],
		"requires_traveler_today": 3,
		"dialogue_keys": [
			"TAVERN_TRAVELER_3_DIALOG_1",
			"TAVERN_TRAVELER_3_DIALOG_2",
		],
	},
	{
		"id": "traveler_4",
		"strip_id": "traveler_4",
		"name_key": "VILLAGE_TRAVELER_4_NAME",
		"subtitle_key": "VILLAGE_TRAVELER_4_PERSONAL_NAME",
		"map_slots": ["Traveler", "Traveler4", "traveler", "traveler4"],
		"requires_traveler_today": 4,
		"dialogue_keys": [
			"TAVERN_TRAVELER_4_DIALOG_1",
			"TAVERN_TRAVELER_4_DIALOG_2",
		],
	},
]


func get_tavern_permanent_npc(npc_id: String) -> Dictionary:
	for entry in TAVERN_PERMANENT_NPCS:
		if String(entry.get("id", "")) == npc_id:
			return entry
	return {}


func get_tavern_social_npc(npc_id: String) -> Dictionary:
	for entry in TAVERN_SOCIAL_NPCS:
		if String(entry.get("id", "")) == npc_id:
			return entry
	return {}


func is_tavern_open_for_entry(phase: String) -> bool:
	return phase != "night"


func is_tavern_social_hours(phase: String) -> bool:
	return phase == "evening"


func tavern_npc_available(entry: Dictionary) -> bool:
	if entry.is_empty():
		return false
	var req_rescued: String = String(entry.get("requires_rescued", ""))
	if req_rescued != "" and not GameState.is_npc_rescued(req_rescued):
		return false
	var req_facility: String = String(entry.get("requires_facility", ""))
	if req_facility != "" and not GameState.is_village_facility_unlocked(req_facility):
		return false
	var req_traveler: int = int(entry.get("requires_traveler_today", 0))
	if req_traveler > 0 and GameState.tavern_traveler_today != req_traveler:
		return false
	return true


func tavern_social_npc_available(entry: Dictionary) -> bool:
	return tavern_npc_available(entry)


## 村莊 NPC 橫向 sprite strip（單列 hframes 循環待機）
const VILLAGE_NPC_STRIPS: Dictionary = {
	"blacksmith": {
		"strip": GANDALF_NPC_ROOT + "Blacksmith.png",
		"hframes": 5,
		"fps": 6.0,
	},
	"blacksmith_tavern": {
		"strip": GANDALF_NPC_ROOT + "Blacksmith_Tavern.png",
		"hframes": 5,
		"fps": 6.0,
	},
	"merchant": {
		"strip": GANDALF_NPC_ROOT + "Grocer.png",
		"hframes": 5,
		"fps": 6.0,
	},
	"rune_master": {
		"strip": GANDALF_NPC_ROOT + "Runemaster.png",
		"hframes": 5,
		"fps": 6.0,
	},
	"farmer": {
		"strip": GANDALF_NPC_ROOT + "Farmer.png",
		"hframes": 5,
		"fps": 6.0,
	},
	"miner": {
		"strip": GANDALF_NPC_ROOT + "Miner.png",
		"hframes": 5,
		"fps": 6.0,
	},
	"woodcutter": {
		"strip": GANDALF_NPC_ROOT + "Woodcutter.png",
		"hframes": 5,
		"fps": 6.0,
	},
	"headman": {
		"strip": GANDALF_NPC_ROOT + "Headman.png",
		"hframes": 5,
		"fps": 6.0,
	},
	"bard": {
		"strip": GANDALF_NPC_ROOT + "Bard.png",
		"hframes": 5,
		"vframes": 2,
		"fps": 6.0,
	},
	"tavern_keeper": {
		"strip": GANDALF_NPC_ROOT + "Tavern Keeper.png",
		"hframes": 5,
		"fps": 6.0,
	},
	"chef": {
		"strip": GANDALF_NPC_ROOT + "Chef.png",
		"hframes": 5,
		"fps": 6.0,
	},
	"traveler_1": {
		"strip": GANDALF_NPC_ROOT + "Traveler1_Apprentice Alchemist_.png",
		"hframes": 5,
		"fps": 6.0,
	},
	"traveler_2": {
		"strip": GANDALF_NPC_ROOT + "Traveler2_Pirte.png",
		"hframes": 5,
		"fps": 6.0,
	},
	"traveler_3": {
		"strip": GANDALF_NPC_ROOT + "Traveler3_SwordsWoman.png",
		"hframes": 5,
		"fps": 6.0,
	},
	"traveler_4": {
		"strip": GANDALF_NPC_ROOT + "Traveler4_Black Market Dealer.png",
		"hframes": 5,
		"fps": 6.0,
	},
}


func get_village_npc_strip_def(strip_id: String) -> Dictionary:
	if strip_id == "":
		return {}
	return VILLAGE_NPC_STRIPS.get(strip_id, {})


## 村莊常駐 NPC（無需解救，進村即顯示）
const VILLAGE_ALWAYS_NPCS: Array[Dictionary] = [
	{
		"id": "headman",
		"strip_id": "headman",
		"name_key": "VILLAGE_HEADMAN_NAME",
		"subtitle_key": "VILLAGE_HEADMAN_PERSONAL_NAME",
		"map_slots": ["Headman", "headman"],
		"dialogue_keys": [
			"VILLAGE_HEADMAN_DIALOG_1",
			"VILLAGE_HEADMAN_DIALOG_2",
			"VILLAGE_HEADMAN_DIALOG_3",
		],
		"active_phases": ["day"],
	},
	{
		"id": "bard_1",
		"strip_id": "bard",
		"anim_row": 0,
		"name_key": "VILLAGE_BARD_NAME",
		"subtitle_key": "VILLAGE_BARD1_PERSONAL_NAME",
		"map_slots": ["Bard1", "bard1"],
		"dialogue_keys": [
			"VILLAGE_BARD1_DIALOG_1",
			"VILLAGE_BARD1_DIALOG_2",
			"VILLAGE_BARD1_DIALOG_3",
		],
		"active_phases": ["day"],
	},
	{
		"id": "bard_2",
		"strip_id": "bard",
		"anim_row": 1,
		"name_key": "VILLAGE_BARD_NAME",
		"subtitle_key": "VILLAGE_BARD2_PERSONAL_NAME",
		"map_slots": ["Bard2", "bard2"],
		"dialogue_keys": [
			"VILLAGE_BARD2_DIALOG_1",
			"VILLAGE_BARD2_DIALOG_2",
			"VILLAGE_BARD2_DIALOG_3",
		],
		"active_phases": ["day"],
	},
]


func get_village_always_npc(npc_id: String) -> Dictionary:
	for entry in VILLAGE_ALWAYS_NPCS:
		if String(entry.get("id", "")) == npc_id:
			return entry
	return {}


## 村莊 NPC 稱號下的本名（npc_id → 翻譯鍵）
const VILLAGE_NPC_SUBTITLE_KEYS: Dictionary = {
	"blacksmith": "VILLAGE_BLACKSMITH_PERSONAL_NAME",
	"merchant": "VILLAGE_MERCHANT_PERSONAL_NAME",
	"rune_master": "VILLAGE_RUNE_MASTER_PERSONAL_NAME",
	"farmer": "VILLAGE_FARMER_PERSONAL_NAME",
	"headman": "VILLAGE_HEADMAN_PERSONAL_NAME",
	"bard_1": "VILLAGE_BARD1_PERSONAL_NAME",
	"bard_2": "VILLAGE_BARD2_PERSONAL_NAME",
}


func tr_village_npc_subtitle(npc_id: String) -> String:
	var key: String = String(VILLAGE_NPC_SUBTITLE_KEYS.get(npc_id, ""))
	return tr(key) if key != "" else ""

const VILLAGE_RESCUED_NPC_MARKERS: Array[Dictionary] = [
	{
		"npc_id": "tavern_owner",
		"name_key": "VILLAGE_TAVERN_OWNER_NAME",
		"map_slots": ["Tavern Keeper", "TavernKeeper", "tavern_keeper"],
	},
	{
		"npc_id": "rune_master",
		"name_key": "VILLAGE_RUNE_MASTER_NAME",
		"subtitle_key": "VILLAGE_RUNE_MASTER_PERSONAL_NAME",
		"map_slots": ["RuneMaster", "Rune Master", "runemaster"],
	},
	{
		"npc_id": "farmer",
		"name_key": "VILLAGE_FARMER_NAME",
		"subtitle_key": "VILLAGE_FARMER_PERSONAL_NAME",
		"map_slots": ["Farmer", "farmer"],
	},
]


func village_map_pixel_size() -> Vector2:
	return map_pixel_size(VILLAGE_MAP_TILES, VILLAGE_MAP_TILE_PX, VILLAGE_MAP_SCALE)


func tavern_map_pixel_size() -> Vector2:
	return map_pixel_size(TAVERN_MAP_TILES, TAVERN_MAP_TILE_PX, TAVERN_MAP_SCALE)


func map_pixel_size(tiles: Vector2i, tile_px: int, scale: float) -> Vector2:
	return Vector2(
		float(tiles.x * tile_px) * scale,
		float(tiles.y * tile_px) * scale,
	)


func village_scaled_body_radius(base_radius: float) -> float:
	return clampf(base_radius * VILLAGE_BODY_RADIUS_MULT, 8.0, 160.0)


func get_rescue_npc_def(npc_id: String) -> Dictionary:
	return RESCUE_NPCS.get(npc_id, {})


func tr_rescue_npc_name(npc_id: String) -> String:
	var def: Dictionary = get_rescue_npc_def(npc_id)
	if def.is_empty():
		return npc_id
	return tr_field(def, "name", false)


func get_village_facility_def(facility_id: String) -> Dictionary:
	for f in VILLAGE_FACILITIES:
		if String(f.get("id", "")) == facility_id:
			return f
	return {}


## 村莊「資源」分頁四種基礎素材：木工場／礦場額外收取（機率受通關進度影響；戰鬥仍會掉落）
const VILLAGE_BASE_RESOURCE_IDS: Array[String] = ["wood", "stone", "iron", "copper"]

const VILLAGE_FACILITY_RESOURCE_IDS: Dictionary = {
	"lumberyard": ["wood", "sacred_wood", "tree_sap"],
	"quarry": ["stone", "iron", "copper", "silver", "gold_ore"],
}

## 通關對應關卡後，該資源才會進入收取權重池
const VILLAGE_RESOURCE_UNLOCK_STAGE: Dictionary = {
	"wood": "slime_forest",
	"stone": "slime_forest",
	"iron": "crimson_marsh",
	"copper": "crimson_marsh",
	"silver": "dwarf_gold_mine",
	"gold_ore": "dwarf_gold_mine",
	"sacred_wood": "fae_ancient_grove",
	"tree_sap": "fae_ancient_grove",
}

const VILLAGE_RESOURCE_BASE_WEIGHT: Dictionary = {
	"wood": 100.0,
	"stone": 100.0,
	"iron": 50.0,
	"copper": 44.0,
	"silver": 35.0,
	"gold_ore": 22.0,
	"sacred_wood": 35.0,
	"tree_sap": 28.0,
}


func is_village_base_resource(mat_id: String) -> bool:
	return VILLAGE_BASE_RESOURCE_IDS.has(mat_id)


func stage_index(stage_id: String) -> int:
	for i in range(STAGES.size()):
		if String(STAGES[i].get("id", "")) == stage_id:
			return i
	return -1


func highest_completed_stage_index(completed_stage_ids: Array[String]) -> int:
	var hi: int = -1
	for sid in completed_stage_ids:
		var idx: int = stage_index(String(sid))
		if idx > hi:
			hi = idx
	return hi


func village_resource_collect_weight(
		mat_id: String,
		facility_id: String,
		completed_stage_ids: Array[String]) -> float:
	var pool: Variant = VILLAGE_FACILITY_RESOURCE_IDS.get(facility_id, [])
	if not (pool is Array) or not (pool as Array).has(mat_id):
		return 0.0
	var unlock_stage: String = String(VILLAGE_RESOURCE_UNLOCK_STAGE.get(mat_id, ""))
	if unlock_stage == "":
		return 0.0
	var unlock_idx: int = stage_index(unlock_stage)
	if unlock_idx < 0:
		return 0.0
	var hi: int = highest_completed_stage_index(completed_stage_ids)
	if hi < unlock_idx:
		return 0.0
	var w: float = float(VILLAGE_RESOURCE_BASE_WEIGHT.get(mat_id, 40.0))
	var bonus_stages: int = hi - unlock_idx
	w *= 1.0 + 0.14 * float(bonus_stages)
	return w


func village_resource_amount_range(
		mat_id: String,
		completed_stage_ids: Array[String]) -> Vector2i:
	var unlock_stage: String = String(VILLAGE_RESOURCE_UNLOCK_STAGE.get(mat_id, ""))
	var unlock_idx: int = stage_index(unlock_stage)
	var hi: int = highest_completed_stage_index(completed_stage_ids)
	var tier: int = maxi(0, hi - unlock_idx)
	var mn: int = 2 + tier
	var mx: int = 4 + tier * 2
	if mat_id == "wood" or mat_id == "stone":
		mn = 3 + tier
		mx = 5 + tier * 2
	return Vector2i(mn, mx)


func roll_village_facility_collect(
		facility_id: String,
		completed_stage_ids: Array[String]) -> Dictionary:
	var pool: Variant = VILLAGE_FACILITY_RESOURCE_IDS.get(facility_id, [])
	if not (pool is Array):
		return {}
	var weights: Dictionary = {}
	var total: float = 0.0
	for raw_id in pool:
		var mid: String = String(raw_id)
		var w: float = village_resource_collect_weight(mid, facility_id, completed_stage_ids)
		if w <= 0.0:
			continue
		weights[mid] = w
		total += w
	if total <= 0.0 or weights.is_empty():
		return {}
	var roll: float = randf() * total
	var pick: String = ""
	for mid in weights.keys():
		roll -= float(weights[mid])
		if roll <= 0.0:
			pick = mid
			break
	if pick == "":
		var keys: Array = weights.keys()
		pick = String(keys[keys.size() - 1])
	var band: Vector2i = village_resource_amount_range(pick, completed_stage_ids)
	var amount: int = randi_range(band.x, band.y)
	return {pick: amount}


func village_facility_resource_odds_lines(
		facility_id: String,
		completed_stage_ids: Array[String]) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var pool: Variant = VILLAGE_FACILITY_RESOURCE_IDS.get(facility_id, [])
	if not (pool is Array):
		return lines
	var weights: Dictionary = {}
	var total: float = 0.0
	for raw_id in pool:
		var mid: String = String(raw_id)
		var w: float = village_resource_collect_weight(mid, facility_id, completed_stage_ids)
		if w <= 0.0:
			continue
		weights[mid] = w
		total += w
	if total <= 0.0:
		lines.append(tr("VILLAGE_RESOURCE_ODDS_LOCKED"))
		return lines
	var ordered: Array[String] = []
	for raw_id in pool:
		var mid: String = String(raw_id)
		if weights.has(mid):
			ordered.append(mid)
	for mid in ordered:
		var pct: int = int(round(float(weights[mid]) / total * 100.0))
		var band: Vector2i = village_resource_amount_range(mid, completed_stage_ids)
		lines.append(tr("VILLAGE_RESOURCE_ODDS_LINE_FMT") % [
			tr_material_name(mid), pct, band.x, band.y])
	return lines


func stage_rescue_npc_id(stage: Dictionary) -> String:
	if stage.has("rescue_npc"):
		return String(stage["rescue_npc"])
	if bool(stage.get("rescue_blacksmith", false)):
		return "blacksmith"
	if bool(stage.get("rescue_merchant", false)):
		return "merchant"
	return ""


func stage_victory_unlock_facility_ids(stage: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var raw: Variant = stage.get("victory_unlock_facilities", [])
	if raw is Array:
		for item in raw:
			var fid: String = String(item)
			if fid != "" and not out.has(fid):
				out.append(fid)
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


func format_stage_event_armament_book_line(armament_id: String, show_obtained: bool) -> String:
	var name: String = tr_armament_name(armament_id)
	if not show_obtained:
		return tr("STAGE_SELECT_ARMAMENT_BOOK_LINE_FMT") % name
	if GameState.has_armament_recipe(armament_id):
		return tr("STAGE_SELECT_ARMAMENT_BOOK_LINE_OBTAINED_FMT") % name
	return tr("STAGE_SELECT_ARMAMENT_BOOK_LINE_MISSING_FMT") % name


func format_stage_event_armament_books_block(stage_id: String, show_obtained: bool = true) -> String:
	var pool: Array[String] = stage_event_armament_book_ids(stage_id)
	if pool.is_empty():
		return ""
	var lines: PackedStringArray = PackedStringArray([tr("STAGE_SELECT_ARMAMENT_BOOKS_HEADER")])
	for aid in pool:
		lines.append(format_stage_event_armament_book_line(aid, show_obtained))
	return "\n".join(lines)


func format_all_stages_armament_books_hint() -> String:
	var lines: PackedStringArray = PackedStringArray([tr("CODEX_ARMAMENT_BOOKS_BY_STAGE_HEADER")])
	for stage in STAGES:
		var pool: Array[String] = stage_event_armament_book_ids(String(stage.get("id", "")))
		if pool.is_empty():
			continue
		var names: PackedStringArray = PackedStringArray()
		for aid in pool:
			names.append(tr_armament_name(aid))
		lines.append(tr("CODEX_ARMAMENT_BOOKS_STAGE_LINE_FMT") % [tr_name(stage), ", ".join(names)])
	return "\n".join(lines)


func format_armament_recipe_source_hint(armament_id: String) -> String:
	var stage_names: PackedStringArray = PackedStringArray()
	for stage in STAGES:
		var sid: String = String(stage.get("id", ""))
		var pool: Array[String] = stage_event_armament_book_ids(sid)
		if armament_id in pool:
			stage_names.append(tr_name(stage))
	if stage_names.is_empty():
		return tr("CODEX_LOCKED_ARMAMENT_RECIPE_HINT")
	return tr("CODEX_ARMAMENT_BOOK_SOURCE_FMT") % ", ".join(stage_names)


## 掃描貼圖中非透明像素範圍（避免逐幀 PNG 留白導致對齊錯誤）。
func visible_texture_region(tex: Texture2D, source_rect: Rect2 = Rect2(), padding: int = 2) -> Rect2:
	if tex == null:
		return source_rect
	var full := Rect2(0, 0, tex.get_width(), tex.get_height())
	if source_rect.size == Vector2.ZERO:
		source_rect = full
	var img: Image = tex.get_image()
	if img == null:
		return source_rect
	var x0: int = clampi(int(floor(source_rect.position.x)), 0, img.get_width() - 1)
	var y0: int = clampi(int(floor(source_rect.position.y)), 0, img.get_height() - 1)
	var x1: int = clampi(int(ceil(source_rect.end.x)), x0 + 1, img.get_width())
	var y1: int = clampi(int(ceil(source_rect.end.y)), y0 + 1, img.get_height())
	var min_x: int = x1
	var min_y: int = y1
	var max_x: int = x0
	var max_y: int = y0
	for y in range(y0, y1):
		for x in range(x0, x1):
			if img.get_pixel(x, y).a > 0.02:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x + 1)
				max_y = maxi(max_y, y + 1)
	if min_x >= max_x or min_y >= max_y:
		return source_rect
	min_x = maxi(x0, min_x - padding)
	min_y = maxi(y0, min_y - padding)
	max_x = mini(x1, max_x + padding)
	max_y = mini(y1, max_y + padding)
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)


func trim_preview_texture(tex: Texture2D) -> Dictionary:
	if tex == null:
		return {"texture": null, "w": 1.0, "h": 1.0}
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		var reg: Rect2 = visible_texture_region(at.atlas, at.region)
		var out := AtlasTexture.new()
		out.atlas = at.atlas
		out.region = reg
		return {"texture": out, "w": reg.size.x, "h": reg.size.y}
	var pw: float = float(maxi(1, tex.get_width()))
	var ph: float = float(maxi(1, tex.get_height()))
	var reg2: Rect2 = visible_texture_region(tex, Rect2(0.0, 0.0, pw, ph))
	var out2 := AtlasTexture.new()
	out2.atlas = tex
	out2.region = reg2
	return {"texture": out2, "w": reg2.size.x, "h": reg2.size.y}


func resolve_character_preview_source_texture(cdef: Dictionary) -> Texture2D:
	if cdef.is_empty():
		return null
	if cdef.has("sprite_frames") and cdef["sprite_frames"] is Dictionary:
		return sprite_frames_first_texture((cdef["sprite_frames"] as Dictionary).get("idle", null))
	if cdef.has("sprite_strips") and cdef["sprite_strips"] is Dictionary:
		var strips: Dictionary = cdef["sprite_strips"]
		var preview_key: String = String(cdef.get("preview_strip", "idle"))
		if not strips.has(preview_key):
			preview_key = "idle"
		if not strips.has(preview_key):
			return null
		var atlas: Texture2D = load(String(strips[preview_key])) as Texture2D
		if atlas == null:
			return null
		var hf: int = maxi(1, int(cdef.get("strip_hframes", 8)))
		if cdef.has("strip_hframes_by_strip") and cdef["strip_hframes_by_strip"] is Dictionary \
				and (cdef["strip_hframes_by_strip"] as Dictionary).has(preview_key):
			hf = maxi(1, int((cdef["strip_hframes_by_strip"] as Dictionary)[preview_key]))
		var vf: int = maxi(1, int(cdef.get("vframes", 1)))
		var prow: int = clampi(int(cdef.get("preview_row", cdef.get("row_idle", 0))), 0, vf - 1)
		var pcol: int = clampi(int(cdef.get("preview_col", 0)), 0, hf - 1)
		var fw: int = maxi(1, atlas.get_width() / hf)
		var fh: int = maxi(1, atlas.get_height() / vf)
		var trim_t: int = clampi(int(cdef.get("preview_trim_top", 14)), 0, fh - 4)
		var trim_b: int = clampi(int(cdef.get("preview_trim_bottom", 1)), 0, fh - trim_t - 4)
		var trim_l: int = clampi(int(cdef.get("preview_trim_left", 4)), 0, fw - 4)
		var trim_r: int = clampi(int(cdef.get("preview_trim_right", 4)), 0, fw - trim_l - 4)
		var cell_at := AtlasTexture.new()
		cell_at.atlas = atlas
		cell_at.region = Rect2(
			float(pcol * fw + trim_l),
			float(prow * fh + trim_t),
			maxf(1.0, float(fw - trim_l - trim_r)),
			maxf(1.0, float(fh - trim_t - trim_b)))
		return cell_at
	if cdef.has("sprite") and String(cdef["sprite"]) != "":
		var sheet: Texture2D = load(String(cdef["sprite"])) as Texture2D
		if sheet == null:
			return null
		var hf2: int = maxi(1, int(cdef.get("hframes", 1)))
		var vf2: int = maxi(1, int(cdef.get("vframes", 1)))
		var prow2: int = clampi(int(cdef.get("preview_row", cdef.get("row_idle", 0))), 0, vf2 - 1)
		var pcol2: int = clampi(int(cdef.get("preview_col", 0)), 0, hf2 - 1)
		var fw2: int = maxi(1, sheet.get_width() / hf2)
		var fh2: int = maxi(1, sheet.get_height() / vf2)
		var trim_t2: int = clampi(int(cdef.get("preview_trim_top", 14)), 0, fh2 - 4)
		var trim_b2: int = clampi(int(cdef.get("preview_trim_bottom", 1)), 0, fh2 - trim_t2 - 4)
		var trim_l2: int = clampi(int(cdef.get("preview_trim_left", 4)), 0, fw2 - 4)
		var trim_r2: int = clampi(int(cdef.get("preview_trim_right", 4)), 0, fw2 - trim_l2 - 4)
		var cell_at2 := AtlasTexture.new()
		cell_at2.atlas = sheet
		cell_at2.region = Rect2(
			float(pcol2 * fw2 + trim_l2),
			float(prow2 * fh2 + trim_t2),
			maxf(1.0, float(fw2 - trim_l2 - trim_r2)),
			maxf(1.0, float(fh2 - trim_t2 - trim_b2)))
		return cell_at2
	return null


func layout_character_preview_texture_rect(
		prev: TextureRect,
		src_w: float,
		src_h: float,
		scale_mul: float = 1.0,
		offset_y: float = 0.0) -> void:
	if prev == null:
		return
	var parent: Control = prev.get_parent() as Control
	if parent == null:
		return
	var pw: float = parent.size.x
	var ph: float = parent.size.y
	if pw <= 0.0 or ph <= 0.0:
		pw = float(parent.custom_minimum_size.x)
		ph = float(parent.custom_minimum_size.y)
	if pw <= 0.0 or ph <= 0.0:
		pw = 144.0
		ph = 144.0
	var avail_w: float = pw * 0.94
	var avail_h: float = ph * 0.94
	var fit_scale: int = maxi(1, mini(int(avail_w / src_w), int(avail_h / src_h)))
	var min_fill: float = 0.86
	var want_h: float = avail_h * min_fill
	if src_h > 0.0 and src_h * float(fit_scale) < want_h:
		fit_scale = maxi(fit_scale, int(ceil(want_h / src_h)))
	if scale_mul > 0.0:
		fit_scale = maxi(1, int(round(float(fit_scale) * scale_mul)))
	var disp_w: float = src_w * float(fit_scale)
	var disp_h: float = src_h * float(fit_scale)
	prev.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	prev.size = Vector2(disp_w, disp_h)
	prev.position = Vector2((pw - disp_w) * 0.5, (ph - disp_h) * 0.5 + offset_y)
	prev.stretch_mode = TextureRect.STRETCH_SCALE
	prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE


func apply_character_preview_to_rect(prev: TextureRect, cdef: Dictionary) -> void:
	if prev == null:
		return
	if cdef.is_empty():
		prev.texture = null
		prev.visible = false
		return
	var src: Texture2D = resolve_character_preview_source_texture(cdef)
	if src == null:
		prev.texture = null
		prev.visible = false
		return
	var trimmed: Dictionary = trim_preview_texture(src)
	prev.texture = trimmed["texture"]
	if trimmed["texture"] == null:
		prev.visible = false
		return
	prev.modulate = cdef.get("tint", Color.WHITE)
	prev.visible = true
	prev.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	prev.flip_h = bool(cdef.get("sprite_faces_left", false))
	layout_character_preview_texture_rect(
		prev,
		float(trimmed["w"]),
		float(trimmed["h"]),
		float(cdef.get("preview_scale", 1.0)),
		float(cdef.get("preview_feet_fine_y", 0.0)))


## 讓 Sprite2D（centered）腳底落在 body_radius 圓心下方。
func sprite_feet_offset_y(tex: Texture2D, body_radius: float, sprite_scale: float, fine_offset_y: float = 0.0) -> float:
	if tex == null:
		return fine_offset_y
	var vis: Rect2 = visible_texture_region(tex)
	var tex_h: float = float(maxi(1, tex.get_height()))
	var foot_from_center: float = (vis.position.y + vis.size.y) - tex_h * 0.5
	return body_radius - foot_from_center * sprite_scale + fine_offset_y


## 橫向 strip：依第一格可見像素，讓腳底對齊錨點 local Y（feet_anchor_y）。
func sprite_strip_feet_offset_y(
		tex: Texture2D,
		hframes: int,
		target_height: float,
		feet_anchor_y: float,
		frame_index: int = 0,
		fine_offset_y: float = 0.0,
		vframes: int = 1,
		anim_row: int = 0,
) -> float:
	if tex == null:
		return feet_anchor_y + fine_offset_y
	var hf: int = maxi(1, hframes)
	var vf: int = maxi(1, vframes)
	var frame_w: float = float(tex.get_width()) / float(hf)
	var frame_h: float = float(maxi(1, tex.get_height())) / float(vf)
	var fx: float = float(clampi(frame_index, 0, hf - 1)) * frame_w
	var fy: float = float(clampi(anim_row, 0, vf - 1)) * frame_h
	var vis: Rect2 = visible_texture_region(tex, Rect2(fx, fy, frame_w, frame_h))
	# vis 為全圖座標；腳底須換算成當前列內 Y 再與列中心比較（vframes>1 時否則會浮空）
	var foot_y_in_row: float = (vis.position.y + vis.size.y) - fy
	var foot_from_center: float = foot_y_in_row - frame_h * 0.5
	var sc: float = target_height / frame_h
	return feet_anchor_y - foot_from_center * sc + fine_offset_y


func apply_icon_button(btn: Button, icon_path: String, fallback_text: String = "") -> void:
	btn.text = ""
	btn.expand_icon = true
	if icon_path != "" and ResourceLoader.exists(icon_path, "Texture2D"):
		btn.icon = ResourceLoader.load(icon_path, "Texture2D") as Texture2D
	elif fallback_text != "":
		btn.text = fallback_text
		btn.icon = null


func resolve_frame_texture(entry: Variant) -> Texture2D:
	if entry is Texture2D:
		return entry
	if entry is String:
		var path: String = String(entry)
		if path == "":
			return null
		if ResourceLoader.exists(path, "Texture2D"):
			return ResourceLoader.load(path, "Texture2D") as Texture2D
		return load(path) as Texture2D
	return null


func sprite_frames_first_texture(entry: Variant) -> Texture2D:
	if entry is Array:
		var arr: Array = entry
		if arr.is_empty():
			return null
		return resolve_frame_texture(arr[0])
	if entry is Dictionary:
		var paths: Array = _resolve_frame_paths_dict(entry)
		if paths.is_empty():
			return null
		return resolve_frame_texture(paths[0])
	return null


func _resolve_frame_paths_dict(entry: Dictionary) -> Array:
	var pat: String = String(entry.get("pattern", ""))
	var cnt: int = int(entry.get("count", 0))
	var start: int = int(entry.get("start", 1))
	if pat == "" or cnt <= 0:
		return []
	var out: Array = []
	for i in range(cnt):
		out.append(pat.replace("{i}", str(start + i)))
	return out


func _sheet_row_has_pixel(img: Image, y: int, width: int) -> bool:
	for x in range(width):
		if img.get_pixel(x, y).a > 0.02:
			return true
	return false


func get_sprite_sheet_row_bands(sheet_path: String) -> Array:
	if _sprite_sheet_row_bands_cache.has(sheet_path):
		return _sprite_sheet_row_bands_cache[sheet_path]
	var bands: Array = []
	var tex: Texture2D = load(sheet_path) as Texture2D
	if tex == null:
		return bands
	var img: Image = tex.get_image()
	if img == null:
		return bands
	var w: int = img.get_width()
	var h: int = img.get_height()
	var y: int = 0
	while y < h:
		while y < h and not _sheet_row_has_pixel(img, y, w):
			y += 1
		if y >= h:
			break
		var y0: int = y
		while y < h and _sheet_row_has_pixel(img, y, w):
			y += 1
		bands.append({"y": y0, "h": y - y0})
	_sprite_sheet_row_bands_cache[sheet_path] = bands
	return bands


func _build_sprite_sheet_row_frames(
		tex: Texture2D,
		row_1based: int,
		frame_count: int,
		bands: Array,
		spec: Dictionary = {},
) -> Array:
	var out: Array = []
	if tex == null or frame_count <= 0:
		return out
	var fixed_w: int = int(spec.get("frame_w", 0))
	var fixed_h: int = int(spec.get("frame_h", 0))
	if fixed_w > 0 and fixed_h > 0:
		var row_y: float = float(row_1based - 1) * float(fixed_h)
		for i in range(frame_count):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(float(i * fixed_w), row_y, float(fixed_w), float(fixed_h))
			out.append(at)
		return out
	var row_idx: int = row_1based - 1
	if row_idx < 0 or row_idx >= bands.size():
		return out
	var band: Dictionary = bands[row_idx]
	var row_y_auto: float = float(band.get("y", 0))
	var row_h_auto: float = float(maxi(1, int(band.get("h", 1))))
	var sheet_w: float = float(tex.get_width())
	var frame_w_auto: float = sheet_w / float(frame_count)
	for i in range(frame_count):
		var at2 := AtlasTexture.new()
		at2.atlas = tex
		at2.region = Rect2(frame_w_auto * float(i), row_y_auto, frame_w_auto, row_h_auto)
		out.append(at2)
	return out


func get_sprite_sheet_anim_frames(sheet_id: String) -> Dictionary:
	var spec: Dictionary = {}
	if sheet_id == "warrior":
		spec = WARRIOR_SPRITE_SHEET
	if spec.is_empty():
		return {}
	var cache_key: String = "%s|%d|%d" % [
		sheet_id, int(spec.get("frame_w", 0)), int(spec.get("frame_h", 0)),
	]
	if _sprite_sheet_anim_frames_cache.has(cache_key):
		return _sprite_sheet_anim_frames_cache[cache_key]
	var sheet_path: String = String(spec.get("sheet", ""))
	var tex: Texture2D = load(sheet_path) as Texture2D
	if tex == null:
		return {}
	var bands: Array = []
	if int(spec.get("frame_w", 0)) <= 0 or int(spec.get("frame_h", 0)) <= 0:
		bands = get_sprite_sheet_row_bands(sheet_path)
	var anims: Dictionary = spec.get("anims", {})
	var out: Dictionary = {}
	for anim_key in anims:
		var adef: Dictionary = anims[anim_key]
		var rows: Array = adef.get("rows", [])
		var counts: Array = adef.get("frames", [])
		var merged: Array = []
		for ri in range(rows.size()):
			var row_n: int = int(rows[ri])
			var fc: int = int(counts[ri]) if ri < counts.size() else 0
			for frame_tex in _build_sprite_sheet_row_frames(tex, row_n, fc, bands, spec):
				merged.append(frame_tex)
		if not merged.is_empty():
			out[anim_key] = merged
	_sprite_sheet_anim_frames_cache[cache_key] = out
	return out


func _normalize_res_dir(dir: String) -> String:
	var p: String = String(dir).strip_edges().replace("\\", "/")
	if not p.begins_with("res://"):
		p = "res://" + p.trim_prefix("/")
	if not p.ends_with("/"):
		p += "/"
	return p


func _res_path_join(dir_path: String, entry: String) -> String:
	var name: String = String(entry).strip_edges().replace("\\", "/")
	if name.begins_with("res://"):
		return name
	return dir_path + name.trim_prefix("/")


func _list_dreamir_png_paths(subdir: String, recursive: bool = false) -> Array:
	return _list_png_paths_in_dir(subdir, recursive)


## 列出資料夾內 PNG（網頁匯出優先 ResourceLoader；編輯器可 fallback DirAccess）
func _list_png_paths_in_dir(dir: String, recursive: bool = false) -> Array:
	var paths: Array = []
	var dir_path: String = _normalize_res_dir(dir)
	_collect_png_paths_resource_loader(dir_path, recursive, paths)
	if paths.is_empty():
		_collect_png_paths_diraccess(dir_path, recursive, paths)
	paths.sort()
	return paths


func _collect_png_paths_resource_loader(dir_path: String, recursive: bool, paths: Array) -> void:
	var listed: PackedStringArray = ResourceLoader.list_directory(dir_path)
	for entry in listed:
		var name: String = String(entry).strip_edges().replace("\\", "/")
		if name.is_empty() or name.begins_with("."):
			continue
		if name.ends_with("/"):
			if recursive:
				_collect_png_paths_resource_loader(dir_path + name, true, paths)
			continue
		var full: String = _res_path_join(dir_path, name)
		if full.to_lower().ends_with(".png"):
			paths.append(full)


func _collect_png_paths_diraccess(dir_path: String, recursive: bool, paths: Array) -> void:
	var da := DirAccess.open(dir_path)
	if da == null:
		return
	da.list_dir_begin()
	var fn := da.get_next()
	while fn != "":
		if fn == "." or fn == ".." or fn.begins_with("."):
			fn = da.get_next()
			continue
		var full: String = dir_path.path_join(fn)
		if da.current_is_dir():
			if recursive:
				_collect_png_paths_diraccess(_normalize_res_dir(full), true, paths)
		elif fn.to_lower().ends_with(".png"):
			paths.append(full)
		fn = da.get_next()
	da.list_dir_end()


func get_dreamir_sprite_frames(char_id: String) -> Dictionary:
	if _dreamir_sprite_frames_cache.has(char_id):
		return _dreamir_sprite_frames_cache[char_id]
	var spec: Dictionary = DREAMIR_CHARACTER_ANIMS.get(char_id, {})
	if spec.is_empty():
		return {}
	var folder: String = String(spec.get("folder", ""))
	var anims: Dictionary = spec.get("anims", {})
	if folder == "" or anims.is_empty():
		return {}
	var out: Dictionary = {}
	for anim_key in anims:
		var sub: String = String(anims[anim_key])
		var subdir: String = DREAMIR_CHAR_ROOT.path_join(folder).path_join(sub)
		var frames: Array = _list_dreamir_png_paths(subdir)
		if not frames.is_empty():
			out[anim_key] = frames
	_dreamir_sprite_frames_cache[char_id] = out
	return out


func get_fire_knight_sprite_frames() -> Dictionary:
	return get_chierit_sprite_frames(FIRE_KNIGHT_ROOT, FIRE_KNIGHT_ANIM_FOLDERS, "fire_knight")


func _character_def_with_visuals(c: Dictionary) -> Dictionary:
	var id: String = String(c.get("id", ""))
	if id == "":
		return c
	var needs_dup: bool = DREAMIR_CHARACTER_ANIMS.has(id) or String(c.get("sprite_sheet", "")) != ""
	if not needs_dup:
		return c
	var d: Dictionary = c.duplicate(true)
	if DREAMIR_CHARACTER_ANIMS.has(id):
		var dreamir_frames: Dictionary = get_dreamir_sprite_frames(id)
		if not dreamir_frames.is_empty():
			d["sprite_frames"] = dreamir_frames
	var sheet_id: String = String(d.get("sprite_sheet", ""))
	if sheet_id != "":
		var sheet_frames: Dictionary = get_sprite_sheet_anim_frames(sheet_id)
		if not sheet_frames.is_empty():
			d["sprite_frames"] = sheet_frames
	return d


func get_character_def(id: String) -> Dictionary:
	for c in CHARACTERS:
		if c["id"] == id:
			return _character_def_with_visuals(c)
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
		"name": "破綻印記", "name_key": "PASSIVE_SWORD_AURA_RESONANCE_NAME",
		"desc": "使敵人陷入異常或破綻狀態時，為自身技能量表填充一段；觸發後 5 秒內不會再次因本被動充能。",
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
	{
		"id": "blade_aura",
		"name": "刃氣充盈", "name_key": "PASSIVE_BLADE_AURA_NAME",
		"desc": "碎刃命中敵人每累積 10 次，為自身技能量表填充一段；觸發後 5 秒內不會再次因本被動充能。",
		"desc_key": "PASSIVE_BLADE_AURA_DESC",
		"icon": "res://assets/icons/passives/blade_aura.png",
		"params": {
			"hits_per_fill": 10,
			"meter_fill": 28.0,
			"passive_fill_cd": 5.0,
		},
	},
	{
		"id": "blood_frenzy",
		"name": "嗜血衝動", "name_key": "PASSIVE_BLOOD_FRENZY_NAME",
		"desc": "每擊殺一名敵人疊加一層狂熱（最多 5 層），每層提升攻速 8%；各層獨立計時 3 秒衰退，不刷新。",
		"desc_key": "PASSIVE_BLOOD_FRENZY_DESC",
		"icon": "res://assets/icons/passives/blood_frenzy.png",
		"params": {
			"max_stacks": 5,
			"rate_per_stack": 0.08,
			"stack_duration": 3.0,
		},
	},
	{
		"id": "ignition",
		"name": "引爆本能", "name_key": "PASSIVE_IGNITION_NAME",
		"desc": "火焰武器命中已燃燒的敵人時，觸發小爆炸，對以該敵人為中心 3 格範圍造成 ATK×0.6 傷害（同一敵人 3 秒 CD）；每觸發 5 次爆炸為技能量表填充 25 點。",
		"desc_key": "PASSIVE_IGNITION_DESC",
		"icon": "res://assets/icons/passives/ignition.png",
		"params": {
			"explosion_radius": 72.0,
			"explosion_damage_mult": 0.6,
			"enemy_cd": 3.0,
			"explosions_per_fill": 5,
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
	{
		"id": "heavenly_judgment",
		"name": "天降重罰", "name_key": "SKILL_HEAVENLY_JUDGMENT_NAME",
		"desc": "戰鬥：升空 3 秒內選點落下，範圍傷害並暈眩；逾時則原地落下。\n彈珠台：垂直落砸摧毀路徑彈針；落入獎勵本場不再出現，本回合無獎勵（最多 3 次）。",
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
			"combat_rise_time": 0.45,
			"combat_fall_time": 0.32,
			"combat_landing_iframe": 0.35,
			"combat_air_offset_y": 180.0,
			"pinball_gravity_mult": 3.0,
			"pinball_destroy_limit": 3,
		},
	},
	{
		"id": "mirror_moon",
		"name": "影襲", "name_key": "SKILL_MIRROR_MOON_NAME",
		"desc": "戰鬥：向前方疾衝刺殺造成傷害，並在原地留下會持續攻擊的殘影，持續 3 秒。\n彈珠台：將目前未摧毀的獎勵區間重抽，優先抽換目前獎勵區沒有的獎勵，並保留倍率。",
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
	{
		"id": "mushin",
		"name": "無我", "name_key": "SKILL_MUSHIN_NAME",
		"desc": "戰鬥：進入無我之境持續 5 秒：碎刃旋轉速度 ×2、全武器攻速 +40%；期間受傷不中斷狀態。\n彈珠台：彈珠進入殘影模式，本次落下過程中所有碰針得分翻倍。",
		"desc_key": "SKILL_MUSHIN_DESC",
		"cooldown": 14.0,
		"icon": "res://assets/icons/skills/mushin.png",
		"params": {
			"combat_duration": 5.0,
			"combat_spin_mult": 2.0,
			"combat_rate_mult": 1.4,
			"pinball_score_mult": 2.0,
		},
	},
	{
		"id": "blood_shroud",
		"name": "血霧籠罩", "name_key": "SKILL_BLOOD_SHROUD_NAME",
		"desc": "戰鬥：釋放血霧持續 5 秒，每 0.5 秒對周圍敵人造成 ATK×0.8 傷害並施加流血，傷害量的 30% 回復 HP；期間移動速度 -50%。\n彈珠台：隨機 4～6 顆彈針變成血針，彈珠碰到血針得分 ×2 並獲得 1 層血包，血針消失。集滿 5 層血包換取復活機會（20% HP）。",
		"desc_key": "SKILL_BLOOD_SHROUD_DESC",
		"cooldown": 12.0,
		"icon": "res://assets/icons/skills/blood_shroud.png",
		"params": {
			"combat_radius": 200.0,
			"combat_damage_mult": 0.8,
			"combat_tick_interval": 0.5,
			"combat_duration": 5.0,
			"combat_heal_ratio": 0.3,
			"combat_speed_mult": 0.5,
			"combat_bleed_dps_ratio": 0.15,
			"pinball_peg_count_min": 4,
			"pinball_peg_count_max": 6,
			"pinball_score_mult": 2.0,
		},
	},
	{
		"id": "flame_burst",
		"name": "炎爆", "name_key": "SKILL_FLAME_BURST_NAME",
		"desc": "戰鬥：朝前方投擲炸彈，外圈（8 格）施加燃燒，內圈（4 格）造成 ATK×5 傷害並擊退；持有焰氣 5 層時施放必定爆擊（×2 傷害）。\n彈珠台：隨機 4～6 顆彈針變成炎針，彈珠碰到炎針得分 ×2 並獲得 1 層焰氣，炎針消失。集滿 5 層焰氣換取下次戰鬥技能必定爆擊。",
		"desc_key": "SKILL_FLAME_BURST_DESC",
		"cooldown": 13.0,
		"icon": "res://assets/icons/skills/flame_burst.png",
		"params": {
			"combat_range": 280.0,
			"combat_inner_radius": 96.0,
			"combat_outer_radius": 192.0,
			"combat_damage_mult": 5.0,
			"combat_min_damage": 60.0,
			"combat_push": 80.0,
			"combat_boost_crit_mult": 2.0,
			"pinball_peg_count_min": 4,
			"pinball_peg_count_max": 6,
			"pinball_score_mult": 2.0,
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


func load_weapon_icon(weapon_id: String) -> Texture2D:
	if weapon_id == "":
		return null
	var w: Dictionary = get_weapon_def(weapon_id)
	return _load_icon_safe(String(w.get("icon", "")))


func load_armament_icon(armament_id: String) -> Texture2D:
	if armament_id == "" or armament_id == "none":
		return null
	return _load_icon_safe(armament_icon_path(armament_id))


## 彈珠台底部獎勵格圖示（武器／通用強化；金幣等無圖則回 null）
func pinball_reward_icon(reward: Dictionary) -> Texture2D:
	var rtype: String = String(reward.get("type", "noop"))
	var rid: String = String(reward.get("id", ""))
	match rtype:
		"weapon", "weapon_up":
			return load_weapon_icon(rid)
		"common":
			return load_common_upgrade_icon(rid)
		_:
			return null


func load_common_upgrade_icon(upgrade_id: String) -> Texture2D:
	if upgrade_id == "":
		return null
	var u: Dictionary = get_common_upgrade_def(upgrade_id)
	return _load_icon_safe(String(u.get("icon", "")))


func common_upgrade_icon_path(upgrade_id: String) -> String:
	if upgrade_id == "":
		return ""
	var path: String = COMMON_ICON_ROOT + upgrade_id + ".png"
	if ResourceLoader.exists(path):
		return path
	return ""


## 武器升級項 → 通用能力圖示（無對應則回空，UI 改顯示文字名稱）
func weapon_upgrade_common_icon_id(upgrade_id: String) -> String:
	match upgrade_id:
		"w_damage":
			return "c_atk"
		"w_rate":
			return "c_cooldown"
		"w_range":
			return "c_pickup"
		"w_count":
			return "c_w_count"
		_:
			return ""


func weapon_icon_bbcode(weapon_id: String, size: int = ARMAMENT_STAT_ICON_SIZE) -> String:
	var path: String = weapon_icon_path(weapon_id)
	if path == "" or not ResourceLoader.exists(path):
		return ""
	return "[img=%dx%d]%s[/img]" % [size, size, path]


func format_weapon_name_bbcode(weapon_id: String, size: int = ARMAMENT_STAT_ICON_SIZE) -> String:
	var icon: String = weapon_icon_bbcode(weapon_id, size)
	var wname: String = tr_weapon_name(weapon_id)
	if icon != "":
		return "%s %s" % [icon, wname]
	return wname


func armament_icon_path(armament_id: String) -> String:
	if armament_id == "" or armament_id == "none":
		return ""
	var from_def: String = String(get_armament_def(armament_id).get("icon", ""))
	if from_def != "":
		return from_def
	var path: String = ARMAMENT_ICON_ROOT + armament_id + ".png"
	if ResourceLoader.exists(path, "Texture2D"):
		return path
	return ""


func armament_icon_bbcode(
		armament_id: String,
		size: int = ARMAMENT_STAT_ICON_SIZE,
		link_meta: bool = false) -> String:
	var path: String = armament_icon_path(armament_id)
	if path == "":
		return ""
	var img: String = "[img=%dx%d]%s[/img]" % [size, size, path]
	if link_meta:
		return "[url=armament:%s]%s[/url]" % [armament_id, img]
	return img


func format_armament_name_bbcode(armament_id: String, size: int = ARMAMENT_STAT_ICON_SIZE) -> String:
	if armament_id == "" or armament_id == "none":
		return tr("CSEL_NONE")
	var icon: String = armament_icon_bbcode(armament_id, size)
	var aname: String = tr_armament_name(armament_id)
	if icon != "":
		return "%s %s" % [icon, aname]
	return aname


func format_weapon_upgrade_label_bbcode(upgrade_id: String, size: int = ARMAMENT_STAT_ICON_SIZE) -> String:
	var icon: String = common_upgrade_icon_bbcode(weapon_upgrade_common_icon_id(upgrade_id), size)
	if icon != "":
		return icon
	var udef: Dictionary = get_weapon_upgrade_def(upgrade_id)
	return tr_name(udef) if not udef.is_empty() else upgrade_id


func format_common_upgrade_label_bbcode(common_id: String, size: int = ARMAMENT_STAT_ICON_SIZE) -> String:
	var icon: String = common_upgrade_icon_bbcode(common_id, size)
	if icon != "":
		return icon
	var cdef: Dictionary = get_common_upgrade_def(common_id)
	return tr_name(cdef) if not cdef.is_empty() else common_id


func weapon_icon_path(weapon_id: String) -> String:
	if weapon_id == "":
		return ""
	var from_def: String = String(get_weapon_def(weapon_id).get("icon", ""))
	if from_def != "":
		return from_def
	var path: String = WEAPON_ICON_ROOT + weapon_id + ".png"
	if ResourceLoader.exists(path):
		return path
	return ""


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
# 鍛造素材／資源／農產（物品分頁用 category）
# ====================================================
const MAT_CATEGORY_FORGING := "forging"
const MAT_CATEGORY_RESOURCE := "resource"
const MAT_CATEGORY_SEED := "seed"
const MAT_CATEGORY_CROP := "crop"

const MATERIALS: Array[Dictionary] = [
	{"id": "wood", "name": "木頭", "name_key": "MAT_WOOD_NAME", "category": MAT_CATEGORY_RESOURCE},
	{"id": "stone", "name": "石頭", "name_key": "MAT_STONE_NAME", "category": MAT_CATEGORY_RESOURCE},
	{"id": "iron", "name": "鐵", "name_key": "MAT_IRON_NAME", "category": MAT_CATEGORY_RESOURCE},
	{"id": "copper", "name": "銅", "name_key": "MAT_COPPER_NAME", "category": MAT_CATEGORY_RESOURCE},
	{"id": "bone", "name": "骨頭", "name_key": "MAT_BONE_NAME", "category": MAT_CATEGORY_FORGING},
	{"id": "rag", "name": "破布", "name_key": "MAT_RAG_NAME", "category": MAT_CATEGORY_FORGING},
	{"id": "silver", "name": "銀", "name_key": "MAT_SILVER_NAME", "category": MAT_CATEGORY_RESOURCE},
	{"id": "gold_ore", "name": "金", "name_key": "MAT_GOLD_ORE_NAME", "category": MAT_CATEGORY_RESOURCE},
	{"id": "gunpowder", "name": "火藥", "name_key": "MAT_GUNPOWDER_NAME", "category": MAT_CATEGORY_FORGING},
	{"id": "sacred_wood", "name": "神木", "name_key": "MAT_SACRED_WOOD_NAME", "category": MAT_CATEGORY_RESOURCE},
	{"id": "glow_dust", "name": "光粉", "name_key": "MAT_GLOW_DUST_NAME", "category": MAT_CATEGORY_FORGING},
	{"id": "tree_sap", "name": "樹液", "name_key": "MAT_TREE_SAP_NAME", "category": MAT_CATEGORY_RESOURCE},
	{"id": "flame_scale", "name": "炎鱗", "name_key": "MAT_FLAME_SCALE_NAME", "category": MAT_CATEGORY_FORGING},
	{"id": "obsidian", "name": "黑曜石", "name_key": "MAT_OBSIDIAN_NAME", "category": MAT_CATEGORY_RESOURCE},
	{"id": "venom", "name": "毒液", "name_key": "MAT_VENOM_NAME", "category": MAT_CATEGORY_FORGING},
	{"id": "wheat_seed", "name": "小麥種", "name_key": "MAT_WHEAT_SEED_NAME", "category": MAT_CATEGORY_SEED},
	{"id": "carrot_seed", "name": "胡蘿蔔種", "name_key": "MAT_CARROT_SEED_NAME", "category": MAT_CATEGORY_SEED},
	{"id": "potato_seed", "name": "馬鈴薯種", "name_key": "MAT_POTATO_SEED_NAME", "category": MAT_CATEGORY_SEED},
	{"id": "wheat", "name": "小麥", "name_key": "MAT_WHEAT_NAME", "category": MAT_CATEGORY_CROP},
	{"id": "carrot", "name": "胡蘿蔔", "name_key": "MAT_CARROT_NAME", "category": MAT_CATEGORY_CROP},
	{"id": "potato", "name": "馬鈴薯", "name_key": "MAT_POTATO_NAME", "category": MAT_CATEGORY_CROP},
]

## 農田：7 格（Crops1～Crops7），每格可播種、澆水、收成
const FARM_PLOT_COUNT := 7
const VILLAGE_WATER_MAX_CHARGES := 4

const FARM_CROPS: Array[Dictionary] = [
	{
		"id": "wheat",
		"seed_id": "wheat_seed",
		"stages_to_mature": 3,
		"name_key": "CROP_WHEAT_NAME",
		"seed_name_key": "MAT_WHEAT_SEED_NAME",
	},
	{
		"id": "carrot",
		"seed_id": "carrot_seed",
		"stages_to_mature": 3,
		"name_key": "CROP_CARROT_NAME",
		"seed_name_key": "MAT_CARROT_SEED_NAME",
	},
	{
		"id": "potato",
		"seed_id": "potato_seed",
		"stages_to_mature": 3,
		"name_key": "CROP_POTATO_NAME",
		"seed_name_key": "MAT_POTATO_SEED_NAME",
	},
]

const FARMER_SEED_PRICES: Dictionary = {
	"wheat_seed": 10,
	"carrot_seed": 14,
	"potato_seed": 18,
}

## 物品介面分頁 id
const ITEMS_TAB_CURRENCY := "currency"
const ITEMS_TAB_CROPS := "crops"
const ITEMS_TAB_RESOURCES := "resources"
const ITEMS_TAB_FORGING := "forging"
const ITEMS_TAB_ARMAMENTS := "armaments"
const ITEMS_TAB_RUNES := "runes"

const ITEMS_TABS: Array[Dictionary] = [
	{"id": ITEMS_TAB_CURRENCY, "label_key": "ITEMS_TAB_CURRENCY"},
	{"id": ITEMS_TAB_CROPS, "label_key": "ITEMS_TAB_CROPS"},
	{"id": ITEMS_TAB_RESOURCES, "label_key": "ITEMS_TAB_RESOURCES"},
	{"id": ITEMS_TAB_FORGING, "label_key": "ITEMS_TAB_FORGING"},
	{"id": ITEMS_TAB_ARMAMENTS, "label_key": "ITEMS_TAB_ARMAMENTS"},
	{"id": ITEMS_TAB_RUNES, "label_key": "ITEMS_TAB_RUNES"},
]


func get_material_def(id: String) -> Dictionary:
	for m in MATERIALS:
		if m["id"] == id:
			return m
	return {}


func material_category(mat_id: String) -> String:
	var def: Dictionary = get_material_def(mat_id)
	return String(def.get("category", MAT_CATEGORY_FORGING))


func materials_in_category(category: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in MATERIALS:
		if String(m.get("category", MAT_CATEGORY_FORGING)) == category:
			out.append(m)
	return out


func get_farm_crop_def(crop_id: String) -> Dictionary:
	for c in FARM_CROPS:
		if String(c.get("id", "")) == crop_id:
			return c
	return {}


func farm_crop_for_seed(seed_id: String) -> Dictionary:
	for c in FARM_CROPS:
		if String(c.get("seed_id", "")) == seed_id:
			return c
	return {}


func farm_plot_map_slot_name(slot_index: int) -> String:
	return "Crops%d" % clampi(slot_index, 1, FARM_PLOT_COUNT)


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
# 敵人池（分關卡：史萊姆 / 獸人 / 不死 / 矮人 / 精靈 / 蜥蜴人）
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

# 第四關池：矮人（圖檔：`assets/enemy/Dwarfs/<id>.png`，32px 格線同獸人）
const ENEMY_POOL_DWARF: Array[Dictionary] = [
	{"id": "dwarf_miner", "name_key": "ENEMY_DWARF_MINER_NAME",
		"tex": "res://assets/enemy/Dwarfs/dwarf_miner.png",
		"tier": 0, "elite": false, "boss": false, "hframes": 6, "vframes": 6,
		"frames_per_row": [4, 6, 3, 4, 2, 4], "scale": 1.52, "radius": 24.0, "offset_y": -11,
		"hp_mult": 1.05, "dmg_mult": 1.02, "speed_mult": 1.0, "xp_mult": 1.08, "defense": 0.02,
		"material_drops": [
			{"id": "silver", "chance": 0.14, "min": 1, "max": 1},
		]},
	{"id": "dwarf_gunner", "name_key": "ENEMY_DWARF_GUNNER_NAME",
		"tex": "res://assets/enemy/Dwarfs/dwarf_gunner.png",
		"tier": 1, "elite": false, "boss": false, "hframes": 6, "vframes": 6,
		"frames_per_row": [4, 6, 3, 4, 2, 4], "scale": 1.5, "radius": 23.0, "offset_y": -11,
		"hp_mult": 0.98, "dmg_mult": 0.92, "speed_mult": 0.92, "xp_mult": 1.12, "defense": 0.0,
		"ranged": {"kind": "line", "range": 360.0, "min_range": 100.0, "width": 40.0,
			"windup": 0.88, "cooldown": 4.2, "damage_mult": 0.82},
		"material_drops": [
			{"id": "gunpowder", "chance": 0.12, "min": 1, "max": 1},
			{"id": "silver", "chance": 0.06, "min": 1, "max": 1},
		]},
	{"id": "dwarf_bomber", "name_key": "ENEMY_DWARF_BOMBER_NAME",
		"tex": "res://assets/enemy/Dwarfs/dwarf_bomber.png",
		"tier": 2, "elite": false, "boss": false, "hframes": 6, "vframes": 7,
		"frames_per_row": [4, 6, 3, 4, 2, 4, 6], "scale": 1.48, "radius": 23.0, "offset_y": -11,
		"hp_mult": 1.1, "dmg_mult": 1.0, "speed_mult": 0.9, "xp_mult": 1.2, "defense": 0.0,
		"ranged": {"kind": "bomb", "range": 340.0, "min_range": 70.0, "aoe_radius": 92.0,
			"windup": 1.15, "cooldown": 5.0, "damage_mult": 0.95},
		"material_drops": [
			{"id": "gunpowder", "chance": 0.16, "min": 1, "max": 2},
		]},
	{"id": "dwarf_shieldguard", "name_key": "ENEMY_DWARF_SHIELDGUARD_NAME",
		"tex": "res://assets/enemy/Dwarfs/dwarf_shieldguard.png",
		"tier": 3, "elite": true, "boss": false, "hframes": 6, "vframes": 7,
		"frames_per_row": [4, 6, 3, 4, 2, 4, 6], "scale": 1.65, "radius": 32.0, "offset_y": -11,
		"hp_mult": 2.1, "dmg_mult": 1.05, "speed_mult": 0.78, "xp_mult": 1.38, "defense": 0.14,
		"material_drops": [
			{"id": "silver", "chance": 0.12, "min": 1, "max": 2},
			{"id": "gold_ore", "chance": 0.06, "min": 1, "max": 1},
		]},
	{"id": "dwarf_axeman", "name_key": "ENEMY_DWARF_AXEMAN_NAME",
		"tex": "res://assets/enemy/Dwarfs/dwarf_axeman.png",
		"tier": 4, "elite": false, "boss": false, "hframes": 6, "vframes": 7,
		"frames_per_row": [4, 6, 3, 4, 2, 4, 6], "scale": 1.58, "radius": 28.0, "offset_y": -11,
		"hp_mult": 1.65, "dmg_mult": 1.32, "speed_mult": 0.94, "xp_mult": 1.45, "defense": 0.05,
		"melee_aoe": {"radius": 76.0, "damage_mult": 0.68},
		"material_drops": [
			{"id": "gold_ore", "chance": 0.10, "min": 1, "max": 1},
			{"id": "gunpowder", "chance": 0.08, "min": 1, "max": 1},
		]},
	{"id": "boss_dwarf_hammer_lord", "name_key": "ENEMY_BOSS_DWARF_HAMMER_LORD_NAME",
		"tex": "res://assets/enemy/Dwarfs/boss_dwarf_hammer_lord.png",
		"tier": 99, "elite": true, "boss": true, "stage_boss": true,
		"hframes": 6, "vframes": 9, "frames_per_row": [4, 6, 3, 4, 2, 4, 6, 6, 6],
		"scale": 3.2, "radius": 86.0, "offset_y": -12,
		"hp_mult": 34.0, "dmg_mult": 4.8, "speed_mult": 0.6, "xp_mult": 28.0, "defense": 0.12,
		"melee_aoe": {"radius": 118.0, "damage_mult": 0.82},
		"material_drops": [
			{"id": "silver", "chance": 0.24, "min": 2, "max": 5},
			{"id": "gold_ore", "chance": 0.22, "min": 2, "max": 5},
			{"id": "gunpowder", "chance": 0.18, "min": 2, "max": 4},
		]},
]

# 第五關池：森林精靈（圖檔：`assets/enemy/Fae/<id>.png`）
const ENEMY_POOL_FAE: Array[Dictionary] = [
	{"id": "fae_flash_sprite", "name_key": "ENEMY_FAE_FLASH_SPRITE_NAME",
		"tex": "res://assets/enemy/Fae/fae_flash_sprite.png",
		"tier": 0, "elite": false, "boss": false, "hframes": 6, "vframes": 6,
		"frames_per_row": [4, 6, 3, 4, 2, 4], "scale": 1.38, "radius": 20.0, "offset_y": -10,
		"hp_mult": 0.82, "dmg_mult": 0.72, "speed_mult": 1.32, "xp_mult": 1.06, "defense": 0.0,
		"sprite_modulate": Color(1.45, 1.5, 1.25),
		"hit_effects": {"slow": {"duration": 0.7, "factor": 0.45}},
		"material_drops": [
			{"id": "glow_dust", "chance": 0.15, "min": 1, "max": 1},
		]},
	{"id": "fae_horn_scout", "name_key": "ENEMY_FAE_HORN_SCOUT_NAME",
		"tex": "res://assets/enemy/Fae/fae_horn_scout.png",
		"tier": 1, "elite": false, "boss": false, "hframes": 6, "vframes": 6,
		"frames_per_row": [4, 6, 3, 4, 2, 4], "scale": 1.48, "radius": 22.0, "offset_y": -11,
		"hp_mult": 1.0, "dmg_mult": 1.08, "speed_mult": 1.28, "xp_mult": 1.14, "defense": 0.0,
		"material_drops": [
			{"id": "tree_sap", "chance": 0.13, "min": 1, "max": 1},
		]},
	{"id": "fae_forest_caster", "name_key": "ENEMY_FAE_FOREST_CASTER_NAME",
		"tex": "res://assets/enemy/Fae/fae_forest_caster.png",
		"tier": 2, "elite": false, "boss": false, "hframes": 6, "vframes": 7,
		"frames_per_row": [4, 6, 3, 4, 2, 4, 6], "scale": 1.46, "radius": 22.0, "offset_y": -11,
		"hp_mult": 1.05, "dmg_mult": 0.9, "speed_mult": 0.88, "xp_mult": 1.18, "defense": 0.0,
		"ranged": {"kind": "line", "range": 380.0, "min_range": 95.0, "width": 44.0,
			"windup": 1.0, "cooldown": 4.5, "damage_mult": 0.88},
		"material_drops": [
			{"id": "glow_dust", "chance": 0.11, "min": 1, "max": 2},
			{"id": "sacred_wood", "chance": 0.05, "min": 1, "max": 1},
		]},
	{"id": "fae_bloom_mage", "name_key": "ENEMY_FAE_BLOOM_MAGE_NAME",
		"tex": "res://assets/enemy/Fae/fae_bloom_mage.png",
		"tier": 3, "elite": true, "boss": false, "hframes": 6, "vframes": 7,
		"frames_per_row": [4, 6, 3, 4, 2, 4, 6], "scale": 1.5, "radius": 23.0, "offset_y": -11,
		"hp_mult": 1.15, "dmg_mult": 0.85, "speed_mult": 0.86, "xp_mult": 1.28, "defense": 0.02,
		"ranged": {"kind": "line", "range": 360.0, "min_range": 80.0, "width": 52.0,
			"windup": 1.05, "cooldown": 5.2, "damage_mult": 0.72,
			"hit_effects": {"slow": {"duration": 2.2, "factor": 0.38}, "stun": 0.28}},
		"material_drops": [
			{"id": "tree_sap", "chance": 0.14, "min": 1, "max": 2},
			{"id": "glow_dust", "chance": 0.08, "min": 1, "max": 1},
		]},
	{"id": "fae_pink_wing", "name_key": "ENEMY_FAE_PINK_WING_NAME",
		"tex": "res://assets/enemy/Fae/fae_pink_wing.png",
		"tier": 4, "elite": false, "boss": false, "hframes": 6, "vframes": 7,
		"frames_per_row": [4, 6, 3, 4, 2, 4, 6], "scale": 1.42, "radius": 21.0, "offset_y": -11,
		"hp_mult": 0.95, "dmg_mult": 0.8, "speed_mult": 1.12, "xp_mult": 1.32, "defense": 0.0,
		"ranged": {"kind": "bomb", "range": 320.0, "min_range": 60.0, "aoe_radius": 88.0,
			"windup": 0.95, "cooldown": 4.8, "damage_mult": 0.62,
			"hit_effects": {"knockback": 340.0}},
		"material_drops": [
			{"id": "glow_dust", "chance": 0.12, "min": 1, "max": 2},
		]},
	{"id": "boss_ancient_treant", "name_key": "ENEMY_BOSS_ANCIENT_TREANT_NAME",
		"tex": "res://assets/enemy/Fae/boss_ancient_treant.png",
		"tier": 99, "elite": true, "boss": true, "stage_boss": true,
		"hframes": 6, "vframes": 9, "frames_per_row": [4, 6, 3, 4, 2, 4, 6, 6, 6],
		"scale": 3.35, "radius": 90.0, "offset_y": -14,
		"hp_mult": 36.0, "dmg_mult": 4.6, "speed_mult": 0.52, "xp_mult": 30.0, "defense": 0.1,
		"ranged": {"kind": "bomb", "range": 420.0, "min_range": 90.0, "aoe_radius": 128.0,
			"windup": 1.25, "cooldown": 4.2, "damage_mult": 0.9,
			"hit_effects": {"slow": {"duration": 2.8, "factor": 0.32}, "stun": 0.45, "knockback": 180.0}},
		"material_drops": [
			{"id": "sacred_wood", "chance": 0.24, "min": 2, "max": 5},
			{"id": "glow_dust", "chance": 0.22, "min": 2, "max": 5},
			{"id": "tree_sap", "chance": 0.20, "min": 2, "max": 4},
		]},
]

# 第六關池：蜥蜴人（圖檔：`assets/enemy/Lizardman/<id>.png`）
const ENEMY_POOL_LIZARD: Array[Dictionary] = [
	{"id": "lizard_scout", "name_key": "ENEMY_LIZARD_SCOUT_NAME",
		"tex": "res://assets/enemy/Lizardman/lizard_scout.png",
		"tier": 0, "elite": false, "boss": false, "hframes": 6, "vframes": 6,
		"frames_per_row": [4, 6, 3, 4, 2, 4], "scale": 1.52, "radius": 24.0, "offset_y": -11,
		"hp_mult": 1.0, "dmg_mult": 1.0, "speed_mult": 1.02, "xp_mult": 1.08, "defense": 0.02,
		"material_drops": [
			{"id": "flame_scale", "chance": 0.14, "min": 1, "max": 1},
		]},
	{"id": "lizard_archer", "name_key": "ENEMY_LIZARD_ARCHER_NAME",
		"tex": "res://assets/enemy/Lizardman/lizard_archer.png",
		"tier": 1, "elite": false, "boss": false, "hframes": 6, "vframes": 6,
		"frames_per_row": [4, 6, 3, 4, 2, 4], "scale": 1.5, "radius": 23.0, "offset_y": -11,
		"hp_mult": 0.95, "dmg_mult": 0.88, "speed_mult": 0.9, "xp_mult": 1.12, "defense": 0.0,
		"ranged": {"kind": "line", "range": 370.0, "min_range": 100.0, "width": 38.0,
			"windup": 0.92, "cooldown": 4.0, "damage_mult": 0.78,
			"hit_effects": {"bleed": {"dps": 2.8, "duration": 3.6}}},
		"material_drops": [
			{"id": "venom", "chance": 0.12, "min": 1, "max": 1},
		]},
	{"id": "lizard_priest", "name_key": "ENEMY_LIZARD_PRIEST_NAME",
		"tex": "res://assets/enemy/Lizardman/lizard_priest.png",
		"tier": 2, "elite": false, "boss": false, "hframes": 6, "vframes": 7,
		"frames_per_row": [4, 6, 3, 4, 2, 4, 6], "scale": 1.48, "radius": 23.0, "offset_y": -11,
		"hp_mult": 1.08, "dmg_mult": 0.82, "speed_mult": 0.84, "xp_mult": 1.2, "defense": 0.0,
		"ranged": {"kind": "line", "range": 350.0, "min_range": 85.0, "width": 48.0,
			"windup": 1.1, "cooldown": 5.0, "damage_mult": 0.68,
			"hit_effects": {"slow": {"duration": 1.8, "factor": 0.5}}},
		"material_drops": [
			{"id": "obsidian", "chance": 0.10, "min": 1, "max": 1},
			{"id": "flame_scale", "chance": 0.06, "min": 1, "max": 1},
		]},
	{"id": "raptor_juvenile", "name_key": "ENEMY_RAPTOR_JUVENILE_NAME",
		"tex": "res://assets/enemy/Lizardman/raptor_juvenile.png",
		"tier": 3, "elite": false, "boss": false, "hframes": 6, "vframes": 7,
		"frames_per_row": [4, 6, 3, 4, 2, 4, 6], "scale": 1.55, "radius": 26.0, "offset_y": -10,
		"hp_mult": 1.12, "dmg_mult": 1.15, "speed_mult": 1.38, "xp_mult": 1.35, "defense": 0.0,
		"material_drops": [
			{"id": "flame_scale", "chance": 0.11, "min": 1, "max": 2},
		]},
	{"id": "lizard_blade_fighter", "name_key": "ENEMY_LIZARD_BLADE_FIGHTER_NAME",
		"tex": "res://assets/enemy/Lizardman/lizard_blade_fighter.png",
		"tier": 4, "elite": true, "boss": false, "hframes": 6, "vframes": 7,
		"frames_per_row": [4, 6, 3, 4, 2, 4, 6], "scale": 1.6, "radius": 28.0, "offset_y": -11,
		"hp_mult": 1.55, "dmg_mult": 1.38, "speed_mult": 1.08, "xp_mult": 1.48, "defense": 0.06,
		"material_drops": [
			{"id": "obsidian", "chance": 0.10, "min": 1, "max": 1},
			{"id": "venom", "chance": 0.08, "min": 1, "max": 1},
		]},
	{"id": "boss_lizard_berserker_chief", "name_key": "ENEMY_BOSS_LIZARD_BERSERKER_CHIEF_NAME",
		"tex": "res://assets/enemy/Lizardman/boss_lizard_berserker_chief.png",
		"tier": 99, "elite": true, "boss": true, "stage_boss": true,
		"hframes": 6, "vframes": 9, "frames_per_row": [4, 6, 3, 4, 2, 4, 6, 6, 6],
		"scale": 3.3, "radius": 88.0, "offset_y": -12,
		"hp_mult": 38.0, "dmg_mult": 5.0, "speed_mult": 0.58, "xp_mult": 32.0, "defense": 0.11,
		"melee_aoe": {"radius": 96.0, "damage_mult": 0.75},
		"summon_minions": {
			"interval": 8.5, "count": 2, "level_mult": 0.9,
			"enemy_ids": ["lizard_scout", "lizard_archer", "raptor_juvenile", "lizard_blade_fighter"],
		},
		"material_drops": [
			{"id": "flame_scale", "chance": 0.24, "min": 2, "max": 5},
			{"id": "obsidian", "chance": 0.22, "min": 2, "max": 5},
			{"id": "venom", "chance": 0.20, "min": 2, "max": 4},
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
		"victory_unlock_facilities": ["quarry"],
		"event_armament_books": ["stone_spear", "frost_amulet"],
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
		"rescue_merchant": true,
		"victory_unlock_facilities": ["lumberyard"],
		"random_event": true,
		"event_armament_books": ["copper_axe", "bone_staff", "shadow_blade", "crystal_bracelet"],
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
		"rescue_npc": "farmer",
		"victory_unlock_facilities": ["well", "farm"],
		"random_event": true,
		"event_armament_books": ["cloth_armor", "beast_bracer", "flame_sigil", "venom_belt"],
	},
	{
		"id": "dwarf_gold_mine",
		"name": "第四關 — 矮人金礦",
		"name_key": "STAGE_DWARF_GOLD_MINE_NAME",
		"map_path": "res://assets/Maps/TEST.tmx",
		"boss_id": "boss_dwarf_hammer_lord",
		"boss_time": 600.0,
		"boss_warning_time": 45.0,
		"difficulty_base": 4.0,
		"difficulty_seconds_per_tier": 36.0,
		"difficulty_scale": 1.28,
		"spawn_batch_mult": 1.35,
		"spawn_rate_mult": 1.2,
		"event_difficulty_bonus": 2.8,
		"boss_level_factor": 22.0,
		"enemy_pool": "dwarf",
		"material_drops": [
			{"id": "silver", "chance": 0.12, "min": 1, "max": 2},
			{"id": "gold_ore", "chance": 0.10, "min": 1, "max": 2},
			{"id": "gunpowder", "chance": 0.09, "min": 1, "max": 2},
		],
		"victory_gold": 900,
		"rescue_npc": "rune_master",
		"victory_notes": ["STAGE_QUARRY_UPGRADE_NOTE"],
		"random_event": true,
		"event_armament_books": ["thunder_cape", "holy_shield"],
	},
	{
		"id": "fae_ancient_grove",
		"name": "第五關 — 精靈古林",
		"name_key": "STAGE_FAE_ANCIENT_GROVE_NAME",
		"map_path": "res://assets/Maps/TEST.tmx",
		"boss_id": "boss_ancient_treant",
		"boss_time": 600.0,
		"boss_warning_time": 45.0,
		"difficulty_base": 5.2,
		"difficulty_seconds_per_tier": 34.0,
		"difficulty_scale": 1.35,
		"spawn_batch_mult": 1.42,
		"spawn_rate_mult": 1.25,
		"event_difficulty_bonus": 3.2,
		"boss_level_factor": 24.0,
		"enemy_pool": "fae",
		"material_drops": [
			{"id": "sacred_wood", "chance": 0.12, "min": 1, "max": 2},
			{"id": "glow_dust", "chance": 0.11, "min": 1, "max": 2},
			{"id": "tree_sap", "chance": 0.10, "min": 1, "max": 2},
		],
		"victory_gold": 1200,
		"rescue_npc": "tavern_owner",
		"victory_notes": ["STAGE_LUMBERYARD_UPGRADE_NOTE"],
		"random_event": true,
	},
	{
		"id": "lizard_volcanic_hollow",
		"name": "第六關 — 蜥蜴火山窟",
		"name_key": "STAGE_LIZARD_VOLCANIC_HOLLOW_NAME",
		"map_path": "res://assets/Maps/TEST.tmx",
		"boss_id": "boss_lizard_berserker_chief",
		"boss_time": 600.0,
		"boss_warning_time": 45.0,
		"difficulty_base": 6.4,
		"difficulty_seconds_per_tier": 32.0,
		"difficulty_scale": 1.4,
		"spawn_batch_mult": 1.48,
		"spawn_rate_mult": 1.28,
		"event_difficulty_bonus": 3.6,
		"boss_level_factor": 26.0,
		"enemy_pool": "lizard",
		"material_drops": [
			{"id": "flame_scale", "chance": 0.12, "min": 1, "max": 2},
			{"id": "obsidian", "chance": 0.11, "min": 1, "max": 2},
			{"id": "venom", "chance": 0.10, "min": 1, "max": 2},
		],
		"victory_gold": 1550,
		"victory_blacksmith_tier2": true,
		"random_event": true,
	},
]


func _enemy_pool_source(pool_id: String) -> Array[Dictionary]:
	match pool_id:
		"orc":
			return ENEMY_POOL_ORC
		"undead":
			return ENEMY_POOL_UNDEAD
		"dwarf":
			return ENEMY_POOL_DWARF
		"fae":
			return ENEMY_POOL_FAE
		"lizard":
			return ENEMY_POOL_LIZARD
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
	for s in ENEMY_POOL_DWARF:
		if s["id"] == id:
			return s
	for s in ENEMY_POOL_FAE:
		if s["id"] == id:
			return s
	for s in ENEMY_POOL_LIZARD:
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
	for pool in [ENEMY_POOL_SLIME, ENEMY_POOL_ORC, ENEMY_POOL_UNDEAD, ENEMY_POOL_DWARF, ENEMY_POOL_FAE, ENEMY_POOL_LIZARD]:
		for d in pool:
			var eid: String = String(d.get("id", ""))
			if eid.is_empty() or seen.has(eid):
				continue
			seen[eid] = true
			out.append(d)
	return out


func _ready() -> void:
	if OS.has_feature("web"):
		_prewarm_character_visual_defs()


func _prewarm_character_visual_defs() -> void:
	for c in CHARACTERS:
		var id: String = String(c.get("id", ""))
		if id != "":
			get_character_def(id)
