extends CanvasLayer
## HUD —— V1.2 顶栏状态（HP / 卷轴属性 / 金币 / 细胞 / 命中统计 / 武器双槽 / 治疗瓶 / 翻滚CD）
## 以及：房间 Banner、Boss 血条、Toast、教程面板、结算遮罩。
## 纯代码构建，语言切换即时刷新。

const COLOR_BAR_BG := Color(0.07, 0.09, 0.10, 0.92)
const COLOR_HP_GOOD := Color(0.30, 0.95, 0.45)
const COLOR_HP_MID := Color(0.98, 0.78, 0.20)
const COLOR_HP_LOW := Color(0.95, 0.25, 0.20)
const COLOR_TEXT := Color(0.86, 0.92, 0.88)
const COLOR_DIM := Color(0.58, 0.66, 0.62)
const COL_GOLD := Color(1.0, 0.85, 0.35)
const COL_CELL := Color(0.50, 0.95, 0.92)
const COL_FIRE := Color(1.0, 0.45, 0.38)
const COL_COOL := Color(0.40, 0.82, 1.0)
const COL_STRUCT := Color(0.55, 1.0, 0.55)

const SLOT_W := 130.0
const SLOT_H := 24.0

var _hp_fg: ColorRect
var _hp_label: Label
var _attr_label: RichTextLabel
var _room_label: Label
var _stats_label: Label
var _gold_label: Label
var _cells_label: Label
var _pip_box: HBoxContainer
var _pips: Array = []
var _slot_bgs: Array = []
var _slot_labels: Array = []
var _roll_ctl: Control
var _roll_label: Label

var _banner: Label
var _banner_t := 0.0
var _toast_label: Label
var _toast_t := 0.0
var _tutorial: PanelContainer

var _boss_name: Label
var _boss_bg: ColorRect
var _boss_fg: ColorRect

var _overlay: ColorRect
var _ov_title: Label
var _ov_stats: Label
var _ov_extra: Label
var _ov_hint: Label

var _root: Control


func _ready() -> void:
	layer = 20
	_build()
	_refresh_all()

	EventBus.core_hp_changed.connect(_on_hp)
	EventBus.stats_changed.connect(_refresh_stats)
	EventBus.gold_changed.connect(_on_gold)
	EventBus.cells_changed.connect(_on_cells)
	EventBus.weapon_changed.connect(_on_weapon)
	EventBus.flask_used.connect(_on_flask)
	EventBus.room_entered.connect(_on_room_entered)
	EventBus.room_locked.connect(_on_room_locked)
	EventBus.room_cleared.connect(_on_room_cleared)
	EventBus.toast.connect(_on_toast)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_hp_changed.connect(_on_boss_hp)
	EventBus.boss_died.connect(_on_boss_died)
	Lang.language_changed.connect(func(_c): _refresh_all())


