"""캐릭터 GLB 의 삼각형을 줄입니다(Blender Decimate).

    python tools/decimate.py foe_charger 0.30      비율로
    python tools/decimate.py --all 0.30            전부
    python tools/decimate.py --dry foe_charger     지금 삼각형만 세기

# **먼저 읽으세요: 줄이면 오히려 느려집니다**

재 보니 이렇습니다(적 일곱, 폰 해상도):

    원본 2만 + Godot LOD    삼각형 26천
    줄인 6천 + Godot LOD    삼각형 97천

Godot 은 2만짜리에 **LOD 사슬**을 구워 두어 화면에서 작을 때 하나당 1.5천까지
내려갑니다. 6천으로 줄이면 더 내릴 것이 없다고 보고 LOD 를 안 만들어서, 하나당
6천을 그대로 그립니다(카툰 외곽선까지 두 벌이니 1.2만).

그래서 **이 도구는 기본으로 안 씁니다.** 파일과 메모리를 줄여야 할 때, 그리고
줄인 메시에 LOD 를 직접 구워 넣을 준비가 됐을 때만 쓰세요.

# 왜 LOD 로 안 되나

Godot 이 구워 둔 LOD 는 **그리는 삼각형**을 줄입니다(문턱 8px 에서 167천 ->
26천). 그런데 파일과 메모리는 그대로입니다 - 원본 2만 삼각형에 LOD 단계들이
얹혀 실려 나갑니다. 원본을 줄이면 그 둘이 같이 줍니다.

# 뼈대를 잃지 않게

스킨 메시라 정점마다 뼈 가중치가 붙어 있습니다. Blender 의 Decimate(Collapse)
는 정점 그룹을 이어받으므로 리그가 살아 있습니다 - 다만 **비율을 너무 내리면
관절 근처가 무너집니다**(팔꿈치·무릎이 각지게 접힙니다). 0.25 아래로는 눈으로
보고 정하세요.
"""
import argparse
import subprocess
import sys
from pathlib import Path

BLENDER = Path(r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe")
ROOT = Path(__file__).resolve().parent.parent
CHARS = ROOT / "assets" / "characters"

SCRIPT = r'''
import bpy, sys, json
argv = sys.argv[sys.argv.index("--") + 1:]
src, dst, ratio = argv[0], argv[1], float(argv[2])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
before = after = 0
for ob in list(bpy.data.objects):
    if ob.type != "MESH":
        continue
    before += len(ob.data.polygons)
    if ratio < 1.0:
        bpy.context.view_layer.objects.active = ob
        m = ob.modifiers.new("dec", "DECIMATE")
        m.decimate_type = "COLLAPSE"
        m.ratio = ratio
        m.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=m.name)
    after += len(ob.data.polygons)
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB",
                          export_animations=True, export_skins=True,
                          export_yup=True)
print("DECIMATE_RESULT " + json.dumps({"before": before, "after": after}))
'''


def run(src: Path, dst: Path, ratio: float) -> dict:
    tmp = ROOT / "out" / "_decimate.py"
    tmp.parent.mkdir(exist_ok=True)
    tmp.write_text(SCRIPT, encoding="utf-8")
    p = subprocess.run(
        [str(BLENDER), "-b", "--factory-startup", "-noaudio",
         "--python", str(tmp), "--", str(src), str(dst), str(ratio)],
        capture_output=True, text=True, encoding="utf-8", errors="replace")
    for line in (p.stdout or "").splitlines():
        if line.startswith("DECIMATE_RESULT "):
            import json
            return json.loads(line.split(" ", 1)[1])
    print(p.stdout[-2000:] if p.stdout else "")
    print(p.stderr[-2000:] if p.stderr else "")
    raise SystemExit("[!] Blender 가 결과를 안 냈습니다")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("name", nargs="?", default="")
    ap.add_argument("ratio", nargs="?", type=float, default=0.30)
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--dry", action="store_true")
    args = ap.parse_args()

    names = ([p.stem for p in sorted(CHARS.glob("*.glb"))] if args.all
             else [args.name])
    if not names or names == [""]:
        print("이름을 주거나 --all 을 쓰세요")
        return 1
    for name in names:
        src = CHARS / f"{name}.glb"
        if not src.exists():
            print(f"[!] {src} 없음")
            continue
        ratio = 1.0 if args.dry else args.ratio
        out = src if not args.dry else ROOT / "out" / f"{name}_dry.glb"
        size_before = src.stat().st_size
        r = run(src, out, ratio)
        if args.dry:
            print(f"{name:<16} 삼각형 {r['before']:6d}")
            out.unlink(missing_ok=True)
        else:
            print(f"{name:<16} 삼각형 {r['before']:6d} -> {r['after']:6d}"
                  f"   파일 {size_before/1048576:.1f} -> {out.stat().st_size/1048576:.1f}MB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
