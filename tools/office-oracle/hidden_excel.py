"""One owned, hidden Excel for in-process probes (macro calls only; no keyboard, pointer or focus).

Run the calling script through on-private-desktop.ps1 so no window reaches the owner's desktop and the
session root appears in Excel's command line. Launches exactly one Excel and stops only that process.
"""
import subprocess
from contextlib import contextmanager
from pathlib import Path

import pythoncom

from workbook_comparison_session import EXCEL, native_excel, wait_for


@contextmanager
def hidden_excel(root, log=print):
    root = Path(root).resolve()
    root.mkdir(parents=True, exist_ok=True)
    seed = root / 'seed.csv'
    seed.write_text('a\n', encoding='utf-8')
    pythoncom.CoInitialize()
    process = subprocess.Popen([str(EXCEL), '/x', '/automation', '/r', str(seed)],
                               stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    log(f'excel launched pid {process.pid}')
    excel = None
    try:
        excel = wait_for(lambda: native_excel(process.pid), timeout=60)
        excel.Visible = False
        excel.DisplayAlerts = False
        yield excel, process.pid
    finally:
        try:
            if excel is not None:
                excel.DisplayAlerts = False
                excel.Quit()
        except Exception as error:  # the exact owned process is stopped below
            log(f'quit failed: {error}')
        excel = None
        try:
            process.wait(timeout=45)
        except subprocess.TimeoutExpired:
            try:
                process.terminate()
                process.wait(timeout=20)
            except Exception as error:
                log(f'terminate of owned pid {process.pid} failed: {error}')
        log(f'excel stopped rc {process.returncode}')
