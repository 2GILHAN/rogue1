"""캐릭터 GLB 안의 텍스처를 게임 색감(지브리 톤)으로 다시 칠합니다.

    python tools/tint_models.py            assets/models/*.glb 전부
    python tools/tint_models.py girl.glb   하나만

# 지금은 아무도 안 부릅니다

한동안 `make_kids.py` 가 굽기 끝에 불렀습니다(`raise_hips.py` 와 같은 자리).
**캐릭터는 원래 색이 낫다고 하셔서 그 고리를 뗐고**, 모델도 역변환(`--undo`)으로
되돌린 뒤 blend 에서 다시 구웠습니다. 지금 `assets/models/*.glb` 는 원본 색입니다.

다시 쓰기로 하면 손으로 부르지 말고 `make_kids.py` 의 굽기 끝에 도로 답니다 -
여기서만 칠하면 다시 구울 때마다 원래 색으로 돌아가고, 그때부터는 어떤 모델이
칠해졌는지 아무도 모릅니다.

# 왜 런타임이 아니라 텍스처인가

`Models.tint` 로 재질에 색을 곱하는 길도 있습니다. 실제로 적 종류를 구분하려고
그렇게 하다가 걷어냈습니다 - 공들여 그린 그림 위에 물감을 붓는 셈이라, 붉은
서진 같은 것이 나옵니다.

텍스처를 직접 칠하면 **그림 자체가 그 색**이 됩니다. 그림자와 밝은 면의 관계가
그대로 유지되고, 재질은 손대지 않으므로 카툰 렌더링이나 피격 번쩍임 같은
다른 층과 싸우지 않습니다.

# 색감

버튼과 **같은 변환**을 씁니다(`tint_buttons.py` 의 `ghibli`). 두 곳에서 따로
값을 고르면 화면 안에서 톤이 갈라집니다.

다만 사람 피부는 버튼보다 덜 건드립니다. 채도를 크게 내리면 얼굴이 잿빛이 되어
아파 보입니다 - 옷과 머리의 원색만 죽이면 충분합니다.

# GLB 를 어떻게 고치는가

이 파이프라인이 만드는 GLB 는 이미지가 **하나**이고 버퍼 안에 들어 있습니다
(`images[0].bufferView`). 그 조각만 새 PNG 로 갈아 끼우고, 길이가 달라진
만큼 **뒤쪽 bufferView 들의 시작 위치를 밀어 줍니다.**

새 이미지를 버퍼 끝에 덧붙이고 가리키는 곳만 바꾸는 쪽이 쉽지만, 그러면 안
쓰는 옛 이미지가 파일에 그대로 남아 모델마다 수백 KB 씩 붑니다.
"""
import argparse
import importlib.util
import io
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from glb import read, write  # noqa: E402

_spec = importlib.util.spec_from_file_location("tint_buttons", ROOT / "tools" / "tint_buttons.py")
_tb = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_tb)

MODELS = ROOT / "assets" / "models"

## 사람에게 쓰는 값. 버튼(0.42)보다 채도를 덜 내립니다 - 얼굴이 잿빛이 되면
## 아파 보입니다. 명도 바닥은 옷 주름의 어두운 곳이 새까맣지 않게 조금 올립니다.
SAT = 0.66
FLOOR = 0.07
CEIL = 0.94
WARM = 0.07


def unghibli(im: Image.Image, sat: float, floor: float, ceil: float,
             warm: float) -> Image.Image:
    """칠한 것을 되돌립니다. `ghibli` 의 역순입니다.

    채도(곱하기)와 명도(선형 사상)는 정확히 되돌아갑니다 - 칠한 뒤의 채도는
    늘 `sat` 이하라 나누어도 1 을 넘지 않고, 명도도 [floor, ceil] 안에
    머뭅니다. 따뜻하게 민 것만 더한 값이라, 그 자리에서 잘렸다면(거의 흰 곳)
    1/255 쯤 어긋납니다.
    """
    import numpy as np
    a = np.asarray(im.convert("RGBA")).astype(np.float32) / 255.0
    rgb, alpha = a[..., :3], a[..., 3:]

    s_now = _tb.rgb_to_hsv(rgb)[..., 1:2]
    rgb = rgb - warm * (1.0 - s_now) * np.array([1.0, 0.45, -0.75], dtype=np.float32)
    rgb = np.clip(rgb, 0.0, 1.0)

    hsv = _tb.rgb_to_hsv(rgb)
    hsv[..., 2] = (hsv[..., 2] - floor) / max(ceil - floor, 1e-6)
    hsv[..., 1] = hsv[..., 1] / max(sat, 1e-6)
    hsv = np.clip(hsv, 0.0, 1.0)
    rgb = _tb.hsv_to_rgb(hsv)

    out = np.concatenate([np.clip(rgb, 0.0, 1.0), alpha], axis=-1)
    return Image.fromarray((out * 255.0 + 0.5).astype(np.uint8))


def tint_glb(path: Path, sat: float, floor: float, ceil: float,
             warm: float, undo: bool = False) -> bool:
    js, bn = read(path)
    images = js.get("images", [])
    if not images:
        print(f"[건너뜀] {path.name}: 텍스처 없음")
        return False

    changed = False
    for img in images:
        bv_index = img.get("bufferView")
        if bv_index is None:
            continue
        bv = js["bufferViews"][bv_index]
        start = int(bv.get("byteOffset", 0))
        length = int(bv["byteLength"])
        raw = bytes(bn[start:start + length])
        im = Image.open(io.BytesIO(raw))
        out = (unghibli if undo else _tb.ghibli)(im, sat, floor, ceil, warm)
        buf = io.BytesIO()
        out.save(buf, format="PNG", optimize=True)
        new = buf.getvalue()
        # 4바이트 정렬. glTF 는 bufferView 시작이 정렬돼 있기를 요구합니다.
        pad = (-len(new)) % 4
        new_padded = new + b"\0" * pad
        old_padded = length + ((-length) % 4)

        bn = bn[:start] + new_padded + bn[start + old_padded:]
        shift = len(new_padded) - old_padded
        bv["byteLength"] = len(new)
        if shift != 0:
            for other in js["bufferViews"]:
                if other is bv:
                    continue
                if int(other.get("byteOffset", 0)) > start:
                    other["byteOffset"] = int(other.get("byteOffset", 0)) + shift
        img["mimeType"] = "image/png"
        changed = True

    if not changed:
        return False
    if js.get("buffers"):
        js["buffers"][0]["byteLength"] = len(bn)
    write(path, js, bn)
    return True


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("names", nargs="*", help="비우면 assets/models/*.glb 전부")
    ap.add_argument("--sat", type=float, default=SAT)
    ap.add_argument("--floor", type=float, default=FLOOR)
    ap.add_argument("--ceil", type=float, default=CEIL)
    ap.add_argument("--warm", type=float, default=WARM)
    ap.add_argument("--undo", action="store_true", help="칠한 것을 되돌립니다")
    args = ap.parse_args()

    targets = ([MODELS / n for n in args.names] if args.names
               else sorted(MODELS.glob("*.glb")))
    for path in targets:
        if not path.exists():
            print(f"[없음] {path}")
            continue
        before = path.stat().st_size
        if tint_glb(path, args.sat, args.floor, args.ceil, args.warm, args.undo):
            print(f"[ok] {path.name}  {before // 1024}KB -> "
                  f"{path.stat().st_size // 1024}KB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
