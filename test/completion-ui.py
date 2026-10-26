#!/usr/bin/env python3
"""折り返しと既存出力のある端末で、全画面にしない補完と入力行への復帰を検査する。"""
import errno
import fcntl
import os
from pathlib import Path
import pty
import select
import signal
import struct
import tempfile
import termios
import time


with tempfile.TemporaryDirectory(dir=os.environ['ZDOTDIR']) as temp:
    root = Path(temp)
    work = root / 'work'
    work.mkdir()
    for name in ('alpha', 'beta', 'common-one', 'common-two', '空白 あり'):
        (work / name).mkdir()
    zshrc = str(Path(os.environ['ZDOTDIR']) / '.zshrc')
    (root / '.zshrc').write_text('''source "$UI_ZSHRC"
HISTFILE="$ZDOTDIR/history"
precmd_functions=()
preexec_functions=()
PROMPT='UI-CHECK> '
RPROMPT=''
cd -- "$UI_WORK"
print -rl -- OLD-OUTPUT-{1..20}
''')
    pid, master = pty.fork()
    if pid == 0:
        os.environ.update(ZDOTDIR=temp, UI_ZSHRC=zshrc, UI_WORK=str(work))
        os.execvp('zsh', ['zsh', '-d', '-i'])
    fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack('HHHH', 12, 40, 0, 0))
    terminal_output = bytearray()

    def receive(token=None):
        data = bytearray()
        deadline = time.monotonic() + 8
        last = time.monotonic()
        while time.monotonic() < deadline:
            if select.select([master], [], [], 0.05)[0]:
                try:
                    chunk = os.read(master, 65536)
                except OSError as error:
                    if error.errno == errno.EIO:
                        break
                    raise
                if not chunk:
                    break
                data.extend(chunk)
                terminal_output.extend(chunk)
                last = time.monotonic()
                # 入力行の下に候補を配置できるよう、端末からのカーソル位置応答を再現する。
                if b'\x1b[6n' in chunk:
                    os.write(master, b'\x1b[12;1R')
            elif time.monotonic() - last > 0.2 and (token is None or token in data):
                return bytes(data)
        assert token is None or token in data, '期待した端末出力がありません'
        return bytes(data)

    def send(value):
        os.write(master, value)

    try:
        receive(b'UI-CHECK>')
        # 長い入力を折り返し、Tab 一回で全画面にせず候補が出ることを確認する。
        command = b'cd ' + b'./' * 30
        send(command + b'\t')
        menu = receive(b'beta')
        assert b'\x1b[?1049h' not in menu, '補完候補が全画面になっています'
        assert b'alpha' in menu, '最初の Tab で候補が表示されていません'
        send(b'\t\t')
        receive()
        send(b'\x1b')
        receive()
        send(b'\x15print -r -- "__CANCEL__${PWD:t}__"\r')
        receive(b'__CANCEL__work__')

        # 共通部分だけを延ばす最初の Tab は通常動作として保持する。
        send(b'cd comm\t')
        prefix = receive(b'common-')
        assert b'\x1b[?1049h' not in prefix, '共通部分の補完動作が変わっています'
        send(b'\t')
        receive(b'common-one')
        send(b'\x1b')
        receive()
        send(b'\x15')

        # 採用では実行せず、次の Enter で移動できることを確認する。
        for execute in (False, True):
            send(command + b'\t')
            receive(b'beta')
            send(b'beta')
            receive()
            send(b'\r')
            receive()
            if execute:
                send(b'\r')
                receive(b'UI-CHECK>')
            send(b'\x15print -r -- "__RESULT__${PWD:t}__"\r')
            receive(b'__RESULT__beta__' if execute else b'__RESULT__work__')
        assert b'\x1b[?1049h' not in terminal_output, '補完中に全画面へ切り替わっています'
    finally:
        os.kill(pid, signal.SIGTERM)
        os.close(master)
        os.waitpid(pid, 0)