func _process(delta: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t <= 0.0:
			_banner.modulate.a = 0.0
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast_label.modulate.a = 0.0
	# 翻滚 CD 环
	if _roll_ctl != null:
		_roll_ctl.queue_redraw()
		var p := get_tree().get_first_node_in_group("player")
		if p != null and _roll_label != null:
			_roll_label.modulate = Color(0.45, 1.0, 0.85) if p.roll_cd_ratio() <= 0.001 else COLOR_DIM


# ---------------- 构建 ----------------
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# ---- 顶栏底 ----
	var top := ColorRect.new()
	top.color = Color(0.03, 0.04, 0.05, 0.88)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 64
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)

	# ---- 第一行：HP ----
	var hp_bg := ColorRect.new()
	hp_bg.color = COLOR_BAR_BG
	hp_bg.position = Vector2(16, 10)
	hp_bg.size = Vector2(232, 20)
	_root.add_child(hp_bg)
	_hp_fg = ColorRect.new()
	_hp_fg.color = COLOR_HP_GOOD
	_hp_fg.position = Vector2(18, 12)
	_hp_fg.size = Vector2(228, 16)
	_root.add_child(_hp_fg)
	_hp_label = Label.new()
	_hp_label.position = Vector2(24, 11)
	_hp_label.add_theme_font_size_override("font_size", 14)
	_hp_label.add_theme_color_override("font_color", Color(0.05, 0.08, 0.05))
	_root.add_child(_hp_label)

	# ---- 第一行：卷轴属性 ----
	_attr_label = RichTextLabel.new()
	_attr_label.bbcode_enabled = true
	_attr_label.scroll_active = false
	_attr_label.position = Vector2(258, 12)
	_attr_label.size = Vector2(300, 20)
	_attr_label.add_theme_font_size_override("normal_font_size", 14)
	_root.add_child(_attr_label)

	# ---- 第一行：区块 / 房间 ----
	_room_label = Label.new()
	_room_label.position = Vector2(556, 9)
	_room_label.size = Vector2(300, 22)
	_room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_label.add_theme_font_size_override("font_size", 15)
	_room_label.add_theme_color_override("font_color", COLOR_TEXT)
	_root.add_child(_room_label)

	# ---- 第一行：命中统计 ----
	_stats_label = Label.new()
	_stats_label.position = Vector2(860, 11)
	_stats_label.size = Vector2(404, 20)
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stats_label.add_theme_font_size_override("font_size", 14)
	_stats_label.add_theme_color_override("font_color", COLOR_DIM)
	_root.add_child(_stats_label)

	# ---- 第二行：治疗瓶 ----
	_pip_box = HBoxContainer.new()
	_pip_box.position = Vector2(16, 40)
	_pip_box.add_theme_constant_override("separation", 5)
	_root.add_child(_pip_box)

	# ---- 第二行：武器双槽 ----
	for i in 2:
		var slot := Control.new()
		slot.position = Vector2(160 + i * 140, 36)
		slot.size = Vector2(SLOT_W, SLOT_H)
		_root.add_child(slot)
		var bg := ColorRect.new()
		bg.size = Vector2(SLOT_W, SLOT_H)
		slot.add_child(bg)
		var lab := Label.new()
		lab.position = Vector2(7, 3)
		lab.size = Vector2(SLOT_W - 14, 18)
		lab.add_theme_font_size_override("font_size", 13)
		slot.add_child(lab)
		_slot_bgs.append(bg)
		_slot_labels.append(lab)

	# ---- 第二行：翻滚 CD 环 ----
	_roll_ctl = Control.new()
	_roll_ctl.position = Vector2(452, 36)
	_roll_ctl.size = Vector2(26, 26)
	_roll_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roll_ctl.draw.connect(_draw_roll)
	_root.add_child(_roll_ctl)
	_roll_label = Label.new()
	_roll_label.position = Vector2(482, 40)
	_roll_label.add_theme_font_size_override("font_size", 13)
	_root.add_child(_roll_label)

	# ---- 第二行：金币 / 细胞 ----
	_gold_label = Label.new()
	_gold_label.position = Vector2(600, 40)
	_gold_label.add_theme_font_size_override("font_size", 15)
	_gold_label.add_theme_color_override("font_color", COL_GOLD)
	_root.add_child(_gold_label)

	_cells_label = Label.new()
	_cells_label.position = Vector2(740, 40)
	_cells_label.add_theme_font_size_override("font_size", 15)
	_cells_label.add_theme_color_override("font_color", COL_CELL)
	_root.add_child(_cells_label)

	# ---- Boss 血条（底部）----
	_boss_name = Label.new()
	_boss_name.position = Vector2(340, 632)
	_boss_name.size = Vector2(600, 22)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.add_theme_font_size_override("font_size", 17)
	_boss_name.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	_boss_name.visible = false
	_root.add_child(_boss_name)
	_boss_bg = ColorRect.new()
	_boss_bg.color = Color(0.10, 0.06, 0.07, 0.92)
	_boss_bg.position = Vector2(340, 658)
	_boss_bg.size = Vector2(600, 16)
	_boss_bg.visible = false
	_root.add_child(_boss_bg)
	_boss_fg = ColorRect.new()
	_boss_fg.color = Color(0.95, 0.25, 0.20)
	_boss_fg.position = Vector2(342, 660)
	_boss_fg.size = Vector2(596, 12)
	_boss_fg.visible = false
	_root.add_child(_boss_fg)

	# ---- 中央 Banner ----
	_banner = Label.new()
	_banner.position = Vector2(0, 240)
	_banner.size = Vector2(1280, 44)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 34)
	_banner.add_theme_color_override("font_color", Color(1.0, 0.62, 0.28))
	_banner.modulate.a = 0.0
	_root.add_child(_banner)

	# ---- Toast（左下）----
	_toast_label = Label.new()
	_toast_label.position = Vector2(24, 566)
	_toast_label.size = Vector2(600, 24)
	_toast_label.add_theme_font_size_override("font_size", 16)
	_toast_label.add_theme_color_override("font_color", Color(0.95, 1.0, 0.9))
	_toast_label.modulate.a = 0.0
	_root.add_child(_toast_label)

	# ---- 结算遮罩 ----
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.80)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	_root.add_child(_overlay)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(640, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_overlay.add_child(box)
	_ov_title = _overlay_label(box, 62, Color(0.98, 0.28, 0.22))
	_ov_stats = _overlay_label(box, 22, COLOR_TEXT)
	_ov_extra = _overlay_label(box, 18, COL_CELL)
	_ov_hint = _overlay_label(box, 20, Color(0.7, 0.8, 1.0))


func _overlay_label(parent: Node, size: int, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _draw_roll() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var c := Vector2(13, 13)
	_roll_ctl.draw_arc(c, 10.5, 0.0, TAU, 28, Color(0.14, 0.18, 0.18, 0.95), 3.0, true)
	var r: float = p.roll_cd_ratio()
	if r <= 0.001:
		_roll_ctl.draw_arc(c, 10.5, 0.0, TAU, 28, Color(0.40, 1.0, 0.85), 3.0, true)
	else:
		_roll_ctl.draw_arc(c, 10.5, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - r), 28,
			Color(0.45, 0.68, 0.62), 3.0, true)


# ---------------- 教程 ----------------
func show_tutorial() -> void:
	var lines := [
		Lang.t("tutorial_t1"),
		Lang.t("tutorial_t2"),
		Lang.t("tutorial_t3"),
		Lang.t("tutorial_t4"),
		Lang.t("lang_switch_hint"),
	]
	var p := PanelContainer.new()
	p.position = Vector2(24, 430)
	p.custom_minimum_size = Vector2(560, 122)
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
	_root.add_child(p)
	_tutorial = p


func hide_tutorial() -> void:
	if _tutorial != null and is_instance_valid(_tutorial):
		_tutorial.queue_free()
		_tutorial = null


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.05, 0.84)
	sb.border_color = Color(0.35, 0.6, 0.5, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


# ---------------- 事件回调 ----------------
func _on_hp() -> void:
	var mx: int = maxi(1, GameState.max_hp)
	var ratio := float(GameState.core_hp) / float(mx)
	_hp_fg.size.x = maxf(0.0, 228.0 * ratio)
	_hp_fg.color = COLOR_HP_GOOD if ratio > 0.55 else (COLOR_HP_MID if ratio > 0.25 else COLOR_HP_LOW)
	_hp_label.text = "%s %d / %d" % [Lang.t("hud_hp"), GameState.core_hp, mx]


func _refresh_stats() -> void:
	_attr_label.text = "[color=#ff7260]%s %d[/color]   [color=#66d0ff]%s %d[/color]   [color=#8cff8c]%s %d[/color]" % [
		Lang.t("hud_fire"), GameState.firepower,
		Lang.t("hud_cool"), GameState.cooling,
		Lang.t("hud_struct"), GameState.structure,
	]
	_stats_label.text = "%s %d    %s %d" % [
		Lang.t("hud_kills"), GameState.kills,
		Lang.t("hud_score"), GameState.score,
	]


func _on_gold(_g: int) -> void:
	_gold_label.text = "%s %d" % [Lang.t("hud_gold"), GameState.gold]


func _on_cells(_c: int) -> void:
	_cells_label.text = "%s %d" % [Lang.t("hud_cells"), GameState.cells]


func _on_weapon(slot: int, _id: String) -> void:
	_refresh_weapons(slot)


func _refresh_weapons(active: int = -1) -> void:
	if active < 0:
		active = GameState.weapon_index
	for i in 2:
		var wid: String = GameState.weapons[i]
		var name_txt := Lang.t("w_" + wid) if wid != "" else Lang.t("hud_empty")
		var lab: Label = _slot_labels[i]
		var bg: ColorRect = _slot_bgs[i]
		lab.text = "%d  %s" % [i + 1, name_txt]
		if i == active:
			bg.color = Color(0.20, 0.62, 0.55, 0.95)
			lab.add_theme_color_override("font_color", Color(0.04, 0.09, 0.08))
		else:
			bg.color = Color(0.07, 0.10, 0.11, 0.92)
			lab.add_theme_color_override("font_color", COLOR_DIM)


func _on_flask(_c: int) -> void:
	_refresh_pips()


func _refresh_pips() -> void:
	for c in _pips:
		if is_instance_valid(c):
			c.queue_free()
	_pips.clear()
	for i in GameState.flask_max:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(13, 20)
		pip.color = Color(0.35, 0.95, 0.55) if i < GameState.flask_charges else Color(0.13, 0.16, 0.17)
		_pip_box.add_child(pip)
		_pips.append(pip)


func _on_room_entered(biome: int, room_index: int, room_type: String) -> void:
	var seq := ["combat", "combat", "treasure", "combat", "shop", "boss"]
	var total := seq.size()
	_room_label.text = "%s · %d/%d  %s" % [
		Lang.t("biome_%d" % (biome + 1)), room_index + 1, total, Lang.t("room_" + room_type)
	]
	if room_index == 0 and biome == 0:
		hide_tutorial()
		show_tutorial()


func _on_room_locked() -> void:
	hide_tutorial()
	_show_banner(Lang.t("room_locked"), 2.0, Color(1.0, 0.45, 0.35))


func _on_room_cleared() -> void:
	_show_banner(Lang.t("room_clear"), 2.4, Color(0.5, 1.0, 0.7))


func _on_toast(text: String) -> void:
	_toast_label.text = text
	_toast_label.modulate.a = 1.0
	_toast_t = 2.6


func _show_banner(text: String, dur: float, col: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", col)
	_banner.modulate.a = 1.0
	_banner_t = dur


func _on_boss_spawned(name: String, _hp: int) -> void:
	_boss_name.text = name
	_boss_name.visible = true
	_boss_bg.visible = true
	_boss_fg.visible = true
	_boss_fg.size.x = 596.0
	_show_banner(Lang.f("boss_incoming", [name]), 2.4, Color(1.0, 0.42, 0.32))


func _on_boss_hp(cur: int, max_hp: int) -> void:
	if not _boss_fg.visible:
		return
	var r := clampf(float(cur) / float(maxi(1, max_hp)), 0.0, 1.0)
	_boss_fg.size.x = maxf(0.0, 596.0 * r)
	_boss_fg.color = Color(0.95, 0.25, 0.20) if r > 0.3 else Color(1.0, 0.75, 0.2)


func _on_boss_died() -> void:
	_boss_name.visible = false
	_boss_bg.visible = false
	_boss_fg.visible = false


func show_end(victory: bool, tech: int) -> void:
	_overlay.visible = true
	if victory:
		_ov_title.text = Lang.t("victory_title")
		_ov_stats.text = Lang.f("victory_stats", [GameState.kills, GameState.score])
	else:
		_ov_title.text = Lang.t("game_over_title")
		_ov_stats.text = Lang.f("game_over_stats", [
			GameState.kills, GameState.biome_index * 6 + GameState.room_index + 1, GameState.score
		])
	_ov_extra.text = Lang.f("game_over_cells", [tech])
	_ov_hint.text = Lang.t("restart_hint")


func hide_end() -> void:
	_overlay.visible = false


func _refresh_all() -> void:
	_on_hp()
	_refresh_stats()
	_on_gold(GameState.gold)
	_on_cells(GameState.cells)
	_refresh_weapons()
	_refresh_pips()
	_roll_label.text = Lang.t("hud_roll")
	_on_room_entered(GameState.biome_index, GameState.room_index,
		["combat", "combat", "treasure", "combat", "shop", "boss"][clampi(GameState.room_index, 0, 5)])
