extends Area2D
## LootCard —— 地面掉落卡牌：击杀概率掉落，鼠标左键点击拾取并即时生效。

var card_id := "rapid"
var _picked := false
var _sprite: Sprite2D
var _label: Label
var _t := 0.0


func setup(id: String) -> void:
	card_id = id
	if is_inside_tree():
		_apply_visual()


func _ready() -> void:
	add_to_group("loot_cards")
	collision_layer = 8
	collision_mask = 0
	input_pickable = true

	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 16.0
	shape.shape = circ
	add_child(shape)

	_sprite = Sprite2D.new()
	add_child(_sprite)
	_sprite.z_index = 6

	_label = Label.new()
	_label.position = Vector2(-40, -30)
	_label.custom_minimum_size = Vector2(80, 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 13)
	_label.modulate = Color(1, 1, 0.9, 0.95)
	add_child(_label)
	Lang.language_changed.connect(func(_c): _refresh_text())

	_apply_visual()
	_refresh_text()


func _apply_visual() -> void:
	_sprite.texture = PixelArt.card_tex(26, CardPool.card_color(card_id))


func _refresh_text() -> void:
	if _label != null:
		_label.text = Lang.t("card_" + card_id)


func _process(delta: float) -> void:
	_t += delta
	# 卡牌轻微浮动 + 发光提示可拾取
	var s := 1.0 + 0.07 * sin(_t * 3.2)
	_sprite.scale = Vector2(s, s)
	_sprite.modulate = Color(1.0, 1.0, 1.0, 0.82 + 0.18 * sin(_t * 5.0))


func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _picked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pick()


func pick() -> void:
	if _picked or not GameState.active:
		return
	_picked = true
	var p := get_tree().get_first_node_in_group("player")
	if p != null:
		CardPool.apply(card_id, p)
	EventBus.card_picked.emit(card_id)
	queue_free()
