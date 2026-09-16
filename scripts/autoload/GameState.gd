extends Node
## GameState.gd (Autoload) —— V1.3 单局状态。
##
## 管理：HP / 金币 / 细胞 / 能量碎片 / 武器槽 / 卷轴属性 / 协议(带等级) /
##       过载卡 / 治疗瓶 / 标签套装 / 连杀 Chain / 房间异常规则 / 挑战词缀。
## 所有成长数值的「乘法公式」集中在这里，武器与敌人只读不算。

const BASE_HP := 100

var core_hp := BASE_HP
var max_hp := BASE_HP
var kills := 0
var score := 0
var active := true

# ---------------- 经济 ----------------
var gold := 0
var cells := 0
var energy := 0          # 能量碎片：房间内给设备 / 奇观供电（V1.3 新增）

# ---------------- 位置 ----------------
var biome_index := 0
var room_index := 0
var room_depth := 0

# ---------------- 卷轴 ----------------
var firepower := 0      # 火力：伤害 +15% / 层
var cooling := 0        # 散热：冷却 ×0.88 / 层，移速 +4% / 层
var structure := 0      # 结构：最大 HP +15 / 层

# ---------------- 装备 ----------------
var weapons: Array[String] = ["pulse", ""]
var weapon_index := 0
var protocols: Dictionary = {}          # id -> level(1..3)
var cards: Array = []                   # [{id, rooms}]

var flask_charges := 3
var flask_max := 3
var crit_chance := 0.05
var bonus_proj := 0

# ---------------- 战场 ----------------
var chain := 0
var _chain_t := 0.0
var death_immunity_used := false        # FORTIFY 6 层：一次免死
var room_modifiers: Array = []          # 当前房间异常规则 id 列表
var room_agg: Dictionary = {}           # ModifierDB.aggregate 缓存

var reroll_left := 0                    # 本区块剩余奖励重掷次数（折叠协议提供）

var run_seed := 0

var _hit_cd := 0.0


func _process(delta: float) -> void:
	if _hit_cd > 0.0:
		_hit_cd = maxf(0.0, _hit_cd - delta)
	if chain > 0:
		_chain_t -= delta
		if _chain_t <= 0.0:
			chain = 0
			EventBus.chain_changed.emit(chain)


# ---------------- 开局 / 重置 ----------------
func reset_run() -> void:
	core_hp = BASE_HP + MetaState.bonus_hp()
	max_hp = core_hp
	kills = 0
	score = 0
	active = true
	gold = MetaState.start_gold()
	cells = 0
	energy = 0
	biome_index = 0
	room_index = 0
	room_depth = 0
	firepower = 0
	cooling = 0
	structure = 0
	crit_chance = 0.05
	bonus_proj = 0
	protocols = {}
	cards = []
	chain = 0
	_chain_t = 0.0
	death_immunity_used = false
	room_modifiers = []
	room_agg = {}
	weapon_index = 0
	reroll_left = MetaState.reroll_charges()
	run_seed = randi()
	if MetaState.has_spare_mag():
		weapons = ["pulse", WeaponDB.random_from(MetaState.unlocked_weapons(), ["pulse"])]
	else:
		weapons = ["pulse", ""]
	flask_max = 3 + MetaState.flask_bonus() + tag_flask_bonus()
	flask_charges = flask_max
	_hit_cd = 0.0
	Overload.reset()
	Overload.resistance = MetaState.overload_resistance() + _challenge_resistance_delta()
	Overload.vent_bonus = MetaState.vent_bonus()
	_apply_challenges()
	_broadcast_all()


func _broadcast_all() -> void:
	EventBus.core_hp_changed.emit()
	EventBus.stats_changed.emit()
	EventBus.gold_changed.emit(gold)
	EventBus.cells_changed.emit(cells)
	EventBus.energy_changed.emit(energy)
	EventBus.weapon_changed.emit(0, weapons[0])
	EventBus.protocol_changed.emit(protocol_list())
	EventBus.card_changed.emit(cards)
	EventBus.build_changed.emit()


