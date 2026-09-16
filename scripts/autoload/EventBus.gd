extends Node
## EventBus.gd (Autoload) —— V1.3 全局事件总线。
## 所有跨模块通信经由此处，UI 与逻辑完全解耦。
## V1.3 新增：过载、路线图、构建、挑战、骇入小游戏、存档相关信号。

# ---------------- 核心状态 ----------------
signal core_hp_changed
signal stats_changed
signal gold_changed(gold: int)
signal cells_changed(cells: int)
signal energy_changed(energy: int)
signal weapon_changed(slot: int, weapon_id: String)
signal protocol_changed(protocols: Array)
signal card_changed(cards: Array)
signal build_changed

# ---------------- 房间 / 路线 ----------------
signal room_entered(biome: int, room_index: int, room_type: String, depth: int)
signal room_locked
signal room_cleared
signal door_opened
signal route_ready(choices: Array)
signal route_node_chosen(node_id: int)

# ---------------- 过载 ----------------
signal overload_changed(value: float, tier: int)
signal overload_meltdown(effect: String)
signal overload_vented

# ---------------- 奖励 ----------------
signal scroll_choice_opened(options: Array)
signal scroll_chosen(kind: String)
signal reward_choice_opened(options: Array)
signal toast(text: String)

# ---------------- Boss ----------------
signal boss_spawned(boss_name: String, hp: int)
signal boss_hp_changed(cur: int, max_hp: int)
signal boss_died

# ---------------- 战斗 ----------------
signal roll_started
signal flask_used(charges: int)
signal hit_enemy(pos: Vector2, color: Color, amount: int, crit: bool)
signal enemy_killed(pos: Vector2)
signal fx_shoot(pos: Vector2, dir: Vector2)
signal beam_fired(from: Vector2, to: Vector2, color: Color)
signal enemy_shot(pos: Vector2, dir: Vector2)
signal skill_used(skill_id: String)
signal skill_cd_changed(ratio: float)
signal chain_changed(chain: int)

# ---------------- 骇入小游戏 ----------------
signal hack_requested
signal hack_started
signal hack_finished(success: bool, score: int, reward_source: int)

# ---------------- 新手教学 ----------------
## 教学房推进到某一步：step_id 为 move / shoot / roll / swap / vent / skill
signal tutorial_step(index: int, total: int, step_id: String)
signal tutorial_finished

# ---------------- 流程 ----------------
signal run_started
signal game_over
signal run_victory
signal run_saved
