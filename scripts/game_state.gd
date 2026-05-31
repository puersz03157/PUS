extends Node
## 跨場景共享的狀態：哪幾位玩家、選的角色／被動／技能、結果。
## 也保存「局外」進度（金幣、目前關卡），會寫入 user://save.cfg。

const SAVE_PATH := "user://save.cfg"
const HOUSE_FAVORITES_CFG_SECTION := "house_favorites"
const HOUSE_SUMMONS_CFG_SECTION := "house_summons"
const HOUSE_SUMMON_PROGRESS_CFG_SECTION := "house_summon_progress"
const DEFAULT_UNLOCKED_CHARACTERS: Array[String] = ["swordsman", "ranger"]
const MAX_WEAPON_SLOTS := 5
const DEFAULT_UNLOCKED_WEAPON_SLOTS := 3
const DEFAULT_LOCKED_WEAPONS: Array[String] = ["melody", "claw", "shard", "poison", "holy"]
const BLACKSMITH_CRAFT_WEAPON_IDS: Array[String] = ["axe", "magic_bullet"]
const BLACKSMITH_TIER2_WEAPON_IDS: Array[String] = ["shard", "holy"]
const BLACKSMITH_TIER1_WEAPON_SLOT_MAX := 4
const BLACKSMITH_TIER1_HOUSE_SLOT_MAX := 3
const BLACKSMITH_SLOT_COSTS: Dictionary = {4: 200, 5: 350}
const DEFAULT_UNLOCKED_COMMON_UPGRADE_SLOTS := GameData.COMMON_UPGRADE_SLOT_INITIAL
## 喜愛武裝擴充：解鎖「第 3～5 格」所需金幣（1P／2P 同步）
const BLACKSMITH_HOUSE_FAVORITE_SLOT_COSTS: Dictionary = {3: 130, 4: 240, 5: 400}
const BLACKSMITH_WEAPON_KIND_COST := 180
const BLACKSMITH_ARMAMENT_COST := 160
const MERCHANT_MATERIAL_BUY_PRICE := 12
const MERCHANT_MATERIAL_SELL_PRICE := 4
const DEFAULT_ACHIEVEMENT_STATS: Dictionary = {
	"damage_taken": 0.0,
	"damage_dealt": 0.0,
	"kills": 0,
	"pinball_score": 0,
}
const DEFAULT_MATERIALS: Dictionary = {
	"wood": 0,
	"stone": 0,
	"iron": 0,
	"copper": 0,
	"bone": 0,
	"rag": 0,
	"silver": 0,
	"gold_ore": 0,
	"gunpowder": 0,
	"sacred_wood": 0,
	"glow_dust": 0,
	"tree_sap": 0,
	"flame_scale": 0,
	"obsidian": 0,
	"venom": 0,
	"wheat_seed": 0,
	"carrot_seed": 0,
	"potato_seed": 0,
	"wheat": 0,
	"carrot": 0,
	"potato": 0,
}
const ACHIEVEMENTS: Array[Dictionary] = [
	{
		"id": "damage_taken_knight",
		"stat": "damage_taken",
		"threshold": 3000,
		"character_id": "knight",
		"title_key": "ACH_DAMAGE_TAKEN_NAME",
		"desc_key": "ACH_DAMAGE_TAKEN_DESC",
	},
	{
		"id": "damage_dealt_wizard",
		"stat": "damage_dealt",
		"threshold": 20000,
		"character_id": "wizard",
		"title_key": "ACH_DAMAGE_DEALT_NAME",
		"desc_key": "ACH_DAMAGE_DEALT_DESC",
	},
	{
		"id": "kills_warrior",
		"stat": "kills",
		"threshold": 500,
		"character_id": "warrior",
		"title_key": "ACH_KILLS_NAME",
		"desc_key": "ACH_KILLS_DESC",
	},
	{
		"id": "pinball_score_samurai",
		"stat": "pinball_score",
		"threshold": 12000,
		"character_id": "bard",
		"title_key": "ACH_PINBALL_SCORE_NAME",
		"desc_key": "ACH_PINBALL_SCORE_DESC",
	},
]

var two_players: bool = true
var p1_character: String = "swordsman"
var p2_character: String = "ranger"
## 村莊 1P 上次使用角色（存檔）；空字串＝首次進村，使用劍士
var p1_last_village_character: String = ""

## 任務系統
const QUEST_BLACKSMITH_GOLD_REWARD := 80
const QUEST_BLACKSMITH_IRON_REWARD := 3
var quest_headman_intro_done: bool = false
var quest_headman_starter_summon_done: bool = false
var quest_blacksmith_rewarded: bool = false
var completed_quests: Array[String] = []

# 角色選擇完成後要去哪：
#   "battle"  → StageSelect → Game
#   "village" → Village（舊路線，主選單已改直接進村）
var next_scene: String = "battle"
## 選角畫面按返回時：「main」| 「village」
var character_select_return_scene: String = "main"

# 被動／技能（角色選擇畫面決定，遊戲開始時帶入 Player）
var p1_passive: String = "none"
var p1_skill: String = "none"
var p2_passive: String = "none"
var p2_skill: String = "none"
var p1_armament: String = "none"
var p2_armament: String = "none"

# 局外進度
var gold: int = 0
var current_stage_id: String = "slime_forest"
var unlocked_characters: Array[String] = DEFAULT_UNLOCKED_CHARACTERS.duplicate()
var unlocked_weapons: Array[String] = []
var unlocked_weapon_slots: int = DEFAULT_UNLOCKED_WEAPON_SLOTS
var unlocked_common_upgrade_slots: int = DEFAULT_UNLOCKED_COMMON_UPGRADE_SLOTS
var unlocked_armaments: Array[String] = ["none"]
## 已取得製作書、可在鐵匠製作的武裝 id（第二關偶發事件等）
var unlocked_armament_recipes: Array[String] = []
var blacksmith_rescued: bool = false
var merchant_rescued: bool = false
var tavern_owner_rescued: bool = false
## 酒館旅行者每日輪替（1～4）；與 tavern_traveler_last 避免連續重複
var tavern_traveler_today: int = 0
var tavern_traveler_last: int = 0
var village_day_count: int = 0
var rune_master_rescued: bool = false
var farmer_rescued: bool = false
var blacksmith_tier2_unlocked: bool = false
var village_facilities_unlocked: Dictionary = {}
var village_facility_last_collect_unix: Dictionary = {}
## 農田 1～7 格：{ "crop_id", "stage" }；空字典表示未種植
var farm_plots: Dictionary = {}
## 水井裝水後可澆灌次數（最多 VILLAGE_WATER_MAX_CHARGES）
var water_charges: int = 0
var completed_stage_ids: Array[String] = []
var rune_dust: int = 0
var materials: Dictionary = DEFAULT_MATERIALS.duplicate()
var achievement_stats: Dictionary = DEFAULT_ACHIEVEMENT_STATS.duplicate()
var unlocked_achievements: Array[String] = []
## 圖鑑「怪物」分頁已解鎖的敵人 id（擊倒解鎖；設定可一鍵全開）
var unlocked_codex_monster_ids: Array[String] = []
## 房屋：各玩家、各角色造型與喜愛武裝五格（P1/P2 分開存；喜愛武裝全帳號不可重複）
var p1_house_character_skins: Dictionary = {}
var p1_house_character_favorites: Dictionary = {}
var p2_house_character_skins: Dictionary = {}
var p2_house_character_favorites: Dictionary = {}
## 房屋：各玩家、各角色召喚獸三格（P1/P2 分開；同角色三格不可重複）
var p1_house_character_summons: Dictionary = {}
var p2_house_character_summons: Dictionary = {}
## 召喚獸等級／經驗（依玩家＋召喚獸 id；帶出戰累積後續接入）
var p1_summon_progress: Dictionary = {}
var p2_summon_progress: Dictionary = {}
var _summon_test_level_cycle_idx: int = 0
## 已取得的寵物 id（不含 none）；新帳號為空，後續由蛋／獎勵解鎖。
var unlocked_summons: Array[String] = []
## 未解鎖物種的蛋碎片（5 片合 1 顆）；解鎖後剩餘片數轉飼料。
var summon_egg_shards: Dictionary = {}
## 寵物飼料數量（對 Lv.1+ 召喚獸使用，增加 EXP）。
var pet_feed: int = 0
## 各關卡整蛋掉落機率永久衰減（stage_id -> 0~1 倍率）。
var stage_summon_egg_drop_mult: Dictionary = {}
## 本場戰鬥是否已掉落過整顆蛋（單局上限 1）。
var run_summon_egg_dropped: bool = false
## 戰鬥結束待播的孵化／進化里程碑（不存檔）
var pending_summon_milestones: Array = []
## 弓箭場上資源造型（P1/P2 分開；與武裝數值無關）
var p1_bow_arrow_skin: String = "default"
var p2_bow_arrow_skin: String = "default"
var p1_pinball_bg_pattern: String = GameData.PINBALL_BG_PATTERN_DEFAULT
var p1_ui_bg_main: String = GameData.PINBALL_BG_PATTERN_DEFAULT
var p1_ui_bg_panel: String = GameData.PINBALL_BG_PATTERN_DEFAULT
var p1_ui_bg_dialog: String = GameData.PINBALL_BG_PATTERN_DEFAULT
## UI PatternMix 淡化強度：0=不淡化（圖案最清楚），1=預設淡化。
var ui_bg_pattern_dim: float = 1.0
## 喜愛武裝目前可用格數（含 P1／P2 所有角色；上限見 GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS）
var house_favorite_unlocked_slots: int = 2

# 顯示語系：留空則沿用 project.godot 的 locale。
# 受支援：zh_TW（預設）／zh_CN／en；新語系加在 strings.csv 後可動態切換。
var language: String = ""

# 觸控介面開關（給手機 / 網頁版用；桌機平台仍可手動開啟測試）
var touch_controls_enabled: bool = false

# 戰鬥結算：ESC 進村莊時帶過去的 UI 資料（由 BattleRunSummaryOverlay 讀寫）
var pending_battle_summary: Dictionary = {}

# 結束畫面用
var last_result: Dictionary = {
	"won": false,
	"time": 0.0,
	"kills_p1": 0,
	"kills_p2": 0,
	"gold_reward": 0,
	"stage_id": "",
	"stage_name": "",
	"achievement_unlocks": [],
	"facility_unlocks": [],
}


func _ready() -> void:
	load_from_disk()
	# 語系由 TranslationLoader（autoload 最後）統一套用；此處不呼叫 set_locale，避免早於 CSV 載入。


func set_language(lang: String) -> void:
	language = String(lang).strip_edges()
	var loc: String = language if language != "" else "zh_TW"
	TranslationServer.set_locale(loc)
	save_to_disk()


func set_touch_controls_enabled(v: bool) -> void:
	touch_controls_enabled = v
	save_to_disk()


func is_character_unlocked(id: String) -> bool:
	return unlocked_characters.has(id)


func unlock_character(id: String) -> bool:
	if not _add_unlocked_character(id):
		return false
	save_to_disk()
	return true


func unlock_all_characters() -> void:
	unlocked_characters.clear()
	for c in GameData.CHARACTERS:
		_add_unlocked_character(String(c.get("id", "")))
	unlock_all_house_favorite_slots()
	save_to_disk()


func is_weapon_unlocked(id: String) -> bool:
	return unlocked_weapons.has(id)


func get_unlocked_weapon_slot_count() -> int:
	return clampi(unlocked_weapon_slots, 1, MAX_WEAPON_SLOTS)


func get_unlocked_common_upgrade_slot_count() -> int:
	return clampi(
		unlocked_common_upgrade_slots,
		GameData.COMMON_UPGRADE_SLOT_INITIAL,
		GameData.COMMON_UPGRADE_SLOT_MAX)


func next_common_upgrade_slot_unlock_cost() -> int:
	var next_slot: int = get_unlocked_common_upgrade_slot_count() + 1
	if next_slot > GameData.COMMON_UPGRADE_SLOT_MAX:
		return -1
	return int(GameData.COMMON_UPGRADE_SLOT_DUST_COSTS.get(next_slot, -1))


func spend_rune_dust(amount: int) -> bool:
	if amount <= 0:
		return true
	if rune_dust < amount:
		return false
	rune_dust -= amount
	save_to_disk()
	return true


func buy_next_common_upgrade_slot() -> bool:
	if not rune_master_rescued:
		return false
	var cost: int = next_common_upgrade_slot_unlock_cost()
	if cost < 0 or not spend_rune_dust(cost):
		return false
	unlocked_common_upgrade_slots = clampi(
		unlocked_common_upgrade_slots + 1,
		GameData.COMMON_UPGRADE_SLOT_INITIAL,
		GameData.COMMON_UPGRADE_SLOT_MAX)
	save_to_disk()
	return true


func unlock_all_weapons_and_slots() -> void:
	unlocked_weapons.clear()
	for w in GameData.WEAPONS:
		unlocked_weapons.append(String(w.get("id", "")))
	unlocked_weapon_slots = MAX_WEAPON_SLOTS
	unlocked_common_upgrade_slots = GameData.COMMON_UPGRADE_SLOT_MAX
	unlock_all_house_favorite_slots()
	save_to_disk()


