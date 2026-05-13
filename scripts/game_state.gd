extends Node
## 跨場景共享的狀態：哪幾位玩家、選的角色／被動／技能、結果。
## 也保存「局外」進度（金幣、目前關卡），會寫入 user://save.cfg。

const SAVE_PATH := "user://save.cfg"
const DEFAULT_UNLOCKED_CHARACTERS: Array[String] = ["swordsman", "ranger"]
const MAX_WEAPON_SLOTS := 5
const DEFAULT_UNLOCKED_WEAPON_SLOTS := 3
const DEFAULT_LOCKED_WEAPONS: Array[String] = ["melody", "claw", "shard", "poison", "holy"]
const BLACKSMITH_SLOT_COSTS: Dictionary = {4: 200, 5: 350}
const BLACKSMITH_WEAPON_KIND_COST := 180
const BLACKSMITH_ARMAMENT_COST := 160

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
var blacksmith_rescued: bool = false
var rune_dust: int = 0

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


func unlock_all_characters() -> void:
	unlocked_characters.clear()
	for c in GameData.CHARACTERS:
		unlocked_characters.append(String(c.get("id", "")))
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
		if id != "" and not unlocked_weapons.has(id):
			return id
	return ""


func buy_next_weapon_kind() -> String:
	var wid: String = next_locked_weapon_id()
	if wid == "" or not spend_gold(BLACKSMITH_WEAPON_KIND_COST):
		return ""
	unlocked_weapons.append(wid)
	save_to_disk()
	return wid


func is_armament_unlocked(id: String) -> bool:
	return unlocked_armaments.has(id)


func buy_armament(id: String) -> bool:
	if id == "none" or is_armament_unlocked(id):
		return false
	if GameData.get_armament_def(id).is_empty():
		return false
	if not spend_gold(BLACKSMITH_ARMAMENT_COST):
		return false
	unlocked_armaments.append(id)
	save_to_disk()
	return true


func rescue_blacksmith() -> void:
	if blacksmith_rescued:
		return
	blacksmith_rescued = true
	save_to_disk()


func reset_account() -> void:
	gold = 0
	current_stage_id = "slime_forest"
	unlocked_characters = DEFAULT_UNLOCKED_CHARACTERS.duplicate()
	unlocked_weapons = _default_unlocked_weapons()
	unlocked_weapon_slots = DEFAULT_UNLOCKED_WEAPON_SLOTS
	unlocked_armaments = ["none"]
	blacksmith_rescued = false
	rune_dust = 0
	p1_character = "swordsman"
	p2_character = "ranger"
	p1_passive = "none"
	p1_skill = "none"
	p2_passive = "none"
	p2_skill = "none"
	p1_armament = "none"
	p2_armament = "none"
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
	cfg.set_value("meta", "blacksmith_rescued", blacksmith_rescued)
	cfg.save(SAVE_PATH)


func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		touch_controls_enabled = _default_touch_controls()
		unlocked_weapons = _default_unlocked_weapons()
		unlocked_armaments = ["none"]
		return
	gold = int(cfg.get_value("meta", "gold", 0))
	rune_dust = int(cfg.get_value("meta", "rune_dust", 0))
	current_stage_id = String(cfg.get_value("meta", "current_stage_id", "slime_forest"))
	language = String(cfg.get_value("meta", "language", ""))
	blacksmith_rescued = bool(cfg.get_value("meta", "blacksmith_rescued", false))
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


func _ensure_default_unlocks() -> void:
	for cid in DEFAULT_UNLOCKED_CHARACTERS:
		if not unlocked_characters.has(cid):
			unlocked_characters.append(cid)


func _ensure_default_weapon_unlocks() -> void:
	for wid in _default_unlocked_weapons():
		if not unlocked_weapons.has(wid):
			unlocked_weapons.append(wid)


func _default_unlocked_weapons() -> Array[String]:
	var ids: Array[String] = []
	for w in GameData.WEAPONS:
		var wid: String = String(w.get("id", ""))
		if wid != "" and not DEFAULT_LOCKED_WEAPONS.has(wid):
			ids.append(wid)
	return ids


# 沒有存檔時的預設值：網頁／手機自動開啟觸控介面，桌機預設關閉。
func _default_touch_controls() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("web"):
		return true
	return DisplayServer.is_touchscreen_available()
