"""Fill real greeter input observations using only the owned private Excel."""
import argparse
import hashlib
import json
from pathlib import Path

import win32gui

from input_probes import native_source
from layout_corpus import ROOT
from native_accessibility import accessible, location, property_value, post_key, click
from owned_excel import run_owned_excel
from probe_source import validate_probe_source
from workbook_comparison_session import windows, wait_for, WORKBOOK

DIRECTORY = ROOT / 'docs/evidence/W010_complete_msforms_object_model_parity/beads/oxforms-jbjp.122'
CONTROLS = [('Greet', 'CommandButton'), ('InputName', 'TextBox'), ('Loud', 'CheckBox'), ('Output', 'Label'), ('Prompt', 'Label')]
FORM = dict(name='WorkbookGreeter', controls=[dict(name=name, kind=kind) for name, kind in CONTROLS])
INSTRUMENTATION = 'Private mParityEvents As String\nPrivate mParityFailure As String\n' + native_source(FORM)
ENTRY = '''Option Explicit
Public Function Run8GreeterPrepare(ByVal Zoom As Long) As String
    On Error GoTo Failed
    Unload WorkbookGreeter
    Load WorkbookGreeter
    Dim W As Single, H As Single
    W = WorkbookGreeter.InsideWidth
    H = WorkbookGreeter.InsideHeight
    WorkbookGreeter.Zoom = Zoom
    WorkbookGreeter.Width = WorkbookGreeter.Width + W * (Zoom / 100 - 1)
    WorkbookGreeter.Height = WorkbookGreeter.Height + H * (Zoom / 100 - 1)
    WorkbookGreeter.Show vbModeless
    Run8GreeterPrepare = WorkbookGreeter.ActiveControl.Name & ";" & CStr(W) & ";" & CStr(H)
    Exit Function
Failed:
    Run8GreeterPrepare = "CALCFORMS_NATIVE_ERROR:prepare:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function Run8GreeterForm() As Object
    On Error GoTo Failed
    Set Run8GreeterForm = WorkbookGreeter
    Exit Function
Failed:
    Err.Raise Err.Number, "GreeterForm", Err.Description
End Function
Public Function Run8GreeterState() As String
    On Error GoTo Failed
    Run8GreeterState = WorkbookGreeter.State()
    Exit Function
Failed:
    Run8GreeterState = "CALCFORMS_NATIVE_ERROR:state:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function Run8GreeterTrace(ByVal Reset As Boolean) As String
    On Error GoTo Failed
    Run8GreeterTrace = WorkbookGreeter.ParityInputTrace(Reset)
    Exit Function
Failed:
    Run8GreeterTrace = "CALCFORMS_NATIVE_ERROR:trace:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Sub Run8GreeterFinish()
    On Error GoTo Failed
    Unload WorkbookGreeter
    Exit Sub
Failed:
    Err.Raise Err.Number, "GreeterFinish", Err.Description
End Sub
'''


