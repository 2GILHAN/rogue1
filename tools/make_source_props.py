"""`assets/source/` 의 4면도 그림을 test3 로 3D 소품으로 굽습니다.

    python tools/make_source_props.py            # 없는 것만
    python tools/make_source_props.py --force    # 전부 다시

# 왜 test3 의 이름 추측을 안 쓰는가

test3 의 시트 분할기는 칸을 **왼쪽에서 오른쪽으로** 찾아낸 뒤 각 칸이
정면인지 측면인지를 실루엣 비율과 얼굴 검출로 **추측**합니다. 사람이라면
잘 맞지만 가구에는 얼굴이 없어서, 붕붕카에서는 네 칸을 전부 다른 이름으로
붙였습니다(정면↔우측면이 뒤바뀜, 점수 11/100).

이 그림들은 전부 같은 판형입니다 - 왼쪽부터 **정면·우측면·좌측면·후면**.
그러니 추측을 버리고 **자리로** 정합니다. 분할기가 낸 보고서에 칸이 왼쪽부터
번호로 적히므로, 그 번호를 정답 순서에 그대로 대응시킵니다.

전처리(배경 제거·스케일 정렬)는 test3 것을 그대로 씁니다 - 그쪽이 훨씬
정확하고, 우리가 바꾸는 것은 **이름표뿐**입니다.
"""
import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "source"
OUT = ROOT / "assets" / "props"
TEST3 = Path(r"C:\_project\test3")
PY = TEST3 / ".venv" / "Scripts" / "python.exe"
WORK = ROOT / "out" / "srcprep"

## 왼쪽부터의 정답 순서. 여덟 장이 전부 이 판형입니다.
ORDER = ["front", "right", "left", "back"]

## test3 가 붙이는 한글 이름 → 파일 이름.
KOR = {"정면": "front", "우측면": "right", "좌측면": "left", "후면": "back",
       "미지정": "", "윗면": "front", "아랫면": "back"}

## 무엇을 굽는가.
##
##   file    assets/source 의 파일 이름 조각
##   height  업 축 크기(m). 실제 물건 크기입니다 - 게임 쪽 배율은 prop.gd 가
##           따로 잡으므로, 여기서는 **비례가 맞는 실물 크기**만 냅니다
##   crop    (위, 아래) 비율. 한 장에 줄이 둘이면 쓸 줄만 잘라 냅니다
##   views   자리를 손으로 잡아야 하는 것. (이름, x0, y0, x1, y1) 비율
JOBS = [
    {"name": "wardrobe",  "file": "30d2qd", "height": 1.80},
    {"name": "toyshelf",  "file": "9fn3or", "height": 1.00},
    {"name": "rug",       "file": "cpu2xa", "height": 1.40},
    {"name": "toybox",    "file": "er2b86", "height": 0.30},
    {"name": "ridecar",   "file": "girt7x", "height": 0.42, "crop": (0.0, 0.573)},
    {"name": "kidcloset", "file": "hxbhkt", "height": 1.20},
    # 놀이매트는 판형이 다릅니다 - 옆모습 없이 **윗면과 아랫면** 둘뿐입니다.
    # 자리 순서가 정면·후면입니다. 기본 순서(정면·우측면)로 읽었더니 아랫면을
    # 옆모습으로 넘겨서, 생성기가 두께를 0.84m 로 부풀렸습니다(실제 0.06m).
    {"name": "playmat", "file": "ugkjy1", "height": 1.50,
     "order": ["front", "back"]},
    # 미끄럼틀만 판형이 다릅니다. 정면·후면은 한 줄로 서 있는데 측면은
    # 위아래 두 벌이라(위는 비스듬한 그림, 아래가 진짜 옆모습) 자동 분할이
    # 여섯 칸을 찾아냅니다. 쓸 넷을 자리로 집어 줍니다.
    {"name": "slide", "file": "xgypc4", "height": 1.25, "views": [
        ("front", 0.050, 0.12, 0.260, 0.90),
        ("right", 0.252, 0.50, 0.518, 0.90),
        ("left",  0.502, 0.50, 0.778, 0.90),
        ("back",  0.772, 0.12, 0.965, 0.90),
    ]},
]


