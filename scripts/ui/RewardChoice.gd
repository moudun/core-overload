extends CanvasLayer
## RewardChoice —— V1.3 统一奖励三选一面板。
## 同时处理两种来源：
##   EventBus.scroll_choice_opened(Array[String])       —— 卷轴三选一（宝箱 / 藏宝房）
##   EventBus.reward_choice_opened(Array[Dictionary])   —— 通用奖励（卷轴/协议/卡/武器）
## 打开时暂停游戏树；支持鼠标点击与数字键，并把折叠协议的重掷次数用上。

const CARD_W := 268.0
const CARD_H := 300.0

const COL_BG := Color(0.03, 0.05, 0.06, 0.96)
const COL_TEXT := Color(0.80, 0.88, 0.84)
const COL_DIM := Color(0.55, 0.62, 0.60)

const SCROLL_COLORS := {
	"firepower": Color(1.0, 0.42, 0.35),
	"cooling": Color(0.35, 0.80, 1.0),
	"structure": Color(0.55, 1.0, 0.58),
	"energy": Color(1.0, 0.82, 0.32),
}

var _root: Control
var _title: Label
var _hint: Label
var _box: HBoxContainer
var _reroll_btn: Button
var _options: Array = []
var _open := false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	EventBus.scroll_choice_opened.connect(_on_scroll_signal)
	EventBus.reward_choice_opened.connect(_on_reward_signal)
	Lang.language_changed.connect(func(_c): if _open: _rebuild())


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	_title = Label.new()
	_title.position = Vector2(0, 96)
	_title.size = Vector2(1280, 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", Color(0.75, 1.0, 0.9))
	_root.add_child(_title)

	_box = HBoxContainer.new()
	_box.position = Vector2(0, 186)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 26)
	_root.add_child(_box)

	_reroll_btn = Button.new()
	_reroll_btn.position = Vector2(520, 528)
	_reroll_btn.custom_minimum_size = Vector2(240, 40)
	_reroll_btn.add_theme_font_size_override("font_size", 17)
	_reroll_btn.focus_mode = Control.FOCUS_NONE
	_reroll_btn.pressed.connect(_reroll)
	_root.add_child(_reroll_btn)

	_hint = Label.new()
	_hint.position = Vector2(0, 586)
	_hint.size = Vector2(1280, 22)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", COL_DIM)
	_root.add_child(_hint)


func _on_scroll_signal(options: Array) -> void:
	var conv: Array = []
	for o in options:
		conv.append({"kind": "scroll", "id": str(o)})
	_open_panel(conv)


func _on_reward_signal(options: Array) -> void:
	_open_panel(options)


func _open_panel(options: Array) -> void:
	if _open:
		return
	_open = true
	visible = true
	get_tree().paused = true
	_options = options
	_rebuild()


func _rebuild() -> void:
	_title.text = Lang.t("reward_title")
	_hint.text = Lang.t("route_hint")
	for c in _box.get_children():
		c.queue_free()
	for i in _options.size():
		_box.add_child(_make_card(i, _options[i] as Dictionary))
	var left := GameState.reroll_left
	if left > 0:
		_reroll_btn.visible = true
		_reroll_btn.text = Lang.f("reward_reroll", [left])
		_reroll_btn.disabled = false
	else:
		_reroll_btn.visible = true
		_reroll_btn.text = Lang.t("reward_reroll_none")
		_reroll_btn.disabled = true


func _option_color(opt: Dictionary) -> Color:
	var kind := str(opt.get("kind", "scroll"))
	var id := str(opt.get("id", ""))
	match kind:
		"scroll":
			return SCROLL_COLORS.get(id, Color(0.6, 0.9, 0.9))
		"protocol":
			var tl: Array = ProtocolDB.tags_of(id)
			if tl.is_empty():
				return Color(0.72, 0.62, 1.0)
			return Tags.color_of(str(tl[0]))
		"card":
			var ct: Array = CardDB.tags_of(id)
			if ct.is_empty():
				return Color(1.0, 0.55, 0.35)
			return Tags.color_of(str(ct[0]))
		"weapon":
			return WeaponDB.color_of(id)
	return Color(0.7, 0.7, 0.7)


func _option_title(opt: Dictionary) -> String:
	var kind := str(opt.get("kind", "scroll"))
	var id := str(opt.get("id", ""))
	match kind:
		"scroll":
			return Lang.t("scroll_" + id)
		"protocol":
			var lv := GameState.protocol_level(id) + 1
			return "%s %s" % [Lang.t("proto_" + id), _roman(mini(lv, 3))]
		"card":
			return Lang.t("card_" + id)
		"weapon":
			return Lang.t("w_" + id)
	return id


func _roman(lv: int) -> String:
	match lv:
		1:
			return "I"
		2:
			return "II"
		3:
			return "III"
	return ""


