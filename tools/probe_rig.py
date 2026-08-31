import json, sys
from pathlib import Path

OUT = Path(r"C:\_project\test3\out")

for name in ("dowon_v2", "dowon_b"):
    f = OUT / f"{name}_rig.json"
    if not f.exists():
        print(f"== {name}: 없음"); continue
    d = json.loads(f.read_text(encoding="utf-8"))
    bones = {b["name"]: b for b in d["bones"]}
    print(f"== {name}  본 {len(d['bones'])}개  체인 {len(d.get('chains', []))}개")
    la = bones.get("LeftArm"); lh = bones.get("LeftHand")
    sh = bones.get("LeftShoulder")
    if not la:
        print("   팔 본 없음"); continue
    # 팔이 옆으로 뻗었는지(A 포즈) 아래로 늘어졌는지 봅니다.
    import math
    dx = la["tail"][0] - la["head"][0]
    dy = la["tail"][1] - la["head"][1]
    span = abs(lh["tail"][0]) if lh else abs(la["tail"][0])
    # 수평 대비 수직 비율. 0 에 가까우면 옆으로(A 포즈에 맞음), 크면 아래로.
    ratio = abs(dy) / max(abs(dx), 1e-6)
    print(f"   LeftArm head={[round(v,3) for v in la['head']]} tail={[round(v,3) for v in la['tail']]}")
    print(f"   손끝 x={span:.3f}   수직/수평 = {ratio:.1f}  ->",
          "아래로 늘어짐(A 포즈와 불일치)" if ratio > 1.5 else "옆으로 뻗음(A 포즈와 일치)")
