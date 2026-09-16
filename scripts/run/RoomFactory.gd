class_name RoomFactory
## RoomFactory —— 程序化生成单间房：地板 / 边界墙 / 门 / 障碍柱。
## 全部程序化，无外部素材；返回门与障碍节点供 RoomManager 控制。

const W := 1280
const H := 720
const WALL := 26
const PLAY_TOP := 64
const DOOR_W := 90
const PILLAR := 48

## 生成房间静态视觉与碰撞体。返回 {floor, blockers:Array, door_left, door_right}
static func build(parent: Node2D, biome: int) -> Dictionary:
	# 地板
	var floor_tex := PixelArt.biome_floor_tex(biome, W, H)
	var floor_sprite := Sprite2D.new()
	floor_sprite.texture = floor_tex
	floor_sprite.centered = false
	floor_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	floor_sprite.z_index = -10
	parent.add_child(floor_sprite)

	# 顶栏背景（HUD 区域）
	var top_bg := ColorRect.new()
	top_bg.color = Color(0.03, 0.04, 0.05, 0.86)
	top_bg.position = Vector2(0, 0)
	top_bg.size = Vector2(W, PLAY_TOP)
	top_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(top_bg)

	# 四面静态墙（solid）
	_add_wall(parent, 0, PLAY_TOP, WALL, H - PLAY_TOP)
	_add_wall(parent, W - WALL, PLAY_TOP, WALL, H - PLAY_TOP)
	_add_wall(parent, 0, PLAY_TOP, (W - DOOR_W) / 2, WALL)                       # 上墙左段
	_add_wall(parent, W - (W - DOOR_W) / 2, PLAY_TOP, (W - DOOR_W) / 2, WALL)    # 上墙右段
	_add_wall(parent, 0, H - WALL, W, WALL)
	# 左右墙中间留出门口
	var side_h := (H - PLAY_TOP - WALL - DOOR_W) / 2
	_add_wall(parent, 0, PLAY_TOP + WALL, WALL, side_h)
	_add_wall(parent, 0, H - WALL - side_h, WALL, side_h)
	_add_wall(parent, W - WALL, PLAY_TOP + WALL, WALL, side_h)
	_add_wall(parent, W - WALL, H - WALL - side_h, WALL, side_h)

	# 门（视觉 + 可开合的阻挡体）
	var door_y := (PLAY_TOP + WALL + H - WALL) / 2 - DOOR_W / 2 + 10
	var door_left := _add_door(parent, WALL, door_y, DOOR_W, DOOR_W, true)
	var door_right := _add_door(parent, W - WALL - DOOR_W, door_y, DOOR_W, DOOR_W, true)

	var blockers: Array = []
	var left_block := _add_blocker(parent, WALL, door_y, DOOR_W, DOOR_W)
	var right_block := _add_blocker(parent, W - WALL - DOOR_W, door_y, DOOR_W, DOOR_W)
	blockers.append(left_block)
	blockers.append(right_block)

	return {
		"floor": floor_sprite,
		"door_left": door_left,
		"door_right": door_right,
		"blockers": blockers,
	}


static func _add_wall(parent: Node2D, x: float, y: float, w: float, h: float) -> StaticBody2D:
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

	var tex := PixelArt.wall_tex(GameState.biome_index)
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(w / 32.0, h / 32.0)
	spr.z_index = -5
	body.add_child(spr)
	parent.add_child(body)
	return body


static func _add_door(parent: Node2D, x: float, y: float, w: float, h: float, locked: bool) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = PixelArt.door_tex(locked)
	spr.centered = false
	spr.position = Vector2(x, y)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(w / 40.0, h / 40.0)
	spr.z_index = -4
	parent.add_child(spr)
	return spr


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


## 生成障碍柱（3-7 根），避开出生点与门口区域
static func add_pillars(parent: Node2D, biome: int, count: int) -> Array:
	var made: Array = []
	var tries := 0
	while made.size() < count and tries < 60:
		tries += 1
		var px := randf_range(220.0, W - 220.0)
		var py := randf_range(PLAY_TOP + 90.0, H - 120.0)
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
		var spr := Sprite2D.new()
		spr.texture = PixelArt.pillar_tex(biome)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.z_index = -3
		body.add_child(spr)
		parent.add_child(body)
		made.append(body)
	return made
