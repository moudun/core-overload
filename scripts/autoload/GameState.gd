extends Node
## GameState.gd (Autoload) —— V1.2 单局状态。
## 管理：HP / 金币 / 细胞 / 武器槽 / 卷轴属性 / 协议 / 治疗瓶 / 分数。
## 所有成长数值的「乘法公式」集中在这里，武器与敌人只读不算。

const BASE_HP := 100

var core_hp := BASE_HP
var max_hp := BASE_HP
var kills := 0
var score := 0
var active := true

# --- V1.2 新增 ---
var gold := 0
var cells := 0
var biome_index := 0
var room_index := 0

var firepower := 0      # 火力：伤害 +15% / 层
var cooling := 0        # 散热：冷却 ×0.88 / 层，移速 +4% / 层
var structure := 0      # 结构：最大 HP +15 / 层

var weapons: Array[String] = ["pulse", ""]
var weapon_index := 0
var protocols: Array[String] = []

var flask_charges := 3
var flask_max := 3
var crit_chance := 0.05
var bonus_proj := 0      # 分裂核心卡牌：额外弹道

var _hit_cd := 0.0      # 受击无敌计时（由 CorePlayer 驱动）


func _process(delta: float) -> void:
	if _hit_cd > 0.0:
		_hit_cd = maxf(0.0, _hit_cd - delta)


# ---------------- 开局 / 重置 ----------------
func reset_run() -> void:
	core_hp = BASE_HP + MetaState.bonus_hp()
	max_hp = BASE_HP + MetaState.bonus_hp()
	kills = 0
	score = 0
	active = true
	gold = MetaState.start_gold()
	cells = 0
	biome_index = 0
	room_index = 0
	firepower = 0
	cooling = 0
	structure = 0
	crit_chance = 0.05
	bonus_proj = 0
	protocols = []
	weapon_index = 0
	if MetaState.has_spare_mag():
		weapons = ["pulse", WeaponDB.random_id(["pulse"])]
	else:
		weapons = ["pulse", ""]
	flask_max = 3 + MetaState.flask_bonus()
	flask_charges = flask_max
	_hit_cd = 0.0
	EventBus.core_hp_changed.emit()
	EventBus.stats_changed.emit()
	EventBus.gold_changed.emit(gold)
	EventBus.cells_changed.emit(cells)
	EventBus.weapon_changed.emit(0, weapons[0])


# ---------------- 属性公式 ----------------
func firepower_mult() -> float:
	return 1.0 + 0.15 * float(firepower)


func cooldown_mult() -> float:
	return pow(0.88, float(cooling))


func move_mult() -> float:
	return 1.0 + 0.04 * float(cooling)


func roll_cd_mult() -> float:
	return MetaState.roll_cd_mult()


func has_protocol(id: String) -> bool:
	return protocols.has(id)


# ---------------- 生命 / 治疗 ----------------
func damage_core(v: int) -> void:
	if not active or _hit_cd > 0.0:
		return
	var amount := int(round(float(v) * (0.85 if has_protocol("armor") else 1.0)))
	core_hp = maxi(0, core_hp - amount)
	_hit_cd = 0.5
	EventBus.core_hp_changed.emit()
	if core_hp <= 0:
		core_hp = 0
		active = false
		EventBus.game_over.emit()


func heal(v: int) -> void:
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


# ---------------- 卷轴 / 协议 / 武器 ----------------
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
	EventBus.stats_changed.emit()


func equip_weapon(id: String) -> void:
	var slot := 1 if weapon_index == 0 else 0
	if weapons[1] == "":
		slot = 1
	elif weapons[0] == "":
		slot = 0
	weapons[slot] = id
	weapon_index = slot
	EventBus.weapon_changed.emit(slot, id)


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


func add_protocol(id: String) -> void:
	if protocols.has(id):
		return
	if protocols.size() >= 3:
		protocols.remove_at(0)
	protocols.append(id)
	match id:
		"overclock":
			crit_chance += 0.15
		"capacitor":
			flask_max += 1
			flask_charges += 1
	EventBus.protocol_changed.emit(protocols)
	EventBus.stats_changed.emit()


# ---------------- 经济 ----------------
func add_gold(v: int) -> void:
	gold += v
	EventBus.gold_changed.emit(gold)


func spend_gold(v: int) -> bool:
	if gold < v:
		return false
	gold -= v
	EventBus.gold_changed.emit(gold)
	return true


func add_cells(v: int) -> void:
	cells += v
	EventBus.cells_changed.emit(cells)


func add_kill() -> void:
	kills += 1
	score += 10 + biome_index * 5
	if has_protocol("siphon"):
		heal(1)
	EventBus.stats_changed.emit()


func add_score(v: int) -> void:
	score += v
	EventBus.stats_changed.emit()
