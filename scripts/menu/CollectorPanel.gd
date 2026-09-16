extends Control
## CollectorPanel.gd —— V1.3 收集者（局外成长 · 双货币）。
##
##   数值强化（科技点）   —— 单局「细胞」1:1 兑换，纵向成长
##   玩法解锁（源代码）   —— 骇入 / Boss / 区块 / 通关产出，横向解锁玩法
## 购买逻辑与持久化由 MetaState 负责。

const COL_BG := Color(0.015, 0.028, 0.042, 0.96)
const COL_BORDER := Color(0.26, 0.90, 0.82, 0.85)
const COL_TEXT := Color(0.88, 0.94, 0.90)
const COL_DIM := Color(0.55, 0.62, 0.62)
const COL_TECH := Color(0.50, 0.95, 0.92)
const COL_SOURCE := Color(0.30, 1.00, 0.80)

var _root: Control
var _title: Label
var _tech_label: Label
var _source_label: Label
var _numeric_head: Label
var _unlock_head: Label
var _numeric_vb: VBoxContainer
var _unlock_vb: VBoxContainer
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
	panel.position = Vector2(190, 40)
	panel.custom_minimum_size = Vector2(900, 640)
	panel.add_theme_stylebox_override("panel",
		UITheme.panel_slice(COL_BORDER, 34.0, 34.0, 24.0, 20.0))
	_root.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	_title = _mk_label(vb, 28, COL_BORDER, HORIZONTAL_ALIGNMENT_CENTER)

	var wallet := HBoxContainer.new()
	wallet.alignment = BoxContainer.ALIGNMENT_CENTER
	wallet.add_theme_constant_override("separation", 40)
	vb.add_child(wallet)
	_tech_label = _mk_label(wallet, 19, COL_TECH, HORIZONTAL_ALIGNMENT_CENTER)
	_source_label = _mk_label(wallet, 19, COL_SOURCE, HORIZONTAL_ALIGNMENT_CENTER)

	vb.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 30)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(cols)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(400, 0)
	left.add_theme_constant_override("separation", 6)
	cols.add_child(left)
	_numeric_head = _mk_label(left, 18, COL_TECH, HORIZONTAL_ALIGNMENT_LEFT)
	_numeric_vb = VBoxContainer.new()
	_numeric_vb.add_theme_constant_override("separation", 8)
	left.add_child(_numeric_vb)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(400, 0)
	right.add_theme_constant_override("separation", 6)
	cols.add_child(right)
	_unlock_head = _mk_label(right, 18, COL_SOURCE, HORIZONTAL_ALIGNMENT_LEFT)
	_unlock_vb = VBoxContainer.new()
	_unlock_vb.add_theme_constant_override("separation", 8)
	right.add_child(_unlock_vb)

	for u in MetaDB.UPGRADES:
		var target: VBoxContainer = _numeric_vb if str(u["cur"]) == MetaDB.CUR_TECH else _unlock_vb
		target.add_child(_make_row(u))

	vb.add_child(HSeparator.new())
	_back_btn = Button.new()
	_back_btn.custom_minimum_size = Vector2(0, 42)
	_back_btn.add_theme_font_size_override("font_size", 19)
	_back_btn.focus_mode = Control.FOCUS_NONE
	_back_btn.pressed.connect(hide_panel)
	vb.add_child(_back_btn)


func _mk_label(parent: Node, size: int, col: Color, align: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _make_row(u: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := Label.new()
	nm.add_theme_font_size_override("font_size", 17)
	nm.add_theme_color_override("font_color", COL_TEXT)
	info.add_child(nm)
	var desc := Label.new()
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", COL_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(230, 0)
	info.add_child(desc)
	row.add_child(info)

	var lv := Label.new()
	lv.custom_minimum_size = Vector2(62, 0)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lv.add_theme_font_size_override("font_size", 15)
	lv.add_theme_color_override("font_color", Color(0.70, 0.86, 1.0))
	row.add_child(lv)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(104, 0)
	btn.add_theme_font_size_override("font_size", 15)
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
	MetaState.buy(id)
	_refresh()


func _refresh() -> void:
	_title.text = Lang.t("collector_title")
	_tech_label.text = Lang.f("collector_tech", [MetaState.tech_points])
	_source_label.text = Lang.f("collector_source", [MetaState.source_code])
	_numeric_head.text = "── %s ──" % Lang.t("collector_branch_numeric")
	_unlock_head.text = "── %s ──" % Lang.t("collector_branch_unlock")
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
			if MetaState.can_buy(id):
				btn.add_theme_color_override("font_color",
					COL_SOURCE if str(u["cur"]) == MetaDB.CUR_SOURCE else COL_TECH)
			else:
				btn.add_theme_color_override("font_color", COL_DIM)
