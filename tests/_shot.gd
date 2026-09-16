extends Node
## _shot.gd —— 临时截图探针（仅用于产出验收截图，跑完即从 project.godot 移除）。
## 产出：美术图鉴 / 等距预览 / 角色设定图 + 关键界面 6 张，落盘到 res://output/system-overload-ui/。

const OUT_DIR := "res://output/system-overload-ui"

# autoload 解析得比全局类表更早，这里显式 preload，避免 "Identifier not declared"
const ISO := preload("res://scripts/util/Iso.gd")
const ISOROOM := preload("res://scripts/run/IsoRoom.gd")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	print("SHOT_DIR=", ProjectSettings.globalize_path(OUT_DIR))
	await get_tree().process_frame
	await _frames(50)
	await _shot("01_main_menu")
	await _art_sheet()
	await _iso_preview()
	await _actor_sheet()
	await _actor_walk()
	await _actor_idle()
	await _enemy_sheet()
	await _intro_comic()
	await _scene_tutorial()
	await _scene_combat()
	await _scene_danger()
	await _scene_boss()
	await _scene_end()
	print("SHOT_DONE")
	get_tree().quit()


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


## 按**真实时间**等待。窗口模式下的帧率是不确定的（实测能跑到 400+ fps），
## 用 _frames() 等「刷怪 / 走位」这种要按秒算的东西会完全不准。
func _seconds(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + "/" + shot_name + ".png"))
	print("SHOT=", shot_name)


