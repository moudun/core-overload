class_name Iso
## Iso.gd —— 等距（2:1 斜 45°）投影工具。
##
## 设计前提：**逻辑层完全不动**。所有物理、碰撞、AI、房间生成仍跑在原来的
## 1:1 俯视逻辑坐标里；本模块只负责把逻辑坐标换算成屏幕上的等距坐标。
## 这样既拿到 2.5D 的画面，又不用碰任何一条已经调好的手感参数。
##
## 投影公式（2:1 等距）：
##     sx = (x - y) * 0.5 * SCALE + origin.x
##     sy = (x + y) * 0.25 * SCALE + origin.y
## 反解用于两件事：鼠标瞄准反投影、以及按像素生成地板贴图。

const SCALE := 1.18          ## 逻辑单位 → 等距单位
const VIEW_W := 1280.0       ## 逻辑场地宽（与 RoomFactory.W 一致）
const VIEW_H := 720.0        ## 逻辑场地高
const HALF_H := 0.5 * VIEW_H


## 逻辑原点在屏幕上的落点：把整块菱形居中放进 HUD 之下的可玩区
static func origin() -> Vector2:
	var dw := (VIEW_W + VIEW_H) * 0.5 * SCALE
	var dh := (VIEW_W + VIEW_H) * 0.25 * SCALE
	var top := 84.0                       # 让菱形整体落在 HUD 顶栏（64px）之下
	return Vector2(
		(1280.0 - dw) * 0.5 + HALF_H * SCALE,
		top + (720.0 - top - dh) * 0.5)


## 逻辑坐标 → 屏幕坐标
static func to_screen(v: Vector2) -> Vector2:
	return Vector2((v.x - v.y) * 0.5, (v.x + v.y) * 0.25) * SCALE + origin()


## 屏幕坐标 → 逻辑坐标（鼠标瞄准用）
static func to_logical(p: Vector2) -> Vector2:
	var q := (p - origin()) / SCALE
	var sx := q.y * 4.0        # x + y
	var dx := q.x * 2.0        # x - y
	return Vector2((sx + dx) * 0.5, (sx - dx) * 0.5)


## 方向向量版（无平移），用于把屏幕上的朝向换算回逻辑朝向
static func dir_to_logical(d: Vector2) -> Vector2:
	return Vector2(d.x + d.y * 2.0, d.y * 2.0 - d.x) * 0.5


## 方向向量版：逻辑 → 屏幕
static func dir_to_screen(d: Vector2) -> Vector2:
	return Vector2((d.x - d.y) * 0.5, (d.x + d.y) * 0.25)


## 深度：屏幕上越靠下（x+y 越大）越靠前
static func depth(v: Vector2) -> float:
	return v.x + v.y


## 深度 → z_index（等距遮挡排序）。逻辑 (0,0) → -28，逻辑 (1280,720) → 34
static func z_of(v: Vector2) -> int:
	return int(clampf(depth(v) * 0.03125 - 28.0, -200.0, 200.0))


## 屏幕朝向 → 8 向索引（0=右, 2=下, 4=左, 6=上，顺时针）
## 注意：必须用 posmod 而不是 %。GDScript 的 % 对负数取余结果仍是负数
## （-3 % 8 == -3），atan2 返回负角时会把索引漏到 [-4, 4] 区间外。
static func dir8_of_screen(v: Vector2) -> int:
	if v.length_squared() < 0.0001:
		return 2
	return posmod(int(round(atan2(v.y, v.x) / (TAU / 8.0))), 8)


## 逻辑朝向 → 8 向索引（先投影再取整，保证「看起来朝哪就画哪张」）
static func dir8_of_logical(v: Vector2) -> int:
	return dir8_of_screen(dir_to_screen(v))
