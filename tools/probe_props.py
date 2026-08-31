import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
from glb import read
for p in sorted((Path(__file__).resolve().parent.parent / "assets" / "props").glob("*.glb")):
    js, _ = read(p)
    lo, hi = [1e9]*3, [-1e9]*3
    for m in js.get("meshes", []):
        for pr in m["primitives"]:
            a = js["accessors"][pr["attributes"]["POSITION"]]
            for k in range(3):
                lo[k] = min(lo[k], a["min"][k]); hi[k] = max(hi[k], a["max"][k])
    ext = [round(hi[k]-lo[k], 3) for k in range(3)]
    print("%-24s 크기 %s  바닥y=%.3f  꼭대기y=%.3f" % (p.stem, ext, lo[1], hi[1]))
