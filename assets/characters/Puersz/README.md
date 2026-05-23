# Puersz 造型（本機專用）

此資料夾內的 **PNG 不會提交到 GitHub**，正式匯出時也應排除（見專案根目錄 `export_presets.cfg.example`）。

## 必要檔案（每格 128×128）

| 檔名 | 建議尺寸 | 說明 |
|------|----------|------|
| `Puersz_Idle.png` | 512×512 | 4 列 × 4 格（下／左／右／上） |
| `Puersz_Move.png` | 768×512 | 4 列 × 6 格 |
| `Puersz_Attack.png` | 768×512 | 4 列 × 6 格 |
| `sword.png`（選用） | 建議與預設利劍特效同尺寸 | 裝備**利劍**時的揮砍圖；檔名須為武器 id（`sword.png`） |

列序：第 0 列＝正面向下、第 1 列＝向左、第 2 列＝向右、第 3 列＝背面向上。

**武器特效（全造型通用）**：在造型資料夾放 `<武器id>.png`（如 `spear.png`），該造型下裝備對應武器即會套用；無檔則用預設 `assets/Effects/`。烈焰騎士範例：`assets/characters/chierit/fire_knight/sword.png`（可提交 Git）。

此資料夾內**所有檔案**（含 `sword.png`、`.import`）皆受 `.gitignore` 與匯出排除 `assets/characters/Puersz/*` 涵蓋，**不必另加規則**。

## 匯出

在 Godot **專案 → 匯出** → 各平台的 **資源 (Resources)** → **排除篩選 (Exclude filter)** 加入：

```text
assets/characters/Puersz/*
```

或參考根目錄的 `export_presets.cfg.example` 建立／合併你的 `export_presets.cfg`。

檔案齊全時，村莊「角色造型」才會出現 **Puersz** 選項。
