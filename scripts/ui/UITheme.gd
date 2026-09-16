class_name UITheme
## UITheme.gd —— V1.3 界面视觉层（纯代码，零外部素材）。
##
## 把「终端 / 机箱仪表」风格的面板底、边框、角标、图标、发光线集中成静态方法，
## 供 HUD 与各菜单面板复用，保证全局视觉一致：
##   · 面板底  —— panel()   9-slice 渐变 + 描边（顶边高亮），任意尺寸不变形
##   · 条形槽  —— bar_slot() HP / 过载 / Boss 血条的凹槽
##   · 角标    —— corner_brackets() 四角 L 形刻度，HUD「仪器感」的主要来源
##   · 图标    —— icon() 直接取 PixelArt.icon_tex()
## 设计规范沿用 PixelArt：深蓝黑底 + 冷青主色 + 琥珀告警 + 稀有紫。

const CYAN := Color(0.42, 0.95, 0.84)
const CYAN_DIM := Color(0.26, 0.90, 0.82)
const AMBER := Color(1.00, 0.70, 0.28)
const RED := Color(1.00, 0.36, 0.41)
const PURPLE := Color(0.71, 0.55, 1.00)
const GREEN := Color(0.35, 0.95, 0.55)
const TEXT := Color(0.88, 0.94, 0.90)
const DIM := Color(0.52, 0.60, 0.62)
const GOLD := Color(1.00, 0.85, 0.35)
const CELL := Color(0.50, 0.95, 0.92)
const ENERGY := Color(1.00, 0.82, 0.32)
const SOURCE := Color(0.30, 1.00, 0.80)

const BAR_BG := Color(0.045, 0.065, 0.082, 0.94)


## 9-slice 面板底：纵向渐变 + 1px 描边（顶边 accent 提亮）
static func panel(accent: Color = CYAN, margin: float = 10.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = PixelArt.panel_slice_texture(accent)
	sb.set_texture_margin_all(6.0)
	sb.set_content_margin_all(margin)
	return sb


## 9-slice 面板 + 调用方自定义内边距（替换各面板里的 StyleBoxFlat 手搓底）
static func panel_slice(accent: Color, ml: float, mr: float, mt: float, mb: float) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = PixelArt.panel_slice_texture(accent)
	sb.set_texture_margin_all(6.0)
	sb.content_margin_left = ml
	sb.content_margin_right = mr
	sb.content_margin_top = mt
	sb.content_margin_bottom = mb
	return sb


## 纯色描边面板（需要完全不透明 / 极小时用）
static func panel_flat(accent: Color = CYAN, alpha: float = 0.90,
		margin: float = 10.0, radius: int = 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.028, 0.045, 0.058, alpha)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.60)
	sb.set_border_width_all(1)
	sb.border_width_top = 2
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


## 条形槽（HP / 过载 / Boss 血条底）
static func bar_slot(accent: Color, radius: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BAR_BG
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	return sb


## 细线（分隔 / 强调）
static func hairline(parent: Control, at: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = at
	r.size = size
	parent.add_child(r)
	return r


## 四角 L 形角标：at = 左上角，box = 尺寸
static func corner_brackets(parent: Control, at: Vector2, box: Vector2, color: Color,
		arm: float = 9.0, thick: float = 2.0) -> void:
	for i in 4:
		var right: bool = (i == 1 or i == 3)
		var bottom: bool = (i == 2 or i == 3)
		var x: float = at.x + box.x if right else at.x
		var y: float = at.y + box.y if bottom else at.y
		var h := ColorRect.new()
		h.color = color
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.position = Vector2(x - arm if right else x, y - thick if bottom else y)
		h.size = Vector2(arm, thick)
		parent.add_child(h)
		var v := ColorRect.new()
		v.color = color
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.position = Vector2(x - thick if right else x, y - arm if bottom else y)
		v.size = Vector2(thick, arm)
		parent.add_child(v)


## 矢量图标（TextureRect 包装）
static func icon(parent: Control, at: Vector2, px: int, kind: String, color: Color) -> TextureRect:
	var t := TextureRect.new()
	t.texture = PixelArt.icon_tex(kind, px, color)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.position = at
	t.size = Vector2(px, px)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t


## 给 Label 套上「发光 / 描边」主题（深底、亮底上都能读）
static func glow_label(l: Label, color: Color = TEXT, glow: Color = Color(0.02, 0.05, 0.06, 0.92),
		outline: int = 3) -> Label:
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", glow)
	l.add_theme_constant_override("outline_size", outline)
	return l
