"""test3 리그(.blend)에 걷기/대기 동작을 얹어 rogue1 이 쓸 GLB 를 만듭니다.

test3 가 만든 것은 '리깅된 정지 메시'입니다. 게임에 넣으려면 클립이 필요하고,
그 클립을 만드는 코드는 이미 test3 안에 있습니다(img2model.animate). 여기서는
그것을 캐릭터 셋에 대해 한 번 돌려 결과만 이 프로젝트로 가져옵니다.
"""
import sys, shutil
from pathlib import Path

TEST3 = Path(r"C:\_project\test3")
sys.path.insert(0, str(TEST3))

from img2model import animate  # noqa: E402

BUILD = TEST3 / "build_roguelike"
DEST = Path(r"C:\_project\rogue1\assets\models")
DEST.mkdir(parents=True, exist_ok=True)

# 이동 속도가 다르면 걸음 폭도 달라야 합니다. 적은 종종걸음, 상인은 거의 안 움직입니다.
CHARACTERS = {
    "hero_emberling": {"walk": {"leg_swing": 28.0}},
    "enemy_sprout":   {"walk": {"leg_swing": 34.0}},
    "npc_shopkeeper": {"walk": {"leg_swing": 16.0}},
}

for cid, opts in CHARACTERS.items():
    blend = BUILD / cid / f"{cid}.blend"
    if not blend.exists():
        print(f"[skip] {cid}: {blend} 없음"); continue
    for name in ("walk", "idle"):
        out = DEST / f"{cid}_{name}.glb"
        if out.exists():
            print(f"[keep] {out.name}"); continue
        motion = animate.MOTIONS[name](**opts.get(name, {}))
        print(f"[make] {out.name} ...", flush=True)
        animate.apply_motion(blend, motion, out)
        print(f"       {out.stat().st_size//1024} KB")

# 정지 메시도 함께 옮깁니다(상점 좌판 등 애니메이션이 필요 없는 배치용).
for cid in CHARACTERS:
    src = BUILD / cid / f"{cid}_rigged.glb"
    if src.exists() and not (DEST / src.name).exists():
        shutil.copy2(src, DEST / src.name)
        print(f"[copy] {src.name}")
print("done ->", DEST)
