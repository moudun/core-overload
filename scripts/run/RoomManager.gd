extends Node2D
class_name RoomManager
## RoomManager —— V1.3 单房间生命周期状态机（11 类房间）。
## BUILD → (玩家入场) LOCKED → COMBAT / PUZZLE / TUTORIAL → CLEARED → (踩出口门) TRANSITION
##
## 房间类型：combat / elite / treasure / repair / shop / lab / glitch / harvest / hack / boss / tutorial
## 房间异常规则由 ModifierDB 提供聚合数值，房间本身只负责「要素」。

enum State { BUILD, LOCKED, COMBAT, PUZZLE, CLEARED, TRANSITION, TUTORIAL }

const W := 1280
const H := 720
## 出生点必须在左门阻挡体（x 26..116）之外，否则玩家会被卡在门里
const SPAWN_ENTRY := Vector2(176, 380)
const EXIT_POS := Vector2(1195, 380)

const GLITCH_NODES := 3
const GLITCH_TIME := 22.0
const HARVEST_TIME := 30.0

## 交互判定半径（逻辑坐标）。比以前的 74/76 放宽：等距下「看起来踩上去了」
## 和「逻辑上重合」有视觉错觉，半径太小会让玩家觉得按 E 没反应。
const CHEST_RADIUS := 96.0
const SHOP_RADIUS := 100.0
const TERMINAL_RADIUS := 112.0
const GLITCH_RADIUS := 100.0

## 宝箱位置：主走廊正中偏右，出生点到它是一条无障碍直线
const CHEST_POS := Vector2(700, 380)

## 教学房：逐步教学的操作清单（与 Lang 的 tutorial_goal_<id> 一一对应）
const TUTORIAL_STEPS := ["move", "shoot", "roll", "swap", "vent", "skill"]
const TUTORIAL_MOVE_X := 430.0
const TUTORIAL_SHOOT_HITS := 3
const TUTORIAL_VENT_TARGET := 5.0     # 过载压到这个值以下算完成
const TUTORIAL_VENT_HOLD := 1.0       # 或累计泄压 1 秒也算完成
const TUTORIAL_DUMMY_POS := Vector2(850, 380)

var room_type := "combat"
var biome := 0
var room_index := 0
var depth := 0

var _state: State = State.BUILD
var _built := false
var _view: Node2D = null
var _blockers: Array = []
var _door_left: Node2D
var _door_right: Node2D
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
var _chest_halo: Sprite2D = null
var _shop_items: Array = []
## true = 玩家上一帧已经站在某个商品前（用于 E 的边沿触发，买完必须走开再回来）
var _shop_near := false

## 当前「可交互目标」——HUD 用它显示「[E] 开启宝箱」这类提示。
## {id: String, label: String, dist: float} 或空字典表示附近没有可交互物。
var _prompt: Dictionary = {}

# 故障房
var _nodes: Array = []
var _seq: Array = []
var _seq_idx := 0
var _glitch_t := 0.0
var _glitch_done := false
var _flash_obj: Node2D = null
var _flash_t := 0.0
var _node_near := -1

# 收割房
var _harvest_t := 0.0
var _harvest_kills := 0
var _harvest_target := 0
var _harvest_start_kills := 0

# 骇入房
var _terminal: Node2D = null
var _terminal_near := false
var _hack_started := false

# 教学房
var _tut_idx := 0
var _tut_hits := 0
var _tut_vent_t := 0.0
var _tut_roll_seen := false
var _tut_skill_seen := false
var _tut_swap_from := 0
var _tut_dummy: Node2D = null
var _tut_marker: Node2D = null

# 通用
var _e_prev := false
var _hazards: Array = []
var _soft_walls: Array = []
var _vignette: ColorRect = null
var _room_time := 0.0


func _ready() -> void:
	add_to_group("room")
	set_process(true)


func setup(kind: String, biome_idx: int, idx: int, depth_v: int) -> void:
	room_type = kind
	biome = biome_idx
	room_index = idx
	depth = depth_v
	_build()


func _build() -> void:
	var parts := RoomFactory.build(self, biome)
	_door_left = parts["door_left"]
	_door_right = parts["door_right"]
	_blockers = parts["blockers"]
	_view = parts["view"]

	if RoomDB.is_combat(room_type) or room_type == "glitch" or room_type == "harvest":
		var pillars := 2 if room_type == "boss" else 4
		RoomFactory.add_pillars(self, biome, randi_range(3, pillars + 3), _view)

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

	# 房间异常规则（仅战斗类房间挂）
	if RoomDB.is_combat(room_type) or room_type == "glitch" or room_type == "harvest":
		GameState.set_room_modifiers(ModifierDB.roll(biome, depth))
	else:
		GameState.clear_room_modifiers()
	_build_hazards()
	_build_vignette()

	match room_type:
		"shop":
			_build_shop()
		"repair":
			_build_repair()
		"treasure":
			_build_chest()
		"glitch":
			_build_glitch()
		"harvest":
			_build_harvest()
		"hack":
			_build_terminal()
		"lab":
			_build_lab_beacon()
		"boss":
			pass
		"tutorial":
			_build_tutorial()

	EventBus.room_entered.emit(biome, room_index, room_type, depth)
	_built = true


