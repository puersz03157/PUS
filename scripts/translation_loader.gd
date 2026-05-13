extends Node
## 啟動時從 res://translations/strings.csv 建立 Translation 並註冊到 TranslationServer。
## 優先讀 raw CSV；匯出版若拿不到 CSV，會退回 Godot 匯出的 .translation 檔。
## 空白的 zh_CN / en 欄位會以 zh_TW 內容補齊，避免系統語系落在 en 時整片顯示 KEY。

const CSV_PATH := "res://translations/strings.csv"
const FALLBACK_TRANSLATION_PATHS := [
	"res://translations/strings.zh_TW.translation",
]


func _ready() -> void:
	if not _load_translations_from_csv(CSV_PATH):
		_load_fallback_translation_resources()
	_apply_startup_locale()


func _apply_startup_locale() -> void:
	var loc: String = ""
	if is_instance_valid(GameState):
		loc = String(GameState.language).strip_edges()
	if loc == "":
		loc = "zh_TW"
	TranslationServer.set_locale(loc)


func _load_translations_from_csv(path: String) -> bool:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("TranslationLoader: 無法開啟 %s" % path)
		return false
	var header: PackedStringArray = f.get_csv_line()
	if header.size() < 2:
		push_warning("TranslationLoader: CSV 標題列無效")
		return false
	if String(header[0]).strip_edges().to_lower() != "keys":
		push_warning("TranslationLoader: 第一欄必須為 keys")
	var locales: PackedStringArray = PackedStringArray()
	for i in range(1, header.size()):
		var h: String = String(header[i]).strip_edges()
		if h != "":
			locales.append(h)
	if locales.is_empty():
		return false
	var by_locale: Dictionary = {}
	for li in range(locales.size()):
		by_locale[locales[li]] = {}
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.is_empty():
			continue
		if row.size() == 1 and String(row[0]).strip_edges() == "":
			continue
		var msg_key: String = String(row[0]).strip_edges()
		if msg_key.is_empty() or msg_key.begins_with("#"):
			continue
		for li in range(locales.size()):
			var col: int = li + 1
			var cell: String = ""
			if col < row.size():
				cell = String(row[col]).replace("\\n", "\n")
			by_locale[locales[li]][msg_key] = cell
	# 非 zh_TW：空白欄位沿用 zh_TW（避免 en/zh_CN 未填時顯示 KEY）
	if by_locale.has("zh_TW"):
		var tw: Dictionary = by_locale["zh_TW"]
		for li in range(locales.size()):
			var loc: String = locales[li]
			if loc == "zh_TW":
				continue
			var tgt: Dictionary = by_locale[loc]
			for k in tw.keys():
				var cur: String = String(tgt.get(k, "")).strip_edges()
				if cur == "":
					tgt[k] = String(tw[k])
	for li in range(locales.size()):
		var loc2: String = locales[li]
		var tr_res := Translation.new()
		tr_res.locale = loc2
		var msgs: Dictionary = by_locale[loc2]
		for k in msgs.keys():
			var val: String = String(msgs[k])
			if val.strip_edges() == "":
				continue
			tr_res.add_message(String(k), val)
		TranslationServer.add_translation(tr_res)
	return true


func _load_fallback_translation_resources() -> void:
	for path in FALLBACK_TRANSLATION_PATHS:
		if not ResourceLoader.exists(path):
			continue
		var tr_res: Translation = load(path) as Translation
		if tr_res != null:
			TranslationServer.add_translation(tr_res)