## ---------------- 输入模拟（用于拍出「真的在打」的画面）----------------
func _press(key: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = key
	down.physical_keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	var up := InputEventKey.new()
	up.keycode = key
	up.physical_keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _hold_key(key: Key, on: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = key
	ev.physical_keycode = key
	ev.pressed = on
	Input.parse_input_event(ev)


func _hold_fire(on: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = on
	ev.position = AIM_SCREEN
	Input.parse_input_event(ev)


## 屏幕上的瞄准点。等距下「画面向右飞」对应的逻辑方向是右上，所以选这个点最直观。
const AIM_SCREEN := Vector2(1010, 300)


func _route_map() -> Node:
	return get_tree().root.find_child("RouteMap", true, false)


## 开局必弹路线图：优先选 2 号（通常是「战斗房」），再退回 1 / 3 直到关掉
func _dismiss_route_map() -> void:
	for k in [KEY_2, KEY_1, KEY_3]:
		for _i in 3:
			var rm := _route_map()
			if rm == null or not rm.visible:
				return
			await _press(k)
			await _seconds(0.25)


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _cell(caption: String, tex: Texture2D, px: int) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(_label(caption, 15, Color(0.86, 0.94, 0.90)))
	var holder := Panel.new()
	holder.custom_minimum_size = Vector2(px + 30, px + 30)
	holder.add_theme_stylebox_override("panel", UITheme.panel(UITheme.CYAN, 8.0))
	v.add_child(holder)
	var t := TextureRect.new()
	t.texture = tex
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(t)
	return v


func _icon_cell(caption: String, kind: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var holder := Panel.new()
	holder.custom_minimum_size = Vector2(64, 64)
	holder.add_theme_stylebox_override("panel", UITheme.panel(UITheme.PURPLE, 6.0))
	v.add_child(holder)
	var t := TextureRect.new()
	t.texture = PixelArt.icon_tex(kind, 16, Color(0.90, 0.98, 0.95))
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(t)
	var l := _label(caption, 13, Color(0.62, 0.70, 0.72))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return v


## 等距（2:1 斜 45°）预览：地板 / 墙体 / 方块 + 8 向程序化驾驶员
func _iso_preview() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var world := Node2D.new()
	layer.add_child(world)

	ISOROOM.backdrop(world)
	ISOROOM.floor(world, 0)

	var vw := ISO.VIEW_W
	var vh := ISO.VIEW_H
	# 远侧两条边起高墙，近侧两条边只留矮沿，避免挡住场内
	ISOROOM.wall(world, 0, Vector2(0, 0), Vector2(vw, 0), 72.0, -90)
	ISOROOM.wall(world, 0, Vector2(0, 0), Vector2(0, vh), 72.0, -93)
	ISOROOM.wall(world, 0, Vector2(vw, 0), Vector2(vw, vh), 18.0, 30)
	ISOROOM.wall(world, 0, Vector2(0, vh), Vector2(vw, vh), 18.0, 33)

	ISOROOM.block(world, 0, Vector2(360, 280), 104, 58)
	ISOROOM.block(world, 0, Vector2(930, 470), 104, 58)
	ISOROOM.block(world, 0, Vector2(1000, 220), 68, 42)

	# 场内放 3 个驾驶员（×2 放大以便看清落位与遮挡）
	var place: Array = [Vector2(470, 372), Vector2(880, 300), Vector2(660, 560)]
	var face: Array = [2, 6, 1]
	for i in 3:
		var p: Vector2 = place[i]
		_shadow(world, p)
		var s := Sprite2D.new()
		s.texture = PixelArt.actor_tex(face[i])
		s.position = ISO.to_screen(p)
		s.position -= Vector2(0.0, (PixelArt.ACTOR_FOOT - PixelArt.ACTOR_H * 0.5) * 2.4)
		s.scale = Vector2(2.4, 2.4)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.z_index = ISO.z_of(p)
		world.add_child(s)

	# HUD 层：标题与图鉴必须压在场内几何之上，否则被近侧矮墙切掉
	var hud := CanvasLayer.new()
	hud.layer = 101
	add_child(hud)

	# 顶部标题
	var title := Panel.new()
	title.add_theme_stylebox_override("panel", UITheme.panel(UITheme.CYAN, 12.0))
	title.position = Vector2(56, 74)
	title.size = Vector2(560, 40)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(title)
	title.add_child(_at(_label("等距 2:1 预览 · 逻辑坐标不变，只换画法", 15,
		Color(0.55, 0.92, 0.86)), Vector2(16, 9)))

	# 8 向图鉴
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel(UITheme.CYAN, 14.0))
	panel.position = Vector2(56, 518)
	panel.size = Vector2(1168, 188)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(panel)
	panel.add_child(_at(_label("8 向「核心机体」驾驶员 · 程序化生成（×2.8 放大）", 14,
		Color(0.52, 0.88, 0.82)), Vector2(20, 10)))

	var names := ["右 E", "右下 SE", "下 S", "左下 SW", "左 W", "左上 NW", "上 N", "右上 NE"]
	for i in 8:
		var x := 150.0 + float(i) * 140.0
		var s := Sprite2D.new()
		s.texture = PixelArt.actor_tex(i)
		s.position = Vector2(x, 680)
		s.position -= Vector2(0.0, (PixelArt.ACTOR_FOOT - PixelArt.ACTOR_H * 0.5) * 2.8)
		s.scale = Vector2(2.8, 2.8)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hud.add_child(s)
		var l := _label(names[i], 12, Color(0.66, 0.76, 0.78))
		l.position = Vector2(x - 34.0, 684)
		l.size = Vector2(68, 16)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hud.add_child(l)

	await _frames(14)
	await _shot("07_iso_preview")
	layer.queue_free()
	hud.queue_free()
	await _frames(4)


func _at(c: Control, pos: Vector2) -> Control:
	c.position = pos
	return c


func _shadow(parent: Node2D, logical: Vector2) -> void:
	var s := 17.0
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([
		ISO.to_screen(logical + Vector2(-s, -s)),
		ISO.to_screen(logical + Vector2(s, -s)),
		ISO.to_screen(logical + Vector2(s, s)),
		ISO.to_screen(logical + Vector2(-s, s)),
	])
	p.color = Color(0.0, 0.0, 0.0, 0.34)
	p.antialiased = false
	p.z_index = ISO.z_of(logical) - 2
	parent.add_child(p)


func _art_sheet() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.078, 0.105)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 46)
	margin.add_theme_constant_override("margin_right", 46)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 30)
	layer.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)
	col.add_child(_label("CORE OVERLOAD V1.3   程序化美术 / 界面图鉴", 27, Color(0.42, 0.95, 0.84)))
	col.add_child(_label("全部贴图由 PixelArt.gd 逐像素生成，零外部素材；玩家已由「圆球」重做为装甲机体（八边形装甲舱体 + 四角梯形推进器喷口 + 反应堆核心）",
		14, Color(0.55, 0.78, 1.0)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 44)
	col.add_child(row)
	row.add_child(_cell("玩家机体  ×7", PixelArt.player_core_tex(), 240))
	row.add_child(_cell("反应堆光晕  ×3", PixelArt.radial_glow_tex(64, Color(0.30, 0.95, 0.85), 2.6), 176))
	row.add_child(_cell("推进器尾焰  ×7", PixelArt.thruster_tex(Color(0.88, 1.0, 0.98), Color(0.22, 0.72, 1.0)), 154))

	var irow := HBoxContainer.new()
	irow.add_theme_constant_override("separation", 20)
	col.add_child(irow)
	var icons := [["HP", "hp"], ["过载", "bolt"], ["翻滚", "roll"], ["技能", "skill"],
		["金币", "coin"], ["细胞", "cell"], ["能量", "energy"], ["源代码", "source"], ["深度", "depth"]]
	for e in icons:
		irow.add_child(_icon_cell(str(e[0]), str(e[1])))

	await _frames(14)
	await _shot("00_art_sheet")
	layer.queue_free()
	await _frames(4)


## 八向角色设定图（×5）—— 专门给「人物建模」验收看的一张大图
func _actor_sheet() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color(0.043, 0.062, 0.086)
	bg.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 0)
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)

	layer.add_child(_at(_label("核心机体 · 驾驶员设定图", 26, Color(0.62, 0.94, 0.90)), Vector2(48, 26)))
	layer.add_child(_at(_label(
		"程序化生成 · 32×44 px · 八向查表（非插值） · 逻辑坐标不变，仅换画法",
		14, Color(0.44, 0.62, 0.66)), Vector2(50, 60)))

	var names := ["右 E", "右下 SE", "下 S", "左下 SW", "左 W", "左上 NW", "上 N", "右上 NE"]
	var sc := 5.0
	var cw := 300.0
	var ox := 40.0
	var oy := 96.0
	for i in 8:
		var col := i % 4
		var row := i / 4
		var cell := Vector2(ox + float(col) * cw, oy + float(row) * 300.0)
		# 地面基线 + 落影，确认「脚踩在地上」
		var shadow := Polygon2D.new()
		shadow.polygon = PackedVector2Array([
			Vector2(cell.x + 128.0, cell.y + 268.0),
			Vector2(cell.x + 172.0, cell.y + 268.0),
			Vector2(cell.x + 150.0, cell.y + 282.0),
			Vector2(cell.x + 106.0, cell.y + 282.0)])
		shadow.color = Color(0.0, 0.0, 0.0, 0.35)
		shadow.antialiased = false
		layer.add_child(shadow)
		var base := Line2D.new()
		base.points = PackedVector2Array([
			Vector2(cell.x + 60.0, cell.y + 268.0),
			Vector2(cell.x + 240.0, cell.y + 268.0)])
		base.width = 1.0
		base.default_color = Color(0.16, 0.34, 0.38)
		layer.add_child(base)

		var s := Sprite2D.new()
		s.texture = PixelArt.actor_tex(i)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(sc, sc)
		s.position = Vector2(cell.x + 150.0, cell.y + 268.0)             - Vector2(0.0, (PixelArt.ACTOR_FOOT - PixelArt.ACTOR_H * 0.5) * sc)
		layer.add_child(s)

		var l := _label("%s   dir=%d" % [names[i], i], 15, Color(0.70, 0.86, 0.86))
		l.position = Vector2(cell.x + 90.0, cell.y + 288.0)
		l.size = Vector2(120, 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		layer.add_child(l)

	await _frames(14)
	await _shot("08_actor_sheet")
	layer.queue_free()
	await _frames(4)


## 主角动作演示：4 个代表方向 × 6 帧行走循环（×3），验证「能做出丰富动作」
func _actor_walk() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color(0.043, 0.062, 0.086)
	bg.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 0)
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)

	layer.add_child(_at(_label("核心机体 · 行走循环", 24, Color(0.62, 0.94, 0.90)), Vector2(48, 20)))
	layer.add_child(_at(_label(
		"6 帧 / 方向 · 双腿剪刀 + 双臂反相摆动 + 躯干起伏 + 抬脚离地 · 全部由代码按角度调制",
		13, Color(0.44, 0.62, 0.66)), Vector2(50, 50)))

	var dirs := [0, 2, 4, 6]
	var names := ["右 E", "下 S", "左 W", "上 N"]
	var sc := 3.0
	var gx := 150.0
	var pitch := 185.0
	for r in 4:
		var rowy := 96.0 + float(r) * 155.0
		layer.add_child(_at(_label(names[r], 14, Color(0.70, 0.86, 0.86)), Vector2(48, rowy + 52)))
		for f in PixelArt.ACTOR_WALK:
			var x := gx + float(f) * pitch + pitch * 0.5
			var base := rowy + 120.0
			var sh := Polygon2D.new()
			sh.polygon = PackedVector2Array([
				Vector2(x - 22.0, base - 5.0), Vector2(x + 22.0, base - 5.0),
				Vector2(x + 14.0, base + 3.0), Vector2(x - 14.0, base + 3.0)])
			sh.color = Color(0.0, 0.0, 0.0, 0.32)
			sh.antialiased = false
			layer.add_child(sh)
			var sp := Sprite2D.new()
			sp.texture = PixelArt.actor_tex(dirs[r], f)
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sp.scale = Vector2(sc, sc)
			sp.position = Vector2(x, base) \
				- Vector2(0.0, (PixelArt.ACTOR_FOOT - PixelArt.ACTOR_H * 0.5) * sc)
			layer.add_child(sp)
			if r == 0:
				var l := _label("帧 %d" % f, 12, Color(0.48, 0.66, 0.72))
				l.position = Vector2(x - 30.0, base + 10.0)
				l.size = Vector2(60, 16)
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				layer.add_child(l)

	await _frames(14)
	await _shot("09_actor_walk")
	layer.queue_free()
	await _frames(4)


