class_name IsoRoom
## IsoRoom.gd —— 等距房间的静态几何（地板 / 墙 / 闸门 / 方块）。
##
## 全部只画「视觉」，不含任何碰撞体 —— 碰撞仍由 RoomFactory 在逻辑坐标里放矩形，
## 所以物理和手感一行都不用改。等距只是「换了个画法」。
##
## 深度：所有几何用 Iso.z_of(逻辑中点) 参与全场遮挡排序，因此「站在柱子后面会被
## 柱子的顶面挡住」「远处的墙在角色之后」都自动成立。


## 地板：一张半分辨率贴图放大 2 倍，铺满整块菱形并带边缘发光
static func floor(parent: Node2D, biome: int) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.texture = PixelArt.iso_floor_tex(biome)
	spr.centered = false
	spr.position = Vector2.ZERO
	spr.scale = Vector2(2, 2)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.z_index = -900
	spr.name = "IsoFloor"
	parent.add_child(spr)
	return spr


## 场外底噪：菱形之外的深色底，让「浮空平台」的感觉成立
static func backdrop(parent: Node2D) -> void:
	var rect := ColorRect.new()
	rect.color = Color(0.031, 0.047, 0.070, 1.0)
	rect.position = Vector2(0, 0)
	rect.size = Vector2(1280, 720)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = -950
	rect.name = "IsoBackdrop"
	parent.add_child(rect)


## 沿逻辑线段 (a → b) 升起一道等距墙。height 是屏幕像素高度。
## auto_z=true 时每段自己按逻辑中点算深度，墙面才能和角色正确互相遮挡。
static func wall(parent: Node2D, biome: int, a: Vector2, b: Vector2,
		height: float, z: int = -90, auto_z := false) -> void:
	var pal: Array = PixelArt.BIOMES[clampi(biome, 0, 2)]
	var face: Color = pal[2]
	var top: Color = pal[2].lightened(0.28)
	var glow: Color = pal[3]
	var pa := Iso.to_screen(a)
	var pb := Iso.to_screen(b)
	var up := Vector2(0, -height)
	# 分段面板：每段深浅交替 + 一道竖缝，墙才不会看起来像一块平地
	var seg := 3
	if absf(pb.x - pa.x) + absf(pb.y - pa.y) < 40.0:
		seg = 1
	elif absf(pb.x - pa.x) + absf(pb.y - pa.y) > 700.0:
		seg = 8                       # 长墙多切几段，深度排序才跟得上
	var step := (b - a) / float(seg)
	var seam := face.darkened(0.48)
	for i in seg:
		var sa := Iso.to_screen(a + step * float(i))
		var sb := Iso.to_screen(a + step * float(i + 1))
		var c := face if (i % 2) == 0 else face.lightened(0.09)
		var zz := Iso.z_of(a + step * (float(i) + 0.5)) if auto_z else z
		_poly(parent, PackedVector2Array([sa, sb, sb + up, sa + up]), c, zz)
		if i > 0:
			_poly(parent, PackedVector2Array([
				sa, sa + Vector2(1.5, 0), sa + up + Vector2(1.5, 0), sa + up]), seam, zz + 1)
	# 顶部封边（受光面）+ 一道冷色灯带（整条一条，跨段不打断）
	var z_top := Iso.z_of((a + b) * 0.5) if auto_z else z
	_poly(parent, PackedVector2Array([pa + up, pb + up, pb + up + Vector2(0, -4), pa + up + Vector2(0, -4)]),
		top, z_top + 2)
	_poly(parent, PackedVector2Array([pa + up, pb + up, pb + up + Vector2(0, -1.5), pa + up + Vector2(0, -1.5)]),
		glow, z_top + 3)


## 门口闸板：一段带横梁的等距闸门。locked=true 是暖色实体闸门，开启后变冷色空框。
## 返回的 holder 交给 set_gate_open() 切换状态。
static func gate(parent: Node2D, biome: int, a: Vector2, b: Vector2, height: float,
		locked: bool = true) -> Node2D:
	var pal: Array = PixelArt.BIOMES[clampi(biome, 0, 2)]
	var holder := Node2D.new()
	holder.name = "IsoGate"
	holder.z_index = Iso.z_of((a + b) * 0.5) + 2
	parent.add_child(holder)

	var pa := Iso.to_screen(a)
	var pb := Iso.to_screen(b)
	var up := Vector2(0, -height)
	var dir := (pb - pa)
	if dir.length() < 0.001:
		dir = Vector2.RIGHT
	var inset := dir.normalized() * 4.0
	var qa := pa + inset
	var qb := pb - inset

	# 闸门本体（会随开合换色）
	var body := _poly(holder, PackedVector2Array([qa, qb, qb + up, qa + up]),
		Color(0.62, 0.30, 0.10), 0)
	body.name = "GateBody"
	# 门框立柱（固定，不受开合影响）
	var post_c: Color = pal[2].lightened(0.34)
	_poly(holder, PackedVector2Array([
		pa - dir.normalized() * 5.0, pa + dir.normalized() * 5.0,
		pa + dir.normalized() * 5.0 + up, pa - dir.normalized() * 5.0 + up]), post_c, 1)
	_poly(holder, PackedVector2Array([
		pb - dir.normalized() * 5.0, pb + dir.normalized() * 5.0,
		pb + dir.normalized() * 5.0 + up, pb - dir.normalized() * 5.0 + up]), post_c, 1)
	# 横梁：贴在门顶（只占 5px 高，不要写成长条 —— 那会把整个门体盖住）
	_poly(holder, PackedVector2Array([
		pa - dir.normalized() * 6.0 + up, pb + dir.normalized() * 6.0 + up,
		pb + dir.normalized() * 6.0 + up + Vector2(0, -5),
		pa - dir.normalized() * 6.0 + up + Vector2(0, -5)]), pal[2].lightened(0.30), 2)
	# 状态灯带（开合换色）
	var b1 := height * 0.30
	var b2 := height * 0.42
	var strip := _poly(holder, PackedVector2Array([
		qa + up + Vector2(0, b1), qb + up + Vector2(0, b1),
		qb + up + Vector2(0, b2), qa + up + Vector2(0, b2)]), Color(1.0, 0.72, 0.28), 3)
	strip.name = "GateStrip"

	set_gate_open(holder, not locked)
	return holder


