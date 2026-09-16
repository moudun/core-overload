"""测试运行期的用户存档保护（零删除实现）。

冒烟测试与截图探针都会启动真实的 Godot 进程，而游戏会把
meta.json / run_save.json / lang.json / settings.json 写到
%APPDATA%/Godot/app_userdata/Core Overload/。

为了让测试拿到「干净的新档」并且绝不破坏玩家真实存档，这里全部使用
**同卷改名（os.replace）**，不对任何文件做删除：

    进入测试前：  p  ->  p.smokebak      （把真存档挪开）
    测试结束后：  p.smokebak -> p        （挪回来，顺带覆盖测试产生的文件）

只有「测试前本就不存在」的文件，才把它挪成 p.smokerun 留档，同样不删除。

另外带自愈：若上一次运行被强杀，残留的 .smokebak 会在下次启动时先归位。
"""

import os

NAMES = ("meta.json", "run_save.json", "lang.json", "settings.json")
USERDIR = os.path.expandvars(r"%APPDATA%/Godot/app_userdata/Core Overload")

BAK = ".smokebak"
RUN = ".smokerun"


def _p(name):
    return os.path.join(USERDIR, name)


def activate():
    """把玩家存档挪开，让 Godot 从零开始。必须先自愈上一次的残留。"""
    os.makedirs(USERDIR, exist_ok=True)

    # 1) 自愈：上次被强杀留下的 .smokebak 先归位（os.replace 允许覆盖）
    healed = []
    for name in NAMES:
        p, b = _p(name), _p(name + BAK)
        if os.path.exists(b):
            os.replace(b, p)
            healed.append(name)
    if healed:
        print("[userdata] 自愈归位:", ", ".join(healed))

    # 2) 正式挪开真存档
    moved = []
    for name in NAMES:
        p, b = _p(name), _p(name + BAK)
        if os.path.exists(p):
            os.replace(p, b)
            moved.append(name)
    print("[userdata] 已挪开真存档:", ", ".join(moved) if moved else "(无，全新环境)")


def restore():
    """把玩家存档挪回原处；测试新产生的、原本不存在的文件挪成 .smokerun 留档。"""
    back, parked = [], []
    for name in NAMES:
        p, b = _p(name), _p(name + BAK)
        if os.path.exists(b):
            os.replace(b, p)
            back.append(name)
        elif os.path.exists(p):
            os.replace(p, _p(name + RUN))
            parked.append(name)
    print("[userdata] 已还原真存档:", ", ".join(back) if back else "(无)")
    if parked:
        print("[userdata] 测试产物留档:", ", ".join(n + RUN for n in parked))
