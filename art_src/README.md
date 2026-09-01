# 게임에 안 들어가는 원본

여기 있는 것은 **굽기 전의 재료**입니다. `.gdignore` 가 있어서 Godot 이
들여오지도 않습니다 - 예전에는 `assets/models/_src`(80MB)를 매번 들여오느라
`.godot` 이 부풀고 들여오기가 느렸습니다.

| | 무엇 |
|---|---|
| `src/` | test3 가 낸 조각 클립(`*_idle.glb`, `*_walk.glb`). `tools/make_kids.py` 가 이것을 합쳐 `assets/characters/` 를 만듭니다 |
| `backup/` | 굽기 전 원본(`.orig`). 되돌릴 때 씁니다 |
| `source/` | 소품을 굽는 데 쓴 4면도 원본 그림 |
| `unused/` | 지금 안 쓰는 모델. 되살릴 수 있게 남겨 둡니다 |

**여기 것을 게임이 읽으면 안 됩니다.** 읽어야 하는 것이 생기면 굽어서
`assets/` 아래로 내보내세요.
