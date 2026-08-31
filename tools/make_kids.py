"""등장 인물들의 걷기/대기 클립을 만들어 게임용 GLB 로 합칩니다.

    python tools/make_kids.py
    python tools/make_kids.py --force        이미 있어도 다시

# 왜 이제는 본 애니메이션을 쓰는가

처음 도원 리그는 팔 본이 몸통을 따라 아래로 나 있었습니다(랜드마크 검출이
손목 높이를 어깨 아래로 강제했기 때문). 메시는 A 포즈라 팔이 옆으로 벌어져
있어서, 팔 본을 돌리면 팔이 아니라 셔츠가 딸려와 뭉개졌습니다. 그래서 몸통
전체를 움직이는 절차적 동작으로 우회했습니다.

**새로 리깅된 셋은 팔 본이 실제 팔을 따라갑니다**(실측: 어깨에서 손끝까지
x 가 0.43~0.46, 수직 변화는 거의 없음). 그래서 기존 캐릭터들과 같은 길 -
test3 의 절차적 걷기 사이클을 리그에 얹는 방식 - 로 돌아갑니다.
"""
import argparse
import subprocess
import sys
from pathlib import Path

TEST3 = Path(r"C:\_project\test3")
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(TEST3))
sys.path.insert(0, str(ROOT / "tools"))

from img2model import animate            # noqa: E402
from glb import read, write              # noqa: E402
from merge_anims import graft            # noqa: E402

MODELS = ROOT / "assets" / "models"
SRC = MODELS / "_src"

# 키 1.25m 의 아이들입니다. 다리가 짧아 성인 기준(24도)으로 흔들면 종종거려
# 보이므로 넓게 잡습니다.
#
# 팔 각도는 처음 값의 1.2배입니다. 클립을 3배로 빨리 돌리게 되면서 팔이
# 작게 떨리는 것처럼 보였습니다 - 빨라질수록 진폭도 같이 키워야 걷는 것으로
# 읽힙니다.
KIDS = {
    # 새 주인공. 키가 0.85m 라 아이들(1.25m)보다도 작습니다 - 다리가 더
    # 짧으니 걸음 폭을 더 넓게 잡아야 종종거려 보이지 않습니다.
    "dowon_b": {"blend": "dowon_b.blend",
                "walk": {"leg_swing": 35.0, "arm_swing": 21.0, "knee": 40.0,
                         "bob_amount": 0.018},
                # 달리기는 다리가 갈라지는 한계까지 벌립니다. 여기서 나오는
                # 보폭이 곧 "1배속에서 낼 수 있는 속도" 라, 좁으면 빨리 달릴
                # 때 다리가 떨리는 것으로 보입니다.
                "run": {"leg_swing": 62.0, "arm_swing": 40.0, "knee": 70.0,
                        "bob_amount": 0.040, "cycle_frames": 24},
                # 뒷걸음질. 걷기를 거꾸로 돌려 쓰면 **보폭이 앞걸음 그대로**라
                # 발이 뒤로 성큼 뻗습니다 - 사람은 뒤로 갈 때 발을 멀리
                # 내밀지 않습니다(발밑이 안 보이니까). 보폭만 줄인 사이클을
                # 따로 구워 그것을 거꾸로 돌립니다.
                "back": {"leg_swing": 20.0, "arm_swing": 12.0, "knee": 26.0,
                         "bob_amount": 0.010}},
    "dowon": {"blend": "dowon_v2.blend",
              "walk": {"leg_swing": 32.0, "arm_swing": 19.2, "knee": 38.0,
                       "bob_amount": 0.016}},
    # 보폭을 70도까지 넓혔다가 되돌렸습니다. 배속(스케이팅)만 보고 키웠더니
    # **걷는 것이 아니라 성큼 뛰어넘는 자세**가 됐습니다. 재생 속도가 좀
    # 빨라지더라도 자세가 사람 같은 쪽이 낫습니다 - 배속은 클램프가 받습니다.
    "seojin": {"blend": "seojin.blend",
               "walk": {"leg_swing": 40.0, "arm_swing": 22.0, "knee": 44.0,
                        "bob_amount": 0.016}},
    # 다리가 짧아서 같은 각도라도 발이 덜 움직입니다. 서진보다 조금 넓게
    # 잡되, 걷는 자세를 벗어나지 않는 선까지만입니다.
    "black": {"blend": "black.blend",
              "walk": {"leg_swing": 44.0, "arm_swing": 22.0, "knee": 46.0,
                       "bob_amount": 0.016}},
    # 베개를 든 적. 원본이 0.85m 라 새 주인공과 같은 크기이고, 팔다리
    # 비례도 비슷해서 그쪽 값을 그대로 씁니다. 게임 안에서는 1.44m 로
    # 키워 쓰므로(enemy.gd 의 scale 1.15) 걷는 자세는 같아 보입니다.
    "baby": {"blend": "baby.blend",
             "walk": {"leg_swing": 35.0, "arm_swing": 21.0, "knee": 40.0,
                      "bob_amount": 0.018}},
    # 고함치는 아기. 베개 아기와 같은 사정(작게 나온 원본)이라 같은 값을
    # 씁니다 - 둘 다 test3 가 같은 파이프라인으로 만든 또래입니다.
    "girl": {"blend": "girl.blend",
             "walk": {"leg_swing": 35.0, "arm_swing": 21.0, "knee": 40.0,
                      "bob_amount": 0.018}},
    # 붙잡는 아기. 위 둘과 같은 파이프라인에서 나온 또래라 값도 같습니다.
    "boy": {"blend": "boy.blend",
            "walk": {"leg_swing": 35.0, "arm_swing": 21.0, "knee": 40.0,
                     "bob_amount": 0.018}},
    # 물물교환하는 여자아이(witch). 원본이 0.97m 로 다른 아이들보다 조금
    # 큽니다 - 같은 또래이므로 걷기 값도 같이 씁니다. 서 있기만 하지만
    # 대기 클립이 있어야 숨을 쉬는 것으로 보입니다.
    "witch": {"blend": "witch.blend",
              "walk": {"leg_swing": 35.0, "arm_swing": 21.0, "knee": 40.0,
                       "bob_amount": 0.018}},
    # 선생님만 어른입니다(1.65m). 다리가 길어 아이들처럼 크게 흔들면 성큼거려
    # 우스워집니다 - 교본 기준값에 가깝게 되돌립니다. 대신 팔은 크게 흔들어
    # 다가오는 것이 멀리서도 보이게 합니다.
    "teacher": {"blend": "teacher.blend",
                "walk": {"leg_swing": 24.0, "arm_swing": 24.0, "knee": 32.0,
                         "bob_amount": 0.012}},
}