func _build_vignette() -> void:
	var v := float(GameState.room_agg.get("vignette", 0.0))
	var d := float(GameState.room_agg.get("dim", 0.0))
	var strength := maxf(v, d)
	if strength <= 0.0:
		return
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_vignette = ColorRect.new()
	_vignette.color = Color(0.0, 0.0, 0.02, clampf(strength * 0.55, 0.0, 0.7))
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_vignette)


func _build_hazards() -> void:
	var hz := str(GameState.room_agg.get("hazard", ""))
	if hz == "":
		return
	for i in 2:
		var pos := Vector2(420 + i * 380, 300 + (i % 2) * 160)
		var n := IsoShim.anchored(self, pos, -2)
		if hz == "coolant":
			_decal(n, PixelArt.circle_tex(120, Color(0.12, 0.45, 0.42, 0.55), Color(0.20, 0.75, 0.70, 0.4), Color(0.30, 0.95, 0.85, 0.3)))
		else:
			_decal(n, PixelArt.circle_tex(120, Color(0.50, 0.28, 0.05, 0.5), Color(0.90, 0.55, 0.10, 0.4), Color(1.0, 0.72, 0.28, 0.3)))
		# 伤害判定区仍然在逻辑坐标里
		var area := Area2D.new()
		area.collision_layer = 0
		area.collision_mask = 1
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 58.0
		cs.shape = c
		area.add_child(cs)
		area.global_position = pos
		add_child(area)
		_hazards.append({"node": n, "area": area, "kind": hz, "cd": 0.0, "inside": false})
		area.body_entered.connect(func(b): if b.is_in_group("player"): _hazard_enter(hz))
		area.body_exited.connect(func(b): if b.is_in_group("player"): _hazard_exit(hz))


func _hazard_enter(kind: String) -> void:
	for h in _hazards:
		var hd: Dictionary = h
		if str(hd["kind"]) == kind:
			hd["inside"] = true


func _hazard_exit(kind: String) -> void:
	for h in _hazards:
		var hd: Dictionary = h
		if str(hd["kind"]) == kind:
			hd["inside"] = false


# ---------------- 各类房间的静态要素 ----------------
## 说明：这些道具全部用 IsoShim 定位 —— 逻辑坐标给碰撞与交互，屏幕坐标给画面。
## 「贴在地上的」一律压成 2:1 椭圆/菱形，才和等距地板对得上；
## 「立着的」（宝箱、终端、机体）保持正立当广告牌。
func _make_label(parent: Node2D, text: String, y_off: float, width: float, size: int = 13) -> Label:
	var lab := Label.new()
	lab.position = Vector2(-width * 0.5, y_off)
	lab.custom_minimum_size = Vector2(width, 0)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.add_theme_font_size_override("font_size", size)
	lab.modulate = Color(0.92, 1.0, 0.94, 0.95)
	parent.add_child(lab)
	lab.text = text
	return lab


## 地面贴花：贴图压成 2:1，看起来才像躺在等距地板上
func _decal(parent: Node2D, tex: Texture2D, y_off: float = 0.0) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(1.0, 0.5)
	spr.position = Vector2(0.0, y_off)
	parent.add_child(spr)
	return spr


## 立式广告牌：正立，向上抬一点让底边落在逻辑点上
func _billboard(parent: Node2D, tex: Texture2D, lift: float) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = Vector2(0.0, -lift)
	parent.add_child(spr)
	return spr


func _build_shop() -> void:
	var offers: Array = ["weapon", "heal", "protocol", "card", "energy"]
	offers.shuffle()
	var n := 4 if depth < 3 else 5
	var discount := GameState.card_value("shop_discount", 0.0)
	for i in n:
		var offer := str(offers[i % offers.size()])
		var base_price := 55
		match offer:
			"weapon":
				base_price = 60
			"heal":
				base_price = 30
			"protocol":
				base_price = 70
			"card":
				base_price = 65
			"energy":
				base_price = 20
		var price := maxi(8, int(round(float(base_price) * (1.0 - discount))))
		var ped := IsoShim.anchored(self, Vector2(340 + i * 160, 300), 1, 13.0)
		_decal(ped, PixelArt.circle_tex(64, Color(0.10, 0.26, 0.30, 0.55), Color(0.20, 0.60, 0.58, 0.35), Color(0.35, 0.90, 0.84, 0.25)))
		_billboard(ped, PixelArt.card_tex(30, _offer_color(offer)), 24.0)
		_make_label(ped, "%s\n%dG" % [Lang.t("shop_buy_" + offer), price], 8, 150, 13)
		_shop_items.append({"node": ped, "offer": offer, "price": price})


