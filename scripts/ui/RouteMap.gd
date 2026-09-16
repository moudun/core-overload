extends CanvasLayer
## RouteMap —— V1.3 路线图覆盖层。
## 清空房间后弹出：展示当前可选的后续节点（room_type / 风险 / 奖励提示），
## 点击或按 1-4 键选择；同时用顶部条带展示整条系统拓扑图的进度。

const CARD_W := 246.0
const CARD_H := 300.0
const CARD_GAP := 24.0

const COL_BG := Color(0.02, 0.035, 0.055, 0.94)
const COL_BORDER := Color(0.26, 0.90, 0.82)
const COL_TEXT := Color(0.88, 0.94, 0.92)
const COL_DIM := Color(0.52, 0.60, 0.62)

var _root: Control
var _title: Label
var _subtitle: Label
var _hint: Label
var _box: HBoxContainer
var _strip: Control
var _choices: Array = []
var _open := false


func _ready() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	EventBus.route_ready.connect(_open_panel)
	Lang.language_changed.connect(func(_c): if _open: _rebuild())


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.03, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	_title = Label.new()
	_title.position = Vector2(0, 42)
	_title.size = Vector2(1280, 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", COL_BORDER)
	_root.add_child(_title)

	_subtitle = Label.new()
	_subtitle.position = Vector2(0, 86)
	_subtitle.size = Vector2(1280, 26)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 17)
	_subtitle.add_theme_color_override("font_color", COL_TEXT)
	_root.add_child(_subtitle)

	_strip = Control.new()
	_strip.position = Vector2(0, 126)
	_strip.size = Vector2(1280, 54)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.draw.connect(_draw_strip)
	_root.add_child(_strip)

	_box = HBoxContainer.new()
	_box.position = Vector2(0, 216)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", int(CARD_GAP))
	_root.add_child(_box)

	_hint = Label.new()
	_hint.position = Vector2(0, 640)
	_hint.size = Vector2(1280, 24)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", COL_DIM)
	_root.add_child(_hint)


func _open_panel(choices: Array) -> void:
	if _open:
		return
	_open = true
	_choices = choices
	visible = true
	get_tree().paused = true
	_rebuild()


func _rebuild() -> void:
	_title.text = Lang.t("route_title")
	_subtitle.text = "%s  ·  %s" % [RunDirector.biome_name(),
		Lang.f("route_biome", [RunDirector.biome + 1])]
	_hint.text = Lang.t("route_hint")
	for c in _box.get_children():
		c.queue_free()
	for i in _choices.size():
		_box.add_child(_make_card(i, _choices[i] as Dictionary))
	_strip.queue_redraw()


func _make_card(idx: int, node: Dictionary) -> Control:
	var kind := str(node.get("kind", "combat"))
	var col: Color = node.get("color", Color(0.6, 0.6, 0.6))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.add_theme_stylebox_override("panel",
		UITheme.panel_slice(col, 18.0, 18.0, 16.0, 16.0))

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	var num := Label.new()
	num.text = str(idx + 1)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.add_theme_font_size_override("font_size", 30)
	num.add_theme_color_override("font_color", col)
	vb.add_child(num)

	var icon := TextureRect.new()
	icon.texture = PixelArt.card_tex(44, col)
	icon.custom_minimum_size = Vector2(56, 56)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vb.add_child(icon)

	var nm := Label.new()
	nm.text = str(node.get("name", "?"))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_font_size_override("font_size", 21)
	nm.add_theme_color_override("font_color", col)
	vb.add_child(nm)

	var layer_l := Label.new()
	layer_l.text = Lang.f("route_depth", [int(node.get("layer", 1)) + 1])
	layer_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer_l.add_theme_font_size_override("font_size", 13)
	layer_l.add_theme_color_override("font_color", COL_DIM)
	vb.add_child(layer_l)

	var risk_row := HBoxContainer.new()
	risk_row.alignment = BoxContainer.ALIGNMENT_CENTER
	risk_row.add_theme_constant_override("separation", 4)
	for i in 5:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(16, 8)
		pip.color = col if i < int(node.get("risk", 1)) else Color(0.14, 0.17, 0.19)
		risk_row.add_child(pip)
	vb.add_child(risk_row)

	var reward := Label.new()
	reward.text = str(node.get("reward", ""))
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward.custom_minimum_size = Vector2(CARD_W - 40, 44)
	reward.add_theme_font_size_override("font_size", 14)
	reward.add_theme_color_override("font_color", COL_TEXT)
	vb.add_child(reward)

	var btn := Button.new()
	btn.text = "▶"
	btn.custom_minimum_size = Vector2(0, 34)
	btn.add_theme_font_size_override("font_size", 18)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(func(): _choose(int(node.get("id", -1))))
	vb.add_child(btn)
	return card


func _draw_strip() -> void:
	# 顶部条带：每一层一个点，已通过的层为青色，当前可选择为琥珀
	var total := RunDirector.layers.size()
	if total <= 0:
		return
	var w := float(_strip.size.x)
	var step := w / float(total + 1)
	for li in total:
		var x := step * float(li + 1)
		var y := 26.0
		var col := Color(0.16, 0.22, 0.24)
		var r := 7.0
		var layer_nodes: Array = RunDirector.layers[li]
		var cleared_here := 0
		var pending_here := 0
		for nid in layer_nodes:
			if RunDirector.cleared.has(int(nid)):
				cleared_here += 1
			if RunDirector.pending.has(int(nid)):
				pending_here += 1
		if pending_here > 0:
			col = Color(1.0, 0.70, 0.28)
			r = 10.0
		elif cleared_here == layer_nodes.size() and cleared_here > 0:
			col = Color(0.26, 0.90, 0.82)
		_strip.draw_circle(Vector2(x, y), r, col)
		if li < total - 1:
			_strip.draw_line(Vector2(x + 12, y), Vector2(step * float(li + 2) - 12, y),
				Color(0.20, 0.30, 0.32), 2.0)
		if RunDirector.current >= 0 and RunDirector.current < RunDirector.nodes.size() \
				and layer_nodes.has(RunDirector.current):
			_strip.draw_arc(Vector2(x, y), 14.0, 0.0, TAU, 24, Color(0.88, 0.94, 0.92), 2.0)


func _choose(node_id: int) -> void:
	if not _open:
		return
	_open = false
	visible = false
	get_tree().paused = false
	RunDirector.choose(node_id)


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
			KEY_4:
				idx = 3
		if idx >= 0 and idx < _choices.size():
			_choose(int((_choices[idx] as Dictionary).get("id", -1)))
