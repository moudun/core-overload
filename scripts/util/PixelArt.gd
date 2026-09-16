class_name PixelArt
## PixelArt.gd —— V1.3 程序化像素贴图（纯代码，零外部素材）。
## 视觉规范：深蓝黑底 (#101722) + 冷青 (#42E6D0) / 琥珀 (#FFB347) /
##           危险红 (#FF5C69) / 稀有紫 (#B68CFF)。

const PX := 1

# ---------------- V1.3 视觉规范色 ----------------
const C_BG := Color(0.063, 0.090, 0.133)
const C_CYAN := Color(0.259, 0.902, 0.816)
const C_AMBER := Color(1.000, 0.702, 0.278)
const C_RED := Color(1.000, 0.361, 0.412)
const C_PURPLE := Color(0.714, 0.549, 1.000)
const C_TEXT := Color(0.863, 0.925, 0.902)
const C_DIM := Color(0.520, 0.600, 0.620)

# 三区块色板：[地板, 地板暗, 墙体, 氛围光]
const BIOMES := [
	[Color(0.055, 0.105, 0.130), Color(0.040, 0.078, 0.098), Color(0.098, 0.200, 0.240), Color(0.259, 0.902, 0.816)],
	[Color(0.090, 0.075, 0.155), Color(0.065, 0.052, 0.115), Color(0.180, 0.145, 0.285), Color(0.714, 0.549, 1.000)],
	[Color(0.125, 0.060, 0.070), Color(0.095, 0.042, 0.050), Color(0.280, 0.125, 0.120), Color(1.000, 0.361, 0.412)],
]


# ---------------- 基础图形 ----------------
static func circle_tex(size: int, core: Color, glow: Color, rim: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := float(size) * 0.5
	var r := half - 1.0
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(half, half))
			if d > half:
				continue
			var col := core
			if d > r - 1.5:
				col = rim
			elif d > r * 0.62:
				col = glow
			elif d > r * 0.28:
				col = core.lerp(glow, 0.35)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func square_tex(size: int, base: Color, edge: Color, corners: float = 1.0) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := float(size) * 0.5 - 1.0
	for y in size:
		for x in size:
			var dx := absf((x + 0.5) - size * 0.5)
			var dy := absf((y + 0.5) - size * 0.5)
			var ox := maxf(dx - (r - corners), 0.0)
			var oy := maxf(dy - (r - corners), 0.0)
			if ox * ox + oy * oy > corners * corners:
				continue
			if dx >= r or dy >= r:
				img.set_pixel(x, y, edge)
			else:
				var shade := 1.0 - 0.18 * (dx + dy) / float(size)
				img.set_pixel(x, y, base * Color(shade, shade, shade, 1.0))
	return ImageTexture.create_from_image(img)


static func card_tex(size: int, base: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var on_edge := x == 0 or y == 0 or x == size - 1 or y == size - 1
			if on_edge:
				img.set_pixel(x, y, Color(0.9, 0.9, 0.85))
			elif x <= 1 or y <= 1 or x >= size - 2 or y >= size - 2:
				img.set_pixel(x, y, base.darkened(0.35))
			elif y == 2:
				img.set_pixel(x, y, Color(1, 1, 1, 0.85))
			else:
				img.set_pixel(x, y, base)
	return ImageTexture.create_from_image(img)


## 菱形（源代码 / 细胞）
static func diamond_tex(size: int, core: Color, edge: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := size * 0.5
	for y in size:
		for x in size:
			var d := absf(x + 0.5 - half) + absf(y + 0.5 - half)
			if d > half:
				continue
			var col := core if d < half * 0.55 else edge
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


# ---------------- 地板 / 墙 ----------------
static func biome_floor_tex(biome: int, w: int, h: int) -> ImageTexture:
	var pal: Array = BIOMES[clampi(biome, 0, 2)]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var s := 32
	var light_c: Color = pal[0]
	var dark_c: Color = pal[1]
	for gy in range(h / s + 1):
		for gx in range(w / s + 1):
			var col := light_c if (gx + gy) % 2 == 0 else dark_c
			if (gx * 7 + gy * 13) % 9 == 0:
				col = col.darkened(0.12)
			img.fill_rect(Rect2i(gx * s, gy * s, s, s), col)
	var seam := Color(0.03, 0.04, 0.055)
	for y in range(0, h, s):
		img.fill_rect(Rect2i(0, y, w, 2), seam)
	for x in range(0, w, s):
		img.fill_rect(Rect2i(x, 0, 2, h), seam)
	return ImageTexture.create_from_image(img)


static func wall_tex(biome: int) -> ImageTexture:
	var pal: Array = BIOMES[clampi(biome, 0, 2)]
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var base: Color = pal[2]
	var brick := s / 4
	for y in s:
		for x in s:
			var col := base
			if (x % brick) < 1 or (y % brick) < 1:
				col = base.darkened(0.45)
			if x < 2 or y < 2 or x >= s - 2 or y >= s - 2:
				col = base.lightened(0.28)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func pillar_tex(biome: int) -> ImageTexture:
	var pal: Array = BIOMES[clampi(biome, 0, 2)]
	var s := 48
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var base: Color = pal[2].darkened(0.25)
	var accent: Color = pal[3].darkened(0.35)
	for y in s:
		for x in s:
			var col := base
			if x < 3 or y < 3 or x >= s - 3 or y >= s - 3:
				col = accent
			if (x + y) % 8 == 0:
				col = col.darkened(0.15)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func door_tex(locked: bool) -> ImageTexture:
	var s := 40
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var frame := Color(0.30, 0.33, 0.38)
	var fill := C_RED if locked else C_CYAN
	for y in s:
		for x in s:
			var col := frame
			if x >= 4 and y >= 4 and x < s - 4 and y < s - 4:
				var band := ((x + y) % 12) < 4
				col = fill.lightened(0.25) if band else fill
			if x < 2 or y < 2 or x >= s - 2 or y >= s - 2:
				col = fill.lightened(0.5)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


# ---------------- 角色 / 敌人 ----------------
## 玩家机体：八边形装甲舱体 + 四角推进器吊舱 + 中央反应堆核心。
## 刻意做成「非圆形剪影」——斜向吊舱向外探出并带琥珀色喷口，
## 一眼能读出这是台机体 / 无人机，而不是一颗球。
static func player_core_tex() -> ImageTexture:
	var s := 34
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var half := float(s) * 0.5

	var rim := Color(0.46, 0.99, 0.91)        # 外壳冷青描边
	var shell_lit := Color(0.44, 0.63, 0.67)  # 受光面（提亮：机身本身要是「块面」）
	var shell := Color(0.27, 0.41, 0.45)      # 主体装甲
	var hull := Color(0.14, 0.23, 0.27)       # 核心座（比机身暗一档）
	var seam := Color(0.04, 0.09, 0.11)       # 装甲板接缝
	var bell := Color(0.20, 0.32, 0.37)       # 推进器壳体
	var bell_rim := Color(1.00, 0.66, 0.24)   # 喷口环
	var bell_hot := Color(1.00, 0.88, 0.52)   # 喷口焰心
	var core_a := Color(0.13, 0.80, 0.73)
	var core_b := Color(0.36, 1.00, 0.92)
	var core_c := Color(0.95, 1.00, 0.99)

	# 1) 八边形装甲舱体（四角切角 → 明显不是圆）
	for y in s:
		for x in s:
			var ax := absf(float(x) + 0.5 - half)
			var ay := absf(float(y) + 0.5 - half)
			var oct := maxf(ax, ay) + 0.45 * minf(ax, ay)
			if oct > 10.2:
				continue
			var col := hull
			if oct > 8.8:
				col = rim
			elif oct > 7.8:
				col = shell_lit
			elif oct > 5.4:
				col = shell
			# 四块装甲板之间的十字接缝
			if (ax < 0.8 or ay < 0.8) and maxf(ax, ay) > 3.4:
				col = seam
			img.set_pixel(x, y, col)

	# 2) 四角推进器：自舱体斜向外张开的梯形喷口（打破圆形剪影的关键）
	for sy in [-1.0, 1.0]:
		for sx in [-1.0, 1.0]:
			var axis := Vector2(sx, sy).normalized()
			for y in s:
				for x in s:
					var px := float(x) + 0.5 - half
					var py := float(y) + 0.5 - half
					var along := px * axis.x + py * axis.y
					if along < 6.8 or along > 14.2:
						continue
					var hw := lerpf(3.7, 2.6, (along - 6.8) / 7.4)
					var perp := absf(-px * axis.y + py * axis.x)
					if perp > hw:
						continue
					var c := bell
					if along > 9.2 and perp > hw - 1.3:
						c = bell_rim
					if along > 12.4:
						c = bell_hot
					img.set_pixel(x, y, c)

	# 3) 中央反应堆核心
	for y in s:
		for x in s:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(half, half))
			if d > 4.1:
				continue
			var c := core_a
			if d > 3.0:
				c = core_a.darkened(0.45)
			elif d > 1.6:
				c = core_b
			else:
				c = core_c
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## 径向光晕（叠加发光用；中心不透明，向外按 power 次幂衰减）
static func radial_glow_tex(size: int, color: Color, power: float = 2.2) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := float(size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(half, half)) / half
			if d >= 1.0:
				continue
			var a := clampf(pow(1.0 - d, power), 0.0, 1.0)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, a))
	return ImageTexture.create_from_image(img)


