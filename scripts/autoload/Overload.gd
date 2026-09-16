extends Node
## Overload.gd (Autoload) —— V1.3 核心系统：OVERLOAD 过载。
##
## 设计原则：过载不是纯 Debuff，而是一根玩家可以主动踩红线的「收益杠杆」。
## 外部系统只通过信号读结果，不直接改内部变量。
##
## 区间      状态     玩家体验                       额外收益
## 0-39      稳定     武器正常、管线效率 100%        无
## 40-69     高负载   设备冒火花                     掉落率 +5%
## 70-89     危险     敌人伤害 +10%                  金币 +20%
## 90-99     临界     屏幕报警                       金币 +40%、细胞 +25%
## 100       崩溃     随机设备断电 / 爆炸 / 故障敌人  返还部分资源 + 过载遗物

signal tier_changed(tier: int)

const MAX_VALUE := 100.0
const DECAY_BASE := 3.2          # 每秒自然衰减
const VENT_RATE := 30.0          # 主动泄压速率
const MELTDOWN_RESET := 28.0     # 崩溃后回落值

const TIER_STABLE := 0
const TIER_HIGH := 1
const TIER_DANGER := 2
const TIER_CRITICAL := 3
const TIER_MELTDOWN := 4

const MELTDOWN_EFFECTS := ["blackout", "surge", "burn", "emp"]

var value := 0.0
var heat_mult := 1.0             # 房间异常规则 / 过载卡加成
var vent_bonus := 0.0            # 局外「能源工程」+ 冷却协议
var resistance := 0.0            # 全局过热抗性；负数 = 过热加速（如「热能失控」词缀）
var locked := false              # 崩溃锁定期间不衰减
var meltdowns := 0
var _lock_t := 0.0
var _tier := 0


func _process(delta: float) -> void:
	if _lock_t > 0.0:
		_lock_t = maxf(0.0, _lock_t - delta)
		if _lock_t <= 0.0:
			locked = false
	if not locked:
		value = maxf(0.0, value - DECAY_BASE * (1.0 + GameState.overload_decay_bonus()) * delta)
	_push_tier()


func reset() -> void:
	value = 0.0
	heat_mult = 1.0
	meltdowns = 0
	_lock_t = 0.0
	locked = false
	_tier = 0
	_emit()


func setup_room(mult: float) -> void:
	heat_mult = maxf(0.05, mult)


# ---------------- 加 / 减 ----------------
func add(v: float) -> void:
	if v <= 0.0:
		return
	var scaled := v * heat_mult * (1.0 - resistance)
	value = clampf(value + scaled, 0.0, MAX_VALUE)
	_push_tier()


## 按武器表的热量值累积
func add_weapon(weapon_id: String) -> void:
	add(WeaponDB.heat_of(weapon_id) * GameState.card_heat_mult())


func add_overload_card(v: float) -> void:
	add(v)


func vent(delta: float, active: bool) -> void:
	if not active or locked:
		return
	var rate := VENT_RATE * (1.0 + vent_bonus + GameState.vent_bonus())
	value = maxf(0.0, value - rate * delta)
	_push_tier()


func reduce(v: float) -> void:
	value = maxf(0.0, value - v)
	_push_tier()


func ratio() -> float:
	return clampf(value / MAX_VALUE, 0.0, 1.0)


# ---------------- 分段 ----------------
func tier() -> int:
	if value >= MAX_VALUE - 0.001:
		return TIER_MELTDOWN
	if value >= 90.0:
		return TIER_CRITICAL
	if value >= 70.0:
		return TIER_DANGER
	if value >= 40.0:
		return TIER_HIGH
	return TIER_STABLE


func tier_key() -> String:
	match tier():
		TIER_HIGH:
			return "overload_high"
		TIER_DANGER:
			return "overload_danger"
		TIER_CRITICAL:
			return "overload_critical"
		TIER_MELTDOWN:
			return "overload_meltdown"
	return "overload_stable"


# ---------------- 收益杠杆 ----------------
func damage_mult() -> float:
	match tier():
		TIER_HIGH:
			return 1.08
		TIER_DANGER:
			return 1.18
		TIER_CRITICAL:
			return 1.32
		TIER_MELTDOWN:
			return 1.45
	return 1.0


func gold_mult() -> float:
	match tier():
		TIER_DANGER:
			return 1.20
		TIER_CRITICAL:
			return 1.40
		TIER_MELTDOWN:
			return 1.25
	return 1.0


func cell_mult() -> float:
	match tier():
		TIER_CRITICAL:
			return 1.25
		TIER_MELTDOWN:
			return 1.15
	return 1.0


func drop_luck() -> float:
	match tier():
		TIER_HIGH:
			return 0.05
		TIER_DANGER:
			return 0.12
		TIER_CRITICAL:
			return 0.25
		TIER_MELTDOWN:
			return 0.18
	return 0.0


## 高过载时敌人变强
func enemy_damage_mult() -> float:
	return 1.10 if tier() >= TIER_DANGER else 1.0


## 部分武器在 90% 以上获得特殊强化（见 CorePlayer）
func overdrive() -> bool:
	return value >= 90.0


# ---------------- 崩溃 ----------------
func is_meltdown() -> bool:
	return value >= MAX_VALUE - 0.001


func trigger_meltdown(effect: String) -> void:
	meltdowns += 1
	locked = true
	_lock_t = 1.6
	value = MELTDOWN_RESET
	_tier = TIER_STABLE
	EventBus.overload_meltdown.emit(effect)
	_emit()


func random_meltdown_effect() -> String:
	return str(MELTDOWN_EFFECTS[randi() % MELTDOWN_EFFECTS.size()])


# ---------------- 内部 ----------------
func _push_tier() -> void:
	var t := tier()
	if t != _tier:
		_tier = t
		tier_changed.emit(t)
	_emit()


func _emit() -> void:
	EventBus.overload_changed.emit(value, tier())
