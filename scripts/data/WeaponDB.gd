class_name WeaponDB
## WeaponDB.gd —— V1.3 武器数值表（12 把，数据驱动）。
## 新增武器 = 在此加一条数据；CorePlayer / Bullet 按 kind 自动处理弹道行为。
##
## kind 取值：
##   DIRECT    直线弹丸            HOMING  追踪弹
##   BEAM      即时贯穿光束        ORBIT   环绕无人机
##   CHAIN     电弧（命中后连锁）  CONE    扇形短距喷射
##   NOVA      以自身为中心放射    LOB     抛物线落点爆炸
##   BOUNCE    墙面反弹弹丸        LIFESTEAL 吸血直弹
## 注意：方法名不能叫 get()，会与 Object.get() 冲突导致解析失败。

const WEAPONS := {
	"pulse": {
		"name": "PULSE", "kind": "DIRECT",
		"dmg": 12, "cd": 0.17, "proj": 1, "speed": 620.0, "spread": 0.05, "life": 1.2,
		"color": Color(1.0, 0.95, 0.6), "tags": [], "heat": 1.6,
	},
	"scatter": {
		"name": "SCATTER", "kind": "DIRECT",
		"dmg": 7, "cd": 0.55, "proj": 5, "speed": 520.0, "spread": 0.5, "life": 0.45,
		"color": Color(1.0, 0.72, 0.3), "tags": [Tags.SALVAGE], "heat": 10.0,
	},
	"railgun": {
		"name": "RAILGUN", "kind": "BEAM",
		"dmg": 34, "cd": 0.75, "pierce": true, "range": 900.0,
		"color": Color(0.55, 0.9, 1.0), "tags": [Tags.PRECISION, Tags.OVERCLOCK], "heat": 13.0,
	},
	"homing": {
		"name": "SWARM", "kind": "HOMING",
		"dmg": 20, "cd": 0.40, "proj": 1, "speed": 380.0, "turn": 4.5, "life": 2.2,
		"color": Color(0.8, 0.6, 1.0), "tags": [], "heat": 8.0,
	},
	"orbiter": {
		"name": "SENTRY", "kind": "ORBIT",
		"dmg": 10, "cd": 0.0, "count": 2, "radius": 58.0, "spin": 3.2, "tick": 0.4,
		"color": Color(0.6, 1.0, 0.85), "tags": [Tags.FORTIFY], "heat": 0.0,
	},
	"arc": {
		"name": "ARC CUTTER", "kind": "CHAIN",
		"dmg": 18, "cd": 0.48, "proj": 1, "speed": 760.0, "life": 0.5, "spread": 0.02,
		"chain": 4, "chain_range": 190.0, "chain_falloff": 0.75,
		"color": Color(0.72, 0.62, 1.0), "tags": [Tags.ARC], "heat": 9.0,
	},
	"cryo": {
		"name": "CRYO NOZZLE", "kind": "CONE",
		"dmg": 8, "cd": 0.34, "proj": 6, "speed": 400.0, "spread": 0.42, "life": 0.30,
		"range": 200.0, "freeze": 2.2,
		"color": Color(0.45, 0.88, 1.0), "tags": [Tags.CRYO], "heat": 6.5,
	},
	"nova": {
		"name": "NOVA CORE", "kind": "NOVA",
		"dmg": 42, "cd": 1.10, "radius": 210.0, "knockback": 380.0,
		"color": Color(1.0, 0.72, 0.42), "tags": [Tags.OVERCLOCK], "heat": 22.0,
	},
	"mortar": {
		"name": "MELT MORTAR", "kind": "LOB",
		"dmg": 46, "cd": 1.25, "speed": 400.0, "life": 1.1, "aoe": 130.0,
		"burn": 4.0,
		"color": Color(1.0, 0.45, 0.22), "tags": [Tags.OVERCLOCK], "heat": 18.0,
	},
	"drill": {
		"name": "PHASE DRILL", "kind": "DIRECT",
		"dmg": 30, "cd": 0.70, "proj": 1, "speed": 900.0, "spread": 0.02, "life": 0.55,
		"pierce": true,
		"color": Color(0.95, 0.9, 0.45), "tags": [Tags.PRECISION], "heat": 11.0,
	},
	"leech": {
		"name": "LEECH BEAM", "kind": "LIFESTEAL",
		"dmg": 11, "cd": 0.22, "proj": 1, "speed": 700.0, "spread": 0.04, "life": 0.9,
		"heal": 1,
		"color": Color(0.55, 1.0, 0.5), "tags": [Tags.VOID, Tags.FORTIFY], "heat": 3.2,
	},
	"mirror": {
		"name": "MIRROR PRISM", "kind": "BOUNCE",
		"dmg": 15, "cd": 0.50, "proj": 2, "speed": 560.0, "spread": 0.18, "life": 2.4,
		"bounce": 3,
		"color": Color(0.85, 0.75, 1.0), "tags": [Tags.PRECISION, Tags.ARC], "heat": 7.0,
	},
}

## 解锁顺序：前 5 把为初始池，其余由「武器实验室」局外升级逐步解锁
const STARTER_IDS := ["pulse", "scatter", "railgun", "homing", "orbiter"]
const ALL_IDS := ["pulse", "scatter", "railgun", "homing", "orbiter",
	"arc", "cryo", "mirror", "leech", "nova", "mortar", "drill"]


static func info(id: String) -> Dictionary:
	return WEAPONS.get(id, WEAPONS["pulse"])


static func exists(id: String) -> bool:
	return WEAPONS.has(id)


static func display_name(id: String) -> String:
	return str(info(id).get("name", id.to_upper()))


static func kind_of(id: String) -> String:
	return str(info(id).get("kind", "DIRECT"))


static func tags_of(id: String) -> Array:
	return info(id).get("tags", [])


static func heat_of(id: String) -> float:
	return float(info(id).get("heat", 0.0))


static func color_of(id: String) -> Color:
	return info(id).get("color", Color(0.8, 0.8, 0.8))


## 武器 → 状态映射（burn 燃烧 / freeze 冻结 / shock 感电 / mark 标记）
const STATUS := {
	"railgun": "mark",
	"orbiter": "shock",
	"arc": "shock",
	"cryo": "freeze",
	"nova": "burn",
	"mortar": "burn",
	"drill": "mark",
}

const STATUS_DURATION := {
	"mark": 4.0, "shock": 3.0, "freeze": 2.2, "burn": 3.5,
}


static func status_of(id: String) -> String:
	return str(STATUS.get(id, ""))


static func status_duration_of(id: String) -> float:
	return float(STATUS_DURATION.get(status_of(id), 0.0))


## 从给定武器池中随机取一把（排除已有）。池由调用方传入（通常 MetaState.unlocked_weapons()）。
static func random_from(pool_in: Array, exclude: Array = []) -> String:
	var pool: Array = []
	for wid in pool_in:
		if str(wid) != "pulse" and not exclude.has(wid):
			pool.append(wid)
	if pool.is_empty():
		return "scatter"
	return str(pool[randi() % pool.size()])


## 高阶武器池（用于骇入房 / Boss 奖励）
static func high_tier_from(pool_in: Array) -> String:
	var pool: Array = []
	for wid in pool_in:
		if not STARTER_IDS.has(wid):
			pool.append(wid)
	if pool.is_empty():
		pool = STARTER_IDS.duplicate()
	return str(pool[randi() % pool.size()])