# ---------------- 属性公式 ----------------
func firepower_mult() -> float:
	return (1.0 + 0.15 * float(firepower)) * tag_damage_mult()


func cooldown_mult() -> float:
	return pow(0.88, float(cooling)) * card_rate_mult()


func move_mult() -> float:
	var m := 1.0 + 0.04 * float(cooling)
	m += float(room_agg.get("player_speed", 0.0))
	m *= tag_move_mult()
	return maxf(0.4, m)


func roll_cd_mult() -> float:
	return MetaState.roll_cd_mult() * card_roll_cd_mult()


func crit_damage_mult() -> float:
	return 2.5 if tag_tier(Tags.PRECISION) >= 2 else 2.0


func overload_decay_bonus() -> float:
	return 0.0


func vent_bonus() -> float:
	return float(room_agg.get("vent_bonus", 0.0))


func enemy_hp_mult() -> float:
	return 1.0 + float(room_agg.get("enemy_hp", 0.0))


func enemy_count_mult() -> float:
	return 1.0 + float(room_agg.get("enemy_count", 0.0)) \
		+ float(challenge_agg().get("enemy_count", 0.0))


func enemy_dmg_mult() -> float:
	var m := 1.0 + float(room_agg.get("enemy_dmg", 0.0))
	return maxf(0.3, m) * Overload.enemy_damage_mult()


func enemy_speed_mult() -> float:
	return 1.0 + float(room_agg.get("enemy_speed", 0.0))


func enemy_shield_bonus() -> int:
	return int(room_agg.get("enemy_shield", 0))


# ---------------- 生命 / 治疗 ----------------
func damage_core(v: int) -> void:
	if not active or _hit_cd > 0.0:
		return
	var amount := float(v)
	amount *= (1.0 - protocol_value("armor"))
	amount *= (1.0 - tag_damage_reduction())
	amount = maxf(1.0, round(amount))
	core_hp = maxi(0, core_hp - int(amount))
	_hit_cd = 0.5
	EventBus.core_hp_changed.emit()
	if core_hp <= 0:
		if tag_tier(Tags.FORTIFY) >= 3 and not death_immunity_used:
			death_immunity_used = true
			core_hp = maxi(1, int(float(max_hp) * 0.25))
			EventBus.core_hp_changed.emit()
			EventBus.toast.emit(Lang.t("fortify_last_stand"))
			return
		core_hp = 0
		active = false
		EventBus.game_over.emit()


func heal(v: int) -> void:
	if v <= 0:
		return
	core_hp = mini(max_hp, core_hp + v)
	EventBus.core_hp_changed.emit()


func use_flask() -> bool:
	if flask_charges <= 0 or not active:
		return false
	flask_charges -= 1
	heal(int(round(float(max_hp) * 0.4)))
	EventBus.flask_used.emit(flask_charges)
	return true


func refill_flask() -> void:
	flask_charges = flask_max
	EventBus.flask_used.emit(flask_charges)


# ---------------- 卷轴 ----------------
func grant_scroll(kind: String) -> void:
	match kind:
		"firepower":
			firepower += 1
		"cooling":
			cooling += 1
		"structure":
			structure += 1
			max_hp += 15
			heal(15)
		"energy":
			add_energy(30)
		_:
			firepower += 1
	EventBus.stats_changed.emit()
	EventBus.build_changed.emit()


# ---------------- 武器 ----------------
func equip_weapon(id: String) -> void:
	var slot := 1 if weapon_index == 0 else 0
	if weapons[1] == "":
		slot = 1
	elif weapons[0] == "":
		slot = 0
	weapons[slot] = id
	weapon_index = slot
	MetaState.archive_see("weapon", id)
	EventBus.weapon_changed.emit(slot, id)
	EventBus.build_changed.emit()


func swap_weapon() -> void:
	if weapons[1] == "":
		return
	weapon_index = 1 if weapon_index == 0 else 0
	EventBus.weapon_changed.emit(weapon_index, weapons[weapon_index])


func current_weapon() -> String:
	var wid: String = weapons[weapon_index]
	if wid == "":
		return "pulse"
	return wid


