"""Owned Excel + CalcForms comparison on a private Windows desktop.

Never switches the input desktop, moves a pointer, injects physical input, or
changes Office security/registrations. Append JSON commands (compare, macro,
close) to the session's commands.jsonl. Only owned process handles close.
The fixture is opened read-only; oracle VBA is added only to the in-memory copy.
"""
from __future__ import annotations

import argparse
import ctypes
from ctypes import wintypes
import hashlib
import gc
import json
from pathlib import Path
import subprocess
import sys
import threading
import time
import uuid

import pythoncom
import pywintypes
import win32api
import win32com.client
import win32con
import win32event
import win32file
import win32gui
import win32process
import win32service
import win32ui
from PIL import Image

from workbook_form_session import ORACLE_CODE

ROOT = Path(__file__).resolve().parents[2]
WORKBOOK = ROOT / 'fixtures/workbooks/greeter/workbook-greeter.xlsm'
EXCEL = Path('C:/Program Files/Microsoft Office/Root/Office16/EXCEL.EXE')
PREFIX = 'CALCFORMS_WORKBOOK_OBSERVATION '


def emit(value):
    print(json.dumps(value), flush=True)


def wait_for(read, predicate=bool, timeout=30):
    until = time.monotonic() + timeout
    while time.monotonic() < until:
        value = read()
        if predicate(value):
            return value
        pythoncom.PumpWaitingMessages()
        time.sleep(0.05)
    raise TimeoutError('Timed out waiting for an owned process/window/state')


def windows(pid, title=None, class_name=None):
    matches = []
    def collect(hwnd, _):
        if (win32process.GetWindowThreadProcessId(hwnd)[1] == pid
                and (title is None or win32gui.GetWindowText(hwnd) == title)
                and (class_name is None or win32gui.GetClassName(hwnd) == class_name)):
            matches.append(hwnd)
        return True
    win32gui.EnumWindows(collect, None)
    return matches


def native_excel(pid):
    roots = windows(pid, class_name='XLMAIN')
    children = []
    for root in roots:
        win32gui.EnumChildWindows(root, lambda hwnd, _: children.append(hwnd)
                                 if win32gui.GetClassName(hwnd) == 'EXCEL7' else None, None)
    if not children:
        return None
    class Guid(ctypes.Structure):
        _fields_ = [('a', wintypes.DWORD), ('b', wintypes.WORD), ('c', wintypes.WORD),
                    ('d', ctypes.c_ubyte * 8)]
    iid = Guid.from_buffer_copy(uuid.UUID(str(pythoncom.IID_IDispatch)).bytes_le)
    pointer = ctypes.c_void_p()
    function = ctypes.OleDLL('oleacc').AccessibleObjectFromWindow
    function.argtypes = [wintypes.HWND, wintypes.DWORD, ctypes.POINTER(Guid),
                         ctypes.POINTER(ctypes.c_void_p)]
    function.restype = ctypes.HRESULT
    try:
        function(children[0], 0xfffffff0, ctypes.byref(iid), ctypes.byref(pointer))
        window = win32com.client.Dispatch(pythoncom.ObjectFromAddress(pointer.value, pythoncom.IID_IDispatch))
        excel = window.Application
        if win32process.GetWindowThreadProcessId(excel.Hwnd)[1] != pid:
            raise RuntimeError('NativeOM returned another Excel process')
        return excel
    except (pywintypes.com_error, OSError):
        return None


