class_name ProtocolDB
## ProtocolDB.gd —— V1.3 协议表（每条协议 I → II → III 三段升级）。
## 重复获得同一协议时不再覆盖，而是升一级。
## 高级协议需要局外「协议研究」解锁后才会进入掉落池。

const PROTOCOLS := {
	"siphon": {
		"name": "SIPHON", "tags": [Tags.VOID, Tags.FORTIFY],
		"values": [1, 2, 3], "star": 1,
	},
	"phase": {
		"name": "PHASE", "tags": [Tags.PRECISION],
		"values": [0.40, 0.60, 0.85], "star": 1,
	},
	"magnet": {
		"name": "MAGNET", "tags": [Tags.SALVAGE],
		"values": [80.0, 140.0, 220.0], "star": 1,
	},
	"overclock": {
		"name": "OVERCLOCK", "tags": [Tags.OVERCLOCK],
		"values": [0.15, 0.25, 0.38], "star": 1,
	},
	"armor": {
		"name": "ARMOR", "tags": [Tags.FORTIFY],
		"values": [0.15, 0.25, 0.35], "star": 1,
	},
	"capacitor": {
		"name": "CAPACITOR", "tags": [Tags.FORTIFY, Tags.SALVAGE],
		"values": [1, 2, 3], "star": 1,
	},
	# ---- 高级协议（需局外解锁）----
	"chain": {
		"name": "CHAIN REACTION", "tags": [Tags.ARC, Tags.OVERCLOCK],
		"values": [0.25, 0.40, 0.60], "star": 2,
	},
	"execution": {
		"name": "EXECUTION", "tags": [Tags.PRECISION, Tags.VOID],
		"values": [0.15, 0.25, 0.35], "star": 2,
	},
	"vent": {
		"name": "RELIEF VALVE", "tags": [Tags.FORTIFY],
		"values": [0.50, 0.80, 1.20], "star": 2,
	},
	"vampiric": {
		"name": "VAMPIRIC", "tags": [Tags.VOID, Tags.ARC],
		"values": [1, 2, 3], "star": 2,
	},
	"cryo_field": {
		"name": "CRYO FIELD", "tags": [Tags.CRYO],
		"values": [0.12, 0.20, 0.30], "star": 2,
	},
	"salvage_rig": {
		"name": "SALVAGE RIG", "tags": [Tags.SALVAGE],
		"values": [0.20, 0.35, 0.50], "star": 2,
	},
}

const STARTER_IDS := ["siphon", "phase", "magnet", "overclock", "armor", "capacitor"]
const ADVANCED_IDS := ["chain", "execution", "vent", "vampiric", "cryo_field", "salvage_rig"]
const ALL_IDS := ["siphon", "phase", "magnet", "overclock", "armor", "capacitor",
	"chain", "execution", "vent", "vampiric", "cryo_field", "salvage_rig"]


static func info(id: String) -> Dictionary:
	return PROTOCOLS.get(id, PROTOCOLS["siphon"])


static func exists(id: String) -> bool:
	return PROTOCOLS.has(id)


static func display_name(id: String) -> String:
	return str(info(id).get("name", id.to_upper()))


static func tags_of(id: String) -> Array:
	return info(id).get("tags", [])


## level 为 1..3，返回该等级的数值
static func value_at(id: String, level: int) -> float:
	var vals: Array = info(id).get("values", [0.0, 0.0, 0.0])
	var i := clampi(level - 1, 0, vals.size() - 1)
	return float(vals[i])


static func max_level() -> int:
	return 3


## 从给定池中随机取一条（优先给未拥有的 / 可升级的）
static func random_from(pool_in: Array, owned: Dictionary) -> String:
	var upgradable: Array = []
	var fresh: Array = []
	for pid in pool_in:
		if not ProtocolDB.exists(str(pid)):
			continue
		if owned.has(pid):
			if int(owned[pid]) < 3:
				upgradable.append(pid)
		else:
			fresh.append(pid)
	var pool: Array = []
	if not fresh.is_empty() and (upgradable.is_empty() or randf() < 0.65):
		pool = fresh
	else:
		pool = upgradable if not upgradable.is_empty() else fresh
	if pool.is_empty():
		return "siphon"
	return str(pool[randi() % pool.size()])