func is_codex_monster_unlocked(enemy_id: String) -> bool:
	return unlocked_codex_monster_ids.has(enemy_id)


func unlock_all_codex_monsters() -> void:
	_fill_all_codex_monster_ids()
	save_to_disk()


func unlock_all_armaments() -> void:
	for a in GameData.ARMAMENTS:
		var aid: String = String(a.get("id", ""))
		if aid == "" or aid == "none":
			continue
		if not unlocked_armament_recipes.has(aid) and GameData.armament_requires_craft_book(aid):
			unlocked_armament_recipes.append(aid)
		if not unlocked_armaments.has(aid):
			unlocked_armaments.append(aid)
	save_to_disk()


## 設定除錯：解救全部村莊 NPC，並開啟全部村莊設施。
func unlock_all_village_npcs_and_facilities() -> void:
	blacksmith_rescued = true
	merchant_rescued = true
	tavern_owner_rescued = true
	rune_master_rescued = true
	farmer_rescued = true
	for fdef in GameData.VILLAGE_FACILITIES:
		var fid: String = String(fdef.get("id", ""))
		if fid != "":
			village_facilities_unlocked[fid] = true
	save_to_disk()


func unlock_codex_monster_on_defeat(enemy_id: String) -> void:
	if enemy_id == "" or unlocked_codex_monster_ids.has(enemy_id):
		return
	if GameData.get_enemy_def(enemy_id).is_empty():
		return
	unlocked_codex_monster_ids.append(enemy_id)
	save_to_disk()


func _fill_all_codex_monster_ids() -> void:
	unlocked_codex_monster_ids.clear()
	for d in GameData.all_enemy_defs_for_codex():
		var eid: String = String(d.get("id", ""))
		if eid != "":
			unlocked_codex_monster_ids.append(eid)


func _load_armament_recipes(cfg: ConfigFile) -> void:
	unlocked_armament_recipes.clear()
	var saved: Array = cfg.get_value("meta", "unlocked_armament_recipes", [])
	for raw in saved:
		var aid: String = String(raw)
		if aid == "" or unlocked_armament_recipes.has(aid):
			continue
		if not GameData.armament_requires_craft_book(aid):
			continue
		unlocked_armament_recipes.append(aid)


func _load_codex_monster_unlocks(cfg: ConfigFile) -> void:
	unlocked_codex_monster_ids.clear()
	if not cfg.has_section_key("meta", "unlocked_codex_monsters"):
		return
	var saved: Array = cfg.get_value("meta", "unlocked_codex_monsters", [])
	for raw in saved:
		var eid: String = String(raw)
		if eid == "" or unlocked_codex_monster_ids.has(eid):
			continue
		if GameData.get_enemy_def(eid).is_empty():
			continue
		unlocked_codex_monster_ids.append(eid)


func spend_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	if gold < amount:
		return false
	gold -= amount
	save_to_disk()
	return true


func next_weapon_slot_unlock_cost() -> int:
	var next_slot: int = get_unlocked_weapon_slot_count() + 1
	if next_slot > MAX_WEAPON_SLOTS:
		return -1
	return int(BLACKSMITH_SLOT_COSTS.get(next_slot, 300))


func buy_next_weapon_slot() -> bool:
	if get_unlocked_weapon_slot_count() + 1 > BLACKSMITH_TIER1_WEAPON_SLOT_MAX \
			and not blacksmith_tier2_unlocked:
		return false
	var cost: int = next_weapon_slot_unlock_cost()
	if cost < 0 or not spend_gold(cost):
		return false
	unlocked_weapon_slots = clampi(unlocked_weapon_slots + 1, 1, MAX_WEAPON_SLOTS)
	save_to_disk()
	return true


func get_house_favorite_unlocked_slot_count() -> int:
	return clampi(
		house_favorite_unlocked_slots,
		GameData.HOUSE_FAVORITE_ARMAMENT_SLOTS_INITIAL,
		GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS)


func next_house_favorite_slot_unlock_cost() -> int:
	var next_n: int = get_house_favorite_unlocked_slot_count() + 1
	if next_n > GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS:
		return -1
	return int(BLACKSMITH_HOUSE_FAVORITE_SLOT_COSTS.get(next_n, 320))


func buy_next_house_favorite_slot() -> bool:
	if get_house_favorite_unlocked_slot_count() + 1 > BLACKSMITH_TIER1_HOUSE_SLOT_MAX \
			and not blacksmith_tier2_unlocked:
		return false
	var cost: int = next_house_favorite_slot_unlock_cost()
	if cost < 0 or not spend_gold(cost):
		return false
	house_favorite_unlocked_slots = clampi(
		house_favorite_unlocked_slots + 1,
		GameData.HOUSE_FAVORITE_ARMAMENT_SLOTS_INITIAL,
		GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS)
	_dedupe_global_house_favorites()
	save_to_disk()
	return true


func is_blacksmith_slot_tier2_locked() -> bool:
	return get_unlocked_weapon_slot_count() + 1 > BLACKSMITH_TIER1_WEAPON_SLOT_MAX \
		and not blacksmith_tier2_unlocked


func is_blacksmith_house_slot_tier2_locked() -> bool:
	return get_house_favorite_unlocked_slot_count() + 1 > BLACKSMITH_TIER1_HOUSE_SLOT_MAX \
		and not blacksmith_tier2_unlocked


func unlock_blacksmith_tier2() -> void:
	if blacksmith_tier2_unlocked:
		return
	blacksmith_tier2_unlocked = true
	save_to_disk()


func _fallback_village_p1_character() -> String:
	if is_character_unlocked("swordsman"):
		return "swordsman"
	for raw in unlocked_characters:
		var cid: String = String(raw)
		if cid != "" and not GameData.get_character_def(cid).is_empty():
			return cid
	return "swordsman"


func resolve_village_p1_character() -> String:
	var cid: String = String(p1_last_village_character)
	if cid == "" or not is_character_unlocked(cid) \
			or GameData.get_character_def(cid).is_empty():
		return _fallback_village_p1_character()
	return cid


func prepare_enter_village() -> void:
	two_players = false
	p1_character = resolve_village_p1_character()


func set_p1_village_character(char_id: String) -> void:
	if char_id == "" or GameData.get_character_def(char_id).is_empty() \
			or not is_character_unlocked(char_id):
		return
	p1_character = char_id
	p1_last_village_character = char_id
	save_to_disk()


func unlock_all_house_favorite_slots() -> void:
	house_favorite_unlocked_slots = GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS


func next_locked_weapon_id() -> String:
	for wid in DEFAULT_LOCKED_WEAPONS:
		if not unlocked_weapons.has(wid):
			if BLACKSMITH_TIER2_WEAPON_IDS.has(wid) and not blacksmith_tier2_unlocked:
				continue
			return wid
	for w in GameData.WEAPONS:
		var id: String = String(w.get("id", ""))
		if id != "" and not unlocked_weapons.has(id) and not BLACKSMITH_CRAFT_WEAPON_IDS.has(id):
			return id
	return ""


func next_locked_weapon_id_tier2() -> String:
	if blacksmith_tier2_unlocked:
		return ""
	for wid in BLACKSMITH_TIER2_WEAPON_IDS:
		if not unlocked_weapons.has(wid):
			return wid
	return ""


func buy_next_weapon_kind() -> String:
	var wid: String = next_locked_weapon_id()
	if wid == "" or not spend_gold(BLACKSMITH_WEAPON_KIND_COST):
		return ""
	unlocked_weapons.append(wid)
	save_to_disk()
	return wid


func weapon_gold_cost(id: String) -> int:
	var wdef: Dictionary = GameData.get_weapon_def(id)
	if wdef.is_empty():
		return BLACKSMITH_WEAPON_KIND_COST
	return int(wdef.get("craft_gold", BLACKSMITH_WEAPON_KIND_COST))


func weapon_material_costs(id: String) -> Dictionary:
	var wdef: Dictionary = GameData.get_weapon_def(id)
	if wdef.is_empty():
		return {}
	var costs: Dictionary = wdef.get("craft_materials", {})
	if costs == null:
		return {}
	return costs


func can_craft_weapon_kind(id: String) -> bool:
	if id == "" or is_weapon_unlocked(id) or GameData.get_weapon_def(id).is_empty():
		return false
	if gold < weapon_gold_cost(id):
		return false
	var material_costs: Dictionary = weapon_material_costs(id)
	for material_id in material_costs.keys():
		if get_material_amount(String(material_id)) < int(material_costs[material_id]):
			return false
	return true


func craft_weapon_kind(id: String) -> bool:
	if id == "" or is_weapon_unlocked(id):
		return false
	var wdef: Dictionary = GameData.get_weapon_def(id)
	if wdef.is_empty():
		return false
	var gold_cost: int = weapon_gold_cost(id)
	var material_costs: Dictionary = weapon_material_costs(id)
	if gold < gold_cost:
		return false
	for material_id in material_costs.keys():
		if get_material_amount(String(material_id)) < int(material_costs[material_id]):
			return false
	gold -= gold_cost
	for material_id in material_costs.keys():
		var mid: String = String(material_id)
		materials[mid] = get_material_amount(mid) - int(material_costs[material_id])
	unlocked_weapons.append(id)
	save_to_disk()
	return true


func is_armament_unlocked(id: String) -> bool:
	return unlocked_armaments.has(id)


func _house_player_slot_valid(player_slot: String) -> bool:
	return player_slot == "p1" or player_slot == "p2"


func _house_skins_dict(player_slot: String) -> Dictionary:
	return p2_house_character_skins if player_slot == "p2" else p1_house_character_skins


func _house_favorites_dict(player_slot: String) -> Dictionary:
	return p2_house_character_favorites if player_slot == "p2" else p1_house_character_favorites


func _house_favorites_cfg_key(player_slot: String, char_id: String) -> String:
	return "%s:%s" % [player_slot, char_id]


func _default_house_favorites_array() -> Array[String]:
	var out: Array[String] = []
	for _i in GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS:
		out.append("none")
	return out


func _ensure_house_char_favorites(player_slot: String, char_id: String) -> void:
	if not _house_player_slot_valid(player_slot) or char_id == "":
		return
	var fav_dict: Dictionary = _house_favorites_dict(player_slot)
	if not fav_dict.has(char_id):
		fav_dict[char_id] = _default_house_favorites_array()
		return
	var arr: Variant = fav_dict[char_id]
	if not (arr is Array):
		fav_dict[char_id] = _default_house_favorites_array()
		return
	while (arr as Array).size() < GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS:
		(arr as Array).append("none")
	if (arr as Array).size() > GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS:
		fav_dict[char_id] = (arr as Array).slice(0, GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS)


func get_house_favorite_armaments(player_slot: String, char_id: String) -> Array[String]:
	_ensure_house_char_favorites(player_slot, char_id)
	var arr: Array = _house_favorites_dict(player_slot)[char_id]
	var out: Array[String] = []
	for item in arr:
		out.append(String(item))
	return out


func _collect_house_favorite_armaments_used(
		except_player: String, except_char: String, except_index: int) -> Dictionary:
	var used: Dictionary = {}
	for player_slot in ["p1", "p2"]:
		var fav_dict: Dictionary = _house_favorites_dict(player_slot)
		for raw_cid in fav_dict.keys():
			var cid: String = String(raw_cid)
			_ensure_house_char_favorites(player_slot, cid)
			var slots: Array[String] = get_house_favorite_armaments(player_slot, cid)
			var cap: int = get_house_favorite_unlocked_slot_count()
			for i in mini(slots.size(), cap):
				if player_slot == except_player and cid == except_char and i == except_index:
					continue
				var aid: String = slots[i]
				if aid != "none":
					used[aid] = true
	return used


func set_house_favorite_slot(player_slot: String, char_id: String, index: int, armament_id: String) -> bool:
	if not _house_player_slot_valid(player_slot) or char_id == "":
		return false
	_ensure_house_char_favorites(player_slot, char_id)
	if index < 0 or index >= get_house_favorite_unlocked_slot_count():
		return false
	if index >= GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS:
		return false
	var aid: String = armament_id
	if aid == "":
		aid = "none"
	if aid != "none":
		if not is_armament_unlocked(aid) or GameData.get_armament_def(aid).is_empty():
			return false
		if _collect_house_favorite_armaments_used(player_slot, char_id, index).has(aid):
			return false
	var arr: Array = _house_favorites_dict(player_slot)[char_id]
	arr[index] = aid
	_house_favorites_dict(player_slot)[char_id] = arr.duplicate()
	save_to_disk()
	return true


func _dedupe_house_char_favorites(player_slot: String, char_id: String) -> void:
	_ensure_house_char_favorites(player_slot, char_id)
	var cap: int = get_house_favorite_unlocked_slot_count()
	var arr: Array = _house_favorites_dict(player_slot)[char_id]
	var seen: Dictionary = {}
	var changed: bool = false
	for i in arr.size():
		if i >= cap:
			continue
		var aid: String = String(arr[i])
		if aid == "none":
			continue
		if seen.has(aid):
			arr[i] = "none"
			changed = true
		else:
			seen[aid] = true
	if changed:
		_house_favorites_dict(player_slot)[char_id] = arr.duplicate()


