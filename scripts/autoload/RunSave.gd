extends Node
## RunSave.gd (Autoload) —— V1.3 局内断点存档。
##
## 只在「安全状态」写盘：清空房间、关闭房间前 / 路线图选择节点时。
## 战斗中不写，避免保存到半死状态造成的欺骗性读档。
## 单存档槽位；死亡 / 通关 / 主动放弃时清除。

const FILE_PATH := "user://run_save.json"
const SAVE_VERSION := 2

var _last_write_ms := 0


func has_save() -> bool:
	if not FileAccess.file_exists(FILE_PATH):
		return false
	return not load_payload().is_empty()


func save_checkpoint(route_state: Dictionary, safe_room: String = "") -> bool:
	if not GameState.active:
		return false
	var payload := {
		"version": SAVE_VERSION,
		"ts": Time.get_unix_time_from_system(),
		"safe_room": safe_room,
		"game": GameState.snapshot(),
		"route": route_state,
	}
	var f := FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(payload))
	_last_write_ms = Time.get_ticks_msec()
	EventBus.run_saved.emit()
	return true


func load_payload() -> Dictionary:
	if not FileAccess.file_exists(FILE_PATH):
		return {}
	var f := FileAccess.open(FILE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return {}
	var d: Dictionary = parsed
	if int(d.get("version", 0)) != SAVE_VERSION:
		return {}
	return d


## 摘要信息（主菜单「继续 Run」副标题用）
func summary() -> Dictionary:
	var d := load_payload()
	if d.is_empty():
		return {}
	var g: Dictionary = d.get("game", {})
	return {
		"biome": int(g.get("biome_index", 0)) + 1,
		"depth": int(g.get("room_depth", 0)),
		"hp": int(g.get("core_hp", 0)),
		"max_hp": int(g.get("max_hp", 0)),
		"cells": int(g.get("cells", 0)),
		"kills": int(g.get("kills", 0)),
		"score": int(g.get("score", 0)),
		"ts": int(d.get("ts", 0)),
	}


func clear() -> void:
	if FileAccess.file_exists(FILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE_PATH))
	if FileAccess.file_exists(FILE_PATH):
		var f := FileAccess.open(FILE_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string("")
