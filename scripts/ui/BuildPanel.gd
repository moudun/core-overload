extends CanvasLayer
## BuildPanel —— V1.3 构筑检视层（按住/按 Tab 切换）。
## 只回答一个问题：我这局构筑是什么？不暂停游戏，半透明覆盖。

const COL_BG := Color(0.02, 0.035, 0.055, 0.92)
const COL_BORDER := Color(0.26, 0.90, 0.82, 0.85)
const COL_TEXT := Color(0.86, 0.92, 0.90)
const COL_DIM := Color(0.55, 0.62, 0.62)

var _root: Control
var _title: Label
var _left: VBoxContainer
var _right: VBoxContainer
var _open := false


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	EventBus.build_changed.connect(func(): if _open: refresh())
	Lang.language_changed.connect(func(_c): if _open: refresh())


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var panel := PanelContainer.new()
	panel.position = Vector2(90, 96)
	panel.custom_minimum_size = Vector2(1100, 520)
	panel.add_theme_stylebox_override("panel",
		UITheme.panel_slice(COL_BORDER, 28.0, 28.0, 20.0, 20.0))
	_root.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	panel.add_child(outer)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", COL_BORDER)
	outer.add_child(_title)

	outer.add_child(HSeparator.new())

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 26)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(cols)

	_left = VBoxContainer.new()
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left.add_theme_constant_override("separation", 6)
	cols.add_child(_left)

	_right = VBoxContainer.new()
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.add_theme_constant_override("separation", 6)
	cols.add_child(_right)


func toggle() -> void:
	_open = not _open
	visible = _open
	if _open:
		refresh()


func close() -> void:
	_open = false
	visible = false


func _line(parent: VBoxContainer, text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(500, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func refresh() -> void:
	_title.text = Lang.t("hud_build")
	for c in _left.get_children():
		c.queue_free()
	for c in _right.get_children():
		c.queue_free()

	# ---- 左：武器 / 卷轴 / 标签 ----
	_line(_left, "─ %s ─" % Lang.t("hud_weapon"), 17, COL_BORDER)
	for i in GameState.weapons.size():
		var wid: String = GameState.weapons[i]
		if wid == "":
			_line(_left, "  %d  %s" % [i + 1, Lang.t("hud_empty")], 15, COL_DIM)
			continue
		var mark := "▶" if i == GameState.weapon_index else " "
		var tags_txt := _tags_text(WeaponDB.tags_of(wid))
		_line(_left, "  %s %d %s  %s" % [mark, i + 1, Lang.t("w_" + wid), tags_txt], 15, COL_TEXT)

	_line(_left, "─ %s ─" % Lang.t("hud_scrolls"), 17, COL_BORDER)
	_line(_left, "  %s %d    %s %d    %s %d" % [
		Lang.t("hud_fire"), GameState.firepower,
		Lang.t("hud_cool"), GameState.cooling,
		Lang.t("hud_struct"), GameState.structure], 15, COL_TEXT)
	_line(_left, "  %s %d   %s %d   %s %d" % [
		Lang.t("hud_gold"), GameState.gold, Lang.t("hud_cells"), GameState.cells,
		Lang.t("hud_energy"), GameState.energy], 15, COL_TEXT)

	_line(_left, "─ %s ─" % Lang.t("tag_SALVAGE").substr(0, 0) + "TAGS", 17, COL_BORDER)
	var counts := GameState.tag_counts()
	for t in Tags.ALL:
		var n := int(counts.get(t, 0))
		var tier := Tags.tier_of(n)
		var desc := ""
		if tier > 0:
			desc = Lang.t(Tags.DESC_KEYS[t][tier - 1])
		_line(_left, "  %s ×%d  ★%d  %s" % [Lang.t("tag_" + t), n, tier, desc], 14,
			Tags.color_of(t) if n > 0 else COL_DIM)

	# ---- 右：协议 / 过载卡 / 房间异常 ----
	_line(_right, "─ %s ─" % Lang.t("proto_gained"), 17, COL_BORDER)
	var plist := GameState.protocol_list()
	if plist.is_empty():
		_line(_right, "  " + Lang.t("hud_empty"), 15, COL_DIM)
	for p in plist:
		var pd: Dictionary = p
		var pid := str(pd["id"])
		var lv := int(pd["level"])
		var v := ProtocolDB.value_at(pid, lv)
		var dkey := "proto_" + pid + "_desc"
		var dtxt := dkey
		if Lang.has(dkey):
			dtxt = Lang.f(dkey, [int(round(v * 100.0)) if v <= 1.0 else int(v)])
		_line(_right, "  %s %s  —  %s" % [Lang.t("proto_" + pid), _roman(lv), dtxt], 14,
			Tags.color_of(str(ProtocolDB.tags_of(pid)[0])) if ProtocolDB.tags_of(pid).size() > 0 else COL_TEXT)

	_line(_right, "─ %s ─" % Lang.t("card_allin").substr(0, 0) + "CARDS", 17, COL_BORDER)
	if GameState.cards.is_empty():
		_line(_right, "  " + Lang.t("hud_empty"), 15, COL_DIM)
	for c in GameState.cards:
		var cd: Dictionary = c
		var cid := str(cd["id"])
		_line(_right, "  %s  (%s)" % [Lang.t("card_" + cid),
			Lang.f("card_rooms", [int(cd["rooms"])])], 14, Color(1.0, 0.62, 0.38))
		_line(_right, "      " + Lang.t("card_" + cid + "_desc"), 13, COL_DIM)

	_line(_right, "─ %s ─" % Lang.t("hud_rules"), 17, COL_BORDER)
	if GameState.room_modifiers.is_empty():
		_line(_right, "  " + Lang.t("hud_no_rule"), 15, COL_DIM)
	for mid in GameState.room_modifiers:
		_line(_right, "  %s — %s" % [ModifierDB.display_name(str(mid)), ModifierDB.desc(str(mid))],
			14, ModifierDB.color_of(str(mid)))

	if not MetaState.active_challenges.is_empty():
		_line(_right, "─ %s ─" % Lang.t("challenge_title"), 17, Color(1.0, 0.45, 0.45))
		for cid in MetaState.active_challenges:
			_line(_right, "  " + Lang.t("challenge_" + str(cid)), 14, Color(1.0, 0.55, 0.55))


func _tags_text(tags: Array) -> String:
	if tags.is_empty():
		return ""
	var parts: Array = []
	for t in tags:
		parts.append(Lang.t("tag_" + str(t)))
	return "[%s]" % ", ".join(parts)


func _roman(lv: int) -> String:
	match lv:
		1:
			return "I"
		2:
			return "II"
		3:
			return "III"
	return "?"