func _dedupe_global_house_favorites() -> void:
	var cap: int = get_house_favorite_unlocked_slot_count()
	var seen: Dictionary = {}
	var changed: bool = false
	for player_slot in ["p1", "p2"]:
		var fav_dict: Dictionary = _house_favorites_dict(player_slot)
		for raw_cid in fav_dict.keys():
			var cid: String = String(raw_cid)
			_ensure_house_char_favorites(player_slot, cid)
			var arr: Array = fav_dict[cid]
			var char_changed: bool = false
			for i in arr.size():
				if i >= cap:
					continue
				var aid: String = String(arr[i])
				if aid == "none":
					continue
				if seen.has(aid):
					arr[i] = "none"
					char_changed = true
					changed = true
				else:
					seen[aid] = true
			if char_changed:
				fav_dict[cid] = arr.duplicate()
	if changed:
		save_to_disk()


func house_favorite_armament_choices(player_slot: String, char_id: String, slot_index: int) -> Array[String]:
	if slot_index < 0 or slot_index >= get_house_favorite_unlocked_slot_count():
		return ["none"]
	var out: Array[String] = ["none"]
	var slots: Array[String] = get_house_favorite_armaments(player_slot, char_id)
	var current: String = slots[slot_index] if slot_index >= 0 and slot_index < slots.size() else "none"
	var used: Dictionary = _collect_house_favorite_armaments_used(player_slot, char_id, slot_index)
	for aid in unlocked_armaments:
		var id: String = String(aid)
		if id == "none" or id == "":
			continue
		if used.has(id) and id != current:
			continue
		out.append(id)
	return out


func get_house_character_skin(player_slot: String, char_id: String) -> String:
	var sid: String = String(_house_skins_dict(player_slot).get(char_id, "default"))
	if sid == "":
		return "default"
	return sid


func set_house_character_skin(player_slot: String, char_id: String, skin_id: String) -> void:
	if not _house_player_slot_valid(player_slot) or GameData.get_character_def(char_id).is_empty():
		return
	var sid: String = skin_id if skin_id != "" else "default"
	var valid: bool = false
	for opt in GameData.character_house_skin_options(char_id, unlocked_characters):
		if String(opt.get("id", "")) == sid:
			valid = true
			break
	if not valid:
		return
	var skins: Dictionary = _house_skins_dict(player_slot)
	if sid == "default":
		skins.erase(char_id)
	else:
		skins[char_id] = sid
	save_to_disk()


func house_favorite_armament_ids_for_battle(player_slot: String, char_id: String) -> Array[String]:
	var out: Array[String] = []
	var cap: int = get_house_favorite_unlocked_slot_count()
	var arr: Array[String] = get_house_favorite_armaments(player_slot, char_id)
	for i in mini(arr.size(), cap):
		var aid: String = arr[i]
		if aid != "none" and is_armament_unlocked(aid):
			out.append(aid)
	return out


func _house_summons_dict(player_slot: String) -> Dictionary:
	return p2_house_character_summons if player_slot == "p2" else p1_house_character_summons


func _house_summons_cfg_key(player_slot: String, char_id: String) -> String:
	return "%s:%s" % [player_slot, char_id]


func _default_house_summons_array() -> Array[String]:
	var out: Array[String] = []
	for _i in GameData.P1_HOUSE_SUMMON_SLOTS:
		out.append("none")
	return out


func _ensure_house_char_summons(player_slot: String, char_id: String) -> void:
	if not _house_player_slot_valid(player_slot) or char_id == "":
		return
	var sum_dict: Dictionary = _house_summons_dict(player_slot)
	if not sum_dict.has(char_id):
		sum_dict[char_id] = _default_house_summons_array()
		return
	var arr: Variant = sum_dict[char_id]
	if not (arr is Array):
		sum_dict[char_id] = _default_house_summons_array()
		return
	while (arr as Array).size() < GameData.P1_HOUSE_SUMMON_SLOTS:
		(arr as Array).append("none")
	if (arr as Array).size() > GameData.P1_HOUSE_SUMMON_SLOTS:
		sum_dict[char_id] = (arr as Array).slice(0, GameData.P1_HOUSE_SUMMON_SLOTS)


func get_house_summons(player_slot: String, char_id: String) -> Array[String]:
	_ensure_house_char_summons(player_slot, char_id)
	var arr: Array = _house_summons_dict(player_slot)[char_id]
	var out: Array[String] = []
	for item in arr:
		out.append(String(item))
	return out


func _collect_house_summons_used(
		player_slot: String, char_id: String, except_index: int) -> Dictionary:
	var used: Dictionary = {}
	_ensure_house_char_summons(player_slot, char_id)
	var slots: Array[String] = get_house_summons(player_slot, char_id)
	for i in mini(slots.size(), GameData.P1_HOUSE_SUMMON_SLOTS):
		if i == except_index:
			continue
		var sid: String = slots[i]
		if sid != "none":
			used[sid] = true
	return used


func house_summon_choices(player_slot: String, char_id: String, slot_index: int) -> Array[String]:
	if slot_index < 0 or slot_index >= GameData.P1_HOUSE_SUMMON_SLOTS:
		return ["none"]
	var out: Array[String] = ["none"]
	var slots: Array[String] = get_house_summons(player_slot, char_id)
	var current: String = slots[slot_index] if slot_index < slots.size() else "none"
	var used: Dictionary = _collect_house_summons_used(player_slot, char_id, slot_index)
	for sid in GameData.house_summon_choice_ids():
		if sid == "" or sid == "none":
			continue
		if not is_summon_unlocked(sid) and sid != current:
			continue
		if used.has(sid) and sid != current:
			continue
		if not out.has(sid):
			out.append(sid)
	return out


func is_summon_unlocked(summon_id: String) -> bool:
	if summon_id == "" or summon_id == "none":
		return false
	return unlocked_summons.has(summon_id)


func has_any_unlocked_summon() -> bool:
	return not unlocked_summons.is_empty()


func has_all_summons_unlocked() -> bool:
	return unowned_summon_ids().is_empty()


func unowned_summon_ids() -> Array[String]:
	var out: Array[String] = []
	for sid in GameData.playable_summon_ids():
		if not is_summon_unlocked(sid):
			out.append(sid)
	return out


func get_summon_shard_count(summon_id: String) -> int:
	if summon_id == "" or summon_id == "none":
		return 0
	return maxi(0, int(summon_egg_shards.get(summon_id, 0)))


func _convert_species_shards_to_feed(summon_id: String) -> int:
	if summon_id == "" or summon_id == "none":
		return 0
	if not summon_egg_shards.has(summon_id):
		return 0
	var count: int = maxi(0, int(summon_egg_shards[summon_id]))
	if count <= 0:
		return 0
	summon_egg_shards.erase(summon_id)
	pet_feed += count
	return count


func unlock_summon_species(summon_id: String) -> Dictionary:
	var result := {
		"new_unlock": false,
		"feed_from_shards": 0,
		"summon_id": summon_id,
	}
	if summon_id == "" or summon_id == "none" or GameData.get_summon_def(summon_id).is_empty():
		return result
	if is_summon_unlocked(summon_id):
		result.feed_from_shards = _convert_species_shards_to_feed(summon_id)
		return result
	unlocked_summons.append(summon_id)
	ensure_summon_progress("p1", summon_id)
	ensure_summon_progress("p2", summon_id)
	result.new_unlock = true
	result.feed_from_shards = _convert_species_shards_to_feed(summon_id)
	return result


func grant_summon_unlock(summon_id: String, do_save: bool = true) -> bool:
	var res: Dictionary = unlock_summon_species(summon_id)
	if do_save and (bool(res.get("new_unlock", false)) or int(res.get("feed_from_shards", 0)) > 0):
		save_to_disk()
	return bool(res.get("new_unlock", false))


func grant_summon_starter_egg(summon_id: String) -> bool:
	if quest_headman_starter_summon_done:
		return false
	var res: Dictionary = unlock_summon_species(summon_id)
	if not bool(res.get("new_unlock", false)):
		return false
	quest_headman_starter_summon_done = true
	complete_quest("headman_starter_summon")
	var char_id: String = resolve_village_p1_character()
	set_house_summon_slot("p1", char_id, 0, summon_id)
	save_to_disk()
	return true


func add_summon_shard(summon_id: String, amount: int = 1) -> Dictionary:
	var result := {
		"summon_id": summon_id,
		"shards_added": 0,
		"shard_total": 0,
		"new_unlock": false,
		"feed_from_shards": 0,
	}
	if amount <= 0 or summon_id == "" or summon_id == "none":
		return result
	if GameData.get_summon_def(summon_id).is_empty():
		return result
	if is_summon_unlocked(summon_id):
		pet_feed += amount
		result.feed_from_shards = amount
		return result
	var total: int = get_summon_shard_count(summon_id) + amount
	summon_egg_shards[summon_id] = total
	result.shards_added = amount
	result.shard_total = total
	if total >= GameData.SUMMON_SHARDS_PER_EGG:
		var unlock_res: Dictionary = unlock_summon_species(summon_id)
		result.new_unlock = bool(unlock_res.get("new_unlock", false))
		result.feed_from_shards = int(unlock_res.get("feed_from_shards", 0))
		result.shard_total = get_summon_shard_count(summon_id)
	return result


func grant_random_unowned_summon_shard() -> Dictionary:
	if has_all_summons_unlocked():
		return {"kind": "complete", "feed": 0, "gold": 0}
	var pool: Array[String] = unowned_summon_ids()
	if pool.is_empty():
		return {"kind": "none"}
	var sid: String = pool[randi() % pool.size()]
	var shard_res: Dictionary = add_summon_shard(sid, 1)
	shard_res["kind"] = "shard"
	return shard_res


func _stage_egg_drop_multiplier(stage_id: String) -> float:
	if stage_id == "":
		return 1.0
	return clampf(float(stage_summon_egg_drop_mult.get(stage_id, 1.0)), \
		GameData.SUMMON_EGG_STAGE_DECAY_MIN, 1.0)


func _decay_stage_egg_drop_multiplier(stage_id: String) -> void:
	if stage_id == "":
		return
	var cur: float = _stage_egg_drop_multiplier(stage_id)
	var next: float = maxf(cur * GameData.SUMMON_EGG_STAGE_DECAY_MULT, \
		GameData.SUMMON_EGG_STAGE_DECAY_MIN)
	stage_summon_egg_drop_mult[stage_id] = next


func try_roll_enemy_summon_egg_drop(stage_id: String) -> Dictionary:
	var empty := {"dropped": false, "summon_id": ""}
	if run_summon_egg_dropped or has_all_summons_unlocked():
		return empty
	var pool: Array[String] = unowned_summon_ids()
	if pool.is_empty():
		return empty
	var chance: float = GameData.SUMMON_EGG_DROP_BASE_CHANCE * _stage_egg_drop_multiplier(stage_id)
	if randf() >= chance:
		return empty
	var sid: String = pool[randi() % pool.size()]
	run_summon_egg_dropped = true
	_decay_stage_egg_drop_multiplier(stage_id)
	var unlock_res: Dictionary = unlock_summon_species(sid)
	var loot_entry: Dictionary = unlock_res.duplicate()
	loot_entry["dropped"] = true
	_record_run_summon_loot(loot_entry, "enemy_drop")
	save_to_disk()
	return {
		"dropped": true,
		"summon_id": sid,
		"new_unlock": bool(unlock_res.get("new_unlock", false)),
		"feed_from_shards": int(unlock_res.get("feed_from_shards", 0)),
	}


func apply_stage_victory_summon_rewards(stage_id: String) -> Dictionary:
	var result := {
		"kind": "",
		"summon_id": "",
		"shards_added": 0,
		"shard_total": 0,
		"new_unlock": false,
		"feed_from_shards": 0,
		"feed_bonus": 0,
		"gold_bonus": 0,
	}
	if has_all_summons_unlocked():
		result.kind = "complete"
		result.feed_bonus = GameData.SUMMON_VICTORY_FEED_WHEN_COMPLETE
		result.gold_bonus = GameData.SUMMON_VICTORY_GOLD_WHEN_COMPLETE
		pet_feed += result.feed_bonus
		if result.gold_bonus > 0:
			grant_run_gold(result.gold_bonus)
		_record_run_summon_loot(result, "victory_complete")
		save_to_disk()
		return result
	var shard_res: Dictionary = grant_random_unowned_summon_shard()
	result.kind = String(shard_res.get("kind", "shard"))
	result.summon_id = String(shard_res.get("summon_id", ""))
	result.shards_added = int(shard_res.get("shards_added", 0))
	result.shard_total = int(shard_res.get("shard_total", 0))
	result.new_unlock = bool(shard_res.get("new_unlock", false))
	result.feed_from_shards = int(shard_res.get("feed_from_shards", 0))
	_record_run_summon_loot(result, "victory_shard")
	save_to_disk()
	return result


func _record_run_summon_loot(payload: Dictionary, source: String) -> void:
	var loot: Variant = last_result.get("summon_loot", [])
	var entries: Array = loot if loot is Array else []
	var entry: Dictionary = payload.duplicate()
	entry["source"] = source
	entries.append(entry)
	last_result["summon_loot"] = entries


