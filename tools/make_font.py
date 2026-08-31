"""UI 에 실제로 쓰는 글자만 남긴 한글 폰트를 만듭니다.

    python tools/make_font.py

# 왜 필요한가

데스크톱에서는 SystemFont 로 OS 글꼴(맑은 고딕)을 빌려 씁니다. 하지만
**브라우저에는 OS 글꼴을 빌려 줄 방법이 없습니다.** 웹으로 내보내면 모든
한글이 빈 네모가 됩니다. 그래서 폰트를 프로젝트에 넣어야 하는데, 맑은 고딕
전체는 13MB 라 폰에서 받기에 부담입니다.

한글은 완성형만 11,172자입니다. 그중 이 게임이 쓰는 글자는 300자도 안 되므로,
**소스에 등장하는 글자만** 남기면 수십 KB 로 줄어듭니다.

글자를 소스에서 뽑는 이유는 목록을 손으로 관리하면 반드시 빠뜨리기 때문입니다.
문구를 고치면 이 스크립트를 다시 돌리세요.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools" / "_pylibs"))

SOURCE_FONT = Path(r"C:\Windows\Fonts\malgun.ttf")
OUT = ROOT / "assets" / "fonts" / "ui.ttf"

# 화면에 나오는 문자열은 전부 .gd 안에 있습니다. 숫자와 기호는 실행 중에
# 만들어지므로 따로 넣습니다.
EXTRA = (
    "0123456789"
    "abcdefghijklmnopqrstuvwxyz"
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    " !\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"
    "…·—–×÷≤≥±"
    "◆▲■◎●★◇○·•–—"
    "초분층"
)


def collect() -> set:
    chars = set(EXTRA)
    for path in sorted((ROOT / "scripts").glob("*.gd")):
        text = path.read_text(encoding="utf-8")
        # 주석은 화면에 안 나옵니다. 문자열 리터럴만 봅니다.
        for literal in re.findall(r'"([^"\\]*(?:\\.[^"\\]*)*)"', text):
            chars.update(literal)
    # 제어문자는 뺍니다.
    return {c for c in chars if ord(c) >= 32}


def missing_in_source(chars: set) -> list:
    """원본 폰트에 아예 없는 글자를 찾습니다.

    서브셋은 없는 글자를 조용히 넘어갑니다. 그래서 맑은 고딕에 없는 기호를
    쓰면 **폰에서만** 빈 네모로 나오고, 데스크톱에서는 OS 가 다른 글꼴로
    대신 그려 주기 때문에 눈치채지 못합니다. 실제로 금화 아이콘(U+2666)이
    그랬습니다 - 맑은 고딕에는 그 글자가 없습니다.
    """
    from fontTools.ttLib import TTFont

    cmap = TTFont(str(SOURCE_FONT)).getBestCmap()
    return sorted(c for c in chars if ord(c) not in cmap)


def main() -> int:
    if not SOURCE_FONT.exists():
        print(f"[!] 원본 글꼴이 없습니다: {SOURCE_FONT}")
        return 1
    try:
        from fontTools import subset
    except ImportError:
        print("[!] fonttools 가 없습니다. 먼저:")
        print("    python -m pip install --target tools/_pylibs fonttools brotli")
        return 1

    chars = collect()
    gone = missing_in_source(chars)
    if gone:
        print("[!] 원본 폰트에 없는 글자 %d 개 - 화면에서 빈 네모가 됩니다:"
              % len(gone))
        print("    " + " ".join("U+%04X" % ord(c) for c in gone))
    OUT.parent.mkdir(parents=True, exist_ok=True)

    options = subset.Options()
    options.layout_features = ["*"]
    options.notdef_outline = True
    options.recalc_bounds = True
    options.drop_tables += ["DSIG"]

    font = subset.load_font(str(SOURCE_FONT), options)
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(text="".join(sorted(chars)))
    subsetter.subset(font)
    subset.save_font(font, str(OUT), options)
    font.close()

    print(f"[ok] {OUT}")
    print(f"     글자 {len(chars)}자, {SOURCE_FONT.stat().st_size // 1024} KB "
          f"-> {OUT.stat().st_size // 1024} KB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
