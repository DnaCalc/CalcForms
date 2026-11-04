"""Build the workbook greeter and keep one owned Excel for interactive comparison.

Requires the existing pywin32 installation and existing VBIDE access. This never
changes Office security, registry settings, or another Excel process. Commands on
stdin are JSON objects: state, show, hide, reset, close. One process is reused.
"""
from __future__ import annotations

import argparse
import ctypes
from ctypes import wintypes
import json
from pathlib import Path
import sys
import uuid

import pythoncom
import win32com.client
import win32gui
import win32process


FORM_CODE = '''Option Explicit
Private mLog As String

Private Sub UserForm_Initialize()
    mLog = "Initialize"
End Sub

Private Sub InputName_Change()
    mLog = mLog & "|Change:" & InputName.Text
End Sub

Private Sub Greet_Click()
    Output.Caption = "Hello, " & InputName.Text
    If Loud.Value Then Output.Caption = UCase$(Output.Caption)
    mLog = mLog & "|Click:" & Output.Caption
End Sub

Private Sub Loud_Click()
    mLog = mLog & "|Check:" & CStr(Loud.Value)
End Sub

Public Function State() As String
    State = mLog & ";text=" & InputName.Text & ";caption=" & Output.Caption & ";loud=" & CStr(Loud.Value)
End Function
'''

MODULE_CODE = '''Option Explicit
Public Sub ShowGreeter()
    WorkbookGreeter.Show vbModeless
End Sub
Public Sub HideGreeter()
    WorkbookGreeter.Hide
End Sub
Public Sub ResetGreeter()
    Unload WorkbookGreeter
    WorkbookGreeter.Show vbModeless
End Sub
Public Function GreeterState() As String
    GreeterState = WorkbookGreeter.State()
End Function
'''

ORACLE_CODE = '''
Public Function CalcFormsOracleStep(ByVal Action As String, ByVal Text As String) As String
    Select Case Action
        Case "text"
            WorkbookGreeter.InputName.Text = Text
        Case "greet"
            WorkbookGreeter.Greet.Value = True
        Case "check"
            WorkbookGreeter.Loud.Value = True
    End Select
    CalcFormsOracleStep = WorkbookGreeter.State()
End Function
'''


def emit(value: dict) -> None:
    print(json.dumps(value), flush=True)


def compare_owned(session_dir: Path, output: Path) -> None:
    """Attach through NativeOM to the recorded PID; never activate a new Excel."""
    owner = json.loads((session_dir / 'ownership.json').read_text(encoding='utf-8'))
    roots = []
    def collect(hwnd, _):
        if win32process.GetWindowThreadProcessId(hwnd)[1] == owner['pid'] and win32gui.GetClassName(hwnd) == 'XLMAIN':
            roots.append(hwnd)
    win32gui.EnumWindows(collect, None)
    children = []
    for root in roots:
        win32gui.EnumChildWindows(root, lambda hwnd, _: children.append(hwnd) if win32gui.GetClassName(hwnd) == 'EXCEL7' else None, None)
    if len(children) != 1:
        raise RuntimeError('Expected exactly one worksheet window in the recorded owned process')
    class Guid(ctypes.Structure):
        _fields_ = [('data1', wintypes.DWORD), ('data2', wintypes.WORD), ('data3', wintypes.WORD), ('data4', ctypes.c_ubyte * 8)]
    iid = Guid.from_buffer_copy(uuid.UUID(str(pythoncom.IID_IDispatch)).bytes_le)
    pointer = ctypes.c_void_p()
    function = ctypes.OleDLL('oleacc').AccessibleObjectFromWindow
    function.argtypes = [wintypes.HWND, wintypes.DWORD, ctypes.POINTER(Guid), ctypes.POINTER(ctypes.c_void_p)]
    function.restype = ctypes.HRESULT
    pythoncom.CoInitialize()
    try:
        function(children[0], 0xfffffff0, ctypes.byref(iid), ctypes.byref(pointer))
        window = win32com.client.Dispatch(pythoncom.ObjectFromAddress(pointer.value, pythoncom.IID_IDispatch))
        excel = window.Application
        if win32process.GetWindowThreadProcessId(excel.Hwnd)[1] != owner['pid']:
            raise RuntimeError('NativeOM PID differs from the owned Excel')
        book = excel.Workbooks.Item('workbook-greeter.xlsm')
        if Path(book.FullName).resolve() != Path(owner['workbook']).resolve():
            raise RuntimeError('Owned workbook path mismatch')
        module = book.VBProject.VBComponents.Item('GreeterEntry').CodeModule
        if 'CalcFormsOracleStep' not in module.Lines(1, module.CountOfLines):
            module.AddFromString(ORACLE_CODE)
        excel.Run('ResetGreeter')
        observations = [{'action': 'initial', 'state': excel.Run('GreeterState')}]
        for action, text in [('greet',''), ('text','Lin'), ('greet',''), ('check',''), ('greet','')]:
            observations.append({'action': action, 'text': text, 'state': excel.Run('CalcFormsOracleStep', action, text)})
        result = {'schema': 'calcforms.workbook_greeter_oracle.v1', 'excel_version': excel.Version,
                  'excel_build': excel.Build, 'pid': owner['pid'], 'launches': owner['launches'],
                  'input': 'public MSForms Text/Value setters', 'observations': observations}
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
        emit(result)
        # The added driver stays in memory. The saved input fixture is unchanged.
    finally:
        pythoncom.CoUninitialize()


