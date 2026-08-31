"""Blender 로 FBX 를 열어 본 배치와 메시 크기를 봅니다.

    blender -b -P tools/fbx_probe.py -- <fbx> [<fbx> ...]
"""
import sys, bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for path in argv:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=path)
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    name = path.replace("\\", "/").split("/")[-1]
    if not arms:
        print(f"[{name}] 아마추어 없음"); continue
    arm = arms[0]
    bones = arm.data.bones
    verts = sum(len(m.data.vertices) for m in meshes)
    la = bones.get("LeftArm")
    line = f"[{name}] 본 {len(bones)} 정점 {verts}"
    if la:
        h, t = la.head_local, la.tail_local
        d = t - h
        ratio = abs(d.z) / max(abs(d.x), 1e-6)   # 블렌더는 Z 가 위
        line += (f" | LeftArm ({h.x:.3f},{h.y:.3f},{h.z:.3f})"
                 f"->({t.x:.3f},{t.y:.3f},{t.z:.3f}) 수직/수평 {ratio:.1f}"
                 f" -> {'옆으로(A포즈 일치)' if ratio < 1.5 else '아래로(불일치)'}")
    print(line, flush=True)
