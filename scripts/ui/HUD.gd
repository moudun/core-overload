extends CanvasLayer
## HUD —— V1.3 战斗 HUD。
## 信息优先级：战斗焦点 > 风险(HP/过载) > 操作(武器/技能/治疗) > 构筑(标签/协议/卡) > 资源。
## 视觉层：暗角氛围 + 高光条形槽 + 四角仪器角标 + 矢量图标（统一走 UITheme）。
## 纯代码构建，语言切换即时刷新。

const COLOR_BAR_BG := Color(0.045, 0.065, 0.082, 0.94)
const COLOR_HP_GOOD := Color(0.30, 0.95, 0.45)
const COLOR_HP_MID := Color(0.98, 0.78, 0.20)
const COLOR_HP_LOW := Color(0.95, 0.25, 0.20)
const COLOR_TEXT := Color(0.86, 0.92, 0.88)
const COLOR_DIM := Color(0.52, 0.60, 0.62)
const COL_GOLD := Color(1.0, 0.85, 0.35)
const COL_CELL := Color(0.50, 0.95, 0.92)
const COL_ENERGY := Color(1.0, 0.82, 0.32)
const COL_SOURCE := Color(0.30, 1.0, 0.80)

const COL_OV_STABLE := Color(0.26, 0.90, 0.82)
const COL_OV_HIGH := Color(1.00, 0.70, 0.28)
const COL_OV_DANGER := Color(1.00, 0.45, 0.30)
const COL_OV_CRIT := Color(1.00, 0.24, 0.30)
const COL_ACCENT := Color(0.26, 0.90, 0.82)

const SLOT_W := 128.0
const SLOT_H := 26.0
const TOP_H := 64.0
const HP_W := 192.0
const OV_W := 270.0
const BOSS_W := 596.0
const TUT_W := 376.0

var _root: Control
var _hp_frame: ColorRect
var _hp_bg: ColorRect
var _hp_fg: ColorRect
var _hp_gloss: ColorRect
var _hp_label: Label
var _ov_frame: ColorRect
var _ov_bg: ColorRect
var _ov_fg: ColorRect
var _ov_gloss: ColorRect
var _ov_label: Label
var _ov_tier: Label
var _attr_label: RichTextLabel
var _room_label: Label
var _depth_label: Label
var _stats_label: Label
var _gold_label: Label
var _cells_label: Label
var _energy_label: Label
var _source_label: Label
var _pip_box: HBoxContainer
var _pips: Array = []
var _slot_bgs: Array = []
var _slot_chips: Array = []
var _slot_labels: Array = []
var _roll_ctl: Control
var _roll_label: Label
var _skill_ctl: Control
var _skill_label: Label
var _tag_box: HBoxContainer
var _build_head: Label
var _protos_label: Label
var _cards_label: Label
var _rules_label: Label
var _hint_label: Label
var _chain_label: Label
var _vent_label: Label

var _vignette: TextureRect
var _danger_vig: TextureRect
var _banner: Label
var _banner_band: Panel
var _banner_line_a: ColorRect
var _banner_line_b: ColorRect
var _banner_t := 0.0
var _toast_label: Label
var _toast_accent: ColorRect
var _toast_t := 0.0
var _tutorial: PanelContainer

# 教学房目标面板（由 RoomManager 通过 EventBus.tutorial_step 驱动）
var _tut_panel: PanelContainer
var _tut_step_label: Label
var _tut_goal_label: Label
var _tut_bar_bg: ColorRect
var _tut_bar_fg: ColorRect
var _tut_idx := -1
var _tut_total := 0
var _tut_sid := ""

var _boss_name: Label
var _boss_bg: ColorRect
var _boss_fg: ColorRect
var _boss_gloss: ColorRect
var _boss_ticks: Array = []

var _overlay: ColorRect
var _ov_title: Label
var _ov_stats: Label
var _ov_extra: Label
var _ov_extra2: Label
var _ov_hint: Label

var _pulse_t := 0.0
var _score_line := ""

# ---- 可折叠操作指南栏 ----
const GUIDE_W := 268.0
const GUIDE_H := 316.0
const GUIDE_X := 1280.0 - GUIDE_W - 16.0
const GUIDE_Y := 250.0
var _guide_root: Control
var _guide_panel: Panel
var _guide_tab: Panel
var _guide_open := true

# ---- 交互提示条 ----
var _prompt_root: Control
var _prompt_bg: Panel
var _prompt_key: Label
var _prompt_label: Label

var _tab_prev := false


func _ready() -> void:
	layer = 20
	_build()
	_refresh_all()

	EventBus.core_hp_changed.connect(_on_hp)
	EventBus.stats_changed.connect(_refresh_stats)
	EventBus.gold_changed.connect(_on_gold)
	EventBus.cells_changed.connect(_on_cells)
	EventBus.energy_changed.connect(_on_energy)
	EventBus.weapon_changed.connect(_on_weapon)
	EventBus.flask_used.connect(_on_flask)
	EventBus.protocol_changed.connect(_on_protocols)
	EventBus.card_changed.connect(_on_cards)
	EventBus.build_changed.connect(_on_build)
	EventBus.room_entered.connect(_on_room_entered)
	EventBus.room_locked.connect(_on_room_locked)
	EventBus.room_cleared.connect(_on_room_cleared)
	EventBus.toast.connect(_on_toast)
	EventBus.overload_changed.connect(_on_overload)
	EventBus.overload_meltdown.connect(_on_meltdown)
	EventBus.chain_changed.connect(_on_chain)
	EventBus.skill_used.connect(_on_skill)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_hp_changed.connect(_on_boss_hp)
	EventBus.boss_died.connect(_on_boss_died)
	EventBus.run_saved.connect(_on_saved)
	EventBus.tutorial_step.connect(_on_tutorial_step)
	EventBus.tutorial_finished.connect(_on_tutorial_finished)
	Lang.language_changed.connect(func(_c): _refresh_all())
	MetaState.meta_changed.connect(func(): _on_source())