func add_summon_exp(player_slot: String, summon_id: String, amount: int) -> Dictionary:
	var result := {
		"ok": false,
		"summon_id": summon_id,
		"player_slot": player_slot,
		"level_before": GameData.SUMMON_MIN_LEVEL,
		"level_after": GameData.SUMMON_MIN_LEVEL,
		"hatched": false,
		"evolved": false,
	}
	if amount <= 0 or not _house_player_slot_valid(player_slot):
		return result
	if not is_summon_unlocked(summon_id):
		return result
	var prog_dict: Dictionary = _summon_progress_dict(player_slot)
	var entry: Dictionary = get_summon_progress(player_slot, summon_id)
	var lv: int = int(entry.get("level", GameData.SUMMON_MIN_LEVEL))
	var lv_before: int = lv
	var was_egg: bool = GameData.summon_is_egg(lv_before)
	var evolved_before: bool = GameData.summon_is_evolved(lv_before)
	var xp: int = int(entry.get("exp", 0)) + amount
	while lv < GameData.SUMMON_MAX_LEVEL:
		var cap: int = GameData.summon_exp_to_next_level(lv)
		if cap <= 0 or xp < cap:
			break
		xp -= cap
		lv += 1
	if lv >= GameData.SUMMON_MAX_LEVEL:
		xp = 0
	prog_dict[summon_id] = {"level": lv, "exp": xp}
	result.ok = true
	result.level_before = lv_before
	result.level_after = lv
	result.hatched = was_egg and lv >= 1
	result.evolved = (not evolved_before) and GameData.summon_is_evolved(lv)
	return result


func _summon_milestone_from_exp_result(exp_res: Dictionary) -> Dictionary:
	if not bool(exp_res.get("ok", false)):
		return {}
	if bool(exp_res.get("hatched", false)):
		return {
			"kind": "hatch",
			"summon_id": String(exp_res.get("summon_id", "")),
			"player_slot": String(exp_res.get("player_slot", "p1")),
			"level": int(exp_res.get("level_after", 1)),
		}
	if bool(exp_res.get("evolved", false)):
		return {
			"kind": "evolve",
			"summon_id": String(exp_res.get("summon_id", "")),
			"player_slot": String(exp_res.get("player_slot", "p1")),
			"level": int(exp_res.get("level_after", GameData.SUMMON_EVOLVE_LEVEL)),
		}
	return {}


func grant_battle_summon_exp(player_slot: String, char_id: String, amount: int) -> Dictionary:
	var result := {"milestones": [], "applied": false}
	if amount <= 0 or char_id == "":
		return result
	var milestones: Array = []
	var changed: bool = false
	for sid in village_summon_ids_for_follow(player_slot, char_id):
		var exp_res: Dictionary = add_summon_exp(player_slot, sid, amount)
		if not bool(exp_res.get("ok", false)):
			continue
		changed = true
		var milestone: Dictionary = _summon_milestone_from_exp_result(exp_res)
		if not milestone.is_empty():
			milestones.append(milestone)
	if changed:
		save_to_disk()
	result["milestones"] = milestones
	result["applied"] = changed
	return result


func apply_run_battle_summon_exp(won: bool, run_time: float, boss_entered: bool) -> Array:
	var amount: int = 0
	if won:
		amount = GameData.SUMMON_BATTLE_EXP_VICTORY
	elif run_time >= GameData.SUMMON_BATTLE_PARTIAL_MIN_TIME or boss_entered:
		amount = GameData.SUMMON_BATTLE_EXP_PARTIAL
	else:
		return []
	var all_milestones: Array = []
	var any_applied: bool = false
	var res_p1: Dictionary = grant_battle_summon_exp("p1", p1_character, amount)
	all_milestones.append_array(res_p1.get("milestones", []))
	any_applied = bool(res_p1.get("applied", false))
	if two_players:
		var res_p2: Dictionary = grant_battle_summon_exp("p2", p2_character, amount)
		all_milestones.append_array(res_p2.get("milestones", []))
		any_applied = any_applied or bool(res_p2.get("applied", false))
	if any_applied:
		var loot: Variant = last_result.get("summon_loot", [])
		var entries: Array = loot if loot is Array else []
		entries.append({
			"kind": "battle_exp",
			"amount": amount,
			"won": won,
		})
		last_result["summon_loot"] = entries
	return all_milestones


func use_pet_feed_on_summon(player_slot: String, summon_id: String) -> bool:
	if pet_feed <= 0:
		return false
	if not is_summon_unlocked(summon_id):
		return false
	var entry: Dictionary = get_summon_progress(player_slot, summon_id)
	if int(entry.get("level", GameData.SUMMON_MIN_LEVEL)) < 1:
		return false
	var exp_res: Dictionary = add_summon_exp(player_slot, summon_id, GameData.PET_FEED_EXP_AMOUNT)
	if not bool(exp_res.get("ok", false)):
		return false
	pet_feed -= 1
	save_to_disk()
	return true


func unlock_all_summons_for_test() -> void:
	var changed: bool = false
	for sid in GameData.house_summon_choice_ids():
		if grant_summon_unlock(String(sid), false):
			changed = true
	if changed:
		save_to_disk()


func set_house_summon_slot(player_slot: String, char_id: String, index: int, summon_id: String) -> bool:
	if not _house_player_slot_valid(player_slot) or char_id == "":
		return false
	_ensure_house_char_summons(player_slot, char_id)
	if index < 0 or index >= GameData.P1_HOUSE_SUMMON_SLOTS:
		return false
	var sid: String = summon_id
	if sid == "":
		sid = "none"
	if sid != "none" and not is_summon_unlocked(sid):
		return false
	if sid != "none" and GameData.get_summon_def(sid).is_empty():
		return false
	if sid != "none" and _collect_house_summons_used(player_slot, char_id, index).has(sid):
		return false
	var arr: Array = _house_summons_dict(player_slot)[char_id]
	arr[index] = sid
	_house_summons_dict(player_slot)[char_id] = arr.duplicate()
	if sid != "none":
		ensure_summon_progress(player_slot, sid)
	save_to_disk()
	return true


func house_summon_ids_for_battle(player_slot: String, char_id: String) -> Array[String]:
	var out: Array[String] = []
	var arr: Array[String] = get_house_summons(player_slot, char_id)
	for i in mini(arr.size(), GameData.P1_HOUSE_SUMMON_SLOTS):
		var sid: String = arr[i]
		if sid != "none" and is_summon_unlocked(sid) \
				and not GameData.get_summon_def(sid).is_empty():
			out.append(sid)
	return out


## 村莊跟隨：單人最多三格；雙人各只跟第一格（slot 0）。
func village_summon_ids_for_follow(player_slot: String, char_id: String) -> Array[String]:
	var arr: Array[String] = get_house_summons(player_slot, char_id)
	if two_players:
		if arr.is_empty():
			return []
		var first: String = arr[0]
		if first == "none" or GameData.get_summon_def(first).is_empty():
			return []
		return [first]
	return house_summon_ids_for_battle(player_slot, char_id)


func _summon_progress_dict(player_slot: String) -> Dictionary:
	return p2_summon_progress if player_slot == "p2" else p1_summon_progress


func _summon_progress_cfg_key(player_slot: String, summon_id: String) -> String:
	return "%s:%s" % [player_slot, summon_id]


func _default_summon_progress_entry() -> Dictionary:
	return {"level": GameData.SUMMON_MIN_LEVEL, "exp": 0}


func _normalize_summon_progress_entry(raw: Variant) -> Dictionary:
	if raw is Dictionary:
		var lv: int = clampi(
			int(raw.get("level", GameData.SUMMON_MIN_LEVEL)),
			GameData.SUMMON_MIN_LEVEL, GameData.SUMMON_MAX_LEVEL)
		var xp: int = maxi(0, int(raw.get("exp", 0)))
		if lv >= GameData.SUMMON_MAX_LEVEL:
			xp = 0
		else:
			var cap: int = GameData.summon_exp_to_next_level(lv)
			xp = clampi(xp, 0, maxi(0, cap - 1))
		return {"level": lv, "exp": xp}
	return _default_summon_progress_entry()


func ensure_summon_progress(player_slot: String, summon_id: String) -> void:
	if not _house_player_slot_valid(player_slot) or not GameData.is_valid_summon_id(summon_id):
		return
	if summon_id == "none":
		return
	var prog_dict: Dictionary = _summon_progress_dict(player_slot)
	if not prog_dict.has(summon_id):
		prog_dict[summon_id] = _default_summon_progress_entry()


func get_summon_progress(player_slot: String, summon_id: String) -> Dictionary:
	if summon_id == "" or summon_id == "none":
		return _default_summon_progress_entry()
	ensure_summon_progress(player_slot, summon_id)
	return _normalize_summon_progress_entry(_summon_progress_dict(player_slot).get(summon_id, null))


func cycle_all_summon_test_levels() -> Dictionary:
	var result := {
		"level": GameData.SUMMON_MIN_LEVEL,
		"milestones": [],
	}
	var levels: Array[int] = GameData.SUMMON_TEST_LEVELS
	if levels.is_empty():
		return result
	var lv: int = levels[_summon_test_level_cycle_idx % levels.size()]
	_summon_test_level_cycle_idx = (_summon_test_level_cycle_idx + 1) % levels.size()
	var demo_sid: String = _test_milestone_demo_summon_id()
	var demo_lv_before: int = GameData.SUMMON_MIN_LEVEL
	if demo_sid != "":
		demo_lv_before = int(get_summon_progress("p1", demo_sid).get("level", GameData.SUMMON_MIN_LEVEL))
	for player_slot in ["p1", "p2"]:
		var prog_dict: Dictionary = _summon_progress_dict(player_slot)
		for sid in unlocked_summons:
			var summon_id: String = String(sid)
			if summon_id == "" or summon_id == "none":
				continue
			prog_dict[summon_id] = {"level": lv, "exp": 0}
	if demo_sid != "":
		var was_egg: bool = GameData.summon_is_egg(demo_lv_before)
		var evolved_before: bool = GameData.summon_is_evolved(demo_lv_before)
		if was_egg and lv >= 1:
			result["milestones"].append({
				"kind": "hatch",
				"summon_id": demo_sid,
				"player_slot": "p1",
				"level": lv,
			})
		elif (not evolved_before) and GameData.summon_is_evolved(lv):
			result["milestones"].append({
				"kind": "evolve",
				"summon_id": demo_sid,
				"player_slot": "p1",
				"level": lv,
			})
	result["level"] = lv
	save_to_disk()
	return result


func _test_milestone_demo_summon_id() -> String:
	if unlocked_summons.is_empty():
		return ""
	var char_id: String = resolve_village_p1_character()
	if char_id != "":
		var slots: Array[String] = get_house_summons("p1", char_id)
		if not slots.is_empty():
			var equipped: String = slots[0]
			if equipped != "none" and is_summon_unlocked(equipped):
				return equipped
	return String(unlocked_summons[0])


func _default_p1_house_favorites_array() -> Array[String]:
	return _default_house_favorites_array()


func _ensure_p1_house_char_favorites(char_id: String) -> void:
	_ensure_house_char_favorites("p1", char_id)


func get_p1_house_favorite_armaments(char_id: String) -> Array[String]:
	return get_house_favorite_armaments("p1", char_id)


func set_p1_house_favorite_slot(char_id: String, index: int, armament_id: String) -> bool:
	return set_house_favorite_slot("p1", char_id, index, armament_id)


func _dedupe_p1_house_char_favorites(char_id: String) -> void:
	_dedupe_house_char_favorites("p1", char_id)


func get_p2_house_favorite_armaments(char_id: String) -> Array[String]:
	return get_house_favorite_armaments("p2", char_id)


func set_p2_house_favorite_slot(char_id: String, index: int, armament_id: String) -> bool:
	return set_house_favorite_slot("p2", char_id, index, armament_id)


func get_p1_house_character_skin(char_id: String) -> String:
	return get_house_character_skin("p1", char_id)


func set_p1_house_character_skin(char_id: String, skin_id: String) -> void:
	set_house_character_skin("p1", char_id, skin_id)


func get_p2_house_character_skin(char_id: String) -> String:
	return get_house_character_skin("p2", char_id)


func set_p2_house_character_skin(char_id: String, skin_id: String) -> void:
	set_house_character_skin("p2", char_id, skin_id)


func get_bow_arrow_skin(player_slot: String) -> String:
	if player_slot != "p1" and player_slot != "p2":
		return "default"
	var sid: String = p2_bow_arrow_skin if player_slot == "p2" else p1_bow_arrow_skin
	if not GameData.is_valid_bow_arrow_skin(sid):
		return "default"
	return sid


func set_bow_arrow_skin(player_slot: String, skin_id: String) -> bool:
	return set_weapon_visual_skin(player_slot, "bow", skin_id)


func get_weapon_visual_skin(player_slot: String, weapon_id: String) -> String:
	if player_slot != "p1" and player_slot != "p2":
		return "default"
	if weapon_id == "bow":
		return get_bow_arrow_skin(player_slot)
	return "default"


func get_pinball_bg_pattern(_player_slot: String = "p1") -> String:
	return get_ui_bg_pattern(GameData.UI_BG_CTX_PINBALL, _player_slot)


