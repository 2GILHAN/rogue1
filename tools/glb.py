"""GLB(glTF binary) 를 읽고 쓰는 최소 도구. 외부 의존성 없이 표준 라이브러리만 씁니다."""
import json, struct
from pathlib import Path

def read(path):
    d = Path(path).read_bytes()
    magic, ver, total = struct.unpack("<III", d[:12])
    assert magic == 0x46546C67, "GLB 가 아닙니다"
    off, js, bin_ = 12, None, b""
    while off < total:
        ln, kind = struct.unpack("<II", d[off:off+8]); off += 8
        chunk = d[off:off+ln]; off += ln
        if kind == 0x4E4F534A: js = json.loads(chunk)
        elif kind == 0x004E4942: bin_ = chunk
    return js, bin_

def write(path, js, bin_):
    jb = json.dumps(js, separators=(",", ":")).encode("utf-8")
    jb += b" " * (-len(jb) % 4)
    bb = bin_ + b"\0" * (-len(bin_) % 4)
    total = 12 + 8 + len(jb) + (8 + len(bb) if bb else 0)
    out = struct.pack("<III", 0x46546C67, 2, total)
    out += struct.pack("<II", len(jb), 0x4E4F534A) + jb
    if bb: out += struct.pack("<II", len(bb), 0x004E4942) + bb
    Path(path).write_bytes(out)
    return total
