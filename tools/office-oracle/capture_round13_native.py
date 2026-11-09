"""Round 13 native probes in one owned hidden Excel (macro calls only).

.118  ListBox Height as an ordered sequence of operations (font, border, IntegralHeight, Height, Show),
      so the rule that decides when Excel snaps, keeps or restores the public Height can be read from
      the order of events instead of from one fixed order.
"""
import argparse
import json
from pathlib import Path

from hidden_excel import hidden_excel

LIST_FORM = '''Option Explicit
Private Sub UserForm_Initialize()
    Dim L As Object, I As Long
    Set L = Me.Controls.Add("Forms.ListBox.1", "L")
    L.Left = 6: L.Top = 6: L.Width = 120: L.Height = 72
    For I = 0 To 29
        L.AddItem "Row " & CStr(I)
    Next I
End Sub
'''

MODULE = '''Option Explicit
Public Function SeqRun(ByVal Zoom As Long, ByVal Ops As String) As String
    On Error GoTo Failed
    Dim L As Object, S As String, Parts() As String, I As Long, Op As String, Arg As String
    Unload ListForm
    Load ListForm
    ListForm.Zoom = Zoom
    Set L = ListForm.Controls("L")
    S = "start=" & CStr(L.Height) & ";"
    Parts = Split(Ops, ",")
    For I = 0 To UBound(Parts)
        Op = Left(Parts(I), 1)
        Arg = Mid(Parts(I), 2)
        Select Case Op
            Case "F": L.Font.Name = "Tahoma": L.Font.Size = CSng(Arg)
            Case "A": L.Font.Name = "Arial": L.Font.Size = CSng(Arg)
            Case "B": L.BorderStyle = CLng(Arg)
            Case "I": L.IntegralHeight = (Arg = "1")
            Case "H": L.Height = CSng(Arg)
            Case "S": ListForm.Show vbModeless
            Case "N": ListForm.Hide
            Case "T": L.ListIndex = 29
            Case "Z": L.ListIndex = 0
            Case "R"
        End Select
        If Op = "T" Or Op = "Z" Then
            S = S & Parts(I) & "=top" & CStr(L.TopIndex) & ";"
        Else
            S = S & Parts(I) & "=" & CStr(L.Height) & ";"
        End If
    Next I
    SeqRun = S
    On Error Resume Next
    ListForm.Hide
    Unload ListForm
    Exit Function
Failed:
    SeqRun = S & "ERR:" & CStr(Err.Number) & ":" & Err.Description
    On Error Resume Next
    Unload ListForm
End Function
'''

SEQUENCES = []
for zoom in (100, 150):
    for h in (30, 50, 72, 100, 120):
        for prefix in ("", "F10,", "F8.25,", "B1,", "B0,", "A12,", "I0,", "I0,F10,", "F10,I0,", "B1,F10,"):
            SEQUENCES.append((zoom, f"{prefix}R,H{h},S,R,H{h},R,N,R"))
        SEQUENCES.append((zoom, f"H{h},F10,R,S,R"))
        SEQUENCES.append((zoom, f"H{h},B1,R,S,R"))
        SEQUENCES.append((zoom, f"S,H{h},R,F10,R,B1,R,I0,R,I1,R"))
        SEQUENCES.append((zoom, f"S,F10,R,H{h},R,B0,R,B1,R,F8.25,R"))
        SEQUENCES.append((zoom, f"S,I0,H{h},R,I1,R,I0,R,I1,R,H{h},R"))
        SEQUENCES.append((zoom, f"S,H{h},T,Z,I0,T,Z,I1,T,Z"))


TAB_FORM = """Option Explicit
Private Sub UserForm_Initialize()
    Dim C As Object
    Set C = Me.Controls.Add("Forms.Frame.1", "Group")
    C.Left = 12: C.Top = 12: C.Width = 174: C.Height = 72
    Set C = Me.Controls.Add("Forms.Image.1", "Picture")
    C.Left = 210: C.Top = 12: C.Width = 66: C.Height = 54
    Set C = Me.Controls.Add("Forms.SpinButton.1", "Spinner")
    C.Left = 300: C.Top = 12: C.Width = 18: C.Height = 54
    Set C = Me.Controls.Add("Forms.ScrollBar.1", "Slider")
    C.Left = 12: C.Top = 102: C.Width = 174: C.Height = 18
    Set C = Me.Controls.Add("Forms.TabStrip.1", "TabsControl")
    C.Left = 12: C.Top = 144: C.Width = 174: C.Height = 102
    Set C = Me.Controls.Add("Forms.MultiPage.1", "PagesControl")
    C.Left = 210: C.Top = 102: C.Width = 162: C.Height = 144
    Set C = Me.Controls("Group").Controls.Add("Forms.Label.1", "NestedLabel")
    Set C = Me.Controls("Group").Controls.Add("Forms.TextBox.1", "NestedInput")
End Sub
"""

TAB_MODULE = """Option Explicit
Public Function TabShow() As Object
    Unload TabForm
    Load TabForm
    TabForm.Show vbModeless
    Set TabShow = TabForm
End Function
Public Function TabActive() As String
    On Error GoTo Failed
    TabActive = TabForm.ActiveControl.Name
    Exit Function
Failed:
    TabActive = "ERR" & CStr(Err.Number)
End Function
Public Function TabPage() As String
    On Error GoTo Failed
    TabPage = CStr(TabForm.Controls("PagesControl").Value)
    Exit Function
Failed:
    TabPage = "ERR" & CStr(Err.Number)
End Function
Public Sub TabClose()
    On Error Resume Next
    TabForm.Hide
    Unload TabForm
End Sub
"""