func _process(delta: float) -> void:
	_pulse_t += delta
	if _banner_t > 0.0:
		_banner_t -= delta
		_set_banner_alpha(clampf(_banner_t / 0.45, 0.0, 1.0))
	elif _banner != null and _banner.modulate.a > 0.0:
		_set_banner_alpha(0.0)
	if _toast_t > 0.0:
		_toast_t -= delta
		_set_toast_alpha(clampf(_toast_t / 0.55, 0.0, 1.0))
	elif _toast_label != null and _toast_label.modulate.a > 0.0:
		_set_toast_alpha(0.0)

	if _roll_ctl != null:
		_roll_ctl.queue_redraw()
	if _skill_ctl != null:
		_skill_ctl.queue_redraw()

	var p := get_tree().get_first_node_in_group("player")
	if p != null:
		if _roll_label != null:
			_roll_label.modulate = Color(0.45, 1.0, 0.85) if p.roll_cd_ratio() <= 0.001 else COLOR_DIM
		if _skill_label != null:
			_skill_label.modulate = Color(0.75, 0.95, 1.0) if p.skill_cd_ratio() <= 0.001 else COLOR_DIM
		if _vent_label != null:
			_vent_label.visible = p.venting

	_update_danger_vignette()
	_tick_guide()
	_update_prompt()

	# 过载危险呼吸
	var tier := Overload.tier()
	if tier >= Overload.TIER_DANGER:
		var speed := 3.0 if tier == Overload.TIER_DANGER else 6.0
		_ov_frame.modulate.a = 0.35 + 0.35 * absf(sin(_pulse_t * speed))
		_ov_label.modulate = Color(1.0, 0.78, 0.72)
	else:
		_ov_frame.modulate.a = 0.25
		_ov_label.modulate = Color.WHITE
	_update_room_hint()


## Tab 键收起/展开指南栏。这里用轮询而不是 InputMap，是因为指南栏是 HUD 内部状态，
## 走 _input 会被暂停态 / 其它面板抢焦点。
func _tick_guide() -> void:
	var down := Input.is_key_pressed(KEY_TAB)
	if down and not _tab_prev:
		_toggle_guide()
	_tab_prev = down
	_update_room_hint()


## 低血量：屏幕边缘红色呼吸警示
func _update_danger_vignette() -> void:
	if _danger_vig == null:
		return
	if not GameState.active:
		_danger_vig.modulate.a = 0.0
		return
	var mx: int = maxi(1, GameState.max_hp)
	var ratio := float(GameState.core_hp) / float(mx)
	if ratio > 0.35:
		_danger_vig.modulate.a = 0.0
		return
	var sev := clampf((0.35 - ratio) / 0.35, 0.0, 1.0)
	var beat := 0.55 + 0.45 * absf(sin(_pulse_t * 3.4))
	_danger_vig.modulate.a = sev * 0.72 * beat


func _set_banner_alpha(a: float) -> void:
	if _banner != null:
		_banner.modulate.a = a
	if _banner_band != null:
		_banner_band.modulate.a = a
	if _banner_line_a != null:
		_banner_line_a.modulate.a = a
	if _banner_line_b != null:
		_banner_line_b.modulate.a = a


func _set_toast_alpha(a: float) -> void:
	if _toast_label != null:
		_toast_label.modulate.a = a
	if _toast_accent != null:
		_toast_accent.modulate.a = a


func _update_room_hint() -> void:
	var room := get_tree().get_first_node_in_group("room")
	if room == null or _hint_label == null:
		_hint_label.text = ""
		return
	var txt := ""
	if room.has_method("glitch_hint_text"):
		txt = str(room.glitch_hint_text())
	if txt == "" and room.has_method("harvest_hint_text"):
		txt = str(room.harvest_hint_text())
	if txt == "" and room.has_method("tutorial_hint_text"):
		txt = str(room.tutorial_hint_text())
	_hint_label.text = txt


# ---------------- 构建 ----------------
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_atmosphere()
	_build_top_bar()
	_build_build_bar()
	_build_guide()
	_build_prompt()
	_build_center_layer()
	_build_overlay()


## 氛围层：机身暗角 + 低血警示
func _build_atmosphere() -> void:
	_vignette = _full_texture(PixelArt.vignette_tex(160, 90, 0.88))
	_root.add_child(_vignette)
	_danger_vig = _full_texture(PixelArt.vignette_tex(160, 90, 1.0, Color(0.85, 0.05, 0.10)))
	_danger_vig.modulate.a = 0.0
	_root.add_child(_danger_vig)


func _full_texture(tex: Texture2D) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _build_top_bar() -> void:
	var top := ColorRect.new()
	top.color = Color(0.018, 0.030, 0.048, 0.93)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = TOP_H
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)

	# 顶栏下方渐隐，避免生硬切边
	var fade := TextureRect.new()
	fade.texture = PixelArt.vfade_tex(Color(0.02, 0.05, 0.07), 0.68)
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.position = Vector2(0, TOP_H)
	fade.size = Vector2(1280, 26)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(fade)

	UITheme.hairline(_root, Vector2(0, TOP_H - 2), Vector2(1280, 2), Color(0.26, 0.90, 0.82, 0.32))
	UITheme.hairline(_root, Vector2(0, TOP_H - 1), Vector2(1280, 1), Color(0.55, 1.0, 0.92, 0.20))

	_build_hp_bar()
	_build_overload_bar()
	_build_room_labels()
	_build_attr_row()
	_build_weapon_slots()
	_build_cooldown_rings()
	_build_resource_row()

	# 屏幕四角机箱角标
	UITheme.corner_brackets(_root, Vector2(4, 4), Vector2(1272, 712), Color(0.26, 0.90, 0.82, 0.20), 18, 2)


func _build_hp_bar() -> void:
	_hp_frame = ColorRect.new()
	_hp_frame.color = Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.30)
	_hp_frame.position = Vector2(14, 6)
	_hp_frame.size = Vector2(200, 26)
	_hp_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hp_frame)
	_hp_bg = ColorRect.new()
	_hp_bg.color = COLOR_BAR_BG
	_hp_bg.position = Vector2(16, 8)
	_hp_bg.size = Vector2(196, 22)
	_hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hp_bg)
	_hp_fg = ColorRect.new()
	_hp_fg.color = COLOR_HP_GOOD
	_hp_fg.position = Vector2(18, 10)
	_hp_fg.size = Vector2(HP_W, 18)
	_hp_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hp_fg)
	_hp_gloss = ColorRect.new()
	_hp_gloss.color = Color(1, 1, 1, 0.20)
	_hp_gloss.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hp_gloss.offset_bottom = 6
	_hp_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_fg.add_child(_hp_gloss)
	for i in 3:
		UITheme.hairline(_root, Vector2(18 + 48 * (i + 1), 10), Vector2(2, 18), Color(0.02, 0.03, 0.04, 0.45))
	UITheme.icon(_root, Vector2(21, 11), 14, "hp", Color(1.0, 0.42, 0.48))
	_hp_label = Label.new()
	_hp_label.position = Vector2(42, 9)
	_hp_label.size = Vector2(168, 20)
	_hp_label.add_theme_font_size_override("font_size", 13)
	UITheme.glow_label(_hp_label, Color(1, 1, 1, 0.97), Color(0.01, 0.04, 0.04, 0.95), 4)
	_root.add_child(_hp_label)
	UITheme.corner_brackets(_root, Vector2(11, 3), Vector2(206, 32), Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.45), 9, 2)


