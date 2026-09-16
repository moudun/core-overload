class_name EnemyDB
## EnemyDB.gd —— V1.3 敌人数值表与区块缩放。
## kind: 0 drone(追踪自爆) / 1 brute(慢速高伤) / 2 runner(高速) / 3 spitter(远程)
##       4 glitch(过载崩溃时刷出的故障体：随机抖动 + 自带护盾)
## V1.3 新增：shield（护盾值，需先破盾）、status_res（状态抗性）。

const BASE := {
	0: {"hp": 2, "speed": 72.0, "dmg": 12, "radius": 10.0, "ranged": false, "shield": 0},
	1: {"hp": 6, "speed": 46.0, "dmg": 24, "radius": 12.0, "ranged": false, "shield": 0},
	2: {"hp": 1, "speed": 122.0, "dmg": 8, "radius": 8.0, "ranged": false, "shield": 0},
	3: {"hp": 3, "speed": 12.0, "dmg": 10, "radius": 11.0, "ranged": true, "shield": 0,
		"fire_cd": 2.2, "bullet_speed": 240.0, "keep_min": 260.0, "keep_max": 420.0},
	4: {"hp": 4, "speed": 96.0, "dmg": 16, "radius": 11.0, "ranged": false, "shield": 6,
		"jitter": true},
}

const BIOME_MULT := [1.0, 1.35, 1.80]
const ELITE_HP := 2.5
const ELITE_SPEED := 0.9
const ELITE_DMG := 1.5
const ELITE_SHIELD := 8

const BOSSES := [
	{"id": "titan", "name": "COOLANT TITAN", "hp": 260, "cells": 15, "gold": 60},
	{"id": "gravekeeper", "name": "GRAVEKEEPER", "hp": 420, "cells": 15, "gold": 60},
	{"id": "coremind", "name": "THE CORE MIND", "hp": 600, "cells": 15, "gold": 60},
]

## 挑战词缀对敌人的修正入口（由 GameState.challenge_agg() 提供）
static func stats(kind: int, biome: int, elite: bool = false, shield_bonus: int = 0,
		hp_mult: float = 1.0, count_mult: float = 1.0, dmg_mult: float = 1.0,
		speed_mult: float = 1.0) -> Dictionary:
	var base: Dictionary = BASE.get(kind, BASE[0])
	var m: float = BIOME_MULT[clampi(biome, 0, 2)]
	var hp := maxi(1, int(round(float(base["hp"]) * m * (1.0 + count_mult * -0.5))))
	hp = maxi(1, int(round(float(hp) * (1.0 + hp_mult))))
	var spd := float(base["speed"]) * (1.0 + float(biome) * 0.06) * speed_mult
	var dmg := int(round(float(base["dmg"]) * (1.0 + float(biome) * 0.25) * dmg_mult))
	var shield := int(base.get("shield", 0)) + shield_bonus
	if elite:
		hp = maxi(1, int(round(float(hp) * ELITE_HP)))
		spd *= ELITE_SPEED
		dmg = int(round(float(dmg) * ELITE_DMG))
		shield += ELITE_SHIELD
	return {
		"hp": hp, "speed": spd, "dmg": dmg, "radius": float(base["radius"]),
		"ranged": bool(base.get("ranged", false)),
		"shield": shield,
		"jitter": bool(base.get("jitter", false)),
		"fire_cd": float(base.get("fire_cd", 0.0)),
		"bullet_speed": float(base.get("bullet_speed", 0.0)),
		"keep_min": float(base.get("keep_min", 0.0)),
		"keep_max": float(base.get("keep_max", 0.0)),
	}


static func roll_kind(biome: int, depth: int) -> int:
	var r := randf()
	if biome >= 1 or depth >= 3:
		if r < 0.16:
			return 3
		if r < 0.38:
			return 1
		if r < 0.58:
			return 2
		if r < 0.68:
			return 4
		return 0
	return 0 if r < 0.75 else 2


## 故障体专用（过载崩溃刷怪）
static func glitch_kind() -> int:
	return 4