## 待机循环：8 帧呼吸 + 重心微摆，验证「站着也不是死图」
func _actor_idle() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color(0.043, 0.062, 0.086)
	bg.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 0)
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)

	layer.add_child(_at(_label("核心机体 · 待机循环", 24, Color(0.62, 0.94, 0.90)), Vector2(48, 20)))
	layer.add_child(_at(_label(
		"8 帧 · 呼吸起伏 + 重心左右微摆 + 手臂轻摆（原地站立时自动播放，与行走共用同一套帧缓存）",
		13, Color(0.44, 0.62, 0.66)), Vector2(50, 50)))

	var dirs := [0, 2, 4, 6]
	var names := ["右 E", "下 S", "左 W", "上 N"]
	var sc := 3.0
	var pitch := 150.0
	for r in 4:
		var rowy := 92.0 + float(r) * 155.0
		layer.add_child(_at(_label(names[r], 14, Color(0.70, 0.86, 0.86)), Vector2(24, rowy + 52)))
		for f in PixelArt.ACTOR_IDLE:
			var x := 210.0 + float(f) * pitch
			var base := rowy + 120.0
			var sh := Polygon2D.new()
			sh.polygon = PackedVector2Array([
				Vector2(x - 22.0, base - 5.0), Vector2(x + 22.0, base - 5.0),
				Vector2(x + 14.0, base + 3.0), Vector2(x - 14.0, base + 3.0)])
			sh.color = Color(0.0, 0.0, 0.0, 0.32)
			sh.antialiased = false
			layer.add_child(sh)
			var sp := Sprite2D.new()
			sp.texture = PixelArt.actor_tex(dirs[r], PixelArt.ACTOR_IDLE_BASE + f)
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sp.scale = Vector2(sc, sc)
			sp.position = Vector2(x, base) \
				- Vector2(0.0, (PixelArt.ACTOR_FOOT - PixelArt.ACTOR_H * 0.5) * sc)
			layer.add_child(sp)
			if r == 0:
				var l := _label("i%d" % f, 12, Color(0.48, 0.66, 0.72))
				l.position = Vector2(x - 30.0, base + 10.0)
				l.size = Vector2(60, 16)
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				layer.add_child(l)

	await _frames(14)
	await _shot("10_actor_idle")
	layer.queue_free()
	await _frames(4)


