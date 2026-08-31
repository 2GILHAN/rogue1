"""잡기와 던지기 효과음을 만듭니다.

    python tools/make_sfx.py

# 왜 만드나

목소리(고함)와 밀기는 vtos 에서 잘라 온 실제 녹음이지만, 잡기와 던지기는
쓸 만한 클립이 없습니다. 짧고 유쾌한 소리 둘이라 합성으로 충분합니다 -
녹음을 구하는 것보다 빠르고, 마음에 안 들면 숫자만 고쳐 다시 만듭니다.

# 어떤 소리인가

- **잡기**: 위로 튀는 "뽕". 무언가 손에 붙었다는 신호라 **짧고 끝이 분명해야**
  합니다. 길게 늘어지면 집는 동작(0.42초)보다 소리가 오래 남습니다.
- **던지기**: 바람 소리에 올라가는 휘파람. 날아가는 것이 눈에 보이므로
  소리는 **떠나는 순간**만 맡습니다.

둘 다 장조 음정(도-미-솔 언저리)으로 잡았습니다. 아이가 주인공인 게임이라
소리도 그쪽이어야 합니다 - 같은 합성이라도 반음이 섞이면 불길해집니다.

의존성 없이 표준 라이브러리만 씁니다.
"""
import array
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"


def write(name: str, samples: list[float]) -> None:
    """-1..1 실수 배열을 16비트 모노 wav 로 씁니다."""
    # 마지막 3ms 를 0 으로 내립니다. 뚝 끊으면 "탁" 하는 잡음이 남습니다.
    tail = int(RATE * 0.003)
    for i in range(max(0, len(samples) - tail), len(samples)):
        samples[i] *= (len(samples) - i) / tail

    peak = max(0.0001, max(abs(v) for v in samples))
    data = array.array("h", (int(max(-1.0, min(1.0, v / peak * 0.92)) * 32767)
                             for v in samples))
    path = OUT / name
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print(f"[ok] {path.name}  {len(samples) / RATE:.2f}초  {path.stat().st_size // 1024} KB")


def grab_pop() -> list[float]:
    """잡기. 아래에서 위로 튀어 오르는 짧은 소리."""
    dur = 0.20
    n = int(RATE * dur)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / RATE
        u = t / dur
        # 음이 위로 휩니다(440 -> 990Hz). 올라가는 쪽이 "붙었다",
        # 내려가는 쪽은 "놓쳤다" 로 들립니다.
        freq = 440.0 * (1.0 + 1.25 * u * u)
        phase += 2.0 * math.pi * freq / RATE
        # 기본음에 3배음을 조금 섞어 나무 장난감 같은 소리를 만듭니다.
        v = math.sin(phase) + 0.28 * math.sin(phase * 3.0)
        # 순간적으로 세게 나왔다가 빠르게 잦아듭니다.
        env = math.exp(-9.0 * t) * min(1.0, t / 0.004)
        out[i] = v * env
    return out


def throw_whoosh() -> list[float]:
    """던지기. 바람 소리 위에 올라가는 휘파람."""
    dur = 0.34
    n = int(RATE * dur)
    out = [0.0] * n
    rng = random.Random(7)          # 매번 같은 소리가 나오도록 고정합니다
    lp = 0.0
    phase = 0.0
    for i in range(n):
        t = i / RATE
        u = t / dur
        # 바람: 잡음을 저역통과에 통과시키고, 그 문턱을 위로 올립니다.
        # 문턱이 고정이면 바람이 아니라 그냥 쉭 소리입니다.
        cut = 0.03 + 0.30 * u
        lp += cut * (rng.uniform(-1.0, 1.0) - lp)
        # 휘파람: 낮은 도에서 높은 솔까지.
        freq = 330.0 * (1.0 + 2.0 * u)
        phase += 2.0 * math.pi * freq / RATE
        tone = math.sin(phase) * 0.5
        # 부풀었다 사라집니다. 처음부터 세면 던지기 전에 소리가 먼저 납니다.
        env = math.sin(math.pi * min(1.0, u ** 0.7)) ** 1.4
        out[i] = (lp * 1.6 + tone) * env
    return out


# ---------------------------------------------------------------- 나머지 소리
#
# 아래는 "자리는 있는데 소리가 없던" 곳들을 채운 것입니다. 전부 합성이고,
# 나중에 녹음으로 갈아 끼울 자리입니다 - 파일 이름만 맞추면 코드는 그대로입니다.
#
# 공통 규칙 셋:
#   1. **짧게.** 게임에서 초당 여러 번 나는 소리라, 길면 서로 밟습니다.
#   2. **장조.** 아이가 주인공이라 반음이 섞이면 불길해집니다.
#   3. **끝을 분명히.** 여운이 길면 다음 소리와 뭉개집니다.