## 推进器尾焰：喷口在左（最宽最亮）→ 尾端向右收细并淡出。
## 使用时把贴图旋转到「移动方向的反方向」。
static func thruster_tex(core: Color, outer: Color, w: int = 22, h: int = 13) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var half_h := float(h) * 0.5
	for y in h:
		for x in w:
			var t := 1.0 - float(x) / float(maxi(1, w - 1))   # 1 = 喷口，0 = 尾端
			var dy := absf(float(y) + 0.5 - half_h) / half_h
			var wob := 1.0 + 0.24 * sin(float(x) * 1.9)
			if dy > t * wob:
				continue
			var c := outer if dy > t * wob * 0.48 else core
			img.set_pixel(x, y, Color(c.r, c.g, c.b, clampf(t * 1.2, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


static func enemy_tex(kind: int) -> ImageTexture:
	var key := clampi(kind, 0, 4)
	if _enemy_cache.has(key):
		return _enemy_cache[key]
	var tex := _enemy_build(key)
	_enemy_cache[key] = tex
	return tex


static var _enemy_cache := {}


## 每种敌人一个**专属外形**（不再是方块/圆盘）。
## 纯程序化像素画，和玩家机体同一套配色语言：暗底 + 冷青描边 + 一个发光「眼」。
##  0 drone   —— 悬浮小核，底下两片稳定翼，中间独眼（追踪自爆）
##  1 brute   —— 宽肩厚甲，双臂下垂，前倾的重装躯干（慢速高伤）
##  2 runner  —— 细长瘦高，后掠腿，针刺状头部（高速冲锋）
##  3 spitter —— 三足支架 + 顶部炮口，像个小型炮台（远程）
##  4 glitch  —— 破碎多边形，边缘不规则抖动，多个错位复眼（故障体）
static func _enemy_build(kind: int) -> ImageTexture:
	var s := 40
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var cx := float(s) * 0.5

	match kind:
		0:
			# ---- DRONE：悬浮核 + 侧翼 + 独眼 ----
			var shell := Color(0.46, 0.20, 0.20)
			var shell_lit := Color(0.68, 0.30, 0.27)
			var dark := Color(0.22, 0.09, 0.09)
			# 侧翼（左右两片斜板）
			_blk(img, cx - 15.0, 18.0, 7.0, 3.0, dark)
			_blk(img, cx + 8.0, 18.0, 7.0, 3.0, dark)
			_blk(img, cx - 13.0, 15.0, 5.0, 3.0, shell)
			_blk(img, cx + 8.0, 15.0, 5.0, 3.0, shell)
			# 主体八边形
			_oct(img, cx, 20.0, 9.0, shell, shell_lit)
			# 独眼
			_ring(img, cx, 19.0, 4.0, 2.0, dark)
			_ring(img, cx, 19.0, 2.6, 2.6, Color(1.0, 0.42, 0.36))
			_blk(img, cx - 1.0, 18.0, 2.0, 2.0, Color(1.0, 0.94, 0.90))
			# 下方悬浮喷口
			_blk(img, cx - 3.0, 29.0, 6.0, 2.0, dark)
			_blk(img, cx - 2.0, 31.0, 4.0, 2.0, Color(1.0, 0.55, 0.18))
		1:
			# ---- BRUTE：宽肩重甲，前倾 ----
			var arm := Color(0.52, 0.24, 0.16)
			var arm_lit := Color(0.72, 0.38, 0.24)
			var dark2 := Color(0.20, 0.09, 0.06)
			# 双腿
			_blk(img, cx - 8.0, 28.0, 5.0, 9.0, dark2)
			_blk(img, cx + 3.0, 28.0, 5.0, 9.0, dark2)
			_blk(img, cx - 9.0, 35.0, 7.0, 3.0, arm)
			_blk(img, cx + 2.0, 35.0, 7.0, 3.0, arm)
			# 躯干（上宽下窄）
			_blk(img, cx - 10.0, 13.0, 20.0, 9.0, arm)
			_blk(img, cx - 8.0, 21.0, 16.0, 8.0, dark2)
			_blk(img, cx - 9.0, 14.0, 18.0, 3.0, arm_lit)
			# 双臂下垂
			_blk(img, cx - 14.0, 15.0, 5.0, 13.0, dark2)
			_blk(img, cx + 9.0, 15.0, 5.0, 13.0, dark2)
			_blk(img, cx - 15.0, 27.0, 7.0, 4.0, arm)
			_blk(img, cx + 8.0, 27.0, 7.0, 4.0, arm)
			# 小头 + 眼
			_blk(img, cx - 4.0, 7.0, 8.0, 6.0, dark2)
			_blk(img, cx - 3.0, 10.0, 6.0, 2.0, Color(1.0, 0.46, 0.30))
		2:
			# ---- RUNNER：细高、后掠腿、针刺头 ----
			var rs := Color(0.60, 0.30, 0.14)
			var rs_lit := Color(0.86, 0.48, 0.20)
			var rs_dark := Color(0.24, 0.12, 0.05)
			# 后掠腿（向左下）
			_blk(img, cx - 7.0, 26.0, 3.0, 8.0, rs_dark)
			_blk(img, cx - 10.0, 32.0, 4.0, 4.0, rs)
			_blk(img, cx + 3.0, 26.0, 3.0, 9.0, rs_dark)
			_blk(img, cx + 3.0, 34.0, 5.0, 3.0, rs)
			# 细躯干
			_blk(img, cx - 4.0, 14.0, 8.0, 13.0, rs)
			_blk(img, cx - 3.0, 15.0, 3.0, 11.0, rs_lit)
			_blk(img, cx - 5.0, 20.0, 10.0, 3.0, rs_dark)
			# 前伸细臂
			_blk(img, cx - 9.0, 17.0, 5.0, 3.0, rs_dark)
			_blk(img, cx + 4.0, 17.0, 5.0, 3.0, rs_dark)
			# 针刺头
			_blk(img, cx - 3.0, 8.0, 6.0, 6.0, rs_dark)
			_blk(img, cx - 1.0, 3.0, 2.0, 6.0, rs_lit)
			_blk(img, cx - 2.0, 11.0, 4.0, 2.0, Color(1.0, 0.72, 0.24))
		3:
			# ---- SPITTER：三足炮台 ----
			var sp := Color(0.24, 0.46, 0.28)
			var sp_lit := Color(0.42, 0.74, 0.42)
			var sp_dark := Color(0.09, 0.20, 0.12)
			# 三条支腿
			_blk(img, cx - 12.0, 26.0, 3.0, 8.0, sp_dark)
			_blk(img, cx - 1.0, 27.0, 3.0, 9.0, sp_dark)
			_blk(img, cx + 9.0, 26.0, 3.0, 8.0, sp_dark)
			_blk(img, cx - 14.0, 33.0, 6.0, 3.0, sp)
			_blk(img, cx - 3.0, 34.0, 6.0, 3.0, sp)
			_blk(img, cx + 8.0, 33.0, 6.0, 3.0, sp)
			# 球状躯体
			_ring(img, cx, 21.0, 9.0, 9.0, sp)
			_ring(img, cx, 21.0, 9.0, 2.0, sp_dark)
			_blk(img, cx - 5.0, 15.0, 6.0, 4.0, sp_lit)
			# 顶部炮口
			_blk(img, cx - 4.0, 6.0, 8.0, 5.0, sp_dark)
			_blk(img, cx - 3.0, 4.0, 6.0, 3.0, sp_lit)
			_blk(img, cx - 2.0, 8.0, 4.0, 2.0, Color(0.62, 1.0, 0.60))
		4:
			# ---- GLITCH：破碎多边形 + 错位复眼 ----
			var gl := Color(0.56, 0.30, 0.82)
			var gl_lit := Color(0.78, 0.50, 1.0)
			var gl_dark := Color(0.22, 0.08, 0.36)
			# 破碎主体：三块错位方片拼成
			_blk(img, cx - 11.0, 12.0, 13.0, 11.0, gl)
			_blk(img, cx + 1.0, 16.0, 10.0, 12.0, gl_dark)
			_blk(img, cx - 8.0, 23.0, 12.0, 9.0, gl.lightened(0.12))
			_blk(img, cx - 10.0, 13.0, 11.0, 3.0, gl_lit)
			# 锯齿边缘（抖动感）
			_blk(img, cx - 14.0, 15.0, 4.0, 3.0, gl_dark)
			_blk(img, cx + 10.0, 22.0, 4.0, 4.0, gl_dark)
			_blk(img, cx - 12.0, 30.0, 5.0, 3.0, gl_dark)
			# 错位复眼（3 只，大小不一）
			_ring(img, cx - 4.0, 17.0, 3.4, 3.4, Color(0.10, 0.02, 0.18))
			_ring(img, cx - 4.0, 17.0, 1.8, 1.8, Color(0.86, 0.62, 1.0))
			_ring(img, cx + 5.0, 21.0, 2.6, 2.6, Color(0.10, 0.02, 0.18))
			_ring(img, cx + 5.0, 21.0, 1.2, 1.2, Color(1.0, 0.80, 1.0))
			_ring(img, cx + 1.0, 28.0, 2.0, 2.0, Color(1.0, 0.46, 0.90))

	# 统一描一圈深色剪影边（和角色同一手法，小尺寸下才立得住）
	_outline(img, Color(0.02, 0.04, 0.06))
	return ImageTexture.create_from_image(img)


## 实心八边形（敌人主体用）
static func _oct(img: Image, cx: float, cy: float, r: float, fill: Color, lit: Color) -> void:
	var s := img.get_width()
	for y in s:
		for x in s:
			var ax := absf(float(x) + 0.5 - cx)
			var ay := absf(float(y) + 0.5 - cy)
			var o := maxf(ax, ay) + 0.45 * minf(ax, ay)
			if o <= r:
				# 左上受光
				var up := (float(y) + 0.5) < cy and ax < r * 0.7
				img.set_pixel(x, y, lit if up else fill)


## 宝箱底部的脉冲光环（2:1 菱形，贴地）
static func chest_halo_tex() -> ImageTexture:
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var cx := float(s) * 0.5
	var cy := float(s) * 0.5
	for y in s:
		for x in s:
			var dx := absf(float(x) + 0.5 - cx) / (float(s) * 0.5)
			var dy := absf(float(y) + 0.5 - cy) / (float(s) * 0.25)
			var d := dx + dy
			if d <= 1.0 and d >= 0.72:
				var a := 0.85 * (1.0 - absf(d - 0.86) / 0.14)
				img.set_pixel(x, y, Color(1.0, 0.80, 0.34, clampf(a, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


static func bullet_tex() -> ImageTexture:
	return circle_tex(10, Color(1, 0.95, 0.6), Color(1, 0.6, 0.1), Color(0.5, 0.2, 0.0))


static func boss_tex(kind: int) -> ImageTexture:
	match kind:
		1:
			return circle_tex(84, Color(0.75, 0.35, 0.95), Color(0.32, 0.10, 0.45), Color(0.10, 0.03, 0.16))
		2:
			return circle_tex(108, Color(1.0, 0.45, 0.28), Color(0.55, 0.14, 0.06), Color(0.14, 0.03, 0.02))
		_:
			return circle_tex(64, Color(0.30, 0.85, 0.95), Color(0.06, 0.38, 0.48), Color(0.01, 0.14, 0.18))


# ---------------- 掉落 / 图标 ----------------
static func chest_tex() -> ImageTexture:
	var s := 34
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var col := Color(0.36, 0.16, 0.52)
			if x < 3 or y < 3 or x >= s - 3 or y >= s - 3:
				col = Color(0.95, 0.78, 0.25)
			if y > s / 2 - 2 and y < s / 2 + 2:
				col = Color(0.95, 0.78, 0.25)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func coin_tex() -> ImageTexture:
	return circle_tex(14, Color(1.0, 0.92, 0.35), Color(0.85, 0.62, 0.1), Color(0.45, 0.3, 0.02))


static func cell_tex() -> ImageTexture:
	return diamond_tex(16, Color(0.35, 1.0, 0.85), Color(0.08, 0.55, 0.48))


## 能量碎片（房间内给设备供电）
static func energy_tex() -> ImageTexture:
	return diamond_tex(15, Color(1.0, 0.85, 0.35), Color(0.60, 0.36, 0.02))


## 底层源代码（局外永久货币）
static func source_tex() -> ImageTexture:
	var s := 18
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var half := s * 0.5
	for y in s:
		for x in s:
			var d := absf(x + 0.5 - half) + absf(y + 0.5 - half)
			if d > half:
				continue
			var col := Color(0.30, 1.0, 0.80) if d < half * 0.45 else Color(0.10, 0.55, 0.60)
			if (x + y) % 4 == 0 and d < half * 0.8:
				col = Color(0.85, 1.0, 0.95)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func scroll_tex(color: Color) -> ImageTexture:
	return circle_tex(26, color.lightened(0.35), color, color.darkened(0.5))


static func weapon_drop_tex(color: Color) -> ImageTexture:
	return square_tex(28, color, color.darkened(0.55), 5.0)


static func protocol_tex(color: Color) -> ImageTexture:
	return diamond_tex(26, color.lightened(0.30), color.darkened(0.35))


static func card_icon_tex(color: Color) -> ImageTexture:
	return card_tex(26, color)


# ---------------- 底层骇入（打飞机）专用 ----------------
## 玩家：数据包（上箭头造型）
static func hack_ship_tex() -> ImageTexture:
	var s := 26
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var half := s * 0.5
	for y in s:
		for x in s:
			var col := Color(0, 0, 0, 0)
			var fy := float(y)
			var spread := (fy / float(s)) * half * 1.05
			if absf(float(x) + 0.5 - half) <= spread and fy > 3.0:
				col = Color(0.45, 1.0, 0.90)
				if fy > s - 8.0:
					col = Color(0.24, 0.72, 1.0)
				if absf(float(x) + 0.5 - half) > spread - 1.6:
					col = Color(0.10, 0.55, 0.60)
			if fy <= 5.0 and absf(float(x) + 0.5 - half) <= 1.6:
				col = Color(0.95, 1.0, 1.0)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## 敌方进程：kind 0 基础 / 1 厚壳 / 2 快速 / 3 炮台
static func hack_enemy_tex(kind: int) -> ImageTexture:
	match kind:
		1:
			return square_tex(28, Color(0.80, 0.25, 0.30), Color(0.24, 0.05, 0.08), 3.0)
		2:
			return diamond_tex(20, Color(1.0, 0.72, 0.28), Color(0.45, 0.24, 0.02))
		3:
			return square_tex(26, Color(0.60, 0.40, 0.95), Color(0.16, 0.08, 0.35), 8.0)
		_:
			return square_tex(22, Color(0.85, 0.30, 0.35), Color(0.25, 0.05, 0.08), 2.0)


## 防火墙 mini-boss
static func hack_boss_tex() -> ImageTexture:
	var s := 74
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var half := s * 0.5
	for y in s:
		for x in s:
			var col := Color(0, 0, 0, 0)
			var dx := float(x) + 0.5 - half
			var dy := float(y) + 0.5 - half
			var d := sqrt(dx * dx + dy * dy)
			if d <= half:
				col = Color(0.36, 0.10, 0.42)
				if d > half - 4.0:
					col = Color(1.0, 0.36, 0.41)
				elif d > half - 11.0:
					col = Color(0.72, 0.30, 0.85)
				if (x + y) % 9 == 0:
					col = col.lightened(0.28)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## 骇入弹丸（小胶囊）
static func hack_bullet_tex(color: Color, w: int = 5, h: int = 13) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var edge := x == 0 or y == 0 or x == w - 1 or y == h - 1
			img.set_pixel(x, y, color.darkened(0.35) if edge else color)
	return ImageTexture.create_from_image(img)


## 骇入小游戏的星空 / 网格背景
static func hack_bg_tex(w: int, h: int) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.020, 0.035, 0.070))
	# 纵向电路走线
	for x in range(0, w, 40):
		img.fill_rect(Rect2i(x, 0, 1, h), Color(0.05, 0.13, 0.18))
	for y in range(0, h, 40):
		img.fill_rect(Rect2i(0, y, w, 1), Color(0.05, 0.13, 0.18))
	return ImageTexture.create_from_image(img)


# ---------------- 房间要素 ----------------
## 故障房的供电节点：state 0=熄灭 1=闪烁 2=已修复
static func pipe_node_tex(state: int) -> ImageTexture:
	var s := 44
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var base := Color(0.16, 0.20, 0.24)
	var lit := Color(0.24, 0.34, 0.38)
	match state:
		1:
			lit = C_AMBER
		2:
			lit = C_CYAN
	var half := s * 0.5
	for y in s:
		for x in s:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(half, half))
			if d > half:
				continue
			var col := base
			if d > half - 3.0:
				col = base.lightened(0.35)
			elif d < half * 0.42:
				col = lit
			else:
				col = base.lerp(lit, 0.30)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


# ---------------- 界面（HUD / 面板 / 图标） ----------------
## 9-slice 面板底：纵向渐变 + 1px 描边（顶边用 accent 提亮）。
## 配合 StyleBoxTexture 使用，任意尺寸都不会拉伸变形。
static func panel_slice_texture(accent: Color) -> ImageTexture:
	var s := 24
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var top := Color(0.066, 0.100, 0.122, 0.94)
	var bot := Color(0.016, 0.028, 0.040, 0.96)
	for y in s:
		var c := top.lerp(bot, float(y) / float(s - 1))
		for x in s:
			img.set_pixel(x, y, c)
	for i in s:
		img.set_pixel(i, 0, Color(accent.r, accent.g, accent.b, 0.92))
		img.set_pixel(0, i, Color(accent.r, accent.g, accent.b, 0.40))
		img.set_pixel(s - 1, i, Color(accent.r, accent.g, accent.b, 0.40))
		img.set_pixel(i, s - 1, Color(accent.r, accent.g, accent.b, 0.26))
	return ImageTexture.create_from_image(img)


## 竖向渐隐条（低分辨率生成后拉伸 → 顶栏阴影 / 氛围过渡）
static func vfade_tex(color: Color, top_a: float = 0.6, w: int = 4, h: int = 32) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var a := top_a * pow(1.0 - float(y) / float(maxi(1, h - 1)), 1.6)
		for x in w:
			img.set_pixel(x, y, Color(color.r, color.g, color.b, a))
	return ImageTexture.create_from_image(img)


## 屏幕暗角（低分辨率生成后线性拉伸，避免逐像素开销）
static func vignette_tex(w: int = 160, h: int = 90, strength: float = 0.62,
		tint: Color = Color(0.0, 0.012, 0.024)) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cx := float(w) * 0.5
	var cy := float(h) * 0.5
	var maxd := sqrt(cx * cx + cy * cy)
	for y in h:
		for x in w:
			var d := Vector2(float(x) + 0.5 - cx, float(y) + 0.5 - cy).length() / maxd
			var a := clampf((d - 0.46) / 0.54, 0.0, 1.0)
			a = a * a * strength
			if a <= 0.004:
				continue
			img.set_pixel(x, y, Color(tint.r, tint.g, tint.b, a))
	return ImageTexture.create_from_image(img)


## HUD 矢量图标：hp / bolt / roll / skill / shield / coin / cell / energy / source / depth
static func icon_tex(kind: String, s: int, color: Color) -> ImageTexture:
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var f := float(s)
	match kind:
		"hp":
			img.fill_rect(Rect2i(int(f * 0.31), int(f * 0.04), maxi(1, int(f * 0.38)), maxi(1, int(f * 0.92))), color)
			img.fill_rect(Rect2i(int(f * 0.04), int(f * 0.31), maxi(1, int(f * 0.92)), maxi(1, int(f * 0.38))), color)
		"bolt":
			_poly(img, PackedVector2Array([
				Vector2(f * 0.62, f * 0.02), Vector2(f * 0.20, f * 0.56),
				Vector2(f * 0.45, f * 0.56), Vector2(f * 0.36, f * 0.98),
				Vector2(f * 0.82, f * 0.40), Vector2(f * 0.54, f * 0.40),
			]), color)
		"roll":
			for k in 2:
				var ox := f * (0.06 + 0.32 * float(k))
				_poly(img, PackedVector2Array([
					Vector2(ox, f * 0.14), Vector2(ox + f * 0.30, f * 0.50), Vector2(ox, f * 0.86),
					Vector2(ox + f * 0.14, f * 0.86), Vector2(ox + f * 0.44, f * 0.50), Vector2(ox + f * 0.14, f * 0.14),
				]), color)
		"skill":
			var star := PackedVector2Array()
			for i in 8:
				var a := -PI * 0.5 + TAU * float(i) / 8.0
				var r := f * (0.50 if i % 2 == 0 else 0.20)
				star.append(Vector2(f * 0.5 + cos(a) * r, f * 0.5 + sin(a) * r))
			_poly(img, star, color)
		"shield":
			_poly(img, PackedVector2Array([
				Vector2(f * 0.5, f * 0.03), Vector2(f * 0.94, f * 0.22), Vector2(f * 0.86, f * 0.72),
				Vector2(f * 0.5, f * 0.98), Vector2(f * 0.14, f * 0.72), Vector2(f * 0.06, f * 0.22),
			]), color)
		"coin":
			_ring(img, f * 0.5, f * 0.5, f * 0.46, f * 0.22, color)
		"cell":
			_diamond(img, f * 0.5, f * 0.5, f * 0.50, 0.0, color)
		"energy":
			_diamond(img, f * 0.5, f * 0.5, f * 0.50, 0.42, color)
			_diamond(img, f * 0.5, f * 0.5, f * 0.24, 0.0, color)
		"source":
			var hex := PackedVector2Array()
			for i in 6:
				var a := -PI * 0.5 + TAU * float(i) / 6.0
				hex.append(Vector2(f * 0.5 + cos(a) * f * 0.48, f * 0.5 + sin(a) * f * 0.48))
			_poly(img, hex, color)
			_diamond(img, f * 0.5, f * 0.5, f * 0.21, 0.0, Color(0, 0, 0, 0))
		"depth":
			_poly(img, PackedVector2Array([
				Vector2(f * 0.06, f * 0.24), Vector2(f * 0.5, f * 0.60), Vector2(f * 0.94, f * 0.24),
				Vector2(f * 0.94, f * 0.48), Vector2(f * 0.5, f * 0.86), Vector2(f * 0.06, f * 0.48),
			]), color)
		"warn":
			_poly(img, PackedVector2Array([
				Vector2(f * 0.5, f * 0.04), Vector2(f * 0.98, f * 0.92), Vector2(f * 0.02, f * 0.92),
			]), color)
			img.fill_rect(Rect2i(int(f * 0.44), int(f * 0.34), maxi(1, int(f * 0.12)), maxi(1, int(f * 0.30))),
				Color(0.03, 0.05, 0.06, 0.95))
			img.fill_rect(Rect2i(int(f * 0.44), int(f * 0.74), maxi(1, int(f * 0.12)), maxi(1, int(f * 0.12))),
				Color(0.03, 0.05, 0.06, 0.95))
		_:
			_diamond(img, f * 0.5, f * 0.5, f * 0.44, 0.0, color)
	return ImageTexture.create_from_image(img)


static func _poly(img: Image, pts: PackedVector2Array, color: Color) -> void:
	var s := img.get_width()
	for y in s:
		for x in s:
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				img.set_pixel(x, y, color)


static func _ring(img: Image, cx: float, cy: float, r: float, w: float, color: Color) -> void:
	var s := img.get_width()
	for y in s:
		for x in s:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, cy))
			if d <= r and d >= r - w:
				img.set_pixel(x, y, color)


static func _diamond(img: Image, cx: float, cy: float, r: float, inner: float, color: Color) -> void:
	var s := img.get_width()
	for y in s:
		for x in s:
			var d := absf(x + 0.5 - cx) + absf(y + 0.5 - cy)
			if d <= r and d >= r * inner:
				img.set_pixel(x, y, color)


# ---------------- 等距（2.5D）专用 ----------------

static func _blk(img: Image, x: float, y: float, w: float, h: float, c: Color) -> void:
	var x0 := maxi(int(round(x)), 0)
	var y0 := maxi(int(round(y)), 0)
	var x1 := mini(x0 + int(round(w)), img.get_width())
	var y1 := mini(y0 + int(round(h)), img.get_height())
	for yy in range(y0, y1):
		for xx in range(x0, x1):
			img.set_pixel(xx, yy, c)


## 带 1px 描边的色块
static func _part(img: Image, x: float, y: float, w: float, h: float, fill: Color, line: Color) -> void:
	_blk(img, x - 1.0, y - 1.0, w + 2.0, h + 2.0, line)
	_blk(img, x, y, w, h, fill)


## 八向姿势表 —— 硬性拉开四档差异（纯侧 / 3-4 侧 / 正面 / 背面），
## 不靠连续插值，否则 45 度之间几乎看不出区别。
## hd=头部横向偏移  hy=头部纵向偏移  tw=肩宽  vis=面罩(0正面/1右缝/2左缝/3背无)
## pack=背包突出度  lg=步幅  pf=侧身程度(1=纯侧视)
const ACTOR_POSE := [
	{"hd": 3.0, "hy": 0.0, "tw": 7.0, "vis": 1, "pack": 0.0, "lg": 0.0, "pf": 1.0},
	{"hd": 2.0, "hy": 1.0, "tw": 11.0, "vis": 0, "pack": 0.0, "lg": 2.4, "pf": 0.35},
	{"hd": 0.0, "hy": 1.5, "tw": 13.0, "vis": 0, "pack": 0.0, "lg": 0.0, "pf": 0.0},
	{"hd": -2.0, "hy": 1.0, "tw": 11.0, "vis": 0, "pack": 0.0, "lg": 2.4, "pf": 0.35},
	{"hd": -3.0, "hy": 0.0, "tw": 7.0, "vis": 2, "pack": 0.0, "lg": 0.0, "pf": 1.0},
	{"hd": -2.0, "hy": -1.0, "tw": 11.0, "vis": 3, "pack": 0.6, "lg": 2.4, "pf": 0.35},
	{"hd": 0.0, "hy": -1.5, "tw": 13.0, "vis": 3, "pack": 1.0, "lg": 0.0, "pf": 0.0},
	{"hd": 2.0, "hy": -1.0, "tw": 11.0, "vis": 3, "pack": 0.6, "lg": 2.4, "pf": 0.35},
]

const ACTOR_W := 32          ## 贴图宽
const ACTOR_H := 44          ## 贴图高
const ACTOR_FOOT := 40.0     ## 贴图内脚底所在的 y（摆位时用来把脚对齐地面）


## 给整个剪影描 1px 深色边。小尺寸像素画能不能「读得清」几乎全看这一步。
static func _outline(img: Image, c: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var edges: Array = []
	var nb: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.02:
				continue
			var hit := false
			for d in nb:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				if img.get_pixel(nx, ny).a > 0.5:
					hit = true
					break
			if hit:
				edges.append(Vector2i(x, y))
	for e in edges:
		img.set_pixel(e.x, e.y, c)


## 八向「核心机体」驾驶员 —— 从机舱里爬出来的小个子。32x44，脚底 y=40，中轴 x=16。
## dir: 0=右 1=右下 2=下 3=左下 4=左 5=左上 6=上 7=右上
## 行走循环帧数。actor_tex(dir, phase) 里 phase 取 0..ACTOR_WALK-1；传 -1 为静态站姿。
const ACTOR_WALK := 6

## 待机循环帧数：phase 取 ACTOR_IDLE_BASE .. ACTOR_IDLE_BASE+ACTOR_IDLE-1 为待机呼吸。
## 之所以把「待机」也塞进同一个 phase 参数（而不是新加一个函数），是为了让 CorePlayer
## 只用一个 `_face_dir` + `_phase` 就能表达全部状态，缓存键也不用改结构。
const ACTOR_IDLE := 8
const ACTOR_IDLE_BASE := 100

## phase 是待机帧吗
static func _is_idle_phase(ph: int) -> bool:
	return ph >= ACTOR_IDLE_BASE


## 8 向 × (静态 + 6 帧行走 + 8 帧待机) = 120 张，生成一次缓存到底。
## 每帧新建 ImageTexture 会把 GPU 上传变成热路径，必须缓存。
static var _actor_cache := {}


static func actor_tex(dir: int, phase: int = -1) -> ImageTexture:
	var d := posmod(dir, 8)
	var ph := phase
	if _is_idle_phase(ph):
		ph = ACTOR_IDLE_BASE + posmod(ph - ACTOR_IDLE_BASE, ACTOR_IDLE)
	else:
		ph = clampi(phase, -1, ACTOR_WALK - 1)
	var ck := d * 64 + (ph + 1)
	if _actor_cache.has(ck):
		return _actor_cache[ck]
	var tex := _actor_build(d, ph)
	_actor_cache[ck] = tex
	return tex


static func _actor_build(dir: int, phase: int) -> ImageTexture:
	var img := Image.create(ACTOR_W, ACTOR_H, false, Image.FORMAT_RGBA8)
	var p: Dictionary = ACTOR_POSE[posmod(dir, 8)]
	var hd: float = p["hd"]
	var hy: float = p["hy"]
	var tw: float = p["tw"]
	var vis: int = p["vis"]
	var pack: float = p["pack"]
	var lg: float = p["lg"]
	var pf: float = p["pf"]

	# ---- 步态调制 ----
	var sw := 0.0
	var bob := 0.0
	var lift_a := 0.0
	var lift_b := 0.0
	var arm_sw := 0.0
	var lean := 0.0
	var breathe := 0.0
	var moving := phase >= 0 and not _is_idle_phase(phase)
	if moving:
		var t := float(posmod(phase, ACTOR_WALK)) / float(ACTOR_WALK)
		sw = sin(t * TAU)
		bob = -absf(sw) * 1.4              # 双腿分开时躯干下沉
		lift_a = maxf(0.0, sw) * 2.0       # 摆动腿抬脚
		lift_b = maxf(0.0, -sw) * 2.0
		arm_sw = sw * 2.2                  # 双臂反相摆动
	elif _is_idle_phase(phase):
		# 待机循环：一个 8 帧的「呼吸 + 微重心转移」周期。
		# 关键是**不要**只是上下平移 —— 那样看起来像整体缩放。这里拆成三层：
		#   1) 胸腔呼吸（躯干上下 0.9px + 肩宽极其轻微变化 → 用 bob 表达）
		#   2) 重心左右移（sway，作用在头部/手臂/腿部整体，幅度小但能看出「站得不僵硬」）
		#   3) 手臂自然微摆（和呼吸反相，制造一点迟滞感）
		var it := float(posmod(phase - ACTOR_IDLE_BASE, ACTOR_IDLE)) / float(ACTOR_IDLE)
		var a := it * TAU
		bob = -0.9 + sin(a) * 0.9              # 呼吸起伏
		lean = sin(a * 2.0) * 0.6              # 双倍频的轻微前倾
		breathe = sin(a) * 0.5
		arm_sw = sin(a + PI * 0.6) * 1.0       # 手臂滞后于呼吸
		lift_a = 0.0
		lift_b = 0.0
		# 重心转移：一周期内左右各一次，幅度 1.2px
		sw = sin(a) * 0.0

	var light := Color(0.670, 0.850, 0.865)
	var mid := Color(0.290, 0.475, 0.515)
	var thigh := Color(0.215, 0.350, 0.395)
	var dark := Color(0.140, 0.235, 0.280)
	var deep := Color(0.078, 0.140, 0.180)
	var line := Color(0.030, 0.058, 0.078)

	var cx := ACTOR_W * 0.5
	var foot := ACTOR_FOOT
	var sho := 15.0 + bob - lean
	var hip := 27.0 + bob
	var tx := cx - tw * 0.5

	# --- 背包推进器（先画，压在躯干之后）---
	if pack > 0.05:
		var bw := 3.5 + pack * 1.5
		var bh := 9.0 + pack * 4.0
		_blk(img, tx - bw * 0.45, sho + 2.0, bw, bh, deep)
		_blk(img, tx + tw - bw * 0.55, sho + 2.0, bw, bh, deep)
		if pack > 0.5:
			_blk(img, cx - 4.5, sho + 1.0, 9.0, bh - 1.0, dark)
			_blk(img, cx - 3.0, sho + 3.0, 6.0, 2.0, C_CYAN)
			_blk(img, cx - 3.0, sho + bh - 3.0, 6.0, 2.0, C_AMBER)
	else:
		_blk(img, tx - 2.0, sho + 3.0, 2.5, 7.0, deep)

	# --- 后侧手臂（与腿反相摆动）---
	var bax := cx - tw * 0.5 - 2.0
	if pf > 0.5:
		bax = cx + hd * 0.8 - 1.0
	if moving:
		bax += sw * 2.2
	elif _is_idle_phase(phase):
		bax += arm_sw * 0.6
	_blk(img, bax, sho + 2.0, 3.0, 5.0, mid.darkened(0.22))
	_blk(img, bax, sho + 7.0, 3.0, 6.0, dark)
	_blk(img, bax - 0.5, sho + 13.0, 4.0, 2.0, deep)

	# --- 双腿（剪刀步）---
	var spread := 3.5 * (1.0 - pf)
	var la := cx - 2.0 - spread - lg
	var lb := cx + 1.0 + lg * 0.7
	if moving:
		la = cx - 2.0 - spread - sw * 3.0
		lb = cx + 1.0 + sw * 3.0
	var lt := hip + 1.0 - lift_a
	var ls := foot - 7.0 - lift_a
	var lf := foot - 3.0 - lift_a
	_blk(img, la, lt, 4.0, ls - lt, thigh)
	_blk(img, la, ls, 4.0, lf - ls, dark)
	_blk(img, la - 1.0, lf, 6.0, 3.0, deep)
	_blk(img, la + 0.5, lt + 3.0, 3.0, 2.0, mid)
	_blk(img, la - 1.0, lf + 2.0, 6.0, 1.0, mid.darkened(0.3))
	var rt := hip + 1.0 - lift_b
	var rs := foot - 7.0 - lift_b
	var rf := foot - 3.0 - lift_b
	_blk(img, lb, rt, 4.0, rs - rt, thigh)
	_blk(img, lb, rs, 4.0, rf - rs, dark)
	_blk(img, lb - 1.0, rf, 6.0, 3.0, deep)
	_blk(img, lb + 0.5, rt + 3.0, 3.0, 2.0, mid)
	_blk(img, lb - 1.0, rf + 2.0, 6.0, 1.0, mid.darkened(0.3))

	# --- 髋 ---
	_blk(img, cx - tw * 0.5 + 1.0, hip - 2.0, tw - 2.0, 5.0, dark)
	_blk(img, cx - tw * 0.5, hip + 1.0, tw, 1.0, deep)

	# --- 躯干 ---
	_blk(img, tx, sho, tw, hip - sho, mid)
	_blk(img, tx + 1.0, sho, tw - 2.0, 2.0, light)
	_blk(img, tx + 1.0, sho + 2.0, tw - 2.0, 1.0, mid.darkened(0.42))
	_blk(img, tx, sho + 3.0, 1.0, hip - sho - 3.0, mid.darkened(0.48))
	_blk(img, tx + tw - 1.0, sho + 3.0, 1.0, hip - sho - 3.0, mid.darkened(0.48))
	if vis != 3:
		_blk(img, cx - 3.0 + hd * 0.5, sho + 5.0, 6.0, 4.0, deep)
		_blk(img, cx - 1.5 + hd * 0.5, sho + 6.0, 3.0, 2.0, C_CYAN)
	else:
		_blk(img, cx - 3.0, sho + 5.0, 6.0, 3.0, C_AMBER.darkened(0.25))
		_blk(img, cx - 0.5, sho + 3.0, 1.0, hip - sho - 3.0, mid.darkened(0.5))
	_blk(img, tx - 1.5, sho - 2.0, 4.0, 4.0, light)
	_blk(img, tx + tw - 2.5, sho - 2.0, 4.0, 4.0, light)

	# --- 前侧手臂 ---
	var fax := cx + tw * 0.5 - 2.0
	if pf > 0.5:
		fax = cx + hd * 0.6 - 0.5
	elif absf(hd) > 0.5:
		fax = cx + hd * 1.1 - 1.0
	if moving:
		fax -= sw * 2.2
	elif _is_idle_phase(phase):
		fax -= arm_sw * 0.6
	_blk(img, fax, sho + 2.0, 3.0, 5.0, mid)
	_blk(img, fax, sho + 7.0, 3.0, 6.0, dark)
	_blk(img, fax - 0.5, sho + 13.0, 4.0, 2.0, deep)
	_blk(img, fax - 1.5, sho - 2.0, 4.0, 4.0, light)

	# --- 头（头盔，随躯干起伏）---
	var hw := 12.0
	var hx := cx - hw * 0.5 + hd
	var hyy := 4.0 + hy + bob - lean * 0.6
	_blk(img, cx - 2.0, hyy + 8.0, 4.0, 4.0, deep)
	_blk(img, hx, hyy, hw, 10.0, mid)
	_blk(img, hx, hyy, hw, 2.0, light)
	_blk(img, hx + 1.0, hyy + 2.0, hw - 2.0, 1.0, mid.darkened(0.40))
	_blk(img, hx + 1.0, hyy + 3.0, hw - 2.0, 4.0, deep)
	match vis:
		0:
			_blk(img, hx + 3.0, hyy + 4.0, hw - 6.0, 2.0, C_CYAN)
		1:
			_blk(img, hx + hw - 5.0, hyy + 4.0, 3.0, 2.0, C_CYAN)
		2:
			_blk(img, hx + 2.0, hyy + 4.0, 3.0, 2.0, C_CYAN)
		_:
			_blk(img, hx + 3.0, hyy + 4.0, hw - 6.0, 2.0, C_AMBER.darkened(0.5))
	_blk(img, hx + 1.0, hyy + 7.0, hw - 2.0, 2.0, mid.darkened(0.30))
	_blk(img, hx + hw - 4.0, hyy - 3.0, 1.0, 3.0, light)
	_blk(img, hx + hw - 5.0, hyy - 4.0, 3.0, 1.0, mid)

	_outline(img, line)
	return ImageTexture.create_from_image(img)


## 等距落影用的 2:1 菱形（unit = 横向半径，返回贴图宽 2*unit+2、高 unit+2）
static func iso_shadow_tex(unit: int = 16, alpha: float = 0.34) -> ImageTexture:
	var w := unit * 2 + 2
	var h := unit + 2
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cx := float(unit) + 1.0
	var cy := float(unit) * 0.5 + 1.0
	for y in h:
		for x in w:
			var u := absf((float(x) + 0.5 - cx) / float(unit))
			var v := absf((float(y) + 0.5 - cy) / (float(unit) * 0.5))
			if u + v <= 1.0:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, alpha))
	return ImageTexture.create_from_image(img)


