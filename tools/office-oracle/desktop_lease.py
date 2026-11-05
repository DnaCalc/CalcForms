"""Exclusive, short desktop use during the owner's overnight permission window."""
from __future__ import annotations

from contextlib import contextmanager
from datetime import datetime, time as wall_time, timedelta
import json
import os
from pathlib import Path
import time
import threading

LOCK = Path('C:/Work/DnaCalc/codex-runs/desktop.lock')
MAX_HOLD_SECONDS = 110


def check_input_time():
    now = datetime.now()
    if not (now.time() >= wall_time(23, 30) or now.time() < wall_time(6, 55)):
        raise RuntimeError('Desktop input is permitted only from 23:30 until 06:55 machine time')


def lease_duration():
    now = datetime.now()
    cutoff = now.replace(hour=6, minute=55, second=0, microsecond=0)
    if now.time() >= wall_time(23, 30):
        cutoff += timedelta(days=1)
    return min(MAX_HOLD_SECONDS, max(0, (cutoff - now).total_seconds()))


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
    serialized = json.dumps(token)
    expired = threading.Event()
    release_lock = threading.Lock()
    timer = None
    def release_owned():
        with release_lock:
            try:
                if LOCK.read_text(encoding='utf-8') == serialized:
                    LOCK.unlink()
            except FileNotFoundError:
                pass
    def expire():
        expired.set()
        release_owned()
    def check_alive():
        check_input_time()
        if expired.is_set() or time.monotonic() - started >= MAX_HOLD_SECONDS:
            raise RuntimeError('Desktop lease expired')
        if not LOCK.exists() or LOCK.read_text(encoding='utf-8') != serialized:
            raise RuntimeError('Desktop lease ownership changed')
    try:
        os.write(handle, serialized.encode())
        os.close(handle)
        handle = None
        # This releases the lock even while the caller is blocked inside COM.
        # Callers must check the returned guard before another UI operation.
        timer = threading.Timer(lease_duration(), expire)
        timer.daemon = True
        timer.start()
        yield check_alive
    finally:
        if timer is not None:
            timer.cancel()
        if handle is not None:
            os.close(handle)
        release_owned()
        if expired.is_set() or time.monotonic() - started >= MAX_HOLD_SECONDS:
            raise RuntimeError('Desktop operation exceeded its lease deadline')
