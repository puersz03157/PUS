extends "res://scripts/weapons/weapon_base.gd"
## 鞭子：不直接攻擊；強化並擴充御五家召喚部署（數量／能力見 GameData.build_whip_summon_deploy_list）。


func _process(_delta: float) -> void:
	# 不觸發 fire；召喚邏輯由 BattleSummonFollower + 部署列表處理
	pass


func fire() -> bool:
	return false


func get_summon_count_bonus() -> int:
	return int(entry.get("upgrades", {}).get("w_count", 0))
