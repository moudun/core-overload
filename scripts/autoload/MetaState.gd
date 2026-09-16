extends Node
## MetaState.gd (Autoload) —— V1.3 局外成长（收集者 · 双货币成长树）。
##
##   tech   科技点   —— 单局「细胞」1:1 兑换，纵向数值成长
##   source 底层源代码 —— 底层骇入房 / Boss / 区块通关 / 通关产出，横向解锁玩法
##
## 持久化到 user://meta.json；旧版 V1.2 存档字段会被迁移读取。
## 同时维护「收藏者档案」图鉴（见过的武器 / 协议 / 事件 / Boss）。

const FILE_PATH := "user://meta.json"

signal meta_changed

# ---------------- 货币 ----------------
var tech_points := 0
var source_code := 0

# ---------------- 等级 ----------------
var levels := {
	"armor": 0, "phase": 0, "funds": 0, "serum": 0, "power": 0,
	"lab": 0, "research": 0, "hack_rig": 0, "reroll": 0, "challenge": 0,
}

# ---------------- 图鉴 ----------------
var archive_weapons: Array = []
var archive_protocols: Array = []
var archive_events: Array = []
var archive_bosses: Array = []
var archive_cards: Array = []

# ---------------- 挑战词缀 ----------------
var active_challenges: Array = []
var runs_completed := 0
var best_score := 0

# ---------------- 新手教学 ----------------
## 是否已完成过操作教学；未完成时「开始新的一局」会先进入教学房。
var tutorial_done := false

## 是否看过开场漫画引导；没看过时主菜单「开始」会先播 4 页漫画。
var intro_seen := false


func _ready() -> void:
	_load()


# ---------------- 查询 ----------------
func level_of(id: String) -> int:
	return int(levels.get(id, 0))


func next_cost(id: String) -> int:
	var lv := level_of(id)
	var c := MetaDB.cost_at(id, lv)
	return c


func can_buy(id: String) -> bool:
	var c := next_cost(id)
	if c < 0:
		return false
	if MetaDB.currency_of(id) == MetaDB.CUR_SOURCE:
		return source_code >= c
	return tech_points >= c


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	var c := next_cost(id)
	if MetaDB.currency_of(id) == MetaDB.CUR_SOURCE:
		source_code -= c
	else:
		tech_points -= c
	levels[id] = level_of(id) + 1
	_save()
	meta_changed.emit()
	return true


func add_tech(v: int) -> void:
	if v <= 0:
		return
	tech_points += v
	_save()
	meta_changed.emit()


func add_source(v: int) -> void:
	if v <= 0:
		return
	source_code += v
	_save()
	meta_changed.emit()


## 细胞 → 科技点换算（1 细胞 = 1 科技点）
func tech_from_cells(cells: int) -> int:
	if cells <= 0:
		return 0
	add_tech(cells)
	return cells


func record_run(score: int, victory: bool) -> void:
	if victory:
		runs_completed += 1
	best_score = maxi(best_score, score)
	_save()


# ---------------- 效果：数值 ----------------
func bonus_hp() -> int:
	return 8 * level_of("armor")


func roll_cd_mult() -> float:
	return 1.0 - 0.12 * float(level_of("phase"))


func start_gold() -> int:
	return 25 * level_of("funds")


func flask_bonus() -> int:
	return level_of("serum")


## 能源工程：全局过热抗性 + 泄压速率
func overload_resistance() -> float:
	return 0.08 * float(level_of("power"))


func vent_bonus() -> float:
	return 0.25 * float(level_of("power"))


# ---------------- 效果：横向解锁 ----------------
func unlocked_weapons() -> Array:
	var pool: Array = WeaponDB.STARTER_IDS.duplicate()
	var lv := level_of("lab")
	for i in mini(lv, MetaDB.LAB_UNLOCKS.size()):
		for wid in MetaDB.LAB_UNLOCKS[i]:
			if not pool.has(wid):
				pool.append(wid)
	return pool


func unlocked_protocols() -> Array:
	var pool: Array = ProtocolDB.STARTER_IDS.duplicate()
	var lv := level_of("research")
	for i in mini(lv, MetaDB.RESEARCH_UNLOCKS.size()):
		for pid in MetaDB.RESEARCH_UNLOCKS[i]:
			if not pool.has(pid):
				pool.append(pid)
	return pool


## 骇入房奖励倍率
func hack_reward_mult() -> float:
	return 1.0 + 0.20 * float(level_of("hack_rig"))


## 骇入小游戏的初始护盾
func hack_shield_bonus() -> int:
	return level_of("hack_rig")


## 每区块可重掷奖励的次数
func reroll_charges() -> int:
	return level_of("reroll")