func _build_overload_bar() -> void:
	_ov_frame = ColorRect.new()
	_ov_frame.color = Color(1.0, 0.36, 0.41, 1.0)
	_ov_frame.position = Vector2(226, 6)
	_ov_frame.size = Vector2(278, 26)
	_ov_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ov_frame)
	_ov_bg = ColorRect.new()
	_ov_bg.color = COLOR_BAR_BG
	_ov_bg.position = Vector2(228, 8)
	_ov_bg.size = Vector2(274, 22)
	_ov_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ov_bg)
	_ov_fg = ColorRect.new()
	_ov_fg.color = COL_OV_STABLE
	_ov_fg.position = Vector2(230, 10)
	_ov_fg.size = Vector2(OV_W, 18)
	_ov_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_ov_fg)
	_ov_gloss = ColorRect.new()
	_ov_gloss.color = Color(1, 1, 1, 0.22)
	_ov_gloss.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_ov_gloss.offset_bottom = 6
	_ov_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ov_fg.add_child(_ov_gloss)
	# 25 / 50 / 75 分段刻度
	for i in 3:
		UITheme.hairline(_root, Vector2(230 + OV_W * 0.25 * (i + 1), 10), Vector2(2, 18), Color(0.02, 0.03, 0.04, 0.40))
	UITheme.icon(_root, Vector2(233, 11), 14, "bolt", Color(0.08, 0.13, 0.15))
	_ov_label = Label.new()
	_ov_label.position = Vector2(254, 9)
	_ov_label.size = Vector2(240, 20)
	_ov_label.add_theme_font_size_override("font_size", 13)
	UITheme.glow_label(_ov_label, Color(1, 1, 1, 0.97), Color(0.01, 0.04, 0.04, 0.95), 4)
	_root.add_child(_ov_label)
	_ov_tier = Label.new()
	_ov_tier.position = Vector2(514, 8)
	_ov_tier.size = Vector2(150, 22)
	_ov_tier.add_theme_font_size_override("font_size", 14)
	UITheme.glow_label(_ov_tier, COL_OV_STABLE, Color(0.02, 0.04, 0.05, 0.9), 3)
	_root.add_child(_ov_tier)
	UITheme.corner_brackets(_root, Vector2(224, 3), Vector2(284, 32), Color(1.0, 0.36, 0.41, 0.45), 9, 2)


func _build_room_labels() -> void:
	_room_label = Label.new()
	_room_label.position = Vector2(660, 7)
	_room_label.size = Vector2(300, 24)
	_room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_label.add_theme_font_size_override("font_size", 16)
	UITheme.glow_label(_room_label, UITheme.TEXT, Color(0.02, 0.04, 0.05, 0.92), 4)
	_root.add_child(_room_label)

	_depth_label = Label.new()
	_depth_label.position = Vector2(950, 8)
	_depth_label.size = Vector2(314, 22)
	_depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_depth_label.add_theme_font_size_override("font_size", 13)
	UITheme.glow_label(_depth_label, COLOR_DIM, Color(0.02, 0.04, 0.05, 0.85), 3)
	_root.add_child(_depth_label)


func _build_attr_row() -> void:
	_attr_label = RichTextLabel.new()
	_attr_label.bbcode_enabled = true
	_attr_label.scroll_active = false
	_attr_label.position = Vector2(16, 37)
	_attr_label.size = Vector2(300, 20)
	_attr_label.add_theme_font_size_override("normal_font_size", 13)
	_attr_label.add_theme_color_override("default_color", UITheme.TEXT)
	_root.add_child(_attr_label)

	UITheme.icon(_root, Vector2(330, 38), 14, "hp", UITheme.GREEN)
	_pip_box = HBoxContainer.new()
	_pip_box.position = Vector2(350, 36)
	_pip_box.add_theme_constant_override("separation", 4)
	_pip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_pip_box)


func _build_weapon_slots() -> void:
	for i in 2:
		var slot := Control.new()
		slot.position = Vector2(450 + i * 136, 34)
		slot.size = Vector2(SLOT_W, SLOT_H)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(slot)
		var bg := Panel.new()
		bg.size = Vector2(SLOT_W, SLOT_H)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_theme_stylebox_override("panel", UITheme.bar_slot(COLOR_DIM, 3))
		slot.add_child(bg)
		var chip := ColorRect.new()
		chip.position = Vector2(3, SLOT_H * 0.5 - 8)
		chip.size = Vector2(3, 16)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(chip)
		var lab := Label.new()
		lab.position = Vector2(12, 4)
		lab.size = Vector2(SLOT_W - 18, 18)
		lab.add_theme_font_size_override("font_size", 12)
		slot.add_child(lab)
		_slot_bgs.append(bg)
		_slot_chips.append(chip)
		_slot_labels.append(lab)


func _build_cooldown_rings() -> void:
	_roll_ctl = _make_ring(Vector2(736, 31), "roll")
	_roll_label = _ring_label(Vector2(770, 36))
	_skill_ctl = _make_ring(Vector2(830, 31), "skill")
	_skill_label = _ring_label(Vector2(864, 36))


func _ring_label(at: Vector2) -> Label:
	var l := Label.new()
	l.position = at
	l.size = Vector2(34, 20)
	l.add_theme_font_size_override("font_size", 12)
	UITheme.glow_label(l, Color(1, 1, 1, 1), Color(0.02, 0.04, 0.05, 0.92), 4)
	l.modulate = COLOR_DIM
	_root.add_child(l)
	return l


func _build_resource_row() -> void:
	# 右上角资源簇：图标 + 数值，右对齐自动排布，永不互相压字
	var res := HBoxContainer.new()
	res.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	res.offset_left = -430
	res.offset_top = 34
	res.offset_right = -14
	res.offset_bottom = 58
	res.alignment = BoxContainer.ALIGNMENT_END
	res.add_theme_constant_override("separation", 16)
	res.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(res)
	_gold_label = _res_item(res, "coin", COL_GOLD)
	_cells_label = _res_item(res, "cell", COL_CELL)
	_energy_label = _res_item(res, "energy", COL_ENERGY)
	_source_label = _res_item(res, "source", COL_SOURCE)


