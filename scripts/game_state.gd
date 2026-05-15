extends Node
## 跨場景共享的狀態：哪幾位玩家、選的角色／被動／技能、結果。
## 也保存「局外」進度（金幣、目前關卡），會寫入 user://save.cfg。

const SAVE_PATH := "user://save.cfg"
const HOUSE_FAVORITES_CFG_SECTION := "house_favorites"
const DEFAULT_UNLOCKED_CHARACTERS: Array[String] = ["swordsman", "ranger"]
const MAX_WEAPON_SLOTS := 5
const DEFAULT_UNLOCKED_WEAPON_SLOTS := 3
const DEFAULT_LOCKED_WEAPONS: Array[String] = ["melody", "claw", "shard", "poison", "holy"]
const BLACKSMITH_CRAFT_WEAPON_IDS: Array[String] = ["axe", "magic_bullet"]
const BLACKSMITH_SLOT_COSTS: Dictionary = {4: 200, 5: 350}
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

# 角色選擇完成後要去哪：
#   "battle"  → res://scenes/Game.tscn
#   "village" → res://scenes/Village.tscn
var next_scene: String = "battle"

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
var unlocked_armaments: Array[String] = ["none"]
## 已取得製作書、可在鐵匠製作的武裝 id（第二關偶發事件等）
var unlocked_armament_recipes: Array[String] = []
var blacksmith_rescued: bool = false
var merchant_rescued: bool = false
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

# 顯示語系：留空則沿用 project.godot 的 locale。
# 受支援：zh_TW（預設）／zh_CN／en；新語系加在 strings.csv 後可動態切換。
var language: String = ""

# 觸控介面開關（給手機 / 網頁版用；桌機平台仍可手動開啟測試）
var touch_controls_enabled: bool = false

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
	save_to_disk()


func is_weapon_unlocked(id: String) -> bool:
	return unlocked_weapons.has(id)


func get_unlocked_weapon_slot_count() -> int:
	return clampi(unlocked_weapon_slots, 1, MAX_WEAPON_SLOTS)


func unlock_all_weapons_and_slots() -> void:
	unlocked_weapons.clear()
	for w in GameData.WEAPONS:
		unlocked_weapons.append(String(w.get("id", "")))
	unlocked_weapon_slots = MAX_WEAPON_SLOTS
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
	var cost: int = next_weapon_slot_unlock_cost()
	if cost < 0 or not spend_gold(cost):
		return false
	unlocked_weapon_slots = clampi(unlocked_weapon_slots + 1, 1, MAX_WEAPON_SLOTS)
	save_to_disk()
	return true


func next_locked_weapon_id() -> String:
	for wid in DEFAULT_LOCKED_WEAPONS:
		if not unlocked_weapons.has(wid):
			return wid
	for w in GameData.WEAPONS:
		var id: String = String(w.get("id", ""))
		if id != "" and not unlocked_weapons.has(id) and not BLACKSMITH_CRAFT_WEAPON_IDS.has(id):
			return id
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
			for i in slots.size():
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
	if index < 0 or index >= GameData.P1_HOUSE_FAVORITE_ARMAMENT_SLOTS:
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
	var arr: Array = _house_favorites_dict(player_slot)[char_id]
	var seen: Dictionary = {}
	var changed: bool = false
	for i in arr.size():
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
	for aid in get_house_favorite_armaments(player_slot, char_id):
		if aid != "none" and is_armament_unlocked(aid):
			out.append(aid)
	return out


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


func rescue_blacksmith() -> void:
	if blacksmith_rescued:
		return
	blacksmith_rescued = true
	save_to_disk()


func rescue_merchant() -> void:
	if merchant_rescued:
		return
	merchant_rescued = true
	save_to_disk()


func reset_account() -> void:
	gold = 0
	current_stage_id = "slime_forest"
	unlocked_characters = DEFAULT_UNLOCKED_CHARACTERS.duplicate()
	unlocked_weapons = _default_unlocked_weapons()
	unlocked_weapon_slots = DEFAULT_UNLOCKED_WEAPON_SLOTS
	unlocked_armaments = ["none"]
	unlocked_armament_recipes.clear()
	blacksmith_rescued = false
	merchant_rescued = false
	completed_stage_ids.clear()
	rune_dust = 0
	materials = DEFAULT_MATERIALS.duplicate()
	achievement_stats = DEFAULT_ACHIEVEMENT_STATS.duplicate()
	unlocked_achievements.clear()
	unlocked_codex_monster_ids.clear()
	p1_character = "swordsman"
	p2_character = "ranger"
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
	reset_run()
	save_to_disk()


func reset_run() -> void:
	last_result = {
		"won": false,
		"time": 0.0,
		"kills_p1": 0,
		"kills_p2": 0,
		"gold_reward": 0,
		"stage_id": "",
		"stage_name": "",
		"achievement_unlocks": [],
	}


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


func grant_material(id: String, amount: int) -> bool:
	if id == "" or amount <= 0:
		return false
	if GameData.get_material_def(id).is_empty():
		return false
	materials[id] = get_material_amount(id) + amount
	save_to_disk()
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
	cfg.set_value("meta", "unlocked_characters", unlocked_characters)
	cfg.set_value("meta", "unlocked_weapons", unlocked_weapons)
	cfg.set_value("meta", "unlocked_weapon_slots", unlocked_weapon_slots)
	cfg.set_value("meta", "unlocked_armaments", unlocked_armaments)
	cfg.set_value("meta", "unlocked_armament_recipes", unlocked_armament_recipes)
	cfg.set_value("meta", "base_weapon_craft_migrated", true)
	cfg.set_value("meta", "blacksmith_rescued", blacksmith_rescued)
	cfg.set_value("meta", "merchant_rescued", merchant_rescued)
	cfg.set_value("meta", "completed_stage_ids", completed_stage_ids)
	cfg.set_value("meta", "materials", materials)
	cfg.set_value("meta", "achievement_stats", achievement_stats)
	cfg.set_value("meta", "unlocked_achievements", unlocked_achievements)
	cfg.set_value("meta", "unlocked_codex_monsters", unlocked_codex_monster_ids)
	cfg.set_value("meta", "p1_house_character_skins", p1_house_character_skins.duplicate())
	cfg.set_value("meta", "p2_house_character_skins", p2_house_character_skins.duplicate())
	_write_house_favorites_cfg(cfg)
	cfg.save(SAVE_PATH)


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
		return
	var should_save_migration: bool = not bool(cfg.get_value(
		"meta", "base_weapon_craft_migrated", false))
	gold = int(cfg.get_value("meta", "gold", 0))
	rune_dust = int(cfg.get_value("meta", "rune_dust", 0))
	current_stage_id = String(cfg.get_value("meta", "current_stage_id", "slime_forest"))
	language = String(cfg.get_value("meta", "language", ""))
	blacksmith_rescued = bool(cfg.get_value("meta", "blacksmith_rescued", false))
	merchant_rescued = bool(cfg.get_value("meta", "merchant_rescued", false))
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


func _load_house_state(cfg: ConfigFile) -> void:
	_load_house_skins_from_meta(cfg, "p1_house_character_skins", "p1")
	_load_house_skins_from_meta(cfg, "p2_house_character_skins", "p2")
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