def run(directory: Path, session_dir: Path) -> None:
    directory = directory.resolve()
    session_dir = session_dir.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    session_dir.mkdir(parents=True, exist_ok=True)
    workbook_path = directory / 'workbook-greeter.xlsm'
    if workbook_path.exists():
        raise ValueError(f'Refusing to overwrite fixture {workbook_path}')
    ownership_path = session_dir / 'ownership.json'
    previous = json.loads(ownership_path.read_text(encoding='utf-8')) if ownership_path.exists() else {}
    launches = int(previous.get('launches', 0)) + 1
    pythoncom.CoInitialize()
    before = set(win32process.EnumProcesses())
    excel = None
    owned = False
    try:
        emit({'stage': 'starting_excel', 'launches': launches})
        excel = win32com.client.DispatchEx('Excel.Application')
        _, process_id = win32process.GetWindowThreadProcessId(excel.Hwnd)
        if process_id in before:
            raise RuntimeError('DispatchEx returned a pre-existing process; refusing to operate it')
        owned = True
        ownership = {'pid': process_id, 'launches': launches, 'created_by': 'workbook_form_session.py',
                     'workbook': str(workbook_path), 'security_changes': 0}
        ownership_path.write_text(json.dumps(ownership, indent=2) + '\n', encoding='utf-8')
        emit({'stage': 'owned_excel', **ownership})
        excel.DisplayAlerts = False
        excel.Visible = True
        book = excel.Workbooks.Add()
        project = book.VBProject  # Existing Trust Center policy applies; do not change it.
        component = project.VBComponents.Add(3)
        component.Name = 'WorkbookGreeter'
        designer = component.Designer
        component.Properties.Item('Caption').Value = 'CalcForms workbook greeter'
        component.Properties.Item('Width').Value = 300
        component.Properties.Item('Height').Value = 160
        for kind, name, caption, left, top, width, height in [
            ('Label', 'Prompt', 'Your name', 12, 12, 96, 18),
            ('TextBox', 'InputName', '', 12, 36, 170, 20),
            ('CommandButton', 'Greet', 'Greet', 198, 36, 72, 24),
            ('CheckBox', 'Loud', 'Uppercase', 12, 66, 120, 18),
            ('Label', 'Output', '(ready)', 12, 96, 258, 22),
        ]:
            control = designer.Controls.Add(f'Forms.{kind}.1', name, True)
            control.Left, control.Top = left, top
            control.Width, control.Height = width, height
            if kind == 'TextBox':
                control.Text = 'Ada'
            else:
                control.Caption = caption
            if kind == 'CommandButton':
                control.Default = True
        component.CodeModule.AddFromString(FORM_CODE)
        module = project.VBComponents.Add(1)
        module.Name = 'GreeterEntry'
        module.CodeModule.AddFromString(MODULE_CODE)
        component.Export(str(directory / 'WorkbookGreeter.frm'))
        (directory / 'form-code.bas').write_text(FORM_CODE, encoding='utf-8', newline='\n')
        (directory / 'entry-code.bas').write_text(MODULE_CODE, encoding='utf-8', newline='\n')
        book.SaveAs(str(workbook_path), 52)
        excel.Run('ShowGreeter')
        emit({'stage': 'ready', 'pid': process_id, 'launches': launches, 'state': excel.Run('GreeterState')})
        for line in sys.stdin:
            try:
                command = json.loads(line)['command']
                if command == 'close':
                    break
                procedure = {'show': 'ShowGreeter', 'hide': 'HideGreeter', 'reset': 'ResetGreeter'}.get(command)
                if procedure:
                    excel.Run(procedure)
                elif command != 'state':
                    raise ValueError(f'Unknown command {command}')
                emit({'stage': command, 'state': excel.Run('GreeterState'), 'launches': launches})
            except Exception as error:
                emit({'stage': 'command_error', 'error': str(error), 'launches': launches})
    finally:
        if owned and excel is not None:
            excel.Quit()
            emit({'stage': 'closed_owned_excel', 'launches': launches})
        pythoncom.CoUninitialize()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path)
    parser.add_argument('--session-dir', type=Path, required=True)
    parser.add_argument('--compare', type=Path, help='Write native observations using the already-owned process')
    args = parser.parse_args()
    if args.compare:
        compare_owned(args.session_dir, args.compare)
    elif args.directory:
        run(args.directory, args.session_dir)
    else:
        parser.error('--directory or --compare is required')