def source_of(fragment: str) -> Path:
    hits = sorted(SRC.glob(f"*{fragment}*.png"))
    if not hits:
        raise SystemExit(f"[!] 원본을 못 찾았습니다: {fragment}")
    return hits[0]


def split(job: dict, sheet: Path, work: Path) -> dict:
    """시트를 뷰 PNG 로 나눕니다. 이름은 **자리**로 정합니다."""
    from PIL import Image

    if job.get("views"):
        # 자리를 손으로 잡은 것. 배경 제거는 파이프라인에 맡깁니다.
        im = Image.open(sheet).convert("RGB")
        got = {}
        for name, x0, y0, x1, y1 in job["views"]:
            box = (int(x0 * im.width), int(y0 * im.height),
                   int(x1 * im.width), int(y1 * im.height))
            p = work / f"{name}.png"
            im.crop(box).save(p)
            got[name] = p
        return got

    feed = sheet
    if job.get("crop"):
        top, bottom = job["crop"]
        im = Image.open(sheet)
        feed = work / "row.png"
        im.crop((0, int(top * im.height), im.width, int(bottom * im.height))).save(feed)

    cut = work / "cut"
    run = subprocess.run(
        [str(PY), "-m", "img2model", str(feed), "--prep-only", str(cut)],
        cwd=str(TEST3), capture_output=True, text=True,
        encoding="utf-8", errors="replace")
    folder = next((d for d in cut.rglob("report.txt")), None)
    if folder is None:
        print(run.stdout[-1200:])
        raise SystemExit(f"[!] {job['name']}: 분할 실패")
    folder = folder.parent

    # 보고서의 "  1. 정면" 은 **왼쪽부터** 몇 번째 칸인지입니다. 그 번호를
    # 정답 순서에 대응시키고, 분할기가 붙인 이름은 파일을 찾는 데만 씁니다.
    labels = re.findall(r"^\s+(\d+)\.\s+(\S+)", folder.joinpath("report.txt")
                        .read_text(encoding="utf-8"), re.M)
    got = {}
    for index, korean in labels:
        slot = int(index) - 1
        order = job.get("order", ORDER)
        if slot >= len(order):
            continue
        made = folder / f"{KOR.get(korean, '')}.png"
        if not made.exists():
            continue
        want = work / f"{order[slot]}.png"
        shutil.copy(made, want)
        got[order[slot]] = want
    if "front" not in got:
        raise SystemExit(f"[!] {job['name']}: 정면을 못 찾았습니다 ({labels})")
    return got


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true", help="이미 있어도 다시 굽습니다")
    ap.add_argument("--only", help="이름 하나만")
    args = ap.parse_args()

    OUT.mkdir(parents=True, exist_ok=True)
    for job in JOBS:
        if args.only and job["name"] != args.only:
            continue
        target = OUT / f"{job['name']}.glb"
        if target.exists() and not args.force:
            print(f"[keep] {target.name}")
            continue

        work = WORK / job["name"]
        if work.exists():
            shutil.rmtree(work, ignore_errors=True)
        work.mkdir(parents=True, exist_ok=True)

        sheet = source_of(job["file"])
        print(f"[make] {job['name']} <- {sheet.name}", flush=True)
        views = split(job, sheet, work)
        print("        뷰 " + " ".join(sorted(views)), flush=True)

        cmd = [str(PY), "-m", "img2model"]
        for name in ORDER:
            if name in views:
                cmd += ["--view", f"{name}={views[name]}"]
        cmd += ["-o", str(target), "--preset", "배경 소품",
                "--height", str(job["height"]), "--convention", "unity"]
        run = subprocess.run(cmd, cwd=str(TEST3), capture_output=True,
                             text=True, encoding="utf-8", errors="replace")
        if not target.exists():
            print(run.stdout[-1500:])
            print(f"[!] {job['name']} 생성 실패")
            continue
        for line in run.stdout.splitlines():
            if "완료: " in line or "크기" in line:
                print("       " + line.strip())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
