class_name PixelArt
## PixelArt —— 程序化生成像素风贴图（纯代码，无外部素材）。
## V1.2 扩展：三区块色板、门、宝箱、金币、细胞、卷轴、Boss、武器掉落物。

const PX := 1

# 三区块色板：[地板, 地板暗, 墙体, 氛围光]
const BIOMES := [
	[Color(0.055, 0.10, 0.125), Color(0.04, 0.075, 0.095), Color(0.10, 0.20, 0.24), Color(0.25, 0.84, 0.78)],
	[Color(0.09, 0.07, 0.15), Color(0.065, 0.05, 0.11), Color(0.18, 0.14, 0.28), Color(0.65, 0.55, 0.98)],
	[Color(0.125, 0.055, 0.055), Color(0.095, 0.04, 0.04), Color(0.28, 0.12, 0.11), Color(1.0, 0.42, 0.29)],
]


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


static func floor_tex(tile: int = 64, base: Color = Color(0.16, 0.17, 0.19)) -> ImageTexture:
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
	return circle_tex(28, Color(0.55, 1.0, 0.9), Color(0.1, 0.7, 0.62), Color(0.02, 0.35, 0.3))


static func enemy_tex(kind: int) -> ImageTexture:
	match kind:
		1:
			return square_tex(26, Color(0.72, 0.16, 0.12), Color(0.18, 0.03, 0.02), 4.0)
		2:
			return circle_tex(18, Color(0.95, 0.5, 0.16), Color(0.6, 0.2, 0.04), Color(0.25, 0.08, 0.0))
		3:
			return square_tex(24, Color(0.35, 0.75, 0.35), Color(0.05, 0.22, 0.08), 6.0)
		_:
			return square_tex(22, Color(0.83, 0.20, 0.20), Color(0.2, 0.03, 0.03), 2.0)


static func bullet_tex() -> ImageTexture:
	return circle_tex(10, Color(1, 0.95, 0.6), Color(1, 0.6, 0.1), Color(0.5, 0.2, 0.0))


# ---------------- V1.2 新增 ----------------

static func biome_floor_tex(biome: int, w: int, h: int) -> ImageTexture:
	## 按区块色板生成整块地板（32px 棋盘 + 缝线）。
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
	var seam := Color(0.03, 0.035, 0.04)
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
	var fill := Color(0.85, 0.15, 0.12) if locked else Color(0.25, 0.95, 0.45)
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
	var s := 16
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var half := s * 0.5
	for y in s:
		for x in s:
			var d := absf(x + 0.5 - half) + absf(y + 0.5 - half)
			if d > half + 2.0:
				continue
			var col := Color(0.35, 1.0, 0.85) if d < half * 0.5 else Color(0.08, 0.55, 0.48)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func scroll_tex(color: Color) -> ImageTexture:
	return circle_tex(26, color.lightened(0.35), color, color.darkened(0.5))


static func weapon_drop_tex(color: Color) -> ImageTexture:
	return square_tex(28, color, color.darkened(0.55), 5.0)


static func boss_tex(kind: int) -> ImageTexture:
	match kind:
		1:
			return circle_tex(84, Color(0.75, 0.35, 0.95), Color(0.32, 0.10, 0.45), Color(0.10, 0.03, 0.16))
		2:
			return circle_tex(108, Color(1.0, 0.45, 0.28), Color(0.55, 0.14, 0.06), Color(0.14, 0.03, 0.02))
		_:
			return circle_tex(64, Color(0.30, 0.85, 0.95), Color(0.06, 0.38, 0.48), Color(0.01, 0.14, 0.18))
