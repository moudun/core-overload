extends Control
## MainMenu.gd —— V1.3 启动主菜单（终端 / 系统拓扑风格、双语）。
##
## 入口：新的一局 · 继续 Run（断点存档）· 收集者 · 收藏者档案 · 挑战词缀 ·
##       语言和设置 · 退出。
## 「继续 Run」把存档 payload 交给 RunDirector.pending_resume，由 MainGame 消费。

const W := 1280
const H := 720

const COL_TITLE := Color(0.42, 0.95, 0.84)
const COL_TITLE_DIM := Color(0.55, 0.78, 1.0)
const COL_TEXT := Color(0.88, 0.94, 0.90)
const COL_TEXT_DIM := Color(0.52, 0.60, 0.60)
const COL_PANEL_BG := Color(0.015, 0.028, 0.042, 0.90)
const COL_BORDER := Color(0.26, 0.90, 0.82, 0.85)
const COL_WARN := Color(1.0, 0.70, 0.28)

var _box: VBoxContainer
var _start_btn: Button
var _continue_btn: Button
var _tutorial_btn: Button
var _intro_btn: Button
var _collector_btn: Button
var _archive_btn: Button
var _challenge_btn: Button
var _lang_btn: Button
var _quit_btn: Button
var _status_label: Label
var _settings_panel: Control
var _collector_panel: Control
var _archive_panel: Control
var _challenge_panel: Control


func _ready() -> void:
	_build_bg()
	_build_ui()
	_refresh_all_texts()
	Lang.language_changed.connect(func(_c): _refresh_all_texts())
	MetaState.meta_changed.connect(_refresh_all_texts)
	var panel_script: GDScript = load("res://scripts/menu/LanguageSettingsPanel.gd")
	_settings_panel = panel_script.new()
	add_child(_settings_panel)
	_collector_panel = (load("res://scripts/menu/CollectorPanel.gd") as GDScript).new()
	add_child(_collector_panel)
	_archive_panel = (load("res://scripts/menu/ArchivePanel.gd") as GDScript).new()
	add_child(_archive_panel)
	_challenge_panel = (load("res://scripts/menu/ChallengePanel.gd") as GDScript).new()
	add_child(_challenge_panel)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.30)


func _build_bg() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	# 底层电路板：暗青底 + 网格走线
	img.fill_rect(Rect2i(0, 0, W, H), Color(0.035, 0.055, 0.075))
	var s := 40
	var line_c := Color(0.06, 0.10, 0.13)
	for x in range(0, W, s):
		img.fill_rect(Rect2i(x, 0, 1, H), line_c)
	for y in range(0, H, s):
		img.fill_rect(Rect2i(0, y, W, 1), line_c)
	# 随机焊点 / 过孔
	for _i in 130:
		var px := randi() % (W / s) * s
		var py := randi() % (H / s) * s
		var c := Color(0.10, 0.22, 0.24) if randi() % 3 != 0 else Color(0.16, 0.42, 0.40)
		img.fill_rect(Rect2i(px + 4, py + 4, 4, 4), c)
	# 四周机箱边框
	var wall_c := Color(0.09, 0.13, 0.16)
	img.fill_rect(Rect2i(0, 0, W, 22), wall_c)
	img.fill_rect(Rect2i(0, H - 22, W, 22), wall_c)
	img.fill_rect(Rect2i(0, 22, 22, H - 44), wall_c)
	img.fill_rect(Rect2i(W - 22, 22, 22, H - 44), wall_c)
	var edge := Color(0.26, 0.90, 0.82, 0.5)
	img.fill_rect(Rect2i(22, 21, W - 44, 1), edge)
	img.fill_rect(Rect2i(22, H - 22, W - 44, 1), edge)
	img.fill_rect(Rect2i(21, 22, 1, H - 44), edge)
	img.fill_rect(Rect2i(W - 22, 22, 1, H - 44), edge)
	var tex := ImageTexture.create_from_image(img)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(sprite)


