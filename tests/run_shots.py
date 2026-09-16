import os, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _userdata_guard

PROJ = r"H:/SystemOverload-V1.3"
GODOT = r"H:/Godot/Godot_v4.4.1-stable_win64_console.exe"
PG = os.path.join(PROJ, "project.godot")
SHOTS = os.path.join(PROJ, "output", "system-overload-ui")

# 1) 保护玩家存档（同卷改名，零删除；详见 tests/_userdata_guard.py）
_userdata_guard.activate()

# 2) 注入截图探针 autoload
src = open(PG, encoding="utf-8").read()
if "ShotProbe=" not in src:
    src = src.replace(
        'RunDirector="*res://scripts/run/RunDirector.gd"',
        'RunDirector="*res://scripts/run/RunDirector.gd"\nShotProbe="*res://tests/_shot.gd"',
    )
    open(PG, "w", encoding="utf-8").write(src)
    print("shot probe injected")

try:
    # 3) 真实窗口运行（窗口必须存在才能抓帧）
    t0 = time.time()
    p = subprocess.run(
        [GODOT, "--path", PROJ, "--resolution", "1280x720", "--quit-after", "4000"],
        capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=900,
    )
    out = (p.stdout or "") + (p.stderr or "")
    open(os.path.join(PROJ, "tests", "shot_log.txt"), "w", encoding="utf-8").write(out)
    print("RC=", p.returncode, "elapsed=%.1fs" % (time.time() - t0))
    for line in out.splitlines():
        if ("SHOT" in line or "SCRIPT ERROR" in line or "Parse Error" in line
                or "ERROR" in line):
            print(line)
finally:
    # 4) 还原 project.godot
    src = open(PG, encoding="utf-8").read()
    src = src.replace('\nShotProbe="*res://tests/_shot.gd"', "")
    open(PG, "w", encoding="utf-8").write(src)
    print("probe removed")
    # 5) 还原玩家存档
    _userdata_guard.restore()

# 6) 列出产出
if os.path.isdir(SHOTS):
    for f in sorted(os.listdir(SHOTS)):
        print("  ", f, os.path.getsize(os.path.join(SHOTS, f)))
else:
    print("NO SHOT DIR:", SHOTS)