def foreground_info():
    import win32gui
    import win32process
    hwnd = win32gui.GetForegroundWindow()
    if not hwnd:
        return dict(hwnd=0)
    return dict(hwnd=hwnd, cls=win32gui.GetClassName(hwnd), title=win32gui.GetWindowText(hwnd),
                pid=win32process.GetWindowThreadProcessId(hwnd)[1])


def msaa_state(control):
    """Raw IAccessible focus, child count and per-child name/state for a control."""
    import ctypes
    import pythoncom
    from native_accessibility import Accessible, Variant, check_hresult, method
    acc = Accessible(control)
    try:
        out = dict(child_count=acc.child_count())
        focus = Variant()
        check_hresult(method(acc.pointer, 18, ctypes.HRESULT, [ctypes.POINTER(Variant)])(
            acc.pointer, ctypes.byref(focus)), 'IAccessible.get_accFocus')
        out['focus_vt'] = focus.vt
        out['focus_value'] = focus.value.i4 if focus.vt == pythoncom.VT_I4 else None
        states = []
        for child_id in range(0, out['child_count'] + 1):
            child = Variant()
            child.vt = pythoncom.VT_I4
            child.value.i4 = child_id
            state = Variant()
            check_hresult(method(acc.pointer, 14, ctypes.HRESULT, [Variant, ctypes.POINTER(Variant)])(
                acc.pointer, child, ctypes.byref(state)), 'IAccessible.get_accState')
            name = ctypes.c_wchar_p()
            hr = method(acc.pointer, 10, ctypes.HRESULT, [Variant, ctypes.POINTER(ctypes.c_wchar_p)])(
                acc.pointer, child, ctypes.byref(name))
            states.append(dict(child=child_id, state=state.value.i4 if state.vt == pythoncom.VT_I4 else None,
                               name=name.value if hr >= 0 else None))
        out['children'] = states
        return out
    finally:
        acc.close()


def part_list(macro, result):
    for zoom, ops in SEQUENCES:
        row = str(macro('SeqRun', zoom, ops))
        result['list_sequences'].append(dict(zoom=zoom, ops=ops, result=row))
    print(len(result['list_sequences']), 'list sequences', flush=True)


def part_focus(excel, pid, macro, result):
    from capture_focus_updates import SCENARIOS
    result['foreground_after_visible'] = foreground_info()
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
            else:
                out = 'foreground=' + json.dumps(foreground_info())
            rows.append(dict(step=list(step), result=out,
                             active=macro('PActive') if kind in ('focus', 'show') else None))
        macro('PUnload')
        result['focus_scenarios'][name] = rows
        print(name, json.dumps(rows), flush=True)


def part_tab(excel, pid, macro, result):
    import win32gui
    from native_accessibility import focused_hwnd, post_key
    from workbook_comparison_session import windows
    form = macro('TabShow')
    root = windows(pid, 'TabForm')[0]
    steps = []
    for index in range(14):
        entry = dict(step=index, active=str(macro('TabActive')), page=str(macro('TabPage')))
        try:
            hwnd = focused_hwnd(root, pid)
            entry['focus_hwnd_class'] = win32gui.GetClassName(hwnd)
            entry['focus_is_root'] = hwnd == root
        except Exception as error:
            entry['focus_hwnd_error'] = str(error)
        try:
            entry['multipage_msaa'] = msaa_state(form.Controls.Item('PagesControl'))
        except Exception as error:
            entry['multipage_msaa_error'] = str(error)
        try:
            entry['tabstrip_msaa'] = msaa_state(form.Controls.Item('TabsControl'))
        except Exception as error:
            entry['tabstrip_msaa_error'] = str(error)
        steps.append(entry)
        post_key(root, pid, 9)
    result['tab_steps'] = steps
    result['foreground_tab'] = foreground_info()
    macro('TabClose')
    print('tab steps', json.dumps([(e['step'], e['active'], e.get('multipage_msaa', {}).get('focus_value')) for e in steps]), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    result = dict(schema='calcforms.round13_native.v1', excel_launches=1, list_sequences=[],
                  focus_scenarios={}, errors={})
    try:
        with hidden_excel(args.root) as (excel, pid):
            result.update(excel_pid=pid, excel_version=str(excel.Version), excel_build=str(excel.Build))
            from capture_focus_updates import MODULE as FOCUS_MODULE
            from capture_round12_native import INPUT_FORM
            book = excel.Workbooks.Add()
            project = book.VBProject
            for name, code in (('ListForm', LIST_FORM), ('InputForm', INPUT_FORM), ('TabForm', TAB_FORM)):
                form = project.VBComponents.Add(3)
                form.Name = name
                form.CodeModule.AddFromString(code)
            for name, code in (('Probe', MODULE), ('FocusProbe', FOCUS_MODULE), ('TabProbe', TAB_MODULE)):
                mod = project.VBComponents.Add(1)
                mod.Name = name
                mod.CodeModule.AddFromString(code)
            macro = lambda name, *a: excel.Run("'" + book.Name + "'!" + name, *a)
            try:
                part_list(macro, result)
            except Exception as error:
                result['errors']['list'] = repr(error)
            # The next parts need a form that can become the active window. Excel stays on the
            # private desktop (run through on-private-desktop.ps1), so nothing reaches the owner.
            excel.Visible = True
            result['visible_set'] = True
            try:
                part_focus(excel, pid, macro, result)
            except Exception as error:
                result['errors']['focus'] = repr(error)
            try:
                part_tab(excel, pid, macro, result)
            except Exception as error:
                result['errors']['tab'] = repr(error)
            book.Close(False)
    finally:
        args.out.write_text(json.dumps(result, indent=2, default=str) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
