extends Node
## Settings.gd (Autoload)
## 用户设置：音效音量、CRT 滤镜开关。持久化到 user://settings.json。
## 音量以 -6dB..-40dB 区间存储，UI 层使用 0..100 整数百分比。

const FILE_PATH := "user://settings.json"

var sfx_volume_percent: int = 80
var crt_enabled: bool = true

const VOL_DB_MIN := -40.0
const VOL_DB_MAX := -6.0


func _ready() -> void:
	_load()


func volume_db() -> float:
	var t01 := clampf(float(sfx_volume_percent) / 100.0, 0.0, 1.0)
	return lerpf(VOL_DB_MIN, VOL_DB_MAX, t01)


func set_volume_percent(v: int) -> void:
	sfx_volume_percent = clampi(v, 0, 100)
	_save()


func set_crt_enabled(v: bool) -> void:
	crt_enabled = v
	_save()


func _load() -> void:
	if not FileAccess.file_exists(FILE_PATH):
		return
	var f := FileAccess.open(FILE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		if parsed.has("sfx_volume_percent"):
			sfx_volume_percent = clampi(int(parsed["sfx_volume_percent"]), 0, 100)
		if parsed.has("crt_enabled"):
			crt_enabled = bool(parsed["crt_enabled"])


func _save() -> void:
	var f := FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"sfx_volume_percent": sfx_volume_percent,
		"crt_enabled": crt_enabled
	}))
