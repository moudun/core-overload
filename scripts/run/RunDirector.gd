extends Node
## RunDirector (Autoload) —— V1.2 Run 总控。
## 管理区块 / 房间序列与推进判定；实际建房由 MainGame 监听 room_requested 完成。

signal room_requested(biome: int, room_index: int, room_type: String)
signal run_started
signal run_finished(victory: bool)

## 每区块固定 6 间：战斗 → 战斗 → 宝藏 → 战斗 → 商店 → Boss
const SEQUENCE := ["combat", "combat", "treasure", "combat", "shop", "boss"]
const BIOMES := 3


func start_run() -> void:
	GameState.reset_run()
	GameState.biome_index = 0
	GameState.room_index = 0
	run_started.emit()
	room_requested.emit(0, 0, SEQUENCE[0])


func advance() -> void:
	var next_room := GameState.room_index + 1
	var next_biome := GameState.biome_index
	if next_room >= SEQUENCE.size():
		next_room = 0
		next_biome += 1
	if next_biome >= BIOMES:
		GameState.active = false
		run_finished.emit(true)
		EventBus.run_victory.emit()
		return
	GameState.biome_index = next_biome
	GameState.room_index = next_room
	room_requested.emit(next_biome, next_room, SEQUENCE[next_room])


func current_type() -> String:
	return SEQUENCE[clampi(GameState.room_index, 0, SEQUENCE.size() - 1)]