func challenge_unlocked() -> bool:
	return level_of("challenge") > 0


func has_spare_mag() -> bool:
	return level_of("lab") >= 1


# ---------------- 图鉴 ----------------
func archive_see(category: String, id: String) -> void:
	var arr: Array = []
	match category:
		"weapon":
			arr = archive_weapons
		"protocol":
			arr = archive_protocols
		"event":
			arr = archive_events
		"boss":
			arr = archive_bosses
		"card":
			arr = archive_cards
		_:
			return
	if arr.has(id):
		return
	arr.append(id)
	_save()


func archive_has(category: String, id: String) -> bool:
	match category:
		"weapon":
			return archive_weapons.has(id)
		"protocol":
			return archive_protocols.has(id)
		"event":
			return archive_events.has(id)
		"boss":
			return archive_bosses.has(id)
		"card":
			return archive_cards.has(id)
	return false


func archive_count(category: String) -> int:
	match category:
		"weapon":
			return archive_weapons.size()
		"protocol":
			return archive_protocols.size()
		"event":
			return archive_events.size()
		"boss":
			return archive_bosses.size()
		"card":
			return archive_cards.size()
	return 0


func archive_total(category: String) -> int:
	match category:
		"weapon":
			return WeaponDB.ALL_IDS.size()
		"protocol":
			return ProtocolDB.ALL_IDS.size()
		"event":
			return 8
		"boss":
			return EnemyDB.BOSSES.size()
		"card":
			return CardDB.ALL_IDS.size()
	return 0


# ---------------- 挑战词缀 ----------------
func toggle_challenge(id: String) -> void:
	if active_challenges.has(id):
		active_challenges.erase(id)
	else:
		active_challenges.append(id)
	_save()
	meta_changed.emit()


func clear_challenges() -> void:
	active_challenges.clear()
	_save()
	meta_changed.emit()


# ---------------- 新手教学 ----------------
## 标记操作教学已完成；完成后新的一局不再自动插入教学房。
func set_tutorial_done(v: bool = true) -> void:
	if tutorial_done == v:
		return
	tutorial_done = v
	_save()
	meta_changed.emit()


# ---------------- 存档 ----------------
func _load() -> void:
	if not FileAccess.file_exists(FILE_PATH):
		return
	var f := FileAccess.open(FILE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return
	var d: Dictionary = parsed
	tech_points = int(d.get("tech_points", 0))
	source_code = int(d.get("source_code", 0))
	# 兼容 V1.2 旧字段
	for k in levels.keys():
		levels[k] = clampi(int(d.get(k, 0)), 0, MetaDB.max_of(k))
	if d.has("armor_lv"):
		levels["armor"] = clampi(int(d["armor_lv"]), 0, 5)
	if d.has("phase_lv"):
		levels["phase"] = clampi(int(d["phase_lv"]), 0, 3)
	if d.has("funds_lv"):
		levels["funds"] = clampi(int(d["funds_lv"]), 0, 3)
	if bool(d.get("serum", false)) and levels["serum"] < 1:
		levels["serum"] = 1
	if bool(d.get("spare_mag", false)) and levels["lab"] < 1:
		levels["lab"] = 1
	archive_weapons = _as_array(d.get("archive_weapons", []))
	archive_protocols = _as_array(d.get("archive_protocols", []))
	archive_events = _as_array(d.get("archive_events", []))
	archive_bosses = _as_array(d.get("archive_bosses", []))
	archive_cards = _as_array(d.get("archive_cards", []))
	active_challenges = _as_array(d.get("active_challenges", []))
	runs_completed = int(d.get("runs_completed", 0))
	best_score = int(d.get("best_score", 0))
	tutorial_done = bool(d.get("tutorial_done", false))
	intro_seen = bool(d.get("intro_seen", false))


## 标记看过开场漫画（主菜单播完一輪后调用）
func mark_intro_seen() -> void:
	if intro_seen:
		return
	intro_seen = true
	_save()


func _as_array(v: Variant) -> Array:
	if v is Array:
		return v
	return []


func _save() -> void:
	var f := FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if f == null:
		return
	var d := {
		"tech_points": tech_points,
		"source_code": source_code,
		"archive_weapons": archive_weapons,
		"archive_protocols": archive_protocols,
		"archive_events": archive_events,
		"archive_bosses": archive_bosses,
		"archive_cards": archive_cards,
		"active_challenges": active_challenges,
		"runs_completed": runs_completed,
		"best_score": best_score,
		"tutorial_done": tutorial_done,
		"intro_seen": intro_seen,
	}
	for k in levels.keys():
		d[k] = levels[k]
	f.store_string(JSON.stringify(d))
