"""dowon 리그에 걷기/대기를 얹어 게임용 GLB 를 만듭니다.

    python tools/make_dowon.py                 기본값으로 생성
    python tools/make_dowon.py --arms 62        팔 내리는 각도만 바꿔 다시

dowon.fbx 에는 애니메이션 클립이 없지만 dowon.blend 에 리그가 그대로 있고
본 이름이 Mixamo 규약이라, 기존 캐릭터와 같은 경로로 동작을 만들 수 있습니다.

# 팔 내리기

카탈로그가 만든 리그의 기본 자세는 **A 포즈**입니다 - 리깅에 좋은 자세이지
서 있는 자세가 아닙니다. 그대로 두면 주인공이 팔을 벌린 채 뛰어다닙니다.

test3 의 동작 데이터는 본의 로컬 오일러 각이고, 로컬 Z 가 좌우로 벌리는
축입니다. 그래서 모든 프레임의 어깨 각도에 상수를 더해 팔을 몸에 붙입니다.
프레임마다 더하는 이유는, 걷기의 팔 흔들기(로컬 X)를 살린 채로 벌림만
없애야 하기 때문입니다.
"""
import argparse
import sys
from pathlib import Path

TEST3 = Path(r"C:\_project\test3")
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(TEST3))
sys.path.insert(0, str(ROOT / "tools"))

from img2model import animate            # noqa: E402
from glb import read, write              # noqa: E402
from merge_anims import graft            # noqa: E402

BLEND = TEST3 / "out" / "dowon.blend"
MODELS = ROOT / "assets" / "models"
SRC = MODELS / "_src"

# 키 1.25m 의 아이입니다. 다리가 짧아 성인 기준(24도)으로 흔들면 종종거려
# 보이므로 넓게, 팔은 반대로 줄여야 허수아비처럼 안 보입니다.
WALK = {"leg_swing": 32.0, "arm_swing": 14.0, "knee": 38.0, "bob_amount": 0.016}


def press_arms(motion, degrees: float, elbow: float = 12.0) -> None:
    """모든 프레임의 어깨를 몸 쪽으로 접습니다(A 포즈 -> 차렷에 가깝게).

    좌우가 거울이라 부호가 반대입니다. 팔꿈치는 살짝만 굽혀 둡니다 - 완전히
    편 팔은 마네킹처럼 보입니다.
    """
    sides = {"LeftArm": +degrees, "RightArm": -degrees}
    elbows = {"LeftForeArm": +elbow, "RightForeArm": -elbow}
    for frame in motion.frames:
        pose = frame["pose"]
        for bone, dz in sides.items():
            angles = pose.get(bone) or [0.0, 0.0, 0.0]
            pose[bone] = [angles[0], angles[1], angles[2] + dz]
        for bone, dz in elbows.items():
            angles = pose.get(bone) or [0.0, 0.0, 0.0]
            pose[bone] = [angles[0], angles[1], angles[2] + dz]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--arms", type=float, default=62.0,
                    help="어깨를 몸 쪽으로 접는 각도(도). 부호는 좌우가 알아서 뒤집습니다")
    ap.add_argument("--elbow", type=float, default=12.0)
    args = ap.parse_args()

    SRC.mkdir(parents=True, exist_ok=True)
    (SRC / ".gdignore").touch()

    for name in ("walk", "idle"):
        out = SRC / f"dowon_{name}.glb"
        motion = animate.MOTIONS[name](**(WALK if name == "walk" else {}))
        press_arms(motion, args.arms, args.elbow)
        print(f"[make] {out.name} (팔 {args.arms:+.0f}도) ...", flush=True)
        animate.apply_motion(BLEND, motion, out)
        print(f"       {out.stat().st_size // 1024} KB")

    js, bn = read(SRC / "dowon_walk.glb")
    sjs, sbn = read(SRC / "dowon_idle.glb")
    bn, _ = graft(js, bn, sjs, sbn)
    target = MODELS / "dowon.glb"
    size = write(target, js, bn)
    print(f"[ok] {target.name}: {[a.get('name') for a in js['animations']]} "
          f"({size // 1024} KB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
