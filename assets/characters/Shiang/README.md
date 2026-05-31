# Shiang 造型（本機專用）

此資料夾內的 **PNG 不會提交到 GitHub**，正式匯出時也應排除（見專案根目錄 `export_presets.cfg.example`）。

## 必要檔案（每格 64×64，橫向 4 幀，美術朝右）

| 檔名 | 尺寸 | 說明 |
|------|------|------|
| `Shiang_Idle.png` | 256×64 | 待機：單列 4 格 |
| `Shiang_Move.png` | 256×64 | 移動：單列 4 格 |

遊戲內使用朝右幀；**向左走會水平鏡像**（`flip_h`）。

顯示倍率預設 **0.88**（略小於一般角色）；腳底會套用角色表 `offset_y: -7` 與微量 `SHIANG_SPRITE_FEET_FINE`。若仍偏大／偏低，可改 `game_data.gd` 內上述常數。

無專用攻擊圖時，攻擊動畫沿用 **Move**；受傷／死亡沿用 **Idle**。

**武器特效（可選）**：在資料夾放 `<武器id>.png`（如 `sword.png`）。

## 匯出

Exclude filter 加入 `assets/characters/Shiang/*`（可與 Puersz 一併設定）。

兩張圖齊全時，村莊「角色造型」才會出現 **Shiang** 選項。
