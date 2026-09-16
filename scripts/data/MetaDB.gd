class_name MetaDB
## MetaDB.gd —— V1.3 局外成长树定义。
##
## 两种货币：
##   tech  科技点 —— 由单局「细胞」1:1 兑换，用于纵向数值成长
##   source 底层源代码 —— 由「底层骇入房 / Boss / 区块通关」产出，用于横向解锁玩法
##
## 设计原则：永久成长以横向解锁为主、少量基础数值为辅，
## 避免「刷很多局只因为 HP 高了才感觉能赢」。

const CUR_TECH := "tech"
const CUR_SOURCE := "source"

const UPGRADES := [
	{"id": "armor", "cur": CUR_TECH, "max": 5, "costs": [20, 45, 80, 130, 200],
		"key": "meta_armor", "desc_key": "meta_armor_desc"},
	{"id": "phase", "cur": CUR_TECH, "max": 3, "costs": [30, 60, 110],
		"key": "meta_phase", "desc_key": "meta_phase_desc"},
	{"id": "funds", "cur": CUR_TECH, "max": 3, "costs": [25, 50, 90],
		"key": "meta_funds", "desc_key": "meta_funds_desc"},
	{"id": "serum", "cur": CUR_TECH, "max": 2, "costs": [50, 110],
		"key": "meta_serum", "desc_key": "meta_serum_desc"},
	{"id": "power", "cur": CUR_TECH, "max": 3, "costs": [40, 90, 160],
		"key": "meta_power", "desc_key": "meta_power_desc"},

	{"id": "lab", "cur": CUR_SOURCE, "max": 3, "costs": [15, 40, 90],
		"key": "meta_lab", "desc_key": "meta_lab_desc"},
	{"id": "research", "cur": CUR_SOURCE, "max": 2, "costs": [30, 70],
		"key": "meta_research", "desc_key": "meta_research_desc"},
	{"id": "hack_rig", "cur": CUR_SOURCE, "max": 3, "costs": [12, 30, 65],
		"key": "meta_hack", "desc_key": "meta_hack_desc"},
	{"id": "reroll", "cur": CUR_SOURCE, "max": 2, "costs": [25, 60],
		"key": "meta_reroll", "desc_key": "meta_reroll_desc"},
	{"id": "challenge", "cur": CUR_SOURCE, "max": 1, "costs": [50],
		"key": "meta_challenge", "desc_key": "meta_challenge_desc"},
]

## 武器实验室每级解锁的武器
const LAB_UNLOCKS := [
	["arc"],
	["cryo", "mirror"],
	["leech", "nova"],
	["mortar", "drill"],
]

## 协议研究每级解锁的高级协议
const RESEARCH_UNLOCKS := [
	["chain", "execution"],
	["vent", "vampiric"],
	["cryo_field", "salvage_rig"],
]


static func find(id: String) -> Dictionary:
	for u in UPGRADES:
		if str(u["id"]) == id:
			return u
	return {}


static func currency_of(id: String) -> String:
	var u := find(id)
	return str(u.get("cur", CUR_TECH))


static func max_of(id: String) -> int:
	return int(find(id).get("max", 0))


static func cost_at(id: String, level: int) -> int:
	var u := find(id)
	if u.is_empty():
		return -1
	var costs: Array = u["costs"]
	if level >= costs.size():
		return -1
	return int(costs[level])


## 骇入房 / Boss 等产出的源代码基础值（再由 hack_rig 加成）
const SOURCE_PER_HACK := 6
const SOURCE_PER_BOSS := 8
const SOURCE_PER_BIOME := 10
const SOURCE_VICTORY := 40