func _res_item(parent: Node, kind: String, col: Color) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var ic := TextureRect.new()
	ic.texture = PixelArt.icon_tex(kind, 14, col)
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 14)
	UITheme.glow_label(l, col, Color(0.02, 0.04, 0.05, 0.9), 3)
	row.add_child(l)
	return l


## 左下构筑区：竖向强调脊 + 标签 / 协议 / 过载卡
func _build_build_bar() -> void:
	UITheme.hairline(_root, Vector2(16, 620), Vector2(3, 86), Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.26))
	UITheme.hairline(_root, Vector2(16, 620), Vector2(3, 28), Color(0.71, 0.55, 1.0, 0.80))
	UITheme.hairline(_root, Vector2(16, 678), Vector2(3, 28), Color(1.0, 0.58, 0.38, 0.80))

	var head := Label.new()
	head.position = Vector2(28, 620)
	head.size = Vector2(300, 16)
	head.add_theme_font_size_override("font_size", 12)
	UITheme.glow_label(head, Color(0.46, 0.58, 0.60), Color(0.02, 0.04, 0.05, 0.85), 3)
	head.set_meta("lang_key", "hud_tags")
	_root.add_child(head)
	_build_head = head

	_tag_box = HBoxContainer.new()
	_tag_box.position = Vector2(28, 640)
	_tag_box.add_theme_constant_override("separation", 12)
	_tag_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tag_box)

	_protos_label = Label.new()
	_protos_label.position = Vector2(28, 664)
	_protos_label.size = Vector2(660, 20)
	_protos_label.add_theme_font_size_override("font_size", 13)
	UITheme.glow_label(_protos_label, Color(0.72, 0.62, 1.0), Color(0.02, 0.04, 0.05, 0.9), 3)
	_root.add_child(_protos_label)

	_cards_label = Label.new()
	_cards_label.position = Vector2(28, 686)
	_cards_label.size = Vector2(660, 20)
	_cards_label.add_theme_font_size_override("font_size", 13)
	UITheme.glow_label(_cards_label, Color(1.0, 0.58, 0.38), Color(0.02, 0.04, 0.05, 0.9), 3)
	_root.add_child(_cards_label)


## 右侧可折叠「操作指南」栏。默认展开，按 Tab 收起；收起状态写进 Settings 持久化。
## 之所以做成纯代码 Panel + VBox（而不是 .tscn），是为了和 HUD 其它部分保持一致，
## 也让折叠时能整块隐藏而不留空壳。
func _build_guide() -> void:
	_guide_root = Control.new()
	_guide_root.position = Vector2(GUIDE_X, GUIDE_Y)
	_guide_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_guide_root)

	# 折叠后只剩一条竖标签（贴在右边缘）
	_guide_tab = Panel.new()
	_guide_tab.position = Vector2(GUIDE_W - 22.0, 0)
	_guide_tab.size = Vector2(22, 128)
	var tab_st := UITheme.panel_flat(COL_ACCENT, 0.30, 0.0, 0)
	tab_st.bg_color = Color(0.030, 0.055, 0.075, 0.88)
	_guide_tab.add_theme_stylebox_override("panel", tab_st)
	_guide_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide_root.add_child(_guide_tab)

	var tab_lab := Label.new()
	tab_lab.text = "TAB"
	tab_lab.position = Vector2(0, 0)
	tab_lab.size = Vector2(22, 128)
	tab_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tab_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tab_lab.add_theme_font_size_override("font_size", 10)
	UITheme.glow_label(tab_lab, COL_ACCENT, Color(0.02, 0.04, 0.05, 0.9), 2)
	_guide_tab.add_child(tab_lab)

	# 展开态的整块面板
	_guide_panel = Panel.new()
	_guide_panel.size = Vector2(GUIDE_W, GUIDE_H)
	# StyleBoxTexture 没有 bg_color（那是 StyleBoxFlat 的）—— 只能调 modulate 压暗
	var st := UITheme.panel_slice(COL_ACCENT, 12, 12, 10, 10)
	st.modulate_color = Color(0.62, 0.72, 0.78, 0.96)
	_guide_panel.add_theme_stylebox_override("panel", st)
	_guide_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide_root.add_child(_guide_panel)

	var head := Label.new()
	head.position = Vector2(14, 8)
	head.size = Vector2(GUIDE_W - 40, 18)
	head.add_theme_font_size_override("font_size", 12)
	UITheme.glow_label(head, COL_ACCENT, Color(0.02, 0.04, 0.05, 0.9), 3)
	head.set_meta("lang_key", "guide_title")
	_guide_panel.add_child(head)

	var toggle := Label.new()
	toggle.position = Vector2(14, 8)
	toggle.size = Vector2(GUIDE_W - 28, 18)
	toggle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toggle.add_theme_font_size_override("font_size", 10)
	UITheme.glow_label(toggle, Color(0.42, 0.52, 0.55), Color(0.02, 0.04, 0.05, 0.9), 2)
	toggle.set_meta("lang_key", "guide_toggle")
	_guide_panel.add_child(toggle)

	UITheme.hairline(_guide_panel, Vector2(12, 28), Vector2(GUIDE_W - 24, 1),
		Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.30))

	# 指南条目：每行一个 key，渲染时按当前语言取文本
	var keys := [
		"guide_move", "guide_shoot", "guide_roll", "guide_swap", "guide_skill",
		"guide_flask", "guide_interact", "guide_chest", "guide_shop", "guide_hack",
		"guide_glitch", "guide_overload", "guide_vent", "guide_lang",
	]
	var y := 34.0
	for k in keys:
		var l := Label.new()
		l.position = Vector2(14, y)
		l.size = Vector2(GUIDE_W - 26, 16)
		l.add_theme_font_size_override("font_size", 11)
		UITheme.glow_label(l, Color(0.74, 0.82, 0.82), Color(0.02, 0.04, 0.05, 0.9), 2)
		l.set_meta("lang_key", k)
		_guide_panel.add_child(l)
		y += 19.0

	_guide_open = Settings.hud_guide_open
	_apply_guide_state()


## Tab 切换收起/展开
func _toggle_guide() -> void:
	_guide_open = not _guide_open
	Settings.set_hud_guide_open(_guide_open)
	_apply_guide_state()
	EventBus.toast.emit(Lang.t("guide_title") + (" ▲" if _guide_open else " ▼"))


func _apply_guide_state() -> void:
	if _guide_panel == null or _guide_tab == null:
		return
	_guide_panel.visible = _guide_open
	_guide_tab.visible = not _guide_open


