extends Control
## ArchivePanel.gd —— V1.3 收藏者档案（图鉴）。
## 展示已收录的武器 / 协议 / 过载卡 / Boss；未发现的显示为「未发现」。
## 收录由 MetaState.archive_see() 在 Run 中自动完成。

const COL_BG := Color(0.015, 0.028, 0.042, 0.96)
const COL_BORDER := Color(0.26, 0.90, 0.82, 0.85)
const COL_TEXT := Color(0.88, 0.94, 0.90)
const COL_DIM := Color(0.42, 0.48, 0.48)

var _root: Control
var _title: Label
var _hint: Label
var _heads: Array = []
var _cols: Array = []
var _col_vbs: Array = []
var _back_btn: Button

const CATEGORIES := ["weapon", "protocol", "card", "boss"]


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
	dim.color = Color(0, 0, 0, 0.84)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.position = Vector2(120, 36)
	panel.custom_minimum_size = Vector2(1040, 648)
	panel.add_theme_stylebox_override("panel",
		UITheme.panel_slice(COL_BORDER, 34.0, 34.0, 22.0, 18.0))
	_root.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	_title = _mk_label(vb, 28, COL_BORDER, HORIZONTAL_ALIGNMENT_CENTER)
	_hint = _mk_label(vb, 13, COL_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 26)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(cols)

	for cat in CATEGORIES:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(238, 0)
		col.add_theme_constant_override("separation", 5)
		cols.add_child(col)
		var head := _mk_label(col, 17, COL_BORDER, HORIZONTAL_ALIGNMENT_LEFT)
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 3)
		col.add_child(list)
		_cols.append(cat)
		_heads.append(head)
		_col_vbs.append(list)

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


func show_panel() -> void:
	visible = true
	_refresh()


func hide_panel() -> void:
	visible = false


func _ids_of(cat: String) -> Array:
	match cat:
		"weapon":
			return WeaponDB.ALL_IDS
		"protocol":
			return ProtocolDB.ALL_IDS
		"card":
			return CardDB.ALL_IDS
		"boss":
			var out: Array = []
			for b in EnemyDB.BOSSES:
				out.append(str((b as Dictionary)["id"]))
			return out
	return []


func _name_of(cat: String, id: String) -> String:
	match cat:
		"weapon":
			return Lang.t("w_" + id)
		"protocol":
			return Lang.t("proto_" + id)
		"card":
			return Lang.t("card_" + id)
		"boss":
			for b in EnemyDB.BOSSES:
				if str((b as Dictionary)["id"]) == id:
					return str((b as Dictionary)["name"])
	return id


func _refresh() -> void:
	_title.text = Lang.t("archive_title")
	_hint.text = Lang.t("archive_hint")
	_back_btn.text = Lang.t("back")
	for i in _cols.size():
		var cat := str(_cols[i])
		var head: Label = _heads[i]
		var list: VBoxContainer = _col_vbs[i]
		var total := MetaState.archive_total(cat)
		var head_key := "archive_" + cat + "s"
		if cat == "boss":
			head_key = "archive_bosses"
		head.text = "%s  (%s)" % [
			Lang.t(head_key),
			Lang.f("archive_progress", [MetaState.archive_count(cat), total]),
		]
		for c in list.get_children():
			c.queue_free()
		for id in _ids_of(cat):
			var found := MetaState.archive_has(cat, str(id))
			var l := Label.new()
			l.add_theme_font_size_override("font_size", 14)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if found:
				l.text = "● " + _name_of(cat, str(id))
				l.add_theme_color_override("font_color", COL_TEXT)
			else:
				l.text = "○ " + Lang.t("archive_unknown")
				l.add_theme_color_override("font_color", COL_DIM)
			list.add_child(l)
