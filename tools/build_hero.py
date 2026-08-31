"""새 주인공 원화 한 장 -> 게임에 바로 들어가는 GLB.

    python tools/build_hero.py                 전부 실행
    python tools/build_hero.py --dry-run       무엇을 할지만 보기
    python tools/build_hero.py --skip-catalog  이미 뽑은 메시로 애니메이션만

세 단계를 이어 붙인 것뿐이고, 실제 일은 전부 test3 가 합니다.

  1. 카탈로그  hero.yaml 대로 3면도를 나눠 3D 로 만들고 리깅합니다 (느립니다)
  2. 동작      리그 위에 걷기/대기 사이클을 얹습니다 (Blender 필요)
  3. 합치기    걷기 파일에 대기 클립을 옮겨 붙여 한 파일로 만듭니다

마지막에 assets/models/hero_boy.glb 가 생기고, scripts/models.gd 의
HERO 상수를 그리로 바꾸면 주인공이 교체됩니다.
"""
import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEST3 = Path(r"C:\_project\test3")
PYTHON = TEST3 / ".venv" / "Scripts" / "python.exe"

ASSET_ID = "hero_boy"
SOURCE = ROOT / "assets" / "source" / "hero_sheet.png"
BUILD = ROOT / "build_hero" / ASSET_ID
MODELS = ROOT / "assets" / "models"

# 걸음 폭. 아이 캐릭터라 다리가 짧아 성인 기준(24도)보다 넓게 흔들어야
# 종종거리지 않고 걷는 것처럼 보입니다.
WALK = {"leg_swing": 30.0}


def run(cmd, cwd=None, dry=False):
    print("$", " ".join(str(c) for c in cmd))
    if dry:
        return 0
    return subprocess.call([str(c) for c in cmd], cwd=str(cwd) if cwd else None)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--skip-catalog", action="store_true")
    ap.add_argument("--force", action="store_true",
                    help="지문이 같아도 다시 만듭니다")
    args = ap.parse_args()

    if not PYTHON.exists():
        print(f"[!] test3 가상환경이 없습니다: {PYTHON}")
        return 1
    if not SOURCE.exists():
        print(f"[!] 원화가 없습니다: {SOURCE}")
        print("    3면도 이미지를 그 경로에 저장한 뒤 다시 실행하세요.")
        return 1

    # 1. 카탈로그. 카탈로그는 자기 위치를 기준으로 경로를 풉니다.
    if not args.skip_catalog:
        cmd = [PYTHON, "-u", "-m", "img2model.catalog", str(ROOT / "hero.yaml")]
        if args.force:
            cmd.append("--force")
        if args.dry_run:
            cmd.append("--dry-run")
        # test3 를 import 경로로 쓰되, 작업 디렉터리는 test3 여야 vendor 를 찾습니다.
        if run(cmd, cwd=TEST3) != 0:
            print("[!] 카탈로그 빌드가 실패했습니다.")
            return 1
    if args.dry_run:
        print("[dry-run] 여기까지.")
        return 0

    blend = BUILD / f"{ASSET_ID}.blend"
    if not blend.exists():
        print(f"[!] 리깅된 blend 가 없습니다: {blend}")
        return 1

    # 2. 동작.
    sys.path.insert(0, str(TEST3))
    from img2model import animate  # noqa: E402

    MODELS.mkdir(parents=True, exist_ok=True)
    src_dir = MODELS / "_src"
    src_dir.mkdir(exist_ok=True)
    (src_dir / ".gdignore").touch()

    for name in ("walk", "idle"):
        out = src_dir / f"{ASSET_ID}_{name}.glb"
        if out.exists() and not args.force:
            print(f"[keep] {out.name}")
            continue
        motion = animate.MOTIONS[name](**(WALK if name == "walk" else {}))
        print(f"[make] {out.name} ...", flush=True)
        animate.apply_motion(blend, motion, out)

    # 3. 합치기. merge_anims 와 같은 방식이지만 이 캐릭터 하나만 다룹니다.
    sys.path.insert(0, str(ROOT / "tools"))
    from merge_anims import graft  # noqa: E402
    from glb import read, write  # noqa: E402

    js, bn = read(src_dir / f"{ASSET_ID}_walk.glb")
    sjs, sbn = read(src_dir / f"{ASSET_ID}_idle.glb")
    bn, added = graft(js, bn, sjs, sbn)
    target = MODELS / f"{ASSET_ID}.glb"
    size = write(target, js, bn)
    print(f"[ok] {target.name}: {[a.get('name') for a in js['animations']]} "
          f"({size // 1024} KB)")

    # 카탈로그가 잰 콜라이더 값을 남겨 둡니다. models.gd 의 SIZE 에 넣습니다.
    asset_json = BUILD / "asset.json"
    if asset_json.exists():
        import json
        data = json.loads(asset_json.read_text(encoding="utf-8"))
        col = data.get("metrics", {}).get("collider", {})
        if col:
            print(f"[치수] height={col.get('height')} radius={col.get('radius')}"
                  "   <- scripts/models.gd 의 SIZE 에 반영하세요")
    shutil.copy2(BUILD / f"{ASSET_ID}_preview.png", ROOT / "out" / f"{ASSET_ID}_preview.png") \
        if (BUILD / f"{ASSET_ID}_preview.png").exists() else None
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
