"""버튼 그림을 이 게임의 색감(지브리 톤)으로 다시 칠합니다.

    python tools/tint_buttons.py
    python tools/tint_buttons.py --sat 0.60 --warm 0.06   값을 바꿔 보며

# 왜 도구인가

원본(test3)은 그대로 두고 여기서 칠합니다. 색감이 마음에 안 들면 숫자만 고쳐
다시 돌리면 되고, 원본을 덮어썼다면 되돌릴 수 없습니다. 나중에 그림이 다시
오더라도 같은 값으로 한 번 더 돌리면 톤이 맞습니다.

# 무엇을 하는가

원본은 원색에 가깝습니다(순수한 빨강·노랑·파랑, 검은 외곽선). 이 게임의 화면은
따뜻한 나무 바닥과 크림색 벽이라, 그 위에 놓으면 버튼만 다른 그림에서 오려
붙인 것처럼 보입니다.

지브리 색감의 성질 셋을 그대로 적용합니다.

1. **채도를 낮춥니다.** 원색이 없습니다 - 빨강은 주홍에, 파랑은 청록에
   가깝습니다.
2. **검은색이 없습니다.** 가장 어두운 곳도 짙은 갈색이나 남색입니다. 그래서
   명도 아래쪽을 들어 올립니다(0 -> 0.16).
3. **전체가 따뜻합니다.** 빨강을 조금 올리고 파랑을 조금 내립니다. 다만
   파란 버튼까지 갈색으로 만들면 세 버튼을 구분하는 색이 사라지므로,
   따뜻하게 미는 양은 채도가 낮은 곳(회색에 가까운 곳)에서 더 큽니다.

외곽선의 계단 모양은 건드리지 않습니다 - 흐리게 하거나 크기를 바꾸지 않고
**색만** 바꿉니다. 도트 그림이 도트로 남아야 합니다.
"""
import argparse
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = Path(r"C:\_project\test3\out\buttons")
OUT = ROOT / "assets" / "textures" / "buttons"
NAMES = ["button_red.png", "button_yellow.png", "button_blue.png"]


def rgb_to_hsv(rgb: np.ndarray) -> np.ndarray:
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = rgb.max(axis=-1)
    mn = rgb.min(axis=-1)
    d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    idx = m & (mx == r)
    h[idx] = ((g - b)[idx] / d[idx]) % 6.0
    idx = m & (mx == g)
    h[idx] = ((b - r)[idx] / d[idx]) + 2.0
    idx = m & (mx == b)
    h[idx] = ((r - g)[idx] / d[idx]) + 4.0
    h = h / 6.0
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0.0)
    return np.stack([h, s, mx], axis=-1)


def hsv_to_rgb(hsv: np.ndarray) -> np.ndarray:
    h, s, v = hsv[..., 0] * 6.0, hsv[..., 1], hsv[..., 2]
    i = np.floor(h).astype(int) % 6
    f = h - np.floor(h)
    p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    out = np.zeros(hsv.shape, dtype=np.float32)
    for k, (rr, gg, bb) in enumerate([(v, t, p), (q, v, p), (p, v, t),
                                      (p, q, v), (t, p, v), (v, p, q)]):
        m = i == k
        out[m] = np.stack([rr, gg, bb], axis=-1)[m]
    return out


def ghibli(im: Image.Image, sat: float, floor: float, ceil: float,
           warm: float) -> Image.Image:
    a = np.asarray(im.convert("RGBA")).astype(np.float32) / 255.0
    rgb, alpha = a[..., :3], a[..., 3:]

    hsv = rgb_to_hsv(rgb)
    # 1) 채도를 낮춥니다.
    hsv[..., 1] *= sat
    # 2) 명도를 [floor, ceil] 로 눌러 넣습니다. 순수한 검정과 순수한 흰색이
    #    사라지고, 가장 어두운 곳이 짙은 색으로 남습니다.
    hsv[..., 2] = floor + hsv[..., 2] * (ceil - floor)
    rgb = hsv_to_rgb(hsv)

    # 3) 따뜻하게. 채도가 낮은 곳(외곽선·그림자·흰 여백)에서 더 세게 밀어야
    #    파란 버튼이 갈색이 되지 않습니다.
    lean = warm * (1.0 - hsv[..., 1:2])
    rgb = rgb + lean * np.array([1.0, 0.45, -0.75], dtype=np.float32)
    rgb = np.clip(rgb, 0.0, 1.0)

    out = np.concatenate([rgb, alpha], axis=-1)
    return Image.fromarray((out * 255.0 + 0.5).astype(np.uint8), "RGBA")


def main() -> int:
    ap = argparse.ArgumentParser()
    # 값은 나무 바닥 위에 나란히 깔아 놓고 골랐습니다.
    #
    #   채도 0.62 / 바닥 0.16 -> 너무 바랬습니다. 지브리 색감은 흐린 것이
    #                            아니라 **원색이 아닌** 것입니다.
    #   채도 0.74 / 바닥 0.11 -> 탁해지되 셋이 또렷하게 구분됩니다.
    #   채도 0.80 / 바닥 0.08 -> 거의 원본. 바닥 위에서 여전히 튑니다.
    #   채도 0.42 / 바닥 0.13 -> 고른 값. 셋이 서로 가까워지고 바닥에 묻힙니다.
    #
    # 0.5 아래로 내리면 세 버튼의 색이 서로 가까워집니다. 그래도 구분은
    # 됩니다 - **그림이 다르기 때문**입니다(소리 지르는 아이·미는 아이·구르는
    # 아이). 색으로만 구분하던 예전 원 버튼이었다면 못 내렸을 값입니다.
    #
    # 명도 바닥을 0.2 위로 올리면 외곽선이 사라져 도트 그림이 뭉갭니다.
    ap.add_argument("--sat", type=float, default=0.42)
    ap.add_argument("--floor", type=float, default=0.13)
    ap.add_argument("--ceil", type=float, default=0.90)
    ap.add_argument("--warm", type=float, default=0.07)
    args = ap.parse_args()

    OUT.mkdir(parents=True, exist_ok=True)
    for name in NAMES:
        src = SRC / name
        if not src.exists():
            print(f"[없음] {src}")
            continue
        im = Image.open(src)
        ghibli(im, args.sat, args.floor, args.ceil, args.warm).save(OUT / name)
        print(f"[ok] {name}  {im.size[0]}x{im.size[1]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
