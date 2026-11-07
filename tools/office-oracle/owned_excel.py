"""Run a callback on the existing owned private Excel; never launch or focus one."""
import gc
import json
from pathlib import Path
import re
import threading

import pythoncom
import win32api
import win32con
import win32process
import win32service

from workbook_comparison_session import EXCEL, native_excel, wait_for


def run_owned_excel(owner_path, action):
    owner_path = Path(owner_path).resolve()
    owner = json.loads(owner_path.read_text(encoding='utf-8'))
    if (owner['schema'] != 'calcforms.layout_session.v1' or owner.get('closed')
            or owner['interactive'] or owner['excel_launches'] != 1
            or not re.fullmatch(r'CalcFormsOracle_[0-9a-f]{12}', owner['desktop'])):
        raise ValueError('Requires the live owned private layout session')
    process = win32api.OpenProcess(win32con.PROCESS_QUERY_INFORMATION | win32con.PROCESS_VM_READ,
                                  False, owner['excel_pid'])
    desktop = None
    try:
        created = win32process.GetProcessTimes(process)['CreationTime'].timestamp()
        if (Path(win32process.GetModuleFileNameEx(process, 0)).resolve() != EXCEL.resolve()
                or abs(created - owner_path.stat().st_birthtime) > 10):
            raise RuntimeError('Owned Excel PID/path/creation identity differs')
        desktop = win32service.OpenDesktop(owner['desktop'], 0, False, 0x01ff)
        result, failures = [], []

        def worker():
            excel = None
            initialized = False
            original_desktop = win32service.GetThreadDesktop(win32api.GetCurrentThreadId())
            try:
                desktop.SetThreadDesktop()  # selects this worker's desktop, never the input desktop
                pythoncom.CoInitialize()
                initialized = True
                excel = wait_for(lambda: native_excel(owner['excel_pid']))
                excel.Visible = False
                result.append(action(excel, owner, owner_path.parent))
            except BaseException as error:
                failures.append(error)
            finally:
                if excel is not None:
                    try:
                        excel.Visible = False
                    except BaseException as error:
                        failures.append(error)
                excel = None
                gc.collect()
                if initialized:
                    pythoncom.CoUninitialize()
                try:
                    original_desktop.SetThreadDesktop()
                except BaseException as error:
                    failures.append(error)

        thread = threading.Thread(target=worker)
        thread.start()
        thread.join()
        if failures:
            raise failures[0]
        return result[0]
    finally:
        try:
            if desktop is not None:
                desktop.CloseDesktop()
        finally:
            process.Close()