def _noise_burst(dur: float, cut0: float, cut1: float, seed: int,
                 curve: float = 1.0) -> list:
    """저역통과 잡음 한 덩어리. 문턱을 움직여 '쉭' 과 '툭' 을 만듭니다."""
    rng = random.Random(seed)
    n = int(RATE * dur)
    out = [0.0] * n
    lp = 0.0
    for i in range(n):
        u = i / n
        cut = cut0 + (cut1 - cut0) * u
        lp += cut * (rng.uniform(-1.0, 1.0) - lp)
        out[i] = lp * ((1.0 - u) ** curve)
    return out


def _tone(dur: float, f0: float, f1: float, curve: float = 2.0,
          harm: float = 0.0) -> list:
    """미끄러지는 음 하나. `harm` 은 3배음 섞는 양입니다."""
    n = int(RATE * dur)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        u = i / n
        freq = f0 + (f1 - f0) * u
        phase += 2.0 * math.pi * freq / RATE
        v = math.sin(phase) + math.sin(phase * 3.0) * harm
        out[i] = v * ((1.0 - u) ** curve)
    return out


def _mix(*parts) -> list:
    n = max(len(p) for p in parts)
    out = [0.0] * n
    for p in parts:
        for i, v in enumerate(p):
            out[i] += v
    return out


def hurt_yelp() -> list:
    """주인공 피격. 짧게 **내려가는** 소리 - 올라가면 아픈 것이 아니라
    놀란 것으로 들립니다."""
    return _mix(_tone(0.16, 620.0, 330.0, 2.4, 0.25),
                _noise_burst(0.09, 0.25, 0.05, 11, 2.0))


def foe_hit() -> list:
    """적 피격. 살짝 둔한 '툭'. 초당 여러 번 나므로 가장 짧습니다."""
    return _mix(_tone(0.085, 260.0, 150.0, 3.0),
                _noise_burst(0.055, 0.35, 0.10, 22, 2.5))


def foe_die() -> list:
    """처치. 바람 빠지듯 내려가고 끝에 작게 '퐁'."""
    down = _tone(0.30, 420.0, 120.0, 1.6, 0.15)
    puff = _noise_burst(0.26, 0.20, 0.02, 33, 1.4)
    pop = [0.0] * int(RATE * 0.17) + _tone(0.10, 700.0, 900.0, 3.0)
    return _mix(down, [v * 0.7 for v in puff], [v * 0.5 for v in pop])


def coin() -> list:
    """금화. 도-솔 두 음. 위로 뛰어야 '얻었다' 로 들립니다."""
    a = _tone(0.09, 880.0, 880.0, 2.0, 0.35)
    b = [0.0] * int(RATE * 0.06) + _tone(0.16, 1320.0, 1320.0, 2.2, 0.3)
    return _mix(a, b)


def step() -> list:
    """발소리. 아주 작고 짧은 '톡'. 걷는 내내 나므로 여기서 조금만 커져도
    금세 시끄러워집니다."""
    return _mix(_tone(0.055, 180.0, 110.0, 3.5),
                _noise_burst(0.045, 0.30, 0.08, 44, 3.0))


def warn() -> list:
    """적의 공격 예고. 같은 음 두 번 - 멜로디가 되면 신호가 아니라 음악입니다."""
    a = _tone(0.07, 990.0, 990.0, 2.0)
    b = [0.0] * int(RATE * 0.10) + _tone(0.09, 990.0, 990.0, 2.0)
    return _mix(a, b)


def page() -> list:
    """책장 넘김. 종이 스치는 소리 둘."""
    a = _noise_burst(0.13, 0.55, 0.18, 55, 1.2)
    b = [0.0] * int(RATE * 0.16) + _noise_burst(0.11, 0.50, 0.20, 66, 1.2)
    return _mix(a, b)


def stairs() -> list:
    """층 이동. 도-미-솔 - 올라가는 세 음이라 '다음' 으로 읽힙니다."""
    out = [0.0] * int(RATE * 0.46)
    for k, f in enumerate((523.0, 659.0, 784.0)):
        start = int(RATE * 0.10 * k)
        piece = _tone(0.26, f, f, 2.2, 0.25)
        for i, v in enumerate(piece):
            if start + i < len(out):
                out[start + i] += v * 0.8
    return out


def pick() -> list:
    """고르기(축복·상점). 밝고 아주 짧은 '띵'."""
    return _tone(0.13, 1180.0, 1580.0, 2.6, 0.3)


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    write("grab_pop.wav", grab_pop())
    write("throw_whoosh.wav", throw_whoosh())
    write("hurt_yelp.wav", hurt_yelp())
    write("foe_hit.wav", foe_hit())
    write("foe_die.wav", foe_die())
    write("coin.wav", coin())
    write("step.wav", step())
    write("warn.wav", warn())
    write("page.wav", page())
    write("stairs.wav", stairs())
    write("pick.wav", pick())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
