"""골반(Hips)을 올리고 다리를 그만큼 늘립니다.

    python tools/raise_hips.py assets/characters/hero.glb --hip 0.33

# 왜 필요한가

test3 의 리깅은 골반 높이를 **메시 실루엣에서 다리가 갈라지는 지점**으로
잡습니다. 이 아이들은 옷자락이 길어서 그 지점이 실제 골반보다 한참 아래에
찍힙니다 - 실측으로 키의 23% 였습니다(사람은 45%, 치비라도 35% 쯤).

골반이 낮으면 다리를 흔들 때 **골반과 배까지 같이 돌아갑니다.** 걷는 것이
아니라 몸통 아래쪽이 좌우로 출렁이는 것으로 보입니다.

# 어떻게 고치는가

본의 쉬는 자세(rest)만 옮기고 **inverseBindMatrices 를 새 자세로 다시
계산합니다.** 그러면 가만히 서 있을 때의 메시는 **한 픽셀도 바뀌지 않고**,
움직일 때의 회전 중심만 올라갑니다. 다시 계산하지 않으면 본을 올린 만큼
살가죽이 딸려 올라가 몸이 찌그러집니다.

바꾸는 것은 셋뿐입니다.

- `Hips` 를 위로 옮깁니다.
- `Spine` 을 그만큼 줄입니다(머리 위치가 그대로 있어야 합니다).
- 허벅지와 정강이를 함께 늘립니다(발이 바닥에 그대로 있어야 합니다).

허벅지만 늘리면 무릎이 제자리에 남아 허벅지:정강이가 1.9:1 이 됩니다.
둘을 같은 비율로 늘려야 무릎도 같이 올라갑니다.
"""
import argparse
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np                      # noqa: E402
from glb import read, write             # noqa: E402


def quat_mat(q):
    x, y, z, w = q
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def local_mat(node):
    M = np.eye(4)
    R = np.eye(3)
    if "rotation" in node:
        R = quat_mat(node["rotation"])
    if "scale" in node:
        R = R @ np.diag(node["scale"])
    M[:3, :3] = R
    if "translation" in node:
        M[:3, 3] = node["translation"]
    return M


def world_mats(nodes, parent):
    out = {}

    def walk(i):
        if i in out:
            return out[i]
        M = local_mat(nodes[i])
        p = parent.get(i)
        if p is not None:
            M = walk(p) @ M
        out[i] = M
        return M

    for i in range(len(nodes)):
        walk(i)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("path")
    ap.add_argument("--hip", type=float, default=0.33,
                    help="골반 높이(키 대비 비율). 사람은 0.45, 치비는 0.33~0.38.")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    path = Path(args.path)
    js, bn = read(path)
    nodes = js["nodes"]
    name2i = {n.get("name", ""): i for i, n in enumerate(nodes)}
    parent = {}
    for i, n in enumerate(nodes):
        for c in n.get("children", []):
            parent[c] = i

    need = ["Hips", "Spine", "LeftUpLeg", "LeftLeg", "RightUpLeg", "RightLeg",
            "LeftFoot", "RightFoot", "Head"]
    missing = [b for b in need if b not in name2i]
    if missing:
        print(f"[!] 본이 없습니다: {missing}")
        return 1

    W = world_mats(nodes, parent)
    up = np.array([0.0, 0.0, -1.0])      # 이 리그는 -Z 가 위입니다(실측).

    def h(bone):
        return float(W[name2i[bone]][:3, 3] @ up)

    foot = min(h("LeftFoot"), h("RightFoot"))
    top = h("Head")
    # 키는 머리 본이 아니라 정수리까지입니다. 본만으로는 모르니 머리 위로
    # 목-머리 간격만큼 더 있다고 봅니다(치비는 머리가 커서 이보다 크지만,
    # 비율의 기준을 일정하게만 잡으면 됩니다).
    height = (top - foot) * 1.31
    hip_now = h("Hips") - foot
    want = height * args.hip
    delta = want - hip_now

    print(f"키(추정) {height:.3f}  골반 {hip_now:.3f} ({hip_now / height:.0%})"
          f"  ->  {want:.3f} ({args.hip:.0%})  올릴 값 {delta:+.4f}")
    if args.dry_run:
        return 0
    if delta <= 0.0:
        print("[keep] 이미 충분히 높습니다.")
        return 0

    # 1) 골반을 올리고 척추를 그만큼 줄입니다.
    #    이 본들의 로컬 이동은 뼈 방향(+Y)으로만 나 있습니다.
    def bump(bone, amount):
        t = list(nodes[name2i[bone]].get("translation", [0.0, 0.0, 0.0]))
        t[1] += amount
        nodes[name2i[bone]]["translation"] = t

    bump("Hips", delta)
    bump("Spine", -delta)

    # 2) 다리를 같은 비율로 늘립니다. 발이 바닥에 그대로 있어야 합니다.
    leg_now = hip_now - 0.0
    k = (hip_now + delta) / hip_now
    for side in ("Left", "Right"):
        for seg in (f"{side}Leg", f"{side}Foot"):
            t = list(nodes[name2i[seg]].get("translation", [0.0, 0.0, 0.0]))
            t[1] *= k
            nodes[name2i[seg]]["translation"] = t
    print(f"다리 길이 x{k:.3f}")

    # 3) inverseBindMatrices 를 **새 쉬는 자세로 다시 계산**합니다.
    #    이걸 빼먹으면 살가죽이 본을 따라 올라가 몸이 찌그러집니다.
    W2 = world_mats(nodes, parent)
    for skin in js.get("skins", []):
        acc_i = skin.get("inverseBindMatrices")
        if acc_i is None:
            continue
        acc = js["accessors"][acc_i]
        bv = js["bufferViews"][acc["bufferView"]]
        off = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
        data = bytearray(bn)
        for n, joint in enumerate(skin["joints"]):
            ibm = np.linalg.inv(W2[joint])
            # glTF 는 열 우선(column-major)입니다.
            flat = ibm.T.reshape(-1)
            struct.pack_into("<16f", data, off + n * 64, *flat)
        bn = bytes(data)

    size = write(path, js, bn)
    print(f"[ok] {path.name} ({size // 1024} KB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