func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)

	_box = VBoxContainer.new()
	# 7 个入口 + 7 行副标题必须在 720 高度内放完，间距压到最小
	_box.add_theme_constant_override("separation", 2)
	panel.add_child(_box)

	var title := Label.new()
	title.name = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.glow_label(title, COL_TITLE, Color(0.01, 0.03, 0.04, 0.95), 7)
	title.add_theme_font_size_override("font_size", 46)
	_box.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "SubtitleLabel"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.glow_label(subtitle, COL_TITLE_DIM, Color(0.01, 0.03, 0.04, 0.9), 4)
	subtitle.add_theme_font_size_override("font_size", 18)
	_box.add_child(subtitle)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", COL_TITLE)
	_status_label.add_theme_font_size_override("font_size", 12)
	_box.add_child(_status_label)

	var hint := Label.new()
	hint.name = "HintLabel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", COL_TEXT_DIM)
	hint.add_theme_font_size_override("font_size", 12)
	_box.add_child(hint)

	_box.add_child(_separator())

	_start_btn = _menu_button()
	_box.add_child(_start_btn)
	_start_btn.pressed.connect(_start_run)
	_new_sub_helper(_start_btn, "StartSubLabel")

	_continue_btn = _menu_button()
	_box.add_child(_continue_btn)
	_continue_btn.pressed.connect(_continue_run)
	_new_sub_helper(_continue_btn, "ContinueSubLabel")

	_tutorial_btn = _menu_button()
	_box.add_child(_tutorial_btn)
	_tutorial_btn.pressed.connect(_start_tutorial_run)
	_new_sub_helper(_tutorial_btn, "TutorialSubLabel")

	_intro_btn = _menu_button()
	_box.add_child(_intro_btn)
	_intro_btn.pressed.connect(_open_intro)
	_new_sub_helper(_intro_btn, "IntroSubLabel")

	_box.add_child(_separator())

	_collector_btn = _menu_button()
	_box.add_child(_collector_btn)
	_collector_btn.pressed.connect(func() -> void: _collector_panel.show_panel())
	_new_sub_helper(_collector_btn, "CollectorSubLabel")

	_archive_btn = _menu_button()
	_box.add_child(_archive_btn)
	_archive_btn.pressed.connect(func() -> void: _archive_panel.show_panel())
	_new_sub_helper(_archive_btn, "ArchiveSubLabel")

	_challenge_btn = _menu_button()
	_box.add_child(_challenge_btn)
	_challenge_btn.pressed.connect(func() -> void: _challenge_panel.show_panel())
	_new_sub_helper(_challenge_btn, "ChallengeSubLabel")

	_lang_btn = _menu_button()
	_box.add_child(_lang_btn)
	_lang_btn.pressed.connect(func() -> void: _settings_panel.show_panel())
	_new_sub_helper(_lang_btn, "LangSubLabel")

	_box.add_child(_separator())

	_quit_btn = _menu_button()
	_box.add_child(_quit_btn)
	_quit_btn.pressed.connect(func() -> void: get_tree().quit())
	_new_sub_helper(_quit_btn, "QuitSubLabel")


func _separator() -> HSeparator:
	var s := HSeparator.new()
	s.modulate = Color(0.26, 0.90, 0.82, 0.25)
	return s


func _new_sub_helper(btn: Button, sub_name: String) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_child(row)
	var sub := Label.new()
	sub.name = sub_name
	sub.add_theme_color_override("font_color", COL_TEXT_DIM)
	sub.add_theme_font_size_override("font_size", 12)
	row.add_child(sub)
	btn.set_meta("sub_label", sub)


func _panel_style() -> StyleBoxTexture:
	return UITheme.panel_slice(COL_BORDER, 60.0, 60.0, 16.0, 14.0)


func _menu_button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(470, 38)
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", COL_TITLE)
	b.add_theme_color_override("font_pressed_color", COL_TITLE)
	b.add_theme_color_override("font_disabled_color", Color(0.34, 0.38, 0.38))
	b.add_theme_stylebox_override("normal", _btn_style(Color(0.03, 0.055, 0.07), Color(0.20, 0.45, 0.48)))
	b.add_theme_stylebox_override("hover", _btn_style(Color(0.05, 0.10, 0.12), COL_TITLE))
	b.add_theme_stylebox_override("pressed", _btn_style(Color(0.07, 0.14, 0.15), COL_TITLE))
	b.add_theme_stylebox_override("disabled", _btn_style(Color(0.025, 0.035, 0.045), Color(0.14, 0.18, 0.20)))
	b.add_theme_stylebox_override("focus", _btn_style(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0)))
	b.focus_mode = Control.FOCUS_NONE
	return b


func _btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 26.0
	sb.content_margin_right = 26.0
	return sb