## 屏幕中下方「[E] 做什么」的交互提示。
## 数据来自 RoomManager._prompt（它在 _tick_interactions 里逐帧填）。
func _build_prompt() -> void:
	_prompt_root = Control.new()
	_prompt_root.position = Vector2(0, 604)
	_prompt_root.size = Vector2(1280, 34)
	_prompt_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_root.visible = false
	_root.add_child(_prompt_root)

	_prompt_bg = Panel.new()
	_prompt_bg.size = Vector2(300, 30)
	_prompt_bg.position = Vector2(490, 0)
	var pst := UITheme.panel_slice(COL_ACCENT, 8, 8, 4, 4)
	pst.modulate_color = Color(0.72, 0.82, 0.86, 0.98)
	_prompt_bg.add_theme_stylebox_override("panel", pst)
	_prompt_root.add_child(_prompt_bg)

	_prompt_key = Label.new()
	_prompt_key.position = Vector2(10, 4)
	_prompt_key.size = Vector2(26, 22)
	_prompt_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_key.add_theme_font_size_override("font_size", 14)
	UITheme.glow_label(_prompt_key, COL_ACCENT, Color(0.02, 0.04, 0.05, 0.95), 4)
	_prompt_bg.add_child(_prompt_key)

	_prompt_label = Label.new()
	_prompt_label.position = Vector2(42, 4)
	_prompt_label.size = Vector2(250, 22)
	_prompt_label.add_theme_font_size_override("font_size", 13)
	UITheme.glow_label(_prompt_label, Color(0.88, 0.94, 0.92), Color(0.02, 0.04, 0.05, 0.95), 3)
	_prompt_bg.add_child(_prompt_label)


## 每帧从 RoomManager 拉取当前可交互目标并显示提示
func _update_prompt() -> void:
	if _prompt_root == null:
		return
	var room := get_tree().get_first_node_in_group("room")
	var txt := ""
	if room != null and "_prompt" in room:
		var pr: Dictionary = room._prompt
		if not pr.is_empty():
			txt = str(pr.get("label", ""))
	if txt == "":
		_prompt_root.visible = false
		return
	_prompt_root.visible = true
	_prompt_key.text = Lang.t("prompt_key")
	_prompt_label.text = txt
	# 面板宽度跟着文字长度走
	var w := maxf(160.0, 62.0 + float(txt.length()) * 13.5)
	_prompt_bg.size = Vector2(w, 30)
	_prompt_bg.position = Vector2(640.0 - w * 0.5, 0)
	_prompt_key.position = Vector2(10, 4)
	_prompt_label.size = Vector2(w - 56.0, 22)


func _build_center_layer() -> void:
	_rules_label = Label.new()
	_rules_label.position = Vector2(16, 72)
	_rules_label.size = Vector2(700, 22)
	_rules_label.add_theme_font_size_override("font_size", 14)
	UITheme.glow_label(_rules_label, Color(1.0, 0.72, 0.30), Color(0.02, 0.04, 0.05, 0.9), 3)
	_root.add_child(_rules_label)

	_chain_label = Label.new()
	_chain_label.position = Vector2(900, 70)
	_chain_label.size = Vector2(364, 24)
	_chain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_chain_label.add_theme_font_size_override("font_size", 16)
	UITheme.glow_label(_chain_label, Color(1.0, 0.82, 0.30), Color(0.02, 0.04, 0.05, 0.9), 4)
	_root.add_child(_chain_label)

	_hint_label = Label.new()
	_hint_label.position = Vector2(240, 698)
	_hint_label.size = Vector2(800, 20)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 14)
	UITheme.glow_label(_hint_label, Color(1.0, 0.74, 0.30), Color(0.02, 0.04, 0.05, 0.9), 3)
	_root.add_child(_hint_label)

	_vent_label = Label.new()
	_vent_label.position = Vector2(540, 596)
	_vent_label.size = Vector2(200, 26)
	_vent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vent_label.add_theme_font_size_override("font_size", 17)
	UITheme.glow_label(_vent_label, Color(0.50, 0.92, 1.0), Color(0.02, 0.04, 0.06, 0.92), 4)
	_vent_label.visible = false
	_root.add_child(_vent_label)

	_build_banner()
	_build_toast()
	_build_boss_bar()


## 横幅：全宽警戒带 + 上下强调线
func _build_banner() -> void:
	_banner_band = Panel.new()
	_banner_band.position = Vector2(0, 226)
	_banner_band.size = Vector2(1280, 64)
	_banner_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := UITheme.panel_flat(COL_ACCENT, 0.34, 0.0, 0)
	st.set_border_width_all(0)
	_banner_band.add_theme_stylebox_override("panel", st)
	_banner_band.modulate.a = 0.0
	_root.add_child(_banner_band)
	_banner_line_a = UITheme.hairline(_root, Vector2(0, 226), Vector2(1280, 2), Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.55))
	_banner_line_b = UITheme.hairline(_root, Vector2(0, 288), Vector2(1280, 2), Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.32))
	_banner_line_a.modulate.a = 0.0
	_banner_line_b.modulate.a = 0.0
	_banner = Label.new()
	_banner.position = Vector2(0, 236)
	_banner.size = Vector2(1280, 48)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 34)
	UITheme.glow_label(_banner, Color(1.0, 0.62, 0.28), Color(0.02, 0.02, 0.03, 0.95), 6)
	_banner.modulate.a = 0.0
	_root.add_child(_banner)


func _build_toast() -> void:
	_toast_accent = UITheme.hairline(_root, Vector2(20, 566), Vector2(4, 24), Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.85))
	_toast_accent.modulate.a = 0.0
	_toast_label = Label.new()
	_toast_label.position = Vector2(34, 566)
	_toast_label.size = Vector2(760, 24)
	_toast_label.add_theme_font_size_override("font_size", 16)
	UITheme.glow_label(_toast_label, Color(0.95, 1.0, 0.92), Color(0.02, 0.04, 0.05, 0.92), 4)
	_toast_label.modulate.a = 0.0
	_root.add_child(_toast_label)