def named_motion(name: str, **walk_kwargs):
    """걷기 사이클을 다른 이름으로 굽습니다. 보폭만 다른 같은 동작이 여럿
    필요해서(달리기, 뒷걸음질) 이름을 붙이는 곳을 하나로 모았습니다."""
    from img2model.animate import walk_cycle
    m = walk_cycle(**walk_kwargs)
    m.name = name
    return m


def run_motion(**walk_kwargs):
    """달리기. 걷기와 같은 사이클인데 **보폭이 훨씬 큽니다.**

    보폭이 왜 중요한가: 재생 속도를 이동 속도에 맞추면(스케이팅 제거) 클립이
    바닥을 미는 거리가 곧 1배속에서의 이동 속도가 됩니다. 걷기 클립은 그 값이
    0.36 m/s 라, 3.1 m/s 로 달리려면 8.6배로 돌려야 합니다 - 다리가 보이지
    않게 떨립니다. 보폭을 키우면 같은 속도를 더 낮은 배속으로 낼 수 있습니다.

    무릎을 크게 접는 것도 같은 이유입니다. 다리를 곧게 편 채 크게 흔들면
    발이 바닥을 뚫습니다.
    """
    from img2model.animate import walk_cycle
    kwargs = dict(walk_kwargs)
    m = walk_cycle(**kwargs)
    m.name = "Run"
    return m


