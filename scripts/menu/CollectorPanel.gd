extends Control
## CollectorPanel —— 收集者（局外永久升级）。
## 用科技点购买永久强化；数据持久化由 MetaState 负责。

var _root: Control
var _tech_label: Label
var _title: Label
var _rows_vb: VBoxContainer
var _back_btn: Button
var _rows: Array = []


func _ready() -> void:
	z_index = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	visible = false
	Lang.language_changed.connect(func(_c): _refresh())


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(760, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.015, 0.02, 0.035, 0.95)
	sb.border_color = Color(0.32, 0.55, 0.8, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 40.0
	sb.content_margin_right = 40.0
	sb.content_margin_top = 30.0
	sb.content_margin_bottom = 26.0
	panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", Color(0.55, 0.95, 0.90))
	vb.add_child(_title)

	_tech_label = Label.new()
	_tech_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tech_label.add_theme_font_size_override("font_size", 20)
	_tech_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	vb.add_child(_tech_label)

	vb.add_child(HSeparator.new())

	_rows_vb = VBoxContainer.new()
	_rows_vb.add_theme_constant_override("separation", 8)
	vb.add_child(_rows_vb)

	for u in MetaState.UPGRADES:
		_rows_vb.add_child(_make_row(u))

	vb.add_child(HSeparator.new())

	_back_btn = Button.new()
	_back_btn.custom_minimum_size = Vector2(0, 44)
	_back_btn.add_theme_font_size_override("font_size", 20)
	_back_btn.focus_mode = Control.FOCUS_NONE
	_back_btn.pressed.connect(hide_panel)
	vb.add_child(_back_btn)


func _make_row(u: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := Label.new()
	nm.add_theme_font_size_override("font_size", 19)
	nm.add_theme_color_override("font_color", Color(0.88, 0.94, 0.90))
	info.add_child(nm)
	var desc := Label.new()
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.60, 0.68, 0.64))
	info.add_child(desc)
	row.add_child(info)

	var lv := Label.new()
	lv.custom_minimum_size = Vector2(70, 0)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lv.add_theme_font_size_override("font_size", 16)
	lv.add_theme_color_override("font_color", Color(0.70, 0.86, 1.0))
	row.add_child(lv)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 0)
	btn.add_theme_font_size_override("font_size", 16)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(func(): _try_buy(str(u["id"])))
	row.add_child(btn)

	row.set_meta("u", u)
	row.set_meta("name_label", nm)
	row.set_meta("desc_label", desc)
	row.set_meta("lv_label", lv)
	row.set_meta("buy_button", btn)
	_rows.append(row)
	return row


func show_panel() -> void:
	visible = true
	_refresh()


func hide_panel() -> void:
	visible = false


func _try_buy(id: String) -> void:
	if MetaState.buy(id):
		_refresh()
	else:
		_refresh()


func _refresh() -> void:
	_title.text = Lang.t("collector_title")
	_tech_label.text = Lang.f("collector_tech", [MetaState.tech_points])
	_back_btn.text = Lang.t("back")
	for row in _rows:
		if not is_instance_valid(row):
			continue
		var u: Dictionary = row.get_meta("u")
		var id := str(u["id"])
		var lv: int = MetaState.level_of(id)
		var mx := int(u["max"])
		var nm: Label = row.get_meta("name_label")
		var desc: Label = row.get_meta("desc_label")
		var lv_label: Label = row.get_meta("lv_label")
		var btn: Button = row.get_meta("buy_button")
		nm.text = Lang.t(str(u["key"]))
		desc.text = Lang.t(str(u["desc_key"]))
		lv_label.text = "Lv %d/%d" % [lv, mx]
		var cost := MetaState.next_cost(id)
		if cost < 0:
			btn.text = Lang.t("collector_max")
			btn.disabled = true
		else:
			btn.text = "%s %d" % [Lang.t("collector_buy"), cost]
			btn.disabled = not MetaState.can_buy(id)