func _build_boss_bar() -> void:
	_boss_name = Label.new()
	_boss_name.position = Vector2(340, 626)
	_boss_name.size = Vector2(600, 24)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name.add_theme_font_size_override("font_size", 18)
	UITheme.glow_label(_boss_name, Color(1.0, 0.58, 0.48), Color(0.03, 0.02, 0.03, 0.95), 5)
	_boss_name.visible = false
	_root.add_child(_boss_name)
	_boss_bg = ColorRect.new()
	_boss_bg.color = Color(0.014, 0.028, 0.038, 0.95)
	_boss_bg.position = Vector2(340, 654)
	_boss_bg.size = Vector2(600, 18)
	_boss_bg.visible = false
	_root.add_child(_boss_bg)
	_boss_fg = ColorRect.new()
	_boss_fg.color = Color(0.95, 0.25, 0.20)
	_boss_fg.position = Vector2(342, 656)
	_boss_fg.size = Vector2(BOSS_W, 14)
	_boss_fg.visible = false
	_root.add_child(_boss_fg)
	_boss_gloss = ColorRect.new()
	_boss_gloss.color = Color(1, 1, 1, 0.20)
	_boss_gloss.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_boss_gloss.offset_bottom = 5
	_boss_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_fg.add_child(_boss_gloss)
	for i in 3:
		var t := UITheme.hairline(_root, Vector2(340 + 150 * (i + 1), 654), Vector2(2, 18), Color(0.02, 0.03, 0.04, 0.5))
		t.visible = false
		_boss_ticks.append(t)


func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.86)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	_root.add_child(_overlay)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", UITheme.panel(UITheme.RED, 34.0))
	_overlay.add_child(panel)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(760, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_ov_title = _overlay_label(box, 58, Color(0.98, 0.28, 0.22))
	_ov_stats = _overlay_label(box, 22, COLOR_TEXT)
	_ov_extra = _overlay_label(box, 18, COL_CELL)
	_ov_extra2 = _overlay_label(box, 18, COL_SOURCE)
	_ov_hint = _overlay_label(box, 20, Color(0.7, 0.8, 1.0))


func _make_ring(pos: Vector2, kind: String) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = Vector2(26, 26)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_meta("icon", PixelArt.icon_tex(kind, 12, Color(0.85, 1.0, 0.96)))
	c.draw.connect(func(): _draw_ring(c))
	_root.add_child(c)
	return c


func _overlay_label(parent: Node, size: int, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)
	UITheme.glow_label(l, col, Color(0.02, 0.03, 0.04, 0.95), maxi(3, size / 6))
	return l


func _draw_ring(c: Control) -> void:
	var center := Vector2(13, 13)
	c.draw_arc(center, 13.0, 0.0, TAU, 28, Color(COL_ACCENT.r, COL_ACCENT.g, COL_ACCENT.b, 0.22), 1.0, true)
	c.draw_arc(center, 11.0, 0.0, TAU, 28, Color(0.09, 0.13, 0.15, 0.96), 3.0, true)
	var p := get_tree().get_first_node_in_group("player")
	var r := 0.0
	if p != null:
		r = p.roll_cd_ratio() if c == _roll_ctl else p.skill_cd_ratio()
	if r <= 0.001:
		c.draw_arc(center, 11.0, 0.0, TAU, 28, Color(0.40, 1.0, 0.85), 3.0, true)
	else:
		c.draw_arc(center, 11.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - r), 28,
			Color(0.45, 0.68, 0.62), 3.0, true)
	var ic: Texture2D = c.get_meta("icon", null)
	if ic != null:
		c.draw_texture(ic, center - Vector2(6, 6))


# ---------------- 教程 ----------------
func show_tutorial() -> void:
	var lines := [
		Lang.t("tutorial_t1"),
		Lang.t("tutorial_t2"),
		Lang.t("tutorial_t3"),
		Lang.t("tutorial_t4"),
		Lang.t("tutorial_t5"),
		Lang.t("lang_switch_hint"),
	]
	var p := PanelContainer.new()
	p.position = Vector2(24, 400)
	p.custom_minimum_size = Vector2(600, 148)
	p.add_theme_stylebox_override("panel", UITheme.panel(COL_ACCENT, 14.0))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	p.add_child(vb)
	for line in lines:
		var l := Label.new()
		l.text = line
		l.add_theme_font_size_override("font_size", 14)
		UITheme.glow_label(l, Color(0.84, 0.92, 0.86), Color(0.02, 0.04, 0.05, 0.85), 3)
		vb.add_child(l)
	_root.add_child(p)
	_tutorial = p


func hide_tutorial() -> void:
	if _tutorial != null and is_instance_valid(_tutorial):
		_tutorial.queue_free()
		_tutorial = null


# ---------------- 教学房目标面板 ----------------
func _ensure_tutorial_panel() -> void:
	if _tut_panel != null and is_instance_valid(_tut_panel):
		return
	var p := PanelContainer.new()
	p.position = Vector2(438, 96)
	p.custom_minimum_size = Vector2(404, 88)
	p.add_theme_stylebox_override("panel", UITheme.panel(COL_ACCENT, 12.0))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	p.add_child(vb)
	_tut_step_label = Label.new()
	_tut_step_label.add_theme_font_size_override("font_size", 13)
	UITheme.glow_label(_tut_step_label, Color(0.55, 0.92, 1.00), Color(0.02, 0.04, 0.06, 0.9), 3)
	vb.add_child(_tut_step_label)
	_tut_goal_label = Label.new()
	_tut_goal_label.custom_minimum_size = Vector2(TUT_W, 0)
	_tut_goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tut_goal_label.add_theme_font_size_override("font_size", 15)
	UITheme.glow_label(_tut_goal_label, Color(0.92, 0.97, 0.94), Color(0.02, 0.04, 0.06, 0.9), 3)
	vb.add_child(_tut_goal_label)
	# 步骤进度条
	_tut_bar_bg = ColorRect.new()
	_tut_bar_bg.custom_minimum_size = Vector2(TUT_W, 4)
	_tut_bar_bg.color = Color(0.10, 0.15, 0.18, 0.92)
	vb.add_child(_tut_bar_bg)
	_tut_bar_fg = ColorRect.new()
	_tut_bar_fg.color = COL_ACCENT
	_tut_bar_fg.size = Vector2(0, 4)
	_tut_bar_bg.add_child(_tut_bar_fg)
	_root.add_child(p)
	_tut_panel = p
	_refresh_tutorial_text()


func _refresh_tutorial_text() -> void:
	if _tut_panel == null or not is_instance_valid(_tut_panel):
		return
	if _build_head != null and _build_head.is_inside_tree():
		_build_head.text = Lang.t(str(_build_head.get_meta("lang_key", "hud_tags")))
	if _tut_idx < 0 or _tut_sid == "":
		return
	_tut_step_label.text = Lang.f("tutorial_step_label", [_tut_idx + 1, _tut_total])
	_tut_goal_label.text = Lang.t("tutorial_goal_" + _tut_sid)
	if _tut_bar_fg != null:
		var ratio := float(_tut_idx + 1) / float(maxi(1, _tut_total))
		_tut_bar_fg.size = Vector2(TUT_W * clampf(ratio, 0.0, 1.0), 4)