def push_motion():
    """두 손으로 밀치는 동작. test3 에 없는 동작이라 여기서 만듭니다.

    동작 데이터는 그냥 본별 오일러 각의 시간표라, 걷기와 같은 형식으로 적어
    주면 같은 경로(apply_motion)로 구워집니다.

    부호는 test3 의 `_swing` 에서 확인했습니다 - 팔다리 모두 **로컬 X 양수가
    앞**입니다(step=+1 일 때 LeftUpLeg 가 +leg_swing 이고, 그때 왼다리가 앞).

    한 번 재생하고 끝나는 동작이라 되감기(뒤로 당기기)가 특히 중요합니다.
    곧바로 앞으로만 뻗으면 미는 것이 아니라 가리키는 것처럼 보입니다.
    """
    from img2model.animate import Motion

    def arms(shoulder, elbow, spine, chest):
        return {
            "LeftArm": [shoulder, 0.0, 0.0], "RightArm": [shoulder, 0.0, 0.0],
            "LeftForeArm": [elbow, 0.0, 0.0], "RightForeArm": [elbow, 0.0, 0.0],
            "Spine": [spine, 0.0, 0.0], "Chest": [chest, 0.0, 0.0],
        }

    frames = [
        {"t": 0.00, "pose": arms(0.0, 0.0, 0.0, 0.0)},
        {"t": 0.30, "pose": arms(-40.0, -32.0, -7.0, -5.0)},   # 당기기
        {"t": 0.50, "pose": arms(68.0, -8.0, 12.0, 9.0)},      # 밀기
        {"t": 1.00, "pose": arms(0.0, 0.0, 0.0, 0.0)},         # 복귀
    ]
    return Motion(name="Push", frames=frames, cycle_frames=20,
                  bob=[0.0, -0.014, 0.016, 0.0], fps=24)


def fix_knees(motion) -> None:
    """무릎이 반대로 꺾이는 것을 바로잡습니다.

    test3 의 `_swing` 은 다리가 뒤로 갈 때 무릎을 접는데(발을 끌지 않으려고)
    부호가 **양수**입니다. 이 리그에서 다리 본의 로컬 X 양수는 **앞**이라
    (팔에서 실측으로 확인한 것과 같은 규약), 정강이가 앞으로 돌아갑니다 -
    사람 무릎이 반대로 꺾인 모양이 됩니다. 뒤로 뻗은 다리에서 특히 크게
    보이고, 보폭이 큰 달리기(무릎 70도)에서는 눈에 확 띕니다.

    사람 무릎은 한쪽으로만 접힙니다. 발뒤꿈치가 엉덩이 쪽으로 가는 방향,
    즉 정강이가 **뒤로** 도는 쪽입니다.

    test3 를 고치지 않고 여기서 뒤집는 이유: 그쪽은 다른 프로젝트도 쓰는
    공용 코드입니다. 이 게임이 쓰는 클립만 여기서 바로잡습니다.
    """
    for frame in motion.frames:
        pose = frame["pose"]
        for bone in ("LeftLeg", "RightLeg"):
            a = pose.get(bone)
            if a:
                pose[bone] = [-a[0], a[1], a[2]]


# 리그 실험실에서 고른 동작 크기. 없으면 전부 1.0 입니다.
TUNING = ROOT / "assets" / "anim_tuning.json"

# 본 이름의 조각 -> 어느 손잡이에 묶이는가. riglab.gd 의 BONE_GROUP 과
# **같은 표**여야 합니다 - 갈라지면 미리보기와 구운 결과가 달라집니다.
# 긴 이름부터 봅니다("ForeArm" 이 "Arm" 보다 먼저).
GROUP_ORDER = [
    ("ForeArm", "arms"), ("UpLeg", "legs"), ("Shoulder", "arms"),
    ("Toe", "legs"), ("Hand", "arms"), ("Foot", "legs"),
    ("Leg", "legs"), ("Arm", "arms"),
    ("Hips", "torso"), ("Spine", "torso"), ("Chest", "torso"),
    ("Neck", "torso"), ("Head", "torso"),
]


def load_tuning(name: str) -> dict:
    if not TUNING.exists():
        return {}
    import json
    try:
        data = json.loads(TUNING.read_text(encoding="utf-8"))
    except ValueError:
        print(f"[!] {TUNING.name} 를 읽지 못했습니다. 배율 없이 굽습니다.")
        return {}
    return data.get(name, {})


def scale_motion(motion, tune: dict) -> None:
    """프레임마다의 각도에 배율을 곱합니다.

    리그 실험실(`--ui=riglab`)에서 고른 값입니다. 실험실은 구워진 키를
    쉬는 자세 기준으로 줄이고 늘리는데, 여기서는 굽기 **전의** 각도에
    같은 배율을 곱합니다 - 결과가 같아야 미리보기가 거짓말이 아닙니다.

    `press_arms` 보다 **먼저** 불러야 합니다. 그쪽은 팔을 몸에 붙이는 상수를
    더하는데, 그것까지 같이 줄이면 팔이 도로 벌어집니다.
    """
    if not tune:
        return
    for frame in motion.frames:
        pose = frame["pose"]
        for bone, angles in list(pose.items()):
            group = ""
            for piece, g in GROUP_ORDER:
                if piece in bone:
                    group = g
                    break
            if not group:
                continue
            k = float(tune.get(group, 1.0))
            if k != 1.0:
                pose[bone] = [a * k for a in angles]
    bob_k = float(tune.get("bob", 1.0))
    if bob_k != 1.0 and getattr(motion, "bob", None):
        motion.bob = [v * bob_k for v in motion.bob]


