# SYSTEM OVERLOAD

终端策略 Roguelike 原型（Godot 4.4.1 / GDScript）。
你扮演系统调度员，在 CRT 终端里打出脚本指令，抵御不断升级的系统入侵。

## 运行方式

- 引擎：`H:\Godot\Godot_v4.4.1-stable_win64.exe`（已下载，官方 4.4.1 stable）
- 打开：引擎 → Import → 选择 `H:\SystemOverload\project.godot` → 运行（F5 / ▶）

## 操作

| 按键 | 功能 |
| --- | --- |
| 1-5 | 执行手牌中对应编号的脚本 |
| E | 结束回合（威胁行动 / 散热 / 手牌弃置） |
| R | 系统崩溃后重新开始 |
| H | 显示帮助手册 |

## 游戏循环

1. 每回合刷新 CPU（算力）/ RAM（内存），抽取 5 张手牌。
2. 打出脚本：攻击（消减威胁 HP）、防御（叠加 BLOCK）、抽牌、超频、修复、启动守护进程。
3. 回合结束：威胁倒计时归零即攻击核心；过热(HEAT>=100)会持续损伤核心；散热随后结算。
4. 清空全部威胁 = 波次胜利 → 三选一升级脚本 → 进入下一波。
5. 核心 CORE 归零 → 任务失败 → R 重开。

## 资源与规则

- CORE：核心稳定性，100 上限，归零失败。
- CPU / RAM：每回合开始回满。
- BLOCK：护盾，先于核心吸收伤害；DAEMON 可提供回合开始自动护盾。
- HEAT：执行脚本产生热量；每回合自然散热 8（可被 DAEMON 增强）。
- 威胁拥有 HP / 倒计时 / 攻击力，部分威胁造成额外发热。

## 项目结构

```
H:\SystemOverload\
├── project.godot          # 项目配置（Autoload 挂载）
├── scenes\Main.tscn       # 主场景
├── scripts\
│   ├── Main.gd            # UI 组装 / 信号连接 / 音效
│   ├── autoload\
│   │   ├── EventBus.gd        # 全局信号总线
│   │   ├── GameState.gd       # 核心状态（CORE/CPU/RAM/HEAT/DAEMON）
│   │   ├── DeckManager.gd     # 抽牌/手牌/弃牌管理
│   │   └── IncidentManager.gd # 威胁队列与回合结算
│   ├── core\
│   │   ├── FSM.gd             # 状态机基类
│   │   ├── ResourceController.gd # 散热/资源条工具
│   │   └── TurnManager.gd     # 主回合状态机
│   ├── cards\
│   │   ├── CardData.gd        # 卡牌数据类
│   │   ├── CardLibrary.gd     # 卡牌数据工厂（起始卡组/奖励池）
│   │   └── CardEffect.gd      # 效果结算分派
│   ├── incidents\
│   │   ├── IncidentData.gd    # 威胁数据类
│   │   └── IncidentLibrary.gd # 威胁模板与波次生成
│   └── ui\
│       ├── TerminalDisplay.gd # 打字机终端输出
│       ├── CommandInputHandler.gd # 键盘指令
│       └── CRTShaderController.gd # CRT 滤镜
├── assets\
│   ├── fonts\VT323-Regular.ttf
│   └── shaders\crt_filter.gdshader
└── README.md
```

## 扩展指南

- 加卡牌：`scripts/cards/CardLibrary.gd` 的 `starting_deck()` / `reward_pool()` 数组追加一项即可，效果类型需在 `CardEffect.gd` 有分支。
- 加威胁：`scripts/incidents/IncidentLibrary.gd` 的 `_build_cfg()` 追加 `match` 分支并在 `spawn_wave_pack` 放入解锁条件。
- 新效果：在 `CardEffect.gd` 增加分支与对应 `effect_type`。