func all_weapons() -> Array:
	var out: Array = []
	for w in weapons:
		if str(w) != "":
			out.append(str(w))
	return out


# ---------------- 协议（I→II→III 升级） ----------------
func protocol_level(id: String) -> int:
	return int(protocols.get(id, 0))


func has_protocol(id: String) -> bool:
	return protocol_level(id) > 0


func protocol_value(id: String) -> float:
	var lv := protocol_level(id)
	if lv <= 0:
		return 0.0
	return ProtocolDB.value_at(id, lv)


func protocol_list() -> Array:
	var out: Array = []
	for k in protocols.keys():
		out.append({"id": k, "level": int(protocols[k])})
	out.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	return out


const MAX_PROTOCOLS := 3


func add_protocol(id: String) -> void:
	if not ProtocolDB.exists(id):
		return
	var lv := protocol_level(id)
	if lv > 0:
		if lv >= ProtocolDB.max_level():
			return
		protocols[id] = lv + 1
	else:
		if protocols.size() >= MAX_PROTOCOLS:
			# 已满：替换掉等级最低的一条
			var lowest := ""
			var lowest_lv := 99
			for k in protocols.keys():
				if int(protocols[k]) < lowest_lv:
					lowest_lv = int(protocols[k])
					lowest = str(k)
			if lowest != "":
				protocols.erase(lowest)
		protocols[id] = 1
	if id == "capacitor":
		var add := protocol_level("capacitor")
		flask_max = 3 + MetaState.flask_bonus() + tag_flask_bonus() + add
		flask_charges = mini(flask_max, flask_charges + 1)
	MetaState.archive_see("protocol", id)
	EventBus.protocol_changed.emit(protocol_list())
	EventBus.stats_changed.emit()
	EventBus.build_changed.emit()


# ---------------- 过载卡 ----------------
func add_card(id: String) -> void:
	if not CardDB.exists(id):
		return
	for c in cards:
		var cd: Dictionary = c
		if str(cd["id"]) == id:
			cd["rooms"] = int(cd["rooms"]) + CardDB.duration(id)
			_apply_card_instant(id)
			EventBus.card_changed.emit(cards)
			EventBus.build_changed.emit()
			return
	if cards.size() >= 4:
		cards.pop_front()
	cards.append({"id": id, "rooms": CardDB.duration(id)})
	_apply_card_instant(id)
	MetaState.archive_see("card", id)
	EventBus.card_changed.emit(cards)
	EventBus.build_changed.emit()


func card_level(id: String) -> int:
	for c in cards:
		var cd: Dictionary = c
		if str(cd["id"]) == id:
			return int(cd["rooms"])
	return 0


func has_card(id: String) -> bool:
	return card_level(id) > 0


## 每清空一间房调用一次，递减剩余房间数
func tick_cards() -> void:
	var changed := false
	for i in range(cards.size() - 1, -1, -1):
		var cd: Dictionary = cards[i]
		cd["rooms"] = int(cd["rooms"]) - 1
		if int(cd["rooms"]) <= 0:
			cards.remove_at(i)
			changed = true
	if changed:
		EventBus.card_changed.emit(cards)
		EventBus.build_changed.emit()


func card_dmg_mult() -> float:
	var m := 1.0
	for c in cards:
		m += float(CardDB.info(str((c as Dictionary)["id"])).get("dmg", 0.0))
	return maxf(0.2, m)


func card_rate_mult() -> float:
	var m := 1.0
	for c in cards:
		m -= float(CardDB.info(str((c as Dictionary)["id"])).get("rate", 0.0))
	return clampf(m, 0.3, 3.0)


func card_heat_mult() -> float:
	var m := 1.0
	for c in cards:
		m *= float(CardDB.info(str((c as Dictionary)["id"])).get("heat_mult", 1.0))
	return m


func card_roll_cd_mult() -> float:
	var m := 1.0
	for c in cards:
		m *= float(CardDB.info(str((c as Dictionary)["id"])).get("roll_cd_mult", 1.0))
	return m


func card_gold_mult() -> float:
	var m := 1.0
	for c in cards:
		m += float(CardDB.info(str((c as Dictionary)["id"])).get("gold_mult", 0.0))
	return maxf(0.1, m)


