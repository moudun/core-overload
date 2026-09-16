class_name EnemyDB
## EnemyDB —— 敌人数值表与区块缩放。
## kind: 0 drone / 1 brute / 2 runner / 3 spitter

const BASE := {
	0: {"hp": 2, "speed": 72.0, "dmg": 12, "radius": 10.0, "ranged": false},
	1: {"hp": 6, "speed": 46.0, "dmg": 24, "radius": 12.0, "ranged": false},
	2: {"hp": 1, "speed": 122.0, "dmg": 8, "radius": 8.0, "ranged": false},
	3: {"hp": 3, "speed": 12.0, "dmg": 10, "radius": 11.0, "ranged": true,
		"fire_cd": 2.2, "bullet_speed": 240.0, "keep_min": 260.0, "keep_max": 420.0},
}

const BIOME_MULT := [1.0, 1.35, 1.80]
const ELITE_HP := 2.5
const ELITE_SPEED := 0.9
const ELITE_DMG := 1.5

const BOSSES := [
	{"id": "titan", "name": "COOLANT TITAN", "hp": 260, "cells": 15, "gold": 60},
	{"id": "gravekeeper", "name": "GRAVEKEEPER", "hp": 420, "cells": 15, "gold": 60},
	{"id": "coremind", "name": "THE CORE MIND", "hp": 600, "cells": 15, "gold": 60},
]


static func stats(kind: int, biome: int, elite: bool = false) -> Dictionary:
	var base: Dictionary = BASE.get(kind, BASE[0])
	var m: float = BIOME_MULT[clampi(biome, 0, 2)]
	var hp := maxi(1, int(round(float(base["hp"]) * m)))
	var spd := float(base["speed"]) * (1.0 + float(biome) * 0.06)
	var dmg := int(round(float(base["dmg"]) * (1.0 + float(biome) * 0.25)))
	if elite:
		hp = maxi(1, int(round(float(hp) * ELITE_HP)))
		spd *= ELITE_SPEED
		dmg = int(round(float(dmg) * ELITE_DMG))
	return {
		"hp": hp, "speed": spd, "dmg": dmg, "radius": float(base["radius"]),
		"ranged": bool(base.get("ranged", false)),
		"fire_cd": float(base.get("fire_cd", 0.0)),
		"bullet_speed": float(base.get("bullet_speed", 0.0)),
		"keep_min": float(base.get("keep_min", 0.0)),
		"keep_max": float(base.get("keep_max", 0.0)),
	}


static func roll_kind(biome: int, room_index: int) -> int:
	var r := randf()
	if biome >= 1 or room_index >= 2:
		if r < 0.18:
			return 3
		if r < 0.40:
			return 1
		if r < 0.58:
			return 2
		return 0
	return 0 if r < 0.75 else 2