func get_ui_bg_pattern_dim() -> float:
	return clampf(ui_bg_pattern_dim, 0.0, 1.0)


func set_ui_bg_pattern_dim(value: float) -> void:
	ui_bg_pattern_dim = clampf(value, 0.0, 1.0)
	save_to_disk()


func get_ui_bg_pattern(context: String, _player_slot: String = "p1") -> String:
	var pid: String = GameData.PINBALL_BG_PATTERN_DEFAULT
	match context:
		GameData.UI_BG_CTX_MAIN:
			pid = p1_ui_bg_main
		GameData.UI_BG_CTX_PANEL:
			pid = p1_ui_bg_panel
		GameData.UI_BG_CTX_DIALOG:
			pid = p1_ui_bg_dialog
		GameData.UI_BG_CTX_PINBALL:
			pid = p1_pinball_bg_pattern
		_:
			pid = GameData.PINBALL_BG_PATTERN_DEFAULT
	if not GameData.is_valid_pinball_bg_pattern(pid):
		return GameData.PINBALL_BG_PATTERN_DEFAULT
	return pid


func set_pinball_bg_pattern(player_slot: String, pattern_id: String) -> bool:
	return set_ui_bg_pattern(GameData.UI_BG_CTX_PINBALL, player_slot, pattern_id)


func set_ui_bg_pattern(context: String, player_slot: String, pattern_id: String) -> bool:
	if player_slot != "p1":
		return false
	var pid: String = pattern_id if pattern_id != "" else GameData.PINBALL_BG_PATTERN_DEFAULT
	if not GameData.is_valid_pinball_bg_pattern(pid):
		return false
	match context:
		GameData.UI_BG_CTX_MAIN:
			p1_ui_bg_main = pid
		GameData.UI_BG_CTX_PANEL:
			p1_ui_bg_panel = pid
		GameData.UI_BG_CTX_DIALOG:
			p1_ui_bg_dialog = pid
		GameData.UI_BG_CTX_PINBALL:
			p1_pinball_bg_pattern = pid
		_:
			return false
	save_to_disk()
	return true


func set_weapon_visual_skin(player_slot: String, weapon_id: String, skin_id: String) -> bool:
	if player_slot != "p1" and player_slot != "p2":
		return false
	var sid: String = skin_id if skin_id != "" else "default"
	if weapon_id == "bow":
		if not GameData.is_valid_bow_arrow_skin(sid):
			return false
		if player_slot == "p2":
			p2_bow_arrow_skin = sid
		else:
			p1_bow_arrow_skin = sid
		save_to_disk()
		return true
	if not GameData.is_valid_weapon_visual_skin(weapon_id, sid):
		return false
	save_to_disk()
	return true


func p1_house_favorite_armament_ids_for_battle(char_id: String) -> Array[String]:
	return house_favorite_armament_ids_for_battle("p1", char_id)


func p2_house_favorite_armament_ids_for_battle(char_id: String) -> Array[String]:
	return house_favorite_armament_ids_for_battle("p2", char_id)


func has_armament_recipe(id: String) -> bool:
	if id == "" or id == "none":
		return false
	if not GameData.armament_requires_craft_book(id):
		return true
	return unlocked_armament_recipes.has(id)


func unlock_armament_recipe(id: String) -> bool:
	if id == "" or id == "none":
		return false
	if GameData.get_armament_def(id).is_empty():
		return false
	if not GameData.armament_requires_craft_book(id):
		return false
	if unlocked_armament_recipes.has(id):
		return false
	unlocked_armament_recipes.append(id)
	save_to_disk()
	return true


func buy_armament(id: String) -> bool:
	if id == "none" or is_armament_unlocked(id):
		return false
	if not has_armament_recipe(id):
		return false
	var adef: Dictionary = GameData.get_armament_def(id)
	if adef.is_empty():
		return false
	var gold_cost: int = armament_gold_cost(id)
	var material_costs: Dictionary = armament_material_costs(id)
	if gold < gold_cost:
		return false
	for material_id in material_costs.keys():
		if get_material_amount(String(material_id)) < int(material_costs[material_id]):
			return false
	gold -= gold_cost
	for material_id in material_costs.keys():
		var mid: String = String(material_id)
		materials[mid] = get_material_amount(mid) - int(material_costs[material_id])
	unlocked_armaments.append(id)
	save_to_disk()
	return true


func armament_gold_cost(id: String) -> int:
	var adef: Dictionary = GameData.get_armament_def(id)
	if adef.is_empty():
		return BLACKSMITH_ARMAMENT_COST
	return int(adef.get("craft_gold", BLACKSMITH_ARMAMENT_COST))


func armament_material_costs(id: String) -> Dictionary:
	var adef: Dictionary = GameData.get_armament_def(id)
	if adef.is_empty():
		return {}
	var costs: Dictionary = adef.get("craft_materials", {})
	if costs == null:
		return {}
	return costs


func can_craft_armament(id: String) -> bool:
	if id == "none" or is_armament_unlocked(id):
		return false
	if GameData.get_armament_def(id).is_empty():
		return false
	if not has_armament_recipe(id):
		return false
	if gold < armament_gold_cost(id):
		return false
	var material_costs: Dictionary = armament_material_costs(id)
	for material_id in material_costs.keys():
		if get_material_amount(String(material_id)) < int(material_costs[material_id]):
			return false
	return true


func is_npc_rescued(npc_id: String) -> bool:
	match npc_id:
		"blacksmith":
			return blacksmith_rescued
		"merchant":
			return merchant_rescued
		"tavern_owner":
			return tavern_owner_rescued
		"rune_master":
			return rune_master_rescued
		"farmer":
			return farmer_rescued
		_:
			return false


func ensure_tavern_traveler_for_today() -> void:
	if tavern_traveler_today >= 1 and tavern_traveler_today <= 4:
		return
	roll_tavern_traveler_for_new_day()


func roll_tavern_traveler_for_new_day() -> void:
	var pool: Array[int] = [1, 2, 3, 4]
	if tavern_traveler_last >= 1 and tavern_traveler_last <= 4:
		pool.erase(tavern_traveler_last)
	tavern_traveler_today = pool[randi() % pool.size()]
	tavern_traveler_last = tavern_traveler_today


func on_village_new_day() -> void:
	village_day_count += 1
	roll_tavern_traveler_for_new_day()


func rescue_npc(npc_id: String) -> void:
	if npc_id == "" or is_npc_rescued(npc_id):
		return
	match npc_id:
		"blacksmith":
			blacksmith_rescued = true
		"merchant":
			merchant_rescued = true
		"tavern_owner":
			tavern_owner_rescued = true
		"rune_master":
			rune_master_rescued = true
		"farmer":
			farmer_rescued = true
	save_to_disk()


func rescue_blacksmith() -> void:
	rescue_npc("blacksmith")


func rescue_merchant() -> void:
	rescue_npc("merchant")


func is_village_facility_unlocked(facility_id: String) -> bool:
	return bool(village_facilities_unlocked.get(facility_id, false))


func unlock_village_facility(facility_id: String) -> void:
	if facility_id == "" or is_village_facility_unlocked(facility_id):
		return
	village_facilities_unlocked[facility_id] = true
	save_to_disk()


func apply_stage_victory_facility_unlocks(stage: Dictionary) -> Array[String]:
	var rescue_id: String = GameData.stage_rescue_npc_id(stage)
	if rescue_id == "" or not is_npc_rescued(rescue_id):
		return []
	var newly: Array[String] = []
	for fid in GameData.stage_victory_unlock_facility_ids(stage):
		if is_village_facility_unlocked(fid):
			continue
		unlock_village_facility(fid)
		newly.append(fid)
	return newly


func village_facility_collect_cooldown_left(facility_id: String) -> float:
	var fdef: Dictionary = GameData.get_village_facility_def(facility_id)
	if fdef.is_empty():
		return 0.0
	var cd: float = float(fdef.get("collect_cooldown_sec", 60.0))
	var last: float = float(village_facility_last_collect_unix.get(facility_id, 0.0))
	var now: float = float(Time.get_unix_time_from_system())
	return maxf(0.0, cd - (now - last))


func _ensure_farm_plot_keys() -> void:
	for i in range(1, GameData.FARM_PLOT_COUNT + 1):
		var key: String = str(i)
		if not farm_plots.has(key):
			farm_plots[key] = {}


func get_farm_plot(slot_index: int) -> Dictionary:
	_ensure_farm_plot_keys()
	var key: String = str(clampi(slot_index, 1, GameData.FARM_PLOT_COUNT))
	var raw: Variant = farm_plots.get(key, {})
	if raw is Dictionary:
		return (raw as Dictionary).duplicate()
	return {}


func farm_plot_crop_id(slot_index: int) -> String:
	return String(get_farm_plot(slot_index).get("crop_id", ""))


func farm_plot_stage(slot_index: int) -> int:
	return int(get_farm_plot(slot_index).get("stage", 0))


func farm_plot_is_empty(slot_index: int) -> bool:
	return farm_plot_crop_id(slot_index) == ""


func farm_plot_is_ready(slot_index: int) -> bool:
	var crop_id: String = farm_plot_crop_id(slot_index)
	if crop_id == "":
		return false
	var cdef: Dictionary = GameData.get_farm_crop_def(crop_id)
	if cdef.is_empty():
		return false
	return farm_plot_stage(slot_index) >= int(cdef.get("stages_to_mature", 3))


func farm_plot_status_key(slot_index: int) -> String:
	if farm_plot_is_empty(slot_index):
		return "FARM_PLOT_STATUS_EMPTY"
	if farm_plot_is_ready(slot_index):
		return "FARM_PLOT_STATUS_READY"
	return "FARM_PLOT_STATUS_GROWING"


func owned_farm_seed_ids() -> Array[String]:
	var out: Array[String] = []
	for m in GameData.materials_in_category(GameData.MAT_CATEGORY_SEED):
		var sid: String = String(m.get("id", ""))
		if sid != "" and get_material_amount(sid) > 0:
			out.append(sid)
	return out


func fill_water_at_well() -> void:
	water_charges = GameData.VILLAGE_WATER_MAX_CHARGES
	save_to_disk()


func buy_farmer_seed(seed_id: String) -> bool:
	var price: int = int(GameData.FARMER_SEED_PRICES.get(seed_id, -1))
	if price < 0 or gold < price:
		return false
	if GameData.farm_crop_for_seed(seed_id).is_empty():
		return false
	gold -= price
	grant_material(seed_id, 1)
	save_to_disk()
	return true


func plant_farm_plot(slot_index: int, seed_id: String) -> bool:
	if not farm_plot_is_empty(slot_index):
		return false
	var cdef: Dictionary = GameData.farm_crop_for_seed(seed_id)
	if cdef.is_empty():
		return false
	if get_material_amount(seed_id) <= 0:
		return false
	materials[seed_id] = get_material_amount(seed_id) - 1
	_ensure_farm_plot_keys()
	farm_plots[str(slot_index)] = {
		"crop_id": String(cdef.get("id", "")),
		"stage": 0,
	}
	save_to_disk()
	return true


func water_farm_plot(slot_index: int) -> Dictionary:
	if water_charges <= 0:
		return {"ok": false, "reason": "no_water"}
	if farm_plot_is_empty(slot_index):
		return {"ok": false, "reason": "empty"}
	if farm_plot_is_ready(slot_index):
		return {"ok": false, "reason": "ready"}
	var crop_id: String = farm_plot_crop_id(slot_index)
	var cdef: Dictionary = GameData.get_farm_crop_def(crop_id)
	if cdef.is_empty():
		return {"ok": false, "reason": "invalid"}
	water_charges -= 1
	var stage: int = farm_plot_stage(slot_index) + 1
	_ensure_farm_plot_keys()
	farm_plots[str(slot_index)] = {"crop_id": crop_id, "stage": stage}
	save_to_disk()
	return {"ok": true, "stage": stage, "ready": farm_plot_is_ready(slot_index)}


func harvest_farm_plot(slot_index: int) -> bool:
	if not farm_plot_is_ready(slot_index):
		return false
	var crop_id: String = farm_plot_crop_id(slot_index)
	if crop_id == "":
		return false
	grant_material(crop_id, 1)
	_ensure_farm_plot_keys()
	farm_plots[str(slot_index)] = {}
	save_to_disk()
	return true


func try_collect_village_facility(facility_id: String) -> Dictionary:
	if facility_id == "well" or facility_id == "farm":
		return {}
	if not is_village_facility_unlocked(facility_id):
		return {}
	if village_facility_collect_cooldown_left(facility_id) > 0.0:
		return {}
	var fdef: Dictionary = GameData.get_village_facility_def(facility_id)
	var granted: Dictionary = {}
	if bool(fdef.get("resource_collect", false)):
		var rolled: Dictionary = GameData.roll_village_facility_collect(
			facility_id, completed_stage_ids)
		for mid in rolled.keys():
			var amount: int = int(rolled[mid])
			if amount > 0 and grant_material(String(mid), amount):
				granted[String(mid)] = amount
	else:
		var output_raw: Variant = fdef.get("output", {})
		if output_raw is Dictionary:
			for mat_id in output_raw.keys():
				var mid: String = String(mat_id)
				var band: Variant = output_raw[mat_id]
				if not (band is Dictionary):
					continue
				var mn: int = maxi(1, int(band.get("min", 1)))
				var mx: int = maxi(mn, int(band.get("max", mn)))
				var amount: int = randi_range(mn, mx)
				if grant_material(mid, amount):
					granted[mid] = amount
	if granted.is_empty():
		return {}
	village_facility_last_collect_unix[facility_id] = float(Time.get_unix_time_from_system())
	save_to_disk()
	return granted


