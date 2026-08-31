"""올린 그림을 게임용 타일 텍스처로 다듬습니다.

    python tools/make_textures.py                     새 업로드를 찾아 목록만 보여줍니다
    python tools/make_textures.py <원본> <이름> [잘라낼비율] [floor|wall]

# 하는 일

  1. **종이 여백 자르기.** 수채화로 그린 그림이라 가장자리에 종이색 테두리가
     남아 있습니다. 그대로 타일링하면 격자 무늬가 생깁니다.
  2. **크기 줄이기.** 폰으로 내려받는 용량이라 가로 1024 로 맞춥니다.

# 이음매는 어떻게 하나

여기서 안 합니다. 게임 쪽에서 **UV 를 한 칸 걸러 뒤집어**(미러 타일링) 붙이기
때문에 가장자리가 언제나 맞습니다(dungeon.gd 참고). 그림을 억지로 이어 붙이는
가공보다 결과가 깨끗하고, 원본의 붓질도 그대로 남습니다.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools" / "_pylibs"))
OUT = ROOT / "assets" / "textures"
GRADIO = Path(r"C:\Users\GilhanLee\AppData\Local\Temp\gradio")

TARGET_WIDTH = 1024


def find_uploads(limit: int = 8) -> list:
    """test3 의 그림 올리기가 남긴 임시 파일들을 최신순으로."""
    items = []
    if GRADIO.exists():
        for p in GRADIO.glob("*/*"):
            if p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"):
                items.append((p.stat().st_mtime, p))
    items.sort(reverse=True)
    return items[:limit]


def trim_paper(im, tolerance: int = 14):
    """종이색 테두리를 잘라 냅니다.

    네 귀퉁이 색을 종이색으로 보고, 그 색에서 충분히 벗어나는 첫 줄까지
    안쪽으로 파고듭니다. 여백 두께를 손으로 적지 않아도 되고, 그림마다
    여백이 달라도 알아서 맞습니다.
    """
    from PIL import Image
    import numpy as np

    a = np.asarray(im.convert("RGB"), dtype=np.int16)
    h, w = a.shape[:2]
    corners = np.stack([a[0, 0], a[0, w - 1], a[h - 1, 0], a[h - 1, w - 1]])
    paper = corners.mean(axis=0)
    far = np.abs(a - paper).max(axis=2) > tolerance

    def first_true(mask_1d):
        idx = np.nonzero(mask_1d)[0]
        return int(idx[0]) if len(idx) else 0

    rows = far.mean(axis=1) > 0.15      # 그 줄의 15% 이상이 종이색이 아니면 그림
    cols = far.mean(axis=0) > 0.15
    top = first_true(rows)
    bottom = h - first_true(rows[::-1])
    left = first_true(cols)
    right = w - first_true(cols[::-1])
    if right - left < w * 0.5 or bottom - top < h * 0.5:
        return im                        # 뭔가 이상하면 그대로 둡니다
    return Image.fromarray(a[top:bottom, left:right].astype("uint8"))


## 그레이디언트 맵의 양 끝. 지브리풍 배경의 색 폭이 대체로 이 사이입니다 -
## 그늘도 검정이 아니라 따뜻한 갈색이고, 밝은 곳도 순백이 아니라 크림색입니다.
TONE_SHADOW = (0.45, 0.34, 0.25)
TONE_LIGHT = (1.00, 0.94, 0.80)


def stylize(im, detail: float = 1.0, saturation: float = 1.0,
             lift: float = 0.0, contrast: float = 1.0, warmth: float = 0.0,
             flatten: float = 0.0, tone: float = 0.0):
    """그림을 게임 배경답게 눕힙니다.

    원본은 한 장으로 보는 삽화라 색이 진하고 잔무늬가 촘촘합니다. 그대로
    깔면 두 가지가 걸립니다 - **어두운 얼룩이 타일마다 되풀이되고**, 무늬가
    캐릭터보다 자세해서 눈이 바닥으로 갑니다. 배경은 캐릭터보다 한 단계
    물러나 있어야 합니다.

    flatten   큰 얼룩을 지웁니다. 화면 넓이의 12% 로 흐린 그림으로 나눠서
              전체 밝기를 고르게 만듭니다. 붓질(잔무늬)은 그 크기보다
              작아서 살아남고, 넓게 진 그늘만 사라집니다.
    detail    잔무늬를 남길 비율. 흐린 판과 원본의 차이를 줄여서 깎습니다.
    lift      어두운 쪽만 끌어올립니다. 되풀이가 눈에 띄는 건 결국 대비라,
              검은 점이 옅어지면 같은 무늬라도 덜 도드라집니다.
    warmth    종이색(따뜻한 아이보리) 쪽으로 당깁니다.
    tone      밝기에 따라 **따뜻한 두 색 사이**로 색을 모읍니다(그레이디언트
              맵). 채도만 낮추면 따뜻함까지 같이 빠져 베이지-회색이 되는데,
              이렇게 하면 진한 곳은 나뭇빛, 옅은 곳은 크림색으로 모여
              색은 하나로 정리되면서 따뜻함은 남습니다. 원본의 초록 이끼
              얼룩처럼 튀는 색이 흡수되는 효과도 같이 옵니다 - 되풀이가
              가장 먼저 눈에 띄던 것이 그 얼룩이었습니다.
    """
    import numpy as np
    from PIL import Image, ImageFilter

    a = np.asarray(im.convert("RGB"), dtype=np.float32) / 255.0
    w, h = im.size
    span = float(max(w, h))

    def blurred(arr, radius):
        src = Image.fromarray((np.clip(arr, 0.0, 1.0) * 255.0).astype("uint8"))
        out = src.filter(ImageFilter.GaussianBlur(radius))
        return np.asarray(out, dtype=np.float32) / 255.0

    if flatten > 0.0:
        lum = a.mean(axis=2)
        base = blurred(lum, span * 0.12)
        ratio = np.clip(float(lum.mean()) / np.maximum(base, 1e-3), 0.72, 1.38)
        a = a * (1.0 + (ratio - 1.0) * flatten)[..., None]

    if detail < 1.0:
        soft = blurred(a, span * 0.0035)
        a = soft + (a - soft) * detail

    if saturation != 1.0:
        gray = (a * np.array([0.299, 0.587, 0.114], dtype=np.float32)).sum(axis=2)
        a = gray[..., None] + (a - gray[..., None]) * saturation

    if lift > 0.0:
        # 어두운 쪽만 끌어올립니다. 전체에 더하면 중간톤까지 같이 떠서
        # 나무색이 모래색이 됩니다(실제로 그랬습니다). 세제곱을 쓰면
        # 검정에는 lift 만큼, 중간톤에는 그 1/8 만, 밝은 곳에는 거의
        # 영향이 없습니다.
        a = a + lift * np.power(1.0 - a, 3.0)
    if contrast != 1.0:
        a = 0.62 + (a - 0.62) * contrast
    if tone > 0.0:
        shadow = np.array(TONE_SHADOW, dtype=np.float32)
        light = np.array(TONE_LIGHT, dtype=np.float32)
        lum = (a * np.array([0.299, 0.587, 0.114], dtype=np.float32)).sum(axis=2)
        ramp = shadow + (light - shadow) * np.clip(lum, 0.0, 1.0)[..., None]
        a = a * (1.0 - tone) + ramp * tone

    if warmth > 0.0:
        # 밝기는 그대로 두고 색만 기웁니다. 그냥 곱하면 같이 어두워집니다.
        paper = np.array([1.06, 1.00, 0.86], dtype=np.float32)
        a = a * (1.0 + (paper - 1.0) * warmth)

    return Image.fromarray((np.clip(a, 0.0, 1.0) * 255.0).astype("uint8"))


def tile_preview(im, cols: int = 3, rows: int = 2, width: int = 900) -> "Image":
    """미러 타일링을 그대로 흉내 낸 미리보기. 되풀이가 눈에 띄는지 봅니다.

    게임은 UV 를 한 칸 걸러 뒤집어 붙입니다(dungeon.gd). 같은 방식으로
    이어 붙여 봐야 실제로 어떻게 보이는지 알 수 있습니다.
    """
    from PIL import Image

    cell = im.resize((width // cols, int(im.height * (width // cols) / im.width)),
                     Image.LANCZOS)
    out = Image.new("RGB", (cell.width * cols, cell.height * rows))
    for r in range(rows):
        for c in range(cols):
            piece = cell
            if c % 2:
                piece = piece.transpose(Image.FLIP_LEFT_RIGHT)
            if r % 2:
                piece = piece.transpose(Image.FLIP_TOP_BOTTOM)
            out.paste(piece, (c * cell.width, r * cell.height))
    return out


## 용도별 프리셋. 바닥은 캐릭터가 늘 그 위에 서 있어서 가장 많이 물러나야
## 하고, 벽은 옆면만 잠깐 보이므로 원본을 조금 더 남깁니다.
STYLES = {
    "floor": dict(flatten=1.0, detail=0.38, saturation=0.80, lift=0.42,
                  contrast=0.88, tone=0.45, warmth=0.28),
    "wall": dict(flatten=0.75, detail=0.55, saturation=0.85, lift=0.30,
                 contrast=0.92, tone=0.30, warmth=0.30),
}


def convert(src: Path, name: str, crop_bottom: float = 0.0,
            style: str = "") -> Path:
    from PIL import Image

    OUT.mkdir(parents=True, exist_ok=True)
    im = Image.open(src).convert("RGB")
    before = im.size
    im = trim_paper(im)
    if crop_bottom > 0.0:
        # 벽 그림 아래쪽에 바닥이 같이 그려져 있으면 잘라 냅니다. 벽면에
        # 바닥이 또 나오면 두 겹으로 보입니다.
        keep = int(im.height * (1.0 - crop_bottom))
        im = im.crop((0, 0, im.width, keep))
    # 종이 테두리를 잘라도 붓이 번진 밝은 줄이 한두 픽셀 남습니다. 타일
    # 경계에서 그것이 흰 선으로 도드라져서, 안쪽으로 한 번 더 깎습니다.
    w, h = im.size
    im = im.crop((int(w * 0.02), int(h * 0.02), w - int(w * 0.02), h - int(h * 0.02)))
    if im.width > TARGET_WIDTH:
        scale = TARGET_WIDTH / im.width
        im = im.resize((TARGET_WIDTH, max(1, round(im.height * scale))),
                       Image.LANCZOS)
    if style:
        im = stylize(im, **STYLES[style])
        # 되풀이가 어떻게 보이는지는 한 장으로는 알 수 없습니다. 게임과 같은
        # 방식으로 이어 붙인 미리보기를 남겨 눈으로 확인합니다.
        preview = ROOT / "out" / f"_tile_{name}.png"
        preview.parent.mkdir(exist_ok=True)
        tile_preview(im).save(preview)
    target = OUT / f"{name}.png"
    im.save(target, optimize=True)
    print(f"[ok] {target.name}  {before} -> {im.size}  "
          f"({target.stat().st_size // 1024} KB)")
    return target


def main() -> int:
    args = sys.argv[1:]
    if len(args) >= 2:
        crop = float(args[2]) if len(args) >= 3 else 0.0
        style = args[3] if len(args) >= 4 else ""
        convert(Path(args[0]), args[1], crop, style)
        return 0
    print("최근 올린 그림 (최신순):")
    import time
    for t, p in find_uploads():
        try:
            from PIL import Image
            size = Image.open(p).size
        except Exception:
            size = "?"
        print(f"  {time.strftime('%m-%d %H:%M', time.localtime(t))}  {str(size):<12} {p}")
    print("\n쓰려면:  python tools/make_textures.py <위 경로> <이름>")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
