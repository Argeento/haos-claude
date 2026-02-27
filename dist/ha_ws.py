#!/usr/bin/env python3
"""Minimal WebSocket client for Home Assistant (stdlib only)."""
import hashlib, base64, json, os, socket, ssl, struct, sys, urllib.parse


def recv_exact(sock, n):
    data = b""
    while len(data) < n:
        chunk = sock.recv(n - len(data))
        if not chunk:
            raise ConnectionError("Connection closed")
        data += chunk
    return data


def ws_send(sock, data, opcode=0x1):
    if isinstance(data, str):
        data = data.encode("utf-8")
    frame = bytearray([0x80 | opcode])
    length = len(data)
    if length <= 125:
        frame.append(0x80 | length)
    elif length <= 65535:
        frame.append(0x80 | 126)
        frame.extend(struct.pack("!H", length))
    else:
        frame.append(0x80 | 127)
        frame.extend(struct.pack("!Q", length))
    mask = os.urandom(4)
    frame.extend(mask)
    frame.extend(bytes(b ^ mask[i % 4] for i, b in enumerate(data)))
    sock.sendall(frame)


def ws_recv(sock):
    header = recv_exact(sock, 2)
    opcode = header[0] & 0x0F
    length = header[1] & 0x7F
    if length == 126:
        length = struct.unpack("!H", recv_exact(sock, 2))[0]
    elif length == 127:
        length = struct.unpack("!Q", recv_exact(sock, 8))[0]
    if header[1] & 0x80:
        mask = recv_exact(sock, 4)
        payload = bytes(b ^ mask[i % 4] for i, b in enumerate(recv_exact(sock, length)))
    else:
        payload = recv_exact(sock, length)
    if opcode == 0x8:
        raise ConnectionError("Server closed connection")
    if opcode == 0x9:
        ws_send(sock, payload, opcode=0xA)
        return ws_recv(sock)
    return payload.decode("utf-8")


def ws_connect(host, port, use_ssl):
    sock = socket.create_connection((host, port), timeout=10)
    if use_ssl:
        ctx = ssl.create_default_context()
        sock = ctx.wrap_socket(sock, server_hostname=host)
    key = base64.b64encode(os.urandom(16)).decode()
    sock.sendall(
        f"GET /api/websocket HTTP/1.1\r\n"
        f"Host: {host}:{port}\r\n"
        f"Upgrade: websocket\r\n"
        f"Connection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key}\r\n"
        f"Sec-WebSocket-Version: 13\r\n"
        f"\r\n".encode()
    )
    response = b""
    while b"\r\n\r\n" not in response:
        response += sock.recv(4096)
    if b"101" not in response.split(b"\r\n")[0]:
        raise ConnectionError(f"WebSocket handshake failed: {response.decode()}")
    return sock


def main():
    if len(sys.argv) < 4:
        print("Usage: ha_ws.py <ha_url> <token> <type> [json_data]", file=sys.stderr)
        sys.exit(1)

    ha_url, token, ws_type = sys.argv[1], sys.argv[2], sys.argv[3]
    ws_data = json.loads(sys.argv[4]) if len(sys.argv) > 4 else {}

    parsed = urllib.parse.urlparse(ha_url)
    use_ssl = parsed.scheme == "https"
    host = parsed.hostname
    port = parsed.port or (443 if use_ssl else 8123)

    sock = ws_connect(host, port, use_ssl)
    try:
        msg = json.loads(ws_recv(sock))
        if msg.get("type") != "auth_required":
            raise Exception(f"Expected auth_required, got: {msg.get('type')}")

        ws_send(sock, json.dumps({"type": "auth", "access_token": token}))

        msg = json.loads(ws_recv(sock))
        if msg.get("type") == "auth_invalid":
            print(json.dumps({"error": "auth_invalid", "message": msg.get("message", "")}), file=sys.stderr)
            sys.exit(1)
        if msg.get("type") != "auth_ok":
            raise Exception(f"Expected auth_ok, got: {msg.get('type')}")

        cmd = {"id": 1, "type": ws_type}
        cmd.update(ws_data)
        ws_send(sock, json.dumps(cmd))

        while True:
            msg = json.loads(ws_recv(sock))
            if msg.get("id") == 1:
                break

        if msg.get("success"):
            result = msg.get("result")
            if result is None:
                print("{}")
            else:
                print(json.dumps(result, ensure_ascii=False, indent=2))
        else:
            print(json.dumps(msg.get("error", {}), ensure_ascii=False), file=sys.stderr)
            sys.exit(1)
    finally:
        try:
            ws_send(sock, b"", opcode=0x8)
            sock.close()
        except Exception:
            pass


if __name__ == "__main__":
    main()