## 敌人图鉴：5 种专属外形（不再是方块）
func _enemy_sheet() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color(0.043, 0.062, 0.086)
	bg.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 0)
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)

	layer.add_child(_at(_label("敌对单位 · 造型图鉴", 26, Color(1.00, 0.62, 0.52)), Vector2(48, 26)))
	layer.add_child(_at(_label(
		"程序化生成 · 40×40 px · 5 种专属剪影（悬浮核心 / 重甲 / 疾行者 / 三足炮台 / 故障体）",
		14, Color(0.66, 0.50, 0.48)), Vector2(50, 60)))

	var names := ["0 悬浮核心 DRONE", "1 重甲 BRUTE", "2 疾行者 RUNNER",
		"3 三足炮台 SPITTER", "4 故障体 GLITCH"]
	var tint := [
		Color(0.55, 0.85, 1.00), Color(1.00, 0.72, 0.45), Color(0.62, 1.00, 0.62),
		Color(0.85, 0.68, 1.00), Color(1.00, 0.48, 0.72)]
	var sc := 5.0
	for i in 5:
		var cx := 130.0 + float(i) * 250.0
		var cy := 300.0
		# 落影，确认脚踩地
		var sh := Polygon2D.new()
		sh.polygon = PackedVector2Array([
			Vector2(cx - 46.0, cy + 62.0), Vector2(cx + 46.0, cy + 62.0),
			Vector2(cx + 30.0, cy + 84.0), Vector2(cx - 30.0, cy + 84.0)])
		sh.color = Color(0.0, 0.0, 0.0, 0.34)
		sh.antialiased = false
		layer.add_child(sh)

		var sp := Sprite2D.new()
		sp.texture = PixelArt.enemy_tex(i)
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.scale = Vector2(sc, sc)
		sp.position = Vector2(cx, cy)
		layer.add_child(sp)

		# 名称牌
		var plate := ColorRect.new()
		plate.color = Color(tint[i].r, tint[i].g, tint[i].b, 0.14)
		plate.position = Vector2(cx - 108.0, cy + 112.0)
		plate.size = Vector2(216, 30)
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(plate)

		var l := _label(names[i], 15, tint[i])
		l.position = Vector2(cx - 108.0, cy + 117.0)
		l.size = Vector2(216, 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		layer.add_child(l)

	# 底部说明
	layer.add_child(_at(_label(
		"每种都有自己的轮廓剪影与独立配色 —— 不再共用同一个方块；外形差异也用于战斗中快速辨识威胁等级。",
		13, Color(0.50, 0.62, 0.68)), Vector2(48, 660)))

	await _frames(14)
	await _shot("11_enemy_sheet")
	layer.queue_free()
	await _frames(4)


## 开场漫画：4 页引导插画
func _intro_comic() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color(0.043, 0.062, 0.086)
	bg.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, 0)
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)

	var files := [
		"01_page_awakening", "02_page_overload", "03_page_loot", "04_page_controls"]
	var titles := ["第 1 页 · 苏醒", "第 2 页 · 过载", "第 3 页 · 拾取", "第 4 页 · 操作"]
	for i in 4:
		var col := i % 2
		var row := i / 2
		var cell := Vector2(56.0 + float(col) * 600.0, 76.0 + float(row) * 320.0)
		var tex: Texture2D = load("res://assets/story-comic/%s.png" % files[i])
		if tex != null:
			var sp := TextureRect.new()
			sp.texture = tex
			sp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
			sp.position = cell
			sp.size = Vector2(560, 288)
			sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.add_child(sp)
		# 描一圈边框（ReferenceRect 在 Godot 4 没有 edges 属性，用 4 条 Line2D 自己画）
		var bx := cell.x
		var by := cell.y
		var bw := 560.0
		var bh := 288.0
		for seg in [
			[Vector2(bx, by), Vector2(bx + bw, by)],
			[Vector2(bx + bw, by), Vector2(bx + bw, by + bh)],
			[Vector2(bx + bw, by + bh), Vector2(bx, by + bh)],
			[Vector2(bx, by + bh), Vector2(bx, by)],
		]:
			var ln := Line2D.new()
			ln.points = PackedVector2Array([seg[0], seg[1]])
			ln.width = 2.0
			ln.default_color = Color(0.30, 0.80, 0.78, 0.75)
			layer.add_child(ln)

		var l := _label(titles[i], 15, Color(0.62, 0.94, 0.90))
		l.position = Vector2(cell.x, cell.y - 26.0)
		l.size = Vector2(400, 20)
		layer.add_child(l)

	layer.add_child(_at(_label("开场漫画 · 首次开始游戏时自动播放（4 页）", 24,
		Color(0.62, 0.94, 0.90)), Vector2(56, 28)))

	await _frames(16)
	await _shot("12_intro_comic")
	layer.queue_free()
	await _frames(4)


