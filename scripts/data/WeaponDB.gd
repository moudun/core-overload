class_name WeaponDB
## WeaponDB —— 武器数值表（数据驱动）。
## 新增武器 = 在此加一条数据，Bullet / CorePlayer 按 kind 自动处理弹道行为。

const WEAPONS := {
	"pulse": {
		"name": "PULSE", "kind": "DIRECT",
		"dmg": 12, "cd": 0.17, "proj": 1, "speed": 620.0, "spread": 0.05, "life": 1.2,
		"color": Color(1.0, 0.95, 0.6),
	},
	"scatter": {
		"name": "SCATTER", "kind": "DIRECT",
		"dmg": 7, "cd": 0.55, "proj": 5, "speed": 520.0, "spread": 0.5, "life": 0.45,
		"color": Color(1.0, 0.72, 0.3),
	},
	"railgun": {
		"name": "RAILGUN", "kind": "BEAM",
		"dmg": 34, "cd": 0.75, "charge": 0.15, "pierce": true, "range": 900.0,
		"color": Color(0.55, 0.9, 1.0),
	},
	"homing": {
		"name": "SWARM", "kind": "HOMING",
		"dmg": 20, "cd": 0.40, "proj": 1, "speed": 380.0, "turn": 4.5, "life": 2.2,
		"color": Color(0.8, 0.6, 1.0),
	},
	"orbiter": {
		"name": "SENTRY", "kind": "ORBIT",
		"dmg": 10, "cd": 0.0, "count": 2, "radius": 55.0, "spin": 3.2, "tick": 0.4,
		"color": Color(0.6, 1.0, 0.85),
	},
}

const ALL_IDS := ["pulse", "scatter", "railgun", "homing", "orbiter"]


## 注意：方法名不能叫 get()，会与 Object.get() 冲突导致解析失败。
static func info(id: String) -> Dictionary:
	return WEAPONS.get(id, WEAPONS["pulse"])


static func display_name(id: String) -> String:
	return str(info(id).get("name", id.to_upper()))


static func random_id(exclude: Array = []) -> String:
	var pool: Array = []
	for wid in ALL_IDS:
		if wid != "pulse" and not exclude.has(wid):
			pool.append(wid)
	if pool.is_empty():
		return "scatter"
	return str(pool[randi() % pool.size()])