func _on_tutorial_step(index: int, total: int, step_id: String) -> void:
	_tut_idx = index
	_tut_total = total
	_tut_sid = step_id
	hide_tutorial()
	_ensure_tutorial_panel()
	_refresh_tutorial_text()


func _on_tutorial_finished() -> void:
	_tut_idx = -1
	_tut_total = 0
	_tut_sid = ""
	if _tut_panel != null and is_instance_valid(_tut_panel):
		_tut_panel.queue_free()
	_tut_panel = null


# ---------------- 回调 ----------------
func _on_hp() -> void:
	var mx: int = maxi(1, GameState.max_hp)
	var ratio := float(GameState.core_hp) / float(mx)
	_hp_fg.size.x = maxf(0.0, HP_W * ratio)
	_hp_fg.color = COLOR_HP_GOOD if ratio > 0.55 else (COLOR_HP_MID if ratio > 0.25 else COLOR_HP_LOW)
	_hp_label.text = "%s %d / %d" % [Lang.t("hud_hp"), GameState.core_hp, mx]


func _on_overload(value: float, tier: int) -> void:
	var ratio := clampf(value / 100.0, 0.0, 1.0)
	_ov_fg.size.x = maxf(0.0, OV_W * ratio)
	var col := COL_OV_STABLE
	match tier:
		1:
			col = COL_OV_HIGH
		2:
			col = COL_OV_DANGER
		3, 4:
			col = COL_OV_CRIT
	_ov_fg.color = col
	_ov_label.text = "%s %.0f%%" % [Lang.t("hud_overload"), value]
	_ov_tier.text = Lang.t(Overload.tier_key())
	_ov_tier.add_theme_color_override("font_color", col)
	var bonus := ""
	if tier >= 2:
		bonus = "  %d%%G" % int(round((Overload.gold_mult() - 1.0) * 100.0))
	_ov_tier.text += bonus


func _refresh_stats() -> void:
	_attr_label.text = "[color=#ff7260]%s %d[/color]  [color=#66d0ff]%s %d[/color]  [color=#8cff8c]%s %d[/color]  [color=#b9a6ff]%s x%.1f[/color]" % [
		Lang.t("hud_fire"), GameState.firepower,
		Lang.t("hud_cool"), GameState.cooling,
		Lang.t("hud_struct"), GameState.structure,
		Lang.t("hud_chain"), GameState.chain_mult(),
	]
	_stats_label = null
	_on_room_entered(GameState.biome_index, GameState.room_index,
		RunDirector.current_kind() if RunDirector.nodes.size() > 0 else "combat", GameState.room_depth)


func _on_gold(_g: int) -> void:
	_gold_label.text = "%s %d" % [Lang.t("hud_gold"), GameState.gold]


func _on_cells(_c: int) -> void:
	_cells_label.text = "%s %d" % [Lang.t("hud_cells"), GameState.cells]


func _on_energy(_e: int) -> void:
	_energy_label.text = "%s %d" % [Lang.t("hud_energy"), GameState.energy]


## 底层源代码是局外货币，跑图途中同步显示累计值
func _on_source() -> void:
	if _source_label != null:
		_source_label.text = "%s %d" % [Lang.t("hud_source"), MetaState.source_code]


func _on_weapon(slot: int, _id: String) -> void:
	_refresh_weapons(slot)
	_on_build()


func _refresh_weapons(active: int = -1) -> void:
	if active < 0:
		active = GameState.weapon_index
	for i in 2:
		var wid: String = GameState.weapons[i]
		var name_txt := Lang.t("w_" + wid) if wid != "" else Lang.t("hud_empty")
		var lab: Label = _slot_labels[i]
		var bg: Panel = _slot_bgs[i]
		var chip: ColorRect = _slot_chips[i]
		var wcol: Color = WeaponDB.color_of(wid) if wid != "" else Color(0.38, 0.45, 0.47)
		lab.text = "%d  %s" % [i + 1, name_txt]
		chip.color = wcol
		var st := UITheme.bar_slot(wcol, 3)
		if i == active:
			st.bg_color = Color(wcol.r * 0.28, wcol.g * 0.30, wcol.b * 0.30, 0.96)
			st.border_color = Color(wcol.r, wcol.g, wcol.b, 0.95)
			lab.add_theme_color_override("font_color", Color(0.94, 1.0, 0.98))
		else:
			st.bg_color = Color(0.045, 0.065, 0.082, 0.92)
			st.border_color = Color(wcol.r, wcol.g, wcol.b, 0.32)
			lab.add_theme_color_override("font_color", COLOR_DIM)
		bg.add_theme_stylebox_override("panel", st)


func _on_flask(_c: int) -> void:
	_refresh_pips()


func _refresh_pips() -> void:
	for c in _pips:
		if is_instance_valid(c):
			c.queue_free()
	_pips.clear()
	for i in GameState.flask_max:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(9, 20)
		var st := UITheme.bar_slot(UITheme.GREEN, 2)
		if i < GameState.flask_charges:
			st.bg_color = Color(0.16, 0.88, 0.48, 0.95)
			st.border_color = Color(0.60, 1.0, 0.75, 0.85)
		else:
			st.bg_color = Color(0.085, 0.120, 0.140, 0.92)
			st.border_color = Color(0.28, 0.36, 0.38, 0.70)
		pip.add_theme_stylebox_override("panel", st)
		_pip_box.add_child(pip)
		_pips.append(pip)


func _on_protocols(_p: Array) -> void:
	_on_build()


func _on_cards(_c: Array) -> void:
	_on_build()


func _on_build() -> void:
	_refresh_weapons()
	_refresh_pips()
	_refresh_tags()
	_refresh_protocols()
	_refresh_cards()


func _refresh_tags() -> void:
	for c in _tag_box.get_children():
		c.queue_free()
	var counts := GameState.tag_counts()
	for t in Tags.ALL:
		var n := int(counts.get(t, 0))
		if n <= 0:
			continue
		var tier := Tags.tier_of(n)
		var l := Label.new()
		l.text = "%s %d" % [Tags.short_name(t), n]
		l.add_theme_font_size_override("font_size", 13)
		if tier > 0:
			l.text += " ★%d" % tier
		UITheme.glow_label(l, Tags.color_of(t), Color(0.02, 0.04, 0.05, 0.9), 3)
		_tag_box.add_child(l)


