extends Node
## GameState.gd (Autoload) —— V1.1 单局状态：核心血量、护盾、击杀、波次、得分。

const CORE_MAX := 100
const SHIELD_MAX := 60

var core_hp := CORE_MAX
var shield := 0
var kills := 0
var wave := 0
var score := 0
var active := true


func reset_run() -> void:
	core_hp = CORE_MAX
	shield = 0
	kills = 0
	wave = 0
	score = 0
	active = true
	EventBus.core_hp_changed.emit()
	EventBus.kills_changed.emit(kills)


func damage_core(v: int) -> void:
	if not active:
		return
	var amount := v
	if shield > 0:
		var absorbed := mini(shield, amount)
		shield -= absorbed
		amount -= absorbed
		EventBus.hit_core.emit(absorbed)
	if amount > 0:
		core_hp = maxi(0, core_hp - amount)
		EventBus.hit_core.emit(amount)
		if core_hp <= 0:
			core_hp = 0
			active = false
			EventBus.game_over.emit()
	EventBus.core_hp_changed.emit()


func add_shield(v: int) -> void:
	shield = mini(SHIELD_MAX, shield + v)
	EventBus.core_hp_changed.emit()


func add_kill() -> void:
	kills += 1
	score += 10 + wave * 5
	EventBus.kills_changed.emit(kills)


func add_wave_clear_bonus() -> void:
	score += 50 + wave * 20
	EventBus.kills_changed.emit(kills)


func next_wave() -> void:
	wave += 1
	EventBus.wave_changed.emit(wave)
