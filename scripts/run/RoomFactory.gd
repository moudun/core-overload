class_name RoomFactory
## RoomFactory —— V1.3 程序化生成单间房。
##
## 拆成两半，各管各的：
##   * **逻辑碰撞体**：仍然是原来的 1:1 俯视矩形（layer=8），速度 / 手感 / AI 全不变；
##   * **可见几何**：交给 IsoRoom 按 2:1 等距画（地板 / 远墙 / 近沿 / 门口闸板 / 障碍柱）。
## 两者共用同一组坐标常量，所以「看起来在哪」和「实际挡在哪」永远对得上。

const W := 1280
const H := 720
const WALL := 26
const PLAY_TOP := 64
const DOOR_W := 90
const PILLAR := 48

## 远边（屏幕上方那两条边）起高墙做背景；近边只留矮沿，否则会把场内挡死。
const FAR_WALL_H := 78.0
const NEAR_WALL_H := 18.0
## 门口闸板高度：远门可以高（它天然在角色之后），近门必须矮（否则会盖住站在出口的玩家）
const GATE_H_FAR := 54.0
const GATE_H_NEAR := 20.0
## 障碍柱的屏幕高度。刻意压到角色身高以下：等距里遮挡是双向的，
## 柱子太高会频繁把主角挡掉，反而看不清自己站在哪。
const PILLAR_H := 38.0


## 生成房间静态几何。返回 {view, floor, blockers, door_left, door_right}
static func build(parent: Node2D, biome: int) -> Dictionary:
	# ---------------- 可见几何容器（等距）----------------
	var view := Node2D.new()
	view.name = "IsoView"
	parent.add_child(view)
	IsoRoom.backdrop(view)
	var floor_spr := IsoRoom.floor(view, biome)

	# ---------------- 逻辑碰撞（一行不改）----------------
	_add_wall(parent, biome, 0, PLAY_TOP, WALL, H - PLAY_TOP)
	_add_wall(parent, biome, W - WALL, PLAY_TOP, WALL, H - PLAY_TOP)
	_add_wall(parent, biome, 0, PLAY_TOP, (W - DOOR_W) / 2, WALL)
	_add_wall(parent, biome, W - (W - DOOR_W) / 2, PLAY_TOP, (W - DOOR_W) / 2, WALL)
	# 顶边中段原来是空的（玩家能从缺口走出去），这里补上
	_add_wall(parent, biome, (W - DOOR_W) / 2, PLAY_TOP, DOOR_W, WALL)
	_add_wall(parent, biome, 0, H - WALL, W, WALL)
	var side_h := (H - PLAY_TOP - WALL - DOOR_W) / 2
	_add_wall(parent, biome, 0, PLAY_TOP + WALL, WALL, side_h)
	_add_wall(parent, biome, 0, H - WALL - side_h, WALL, side_h)
	_add_wall(parent, biome, W - WALL, PLAY_TOP + WALL, WALL, side_h)
	_add_wall(parent, biome, W - WALL, H - WALL - side_h, WALL, side_h)

	var door_y := (PLAY_TOP + WALL + H - WALL) / 2 - DOOR_W / 2 + 10
	var blockers: Array = []
	blockers.append(_add_blocker(parent, WALL, door_y, DOOR_W, DOOR_W))
	blockers.append(_add_blocker(parent, W - WALL - DOOR_W, door_y, DOOR_W, DOOR_W))

	# ---------------- 可见几何（等距）----------------
	var top_a := Vector2(0.0, float(PLAY_TOP))
	var top_b := Vector2(float(W), float(PLAY_TOP))
	var bot_a := Vector2(0.0, float(H))
	var bot_b := Vector2(float(W), float(H))
	var d_a := Vector2(0.0, float(door_y))
	var d_b := Vector2(0.0, float(door_y + DOOR_W))
	var e_a := Vector2(float(W), float(door_y))
	var e_b := Vector2(float(W), float(door_y + DOOR_W))

	# 远边：顶边整条（顶边中段的碰撞缺口已经在上面补掉了，所以整条直接连着画）
	IsoRoom.wall(view, biome, top_a, top_b, FAR_WALL_H, 0, true)
	# 远边：左墙（中间留门洞）
	IsoRoom.wall(view, biome, top_a, d_a, FAR_WALL_H, 0, true)
	IsoRoom.wall(view, biome, d_b, bot_a, FAR_WALL_H, 0, true)
	# 近边：右墙（中间留门洞）+ 底边，都只留矮沿
	IsoRoom.wall(view, biome, top_b, e_a, NEAR_WALL_H, 0, true)
	IsoRoom.wall(view, biome, e_b, bot_b, NEAR_WALL_H, 0, true)
	IsoRoom.wall(view, biome, bot_a, bot_b, NEAR_WALL_H, 0, true)

	# 门口闸板：左门在远边（可高），右门在近边（必须矮）
	var gate_l := IsoRoom.gate(view, biome, d_a, d_b, GATE_H_FAR, true)
	var gate_r := IsoRoom.gate(view, biome, e_a, e_b, GATE_H_NEAR, true)

	return {
		"view": view,
		"floor": floor_spr,
		"door_left": gate_l,
		"door_right": gate_r,
		"blockers": blockers,
	}


## 纯碰撞墙：不再挂任何可见贴图，可见墙体由 IsoRoom 统一画
static func _add_wall(parent: Node2D, _biome: int, x: float, y: float, w: float, h: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 8
	body.collision_mask = 0
	body.add_to_group("solid")
	body.position = Vector2(x, y)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	shape.position = Vector2(w / 2.0, h / 2.0)
	shape.shape = rect
	body.add_child(shape)
	parent.add_child(body)
	return body


## 纯碰撞阻挡体（锁门）
static func _add_blocker(parent: Node2D, x: float, y: float, w: float, h: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 8
	body.collision_mask = 0
	body.add_to_group("solid")
	body.position = Vector2(x, y)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, h)
	shape.position = Vector2(w / 2.0, h / 2.0)
	shape.shape = rect
	body.add_child(shape)
	parent.add_child(body)
	return body


## 生成障碍柱（3-7 根），避开出生点与门口区域。
## 碰撞是逻辑 48×48 的方块，可见部分是等距棱柱 —— 两者同一中心点。
static func add_pillars(parent: Node2D, biome: int, count: int, view: Node2D = null) -> Array:
	var made: Array = []
	var tries := 0
	while made.size() < count and tries < 60:
		tries += 1
		var px := randf_range(240.0, W - 240.0)
		var py := randf_range(PLAY_TOP + 100.0, H - 130.0)
		var pos := Vector2(px, py)
		var ok := true
		for m in made:
			if (m as Node2D).global_position.distance_to(pos) < 150.0:
				ok = false
				break
		if not ok:
			continue
		# 避开水平中路：出生点(y=380) → 出口(y=380) 的直线走廊必须畅通
		if absf(py - 380.0) < 96.0:
			continue
		var body := StaticBody2D.new()
		body.collision_layer = 8
		body.collision_mask = 0
		body.add_to_group("solid")
		body.global_position = pos
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(PILLAR, PILLAR)
		shape.shape = rect
		body.add_child(shape)
		parent.add_child(body)
		if view != null and is_instance_valid(view):
			IsoRoom.block(view, biome, pos, float(PILLAR), PILLAR_H)
		made.append(body)
	return made