func _refresh_protocols() -> void:
	var parts: Array = []
	for p in GameState.protocol_list():
		var pd: Dictionary = p
		var pid := str(pd["id"])
		parts.append("%s %s" % [Lang.t("proto_" + pid), _roman(int(pd["level"]))])
	if parts.is_empty():
		_protos_label.text = ""
	else:
		_protos_label.text = "%s: %s" % [Lang.t("proto_gained"), ", ".join(parts)]


func _roman(lv: int) -> String:
	match lv:
		1:
			return "I"
		2:
			return "II"
		3:
			return "III"
	return "?"


func _refresh_cards() -> void:
	var parts: Array = []
	for c in GameState.cards:
		var cd: Dictionary = c
		parts.append("%s(%d)" % [Lang.t("card_" + str(cd["id"])), int(cd["rooms"])])
	if parts.is_empty():
		_cards_label.text = ""
	else:
		_cards_label.text = ", ".join(parts)


func _on_room_entered(biome: int, room_index: int, room_type: String, depth: int) -> void:
	_room_label.text = "%s · %s" % [Lang.t("biome_%d" % (biome + 1)), Lang.t("room_" + room_type)]
	if room_type == "tutorial":
		_depth_label.text = Lang.t("tutorial_hud_tag")
	else:
		_depth_label.text = "%s %d · %s %d / %d" % [
			Lang.t("hud_depth"), depth, Lang.t("hud_room"),
			room_index + 1, maxi(1, RunDirector.cleared.size() + RunDirector.pending.size()),
		]
	# 异常规则
	var parts: Array = []
	for mid in GameState.room_modifiers:
		parts.append(ModifierDB.display_name(str(mid)))
	if parts.is_empty():
		_rules_label.text = ""
	else:
		_rules_label.text = "%s: %s" % [Lang.t("hud_rules"), " / ".join(parts)]
	if room_type == "tutorial":
		# 教学房用 EventBus.tutorial_step 驱动的专用目标面板，不叠加旧版说明面板
		hide_tutorial()
	elif biome == 0 and depth <= 1 and room_index == 0:
		hide_tutorial()
		show_tutorial()
	else:
		_on_tutorial_finished()


func _on_room_locked() -> void:
	hide_tutorial()
	_show_banner(Lang.t("room_locked"), 2.0, Color(1.0, 0.45, 0.35))


func _on_room_cleared() -> void:
	_show_banner(Lang.t("room_clear"), 2.0, Color(0.5, 1.0, 0.7))


func _on_toast(text: String) -> void:
	_toast_label.text = text
	_set_toast_alpha(1.0)
	_toast_t = 2.8


func _show_banner(text: String, dur: float, col: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", col)
	_banner_band.add_theme_stylebox_override("panel", UITheme.panel_flat(col, 0.30, 0.0, 0))
	_set_banner_alpha(1.0)
	_banner_t = dur


func _on_chain(_c: int) -> void:
	if GameState.chain >= 3:
		_chain_label.text = "%s %d  (+%d%%)" % [Lang.t("hud_chain"), GameState.chain,
			int(round((GameState.chain_mult() - 1.0) * 100.0))]
	else:
		_chain_label.text = ""


func _on_skill(skill_id: String) -> void:
	if Lang.has("skill_" + skill_id):
		EventBus.toast.emit(Lang.t("skill_" + skill_id))


func _on_meltdown(effect: String) -> void:
	_show_banner(Lang.t("melt_" + effect), 2.6, Color(1.0, 0.30, 0.30))


func _on_boss_spawned(boss_name: String, _hp: int) -> void:
	_boss_name.text = boss_name
	_boss_name.visible = true
	_boss_bg.visible = true
	_boss_fg.visible = true
	_boss_fg.size.x = BOSS_W
	for t in _boss_ticks:
		t.visible = true
	_show_banner(Lang.f("boss_incoming", [boss_name]), 2.4, Color(1.0, 0.42, 0.32))


func _on_boss_hp(cur: int, max_hp: int) -> void:
	if not _boss_fg.visible:
		return
	var r := clampf(float(cur) / float(maxi(1, max_hp)), 0.0, 1.0)
	_boss_fg.size.x = maxf(0.0, BOSS_W * r)
	_boss_fg.color = Color(0.95, 0.25, 0.20) if r > 0.3 else Color(1.0, 0.75, 0.2)


func _on_boss_died() -> void:
	_boss_name.visible = false
	_boss_bg.visible = false
	_boss_fg.visible = false
	for t in _boss_ticks:
		t.visible = false


func _on_saved() -> void:
	EventBus.toast.emit(Lang.t("pause_saved"))


func show_end(victory: bool, tech: int, source: int) -> void:
	_overlay.visible = true
	if victory:
		_ov_title.text = Lang.t("victory_title")
		_ov_stats.text = Lang.f("victory_stats", [GameState.kills, GameState.score])
		_ov_extra2.text = Lang.f("victory_source", [source])
	else:
		_ov_title.text = Lang.t("game_over_title")
		_ov_stats.text = Lang.f("game_over_stats", [
			GameState.kills, GameState.room_depth, GameState.score
		])
		_ov_extra2.text = Lang.f("game_over_source", [source])
	_ov_extra.text = Lang.f("game_over_cells", [tech])
	_ov_hint.text = Lang.t("restart_hint")


func hide_end() -> void:
	_overlay.visible = false


## 把所有带 lang_key 元数据的 Label 按当前语言重刷。
## 目的：切语言时整个 HUD（含指南栏那一坨静态文案）一起更新，不用逐个 connect。
func _refresh_lang_keys() -> void:
	if _root == null:
		return
	_walk_lang_keys(_root)


func _walk_lang_keys(n: Node) -> void:
	if n is Label and n.has_meta("lang_key"):
		var lab := n as Label
		lab.text = Lang.t(str(lab.get_meta("lang_key")))
	for c in n.get_children():
		_walk_lang_keys(c)


func _refresh_all() -> void:
	_on_hp()
	_refresh_stats()
	_on_gold(GameState.gold)
	_on_cells(GameState.cells)
	_on_energy(GameState.energy)
	_on_source()
	_on_overload(Overload.value, Overload.tier())
	_on_build()
	_refresh_lang_keys()
	_roll_label.text = Lang.t("hud_roll")
	_skill_label.text = Lang.t("hud_build")
	_vent_label.text = Lang.t("overload_vented")
	_on_chain(GameState.chain)
	_refresh_tutorial_text()
	if RunDirector.nodes.size() > 0:
		_on_room_entered(GameState.biome_index, GameState.room_index, RunDirector.current_kind(),
			GameState.room_depth)
