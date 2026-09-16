extends Control
## IntroComic —— 开场漫画引导（4 页）。
##
## 为什么做成纯代码 Control 而不是 .tscn：和项目其它 UI 一致（HUD / RouteMap 都是代码搭的），
## 而且它需要在任何分辨率下整页缩放显示，代码里算 scale 比在编辑器里对锚点更直接。
##
## 交互：
##   → / D / 空格 / 左键   下一页
##   ← / A                 上一页
##   Esc                   跳过整段
##   最后一页自动把 intro_seen 写进 meta.json
##
## 图片来自 res://assets/story-comic/*.png（不是 output/，原因见下）。

signal finished

## 图片来自 res://assets/story-comic/*.png。
## ⚠️ 必须放在 assets/ 而不是 output/ —— 导出预设里 output/* 是**排除**的（那是截图产物目录），
## 放那儿打包不进 exe。
const PAGES := [
	"res://assets/story-comic/01_page_awakening.png",
	"res://assets/story-comic/02_page_overload.png",
	"res://assets/story-comic/03_page_loot.png",
	"res://assets/story-comic/04_page_controls.png",
]

const COL_ACCENT := Color(0.26, 0.90, 0.82)
const COL_DIM := Color(0.52, 0.60, 0.62)

var _idx := 0
var _tex_rect: TextureRect
var _page_label: Label
var _hint_label: Label
var _dots: Array = []
var _fade: ColorRect
var _busy := false
var _adv_prev := false
var _back_prev := false
var _click_prev := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_show_page(0, false)
	# 入场淡入
	_fade.color = Color(0, 0, 0, 1)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.35)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.024, 0.036, 0.050)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 整页画面（按比例缩放，永远完整显示不裁切）
	_tex_rect = TextureRect.new()
	_tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tex_rect)

	# 底部黑带 + 页码
	var band := ColorRect.new()
	band.color = Color(0.016, 0.026, 0.036, 0.92)
	band.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	band.offset_top = -52.0
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)

	_page_label = Label.new()
	_page_label.position = Vector2(28, 0)
	_page_label.size = Vector2(200, 52)
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.add_theme_font_size_override("font_size", 15)
	_page_label.modulate = COL_ACCENT
	band.add_child(_page_label)

	_hint_label = Label.new()
	_hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_label.offset_top = -52.0
	_hint_label.offset_bottom = -8.0
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.modulate = COL_DIM
	band.add_child(_hint_label)

	# 页码点
	for i in PAGES.size():
		var dot := ColorRect.new()
		dot.size = Vector2(22, 4)
		dot.position = Vector2(640.0 - float(PAGES.size()) * 14.0 + float(i) * 28.0, 690)
		dot.color = Color(0.10, 0.16, 0.19)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dot)
		_dots.append(dot)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	_refresh_texts()


func _refresh_texts() -> void:
	_hint_label.text = Lang.t("intro_hint")
	_page_label.text = Lang.f("intro_page", [_idx + 1, PAGES.size()])


func _show_page(i: int, animate: bool = true) -> void:
	_idx = clampi(i, 0, PAGES.size() - 1)
	var path: String = PAGES[_idx]
	if ResourceLoader.exists(path):
		_tex_rect.texture = load(path)
	else:
		# 图片缺失时不要白屏：给一个占位提示，方便排查导出漏打包
		_tex_rect.texture = null
	for k in _dots.size():
		_dots[k].color = COL_ACCENT if k <= _idx else Color(0.10, 0.16, 0.19)
	_refresh_texts()
	if animate:
		_fade.color = Color(0, 0, 0, 0.65)
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", 0.0, 0.22)


func _next() -> void:
	if _busy:
		return
	if _idx >= PAGES.size() - 1:
		_finish()
		return
	_show_page(_idx + 1)


func _back() -> void:
	if _busy:
		return
	_show_page(_idx - 1)


func _finish() -> void:
	_busy = true
	MetaState.mark_intro_seen()
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.28)
	tw.tween_callback(func():
		finished.emit()
		queue_free())


func _process(_delta: float) -> void:
	# 轮询而不是 _input：本面板可能被塞进 CanvasLayer，用轮询最省事且不受焦点影响
	var a := Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D) \
		or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER)
	if a and not _adv_prev:
		_next()
	_adv_prev = a

	var b := Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)
	if b and not _back_prev:
		_back()
	_back_prev = b

	if Input.is_key_pressed(KEY_ESCAPE):
		_finish()

	var click := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if click and not _click_prev:
		_next()
	_click_prev = click