def launch(arguments, desktop, log):
    attributes = pywintypes.SECURITY_ATTRIBUTES()
    attributes.bInheritHandle = True
    output = win32file.CreateFile(str(log), win32con.GENERIC_WRITE,
                                 win32con.FILE_SHARE_READ | win32con.FILE_SHARE_WRITE,
                                 attributes, win32con.CREATE_ALWAYS, win32con.FILE_ATTRIBUTE_NORMAL, None)
    null = win32file.CreateFile('NUL', win32con.GENERIC_READ, win32con.FILE_SHARE_READ | win32con.FILE_SHARE_WRITE,
                               attributes, win32con.OPEN_EXISTING, 0, None)
    try:
        startup = win32process.STARTUPINFO()
        startup.lpDesktop = desktop
        startup.dwFlags = win32con.STARTF_USESTDHANDLES | win32con.STARTF_USESHOWWINDOW
        startup.wShowWindow = win32con.SW_SHOWNOACTIVATE
        startup.hStdInput = null
        startup.hStdOutput = output
        startup.hStdError = output
        process, thread, pid, _ = win32process.CreateProcess(
            None, subprocess.list2cmdline([str(a) for a in arguments]), None, None, True,
            win32con.CREATE_NO_WINDOW, None, str(ROOT), startup)
        thread.Close()
        return process, pid
    finally:
        output.Close()
        null.Close()


def stop_owned(process, hwnd=None):
    if win32event.WaitForSingleObject(process, 0) == win32con.WAIT_OBJECT_0:
        process.Close()
        return 'exited'
    if (hwnd and win32gui.IsWindow(hwnd)
            and win32process.GetWindowThreadProcessId(hwnd)[1] == win32process.GetProcessId(process)):
        win32gui.PostMessage(hwnd, win32con.WM_CLOSE, 0, 0)
    if win32event.WaitForSingleObject(process, 10000) != win32con.WAIT_OBJECT_0:
        win32api.TerminateProcess(process, 1)
        win32event.WaitForSingleObject(process, 10000)
        result = 'terminated_owned_handle'
    else:
        result = 'closed'
    process.Close()
    return result


