extends CanvasLayer
## HUD —— 顶栏状态（HP/护盾/波次/击杀/得分）、Banner、右下提示、教程与结算层。
## 纯代码构建，语言切换即时刷新。

const COLOR_BAR_BG := Color(0.07, 0.09, 0.10, 0.9)
const COLOR_HP_GOOD := Color(0.30, 0.95, 0.45)
const COLOR_HP_MID := Color(0.98, 0.78, 0.20)
const COLOR_HP_LOW := Color(0.95, 0.25, 0.20)

var _hp_fg: ColorRect
var _shield_label: Label
var _stats_label: Label
var _banner: Label
var _banner_t := 0.0
var _toast: Label
var _toast_t := 0.0
var _tutorial_panel: PanelContainer
var _overlay: Control
var _overlay_title: Label
var _overlay_stats: Label
var _overlay_hint: Label
var _game_title: Label


func _ready() -> void:
	layer = 20
	_build()
	_refresh_all()
	# 事件订阅
	EventBus.core_hp_changed.connect(_on_core_hp)
	EventBus.kills_changed.connect(_on_kills)
	EventBus.wave_changed.connect(_on_wave)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.card_picked.connect(_on_card_picked)
	EventBus.game_over.connect(_on_game_over)
	Lang.language_changed.connect(func(_c): _refresh_all())


