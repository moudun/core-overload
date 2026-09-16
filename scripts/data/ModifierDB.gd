class_name ModifierDB
## ModifierDB.gd —— V1.3 房间异常规则（Room Modifier）。
## 进房时按区块/深度随机挂 1-2 条；全部走数据表，不在 RoomManager 里堆 if/else。
##
## 约定：Modifier 只提供「数值修正」与「场景要素」，由 GameState / RoomManager 统一消费。

const MODIFIERS := {
	"heat_surge": {
		"name_key": "mod_heat_surge", "desc_key": "mod_heat_surge_desc",
		"heat_mult": 1.5, "color": Color(1.0, 0.45, 0.30), "weight": 12, "min_biome": 0,
	},
	"chill_field": {
		"name_key": "mod_chill", "desc_key": "mod_chill_desc",
		"vent_bonus": 0.6, "color": Color(0.40, 0.85, 1.0), "weight": 10, "min_biome": 0,
	},
	"shielded": {
		"name_key": "mod_shielded", "desc_key": "mod_shielded_desc",
		"enemy_shield": 1, "color": Color(0.60, 0.75, 1.0), "weight": 11, "min_biome": 1,
	},
	"swarm": {
		"name_key": "mod_swarm", "desc_key": "mod_swarm_desc",
		"enemy_count": 0.5, "enemy_hp": -0.25, "color": Color(1.0, 0.75, 0.30), "weight": 12, "min_biome": 0,
	},
	"armored": {
		"name_key": "mod_armored", "desc_key": "mod_armored_desc",
		"enemy_hp": 0.6, "enemy_count": -0.25, "color": Color(0.85, 0.85, 0.95), "weight": 11, "min_biome": 1,
	},
	"fog": {
		"name_key": "mod_fog", "desc_key": "mod_fog_desc",
		"vignette": 0.62, "color": Color(0.45, 0.45, 0.55), "weight": 9, "min_biome": 0,
	},
	"blackout": {
		"name_key": "mod_blackout", "desc_key": "mod_blackout_desc",
		"dim": 0.55, "enemy_dmg": -0.20, "color": Color(0.35, 0.35, 0.45), "weight": 9, "min_biome": 1,
	},
	"surge_pool": {
		"name_key": "mod_surge", "desc_key": "mod_surge_desc",
		"hazard": "surge", "color": Color(1.0, 0.55, 0.20), "weight": 10, "min_biome": 1,
	},
	"coolant_pool": {
		"name_key": "mod_coolant", "desc_key": "mod_coolant_desc",
		"hazard": "coolant", "color": Color(0.35, 0.95, 0.85), "weight": 10, "min_biome": 0,
	},
	"reflective": {
		"name_key": "mod_reflect", "desc_key": "mod_reflect_desc",
		"reflect": true, "color": Color(0.80, 0.70, 1.0), "weight": 8, "min_biome": 2,
	},
	"gravity": {
		"name_key": "mod_gravity", "desc_key": "mod_gravity_desc",
		"enemy_speed": 0.35, "player_speed": -0.12, "color": Color(0.70, 0.60, 0.95), "weight": 8, "min_biome": 2,
	},
	"overclocked": {
		"name_key": "mod_overclocked", "desc_key": "mod_overclocked_desc",
		"enemy_speed": 0.30, "gold_mult": 0.35, "color": Color(1.0, 0.35, 0.55), "weight": 9, "min_biome": 2,
	},
}

const ALL_IDS := ["heat_surge", "chill_field", "shielded", "swarm", "armored", "fog",
	"blackout", "surge_pool", "coolant_pool", "reflective", "gravity", "overclocked"]


static func info(id: String) -> Dictionary:
	return MODIFIERS.get(id, MODIFIERS["heat_surge"])


static func exists(id: String) -> bool:
	return MODIFIERS.has(id)


static func display_name(id: String) -> String:
	return Lang.t(str(info(id).get("name_key", "mod_heat_surge")))


static func desc(id: String) -> String:
	return Lang.t(str(info(id).get("desc_key", "mod_heat_surge_desc")))


static func color_of(id: String) -> Color:
	return info(id).get("color", Color(0.7, 0.7, 0.7))


## 按区块 + 深度抽 1-3 条不重复的异常规则
static func roll(biome: int, depth: int, rng_seed: int = 0) -> Array:
	var rng := RandomNumberGenerator.new()
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	var pool: Array = []
	for mid in ALL_IDS:
		if int(info(mid).get("min_biome", 0)) <= biome:
			pool.append({"id": mid, "weight": int(info(mid).get("weight", 10))})
	var count := 1
	if depth >= 3:
		count = 2 if rng.randf() < 0.55 else 1
	if biome >= 2 and depth >= 4:
		count = 2
	var out: Array = []
	for _i in count:
		if pool.is_empty():
			break
		var total := 0
		for p in pool:
			total += int(p["weight"])
		var r := rng.randi_range(0, maxi(0, total - 1))
		var acc := 0
		var chosen := -1
		for j in pool.size():
			acc += int(pool[j]["weight"])
			if r < acc:
				chosen = j
				break
		if chosen < 0:
			chosen = pool.size() - 1
		out.append(str(pool[chosen]["id"]))
		pool.remove_at(chosen)
	return out


## 把多条 modifier 的数值修正合并成一份「聚合表」供消费方读取
static func aggregate(ids: Array) -> Dictionary:
	var agg := {
		"heat_mult": 1.0, "vent_bonus": 0.0, "enemy_hp": 0.0, "enemy_count": 0.0,
		"enemy_dmg": 0.0, "enemy_speed": 0.0, "player_speed": 0.0, "gold_mult": 0.0,
		"cell_mult": 0.0, "dim": 0.0, "vignette": 0.0, "enemy_shield": 0,
		"reflect": false, "hazard": "",
	}
	for mid in ids:
		var m: Dictionary = info(str(mid))
		agg["heat_mult"] = float(agg["heat_mult"]) * float(m.get("heat_mult", 1.0))
		for k in ["vent_bonus", "enemy_hp", "enemy_count", "enemy_dmg", "enemy_speed",
				"player_speed", "gold_mult", "cell_mult", "dim", "vignette"]:
			agg[k] = float(agg[k]) + float(m.get(k, 0.0))
		if int(m.get("enemy_shield", 0)) > 0:
			agg["enemy_shield"] = int(agg["enemy_shield"]) + int(m["enemy_shield"])
		if bool(m.get("reflect", false)):
			agg["reflect"] = true
		if str(m.get("hazard", "")) != "":
			agg["hazard"] = str(m["hazard"])
	return agg