func reset_account() -> void:
	gold = 0
	current_stage_id = "slime_forest"
	unlocked_characters = DEFAULT_UNLOCKED_CHARACTERS.duplicate()
	unlocked_weapons = _default_unlocked_weapons()
	unlocked_weapon_slots = DEFAULT_UNLOCKED_WEAPON_SLOTS
	unlocked_common_upgrade_slots = DEFAULT_UNLOCKED_COMMON_UPGRADE_SLOTS
	unlocked_armaments = ["none"]
	unlocked_armament_recipes.clear()
	blacksmith_rescued = false
	merchant_rescued = false
	tavern_owner_rescued = false
	tavern_traveler_today = 0
	tavern_traveler_last = 0
	village_day_count = 0
	rune_master_rescued = false
	farmer_rescued = false
	blacksmith_tier2_unlocked = false
	quest_headman_intro_done = false
	quest_headman_starter_summon_done = false
	quest_blacksmith_rewarded = false
	completed_quests.clear()
	village_facilities_unlocked.clear()
	village_facility_last_collect_unix.clear()
	farm_plots.clear()
	water_charges = 0
	completed_stage_ids.clear()
	rune_dust = 0
	materials = DEFAULT_MATERIALS.duplicate()
	achievement_stats = DEFAULT_ACHIEVEMENT_STATS.duplicate()
	unlocked_achievements.clear()
	unlocked_codex_monster_ids.clear()
	p1_character = "swordsman"
	p2_character = "ranger"
	p1_last_village_character = ""
	p1_passive = "none"
	p1_skill = "none"
	p2_passive = "none"
	p2_skill = "none"
	p1_armament = "none"
	p2_armament = "none"
	p1_house_character_skins.clear()
	p1_house_character_favorites.clear()
	p2_house_character_skins.clear()
	p2_house_character_favorites.clear()
	p1_house_character_summons.clear()
	p2_house_character_summons.clear()
	p1_summon_progress.clear()
	p2_summon_progress.clear()
	unlocked_summons.clear()
	summon_egg_shards.clear()
	pet_feed = 0
	stage_summon_egg_drop_mult.clear()
	run_summon_egg_dropped = false
	_summon_test_level_cycle_idx = 0
	p1_pinball_bg_pattern = GameData.PINBALL_BG_PATTERN_DEFAULT
	p1_ui_bg_main = GameData.PINBALL_BG_PATTERN_DEFAULT
	p1_ui_bg_panel = GameData.PINBALL_BG_PATTERN_DEFAULT
	p1_ui_bg_dialog = GameData.PINBALL_BG_PATTERN_DEFAULT
	ui_bg_pattern_dim = 1.0
	house_favorite_unlocked_slots = GameData.HOUSE_FAVORITE_ARMAMENT_SLOTS_INITIAL
	reset_run()
	save_to_disk()


func reset_run() -> void:
	run_summon_egg_dropped = false
	last_result = {
		"won": false,
		"time": 0.0,
		"kills_p1": 0,
		"kills_p2": 0,
		"gold_reward": 0,
		"run_material_gains": {},
		"stage_id": "",
		"stage_name": "",
		"achievement_unlocks": [],
		"facility_unlocks": [],
		"summon_loot": [],
	}
	pending_summon_milestones.clear()


func grant_run_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	last_result["gold_reward"] = int(last_result.get("gold_reward", 0)) + amount
	save_to_disk()


func grant_rune_dust(amount: int) -> void:
	if amount <= 0:
		return
	rune_dust += amount
	save_to_disk()


func complete_quest(quest_id: String) -> void:
	if not completed_quests.has(quest_id):
		completed_quests.append(quest_id)


func is_quest_completed(quest_id: String) -> bool:
	return completed_quests.has(quest_id)


func grant_material(id: String, amount: int) -> bool:
	if id == "" or amount <= 0:
		return false
	if GameData.get_material_def(id).is_empty():
		return false
	materials[id] = get_material_amount(id) + amount
	save_to_disk()
	return true


## 戰鬥內拾取／事件發放：入庫並累計至本場結算（不含經驗）
func grant_run_material(id: String, amount: int) -> bool:
	if not grant_material(id, amount):
		return false
	var gains: Variant = last_result.get("run_material_gains", {})
	var bag: Dictionary = gains if gains is Dictionary else {}
	bag[id] = int(bag.get(id, 0)) + amount
	last_result["run_material_gains"] = bag
	return true


func get_material_amount(id: String) -> int:
	return int(materials.get(id, 0))


func spend_material(id: String, amount: int) -> bool:
	if id == "" or amount <= 0:
		return false
	if get_material_amount(id) < amount:
		return false
	materials[id] = get_material_amount(id) - amount
	save_to_disk()
	return true


func buy_merchant_material(id: String) -> bool:
	if not is_merchant_material_available(id):
		return false
	if not spend_gold(MERCHANT_MATERIAL_BUY_PRICE):
		return false
	return grant_material(id, 1)


func sell_merchant_material(id: String, amount: int = 1) -> bool:
	if amount <= 0 or not is_merchant_material_available(id):
		return false
	if not spend_material(id, amount):
		return false
	gold += MERCHANT_MATERIAL_SELL_PRICE * amount
	save_to_disk()
	return true


func mark_stage_completed(id: String) -> void:
	if id == "" or completed_stage_ids.has(id):
		return
	completed_stage_ids.append(id)
	save_to_disk()


func is_stage_completed(id: String) -> bool:
	return completed_stage_ids.has(id)


func is_merchant_material_available(id: String) -> bool:
	if GameData.is_village_base_resource(id):
		var unlock_stage: String = String(GameData.VILLAGE_RESOURCE_UNLOCK_STAGE.get(id, ""))
		return unlock_stage != "" and is_stage_completed(unlock_stage)
	return get_merchant_material_ids().has(id)


func get_merchant_material_ids() -> Array[String]:
	var ids: Array[String] = []
	for stage_id in completed_stage_ids:
		var stage: Dictionary = GameData.get_stage_def(stage_id)
		for drop in stage.get("material_drops", []):
			if not (drop is Dictionary):
				continue
			var id: String = String(drop.get("id", ""))
			if id != "" and not ids.has(id):
				ids.append(id)
	return ids


func record_achievement_progress(run_stats: Dictionary) -> Array[String]:
	var changed: bool = false
	for stat in DEFAULT_ACHIEVEMENT_STATS.keys():
		var add_value: float = float(run_stats.get(stat, 0.0))
		if add_value <= 0.0:
			continue
		var current: float = float(achievement_stats.get(stat, 0.0))
		achievement_stats[stat] = current + add_value
		changed = true
	var newly_unlocked: Array[String] = _check_achievement_unlocks()
	if changed or not newly_unlocked.is_empty():
		save_to_disk()
	return newly_unlocked


func is_achievement_unlocked(id: String) -> bool:
	return unlocked_achievements.has(id)


func achievement_progress(stat: String) -> float:
	return float(achievement_stats.get(stat, 0.0))


func save_to_disk() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "gold", gold)
	cfg.set_value("meta", "rune_dust", rune_dust)
	cfg.set_value("meta", "current_stage_id", current_stage_id)
	cfg.set_value("meta", "language", language)
	cfg.set_value("meta", "touch_controls_enabled", touch_controls_enabled)
	cfg.set_value("meta", "p1_armament", p1_armament)
	cfg.set_value("meta", "p2_armament", p2_armament)
	cfg.set_value("meta", "p1_last_village_character", p1_last_village_character)
	cfg.set_value("meta", "unlocked_characters", unlocked_characters)
	cfg.set_value("meta", "unlocked_weapons", unlocked_weapons)
	cfg.set_value("meta", "unlocked_weapon_slots", unlocked_weapon_slots)
	cfg.set_value("meta", "unlocked_common_upgrade_slots", unlocked_common_upgrade_slots)
	cfg.set_value("meta", "unlocked_armaments", unlocked_armaments)
	cfg.set_value("meta", "unlocked_armament_recipes", unlocked_armament_recipes)
	cfg.set_value("meta", "base_weapon_craft_migrated", true)
	cfg.set_value("meta", "blacksmith_rescued", blacksmith_rescued)
	cfg.set_value("meta", "merchant_rescued", merchant_rescued)
	cfg.set_value("meta", "tavern_owner_rescued", tavern_owner_rescued)
	cfg.set_value("meta", "tavern_traveler_today", tavern_traveler_today)
	cfg.set_value("meta", "tavern_traveler_last", tavern_traveler_last)
	cfg.set_value("meta", "village_day_count", village_day_count)
	cfg.set_value("meta", "rune_master_rescued", rune_master_rescued)
	cfg.set_value("meta", "farmer_rescued", farmer_rescued)
	cfg.set_value("meta", "blacksmith_tier2_unlocked", blacksmith_tier2_unlocked)
	cfg.set_value("meta", "quest_headman_intro_done", quest_headman_intro_done)
	cfg.set_value("meta", "quest_headman_starter_summon_done", quest_headman_starter_summon_done)
	cfg.set_value("meta", "quest_blacksmith_rewarded", quest_blacksmith_rewarded)
	cfg.set_value("meta", "completed_quests", completed_quests)
	cfg.set_value("meta", "village_facilities_unlocked", village_facilities_unlocked)
	cfg.set_value("meta", "village_facility_last_collect_unix", village_facility_last_collect_unix)
	cfg.set_value("meta", "farm_plots", farm_plots)
	cfg.set_value("meta", "water_charges", water_charges)
	cfg.set_value("meta", "completed_stage_ids", completed_stage_ids)
	cfg.set_value("meta", "materials", materials)
	cfg.set_value("meta", "achievement_stats", achievement_stats)
	cfg.set_value("meta", "unlocked_achievements", unlocked_achievements)
	cfg.set_value("meta", "unlocked_codex_monsters", unlocked_codex_monster_ids)
	cfg.set_value("meta", "p1_house_character_skins", p1_house_character_skins.duplicate())
	cfg.set_value("meta", "p2_house_character_skins", p2_house_character_skins.duplicate())
	cfg.set_value("meta", "p1_bow_arrow_skin", p1_bow_arrow_skin)
	cfg.set_value("meta", "p2_bow_arrow_skin", p2_bow_arrow_skin)
	cfg.set_value("meta", "p1_pinball_bg_pattern", p1_pinball_bg_pattern)
	cfg.set_value("meta", "p1_ui_bg_main", p1_ui_bg_main)
	cfg.set_value("meta", "p1_ui_bg_panel", p1_ui_bg_panel)
	cfg.set_value("meta", "p1_ui_bg_dialog", p1_ui_bg_dialog)
	cfg.set_value("meta", "ui_bg_pattern_dim", ui_bg_pattern_dim)
	cfg.set_value("meta", "unlocked_summons", unlocked_summons.duplicate())
	cfg.set_value("meta", "summon_egg_shards", summon_egg_shards.duplicate())
	cfg.set_value("meta", "pet_feed", pet_feed)
	cfg.set_value("meta", "stage_summon_egg_drop_mult", stage_summon_egg_drop_mult.duplicate())
	cfg.set_value("meta", "house_favorite_unlocked_slots", house_favorite_unlocked_slots)
	_write_house_favorites_cfg(cfg)
	_write_house_summons_cfg(cfg)
	_write_house_summon_progress_cfg(cfg)
	cfg.save(SAVE_PATH)


func _write_house_summon_progress_cfg(cfg: ConfigFile) -> void:
	for player_slot in ["p1", "p2"]:
		var prog_dict: Dictionary = _summon_progress_dict(player_slot)
		for raw_sid in prog_dict.keys():
			var sid: String = String(raw_sid)
			if sid == "" or sid == "none":
				continue
			var entry: Dictionary = get_summon_progress(player_slot, sid)
			cfg.set_value(
				HOUSE_SUMMON_PROGRESS_CFG_SECTION,
				_summon_progress_cfg_key(player_slot, sid),
				"%d,%d" % [int(entry.get("level", GameData.SUMMON_MIN_LEVEL)), int(entry.get("exp", 0))])


func _write_house_summons_cfg(cfg: ConfigFile) -> void:
	for player_slot in ["p1", "p2"]:
		var sum_dict: Dictionary = _house_summons_dict(player_slot)
		for raw_cid in sum_dict.keys():
			var cid: String = String(raw_cid)
			var slots: Array[String] = get_house_summons(player_slot, cid)
			cfg.set_value(
				HOUSE_SUMMONS_CFG_SECTION,
				_house_summons_cfg_key(player_slot, cid),
				"|".join(slots))


func _write_house_favorites_cfg(cfg: ConfigFile) -> void:
	for player_slot in ["p1", "p2"]:
		var fav_dict: Dictionary = _house_favorites_dict(player_slot)
		for raw_cid in fav_dict.keys():
			var cid: String = String(raw_cid)
			var slots: Array[String] = get_house_favorite_armaments(player_slot, cid)
			cfg.set_value(
				HOUSE_FAVORITES_CFG_SECTION,
				_house_favorites_cfg_key(player_slot, cid),
				"|".join(slots))


