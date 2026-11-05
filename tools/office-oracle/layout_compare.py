"""Capture matched Excel/CalcForms client areas at 100% and 150% form zoom.

One Excel process is created and reused until cleanup. The default batch runs
on a private desktop without switching the input desktop. --interactive uses
the owner's desktop, guarded by desktop.lock for every operation that can
activate a window. --serve keeps that owned instance available for real input.
No Office security settings or registrations are modified.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager, nullcontext
import gc
import hashlib
import json
from pathlib import Path
import shutil
import threading
import time
import uuid

import pythoncom
import win32api
import win32con
import win32gui
import win32process
import win32service
from PIL import Image, ImageChops, ImageStat

from desktop_lease import desktop_lease
from layout_corpus import author_excel, load_corpus
from probe_source import validate_probe_source
from layout_measurements import measure
from layout_pixels import rank_controls
from capture_qualification import choose_capture
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
    win32gui.RedrawWindow(hwnd, None, None, win32con.RDW_INVALIDATE | win32con.RDW_ERASE
                          | win32con.RDW_FRAME | win32con.RDW_ALLCHILDREN | win32con.RDW_UPDATENOW)
    artifact = capture(hwnd, path)
    image = Image.open(path)
    # MSForms' F3 child servers can be absent from the parent's WM_PRINT result
    # while fully populated on screen. Capture each visible owned child itself,
    # in back-to-front sibling order, clipping descendants to their parent.
    children = []
    def composite(parent, canvas, parent_rect):
        siblings = []
        child = win32gui.GetWindow(parent, win32con.GW_CHILD)
        while child:
            siblings.append(child)
            child = win32gui.GetWindow(child, win32con.GW_HWNDNEXT)
        for child in reversed(siblings):
            if not win32gui.IsWindowVisible(child):
                continue
            if win32process.GetWindowThreadProcessId(child)[1] != expected_pid:
                raise RuntimeError('Child capture belongs to a different process')
            rect = win32gui.GetWindowRect(child)
            if rect[2] <= rect[0] or rect[3] <= rect[1]:
                continue
            child_path = path.with_name(path.stem + f'-child-{len(children)}.png')
            info = capture(child, child_path)
            children.append({'hwnd': child, 'class': win32gui.GetClassName(child),
                             'window_rect': list(rect), **info})
            child_image = Image.open(child_path).convert('RGB')
            composite(child, child_image, rect)
            # A child cannot paint outside the parent's client area.
            client = win32gui.GetClientRect(parent)
            origin = win32gui.ClientToScreen(parent, (0, 0))
            clip = (max(rect[0], origin[0]), max(rect[1], origin[1]),
                    min(rect[2], origin[0] + client[2]), min(rect[3], origin[1] + client[3]))
            if clip[2] > clip[0] and clip[3] > clip[1]:
                crop = child_image.crop((clip[0] - rect[0], clip[1] - rect[1],
                                         clip[2] - rect[0], clip[3] - rect[1]))
                canvas.paste(crop, (clip[0] - parent_rect[0], clip[1] - parent_rect[1]))
    composite(hwnd, image, details['window_rect'])
    composite_path = path.with_name(path.stem + '-composited.png')
    image.save(composite_path)
    x, y = details['client_offset']
    w, h = details['client_size']
    image = image.crop((x, y, x + w, y + h)).convert('RGB')
    client_path = path.with_name(path.stem + '-client.png')
    image.save(client_path)
    return image, {'window': artifact, 'children': children,
                   'composite': {'file': composite_path.name,
                                 'sha256': hashlib.sha256(composite_path.read_bytes()).hexdigest()},
                   'geometry': details,
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
        self.corpus_book = None
        self.selected_form = None
        self.active_lease_guard = None
        self.corpus = load_corpus()
        self.comparisons = []
        self.workbook_hash = hashlib.sha256(WORKBOOK.read_bytes()).hexdigest()
        self.owner = {'schema': 'calcforms.layout_session.v1', 'excel_launches': 0,
                      'interactive': args.interactive, 'security_changes': 0,
                      'input_desktop_switched': False, 'workbook_sha256': self.workbook_hash}
        self.owner['corpus_sha256'] = hashlib.sha256((ROOT / 'fixtures/office-oracle/excel-msforms/layout-corpus.v1.json').read_bytes()).hexdigest()

    @contextmanager
    def lease(self, operation):
        if not self.args.interactive:
            with nullcontext():
                yield
            return
        deadline = time.monotonic() + 180
        announced = False
        while True:
            lease = desktop_lease(operation)
            try:
                guard = lease.__enter__()
                break
            except RuntimeError as error:
                if 'Desktop is in use' not in str(error) or time.monotonic() >= deadline:
                    raise
                if not announced:
                    emit({'stage': 'waiting_for_desktop', 'operation': operation})
                    announced = True
                pythoncom.PumpWaitingMessages()
                time.sleep(0.2)
        try:
            self.active_lease_guard = guard
            yield
        finally:
            self.active_lease_guard = None
            lease.__exit__(None, None, None)

    def check_lease(self):
        if self.args.interactive:
            if self.active_lease_guard is None:
                raise RuntimeError('Desktop operation requires an active lease')
            self.active_lease_guard()

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
        with self.lease('open owned Excel session'):
            if self.args.attach_owned:
                source = self.args.attach_owned.resolve()
                proof = json.loads(source.read_text())
                if (proof['schema'] != 'calcforms.layout_session.v1' or not proof['interactive']
                        or proof.get('closed') or proof['workbook_sha256'] != self.workbook_hash):
                    raise RuntimeError('Not a live owned layout session')
                process = win32api.OpenProcess(win32con.PROCESS_QUERY_INFORMATION | win32con.PROCESS_VM_READ
                                               | win32con.PROCESS_TERMINATE | win32con.SYNCHRONIZE, False, proof['excel_pid'])
                try:
                    created = win32process.GetProcessTimes(process)['CreationTime'].timestamp()
                    if (Path(win32process.GetModuleFileNameEx(process, 0)).resolve() != EXCEL.resolve()
                            or abs(created - source.stat().st_birthtime) > 10):
                        raise RuntimeError('Owned Excel PID/path/creation identity differs')
                except BaseException:
                    process.Close()
                    raise
                self.excel_process, self.excel_pid = process, proof['excel_pid']
                self.owner.update(excel_launches=proof['excel_launches'], excel_launches_by_this_session=0,
                                  source_owner=str(source), process_created=created)
            else:
                self.check_lease()
                self.excel_process, self.excel_pid = launch(
                    [EXCEL, '/x', '/automation', '/r', WORKBOOK], self.desktop_name,
                    self.output / 'excel-stdout.txt')
                self.owner.update(excel_launches=1, excel_launches_by_this_session=1)
            self.owner.update(excel_pid=self.excel_pid, desktop=self.desktop_name)
            self.save_owner()
            self.excel = wait_for(lambda: native_excel(self.excel_pid), timeout=45)
            self.excel.DisplayAlerts = False
            self.book = self.excel.Workbooks.Item(WORKBOOK.name)
            self.greeter_book = self.book
            # A previous interrupted capture may have left its authored book in
            # this same owned Excel. Close only our known capture-root artifact.
            for index in range(self.excel.Workbooks.Count, 0, -1):
                candidate = self.excel.Workbooks.Item(index)
                if candidate.Name == 'layout-corpus.xlsm':
                    path = Path(candidate.FullName).resolve()
                    capture_root = Path('C:/Work/DnaCalc/codex-runs/forms-captures').resolve()
                    if not path.is_relative_to(capture_root):
                        raise RuntimeError('A different workbook already uses the authored corpus name')
                    candidate.Close(False)
            if Path(self.book.FullName).resolve() != WORKBOOK.resolve():
                raise RuntimeError('Owned workbook path differs')
            entry = self.book.VBProject.VBComponents.Item('GreeterEntry').CodeModule
            if 'CalcFormsOracleStep' not in entry.Lines(1, entry.CountOfLines):
                entry.AddFromString(ORACLE_CODE)
            names = [self.book.VBProject.VBComponents.Item(i).Name
                     for i in range(1, self.book.VBProject.VBComponents.Count + 1)]
            if 'LayoutOracle' in names:
                module = self.book.VBProject.VBComponents.Item('LayoutOracle')
                module.CodeModule.DeleteLines(1, module.CodeModule.CountOfLines)
            else:
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
        self.check_lease()
        prefix = "'" + self.book.Name + "'!"
        result = self.excel.Run(prefix + name, *args)
        if isinstance(result, str) and result.startswith('CALCFORMS_NATIVE_ERROR:'):
            raise RuntimeError(result)
        return result

    def start_pair(self, zoom, form_name='greeter'):
        if type(zoom) is not int or not 50 <= zoom <= 200:
            raise ValueError('zoom must be an integer between 50 and 200')
        self.stop_runtime()
        self.zoom = zoom
        with self.lease('show layout pair'):
            if self.selected_form == 'greeter':
                self.macro('HideGreeter')
            elif self.selected_form:
                self.macro('LayoutHide')
            self.selected_form = form_name
            self.scene_path = self.output / f'scene-{time.time_ns()}.json'
            if form_name == 'greeter':
                self.book = self.greeter_book
                self.macro('LayoutShow', zoom)
                caption = 'CalcForms workbook greeter'
                binary = ROOT / 'target/debug/calcforms-workbook.exe'
                arguments = [WORKBOOK, 'WorkbookGreeter', '--observe-member', 'State',
                             '--scale', str(zoom / 100), '--dump-scene', self.scene_path]
            else:
                definition = next((f for f in self.corpus['forms'] if f['name'] == form_name), None)
                if definition is None:
                    raise ValueError('Unknown authored form')
                if self.corpus_book is None:
                    directory = self.output / 'corpus'
                    directory.mkdir()
                    self.corpus_book = author_excel(self.excel, directory, self.corpus)
                self.book = self.corpus_book
                self.macro('LayoutShow', form_name, definition['width'], definition['height'], zoom)
                caption = definition['caption']
                binary = ROOT / 'target/debug/examples/layout_probe.exe'
                arguments = [self.output / 'corpus' / (form_name + '.cls'), form_name,
                             definition['width'], definition['height'], zoom / 100, self.scene_path, caption, self.corpus['font']]
            self.native_hwnd = wait_for(lambda: next(iter(windows(self.excel_pid, caption)), None))
            self.runtime_log = self.output / f'runtime-{time.time_ns()}.txt'
            # A versioned copy keeps the running image from locking Cargo's output.
            self.runtime_digest = hashlib.sha256(binary.read_bytes()).hexdigest()
            copied = self.output / 'bin' / self.runtime_digest[:16] / binary.name
            copied.parent.mkdir(parents=True, exist_ok=True)
            if not copied.exists():
                shutil.copyfile(binary, copied)
            self.check_lease()
            self.runtime, self.runtime_pid = launch(
                [copied, *arguments],
                self.desktop_name, self.runtime_log)
            def runtime_window():
                if win32process.GetExitCodeProcess(self.runtime) != 259:
                    raise RuntimeError(self.runtime_log.read_text(encoding='utf-8')[-6000:])
                return next(iter(windows(self.runtime_pid, caption)), None)
            self.runtime_hwnd = wait_for(runtime_window)
            wait_for(self.runtime_state)
        time.sleep(0.3)
        emit({'stage': 'pair', 'form': form_name, 'zoom': zoom, 'excel_hwnd': self.native_hwnd,
              'excel_root_hwnd': self.excel.Hwnd, 'calcforms_hwnd': self.runtime_hwnd, 'runtime_pid': self.runtime_pid})

    def runtime_state(self):
        rows = [json.loads(line[len(PREFIX):]) for line in self.runtime_log.read_text(encoding='utf-8').splitlines(keepends=True)
                if line.startswith(PREFIX) and line.endswith('\n')]
        return rows[-1]['state'] if rows else None

    def snapshot(self, label):
        if not label.replace('-', '').replace('_', '').isalnum():
            raise ValueError('Use a simple capture label')
        directory = self.output / (self.selected_form + '-' + label + '-' + str(self.zoom))
        directory.mkdir(exist_ok=False)
        with self.lease('read owned layout observations'):
            facts = self.macro('LayoutFacts')
            state = self.macro('GreeterState') if self.selected_form == 'greeter' else None
            paint_facts = self.macro('LayoutPaintFacts') if self.selected_form != 'greeter' else ''
        native, native_info = client_capture(self.native_hwnd, directory / 'excel.png', self.excel_pid)
        runtime, runtime_info = client_capture(self.runtime_hwnd, directory / 'calcforms.png', self.runtime_pid)
        probes = []
        if paint_facts:
            definition = next(f for f in self.corpus['forms'] if f['name'] == self.selected_form)
            scale_x = native.width / definition['width']
            scale_y = native.height / definition['height']
            for line in paint_facts.splitlines():
                control, color, x, y = line.split(';')
                color = int(color) & 0xffffffff
                resolved = win32api.GetSysColor(color & 0xff) if color & 0x80000000 else color
                probes.append({'control': control, 'ole_color': color,
                               'kind': next(c['kind'] for c in definition['controls'] if c['name'] == control),
                               'point': [float(x), float(y)],
                               'pixel': [round(float(x) * scale_x), round(float(y) * scale_y)],
                               'expected_rgb': [resolved & 255, (resolved >> 8) & 255, (resolved >> 16) & 255]})
        parent = Image.open(directory / 'excel.png').convert('RGB')
        x, y = native_info['geometry']['client_offset']
        parent = parent.crop((x, y, x + native.width, y + native.height))
        qualification = choose_capture(native, parent, probes)
        if qualification['selected'] == 'parent':
            native = parent
            native.save(directory / 'excel-client.png')
            native_info['client']['sha256'] = hashlib.sha256((directory / 'excel-client.png').read_bytes()).hexdigest()
        pixels = pixel_compare(native, runtime, directory / 'difference.png') if qualification['verified'] else {
            'comparable': False, 'reason': 'Native container background disagrees with its live BackColor; capture unverified'}
        data = {'schema': 'calcforms.layout_comparison.v2', 'form': self.selected_form, 'zoom': self.zoom,
                'excel_version': self.excel.Version, 'excel_build': self.excel.Build,
                'excel': native_info, 'calcforms': runtime_info,
                'excel_facts': facts,
                'excel_state': state,
                'calcforms_observation': self.runtime_state(), 'scene_file': self.scene_path.name,
                'runtime_sha256': self.runtime_digest, 'corpus_sha256': self.owner['corpus_sha256'],
                'pixels': pixels, 'native_paint_facts': paint_facts,
                'native_capture_validation': qualification,
                'capture': 'PrintWindow parent and visible owned children; client crop from GetClientRect/ClientToScreen',
                'input': 'none; initial handlers only' if label == 'initial' else 'see session input log'}
        data['measurements'] = measure(data, json.loads(self.scene_path.read_text(encoding='utf-8')))
        data['control_pixels'] = rank_controls(data, native, runtime)
        (directory / 'comparison.json').write_text(json.dumps(data, indent=2) + '\n')
        self.comparisons.append({'form': self.selected_form, 'zoom': self.zoom,
                                 'comparison': str((directory / 'comparison.json').relative_to(self.output)),
                                 'pixels': data['pixels'], 'max_abs_delta_pt': data['measurements']['max_abs_delta_pt'],
                                 'largest_control_regions': data['control_pixels']['ranked'][:3],
                                 'client_size_equal': data['measurements']['client_size_equal']})
        self.save_summary()
        emit({'stage': 'snapshot', 'path': str(directory / 'comparison.json'), 'pixels': data['pixels']})

    def save_summary(self):
        (self.output / 'summary.json').write_text(json.dumps(
            {'schema': 'calcforms.layout_summary.v1', 'ownership': self.owner,
             'comparisons': self.comparisons, 'pixel_parity_claimed': False}, indent=2) + '\n')

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
                    if self.corpus_book is not None:
                        self.check_lease()
                        self.corpus_book.Close(False)
                        self.corpus_book = None
                    if not self.args.keep_excel:
                        self.check_lease()
                        self.greeter_book.Close(False)
                        self.check_lease()
                        self.excel.Quit()
        except Exception as error:
            failures.append(repr(error))
        finally:
            self.book = self.excel = None
            self.greeter_book = None
            gc.collect()
        # Cleanup still reaches retained owned process handles if COM fails or
        # another agent holds the desktop. No foreground/input call is needed.
        if self.runtime:
            self.owner['runtime_cleanup'] = stop_owned(self.runtime)
            self.runtime = None
        if self.excel_process:
            if self.args.keep_excel:
                self.excel_process.Close()
                self.owner['closed'] = 'retained_by_original_session'
            else:
                self.owner['closed'] = stop_owned(self.excel_process)
            self.excel_process = None
        self.owner['workbook_unchanged'] = self.workbook_hash == hashlib.sha256(WORKBOOK.read_bytes()).hexdigest()
        self.owner['cleanup_notes'] = failures
        self.save_owner()
        self.save_summary()
        emit({'stage': 'closed', **self.owner})
        pythoncom.CoUninitialize()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--interactive', action='store_true')
    parser.add_argument('--serve', action='store_true')
    parser.add_argument('--attach-owned', type=Path, help='reuse a live ownership.json created by this tool')
    parser.add_argument('--keep-excel', action='store_true', help='leave the attached Excel under its original owner')
    parser.add_argument('--forms', nargs='+', help='greeter or authored corpus form names; default is all forms')
    parser.add_argument('--scales', type=int, nargs='+', default=[100, 150])
    args = parser.parse_args()
    if args.attach_owned and not args.interactive:
        parser.error('attaching to the shared desktop requires --interactive')
    if args.keep_excel and not args.attach_owned:
        parser.error('--keep-excel requires --attach-owned')
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
                            session.start_pair(command.get('zoom', 100), command.get('form', 'greeter'))
                        elif command['command'] == 'snapshot':
                            session.snapshot(command['label'])
                        elif command['command'] == 'macro':
                            with session.lease('owned Excel macro'):
                                if 'source' in command:
                                    validate_probe_source(command['source'])
                                    component = session.book.VBProject.VBComponents.Add(1)
                                    component.Name = command['module']
                                    component.CodeModule.AddFromString(command['source'])
                                emit({'stage': 'macro', 'result': session.macro(command['name'], *command.get('args', []))})
                        else:
                            raise ValueError('Unknown command')
                    except Exception as error:
                        emit({'stage': 'command_error', 'error': repr(error)})
            else:
                for form in args.forms or ['greeter', *[f['name'] for f in session.corpus['forms']]]:
                    for zoom in args.scales:
                        session.start_pair(zoom, form)
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
