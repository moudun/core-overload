class_name PixelArt
## PixelArt —— 程序化生成像素风贴图（纯代码，无外部素材）。
## 所有贴图统一在运行时生成，风格：粗像素、高对比、暗色描边。

const PX := 1  # 像素粒度，1px 一个“像素点”（可整体放大获得更粗颗粒）


static func circle_tex(size: int, core: Color, glow: Color, rim: Color) -> ImageTexture:
	## 圆点：中心亮 core -> 外圈 glow -> 1px 深色 rim。
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
	## 圆角方块（尖角怪/卡牌通用）。
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
	## 掉落卡牌：浅色描边 + 彩色芯 + 白色高光条。
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


static func floor_tex(tile: int = 64, base: Color = Color(0.16, 0.17, 0.19)) -> ImageTexture:
	## 石砖地板：每 tile 内做 4x4 砖缝 + 噪点。
	var img := Image.create(tile, tile, false, Image.FORMAT_RGBA8)
	var brick := tile / 4
	for y in tile:
		for x in tile:
			var col := base
			var in_v := x % brick
			var in_h := y % brick
			if in_v < 1 or in_h < 1:
				col = Color(0.06, 0.06, 0.075)
			elif in_v == 2 or in_h == 2:
				col = base.lightened(0.06)
			if ((x * 31 + y * 17) % 13) == 0:
				col = base.darkened(0.12)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func wall_tile() -> ImageTexture:
	## 边界墙砖：暗金属边框 + 铆钉。
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var brick := s / 4
	for y in s:
		for x in s:
			var col := Color(0.22, 0.23, 0.26)
			if (x % brick) < 1 or (y % brick) < 1:
				col = Color(0.10, 0.10, 0.12)
			if x < 2 or y < 2 or x >= s - 2 or y >= s - 2:
				col = Color(0.31, 0.32, 0.36)
			if ((x - 6) * (x - 6) + (y - 6) * (y - 6)) < 4 or ((x - s + 7) * (x - s + 7) + (y - 6) * (y - 6)) < 4 \
				or ((x - 6) * (x - 6) + (y - s + 7) * (y - s + 7)) < 4 or ((x - s + 7) * (x - s + 7) + (y - s + 7) * (y - s + 7)) < 4:
				col = Color(0.5, 0.5, 0.55)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func player_core_tex() -> ImageTexture:
	## 玩家核心：大圆 + 内芯 + 呼吸感留白由动画控制。
	return circle_tex(28, Color(0.55, 1.0, 0.9), Color(0.1, 0.7, 0.62), Color(0.02, 0.35, 0.3))


static func enemy_tex(kind: int) -> ImageTexture:
	match kind:
		1:  # brute 重甲
			return square_tex(26, Color(0.72, 0.16, 0.12), Color(0.18, 0.03, 0.02), 4.0)
		2:  # runner 快速小怪
			return circle_tex(18, Color(0.95, 0.5, 0.16), Color(0.6, 0.2, 0.04), Color(0.25, 0.08, 0.0))
		_:  # normal 普通
			return square_tex(22, Color(0.83, 0.20, 0.20), Color(0.2, 0.03, 0.03), 2.0)


static func bullet_tex() -> ImageTexture:
	return circle_tex(10, Color(1, 0.95, 0.6), Color(1, 0.6, 0.1), Color(0.5, 0.2, 0.0))