func _offer_color(offer: String) -> Color:
	match offer:
		"weapon":
			return Color(1.0, 0.72, 0.30)
		"heal":
			return Color(0.40, 1.00, 0.68)
		"protocol":
			return Color(0.72, 0.62, 1.00)
		"card":
			return Color(1.00, 0.42, 0.30)
		_:
			return Color(1.00, 0.85, 0.35)


func _build_repair() -> void:
	var pad := IsoShim.anchored(self, Vector2(640, 330), 1)
	_decal(pad, PixelArt.circle_tex(96, Color(0.15, 0.85, 0.65), Color(0.08, 0.45, 0.40), Color(0.30, 1.0, 0.80)))
	_make_label(pad, Lang.t("room_repair"), -44, 260, 15)


func _build_lab_beacon() -> void:
	var pad := IsoShim.anchored(self, Vector2(640, 330), 1)
	_decal(pad, PixelArt.diamond_tex(96, Color(0.60, 0.95, 0.95), Color(0.15, 0.40, 0.55)))
	_make_label(pad, Lang.t("lab_title"), -44, 420, 15)


func _build_chest() -> void:
	# 宝箱放在主走廊（y=380）上，玩家一进房就能看到并走过去。
	# 原来放在 (640,260) —— 出生点 (176,380) 距它 479px，而且房间一进门就封锁，
	# 玩家根本走不到，体感就是「按 E 没反应」。
	_chest = IsoShim.anchored(self, CHEST_POS, 1, 15.0)
	_billboard(_chest, PixelArt.chest_tex(), 18.0)
	_make_label(_chest, Lang.t("chest_hint"), 12, 320, 12)
	# 地上一圈脉冲光环，远远就能看见这里有个能按的东西
	var ring := IsoShim.anchored(self, CHEST_POS, 0, 0.0)
	var halo := Sprite2D.new()
	halo.texture = PixelArt.chest_halo_tex()
	halo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	halo.scale = Vector2(1.0, 0.5)
	halo.position = Vector2(0.0, 2.0)
	halo.z_index = -1
	ring.add_child(halo)
	_chest_halo = halo



func _build_terminal() -> void:
	_terminal = IsoShim.anchored(self, Vector2(640, 330), 1, 22.0)
	_billboard(_terminal, PixelArt.square_tex(72, Color(0.16, 0.36, 0.52), Color(0.30, 1.0, 0.80), 6.0), 26.0)
	var inner := Sprite2D.new()
	inner.texture = PixelArt.source_tex()
	inner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	inner.scale = Vector2(2.4, 2.4)
	inner.position = Vector2(0.0, -26.0)
	inner.z_index = 1
	_terminal.add_child(inner)
	_make_label(_terminal, Lang.t("hack_title"), -64, 300, 16)
	_make_label(_terminal, Lang.t("hack_hint"), 14, 420, 12)


func _build_glitch() -> void:
	var spots := [Vector2(400, 260), Vector2(660, 420), Vector2(900, 250)]
	for i in GLITCH_NODES:
		var n := IsoShim.anchored(self, spots[i], 1, 10.0)
		var node_spr := _decal(n, PixelArt.pipe_node_tex(0))
		var glow := Sprite2D.new()
		glow.texture = PixelArt.circle_tex(96, Color(1.0, 0.70, 0.30, 0.30), Color(1.0, 0.55, 0.15, 0.22), Color(1.0, 0.72, 0.28, 0.15))
		glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		glow.scale = Vector2(1.0, 0.5)
		glow.visible = false
		n.add_child(glow)
		_nodes.append({"node": n, "spr": node_spr, "glow": glow, "fixed": false, "index": i})
	_seq = _roll_sequence()
	_seq_idx = 0
	_glitch_t = GLITCH_TIME
	_flash_t = 1.4
	_refresh_node_visuals()
	EventBus.toast.emit(Lang.t("glitch_hint"))


func _roll_sequence() -> Array:
	var arr: Array = [0, 1, 2]
	for i in range(arr.size() - 1, 0, -1):
		var j := randi() % (i + 1)
		var t: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = t
	return arr


func _build_harvest() -> void:
	_harvest_t = HARVEST_TIME
	_harvest_kills = 0
	_harvest_start_kills = GameState.kills
	_harvest_target = 12 + depth * 3
	EventBus.toast.emit(Lang.f("harvest_hint", [int(HARVEST_TIME)]))


