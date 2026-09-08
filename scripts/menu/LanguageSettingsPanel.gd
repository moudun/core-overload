extends Control
## LanguageSettingsPanel.gd —— V1.1 “语言和设置”面板。
## 覆盖在主菜单之上：界面语言（中文/English）+ 音效音量。
## 语言变更即时生效；音量立即写入 Settings。

const COL_DIM_BG := Color(0.01, 0.015, 0.03, 0.9)
const COL_PANEL_BG := Color(0.02, 0.03, 0.05, 0.98)
const COL_BORDER := Color(0.32, 0.55, 0.8, 0.95)
const COL_SYS := Color(0.5, 0.95, 0.6)
const COL_TEXT := Color(0.9, 0.95, 0.9)
const COL_TEXT_DIM := Color(0.55, 0.62, 0.6)
const COL_WARN := Color(1.0, 0.75, 0.35)

var _dim: ColorRect
var _box: VBoxContainer
var _lang_zh_btn: Button
var _lang_en_btn: Button
var _volume_value: Label

signal closed


func _ready() -> void:
	_build_ui()
	visible = false
	Lang.language_changed.connect(_refresh_all_texts)


func show_panel() -> void:
	_refresh_all_texts()
	visible = true


func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim = ColorRect.new()
	_dim.color = COL_DIM_BG
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL_BG
	sb.border_color = COL_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 44.0
	sb.content_margin_right = 44.0
	sb.content_margin_top = 30.0
	sb.content_margin_bottom = 30.0
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	panel.add_child(_box)

	var title := Label.new()
	title.name = "PanelTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)

	# 语言组
	var lang_title := Label.new()
	lang_title.name = "LangTitle"
	lang_title.add_theme_color_override("font_color", COL_TEXT_DIM)
	_box.add_child(lang_title)
	var lang_row := HBoxContainer.new()
	lang_row.alignment = BoxContainer.ALIGNMENT_CENTER
	lang_row.add_theme_constant_override("separation", 18)
	_box.add_child(lang_row)
	_lang_zh_btn = _make_option_button()
	lang_row.add_child(_lang_zh_btn)
	_lang_en_btn = _make_option_button()
	lang_row.add_child(_lang_en_btn)
	_lang_zh_btn.pressed.connect(func() -> void: Lang.apply("zh"))
	_lang_en_btn.pressed.connect(func() -> void: Lang.apply("en"))

	var sep1 := HSeparator.new()
	sep1.modulate = Color(1, 1, 1, 0.25)
	_box.add_child(sep1)

	# 音量组
	var sfx_title := Label.new()
	sfx_title.name = "SfxTitle"
	sfx_title.add_theme_color_override("font_color", COL_TEXT_DIM)
	_box.add_child(sfx_title)
	var vol_row := HBoxContainer.new()
	vol_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vol_row.add_theme_constant_override("separation", 12)
	_box.add_child(vol_row)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(300, 26)
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = Settings.sfx_volume_percent
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float) -> void:
		Settings.set_volume_percent(int(v))
		_volume_value.text = "%d%%" % int(v)
	)
	vol_row.add_child(slider)
	_volume_value = Label.new()
	_volume_value.custom_minimum_size = Vector2(72, 0)
	_volume_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_volume_value.add_theme_color_override("font_color", COL_WARN)
	vol_row.add_child(_volume_value)

	var sep2 := HSeparator.new()
	sep2.modulate = Color(1, 1, 1, 0.25)
	_box.add_child(sep2)

	var back_btn := Button.new()
	back_btn.name = "BackBtn"
	back_btn.custom_minimum_size = Vector2(220, 46)
	back_btn.add_theme_font_size_override("font_size", 21)
	back_btn.add_theme_color_override("font_color", COL_TEXT)
	back_btn.add_theme_color_override("font_hover_color", COL_SYS)
	back_btn.add_theme_stylebox_override("normal", _box_style(Color(0.04, 0.07, 0.09), COL_BORDER))
	back_btn.add_theme_stylebox_override("hover", _box_style(Color(0.06, 0.11, 0.14), Color(0.4, 0.7, 0.9)))
	back_btn.add_theme_stylebox_override("pressed", _box_style(Color(0.08, 0.15, 0.18), COL_SYS))
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.pressed.connect(func() -> void:
		visible = false
		closed.emit()
	)
	var back_center := CenterContainer.new()
	back_center.add_child(back_btn)
	_box.add_child(back_center)

	_refresh_all_texts()


func _make_option_button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(180, 46)
	b.add_theme_font_size_override("font_size", 21)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _box_style(Color(0.03, 0.05, 0.07), Color(0.25, 0.42, 0.6)))
	b.add_theme_stylebox_override("hover", _box_style(Color(0.05, 0.09, 0.12), Color(0.4, 0.7, 0.9)))
	b.add_theme_stylebox_override("pressed", _box_style(Color(0.07, 0.13, 0.16), COL_SYS))
	return b


func _box_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	return sb


func _refresh_all_texts() -> void:
	var title: Label = _box.get_node_or_null("PanelTitle")
	if title:
		title.text = Lang.t("settings_title")
		title.add_theme_color_override("font_color", COL_SYS)
		title.add_theme_font_size_override("font_size", 30)
	var lt: Label = _box.get_node_or_null("LangTitle")
	if lt:
		lt.text = Lang.t("settings_language")
		lt.add_theme_font_size_override("font_size", 18)
	var st: Label = _box.get_node_or_null("SfxTitle")
	if st:
		st.text = Lang.t("settings_volume")
		st.add_theme_font_size_override("font_size", 18)
	var bb: Button = _box.get_node_or_null("BackBtn")
	if bb:
		bb.text = Lang.t("back")
	_lang_zh_btn.text = Lang.t("lang_zh")
	_lang_en_btn.text = Lang.t("lang_en")
	_volume_value.text = "%d%%" % Settings.sfx_volume_percent
	_highlight_options()


func _highlight_options() -> void:
	_apply_option_highlight(_lang_zh_btn, Lang.is_zh())
	_apply_option_highlight(_lang_en_btn, not Lang.is_zh())


func _apply_option_highlight(btn: Button, active: bool) -> void:
	btn.add_theme_color_override("font_color", COL_SYS if active else COL_TEXT_DIM)
	if active:
		btn.add_theme_stylebox_override("normal", _box_style(Color(0.05, 0.12, 0.09), COL_SYS))
	else:
		btn.add_theme_stylebox_override("normal", _box_style(Color(0.03, 0.05, 0.07), Color(0.25, 0.42, 0.6)))
