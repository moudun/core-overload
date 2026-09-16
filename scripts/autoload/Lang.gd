extends Node
## Lang.gd (Autoload) —— V1.2 双语文案（默认中文，可切换英文，持久化）。
## 用法：Lang.t("key") / Lang.f("key", [args])；语言切换会 emit language_changed。

const FILE_PATH := "user://lang.json"

signal language_changed(lang_code: String)

var lang: String = "zh"

const _ZH := {
	"game_title": "地牢主脑：过载危机",
	"game_title_en": "CORE OVERLOAD",
	"version_tag": "V1.2",
	"tutorial_t1": "WASD 移动 · 鼠标瞄准 · 左键射击",
	"tutorial_t2": "Shift / 空格：翻滚闪避（无敌帧可穿弹）",
	"tutorial_t3": "Q：切换主副武器 · F：治疗瓶 · E：交互",
	"tutorial_t4": "清空房间 → 门变绿 → 走右侧门推进",
	"lang_switch_hint": "按 L 切换语言",
	# HUD
	"hud_hp": "HP",
	"hud_gold": "金币",
	"hud_cells": "细胞",
	"hud_kills": "击杀",
	"hud_score": "得分",
	"hud_room": "房间",
	"hud_biome": "区块",
	"hud_flask": "治疗瓶",
	"hud_fire": "火力",
	"hud_cool": "散热",
	"hud_struct": "结构",
	"hud_weapon": "武器",
	"hud_empty": "空",
	"hud_roll": "翻滚",
	# 区块
	"biome_1": "冷却水道",
	"biome_2": "服务器墓场",
	"biome_3": "主脑核心",
	"room_combat": "战斗房",
	"room_treasure": "宝藏房",
	"room_shop": "商店",
	"room_boss": "BOSS 房",
	"room_clear": "房间已清空 —— 前往右侧出口",
	"room_locked": "警告：房门已锁定",
	# 战斗
	"roll_ready": "翻滚就绪",
	"boss_incoming": "%s 已激活",
	"crit": "暴击",
	# 卷轴
	"scroll_title": "过载卷轴 —— 选择一项强化",
	"scroll_firepower": "火力",
	"scroll_firepower_desc": "全武器伤害 +15%",
	"scroll_cooling": "散热",
	"scroll_cooling_desc": "射速提升 · 冷却 ×0.88",
	"scroll_structure": "结构",
	"scroll_structure_desc": "最大 HP +15 并回复 15",
	# 协议
	"proto_siphon": "汲能协议",
	"proto_siphon_desc": "每次击杀回复 1 HP",
	"proto_phase": "相位协议",
	"proto_phase_desc": "翻滚后 1 秒伤害 +40%",
	"proto_magnet": "磁场协议",
	"proto_magnet_desc": "掉落物吸取范围 +80",
	"proto_overclock": "超频协议",
	"proto_overclock_desc": "暴击率 +15%",
	"proto_armor": "装甲协议",
	"proto_armor_desc": "受到伤害 -15%",
	"proto_capacitor": "电容协议",
	"proto_capacitor_desc": "治疗瓶充能 +1",
	"proto_gained": "已装备协议",
	# 武器
	"w_pulse": "脉冲发生器",
	"w_scatter": "散射矩阵",
	"w_railgun": "轨道穿刺",
	"w_homing": "蜂群导弹",
	"w_orbiter": "哨戒无人机",
	"weapon_gained": "获得武器",
	# 商店 / 宝箱
	"shop_hint": "按 E 购买（靠近货架）",
	"shop_buy_weapon": "随机武器",
	"shop_buy_heal": "应急维修 +40 HP",
	"shop_buy_scroll": "过载卷轴",
	"shop_buy_protocol": "协议模块",
	"shop_bought": "购买成功",
	"shop_poor": "金币不足",
	"chest_hint": "按 E 开启诅咒宝箱（会引来敌人）",
	"chest_opened": "宝箱开启 —— 过载反噬！",
	"chest_reward": "获得卷轴 + 30 金币",
	# 结算
	"game_over_title": "核心过载",
	"game_over_stats": "击杀 %d · 房间 %d · 得分 %d",
	"game_over_cells": "细胞兑换：%d 科技点",
	"victory_title": "主脑已回收",
	"victory_stats": "通关！击杀 %d · 得分 %d",
	"restart_hint": "按 R 重新开始 · ESC 返回主菜单",
	"picked_prefix": "拾取",
	"card_rapid": "快速充能",
	"card_damage": "过载弹头",
	"card_split": "分裂核心",
	"card_shield": "临时护盾",
	"card_speed": "磁悬浮轴承",
	"card_rapid_desc": "射速 +18%",
	"card_damage_desc": "伤害 +8",
	"card_split_desc": "弹道 +1",
	"card_shield_desc": "护盾 +20",
	"card_speed_desc": "移速 +35",
	# 菜单 / 收集者
	"menu_start": "开始游戏",
	"menu_start_sub": "以全新状态进入地牢，杀回主脑",
	"menu_collector": "收集者",
	"menu_collector_sub": "用科技点永久强化（当前：%d）",
	"menu_language": "语言和设置",
	"menu_language_sub": "界面语言 · 音效音量",
	"menu_quit": "退出",
	"menu_quit_sub": "离开游戏",
	"menu_hint": "战斗中按 ESC 可返回本菜单",
	"collector_title": "收集者 —— 局外永久升级",
	"collector_tech": "科技点：%d",
	"collector_buy": "购买",
	"collector_max": "已满级",
	"collector_poor": "科技点不足",
	"meta_armor": "核心装甲",
	"meta_armor_desc": "初始 HP +10 / +20 / +30",
	"meta_phase": "相位引擎",
	"meta_phase_desc": "翻滚冷却 -15% / -30%",
	"meta_funds": "启动资金",
	"meta_funds_desc": "开局金币 +30 / +60",
	"meta_mag": "备用弹匣",
	"meta_mag_desc": "开局副武器槽携带随机武器",
	"meta_serum": "应急血清",
	"meta_serum_desc": "每区块治疗瓶充能 +1",
	"settings_title": "语言和设置",
	"settings_language": "界面语言",
	"settings_volume": "音效音量",
	"lang_zh": "中文",
	"lang_en": "English",
	"back": "返回",
}

