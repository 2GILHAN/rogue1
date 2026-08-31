"""웹 빌드를 폰에서 열 수 있게 띄웁니다.

    python tools/serve.py

ServerControl 이 포트와 tailnet 주소를 정해 줍니다. 출력된 주소를 폰에서
열면 됩니다.

# 이 서버가 신경 쓰는 것

  - **application/wasm** 헤더. 이게 틀리면 브라우저가 스트리밍 컴파일을
    포기하고, 폰에서는 그대로 메모리 부족으로 죽습니다.
  - **gzip**. 웹 빌드는 40MB 가 넘는데 대부분이 wasm 이고, 압축하면 1/4 로
    줄어듭니다. 폰에서 기다리는 시간이 곧 이 숫자입니다.
  - **캐시**. 두 번째부터는 받지 않게 해 둡니다. 코드가 바뀌면 파일 시간이
    바뀌므로 ETag 로 구분됩니다.

스레드를 끄고 내보냈기 때문에(export_presets.cfg 의 thread_support=false)
COOP/COEP 헤더는 필요 없습니다. 그 헤더가 필요한 빌드였다면 사설 인증서
없이는 폰에서 열리지 않았을 겁니다.
"""
from __future__ import annotations

import gzip
import io
import os
import sys
from email.utils import formatdate
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from servercontrol_client import register  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent / "build" / "web"
APP_ID = "rogue1"          # 한 번 정하면 바꾸지 않습니다 - 주소가 여기서 나옵니다.

TYPES = {
    ".html": "text/html; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".wasm": "application/wasm",
    ".pck": "application/octet-stream",
    ".png": "image/png",
    ".svg": "image/svg+xml",
    ".json": "application/json",
}
# 압축해서 이득이 있는 것만. png 는 이미 압축돼 있어 오히려 CPU 만 씁니다.
COMPRESS = {".html", ".js", ".wasm", ".pck", ".json", ".svg"}

_cache: dict[str, tuple[float, bytes]] = {}


def _cache_policy(content_type: str, cache: bool) -> str:
    if not cache:
        return "no-store"
    # html/js 와 **pck** 는 늘 물어보게 합니다.
    #
    # pck 안에 게임 코드가 통째로 들어 있습니다. 10분을 캐시하게 두면 새로
    # 내보낸 뒤에도 폰이 옛 코드를 그대로 돌립니다 - 실제로 조작을 바꾼 뒤에도
    # 예전 방식으로 동작한다는 이야기를 들었고, 원인이 이것이었습니다.
    #
    # 매번 다시 내려받지는 않습니다. ETag 가 같으면 304 로 끝나므로, 바뀌지
    # 않았을 때의 비용은 왕복 한 번입니다.
    if ("html" in content_type or "javascript" in content_type
            or "octet-stream" in content_type):
        return "no-cache, must-revalidate"
    # wasm 은 엔진 템플릿이라 빌드해도 바뀌지 않습니다. 40MB 를 매번 물어볼
    # 이유가 없습니다.
    return "public, max-age=600"


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "rogue1"

    def log_message(self, fmt, *args):  # 조용히
        pass

    def handle_one_request(self):
        # 폰이 탭을 닫거나 화면이 꺼지면 연결이 그냥 끊깁니다. 그때마다
        # 역추적이 찍히면 진짜 오류가 묻힙니다.
        try:
            super().handle_one_request()
        except (ConnectionResetError, ConnectionAbortedError, BrokenPipeError):
            self.close_connection = True

    def do_GET(self) -> None:
        self._serve(body=True)

    def do_HEAD(self) -> None:
        self._serve(body=False)

    def _serve(self, body: bool) -> None:
        path = self.path.split("?", 1)[0]
        if path == "/healthz":
            self._send(b"ok", "text/plain", body, cache=False)
            return
        if path in ("/", ""):
            path = "/index.html"

        target = (ROOT / path.lstrip("/")).resolve()
        if not str(target).startswith(str(ROOT.resolve())) or not target.is_file():
            self._send(b"not found", "text/plain", body, status=404, cache=False)
            return

        suffix = target.suffix.lower()
        data = target.read_bytes()
        etag = '"%d-%d"' % (int(target.stat().st_mtime), len(data))
        if self.headers.get("If-None-Match") == etag:
            self.send_response(304)
            self.send_header("ETag", etag)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return

        encoding = None
        if suffix in COMPRESS and "gzip" in (self.headers.get("Accept-Encoding") or ""):
            key = str(target)
            stamp = target.stat().st_mtime
            hit = _cache.get(key)
            if hit is None or hit[0] != stamp:
                buffer = io.BytesIO()
                with gzip.GzipFile(fileobj=buffer, mode="wb", compresslevel=6) as gz:
                    gz.write(data)
                hit = (stamp, buffer.getvalue())
                _cache[key] = hit
            data = hit[1]
            encoding = "gzip"

        self._send(data, TYPES.get(suffix, "application/octet-stream"), body,
                   etag=etag, encoding=encoding)

    def _send(self, data: bytes, content_type: str, body: bool, *,
              status: int = 200, etag: str | None = None,
              encoding: str | None = None, cache: bool = True) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Date", formatdate(usegmt=True))
        if encoding:
            self.send_header("Content-Encoding", encoding)
        if etag:
            self.send_header("ETag", etag)
        # 껍데기(html/js)는 캐시하지 않습니다.
        #
        # 폰에서 새 빌드를 올려도 옛 화면이 계속 떴습니다. wasm 과 pck 는
        # 매번 새로 받으면서 **index.html 만 캐시에 남아** 있었기 때문인데,
        # 거기에 오디오 훅처럼 중요한 것이 들어 있으면 고친 것이 반영되지
        # 않습니다. ETag 가 있어서 재검증은 싸게 끝납니다.
        self.send_header("Cache-Control", _cache_policy(content_type, cache))
        self.end_headers()
        if body:
            self.wfile.write(data)


def main() -> int:
    # 파이프로 넘길 때 버퍼에 갇히면 주소를 못 봅니다.
    try:
        sys.stdout.reconfigure(line_buffering=True)
    except AttributeError:
        pass
    if not (ROOT / "index.html").exists():
        print(f"[!] 웹 빌드가 없습니다: {ROOT}")
        print("    먼저: tools\\build_web.bat")
        return 1

    info = register(APP_ID, title="Emberling (로그라이크)", health="/healthz")
    # 0.0.0.0 에 바인드하지 않습니다. 이 PC 의 이더넷은 공인 IP 입니다.
    server = ThreadingHTTPServer(("127.0.0.1", info.port), Handler)
    total = sum(f.stat().st_size for f in ROOT.iterdir() if f.is_file())
    print(f"빌드 {total // (1024 * 1024)}MB  ({ROOT})")
    print(f"로컬:  http://127.0.0.1:{info.port}/")
    if info.url:
        print(f"폰에서: {info.url}")
    else:
        print("ServerControl 에 등록하지 못했습니다 - 로컬 주소로만 열립니다.")
    print("Ctrl+C 로 종료")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n종료")
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
