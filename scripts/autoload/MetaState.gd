extends Node
## MetaState.gd (Autoload) —— V1.2 局外成长（收集者）。
## 科技点由单局细胞 1:1 兑换，永久升级持久化到 user://meta.json。

const FILE_PATH := "user://meta.json"

var tech_points := 0
var armor_lv := 0        # 核心装甲 0..3
var phase_lv := 0        # 相位引擎 0..2
var funds_lv := 0        # 启动资金 0..2
var spare_mag := false   # 备用弹匣
var serum := false       # 应急血清

const UPGRADES := [
	{"id": "armor", "max": 3, "costs": [20, 45, 80], "key": "meta_armor", "desc_key": "meta_armor_desc"},
	{"id": "phase", "max": 2, "costs": [30, 60], "key": "meta_phase", "desc_key": "meta_phase_desc"},
	{"id": "funds", "max": 2, "costs": [25, 50], "key": "meta_funds", "desc_key": "meta_funds_desc"},
	{"id": "spare_mag", "max": 1, "costs": [70], "key": "meta_mag", "desc_key": "meta_mag_desc"},
	{"id": "serum", "max": 1, "costs": [50], "key": "meta_serum", "desc_key": "meta_serum_desc"},
]


func _ready() -> void:
	_load()


func level_of(id: String) -> int:
	match id:
		"armor":
			return armor_lv
		"phase":
			return phase_lv
		"funds":
			return funds_lv
		"spare_mag":
			return 1 if spare_mag else 0
		"serum":
			return 1 if serum else 0
	return 0


func next_cost(id: String) -> int:
	var lv := level_of(id)
	for u in UPGRADES:
		if u["id"] == id:
			var costs: Array = u["costs"]
			if lv >= costs.size():
				return -1
			return int(costs[lv])
	return -1


func can_buy(id: String) -> bool:
	var c := next_cost(id)
	return c > 0 and tech_points >= c


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	tech_points -= next_cost(id)
	match id:
		"armor":
			armor_lv += 1
		"phase":
			phase_lv += 1
		"funds":
			funds_lv += 1
		"spare_mag":
			spare_mag = true
		"serum":
			serum = true
	_save()
	return true


func add_tech(v: int) -> void:
	tech_points += v
	_save()


## 细胞 → 科技点换算（V1.2：1 细胞 = 1 科技点）
func tech_from_cells(cells: int) -> int:
	if cells <= 0:
		return 0
	add_tech(cells)
	return cells


# ---------------- 效果 ----------------
func bonus_hp() -> int:
	return [0, 10, 20, 30][clampi(armor_lv, 0, 3)]


func roll_cd_mult() -> float:
	return 1.0 - 0.15 * float(clampi(phase_lv, 0, 2))


func start_gold() -> int:
	return [0, 30, 60][clampi(funds_lv, 0, 2)]


func has_spare_mag() -> bool:
	return spare_mag


func flask_bonus() -> int:
	return 1 if serum else 0


# ---------------- 存档 ----------------
func _load() -> void:
	if not FileAccess.file_exists(FILE_PATH):
		return
	var f := FileAccess.open(FILE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		tech_points = int(parsed.get("tech_points", 0))
		armor_lv = clampi(int(parsed.get("armor_lv", 0)), 0, 3)
		phase_lv = clampi(int(parsed.get("phase_lv", 0)), 0, 2)
		funds_lv = clampi(int(parsed.get("funds_lv", 0)), 0, 2)
		spare_mag = bool(parsed.get("spare_mag", false))
		serum = bool(parsed.get("serum", false))


func _save() -> void:
	var f := FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"tech_points": tech_points,
		"armor_lv": armor_lv,
		"phase_lv": phase_lv,
		"funds_lv": funds_lv,
		"spare_mag": spare_mag,
		"serum": serum,
	}))
