class_name CardPool
## CardPool —— 掉落卡牌词条库：定义卡牌 id / 颜色 / 应用效果。
## 卡牌拾取后立即生效（本局内可叠加），数值全部由这里统一维护。

static var CARDS: Array = [
	{
		"id": "rapid", "color": Color(0.15, 0.9, 0.95),
		"apply": func(p): p.fire_cd = maxf(0.055, p.fire_cd * 0.82)
	},
	{
		"id": "damage", "color": Color(1.0, 0.42, 0.25),
		"apply": func(p): p.damage += 8
	},
	{
		"id": "split", "color": Color(1.0, 0.72, 0.2),
		"apply": func(p): p.projectiles += 1
	},
	{
		"id": "shield", "color": Color(0.35, 0.62, 1.0),
		"apply": func(p): GameState.add_shield(20)
	},
	{
		"id": "speed", "color": Color(0.5, 0.95, 0.35),
		"apply": func(p): p.speed += 35
	},
]


static func card_color(card_id: String) -> Color:
	for c in CARDS:
		if c["id"] == card_id:
			return c["color"]
	return Color(0.8, 0.8, 0.8)


static func random_id() -> String:
	var c: Dictionary = CARDS[randi() % CARDS.size()]
	return c["id"]


static func apply(card_id: String, p: Node) -> void:
	for c in CARDS:
		if c["id"] == card_id:
			var fn: Callable = c["apply"]
			fn.call(p)
			return
