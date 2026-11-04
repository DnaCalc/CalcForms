"""Capture matched Excel/CalcForms client areas at 100% and 150% form zoom.

One Excel process is created and reused until cleanup. The default batch runs
on a private desktop without switching the input desktop. --interactive uses
the owner's desktop, guarded by desktop.lock for every operation that can
activate a window. --serve keeps that owned instance available for real input.
No Office security settings or registrations are modified.
"""
from __future__ import annotations

import argparse
from contextlib import nullcontext
import gc
import hashlib
import json
from pathlib import Path
import threading
import time
import uuid

import pythoncom
import win32gui
import win32process
import win32service
from PIL import Image, ImageChops, ImageStat

from desktop_lease import desktop_lease
from workbook_comparison_session import (EXCEL, PREFIX, ROOT, WORKBOOK, capture,
    command_lines, emit, launch, native_excel, stop_owned, wait_for, windows)
from workbook_form_session import ORACLE_CODE


def geometry(hwnd):
    window = win32gui.GetWindowRect(hwnd)
    client = win32gui.GetClientRect(hwnd)
    origin = win32gui.ClientToScreen(hwnd, (0, 0))
    return {'hwnd': hwnd, 'pid': win32process.GetWindowThreadProcessId(hwnd)[1],
            'window_rect': list(window), 'client_size': [client[2], client[3]],
            'client_offset': [origin[0] - window[0], origin[1] - window[1]],
            'style': win32gui.GetWindowLong(hwnd, -16) & 0xffffffff,
            'extended_style': win32gui.GetWindowLong(hwnd, -20) & 0xffffffff}


def client_capture(hwnd, path, expected_pid):
    details = geometry(hwnd)
    if details['pid'] != expected_pid:
        raise RuntimeError('Capture HWND no longer belongs to the owned process')
    artifact = capture(hwnd, path)
    image = Image.open(path)
    x, y = details['client_offset']
    w, h = details['client_size']
    image = image.crop((x, y, x + w, y + h)).convert('RGB')
    client_path = path.with_name(path.stem + '-client.png')
    image.save(client_path)
    return image, {'window': artifact, 'geometry': details,
                   'client': {'file': client_path.name,
                              'sha256': hashlib.sha256(client_path.read_bytes()).hexdigest()}}


def pixel_compare(excel, runtime, output):
    if excel.size != runtime.size:
        return {'comparable': False, 'reason': 'client sizes differ',
                'excel_size': excel.size, 'calcforms_size': runtime.size}
    diff = ImageChops.difference(excel, runtime)
    diff.save(output)
    histogram = diff.convert('L').histogram()
    nonzero = ImageChops.lighter(diff.getchannel('R'), ImageChops.lighter(diff.getchannel('G'), diff.getchannel('B')))
    unequal = excel.width * excel.height - nonzero.histogram()[0]
    return {'comparable': True, 'pixels': excel.width * excel.height,
            'different_pixels': unequal, 'different_fraction': unequal / (excel.width * excel.height),
            'mean_absolute_rgb': ImageStat.Stat(diff).mean,
            'luminance_error_above_32': sum(histogram[33:]), 'diff': output.name}


