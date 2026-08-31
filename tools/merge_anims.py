"""캐릭터별로 흩어진 동작 GLB 를 한 파일로 합칩니다.

Godot 은 파일 하나를 씬 하나로 들여옵니다. 걷기와 대기가 다른 파일이면 같은
캐릭터가 두 개의 씬이 되고, AnimationPlayer 도 둘로 갈립니다. 메시와 리그는
어차피 같으니 걷기 파일을 본체로 삼고 **대기 동작만 얹습니다.**

노드 인덱스가 아니라 **이름으로** 대응시킵니다. 두 파일이 같은 blend 에서
나왔더라도 익스포터가 순서를 보장하지는 않기 때문입니다.
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from glb import read, write

MODELS = Path(r"C:\_project\rogue1\assets\models")
CHARACTERS = ["hero_emberling", "enemy_sprout", "npc_shopkeeper"]


def graft(base_js, base_bin, src_js, src_bin):
    """src 의 모든 애니메이션을 base 로 옮깁니다. (base_bin 은 뒤에 덧붙습니다)"""
    by_name = {n.get("name"): i for i, n in enumerate(base_js["nodes"]) if n.get("name")}
    bin_parts, offset = [base_bin], len(base_bin)
    view_map, acc_map = {}, {}

    def copy_view(vi):
        nonlocal offset
        if vi in view_map:
            return view_map[vi]
        v = dict(src_js["bufferViews"][vi])
        start, length = v.get("byteOffset", 0), v["byteLength"]
        pad = -offset % 4                      # 접근자 정렬은 4바이트 경계입니다
        if pad:
            bin_parts.append(b"\0" * pad); offset += pad
        bin_parts.append(src_bin[start:start + length])
        v["byteOffset"], v["buffer"] = offset, 0
        offset += length
        base_js["bufferViews"].append(v)
        view_map[vi] = len(base_js["bufferViews"]) - 1
        return view_map[vi]

    def copy_acc(ai):
        if ai in acc_map:
            return acc_map[ai]
        a = dict(src_js["accessors"][ai])
        if "bufferView" in a:
            a["bufferView"] = copy_view(a["bufferView"])
        base_js["accessors"].append(a)
        acc_map[ai] = len(base_js["accessors"]) - 1
        return acc_map[ai]

    added = []
    for anim in src_js.get("animations", []):
        samplers = [{**s, "input": copy_acc(s["input"]), "output": copy_acc(s["output"])}
                    for s in anim["samplers"]]
        channels, dropped = [], 0
        for c in anim["channels"]:
            name = src_js["nodes"][c["target"]["node"]].get("name")
            if name not in by_name:            # base 에 없는 본이면 조용히 버립니다
                dropped += 1
                continue
            channels.append({"sampler": c["sampler"],
                             "target": {"node": by_name[name], "path": c["target"]["path"]}})
        base_js.setdefault("animations", []).append(
            {"name": anim.get("name", "Anim"), "samplers": samplers, "channels": channels})
        added.append((anim.get("name"), len(channels), dropped))

    merged = b"".join(bin_parts)
    base_js["buffers"][0]["byteLength"] = len(merged)
    return merged, added


def main() -> None:
    for cid in CHARACTERS:
        walk, idle = MODELS / f"{cid}_walk.glb", MODELS / f"{cid}_idle.glb"
        out = MODELS / f"{cid}.glb"
        if not (walk.exists() and idle.exists()):
            print(f"[skip] {cid}"); continue
        js, bn = read(walk)
        sjs, sbn = read(idle)
        bn, added = graft(js, bn, sjs, sbn)
        size = write(out, js, bn)
        names = [a.get("name") for a in js["animations"]]
        print(f"[ok] {out.name}: {names}  ({size//1024} KB)"
              + "".join(f"  +{n}:{c}ch{f' -{d}' if d else ''}" for n, c, d in added))


if __name__ == "__main__":
    main()