func card_cell_mult() -> float:
	var m := 1.0
	for c in cards:
		m += float(CardDB.info(str((c as Dictionary)["id"])).get("cell_mult", 0.0))
	return maxf(0.1, m)


func card_has(key: String) -> bool:
	for c in cards:
		if CardDB.info(str((c as Dictionary)["id"])).has(key):
			return true
	return false


func card_value(key: String, default_v: float = 0.0) -> float:
	var total := 0.0
	for c in cards:
		total += float(CardDB.info(str((c as Dictionary)["id"])).get(key, 0.0))
	return total if total != 0.0 else default_v


func _apply_card_instant(id: String) -> void:
	if id == "fission":
		var cost := int(round(float(max_hp) * 0.15))
		max_hp = maxi(20, max_hp - cost)
		core_hp = mini(core_hp, max_hp)
		EventBus.core_hp_changed.emit()


# ---------------- 标签套装 ----------------
func tag_counts() -> Dictionary:
	var counts := {}
	for t in Tags.ALL:
		counts[t] = 0
	for wid in all_weapons():
		for t in WeaponDB.tags_of(wid):
			counts[t] = int(counts[t]) + 1
	for pid in protocols.keys():
		for t in ProtocolDB.tags_of(str(pid)):
			counts[t] = int(counts[t]) + 1
	for c in cards:
		for t in CardDB.tags_of(str((c as Dictionary)["id"])):
			counts[t] = int(counts[t]) + 1
	return counts


func tag_count(tag: String) -> int:
	return int(tag_counts().get(tag, 0))


func tag_tier(tag: String) -> int:
	return Tags.tier_of(tag_count(tag))


func tag_damage_mult() -> float:
	var m := 1.0
	var oc := tag_tier(Tags.OVERCLOCK)
	if oc >= 1 and Overload.value >= 70.0:
		m += [0.0, 0.10, 0.22, 0.38][oc]
	var vd := tag_tier(Tags.VOID)
	if vd >= 1 and float(core_hp) / float(maxi(1, max_hp)) < 0.40:
		m += [0.0, 0.12, 0.20, 0.30][vd]
	m += card_dmg_mult()
	return maxf(0.2, m)


func tag_move_mult() -> float:
	var vd := tag_tier(Tags.VOID)
	if vd >= 2:
		return 1.12
	return 1.0


func tag_damage_reduction() -> float:
	var f := tag_tier(Tags.FORTIFY)
	var r := 0.0
	if f >= 1:
		r += 0.08
	if f >= 2:
		r += 0.07
	return r


func tag_crit_bonus() -> float:
	var p := tag_tier(Tags.PRECISION)
	var c := 0.0
	if p >= 1:
		c += 0.08
	if p >= 2:
		c += 0.07
	return c


func tag_flask_bonus() -> int:
	return 1 if tag_tier(Tags.FORTIFY) >= 2 else 0


func effective_crit() -> float:
	return clampf(crit_chance + tag_crit_bonus(), 0.0, 0.95)


func tag_chain_bonus() -> int:
	return 1 if tag_tier(Tags.ARC) >= 1 else 0


func tag_freeze_bonus() -> float:
	var c := tag_tier(Tags.CRYO)
	if c >= 1:
		return 0.5
	return 0.0


func tag_frozen_damage_bonus() -> float:
	return 0.25 if tag_tier(Tags.CRYO) >= 2 else 0.0


# ---------------- 经济 ----------------
func gold_mult() -> float:
	var s := tag_tier(Tags.SALVAGE)
	var m := 1.0
	if s >= 1:
		m += 0.20
	if s >= 2:
		m += 0.20
	m += float(room_agg.get("gold_mult", 0.0))
	return maxf(0.1, m * Overload.gold_mult() * card_gold_mult()
		* float(challenge_agg().get("gold_mult", 1.0)))


