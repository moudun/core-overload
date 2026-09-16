extends Node2D
## RoomManager —— 单房间生命周期状态机（V1.2 核心）。
## BUILD → (玩家入场) LOCKED → COMBAT → CLEARED → (踩出口门) TRANSITION
## 房间类型：combat / treasure / shop / boss

enum State { BUILD, LOCKED, COMBAT, CLEARED, TRANSITION }

const W := 1280
const H := 720
## 出生点必须在左门阻挡体（x 26..116）之外，否则玩家会被卡在门里
const SPAWN_ENTRY := Vector2(176, 380)
const EXIT_POS := Vector2(1195, 380)

var room_type := "combat"
var biome := 0
var room_index := 0
var _state: State = State.BUILD
var _built := false
var _blockers: Array = []
var _door_left: Sprite2D
var _door_right: Sprite2D
var _exit_area: Area2D
var _exit_t := 0.0
var _player_in_exit := false
var _waves: Array = []
var _wave_idx := 0
var _spawn_q: Array = []
var _spawn_t := 0.0
var _boss: Node = null
var _chest: Node2D = null
var _chest_near := false
var _shop_items: Array = []
var _shop_near := -1


func _ready() -> void:
	set_process(true)


func setup(kind: String, biome_idx: int, idx: int) -> void:
	room_type = kind
	biome = biome_idx
	room_index = idx
	_build()


func _build() -> void:
	var parts := RoomFactory.build(self, biome)
	_door_left = parts["door_left"]
	_door_right = parts["door_right"]
	_blockers = parts["blockers"]

	var pillars := 4 if room_type != "boss" else 2
	RoomFactory.add_pillars(self, biome, randi_range(3, pillars + 3))

	# 出口感应区
	_exit_area = Area2D.new()
	_exit_area.collision_layer = 0
	_exit_area.collision_mask = 1
	_exit_area.monitoring = true
	_exit_area.global_position = EXIT_POS
	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 40.0
	shape.shape = circ
	_exit_area.add_child(shape)
	add_child(_exit_area)
	_exit_area.body_entered.connect(func(b): if b.is_in_group("player"): _player_in_exit = true)
	_exit_area.body_exited.connect(func(b): if b.is_in_group("player"): _player_in_exit = false)

	if room_type == "shop":
		_build_shop()
	elif room_type == "combat" and randf() < 0.35:
		_build_chest()

	EventBus.room_entered.emit(biome, room_index, room_type)
	_built = true


func _build_shop() -> void:
	var offers := ["weapon", "heal", "scroll"]
	var prices := [55, 30, 60]
	for i in offers.size():
		var ped := Node2D.new()
		ped.global_position = Vector2(420 + i * 200, 300)
		var spr := Sprite2D.new()
		spr.texture = PixelArt.card_tex(30, Color(0.2, 0.7, 0.95))
		ped.add_child(spr)
		var lab := Label.new()
		lab.position = Vector2(-60, 34)
		lab.custom_minimum_size = Vector2(120, 0)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", 13)
		lab.modulate = Color(0.9, 1.0, 0.9)
		lab.text = "%s\n%dG" % [Lang.t("shop_buy_" + offers[i]), prices[i]]
		ped.add_child(lab)
		add_child(ped)
		_shop_items.append({"node": ped, "offer": offers[i], "price": prices[i]})


func _build_chest() -> void:
	_chest = Node2D.new()
	_chest.global_position = Vector2(640, 220)
	var spr := Sprite2D.new()
	spr.texture = PixelArt.chest_tex()
	_chest.add_child(spr)
	var lab := Label.new()
	lab.position = Vector2(-70, 30)
	lab.custom_minimum_size = Vector2(140, 0)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 12)
	lab.text = Lang.t("chest_hint")
	_chest.add_child(lab)
	add_child(_chest)


# ---------------- 主循环 ----------------
func _process(delta: float) -> void:
	if not _built:
		return
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return

	match _state:
		State.BUILD:
			if room_type == "shop":
				_state = State.CLEARED
				_unlock()
				EventBus.room_cleared.emit()
			elif p.global_position.x > 200.0:
				_lock()
		State.LOCKED:
			pass
		State.COMBAT:
			_tick_combat(delta)
		State.CLEARED:
			_exit_tick(delta)
		State.TRANSITION:
			pass

	# 交互（商店 / 宝箱）
	if _chest != null and is_instance_valid(_chest):
		var near_chest := _chest.global_position.distance_to(p.global_position) < 70.0
		if near_chest and Input.is_key_pressed(KEY_E) and not _chest_near:
			_open_chest()
		_chest_near = near_chest

	var near_shop := -1
	for i in _shop_items.size():
		var it: Dictionary = _shop_items[i]
		var n: Node2D = it["node"]
		if is_instance_valid(n) and n.global_position.distance_to(p.global_position) < 70.0:
			near_shop = i
			break
	if near_shop >= 0 and Input.is_key_pressed(KEY_E) and near_shop != _shop_near:
		_buy(near_shop)
	_shop_near = near_shop


func _lock() -> void:
	_state = State.LOCKED
	EventBus.room_locked.emit()
	if room_type == "boss":
		_spawn_boss()
		return
	# 战斗波表：2 波（60% / 40%）
	var total := 4 + GameState.biome_index + room_index
	var w1 := int(ceil(float(total) * 0.6))
	var w2 := maxi(1, total - w1)
	_waves = [_composition(w1), _composition(w2)]
	if room_type == "treasure":
		_waves = [[{"kind": 0, "elite": true}], [{"kind": 0, "elite": false}, {"kind": 2, "elite": false}]]
	_wave_idx = 0
	_start_wave()


