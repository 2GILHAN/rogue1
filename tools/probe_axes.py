"""GLB 의 위/앞 축을 눈이 아니라 숫자로 확인합니다.

카탈로그 에셋을 바꾼 뒤 캐릭터가 눕거나 뒤를 보고 걸으면, 회전값을 바꿔 가며
찍어 보는 대신 여기부터 돌리세요. 메시 경계 상자가 어느 축으로 긴지 보면
위쪽 축이 바로 나옵니다.

    python tools/probe_axes.py

지금 에셋은 z 가 -1.5~0 (머리가 -Z, 발이 0) 이라, scripts/models.gd 에서
X 를 +90도 돌려 세우고 있습니다.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from glb import read  # noqa: E402

MODELS = Path(__file__).resolve().parent.parent / "assets" / "models"

for path in sorted(MODELS.glob("*.glb")):
    js, _ = read(path)
    lo, hi = [1e9] * 3, [-1e9] * 3
    for mesh in js.get("meshes", []):
        for prim in mesh["primitives"]:
            acc = js["accessors"][prim["attributes"]["POSITION"]]
            for k in range(3):
                lo[k] = min(lo[k], acc["min"][k])
                hi[k] = max(hi[k], acc["max"][k])
    extent = [hi[k] - lo[k] for k in range(3)]
    up = "XYZ"[extent.index(max(extent))]
    print(f"{path.name}")
    print(f"  애니메이션: {[a.get('name') for a in js.get('animations', [])]}")
    print(f"  min {[round(v, 3) for v in lo]}  max {[round(v, 3) for v in hi]}")
    print(f"  가장 긴 축 = {up} -> 위쪽 축일 가능성이 높습니다"
          f" (부호는 min/max 로 판단)")