# ---------------- 行为 ----------------
func _start_run() -> void:
	# 第一次开局先播开场漫画；看完（或跳过）再进游戏。
	# seen 标记写在 MetaState，跳过也算看过 —— 不然每次开局都要再跳一次。
	if not MetaState.intro_seen:
		_open_intro(true)
		return
	_begin_run()


func _begin_run() -> void:
	RunDirector.pending_resume = {}
	RunDirector.pending_tutorial = false
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")


## 打开开场漫画；then_start=true 表示播完直接进游戏
func _open_intro(then_start: bool = false) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var comic: Control = load("res://scripts/menu/IntroComic.gd").new()
	layer.add_child(comic)
	comic.finished.connect(func():
		layer.queue_free()
		if then_start:
			_begin_run()
	)


## 「训练关卡」：强制下一局先跑教学房，不消耗 / 不推进任何存档进度
func _start_tutorial_run() -> void:
	RunDirector.pending_resume = {}
	RunDirector.pending_tutorial = true
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")


func _continue_run() -> void:
	var payload := RunSave.load_payload()
	if payload.is_empty():
		_refresh_all_texts()
		return
	RunDirector.pending_resume = payload
	RunDirector.pending_tutorial = false
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")


func _open_challenge() -> void:
	if not MetaState.challenge_unlocked():
		_open_challenge_locked()
		return
	_challenge_panel.show_panel()


func _open_challenge_locked() -> void:
	# 未解锁：把解锁说明闪一下（复用副标题）
	var sub: Label = _challenge_btn.get_meta("sub_label")
	sub.text = Lang.t("challenge_locked")
	sub.add_theme_color_override("font_color", COL_WARN)
	if _challenge_panel.has_method("show_panel"):
		_challenge_panel.show_panel()


# ---------------- 刷新 ----------------
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
	if _status_label:
		_status_label.text = "● " + Lang.t("menu_status_online")

	_start_btn.text = Lang.t("menu_start")
	_start_btn.get_meta("sub_label").text = Lang.t("menu_start_sub")

	_tutorial_btn.text = Lang.t("menu_tutorial")
	_tutorial_btn.get_meta("sub_label").text = Lang.t("menu_tutorial_sub")

	_intro_btn.text = Lang.t("intro_menu_btn")
	_intro_btn.get_meta("sub_label").text = Lang.t("intro_menu_sub")

	# 继续 Run
	var saved := RunSave.has_save()
	var sum := RunSave.summary()
	_continue_btn.disabled = not saved
	_continue_btn.text = Lang.t("menu_continue")
	var csub: Label = _continue_btn.get_meta("sub_label")
	if saved:
		csub.add_theme_color_override("font_color", COL_TITLE)
		csub.text = Lang.f("menu_continue_sub", [
			int(sum.get("biome", 1)), int(sum.get("depth", 0)),
			int(sum.get("hp", 0)), int(sum.get("max_hp", 0)),
		])
	else:
		csub.add_theme_color_override("font_color", COL_TEXT_DIM)
		csub.text = Lang.t("menu_continue_none")

	_collector_btn.text = Lang.t("menu_collector")
	_collector_btn.get_meta("sub_label").text = Lang.f("menu_collector_sub", [
		MetaState.tech_points, MetaState.source_code])

	_archive_btn.text = Lang.t("menu_archive")
	_archive_btn.get_meta("sub_label").text = Lang.f("menu_archive_sub", [
		MetaState.archive_count("weapon"), MetaState.archive_total("weapon"),
		MetaState.archive_count("protocol"), MetaState.archive_total("protocol"),
		MetaState.archive_count("card"), MetaState.archive_total("card"),
	])

	_challenge_btn.text = Lang.t("challenge_title")
	var chsub: Label = _challenge_btn.get_meta("sub_label")
	chsub.add_theme_color_override("font_color", COL_TEXT_DIM)
	if not MetaState.challenge_unlocked():
		chsub.text = Lang.t("challenge_locked")
	elif MetaState.active_challenges.is_empty():
		chsub.text = Lang.t("challenge_none")
	else:
		var parts: Array = []
		for cid in MetaState.active_challenges:
			parts.append(Lang.t("challenge_" + str(cid)))
		chsub.text = " / ".join(parts)

	_lang_btn.text = Lang.t("menu_language")
	_lang_btn.get_meta("sub_label").text = Lang.t("menu_language_sub")
	_quit_btn.text = Lang.t("menu_quit")
	_quit_btn.get_meta("sub_label").text = Lang.t("menu_quit_sub")