func _composition(n: int) -> Array:
	var arr: Array = []
	for _i in n:
		var k := EnemyDB.roll_kind(GameState.biome_index, room_index)
		arr.append({"kind": k, "elite": randf() < 0.08})
	return arr


func _start_wave() -> void:
	if _wave_idx >= _waves.size():
		return
	_spawn_q = (_waves[_wave_idx] as Array).duplicate()
	_spawn_t = 0.4
	_state = State.COMBAT


func _tick_combat(delta: float) -> void:
	if not _spawn_q.is_empty():
		_spawn_t -= delta
		if _spawn_t <= 0.0:
			var spec: Dictionary = _spawn_q.pop_front()
			_spawn_enemy(int(spec["kind"]), bool(spec["elite"]))
			_spawn_t = 0.35
		return
	if get_tree().get_nodes_in_group("enemies").is_empty():
		_wave_idx += 1
		if _wave_idx < _waves.size():
			_start_wave()
		else:
			_clear()


func _spawn_enemy(kind: int, elite: bool) -> void:
	var e: Node = load("res://scripts/entities/Enemy.gd").new()
	add_child(e)
	var pos := Vector2(randf_range(300.0, 980.0), randf_range(120.0, 620.0))
	var p := get_tree().get_first_node_in_group("player")
	if p != null:
		# 保证不在玩家脸上刷怪
		for _i in 12:
			if pos.distance_to(p.global_position) > 260.0:
				break
			pos = Vector2(randf_range(300.0, 980.0), randf_range(120.0, 620.0))
	e.global_position = pos
	e.setup(kind, GameState.biome_index, elite)


func _spawn_boss() -> void:
	var script_path := "res://scripts/entities/bosses/CoolantTitan.gd"
	match GameState.biome_index:
		1:
			script_path = "res://scripts/entities/bosses/Gravekeeper.gd"
		2:
			script_path = "res://scripts/entities/bosses/CoreMind.gd"
	_boss = load(script_path).new()
	add_child(_boss)
	_boss.global_position = Vector2(880, 360)
	_state = State.COMBAT
	# 注意：boss_spawned 由 Boss 自身 _ready 发出（带真实名字与血量），此处不得重复发送


func _clear() -> void:
	_state = State.CLEARED
	_unlock()
	EventBus.room_cleared.emit()
	if room_type == "treasure":
		EventBus.scroll_choice_opened.emit(["firepower", "cooling", "structure"])
		GameState.add_cells(3)
	elif room_type == "combat":
		GameState.add_gold(10 + GameState.biome_index * 5)
		if randf() < 0.35:
			var ids: Array = LootCard.CARD_IDS
			_drop_loot("card", str(ids[randi() % ids.size()]), 0)
	elif room_type == "boss":
		GameState.refill_flask()


func _unlock() -> void:
	for b in _blockers:
		if is_instance_valid(b):
			b.queue_free()
	_blockers.clear()
	if is_instance_valid(_door_left):
		_door_left.texture = PixelArt.door_tex(false)
	if is_instance_valid(_door_right):
		_door_right.texture = PixelArt.door_tex(false)
	EventBus.door_opened.emit()


func _exit_tick(delta: float) -> void:
	if _player_in_exit:
		_exit_t += delta
		if _exit_t >= 0.3:
			_state = State.TRANSITION
			RunDirector.advance()
	else:
		_exit_t = 0.0


func _drop_loot(kind: String, payload: String, amount: int) -> void:
	var l: Node = load("res://scripts/entities/LootCard.gd").new()
	add_child(l)
	l.global_position = Vector2(640, 360) + Vector2(randf_range(-60, 60), randf_range(-60, 60))
	l.setup(kind, payload, amount)


func _open_chest() -> void:
	if _chest == null:
		return
	_chest.queue_free()
	_chest = null
	GameState.add_gold(30)
	EventBus.scroll_choice_opened.emit(["firepower", "cooling", "structure"])
	EventBus.toast.emit(Lang.t("chest_opened"))
	# 过载反噬：6 只强化敌人
	_waves = [[]]
	var back: Array = []
	for _i in 6:
		back.append({"kind": EnemyDB.roll_kind(GameState.biome_index, room_index), "elite": true})
	_waves = [back]
	_wave_idx = 0
	_start_wave()


func _buy(idx: int) -> void:
	var it: Dictionary = _shop_items[idx]
	var price: int = int(it["price"])
	if not GameState.spend_gold(price):
		EventBus.toast.emit(Lang.t("shop_poor"))
		return
	match str(it["offer"]):
		"weapon":
			var wid := WeaponDB.random_id(GameState.weapons)
			GameState.equip_weapon(wid)
			EventBus.toast.emit("%s: %s" % [Lang.t("weapon_gained"), Lang.t("w_" + wid)])
		"heal":
			GameState.heal(40)
		"scroll":
			GameState.grant_scroll(["firepower", "cooling", "structure"][randi() % 3])
	EventBus.toast.emit(Lang.t("shop_bought"))
	var n: Node2D = it["node"]
	n.queue_free()
	_shop_items.remove_at(idx)