# ---------------- 教学房 ----------------
func _build_tutorial() -> void:
	# 1) 走位标记：第 1 步的落点
	_tut_marker = IsoShim.anchored(self, Vector2(TUTORIAL_MOVE_X, 380), -1, 30.0)
	_decal(_tut_marker, PixelArt.circle_tex(120,
		Color(0.10, 0.28, 0.30, 0.45), Color(0.22, 0.68, 0.64, 0.45), Color(0.45, 1.0, 0.92, 0.35)))
	_make_label(_tut_marker, Lang.t("tutorial_move_marker"), -44, 320, 14)

	# 2) 训练假人：不还手、不死亡
	_tut_dummy = load("res://scripts/entities/TrainingDummy.gd").new()
	add_child(_tut_dummy)
	_tut_dummy.global_position = TUTORIAL_DUMMY_POS

	# 3) 教学补给：给一把副武器，让 Q 换武器这一步有实际效果
	if GameState.weapons[1] == "":
		GameState.equip_weapon("scatter")
		EventBus.toast.emit(Lang.t("tutorial_swap_bonus"))
	else:
		EventBus.toast.emit(Lang.t("tutorial_title"))

	# 4) 监听玩家动作（节点释放时连接自动断开）
	EventBus.hit_enemy.connect(_on_tut_hit)
	EventBus.roll_started.connect(_on_tut_roll)
	EventBus.skill_used.connect(_on_tut_skill)

	# 5) 立刻开训（延迟一帧，保证 room_entered 先发给 HUD）：
	#    第 1 步本身就是「用 WASD 走到标记处」，所以不需要等玩家先走一步才出提示。
	#    房间从开场就是封闭的，唯一出口是完成全部步骤后打开。
	_start_tutorial.call_deferred()


func _on_tut_hit(_pos: Vector2, _color: Color, _amount: int, _crit: bool) -> void:
	if _state != State.TUTORIAL or _tut_idx >= TUTORIAL_STEPS.size():
		return
	if str(TUTORIAL_STEPS[_tut_idx]) == "shoot":
		_tut_hits += 1


func _on_tut_roll() -> void:
	if _state == State.TUTORIAL:
		_tut_roll_seen = true


func _on_tut_skill(_skill_id: String) -> void:
	if _state == State.TUTORIAL:
		_tut_skill_seen = true


func _start_tutorial() -> void:
	_state = State.TUTORIAL
	_tut_idx = 0
	_tut_hits = 0
	_tut_vent_t = 0.0
	_tut_roll_seen = false
	_tut_skill_seen = false
	_emit_tutorial_step()


## 广播当前步骤；进入某些步骤前先布置好「可被观察到的状态」
func _emit_tutorial_step() -> void:
	if _tut_idx >= TUTORIAL_STEPS.size():
		return
	var sid := str(TUTORIAL_STEPS[_tut_idx])
	match sid:
		"swap":
			# 记下进入本步时的武器槽，玩家只要切走即算完成
			_tut_swap_from = GameState.weapon_index
		"vent":
			# 先灌一段过载，玩家才能看到泄压的效果
			Overload.add(45.0)
		"skill":
			# 清掉技能冷却，避免玩家前面误按 R 后卡住
			var pl := get_tree().get_first_node_in_group("player")
			if pl != null and pl.has_method("reset_skill_cd"):
				pl.reset_skill_cd()
		_:
			pass
	EventBus.tutorial_step.emit(_tut_idx, TUTORIAL_STEPS.size(), sid)


func _tick_tutorial(delta: float, p: Node2D) -> void:
	if _tut_idx >= TUTORIAL_STEPS.size():
		return
	var sid := str(TUTORIAL_STEPS[_tut_idx])
	var done := false
	match sid:
		"move":
			done = p.global_position.x >= TUTORIAL_MOVE_X
			if _tut_marker != null and is_instance_valid(_tut_marker):
				_tut_marker.visible = not done
		"shoot":
			done = _tut_hits >= TUTORIAL_SHOOT_HITS
		"roll":
			done = _tut_roll_seen
		"swap":
			done = GameState.weapon_index != _tut_swap_from
		"vent":
			if _is_venting(p):
				_tut_vent_t += delta
			done = Overload.value <= TUTORIAL_VENT_TARGET or _tut_vent_t >= TUTORIAL_VENT_HOLD
		"skill":
			done = _tut_skill_seen
	if not done:
		return
	_tut_idx += 1
	if _tut_idx >= TUTORIAL_STEPS.size():
		_finish_tutorial()
		return
	_emit_tutorial_step()


## CorePlayer 每帧写入的泄压标志；用 get() 读取，避免测试替身（纯 Node2D）直接崩
func _is_venting(p: Node2D) -> bool:
	var v: Variant = p.get("venting")
	return v != null and bool(v)


func _finish_tutorial() -> void:
	if _tut_dummy != null and is_instance_valid(_tut_dummy):
		_tut_dummy.queue_free()
	_tut_dummy = null
	if _tut_marker != null and is_instance_valid(_tut_marker):
		_tut_marker.queue_free()
	_tut_marker = null
	Overload.reset()
	# 步骤全部完成：撤掉目标面板，让「训练完成」提示接管
	EventBus.tutorial_finished.emit()
	EventBus.toast.emit(Lang.t("tutorial_done"))
	_clear()


