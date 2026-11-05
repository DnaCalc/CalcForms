"""Prepare/restore an authored physical-input probe in an already-owned Excel."""
import argparse
import hashlib
import json
from pathlib import Path
import re

import pythoncom
import win32api
import win32con
import win32process

from desktop_lease import desktop_lease
from probe_source import validate_probe_source
from workbook_comparison_session import EXCEL, native_excel


TEXT = 'Alpha Beta Gamma Delta'
READBACK = '''Option Explicit
Public Function Run4InputState() As String
    On Error GoTo Failed
    Run4InputState = LayoutCommon.InputState()
    Exit Function
Failed:
    Run4InputState = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
'''
NATIVE_MEMBERS = '''
Private Sub Greet_Click()
    On Error GoTo Failed
    mInputClicks = mInputClicks + 1
    Exit Sub
Failed:
    mInputError = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Sub
Public Function InputState() As String
    On Error GoTo Failed
    If Len(mInputError) > 0 Then
        InputState = mInputError
        Exit Function
    End If
    InputState = "text=" & InputName.Text & ";start=" & CStr(InputName.SelStart) & ";length=" & CStr(InputName.SelLength) & ";selected=" & InputName.SelText & ";clicks=" & CStr(mInputClicks) & ";focus=" & Me.ActiveControl.Name
    Exit Function
Failed:
    InputState = "CALCFORMS_NATIVE_ERROR:" & CStr(Err.Number) & ":" & Err.Description
End Function
'''
RUNTIME_MEMBERS = '''Public Function LayoutFacts() As String
    LayoutFacts = "text=" & InputName.Text & ";start=" & CStr(InputName.SelStart) & ";length=" & CStr(InputName.SelLength) & ";selected=" & InputName.SelText & ";clicks=" & CStr(mInputClicks) & ";focus=" & CalcFormsHostReducer.FocusName
End Function
Private Sub Greet_Click()
    mInputClicks = mInputClicks + 1
End Sub'''


def digest(text):
    return hashlib.sha256((text.replace('\r\n', '\n').rstrip('\n') + '\n').encode()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owner', type=Path, required=True)
    parser.add_argument('--restore', action='store_true')
    args = parser.parse_args()
    owner_path = args.owner.resolve()
    owner = json.loads(owner_path.read_text())
    if owner['schema'] != 'calcforms.layout_session.v1' or owner.get('closed') or not owner['interactive']:
        raise RuntimeError('Requires the original live interactive ownership file')
    output = owner_path.parent / 'input-probe'
    if not output.resolve().is_relative_to(Path('C:/Work/DnaCalc/codex-runs/forms-captures').resolve()):
        raise RuntimeError('Probe must stay inside the capture root')
    process = win32api.OpenProcess(win32con.PROCESS_QUERY_INFORMATION | win32con.PROCESS_VM_READ, False, owner['excel_pid'])
    try:
        created = win32process.GetProcessTimes(process)['CreationTime'].timestamp()
        if Path(win32process.GetModuleFileNameEx(process, 0)).resolve() != EXCEL.resolve() or abs(created - owner_path.stat().st_birthtime) > 10:
            raise RuntimeError('Owned process identity changed')
    finally:
        process.Close()
    pythoncom.CoInitialize()
    try:
        with desktop_lease('restore input probe' if args.restore else 'prepare input probe') as guard:
            app = native_excel(owner['excel_pid'])
            book = app.Workbooks.Item('layout-corpus.xlsm')
            if Path(book.FullName).resolve() != (owner_path.parent / 'corpus/layout-corpus.xlsm').resolve():
                raise RuntimeError('Authored workbook path differs')
            module = book.VBProject.VBComponents.Item('LayoutCommon').CodeModule
            current_native = module.Lines(1, module.CountOfLines)
            runtime_path = owner_path.parent / 'corpus/LayoutCommon.cls'
            current_runtime = runtime_path.read_text(encoding='utf-8')
            if args.restore:
                proof = json.loads((output / 'prepared.json').read_text())
                if digest(current_native) != proof['native_sha256'] or digest(current_runtime) != proof['runtime_sha256']:
                    raise RuntimeError('Prepared source changed; refusing to overwrite it')
                readback = book.VBProject.VBComponents.Item('Run4InputReadback')
                if digest(readback.CodeModule.Lines(1, readback.CodeModule.CountOfLines)) != digest(READBACK):
                    raise RuntimeError('Readback module changed')
                guard(); module.DeleteLines(1, module.CountOfLines)
                guard(); module.AddFromString((output / 'native-original.bas').read_text())
                guard(); book.VBProject.VBComponents.Remove(readback)
                runtime_path.write_text((output / 'runtime-original.cls').read_text(), encoding='utf-8', newline='\n')
                print('Restored only the owned authored input probe')
                return
            output.mkdir(exist_ok=False)
            (output / 'native-original.bas').write_text(current_native, encoding='utf-8', newline='\n')
            (output / 'runtime-original.cls').write_text(current_runtime, encoding='utf-8', newline='\n')
            native = current_native.replace('Option Explicit', 'Option Explicit\nPrivate mInputClicks As Long\nPrivate mInputError As String')
            native = native.replace('Private Sub UserForm_Initialize()', f'Private Sub UserForm_Initialize()\n    InputName.Text = "{TEXT}"\n    Greet.Accelerator = "G"') + NATIVE_MEMBERS
            validate_probe_source(native)
            runtime = current_runtime.replace('Option Explicit', 'Option Explicit\nPrivate mInputClicks As Long')
            runtime = runtime.replace('Public Greet As CommandButton', 'Public WithEvents Greet As CommandButton')
            runtime = runtime.replace('InputName.Text = "Ada"', f'InputName.Text = "{TEXT}"').replace('Greet.Caption = "Greet"', 'Greet.Caption = "&Greet"')
            runtime, count = re.subn(r'^Public Function LayoutFacts\(\) As String\n.*?^End Function', lambda _: RUNTIME_MEMBERS, runtime, flags=re.M | re.S)
            if count != 1:
                raise RuntimeError('Authored observation entry differs')
            validate_probe_source(READBACK)
            guard(); module.DeleteLines(1, module.CountOfLines)
            guard(); module.AddFromString(native)
            guard(); readback = book.VBProject.VBComponents.Add(1)
            readback.Name = 'Run4InputReadback'
            guard(); readback.CodeModule.AddFromString(READBACK)
            runtime_path.write_text(runtime, encoding='utf-8', newline='\n')
            (output / 'native-input.bas').write_text(native, encoding='utf-8', newline='\n')
            (output / 'runtime-input.cls').write_text(runtime, encoding='utf-8', newline='\n')
            (output / 'readback.bas').write_text(READBACK, encoding='utf-8', newline='\n')
            observed = module.Lines(1, module.CountOfLines)
            (output / 'prepared.json').write_text(json.dumps(dict(native_sha256=digest(observed), runtime_sha256=digest(runtime), text=TEXT, excel_pid=owner['excel_pid'], additional_excel_launches=0), indent=2) + '\n')
            print('Prepared owned common-form input probe; native Accelerator and current runtime caption mnemonic are explicit')
    finally:
        pythoncom.CoUninitialize()


if __name__ == '__main__':
    main()