const _EN := {
	"game_title": "Dungeon Overlord: Overload Crisis",
	"game_title_en": "CORE OVERLOAD",
	"version_tag": "V1.2",
	"tutorial_t1": "WASD move · Mouse aim · LMB shoot",
	"tutorial_t2": "Shift / Space: dodge roll (i-frames)",
	"tutorial_t3": "Q: swap weapon · F: flask · E: interact",
	"tutorial_t4": "Clear the room -> doors turn green -> exit right",
	"lang_switch_hint": "Press L to switch language",
	"hud_hp": "HP",
	"hud_gold": "GOLD",
	"hud_cells": "CELLS",
	"hud_kills": "KILLS",
	"hud_score": "SCORE",
	"hud_room": "ROOM",
	"hud_biome": "BIOME",
	"hud_flask": "FLASK",
	"hud_fire": "FIRE",
	"hud_cool": "COOL",
	"hud_struct": "STRUCT",
	"hud_weapon": "WPN",
	"hud_empty": "EMPTY",
	"hud_roll": "ROLL",
	"biome_1": "Coolant Channels",
	"biome_2": "Server Graveyard",
	"biome_3": "The Core Mind",
	"room_combat": "COMBAT",
	"room_treasure": "TREASURE",
	"room_shop": "SHOP",
	"room_boss": "BOSS",
	"room_clear": "Room cleared - head to the right exit",
	"room_locked": "WARNING: doors locked",
	"roll_ready": "Roll ready",
	"boss_incoming": "%s engaged",
	"crit": "CRIT",
	"scroll_title": "OVERLOAD SCROLL - choose one",
	"scroll_firepower": "FIREPOWER",
	"scroll_firepower_desc": "All weapon damage +15%",
	"scroll_cooling": "COOLING",
	"scroll_cooling_desc": "Fire rate up - cooldown x0.88",
	"scroll_structure": "STRUCTURE",
	"scroll_structure_desc": "Max HP +15 and heal 15",
	"proto_siphon": "Siphon Protocol",
	"proto_siphon_desc": "Heal 1 HP per kill",
	"proto_phase": "Phase Protocol",
	"proto_phase_desc": "+40% damage 1s after rolling",
	"proto_magnet": "Magnet Protocol",
	"proto_magnet_desc": "Pickup radius +80",
	"proto_overclock": "Overclock Protocol",
	"proto_overclock_desc": "Crit chance +15%",
	"proto_armor": "Armor Protocol",
	"proto_armor_desc": "Damage taken -15%",
	"proto_capacitor": "Capacitor Protocol",
	"proto_capacitor_desc": "Flask charge +1",
	"proto_gained": "Protocol equipped",
	"w_pulse": "PULSE",
	"w_scatter": "SCATTER",
	"w_railgun": "RAILGUN",
	"w_homing": "SWARM",
	"w_orbiter": "SENTRY",
	"weapon_gained": "Weapon acquired",
	"shop_hint": "Press E to buy (stand near a shelf)",
	"shop_buy_weapon": "Random weapon",
	"shop_buy_heal": "Repair +40 HP",
	"shop_buy_scroll": "Overload scroll",
	"shop_buy_protocol": "Protocol module",
	"shop_bought": "Purchased",
	"shop_poor": "Not enough gold",
	"chest_hint": "Press E to open the cursed chest",
	"chest_opened": "Chest opened - OVERLOAD BACKLASH!",
	"chest_reward": "Scroll + 30 gold",
	"game_over_title": "CORE OVERLOAD",
	"game_over_stats": "Kills %d · Rooms %d · Score %d",
	"game_over_cells": "Cells converted: %d tech points",
	"victory_title": "CORE RECLAIMED",
	"victory_stats": "Victory! Kills %d · Score %d",
	"restart_hint": "Press R to restart · ESC for menu",
	"picked_prefix": "Picked up",
	"card_rapid": "Overcharge Coil",
	"card_damage": "Overload Bolt",
	"card_split": "Split Core",
	"card_shield": "Temp Shield",
	"card_speed": "Maglev Bearing",
	"card_rapid_desc": "Fire rate +18%",
	"card_damage_desc": "Damage +8",
	"card_split_desc": "+1 projectile",
	"card_shield_desc": "Shield +20",
	"card_speed_desc": "Move speed +35",
	"menu_start": "START GAME",
	"menu_start_sub": "Begin a fresh run, fight back to the core",
	"menu_collector": "THE COLLECTOR",
	"menu_collector_sub": "Spend tech points (have: %d)",
	"menu_language": "LANGUAGE & SETTINGS",
	"menu_language_sub": "Language · Sound volume",
	"menu_quit": "QUIT",
	"menu_quit_sub": "Exit game",
	"menu_hint": "Press ESC during combat to return here",
	"collector_title": "THE COLLECTOR - permanent upgrades",
	"collector_tech": "Tech points: %d",
	"collector_buy": "BUY",
	"collector_max": "MAXED",
	"collector_poor": "Not enough tech",
	"meta_armor": "Core Armor",
	"meta_armor_desc": "Starting HP +10 / +20 / +30",
	"meta_phase": "Phase Engine",
	"meta_phase_desc": "Roll cooldown -15% / -30%",
	"meta_funds": "Startup Funds",
	"meta_funds_desc": "Starting gold +30 / +60",
	"meta_mag": "Spare Magazine",
	"meta_mag_desc": "Start with a random second weapon",
	"meta_serum": "Emergency Serum",
	"meta_serum_desc": "+1 flask charge per biome",
	"settings_title": "LANGUAGE & SETTINGS",
	"settings_language": "Interface Language",
	"settings_volume": "Sound Volume",
	"lang_zh": "中文",
	"lang_en": "English",
	"back": "Back",
}

var lang_zh := false


func _ready() -> void:
	_load()
	lang_zh = (lang == "zh")


func is_zh() -> bool:
	return lang_zh


func apply(new_lang: String) -> void:
	if new_lang != "zh" and new_lang != "en":
		return
	if new_lang == lang:
		return
	lang = new_lang
	lang_zh = (lang == "zh")
	_save()
	language_changed.emit(lang)


func t(key: String) -> String:
	var d: Dictionary = _ZH if lang_zh else _EN
	return str(d.get(key, _EN.get(key, key)))


func f(key: String, args: Array) -> String:
	var fmt: String = t(key)
	if args.is_empty():
		return fmt
	return fmt % args


func toggle() -> void:
	apply("en" if lang_zh else "zh")


func _load() -> void:
	if not FileAccess.file_exists(FILE_PATH):
		return
	var f := FileAccess.open(FILE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary and parsed.has("lang"):
		lang = "zh" if parsed["lang"] == "zh" else "en"


func _save() -> void:
	var f := FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"lang": lang}))