func tutorial_hint_text() -> String:
	if room_type != "tutorial" or _state != State.TUTORIAL:
		return ""
	if _tut_idx >= TUTORIAL_STEPS.size():
		return ""
	return "%s  ·  %s" % [Lang.t("tutorial_title"),
		Lang.f("tutorial_step_label", [_tut_idx + 1, TUTORIAL_STEPS.size()])]



# ---------------- 主循环 ----------------
func _process(delta: float) -> void:
	if not _built:
		return
	_room_time += delta
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var pressed := Input.is_key_pressed(KEY_E) and not _e_prev

	match _state:
		State.BUILD:
			if room_type == "repair":
				_state = State.CLEARED
				_unlock()
				EventBus.room_cleared.emit()
			elif p.global_position.x > 200.0:
				_lock()
		State.LOCKED:
			pass
		State.COMBAT:
			_tick_combat(delta)
		State.PUZZLE:
			_tick_puzzle(delta)
		State.TUTORIAL:
			_tick_tutorial(delta, p)
		State.CLEARED:
			_exit_tick(delta)
		State.TRANSITION:
			pass

	_tick_hazards(delta)
	_tick_interactions(p, pressed)
	_e_prev = Input.is_key_pressed(KEY_E)


func _tick_hazards(delta: float) -> void:
	for h in _hazards:
		var hd: Dictionary = h
		if str(hd["kind"]) == "coolant":
			if bool(hd["inside"]):
				Overload.vent(delta, true)
				Overload.add(-6.0 * delta)
		else:
			if bool(hd["inside"]):
				hd["cd"] = float(hd["cd"]) - delta
				if float(hd["cd"]) <= 0.0:
					hd["cd"] = 1.5
					var p := get_tree().get_first_node_in_group("player")
					if p != null and p.has_method("take_hit"):
						p.take_hit(8)


## 交互判定必须用**逻辑坐标**：投影载体的 global_position 已经是屏幕坐标了，
## 直接拿去和玩家比距离会整体偏 45°。IsoShim.logical 保存的就是逻辑坐标。
func _logical_of(n: Node) -> Vector2:
	if n is IsoShim:
		return (n as IsoShim).logical
	if n is Node2D:
		return (n as Node2D).global_position
	return Vector2.ZERO


func _tick_interactions(p: Node2D, pressed: bool) -> void:
	_prompt = {}

	# ---------------- 宝箱 ----------------
	# 同商店：latch 只在真正开箱那一刻置位，靠近本身不消耗边沿。
	if _chest != null and is_instance_valid(_chest):
		var near := _logical_of(_chest).distance_to(p.global_position) < CHEST_RADIUS
		if near:
			_prompt = {"id": "chest", "label": Lang.t("prompt_chest"), "node": _chest}
			if pressed and not _chest_near:
				_chest_near = true
				_open_chest()
				return
			return
		_chest_near = false

	# ---------------- 商店 ----------------
	# 与宝箱同构：范围内只允许一次购买，走开（离到 SHOP_RADIUS 外）才清零 latch。
	# 历史上这里踩过两个坑，都会表现为「买了东西不掉 / 按 E 没反应」：
	#   1) 用下标比较 `near_shop != _shop_near`：买掉 0 号后数组前移，原 1 号变成 0 号，
	#      被判成「没换目标」，玩家得走开再回来才能买第二件。
	#   2) 靠近那一帧就无条件 `_shop_near = true`：玩家走到商品前的瞬间边沿就被吃掉了，
	#      之后按 E 永远进不来。latch 必须只在**真正买下**那一刻置位。
	var near_shop := -1
	var best_shop_d := 1e20
	for i in _shop_items.size():
		var it: Dictionary = _shop_items[i]
		var n: Node2D = it["node"]
		if not is_instance_valid(n):
			continue
		var d := _logical_of(n).distance_to(p.global_position)
		if d < SHOP_RADIUS and d < best_shop_d:
			best_shop_d = d
			near_shop = i
	var near_any_shop := near_shop >= 0
	if near_any_shop:
		var sit: Dictionary = _shop_items[near_shop]
		_prompt = {
			"id": "shop",
			"label": Lang.f("prompt_shop", [int(sit["price"])]),
			"node": sit["node"],
		}
		# 只在「真的买下手」那一刻置位 latch；只是站在旁边不该消耗掉这一次边沿。
		# （曾经写成无条件 _shop_near = true，于是玩家走到商品前的那一帧就把边沿吃掉了，
		#   之后按 E 永远进不来 —— 这正是「买了不掉 / 按 E 没反应」的根因。）
		if pressed and not _shop_near:
			_shop_near = true
			_buy(near_shop)
			return
		return
	_shop_near = false

	# ---------------- 骇入终端 ----------------
	# 同宝箱/商店：latch 只在真正开始骇入那一刻置位，靠近本身不消耗边沿。
	if _terminal != null and is_instance_valid(_terminal):
		var near_t := _logical_of(_terminal).distance_to(p.global_position) < TERMINAL_RADIUS
		if near_t:
			_prompt = {"id": "terminal", "label": Lang.t("prompt_hack"), "node": _terminal}
			if pressed and not _terminal_near and not _hack_started:
				_terminal_near = true
				_start_hack()
				return
			return
		_terminal_near = false

	# ---------------- 故障节点 ----------------
	if room_type == "glitch" and _state == State.PUZZLE and not _glitch_done:
		_node_near = -1
		var best_nd := 1e20
		for nd in _nodes:
			var item: Dictionary = nd
			var n: Node2D = item["node"]
			if not is_instance_valid(n):
				continue
			var dn := _logical_of(n).distance_to(p.global_position)
			if dn < GLITCH_RADIUS and dn < best_nd:
				best_nd = dn
				_node_near = int(item["index"])
		if _node_near >= 0:
			_prompt = {
				"id": "glitch",
				"label": Lang.f("prompt_repair", [_seq_idx, _seq.size()]),
				"node": null,
			}
			if pressed:
				_try_repair(_node_near)
				return



