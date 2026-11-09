"""Round 13b native probes in one owned Excel on a private desktop (macro calls only).

.124  The form window is made the thread's active window from inside Excel's own UI thread
      (SetActiveWindow/SetFocus declared in a macro), because no foreground window exists on the
      private desktop and a foreign process cannot activate it. Then the .124 scenarios run again, so
      Enter/Exit/BeforeUpdate/AfterUpdate can be observed.
.133  Repeated Tab positions across the LayoutContainers controls, with the focused window class,
      Form.ActiveControl and the raw IAccessible focus/state of the MultiPage and TabStrip.
"""
import argparse
import json
from pathlib import Path

from hidden_excel import hidden_excel

ACTIVATE_MODULE = """Option Explicit
Private Declare PtrSafe Function FindWindowW Lib "user32" (ByVal cls As LongPtr, ByVal title As LongPtr) As LongPtr
Private Declare PtrSafe Function SetActiveWindow Lib "user32" (ByVal hwnd As LongPtr) As LongPtr
Private Declare PtrSafe Function GetActiveWindow Lib "user32" () As LongPtr
Private Declare PtrSafe Function SetFocusApi Lib "user32" Alias "SetFocus" (ByVal hwnd As LongPtr) As LongPtr
Private Declare PtrSafe Function GetFocusApi Lib "user32" Alias "GetFocus" () As LongPtr
Private Declare PtrSafe Function GetForegroundWindow Lib "user32" () As LongPtr
Public Function ActivateForm(ByVal Caption As String) As String
    Dim h As LongPtr, before As LongPtr, prev As LongPtr, setf As LongPtr
    h = FindWindowW(StrPtr("ThunderDFrame"), StrPtr(Caption))
    If h = 0 Then
        ActivateForm = "no window"
        Exit Function
    End If
    before = GetActiveWindow()
    prev = SetActiveWindow(h)
    setf = SetFocusApi(h)
    ActivateForm = "hwnd=" & CStr(h) & ";activeBefore=" & CStr(before) & ";activeAfter=" & CStr(GetActiveWindow()) & ";focus=" & CStr(GetFocusApi()) & ";foreground=" & CStr(GetForegroundWindow())
End Function
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    from capture_focus_updates import MODULE as FOCUS_MODULE, SCENARIOS
    from capture_round12_native import INPUT_FORM
    from capture_round13_native import TAB_FORM, TAB_MODULE, msaa_state, foreground_info
    result = dict(schema='calcforms.round13b_native.v1', excel_launches=1, focus_scenarios={}, errors={})
    try:
        with hidden_excel(args.root) as (excel, pid):
            result.update(excel_pid=pid, excel_version=str(excel.Version), excel_build=str(excel.Build))
            book = excel.Workbooks.Add()
            project = book.VBProject
            for name, code in (('InputForm', INPUT_FORM), ('TabForm', TAB_FORM)):
                form = project.VBComponents.Add(3)
                form.Name = name
                form.CodeModule.AddFromString(code)
            for name, code in (('FocusProbe', FOCUS_MODULE), ('TabProbe', TAB_MODULE), ('Activator', ACTIVATE_MODULE)):
                mod = project.VBComponents.Add(1)
                mod.Name = name
                mod.CodeModule.AddFromString(code)
            macro = lambda name, *a: excel.Run("'" + book.Name + "'!" + name, *a)
            try:
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
                            out = str(macro('ActivateForm', 'InputForm'))
                        rows.append(dict(step=list(step), result=out,
                                         active=macro('PActive') if kind in ('focus', 'show') else None))
                    macro('PUnload')
                    result['focus_scenarios'][name] = rows
                    print(name, json.dumps(rows), flush=True)
            except Exception as error:
                result['errors']['focus'] = repr(error)
            try:
                import win32gui
                from native_accessibility import focused_hwnd, post_key
                from workbook_comparison_session import windows
                form = macro('TabShow')
                frames = windows(pid, class_name='ThunderDFrame')
                result['tab_windows'] = [dict(hwnd=h, title=win32gui.GetWindowText(h)) for h in frames]
                root = frames[0]
                result['tab_activate'] = str(macro('ActivateForm', win32gui.GetWindowText(root)))
                steps = []
                for index in range(14):
                    entry = dict(step=index, active=str(macro('TabActive')), page=str(macro('TabPage')))
                    try:
                        hwnd = focused_hwnd(root, pid)
                        entry['focus_hwnd_class'] = win32gui.GetClassName(hwnd)
                        entry['focus_is_root'] = hwnd == root
                    except Exception as error:
                        entry['focus_hwnd_error'] = str(error)
                    for key, name in (('multipage_msaa', 'PagesControl'), ('tabstrip_msaa', 'TabsControl')):
                        try:
                            entry[key] = msaa_state(form.Controls.Item(name))
                        except Exception as error:
                            entry[key + '_error'] = str(error)
                    steps.append(entry)
                    post_key(root, pid, 9)
                result['tab_steps'] = steps
                result['foreground_tab'] = foreground_info()
                macro('TabClose')
                print('tab', json.dumps([(e['step'], e['active'], e.get('multipage_msaa', {}).get('focus_value')) for e in steps]), flush=True)
            except Exception as error:
                result['errors']['tab'] = repr(error)
            book.Close(False)
    finally:
        args.out.write_text(json.dumps(result, indent=2, default=str) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