func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		touch_controls_enabled = _default_touch_controls()
		unlocked_weapons = _default_unlocked_weapons()
		unlocked_armaments = ["none"]
		unlocked_armament_recipes.clear()
		materials = DEFAULT_MATERIALS.duplicate()
		achievement_stats = DEFAULT_ACHIEVEMENT_STATS.duplicate()
		unlocked_codex_monster_ids.clear()
		p1_house_character_skins.clear()
		p1_house_character_favorites.clear()
		p2_house_character_skins.clear()
		p2_house_character_favorites.clear()
		p1_house_character_summons.clear()
		p2_house_character_summons.clear()
		p1_summon_progress.clear()
		p2_summon_progress.clear()
		unlocked_summons.clear()
		summon_egg_shards.clear()
		pet_feed = 0
		stage_summon_egg_drop_mult.clear()
		run_summon_egg_dropped = false
		quest_headman_starter_summon_done = false
		p1_bow_arrow_skin = "default"
		p2_bow_arrow_skin = "default"
		p1_pinball_bg_pattern = GameData.PINBALL_BG_PATTERN_DEFAULT
		p1_ui_bg_main = GameData.PINBALL_BG_PATTERN_DEFAULT
		p1_ui_bg_panel = GameData.PINBALL_BG_PATTERN_DEFAULT
		p1_ui_bg_dialog = GameData.PINBALL_BG_PATTERN_DEFAULT
		ui_bg_pattern_dim = 1.0
		house_favorite_unlocked_slots = GameData.HOUSE_FAVORITE_ARMAMENT_SLOTS_INITIAL
		roll_tavern_traveler_for_new_day()
		return
	var should_save_migration: bool = not bool(cfg.get_value(
		"meta", "base_weapon_craft_migrated", false))
	gold = int(cfg.get_value("meta", "gold", 0))
	rune_dust = int(cfg.get_value("meta", "rune_dust", 0))
	current_stage_id = String(cfg.get_value("meta", "current_stage_id", "slime_forest"))
	language = String(cfg.get_value("meta", "language", ""))
	blacksmith_rescued = bool(cfg.get_value("meta", "blacksmith_rescued", false))
	merchant_rescued = bool(cfg.get_value("meta", "merchant_rescued", false))
	tavern_owner_rescued = bool(cfg.get_value("meta", "tavern_owner_rescued", false))
	tavern_traveler_today = int(cfg.get_value("meta", "tavern_traveler_today", 0))
	tavern_traveler_last = int(cfg.get_value("meta", "tavern_traveler_last", 0))
	village_day_count = int(cfg.get_value("meta", "village_day_count", 0))
	ensure_tavern_traveler_for_today()
	rune_master_rescued = bool(cfg.get_value("meta", "rune_master_rescued", false))
	farmer_rescued = bool(cfg.get_value("meta", "farmer_rescued", false))
	blacksmith_tier2_unlocked = bool(cfg.get_value("meta", "blacksmith_tier2_unlocked", false))
	quest_headman_intro_done = bool(cfg.get_value("meta", "quest_headman_intro_done", false))
	quest_headman_starter_summon_done = bool(cfg.get_value(
		"meta", "quest_headman_starter_summon_done", false))
	quest_blacksmith_rewarded = bool(cfg.get_value("meta", "quest_blacksmith_rewarded", false))
	completed_quests.clear()
	for qid in cfg.get_value("meta", "completed_quests", []):
		completed_quests.append(String(qid))
	p1_last_village_character = String(cfg.get_value("meta", "p1_last_village_character", ""))
	_load_village_facilities(cfg)
	_load_farm_state(cfg)
	_load_completed_stages(cfg)
	touch_controls_enabled = bool(cfg.get_value(
		"meta", "touch_controls_enabled", _default_touch_controls()))
	var saved_unlocked: Array = cfg.get_value(
		"meta", "unlocked_characters", DEFAULT_UNLOCKED_CHARACTERS)
	unlocked_characters.clear()
	for id in saved_unlocked:
		var cid: String = String(id)
		if cid != "" and not unlocked_characters.has(cid):
			unlocked_characters.append(cid)
	_ensure_default_unlocks()
	var saved_weapons: Array = cfg.get_value(
		"meta", "unlocked_weapons", _default_unlocked_weapons())
	unlocked_weapons.clear()
	for id in saved_weapons:
		var wid: String = String(id)
		if wid != "" and not unlocked_weapons.has(wid):
			unlocked_weapons.append(wid)
	unlocked_weapon_slots = clampi(int(cfg.get_value(
		"meta", "unlocked_weapon_slots", DEFAULT_UNLOCKED_WEAPON_SLOTS)),
		1, MAX_WEAPON_SLOTS)
	unlocked_common_upgrade_slots = clampi(int(cfg.get_value(
		"meta", "unlocked_common_upgrade_slots", DEFAULT_UNLOCKED_COMMON_UPGRADE_SLOTS)),
		GameData.COMMON_UPGRADE_SLOT_INITIAL, GameData.COMMON_UPGRADE_SLOT_MAX)
	if unlocked_weapons.is_empty():
		unlocked_weapons = _default_unlocked_weapons()
	else:
		_ensure_default_weapon_unlocks()
	if should_save_migration:
		for wid in BLACKSMITH_CRAFT_WEAPON_IDS:
			unlocked_weapons.erase(wid)
	var saved_armaments: Array = cfg.get_value("meta", "unlocked_armaments", ["none"])
	unlocked_armaments.clear()
	for id in saved_armaments:
		var aid: String = String(id)
		if aid != "" and not unlocked_armaments.has(aid):
			unlocked_armaments.append(aid)
	if not unlocked_armaments.has("none"):
		unlocked_armaments.insert(0, "none")
	p1_armament = String(cfg.get_value("meta", "p1_armament", "none"))
	p2_armament = String(cfg.get_value("meta", "p2_armament", "none"))
	if not is_armament_unlocked(p1_armament):
		p1_armament = "none"
	if not is_armament_unlocked(p2_armament):
		p2_armament = "none"
	_load_materials(cfg)
	_load_achievement_state(cfg)
	_load_armament_recipes(cfg)
	_load_codex_monster_unlocks(cfg)
	_load_house_state(cfg)
	if should_save_migration:
		save_to_disk()


func _load_house_skins_from_meta(cfg: ConfigFile, meta_key: String, player_slot: String) -> void:
	var skins: Dictionary = _house_skins_dict(player_slot)
	skins.clear()
	var saved_skins: Variant = cfg.get_value("meta", meta_key, {})
	if saved_skins is Dictionary:
		for k in saved_skins.keys():
			var cid: String = String(k)
			var sid: String = String(saved_skins[k])
			if cid != "" and sid != "" and sid != "default":
				skins[cid] = sid


func _parse_house_favorites_line(raw_line: String) -> Array[String]:
	var slots: Array[String] = []
	for part in raw_line.split("|", false):
		var aid: String = String(part)
		if aid == "":
			aid = "none"
		slots.append(aid)
	while slots.size() < GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS:
		slots.append("none")
	if slots.size() > GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS:
		slots = slots.slice(0, GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS)
	return slots


func _parse_house_summons_line(raw_line: String) -> Array[String]:
	var slots: Array[String] = []
	for part in raw_line.split("|", false):
		var sid: String = String(part)
		if sid == "":
			sid = "none"
		slots.append(sid)
	while slots.size() < GameData.P1_HOUSE_SUMMON_SLOTS:
		slots.append("none")
	if slots.size() > GameData.P1_HOUSE_SUMMON_SLOTS:
		slots = slots.slice(0, GameData.P1_HOUSE_SUMMON_SLOTS)
	return slots


func _load_house_summons(cfg: ConfigFile) -> void:
	p1_house_character_summons.clear()
	p2_house_character_summons.clear()
	if cfg.has_section(HOUSE_SUMMONS_CFG_SECTION):
		for key in cfg.get_section_keys(HOUSE_SUMMONS_CFG_SECTION):
			var key_s: String = String(key)
			if key_s == "":
				continue
			var player_slot: String = "p1"
			var char_id: String = key_s
			if key_s.contains(":"):
				var parts: PackedStringArray = key_s.split(":", true, 1)
				player_slot = String(parts[0])
				char_id = String(parts[1])
			if not _house_player_slot_valid(player_slot) or char_id == "":
				continue
			var raw_line: String = String(cfg.get_value(HOUSE_SUMMONS_CFG_SECTION, key, ""))
			_house_summons_dict(player_slot)[char_id] = _parse_house_summons_line(raw_line)
	for player_slot in ["p1", "p2"]:
		var sum_dict: Dictionary = _house_summons_dict(player_slot)
		for raw_cid in sum_dict.keys():
			var cid: String = String(raw_cid)
			_ensure_house_char_summons(player_slot, cid)
			var arr: Array = sum_dict[cid]
			for i in arr.size():
				var sid: String = String(arr[i])
				if sid != "none" and not GameData.is_valid_summon_id(sid):
					arr[i] = "none"
				elif sid != "none":
					ensure_summon_progress(player_slot, sid)


func _parse_house_summon_progress_line(raw_line: String) -> Dictionary:
	var parts: PackedStringArray = raw_line.split(",", false)
	if parts.size() < 2:
		return _default_summon_progress_entry()
	return _normalize_summon_progress_entry({
		"level": int(parts[0]),
		"exp": int(parts[1]),
	})


func _load_house_summon_progress(cfg: ConfigFile) -> void:
	p1_summon_progress.clear()
	p2_summon_progress.clear()
	if not cfg.has_section(HOUSE_SUMMON_PROGRESS_CFG_SECTION):
		return
	for key in cfg.get_section_keys(HOUSE_SUMMON_PROGRESS_CFG_SECTION):
		var key_s: String = String(key)
		if key_s == "":
			continue
		var player_slot: String = "p1"
		var summon_id: String = key_s
		if key_s.contains(":"):
			var parts: PackedStringArray = key_s.split(":", true, 1)
			player_slot = String(parts[0])
			summon_id = String(parts[1])
		if not _house_player_slot_valid(player_slot) or not GameData.is_valid_summon_id(summon_id):
			continue
		if summon_id == "none":
			continue
		var raw_line: String = String(cfg.get_value(HOUSE_SUMMON_PROGRESS_CFG_SECTION, key, ""))
		_summon_progress_dict(player_slot)[summon_id] = _parse_house_summon_progress_line(raw_line)


func _infer_house_favorite_unlocked_slots_from_favorites() -> int:
	var max_i: int = -1
	for player_slot in ["p1", "p2"]:
		var fav_dict: Dictionary = _house_favorites_dict(player_slot)
		for raw_cid in fav_dict.keys():
			var cid: String = String(raw_cid)
			_ensure_house_char_favorites(player_slot, cid)
			var arr: Array = fav_dict[cid]
			for i in mini(arr.size(), GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS):
				if String(arr[i]) != "none":
					max_i = maxi(max_i, i)
	return clampi(
		maxi(GameData.HOUSE_FAVORITE_ARMAMENT_SLOTS_INITIAL, max_i + 1),
		GameData.HOUSE_FAVORITE_ARMAMENT_SLOTS_INITIAL,
		GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS)


func _load_house_favorite_unlocked_slots(cfg: ConfigFile) -> void:
	if cfg.has_section_key("meta", "house_favorite_unlocked_slots"):
		house_favorite_unlocked_slots = clampi(int(cfg.get_value(
			"meta", "house_favorite_unlocked_slots",
			GameData.HOUSE_FAVORITE_ARMAMENT_SLOTS_INITIAL)),
			GameData.HOUSE_FAVORITE_ARMAMENT_SLOTS_INITIAL,
			GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS)
		return
	house_favorite_unlocked_slots = _infer_house_favorite_unlocked_slots_from_favorites()
	save_to_disk()


func _load_unlocked_summons(cfg: ConfigFile) -> void:
	unlocked_summons.clear()
	if cfg.has_section_key("meta", "unlocked_summons"):
		var saved: Array = cfg.get_value("meta", "unlocked_summons", [])
		for id in saved:
			var sid: String = String(id)
			if sid != "" and sid != "none" and GameData.is_valid_summon_id(sid):
				if not unlocked_summons.has(sid):
					unlocked_summons.append(sid)
	else:
		_migrate_unlocked_summons_from_legacy()
		if not unlocked_summons.is_empty():
			save_to_disk()
	if not quest_headman_starter_summon_done and not unlocked_summons.is_empty():
		quest_headman_starter_summon_done = true
		if not is_quest_completed("headman_starter_summon"):
			complete_quest("headman_starter_summon")


