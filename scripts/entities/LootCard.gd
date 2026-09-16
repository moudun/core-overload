extends Area2D
class_name LootCard
## Loot —— V1.2 地面掉落物（统一管线）。
## type: card / weapon / scroll / gold / cell
## 卡牌点击拾取；金币与细胞自动吸取（磁场协议扩大半径）。

const CARD_IDS := ["rapid", "damage", "split", "shield", "speed"]

var loot_type := "card"
var payload: String = ""
var amount := 0
var _picked := false
var _sprite: Sprite2D
var _label: Label
var _t := 0.0


func _ready() -> void:
	add_to_group("loot_cards")
	collision_layer = 8
	collision_mask = 0
	input_pickable = loot_type == "card" or loot_type == "weapon" or loot_type == "scroll"

	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 18.0
	shape.shape = circ
	add_child(shape)

	_sprite = Sprite2D.new()
	_sprite.z_index = 6
	add_child(_sprite)

	_label = Label.new()
	_label.position = Vector2(-46, -32)
	_label.custom_minimum_size = Vector2(92, 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 13)
	_label.modulate = Color(1, 1, 0.9, 0.95)
	add_child(_label)
	Lang.language_changed.connect(func(_c): _refresh_text())

	_apply_visual()
	_refresh_text()


func setup(kind: String, data: String, amount_value: int = 0) -> void:
	loot_type = kind
	payload = data
	amount = amount_value
	if is_inside_tree():
		input_pickable = loot_type == "card" or loot_type == "weapon" or loot_type == "scroll"
		_apply_visual()
		_refresh_text()


func _apply_visual() -> void:
	match loot_type:
		"card":
			_sprite.texture = PixelArt.card_tex(26, _card_color(payload))
		"weapon":
			_sprite.texture = PixelArt.weapon_drop_tex(WeaponDB.info(payload).get("color", Color(0.8, 0.8, 0.8)))
		"scroll":
			_sprite.texture = PixelArt.scroll_tex(_scroll_color(payload))
		"gold":
			_sprite.texture = PixelArt.coin_tex()
		"cell":
			_sprite.texture = PixelArt.cell_tex()
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


func _scroll_color(kind: String) -> Color:
	match kind:
		"firepower":
			return Color(1.0, 0.35, 0.3)
		"cooling":
			return Color(0.3, 0.8, 1.0)
		_:
			return Color(0.5, 1.0, 0.5)


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
		"gold":
			_label.text = "+%d" % amount
		"cell":
			_label.text = "+%d" % amount
		_:
			_label.text = ""


func _process(delta: float) -> void:
	_t += delta
	var s := 1.0 + 0.07 * sin(_t * 3.2)
	_sprite.scale = Vector2(s, s)

	# 自动吸取（金币 / 细胞 / 磁场协议）
	var auto := loot_type == "gold" or loot_type == "cell" or GameState.has_protocol("magnet")
	if not auto:
		return
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var pn: Node2D = p
	var radius := 60.0 + (80.0 if GameState.has_protocol("magnet") else 0.0)
	var d: Vector2 = pn.global_position - global_position
	if d.length() < radius:
		global_position += d.normalized() * minf(520.0 * delta, d.length())
		if d.length() < 18.0:
			pick()


func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _picked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
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
		"scroll":
			EventBus.scroll_choice_opened.emit(["firepower", "cooling", "structure"])
			queue_free()
			return
		"gold":
			GameState.add_gold(amount)
		"cell":
			GameState.add_cells(amount)
	if loot_type != "gold" and loot_type != "cell":
		EventBus.stats_changed.emit()
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
