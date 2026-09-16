extends Node
## EventBus.gd (Autoload) —— V1.2 全局事件总线。
## 所有跨模块通信经由此处，UI 与逻辑完全解耦。

signal core_hp_changed
signal stats_changed
signal gold_changed(gold: int)
signal cells_changed(cells: int)
signal weapon_changed(slot: int, weapon_id: String)
signal protocol_changed(protocols: Array)

signal room_entered(biome: int, room_index: int, room_type: String)
signal room_locked
signal room_cleared
signal door_opened

signal scroll_choice_opened(options: Array)
signal scroll_chosen(kind: String)
signal toast(text: String)

signal boss_spawned(name: String, hp: int)
signal boss_hp_changed(cur: int, max_hp: int)
signal boss_died

signal roll_started
signal flask_used(charges: int)
signal hit_enemy(pos: Vector2, color: Color, amount: int, crit: bool)
signal enemy_killed(pos: Vector2)
signal fx_shoot(pos: Vector2, dir: Vector2)
signal beam_fired(from: Vector2, to: Vector2, color: Color)
signal enemy_shot(pos: Vector2, dir: Vector2)
signal game_over
signal run_victory
