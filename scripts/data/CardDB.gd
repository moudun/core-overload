class_name CardDB
## CardDB.gd —— V1.3 过载卡（Overclock Cards）。
## 只持续 1–2 个房间，效果极端但带明确代价，负责制造临时高潮。
## 生效逻辑集中在 GameState.card_* 系列读取函数里。

const CARDS := {
	"allin": {
		"name": "ALL-IN", "rooms": 1, "tags": [Tags.OVERCLOCK],
		"dmg": 0.60, "rate": 0.20, "heat_mult": 2.0,
	},
	"ice": {
		"name": "ICE PROTOCOL", "rooms": 2, "tags": [Tags.CRYO],
		"freeze_chance": 0.20, "death_explode": 34,
	},
	"repair": {
		"name": "AUTO REPAIR", "rooms": 1, "tags": [Tags.FORTIFY],
		"kills_per_heal": 8, "heal": 5, "gold_mult": -0.25,
	},
	"mirror": {
		"name": "MIRROR FIRE", "rooms": 1, "tags": [Tags.ARC],
		"bonus_proj": 1, "dmg": -0.20,
	},
	"hack": {
		"name": "HACK MODE", "rooms": 2, "tags": [Tags.SALVAGE],
		"shop_discount": 0.40, "cursed_goods": 1,
	},
	"reload": {
		"name": "RELOAD", "rooms": 1, "tags": [Tags.PRECISION],
		"roll_crit": true, "roll_cd_mult": 1.50,
	},
	"fission": {
		"name": "FISSION", "rooms": 2, "tags": [Tags.OVERCLOCK, Tags.VOID],
		"dmg": 0.35, "hp_cost": 0.15, "heat_mult": 1.5,
	},
	"salvage": {
		"name": "SALVAGE RUN", "rooms": 2, "tags": [Tags.SALVAGE],
		"gold_mult": 0.80, "cell_mult": 0.50, "dmg": -0.15,
	},
}

const ALL_IDS := ["allin", "ice", "repair", "mirror", "hack", "reload", "fission", "salvage"]


static func info(id: String) -> Dictionary:
	return CARDS.get(id, CARDS["allin"])


static func exists(id: String) -> bool:
	return CARDS.has(id)


static func display_name(id: String) -> String:
	return str(info(id).get("name", id.to_upper()))


static func tags_of(id: String) -> Array:
	return info(id).get("tags", [])


static func duration(id: String) -> int:
	return int(info(id).get("rooms", 1))


static func random_id(exclude: Array = []) -> String:
	var pool: Array = []
	for cid in ALL_IDS:
		if not exclude.has(cid):
			pool.append(cid)
	if pool.is_empty():
		pool = ALL_IDS.duplicate()
	return str(pool[randi() % pool.size()])


static func random_n(n: int, exclude: Array = []) -> Array:
	var pool: Array = []
	for cid in ALL_IDS:
		if not exclude.has(cid):
			pool.append(cid)
	pool.shuffle()
	var out: Array = []
	for i in mini(n, pool.size()):
		out.append(pool[i])
	return out
