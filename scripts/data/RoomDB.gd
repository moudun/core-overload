class_name RoomDB
## RoomDB.gd —— V1.3 房间类型表（11 类）。
## 路线图节点、HUD、奖励结算都从这里取元数据；RoomManager 按 id 分发具体机制。

const ROOMS := {
	"combat": {
		"name_key": "room_combat", "risk": 1, "color": Color(0.42, 0.90, 0.82),
		"reward_key": "reward_combat", "weight": 34, "min_depth": 1,
	},
	"elite": {
		"name_key": "room_elite", "risk": 3, "color": Color(1.00, 0.42, 0.40),
		"reward_key": "reward_elite", "weight": 16, "min_depth": 1,
	},
	"treasure": {
		"name_key": "room_treasure", "risk": 2, "color": Color(1.00, 0.82, 0.32),
		"reward_key": "reward_treasure", "weight": 14, "min_depth": 1,
	},
	"repair": {
		"name_key": "room_repair", "risk": 1, "color": Color(0.40, 1.00, 0.68),
		"reward_key": "reward_repair", "weight": 12, "min_depth": 2,
	},
	"shop": {
		"name_key": "room_shop", "risk": 2, "color": Color(0.72, 0.62, 1.00),
		"reward_key": "reward_shop", "weight": 12, "min_depth": 2,
	},
	"lab": {
		"name_key": "room_lab", "risk": 2, "color": Color(0.60, 0.95, 0.95),
		"reward_key": "reward_lab", "weight": 12, "min_depth": 2,
	},
	"glitch": {
		"name_key": "room_glitch", "risk": 2, "color": Color(1.00, 0.70, 0.30),
		"reward_key": "reward_glitch", "weight": 11, "min_depth": 2,
	},
	"harvest": {
		"name_key": "room_harvest", "risk": 4, "color": Color(0.95, 0.30, 0.62),
		"reward_key": "reward_harvest", "weight": 10, "min_depth": 3,
	},
	"hack": {
		"name_key": "room_hack", "risk": 3, "color": Color(0.55, 0.85, 1.00),
		"reward_key": "reward_hack", "weight": 13, "min_depth": 2,
	},
	"boss": {
		"name_key": "room_boss", "risk": 5, "color": Color(1.00, 0.30, 0.24),
		"reward_key": "reward_boss", "weight": 0, "min_depth": 99,
	},
	## 新手教学房：只在「新档首局」或主菜单「训练关卡」入口出现，永不进入随机路线图。
	"tutorial": {
		"name_key": "room_tutorial", "risk": 0, "color": Color(0.50, 0.88, 1.00),
		"reward_key": "reward_tutorial", "weight": 0, "min_depth": 99,
	},
}

## 生成路线图时不会作为「可选节点」出现的类型
const EXCLUDED_FROM_MAP := ["boss", "tutorial"]

## 需要战斗清场的房间（其余为交互/事件房）
const COMBAT_ROOMS := ["combat", "elite", "treasure", "harvest", "boss"]

## 每个区块最多出现的次数上限
const MAX_PER_BIOME := {
	"shop": 1, "repair": 1, "lab": 1, "hack": 1, "harvest": 1, "glitch": 1, "treasure": 2,
}


static func info(id: String) -> Dictionary:
	return ROOMS.get(id, ROOMS["combat"])


static func exists(id: String) -> bool:
	return ROOMS.has(id)


static func display_name(id: String) -> String:
	return Lang.t(str(info(id).get("name_key", "room_combat")))


static func color_of(id: String) -> Color:
	return info(id).get("color", Color(0.6, 0.6, 0.6))


static func risk_of(id: String) -> int:
	return int(info(id).get("risk", 1))


static func reward_hint(id: String) -> String:
	return Lang.t(str(info(id).get("reward_key", "reward_combat")))


static func is_combat(id: String) -> bool:
	return COMBAT_ROOMS.has(id)


static func max_per_biome(id: String) -> int:
	return int(MAX_PER_BIOME.get(id, 99))


## 在给定深度可用的房间类型权重表
static func weighted_pool(depth: int) -> Array:
	var out: Array = []
	for rid in ROOMS.keys():
		var info_d: Dictionary = ROOMS[rid]
		if int(info_d.get("weight", 0)) <= 0:
			continue
		if int(info_d.get("min_depth", 1)) > depth:
			continue
		out.append({"id": rid, "weight": int(info_d["weight"])})
	return out