func _tick_combat(delta: float) -> void:
	if room_type == "harvest":
		_harvest_t -= delta
		if _harvest_t <= 0.0:
			_clear_harvest()
			return
	if not _spawn_q.is_empty():
		_spawn_t -= delta
		if _spawn_t <= 0.0:
			var spec: Dictionary = _spawn_q.pop_front()
			_spawn_enemy(int(spec["kind"]), bool(spec["elite"]))
			_spawn_t = maxf(0.12, 0.34 - float(depth) * 0.02)
		return
	if get_tree().get_nodes_in_group("enemies").is_empty():
		if room_type == "harvest":
			_queue_harvest_wave()
			return
		_wave_idx += 1
		if _wave_idx < _waves.size():
			_start_wave()
		else:
			_clear()


func _tick_puzzle(delta: float) -> void:
	_glitch_t -= delta
	_flash_t -= delta
	if _flash_t <= 0.0:
		_flash_t = 1.5
	if _glitch_t <= 0.0:
		_glitch_timeout()


# ---------------- 锁定 / 开战 ----------------
func _lock() -> void:
	_state = State.LOCKED
	# 教学房不发 room_locked：它没有威胁，也不需要弹「房间已锁定」横幅
	if room_type == "tutorial":
		_start_tutorial()
		return
	EventBus.room_locked.emit()
	match room_type:
		"boss":
			_spawn_boss()
			return
		"glitch":
			_state = State.PUZZLE
			_glitch_t = GLITCH_TIME
			return
		"harvest":
			_state = State.COMBAT
			_queue_harvest_wave()
			return
		"shop", "lab", "hack":
			# 交互房：不刷怪，直接开放通行；玩家自由交互后从出口离开
			_state = State.CLEARED
			_unlock()
			EventBus.room_cleared.emit()
			return
		_:
			pass
	# 战斗波表：2 波，按深度与房型调整
	var base := 4 + biome + depth
	match room_type:
		"elite":
			base = 3 + biome + int(float(depth) * 0.8)
		"treasure":
			base = 4 + biome
		_:
			pass
	var total := maxi(2, int(round(float(base) * GameState.enemy_count_mult())))
	var w1 := int(ceil(float(total) * 0.6))
	var w2 := maxi(1, total - w1)
	_waves = [_composition(w1, room_type == "elite"), _composition(w2, false)]
	if room_type == "treasure":
		_waves = [[{"kind": 0, "elite": true}], [{"kind": 0, "elite": false}, {"kind": 2, "elite": false}]]
	elif room_type == "elite":
		# 精英房：全员精英
		_waves = [_composition(maxi(2, base - 1), true), _composition(maxi(2, 2), true)]
	_wave_idx = 0
	_start_wave()


func _composition(n: int, force_elite: bool) -> Array:
	var arr: Array = []
	var elite_chance := 0.08 + float(depth) * 0.03
	for _i in n:
		var k := EnemyDB.roll_kind(biome, depth)
		arr.append({"kind": k, "elite": force_elite or randf() < elite_chance})
	return arr


func _start_wave() -> void:
	if _wave_idx >= _waves.size():
		return
	_spawn_q = (_waves[_wave_idx] as Array).duplicate()
	_spawn_t = 0.4
	_state = State.COMBAT


func _spawn_enemy(kind: int, elite: bool) -> void:
	var e: Node = load("res://scripts/entities/Enemy.gd").new()
	add_child(e)
	var pos := Vector2(randf_range(300.0, 980.0), randf_range(120.0, 620.0))
	var p := get_tree().get_first_node_in_group("player")
	if p != null:
		for _i in 12:
			if pos.distance_to(p.global_position) > 260.0:
				break
			pos = Vector2(randf_range(300.0, 980.0), randf_range(120.0, 620.0))
	e.global_position = pos
	e.setup(kind, biome, elite)


