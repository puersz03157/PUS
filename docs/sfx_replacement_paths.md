# 音效替換路徑

這些是目前遊戲會載入的基本音效。要替換音效時，直接用同名 `.wav` 檔覆蓋下列路徑即可；也可以改 `res://scripts/audio_manager.gd` 內的 `SFX_PATHS` 指到其他檔案。

| 音效 ID | 觸發時機 | 替換路徑 |
| --- | --- | --- |
| `ui_select` | 選單切換、開啟子選單、暫停選單開啟 | `res://assets/audio/sfx/ui_select.wav` |
| `ui_confirm` | 選單確認、角色 Ready、出發、繼續遊戲 | `res://assets/audio/sfx/ui_confirm.wav` |
| `ui_back` | 返回、取消 Ready、關閉子選單、回主選單 | `res://assets/audio/sfx/ui_back.wav` |
| `player_attack` | 武器攻擊或技能播放攻擊動畫 | `res://assets/audio/sfx/player_attack.wav` |
| `enemy_hit` | 敵人受到非 DOT 傷害 | `res://assets/audio/sfx/enemy_hit.wav` |
| `player_hurt` | 玩家受傷但未死亡 | `res://assets/audio/sfx/player_hurt.wav` |
| `player_death` | 玩家死亡 | `res://assets/audio/sfx/player_death.wav` |
| `skill_cast` | 戰鬥或彈珠台成功施放技能 | `res://assets/audio/sfx/skill_cast.wav` |
| `level_up` | 玩家 / 隊伍升級 | `res://assets/audio/sfx/level_up.wav` |
| `pickup_xp` | 拾取經驗珠 | `res://assets/audio/sfx/pickup_xp.wav` |
| `pickup_gold` | 拾取金幣珠 | `res://assets/audio/sfx/pickup_gold.wav` |
| `pinball_launch` | 彈珠台發球 | `res://assets/audio/sfx/pinball_launch.wav` |
| `pinball_bounce` | 彈珠撞牆或撞針 | `res://assets/audio/sfx/pinball_bounce.wav` |
| `reward` | 彈珠台取得獎勵、戰鬥勝利獎勵 | `res://assets/audio/sfx/reward.wav` |

建議格式：WAV / OGG 皆可；如果改成 OGG，請同步修改 `SFX_PATHS` 的副檔名。