func _load_summon_loot_state(cfg: ConfigFile) -> void:
	summon_egg_shards.clear()
	pet_feed = maxi(0, int(cfg.get_value("meta", "pet_feed", 0)))
	stage_summon_egg_drop_mult.clear()
	var saved_shards: Variant = cfg.get_value("meta", "summon_egg_shards", {})
	if saved_shards is Dictionary:
		for raw_sid in (saved_shards as Dictionary).keys():
			var sid: String = String(raw_sid)
			if sid == "" or sid == "none" or not GameData.is_valid_summon_id(sid):
				continue
			if is_summon_unlocked(sid):
				continue
			var count: int = maxi(0, int((saved_shards as Dictionary)[raw_sid]))
			if count > 0:
				summon_egg_shards[sid] = count
	var saved_decay: Variant = cfg.get_value("meta", "stage_summon_egg_drop_mult", {})
	if saved_decay is Dictionary:
		for raw_stage in (saved_decay as Dictionary).keys():
			var stage_id: String = String(raw_stage)
			if stage_id == "":
				continue
			stage_summon_egg_drop_mult[stage_id] = clampf(
				float((saved_decay as Dictionary)[raw_stage]),
				GameData.SUMMON_EGG_STAGE_DECAY_MIN, 1.0)


func _migrate_unlocked_summons_from_legacy() -> void:
	for player_slot in ["p1", "p2"]:
		for raw_sid in _summon_progress_dict(player_slot).keys():
			grant_summon_unlock(String(raw_sid), false)
		var sum_dict: Dictionary = _house_summons_dict(player_slot)
		for raw_cid in sum_dict.keys():
			for sid in get_house_summons(player_slot, String(raw_cid)):
				if sid != "none":
					grant_summon_unlock(sid, false)


func _sanitize_house_summons_unlocks() -> void:
	for player_slot in ["p1", "p2"]:
		var sum_dict: Dictionary = _house_summons_dict(player_slot)
		for raw_cid in sum_dict.keys():
			var cid: String = String(raw_cid)
			_ensure_house_char_summons(player_slot, cid)
			var arr: Array = sum_dict[cid]
			var changed: bool = false
			for i in arr.size():
				var sid: String = String(arr[i])
				if sid != "none" and not is_summon_unlocked(sid):
					arr[i] = "none"
					changed = true
			if changed:
				sum_dict[cid] = arr.duplicate()


func _load_house_state(cfg: ConfigFile) -> void:
	_load_house_skins_from_meta(cfg, "p1_house_character_skins", "p1")
	_load_house_skins_from_meta(cfg, "p2_house_character_skins", "p2")
	p1_bow_arrow_skin = String(cfg.get_value("meta", "p1_bow_arrow_skin", ""))
	if p1_bow_arrow_skin == "":
		p1_bow_arrow_skin = GameData.migrate_legacy_bow_arrow_skin(
			String(cfg.get_value("meta", "p1_bow_visual_skin", "default")),
			String(cfg.get_value("meta", "p1_bow_element_arrow_mode", "random")))
	p2_bow_arrow_skin = String(cfg.get_value("meta", "p2_bow_arrow_skin", ""))
	if p2_bow_arrow_skin == "":
		p2_bow_arrow_skin = GameData.migrate_legacy_bow_arrow_skin(
			String(cfg.get_value("meta", "p2_bow_visual_skin", "default")),
			String(cfg.get_value("meta", "p2_bow_element_arrow_mode", "random")))
	if not GameData.is_valid_bow_arrow_skin(p1_bow_arrow_skin):
		p1_bow_arrow_skin = "default"
	p1_pinball_bg_pattern = String(cfg.get_value(
		"meta", "p1_pinball_bg_pattern", GameData.PINBALL_BG_PATTERN_DEFAULT))
	p1_ui_bg_main = String(cfg.get_value(
		"meta", "p1_ui_bg_main", GameData.PINBALL_BG_PATTERN_DEFAULT))
	p1_ui_bg_panel = String(cfg.get_value(
		"meta", "p1_ui_bg_panel", GameData.PINBALL_BG_PATTERN_DEFAULT))
	p1_ui_bg_dialog = String(cfg.get_value(
		"meta", "p1_ui_bg_dialog", GameData.PINBALL_BG_PATTERN_DEFAULT))
	ui_bg_pattern_dim = float(cfg.get_value("meta", "ui_bg_pattern_dim", 1.0))
	ui_bg_pattern_dim = clampf(ui_bg_pattern_dim, 0.0, 1.0)
	if not GameData.is_valid_pinball_bg_pattern(p1_pinball_bg_pattern):
		p1_pinball_bg_pattern = GameData.PINBALL_BG_PATTERN_DEFAULT
	if not GameData.is_valid_pinball_bg_pattern(p1_ui_bg_main):
		p1_ui_bg_main = GameData.PINBALL_BG_PATTERN_DEFAULT
	if not GameData.is_valid_pinball_bg_pattern(p1_ui_bg_panel):
		p1_ui_bg_panel = GameData.PINBALL_BG_PATTERN_DEFAULT
	if not GameData.is_valid_pinball_bg_pattern(p1_ui_bg_dialog):
		p1_ui_bg_dialog = GameData.PINBALL_BG_PATTERN_DEFAULT
	if not GameData.is_valid_bow_arrow_skin(p2_bow_arrow_skin):
		p2_bow_arrow_skin = "default"
	p1_house_character_favorites.clear()
	p2_house_character_favorites.clear()
	if cfg.has_section(HOUSE_FAVORITES_CFG_SECTION):
		for key in cfg.get_section_keys(HOUSE_FAVORITES_CFG_SECTION):
			var key_s: String = String(key)
			if key_s == "":
				continue
			var player_slot: String = "p1"
			var char_id: String = key_s
			if key_s.contains(":"):
				var parts: PackedStringArray = key_s.split(":", true, 1)
				player_slot = String(parts[0])
				char_id = String(parts[1])
			if not _house_player_slot_valid(player_slot) or char_id == "":
				continue
			var raw_line: String = String(cfg.get_value(HOUSE_FAVORITES_CFG_SECTION, key, ""))
			_house_favorites_dict(player_slot)[char_id] = _parse_house_favorites_line(raw_line)
	if p1_house_character_favorites.is_empty():
		var saved_char_favs: Variant = cfg.get_value("meta", "p1_house_character_favorites", {})
		if saved_char_favs is Dictionary:
			for k in saved_char_favs.keys():
				var cid3: String = String(k)
				var raw_arr: Variant = saved_char_favs[k]
				if cid3 == "" or not (raw_arr is Array):
					continue
				var slots2: Array[String] = []
				for item in raw_arr:
					var aid2: String = String(item)
					if aid2 == "":
						aid2 = "none"
					slots2.append(aid2)
				while slots2.size() < GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS:
					slots2.append("none")
				if slots2.size() > GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS:
					slots2 = slots2.slice(0, GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS)
				p1_house_character_favorites[cid3] = slots2
	if p1_house_character_favorites.is_empty():
		var legacy_favs: Variant = cfg.get_value("meta", "p1_house_favorite_armaments", [])
		if legacy_favs is Array and (legacy_favs as Array).size() > 0:
			var legacy_slots: Array[String] = []
			for item in legacy_favs:
				var aid_l: String = String(item)
				if aid_l == "":
					aid_l = "none"
				legacy_slots.append(aid_l)
			while legacy_slots.size() < GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS:
				legacy_slots.append("none")
			if legacy_slots.size() > GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS:
				legacy_slots = legacy_slots.slice(0, GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS)
			p1_house_character_favorites[p1_character] = legacy_slots
			save_to_disk()
	_load_house_summons(cfg)
	_load_house_summon_progress(cfg)
	_load_unlocked_summons(cfg)
	_load_summon_loot_state(cfg)
	_sanitize_house_summons_unlocks()
	_load_house_favorite_unlocked_slots(cfg)
	for player_slot in ["p1", "p2"]:
		var fav_dict: Dictionary = _house_favorites_dict(player_slot)
		for raw_cid in fav_dict.keys():
			var cid3: String = String(raw_cid)
			_ensure_house_char_favorites(player_slot, cid3)
			_dedupe_house_char_favorites(player_slot, cid3)
			var arr: Array = fav_dict[cid3]
			for i in arr.size():
				var aid2: String = String(arr[i])
				if aid2 != "none" and not is_armament_unlocked(aid2):
					arr[i] = "none"
	_dedupe_global_house_favorites()
	for player_slot in ["p1", "p2"]:
		var skins: Dictionary = _house_skins_dict(player_slot)
		for cid in skins.keys():
			var sid2: String = String(skins[cid])
			var ok: bool = false
			for opt in GameData.character_house_skin_options(cid, unlocked_characters):
				if String(opt.get("id", "")) == sid2:
					ok = true
					break
			if not ok:
				skins.erase(cid)


func _ensure_default_unlocks() -> void:
	for cid in DEFAULT_UNLOCKED_CHARACTERS:
		_add_unlocked_character(cid)


func _add_unlocked_character(id: String) -> bool:
	if id == "":
		return false
	if GameData.get_character_def(id).is_empty():
		return false
	if unlocked_characters.has(id):
		return false
	unlocked_characters.append(id)
	return true


func _check_achievement_unlocks() -> Array[String]:
	var newly_unlocked: Array[String] = []
	for ach in ACHIEVEMENTS:
		var ach_id: String = String(ach.get("id", ""))
		if ach_id == "" or unlocked_achievements.has(ach_id):
			continue
		var stat: String = String(ach.get("stat", ""))
		var threshold: float = float(ach.get("threshold", 0.0))
		if threshold <= 0.0 or achievement_progress(stat) < threshold:
			continue
		unlocked_achievements.append(ach_id)
		var character_id: String = String(ach.get("character_id", ""))
		if _add_unlocked_character(character_id):
			newly_unlocked.append(character_id)
	return newly_unlocked


func _load_achievement_state(cfg: ConfigFile) -> void:
	achievement_stats = DEFAULT_ACHIEVEMENT_STATS.duplicate()
	var saved_stats: Dictionary = cfg.get_value(
		"meta", "achievement_stats", DEFAULT_ACHIEVEMENT_STATS)
	for stat in DEFAULT_ACHIEVEMENT_STATS.keys():
		achievement_stats[stat] = float(saved_stats.get(stat, DEFAULT_ACHIEVEMENT_STATS[stat]))
	var saved_achievements: Array = cfg.get_value("meta", "unlocked_achievements", [])
	unlocked_achievements.clear()
	for id in saved_achievements:
		var ach_id: String = String(id)
		if ach_id != "" and not unlocked_achievements.has(ach_id):
			unlocked_achievements.append(ach_id)
	_check_achievement_unlocks()


func _load_materials(cfg: ConfigFile) -> void:
	materials = DEFAULT_MATERIALS.duplicate()
	var saved_materials: Dictionary = cfg.get_value("meta", "materials", DEFAULT_MATERIALS)
	for m in GameData.MATERIALS:
		var id: String = String(m.get("id", ""))
		if id != "":
			materials[id] = max(0, int(saved_materials.get(id, 0)))
	if saved_materials.has("rope"):
		var legacy_rope: int = maxi(0, int(saved_materials.get("rope", 0)))
		if legacy_rope > 0:
			materials["rag"] = int(materials.get("rag", 0)) + legacy_rope


func _load_village_facilities(cfg: ConfigFile) -> void:
	village_facilities_unlocked.clear()
	var saved_unlocked: Dictionary = cfg.get_value("meta", "village_facilities_unlocked", {})
	if saved_unlocked is Dictionary:
		for key in saved_unlocked.keys():
			if bool(saved_unlocked[key]):
				village_facilities_unlocked[String(key)] = true
	village_facility_last_collect_unix.clear()
	var saved_collect: Dictionary = cfg.get_value("meta", "village_facility_last_collect_unix", {})
	if saved_collect is Dictionary:
		for key in saved_collect.keys():
			village_facility_last_collect_unix[String(key)] = float(saved_collect[key])


func _load_farm_state(cfg: ConfigFile) -> void:
	farm_plots.clear()
	water_charges = int(cfg.get_value("meta", "water_charges", 0))
	var saved_plots: Dictionary = cfg.get_value("meta", "farm_plots", {})
	if saved_plots is Dictionary:
		for key in saved_plots.keys():
			var raw: Variant = saved_plots[key]
			if raw is Dictionary:
				farm_plots[String(key)] = (raw as Dictionary).duplicate()
	_ensure_farm_plot_keys()


func _load_completed_stages(cfg: ConfigFile) -> void:
	completed_stage_ids.clear()
	var saved_stages: Array = cfg.get_value("meta", "completed_stage_ids", [])
	for id in saved_stages:
		var stage_id: String = String(id)
		if stage_id != "" and not completed_stage_ids.has(stage_id):
			completed_stage_ids.append(stage_id)


func _ensure_default_weapon_unlocks() -> void:
	for wid in _default_unlocked_weapons():
		if not unlocked_weapons.has(wid):
			unlocked_weapons.append(wid)


func _default_unlocked_weapons() -> Array[String]:
	var ids: Array[String] = []
	for w in GameData.WEAPONS:
		var wid: String = String(w.get("id", ""))
		if wid != "" and not DEFAULT_LOCKED_WEAPONS.has(wid) \
				and not BLACKSMITH_CRAFT_WEAPON_IDS.has(wid):
			ids.append(wid)
	return ids


# 沒有存檔時的預設值：網頁／手機自動開啟觸控介面，桌機預設關閉。
func _default_touch_controls() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("web"):
		return true
	return DisplayServer.is_touchscreen_available()
