"""보육원 소품 FBX 를 게임용 GLB 로 옮깁니다.

    python tools/make_props.py

test3 의 유니티 브리지가 낸 FBX 를 Blender 로 열어 GLB 로 내보냅니다. 캐릭터와
달리 리그도 애니메이션도 없어서 하는 일이 단순합니다 - 다만 **크기와 충돌체
정보는 asset.json 에 있으므로** 그대로 읽어 게임 쪽에 넘겨 줍니다.

FBX 를 Godot 에 바로 넣지 않는 이유: 나머지 에셋이 전부 GLB 라 임포트 설정이
한 갈래로 유지되고, 축 규약도 여기서 한 번에 흡수됩니다.
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = Path(r"C:\_project\test3\out\DaycareUnity\Assets\Generated")
OUT = ROOT / "assets" / "props"
BLENDER = Path(r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe")

CONVERT = '''
import bpy, sys, json
argv = sys.argv[sys.argv.index("--") + 1:]
fbx, glb = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx)
lo = [1e9] * 3
hi = [-1e9] * 3
for o in bpy.data.objects:
    if o.type != "MESH":
        continue
    for corner in o.bound_box:
        p = o.matrix_world @ __import__("mathutils").Vector(corner)
        for k in range(3):
            lo[k] = min(lo[k], p[k]); hi[k] = max(hi[k], p[k])
bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB",
                          export_yup=True, export_apply=True)
print("SIZE " + json.dumps([round(hi[k] - lo[k], 4) for k in range(3)]))
print("MIN " + json.dumps([round(v, 4) for v in lo]))
'''


def main() -> int:
    if not BLENDER.exists():
        print(f"[!] Blender 없음: {BLENDER}")
        return 1
    OUT.mkdir(parents=True, exist_ok=True)
    script = ROOT / "tools" / "_convert_prop.py"
    script.write_text(CONVERT, encoding="utf-8")

    sizes = {}
    for folder in sorted(p for p in SRC.iterdir() if p.is_dir()):
        name = folder.name
        fbx = folder / f"{name}.fbx"
        if not fbx.exists():
            print(f"[skip] {name}: fbx 없음")
            continue
        glb = OUT / f"{name}.glb"
        if glb.exists():
            print(f"[keep] {glb.name}")
        else:
            print(f"[make] {glb.name} ...", flush=True)
            out = subprocess.run(
                [str(BLENDER), "-b", "-P", str(script), "--", str(fbx), str(glb)],
                capture_output=True, text=True, encoding="utf-8", errors="replace")
            if not glb.exists():
                print(out.stdout[-800:])
                print(f"[!] {name} 변환 실패")
                continue
            for line in out.stdout.splitlines():
                if line.startswith("SIZE "):
                    sizes[name] = json.loads(line[5:])

        meta = folder / f"{name}.asset.json"
        if meta.exists():
            d = json.loads(meta.read_text(encoding="utf-8"))
            col = d.get("collider", {})
            sizes.setdefault(name, col.get("size"))
            print(f"       충돌체 {col.get('kind')} 크기 {col.get('size')}")

    script.unlink(missing_ok=True)
    (OUT / "sizes.json").write_text(json.dumps(sizes, indent=1), encoding="utf-8")
    print("\n크기 요약:")
    for k, v in sorted(sizes.items()):
        print(f"  {k:<22} {v}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