static var _floor_cache := {}


## 整块等距地板贴图（半分辨率生成，精灵放大 2 倍用；按 biome 缓存）。
## 每像素反投影回逻辑坐标 → 铺 128 逻辑单位一格的棋盘，并在四条边加发光镶边。
static func iso_floor_tex(biome: int) -> ImageTexture:
	var key := clampi(biome, 0, 2)
	if _floor_cache.has(key):
		return _floor_cache[key]
	var pal: Array = BIOMES[key]
	var iw := 640
	var ih := 360
	var img := Image.create(iw, ih, false, Image.FORMAT_RGBA8)
	var t := 128.0
	var lit: Color = pal[0].lerp(pal[2], 0.35)
	var dim: Color = pal[1].lerp(pal[2], 0.18)
	var wall_c: Color = pal[2]
	var glow: Color = pal[3]
	for py in ih:
		for px in iw:
			var l := Iso.to_logical(Vector2(px * 2 + 1, py * 2 + 1))
			if l.x < 0.0 or l.y < 0.0 or l.x > Iso.VIEW_W or l.y > Iso.VIEW_H:
				continue
			var ti := int(floor(l.x / t))
			var tj := int(floor(l.y / t))
			var c := lit if ((ti + tj) & 1) == 0 else dim
			var fx := fmod(l.x, t)
			var fy := fmod(l.y, t)
			var gm := minf(minf(fx, t - fx), minf(fy, t - fy))
			if gm < 3.5:
				c = c.lerp(glow, 0.30 * (1.0 - gm / 3.5))
			var e := minf(minf(l.x, Iso.VIEW_W - l.x), minf(l.y, Iso.VIEW_H - l.y))
			if e < 10.0:
				c = c.lerp(glow, 0.55 * (1.0 - e / 10.0))
			elif e < 28.0:
				c = c.lerp(wall_c, 0.30)
			img.set_pixel(px, py, c)
	var tex := ImageTexture.create_from_image(img)
	_floor_cache[key] = tex
	return tex

