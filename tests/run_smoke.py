import os, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _userdata_guard

PROJ = r"H:/SystemOverload-V1.3"
GODOT = r"H:/Godot/Godot_v4.4.1-stable_win64_console.exe"
PG = os.path.join(PROJ, "project.godot")

# 1) 保护玩家存档（同卷改名，零删除；详见 tests/_userdata_guard.py）
_userdata_guard.activate()

# 2) 注入冒烟 autoload
src = open(PG, encoding="utf-8").read()
if "SmokeTest=" not in src:
    src = src.replace(
        'RunDirector="*res://scripts/run/RunDirector.gd"',
        'RunDirector="*res://scripts/run/RunDirector.gd"\nSmokeTest="*res://tests/smoke.gd"',
    )
    open(PG, "w", encoding="utf-8").write(src)
    print("autoload injected")

try:
    # 3) 运行
    t0 = time.time()
    p = subprocess.run(
        [GODOT, "--headless", "--path", PROJ, "--quit-after", "6000"],
        capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=1800,
    )
    out = (p.stdout or "") + (p.stderr or "")
    open(os.path.join(PROJ, "tests", "smoke_log.txt"), "w", encoding="utf-8").write(out)
    print("RC=", p.returncode, "elapsed=%.1fs" % (time.time() - t0))
    # 只打印冒烟相关行 + 错误
    for line in out.splitlines():
        if ("SMOKE" in line or "SCRIPT ERROR" in line or "Parse Error" in line
                or "ERROR" in line or "error" in line.lower()):
            print(line)
finally:
    # 4) 还原 project.godot
    src = open(PG, encoding="utf-8").read()
    src = src.replace('\nSmokeTest="*res://tests/smoke.gd"', "")
    open(PG, "w", encoding="utf-8").write(src)
    print("autoload removed")
    # 5) 还原玩家存档
    _userdata_guard.restore()
