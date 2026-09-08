extends Control
## MainMenu.gd —— V1.1 启动主菜单（像素地牢风、双语）。
## 提供：开始游戏 / 语言和设置 / 退出。
## 语言切换即时刷新全界面；开始游戏进入 main_game.tscn。

const W := 1280
const H := 720

const COL_TITLE := Color(0.5, 0.95, 0.6)
const COL_TITLE_DIM := Color(0.55, 0.75, 1.0)
const COL_TEXT := Color(0.9, 0.95, 0.9)
const COL_TEXT_DIM := Color(0.55, 0.62, 0.6)
const COL_PANEL_BG := Color(0.015, 0.02, 0.035, 0.86)
const COL_BORDER := Color(0.32, 0.55, 0.8, 0.9)

var _box: VBoxContainer
var _start_btn: Button
var _lang_btn: Button
var _quit_btn: Button
var _settings_panel: Control


func _ready() -> void:
	_build_bg()
	_build_ui()
	_refresh_all_texts()
	Lang.language_changed.connect(_refresh_all_texts)
	var panel_script: GDScript = load("res://scripts/menu/LanguageSettingsPanel.gd")
	_settings_panel = panel_script.new()
	add_child(_settings_panel)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.35)


func _build_bg() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	# 地板棋盘（暗蓝紫）
	var s := 32
	var light_c := Color(0.11, 0.125, 0.16)
	var dark_c := Color(0.082, 0.092, 0.115)
	for gy in range(H / s):
		for gx in range(W / s):
			var col := light_c if (gx + gy) % 2 == 0 else dark_c
			if (gx * 7 + gy * 13) % 11 == 0:
				col = col.darkened(0.10)
			img.fill_rect(Rect2i(gx * s, gy * s, s, s), col)
	# 地板分隔线
	var seam := Color(0.045, 0.05, 0.06)
	for y in range(0, H, s):
		img.fill_rect(Rect2i(0, y, W, 2), seam)
	for x in range(0, W, s):
		img.fill_rect(Rect2i(x, 0, 2, H), seam)
	# 四边墙体
	var wall_c := Color(0.24, 0.26, 0.30)
	img.fill_rect(Rect2i(0, 0, W, 26), wall_c)
	img.fill_rect(Rect2i(0, H - 26, W, 26), wall_c)
	img.fill_rect(Rect2i(0, 26, 26, H - 52), wall_c)
	img.fill_rect(Rect2i(W - 26, 26, 26, H - 52), wall_c)
	# 内沿亮线
	var edge := Color(0.5, 0.55, 0.58)
	img.fill_rect(Rect2i(26, 24, W - 52, 2), edge)
	img.fill_rect(Rect2i(26, H - 26, W - 52, 2), edge)
	img.fill_rect(Rect2i(24, 26, 2, H - 52), edge)
	img.fill_rect(Rect2i(W - 26, 26, 2, H - 52), edge)
	var tex := ImageTexture.create_from_image(img)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(sprite)


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL_BG
	sb.border_color = COL_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 72.0
	sb.content_margin_right = 72.0
	sb.content_margin_top = 46.0
	sb.content_margin_bottom = 40.0
	return sb


func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	panel.add_child(_box)

	var title := Label.new()
	title.name = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COL_TITLE)
	title.add_theme_font_size_override("font_size", 64)
	_box.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "SubtitleLabel"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", COL_TITLE_DIM)
	subtitle.add_theme_font_size_override("font_size", 22)
	_box.add_child(subtitle)

	var hint := Label.new()
	hint.name = "HintLabel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", COL_TEXT_DIM)
	hint.add_theme_font_size_override("font_size", 14)
	_box.add_child(hint)

	var sep0 := HSeparator.new()
	sep0.modulate = Color(1, 1, 1, 0.25)
	_box.add_child(sep0)

	# 开始游戏
	_start_btn = _menu_button()
	_box.add_child(_start_btn)
	_start_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main_game.tscn")
	)
	_new_sub_helper(_start_btn, "StartSubLabel")

	var sep1 := HSeparator.new()
	sep1.modulate = Color(1, 1, 1, 0.25)
	_box.add_child(sep1)

	# 语言和设置
	_lang_btn = _menu_button()
	_box.add_child(_lang_btn)
	_lang_btn.pressed.connect(_open_settings)
	_new_sub_helper(_lang_btn, "LangSubLabel")

	# 退出
	_quit_btn = _menu_button()
	_box.add_child(_quit_btn)
	_quit_btn.pressed.connect(func() -> void: get_tree().quit())
	_new_sub_helper(_quit_btn, "QuitSubLabel")


func _new_sub_helper(btn: Button, sub_name: String) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_child(row)
	var sub := Label.new()
	sub.name = sub_name
	sub.add_theme_color_override("font_color", COL_TEXT_DIM)
	sub.add_theme_font_size_override("font_size", 14)
	row.add_child(sub)
	btn.set_meta("sub_label", sub)


func _menu_button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(480, 56)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", COL_TITLE)
	b.add_theme_color_override("font_pressed_color", COL_TITLE)
	b.add_theme_stylebox_override("normal", _btn_style(Color(0.03, 0.05, 0.07), Color(0.25, 0.42, 0.6)))
	b.add_theme_stylebox_override("hover", _btn_style(Color(0.05, 0.09, 0.12), Color(0.4, 0.7, 0.9)))
	b.add_theme_stylebox_override("pressed", _btn_style(Color(0.07, 0.13, 0.16), COL_TITLE))
	b.add_theme_stylebox_override("focus", _btn_style(Color(0.03, 0.05, 0.07), Color(0.0, 0.0, 0.0, 0.0)))
	b.focus_mode = Control.FOCUS_NONE
	return b


func _btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 30.0
	sb.content_margin_right = 30.0
	return sb


func _refresh_all_texts() -> void:
	var title: Label = _box.get_node_or_null("TitleLabel")
	if title:
		title.text = Lang.t("game_title_en")
	var sub: Label = _box.get_node_or_null("SubtitleLabel")
	if sub:
		sub.text = Lang.t("game_title")
	var hint: Label = _box.get_node_or_null("HintLabel")
	if hint:
		hint.text = Lang.t("menu_hint")
	_start_btn.text = Lang.t("menu_start")
	_lang_btn.text = Lang.t("menu_language")
	_quit_btn.text = Lang.t("menu_quit")
	var ssub: Label = _start_btn.get_meta("sub_label")
	if ssub:
		ssub.text = Lang.t("menu_start_sub")
	var lsub: Label = _lang_btn.get_meta("sub_label")
	if lsub:
		lsub.text = Lang.t("menu_language_sub")
	var qsub: Label = _quit_btn.get_meta("sub_label")
	if qsub:
		qsub.text = Lang.t("menu_quit_sub")


func _open_settings() -> void:
	_settings_panel.show_panel()