def capture(excel, owner, directory):
    existing = [book for book in excel.Workbooks if Path(book.FullName).resolve() == WORKBOOK.resolve()]
    book = existing[0] if existing else excel.Workbooks.Open(str(WORKBOOK), ReadOnly=True)
    component = book.VBProject.VBComponents.Item('WorkbookGreeter')
    original = component.CodeModule.Lines(1, component.CodeModule.CountOfLines)
    workbook_hash = hashlib.sha256(WORKBOOK.read_bytes()).hexdigest()
    validate_probe_source(INSTRUMENTATION)
    validate_probe_source(ENTRY)
    component.CodeModule.AddFromString(INSTRUMENTATION)
    observer = book.VBProject.VBComponents.Add(1)
    observer.Name = 'Run8GreeterInputObserver'
    observer.CodeModule.AddFromString(ENTRY)
    prefix = "'" + book.Name + "'!"

    def run(member, *args):
        result = excel.Run(prefix + member, *args)
        if isinstance(result, str) and 'CALCFORMS_NATIVE_ERROR:' in result:
            raise ValueError(result)
        return result

    cases = []
    try:
        for zoom in (100, 150):
            initial, width, height = run('Run8GreeterPrepare', zoom).split(';')
            form = run('Run8GreeterForm')
            root = wait_for(lambda: windows(owner['excel_pid'], title=form.Caption))[0]
            origin = win32gui.ClientToScreen(root, (0, 0))
            size = win32gui.GetClientRect(root)[2:]
            scale = size[0] / float(width), size[1] / float(height)
            cycles = []
            for _ in range(2):
                cycle = [str(form.ActiveControl.Name)]
                for _ in range(8):
                    post_key(root, owner['excel_pid'], 9)
                    cycle.append(str(form.ActiveControl.Name))
                    if cycle[-1] == cycle[0]:
                        break
                if cycle[0] != cycle[-1]:
                    raise ValueError('Native greeter Tab cycle did not close')
                cycles.append(cycle)
            if cycles[0] != cycles[1]:
                raise ValueError('Native greeter Tab cycle did not repeat')
            points = []
            for name, kind in CONTROLS:
                current = form.Controls.Item(name)
                acc = accessible(current)
                try:
                    rect = location(acc)
                    role = property_value(acc, 'accRole')
                finally:
                    acc.close()
                x, y, w, h = rect
                point = [round((x + w // 2 - origin[0]) / scale[0]), round((y + h // 2 - origin[1]) / scale[1])]
                screen = [origin[i] + round(point[i] * scale[i]) for i in range(2)]
                if not x <= screen[0] < x + w or not y <= screen[1] < y + h:
                    raise ValueError('Observed accessible point escaped its native control')
                run('Run8GreeterTrace', True)
                click(root, owner['excel_pid'], screen)
                trace = run('Run8GreeterTrace', False)
                keys = {}
                for metric, code in [('enter_default', 13), ('escape_cancel', 27)]:
                    before = run('Run8GreeterState')
                    post_key(root, owner['excel_pid'], code)
                    after = run('Run8GreeterState')
                    before_log, after_log = before.split(';text=', 1)[0], after.split(';text=', 1)[0]
                    if not after_log.startswith(before_log):
                        raise ValueError('Original greeter event trace was reset unexpectedly')
                    keys[metric] = dict(before=before, after=after, events=[event for event in after_log[len(before_log):].split('|') if event])
                points.append(dict(control=name, kind=kind, point_pt=point, native_accessible_rect_px=rect,
                                   screen_point_px=screen, role=role, trace=trace, keys=keys))
            cases.append(dict(zoom=zoom, initial_focus=initial, tab_cycle=cycles[0], repeated_tab_cycle=cycles[1],
                              client_origin_px=list(origin), client_size_px=list(size), points=points))
            run('Run8GreeterFinish')
    finally:
        try:
            component.CodeModule.DeleteLines(1, component.CodeModule.CountOfLines)
            component.CodeModule.AddFromString(original)
            book.VBProject.VBComponents.Remove(observer)
        finally:
            if not existing:
                book.Close(False)
    assert hashlib.sha256(WORKBOOK.read_bytes()).hexdigest() == workbook_hash
    return dict(schema='calcforms.greeter_input.v1', workbook_sha256=workbook_hash, owner=owner,
                instrumentation_sha256=hashlib.sha256(INSTRUMENTATION.encode('utf-8')).hexdigest(),
                observer_sha256=hashlib.sha256(ENTRY.encode('utf-8')).hexdigest(), observations=cases,
                original_handlers_unchanged=True, workbook_unchanged=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner', type=Path, required=True)
    args = parser.parse_args()
    DIRECTORY.mkdir(parents=True, exist_ok=True)
    (DIRECTORY / 'instrumentation.bas').write_text(INSTRUMENTATION, encoding='utf-8', newline='\n')
    (DIRECTORY / 'observer.bas').write_text(ENTRY, encoding='utf-8', newline='\n')
    data = run_owned_excel(args.owner, capture)
    (DIRECTORY / 'native.json').write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(json.dumps(data, indent=2))