## 切换闸门开合：开门后门体半透明、灯带转冷绿（和地板边缘光同色）
static func set_gate_open(holder: Node2D, open: bool) -> void:
	if holder == null or not is_instance_valid(holder):
		return
	var body := holder.get_node_or_null("GateBody") as Polygon2D
	var strip := holder.get_node_or_null("GateStrip") as Polygon2D
	if body != null:
		body.color = Color(0.10, 0.34, 0.34, 0.28) if open else Color(0.62, 0.30, 0.10)
	if strip != null:
		strip.color = Color(0.35, 1.0, 0.88) if open else Color(1.0, 0.72, 0.28)


## 等距方块（障碍柱 / 货箱）。size 是逻辑边长，height 是屏幕像素高度。
static func block(parent: Node2D, biome: int, center: Vector2, size: float,
		height: float) -> Node2D:
	var pal: Array = PixelArt.BIOMES[clampi(biome, 0, 2)]
	var s := size * 0.5
	var top_c: Color = pal[2].lightened(0.30)
	var mid_c: Color = pal[2]
	var dark_c: Color = pal[2].darkened(0.34)
	var glow: Color = pal[3]
	var rim := Color(0.022, 0.045, 0.060)

	var t := Iso.to_screen(center + Vector2(-s, -s))
	var r := Iso.to_screen(center + Vector2(s, -s))
	var bt := Iso.to_screen(center + Vector2(s, s))
	var l := Iso.to_screen(center + Vector2(-s, s))
	var up := Vector2(0, -height)

	var holder := Node2D.new()
	holder.z_index = Iso.z_of(center)
	holder.name = "IsoBlock"
	parent.add_child(holder)

	var top_pts := PackedVector2Array([t + up, r + up, bt + up, l + up])
	var right_pts := PackedVector2Array([r, bt, bt + up, r + up])
	var left_pts := PackedVector2Array([l, bt, bt + up, l + up])

	# 三面各自外扩一点，先画一层近黑底 —— 得到 1~2px 剪影描边（像素画的关键）
	_poly(holder, _scale_pts(right_pts, 1.07), rim, 0)
	_poly(holder, _scale_pts(left_pts, 1.07), rim, 0)
	_poly(holder, _scale_pts(top_pts, 1.05), rim, 0)

	_poly(holder, right_pts, mid_c, 1)
	_poly(holder, left_pts, dark_c, 1)
	_poly(holder, top_pts, top_c, 2)

	# 顶面：内嵌面板 + 中心指示灯
	_poly(holder, _scale_pts(top_pts, 0.58), mid_c.darkened(0.46), 3)
	_poly(holder, _scale_pts(top_pts, 0.36), mid_c.darkened(0.18), 3)
	_poly(holder, _scale_pts(top_pts, 0.15), glow, 4)

	# 两侧灯带
	var b1 := height * 0.16
	var b2 := height * 0.27
	_poly(holder, PackedVector2Array([
		r + up + Vector2(0, b1), bt + up + Vector2(0, b1),
		bt + up + Vector2(0, b2), r + up + Vector2(0, b2)]), glow, 2)
	_poly(holder, PackedVector2Array([
		l + up + Vector2(0, b1), bt + up + Vector2(0, b1),
		bt + up + Vector2(0, b2), l + up + Vector2(0, b2)]), glow.darkened(0.40), 2)
	return holder


## 以质心为原点缩放多边形（k<1 内缩，k>1 外扩）
static func _scale_pts(pts: PackedVector2Array, k: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= float(pts.size())
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + (p - c) * k)
	return out


static func _poly(parent: Node2D, pts: PackedVector2Array, color: Color, z: int) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = color
	p.antialiased = false
	p.z_index = z
	parent.add_child(p)
	return p