func _scene_tutorial() -> void:
	RunDirector.pending_resume = {}
	RunDirector.pending_tutorial = true
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")
	await _seconds(1.4)
	EventBus.tutorial_step.emit(2, 6, "roll")
	await _frames(24)
	await _shot("02_tutorial_room")


func _scene_combat() -> void:
	MetaState.set_tutorial_done(true)
	RunDirector.pending_tutorial = false
	RunDirector.pending_resume = {}
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")
	await _seconds(0.8)
	await _dismiss_route_map()
	await _seconds(0.5)
	GameState.equip_weapon("scatter")
	GameState.add_protocol("siphon")
	GameState.add_card("allin")
	GameState.grant_scroll("firepower")
	GameState.grant_scroll("firepower")
	GameState.add_gold(240)
	GameState.add_cells(6)
	GameState.add_energy(3)
	EventBus.build_changed.emit()
	await _frames(30)
	# 先往右走触发「房间锁定」，再按住开火让第一波怪走上来 —— 画面里才有真的在打
	Input.warp_mouse(AIM_SCREEN)
	_hold_key(KEY_D, true)
	await _seconds(0.5)
	_hold_key(KEY_D, false)
	_hold_fire(true)
	await _seconds(1.6)
	_hold_key(KEY_D, true)
	await _seconds(0.35)
	_hold_key(KEY_D, false)
	await _seconds(0.6)
	_hold_fire(false)
	await _shot("03_combat_room")
	# 主角特写：摄像机拉近 4x（HUD 是 CanvasLayer，不受摄像机影响）
	var cam := get_viewport().get_camera_2d()
	var pl := get_tree().get_first_node_in_group("player")
	if cam != null and pl != null:
		# 摄像机在等距屏幕上工作，所以要对投影后的坐标，不能直接用逻辑坐标
		cam.position = ISO.to_screen(pl.global_position)
		cam.zoom = Vector2(4.0, 4.0)
		_hold_key(KEY_D, true)
		_hold_fire(true)
		await _seconds(0.9)
		await _shot("03b_player_closeup")
		_hold_fire(false)
		_hold_key(KEY_D, false)
		cam.zoom = Vector2(1.0, 1.0)
		if pl != null:
			cam.position = Vector2(640.0, 360.0)
		await _frames(4)


func _scene_danger() -> void:
	Overload.add(76.0)
	GameState.damage_core(GameState.max_hp - int(float(GameState.max_hp) * 0.22))
	Input.warp_mouse(AIM_SCREEN)
	_hold_key(KEY_D, true)
	await _seconds(0.25)
	_hold_fire(true)
	await _seconds(1.2)
	_hold_fire(false)
	_hold_key(KEY_D, false)
	await _shot("04_hud_danger")


## 真刀真枪放一只 Boss 进场（只发 boss_spawned 事件的话，画面上根本看不到 Boss）
func _scene_boss() -> void:
	var room: Node = get_tree().get_first_node_in_group("room")
	if room != null:
		var boss: Node = load("res://scripts/entities/bosses/CoolantTitan.gd").new()
		room.add_child(boss)
		boss.global_position = Vector2(900, 300)
		await _seconds(0.8)
		EventBus.boss_hp_changed.emit(880, 1400)
	await _frames(10)
	await _shot("05_boss_and_banner")


func _scene_end() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p != null:
		GameState.active = false
	var hud := get_tree().root.find_child("HUD", true, false)
	if hud != null and hud.has_method("show_end"):
		hud.show_end(true, 268, 64)
	await _frames(16)
	await _shot("06_end_overlay")
