"""Threaded static server for previewing web/. One-off helper."""
import functools
import http.server
import socketserver
import sys

port = int(sys.argv[1]) if len(sys.argv) > 1 else 8777
root = sys.argv[2] if len(sys.argv) > 2 else "web"


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=root)
with Server(("127.0.0.1", port), handler) as httpd:
    print("serving", root, "on", port, flush=True)
    httpd.serve_forever()
