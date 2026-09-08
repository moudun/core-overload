extends Node
## Lang.gd (Autoload) —— V1.1 双语文案（默认中文，可切换英文，持久化）。
## 用法：Lang.t("key") / Lang.f("key", [args])；语言切换会 emit language_changed。

const FILE_PATH := "user://lang.json"

signal language_changed(lang_code: String)

var lang: String = "zh"

const _ZH := {
	"game_title": "地牢主脑：过载危机",
	"game_title_en": "CORE OVERLOAD",
	"tutorial_t1": "WASD / 方向键：移动核心",
	"tutorial_t2": "鼠标左键：朝光标方向射击",
	"tutorial_t3": "击杀入侵者，鼠标点击拾取地面卡牌强化自己",
	"tutorial_t4": "守住核心血量，清完一波进入下一波",
	"wave_incoming": "第 %d 波 入侵者正在接近！",
	"wave_cleared": "第 %d 波已清除，%d 秒后下一波",
	"game_over_title": "核心过载",
	"game_over_stats": "击杀 %d · 到达第 %d 波 · 得分 %d",
	"restart_hint": "按 R 重新开始",
	"hud_hp": "HP",
	"hud_shield": "护盾",
	"hud_wave": "波次",
	"hud_kills": "击杀",
	"hud_score": "得分",
	"card_rapid": "快速充能",
	"card_damage": "过载弹头",
	"card_split": "分裂核心",
	"card_shield": "临时护盾",
	"card_speed": "磁悬浮轴承",
	"card_rapid_desc": "射速提升（冷却 -18%）",
	"card_damage_desc": "弹头伤害 +8",
	"card_split_desc": "弹道 +1",
	"card_shield_desc": "核心护盾 +20",
	"card_speed_desc": "移动速度 +35",
	"picked_prefix": "拾取",
	"core_dmg": "核心受到 %d 点损伤",
	"lang_switch_hint": "按 L 切换语言",
	"menu_start": "开始游戏",
	"menu_start_sub": "以全新状态进入地牢，守住核心",
	"menu_language": "语言和设置",
	"menu_language_sub": "界面语言 · 音效音量",
	"menu_quit": "退出",
	"menu_quit_sub": "离开游戏",
	"menu_hint": "战斗中按 ESC 可返回本菜单",
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
	"tutorial_t1": "WASD / Arrows: move the core",
	"tutorial_t2": "Mouse Left: shoot toward cursor",
	"tutorial_t3": "Kill invaders, click dropped cards to upgrade",
	"tutorial_t4": "Keep core HP alive, clear a wave to advance",
	"wave_incoming": "Wave %d incoming!",
	"wave_cleared": "Wave %d cleared. Next in %d s",
	"game_over_title": "CORE OVERLOAD",
	"game_over_stats": "Kills %d · Wave %d · Score %d",
	"restart_hint": "Press R to restart",
	"hud_hp": "HP",
	"hud_shield": "SHIELD",
	"hud_wave": "WAVE",
	"hud_kills": "KILLS",
	"hud_score": "SCORE",
	"card_rapid": "Overcharge Coil",
	"card_damage": "Overload Bolt",
	"card_split": "Split Core",
	"card_shield": "Temp Shield",
	"card_speed": "Maglev Bearing",
	"card_rapid_desc": "Fire rate +18%",
	"card_damage_desc": "Bullet damage +8",
	"card_split_desc": "+1 projectile",
	"card_shield_desc": "Core shield +20",
	"card_speed_desc": "Move speed +35",
	"picked_prefix": "Picked up",
	"core_dmg": "Core takes %d damage",
	"lang_switch_hint": "Press L to switch language",
	"menu_start": "START GAME",
	"menu_start_sub": "Begin a fresh run, protect the core",
	"menu_language": "LANGUAGE & SETTINGS",
	"menu_language_sub": "Language · Sound volume",
	"menu_quit": "QUIT",
	"menu_quit_sub": "Exit game",
	"menu_hint": "Press ESC during combat to return here",
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
