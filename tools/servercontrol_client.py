"""ServerControl 등록 클라이언트 (Python).

새 프로그램에 이 파일을 복사해 넣고 서버를 띄우기 직전에 부르면 된다.
의존성 없음. 표준 라이브러리만 쓴다.

    from servercontrol_client import register

    info = register("myapp", title="내 앱", health="/healthz")
    app.run(host="127.0.0.1", port=info.port)
    print("폰에서:", info.url)

규칙 세 가지만 지키면 된다.

1. **받은 포트에 127.0.0.1로만** 바인드한다. 0.0.0.0은 이 PC가 공인 IP라
   인터넷에 그대로 열린다.
2. `tailscale` CLI를 직접 부르지 않는다. 노출은 ServerControl이 한다.
3. 등록이 실패해도 그냥 뜬다. ServerControl은 편의 계층이지 의존성이 아니다.
"""
from __future__ import annotations

import atexit
import json
import os
import sys
import urllib.error
import urllib.request
from typing import NamedTuple

ENDPOINT = os.environ.get("SERVERCONTROL_URL", "http://127.0.0.1:8799")
TIMEOUT = 2.0


class Registration(NamedTuple):
    port: int           # 여기에 바인드하면 된다
    url: str | None     # 폰에서 열 주소. ServerControl이 없으면 None
    registered: bool    # False면 fallback 포트로 도는 중


def launch_command() -> list[str]:
    """이 프로세스를 다시 띄우려면 뭐라고 쳐야 하는지.

    `python -m taxrefund serve` 로 띄운 경우 sys.argv[0]은 패키지 안의
    __main__.py 절대경로다. 그걸 그대로 다시 실행하면 상대 임포트가 깨져서
    재시작이 실패한다. -m 으로 띄웠는지는 __main__.__spec__ 로 알 수 있다.
    """
    import __main__
    spec = getattr(__main__, "__spec__", None)
    if spec is not None and getattr(spec, "parent", ""):
        return [sys.executable, "-m", spec.parent, *sys.argv[1:]]
    return [sys.executable, *sys.argv]


def _post(path: str, payload: dict, timeout: float = TIMEOUT) -> dict | None:
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(ENDPOINT + path, data=body,
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read() or b"{}")
    except (urllib.error.URLError, OSError, ValueError, TimeoutError):
        return None


def register(app_id: str, *, title: str | None = None,
             health: str | None = "/healthz", port: int | None = None,
             fallback: int = 8080, deregister_on_exit: bool = True) -> Registration:
    """주소를 받아온다. ServerControl이 없으면 fallback 포트로 조용히 물러난다.

    app_id는 바꾸지 마라. 이 값이 주소를 결정한다 - 바꾸면 폰에 저장해둔
    주소가 죽는다.
    """
    data = _post("/api/register", {
        "id": app_id,
        "title": title or app_id,
        "health": health,
        "port": port,
        "pid": os.getpid(),
        "dir": os.getcwd(),
        # 어떻게 띄웠는지 알려주면 대시보드에서 재시작할 수 있다.
        # 폰에서 죽은 앱을 되살리려면 이 정보가 있어야 한다.
        "cmd": launch_command(),
    })
    if not data or not data.get("ok"):
        return Registration(port=port or fallback, url=None, registered=False)

    if deregister_on_exit:
        atexit.register(deregister, app_id)
    return Registration(port=int(data["port"]), url=data.get("url"), registered=True)


def deregister(app_id: str) -> None:
    """종료를 알린다. 안 불러도 ServerControl이 알아서 눈치채지만, 부르면 즉시 반영된다."""
    _post("/api/deregister", {"id": app_id}, timeout=1.0)


if __name__ == "__main__":       # 연결 확인용
    info = register("selftest", title="연결 테스트", health=None)
    print(f"port={info.port}  url={info.url}  registered={info.registered}")
    deregister("selftest")
