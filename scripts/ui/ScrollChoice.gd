extends CanvasLayer
## ScrollChoice —— 过载卷轴三选一（Dead Cells 式）。
## 打开时暂停游戏树，选择后恢复；支持鼠标点击与数字键 1/2/3。

const KINDS := ["firepower", "cooling", "structure"]
const COLORS := {
	"firepower": Color(1.0, 0.42, 0.35),
	"cooling": Color(0.35, 0.80, 1.0),
	"structure": Color(0.55, 1.0, 0.58),
}

var _root: Control
var _box: HBoxContainer
var _title: Label
var _options: Array = []
var _open := false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	EventBus.scroll_choice_opened.connect(_open_panel)
	Lang.language_changed.connect(func(_c): if _open: _refresh_texts())


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	_title = Label.new()
	_title.position = Vector2(0, 128)
	_title.size = Vector2(1280, 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 32)
	_title.add_theme_color_override("font_color", Color(0.75, 1.0, 0.9))
	_root.add_child(_title)

	_box = HBoxContainer.new()
	_box.position = Vector2(190, 220)
	_box.add_theme_constant_override("separation", 28)
	_root.add_child(_box)


func _open_panel(options: Array) -> void:
	if _open:
		return
	_open = true
	visible = true
	get_tree().paused = true
	_options = options if not options.is_empty() else KINDS.duplicate()
	_rebuild_cards()


func _rebuild_cards() -> void:
	for c in _box.get_children():
		c.queue_free()
	_refresh_texts()
	for i in _options.size():
		_box.add_child(_make_card(i, str(_options[i])))


func _make_card(idx: int, kind: String) -> Control:
	var col: Color = COLORS.get(kind, Color(0.7, 0.7, 0.7))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(268, 260)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.06, 0.94)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 22.0
	sb.content_margin_bottom = 20.0
	card.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)

	var num := Label.new()
	num.text = "%d" % (idx + 1)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.add_theme_font_size_override("font_size", 40)
	num.add_theme_color_override("font_color", col)
	vb.add_child(num)

	var icon := TextureRect.new()
	icon.texture = PixelArt.scroll_tex(col)
	icon.custom_minimum_size = Vector2(64, 64)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vb.add_child(icon)

	var nm := Label.new()
	nm.name = "NameLabel"
	nm.text = Lang.t("scroll_" + kind)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_font_size_override("font_size", 24)
	nm.add_theme_color_override("font_color", col)
	vb.add_child(nm)

	var desc := Label.new()
	desc.name = "DescLabel"
	desc.text = Lang.t("scroll_" + kind + "_desc")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(220, 60)
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.78, 0.86, 0.82))
	vb.add_child(desc)

	var btn := Button.new()
	btn.name = "PickButton"
	btn.text = Lang.t("collector_buy")
	btn.custom_minimum_size = Vector2(200, 34)
	btn.add_theme_font_size_override("font_size", 16)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(func(): _choose(kind))
	vb.add_child(btn)

	card.set_meta("kind", kind)
	card.set_meta("name_label", nm)
	card.set_meta("desc_label", desc)
	card.set_meta("pick_button", btn)
	return card


func _refresh_texts() -> void:
	_title.text = Lang.t("scroll_title")
	for card in _box.get_children():
		var kind: String = str(card.get_meta("kind", ""))
		if kind == "":
			continue
		var nm: Label = card.get_meta("name_label")
		var desc: Label = card.get_meta("desc_label")
		var btn: Button = card.get_meta("pick_button")
		nm.text = Lang.t("scroll_" + kind)
		desc.text = Lang.t("scroll_" + kind + "_desc")
		btn.text = Lang.t("collector_buy")


func _choose(kind: String) -> void:
	if not _open:
		return
	_open = false
	visible = false
	get_tree().paused = false
	GameState.grant_scroll(kind)
	EventBus.scroll_chosen.emit(kind)
	EventBus.toast.emit("%s %s" % [Lang.t("picked_prefix"), Lang.t("scroll_" + kind)])


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var idx := -1
		match event.keycode:
			KEY_1:
				idx = 0
			KEY_2:
				idx = 1
			KEY_3:
				idx = 2
		if idx >= 0 and idx < _options.size():
			_choose(str(_options[idx]))
