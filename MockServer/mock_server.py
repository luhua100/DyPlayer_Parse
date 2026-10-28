#!/usr/bin/env python3
"""
本地 Mock 服务：配合 MVVM_Local 演示博客里的 /v1/users 分页接口。

用法：
    python3 MockServer/mock_server.py

模拟器访问 http://localhost:8090；真机请把 NetworkConfig.baseURL
改成 Mac 的局域网 IP（例如 http://192.168.1.10:8090）。
"""

import json
import re
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

PORT = 8090

NAMES = [
    "林晚照", "周砚", "陈见月", "许星野", "沈知夏", "顾青禾", "苏木", "江停",
    "温言", "陆沉", "白露", "宋别", "叶归", "唐棠", "秦朝暮", "黎安",
]

# id=3 的昵称故意留空，用来验证 UserViewData 的「未命名用户」兜底文案。
# id=5 的头像故意为 null，用来验证 avatarURL 为 nil 的分支。
USERS = [
    {
        "id": i,
        "nickname": "" if i == 3 else f"{NAMES[(i - 1) % len(NAMES)]}{i:02d}",
        "avatar": None if i == 5 else f"https://i.pravatar.cc/100?img={i % 70 + 1}",
        "followed": i % 3 == 0,
        "created_at": "2026-10-01T12:00:00Z",
    }
    for i in range(1, 87)
]


class Handler(BaseHTTPRequestHandler):
    server_version = "MVVMLocalMock/1.0"

    def _send_json(self, payload, status=200):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _envelope(self, data=None, code=0, message="ok"):
        return {"code": code, "message": message, "data": data}

    def _read_json_body(self):
        length = int(self.headers.get("Content-Length", "0") or 0)
        if length <= 0:
            return {}
        try:
            return json.loads(self.rfile.read(length).decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            return {}

    # ------------------------------------------------------------------ GET
    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/") or "/"

        if path != "/v1/users":
            self._send_json(self._envelope(code=404, message="Not Found"), 404)
            return

        query = parse_qs(parsed.query)
        try:
            page = max(int(query.get("page", ["1"])[0]), 1)
            page_size = min(max(int(query.get("pageSize", ["20"])[0]), 1), 50)
        except ValueError:
            page, page_size = 1, 20

        # 稍微延迟，方便在模拟器里看到 loading 状态
        time.sleep(0.15)

        start = (page - 1) * page_size
        end = start + page_size
        items = USERS[start:end]

        data = {
            "list": items,
            "page": page,
            "pageSize": page_size,
            "total": len(USERS),
            "hasMore": end < len(USERS),
        }
        self._send_json(self._envelope(data=data))

    # ----------------------------------------------------------------- POST
    def do_POST(self):
        parsed = urlparse(self.path)
        match = re.fullmatch(r"/v1/users/(\d+)/follow", parsed.path.rstrip("/"))
        if not match:
            self._send_json(self._envelope(code=404, message="Not Found"), 404)
            return

        user_id = int(match.group(1))
        user = next((u for u in USERS if u["id"] == user_id), None)
        if user is None:
            self._send_json(self._envelope(code=404, message="用户不存在"), 404)
            return

        user["followed"] = True
        self._send_json(self._envelope())

    # ------------------------------------------------------------------ PUT
    def do_PUT(self):
        parsed = urlparse(self.path)
        match = re.fullmatch(r"/v1/users/(\d+)", parsed.path.rstrip("/"))
        if not match:
            self._send_json(self._envelope(code=404, message="Not Found"), 404)
            return

        user_id = int(match.group(1))
        user = next((u for u in USERS if u["id"] == user_id), None)
        if user is None:
            self._send_json(self._envelope(code=404, message="用户不存在"), 404)
            return

        body = self._read_json_body()
        if "nickname" in body:
            user["nickname"] = str(body["nickname"])
        self._send_json(self._envelope())

    # --------------------------------------------------------------- DELETE
    def do_DELETE(self):
        parsed = urlparse(self.path)
        match = re.fullmatch(r"/v1/users/(\d+)", parsed.path.rstrip("/"))
        if not match:
            self._send_json(self._envelope(code=404, message="Not Found"), 404)
            return

        user_id = int(match.group(1))
        before = len(USERS)
        USERS[:] = [u for u in USERS if u["id"] != user_id]
        if len(USERS) == before:
            self._send_json(self._envelope(code=404, message="用户不存在"), 404)
            return

        self._send_json(self._envelope())

    def log_message(self, fmt, *args):
        print("[mock] " + (fmt % args))


if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(f"Mock API 已启动：http://localhost:{PORT}")
    print("GET  /v1/users?page=1&pageSize=20")
    print("POST /v1/users/{id}/follow")
    print("PUT  /v1/users/{id}")
    print("DEL  /v1/users/{id}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nMock API 已停止")
        server.server_close()
