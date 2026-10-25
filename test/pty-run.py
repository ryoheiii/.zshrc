#!/usr/bin/env python3
"""TTY 用ガードを通してコマンドを検査する。出力と終了状態を呼び出し元へ返す。"""
import errno
import os
import pty
import select
import signal
import sys
import time

pid, master = pty.fork()
if pid == 0:
    os.execvp(sys.argv[1], sys.argv[1:])

output = bytearray()
deadline = time.monotonic() + 20
try:
    while True:
        if time.monotonic() >= deadline:
            os.kill(pid, signal.SIGKILL)
            raise TimeoutError("対話端末の検査が20秒以内に終了しませんでした")
        if not select.select([master], [], [], 0.1)[0]:
            continue
        try:
            chunk = os.read(master, 65536)
        except OSError as error:
            if error.errno == errno.EIO:
                break
            raise
        if not chunk:
            break
        output.extend(chunk)
finally:
    os.close(master)
    _, status = os.waitpid(pid, 0)

sys.stdout.buffer.write(output.replace(b"\r\n", b"\n"))
sys.exit(os.waitstatus_to_exitcode(status))
