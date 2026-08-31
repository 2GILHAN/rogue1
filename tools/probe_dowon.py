import sys, json
sys.path.insert(0, r"C:\_project\rogue1\tools")
from glb import read

d = r"C:/_project/test3/out"
for name in ("dowon.glb", "dowon_rigged.glb"):
    js, b = read(f"{d}/{name}")
    print("==", name)
    print("  animations:", [a.get("name") for a in js.get("animations", [])])
    print("  skins:", len(js.get("skins", [])), " nodes:", len(js.get("nodes", [])))
    lo, hi = [1e9]*3, [-1e9]*3
    for m in js.get("meshes", []):
        for pr in m["primitives"]:
            a = js["accessors"][pr["attributes"]["POSITION"]]
            for k in range(3):
                lo[k] = min(lo[k], a["min"][k]); hi[k] = max(hi[k], a["max"][k])
    print("  AABB min:", [round(v,3) for v in lo], "max:", [round(v,3) for v in hi])
    print("  extent:", [round(hi[k]-lo[k],3) for k in range(3)])
    names = [n.get("name") for n in js["nodes"]]
    print("  first 20 node names:", names[:20])
