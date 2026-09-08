extends Node
## EventBus.gd (Autoload) —— V1.1 全局事件总线。
## 所有跨模块通信经由此处，UI 与逻辑完全解耦。

signal core_hp_changed
signal player_stats_changed
signal wave_changed(wave: int)
signal wave_cleared(wave: int)
signal kills_changed(kills: int)
signal card_picked(card_id: String)
signal game_over
signal hit_core(damage: int)
signal hit_enemy(pos: Vector2, color: Color)
signal enemy_killed(pos: Vector2)
signal fx_shoot(pos: Vector2, dir: Vector2)