func cell_mult() -> float:
	var s := tag_tier(Tags.SALVAGE)
	var m := 1.0
	if s >= 2:
		m += 0.20
	m += float(room_agg.get("cell_mult", 0.0))
	return maxf(0.1, m * Overload.cell_mult() * card_cell_mult()
		* float(challenge_agg().get("cell_mult", 1.0)))


## 挑战词缀「全面停电」：提高房间奖励掉落档次（转成掉落概率加成）
func challenge_drop_bonus() -> float:
	return 0.18 * float(challenge_agg().get("drop_tier", 0))


func add_gold(v: int) -> void:
	var amount := int(round(float(v) * gold_mult()))
	gold += maxi(0, amount)
	EventBus.gold_changed.emit(gold)


func add_gold_raw(v: int) -> void:
	gold += v
	EventBus.gold_changed.emit(gold)


func spend_gold(v: int) -> bool:
	if gold < v:
		return false
	gold -= v
	EventBus.gold_changed.emit(gold)
	return true


func add_cells(v: int, is_boss: bool = false) -> void:
	var mult := cell_mult()
	if is_boss:
		# 挑战词缀「饥饿」：Boss 细胞产出倍率
		mult *= float(challenge_agg().get("boss_cell", 1.0))
	var amount := int(round(float(v) * mult))
	cells += maxi(0, amount)
	EventBus.cells_changed.emit(cells)


func add_energy(v: int) -> void:
	energy = maxi(0, energy + v)
	EventBus.energy_changed.emit(energy)


func spend_energy(v: int) -> bool:
	if energy < v:
		return false
	energy -= v
	EventBus.energy_changed.emit(energy)
	return true


func add_kill(pos: Vector2 = Vector2.ZERO, is_elite: bool = false) -> void:
	kills += 1
	score += 10 + biome_index * 5
	chain += 1
	_chain_t = 5.0
	EventBus.chain_changed.emit(chain)
	if chain == 5 or chain == 10 or chain == 20 or chain == 30:
		add_gold(5 + chain)
		EventBus.toast.emit(Lang.f("chain_reward", [chain]))
	if has_protocol("siphon"):
		heal(int(protocol_value("siphon")))
	if has_card("repair"):
		var per := int(CardDB.info("repair").get("kills_per_heal", 8))
		if per > 0 and kills % per == 0:
			heal(int(CardDB.info("repair").get("heal", 5)))
	if has_protocol("chain") and is_elite:
		pass
	EventBus.stats_changed.emit()


func add_score(v: int) -> void:
	score += v
	EventBus.stats_changed.emit()


func chain_mult() -> float:
	return 1.0 + minf(float(chain), 30.0) * 0.02


# ---------------- 房间异常规则 ----------------
func set_room_modifiers(ids: Array) -> void:
	room_modifiers = ids.duplicate()
	room_agg = ModifierDB.aggregate(room_modifiers)
	Overload.setup_room(float(room_agg.get("heat_mult", 1.0)))


func clear_room_modifiers() -> void:
	room_modifiers = []
	room_agg = {}
	Overload.setup_room(1.0)


func has_modifier(id: String) -> bool:
	return room_modifiers.has(id)


# ---------------- 挑战词缀 ----------------
## 「热能失控」：抗性可降到 0 以下，直接放大过载积累速度（不依赖局外能源工程等级）
func _challenge_resistance_delta() -> float:
	var d := 0.0
	for cid in MetaState.active_challenges:
		if str(cid) == "thermal":
			d -= 0.35
	return d


## 开局生效的「即时数值改写」类词缀（其余词缀由 challenge_agg() 在消费端读取）
func _apply_challenges() -> void:
	for cid in MetaState.active_challenges:
		match str(cid):
			"glass":
				max_hp = maxi(20, int(round(float(max_hp) * 0.70)))
				core_hp = max_hp
	EventBus.core_hp_changed.emit()