class Session:
    def __init__(self, args):
        self.args = args
        self.output = args.out.resolve()
        self.output.mkdir(parents=True, exist_ok=False)
        self.excel = self.book = self.excel_process = self.runtime = self.desktop = None
        self.runtime_hwnd = None
        self.workbook_hash = hashlib.sha256(WORKBOOK.read_bytes()).hexdigest()
        self.owner = {'schema': 'calcforms.layout_session.v1', 'excel_launches': 0,
                      'interactive': args.interactive, 'security_changes': 0,
                      'input_desktop_switched': False, 'workbook_sha256': self.workbook_hash}

    def lease(self, operation):
        return desktop_lease(operation) if self.args.interactive else nullcontext()

    def save_owner(self):
        (self.output / 'ownership.json').write_text(json.dumps(self.owner, indent=2) + '\n')

    def open(self):
        if self.args.interactive:
            self.desktop_name = 'winsta0\\default'
        else:
            self.desktop_name = 'CalcFormsOracle_' + uuid.uuid4().hex[:12]
            self.desktop = win32service.CreateDesktop(self.desktop_name, 0, 0x01ff, None)
            self.desktop.SetThreadDesktop()
        pythoncom.CoInitialize()
        with self.lease('launch owned Excel'):
            self.excel_process, self.excel_pid = launch(
                [EXCEL, '/x', '/automation', '/r', WORKBOOK], self.desktop_name,
                self.output / 'excel-stdout.txt')
            self.owner.update(excel_launches=1, excel_pid=self.excel_pid, desktop=self.desktop_name)
            self.save_owner()
            self.excel = wait_for(lambda: native_excel(self.excel_pid), timeout=45)
            self.excel.DisplayAlerts = False
            self.book = self.excel.Workbooks.Item(WORKBOOK.name)
            if Path(self.book.FullName).resolve() != WORKBOOK.resolve():
                raise RuntimeError('Owned workbook path differs')
            self.book.VBProject.VBComponents.Item('GreeterEntry').CodeModule.AddFromString(ORACLE_CODE)
            module = self.book.VBProject.VBComponents.Add(1)
            module.Name = 'LayoutOracle'
            module.CodeModule.AddFromString('''Option Explicit
Public Sub LayoutShow(ByVal Zoom As Long)
    Unload WorkbookGreeter
    Load WorkbookGreeter
    Dim W As Single, H As Single
    W = WorkbookGreeter.InsideWidth
    H = WorkbookGreeter.InsideHeight
    WorkbookGreeter.Zoom = Zoom
    WorkbookGreeter.Width = WorkbookGreeter.Width + W * (Zoom / 100 - 1)
    WorkbookGreeter.Height = WorkbookGreeter.Height + H * (Zoom / 100 - 1)
    WorkbookGreeter.Show vbModeless
End Sub
Public Function LayoutFacts() As String
    Dim C As Object, S As String
    S = CStr(WorkbookGreeter.InsideWidth) & ";" & CStr(WorkbookGreeter.InsideHeight) & ";" & CStr(WorkbookGreeter.Zoom)
    For Each C In WorkbookGreeter.Controls
        S = S & vbLf & C.Name & ";" & CStr(C.Left) & ";" & CStr(C.Top) & ";" & CStr(C.Width) & ";" & CStr(C.Height) & ";" & C.Font.Name & ";" & CStr(C.Font.Size) & ";" & CStr(C.TabIndex)
    Next
    LayoutFacts = S
End Function
''')
        emit({'stage': 'ready', **self.owner})

    def macro(self, name, *args):
        return self.excel.Run("'" + self.book.Name + "'!" + name, *args)

    def start_pair(self, zoom):
        if type(zoom) is not int or not 50 <= zoom <= 200:
            raise ValueError('zoom must be an integer between 50 and 200')
        self.stop_runtime()
        self.zoom = zoom
        with self.lease('show greeter pair'):
            self.macro('LayoutShow', zoom)
            self.native_hwnd = wait_for(lambda: next(iter(windows(self.excel_pid, 'CalcForms workbook greeter')), None))
            self.runtime_log = self.output / f'runtime-{time.time_ns()}.txt'
            self.runtime, self.runtime_pid = launch(
                [ROOT / 'target/debug/calcforms-workbook.exe', WORKBOOK, 'WorkbookGreeter',
                 '--observe-member', 'State', '--scale', str(zoom / 100)],
                self.desktop_name, self.runtime_log)
            self.runtime_hwnd = wait_for(lambda: next(iter(windows(self.runtime_pid, 'CalcForms workbook greeter')), None))
            wait_for(self.runtime_state)
        time.sleep(0.3)
        emit({'stage': 'pair', 'zoom': zoom, 'excel_hwnd': self.native_hwnd,
              'calcforms_hwnd': self.runtime_hwnd, 'runtime_pid': self.runtime_pid})

    def runtime_state(self):
        rows = [json.loads(line[len(PREFIX):]) for line in self.runtime_log.read_text(encoding='utf-8').splitlines(keepends=True)
                if line.startswith(PREFIX) and line.endswith('\n')]
        return rows[-1]['state'] if rows else None

    def snapshot(self, label):
        if not label.replace('-', '').replace('_', '').isalnum():
            raise ValueError('Use a simple capture label')
        directory = self.output / (label + '-' + str(self.zoom))
        directory.mkdir(exist_ok=False)
        native, native_info = client_capture(self.native_hwnd, directory / 'excel.png', self.excel_pid)
        runtime, runtime_info = client_capture(self.runtime_hwnd, directory / 'calcforms.png', self.runtime_pid)
        data = {'schema': 'calcforms.layout_comparison.v1', 'zoom': self.zoom,
                'excel_version': self.excel.Version, 'excel_build': self.excel.Build,
                'excel': native_info, 'calcforms': runtime_info,
                'excel_facts': self.macro('LayoutFacts'),
                'excel_state': self.macro('GreeterState'), 'calcforms_state': self.runtime_state(),
                'pixels': pixel_compare(native, runtime, directory / 'difference.png'),
                'capture': 'PrintWindow; client crop from GetClientRect/ClientToScreen',
                'input': 'none; initial handlers only' if label == 'initial' else 'see session input log'}
        (directory / 'comparison.json').write_text(json.dumps(data, indent=2) + '\n')
        emit({'stage': 'snapshot', 'path': str(directory / 'comparison.json'), 'pixels': data['pixels']})

    def stop_runtime(self):
        if self.runtime:
            with self.lease('close owned CalcForms'):
                result = stop_owned(self.runtime, self.runtime_hwnd)
            emit({'stage': 'runtime_closed', 'pid': self.runtime_pid, 'result': result})
            self.runtime = self.runtime_hwnd = None

    def close(self):
        failures = []
        try:
            self.stop_runtime()
        except Exception as error:
            failures.append(repr(error))
        try:
            if self.excel is not None:
                with self.lease('close owned Excel'):
                    if self.book is not None:
                        self.book.Close(False)
                    self.excel.Quit()
        except Exception as error:
            failures.append(repr(error))
        finally:
            self.book = self.excel = None
            gc.collect()
        # Cleanup still reaches retained owned process handles if COM fails or
        # another agent holds the desktop. No foreground/input call is needed.
        if self.runtime:
            self.owner['runtime_cleanup'] = stop_owned(self.runtime)
            self.runtime = None
        if self.excel_process:
            self.owner['closed'] = stop_owned(self.excel_process)
            self.excel_process = None
        self.owner['workbook_unchanged'] = self.workbook_hash == hashlib.sha256(WORKBOOK.read_bytes()).hexdigest()
        self.owner['cleanup_notes'] = failures
        self.save_owner()
        emit({'stage': 'closed', **self.owner})
        pythoncom.CoUninitialize()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--interactive', action='store_true')
    parser.add_argument('--serve', action='store_true')
    parser.add_argument('--scales', type=int, nargs='+', default=[100, 150])
    args = parser.parse_args()
    if any(not 50 <= zoom <= 200 for zoom in args.scales):
        parser.error('scales must be between 50 and 200 percent')
    session = Session(args)
    errors = []
    def worker():
        try:
            session.open()
            if args.serve:
                channel = session.output / 'commands.jsonl'
                channel.touch(exist_ok=False)
                for line in command_lines(channel):
                    command = json.loads(line)
                    try:
                        if command['command'] == 'close':
                            break
                        if command['command'] == 'pair':
                            session.start_pair(command.get('zoom', 100))
                        elif command['command'] == 'snapshot':
                            session.snapshot(command['label'])
                        elif command['command'] == 'macro':
                            with session.lease('owned Excel macro'):
                                emit({'stage': 'macro', 'result': session.macro(command['name'], *command.get('args', []))})
                        else:
                            raise ValueError('Unknown command')
                    except Exception as error:
                        emit({'stage': 'command_error', 'error': repr(error)})
            else:
                for zoom in args.scales:
                    session.start_pair(zoom)
                    session.snapshot('initial')
        except BaseException as error:
            errors.append(error)
            emit({'stage': 'error', 'error': repr(error)})
        finally:
            try:
                session.close()
            except BaseException as error:
                errors.append(error)
                emit({'stage': 'cleanup_error', 'error': repr(error)})
    thread = threading.Thread(target=worker)
    thread.start()
    thread.join()
    if session.desktop:
        session.desktop.CloseDesktop()
    if errors:
        raise errors[0]


if __name__ == '__main__':
    main()
