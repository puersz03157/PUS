# 命運的彈珠倖存者 (Fate's Pinball Survivors)

一款用 **Godot 4** 製作的倖存者類遊戲，最大特色：
**升級時不挑卡 — 改成玩一場彈珠台！** 球落入哪一格，就拿那格的武器/能力。

支援單機 / 雙人本機。

---

## 開啟方式

1. 安裝 [Godot Engine 4.x](https://godotengine.org/download)（建議 4.3 或更新）。
2. 開啟 Godot → 「匯入」→ 選擇本資料夾的 `project.godot`。
3. 點 ▶ 執行（F5）。

> 第一次匯入時 Godot 會建立 `.godot/` 快取資料夾，這正常。

---

## 操作

|              | 玩家 1 (P1)      | 玩家 2 (P2)              |
| ------------ | --------------- | ----------------------- |
| 移動         | `W` `A` `S` `D` | `↑` `↓` `←` `→`         |
| 確認/發球    | `Space`         | `Enter`                 |
| 取消         | `Q`             | `右 Shift`              |
| 暫停/繼續    | `Esc`           | `Esc`                   |

- 也支援 PS5 / Xbox 手把：第一支手把＝P1（裝置 0），第二支＝P2（裝置 1）。左搖桿／十字鍵＝移動，A／× ＝確認、發球，B／○ ＝取消、暫停（ESC）。
- 武器是**自動攻擊**，近戰武器會自動朝最近敵人揮砍；遠程武器只在鎖敵範圍內有目標才開火。
- 升級時自動進入**彈珠台**：頂部會有一個左右來回移動的發射口，按發球鍵就把球往下射，撞到底部哪一格就拿那格的獎勵。發球瞬間會繼承發射口當下的橫向速度，所以把握時機可以左右調整入射角。
- 在遊戲中按 **Esc** 開啟**暫停選單**：顯示遊戲時間、雙方等級/HP/擊殺/武器/強化堆疊，可選擇繼續或回主選單。

---

## 設計資料

所有數值都集中在 `scripts/game_data.gd`，直接對應你 Excel 設計表中的：

- 12 種武器（利劍 / 長槍 / 魔彈 / 弓箭 / 飛鏢 / 爪擊 / 碎刃 / 火焰 / 閃電 / 寒冰 / 毒素 / 聖光）
- 9 個角色（劍士、遊俠、騎士、戰士、巫師、武士、狼人、吸血鬼領主、烈焰靈女巫；稀有度由 `game_data.gd` 的 `rarity` 欄位決定）
- 武器升級（傷害、範圍、攻速、投射物）
- 通用能力升級（強健體魄、疾風步、急速冷卻、吸取範圍、智慧之心、鋼鐵肌膚、回復術、力量強化）

要調平衡時直接改這個檔案即可。

---

## 程式架構

```
project.godot         ─ Godot 4 專案檔
icon.svg              ─ 圖示
scenes/               ─ 各個 .tscn 場景
  Main.tscn           ─ 主選單
  CharacterSelect.tscn─ 選角色畫面
  Game.tscn           ─ 主遊戲場景
  Player.tscn         ─ 玩家
  Enemy.tscn          ─ 敵人
  Projectile.tscn     ─ 投射物
  XpOrb.tscn          ─ 經驗珠
  Pinball.tscn        ─ 升級小遊戲
scripts/              ─ 程式
  game_data.gd        ─ ★ 全域資料表（武器/角色/升級數值）
  game_state.gd       ─ 跨場景狀態
  main.gd
  character_select.gd
  game.gd             ─ 主場景控制（生敵、HUD、觸發彈珠台）
  player.gd
  enemy.gd
  projectile.gd
  xp_orb.gd
  pinball.gd          ─ ★ 彈珠台核心邏輯
  drawer_node.gd      ─ 共用繪製節點
  weapons/
    weapon_base.gd
    weapon_melee_fan.gd ─ 利劍 / 長槍 / 爪擊
    weapon_projectile.gd─ 魔彈 / 弓箭 / 飛鏢 / 閃電 / 寒冰
    weapon_orbit.gd     ─ 碎刃
    weapon_aura.gd      ─ 火焰 / 毒素 / 聖光
```

每個武器的視覺/行為都對應 `kind` 欄位：
- `melee_fan` 近戰扇形
- `projectile` 投射物
- `orbit`     環繞玩家
- `aura`      周圍光環

---

## 本機專用素材（Puersz / Shiang 造型）

`assets/characters/Puersz/`、`assets/characters/Shiang/` 內的 PNG **不會進 Git**（見 `.gitignore`），clone 後請自行放入圖檔；說明見各資料夾的 `README.md`。

正式 **匯出** 時請在匯出預設的 **Exclude filter** 加入 `assets/characters/Puersz/*` 與 `assets/characters/Shiang/*`，或參考根目錄 `export_presets.cfg.example` 合併到你的 `export_presets.cfg`（此檔本來就不提交）。

## 房屋造型 × 武器特效

選用房屋造型且該造型資料夾內有 `<武器id>.png` 時，戰鬥中裝備該武器會覆寫 `attack_effect` 的 spritesheet（其餘揮砍參數沿用 `game_data.gd` 武器表）。

| 造型 id | 資料夾（例） | 利劍特效檔 |
|---------|--------------|------------|
| `puersz` | `assets/characters/Puersz/` | `sword.png`（本機專用，不進 Git） |
| `shiang` | `assets/characters/Shiang/` | `sword.png` 等（本機專用，不進 Git） |
| `fire_knight` | `assets/characters/chierit/fire_knight/` | `sword.png` |
| `leaf_ranger` | `assets/characters/chierit/Leaf_Ranger/` | `bow.png` 等 |

新增造型：在 `game_data.gd` 的 `HOUSE_SKIN_ASSET_ROOTS` 登記根目錄，並在該目錄放對應 png 即可。

---

## 待擴充（Roadmap）

這是一個可運行的 MVP 雛形，建議下一步補：

- [ ] 雙人分割畫面 (`SubViewport` + 兩個 `Camera2D`)
- [ ] 滿級特效實裝（流血 / 燃燒 / 易傷 / 中毒 / 緩速 DOT 系統）
- [ ] 投射物的貫穿、反彈、波浪細節
- [ ] 更多敵人類型（菁英 / Boss / 遠程）
- [ ] 音效與背景音樂
- [ ] 彈珠台的額外技能 / 變化（保險球、加速、二段反彈…）
- [ ] 存檔系統 / 角色解鎖
- [ ] 美術資源（目前都是 Polygon2D 程序化幾何）

---

## 比例尺

遊戲座標 1 米 ≈ 25 px。例如「3.5 米的扇形」就是半徑約 90 px。
這個轉換寫在 `game_data.gd` 的武器 `range` 欄位，有需要可整體調整。