func _spawn_boss() -> void:
	var script_path := "res://scripts/entities/bosses/CoolantTitan.gd"
	match biome:
		1:
			script_path = "res://scripts/entities/bosses/Gravekeeper.gd"
		2:
			script_path = "res://scripts/entities/bosses/CoreMind.gd"
	_boss = load(script_path).new()
	add_child(_boss)
	_boss.global_position = Vector2(880, 360)
	_state = State.COMBAT
	# 注意：boss_spawned 由 Boss 自身 _ready 发出（带真实名字与血量），此处不得重复发送


# ---------------- 清房 / 结算 ----------------
func _clear() -> void:
	_state = State.CLEARED
	_unlock()
	EventBus.room_cleared.emit()
	match room_type:
		"treasure":
			GameState.add_cells(3)
			_open_scroll_choice()
		"elite":
			GameState.add_gold(18 + biome * 6)
			GameState.add_cells(4)
			_open_reward("elite")
		"combat":
			GameState.add_gold(10 + biome * 5)
			GameState.add_energy(6)
			if randf() < 0.38 + Overload.drop_luck() + GameState.challenge_drop_bonus():
				EventBus.reward_choice_opened.emit(_roll_reward_options(3, 0))
			elif randf() < 0.22:
				_drop_loot("energy", "", 12)
		"boss":
			GameState.refill_flask()
		"glitch":
			_on_glitch_cleared()
		_:
			pass


func _unlock() -> void:
	for b in _blockers:
		if is_instance_valid(b):
			b.queue_free()
	_blockers.clear()
	IsoRoom.set_gate_open(_door_left, true)
	IsoRoom.set_gate_open(_door_right, true)
	EventBus.door_opened.emit()


func _exit_tick(delta: float) -> void:
	if _player_in_exit:
		_exit_t += delta
		if _exit_t >= 0.3:
			_state = State.TRANSITION
			RunDirector.complete_room()
	else:
		_exit_t = 0.0


# ---------------- 奖励 ----------------
func _roll_reward_options(count: int, bias: int) -> Array:
	var out: Array = []
	var pool_proto: Array = MetaState.unlocked_protocols()
	var pool_weapon: Array = MetaState.unlocked_weapons()
	var kinds := ["scroll", "protocol", "card", "weapon"]
	for i in count:
		var k := str(kinds[(i + bias) % kinds.size()])
		match k:
			"scroll":
				var kinds_s := ["firepower", "cooling", "structure", "energy"]
				out.append({"kind": "scroll", "id": str(kinds_s[randi() % kinds_s.size()])})
			"protocol":
				out.append({"kind": "protocol", "id": ProtocolDB.random_from(pool_proto, GameState.protocols)})
			"card":
				var have: Array = []
				for c in GameState.cards:
					have.append(str((c as Dictionary)["id"]))
				out.append({"kind": "card", "id": CardDB.random_id(have)})
			_:
				out.append({"kind": "weapon", "id": WeaponDB.random_from(pool_weapon, GameState.weapons)})
	return out


func _open_scroll_choice() -> void:
	EventBus.scroll_choice_opened.emit(["firepower", "cooling", "structure"])


func _open_reward(bias_kind: String) -> void:
	var bias := 0
	match bias_kind:
		"elite":
			bias = 1
		_:
			bias = 0
	EventBus.reward_choice_opened.emit(_roll_reward_options(3, bias))


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
	_open_scroll_choice()
	EventBus.toast.emit(Lang.t("chest_opened"))
	_waves = [[]]
	var back: Array = []
	for _i in 6:
		back.append({"kind": EnemyDB.roll_kind(biome, depth), "elite": true})
	_waves = [back]
	_wave_idx = 0
	_state = State.COMBAT
	_start_wave()


func _buy(idx: int) -> void:
	if idx < 0 or idx >= _shop_items.size():
		return
	var it: Dictionary = _shop_items[idx]
	var price: int = int(it["price"])
	if not GameState.spend_gold(price):
		EventBus.toast.emit(Lang.t("shop_poor"))
		return
	var pool_weapon: Array = MetaState.unlocked_weapons()
	match str(it["offer"]):
		"weapon":
			var wid := WeaponDB.random_from(pool_weapon, GameState.weapons)
			GameState.equip_weapon(wid)
			EventBus.toast.emit("%s: %s" % [Lang.t("weapon_gained"), Lang.t("w_" + wid)])
		"heal":
			GameState.heal(40)
		"protocol":
			var pid := ProtocolDB.random_from(MetaState.unlocked_protocols(), GameState.protocols)
			GameState.add_protocol(pid)
			EventBus.toast.emit("%s %s" % [Lang.t("proto_gained"), Lang.t("proto_" + pid)])
		"card":
			var cid := CardDB.random_id()
			GameState.add_card(cid)
			EventBus.toast.emit("%s %s" % [Lang.t("picked_prefix"), Lang.t("card_" + cid)])
		"energy":
			GameState.add_energy(40)
			EventBus.toast.emit(Lang.f("energy_gain", [40]))
	EventBus.toast.emit(Lang.t("shop_bought"))
	var n: Node2D = it["node"]
	n.queue_free()
	_shop_items.remove_at(idx)


