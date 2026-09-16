extends Control
## ChallengePanel.gd —— V1.3 挑战词缀选择（开局前自由组合）。
## 需要先在「收集者 · 挑战协议」解锁；选择结果写入 MetaState.active_challenges，
## 由 GameState.challenge_agg() 在开局时转成实际难度修正。

const COL_BG := Color(0.015, 0.028, 0.042, 0.96)
const COL_BORDER := Color(0.26, 0.90, 0.82, 0.85)
const COL_TEXT := Color(0.88, 0.94, 0.90)
const COL_DIM := Color(0.52, 0.60, 0.60)
const COL_ON := Color(1.0, 0.55, 0.45)
const COL_LOCK := Color(1.0, 0.70, 0.28)

const IDS := ["thermal", "noheal", "glass", "signal", "blackout", "hunger"]

var _root: Control
var _title: Label
var _lock_label: Label
var _sub: Label
var _entry_vb: VBoxContainer
var _clear_btn: Button
var _back_btn: Button
var _rows: Array = []


func _ready() -> void:
	z_index = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	visible = false
	Lang.language_changed.connect(func(_c): _refresh())
	MetaState.meta_changed.connect(func(): if visible: _refresh())


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.84)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.position = Vector2(340, 90)
	panel.custom_minimum_size = Vector2(600, 540)
	panel.add_theme_stylebox_override("panel",
		UITheme.panel_slice(COL_BORDER, 34.0, 34.0, 24.0, 20.0))
	_root.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	_title = _mk(vb, 26, COL_BORDER, HORIZONTAL_ALIGNMENT_CENTER)
	_sub = _mk(vb, 14, COL_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_lock_label = _mk(vb, 15, COL_LOCK, HORIZONTAL_ALIGNMENT_CENTER)
	_lock_label.visible = false
	vb.add_child(HSeparator.new())

	_entry_vb = VBoxContainer.new()
	_entry_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_entry_vb.add_theme_constant_override("separation", 8)
	vb.add_child(_entry_vb)

	for cid in IDS:
		_entry_vb.add_child(_make_row(cid))

	vb.add_child(HSeparator.new())

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(btns)
	_clear_btn = Button.new()
	_clear_btn.custom_minimum_size = Vector2(200, 42)
	_clear_btn.add_theme_font_size_override("font_size", 17)
	_clear_btn.focus_mode = Control.FOCUS_NONE
	_clear_btn.pressed.connect(func() -> void:
		MetaState.clear_challenges()
		_refresh())
	btns.add_child(_clear_btn)

	_back_btn = Button.new()
	_back_btn.custom_minimum_size = Vector2(200, 42)
	_back_btn.add_theme_font_size_override("font_size", 17)
	_back_btn.focus_mode = Control.FOCUS_NONE
	_back_btn.pressed.connect(hide_panel)
	btns.add_child(_back_btn)


func _mk(parent: Node, size: int, col: Color, align: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _make_row(cid: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := Label.new()
	nm.add_theme_font_size_override("font_size", 17)
	nm.add_theme_color_override("font_color", COL_TEXT)
	info.add_child(nm)
	var desc := Label.new()
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", COL_DIM)
	info.add_child(desc)
	row.add_child(info)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120, 0)
	btn.add_theme_font_size_override("font_size", 15)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(func() -> void:
		MetaState.toggle_challenge(cid)
		_refresh())
	row.add_child(btn)

	row.set_meta("cid", cid)
	row.set_meta("name_label", nm)
	row.set_meta("desc_label", desc)
	row.set_meta("btn", btn)
	_rows.append(row)
	return row


func show_panel() -> void:
	visible = true
	_refresh()


func hide_panel() -> void:
	visible = false


func _refresh() -> void:
	_title.text = Lang.t("challenge_title")
	_back_btn.text = Lang.t("back")
	_clear_btn.text = Lang.t("challenge_none")
	var unlocked := MetaState.challenge_unlocked()
	_lock_label.visible = not unlocked
	_lock_label.text = Lang.t("challenge_locked")
	_sub.text = ""
	for row in _rows:
		if not is_instance_valid(row):
			continue
		var cid := str(row.get_meta("cid"))
		var nm: Label = row.get_meta("name_label")
		var desc: Label = row.get_meta("desc_label")
		var btn: Button = row.get_meta("btn")
		var on := MetaState.active_challenges.has(cid)
		nm.text = Lang.t("challenge_" + cid)
		desc.text = Lang.t("challenge_" + cid + "_desc")
		if not unlocked:
			nm.add_theme_color_override("font_color", COL_DIM)
			btn.text = "LOCKED"
			btn.disabled = true
			continue
		btn.disabled = false
		nm.add_theme_color_override("font_color", COL_ON if on else COL_TEXT)
		btn.text = "ON" if on else "OFF"
		btn.add_theme_color_override("font_color", COL_ON if on else COL_DIM)