def press_arms(motion, degrees: float, elbow: float) -> None:
    """모든 프레임의 어깨를 몸 쪽으로 접습니다(A 포즈 -> 차렷에 가깝게).

    카탈로그 리그의 기본 자세는 A 포즈입니다 - 리깅에 좋은 자세이지 서 있는
    자세가 아닙니다. 그대로 두면 아이가 팔을 벌린 채 뛰어다닙니다.

    test3 의 동작 데이터는 본의 로컬 오일러 각이고 로컬 Z 가 좌우로 벌리는
    축입니다. 모든 프레임에 상수를 더해, 걷기의 팔 흔들기(로컬 X)는 살린 채
    벌림만 없앱니다. 좌우가 거울이라 부호가 반대입니다.
    """
    offsets = {"LeftArm": +degrees, "RightArm": -degrees,
               "LeftForeArm": +elbow, "RightForeArm": -elbow}
    for frame in motion.frames:
        pose = frame["pose"]
        for bone, dz in offsets.items():
            a = pose.get(bone) or [0.0, 0.0, 0.0]
            pose[bone] = [a[0], a[1], a[2] + dz]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--only", nargs="*", default=[])
    ap.add_argument("--arms", type=float, default=38.0,
                    help="어깨를 몸 쪽으로 접는 각도(도). 55 까지 가면 팔이 "
                         "몸통을 파고듭니다 - 원본 A 포즈가 수평에서 17도밖에 "
                         "안 내려온 자세라, 더하면 거의 수직이 됩니다.")
    ap.add_argument("--elbow", type=float, default=10.0)
    ap.add_argument("--hip", type=float, default=0.33,
                    help="골반 높이(키 대비). tools/raise_hips.py 참고 - "
                         "test3 리깅이 옷자락 때문에 골반을 키의 23%% 로 "
                         "잡아서, 그대로 두면 다리를 흔들 때 배가 출렁입니다.")
    args = ap.parse_args()

    SRC.mkdir(parents=True, exist_ok=True)
    (SRC / ".gdignore").touch()

    for name, cfg in KIDS.items():
        if args.only and name not in args.only:
            continue
        blend = TEST3 / "out" / cfg["blend"]
        if not blend.exists():
            print(f"[!] {name}: {blend} 없음")
            continue

        # 밀기는 주인공만 씁니다. 적은 이 동작을 안 합니다.
        wanted = ("walk", "idle", "push") if name in ("dowon", "dowon_b") else ("walk", "idle")
        for extra_name in ("run", "back"):
            if extra_name in cfg:
                wanted = wanted + (extra_name,)
        for motion_name in wanted:
            out = SRC / f"{name}_{motion_name}.glb"
            if out.exists() and not args.force:
                print(f"[keep] {out.name}")
                continue
            if motion_name == "push":
                motion = push_motion()
            elif motion_name == "run":
                motion = run_motion(**cfg["run"])
            elif motion_name == "back":
                motion = named_motion("Back", **cfg["back"])
            else:
                motion = animate.MOTIONS[motion_name](
                    **(cfg["walk"] if motion_name == "walk" else {}))
            fix_knees(motion)
            scale_motion(motion, load_tuning(name))
            press_arms(motion, args.arms, args.elbow)
            print(f"[make] {out.name} (팔 {args.arms:+.0f}도) ...", flush=True)
            animate.apply_motion(blend, motion, out)

        js, bn = read(SRC / f"{name}_walk.glb")
        for extra in wanted[1:]:
            sjs, sbn = read(SRC / f"{name}_{extra}.glb")
            bn, _ = graft(js, bn, sjs, sbn)
        target = MODELS / f"{name}.glb"
        size = write(target, js, bn)
        # 골반을 올립니다. **여기서 부르지 않으면 다시 구울 때마다 원래의
        # 낮은 골반으로 되돌아갑니다** - 손으로 한 번 고치고 잊으면 다음
        # 사람이 이유도 모르고 다시 밟습니다.
        subprocess.run([sys.executable, str(ROOT / "tools" / "raise_hips.py"),
                        str(target), "--hip", str(args.hip)], check=True)
        print(f"[ok] {target.name}: {[a.get('name') for a in js['animations']]} "
              f"({size // 1024} KB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
