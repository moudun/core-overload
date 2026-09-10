# Core Overload

像素风 2D 动作射击 + 波次防守 Roguelike，Godot 4.4.1 / GDScript。

你是一颗会走位的核心。外部入侵者一波波涌来，撞上你就掉血——用鼠标把它们点碎，
捡起掉落的程序卡即时强化自己，看你能撑到第几波。

**全部美术与音效均由代码程序化生成**（`scripts/util/PixelArt.gd` 逐像素绘制贴图，
`AudioStreamGenerator` 合成音效），仓库零外部素材依赖，克隆下来就能跑。

> 前作 V0.1 是「CRT 终端文字策略」版本，形态完全不同，已归档到独立仓库：
> [system-overload-v0.1](https://github.com/moudun/system-overload-v0.1)

---

## 运行方式

- 引擎：Godot **4.4.1 stable**（官方 Windows 版）
- 打开：Godot → Import → 选择 `project.godot` → 运行（F5 / ▶）

## 操作

| 按键 | 功能 |
| --- | --- |
| `W A S D` / 方向键 | 移动核心 |
| 鼠标移动 | 瞄准 |
| 鼠标左键（按住） | 自动射击 |
| `L` | 中 / 英 实时切换 |
| `R` | 结算后重新开始 |
| `ESC` | 暂停 / 返回主菜单 |

## 玩法循环

1. 入侵者按波次从场外生成，持续追踪你的核心，撞击造成伤害后自毁。
2. 击杀会掉落**程序卡**，走过去拾取立即生效，本局内可无限叠加。
3. 一波清空后短暂间歇（约 3 秒），进入下一波——数量、血量、速度、装甲逐波增强。
4. 核心 HP 归零 → 结算面板（波次 / 击杀 / 得分），`R` 重开。

## 卡牌（掉落强化）

| 卡 | 中文 | English | 效果 |
| --- | --- | --- | --- |
| `rapid` | 快速充能 | Overcharge Coil | 射速提升（冷却 -18%） |
| `damage` | 过载弹头 | Overload Bolt | 弹头伤害 +8 |
| `split` | 分裂核心 | Split Core | 弹道 +1 |
| `shield` | 临时护盾 | Temp Shield | 核心护盾 +20 |
| `speed` | 磁悬浮轴承 | Maglev Bearing | 移动速度 +35 |

第一个击杀**保底掉卡**，之后掉卡概率随波次提升。

## 敌人

| 类型 | HP | 速度 | 撞击伤害 |
| --- | --- | --- | --- |
| 普通 | 2 | 72 | 12 |
| 重甲（第 2 波起） | 6 | 46 | 24 |
| 快速（第 3 波起） | 1 | 122 | 8 |

所有数值随波次线性缩放（每波 +8%）。

## 项目结构

```
project.godot              # 项目配置（4 个 Autoload）
scenes/
├── MainMenu.tscn          # 主菜单
└── main_game.tscn         # 主游戏场景
scripts/
├── autoload/
│   ├── EventBus.gd        # 全局信号总线
│   ├── GameState.gd       # 核心状态（HP / 护盾 / 波次 / 击杀 / 得分）
│   ├── Lang.gd            # 中英双语词条表
│   └── Settings.gd        # 设置持久化
├── world/MainGame.gd      # 主控：地图 / 波次 / 生成 / 掉落 / 特效 / 音效
├── entities/
│   ├── CorePlayer.gd      # 玩家核心：移动 + 射击 + Build 数值
│   ├── Enemy.gd           # 入侵者：追踪 AI 与三型数值
│   ├── Bullet.gd          # 子弹
│   └── LootCard.gd        # 掉落卡实体
├── cards/CardPool.gd      # 卡牌词条库（id / 颜色 / 效果）
├── ui/HUD.gd              # 顶栏状态 / Banner / 教程 / 结算层
├── menu/                  # 主菜单与语言设置面板
└── util/PixelArt.gd       # 程序化像素贴图生成
```

## 版本记录

`V0.1` → `V1.1` 的形态演进与各版改动明细见 [VERSION.txt](VERSION.txt)。
