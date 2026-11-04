"""Exclusive, short desktop use during the owner's overnight permission window."""
from __future__ import annotations

from contextlib import contextmanager
from datetime import datetime, time as wall_time
import json
import os
from pathlib import Path
import time

LOCK = Path('C:/Work/DnaCalc/codex-runs/desktop.lock')


def check_input_time():
    now = datetime.now()
    if not (now.time() >= wall_time(23, 30) or now.time() < wall_time(6, 55)):
        raise RuntimeError('Desktop input is permitted only from 23:30 until 06:55 machine time')


@contextmanager
def desktop_lease(operation):
    """Fail on a live lock; reclaim only a lock older than five minutes."""
    check_input_time()
    try:
        handle = os.open(LOCK, os.O_WRONLY | os.O_CREAT | os.O_EXCL)
    except FileExistsError:
        if time.time() - LOCK.stat().st_mtime <= 300:
            raise RuntimeError('Desktop is in use by another agent') from None
        LOCK.unlink()
        handle = os.open(LOCK, os.O_WRONLY | os.O_CREAT | os.O_EXCL)
    token = {'owner': 'CalcForms', 'pid': os.getpid(), 'operation': operation,
             'created': datetime.now().isoformat()}
    started = time.monotonic()
    try:
        os.write(handle, json.dumps(token).encode())
        os.close(handle)
        handle = None
        yield
    finally:
        if handle is not None:
            os.close(handle)
        # Do not delete a replacement lock if this operation was interrupted.
        if LOCK.exists() and LOCK.read_text(encoding='utf-8') == json.dumps(token):
            LOCK.unlink()
        if time.monotonic() - started >= 120:
            raise RuntimeError('Desktop operation exceeded the two-minute lease')
