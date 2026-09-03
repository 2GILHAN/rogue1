"""**굽기 전에 메시를 고친 사본을 만듭니다.**

# 왜 필요한가

`seojin.blend` 를 다시 조각해 왔더니 구운 GLB 에 **뼈대도 클립도 없었습니다**
(노드 1개 · skins 0 · animations 0). 오류는 안 났습니다 - 블렌더의 glTF
내보내기가 조용히 이렇게 적고 넘어갑니다.

    WARNING: Mesh input is not valid, and may be exported wrongly
    Finished glTF 2.0 export in 0.116 s

0.116초는 2만 삼각형짜리 스킨 메시를 내보낸 시간이 아닙니다. **메시가
유효하지 않으면 뼈대를 빼고 내보냅니다.**

    seojin.blend      mesh.validate() -> True   (고칠 것이 있었음)
    dowon_new.blend   mesh.validate() -> False  (깨끗함)

그리고 **그것만이 아니었습니다.** 메시를 고친 뒤에도 뼈대가 안 나왔습니다.

    seojin.blend      아마추어 hide_get() -> True    (숨겨져 있음)
    dowon_new.blend   아마추어 hide_get() -> False

워커는 씬의 오브젝트를 전부 골라 `use_selection=True` 로 내보내는데,
**숨겨진 오브젝트는 골라지지 않습니다.** 조각하면서 리그를 숨겨 두는 것은
자연스러운 일인데, 그것이 그대로 굽기까지 따라옵니다.

# 왜 여기서 고치나

`img2model` 은 **다른 프로젝트도 쓰는 공용 코드**라 건드리지 않습니다
(CLAUDE.md). 원본 blend 도 안 고칩니다 - 그건 조각하는 사람의 파일이고,
도구가 남의 원본을 말없이 바꾸면 무엇이 원본인지 알 수 없게 됩니다.

**고친 사본을 따로 만들어** 그것으로 굽습니다. 원본은 그대로 남습니다.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"

SCRIPT = '''
import bpy, sys
a = sys.argv[sys.argv.index("--") + 1:]
src, dst = a[0], a[1]
bpy.ops.wm.open_mainfile(filepath=src)

# **숨겨진 것을 전부 꺼냅니다.**
#
# 워커는 씬의 오브젝트를 전부 골라(select_set) `use_selection=True` 로
# 내보냅니다. 그런데 **숨겨진 오브젝트는 골라지지 않습니다** - 조각하면서
# 리그를 숨겨 두면 그 blend 는 메시만 나갑니다.
shown = []
for o in bpy.data.objects:
    o.hide_viewport = False
    o.hide_select = False
    try:
        if o.hide_get():
            o.hide_set(False)
            shown.append(o.name)
    except RuntimeError:
        pass
print("CLEAN_SHOWN %s" % ",".join(shown))

fixed = 0
for o in bpy.data.objects:
    if o.type != "MESH":
        continue
    # clean_customdata 는 끕니다. UV 와 버텍스 그룹까지 지워 버리면 고친 것이
    # 아니라 다른 모델이 됩니다.
    if o.data.validate(verbose=False, clean_customdata=False):
        fixed += 1
print("CLEAN_RESULT %d" % fixed)
bpy.ops.wm.save_as_mainfile(filepath=dst, copy=True)
'''


def clean(src: Path, dst: Path) -> int:
    """고친 사본을 만들고, 고칠 것이 있던 메시 수를 돌려줍니다."""
    tmp = ROOT / "out" / "_clean_blend.py"
    tmp.parent.mkdir(exist_ok=True)
    tmp.write_text(SCRIPT, encoding="utf-8")
    dst.parent.mkdir(parents=True, exist_ok=True)
    p = subprocess.run(
        [BLENDER, "-b", "--factory-startup", "-noaudio",
         "--python", str(tmp), "--", str(src), str(dst)],
        capture_output=True, text=True, encoding="utf-8", errors="replace")
    for line in (p.stdout or "").splitlines():
        if line.startswith("CLEAN_SHOWN ") and line[12:].strip():
            print("    [숨겨져 있던 것을 꺼냈습니다] %s" % line[12:].strip())
        if line.startswith("CLEAN_RESULT "):
            return int(line.split(" ", 1)[1])
    print(p.stdout[-1500:] if p.stdout else "")
    print(p.stderr[-800:] if p.stderr else "")
    raise RuntimeError("메시를 고치지 못했습니다: %s" % src)


if __name__ == "__main__":
    n = clean(Path(sys.argv[1]), Path(sys.argv[2]))
    print("고칠 것이 있던 메시 %d개" % n)
