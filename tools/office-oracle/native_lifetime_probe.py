"""Observe original greeter default/explicit instances in the existing owned Excel."""
import argparse
import hashlib
import json
from pathlib import Path

import pythoncom
import win32api
import win32con
import win32process

from desktop_lease import desktop_lease
from probe_source import validate_probe_source
from workbook_comparison_session import EXCEL, WORKBOOK, native_excel


SOURCE = '''Option Explicit
Public Function Run4Lifetime() As String
    On Error GoTo Failed
    Dim Held As WorkbookGreeter, Again As WorkbookGreeter
    Dim Fresh As WorkbookGreeter, ExplicitForm As WorkbookGreeter
    Dim S As String
    Unload WorkbookGreeter
    Load WorkbookGreeter
    Set Held = WorkbookGreeter
    Set Again = WorkbookGreeter
    S = "loaded;same=" & CStr(Held Is Again) & ";" & Held.State() & vbLf
    WorkbookGreeter.Show vbModeless
    WorkbookGreeter.InputName.Text = "Lifetime"
    WorkbookGreeter.Hide
    S = S & "hidden;visible=" & CStr(WorkbookGreeter.Visible) & ";" & WorkbookGreeter.State() & vbLf
    WorkbookGreeter.Show vbModeless
    S = S & "reshown;same=" & CStr(Held Is WorkbookGreeter) & ";visible=" & CStr(WorkbookGreeter.Visible) & ";" & WorkbookGreeter.State() & vbLf
    Unload WorkbookGreeter
    S = S & "unloaded-held;same=" & CStr(Held Is Again) & vbLf
    Load WorkbookGreeter
    Set Fresh = WorkbookGreeter
    S = S & "default-after-unload;same=" & CStr(Held Is Fresh) & ";" & Fresh.State() & vbLf
    Set ExplicitForm = New WorkbookGreeter
    Load ExplicitForm
    S = S & "explicit-new;same-default=" & CStr(ExplicitForm Is Fresh) & ";" & ExplicitForm.State() & vbLf
    ExplicitForm.InputName.Text = "Explicit"
    S = S & "default-after-explicit;" & Fresh.State() & vbLf
    S = S & "explicit-edited;" & ExplicitForm.State() & vbLf
    Unload ExplicitForm
    Unload Fresh
    Set ExplicitForm = Nothing
    Set Held = Nothing
    Set Again = Nothing
    Set Fresh = Nothing
    Unload WorkbookGreeter
    Run4Lifetime = S
    Exit Function
Failed:
    Run4Lifetime = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description & vbLf & S
    On Error Resume Next
    Unload ExplicitForm
    Unload Held
    Unload Fresh
    Unload WorkbookGreeter
End Function
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner', type=Path, required=True)
    args = parser.parse_args()
    path = args.owner.resolve()
    owner = json.loads(path.read_text())
    if owner.get('closed') or not owner['interactive'] or owner['schema'] != 'calcforms.layout_session.v1':
        raise RuntimeError('A live original owned interactive session is required')
    output = path.parent / 'lifetime-probe-safe'
    if not output.is_relative_to(Path('C:/Work/DnaCalc/codex-runs/forms-captures').resolve()):
        raise RuntimeError('Output must stay inside the capture root')
    output.mkdir(exist_ok=False)
    (output / 'observer.bas').write_text(SOURCE, encoding='utf-8', newline='\n')
    process = win32api.OpenProcess(win32con.PROCESS_QUERY_INFORMATION | win32con.PROCESS_VM_READ, False, owner['excel_pid'])
    try:
        created = win32process.GetProcessTimes(process)['CreationTime'].timestamp()
        if Path(win32process.GetModuleFileNameEx(process, 0)).resolve() != EXCEL.resolve() or abs(created - path.stat().st_birthtime) > 10:
            raise RuntimeError('Owned process identity changed')
    finally:
        process.Close()
    validate_probe_source(SOURCE)
    before = hashlib.sha256(WORKBOOK.read_bytes()).hexdigest()
    pythoncom.CoInitialize()
    try:
        with desktop_lease('observe owned workbook instance lifetime') as guard:
            app = native_excel(owner['excel_pid'])
            book = app.Workbooks.Item(WORKBOOK.name)
            if Path(book.FullName).resolve() != WORKBOOK.resolve():
                raise RuntimeError('Owned greeter path differs')
            names = [book.VBProject.VBComponents.Item(i).Name for i in range(1, book.VBProject.VBComponents.Count + 1)]
            if 'Run4Lifecycle' in names:
                module = book.VBProject.VBComponents.Item('Run4Lifecycle')
                if 'Public Function Run4Lifetime()' not in module.CodeModule.Lines(1, module.CodeModule.CountOfLines):
                    raise RuntimeError('Existing observer module is not ours')
                guard(); module.CodeModule.DeleteLines(1, module.CodeModule.CountOfLines)
            else:
                guard(); module = book.VBProject.VBComponents.Add(1)
                module.Name = 'Run4Lifecycle'
            guard(); module.CodeModule.AddFromString(SOURCE)
            guard(); result = app.Run("'" + book.Name + "'!Run4Lifetime")
            (output / 'observer.bas').write_text(SOURCE, encoding='utf-8', newline='\n')
            unchanged = before == hashlib.sha256(WORKBOOK.read_bytes()).hexdigest()
            data = dict(schema='calcforms.native_workbook_lifetime.v1', excel_pid=owner['excel_pid'], additional_excel_launches=0,
                        workbook_sha256=before, workbook_unchanged=unchanged, observer_retained_until_owned_workbook_close=True, result=result)
            (output / 'observations.json').write_text(json.dumps(data, indent=2) + '\n')
            print(result)
            if not unchanged or str(result).startswith('CALCFORMS_NATIVE_ERROR:'):
                raise RuntimeError('Native lifetime observation failed; see retained result')
    finally:
        pythoncom.CoUninitialize()


if __name__ == '__main__':
    main()
