extends Area2D
class_name LootCard
## Loot —— V1.3 地面掉落物（统一管线）。
## type: card / weapon / scroll / protocol / gold / cell / energy / source
## 卡牌 / 武器 / 协议需点击拾取；金币、细胞、能量自动吸取（磁场协议扩大半径）。

const CARD_IDS := ["rapid", "damage", "split", "shield", "speed"]

var loot_type := "card"
var payload: String = ""
var amount := 0
var _picked := false
var _view: IsoShim
var _sprite: Sprite2D
var _label: Label
var _t := 0.0
var _mouse_prev := false


func _ready() -> void:
	add_to_group("loot_cards")
	collision_layer = 8
	collision_mask = 0
	# 等距下碰撞体的屏幕位置和贴图位置不一致，鼠标拾取改成屏幕空间手动命中
	input_pickable = false

	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 18.0
	shape.shape = circ
	add_child(shape)

	_view = IsoShim.follow_owner(self, 2, 9.0)

	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.z_index = 6
	_view.add_child(_sprite)

	_label = Label.new()
	_label.position = Vector2(-52, -48)
	_label.custom_minimum_size = Vector2(104, 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 13)
	_label.modulate = Color(1, 1, 0.9, 0.95)
	_view.add_child(_label)
	Lang.language_changed.connect(func(_c): _refresh_text())

	_apply_visual()
	_refresh_text()


func _is_clickable() -> bool:
	return loot_type in ["card", "weapon", "scroll", "protocol"]


func setup(kind: String, data: String, amount_value: int = 0) -> void:
	loot_type = kind
	payload = data
	amount = amount_value
	if is_inside_tree():
		input_pickable = false
		_apply_visual()
		_refresh_text()


func _apply_visual() -> void:
	match loot_type:
		"card":
			_sprite.texture = PixelArt.card_icon_tex(_card_color(payload))
		"weapon":
			_sprite.texture = PixelArt.weapon_drop_tex(WeaponDB.color_of(payload))
		"scroll":
			_sprite.texture = PixelArt.scroll_tex(_scroll_color(payload))
		"protocol":
			_sprite.texture = PixelArt.protocol_tex(_protocol_color(payload))
		"gold":
			_sprite.texture = PixelArt.coin_tex()
		"cell":
			_sprite.texture = PixelArt.cell_tex()
		"energy":
			_sprite.texture = PixelArt.energy_tex()
		"source":
			_sprite.texture = PixelArt.source_tex()
		_:
			_sprite.texture = PixelArt.coin_tex()


func _card_color(id: String) -> Color:
	match id:
		"rapid":
			return Color(0.15, 0.9, 0.95)
		"damage":
			return Color(1.0, 0.42, 0.25)
		"split":
			return Color(1.0, 0.72, 0.2)
		"shield":
			return Color(0.35, 0.62, 1.0)
		_:
			return Color(0.5, 0.95, 0.35)


func _protocol_color(id: String) -> Color:
	var tl: Array = ProtocolDB.tags_of(id)
	if tl.is_empty():
		return Color(0.70, 0.70, 0.70)
	return Tags.color_of(str(tl[0]))


func _scroll_color(kind: String) -> Color:	match kind:
		"firepower":
			return Color(1.0, 0.35, 0.3)
		"cooling":
			return Color(0.3, 0.8, 1.0)
		"structure":
			return Color(0.5, 1.0, 0.5)
		_:
			return Color(1.0, 0.82, 0.32)


func _refresh_text() -> void:
	if _label == null:
		return
	match loot_type:
		"card":
			_label.text = Lang.t("card_" + payload)
		"weapon":
			_label.text = Lang.t("w_" + payload)
		"scroll":
			_label.text = Lang.t("scroll_" + payload)
		"protocol":
			var lv := str(GameState.protocol_level(payload) + 1)
			_label.text = "%s %s" % [Lang.t("proto_" + payload), lv]
		"gold", "cell", "energy", "source":
			_label.text = "+%d" % amount
		_:
			_label.text = ""


func _process(delta: float) -> void:
	_t += delta
	if _sprite != null:
		_sprite.scale = Vector2(1.0 + 0.07 * sin(_t * 3.2), 1.0 + 0.07 * sin(_t * 3.2))

	# 鼠标拾取：把屏幕鼠标反投影回逻辑坐标再比距离
	var down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if _is_clickable() and not _picked and down and not _mouse_prev:
		var m := Iso.to_logical(get_global_mouse_position())
		if m.distance_to(global_position) < 28.0:
			_mouse_prev = down
			pick()
			return
	_mouse_prev = down
	if _picked:
		return

	var auto := loot_type in ["gold", "cell", "energy", "source"] or GameState.has_protocol("magnet")
	if not auto:
		return
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var pn: Node2D = p
	var radius := 60.0 + GameState.protocol_value("magnet")
	var d: Vector2 = pn.global_position - global_position
	if d.length() < radius:
		global_position += d.normalized() * minf(560.0 * delta, d.length())
		if d.length() < 20.0:
			pick()


func pick() -> void:
	if _picked or not GameState.active:
		return
	_picked = true
	match loot_type:
		"card":
			_apply_card(payload)
		"weapon":
			GameState.equip_weapon(payload)
			EventBus.toast.emit("%s: %s" % [Lang.t("weapon_gained"), Lang.t("w_" + payload)])
			EventBus.weapon_changed.emit(GameState.weapon_index, payload)
		"protocol":
			GameState.add_protocol(payload)
		"scroll":
			EventBus.scroll_choice_opened.emit(["firepower", "cooling", "structure"])
			queue_free()
			return
		"gold":
			GameState.add_gold(amount)
		"cell":
			GameState.add_cells(amount)
		"energy":
			GameState.add_energy(amount)
		"source":
			MetaState.add_source(amount)
			EventBus.toast.emit(Lang.f("hack_reward", [amount]))
	if loot_type not in ["gold", "cell", "energy", "source"]:
		EventBus.stats_changed.emit()
		EventBus.build_changed.emit()
	queue_free()


func _apply_card(id: String) -> void:
	var p := get_tree().get_first_node_in_group("player")
	match id:
		"rapid":
			GameState.cooling += 1
		"damage":
			GameState.firepower += 1
		"split":
			GameState.bonus_proj += 1
		"shield":
			GameState.heal(20)
		"speed":
			if p != null:
				p.speed += 35
	EventBus.toast.emit("%s %s" % [Lang.t("picked_prefix"), Lang.t("card_" + id)])
	EventBus.stats_changed.emit()