def capture(hwnd, path):
    left, top, right, bottom = win32gui.GetWindowRect(hwnd)
    width, height = right - left, bottom - top
    source_handle = win32gui.GetWindowDC(hwnd)
    source = win32ui.CreateDCFromHandle(source_handle)
    target = source.CreateCompatibleDC()
    bitmap = win32ui.CreateBitmap()
    try:
        bitmap.CreateCompatibleBitmap(source, width, height)
        target.SelectObject(bitmap)
        function = ctypes.WinDLL('user32', use_last_error=True).PrintWindow
        function.argtypes = [wintypes.HWND, wintypes.HDC, wintypes.UINT]
        function.restype = wintypes.BOOL
        if not function(hwnd, target.GetSafeHdc(), 2):
            raise OSError('PrintWindow failed')
        image = Image.frombuffer('RGB', (width, height), bitmap.GetBitmapBits(True), 'raw', 'BGRX', 0, 1)
        image.save(path)
        return {'file': path.name, 'size': [width, height], 'distinct_colors': len(image.getcolors(width * height) or []),
                'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
    finally:
        target.DeleteDC()
        win32gui.ReleaseDC(hwnd, source_handle)
        win32gui.DeleteObject(bitmap.GetHandle())


class Session:
    def __init__(self, output, round_launch):
        self.output = output
        self.excel = None
        self.excel_process = None
        self.desktop = None
        self.workbook_hash = hashlib.sha256(WORKBOOK.read_bytes()).hexdigest()
        self.runtime = None
        self.runtime_hwnd = None
        self.round_launch = round_launch

    def open(self):
        self.output.mkdir(parents=True, exist_ok=True)
        ownership = self.output / 'ownership.json'
        if ownership.exists():
            raise ValueError('Use a fresh session directory; never overwrite process ownership')
        self.desktop_name = 'CalcFormsOracle_' + uuid.uuid4().hex[:12]
        self.desktop = win32service.CreateDesktop(self.desktop_name, 0, 0x01ff, None)
        self.desktop.SetThreadDesktop()
        pythoncom.CoInitialize()
        self.excel_process, self.excel_pid = launch(
            [EXCEL, '/x', '/automation', '/r', WORKBOOK], self.desktop_name, self.output / 'excel-stdout.txt')
        self.owner = {'schema': 'calcforms.owned_excel.v1', 'pid': self.excel_pid, 'launches_this_round': self.round_launch,
                      'known_launches_including_round_1': 2 + self.round_launch, 'desktop': self.desktop_name,
                      'switched_input_desktop': False, 'workbook': str(WORKBOOK),
                      'workbook_sha256': self.workbook_hash, 'security_changes': 0}
        ownership.write_text(json.dumps(self.owner, indent=2) + '\n', encoding='utf-8')
        emit({'stage': 'owned_excel', **self.owner})
        self.excel = wait_for(lambda: native_excel(self.excel_pid), timeout=60)
        self.excel.DisplayAlerts = False
        self.book = self.excel.Workbooks.Item(WORKBOOK.name)
        if Path(self.book.FullName).resolve() != WORKBOOK.resolve():
            raise RuntimeError('Owned workbook path differs')
        module = self.book.VBProject.VBComponents.Item('GreeterEntry').CodeModule
        module.AddFromString(ORACLE_CODE)

    def macro(self, name, *arguments):
        return self.excel.Run("'" + self.book.Name + "'!" + name, *arguments)

    def compare(self):
        run = self.output / ('comparison-' + str(len(list(self.output.glob('comparison-*'))) + 1))
        run.mkdir()
        self.macro('ResetGreeter')
        native_hwnd = wait_for(lambda: next(iter(windows(self.excel_pid, 'CalcForms workbook greeter')), None))
        log = run / 'runtime-stdout.txt'
        self.runtime, runtime_pid = launch(
            [ROOT / 'target/debug/calcforms-workbook.exe', WORKBOOK, 'WorkbookGreeter', '--observe-member', 'State'],
            self.desktop_name, log)
        self.runtime_hwnd = wait_for(lambda: next(iter(windows(runtime_pid, 'CalcForms workbook greeter')), None))
        def latest():
            rows = [json.loads(line[len(PREFIX):]) for line in log.read_text(encoding='utf-8').splitlines()
                    if line.startswith(PREFIX)]
            return rows[-1]['state'] if rows else None
        wait_for(latest)
        def post(message, key=0, data=0):
            if win32process.GetWindowThreadProcessId(self.runtime_hwnd)[1] != runtime_pid:
                raise RuntimeError('Runtime HWND no longer belongs to the owned process')
            win32gui.PostMessage(self.runtime_hwnd, message, key, ctypes.c_int32(data).value)
        def click(x, y):
            width = win32gui.GetClientRect(self.runtime_hwnd)[2]
            height = win32gui.GetClientRect(self.runtime_hwnd)[3]
            scale = min(width / 288, height / 130.5)
            xy = round(x * scale) | (round(y * scale) << 16)
            post(win32con.WM_MOUSEMOVE, 0, xy)
            post(win32con.WM_LBUTTONDOWN, 1, xy)
            post(win32con.WM_LBUTTONUP, 0, xy)
        def key(code, text=None):
            scan = win32api.MapVirtualKey(code, 0)
            flags = 1 | (scan << 16) | ((1 << 24) if code == win32con.VK_END else 0)
            post(win32con.WM_KEYDOWN, code, flags)
            if text:
                post(win32con.WM_CHAR, ord(text), 1)
            post(win32con.WM_KEYUP, code, flags | 0xc0000000)
        observations = []
        def record(action):
            expected = self.macro('GreeterState')
            actual = wait_for(latest, lambda value: value == expected)
            time.sleep(0.15)
            observations.append({'action': action, 'excel': expected, 'calcforms': actual,
                                 'equal': actual == expected,
                                 'excel_window': capture(native_hwnd, run / f'{action}-excel.png'),
                                 'calcforms_window': capture(self.runtime_hwnd, run / f'{action}-calcforms.png')})
        try:
            record('initial')
            self.macro('CalcFormsOracleStep', 'greet', '')
            click(220, 45)
            record('greet')
            click(25, 45)
            key(win32con.VK_END)
            for text in ['Ad', 'A', '']:
                self.macro('CalcFormsOracleStep', 'text', text)
                key(win32con.VK_BACK)
                wait_for(latest, lambda value: value == self.macro('GreeterState'))
            for character, text in zip('Lin', ['L', 'Li', 'Lin']):
                self.macro('CalcFormsOracleStep', 'text', text)
                key(ord(character.upper()), character)
                wait_for(latest, lambda value: value == self.macro('GreeterState'))
            record('text')
            self.macro('CalcFormsOracleStep', 'greet', '')
            click(220, 45)
            record('greet-lin')
            self.macro('CalcFormsOracleStep', 'check', '')
            click(20, 75)
            record('check')
            self.macro('CalcFormsOracleStep', 'greet', '')
            click(220, 45)
            record('greet-uppercase')
            result = {**self.owner, 'schema': 'calcforms.workbook_windows_comparison.v1',
                      'excel_version': self.excel.Version, 'excel_build': self.excel.Build,
                      'runtime_pid': runtime_pid, 'runtime': 'CalcVBA VM3',
                      'input': {'excel': 'public Text/Value setters in memory',
                                'calcforms': 'PostMessage to owned HWND on private desktop'},
                      'capture': 'PrintWindow; no foreground activation', 'observations': observations}
            (run / 'comparison.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
            emit({'stage': 'comparison', 'path': str(run / 'comparison.json'), 'states_equal': len(observations)})
        finally:
            result = stop_owned(self.runtime, self.runtime_hwnd)
            self.runtime = None
            self.runtime_hwnd = None
            emit({'stage': 'closed_runtime', 'pid': runtime_pid, 'result': result})

    def close(self):
        if self.runtime:
            stop_owned(self.runtime, self.runtime_hwnd)
        if self.excel is not None:
            try:
                self.excel.DisplayAlerts = False
                self.book.Close(False)
                self.excel.Quit()
            except Exception as error:
                emit({'stage': 'quit_error', 'error': repr(error)})
            finally:
                self.book = None
                self.excel = None
                gc.collect()
        if self.excel_process:
            result = stop_owned(self.excel_process)
            self.owner['closed'] = result
            self.owner['workbook_unchanged'] = self.workbook_hash == hashlib.sha256(WORKBOOK.read_bytes()).hexdigest()
            (self.output / 'ownership.json').write_text(json.dumps(self.owner, indent=2) + '\n', encoding='utf-8')
            emit({'stage': 'closed_owned_excel', 'pid': self.excel_pid, 'result': result})
        pythoncom.CoUninitialize()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--round-launch', type=int, default=1)
    args = parser.parse_args()
    session = Session(args.out.resolve(), args.round_launch)
    errors = []
    def worker():
        try:
            run_session(session)
        except BaseException as error:
            errors.append(error)
            emit({'stage': 'session_error', 'error': repr(error)})
    thread = threading.Thread(target=worker)
    thread.start()
    thread.join()
    if session.desktop:
        try:
            session.desktop.CloseDesktop()
        except pywintypes.error as error:
            emit({'stage': 'desktop_close_note', 'error': str(error)})
    if errors:
        raise errors[0]


def run_session(session):
    try:
        session.open()
        emit({'stage': 'session_ready', 'pid': session.excel_pid})
        commands = session.output / 'commands.jsonl'
        commands.touch(exist_ok=False)
        for line in command_lines(commands):
            try:
                command = json.loads(line)
                if command['command'] == 'close':
                    break
                if command['command'] == 'compare':
                    session.compare()
                elif command['command'] == 'macro':
                    if 'source' in command:
                        component = session.book.VBProject.VBComponents.Add(1)
                        component.Name = command['module']
                        component.CodeModule.AddFromString(command['source'])
                    result = session.macro(command['procedure'], *command.get('arguments', []))
                    emit({'stage': 'macro', 'procedure': command['procedure'], 'result': result})
                else:
                    raise ValueError('Unknown command')
            except Exception as error:
                emit({'stage': 'command_error', 'error': repr(error)})
    finally:
        session.close()


def command_lines(path):
    """A file channel survives tool stdin closing; no desktop input is needed."""
    deadline = time.monotonic() + 4 * 60 * 60
    pending = ''
    with path.open(encoding='utf-8') as stream:
        while time.monotonic() < deadline:
            pending += stream.read()
            while '\n' in pending:
                line, pending = pending.split('\n', 1)
                if line.strip():
                    yield line
            pythoncom.PumpWaitingMessages()
            time.sleep(0.1)


if __name__ == '__main__':
    main()
