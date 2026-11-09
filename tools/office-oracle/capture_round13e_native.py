"""Round 13e native probe: who holds focus at the second MultiPage Tab stop (.133).

13b/13c showed two consecutive Tab stops reported as the MultiPage, with and without a TextBox on the page.
This run reads the selected page's own ActiveControl at each stop and varies the page content: a tab-stop
TextBox on the selected page, the same page with Value = 1 selecting an empty page, and a TextBox whose
TabStop is False.
"""
import argparse
import json
from pathlib import Path

from hidden_excel import hidden_excel

FORM = """Option Explicit
Private Sub UserForm_Initialize()
    Dim C As Object
    Set C = Me.Controls.Add("Forms.TextBox.1", "Before")
    C.Left = 12: C.Top = 6: C.Width = 90: C.Height = 18
    Set C = Me.Controls.Add("Forms.MultiPage.1", "MP")
    C.Left = 12: C.Top = 36: C.Width = 200: C.Height = 120
    Set C = Me.Controls.Add("Forms.TextBox.1", "After")
    C.Left = 12: C.Top = 170: C.Width = 90: C.Height = 18
End Sub
"""

MODULE = """Option Explicit
Public Function VShow(ByVal V As Long) As Object
    Dim mp As Object, t As Object
    Unload VForm
    Load VForm
    Set mp = VForm.Controls("MP")
    Select Case V
        Case 1
            Set t = mp.Pages(0).Controls.Add("Forms.TextBox.1", "InPage")
        Case 2
            Set t = mp.Pages(0).Controls.Add("Forms.TextBox.1", "InPage")
            mp.Value = 1
        Case 3
            Set t = mp.Pages(0).Controls.Add("Forms.TextBox.1", "InPage")
            t.TabStop = False
        Case 4
            Set t = mp.Pages(0).Controls.Add("Forms.TextBox.1", "InPage")
            Set t = mp.Pages(0).Controls.Add("Forms.TextBox.1", "InPage2")
    End Select
    VForm.Show vbModeless
    Set VShow = VForm
End Function
Public Function VActive() As String
    Dim mp As Object, pa As String
    On Error Resume Next
    VActive = VForm.ActiveControl.Name
    Set mp = VForm.Controls("MP")
    pa = "none"
    pa = mp.Pages(mp.Value).ActiveControl.Name
    If Err.Number <> 0 Then pa = "ERR" & CStr(Err.Number)
    VActive = VActive & "|page" & CStr(mp.Value) & "=" & pa
End Function
Public Sub VClose()
    On Error Resume Next
    VForm.Hide
    Unload VForm
End Sub
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    from capture_round13b_native import ACTIVATE_MODULE
    from capture_round13_native import msaa_state
    result = dict(schema='calcforms.round13e_native.v1', excel_launches=1, variants={}, errors={})
    try:
        with hidden_excel(args.root) as (excel, pid):
            result.update(excel_pid=pid, excel_version=str(excel.Version), excel_build=str(excel.Build))
            import win32gui
            from native_accessibility import post_key
            from workbook_comparison_session import windows
            book = excel.Workbooks.Add()
            project = book.VBProject
            form = project.VBComponents.Add(3)
            form.Name = 'VForm'
            form.CodeModule.AddFromString(FORM)
            for name, code in (('VProbe', MODULE), ('Activator', ACTIVATE_MODULE)):
                mod = project.VBComponents.Add(1)
                mod.Name = name
                mod.CodeModule.AddFromString(code)
            macro = lambda name, *a: excel.Run("'" + book.Name + "'!" + name, *a)
            for variant in (0, 1, 2, 3, 4):
                try:
                    form_object = macro('VShow', variant)
                    root = windows(pid, class_name='ThunderDFrame')[0]
                    macro('ActivateForm', win32gui.GetWindowText(root))
                    rows = []
                    for index in range(7):
                        entry = dict(step=index, active=str(macro('VActive')))
                        try:
                            states = msaa_state(form_object.Controls.Item('MP'))['children']
                            entry['header_focused'] = bool(states[1]['state'] & 4)
                        except Exception as error:
                            entry['msaa_error'] = str(error)
                        rows.append(entry)
                        post_key(root, pid, 9)
                    macro('VClose')
                    result['variants'][str(variant)] = rows
                    print(variant, json.dumps([(r['step'], r['active'], r.get('header_focused')) for r in rows]), flush=True)
                except Exception as error:
                    result['errors'][str(variant)] = repr(error)
                    try:
                        macro('VClose')
                    except Exception:
                        pass
            book.Close(False)
    finally:
        args.out.write_text(json.dumps(result, indent=2, default=str) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
