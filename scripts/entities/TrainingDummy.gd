extends StaticBody2D
## TrainingDummy —— 教学关训练假人（V1.3 新增）。
##
## 只做三件事：可被子弹命中、给出命中反馈、不移动不还手不死亡。
## 为了复用既有命中链路（Bullet / Beam / Nova / Orbiter / Chain 都只认
## "enemies" 组 + take_damage 接口），这里挂到 enemies 组并实现同签名方法。
## 碰撞：layer=2（玩家子弹 mask=2 命中它），mask=0（不与其它实体互推）。
##
## 可见部分全部挂在 IsoShim 下：碰撞圆仍留在本体的逻辑坐标里。

const RADIUS := 26.0
const MAX_HP := 60
const REGEN_DELAY := 2.2

var hp := MAX_HP

var _view: IsoShim
var _sprite: Sprite2D
var _bar_fill: ColorRect
var _flash := 0.0
var _regen_t := -1.0
var _t := 0.0

const BAR_W := 68.0


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 0

	var shape := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = RADIUS
	shape.shape = circ
	add_child(shape)

	_view = IsoShim.follow_owner(self, 0, 16.0)

	# 靶环：画在**地面**上（y=0），也就是靶子的落地圈 —— 等距下是 2:1 椭圆
	var ring := Line2D.new()
	ring.width = 2.0
	ring.default_color = Color(0.42, 0.90, 0.82, 0.7)
	ring.closed = true
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * float(i) / 28.0
		pts.append(Iso.dir_to_screen(Vector2(cos(a), sin(a))) * (34.0 * Iso.SCALE))
	ring.points = pts
	_view.add_child(ring)

	# 靶柱：正立圆盘，底边压在地面圈上
	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.circle_tex(60,
		Color(0.26, 0.32, 0.36), Color(0.13, 0.17, 0.20), Color(0.45, 0.92, 0.86))
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.position = Vector2(0.0, -30.0)
	_view.add_child(_sprite)

	var lab := Label.new()
	lab.text = Lang.t("tutorial_dummy")
	lab.position = Vector2(-100, -108)
	lab.size = Vector2(200, 0)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 13)
	lab.add_theme_color_override("font_color", Color(0.86, 0.96, 0.92, 0.95))
	lab.z_index = 4
	_view.add_child(lab)

	# HP 条：原来是 _draw() 画的，那是逻辑坐标；改成 Control 才跟得上投影载体
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.06, 0.09, 0.11, 0.92)
	bar_bg.position = Vector2(-BAR_W * 0.5, -72.0)
	bar_bg.size = Vector2(BAR_W, 7.0)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.z_index = 4
	_view.add_child(bar_bg)
	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.42, 0.90, 0.82)
	_bar_fill.position = Vector2(-BAR_W * 0.5 + 1.0, -71.0)
	_bar_fill.size = Vector2(BAR_W - 2.0, 5.0)
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_fill.z_index = 5
	_view.add_child(_bar_fill)


func _process(delta: float) -> void:
	_t += delta
	if _sprite != null:
		var p := 1.0 + 0.03 * sin(_t * 3.0)
		_sprite.scale = Vector2(p, p)
		if _flash > 0.0:
			_flash = maxf(0.0, _flash - delta * 4.0)
			_sprite.modulate = Color(0.92, 0.98, 1.0).lerp(Color(1.0, 1.0, 1.0), _flash)
		else:
			_sprite.modulate = Color(0.92, 0.98, 1.0)
	if _regen_t > 0.0:
		_regen_t -= delta
		if _regen_t <= 0.0:
			hp = MAX_HP
			_refresh_bar()


## 与 Enemy.take_damage 同签名，供所有命中链路直接调用。
func take_damage(amount: int, show_fx: bool = true) -> void:
	hp = maxi(0, hp - maxi(1, amount))
	if show_fx:
		_flash = 1.0
	if hp <= 0:
		# 假人不死亡：打空即回满，方便玩家反复练习
		hp = MAX_HP
	_regen_t = REGEN_DELAY
	_refresh_bar()


func _refresh_bar() -> void:
	if _bar_fill == null:
		return
	var r := clampf(float(hp) / float(MAX_HP), 0.0, 1.0)
	_bar_fill.size = Vector2((BAR_W - 2.0) * r, 5.0)