func _option_desc(opt: Dictionary) -> String:
	var kind := str(opt.get("kind", "scroll"))
	var id := str(opt.get("id", ""))
	match kind:
		"scroll":
			return Lang.t("scroll_" + id + "_desc")
		"protocol":
			var lv := mini(GameState.protocol_level(id) + 1, 3)
			var key := "proto_" + id + "_desc"
			if not Lang.has(key):
				return ""
			var v := ProtocolDB.value_at(id, lv)
			if v <= 1.0:
				return Lang.f(key, [int(round(v * 100.0))])
			return Lang.f(key, [int(v)])
		"card":
			return "%s\n%s" % [
				Lang.t("card_" + id + "_desc"),
				Lang.f("card_rooms", [int(CardDB.info(id).get("rooms", 1))]),
			]
		"weapon":
			var w := WeaponDB.info(id)
			return "%s: %d  ·  CD %.2fs" % [
				Lang.t("reward_scope_scroll"), int(w.get("dmg", 0)), float(w.get("cd", 0.0))]
	return ""


func _make_card(idx: int, opt: Dictionary) -> Control:
	var col := _option_color(opt)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.add_theme_stylebox_override("panel",
		UITheme.panel_slice(col, 20.0, 20.0, 20.0, 18.0))

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	var num := Label.new()
	num.text = str(idx + 1)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.add_theme_font_size_override("font_size", 34)
	num.add_theme_color_override("font_color", col)
	vb.add_child(num)

	var icon := TextureRect.new()
	var kind := str(opt.get("kind", "scroll"))
	if kind == "weapon":
		icon.texture = PixelArt.weapon_drop_tex(col)
	elif kind == "protocol":
		icon.texture = PixelArt.protocol_tex(col)
	elif kind == "card":
		icon.texture = PixelArt.card_icon_tex(col)
	else:
		icon.texture = PixelArt.scroll_tex(col)
	icon.custom_minimum_size = Vector2(60, 60)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vb.add_child(icon)

	var scope := Label.new()
	scope.text = Lang.t("reward_scope_" + kind)
	scope.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scope.add_theme_font_size_override("font_size", 12)
	scope.add_theme_color_override("font_color", COL_DIM)
	vb.add_child(scope)

	var nm := Label.new()
	nm.text = _option_title(opt)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(CARD_W - 40, 30)
	nm.add_theme_font_size_override("font_size", 21)
	nm.add_theme_color_override("font_color", col)
	vb.add_child(nm)

	var desc := Label.new()
	desc.text = _option_desc(opt)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(CARD_W - 40, 70)
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", COL_TEXT)
	vb.add_child(desc)

	var btn := Button.new()
	btn.text = Lang.t("collector_buy")
	btn.custom_minimum_size = Vector2(0, 32)
	btn.add_theme_font_size_override("font_size", 16)
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(func(): _choose(opt))
	vb.add_child(btn)
	return card


func _reroll() -> void:
	if GameState.reroll_left <= 0:
		return
	GameState.reroll_left -= 1
	var pool: Array = []
	if not _options.is_empty():
		var kind := str((_options[0] as Dictionary).get("kind", "scroll"))
		if kind == "scroll":
			_choose(_options[0])
			return
		for _i in 3:
			match kind:
				"protocol":
					pool.append({"kind": "protocol",
						"id": ProtocolDB.random_from(MetaState.unlocked_protocols(), GameState.protocols)})
				"card":
					pool.append({"kind": "card", "id": CardDB.random_id()})
				_:
					pool.append({"kind": "weapon",
						"id": WeaponDB.random_from(MetaState.unlocked_weapons(), GameState.weapons)})
		if not pool.is_empty():
			_options = pool
	_rebuild()


func _choose(opt: Dictionary) -> void:
	if not _open:
		return
	_open = false
	visible = false
	get_tree().paused = false
	var kind := str(opt.get("kind", "scroll"))
	var id := str(opt.get("id", ""))
	match kind:
		"scroll":
			GameState.grant_scroll(id)
			EventBus.scroll_chosen.emit(id)
			EventBus.toast.emit("%s %s" % [Lang.t("picked_prefix"), Lang.t("scroll_" + id)])
		"protocol":
			GameState.add_protocol(id)
			EventBus.toast.emit("%s %s" % [Lang.t("proto_gained"), Lang.t("proto_" + id)])
		"card":
			GameState.add_card(id)
			EventBus.toast.emit("%s %s" % [Lang.t("picked_prefix"), Lang.t("card_" + id)])
		"weapon":
			GameState.equip_weapon(id)
			EventBus.toast.emit("%s: %s" % [Lang.t("weapon_gained"), Lang.t("w_" + id)])
	EventBus.build_changed.emit()


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
			_choose(_options[idx] as Dictionary)