func _process(delta: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t <= 0.0:
			_banner.modulate.a = 0.0
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast.modulate.a = 0.0


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ---- 顶栏底 ----
	var top := ColorRect.new()
	top.color = Color(0.03, 0.04, 0.05, 0.86)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 44
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)

	# HP 条
	var hp_bg := ColorRect.new()
	hp_bg.color = COLOR_BAR_BG
	hp_bg.position = Vector2(18, 12)
	hp_bg.size = Vector2(230, 20)
	root.add_child(hp_bg)
	_hp_fg = ColorRect.new()
	_hp_fg.color = COLOR_HP_GOOD
	_hp_fg.position = Vector2(20, 14)
	_hp_fg.size = Vector2(226, 16)
	root.add_child(_hp_fg)

	var hp_txt := Label.new()
	hp_txt.position = Vector2(24, 13)
	hp_txt.add_theme_font_size_override("font_size", 14)
	hp_txt.add_theme_color_override("font_color", Color(0.05, 0.08, 0.05))
	root.add_child(hp_txt)
	_hp_label = hp_txt

	_shield_label = Label.new()
	_shield_label.position = Vector2(258, 15)
	_shield_label.add_theme_font_size_override("font_size", 14)
	_shield_label.add_theme_color_override("font_color", Color(0.45, 0.7, 1.0))
	root.add_child(_shield_label)

	_game_title = Label.new()
	_game_title.position = Vector2(430, 6)
	_game_title.size = Vector2(420, 20)
	_game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_title.add_theme_font_size_override("font_size", 20)
	_game_title.add_theme_color_override("font_color", Color(0.85, 0.9, 0.85))
	root.add_child(_game_title)

	_stats_label = Label.new()
	_stats_label.position = Vector2(880, 8)
	_stats_label.size = Vector2(380, 30)
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stats_label.add_theme_font_size_override("font_size", 15)
	_stats_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.75))
	root.add_child(_stats_label)

	# 中央 Banner
	_banner = Label.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_top = 90
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 34)
	_banner.add_theme_color_override("font_color", Color(1.0, 0.55, 0.25))
	_banner.modulate.a = 0.0
	root.add_child(_banner)

	# 右下 Toast
	_toast = Label.new()
	_toast.position = Vector2(14, 0)
	_toast.add_theme_font_size_override("font_size", 16)
	_toast.add_theme_color_override("font_color", Color(0.95, 1.0, 0.9))
	_toast.modulate.a = 0.0
	var toast_layer := Control.new()
	toast_layer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	toast_layer.offset_left = 24
	toast_layer.offset_top = -130
	toast_layer.offset_bottom = -20
	toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_layer.add_child(_toast)
	root.add_child(toast_layer)

	# 结算遮罩
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.78)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	root.add_child(_overlay)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(520, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_overlay.add_child(box)

	_overlay_title = Label.new()
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_title.add_theme_font_size_override("font_size", 64)
	_overlay_title.add_theme_color_override("font_color", Color(0.98, 0.25, 0.2))
	box.add_child(_overlay_title)
	_overlay_stats = Label.new()
	_overlay_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_stats.add_theme_font_size_override("font_size", 22)
	_overlay_stats.add_theme_color_override("font_color", Color(0.85, 0.9, 0.85))
	box.add_child(_overlay_stats)
	_overlay_hint = Label.new()
	_overlay_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_hint.add_theme_font_size_override("font_size", 20)
	_overlay_hint.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	box.add_child(_overlay_hint)


func show_tutorial(lines: Array) -> void:
	# 教程面板：左下角显示 4 行操作说明，跟随语言刷新由外部刷新
	var p := PanelContainer.new()
	p.position = Vector2(24, 560)
	p.custom_minimum_size = Vector2(560, 120)
	p.add_theme_stylebox_override("panel", _panel_style())
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	p.add_child(vb)
	for line in lines:
		var l := Label.new()
		l.text = line
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", Color(0.82, 0.9, 0.82))
		vb.add_child(l)
	add_child(p)
	_tutorial_panel = p


func hide_tutorial() -> void:
	if _tutorial_panel != null and is_instance_valid(_tutorial_panel):
		_tutorial_panel.queue_free()
		_tutorial_panel = null


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.05, 0.82)
	sb.border_color = Color(0.35, 0.6, 0.5, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


# ---- 事件回调 ----
func _on_core_hp() -> void:
	var ratio := float(GameState.core_hp) / float(GameState.CORE_MAX)
	_hp_fg.size.x = maxf(0.0, 226.0 * ratio)
	_hp_fg.color = COLOR_HP_GOOD if ratio > 0.55 else (COLOR_HP_MID if ratio > 0.25 else COLOR_HP_LOW)
	_hp_label.text = "%s %d / %d" % [Lang.t("hud_hp"), GameState.core_hp, GameState.CORE_MAX]
	_shield_label.text = (Lang.t("hud_shield") + " %d" % GameState.shield) if GameState.shield > 0 else ""


func _on_kills(_k: int) -> void:
	_stats_label.text = "%s %d    %s %d    %s %d" % [
		Lang.t("hud_wave"), GameState.wave,
		Lang.t("hud_kills"), GameState.kills,
		Lang.t("hud_score"), GameState.score
	]


func _on_wave(wave: int) -> void:
	_on_kills(GameState.kills)
	_banner.modulate.a = 1.0
	_banner.text = Lang.f("wave_incoming", [wave])
	_banner_t = 2.6
	hide_tutorial()


func _on_wave_cleared(wave: int) -> void:
	_banner.modulate.a = 1.0
	_banner.text = Lang.f("wave_cleared", [wave, 3])
	_banner_t = 2.2


func _on_card_picked(id: String) -> void:
	_toast.modulate.a = 1.0
	_toast.text = "%s %s — %s" % [Lang.t("picked_prefix"), Lang.t("card_" + id), Lang.t("card_" + id + "_desc")]
	_toast_t = 3.2


func _on_game_over() -> void:
	_overlay.visible = true
	_overlay_stats.text = Lang.f("game_over_stats", [GameState.kills, GameState.wave, GameState.score])
	_overlay_hint.text = Lang.t("restart_hint")
	_overlay_title.text = Lang.t("game_over_title")


func hide_game_over() -> void:
	_overlay.visible = false


func _refresh_all() -> void:
	_on_core_hp()
	_on_kills(GameState.kills)
	_game_title.text = Lang.t("game_title_en")


var _hp_label: Label
