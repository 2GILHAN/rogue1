# 이 프로젝트에서 일하는 방법

Godot 4.7 3D 액션 로그라이크. 캐릭터는 test3(img2model)이 만든 GLB 입니다.

## 문서 셋

| | 무엇 | 언제 고치나 |
|---|---|---|
| `docs/ANIMATION.md` | 동작이 만들어지는 경로, 각도 규약, 측정 상수, 새 동작 추가법 | 클립·리그·자세 층·재생 속도를 건드릴 때마다 |
| `docs/SYSTEMS.md` | 기술·적·축복·소품·던전·카메라·소리의 현재 수치와 규칙 | 게임 수치나 규칙을 바꿀 때마다 |
| `README.md` | **경위** — 왜 이렇게 됐는지, 무엇을 틀렸다 고쳤는지 | 판단이 필요했던 일을 했을 때 |

**규칙: 코드를 바꾸면 해당 문서를 같은 작업 안에서 고칩니다.** 나중에 몰아서
고치지 않습니다 — 문서와 코드가 갈라지면 문서를 아무도 안 믿게 되고, 그때부터는
없는 것과 같습니다.

특히 이런 것들:

- `player.gd` / `enemy.gd`의 상수를 바꿨다 → `docs/SYSTEMS.md`의 해당 표
- 클립을 다시 구웠다 → **바닥 미는 속도를 다시 재서** `docs/ANIMATION.md`의
  측정 상수 표와 코드 양쪽에
- `pose_override.gd`에 자세를 더했다 → `docs/ANIMATION.md`의 자세 목록
- 축복·적·소품을 더했다 → `docs/SYSTEMS.md`의 해당 표
- 개발용 인자를 더했다 → `docs/SYSTEMS.md`의 인자 목록

문서에 적은 숫자는 **코드에서 읽은 값**이어야 합니다. 기억이나 앞선 대화에서
옮겨 적지 말고 그때그때 `grep` 해서 확인합니다.

## 판 번호를 올립니다

`scripts/game.gd`의 `VERSION`이 화면 오른쪽 아래에 뜹니다. **무엇을 고치든
같은 작업 안에서 올립니다.** 폰은 빌드를 캐시할 수 있고 새로고침이 먹었는지
화면만 봐서는 알 수 없어서, 이 번호가 "지금 내가 고친 것을 하고 있나" 를
확인하는 유일한 수단입니다.

- 수치·값만 바꿨다 → 뒷자리 (`v0.1` → `v0.1.1`)
- 규칙이나 기능이 바뀌었다 → 앞자리 (`v0.1` → `v0.2`)

## 작업을 마칠 때

```bash
GODOT="/c/Users/GilhanLee/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
"$GODOT" --headless --import --path "C:\\_project\\rogue1"
"$GODOT" --path "C:\\_project\\rogue1" --resolution 960x540 --fixed-fps 60 -- --bot --quit-after=9000
"$GODOT" --headless --path "C:\\_project\\rogue1" --export-release "Web"
```

- 소크는 **오류 0**이어야 합니다. 시점을 건드렸으면 `--shoulder` 있는 것과 없는
  것 두 번.
- 한글 문자열을 늘렸으면 `python tools/make_font.py`(서브셋을 다시 만들지 않으면
  폰에서 글자가 빕니다).
- 공개 주소: https://2gilhan.github.io/rogue1/ — `gh-pages` 가지에
  `build/web` 을 통째로 올립니다. **`variant/thread_support` 를 켜지 마세요**
  (GitHub Pages 는 교차 출처 격리 헤더를 못 붙입니다).
- 폰 빌드 주소: https://home.tailc06b21.ts.net:8456/ — `tools/serve.py`가 8807에
  붙습니다. `index.pck`는 `no-cache`여야 합니다(캐시되면 폰이 옛 코드를 돕니다).

## 폴더

`assets/` 는 **게임에 들어가는 것만**입니다. 굽기 전 재료(`src`·`backup`·
`source`·`unused`)는 `art_src/` 에 있고 `.gdignore` 가 있어 Godot 이 들여오지도
않습니다. **게임 코드가 `art_src/` 를 읽으면 안 됩니다** — 필요하면 굽어서
`assets/` 아래로 내보내세요.

사람 이름을 파일에 쓰지 않습니다. 적은 하는 일로 부릅니다
(`foe_charger` · `foe_shouter` …), 화면 이름은 `Enemy.LABEL` 한 곳에 있습니다.

## 건드리지 말 것

- **`C:\_project\test3`는 다른 프로젝트도 쓰는 공용 코드입니다.** 이 게임만의
  보정은 `tools/make_kids.py`에서 하세요(`fix_knees`가 그 예입니다).
- `tools/raise_hips.py`를 손으로 부르지 마세요. `make_kids.py`가 굽기 끝에
  부릅니다 — 그래야 다시 구워도 되돌아가지 않습니다.
- 서버는 포트로 PID를 찾아 그것만 죽입니다. 이름 기반 종료(`taskkill /im
  python.exe`)는 옆 프로젝트를 전멸시킵니다.

## 재서 정합니다

이 프로젝트에서 눈으로 판단했다가 틀린 일이 여러 번 있었습니다(팔 앞뒤, 무릎
방향, 적 보폭). 각도·거리·속도는 **찍어서 재고** 고릅니다 — 측정 경로 목록은
`docs/ANIMATION.md`의 "재는 법"에 있습니다.
