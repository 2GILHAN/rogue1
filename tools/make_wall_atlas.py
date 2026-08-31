"""벽 그림들을 한 장의 아틀라스로 합칩니다.

    python tools/make_wall_atlas.py

# 왜 아틀라스인가

벽 그림 하나를 그대로 반복하면 복도 내내 같은 액자가 걸립니다. 그렇다고
재질을 여러 개 두면 벽이 재질 수만큼 쪼개져 드로우 콜이 늘어납니다.

가로로 이어 붙인 한 장을 만들어 두고, **벽 칸마다 어느 칸을 볼지 UV 로**
고르면 재질은 하나인 채로 그림만 달라집니다.

# 왜 민무늬가 둘이나 있나

네 칸 중 둘은 아무것도 안 걸린 벽입니다. 액자와 시계가 절반씩 나오면 그것도
결국 벽지처럼 보입니다 - 실제 방도 대부분의 벽은 비어 있고 가끔 뭐가 걸려
있어서, 그 비율이 "가끔 눈에 띄는 것" 을 만듭니다.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools" / "_pylibs"))
sys.path.insert(0, str(ROOT / "tools"))
OUT = ROOT / "assets" / "textures"

CELL_W = 512
CELL_H = 272          # 가로세로 1.88 - 벽 높이 1.6m 에 가로 3m


def build(sources: list) -> None:
    from PIL import Image
    from make_textures import trim_paper, stylize, STYLES

    OUT.mkdir(parents=True, exist_ok=True)
    cells = []
    for path, crop_bottom, box in sources:
        im = Image.open(path).convert("RGB")
        im = trim_paper(im)
        if crop_bottom > 0.0:
            im = im.crop((0, 0, im.width, int(im.height * (1.0 - crop_bottom))))
        if box is not None:
            w, h = im.size
            im = im.crop((int(w * box[0]), int(h * box[1]),
                          int(w * box[2]), int(h * box[3])))
        # 가장자리를 한 번 더 깎습니다. trim_paper 가 종이 테두리를 잘라도
        # 붓이 번진 밝은 줄이 한두 픽셀 남는데, 타일 경계에서 그것이
        # **흰 선**으로 도드라집니다(실제로 그랬습니다).
        w, h = im.size
        inset_x, inset_y = int(w * 0.02), int(h * 0.02)
        im = im.crop((inset_x, inset_y, w - inset_x, h - inset_y))
        # 칸마다 따로 눕힙니다. 합친 뒤에 하면 큰 얼룩 지우기가 칸 경계를
        # 넘나들어, 액자 벽의 어두운 부분이 옆 칸까지 번집니다.
        im = stylize(im, **STYLES["wall"])
        cells.append(im.resize((CELL_W, CELL_H), Image.LANCZOS))

    atlas = Image.new("RGB", (CELL_W * len(cells), CELL_H))
    for i, cell in enumerate(cells):
        atlas.paste(cell, (i * CELL_W, 0))
    target = OUT / "wall_atlas.png"
    atlas.save(target, optimize=True)
    print(f"[ok] {target.name}  {len(cells)}칸  {atlas.size}  "
          f"({target.stat().st_size // 1024} KB)")
    print(f"     dungeon.gd 의 WALL_VARIANTS 를 {len(cells)} 로 맞추세요")


def main() -> int:
    gradio = Path(r"C:\Users\GilhanLee\AppData\Local\Temp\gradio")
    pictures = None
    clock = None
    for p in gradio.glob("*/IMG_*.png"):
        name = p.name
        if name == "IMG_1951.png":
            pictures = p
        elif name == "IMG_1950.png":
            clock = p
    if pictures is None or clock is None:
        print("[!] 벽 원본을 찾지 못했습니다 (IMG_1951 / IMG_1950)")
        return 1

    build([
        # 액자 벽. 아래쪽에 바닥이 같이 그려져 있어 잘라 냅니다.
        (pictures, 0.10, None),
        # 시계 벽.
        (clock, 0.0, None),
        # 민무늬 둘. 시계 벽의 좌우 빈 곳을 잘라 씁니다 - 같은 회벽이라
        # 액자 벽 옆에 놓여도 재질이 튀지 않습니다.
        (clock, 0.0, (0.02, 0.05, 0.40, 0.95)),
        (clock, 0.0, (0.60, 0.05, 0.98, 0.95)),
    ])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