## 挑战词缀聚合（供 RoomManager / MainGame 读）
func challenge_agg() -> Dictionary:
	var agg := {"enemy_count": 0.0, "enemy_hp": 0.0, "enemy_dmg": 0.0, "heal_mult": 1.0,
		"cell_mult": 1.0, "gold_mult": 1.0, "drop_tier": 0, "boss_cell": 1.0}
	for cid in MetaState.active_challenges:
		match str(cid):
			"thermal":
				agg["enemy_hp"] = float(agg["enemy_hp"]) + 0.0
			"noheal":
				agg["heal_mult"] = float(agg["heal_mult"]) * 0.5
			"glass":
				agg["gold_mult"] = float(agg["gold_mult"]) * 1.25
			"signal":
				agg["enemy_count"] = float(agg["enemy_count"]) + 0.5
			"blackout":
				agg["drop_tier"] = int(agg["drop_tier"]) + 1
			"hunger":
				agg["boss_cell"] = float(agg["boss_cell"]) * 1.5
	return agg


# ---------------- 存档快照 ----------------
func snapshot() -> Dictionary:
	return {
		"core_hp": core_hp, "max_hp": max_hp, "kills": kills, "score": score,
		"gold": gold, "cells": cells, "energy": energy,
		"biome_index": biome_index, "room_index": room_index, "room_depth": room_depth,
		"firepower": firepower, "cooling": cooling, "structure": structure,
		"weapons": [weapons[0], weapons[1]], "weapon_index": weapon_index,
		"protocols": protocols.duplicate(), "cards": cards.duplicate(),
		"flask_charges": flask_charges, "flask_max": flask_max,
		"crit_chance": crit_chance, "bonus_proj": bonus_proj,
		"overload": Overload.value, "meltdowns": Overload.meltdowns,
		"chain": chain, "run_seed": run_seed,
		"death_immunity_used": death_immunity_used,
		"reroll_left": reroll_left,
		"room_modifiers": room_modifiers.duplicate(),
	}


func restore(d: Dictionary) -> void:
	core_hp = int(d.get("core_hp", BASE_HP))
	max_hp = int(d.get("max_hp", BASE_HP))
	kills = int(d.get("kills", 0))
	score = int(d.get("score", 0))
	gold = int(d.get("gold", 0))
	cells = int(d.get("cells", 0))
	energy = int(d.get("energy", 0))
	biome_index = int(d.get("biome_index", 0))
	room_index = int(d.get("room_index", 0))
	room_depth = int(d.get("room_depth", 0))
	firepower = int(d.get("firepower", 0))
	cooling = int(d.get("cooling", 0))
	structure = int(d.get("structure", 0))
	var w: Array = d.get("weapons", ["pulse", ""])
	weapons = [str(w[0]), str(w[1]) if w.size() > 1 else ""]
	weapon_index = int(d.get("weapon_index", 0))
	protocols = {}
	var pd: Variant = d.get("protocols", {})
	if pd is Dictionary:
		for k in (pd as Dictionary).keys():
			protocols[str(k)] = int((pd as Dictionary)[k])
	cards = []
	var cd: Variant = d.get("cards", [])
	if cd is Array:
		for c in (cd as Array):
			if c is Dictionary:
				cards.append({"id": str((c as Dictionary).get("id", "")),
					"rooms": int((c as Dictionary).get("rooms", 1))})
	flask_charges = int(d.get("flask_charges", 3))
	flask_max = int(d.get("flask_max", 3))
	crit_chance = float(d.get("crit_chance", 0.05))
	bonus_proj = int(d.get("bonus_proj", 0))
	chain = int(d.get("chain", 0))
	run_seed = int(d.get("run_seed", 0))
	death_immunity_used = bool(d.get("death_immunity_used", false))
	reroll_left = int(d.get("reroll_left", 0))
	room_modifiers = []
	var md: Variant = d.get("room_modifiers", [])
	if md is Array:
		for m in (md as Array):
			room_modifiers.append(str(m))
	room_agg = ModifierDB.aggregate(room_modifiers)
	Overload.value = float(d.get("overload", 0.0))
	Overload.meltdowns = int(d.get("meltdowns", 0))
	# 读档同样要带上「热能失控」的抗性修正，否则继续 Run 会丢掉挑战难度
	Overload.resistance = MetaState.overload_resistance() + _challenge_resistance_delta()
	Overload.vent_bonus = MetaState.vent_bonus()
	active = true
	_broadcast_all()
