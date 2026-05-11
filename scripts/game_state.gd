extends Node
## 跨場景共享的狀態：哪幾位玩家、選的角色／被動／技能、結果。
## 也保存「局外」進度（金幣、目前關卡），會寫入 user://save.cfg。

const SAVE_PATH := "user://save.cfg"

var two_players: bool = true
var p1_character: String = "swordsman"
var p2_character: String = "knight"

# 角色選擇完成後要去哪：
#   "battle"  → res://scenes/Game.tscn
#   "village" → res://scenes/Village.tscn
var next_scene: String = "battle"

# 被動／技能（角色選擇畫面決定，遊戲開始時帶入 Player）
var p1_passive: String = "none"
var p1_skill: String = "none"
var p2_passive: String = "none"
var p2_skill: String = "none"

# 局外進度
var gold: int = 0
var current_stage_id: String = "slime_forest"

# 顯示語系：留空則沿用 project.godot 的 locale。
# 受支援：zh_TW（預設）／zh_CN／en；新語系加在 strings.csv 後可動態切換。
var language: String = ""

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
	last_result["gold_reward"] = amount
	save_to_disk()


func save_to_disk() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "gold", gold)
	cfg.set_value("meta", "current_stage_id", current_stage_id)
	cfg.set_value("meta", "language", language)
	cfg.save(SAVE_PATH)


func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	gold = int(cfg.get_value("meta", "gold", 0))
	current_stage_id = String(cfg.get_value("meta", "current_stage_id", "slime_forest"))
	language = String(cfg.get_value("meta", "language", ""))