# ---------------- 故障房 ----------------
func _try_repair(index: int) -> void:
	if _seq_idx >= _seq.size():
		return
	if int(_seq[_seq_idx]) != index:
		EventBus.toast.emit(Lang.t("glitch_fail"))
		_seq = _roll_sequence()
		_seq_idx = 0
		GameState.damage_core(6)
		_spawn_enemy(EnemyDB.glitch_kind(), false)
		_glitch_t = maxf(6.0, _glitch_t)
		_refresh_node_visuals()
		return
	_seq_idx += 1
	_refresh_node_visuals()
	EventBus.toast.emit(Lang.f("glitch_progress", [_seq_idx, _seq.size()]))
	if _seq_idx >= _seq.size():
		_glitch_done = true
		EventBus.toast.emit(Lang.t("glitch_success"))
		_clear()


func _refresh_node_visuals() -> void:
	for nd in _nodes:
		var item: Dictionary = nd
		var idx := int(item["index"])
		var fixed := false
		for i in _seq_idx:
			if int(_seq[i]) == idx:
				fixed = true
		var is_next := _seq_idx < _seq.size() and int(_seq[_seq_idx]) == idx
		var spr: Sprite2D = item["spr"]
		var glow: Sprite2D = item["glow"]
		if fixed:
			spr.texture = PixelArt.pipe_node_tex(2)
			glow.visible = false
		elif is_next:
			spr.texture = PixelArt.pipe_node_tex(1)
			glow.visible = true
		else:
			spr.texture = PixelArt.pipe_node_tex(0)
			glow.visible = false


func _glitch_timeout() -> void:
	EventBus.toast.emit(Lang.t("glitch_timeout"))
	_state = State.COMBAT
	_waves = [_composition(4 + depth, false), _composition(3, false)]
	_wave_idx = 0
	_start_wave()


func _on_glitch_cleared() -> void:
	GameState.add_energy(45)
	GameState.add_cells(4)
	GameState.add_gold(15)
	for nd in _nodes:
		var item: Dictionary = nd
		(item["glow"] as Sprite2D).visible = false
	EventBus.reward_choice_opened.emit(_roll_reward_options(2, 2))


# ---------------- 收割房 ----------------
func _queue_harvest_wave() -> void:
	var n := 5 + depth
	var arr: Array = []
	for _i in n:
		arr.append({"kind": EnemyDB.roll_kind(biome, depth), "elite": randf() < 0.10})
	_spawn_q = arr
	_spawn_t = 0.3
	_state = State.COMBAT


func _clear_harvest() -> void:
	_state = State.CLEARED
	_unlock()
	EventBus.room_cleared.emit()
	_harvest_kills = maxi(0, GameState.kills - _harvest_start_kills)
	var ratio := clampf(float(_harvest_kills) / float(maxi(1, _harvest_target)), 0.0, 3.0)
	var gold_r := int(round(60.0 * ratio))
	var cell_r := int(round(6.0 * ratio))
	GameState.add_gold(gold_r)
	GameState.add_cells(cell_r)
	EventBus.toast.emit(Lang.t("harvest_success"))
	EventBus.reward_choice_opened.emit(_roll_reward_options(2, 1))


# ---------------- 骇入房 ----------------
func _start_hack() -> void:
	_hack_started = true
	_state = State.PUZZLE
	EventBus.hack_requested.emit()


func on_hack_finished(_success: bool, _score: int, reward: int) -> void:
	if reward > 0:
		MetaState.add_source(reward)
		EventBus.toast.emit(Lang.f("hack_reward", [reward]))
	if _terminal != null and is_instance_valid(_terminal):
		for c in _terminal.get_children():
			if c is Sprite2D:
				(c as Sprite2D).modulate = Color(0.40, 0.40, 0.40)
	_state = State.CLEARED
	_unlock()
	EventBus.room_cleared.emit()


func is_puzzle() -> bool:
	return _state == State.PUZZLE


func glitch_hint_text() -> String:
	if room_type != "glitch" or _glitch_done:
		return ""
	return "%s  %s  ·  %ds" % [Lang.t("glitch_title"),
		Lang.f("glitch_progress", [_seq_idx, _seq.size()]), int(maxf(0.0, _glitch_t))]


func harvest_hint_text() -> String:
	if room_type != "harvest" or _state != State.COMBAT:
		return ""
	return Lang.f("harvest_progress", [int(maxf(0.0, _harvest_t)), GameState.kills])
