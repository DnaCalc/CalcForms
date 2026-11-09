"""Native update/focus events from programmatic Text, first Show and redundant SetFocus (.124).

The owned Excel runs hidden on a private desktop; this process lives on the same private desktop and
activates the form window there so Enter/Exit/BeforeUpdate/AfterUpdate behave as for a live form.
No keyboard, pointer or focus of the owner's desktop is used.
"""
import argparse
import ctypes
import json
import time
from pathlib import Path

import win32api
import win32con
import win32gui
import win32process

from capture_round12_native import INPUT_FORM
from hidden_excel import hidden_excel

MODULE = '''Option Explicit
Public Function PLoad() As String
    On Error GoTo Failed
    Unload InputForm
    Load InputForm
    InputForm.Log = ""
    PLoad = "ok"
    Exit Function
Failed:
    PLoad = "ERR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function PShow() As String
    On Error GoTo Failed
    InputForm.Show vbModeless
    PShow = InputForm.Log
    InputForm.Log = ""
    Exit Function
Failed:
    PShow = "ERR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function PHide() As String
    On Error GoTo Failed
    InputForm.Hide
    PHide = InputForm.Log
    InputForm.Log = ""
    Exit Function
Failed:
    PHide = "ERR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function PText(ByVal Name As String, ByVal Text As String) As String
    On Error GoTo Failed
    InputForm.Controls(Name).Text = Text
    PText = InputForm.Log
    InputForm.Log = ""
    Exit Function
Failed:
    PText = "ERR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function PFocus(ByVal Name As String) As String
    On Error GoTo Failed
    InputForm.Controls(Name).SetFocus
    PFocus = InputForm.Log
    InputForm.Log = ""
    Exit Function
Failed:
    PFocus = "ERR:" & CStr(Err.Number) & ":" & Err.Description
End Function
Public Function PActive() As String
    On Error GoTo Failed
    PActive = "active=" & InputForm.ActiveControl.Name
    Exit Function
Failed:
    PActive = "active=ERR" & CStr(Err.Number)
End Function
Public Function PUnload() As String
    On Error Resume Next
    Unload InputForm
    PUnload = "ok"
End Function
'''

SCENARIOS = {
    'text-before-show': [('load',), ('text', 'Qty', '5'), ('show',), ('activate',), ('focus', 'Qty'), ('focus', 'Qty'), ('focus', 'Other'), ('focus', 'Other')],
    'text-while-focused': [('load',), ('show',), ('activate',), ('focus', 'Qty'), ('text', 'Qty', '6'), ('focus', 'Qty'), ('focus', 'Other'), ('focus', 'Qty'), ('focus', 'Other')],
    'text-unfocused': [('load',), ('show',), ('activate',), ('text', 'Qty', '7'), ('focus', 'Qty'), ('focus', 'Other')],
    'no-text': [('load',), ('show',), ('activate',), ('focus', 'Qty'), ('focus', 'Qty'), ('focus', 'Other')],
    'text-same-value': [('load',), ('show',), ('activate',), ('focus', 'Qty'), ('text', 'Qty', '8'), ('text', 'Qty', '8'), ('focus', 'Other')],
    'hide-reshow': [('load',), ('show',), ('activate',), ('focus', 'Qty'), ('text', 'Qty', '9'), ('hide',), ('show',), ('activate',), ('focus', 'Other')],
}


def activate(pid, wait=True):
    found = []

    def collect(hwnd, _):
        if win32process.GetWindowThreadProcessId(hwnd)[1] == pid and win32gui.GetClassName(hwnd) == 'ThunderDFrame':
            found.append(hwnd)
        return True
    deadline = time.monotonic() + 10
    while not found and time.monotonic() < deadline:
        win32gui.EnumWindows(collect, None)
        if not found:
            time.sleep(0.1)
    if not found:
        return 'no ThunderDFrame window'
    hwnd = found[0]
    # This process runs on the private desktop; these calls cannot reach the owner's desktop.
    win32gui.ShowWindow(hwnd, win32con.SW_SHOWNOACTIVATE)
    attempts = []
    target = win32process.GetWindowThreadProcessId(hwnd)[0]
    current = win32api.GetCurrentThreadId()
    for name in ('foreground', 'attach', 'switch', 'messages'):
        try:
            if name == 'foreground':
                win32gui.SetForegroundWindow(hwnd)
            elif name == 'attach':
                win32process.AttachThreadInput(current, target, True)
                try:
                    win32gui.SetForegroundWindow(hwnd)
                    win32gui.BringWindowToTop(hwnd)
                finally:
                    win32process.AttachThreadInput(current, target, False)
            elif name == 'switch':
                ctypes.windll.user32.SwitchToThisWindow(hwnd, True)
            else:
                win32gui.SendMessage(hwnd, win32con.WM_ACTIVATEAPP, 1, 0)
                win32gui.SendMessage(hwnd, win32con.WM_ACTIVATE, win32con.WA_ACTIVE, 0)
        except Exception as error:
            attempts.append(f'{name}: failed {error}')
            continue
        time.sleep(0.3)
        state = 'yes' if win32gui.GetForegroundWindow() == hwnd else 'no'
        attempts.append(f'{name}: foreground={state}')
        if state == 'yes':
            break
    return '; '.join(attempts)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--no-activate', action='store_true')
    args = parser.parse_args()
    result = dict(schema='calcforms.focus_updates.v1', excel_launches=1, scenarios={})
    try:
        with hidden_excel(args.root) as (excel, pid):
            result.update(excel_pid=pid, excel_version=str(excel.Version), excel_build=str(excel.Build))
            book = excel.Workbooks.Add()
            form = book.VBProject.VBComponents.Add(3)
            form.Name = 'InputForm'
            form.CodeModule.AddFromString(INPUT_FORM)
            mod = book.VBProject.VBComponents.Add(1)
            mod.Name = 'Probe'
            mod.CodeModule.AddFromString(MODULE)
            macro = lambda name, *a: str(excel.Run("'" + book.Name + "'!" + name, *a))
            for name, steps in SCENARIOS.items():
                rows = []
                for step in steps:
                    kind = step[0]
                    if kind == 'load':
                        out = macro('PLoad')
                    elif kind == 'show':
                        out = macro('PShow')
                    elif kind == 'hide':
                        out = macro('PHide')
                    elif kind == 'text':
                        out = macro('PText', step[1], step[2])
                    elif kind == 'focus':
                        out = macro('PFocus', step[1])
                    elif kind == 'activate':
                        out = 'skipped' if args.no_activate else activate(pid)
                    rows.append(dict(step=list(step), result=out, active=macro('PActive') if kind in ('focus', 'show') else None))
                macro('PUnload')
                result['scenarios'][name] = rows
                print(name, json.dumps(rows), flush=True)
            book.Close(False)
    finally:
        args.out.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
